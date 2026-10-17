(in-package :conceptual-graphs)

;;; cgraph's UNION, INTERSECTION and SET-DIFFERENCE (system/setup/
;;; set-operations.lisp) promise SBCL's result order on every implementation.
;;; Fixed cases, with SBCL 2.6.6's answers written out, run everywhere; on SBCL
;;; they are also compared against CL's own functions on random inputs, across
;;; the lengths where SBCL's INTERSECTION switches to a hash table.

(defun random-set-list (length range)
  (loop repeat length collect (random range)))

(defun set-operations-agree-with-sbcl-p (trials)
  "On SBCL: true when cgraph's three operations return exactly what CL's do,
   in the same order, over TRIALS random argument lists. Elsewhere: T."
  #-sbcl (declare (ignore trials))
  #-sbcl t
  #+sbcl
  (let ((*random-state* (sb-ext:seed-random-state 1017)))
    (loop repeat trials
          always (let* ((length1 (random (if (zerop (random 4)) 130 25)))
                        (length2 (random (if (zerop (random 4)) 130 25)))
                        (range (1+ (random 40)))
                        (list1 (random-set-list length1 range))
                        (list2 (random-set-list length2 range))
                        (key (if (zerop (random 3)) (lambda (n) (mod n 7)) nil))
                        (test (case (random 5) (0 nil) (1 #'equal) (2 #'=) (3 #'<=) (4 'eql))))
                   (flet ((same (ours theirs)
                            (equal (if key
                                       (apply ours list1 list2 :key key (and test (list :test test)))
                                       (apply ours list1 list2 (and test (list :test test))))
                                   (if key
                                       (apply theirs list1 list2 :key key (and test (list :test test)))
                                       (apply theirs list1 list2 (and test (list :test test)))))))
                     (and (same #'union #'cl:union)
                          (same #'intersection #'cl:intersection)
                          (same #'set-difference #'cl:set-difference)))))))

(defun set-operations-test (&optional verbose)
  (let ((ok t))
    (flet ((check (name result)
             (setf ok (and ok (and result t)))
             (when (or verbose (not result))
               (format t "~&  ~:[fail~;pass~] ~a~%" result name))))
      (when verbose (format t "~&SET-OPERATIONS-TEST~%"))

      (check "set-difference keeps list1's elements, reversed"
             (equal '(5 4 2 1) (set-difference (list 1 2 3 4 5) (list 3))))
      (check "set-difference with nothing to remove is list1 itself"
             (let ((list1 (list 1 2 3)))
               (eq list1 (set-difference list1 nil))))
      (check "union puts the longer list's extras, reversed, before the shorter"
             (equal '(5 4 1 2) (union (list 1 2) (list 2 4 5))))
      (check "union of equal lengths treats list1 as the shorter"
             (equal '(4 1 2) (union (list 1 2) (list 2 4))))
      (check "intersection of short lists walks the shorter, reversed"
             (equal '(3 2) (intersection (list 9 2 3) (list 1 2 3 4))))
      (check "intersection of long lists walks the longer, reversed"
             (equal (reverse (loop for i from 0 below 30 collect i))
                    (intersection (loop for i from 0 below 30 collect i)
                                  (loop for i from 0 below 60 collect i))))
      (check "key applies to both lists"
             (equal '((b 2)) (intersection '((a 1) (b 2)) '((x 2) (y 3)) :key #'second)))
      (check "test is called list1 element first"
             (equal '(3) (set-difference (list 1 3) (list 2) :test #'<)))
      (check "test-not is honoured"
             (equal '(1) (intersection (list 1) (list 1 2) :test-not #'/=)))
      #+sbcl
      (check "on SBCL, identical to CL's own on 3000 random cases"
             (set-operations-agree-with-sbcl-p 3000)))
    ok))
