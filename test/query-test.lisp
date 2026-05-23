;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Tests for Graph Query System
;;;

(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST UTILITIES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun make-query-test-context ()
  "Create and populate a context for query testing."
  (let ((kb (make-context)))
    (make-cgraph "[Person: Sue]←(agnt)←[Eat]→(obj)→[Pie]" kb)
    (make-cgraph "[Person: Tom]←(agnt)←[Eat]→(obj)→[Cake]" kb)
    (make-cgraph "[Person: Pat]←(agnt)←[Drive]→(manr)→[Quickly]" kb)
    kb))

(defun make-query-test-context2 ()
  "Create and populate a context for query testing."
  (let ((kb (make-context)))
    (make-cgraph "[PERSON: Dave]←(agnt)←[DRIVE]" kb)
    (make-cgraph "[PERSON: Dave]→(poss)→[CHEVY-VEHICLE]" kb)
    (make-cgraph "[DRIVE]→(inst)→[CHEVY-VEHICLE]" kb)
    (make-cgraph "[CITY: Baltimore]←(dest)<-[DRIVE]" kb)
    (make-cgraph "[PERSON: Dave]→(attr)→[YOUNG]" kb)
    (make-cgraph "[CHEVY-VEHICLE]→(attr)→[OLD]" kb)
    kb))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST CASES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-query-simple-match (&optional verbose)
  "Query for eating events — should match 2 graphs."
  (let* ((kb (make-query-test-context))
         (results (query "[Person]←(agnt)←[Eat]" kb))
         (pass (= (length results) 2)))
    (when verbose
      (format t "~&simple-match: ~:[FAIL (got ~d, expected 2)~;pass~]"
              pass (length results)))
    pass))


(defun test-query-no-match (&optional verbose)
  "Query for giving events — should match nothing."
  (let* ((kb (make-query-test-context))
         (results (query "[Person]←(agnt)←[Give]" kb))
         (pass (= (length results) 0)))
    (when verbose
      (format t "~&no-match: ~:[FAIL (got ~d matches)~;pass~]"
              pass (length results)))
    pass))


(defun test-query-variable-bindings (&optional verbose)
  "Query with variables — should bind *x to eaters."
  (let* ((kb (make-query-test-context))
         (results (query "[Person: *x]←(agnt)←[Eat]" kb))
         (pass (and (= (length results) 2)
                    (every (lambda (r) (getf r :bindings)) results))))
    (when verbose
      (format t "~&variable-bindings: ~:[FAIL~;pass~]" pass)
      (when results
        (format-query-results results)))
    pass))


(defun test-query-multiple-variables (&optional verbose)
  "Query with two variables — bind who eats what."
  (let* ((kb (make-query-test-context))
         (results (query "[Person: *x]←(agnt)←[Eat]→(obj)→[Food: *y]" kb))
         (pass (and (= (length results) 2)
                    (every (lambda (r) (= (length (getf r :bindings)) 2)) results))))
    (when verbose
      (format t "~&multiple-variables: ~:[FAIL~;pass~]" pass)
      (when results
        (format-query-results results)))
    pass))

;; (defun test-query-multiple-variables2 (&optional verbose)
;;   "Query with two variables — bind who eats what."
;;   (let* (;;(kb (consolidate-cgraphs (make-query-test-context)))
;;          (kb (make-query-test-context))
;;          (results (query "[Person: *x]←(agnt)←[Eat]→(obj)→[Food: *y]" kb))
;;          (pass (and (= (length results) 2)
;;                     (every (lambda (r) (= (length (getf r :bindings)) 2)) results))))
;;     (when verbose
;;       (format t "~&multiple-variables: ~:[FAIL~;pass~]" pass)
;;       (when results
;;         (format-query-results results)))
;;     pass))


(defun test-query-combined-graphs (&optional verbose)
  "Query with two variables — bind who eats what."
  (let* ((kb (consolidate-cgraphs (make-query-test-context2)))
         (results (query "[PERSON: *x]←(agnt)←[DRIVE]→(dest)→[CITY: *Y]" kb))
         (zz (format t "~&results: ~s~%"  results))
         (pass (and (= (length results) 2)
                    (every (lambda (r) (= (length (getf r :bindings)) 2)) results))))
    (when verbose
      (format t "~&combined-graphs: ~:[FAIL~;pass~]" pass)
      (when results
        (format-query-results results)))
    pass))


(defun test-query-type-subsumption (&optional verbose)
  "Query with supertype — [Animate] should match [Person] graphs."
  (let* ((kb (make-query-test-context))
         (results (query "[Animate]←(agnt)←[Act]" kb))
         (pass (= (length results) 3)))
    (when verbose
      (format t "~&type-subsumption: ~:[FAIL (got ~d, expected 3)~;pass~]"
              pass (length results)))
    pass))


(defun test-query-type-subsumption-with-variable (&optional verbose)
  "Query with supertype — [Animate] should match [Person] graphs."
  (let* ((kb (make-query-test-context))
         (results (query "[Animate: ?who]←(agnt)←[Act]" kb))
         (pass (and (= (length results) 3)
                    (every (lambda (r) (= (length (getf r :bindings)) 1)) results))))
    (when verbose
      (format t "~&type-subsumption: ~:[FAIL (got ~d, expected 3)~;pass~]"
              pass (length results)))
    pass))


(defun test-query-type-subsumption-with-multiple-variables (&optional verbose)
  "Query with supertype — [Animate] should match [Person] graphs."
  (let* ((kb (make-query-test-context))
         ;;(results (query "[Animate: ?who]←(agnt)←[Act]" kb))
         (results (query "[Person: *x]←(agnt)←[ACT]→(obj)→[Food: *y]" kb))
         (pass (and (= (length results) 3)
                    (every (lambda (r) (= (length (getf r :bindings)) 1)) results))))
    (when verbose
      (format t "~&type-subsumption: ~:[FAIL (got ~d, expected 3)~;pass~]"
              pass (length results)))
    pass))





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MAIN TEST RUNNER
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun query-test (&optional verbose)
  "Run all query tests. Returns T if all pass, NIL otherwise."
  (with-test-types
    (let ((pass t)
          (*allow-dynamic-individual-creation* t))
      (when verbose
        (format t "~&~%=== Query Tests ===~%"))
      (dolist (test-fn '(test-query-simple-match
                         test-query-no-match
                         test-query-variable-bindings
                         test-query-multiple-variables
                         ;; test-query-multiple-variables2
                         ;; test-query-combined-graphs
                         test-query-type-subsumption))
        (let ((result (funcall test-fn verbose)))
          (setf pass (and pass result))))
      (when verbose
        (format t "~&~%Overall: ~:[SOME TESTS FAILED~;ALL TESTS PASSED~]~%" pass))
      pass)))
