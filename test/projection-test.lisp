;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Tests for Projection Operation
;;;

(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST UTILITIES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun projection-test-case (name pattern target expected-result &optional verbose)
  "Run a single projection test case.
   expected-result: :success, :failure, or a number (for all-solutions count)"
  (let* ((result (project pattern target))
         (pass (case expected-result
                 (:success (not (null result)))
                 (:failure (null result))
                 (otherwise nil))))
    (when verbose
      ;;(format t "~2&~a:~28t~:[FAIL~;pass~]" name pass)
      (format t "~2&~:[** FAIL~;pass   ~]~6t~a" pass name)
      (format t "~35t~s (~a ~a)" expected-result pattern target)
      (when (and result (not (eq expected-result :failure)))
        (format t "~80t~a" (format-projection-mapping result))))
    pass))


(defun projection-all-test-case (name pattern target expected-count &optional verbose)
  "Run a test case checking for multiple solutions."
  (let* ((results (project pattern target :all-solutions t))
         (count (length results))
         (pass (= count expected-count)))
    (when verbose
      (format t "~&~a: ~:[FAIL (got ~d, expected ~d)~;pass (~d solutions)~]"
              name pass count expected-count count)
      (when (and verbose results)
        (dolist (mapping results)
          (format t "~&  ~a" (format-projection-mapping mapping)))))
    pass))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; BASIC CONCEPT PROJECTION TESTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-identical-generic-concepts (&optional verbose)
  "Test: [Dog] -> [Dog] should succeed"
  (projection-test-case "identical-generic"
                        "[Dog]" "[Dog]"
                        :success verbose))


(defun test-generic-to-individual (&optional verbose)
  "Test: [Dog] -> [Dog: Spot] should succeed (generic matches specific)"
  (projection-test-case "generic-to-individual"
                        "[Dog]" "[Dog: Spot]"
                        :success verbose))


(defun test-individual-mismatch (&optional verbose)
  "Test: [Dog: Spot] -> [Dog: Rex] should fail (different individuals)"
  (projection-test-case "individual-mismatch"
                        "[Dog: Spot]" "[Dog: Rex]"
                        :failure verbose))


(defun test-individual-to-generic (&optional verbose)
  "Test: [Dog: Spot] -> [Dog] should fail (specific cannot match generic)"
  (projection-test-case "individual-to-generic"
                        "[Dog: Spot]" "[Dog]"
                        :failure verbose))


