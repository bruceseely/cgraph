;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Tests for Graph Query System
;;;

(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST UTILITIES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun setup-query-test-types ()
  (ensure-concept-types-exist
   '((:label entity :supertypes (⊤))
     (:label physobj :supertypes (entity))
     (:label animate :supertypes (entity))
     (:label animal :supertypes (animate))
     (:label person :supertypes (animal))
     (:label event :supertypes (situation))
     (:label act :supertypes (event))
     (:label eat :supertypes (act))
     (:label give :supertypes (act))
     (:label drive :supertypes (act))
     (:label food :supertypes (entity physobj))
     (:label pie :supertypes (food))
     (:label cake :supertypes (food))
     (:label characteristic :supertypes (⊤))
     (:label attribute :supertypes (characteristic))
     (:label manner :supertypes (characteristic))
     (:label fast :supertypes (manner))))

  (ensure-relation-types-exist
   '((:label agnt :source-types act :dest-type animate)
     (:label obj  :source-types act :dest-type entity)
     (:label manr :source-types act :dest-type manner)
     (:label rcpt :source-types act :dest-type animate))))


(defun make-query-test-context ()
  "Create and populate a context for query testing."
  (let ((kb (make-context)))
    (add-graph "[Person: Sue]←(agnt)←[Eat]→(obj)→[Pie]" kb)
    (add-graph "[Person: Tom]←(agnt)←[Eat]→(obj)→[Cake]" kb)
    (add-graph "[Person: Pat]←(agnt)←[Drive]→(manr)→[Fast]" kb)
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
  (let ((pass t)
        (*allow-dynamic-individual-creation* t))

    (setup-query-test-types)

    (when verbose
      (format t "~&~%=== Query Tests ===~%"))
    (dolist (test-fn '(test-query-simple-match
                       test-query-no-match
                       test-query-variable-bindings
                       test-query-multiple-variables
                       test-query-type-subsumption))
      (let ((result (funcall test-fn verbose)))
        (setf pass (and pass result))))
    (when verbose
      (format t "~&~%Overall: ~:[SOME TESTS FAILED~;ALL TESTS PASSED~]~%" pass))
    pass))
