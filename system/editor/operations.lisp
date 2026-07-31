;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Graph-editor operations.
;;
;;  The edit primitive is one arc: attach an arc to the focus concept, or
;;  remove one. Everything the editor pane does is one of these.
;;
;;  These MUTATE the working graph in place. That is not incidental -- the
;;  skeleton showed that rebuilding by re-parsing mints new nodes and so
;;  churns every node-ref, which would invalidate the browser's click map
;;  after every edit. Refs must stay stable for the life of a session.
;;
;;  Mutating is safe here precisely because the working graph is a private
;;  copy: the original is untouched until commit (see session.lisp).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-condition editor-operation-error (error)
  ((text :initarg :text :reader editor-operation-error-text))
  (:report (lambda (c s) (write-string (editor-operation-error-text c) s))))

(defun editor-error (fmt &rest args)
  (error 'editor-operation-error :text (apply #'format nil fmt args)))

;;; --- Resolving what the browser sent ---------------------------------------

(defun editor-concept (session ref)
  "The concept in SESSION's working graph with node-ref REF."
  (let ((node (session-node session ref)))
    (cond ((null node) (editor-error "no node ~a in this graph" ref))
          ((not (concept-p node)) (editor-error "node ~a is not a concept" ref))
          (t node))))

(defun editor-relation-node (session ref)
  (let ((node (session-node session ref)))
    (cond ((null node) (editor-error "no node ~a in this graph" ref))
          ((not (relation-p node)) (editor-error "node ~a is not a relation" ref))
          (t node))))

(defun editor-make-concept (type-label)
  "A new concept of TYPE-LABEL, with no referent."
  (with-cg-thread-bindings
    (let ((ctype (or (ignore-errors (get-concept-type type-label))
                     (editor-error "unknown concept type: ~a" type-label))))
      (make-concept ctype nil))))

(defun editor-make-relation (label)
  (with-cg-thread-bindings
    (let ((rtype (or (ignore-errors (get-relation-type
                                     (intern (string-upcase (string label))
                                             :conceptual-graphs)))
                     (editor-error "unknown relation type: ~a" label))))
      (or (make-relation rtype)
          (editor-error "could not build relation ~a" label)))))

;;; --- Reachability ----------------------------------------------------------
;;;
;;; Removal prunes "until a concept is reached that is linked via a different
;;; path". Rather than walk outward guessing at that condition, disconnect the
;;; arc and then keep whatever is still reachable from the focus. That is the
;;; same rule stated directly, and it gets three cases right for free:
;;;
;;;   - a coreferent node survives, because the other path still reaches it
;;;   - a dangling branch vanishes entirely, not just its first node
;;;   - cycles terminate, because reachability visits each node once
;;;
;;; Travel is away from the focus and has nothing to do with arc direction.

(defun editor-reachable (start)
  "Every node reachable from START, ignoring arc direction."
  (let ((seen (make-hash-table :test 'eq))
        (stack (list start)))
    (loop while stack
          for node = (pop stack)
          unless (gethash node seen)
            do (setf (gethash node seen) t)
               (dolist (n (arcs node))
                 (unless (gethash n seen) (push n stack))))
    seen))

(defun editor-collect-garbage (session focus)
  "Unlink everything no longer reachable from FOCUS. Returns the count."
  (let* ((graph (session-working session))
         (live (editor-reachable focus))
         (dropped 0))
    ;; NODES traverses from HEAD, so gather candidates before HEAD can be
    ;; left pointing into the part we are about to drop.
    (dolist (node (append (nodes graph) (list focus)))
      (unless (gethash node live)
        (dolist (other (copy-list (arcs node)))
          (when (typep node 'relation)
            (ignore-errors (remove-arc node other)))
          (when (typep other 'relation)
            (ignore-errors (remove-arc other node))))
        (setf (arcs node) nil)
        (incf dropped)))
    (unless (gethash (head graph) live)
      (setf (head graph) focus))
    dropped))

;;; --- Add -------------------------------------------------------------------

(defun editor-add-arc (session &key focus relation target target-type
                                    (direction :forward))
  "Attach an arc to the focus concept.

   FOCUS is a node-ref. RELATION is a relation-type label. The other end is
   either TARGET (a node-ref -- an arc to an EXISTING concept, which is how
   two paths come to share a node) or TARGET-TYPE (a type label -- a NEW
   concept). DIRECTION is :FORWARD for [focus]->(rel)->[other] or :REVERSE
   for [focus]<-(rel)<-[other].

   CONNECT type-checks against the relation's source-types and dest-type, so
   an arc the lattice forbids signals here rather than corrupting the graph."
  (with-cg-thread-bindings
    (let* ((graph (session-working session))
           (focus-node (editor-concept session focus))
           (other (cond (target      (editor-concept session target))
                        (target-type (editor-make-concept target-type))
                        (t (editor-error "need a target ref or a target type"))))
           (rel (editor-make-relation relation))
           (source (ecase direction (:forward focus-node) (:reverse other)))
           (dest   (ecase direction (:forward other)      (:reverse focus-node))))
      (connect source :right rel)
      (connect rel :right dest)
      (unless (head graph) (setf (head graph) focus-node))
      (values rel other))))

(defun editor-add-concept (session type-label)
  "Create a free-standing concept. Used to start an empty graph, where the
   first concept-type click makes a concept that becomes the focus."
  (with-cg-thread-bindings
    (let ((concept (editor-make-concept type-label)))
      (cond ((null (session-working session))
             (setf (session-working session)
                   (make-instance 'graph :head concept)))
            ((null (head (session-working session)))
             (setf (head (session-working session)) concept)))
      concept)))

;;; --- Remove ----------------------------------------------------------------

(defun editor-remove-arc (session &key focus relation)
  "Remove the arc joining FOCUS to RELATION, then drop whatever that leaves
   unreachable from FOCUS.

   The focus itself always survives, even when its last arc goes -- [DOG] is
   a valid graph. To remove the focus, focus on a neighbour first."
  (with-cg-thread-bindings
    (let* ((focus-node (editor-concept session focus))
           (rel (editor-relation-node session relation)))
      (unless (member rel (arcs focus-node) :test #'eq)
        (editor-error "relation ~a is not attached to concept ~a"
                      (node-ref rel) (node-ref focus-node)))
      ;; Detach the relation from every concept it touches; a relation with no
      ;; concepts is meaningless, so it always goes as a unit.
      (dolist (concept (copy-list (arcs rel)))
        (remove-arc rel concept))
      (setf (arcs rel) nil)
      (editor-collect-garbage session focus-node)
      focus-node)))

;;; --- What hangs off the focus ----------------------------------------------

(defun editor-focus-arcs (session focus)
  "The focus's neighbourhood, as the display pane shows it: one relation and
   concept per entry, with the direction the arc runs.

   Returns a list of plists (:relation-ref :relation :direction :concept-ref
   :concept), where :direction is :FORWARD when the focus is the relation's
   source."
  (with-cg-thread-bindings
    (let ((focus-node (editor-concept session focus)))
      (loop for rel in (arcs focus-node)
            when (relation-p rel)
              append (loop for other in (arcs rel)
                           unless (eq other focus-node)
                             collect (list :relation-ref (node-ref rel)
                                           :relation (string-downcase
                                                      (string (label (relation-type rel))))
                                           :direction (if (relation-outarc-p rel focus-node)
                                                          :reverse :forward)
                                           :concept-ref (node-ref other)
                                           :concept (format-node other)))))))
