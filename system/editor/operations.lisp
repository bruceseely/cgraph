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

(defun editor-reachable (start &optional blocked)
  "Every node reachable from START, ignoring arc direction.

   BLOCKED, when given, is a node the walk refuses to enter. That is how a
   removal's effect is measured without performing it: block the relation and
   whatever drops out of the result is what the removal would drop."
  (let ((seen (make-hash-table :test 'eq))
        (stack (list start)))
    (loop while stack
          for node = (pop stack)
          unless (gethash node seen)
            do (setf (gethash node seen) t)
               (dolist (n (arcs node))
                 (unless (or (gethash n seen) (eq n blocked))
                   (push n stack))))
    seen))

(defun editor-prune-count (focus relation)
  "How many CONCEPTS would vanish if RELATION were removed from FOCUS.

   Measured the way the removal itself decides -- reachability from the focus
   -- and not by counting the far concept's arcs, which gets coreference
   exactly backwards: a node standing on two paths survives however many arcs
   it has, and a node standing on one takes its whole branch with it.

   Relations are not counted. The number is for a reader looking at the display
   pane, and what a reader there loses is concepts.

   Nodes already unreachable from FOCUS are outside the comparison entirely, so
   pre-existing garbage cannot inflate the count."
  (let ((after (editor-reachable focus relation))
        (dropped 0))
    (maphash (lambda (node present)
               (declare (ignore present))
               (when (and (typep node 'concept)
                          (not (gethash node after)))
                 (incf dropped)))
             (editor-reachable focus))
    dropped))

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
   first concept-type click makes a concept that becomes the focus.

   REFUSES a graph that already has a head. It used to fall through the COND and
   return the concept anyway -- unattached, since there is nothing here to
   attach it to -- and the page would then set its focus to a NODE-REF the
   working graph did not contain. Every subsequent request answered `no node N
   in this graph', unclearably, because it was true again each time; only a
   reload recovered. A concept with nowhere to go is not something to hand back
   quietly."
  (with-cg-thread-bindings
    (let ((working (session-working session)))
      (when (and working (head working))
        (editor-error "this graph already has concepts — click one in the graph ~
                       to choose the focus, then pick a relation"))
      (let ((concept (editor-make-concept type-label)))
        (if (null working)
            (setf (session-working session) (make-instance 'graph :head concept))
            (setf (head working) concept))
        concept))))

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

;;; --- Replace ---------------------------------------------------------------

(defun editor-replace-target (session &key focus relation target target-type)
  "Put a different concept on the far end of an arc the FOCUS already has.

   RELATION is the node-ref of the arc to change; the relation TYPE and the
   direction are kept, since what is being replaced is the concept, not the
   claim being made about it. The other end is a node-ref (TARGET) or a type
   label (TARGET-TYPE), the same two shapes EDITOR-ADD-ARC takes.

   This is one operation rather than a remove and an add for reasons that are
   not cosmetic:

     - remove-then-add has a wrong order. Add first and the focus briefly has
       two arcs of the same relation, which for a relation like DEST is not a
       graph anyone meant.
     - a target the lattice refuses must leave the graph untouched. Removing
       first and discovering the refusal second costs you the old concept AND
       gives you nothing in its place.

   So the replacement is built FIRST and the old arc comes out only once the
   new one stands. That ordering also gets the prune right for free: the new
   concept is already reachable when EDITOR-REMOVE-ARC decides what the old
   arc was holding up.

   Retyping the concept in place would be the other way to read this request,
   and it is the wrong one: a concept may be the far end of several arcs, so
   changing its type edits every path that reaches it. Replacing is local to
   the arc you are standing on."
  (with-cg-thread-bindings
    (let* ((focus-node (editor-concept session focus))
           (old-rel (editor-relation-node session relation)))
      (unless (member old-rel (arcs focus-node) :test #'eq)
        (editor-error "relation ~a is not attached to concept ~a"
                      (node-ref old-rel) (node-ref focus-node)))
      (let ((label (string-downcase (string (label (relation-type old-rel)))))
            (direction (if (relation-outarc-p old-rel focus-node) :reverse :forward))
            (before (copy-list (arcs focus-node))))
        (multiple-value-bind (new-rel new-target)
            (handler-case
                (editor-add-arc session :focus focus
                                        :relation label
                                        :target target
                                        :target-type target-type
                                        :direction direction)
              (error (condition)
                ;; CONNECT type-checks in the middle of building the arc, so a
                ;; refusal can leave a relation already joined to the focus.
                ;; Whatever appeared since BEFORE is that wreckage, and it goes
                ;; back out before the error is passed on -- the promise this
                ;; function makes is that a failed replace changes nothing.
                (dolist (node (set-difference (arcs focus-node) before :test #'eq))
                  (when (relation-p node)
                    (dolist (other (copy-list (arcs node)))
                      (ignore-errors (remove-arc node other)))
                    (setf (arcs node) nil)))
                (setf (arcs focus-node) before)
                (editor-error "cannot replace: ~a" condition)))
          (editor-remove-arc session :focus focus :relation (node-ref old-rel))
          (values new-rel new-target))))))

;;; --- What hangs off the focus ----------------------------------------------

(defun editor-focus-arcs (session focus)
  "The focus's neighbourhood, as the display pane shows it: one relation and
   concept per entry, with the direction the arc runs.

   Returns a list of plists (:relation-ref :relation :direction :concept-ref
   :concept :concept-type :prune-count), where :direction is :FORWARD when the
   focus is the relation's source.

   :PRUNE-COUNT is what removing that line would cost, because the pane shows
   one hop and the removal acts on every hop behind it. Without the number the
   two cases are indistinguishable on screen: an arc to a leaf and an arc to a
   node holding a whole branch look alike, and so does an arc whose far end is
   coreferent and survives."
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
                                           :concept (format-node other)
                                           ;; The bare type, beside the
                                           ;; formatted node: canonical
                                           ;; conformance is a question about
                                           ;; the type alone, and re-deriving
                                           ;; it from "[PERSON: Sue]" would
                                           ;; mean parsing display text.
                                           :concept-type (string-downcase
                                                          (string (label (concept-type other))))
                                           :prune-count (editor-prune-count
                                                         focus-node rel)))))))
