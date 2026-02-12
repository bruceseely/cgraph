;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(declaim (sb-ext:disable-package-locks set))
(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  sets  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defclass set (basic-node)
  ((members :initarg :members
            :type list  ; list of content objects (individuals, nested sets, etc.)
            :accessor members)
   ;; concepts referencing this set (via referent)
   (concepts :initform (list)
             :accessor concepts)))


(defmethod members ((thing (eql nil))) nil)

;; Primary method - add individual directly to set
(defmethod add-to-set ((indiv individual) (set set))
  (push indiv (members set)))

;; Add nested set directly
(defmethod add-to-set ((inner-set set) (outer-set set))
  (push inner-set (members outer-set)))

;; Primary method - remove individual from set
(defmethod remove-from-set ((indiv individual) (set set))
  (setf (members set)
        (remove indiv (members set) :test #'individuals-equal)))

;; Remove nested set from set
(defmethod remove-from-set ((inner-set set) (outer-set set))
  (setf (members set)
        (remove inner-set (members outer-set) :test #'sets-equal)))




(defmethod print-object ((object set) stream)
  (print-unreadable-object (object stream :type t :identity nil)
    (format stream "~{~a~^ ~}" (members object))))

(defmethod format-set ((set set))
  (format nil "{~{~a~^, ~}}" (mapcar #'format-object (members set))))


(defmethod format-object ((object set)  &rest keys &key &allow-other-keys)
  (format-set object))


(defmethod sets-equal ((set1 set) (set2 set))
  (let* ((set1-members (sort (copy-list (members set1)) #'alpha-lessp))
         (set2-members (sort (copy-list (members set2)) #'alpha-lessp))
         (results (mapcar #'objects-equal set1-members set2-members)))
    (every #'identity results)))

;; Create a set from a list of content objects (individuals, nested sets)
(defun make-set-from-members (member-list)
  "Create a set with the given list of content objects as members"
  (make-instance 'set :members member-list))

;; Convenience alias for creating sets from individuals
(defun make-set-from-individuals (individual-list)
  "Create a set from a list of individuals"
  (make-instance 'set :members individual-list))

;; Type predicate for sets
(defmethod set-p ((thing set)) t)
(defmethod set-p ((thing t)) nil)

;; Set-specific referent methods
(defmethod set-p ((referent referent))
  (and (content referent)
       (typep (content referent) 'set)))

(defmethod set-content ((referent referent))
  (when (set-p referent)
    (content referent)))

(defmethod make-referent ((set set) &optional concept)
  (make-instance 'referent :content set :concept concept))
