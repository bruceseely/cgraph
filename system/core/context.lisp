;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;; include NAME, MEASURE, ...  etc in concept
;;;    instead of explicit graph of concept objects
;;; (defvar *abbreviated-concepts* t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  context  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;; NOTE *context* is declared in definitions.lisp

(defclass context ()
  ((nodes :initform (list)           ; list containing graphs as lists
          :initarg :nodes
          :accessor nodes
          )
   (graphs :initform (list) ; list containing nodes that are head nodes
           :initarg :graphs
           :accessor graphs
           )
   (child-contexts  :initform (list) ; contexts contained by this context
                    :initarg :contexts
                    :accessor child-contexts
                    )
   (parent-context :initform nil
                   :initarg :parent
                   :accessor parent-context
                   )
   ;; Map for efficient graph referent queries
   ;; Maps from graph objects to lists of concepts using them
   (graph-referent-map :initform (list)
                        :accessor graph-referent-map
                        :documentation "association list mapping graphs to concepts")
   (negated :initform nil
            :initarg :negated
            :accessor negated)))


(defmethod make-context (&optional (parent nil) &key negated)
  (let ((new-context (make-instance 'context :negated negated)))
    (when parent
      (setf (parent-context new-context) parent)
      (pushnew new-context (child-contexts parent)))
    new-context))

(defmethod initialize-context ((context context) &optional (parent nil parent-supplied))
  ;; (setf (child-contexts context) (list))
  ;; (when parent-supplied
  ;;   (setf (parent-context context) parent))
  (setf (graphs context) (list))
  (setf (nodes context) (list)))

(defmethod initialize-context ((context (eql nil)) &optional (parent nil)))


(defmethod initialize-instance :after ((context context) &key &allow-other-keys)
  (initialize-context context))


;; (defmethod all-concepts ((context context))
;;   (let ((graph-concepts (list)))
;;     (dolist (graph (graphs context))
;;       (push (collect-concepts (car graph)) graph-concepts))
;;     (let ((concepts (apply #'append graph-concepts)))
;;       (remove-duplicates concepts))))


;; (defmethod all-concepts ((context (eql nil)))
;;   nil)

(define-condition cached-concept-lookup-failed (error)
  ((ctype :initarg :ctype :reader ctype)
   (msg :initarg :msg :reader msg)))


;;; cache all concepts for co-reference linking
(defmethod cache-concept ((concept concept)  &key (context *context*))
  (when context
    (setf (context concept) context)
    (pushnew concept (nodes context) :test #'concepts-equal)
    ;; If concept has a graph referent, add to map
    (let ((graph (graph-referent concept)))
      (when graph
        (map-add-graph-concept graph concept context))))
  concept)


(defmethod add-concept ((concept concept) &optional (context *context*))
  (cache-concept concept :context context))


(defmethod decache-concept ((concept concept))
  ;;(assert (typep concept 'concept))
  (let* ((context (or (context concept) *context*)))
    ;; If concept has a graph referent, remove from map and unregister from graph
    (let ((graph (graph-referent concept)))
      (when graph
        (map-remove-graph-concept graph concept context)
        (unregister-concept graph concept)))
    ;; Remove from nodes list
    (setf (nodes context) (remove concept (nodes context) :test #'concepts-equal))))


(defmethod retrieve-concepts-having-properties (properties &optional (context *context*))
  (remove-if-not (lambda (concept)
                   (let* ((referent (referent concept))
                          (props (properties referent)))
                     (properties-equal props properties)))
                 (nodes context)))

(defmethod retrieve-concepts-having-individual (individual &optional (context *context*))
  (remove-if-not (lambda (concept)
                   (let* ((referent (referent concept))
                          (object (when referent
                                    (content referent))))
                     (and (individual-p object)
                          (individuals-equal object individual))))
                 (nodes context)))

(defmethod retrieve-concepts-having-id (individual-id &optional (context *context*))
  (let ((individual (find-individual-with-id individual-id)))
    (retrieve-concepts-having-individual individual context)))



(defmethod retrieve-concept (concept-type (individual individual) &key (context *context*))
  (let ((candidates (retrieve-concepts-having-individual individual context))
        (ctype (get-concept-type concept-type)))
    ;; (remove-if-not (lambda (concept)
    ;;                  (types-equal (concept-type concept) ctype))
    ;;                candidates)
    (find ctype candidates :key #'concept-type)))

(defmethod retrieve-concept (concept-type (id number) &key (context *context*))
  (let ((candidates (retrieve-concepts-having-id id context))
        (ctype (get-concept-type concept-type)))
    ;; (remove-if-not (lambda (concept)
    ;;                  (types-equal (concept-type concept) ctype))
    ;;                candidates)
    (find ctype candidates :key #'concept-type)))

(defmethod retrieve-concept (concept-type (properties list) &key (context *context*))
  (let ((candidates (retrieve-concepts-having-properties properties context))
        (ctype (get-concept-type concept-type)))
    ;; (remove-if-not (lambda (concept)
    ;;                  (types-equal (concept-type concept) ctype))
    ;;                candidates)
    (find ctype candidates :key #'concept-type)))



(defmethod remove-concept ((concept concept) &optional (context *context*))
  (decache-concept concept))

;;; concept-type is added to the propertis list
(defmethod remove-concept ((properties list) &optional (context *context*))
  (let* ((ctype (cadr (assoc :type properties)))
         (concept (retrieve-concept ctype properties)))
    (when concept
      (remove-concept concept context))))


(defun graph-node-key (node)
  (string-trim " "
               (cond ((eq (type-of node) 'concept)
                      (format nil "concept-~a-~a" (node-type node)  (format-referent node)))
                     ((eq (type-of node) 'relation)
                      (format nil "relation-~a" (node-type node))))))

(defmethod graph-present-p ((graph graph) &optional (context *context*))
  (let* ((graph-nodes (sort (nodes graph) #'alpha-lessp :key #'graph-node-key))
         (graph-node-keys (mapcar #'graph-node-key graph-nodes))
         (sorted-context-graphs
           (mapcar (lambda (graph)
                     (sort (nodes graph) #'alpha-lessp :key #'graph-node-key))
                   (graphs context)))
         (found (find graph-node-keys sorted-context-graphs
                      :key (lambda (list) (mapcar #'graph-node-key list))
                      :test #'equalp)))
    (not (null found))))

(defmethod graph-present-p ((concept concept) &optional (context *context*))
  (let ((graph (make-graph concept)))
    (when graph
      (graph-present-p graph context))))

(defmethod graph-present-p ((graph-string string) &optional (context *context*))
  (let ((graph (make-graph graph-string)))
    (when graph
      (graph-present-p graph context))))



(defmethod remove-cgraph ((graph graph) &optional (context *context*))
  (when (graphs context)
    (when (find graph (graphs context) :test #'graphs-equal)
    (setf (graphs context) (remove graph (graphs context) :test #'graphs-equal)))))


(defmethod remove-cgraph ((graph string ) &optional (context *context*))
  (remove-cgraph (make-cgraph graph context)))



;;; intentionally defined for only graph objects
(defmethod add-cgraph ((graph graph) &optional (context *context*))
  (assert (graph-p graph))
  (unless (graph-present-p graph context)
    (cond ((null (graphs context))
           (setf (graphs context) (list graph)))
          (t
           (setf (cdr (last (graphs context))) (list graph))))))

(defmethod add-cgraph ((thing t) &optional context)
  nil)


(defmethod add-cgraphs ((graphs list) &optional (context *context*))
  (assert (every #'graph-p graphs))
  (mapcar (lambda (g) (add-cgraph g context)) graphs)
  t)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  Graph Referent Tracking  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Methods to track and query concepts that use graphs as referents

;; Find all concepts with graph referents in this context
(defmethod concepts-with-graph-referents (&optional (context *context*))
  "Return all concepts in the context that have graph referents"
  (remove-if-not (lambda (concept)
                   (graph-referent-p concept))
                 (nodes context)))

;; Find concepts that use a specific graph as their referent
(defmethod find-concepts-using-graph ((graph graph) &optional (context *context*))
  "Find all concepts in the context that use this specific graph as their referent (mapped)"
  ;; Use the map for O(1) lookup instead of O(n) linear search
  (map-lookup-concepts graph context))

;; Count concepts with graph referents
(defmethod count-concepts-with-graph-referents (&optional (context *context*))
  "Count how many concepts in the context have graph referents"
  (length (concepts-with-graph-referents context)))

;; Get all unique graphs used as referents in this context
(defmethod all-graph-referents (&optional (context *context*))
  "Return a list of all unique graph objects used as referents in this context (mapped)"
  ;; Use the map for O(1) lookup instead of building list from concepts
  (map-all-graphs context))

;; Report on graph referent usage
(defmethod graph-referent-report (&optional (context *context*) (stream *standard-output*))
  "Print a report of graph referent usage in the context"
  (let ((concepts (concepts-with-graph-referents context))
        (unique-graphs (all-graph-referents context)))
    (format stream "~%Graph Referent Report for Context:")
    (format stream "~%  Total concepts with graph referents: ~d" (length concepts))
    (format stream "~%  Unique graphs used as referents: ~d" (length unique-graphs))
    (when concepts
      (format stream "~%~%Concepts with graph referents:")
      (dolist (concept concepts)
        (format stream "~%  ~a" (format-concept concept))
        (let ((graph (graph-referent concept)))
          (when graph
            (format stream "~%    Graph: ~d concepts, ~d relations"
                    (concept-count graph) (relation-count graph))))))
    (terpri stream)
    t))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  Graph Referent Map Maintenance  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; GRAPH REFERENT MAP
;;;
;;; The graph-referent-map is an association list that maps graph objects
;;; to lists of concepts that use them as referents. This provides O(1) lookup
;;; for common queries instead of O(n) linear searches.
;;;
;;; Structure: ((graph1 . (concept1 concept2)) (graph2 . (concept3)) ...)
;;;
;;; The map is maintained automatically by cache-concept and decache-concept.

;; Add a graph-concept mapping to the map
(defmethod map-add-graph-concept ((graph graph) (concept concept) &optional (context *context*))
  "Add a concept to the map for this graph"
  (let* ((map (graph-referent-map context))
         (entry (assoc graph map :test #'graphs-equal)))
    (if entry
        ;; Graph already in map, add concept to its list
        (pushnew concept (cdr entry) :test #'eq)
        ;; New graph, create entry
        (push (cons graph (list concept)) (graph-referent-map context)))))

;; Remove a graph-concept mapping from the map
(defmethod map-remove-graph-concept ((graph graph) (concept concept) &optional (context *context*))
  "Remove a concept from the map for this graph"
  (let* ((map (graph-referent-map context))
         (entry (assoc graph map :test #'graphs-equal)))
    (when entry
      ;; Remove concept from the list
      (setf (cdr entry) (remove concept (cdr entry) :test #'eq))
      ;; If no more concepts use this graph, remove the entry
      (when (null (cdr entry))
        (setf (graph-referent-map context)
              (remove graph (graph-referent-map context)
                      :key #'car :test #'graphs-equal))))))

;; Lookup concepts by graph using the map
(defmethod map-lookup-concepts ((graph graph) &optional (context *context*))
  "Efficiently lookup which concepts use this graph (O(1) with map)"
  (let* ((map (graph-referent-map context))
         (entry (assoc graph map :test #'graphs-equal)))
    (when entry
      (cdr entry))))

;; Get all mapped graphs
(defmethod map-all-graphs (&optional (context *context*))
  "Return all graphs in the map"
  (mapcar #'car (graph-referent-map context)))

;; Get count of mapped graphs
(defmethod map-graph-count (&optional (context *context*))
  "Return the number of unique graphs in the map"
  (length (graph-referent-map context)))

;; Clear the entire graph referent map
(defmethod clear-graph-referent-map (&optional (context *context*))
  "Clear the graph referent map"
  (setf (graph-referent-map context) (list)))


(defmethod clear-concept-cache (&optional (context *context*))
  (assert (typep context 'context))
  (setf (nodes context) (list))
  ;; Also clear the graph referent map
  (clear-graph-referent-map context))


(defun cached-concepts-report (&optional (context *context*) (stream *standard-output*))
  (when context
    (let ((concept-list (nodes context)))
      (when concept-list
        (format stream "~&Cached Concepts Report:~%")
        (format stream "~&Total concepts: ~d~%" (length concept-list))
        (dolist (concept concept-list)
          (format stream "~&  ~a~%" (format-concept concept))))
      t)))
