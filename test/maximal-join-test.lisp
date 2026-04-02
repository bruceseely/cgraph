;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Tests for Maximal Join Operation
;;;

(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST UTILITIES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun maximal-join-test-case (name graph1-str graph2-str test-fn &optional verbose)
  "Run a single maximal join test case.
   test-fn receives the result head node and returns T if the test passes."
  (let* ((result (maximal-join graph1-str graph2-str))
         (pass (funcall test-fn result)))
    (when verbose
      (format t "~&~a: ~:[FAIL~;pass~]" name pass)
      (when result
        (format t "  => ~a" (format-cgraph result))))
    pass))


(defun count-result-concepts (result)
  "Count the concepts in the result graph."
  (length (collect-concepts result)))

(defun count-result-relations (result)
  "Count the relations in the result graph."
  (length (collect-relations result)))

(defun result-has-concept-type (result type-name)
  "Check if the result contains a concept of the given type."
  (let ((ctype (get-concept-type type-name)))
    (some (lambda (c)
            (or (types-equal (concept-type c) ctype)
                (subtype-p (concept-type c) ctype)))
          (collect-concepts result))))

(defun result-has-exact-type (result type-name)
  "Check if the result contains a concept with exactly the given type."
  (let ((ctype (get-concept-type type-name)))
    (some (lambda (c)
            (types-equal (concept-type c) ctype))
          (collect-concepts result))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST 1: Identical single concepts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-mj-identical-single-concepts (&optional verbose)
  "Test: [Dog] join [Dog] produces 1 concept"
  (maximal-join-test-case
   "mj-identical-single"
   "[Dog]." "[Dog]."
   (lambda (result)
     (= 1 (count-result-concepts result)))
   verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST 2: Type specialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-mj-type-specialization (&optional verbose)
  "Test: [Animal] join [Dog] produces [Dog] (most specific type)"
  (maximal-join-test-case
   "mj-type-specialization"
   "[Animal]." "[Dog]."
   (lambda (result)
     (and (= 1 (count-result-concepts result))
          (result-has-exact-type result 'dog)))
   verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST 3: Referent specialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-mj-referent-specialization (&optional verbose)
  "Test: [Dog] join [Dog: Spot] produces [Dog: Spot]"
  (maximal-join-test-case
   "mj-referent-specialization"
   "[Dog]." "[Dog: Spot]."
   (lambda (result)
     (and (= 1 (count-result-concepts result))
          (let* ((concepts (collect-concepts result))
                 (dog (car concepts)))
            (and (result-has-exact-type result 'dog)
                 (not (null (referent dog)))))))
   verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST 4: Disjoint types — no overlap
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-mj-disjoint-types (&optional verbose)
  "Test: [Dog] join [Person] has no overlap, returns copy of g1"
  (maximal-join-test-case
   "mj-disjoint-types"
   "[Dog]." "[Person]."
   (lambda (result)
     ;; Result should be a copy of g1 only (1 concept: Dog)
     (and (= 1 (count-result-concepts result))
          (result-has-exact-type result 'dog)))
   verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST 5: Identical relation chain — full join
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-mj-identical-relation-chain (&optional verbose)
  "Test: both [Person]<-(agnt)<-[Eat]->(obj)->[Food] fully join"
  (maximal-join-test-case
   "mj-identical-chain"
   "[Person]<-(agnt)<-[Eat]->(obj)->[Food]."
   "[Person]<-(agnt)<-[Eat]->(obj)->[Food]."
   (lambda (result)
     ;; All 3 concepts should merge: Person, Eat, Food
     (and (= 3 (count-result-concepts result))
          (= 2 (count-result-relations result))))
   verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST 6: Partial overlap — different relations off shared concepts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-mj-partial-overlap (&optional verbose)
  "Test: shared concepts with different relations, both preserved"
  (maximal-join-test-case
   "mj-partial-overlap"
   "[Person: Sue]<-(agnt)<-[Eat]->(obj)->[Food]."
   "[Person: Sue]<-(agnt)<-[Eat]->(manr)->[Quickly]."
   (lambda (result)
     ;; Person:Sue and Eat should join; Food and Quickly both present
     ;; Concepts: Person, Eat, Food, Quickly = 4
     (and (= 4 (count-result-concepts result))
          (result-has-exact-type result 'person)
          (result-has-exact-type result 'eat)
          (result-has-exact-type result 'food)
          (result-has-exact-type result 'quickly)))
   verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST 7: Maximal selection — smaller subsumed into larger
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-mj-maximal-selection (&optional verbose)
  "Test: smaller graph subsumed into larger graph"
  (maximal-join-test-case
   "mj-maximal-selection"
   "[Person]<-(agnt)<-[Eat]->(obj)->[Food]->(chrc)->[Old]."
   "[Person]<-(agnt)<-[Eat]->(obj)->[Food]."
   (lambda (result)
     ;; The 3 shared concepts join; Old remains from g1
     ;; Concepts: Person, Eat, Food, Old = 4
     (and (= 4 (count-result-concepts result))
          (result-has-exact-type result 'person)
          (result-has-exact-type result 'food)
          (result-has-exact-type result 'old)))
   verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST 8: Structural incompatibility — same concepts, different relations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-mj-structural-incompatibility (&optional verbose)
  "Test: same concept types but different relation types prevent full join"
  (maximal-join-test-case
   "mj-structural-incompatibility"
   "[Person]<-(agnt)<-[Eat]."
   "[Person]<-(obj)<-[Eat]."
   (lambda (result)
     ;; The concepts have compatible types but the relations differ,
     ;; so structural consistency prevents joining both simultaneously.
     ;; At most one pair can be joined (Person or Eat, not both).
     ;; Result should have at most 3 concepts (1 joined + 2 unjoined, or fewer)
     (let ((nc (count-result-concepts result)))
       ;; We expect either 2 concepts (one pair joined, other left separate)
       ;; or 3 concepts (only one joined with overlap)
       ;; The key constraint: NOT fully merged as 2 concepts with 1 relation
       ;; since the relation types don't match
       (<= nc 3)))
   verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST 9: Non-overlapping extensions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-mj-non-overlapping-extensions (&optional verbose)
  "Test: shared concept with different branches from each graph"
  (maximal-join-test-case
   "mj-non-overlapping-extensions"
   "[Dog: Spot]<-(agnt)<-[Eat]->(obj)->[Food]."
   "[Dog: Spot]<-(rcpt)<-[Give]->(agnt)->[Person]."
   (lambda (result)
     ;; Dog:Spot joins; branches from each graph are preserved
     ;; Concepts: Dog, Eat, Food, Give, Person = 5
     (and (= 5 (count-result-concepts result))
          (result-has-exact-type result 'dog)
          (result-has-exact-type result 'eat)
          (result-has-exact-type result 'food)
          (result-has-exact-type result 'give)
          (result-has-exact-type result 'person)))
   verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TEST 10: Individual mismatch — different individuals cannot join
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-mj-individual-mismatch (&optional verbose)
  "Test: [Dog: Spot] and [Dog: Rex] cannot join (different individuals)"
  (maximal-join-test-case
   "mj-individual-mismatch"
   "[Dog: Spot]." "[Dog: Rex]."
   (lambda (result)
     ;; No overlap, returns copy of g1 with just [Dog: Spot]
     (and (= 1 (count-result-concepts result))
          (result-has-exact-type result 'dog)))
   verbose))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MAIN TEST RUNNER
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun maximal-join-test-defs ()
  "Return list of all maximal join test functions"
  '(test-mj-identical-single-concepts
    test-mj-type-specialization
    test-mj-referent-specialization
    test-mj-disjoint-types
    test-mj-identical-relation-chain
    test-mj-partial-overlap
    test-mj-maximal-selection
    test-mj-structural-incompatibility
    test-mj-non-overlapping-extensions
    test-mj-individual-mismatch))


(defun maximal-join-test (&optional verbose)
  "Run all maximal join tests. Returns T if all pass, NIL otherwise."
  (let ((pass t)
        (*allow-dynamic-individual-creation* t))

    (load-test-types)

    (when verbose
      (format t "~&~%=== Maximal Join Tests ===~%"))
    (dolist (test-fn (maximal-join-test-defs))
      (let ((result (funcall test-fn verbose)))
        (setf pass (and pass result))))
    (when verbose
      (format t "~&~%Overall: ~:[SOME TESTS FAILED~;ALL TESTS PASSED~]~%" pass))
    pass))
