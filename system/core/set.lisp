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
   ;; True when the set has unnamed members besides the ones listed -- the `*'
   ;; placeholder. `{}' and `{*}' are DIFFERENT referents: the first is the
   ;; empty or wholly unquantified set, the second a generic collection, and it
   ;; is the second that a count attaches to. `[CAT: {} @4]' is not how you say
   ;; four unnamed cats; `[CAT: {*} @4]' is.
   (open :initform nil
         :initarg :open
         :accessor set-open-p)
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
  "`{}', `{*}', `{Fido, Spot}', `{Fido, Spot, *}'.

   The `*' is a placeholder for unnamed members, so it is emitted whenever
   there are any -- with named members beside it or without. Dropping it
   closed every set on the way out: `{*}' became `{}', and `{Fido, Spot, *}@4'
   became a two-member set asserting it had four."
  (let ((names (mapcar #'format-object (members set))))
    (format nil "{~{~a~^, ~}~:[~;~:[~;, ~]*~]}"
            names (set-open-p set) names)))


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
(defun make-set-from-individuals (individual-list &key open)
  "Create a set from a list of individuals.

   OPEN says there are unnamed members besides those listed -- the `*'
   placeholder, and the difference between `{Fido}' and `{Fido, *}'. It
   defaults to NIL because naming the members you have is the closed reading:
   a caller that means `and others' has to say so."
  (make-instance 'set :members individual-list :open open))

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
