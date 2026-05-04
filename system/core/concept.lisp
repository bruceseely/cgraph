;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  concept  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;


(defclass concept (graph-node)
  ((concept-type :initarg :concept-type
                 :accessor concept-type)
   (referent :initarg :referent
             :accessor referent
             :initform nil)
   (context :initform *context*
            :initarg :context
            :accessor context)
   ;; list of other contexts that have thos concept
   (coreference :initform (list)
                :accessor coreference)
   ;; coref label when this is a ?x bound reference (not the defining node)
   (coref-bound-label :initform nil
                      :accessor coref-bound-label)
   ;; Sowa quantifier on the referent: :universal ('@every'), :existential
   ;; ('@some'), or NIL. Lives on the concept rather than the referent
   ;; because '@every' typically has no individual at all.
   (quantifier :initform nil
               :initarg :quantifier
               :accessor concept-quantifier)
   (negated :initform nil
            :initarg :negated
            :accessor negated)))



;; (defmethod print-object ((node concept) stream)
;;   (princ (format-concept node) stream))

(defmethod print-object ((node concept) stream)
  ;;(format t "~&*include-node-ref*: ~s~%"  *include-node-ref*)

  (let ((*package* (find-package :conceptual-graphs)))
  (cond (*always-format-nodes*
         (princ (format-concept node) stream))
        (*include-node-ref*
         (print-unreadable-object (node stream :type t)
           (format stream "~a;~d"
                   (label (concept-type node))
                   (node-ref node))))
        (t
         (print-unreadable-object (node stream :type t)
           (format stream "~a" (label (concept-type node))))))))



(defmethod concept-type ((arg t))
  nil)

