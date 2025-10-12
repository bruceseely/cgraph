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
                :accessor coreference)))



;; (defmethod print-object ((node concept) stream)
;;   (princ (format-concept node) stream))

(defmethod print-object ((node concept) stream)
  (cond (*always-format-nodes*
         (princ (format-concept node) stream))
        (t
         (print-unreadable-object (node stream :type t)
           (format stream "~a;~d"
                   (label (concept-type node))
                   (node-ref node))))))


(defmethod concept-type ((arg t))
  nil)

(defmethod id ((concept concept))
  (let ((referent (referent concept)))
    (when (typep referent 'individual)
      (id referent))))

(defmethod properties ((concept concept))
  (let ((referent (referent concept)))
    (when (typep (content referent) 'individual)
      (properties (content referent)))))


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
       (conforms (referent concept) concept-type)))

(defmethod concept-conformity ((concept concept) (ignore (eql nil)))
  (conforms (referent concept) (concept-type concept)))


(defmethod variable-text ((concept concept))
  (let ((var (node-variable concept)))
    (cond (var (format nil "*~(~a~)"  var))
          (t ""))))


(defmethod id-text ((concept concept))
  (let* ((referent (referent concept))
         (id (id (content referent))))
    (cond ((not (typep referent 'individual)) "")
          ((eql id 't) "#")
          ((not (or (properties referent)
                    (unique-individual-p concept)))
           (format nil "#~d" (id referent)))
          (t ""))))




;; (defmethod format-referent ((concept concept) &key &allow-other-keys)
;;    (let ((referent (referent concept))
;;          )
;;      (cond ((typep referent 'individual)
;;             (format-individual referent)))))


(defmethod format-referent (node &key &allow-other-keys)
  (format-node node))

(defmethod format-referent ((concept concept) &key &allow-other-keys)
  (let* ((separator (if *concise* "" " "))
         (variable-text (variable-text concept))
         (var-string (if variable-text (format nil "~a~a" separator variable-text) ""))
         (id-text (id-text concept))
         (id-string (if id-text (format nil "~a~a" separator id-text)))
         (referent (referent concept))
         (ref-string (cond ((null referent) "")
                           (t (format-referent referent)))))
    (when *print-without-variables*
      (setf var-string ""))
    (format nil "~a~a~a" ref-string id-string var-string)))



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

(defmethod graph-spec ((annotations list))
  (getf annotations :graph))



;;; concept accessors
(defmethod name ((concept concept))
  (name-spec (properties concept)))

(defmethod set-spec ((concept concept))
  (set-spec (properties concept)))

(defmethod graph-spec ((concept concept))
  (graph-spec (properties concept)))

(defmethod graph ((concept concept))
  (let ((text (graph-spec concept)))
    (when text
      (parse-cgraph text))))

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
         (node-ref-text (format nil "~:[~; +~d~]"  *always-show-id* node-ref))
         (ref-text (if ref-p
                       (format nil ":~a~a~a~a"  separator refstr separator node-ref-text)
                       node-ref-text)))
    (format nil "[~a~a]" (princ-to-string (label concept-type)) (string-right-trim " " ref-text))))

(defmethod format-concept ((node (eql nil)) &key &allow-other-keys)
  "")

;;; include the node-ref number when in debug mode
(defmethod format-concept :around ((node concept) &key &allow-other-keys)
  (let ((ref (if *include-node-ref* (node-ref node) nil))
        (marked (if (and (marked node) *debug-mode*) marked-string nil))
        (node-text (string-trim "[]" (call-next-method))))
    (format nil "[~@[~a~]~a~@[+~a~]]" marked node-text ref)))


(defmethod format-node ((node concept) &rest keys &key &allow-other-keys)
  (apply #'format-concept node keys))


(defmethod initialize-instance :after ((node concept) &key)
  ;;(cache-node node)
  )



;; (defmethod make-concept-aux ((concept-type concept-type) (referent referent)
;;                              &key (context *context*))
;;   (let* ((concept (make-instance 'concept :concept-type concept-type
;;                                           :referent referent
;;                                           :context context)))
;;     (when referent
;;       ;;(cache-concept concept)
;;       )
;;     concept))



(defgeneric make-concept (type referent &key &allow-other-keys))

(defmethod make-concept ((ctype concept-type) (referent referent) &key (context *context*) &allow-other-keys)
  (make-instance 'concept :concept-type ctype
                          :referent referent
                          :context (or context *context*)))

(defmethod make-concept ((ctype concept-type) (referent (eql nil)) &key (context *context*) &allow-other-keys)
  (make-instance 'concept :concept-type ctype
                          :referent nil
                          :context (or context *context*)))


(defmethod make-concept ((ctype concept-type) (referent individual) &key (context *context*) &allow-other-keys)
  (let ((referent (make-referent referent)))
    (when referent
      (make-concept ctype referent :context (or context *context*)))))


(defmethod make-concept ((ctype concept-type) (referent list) &key (context *context*)  &allow-other-keys)
  (let* ((props (sans-prop referent :id :variable))
         (id (cond ((and referent (getf referent :id)))
                   (t (next-individual-number))))
         (cached (retrieve-concept ctype props :id id :context (or context *context*)))
         (individual (or (get-individual ctype :id id :properties props)
                         (make-individual ctype (sans-prop referent :variable)))))
    ;; (format t "~&id: ~s~%"  id)
    ;; (format t "~&cached: ~s~%"  cached)
    ;; (format t "~&individual: ~s~%"  individual)
    (cond (cached)
          ((null id)
           (let* ((individual (make-individual ctype props))
                  (referent (when individual (make-referent individual))))
             ;;(format t "~&referent: ~s~%"  referent)
             (cond ((null referent)
                    (make-concept ctype nil :context (or context *context*))))))
          (individual
           ;;(format t "~&id2: ~s~%"  id)
           (make-concept ctype individual :context (or context *context*))))))



(defmethod make-concept ((type symbol) referent &key (context *context*) &allow-other-keys)
  (let ((ctype (get-concept-type type)))
    (make-concept ctype referent :context (or context *context*))))

;; (defmethod :around make-concept (type referent &key (context *context*) &allow-other-keys)
;;   (let* ((concept (call-next-method)))
;;     ;; (when concept
;;     ;;   (let ((ref-object (referent concept)))
;;     ;;     ;; (when ref-object
;;     ;;     ;;   (setf (concept ref-object) concept))
;;     ;;     ;;(cache-concept concept :context context)
;;     ;;     ))
;;     concept))s

(defmethod make-concept :around ((ctype concept-type) (referent individual) &key &allow-other-keys)
  (let ((concept (call-next-method)))
    (when referent
      (pushnew concept (concepts referent)))
    concept))




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


(defmethod copy-concept ((concept concept))
  (let* ((type (concept-type concept))
         (referent (referent concept))
         (context (context concept))
         (new-concept (make-concept type referent :context context)))
    (push (list concept new-concept) *copy-map*)
    new-concept))

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
(defgeneric get-concept (concept-type properties &key id))

(defmethod get-concept ((concept-type concept-type) (properties list) &key (id nil id-supplied))
  (let* ((created nil)
         (concept (cond ((and (null id) (retrieve-concept concept-type properties :context *context*))) ; from context
                        ((and (null id) (find-local concept-type id properties))) ; already used in graph

                        (id
                         (let* ((individual (or (get-individual id)
                                                (when *allow-dynamic-individual-creation*
                                                  (make-individual concept-type properties :id id))))
                                (referent individual))
                           (setf created t)
                           (make-concept concept-type referent)))


                        ;; gerneric concept
                        ((null properties)
                         (setf created t)
                         (make-concept concept-type nil))

                        (t
                         (let* ((individuals (get-individuals concept-type properties)))
                           (cond (individuals (car individuals))
                                 (*allow-dynamic-individual-creation*
                                  (let* ((individual (get-individual concept-type :properties properties :id id))
                                         (referent individual))
                                  (when referent
                                    (make-concept concept-type referent))))))))))


    (when concept
      (pushnew concept *concepts-in-graph* :test #'concepts-equal))
    (values concept (when concept created))))


(defmethod get-concept ((type-label symbol) (properties-list list) &key id)
  (let ((ctype (get-concept-type type-label)))
        (if ctype
          (get-concept ctype properties-list :id id)
          (warn "Concept-type ~a is not defined" type-label))))

(defmethod get-concept ((type-label symbol) (properties string) &key id)
  (let ((properties-list (parse-properties properties)))
    (get-concept type-label properties-list :id id)))

(defmethod get-concept (arg1 arg2 &key id)
  (declare (ignore arg1 arg2))
  nil)



(defmethod concept-cache-key (type id (properties list))
  (let ((ctype (get-concept-type type)))
    (when ctype
      (list ctype id properties))))

(defmethod concept-cache-key (type id (referent-text string))
  (let ((properties (parse-properties referent-text)))
    (when properties
      (make-concept-cache-key type id properties))))


;;; (concept-cache-key-for-concept (parse-cgraph "[dog:Spot]"))
(defmethod concept-cache-key-for-concept ((concept concept))
  (let ((*concise* nil)
         (ctype (concept-type concept))
         (id (id concept))
         (properties (properties (referent concept))))
    (concept-cache-key ctype id properties)))


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


(defmethod conforms ((individual individual) (concept concept))
  (let ((concept-type (concept-type concept)))
    (when concept-type
      (conforms individual concept-type))))


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


(defmethod concepts-equal ((concept1 concept) ( concept2 concept) &key (ignore-id t))
  (and
   (types-equal (concept-type concept1) (concept-type concept2))
   ;;(referents-equal (referent concept1) (referent concept2) :ignore-id ignore-id)
   (referents-equal (referent concept1) (referent concept2) )))

(defmethod referents-equal ((concept1 concept) (concept2 concept) &key (ignore-id t))
  (referents-equal (referent concept1) (referent concept2)))
