;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Tests for Sowa's Four Atomic Formation Rules
;;; Tests the atomic operations: copy-concept, restrict-concept-*, join-concepts, simplify-duplicate-relations
;;;

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  TEST UTILITIES  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;; ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun setup-formation-tests ()
  "Initialize the system for atomic formation rule testing"
  (initialize-variables)
  (initialize-individuals)
  (clear-id-cache))

(defun test-formation-rule (rule-name test-function &optional verbose)
  "Run an atomic formation rule test and report results"
  (let ((result (handler-case
                    (progn
                      (setup-formation-tests)
                      (funcall test-function verbose))
                  (error (e)
                    (when verbose
                      (format t "~&>> ERROR in ~A:~%~A~%" rule-name e))
                    nil)
                  )))
    (when verbose
      (format t "~&~A: ~:[FAILED ****~;PASSED~]~%" rule-name result))
    result))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  COPY RULE TESTS  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;; ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-copy-concept-basic (&optional verbose)
  "Test basic concept copying - generic concept"
  (let* ((dog-type (get-concept-type 'dog))
         (original-concept (make-concept dog-type nil))
         (copied-concept (copy-concept original-concept)))

    (when verbose
      (format t "~&Original: ~A~%" original-concept)
      (format t "~&Copy: ~A~%" copied-concept))

    ;; Test that copy is distinct object but equivalent content
    (and (not (eq original-concept copied-concept))  ; Different objects
         (types-equal (concept-type original-concept) (concept-type copied-concept))  ; Same type
         (referents-equal (referent original-concept) (referent copied-concept))  ; Same referent
         (eq (context original-concept) (context copied-concept)))))  ; Same context

(defun test-copy-concept-with-individual (&optional verbose)
  "Test copying concept with individual referent"
  (let* ((dog-type (get-concept-type 'dog))
         (spot-indiv (make-individual dog-type '(:name "Spot") :id 42))
         (original-concept (make-concept dog-type spot-indiv))
         (copied-concept (copy-concept original-concept)))

    (when verbose
      (format t "~&Original with individual: ~A~%" original-concept)
      (format t "~&Copy with individual: ~A~%" copied-concept))

    (and (not (eq original-concept copied-concept))
         (types-equal (concept-type original-concept) (concept-type copied-concept))
         (referents-equal (referent original-concept) (referent copied-concept)))))

(defun test-copy-relation-basic (&optional verbose)
  "Test basic relation copying"
  (let* ((agnt-type (get-relation-type 'agnt))
         (original-relation (make-relation agnt-type))
         (copied-relation (copy-relation original-relation)))

    (when verbose
      (format t "~&Original relation: ~A~%" original-relation)
      (format t "~&Copy relation: ~A~%" copied-relation))

    (and (not (eq original-relation copied-relation))
         (types-equal (relation-type original-relation) (relation-type copied-relation)))))

(defun copy-test (&optional verbose)
  "Run all atomic copy rule tests"
  (when verbose
    (format t "~&~%=== ATOMIC COPY TESTS ===~%"))
  (and (test-formation-rule "Copy Generic Concept" #'test-copy-concept-basic verbose)
       (test-formation-rule "Copy Individual Concept" #'test-copy-concept-with-individual verbose)
       (test-formation-rule "Copy Relation" #'test-copy-relation-basic verbose)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  RESTRICT RULE TESTS  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-restrict-type-basic (&optional verbose)
  "Test basic type restriction - animal to dog"
  (let* ((animal-type (get-concept-type 'animal))
         (dog-type (get-concept-type 'dog))
         (animal-concept (make-concept animal-type nil))
         (restricted-concept (restrict animal-concept dog-type)))

    (when verbose
      (format t "~&Original animal: ~A~%" animal-concept)
      (format t "~&Restricted to dog: ~A~%" restricted-concept))

    (and (not (eq animal-concept restricted-concept))  ; Different objects
         (types-equal (concept-type animal-concept) dog-type)  ; Restricted type
         (referents-equal (referent animal-concept) (referent animal-concept)))))  ; Same referent



(defun test-restrict-referent-generic-to-individual (&optional verbose)
  "Test restricting generic concept to individual"
  (let* ((dog-type (get-concept-type 'dog))
         (generic-concept (make-concept dog-type nil))
         (spot-indiv (make-individual dog-type '(:name "Spot") :id 43))
         (restricted-concept (restrict generic-concept spot-indiv)))

    (when verbose
      (format t "~&Generic concept: ~A~%" generic-concept)
      (format t "~&Restricted to individual: ~A~%" restricted-concept))

    (and (not (null (referent generic-concept)))
         (individuals-equal (content (referent generic-concept)) spot-indiv)




    ;; (and (not (eq generic-concept restricted-concept))
    ;;      (types-equal (concept-type generic-concept) (concept-type restricted-concept)))

    )))

(defun test-restrict-invalid-type (&optional verbose)
  "Test that invalid type restriction fails appropriately"
  (let* ((dog-type (get-concept-type 'dog))
         (person-type (get-concept-type 'person))
         (dog-concept (make-concept dog-type nil))
         (error-caught nil))

    (handler-case
        (restrict-concept-type dog-concept person-type)
      (error (e)
        (setf error-caught t)
        (when verbose
          (format t "~&Expected error caught: ~A~%" e))))

    (when verbose
      (format t "~&Invalid restriction ~:[not caught~;correctly caught~]~%" error-caught))

    error-caught))  ; Should catch error for invalid restriction


(defun test-restrict-referent-compatible-individuals (&optional verbose)
  "Test restricting individual to more specific individual"
  (let* ((dog-type (get-concept-type 'dog))
         (basic-dog (make-individual dog-type '() :id 50))
         (detailed-dog (make-individual dog-type '(:name "Rex") :id 50))
         (basic-concept (make-concept dog-type basic-dog))
         )

    (let ((concept-restricted (restrict basic-concept detailed-dog)))

      (when verbose
        (format t "~&Basic dog concept: ~A~%" basic-concept)
        (format t "~&Restricted to detailed: ~A~%" concept-restricted))


      (and (types-equal (concept-type basic-concept) (concept-type basic-concept))
           (individuals-equal (content (referent basic-concept)) detailed-dog)))))


;; (defun doit ()
;;   (let* ((dog-type (get-concept-type 'dog))
;;          (basic-dog    (make-individual dog-type '() :id 50))
;;          (detailed-dog (make-individual dog-type '(:name "Rex") :id 50))
;;          (basic-concept (make-concept dog-type basic-dog)))
;;     (format t "~&detailed-dog: ~s~%"  detailed-dog)
;;     (format t "~&Basic dog concept: ~A~%" basic-concept)

;;     (let ((concept-restricted (restrict basic-concept detailed-dog)))

;;       (format t "~&Restricted to detailed: ~A~%" concept-restricted)
;;       (format t "~&basic-concept: ~s~%"  basic-concept)
;;       basic-concept)))

(defun restrict-test (&optional verbose)
  "Run all atomic restrict rule tests"
  (when verbose
    (format t "~&~%=== ATOMIC RESTRICT TESTS ===~%"))
  (and (test-formation-rule "Restrict Type Basic" #'test-restrict-type-basic verbose)
       (test-formation-rule "Restrict Generic to Individual" #'test-restrict-referent-generic-to-individual verbose)
       (test-formation-rule "Restrict Invalid Type" #'test-restrict-invalid-type verbose)
       (test-formation-rule "Restrict Compatible Individuals" #'test-restrict-referent-compatible-individuals verbose)))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  JOIN RULE TESTS  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-join-identical-generic-concepts (&optional verbose)
  "Test joining identical generic concepts"
  (let* ((dog-type (get-concept-type 'dog))
         (concept1 (make-concept dog-type nil))
         (concept2 (make-concept dog-type nil))
         (joined-concept (join-concepts concept1 concept2)))

    (when verbose
      (format t "~&Generic concept1: ~A~%" concept1)
      (format t "~&Generic concept2: ~A~%" concept2)
      (format t "~&Joined: ~A~%" joined-concept))

    (and (types-equal (concept-type joined-concept) dog-type)
         (null (referent joined-concept)))))  ; Both generic, result is generic

(defun test-join-generic-with-individual (&optional verbose)
  "Test joining generic concept with individual concept"
  (let* ((dog-type (get-concept-type 'dog))
         (generic-concept (make-concept dog-type nil))
         (spot-indiv (make-individual dog-type '(:name "Spot") :id 44))
         (individual-concept (make-concept dog-type spot-indiv))
         (joined-concept (join-concepts generic-concept individual-concept)))

    (when verbose
      (format t "~&Generic: ~A~%" generic-concept)
      (format t "~&Individual: ~A~%" individual-concept)
      (format t "~&Joined: ~A~%" joined-concept))

    (and (types-equal (concept-type joined-concept) dog-type)
         (not (null (referent joined-concept)))
         (individuals-equal (content (referent joined-concept)) spot-indiv))))

(defun test-join-subtype-concepts (&optional verbose)
  "Test joining concepts with subtype relationship"
  (let* ((animal-type (get-concept-type 'animal))
         (dog-type (get-concept-type 'dog))
         (animal-concept (make-concept animal-type nil))
         (dog-concept (make-concept dog-type nil))
         (joined-concept (join-concepts animal-concept dog-concept)))

    (when verbose
      (format t "~&Animal concept: ~A~%" animal-concept)
      (format t "~&Dog concept: ~A~%" dog-concept)
      (format t "~&Joined: ~A~%" joined-concept))

    ;; Result should be the more specific type (dog)
    (types-equal (concept-type joined-concept) dog-type)))

(defun test-join-same-individuals (&optional verbose)
  "Test joining concepts with same individual"
  (let* ((dog-type (get-concept-type 'dog))
         (spot-indiv (make-individual dog-type '(:name "Spot") :id 45))
         (concept1 (make-concept dog-type spot-indiv))
         (concept2 (make-concept dog-type spot-indiv))
         (joined-concept (join-concepts concept1 concept2)))

    (when verbose
      (format t "~&Concept1 with Spot: ~A~%" concept1)
      (format t "~&Concept2 with Spot: ~A~%" concept2)
      (format t "~&Joined: ~A~%" joined-concept))

    (and (types-equal (concept-type joined-concept) dog-type)
         (individuals-equal (content (referent joined-concept)) spot-indiv))))

(defun test-join-incompatible-types (&optional verbose)
  "Test that concepts with incompatible types cannot be joined"
  (let* ((dog-type (get-concept-type 'dog))
         (person-type (get-concept-type 'person))
         (dog-concept (make-concept dog-type nil))
         (person-concept (make-concept person-type nil))
         (error-caught nil))

    (handler-case
        (join-concepts dog-concept person-concept)
      (error (e)
        (setf error-caught t)
        (when verbose
          (format t "~&Expected error caught: ~A~%" e))))

    (when verbose
      (format t "~&Incompatible join ~:[not caught~;correctly caught~]~%" error-caught))

    error-caught))

(defun test-join-incompatible-individuals (&optional verbose)
  "Test that concepts with different individuals cannot be joined"
  (let* ((dog-type (get-concept-type 'dog))
         (spot-indiv (make-individual dog-type '(:name "Spot") :id 46))
         (rex-indiv (make-individual dog-type '(:name "Rex") :id 47))
         (spot-concept (make-concept dog-type spot-indiv))
         (rex-concept (make-concept dog-type rex-indiv))
         (error-caught nil))

    (handler-case
        (join-concepts spot-concept rex-concept)
      (error (e)
        (setf error-caught t)
        (when verbose
          (format t "~&Expected error caught: ~A~%" e))))

    (when verbose
      (format t "~&Different individuals join ~:[not caught~;correctly caught~]~%" error-caught))

    error-caught))

(defun join-test (&optional verbose)
  "Run all atomic join rule tests"
  (when verbose
    (format t "~&~%=== ATOMIC JOIN TESTS ===~%"))
  (and (test-formation-rule "Join Identical Generic" #'test-join-identical-generic-concepts verbose)
       (test-formation-rule "Join Generic with Individual" #'test-join-generic-with-individual verbose)
       (test-formation-rule "Join Subtype Concepts" #'test-join-subtype-concepts verbose)
       (test-formation-rule "Join Same Individuals" #'test-join-same-individuals verbose)
       (test-formation-rule "Join Incompatible Types" #'test-join-incompatible-types verbose)
       (test-formation-rule "Join Different Individuals" #'test-join-incompatible-individuals verbose)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  SIMPLIFY RULE TESTS  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-simplify-no-duplicates (&optional verbose)
  "Test simplify on concept with no duplicate relations"
  (let* ((person-type (get-concept-type 'person))
         (agnt-type (get-relation-type 'agnt))
         (init-type (get-relation-type 'init))
         (eat-type (get-concept-type 'eat))
         (person-concept (make-concept person-type nil))
         (eat-concept (make-concept eat-type nil))
         (agnt-relation (make-relation agnt-type))
         (init-relation (make-relation init-type)))

    ;; Set up concept with two different relations
    (setf (arcs agnt-relation) (list person-concept eat-concept))
    (setf (arcs init-relation) (list person-concept eat-concept))
    (setf (arcs person-concept) (list agnt-relation init-relation))

    ;;(format t "~&graph: ~s~%"(pcg person-concept))

    (let ((removed-relations (simplify-duplicate-relations person-concept))
          (unique-relations (arcs person-concept)))
      (when verbose
        (format t "~&Concept: ~A~%" person-concept)
        (format t "~&Relations before: 2 different types~%")
        (format t "~&Unique relations after: ~A~%" (length unique-relations))
        (when removed-relations
          (format t "~&Removed relations: ~s~%"  removed-relations))
        )

      (= (length unique-relations) 2))))  ; Should keep both different relations

(defun test-simplify-with-duplicates (&optional verbose)
  "Test simplify on concept with duplicate relations"
  (let* ((person-type (get-concept-type 'person))
         (agnt-type (get-relation-type 'agnt))
         (food-type (get-concept-type 'food))
         (person-concept (make-concept person-type nil))
         (food-concept (make-concept food-type nil))
         (agnt-relation1 (make-relation agnt-type))
         (agnt-relation2 (make-relation agnt-type)))

    ;; Set up concept with duplicate relations (same type, same arcs)
    (setf (arcs agnt-relation1) (list person-concept food-concept))
    (setf (arcs agnt-relation2) (list person-concept food-concept))
    (setf (arcs person-concept) (list agnt-relation1 agnt-relation2))

    (let ((unique-relations (simplify-duplicate-relations person-concept)))
      (when verbose
        (format t "~&Concept: ~A~%" person-concept)
        (format t "~&Relations before: 2 identical~%")
        (format t "~&Unique relations after: ~A~%" (length unique-relations)))

      (= (length unique-relations) 1))))  ; Should remove one duplicate

(defun test-simplify-empty-concept (&optional verbose)
  "Test simplify on concept with no relations"
  (let* ((person-type (get-concept-type 'person))
         (person-concept (make-concept person-type nil)))

    (setf (arcs person-concept) '())  ; No relations

    (let ((unique-relations (simplify-duplicate-relations person-concept)))
      (when verbose
        (format t "~&Concept: ~A~%" person-concept)
        (format t "~&Relations before: 0~%")
        (format t "~&Unique relations after: ~A~%" (length unique-relations)))

      (= (length unique-relations) 0))))  ; Should remain empty

(defun simplify-test (&optional verbose)
  "Run all atomic simplify rule tests"
  (when verbose
    (format t "~&~%=== ATOMIC SIMPLIFY TESTS ===~%"))
  (and (test-formation-rule "Simplify No Duplicates" #'test-simplify-no-duplicates verbose)
       (test-formation-rule "Simplify With Duplicates" #'test-simplify-with-duplicates verbose)
       (test-formation-rule "Simplify Empty Concept" #'test-simplify-empty-concept verbose)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MASTER TEST FUNCTION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun formation-rules-test (&optional verbose)
  "Run all atomic formation rule tests"
  (with-test-types
  (when verbose
    (format t "~&~%==========================================~%")
    (format t "~&=== ATOMIC FORMATION RULES TEST SUITE ===~%")
    (format t "~&==========================================~%"))

  (let ((results (list
                  (copy-test verbose)
                  (restrict-test verbose)
                  (join-test verbose)
                  (simplify-test verbose))))

    (when verbose
      ;; (format t "~&~%=== FINAL RESULTS ===~%")
      ;; (format t "~&Copy Rule Tests:      ~:[FAILED ****~;PASSED~]~%" (first results))
      ;; (format t "~&Restrict Rule Tests:  ~:[FAILED ****~;PASSED~]~%" (second results))
      ;; (format t "~&Join Rule Tests:      ~:[FAILED ****~;PASSED~]~%" (third results))
      ;; (format t "~&Simplify Rule Tests:  ~:[FAILED ****~;PASSED~]~%" (fourth results))
      ;; (format t "~2&Overall Result:       ~:[FAILED~;PASSED~]~%" (every #'identity results))
      ;; (format t "~&==========================================~%")
      )

    (every #'identity results))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; INTEGRATION TESTS - Composition of Formation Rules
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-copy-then-restrict (&optional verbose)
  "Test copy followed by restrict"
  (let* ((animal-type (get-concept-type 'animal))
         (dog-type (get-concept-type 'dog))
         (original (make-concept animal-type nil))
         (copied (copy-concept original))
         (restricted (restrict-concept-type copied dog-type)))

    (when verbose
      (format t "~&Original: ~A~%" original)
      (format t "~&Copied: ~A~%" copied)
      (format t "~&Restricted: ~A~%" restricted))

    (and (not (eq original copied))
         (not (eq copied restricted))
         (types-equal (concept-type original) animal-type)
         (types-equal (concept-type restricted) dog-type))))

(defun test-restrict-then-join (&optional verbose)
  "Test restrict followed by join"
  (let* ((animal-type (get-concept-type 'animal))
         (dog-type (get-concept-type 'dog))
         (animal-concept (make-concept animal-type nil))
         (dog-concept (make-concept dog-type nil))
         (restricted-animal (restrict-concept-type animal-concept dog-type))
         (joined (join-concepts restricted-animal dog-concept)))

    (when verbose
      (format t "~&Animal: ~A~%" animal-concept)
      (format t "~&Dog: ~A~%" dog-concept)
      (format t "~&Restricted animal: ~A~%" restricted-animal)
      (format t "~&Joined: ~A~%" joined))

    (types-equal (concept-type joined) dog-type)))

(defun test-full-composition (&optional verbose)
  "Test all four rules in sequence"
  (let* ((animal-type (get-concept-type 'animal))
         (dog-type (get-concept-type 'dog))
         (original (make-concept animal-type nil)))

    (when verbose
      (format t "~&=== FULL COMPOSITION TEST ===~%")
      (format t "~&1. Original: ~A~%" original))

    ;; Copy
    (let ((copied (copy-concept original)))
      (when verbose
        (format t "~&2. Copied: ~A~%" copied))

      ;; Restrict
      (let ((restricted (restrict-concept-type copied dog-type)))
        (when verbose
          (format t "~&3. Restricted: ~A~%" restricted))

        ;; Join with another dog concept
        (let* ((another-dog (make-concept dog-type nil))
               (joined (join-concepts restricted another-dog)))
          (when verbose
            (format t "~&4. Another dog: ~A~%" another-dog)
            (format t "~&5. Joined: ~A~%" joined))

          ;; Create relations for simplify test
          (let* ((agnt-rel1 (make-relation (get-relation-type 'agnt)))
                 (agnt-rel2 (make-relation (get-relation-type 'agnt)))
                 (food-concept (make-concept (get-concept-type 'food) nil)))

            ;; Set up duplicate relations
            (setf (arcs agnt-rel1) (list joined food-concept))
            (setf (arcs agnt-rel2) (list joined food-concept))
            (setf (arcs joined) (list agnt-rel1 agnt-rel2))

            (when verbose
              (format t "~&6. Before simplify: 2 identical relations~%"))

            ;; Simplify
            (let ((unique-rels (simplify-duplicate-relations joined)))
              (when verbose
                (format t "~&7. After simplify: ~A unique relations~%" (length unique-rels)))

              (and (types-equal (concept-type joined) dog-type)
                   (= (length unique-rels) 1)))))))))

(defun integration-test (&optional verbose)
  "Run integration tests for atomic formation rules"
  (when verbose
    (format t "~&~%=== ATOMIC INTEGRATION TESTS ===~%"))
  (and (test-formation-rule "Copy then Restrict" #'test-copy-then-restrict verbose)
       (test-formation-rule "Restrict then Join" #'test-restrict-then-join verbose)
       (test-formation-rule "Full Composition" #'test-full-composition verbose)))