(defmethod id ((concept concept))
  (let ((referent (referent concept)))
    (when (typep referent 'individual)
      (id referent))))

(defmethod properties ((concept concept))
  (let ((referent (referent concept)))
    (when referent
      (properties referent))))


(defmethod types-equal ((concept1 concept) (concept2 concept))
  (types-equal (concept-type concept1) (concept-type concept2)))


(defmethod maximal-common-subtype ((concept1 concept) (concept2 concept))
  (maximal-common-subtype (concept-type concept1) (concept-type concept2)))

(defmethod minimal-common-supertype ((concept1 concept) (concept2 concept))
  (minimal-common-supertype (concept-type concept1) (concept-type concept2)))



(defmethod common-subtype ((node1 concept) (node2 concept))
  (common-subtype (concept-type node1) (concept-type node2)))



(defmethod conforms ((concept concept) (concept-type concept-type))
  (and (conforms (concept-type concept) concept-type)
       (or (null (referent concept))
           (conforms (referent concept) concept-type))))

(defmethod concept-conformity ((concept concept) (ignore (eql nil)))
  (conforms (referent concept) (concept-type concept)))


(defmethod variable-text ((concept concept))
  (let ((var (node-variable concept)))
    (cond (var (format nil "*~(~a~)"  var))
          (t ""))))

;; Default coref-text method - real implementation in coreference.lisp
;; This stub ensures format-referent compiles; coreference.lisp replaces it
(defgeneric coref-text (concept)
  (:documentation "Return the co-reference label text for a concept"))

;; (defmethod coref-text ((concept concept))
;;   "")


(defmethod id-text ((concept concept))
  (let* ((referent (referent concept))
         (content (content referent))
         ;;(id (id (content referent)))
         )
    (cond ((not (typep content 'individual)) "")
          ((eql (id content) 't) "#")
          ((not (or (properties content)
                    (unique-individual-p concept)))
           (format nil "#~d" (id content)))
          (t ""))))


(defmethod format-referent (node &key &allow-other-keys)
  (format-node node))


;;; *include-node-ref*
(defmethod format-referent ((concept concept) &key &allow-other-keys)
  (let* ((separator (if *concise* "" " "))
         (variable-text (variable-text concept))
         (var-string (if (plusp (length variable-text))
                         (format nil "~a~a" separator variable-text)
                         ""))
         (coref-text (coref-text concept))
         (coref-string (if (plusp (length coref-text))
                           (format nil "~a~a" separator coref-text)
                           ""))
         (id-text (id-text concept))
         (id-string (if id-text (format nil "~a~a" separator id-text)))
         (referent (referent concept))
         (ref-string (cond ((null referent) "")
                           (t (format-referent referent)))))

    (when *print-without-variables*
      (setf var-string ""))
    (format nil "~a~a~a" ref-string var-string coref-string)))



(defmethod referent-name ((concept concept))
  (name-property (referent concept)))


(defmethod referent-type ((concept concept))
  (let ((referent (referent concept)))
    (cond ((null referent) nil)
          (t (concept-type referent)))))


;;; annotation accessors
(defmethod name-spec ((annotations list))
  (getf annotations :name))

(defmethod set-spec ((annotations list))
  (getf annotations :set))

(defmethod measure-spec ((annotations list))
  (getf annotations :measure))

(defmethod referent-spec ((annotations list))
  (getf annotations :referent))

;; (defmethod graph-spec ((annotations list))
;;   (getf annotations :graph))



;;; concept accessors
(defmethod name ((concept concept))
  (name-spec (properties concept)))

(defmethod set-spec ((concept concept))
  (set-spec (properties concept)))

;; (defmethod graph-spec ((concept concept))
;;   (graph-spec (properties concept)))

;; (defmethod graph ((concept concept))
;;   (let ((text (graph-spec concept)))
;;     (when text
;;       (parse-cgraph text))))

(defmethod measure ((concept concept))
  (let ((measure-spec (measure-spec (properties concept))))
    (when measure-spec
      (string-left-trim
       "@" measure-spec))))


(defmethod generic-p ((concept concept))
  (null (referent concept)))

;; (defmethod individual-p ((concept concept))
;;   (let ((referent (referent concept)))
;;     (or (not (equal referent ""))
;;         (null referent))))

(defmethod describe-concept ((concept concept) &optional (stream *standard-output*))
  (let ((links (links concept)))
    (format stream "-- Concept ~a -------" ;;(format-concept concept)
            (princ-to-string concept)
            )
    (format stream "~%concept type:~15t~a" (concept-type concept))
    (if (properties concept)
        (format stream "~%properties:~15t~a" (properties concept))
        (format stream "~%properties:~15t()"))
    (format stream "~%context:       ~a" (context concept))
    (format stream "~%links: " )
    (cond ((null links) (format stream "~15tnone"))
          ((= (length links) 1)
           (format stream "~15t~a" (car links) ))
          (t (format stream "~15t~a" (car links))
             (dolist (link (cdr links))
               (format stream "~&~15t~a" link))))))


(defun remove-plist-properties (plist &rest properties)
  (dolist (prop properties)
    (remf plist prop))
  plist)



(defmethod format-concept ((node concept) &key &allow-other-keys)
  (let* ((separator (if *concise* "" " "))
         (concept-type (concept-type node))
         ;;(refstr (format nil "~a~a" separator (format-referent node)))
         (refstr (string-trim " " (format-referent node)))
         (ref-p (plusp (length refstr)))
         (node-ref (node-ref node))
         (node-ref-text (format nil "~:[~; +~d~]"  *always-show-node-ref* node-ref))
         (ref-text (if ref-p
                       (format nil ":~a~a~a~a"  separator refstr separator node-ref-text)
                       node-ref-text)))

    (format nil "[~a~a]" (princ-to-string (label concept-type)) (string-right-trim " " ref-text))))

(defmethod format-concept ((node (eql nil)) &key &allow-other-keys)
  "")

;;; include the node-ref number when in debug mode
(defmethod format-concept :around ((node concept) &key &allow-other-keys)
  (let* ((ref (if *include-node-ref* (node-ref node) nil))
         (marked (if (and (marked node) *debug-mode*) marked-string nil))
         (neg (if (negated node) "~" ""))
         (raw (call-next-method))
         (node-text (let* ((s (if (and (plusp (length raw)) (char= (char raw 0) #\[))
                                  (subseq raw 1) raw))
                           (s (if (and (plusp (length s)) (char= (char s (1- (length s))) #\]))
                                  (subseq s 0 (1- (length s))) s)))
                      s)))
    (format nil "~a[~@[~a~]~a~@[+~a~]]" neg marked node-text ref)))


(defmethod format-node ((node concept) &rest keys &key &allow-other-keys)
  (apply #'format-concept node keys))


(defmethod initialize-instance :after ((concept concept) &key)
  (when (referent concept)
    (setf (concept (referent concept)) concept)
    ;; If referent is a graph, register the bidirectional link
    (let ((graph (graph-referent concept)))
      (when graph
        (register-concept graph concept))))
  (cache-concept concept))



(defgeneric make-concept (type referent &key &allow-other-keys))

(defmethod make-concept ((ctype concept-type) (referent (eql nil)) &key (context *context*) &allow-other-keys)
  (let ((*context* context))
    (make-instance 'concept :concept-type ctype
                            :referent nil
                            :context *context*)))

(defmethod make-concept ((ctype concept-type) (referent referent) &key (context *context*) &allow-other-keys)
  (let ((*context* context))
    (make-instance 'concept :concept-type ctype
                            :referent referent
                            :context *context*)))


(defmethod make-concept ((ctype concept-type) (individual individual) &key (context *context*) &allow-other-keys)
  (let ((referent (make-referent individual)))
    (when referent
      (make-concept ctype referent :context context))))


(defmethod make-concept ((ctype concept-type) (property-list list) &key (context *context*)  &allow-other-keys)
  (let* ((props (sans-prop property-list :id :variable))
         (supplied-id (when property-list (getf property-list :id)))
         (individual (or (get-individual ctype :properties props :id supplied-id)
                         (get-individual ctype :properties props)))
         (individual-id (id individual)))


    (cond (individual
           ;;(format t "~&supplied-id2: ~s~%"  supplied-id)
           (make-concept ctype individual :context context))
          (supplied-id
           (let* ((individual (make-individual ctype props :id supplied-id))
                  (referent (when individual (make-referent individual))))
             (cond ((null referent)
                    (make-concept ctype nil :context context)))))
          ((null supplied-id)
           (let* ((individual (make-individual ctype props :id (next-individual-number)))
                  (referent (when individual (make-referent individual))))
             (cond ((null referent)
                    (make-concept ctype nil :context context))))))))



(defmethod make-concept ((type symbol) referent &key (context *context*) &allow-other-keys)
  (let ((ctype (get-concept-type type)))
    (make-concept ctype referent :context context)))

;; (defmethod :around make-concept (type referent &key (context *context*) &allow-other-keys)
;;   (let* ((concept (call-next-method)))
;;     ;; (when concept
;;     ;;   (let ((ref-object (referent concept)))
;;     ;;     ;; (when ref-object
;;     ;;     ;;   (setf (concept ref-object) concept))
;;     ;;     ;;(cache-concept concept :context context)
;;     ;;     ))
;;     concept))s



(defun testx (a b)
  (typep b a))

(defun collect-in-tree (item tree &key (test #'testx))
  (let ((found (list)))
    (labels ((find-item-in-tree (tree)
               (cond ((funcall test item tree)
                      (push tree found)
                      ;;(return-from find-in-tree tree)
                      )
                     ((consp tree)
                      (find-item-in-tree (car tree))
                      (find-item-in-tree (cdr tree))))))
      (find-item-in-tree tree))
    found))


;;; want to be able to ask this in merge-concepts()
;;; (defmethod conforms ((concept-type concept-type) (annotations list)))


;; (defmethod copy-concept ((concept concept))
;;   (let* ((type (concept-type concept))
;;          (referent (referent concept))
;;          (context (context concept))
;;          (new-concept (make-concept type referent :context context)))
;;     (push (list concept new-concept) *copy-map*)
;;     new-concept))

(defmethod copy-node ((concept concept))
  (copy-concept concept))



(defmethod is-type ((concept concept) (concept-type concept-type))
    (not (null (nodes-equal (concept-type concept) concept-type))))


(defmethod is-type ((concept concept) (type symbol))
  (let ((concept-type (handler-case (get-concept-type type)
                        (concept-type-lookup-failed () nil))))
    (is-type concept concept-type)))


(defmethod inarcs ((con concept))
  (when (arcs con)
    (remove-if-not (lambda (rel)
                     (equal (outarc rel) con))
                   (arcs con))))

(defmethod outarcs ((con concept))
  (when (arcs con)
    (remove-if (lambda (rel)
                 (equal (outarc rel) con))
               (arcs con))))


(defmethod concept-p ((concept concept))
  t)

(defmethod concept-p ((thing t))
  nil)


;;; features id the properties list + optionally :id & :variable
(defgeneric get-concept (concept-type properties &key id context))

(defmethod get-concept ((concept-type concept-type) (properties list) &key (id nil) (context *context*))
  ;; Concepts are graph-specific nodes - don't reuse across graphs.
  ;; Within a single graph parse, concepts referring to the same individual should be
  ;; the same node. Use find-local with individual ID for coreference detection.
  ;; Coreference to parent contexts is handled via the coreference slot.
  (let* ((concept
           (cond
             ;; Explicit ID provided: check for coreference in current graph
             (id
              (or (find-local concept-type id properties)
                  (let* ((individual (or (get-individual concept-type :id id)
                                         (when *allow-dynamic-individual-creation*
                                           (make-individual concept-type properties :id id))))
                         (referent individual))
                    (when referent
                      (make-concept concept-type referent)))))

             ;; Generic concept (no properties) - always create new
             ((null properties)
              (make-concept concept-type nil))

             ;; Concept with properties - look up individual and check for coreference
             (t
              (let* ((individuals (get-individuals concept-type properties))
                     (individual (car individuals))
                     (individual-id (when individual (id individual))))
                (cond
                  ;; Found individual with ID - check for existing concept in current graph
                  ((and individual-id (find-local concept-type individual-id properties)))

                  ;; Found individual but not yet in graph - create new concept
                  (individual
                   (make-concept concept-type individual))

                  ;; No individual found - create dynamically if allowed
                  (*allow-dynamic-individual-creation*
                   (let* ((new-individual (make-individual concept-type properties))
                          (referent new-individual))
                     (when referent
                       (make-concept concept-type referent))))))))))

    (when concept
      (pushnew concept *concepts-in-graph* :test #'concepts-equal))
    concept))


(defmethod get-concept ((type-label symbol) (properties-list list) &key id (context *context*))
  (let ((ctype (get-concept-type type-label)))
        (if ctype
          (get-concept ctype properties-list :id id :context context)
          (warn "Concept-type ~a is not defined" type-label))))

(defmethod get-concept ((type-label symbol) (properties string) &key id (context *context*))
  (let ((properties-list (parse-properties properties)))
    (get-concept type-label properties-list :id id :context context)))

(defmethod get-concept (arg1 arg2 &key id (context *context*))
  (declare (ignore arg1 arg2))
  nil)



(defmethod concept-cache-key (type (properties list))
  (let ((ctype (get-concept-type type)))
    (when ctype
      (list ctype properties))))

(defmethod concept-cache-key ((type concept-type) (referent-text string))
  (let ((properties (parse-properties referent-text)))
    (when properties
      (concept-cache-key type properties))))

;;; (concept-cache-key-for-concept (parse-cgraph "[dog:Spot]"))
(defmethod concept-cache-key-for-concept ((concept concept))
  (let* ((*concise* nil)
         (ctype (concept-type concept))
         (properties (properties (referent concept))))
    (concept-cache-key ctype properties)))


;; (progn
;;       (untrace)
;;       (let* ((ctype (get-concept-type 'dog))
;;              (individual (make-individual ctype '(:name "Fido")))
;;              (referent (make-referent individual))
;;              (concept (make-concept ctype referent))
;;              )
;;         (format t "~&ctype: ~s~%"  ctype)           ; debug
;;         (format t "~&individual: ~s~%"  individual) ; debug
;;         ;;(format t "~&referent: ~s~%"  referent)   ; debug
;;         ;;(make-referent individual)
;;         (print (format-referent referent))
;;         (format-concept concept)
;;         ))



(defmethod concept-variable ((concept concept))
  (node-variable concept))

(defmethod types-eq ((node1 concept) (node2 concept))
  (nodes-eq (concept-type node1) (concept-type node2)))

(defmethod conforms ((concept concept) (individual individual))
  (and (conforms individual (concept-type concept))
       (conforms individual (content (referent concept)))))

(defmethod conforms ((concept concept) (property-list list))
  (and (referent concept)
       (or (find :name property-list)
           (find :measure property-list))))


;;; The id may not be included in the displayed graph
;;; but the concept still has one
;; (defmethod find-local (concept-type id (properties list))
;;   (dolist (node *concepts-in-graph*)
;;     (when  (or (and id (id node) (= (id node) id))
;;                (and
;;                 ;;(not (generic-p node)) ; generics should not be on the list
;;                 (nodes-eq (concept-type node) (get-concept-type concept-type))
;;                 (or
;;                  (and (null properties) (null (properties node)))
;;                  (equalp (sort-properties (properties node)) (sort-properties properties)))))
;;       ;; what to do with id??
;;       (return node))))


(defmethod find-local (concept-type id (properties list))
  ;;(format t "~&*concepts-in-graph*: ~s~%"  *concepts-in-graph*)
  (dolist (node *concepts-in-graph*)
    ;; (format t "~&(properties node): ~s~%"  (properties node))
    ;; (format t "~&(and id (eql id (id node))): ~s~%"  (and id (eql id (id node))))   ; debug
    ;; (format t "~&(null id): ~s~%"  (null id))   ; debug
    ;; (format t "~&(types-equal (get-concept-type concept-type)
    ;;                          (concept-type node)): ~s~%"  (types-equal (get-concept-type concept-type)
    ;;                          (concept-type node)))   ; debug
    ;; (format t "~&(equalp (sort-properties (properties node))
    ;;                     (sort-properties properties)): ~s~%"  (equalp (sort-properties (properties node))
    ;;                     (sort-properties properties)))
                                        ; debug
    ;; (format t "~&(and (null id)
    ;;             (types-equal (get-concept-type concept-type)
    ;;                          (concept-type node))
    ;;             (equalp (sort-properties (properties node))
    ;;                     (sort-properties properties))): ~s~%"  (and (null id)
    ;;             (types-equal (get-concept-type concept-type)
    ;;                          (concept-type node))
    ;;             (equalp (sort-properties (properties node))
    ;;                     (sort-properties properties))))
                                        ; debug
    ;; (format t "~&node: ~s~%"  node)
    ;; (format t "~&(properties node): ~s~%"  (properties node))
    ;; (format t "~&properties: ~s~%"  properties)
    (cond ((and id (eql id (id node))
                (types-equal (get-concept-type concept-type)
                             (concept-type node)))
           ;;(format t "~&>> first: ~a" node)
           (return node))
          ((and (null id)
                (types-equal (get-concept-type concept-type)
                             (concept-type node))
                (equalp (sort-properties (properties node))
                        (sort-properties properties)))
           ;;(format t "~&>> second: ~a" node)
           (return node)))))


(defmethod concepts-equal ((concept1 concept) ( concept2 concept))
  (and
   (types-equal concept1 concept2)
   (referents-equal (referent concept1) (referent concept2))))

(defmethod referents-equal ((concept1 concept) (concept2 concept))
  (referents-equal (referent concept1) (referent concept2)))


(defmethod concepts-equal ((concept1 (eql 'nil)) ( concept2 (eql 'nil))) t)
