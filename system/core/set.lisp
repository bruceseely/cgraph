;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(declaim (sb-ext:disable-package-locks set))
(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  sets  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defclass set (basic-node)
  ((members :initarg :members
            :type list
            :accessor members)
   ;;concepts referencing this set
   (concepts :initform (list)
             :accessor concepts)))


(defmethod members ((thing (eql nil))) nil)

(defmethod add-to-set ((object individual) (set set))
  (push object (members set)))

(defmethod add-to-set ((object set) (set set))
  (push object (members set)))

(defmethod remove-from-set ((object individual) (set set))
  (setf (members set)
        (remove object (members set) :test #'individuals-equal)))




(defmethod print-object ((object set) stream)
  (print-unreadable-object (object stream :type t :identity nil)
    (format stream "~{~a~^ ~})" (members object))))

(defmethod format-set ((set set))
  (format nil "{~{~a~^, ~}}" (mapcar #'format-object (members set))))


(defmethod format-object ((object set)  &rest keys &key &allow-other-keys)
  (format-set object))


(defmethod sets-equal ((set1 set) (set2 set))
  (let* ((set1-members (sort (members set1) #'alpha-lessp))
         (set2-members (sort (members set2) #'alpha-lessp))
         (results (mapcar #'objects-equal set1-members set2-members)))
    (every #'identity results)))
