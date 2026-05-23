;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  graph  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defclass graph (basic-node)
  ((head :initarg :head
         :initform nil
         :type (or null graph-node)
         :accessor head
         :documentation "An arbitrary node in the graph for traversal entry")
   ;; concepts referencing this graph as a referent
   (holders :initform (list)
            :accessor holders)))


(defmethod nodes ((graph graph))
  "Compute the list of all nodes by traversing from the head node"
  (when (head graph)
    (collect-nodes (head graph))))

(defmethod nodes ((graph list))
  graph)

(defmethod nodes ((thing (eql nil))) nil)


(defmethod head ((node-list list))
  (assert (every #'graph-node-p node-list))
  (cond ((concept-p (car node-list))
         (car node-list))
        ((concept-p (cadr node-list))
         (cadr node-list))))

(defmethod initialize-instance :after ((graph graph) &key head &allow-other-keys)
  "Set back-pointer when graph is created with a head"
  (when (and head (find head (collect-nodes head)))
    (setf (graph head) graph))
  ;; don't know which context to add to here
  ;;(add-cgraph graph *context*)
  )


(defmethod (setf head) :after (new-head (graph graph))
  "Maintain back-pointer from head node to graph"
  (when new-head
    (setf (graph new-head) graph)))


(defmethod print-object ((object graph) stream)
  (cond (*always-format-nodes*
         (let ((text (format-cgraph object)))
           (princ text stream)))
        (t
         (print-unreadable-object (object stream :type t :identity nil)
           (format stream "~a" (flatten-cgraph (format-cgraph object)))))))


(defmethod format-graph ((graph graph))
  (format-cgraph (head graph)))






(defmethod graph-head ((graph graph))
  "Return the most connected concept in the graph, preferring the stored head if tied"
  (let* ((entry-node (head graph))
         (concepts (graph-concepts graph))
         (sorted (sort (copy-list concepts) #'>
                       :key (lambda (node) (length (arcs node))))))
    (cond ((null sorted) entry-node)
          ((concepts-equal entry-node (car sorted))
           entry-node)
          ((and entry-node
                (= (length (arcs entry-node))
                   (length (arcs (car sorted)))))
           entry-node)
          (t (car sorted)))))

(defmethod graph-head ((graph list))
  (assert (every (lambda (x) (typep x 'graph-node)) graph))
  (car graph))


(defmethod graph-head ((node graph-node))
  (graph-head (make-cgraph node)))

;; (defmethod head-node ((node graph-node))
;;   (let ((head-len 0)
;;         head)
;;     (dolist (node (collect-nodes node))
;;       (let ((arcs-len (length (arcs node))))
;;         (when (> arcs-len head-len)
;;           (setf head node
;;                 head-len arcs-len))))
;;     head))



(defmethod format-object ((object graph) &rest keys &key &allow-other-keys)
  ;; Use cgraph-text (no trailing period) — the period belongs only at the outermost level
  (declare (ignore keys))
  (let ((inner (cgraph-text (head object))))
    (cond (*indent-graph-referents*
           (let* ((pad (make-string *graph-referent-indent* :initial-element #\space))
                  (newline-pad (concatenate 'string (string #\newline) pad))
                  ;; Re-indent every line of the nested graph so that wrapped
                  ;; branches inside it line up under their owner's new column,
                  ;; and prepend a newline+pad so the nested graph starts on
                  ;; its own line.
                  (indented (frob-substrings inner (list (string #\newline)) newline-pad)))
             (concatenate 'string newline-pad indented)))
          (t inner))))

;; (defmethod graphs-equal ((graph1 graph) (graph2 graph) &optional debug)
;;   "Compare two graphs for equality by comparing their sorted node representations"
;;   (declare (ignore debug))
;;   (let* ((nodes1 (sort (copy-list (nodes graph1)) #'alpha-lessp :key #'graph-node-key))
;;          (nodes2 (sort (copy-list (nodes graph2)) #'alpha-lessp :key #'graph-node-key))
;;          (keys1 (mapcar #'graph-node-key nodes1))
;;          (keys2 (mapcar #'graph-node-key nodes2)))
;;     (equalp keys1 keys2)))

(defmethod graphs-equal ((graph1 graph) (graph2 graph) &optional debug)
  "Compare two graphs for equality by comparing their sorted node representations"
  (declare (ignore debug))
  (let ((nodes1 (collect-nodes (head graph1)))
        (nodes2 (collect-nodes (head graph2))))
    (graphs-equal nodes1 nodes2)))


(defgeneric make-cgraph (graph &optional context))

;; Utility method to create a graph from a node or list of nodes

(defmethod make-cgraph ((node-list list) &optional (context *context*))
  "Create a graph with the given node as head (or first node if a list)"
  (let* ((head-node (car node-list))
         (graph (make-instance 'graph :head head-node)))
    (add-cgraph graph context)
    graph))

(defmethod make-cgraph ((node graph-node) &optional (context *context*))
  "Create a graph with the given node as head (or first node if a list)"
  (make-cgraph (list node) context))

(defmethod make-cgraph ((text string) &optional (context *context*))
  (make-cgraph (car (parse-cgraph text)) context))

(defmethod make-cgraph ((graph graph) &optional (context *context*))
  (add-cgraph graph context)
  graph)




;; Type predicate for graphs
(defmethod graph-p ((thing graph)) t)
(defmethod graph-p ((thing t)) nil)


;; Graph-specific referent methods
(defmethod graph-p ((referent referent))
  (and (content referent)
       (typep (content referent) 'graph)))


(defmethod graph-content ((referent referent))
  (when (graph-p referent)
    (content referent)))


(defmethod make-referent ((graph graph) &optional concept)
  (let ((referent (make-instance 'referent :content graph)))
    ;; Establish bidirectional link: concept uses this graph as referent
    (when concept
      (pushnew concept (holders graph) :test #'eq))
    referent))


;; Convenience method to create a graph referent from a list of nodes
;; This allows (make-referent (parse-cgraph "[Dog: Fido]"))
(defmethod make-referent ((node-list list) &optional concept)
  "Create a graph referent from a list of graph nodes"
  (when (and node-list
             (every (lambda (node) (typep node 'graph-node)) node-list))
    (let ((graph (make-cgraph node-list)))
      (make-referent graph concept))))

;; Handle case where parse-cgraph returns a single node (the head)
(defmethod make-referent ((node graph-node) &optional concept)
  "Create a graph referent from a graph node"
  (let ((graph (make-cgraph node)))
    (make-referent graph concept)))





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  Property Delegation and Graph Structure Access  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Extract concepts from the graph
(defmethod graph-concepts ((graph graph))
  "Return a list of all concepts in the graph"
  (remove-if-not (lambda (node) (typep node 'concept))
                 (nodes graph)))


(defmethod graph-concepts ((graph list))
  "Return a list of all concepts in the graph"
  (remove-if-not #'concept-p graph))


;; Extract relations from the graph
(defmethod graph-relations ((graph graph))
  "Return a list of all relations in the graph"
  (remove-if-not (lambda (node) (typep node 'relation))
                 (nodes graph)))

;; Find head concepts (concepts that are not targets of any relation)
;; (defmethod zzz-concepts ((graph graph))
;;   "Return concepts that are not targets of relations (potential root nodes)"
;;   (let* ((concepts (graph-concepts graph))
;;          (relations (graph-relations graph))
;;          ;; outarc (car of arcs) = target/destination concept
;;          (target-concepts (loop for rel in relations
;;                                collect (outarc rel))))
;;     (remove-if (lambda (concept)
;;                  (or (null concept)  ; Filter out NIL
;;                      (member concept target-concepts :test #'eq)))
;;                concepts)))

;; Get the primary/head concept if there's a single root
;; (defmethod zzz-concept ((graph graph))
;;   "Return the single head concept if there is exactly one, otherwise nil"
;;   (let ((heads (zzz-concepts graph)))
;;     (when (= (length heads) 1)
;;       (first heads))))

;; Properties delegation - if there's a single head concept, delegate to its properties
(defmethod properties ((graph graph))
  "Extract properties from the graph structure"
  (let ((head (graph-head graph)))
    (when head
      (properties head))))

(defmethod properties ((graph list))
  "Extract properties from the graph structure"
  (let ((head (graph-head graph)))
    (when head
      (properties head))))



;; Concept type delegation - if there's a single head concept, delegate to its type
(defmethod concept-type ((graph graph))
  "Extract the concept type from the graph's head concept"
  (let ((head (graph-head graph)))
    (when head
      (concept-type head))))

;; Get all concepts of a specific type
(defmethod concepts-of-type ((graph graph) concept-type)
  "Return all concepts in the graph of the given type"
  (remove-if-not (lambda (concept)
                   (types-equal (concept-type concept)
                               (get-concept-type concept-type)))
                 (graph-concepts graph)))

;; Count concepts in the graph
(defmethod concept-count ((graph graph))
  "Return the number of concepts in the graph"
  (length (graph-concepts graph)))

;; Count relations in the graph
(defmethod relation-count ((graph graph))
  "Return the number of relations in the graph"
  (length (graph-relations graph)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  Referent-level Graph Access  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Convenience methods for accessing graph structure through referents
(defmethod graph-concepts ((referent referent))
  "Return concepts from a graph referent"
  (when (graph-p referent)
    (graph-concepts (content referent))))

(defmethod graph-relations ((referent referent))
  "Return relations from a graph referent"
  (when (graph-p referent)
    (graph-relations (content referent))))

;; (defmethod zzz-concepts ((referent referent))
;;   "Return head concepts from a graph referent"
;;   (when (graph-p referent)
;;     (zzz-concepts (content referent))))

;; (defmethod zzz-concept ((referent referent))
;;   "Return the head concept from a graph referent"
;;   (when (graph-p referent)
;;     (zzz-concept (content referent))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  Concept-level Graph Access  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Methods for concepts that have graph referents
(defmethod graph-referent ((concept concept))
  "Return the graph object if this concept's referent is a graph"
  (let ((ref (referent concept)))
    (when (and ref (graph-p ref))
      (content ref))))

(defmethod graph-referent-p ((concept concept))
  "Check if this concept has a graph as its referent"
  (not (null (graph-referent concept))))

;; Convenience accessors that work directly on concepts with graph referents
(defmethod referent-concepts ((concept concept))
  "Return concepts from this concept's graph referent"
  (let ((graph (graph-referent concept)))
    (when graph
      (graph-concepts graph))))

(defmethod referent-relations ((concept concept))
  "Return relations from this concept's graph referent"
  (let ((graph (graph-referent concept)))
    (when graph
      (graph-relations graph))))

;; (defmethod referent-zzz-concepts ((concept concept))
;;   "Return head concepts from this concept's graph referent"
;;   (let ((graph (graph-referent concept)))
;;     (when graph
;;       (zzz-concepts graph))))

;; (defmethod referent-zzz-concept ((concept concept))
;;   "Return the head concept from this concept's graph referent"
;;   (let ((graph (graph-referent concept)))
;;     (when graph
;;       (zzz-concept graph))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  Conformity Validation  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod conforms ((graph graph) (concept-type concept-type))
  "Check if the graph conforms to the given concept type restriction"

  (graph-compatible-p concept-type))

;; Convenience methods for symbol and string concept types
(defmethod conforms ((graph graph) (concept-type symbol))
  "Check if the graph conforms to the concept type named by symbol"
  (let ((ctype (get-concept-type concept-type)))
    (when ctype
      (conforms graph ctype))))

(defmethod conforms ((graph graph) (concept-type string))
  "Check if the graph conforms to the concept type named by string"
  (let ((ctype (get-concept-type concept-type)))
    (when ctype
      (conforms graph ctype))))

;;; Graph-to-graph conformity: two graphs conform if they're structurally equal
;;; Isn't this too strict?
;;; maybe use projection?
(defmethod conforms ((graph1 graph) (graph2 graph))
  "Check if two graphs conform to each other (are equal)"
  (graphs-equal graph1 graph2))

;; NIL never conforms to anything - handle gracefully
(defmethod conforms ((obj (eql nil)) concept-type)
  "NIL does not conform to any type"
  nil)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  Bidirectional Linking (Graph <-> Concept)  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; BIDIRECTIONAL LINKING SEMANTICS
;;;
;;; When a graph is used as a referent in a concept, we maintain bidirectional links:
;;;   - Concept -> Referent -> Graph (forward link)
;;;   - Graph -> Concepts (backward link, list of all concepts using this graph)
;;;
;;; This allows:
;;;   1. From a concept, find its graph referent
;;;   2. From a graph, find all concepts that use it
;;;   3. Efficient queries like "which concepts use this graph as a referent?"
;;;
;;; The linking is established in make-referent and maintained automatically
;;; when concepts are created/destroyed.

;; Register a concept as using this graph
(defmethod register-concept ((graph graph) (concept concept))
  "Register that a concept uses this graph as its referent"
  (pushnew concept (holders graph) :test #'eq))

;; Unregister a concept from using this graph
(defmethod unregister-concept ((graph graph) (concept concept))
  "Unregister a concept from using this graph as its referent"
  (setf (holders graph) (remove concept (holders graph) :test #'eq)))




;; Check if a concept is registered with this graph
(defmethod concept-registered-p ((graph graph) (concept concept))
  "Check if a concept is registered as using this graph"
  (member concept (holders graph) :test #'eq))

;; Get all concepts using this graph as a referent
(defmethod referencing-concepts ((graph graph))
  "Return a list of all concepts that use this graph as their referent"
  (holders graph))

;; Count how many concepts use this graph
(defmethod reference-count ((graph graph))
  "Return the number of concepts using this graph as a referent"
  (length (holders graph)))
