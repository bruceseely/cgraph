;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Tests for Type Definitions with Lambda Expressions

(in-package #:conceptual-graphs)


(defun setup-type-definition-tests ()
  "Initialize the system for type definition testing"
  (initialize-variables)
  (initialize-individuals)
  (clear-id-cache)
  ;; Ensure the pet-owner type exists with its definition,
  ;; since the user's types file may not include it.
  (unless (get-concept-type 'pet-owner)
    (define-concept-type :label 'pet-owner
                         :supertypes '(person)
                         :definition "[PERSON: *lambda]->(poss)->[PET]")))


(defun test-td (test-name test-function &optional verbose)
  "Run a type definition test and report results"
  (let ((result (handler-case
                    (progn
                      (setup-type-definition-tests)
                      (funcall test-function verbose))
                  (error (e)
                    (when verbose
                      (format t "~&>> ERROR in ~A:~%~A~%" test-name e))
                    nil))))
    (when verbose
      (format t "~&~A: ~:[FAILED ****~;PASSED~]~%" test-name result))
    result))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Definition String Stored
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-definition-string-stored (&optional verbose)
  "Verify that definition-string is non-nil on types that have one"
  (let ((pet-owner-type (get-concept-type 'pet-owner)))
    (when verbose
      (format t "~&pet-owner type: ~a~%" pet-owner-type)
      (format t "~&definition-string: ~a~%" (definition-string pet-owner-type)))
    (and pet-owner-type
         (not (null (definition-string pet-owner-type))))))

(defun test-no-definition-string (&optional verbose)
  "Verify that types without a definition have nil definition-string"
  (let ((dog-type (get-concept-type 'dog)))
    (when verbose
      (format t "~&dog type: ~a~%" dog-type)
      (format t "~&definition-string: ~a~%" (definition-string dog-type)))
    (and dog-type
         (null (definition-string dog-type)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Definition Parsing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-definition-parsing (&optional verbose)
  "Verify ensure-definition-parsed produces a type-definition with correct lambda concept type"
  (let* ((pet-owner-type (get-concept-type 'pet-owner))
         (type-def (ensure-definition-parsed pet-owner-type)))
    (when verbose
      (format t "~&type-def: ~a~%" type-def)
      (when type-def
        (format t "~&lambda-concept: ~a~%" (lambda-concept type-def))
        (format t "~&lambda type: ~a~%" (concept-type (lambda-concept type-def)))))
    (and type-def
         (typep type-def 'type-definition)
         (not (null (lambda-concept type-def)))
         ;; The lambda concept should be of type PERSON (the supertype of PET-OWNER)
         (types-equal (concept-type (lambda-concept type-def))
                      (get-concept-type 'person)))))

(defun test-definition-caching (&optional verbose)
  "Verify that parsing is cached — second call returns same object"
  (let* ((pet-owner-type (get-concept-type 'pet-owner))
         (type-def1 (ensure-definition-parsed pet-owner-type))
         (type-def2 (ensure-definition-parsed pet-owner-type)))
    (when verbose
      (format t "~&type-def1 eq type-def2: ~a~%" (eq type-def1 type-def2)))
    (and type-def1 type-def2
         (eq type-def1 type-def2))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Expand Generic Concept
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-expand-generic-concept (&optional verbose)
  "[PET-OWNER] expands to [PERSON]->(poss)->[PET]"
  (let* ((*allow-dynamic-individual-creation* t)
         (graph (parse-cgraph "[PET-OWNER]."))
         (concept (head graph))
         (expanded (expand-type concept))
         (expanded-type (concept-type expanded)))
    (when verbose
      (format t "~&original: ~a~%" concept)
      (format t "~&expanded: ~a~%" expanded)
      (format t "~&expanded type: ~a~%" expanded-type)
      (format t "~&expanded arcs: ~a~%" (arcs expanded)))
    ;; The expanded concept should be of type PERSON
    (and (types-equal expanded-type (get-concept-type 'person))
         ;; It should have arcs (the poss relation to PET)
         (plusp (length (arcs expanded))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Expand with Referent
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-expand-with-referent (&optional verbose)
  "[PET-OWNER: Sue] expands to [PERSON: Sue]->(poss)->[PET]"
  (let* ((*allow-dynamic-individual-creation* t)
         (graph (parse-cgraph "[PET-OWNER: Sue]."))
         (concept (head graph))
         (original-referent (referent concept))
         (expanded (expand-type concept))
         (expanded-type (concept-type expanded))
         (expanded-referent (referent expanded)))
    (when verbose
      (format t "~&original referent: ~a~%" original-referent)
      (format t "~&expanded: ~a~%" expanded)
      (format t "~&expanded type: ~a~%" expanded-type)
      (format t "~&expanded referent: ~a~%" expanded-referent))
    ;; The expanded concept should be of type PERSON with Sue as referent
    (and (types-equal expanded-type (get-concept-type 'person))
         (not (null expanded-referent))
         (eq expanded-referent original-referent))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Expand Preserves Arcs
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-expand-preserves-arcs (&optional verbose)
  "Original concept's relations transfer to expanded lambda concept"
  (let* ((*allow-dynamic-individual-creation* t)
         (graph (parse-cgraph "[PET-OWNER: Sue]<-(agnt)<-[GIVE]->(obj)->[DOG: Spot]."))
         (concept (head graph))
         (original-arc-count (length (arcs concept)))
         (expanded (expand-type concept))
         (expanded-arcs (arcs expanded)))
    (when verbose
      (format t "~&original arc count: ~a~%" original-arc-count)
      (format t "~&expanded: ~a~%" expanded)
      (format t "~&expanded arcs: ~a~%" expanded-arcs)
      (format t "~&expanded arc count: ~a~%" (length expanded-arcs)))
    ;; The expanded concept should have both:
    ;; - the original arc (agnt from GIVE)
    ;; - the definition arc (poss to PET)
    (and (types-equal (concept-type expanded) (get-concept-type 'person))
         ;; More arcs than the original (definition arcs + original arcs)
         (> (length expanded-arcs) original-arc-count))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  No Definition Returns Original
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-no-definition-returns-original (&optional verbose)
  "[DOG: Spot] (no definition) returns unchanged"
  (let* ((*allow-dynamic-individual-creation* t)
         (graph (parse-cgraph "[DOG: Spot]."))
         (concept (head graph))
         (expanded (expand-type concept)))
    (when verbose
      (format t "~&concept: ~a~%" concept)
      (format t "~&expanded: ~a~%" expanded)
      (format t "~&same?: ~a~%" (eq concept expanded)))
    ;; Should return the same concept object (no definition to expand)
    (eq concept expanded)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Master Test Function
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun type-definition-test (&optional verbose)
  "Run all type definition tests"
  (when verbose
    (format t "~&~%==========================================~%")
    (format t "~&=== TYPE DEFINITION TEST SUITE ===~%")
    (format t "~&==========================================~%"))


  (ensure-concept-types-exist
   '((:label mobile-entity :supertypes (physobj))
     (:label animate :supertypes (entity))
     (:label animal :supertypes (animate mobile-entity))
     (:label pet :supertypes (animal))
     (:label person :supertypes (animal))
     (:label pet-owner :supertypes (person) :definition "[PERSON: *lambda]->(poss)->[PET]")
     (:label give :supertypes (act) :canonical-graph "[GIVE]- (agnt)→[ANIMATE] (rcpt)→[ANIMATE] (obj)→[ENTITY].")
     (:label dog :supertypes (animal))))

  (ensure-relation-types-exist
   '((:label agnt  :source-types act :dest-type animate :desc "agent - links [ACT] to [ANIMATE], where [ANIMATE] is the actor of the [ACT]")
     (:label obj :source-types act :dest-type entity :desc "object - links an [ACT] to an [ENTITY], which is acted upon")))

 (and (test-td "Definition String Stored" #'test-definition-string-stored verbose)
      (test-td "No Definition String" #'test-no-definition-string verbose)
      (test-td "Definition Parsing" #'test-definition-parsing verbose)
      (test-td "Definition Caching" #'test-definition-caching verbose)
      (test-td "Expand Generic Concept" #'test-expand-generic-concept verbose)
      (test-td "Expand With Referent" #'test-expand-with-referent verbose)
      (test-td "Expand Preserves Arcs" #'test-expand-preserves-arcs verbose)
      (test-td "No Definition Returns Original" #'test-no-definition-returns-original verbose)))