(defun test-same-individual (&optional verbose)
  "Test: [Dog: Spot] -> [Dog: Spot] should succeed"
  (projection-test-case "same-individual"
                        "[Dog: Spot]" "[Dog: Spot]"
                        :success verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TYPE SUBSUMPTION TESTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-type-subsumption (&optional verbose)
  "Test: [Animal] -> [Dog] should succeed (Animal subsumes Dog)"
  (projection-test-case "type-subsumption"
                        "[Animal]." "[Dog]."
                        :success verbose))


(defun test-type-incompatible (&optional verbose)
  "Test: [Dog] -> [Person] should fail (incompatible types)"
  (projection-test-case "type-incompatible"
                        "[Dog]." "[Person]."
                        :failure verbose))


(defun test-subtype-to-supertype (&optional verbose)
  "Test: [Dog] -> [Animal] should fail (subtype cannot project to supertype)"
  (projection-test-case "subtype-to-supertype"
                        "[Dog]." "[Animal]."
                        :failure verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; RELATION PROJECTION TESTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-simple-relation (&optional verbose)
  "Test: [Person]<-(agnt)<-[Eat] -> [Person]<-(agnt)<-[Eat] should succeed"
  (projection-test-case "simple-relation"
                        "[Person]<-(agnt)<-[Eat]."
                        "[Person]<-(agnt)<-[Eat]."
                        :success verbose))


(defun test-relation-chain (&optional verbose)
  "Test: [Person]<-(agnt)<-[Eat]->(obj)->[Food] -> same should succeed"
  (projection-test-case "relation-chain"
                        "[Person]<-(agnt)<-[Eat]->(obj)->[Food]."
                        "[Person]<-(agnt)<-[Eat]->(obj)->[Food]."
                        :success verbose))


(defun test-relation-with-subsumption (&optional verbose)
  "Test: [Animate]<-(agnt)<-[Eat] -> [Person]<-(agnt)<-[Eat] should succeed"
  (projection-test-case "relation-with-subsumption"
                        "[Animate]<-(agnt)<-[Eat]."
                        "[Person]<-(agnt)<-[Eat]."
                        :success verbose))


(defun test-relation-type-mismatch (&optional verbose)
  "Test: [Person]<-(agnt)<-[Eat] -> [Person]<-(obj)<-[Eat] should fail"
  (projection-test-case "relation-type-mismatch"
                        "[Person]<-(agnt)<-[Eat]."
                        "[Person]<-(obj)<-[Eat]."
                        :failure verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; SUBGRAPH MATCHING TESTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-subgraph-match (&optional verbose)
  "Test: Pattern matches part of larger target graph"
  (projection-test-case "subgraph-match"
                        "[Person]<-(agnt)<-[Eat]."
                        "[Person: Sue]<-(agnt)<-[Eat]->(obj)->[Food]."
                        :success verbose))


(defun test-pattern-larger-than-target (&optional verbose)
  "Test: Pattern larger than target should fail"
  (projection-test-case "pattern-larger-than-target"
                        "[Person]<-(agnt)<-[Eat]->(obj)->[Food]->(chrc)->[Old]."
                        "[Person]<-(agnt)<-[Eat]->(obj)->[Food]."
                        :failure verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MULTIPLE SOLUTIONS TESTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-multiple-candidates-single-solution (&optional verbose)
  "Test with multiple possible matches but only one valid solution"
  ;; Pattern: [Person]<-(agnt)<-[Eat]
  ;; Target has one Eat relation, so only one solution
  (projection-all-test-case "multiple-candidates-single"
                            "[Person]<-(agnt)<-[Eat]."
                            "[Person: Sue]<-(agnt)<-[Eat]->(obj)->[Food]."
                            1 verbose))


(defun test-multiple-solutions (&optional verbose)
  "Test: Pattern [Dog] against target with two dogs should find 2 solutions"
  ;; Target has two Dog concepts
  (projection-all-test-case "multiple-solutions"
                            "[Dog]."
                            "[Dog: Spot]<-(rcpt)<-[Give]->(obj)->[Dog: Rex]."
                            2 verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; COMPLEX PATTERN TESTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-complex-pattern (&optional verbose)
  "Test complex pattern with multiple relations"
  (projection-test-case "complex-pattern"
                        "[Person]<-(agnt)<-[Eat]->(obj)->[Food]."
                        "[Person: Sue]<-(agnt)<-[Eat]->(obj)->[Food]->(chrc)->[Old]."
                        :success verbose))


(defun test-multi-arc-relation (&optional verbose)
  "Test pattern with relation having multiple incoming arcs"
  (projection-test-case "multi-arc-relation"
                        "[Person]<-(agnt)<-[Give]->(rcpt)->[Person]."
                        "[Person: Sue]<-(agnt)<-[Give]->(rcpt)->[Person: Tom]."
                        :success verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MAIN TEST RUNNER
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun projection-test-defs ()
  "Return list of all projection test functions"
  '(;; Basic concept tests
    test-identical-generic-concepts
    test-generic-to-individual
    test-individual-mismatch
    test-individual-to-generic
    test-same-individual
    ;; Type subsumption tests
    test-type-subsumption
    test-type-incompatible
    test-subtype-to-supertype
    ;; Relation tests
    test-simple-relation
    test-relation-chain
    test-relation-with-subsumption
    test-relation-type-mismatch
    ;; Subgraph tests
    test-subgraph-match
    test-pattern-larger-than-target
    ;; Multiple solutions tests
    test-multiple-candidates-single-solution
    test-multiple-solutions
    ;; Complex pattern tests
    test-complex-pattern
    test-multi-arc-relation))


(defun projection-test (&optional verbose)
  "Run all projection tests. Returns T if all pass, NIL otherwise."
  (let ((pass t)
        (*allow-dynamic-individual-creation* t))

    (when verbose
      (format t "~&~%=== Projection Tests ===~%"))
    (dolist (test-fn (projection-test-defs))
      (let ((result (funcall test-fn verbose)))
        (setf pass (and pass result))))
    (when verbose
      (format t "~&~%Overall: ~:[SOME TESTS FAILED~;ALL TESTS PASSED~]~2%" pass))
    pass))
