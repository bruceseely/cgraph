;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)


(define-condition concept-type-lookup-failed (error)
  ((type :initarg :type :reader type)))

(define-condition relation-type-lookup-failed (error)
  ((type :initarg :type :reader type)))


(eval-when (:load-toplevel :execute)
  (defvar *concept-type-catalog* (make-hash-table :test 'eql))
  (defvar *relation-type-catalog* (make-hash-table :test 'eql)))


(defvar *concept-type-top*)
(defvar *concept-type-bottom*)

(defun clear-concept-catalog ()
  (when *concept-type-catalog*
    (clrhash *concept-type-catalog*)))

(defun clear-relation-catalog ()
  (when *relation-type-catalog*
    (clrhash *relation-type-catalog*))
  ;; Forgetting the relation types includes forgetting how they surface in
  ;; English -- otherwise a :ROLE removed from the ontology would outlive the
  ;; relation it was attached to. See *RELATION-SYNTAX-RESET-HOOK*.
  (when *relation-syntax-reset-hook*
    (funcall *relation-syntax-reset-hook*)))

(defun clear-cgraph-type-catalogs ()
  (clear-concept-catalog)
  (clear-relation-catalog)
  (setf *loaded-types-source* nil))



 ;;graph
;;;; type-object
 ;;
(defclass type-object (basic-node)
  ((label ;;:type symbol
	  :initarg :label
	  :accessor label)
   (supertypes :type list
	       :initform (list)
	       :initarg :supertypes
	       :accessor direct-supertypes)
   (subtypes :type list
	     :initform (list)
	     :initarg :subtypes
	     :accessor direct-subtypes)
   (description :type string
		:initform ""
		:initarg :description
		:accessor description)
   (definition ;;:type graph-node
	       :initform nil
	       :initarg :definition
	       :accessor definition)
   (canonical-graph ;;:type graph-node
		    :initform nil
		    :initarg :canonical-graph
		    :accessor canonical-graph)
   (schema :initform nil
	   :initarg :schema
	   :accessor schema)))


(defmethod direct-subtypes ((name symbol))
  (direct-subtypes (get-concept-type name)))

(defmethod direct-supertypes ((name symbol))
  (direct-supertypes (get-concept-type name)))

(defmethod definition ((name symbol))
  (definition (get-concept-type name)))

(defmethod canonical-graph ((name symbol))
  (canonical-graph (get-concept-type name)))

(defmethod schema ((name symbol))
  (schema (get-concept-type name)))


(defmethod direct-subtype-p ((node type-object) (subtype-label symbol))
  (not (null (member subtype-label (direct-subtypes node) :key #'label))))

(defmethod direct-subtype-p ((node type-object) (subtype-node type-object))
  (not (null (direct-subtype-p (label subtype-node) node))))

(defmethod direct-subtype-p ((node type-object) (anything t))
  nil)


(defmethod direct-supertype-p ((node type-object) (supertype-label symbol))
  (not (null (member supertype-label (direct-supertypes node) :key #'label))))

(defmethod direct-supertype-p ((node type-object) (supertype-node type-object))
  (not (null (direct-supertype-p (label supertype-node) node))))

(defmethod direct-supertype-p ((node type-object) (anything t))
  nil)

;; (defmethod direct-slot-names ((inst symbol))
;;   (mapcar #'mop:slot-definition-name
;; 	  ;;(mop:type-slots (type-of inst))
;;           (mop:class-slots (find-class inst))))

(defmethod type-leaf-p ((node type-object))
  (and (direct-subtype-p *concept-type-bottom* node) (= (length (direct-subtypes node)) 1)))


(defclass concept-type (type-object)
  ((canonical-graph-string :type string
			   :initform ""
			   :initarg :canonical-graph-string
			   :accessor canonical-graph-string)
   (definition-string :initform nil
                      :initarg :definition-string
                      :accessor definition-string)
   (canonical-graph :type graph-node
		    :accessor canonical-graph)
   ;; :roll :natural
   (natural-p :initform nil
	      :type boolean
	      :accessor namural-p)
   ;; whether the type conforms to a referent containing a graph
   (graph-compatible-p :initform nil
                       :initarg :graph-compatible
                       :accessor graph-compatible-p)
   ;; set to T if define-concept-type encountered this label a second time
   (redefined-p :initform nil
                :accessor redefined-p)
   ;; for parsing canonical graphs -- needed?
   (processor :initform nil
	      :accessor processor)))

(defmethod concept-type-p ((obj concept-type))
  (not (null (get-concept-type obj))))

(defmethod concept-type-p ((obj t))
  nil)

(defmethod concept-type-label-p ((obj symbol))
  (not (null (type-node-type (get-concept-type obj)))))

(defmethod concept-type-label-p ((obj t))
  nil)


;; for the linear form in browser
(defmethod formatted-canonical-graph-string ((concept-type string))
  (let* ((*package* (find-package "CONCEPTUAL-GRAPHS"))
         (ctype (get-concept-type concept-type))
         (cg-string (canonical-graph-string ctype)))
    (format-cgraph (parse-cgraph cg-string))))

#|
(let ((*package* (find-package "COMMON-LISP-USER")))
  (cg::formatted-canonical-graph-string "breakfast-event"))
|#


(defmethod bottom-concept-type-p ((type-object concept-type))
  (eq type-object *concept-type-bottom*))


(defmethod top-concept-type-p ((type-object concept-type))
  (eq type-object *concept-type-top*))


(defmethod print-object ((node concept-type) stream)
  (format stream "~s" (label node)))

;; (defmethod print-object ((node concept-type) stream)
;;   (print-unreadable-object (node stream :identity nil)
;;     (princ (label node) stream)))


(defmethod make-top-concept-type ()
  (let ((concept-type (make-instance 'concept-type :label (intern top-concept-type-string :cg))))
    (record-concept-type concept-type)
    (setf *concept-type-top* concept-type)
    concept-type))


(defmethod make-bottom-concept-type ()
  (let ((concept-type (make-instance 'concept-type :label (intern bottom-concept-type-string :cg))))
    (record-concept-type concept-type)
    (setf *concept-type-bottom* concept-type)
    concept-type))



(defmethod type-depth ((node concept-type) &optional (depth 0))
  ;; (format t "~&depth: ~s~%"  depth)
  ;; (format t "~&node: ~s~%"  node)
  (let ((supertypes (direct-supertypes node))
        ;;(type (concept-type node))
        )
    (format t "~&supertypes: ~s~%"  supertypes)
    (cond ((or (null node)
               (= (node-ref node) (node-ref *CONCEPT-TYPE-TOP*)))
           depth)
          (t (type-depth (car supertypes) (1+ depth))))))



(defmethod make-concept-type-aux ((type-label string)  &key supertypes-list canonical-graph-string graph-compatible)
  (declare (ignore supertypes-list canonical-graph-string))
  (let* ((word-type (get-concept-type 'WORD))
         (concept-type (make-instance 'concept-type
				      :label type-label
                                      :supertypes (list word-type)
                                      :subtypes (list *concept-type-bottom*)
                                      :graph-compatible graph-compatible
				      :canonical-graph-string ""))
         (subtypes (cons concept-type
                         (remove *concept-type-bottom* (direct-subtypes word-type))))
         (pruned (remove-duplicates subtypes :key #'identity :test #'nodes-eq)))

    (setf (direct-subtypes word-type) pruned)
    (record-concept-type concept-type )
    concept-type))

(defmethod make-concept-type-aux (type-label &key supertypes-list (canonical-graph-string "") graph-compatible definition-string)
  (let ((concept-type (make-instance 'concept-type
				     :label type-label
                                     :supertypes (unless (eq type-label (intern (string (code-char #x22A4)) :cg))
                                                   (list *concept-type-top*))
                                     :subtypes (unless (eq type-label (intern (string (code-char #x22A5)) :cg))
                                                 (list *concept-type-bottom*))
                                     :graph-compatible graph-compatible
				     :canonical-graph-string canonical-graph-string
                                     :definition-string definition-string)))
    (dolist (supertype supertypes-list)
      (let ((supertype-node (ignore-errors (get-concept-type supertype))))
        ;; in case supertype is not yet defined
	(unless supertype-node
	  (setq supertype-node (make-concept-type supertype))) ; ?????
        (add-inheritance-link supertype-node concept-type)))
    (record-concept-type concept-type)
    concept-type))



(defmethod make-concept-type ((concept-type concept-type) &rest keys &key supertypes-list canonical-graph-string graph-compatible definition-string)
  (declare (ignore keys supertypes-list canonical-graph-string definition-string))
  concept-type)

(defmethod make-concept-type ((type-label string) &rest keys &key supertypes-list canonical-graph-string graph-compatible definition-string)
  supertypes-list canonical-graph-string definition-string
  (apply #'make-concept-type-aux type-label keys))


(defmethod make-concept-type ((type-label symbol) &rest keys &key supertypes-list canonical-graph-string graph-compatible definition-string)
  (when (eq type-label 't)
    ;;(print "------------------------------------------------ make-concept-type~%")
    ;;(print-backtrace)
    )
  supertypes-list canonical-graph-string definition-string
  (apply #'make-concept-type-aux type-label keys))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  concept-type support  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod types-eq ((type1 concept-type) (type2 concept-type))
  (nodes-eq type1 type2))

(defmethod types-eq ((type1 t) (type2 t))
  nil)


(defmethod types-equal ((type1 concept-type) (type2 concept-type))
  (nodes-equal type1 type2))

(defmethod types-equal ((type1 t) (type2 t))
  nil)


;;; if the lookup fails, return nil, on success returtn T
(defmethod concept-type-defined-p ((type symbol))
  (not (null (ignore-errors (get-concept-type type)))))


(defmethod order-types ((type-list list))
  (sort (copy-list type-list) #'< :key #'type-depth))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; subtypes ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod collect-subtypes ((node (eql '%)) &optional (collected (list)))
  collected
  (list))

(defmethod collect-subtypes ((node concept-type) &optional (collected (list)))
  (unless (nodes-equal node *concept-type-bottom*)
    ;; every type is a subtype of itself, except bottom-type
    (pushnew node collected)
    (dolist (subtype-node (direct-subtypes node))
      (setf collected (collect-subtypes subtype-node collected))))
  ;; it's a lattice, not a tree
  (remove-duplicates collected))

(defmethod collect-subtypes ((node symbol) &optional (collected (list)))
  (collect-subtypes (get-concept-type node) collected))

(defmethod subtypes ((node concept-type))
  (collect-subtypes node))

(defmethod subtypes ((node symbol))
  (subtypes (get-concept-type  node)))

(defmethod proper-subtypes ((node concept-type))
  (remove node (subtypes node)))


(defmethod has-subtype ((subtype-node concept-type) (type-node concept-type))
  (not (null (find subtype-node (subtypes type-node) :test #'nodes-eq))))

(defmethod subtype-p ((subtype-node type-object) (type-node type-object))
  (has-subtype subtype-node type-node))

(defmethod subtype-p ((subtype? symbol) (type-node type-object))
  (has-subtype (get-concept-type subtype?) type-node))

(defmethod subtype-p ((subtype? type-object) (type symbol))
  (has-subtype subtype? (get-concept-type type) ))

(defmethod subtype-p ((subtype? symbol) (type symbol))
  (has-subtype (get-concept-type subtype?) (get-concept-type type) ))


(defmethod common-subtype ((node1 concept-type) (node2 concept-type))
  (cond ((types-eq node1 node2) node1)
        ((subtype-p node2 node1) node2)
        ((subtype-p node1 node2) node1)
        (t nil)))

(defmethod common-subtypes ((node1 concept-type) (node2 concept-type))
  (intersection (subtypes node1) (subtypes node2)))


(defmethod proper-subtype-p ((subtype-node type-object) (type-node type-object))
  (and (not (nodes-eq type-node subtype-node))
       (subtype-p subtype-node type-node)))

(defmethod common-subtype-p ((subtype-node type-object)
                             (type1-node type-object) (type2-node type-object))
  (and (subtype-p subtype-node type1-node)
       (subtype-p subtype-node type2-node)))


(defun expand-subtypes (type-list)
  (assert '(every #'concept-type-p *))
  (remove-duplicates
   (apply #'append
          (mapcar #'direct-subtypes type-list))))


(defmethod common-direct-subtypes ((type1-node concept-type) (type2-node concept-type))
  (loop for set1 = (list type1-node) then (union set1 (expand-subtypes set1))
	for set2 = (list type2-node) then (union set2 (expand-subtypes set2))
	for intersection = (intersection set1 set2)
	until intersection
	finally (return intersection)))

(defmethod common-direct-subtypes ((type1 symbol) (type2 symbol))
  (common-direct-subtypes (get-concept-type type1) (get-concept-type type2)))



(defmethod maximal-common-subtype ((type1-node concept-type) (type2-node concept-type))
  (if (nodes-eq type1-node type2-node)
      type1-node
      (progn
        (walk-concept-types #'unmark)
        (walk-concept-types-down #'mark type1-node)
        (block search
          (crawl-concept-types-down (lambda (node)
                                      (when (marked node)
                                        ;;(print node)
                                        (return-from search node)))
                                    type2-node)))))

(defmethod maximal-common-subtype ((type1 symbol) (type2 symbol))
  (maximal-common-subtype (get-concept-type type1) (get-concept-type type2)))



(defmethod add-subtype ((node type-object) (subtype-node type-object))
  (add-inheritance-link node subtype-node))

(defmethod add-subtype ((node type-object) (subtype symbol))
  (let ((subtype-node (get-concept-type subtype)))
    (when subtype-node
      (add-subtype node subtype-node))))


(defmethod add-subtypes ((node concept-type) (subtypes list))
  (dolist (subtype subtypes)
    (add-subtype node subtype)))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; supertypes ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defmethod collect-supertypes ((node concept-type) &optional (collected (list)))
  ;;(format t "~&(collect-supertypes ~s ~s)" node collected)
  (cond ((equal (label node) 'T)
         (setf collected (cons *concept-type-top* collected)))
        (t
         (push node collected)
         (dolist (supertype (direct-supertypes node))
           (let ((supertypes (collect-supertypes supertype collected)))
             (setf collected (append supertypes collected))))))
  (remove-duplicates collected :test #'nodes-eq))


(defmethod supertypes ((node concept-type))
  (collect-supertypes node))

(defmethod proper-supertypes ((node concept-type))
  (remove node (supertypes node)))


(defmethod common-supertypes ((node1 concept-type) (node2 concept-type))
  (intersection (supertypes node1) (supertypes node2)))



(defmethod has-supertype ((type-node concept-type) (supertype-node concept-type))
  (not (null (find supertype-node (supertypes type-node) :test #'nodes-eq))))


(defmethod supertype-p ((type-node type-object) (supertype-node type-object))
  (has-supertype type-node supertype-node))

(defmethod supertype-p ((type-node type-object) (supertype symbol))
  (has-supertype type-node (get-concept-type supertype)))

(defmethod supertype-p ((type symbol) (supertype-node type-object))
  (has-supertype (get-concept-type type) supertype-node))

(defmethod supertype-p ((type symbol) (supertype symbol))
  (has-supertype (get-concept-type type) (get-concept-type supertype)))


(defmethod supertype ((node1 type-object) (node2 type-object))
  (cond ((nodes-eq (concept-type node1) (concept-type node1)) t)
        ((supertype-p node2 node1) node1)
        ((supertype-p node1 node2) node2)
        (t nil)))

(defmethod proper-supertype-p ((supertype-node type-object) (type-node type-object))
  (and (not (nodes-eq type-node supertype-node))
       (supertype-p type-node supertype-node)))

(defmethod is-common-supertype ((supertype type-object)
                               (type1-node type-object)
                               (type2-node type-object))
  (and (supertype-p type1-node supertype)
       (supertype-p type2-node supertype)))

(defun expand-supertypes (type-list)
  (assert '(every #'concept-type-p *))
  (remove-duplicates
   (apply #'append
          (mapcar #'direct-supertypes type-list))))


(defmethod common-direct-supertypes ((type1 concept-type) (type2 concept-type))
  (loop for set1 = (list type1) then (union set1 (expand-supertypes set1))
	for set2 = (list type2) then (union set2 (expand-supertypes set2))
	for intersection = (intersection set1 set2)
	until intersection
	finally (return intersection)))

(defmethod common-direct-supertypes ((type1 symbol) (type2 symbol))
  (common-direct-supertypes (get-concept-type type1) (get-concept-type type2)))


(defmethod minimal-common-supertype ((type1 concept-type) (type2 concept-type))
  (walk-concept-types #'unmark)
  (walk-concept-types-up #'mark type1)
  (block search
    (crawl-concept-types-up (lambda (node)
                             (when (marked node) (return-from search node)))
                           type2)))

(defmethod minimal-common-supertype ((type1 symbol) (type2 symbol))
  (minimal-common-supertype (get-concept-type type1) (get-concept-type type2)))

#|
(minimal-common-supertype 'dog 'animal)
(minimal-common-supertype 'dog 'girl)
(minimal-common-supertype 'dog 'chevy)
(minimal-common-supertype 'dog 'cake)
(minimal-common-supertype 'dog 'angel)
(minimal-common-supertype 'dog 'drive)
(minimal-common-supertype 'eat 'animate)
|#


(defmethod add-supertype ((node type-object) (supertype-node type-object))
  (add-inheritance-link supertype-node node))

(defmethod add-supertype ((node type-object) (supertype symbol))
  (let ((supertype-node (get-concept-type supertype)))
    (when supertype-node
      (add-supertype node supertype-node))))


(defmethod add-supertypes ((node concept-type) (supertypes list))
  (dolist (supertype supertypes)
    (add-supertype node supertype)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod remove-inheritance-link ((supertype-node concept-type) (subtype-node concept-type))
  (setf (direct-supertypes subtype-node)
	(remove supertype-node (direct-supertypes subtype-node) :test #'nodes-eq))

  (setf (direct-subtypes supertype-node)
	(remove subtype-node (direct-subtypes supertype-node) :test #'nodes-eq))

  (when (null (direct-supertypes subtype-node))
    (push *concept-type-top* (direct-supertypes subtype-node)))

  (when (null (direct-subtypes supertype-node))
    (push *concept-type-bottom* (direct-subtypes supertype-node))))


(defmethod add-inheritance-link ((supertype-node concept-type) (subtype-node concept-type))

  ;; replace a previously-existing link
  (setf (direct-subtypes supertype-node)
        (cond ((nodes-equal subtype-node *concept-type-bottom*) (list *concept-type-bottom*))
              (t (cons subtype-node
                       (remove subtype-node
                               (remove *concept-type-bottom*
                                       (direct-subtypes supertype-node)
                                       :test #'nodes-eq)
                               :test #'nodes-eq)))))

  (setf (direct-supertypes subtype-node)
        (cond ((nodes-equal supertype-node *concept-type-top*) (list *concept-type-top*))
              (t (cons supertype-node
                       (remove supertype-node
                               (remove *concept-type-top*
                                       (direct-supertypes subtype-node)
                                       :test #'nodes-eq)
                               :test #'nodes-eq)))))


  (when (and (find *concept-type-top* (direct-supertypes subtype-node))
	     (> (length (direct-supertypes subtype-node)) 1))
    (setf (direct-supertypes subtype-node)
	  (remove *concept-type-top* (direct-supertypes subtype-node) :test #'nodes-eq :count 1)))

  (when (and (find *concept-type-bottom* (direct-subtypes supertype-node))
	     (> (length (direct-subtypes supertype-node)) 1))
    (setf (direct-subtypes supertype-node)
	  (remove *concept-type-bottom* (direct-subtypes supertype-node) :test #'nodes-eq :count 1))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod word-symbol ((word string))
  (intern (string-upcase (format nil "word-~a" word)) :cg))


;; (defmethod get-word-concept-type ((type-name string))
;;   (let ((type-node (make-concept-type (string-upcase type-name))))
;;     (add-subtype type-node *CONCEPT-TYPE-BOTTOM*)
;;     type-node))

;; (defmethod get-concept-type ((type-name symbol))
;;   (gethash type-name *concept-type-catalog*))



(defmethod get-concept-type ((type-obj concept-type))
  type-obj)

;;; string type indicates a word
(defmethod get-concept-type ((type-name string))
  (get-concept-type (intern (string-upcase type-name) :cg)))

(defmethod get-concept-type ((type-name symbol))
  ;;(print type-name)
  ;;(describe type-name)
  ;;(describe *concept-type-catalog*)
  (multiple-value-bind (value present-p)
      (gethash type-name *concept-type-catalog*)
    (cond (present-p
           value)
          (t (error 'concept-type-lookup-failed :type (princ-to-string type-name))))))

(defmethod get-concept-type ((type-name t))
  (error 'concept-type-lookup-failed :type (format nil "~s, of type ~a"  type-name (type-of type-name))))

;; (defmethod get-concept-type ((type-name t))
;;   (values nil (format nil "~:@(~a~) is not a defined concept-type" type-name)))

(defmethod get-concept-type ((type-name (eql nil)))
  nil)



(defmethod record-concept-type ((type-object concept-type))
  (let ((key (cond ((stringp (label type-object)) (word-symbol (label type-object)))
                   (t (label type-object)))))
    (setf (gethash key *concept-type-catalog*) type-object))
  type-object)

(defmethod concept-type-exists ((type-name symbol))
  (multiple-value-bind (value present-p)
      (gethash type-name *concept-type-catalog*)
    value
    present-p))


;;;; This is to recover when a supertype had to be created before it was defined.
;;;; Is this all that is needed??
(defmethod modify-concept-type ((node concept-type)
				&key supertypes
				     canonical-graph-string
				     graph-compatible)
  (when canonical-graph-string
    (setf (canonical-graph-string node) canonical-graph-string))

  (when graph-compatible
    (setf (graph-compatible-p node) graph-compatible))

  (when supertypes
    ;; Remove back-links from all existing supertypes before replacing them.
    (dolist (old-super (direct-supertypes node))
      (setf (direct-subtypes old-super)
            (remove node (direct-subtypes old-super) :test #'nodes-eq)))
    (setf (direct-supertypes node) nil)

    (dolist (supertype supertypes)
      ;; nil on lookup failure
      (let ((supertype-node (ignore-errors (get-concept-type supertype))))

	(if supertype-node
	    (progn
	      (add-supertype node supertype-node)
	      node)
	    (let ((ctype (make-concept-type supertype)))
	      (add-subtype ctype node))))))
  node)



(defmethod remove-concept-type ((node concept-type))
  (let ((supertypes (direct-supertypes node))
	(subtypes (direct-subtypes node)))
    (dolist (supertype supertypes)
      (remove-inheritance-link supertype node))
    (dolist (subtype subtypes)
      (remove-inheritance-link node subtype))
    ;; It may not be correct to add a link for all members of the cross-product
    ))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;; concept type definition ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defmacro defconcept-type (label &key supertypes (canonical-graph-string ""))
  `(make-concept-type ,label
		      :supertypes-list ,supertypes
		      :canonical-graph-string ,canonical-graph-string))


(defun define-concept-type (&key label supertypes canonical-graph graph-compatible definition)
  ;;(setf label (intern (string-upcase label)))
  (setf supertypes (mapcar (lambda (supertype)
                             (cond ((typep supertype 'string)
                                    (intern (string-upcase supertype)))
                                   ((typep supertype 'symbol)
                                    supertype)))
                           supertypes))

  ;; nil on lookup failure
  (let* ((node (ignore-errors (get-concept-type label)))
         (result (if node
                     (progn
                       (modify-concept-type node
                                            :supertypes supertypes
                                            :canonical-graph-string canonical-graph
                                            :graph-compatible graph-compatible))
                     (make-concept-type label
                                        :supertypes-list supertypes
                                        :canonical-graph-string canonical-graph
                                        :graph-compatible graph-compatible
                                        :definition-string definition))))
    (when (and definition result)
      (setf (definition-string result) definition))
    result))


(defun parse-concept-type-def (def)
  ;; &allow-other-keys: tolerate (and ignore) annotation keys like :note that
  ;; maintainers put in a definition so a comment travels with it when the file
  ;; is alphabetically sorted. Only the keys named below carry meaning.
  (destructuring-bind (&key label supertypes canonical-graph graph-compatible definition
                       &allow-other-keys) def
    ;;(format t "~&~a ~a ~a" label supertypes cgraph) ; debug
    (let ((type-label (intern (string-upcase (string label)) :cg))
          (normalized-supertypes (mapcar (lambda (s) (intern (string-upcase (string s)) :cg))
                                         supertypes)))
      (define-concept-type :label type-label :supertypes normalized-supertypes :canonical-graph canonical-graph
                           :graph-compatible graph-compatible :definition definition))))


;;; load lisp file
(defun load-concept-types (filename &optional supress-warnings)
  supress-warnings
  (let ((count 0)
        (seen (make-hash-table :test 'eq)))
    (with-open-file (stream filename :direction :input)
      (loop
	(let ((def (read stream nil 'eof)))
	  (when (eq def 'eof) (return))
	  ;;(parse-concept-type-def def))
          (let* ((raw-label (getf def :label))
                 (label (when raw-label (intern (string-upcase (string raw-label)) :cg))))
            (when label
              (when (gethash label seen)
                (setf (redefined-p (ignore-errors (get-concept-type label))) t))
              (setf (gethash label seen) t))
            (parse-concept-type-def def)))
	(incf count)))
    count))


;;;;;;;;;;;;;;;


(defvar *visited-nodes*)
(defun walk-concept-types (function &optional (node *concept-type-top*))
  (let ((*visited-nodes* (list *concept-type-bottom*)))
    (walk-concept-types-aux function node)))

(defun walk-concept-types-aux (function &optional (node *concept-type-top*))
  (push node *visited-nodes*)
  (funcall function node)
  (dolist (subnode (direct-subtypes node))
    (unless (bottom-concept-type-p subnode)
      (unless (find subnode *visited-nodes*)
        (walk-concept-types-aux function subnode)))))


(defun walk-concept-types-down (function &optional (node *concept-type-top*))
  (unless (bottom-concept-type-p node)
    (funcall function node)
    (dolist (subnode (direct-subtypes node))
      (walk-concept-types-down function subnode))))

(defun walk-concept-types-up (function &optional (node *concept-type-bottom*))
  (unless (top-concept-type-p node)
    (funcall function node)
    (dolist (supernode (direct-supertypes node))
      (walk-concept-types-up function supernode))))



;;; breadth-first walk of types
(defmethod crawl-concept-types-up (function &optional (start-node *concept-type-bottom*))
  (let ((seen-list (list))
        (horizon (list start-node)))
    (block loop
      (loop
        (cond (horizon
               ;;(print horizon)
               (let* ((node (car horizon))
                      (seen (find node seen-list :test #'nodes-eq))
                      (direct-supertypes (copy-list (direct-supertypes node)))
                      )

                 ;; (format t "~2&node: ~s~%"  node)
                 ;; (format t "~&direct-supertypes: ~s~%"  direct-supertypes)

                 (when (find *concept-type-top* direct-supertypes)
                        (return-from loop nil))

                 (when (nodes-equal *concept-type-top* node)
                        (return-from loop nil))

                 ;;(setf (cdr (last horizon)) (direct-supertypes node))
                 (setf horizon (append horizon (direct-supertypes node)))
                 (unless seen
                   (funcall function (car horizon))
                   (push node seen-list))
                 (pop horizon)))
              (t (return-from loop)))))))

(defmethod crawl-concept-types-down (function &optional (start-node *concept-type-top*))
  (let ((seen-list (list))
        (horizon (list start-node)))
    (block loop
      (loop
        (cond (horizon
               (let* ((node (car horizon))
                      (seen (find node seen-list :test #'nodes-eq)))
                 (setf horizon (append horizon (remove *concept-type-bottom* (direct-subtypes node))))
                 ;;(setf (cdr (last horizon)) (remove *concept-type-bottom* (direct-subtypes node)))
                 (unless seen
                   (funcall function node)
                   (push node seen-list))
                 (pop horizon)))
              (t (return-from loop)))))))

(defmethod crawl-concept-types (function)
  (crawl-concept-types-down function *concept-type-top*))




(defvar *path*)
(defun collect-concept-types (&optional (start-node *concept-type-top*))
  (setq *path* (list))
  (let ((nodes (list)))
    (walk-concept-types (lambda (node)
                          (pushnew node nodes))
                        start-node)
    nodes))


(defvar *type-paths* ())

;;; returns all paths through the type lattice that include the supplied concept-type
(defmethod type-path ((concept-type concept-type))
  (let ((*type-paths* (list)))
    (type-path-aux concept-type *concept-type-top* (list))
    *type-paths*))

(defmethod type-path ((type symbol))
  (type-path (get-concept-type type)))

(defmethod type-path-aux ((target concept-type) (node concept-type) &optional (path (list)))
  (unless (bottom-concept-type-p node)
    (when (equal (label target) (label node))
      (push (reverse (cons node path)) *type-paths*))
    (dolist (subnode (direct-subtypes node))
      (type-path-aux target subnode (cons node path)))))




(defmethod format-concept-type ((node concept-type))
  (unless (eql node *concept-type-bottom*)
    (with-output-to-string (stream)
      (format stream "~&(:label ~:@(~s~)" (label node))
      (when (direct-supertypes node)
        (format stream " :supertypes ~a"
	        (mapcar #'(lambda (x)
			    (format nil "~s" (label x)))
		        (direct-supertypes node))))
      (when (canonical-graph-string node)
        (format stream " :canonical-graph-string \"~a\"" (canonical-graph-string node)))
      (format stream ")"))))


(defun save-concept-types (filename)
  (with-open-file (stream filename
			  :direction :output
			  :if-does-not-exist :create
			  :if-exists :supersede)
    (let* ((concept-types (collect-concept-types))
          (defs (mapcar #'format-concept-type (sort (copy-list concept-types) #'alpha-lessp :key #'label))))
      (dolist (def defs)
        (format stream "~&~a" def)))))


(defmethod nodes-equal ((con concept-type) (anything t)) nil)

(defmethod nodes-equal ((anything t) (con concept-type)) nil)

(defmethod nodes-equal ((type1 concept-type) (type2 concept-type))
  (or (nodes-eq type1 type2)
      (eq (label type1) (label type2))))


(defun describe-concept-types ()
  (mapHash (lambda (key rec)
	     (format *standard-output* "~2&~a:~%" key)
	     (describe rec))
	   *concept-type-catalog*))


(defun effective-canonical-graph-string (node)
  "Return the canonical graph string for NODE, falling back to the
   canonical-graph slot when canonical-graph-string is empty (handles
   a known modify-concept-type bug that stores the string there)."
  (let ((s (canonical-graph-string node)))
    (if (and s (plusp (length s)))
        s
        (let ((cg (ignore-errors (canonical-graph node))))
          (when (stringp cg) cg)))))

(defun extract-cg-type-names (cg-string)
  "Return a list of uppercase type-name strings found inside [...] brackets in CG-STRING.
   Strips any referent after a colon (e.g. [PERSON: John] → \"PERSON\") and
   skips empty names and the top/bottom Unicode characters."
  (when (and cg-string (plusp (length cg-string)))
    (let ((names nil)
          (len (length cg-string))
          (i 0))
      (loop while (< i len) do
        (cond ((char= (char cg-string i) #\[)
               (let ((end (position #\] cg-string :start (1+ i))))
                 (if end
                     (let* ((inner (string-trim " " (subseq cg-string (1+ i) end)))
                            ;; Drop referent after colon
                            (colon (position #\: inner))
                            (name  (string-trim " " (if colon
                                                        (subseq inner 0 colon)
                                                        inner)))
                            (upper (string-upcase name)))
                       (when (and (plusp (length upper))
                                  ;; Skip ⊤ and ⊥ — not in the catalog by their Unicode chars
                                  (not (string= upper "⊤"))
                                  (not (string= upper "⊥")))
                         (push upper names))
                       (setf i (1+ end)))
                     (incf i))))
              (t (incf i))))
      (remove-duplicates (nreverse names) :test #'string=))))

(defun extract-cg-relations (cg-string)
  "Return a list of lowercase relation-name strings from CG-STRING.
   Scans for (name) tokens, which is how relations appear in CG notation."
  (when (and cg-string (plusp (length cg-string)))
    (let ((relations nil)
          (len (length cg-string))
          (i 0))
      (loop while (< i len) do
        (cond ((char= (char cg-string i) #\()
               (let ((end (position #\) cg-string :start (1+ i))))
                 (if end
                     (let ((rel (string-trim " " (subseq cg-string (1+ i) end))))
                       (when (plusp (length rel))
                         (push (string-downcase rel) relations))
                       (setf i (1+ end)))
                     (incf i))))
              (t (incf i))))
      (nreverse relations))))

(defun all-ancestor-types (node)
  "Return all ancestor concept-types of NODE, not including NODE itself."
  (let ((visited (list node))
        (ancestors nil))
    (labels ((walk (current)
               (dolist (super (direct-supertypes current))
                 (unless (member super visited :test #'eq)
                   (push super visited)
                   (push super ancestors)
                   (walk super)))))
      (walk node))
    ancestors))

(defun check-type-lattice ()
  "Check the concept type lattice for structural problems.
   Reports cycles, orphaned types, symmetry violations, duplicate
   definitions, and canonical graph inheritance gaps."
  (let ((problems nil))

    ;; Check each type for cycles via supertypes
    ;; A cycle exists only if a node appears on the current recursion path,
    ;; not merely if it was visited before (which is normal in a lattice/DAG)
    (maphash (lambda (key node)
               (declare (ignore key))
               (let ((path (list)))
                 (labels ((walk-up (current)
                            (cond ((member current path :test #'eq)
                                   (push (format nil "Cycle detected: ~a appears in its own supertype chain ~
                                                      (path: ~{~a~^ → ~})" (label current)
                                                 (mapcar #'label (reverse (cons current path))))
                                         problems))
                                  (t
                                   (push current path)
                                   (dolist (super (direct-supertypes current))
                                     (walk-up super))
                                   (pop path)))))
                   (walk-up node))))
             *concept-type-catalog*)

    ;; Check for types with no supertypes (other than top)
    (maphash (lambda (key node)
               (declare (ignore key))
               (unless (or (eq node *concept-type-top*)
                           (eq node *concept-type-bottom*)
                           (direct-supertypes node))
                 (push (format nil "Orphaned type: ~a has no supertypes" (label node))
                       problems)))
             *concept-type-catalog*)

    ;; Check symmetry: if A is in B's direct-supertypes, B should be in A's direct-subtypes
    ;; Skip checks involving ⊥ since it doesn't maintain back-links to all supertypes
    ;; Use nodes-equal rather than eq to handle stale ⊥ references
    (maphash (lambda (key node)
               (declare (ignore key))
               (unless (eq (label node) bottom-concept-type)
                 (dolist (super (direct-supertypes node))
                   (unless (member node (direct-subtypes super) :test #'eq)
                     (push (format nil "Broken link: ~a lists ~a as supertype, but ~a does not list ~a as subtype"
                                   (label node) (label super) (label super) (label node))
                           problems)))
                 (dolist (sub (direct-subtypes node))
                   (unless (or (eq (label sub) bottom-concept-type)
                               (member node (direct-supertypes sub) :test #'eq))
                     (push (format nil "Broken link: ~a lists ~a as subtype, but ~a does not list ~a as supertype"
                                   (label node) (label sub) (label sub) (label node))
                           problems)))))
             *concept-type-catalog*)

    ;; Check for types defined more than once (redefined during load)
    (maphash (lambda (key node)
               (declare (ignore key))
               (when (redefined-p node)
                 (push (format nil "Duplicate definition: ~a was defined more than once (later definition merged)"
                               (label node))
                       problems)))
             *concept-type-catalog*)


    ;; Check canonical graph inheritance: if a type has a canonical graph,
    ;; it should include all relations present in each ancestor's canonical graph
    (maphash (lambda (key node)
               (declare (ignore key))
               (unless (or (eq node *concept-type-top*)
                           (eq node *concept-type-bottom*))
                 (let ((node-cg (effective-canonical-graph-string node)))
                   (when node-cg
                     (let ((node-relations (extract-cg-relations node-cg)))
                       (dolist (ancestor (all-ancestor-types node))
                         (let ((ancestor-cg (effective-canonical-graph-string ancestor)))
                           (when ancestor-cg
                             (let ((missing (set-difference (extract-cg-relations ancestor-cg)
                                                            node-relations
                                                            :test #'string=)))
                               (when missing
                                 (push (format nil "Canonical graph of ~a is missing relation~p inherited from ~a: ~{(~a)~^, ~}"
                                               (label node) (length missing) (label ancestor) missing)
                                       problems)))))))))))
             *concept-type-catalog*)

    ;; Check that all concept types and relations referenced in canonical graph strings are defined
    (maphash (lambda (key node)
               (declare (ignore key))
               (unless (or (eq node *concept-type-top*)
                           (eq node *concept-type-bottom*))
                 (let ((cg-str (effective-canonical-graph-string node)))
                   (when cg-str
                     (dolist (type-name (extract-cg-type-names cg-str))
                       (let ((sym (intern type-name :cg)))
                         (unless (gethash sym *concept-type-catalog*)
                           (push (format nil "Canonical graph of ~a references undefined concept type: ~a"
                                         (label node) type-name)
                                 problems))))
                     (dolist (rel-name (extract-cg-relations cg-str))
                       (let ((sym (intern (string-upcase rel-name) :cg)))
                         (unless (gethash sym *relation-type-catalog*)
                           (push (format nil "Canonical graph of ~a references undefined relation: (~a)"
                                         (label node) rel-name)
                                 problems))))))))
             *concept-type-catalog*)

    ;; Report results
    (if problems
        (progn
          (format t "~&Type lattice problems found:~%")
          (dolist (problem (reverse problems))
            (format t "~&  ~a~%" problem))
          (format t "~&~d problem~:p found.~%" (length problems))
          nil)
        (progn
          (format t "~&Type lattice OK.~%")
          t))))



(defun all-concept-types (&optional sort)
  (let ((nodes (list)))
    (maphash (lambda (key val)
               val
               (push key nodes))
             *concept-type-catalog*)
    (cond (sort
           (sort nodes #'alpha-lessp))
          (t nodes))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  relation-type  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass relation-type (type-object)
  ((description :type string
		:initarg :desc
		:initform ""
		:accessor desc)
   (source-types :type list
                 :initarg :source-types
                 :initform *concept-type-top*
                 :accessor source-types)
   (dest-type :type concept-type
              :initarg :dest-type
              :initform *concept-type-top*
              :accessor dest-type)))

(defmethod get-relation-type ((type-name symbol))
  (let ((cached-relation-type (gethash type-name *relation-type-catalog*)))
    (cond (cached-relation-type)
          (t (error 'relation-type-lookup-failed :text (princ-to-string type-name))))))

;;; The string case LOOKS UP, like every other method on this generic function,
;;; rather than returning the interned symbol and leaving the caller to finish
;;; the job. RELATION-READER was the only caller relying on that, and it got
;;; away with it because MAKE-RELATION resolves a symbol itself. Mirrors
;;; GET-CONCEPT-TYPE's string method, down to the explicit package.
(defmethod get-relation-type ((relation-type string))
  (get-relation-type (intern (string-upcase relation-type) :cg)))

(defmethod get-relation-type ((relation-type relation-type))
  relation-type)



(defun rel-use (source dest)
  "Relation types that are consistent with the supplied input and output concept types"
  (let ((source-concept-type (get-concept-type source))
        (dest-concept-type (get-concept-type dest))
        (rel-types (mapcar #'get-relation-type (all-relation-types)))
        (collected (list)))
    (dolist (rel rel-types)
      ;;(format t "~&rel: ~s~%"  rel)
      (let ((source-types (source-types rel))
            (dest-type (dest-type rel)))
        (when (and (subtype-p dest-concept-type dest-type)
                   (find source-concept-type source-types :test #'subtype-p))
          (push rel collected))))
    (sort collected #'alpha-lessp :key #'label)))

(defun cg-rel-use (source dest)
  (cond ((and (not (get-concept-type source))
              (not (get-concept-type dest)))
         (format nil "input type, ~a, and outpot tyoe, ~a, are both unknown." source dest))
        ((not (get-concept-type source))
         (format nil "input type, ~a, in unknown." source))
        ((not (get-concept-type dest))
         (format nil "output type, ~a, in unknown." dest))
        (t
         (format nil "~{~(~a~)~^, ~}"
                 (mapcar #'(lambda (z) (string (label z))) (rel-use source dest))))))


;;; --- Direction-labelled lattice queries -------------------------------------
;;;
;;; REL-USE answers "which relations run from this type to that one". The graph
;;; editor needs the same question asked from one concept's point of view, in
;;; both directions at once, because its editor pane has a focus concept and an
;;; arc that may point either way. DIRECTION is always relative to the FOCUS:
;;;
;;;   :FORWARD   focus is the relation's source     [focus]->(rel)->[other]
;;;   :REVERSE   focus is the relation's dest       [focus]<-(rel)<-[other]
;;;
;;; A relation legal both ways appears twice, once per direction -- which is
;;; exactly the symmetric case the editor lets you flip between.

(defun %source-type-list (relation-type)
  "SOURCE-TYPES normally holds a list, but its initform is a bare concept-type,
   so accept either."
  (let ((types (source-types relation-type)))
    (if (listp types) types (list types))))

(defun %type-may-be-source-p (concept-type relation-type)
  (and (find concept-type (%source-type-list relation-type) :test #'subtype-p) t))

(defun %type-may-be-dest-p (concept-type relation-type)
  (and (subtype-p concept-type (dest-type relation-type)) t))

(defun rel-uses-for (concept)
  "Relation types CONCEPT's type can take part in, from CONCEPT's point of
   view. Returns a list of (RELATION-TYPE . DIRECTION).

   Used when only the focus concept is populated: it is every relation the
   focus could hang off, either way round."
  (let ((ctype (get-concept-type concept))
        (collected (list)))
    (dolist (label (all-relation-types))
      (let ((rel (ignore-errors (get-relation-type label))))
        (when rel
          (when (%type-may-be-source-p ctype rel) (push (cons rel :forward) collected))
          (when (%type-may-be-dest-p ctype rel)   (push (cons rel :reverse) collected)))))
    (sort collected #'alpha-lessp :key (lambda (e) (label (car e))))))

(defun rel-uses-between (focus other)
  "Relation types consistent with FOCUS and OTHER in EITHER direction, as a
   list of (RELATION-TYPE . DIRECTION) relative to FOCUS.

   Used when both concepts are populated. This is REL-USE called both ways
   round and labelled, so the caller can tell a relation that is legal only
   one way from one that offers a genuine choice."
  (let ((collected (list)))
    (dolist (rel (rel-use focus other)) (push (cons rel :forward) collected))
    (dolist (rel (rel-use other focus)) (push (cons rel :reverse) collected))
    (sort collected #'alpha-lessp :key (lambda (e) (label (car e))))))

(defun rel-far-end-types (relation direction)
  "Concept types legal at the far end of RELATION, given the focus sits at
   DIRECTION. :FORWARD means the focus is the source, so the far end is the
   destination; :REVERSE means the far end is a source.

   Used when the focus and a relation are populated and the concept list needs
   narrowing to what could legally go on the other end. Excludes bottom, which
   is a subtype of everything and never a useful choice."
  (let* ((rel (get-relation-type relation))
         (roots (ecase direction
                  (:forward (list (dest-type rel)))
                  (:reverse (%source-type-list rel)))))
    (sort (remove-duplicates
           (loop for root in roots
                 for node = (ignore-errors (get-concept-type root))
                 when node
                   append (remove-if #'bottom-concept-type-p (subtypes node)))
           :test #'eq)
          #'alpha-lessp :key #'label)))





(defmethod record-relation-type ((type relation-type))
  (setf (gethash (label type) *relation-type-catalog*) type)
  type)

(defmethod relation-type-exists ((type-name symbol))
  (multiple-value-bind (value present-p)
      (gethash type-name *relation-type-catalog*)
    value
    present-p))


(defmethod relation-type-p ((obj symbol))
  (not (null (get-relation-type obj))))

(defmethod relation-type-p ((obj t))
  nil)

(defmethod types-equal ((type1 relation-type) (type2 relation-type))
  (nodes-equal type1 type2))

(defmethod nodes-equal ((rel relation-type) (anything t)) nil)

(defmethod nodes-equal ((anything t) (rel relation-type)) nil)

(defmethod nodes-equal ((type1 relation-type) (type2 relation-type))
  (or (nodes-eq type1 type2)
      (eq (label type1) (label type2))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  relation-type support  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;
;;;; relation predicate
;;;;

;; (defun make-relation-predicate (relation-type-label)
;;   (ignore-errors
;;     `(defmethod ,relation-type-label ((con1 concept) (con2 concept))
;;        (let* ((relation (make-relation (princ-to-string ',relation-type-label))))
;;          (add-arc-from-concept   con1  relation)
;;          (set-arc-from-relation  relation  con2)
;;          relation))))

;; (defun make-relation-predicate (relation-type-label)
;;   (ignore-errors
;;    (eval
;;     `(defmethod ,relation-type-label ((con1 concept) (con2 concept))
;;        (let* ((relation (make-relation (princ-to-string ',relation-type-label))))
;;          (add-arc-from-concept   con1  relation)
;;          (set-arc-from-relation  relation  con2)
;;          relation)))))

;;; this works
;; (defmethod obj ((con1 concept) (con2 concept))
;;   (let ((relation (make-relation "obj")))
;;     (add-arc-from-concept   con1  relation)
;;     (set-arc-from-relation  relation  con2)
;;     relation))


;; (defmacro make-relation-predicate (relation-type-label)
;;   `(defmethod ,relation-type-label ((con1 concept) (con2 concept))
;;     (connect (princ-to-string ',relation-type-label) con1 con2)))

;; (let ((zzz 'agnt))
;;   `(defmethod ,zzz ((con1 concept) (con2 concept))
;;     (let* ((relation (make-relation (princ-to-string ',zzz))))
;;       (add-arc-from-concept con1 relation)
;;       (set-arc-from-relation relation con2)
;;       relation)))



(defmethod relation-arc-types ((relation-type relation-type))
  (cons (dest-type relation-type) (source-types relation-type)))

(defmethod relation-arc-types ((type-label symbol))
  (relation-arc-types (get-relation-type type-label)))


(defmethod make-relation-type ((label string)  &rest keys &key (source-types nil) (dest-type nil) description)
  (declare (ignore source-types dest-type description))
  ;; :CG explicitly, never the ambient *PACKAGE*. This interns the key the
  ;; relation-type catalog is stored under, and the catalog is an EQL table, so
  ;; a label interned somewhere else is a different key and simply is not
  ;; there. Loading the type files with *PACKAGE* set to anything but :CG --
  ;; calling SETUP-CGRAPH straight from a cl-user REPL will do it -- used to
  ;; build a catalog that every explicit (INTERN ... :CONCEPTUAL-GRAPHS) lookup
  ;; then missed. Same fix, and the same reason, as the concept-type side.
  (apply #'make-relation-type (intern (string-upcase label) :cg) keys))

(defmethod make-relation-type ((label symbol)  &rest keys &key (source-types nil) (dest-type nil) description)
  (assert (or (null source-types) (every #'concept-type-p source-types))
          ()
          "For (make-relation-type ~a), source should be a concept-type, or nil" label)
  (assert (or (null dest-type) (concept-type-p dest-type))
          ()
          "For (make-relation-type ~a), destination should be a concept-type, or nil" label)
  keys

  (when (and source-types (not (listp source-types))) (setf source-types (list source-types)))

  (let ((relation-type (make-instance 'relation-type
				      :label label
				      :source-types source-types
				      :dest-type dest-type
                                      ;; The slot is :TYPE STRING with an
                                      ;; initform of "", and a catalog entry
                                      ;; that omits :desc arrives here as NIL,
                                      ;; which then overrides that initform and
                                      ;; leaves a non-string in a string slot.
                                      ;; Found by the save/load round trip: INIT
                                      ;; held NIL going out and "" coming back,
                                      ;; the reload being the thing that told
                                      ;; the truth.
				      :desc (or description ""))))
    (record-relation-type relation-type)
    ;;(make-relation-predicate label)
    relation-type))


(defmethod print-object ((node relation-type) stream)
  (format stream "~(~a~)" (label node)))


(defparameter *undefined-concept-types* (list))

(defun lookup-concept-type (concept-type &optional supress-warnings)
  (let ((result (ignore-errors (get-concept-type concept-type))))
    (cond (result result)
          ((string-equal concept-type "nil") nil) ;for monads
          (t
           (pushnew concept-type *undefined-concept-types*)
           (unless supress-warnings
             (format *standard-output* "~&WARNING: concept-type ~a is undefined,~%" concept-type))
           *concept-type-top*))))




(defun parse-relation-type-def (def &optional supress-warnings)
  (declare (special *undefined-concept-types*))
  ;; &allow-other-keys: tolerate (and ignore) annotation keys like :note -- see
  ;; parse-concept-type-def.
  ;;
  ;; :ROLE and :PREP are how a definition says what the relation does in
  ;; English -- (:label benef :source-types act :dest-type animate :role :pp
  ;; :prep "for"). They need no change to the file format, because
  ;; &allow-other-keys already tolerated them; older files without them are
  ;; unaffected, and an image with no generation system ignores them.
  (destructuring-bind (&key label desc source-types dest-type role prep
                       &allow-other-keys)
      def

    (unless (listp source-types) (setf source-types (list source-types)))

    (let* ((normalized-sources (mapcar (lambda (s) (intern (string-upcase (string s)) :cg))
                                       source-types))
           (normalized-dest    (when dest-type (intern (string-upcase (string dest-type)) :cg)))
           (source      (mapcar #'lookup-concept-type normalized-sources))
           (destination (lookup-concept-type normalized-dest)))

      (prog1 (make-relation-type (string-upcase label)
                                 :description desc
                                 :source-types source
                                 :dest-type destination)
        ;; After the type exists, so a registration never names a relation the
        ;; catalog has not heard of -- which is precisely what
        ;; %LINT-STALE-RELATION-ENTRIES reports.
        (when (and role *relation-syntax-hook*)
          (funcall *relation-syntax-hook* label role prep))))))


(defun load-relation-types (filename &optional supress-warnings)
  (declare (special *undefined-concept-types*))
  (let ((*undefined-concept-types* (list))
        (count 0))
    (with-open-file (stream filename :direction :input)
      (loop
	(let ((def (read stream nil 'eof)))
	  (when (eq def 'eof) (return))
	  (parse-relation-type-def
           def supress-warnings))
	(incf count)))

    (when (and *undefined-concept-types* (not supress-warnings))
      (format *standard-output* "~%Undefined concept-types references by relation-types:~&~a" *undefined-concept-types*))
    (values count *undefined-concept-types*)))


(defun relation-source-list (relation-type)
  "SOURCE-TYPES as a list, whatever the slot happens to hold.

   The slot's initform is a bare *CONCEPT-TYPE-TOP* rather than a list of one,
   so a relation type that was never given sources holds a concept type where
   everything else holds a list."
  (let ((sources (source-types relation-type)))
    (if (listp sources) sources (list sources))))

(defun relation-source-text (relation-type)
  "SOURCE-TYPES as the catalog file writes them: a bare name for one,
   a parenthesised list for several -- `act', `(entity entity)'.

   Both forms are what PARSE-RELATION-TYPE-DEF reads: it wraps a non-list and
   interns each name. What it cannot read is a STRING of a list, which is what
   this function exists to stop being emitted."
  (let ((names (mapcar (lambda (s) (string-downcase (string (label s))))
                       (relation-source-list relation-type))))
    (if (= 1 (length names))
        (first names)
        (format nil "(~{~a~^ ~})" names))))

(defun save-relation-types (filename)
  "Write the relation-type catalog in the form LOAD-RELATION-TYPES reads back.

   The contract is a round trip, and it was broken in one field. SOURCE-TYPES
   went out as a quoted string of a list -- `\"(ACT)\"' -- and the reader's path
   for that is: not a list, so wrap it; intern `|(ACT)|'; fail to find a
   concept type of that name; fall back to the top type. So saving the catalog
   and loading it again widened EVERY relation's source constraint to ⊤,
   silently, and that constraint is what REL-USE and the editor's contextual
   filtering rest on -- nothing would signal, the type columns would simply
   begin offering every relation for every concept.

   DEST-TYPE survived the same treatment by luck: it holds one concept type
   rather than a list, and a concept type prints as its own label, so the
   quoted form read back correctly.

   Names are written bare and lower-case, matching the files this reads and
   default-types/relation-types.text. TYPE-TEST4 holds the round trip."
  (with-open-file (stream filename
			  :direction :output
			  :if-does-not-exist :create
			  :if-exists :supersede)
    (flet ((format-relation-type (node)
	     (progn
	       (format stream "~&(:label ~(~a~)" (label node))
               (format stream "~14t:source-types ~a" (relation-source-text node))
               (format stream "~46t:dest-type ~(~a~)" (label (dest-type node)))
               ;; Always written, empty or not, as the catalog files have it.
               (format stream "~71t:desc \"~a\"" (or (desc node) ""))
	       (format stream ")"))))
      (let ((relation-types (list)))
	(maphash #'(lambda (name type)
		     (declare (ignore name))
		     (push type relation-types))
		 *relation-type-catalog*)
	(mapc #'format-relation-type (sort relation-types #'alpha-lessp :key #'label)))))
  t)


(defun all-relation-types (&optional sort)
  (let ((nodes (list)))
    (maphash (lambda (key val)
               val
               (push key nodes))
             *relation-type-catalog*)
    (cond (sort
           (sort nodes #'alpha-lessp))
          (t (reverse nodes)))))




(defmethod type-node-type ((node concept-type))
  'concept-type)

(defmethod type-node-type ((node relation-type))
  'relation-type)

(defmethod type-node-type ((node t))
  nil)


(defmethod subsumes-p ((type1 concept-type) (type2 concept-type))
  (or (types-eq type1 type2)
      (subtype-p type2 type1)))


(defun load-cgraph-types (&optional supress-warnings)
  (make-top-concept-type)
  (make-bottom-concept-type)
  (let ((result
         (list
          (load-concept-types (format nil "~aconcept-types.lisp" *cgraph-types-directory*))
          (load-relation-types (format nil "~arelation-types.lisp" *cgraph-types-directory*)))))
    (setf *loaded-types-source* (or *external-types-directory* :default))
    result))


(defun unload-cgraph-types (&optional supress-warnings)
  (declare (ignore supress-warnings))
  (clear-cgraph-type-catalogs))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;; Type Print  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; the indents is the column to start on. The spacing is (1- indent)
(defmethod print-concept-types (&optional (top-node *concept-type-top*) &key (indents '(0)) (newline t))
  (let* ((concept-type (get-concept-type top-node))
	 (subtypes (direct-subtypes concept-type))
	 (concept-label (label concept-type))
	 (concept-label-string (substitute nope-char #\~ (princ-to-string concept-label)))
         (indent-delta (length concept-label-string))
	 (next-indent (car indents))
	 (next-level-indent (+ 2 next-indent indent-delta)))

    (unless (equal concept-type *concept-type-bottom*)
      ;; print the indentation
      (when newline
	(format *standard-output* "~&")
	(let ((last-indent 0))
	  (dolist (i (reverse indents))
	    (format *standard-output* "~a" (make-string (max 0 (- i last-indent 1)) :initial-element #\space))
	    (unless (= i (car indents))
	      (format *standard-output* "."))
	    (setf last-indent i))))
      ;; print the label
      (format *standard-output* "-~a~@[-~]"   concept-label-string (not (and (equal (car subtypes)
                                                                                    *concept-type-bottom*)
                                                                             (null (cdr subtypes)))))

      ;; recur
      (when (car subtypes)
	(print-concept-types (label (car subtypes)) :indents (cons next-level-indent indents) :newline nil))
      (dolist (subtype (cdr subtypes))
	(print-concept-types (label subtype) :indents (cons next-level-indent indents) :newline t)))))

(defun print-relation-types (&optional (stream *standard-output*))
  (let* ((type-labels (all-relation-types))
         (types (mapcar #'get-relation-type type-labels))
         (sorted-types (sort (copy-list types) #'alpha-lessp :key #'label))
         (def-data (list))
         (rel-width 8)
         (source-width 0)
         (dest-width 0)
         (destination-tab 0)
         (description-tab 0)
         (cstr nil))

    (dolist (rtype sorted-types)
      (let* ((source-str (if (source-types rtype) (string-downcase (princ-to-string (mapcar #'label (source-types rtype)))) ""))
             (dest-str (if (dest-type rtype) (string-downcase (princ-to-string (label (dest-type rtype)))) ""))
             (rtype-str (string-upcase (princ-to-string (label rtype))))
             (desc-str (or (desc rtype) ""))
             (data (list source-str rtype-str dest-str desc-str)))

        (push data def-data)

        (setf source-width (max source-width (length source-str)))
        (setf dest-width (max dest-width (length dest-str)))

        (setf destination-tab (+ 1 source-width rel-width 2))
        (setf description-tab (+ destination-tab dest-width 1))

        (setf cstr (format nil "~~&~~~d@a ~a(~~a)~a~~~dt~~a~~~dt~~a"
                           (1+ source-width) right-arrow right-arrow destination-tab description-tab))))

    ;;(print cstr)
    (dolist (data (reverse def-data))
      (apply #'format stream cstr data))))


;;; Return a one-line description of the concept or relation type named by NAME-STRING.
;;; Returns NIL when NAME-STRING doesn't match any known type.
;;; TYPE-HINT, if supplied, should be "concept" or "relation" to restrict the lookup;
;;; when NIL and both exist, both descriptions are returned separated by a newline.
(defun cg-type-info-string (name-string &optional type-hint)
  "Look up NAME-STRING as a concept type or relation type and return a summary string.
Returns NIL if the name is not found in either catalog."
  (let* ((sym          (intern (string-upcase name-string) :cg))
         (want-concept (or (null type-hint) (equal type-hint "concept")))
         (want-relation (or (null type-hint) (equal type-hint "relation")))
         (ct  (when want-concept  (ignore-errors (get-concept-type sym))))
         (rt  (when want-relation (ignore-errors (get-relation-type sym))))
         (ct-str
           (when ct
             (handler-case
                 (let* ((supers (mapcar (lambda (s) (string-downcase (symbol-name (label s))))
                                        (direct-supertypes ct)))
                        (subs   (mapcar (lambda (s) (string-downcase (symbol-name (label s))))
                                        (remove *concept-type-bottom* (direct-subtypes ct))))
                        (def    (definition-string ct))
                        (cg-str (let ((s (canonical-graph-string ct)))
                                  (if (string/= s "")
                                      s
                                      ;; modify-concept-type stores the string in canonical-graph
                                      ;; rather than canonical-graph-string; check that as a fallback
                                      (let ((cg (ignore-errors (canonical-graph ct))))
                                        (when (stringp cg) cg)))))
                        (parts  (list (format nil "[concept]  supertypes: ~{~a~^, ~}" supers)
                                      (when subs (format nil "subtypes: ~{~a~^, ~}" subs))
                                      (when (and (stringp def) (string/= def ""))
                                        (format nil "def: ~a" def))
                                      (when cg-str
                                        (format nil "cg: ~a" cg-str)))))
                   (format nil "~a  ~{~a~^  |  ~}"
                           (string-downcase (symbol-name (label ct)))
                           (remove nil parts)))
               (error (e) (format nil "~a [concept — error: ~a]"
                                  (string-downcase name-string) e)))))
         (rt-str
           (when rt
             (handler-case
                 (let* ((srcs (mapcar (lambda (s) (string-downcase (symbol-name (label s))))
                                      (source-types rt)))
                        (dst  (let ((d (dest-type rt)))
                                (when d (string-downcase (symbol-name (label d))))))
                        (d    (desc rt)))
                   (format nil "~a  [relation]  ~{~a~^, ~} → ~a~:[~; | ~:*~a~]"
                           (string-downcase (symbol-name (label rt)))
                           srcs
                           (or dst "?")
                           (and d (string/= d "") d)))
               (error (e) (format nil "~a [relation — error: ~a]"
                                  (string-downcase name-string) e))))))
    (cond
      ((and ct-str rt-str) (format nil "~a~%~a" ct-str rt-str))
      (ct-str  ct-str)
      (rt-str  rt-str)
      (t nil))))
