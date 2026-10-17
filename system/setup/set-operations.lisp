;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;; UNION, INTERSECTION and SET-DIFFERENCE with a defined result order.
;;;
;;; The standard leaves the order of their results unspecified, and cgraph lets
;;; it show: WALK-GRAPH+ (under COLLECT-NODES) takes its agenda from
;;; SET-DIFFERENCE, so the order a graph is walked, formatted, decomposed and
;;; spoken in comes from it. SBCL returns SET-DIFFERENCE reversed and ECL in
;;; order, so "A dog eats a cake. It is old." came out of ECL as "A dog is old.
;;; It eats a cake."
;;;
;;; The package shadows the three names (cgraph.asd), and these reproduce SBCL
;;; 2.6.6's order exactly -- every expected output in the tests was written
;;; against it -- on any implementation. They are checked against SBCL's own
;;; functions on random inputs by SET-OPERATIONS-TEST. The rules, from SBCL's
;;; src/code/list.lisp:
;;;
;;;   SET-DIFFERENCE  LIST1 itself when LIST2 is empty; otherwise the kept
;;;                   elements of LIST1, reversed.
;;;   UNION           the elements of the longer list missing from the shorter,
;;;                   reversed, in front of the shorter (equal lengths: LIST1
;;;                   counts as the shorter). Either list itself when the other
;;;                   is empty.
;;;   INTERSECTION    short lists: the elements of the SHORTER found in the
;;;                   longer, reversed. Long lists (the shorter over 20, or 3+
;;;                   with the longer 100+), with a test SBCL can hash (EQ EQL
;;;                   EQUAL EQUALP STRING= STRING-EQUAL =): the
;;;                   elements of the LONGER found in the shorter, reversed.
;;;
;;; KEY applies to the elements of both lists, and TEST is always called as
;;; (TEST list1-key list2-key), as the standard says.

(defun set-operation-test (test test-not)
  (cond ((and test test-not)
         (error ":TEST and :TEST-NOT were both supplied."))
        (test-not (complement (coerce test-not 'function)))
        (test (coerce test 'function))
        (t #'eql)))

(defun set-member-p (item-key list key test item-first)
  "True when some element of LIST matches ITEM-KEY. ITEM-FIRST says whether
   ITEM-KEY is the list1 side, and so goes first in the call to TEST."
  (dolist (elt list nil)
    (let ((elt-key (if key (funcall key elt) elt)))
      (when (if item-first
                (funcall test item-key elt-key)
                (funcall test elt-key item-key))
        (return t)))))

(defun set-operation-hashes-p (test test-not short-length long-length)
  "Whether SBCL's INTERSECTION would switch to a hash table here."
  (and (not test-not)
       (or (> short-length 20)
           (and (>= short-length 3) (>= long-length 100)))
       ;; SBCL's MAKE-HASH-TABLE-FOR-DUPLICATES: these functions, compared as
       ;; objects, after a test given as a symbol is turned into its function.
       (member (if test (coerce test 'function) #'eql)
               (list #'eq #'eql #'equal #'equalp #'string= #'string-equal #'=)
               :test #'eq)
       t))

(defun set-difference (list1 list2 &key key test test-not)
  "CL:SET-DIFFERENCE, with SBCL's result order on every implementation."
  (if (null list2)
      list1
      (let ((test (set-operation-test test test-not))
            (result (list)))
        (dolist (elt list1 result)
          (unless (set-member-p (if key (funcall key elt) elt) list2 key test t)
            (push elt result))))))

(defun union (list1 list2 &key key test test-not)
  "CL:UNION, with SBCL's result order on every implementation."
  (cond ((null list1) list2)
        ((null list2) list1)
        (t
         (let* ((test (set-operation-test test test-not))
                (list1-short (<= (length list1) (length list2)))
                (short (if list1-short list1 list2))
                (long (if list1-short list2 list1))
                (result short))
           (dolist (elt long result)
             ;; ELT is from the long list: the list1 side when list1 is long.
             (unless (set-member-p (if key (funcall key elt) elt) short key test
                                   (not list1-short))
               (push elt result)))))))

(defun intersection (list1 list2 &key key test test-not)
  "CL:INTERSECTION, with SBCL's result order on every implementation."
  (when (and list1 list2)
    (let* ((given-test test)
           (test (set-operation-test test test-not))
           (length1 (length list1))
           (length2 (length list2))
           (list1-short (<= length1 length2))
           (short (if list1-short list1 list2))
           (long (if list1-short list2 list1))
           (result (list)))
      (if (set-operation-hashes-p given-test test-not
                                  (min length1 length2) (max length1 length2))
          ;; Walk the long list, keeping what the short one has.
          (dolist (elt long result)
            (when (set-member-p (if key (funcall key elt) elt) short key test
                                (not list1-short))
              (push elt result)))
          ;; Walk the short list, keeping what the long one has.
          (dolist (elt short result)
            (when (set-member-p (if key (funcall key elt) elt) long key test
                                list1-short)
              (push elt result)))))))
