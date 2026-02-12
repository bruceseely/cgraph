;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-
;;;
;;; Testing normalize-cgraph-string function
;;;

(in-package #:conceptual-graphs)


(defun test-normalize-basic-concepts ()
  "Test basic concept normalization with default upcase"
  (let* ((input "[person]-(agnt)->[eat]")
         (expected "[PERSON]-(agnt)->[EAT]")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-basic-relations ()
  "Test basic relation normalization with default downcase"
  (let* ((input "[PERSON]-(AGNT)->[EAT]")
         (expected "[PERSON]-(agnt)->[EAT]")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-concepts-with-referents ()
  "Test concepts with referents - only type label should be normalized"
  (let* ((input "[person:John]-(agnt)->[eat:quickly]")
         (expected "[PERSON:John]-(agnt)->[EAT:quickly]")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-mixed-case ()
  "Test mixed case normalization"
  (let* ((input "[PeRsOn:Sue]<-(AgNt)<-[GiVe]->(OBJ)->[DoG:Spot]")
         (expected "[PERSON:Sue]<-(agnt)<-[GIVE]->(obj)->[DOG:Spot]")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-downcase-concepts ()
  "Test concept normalization with downcase option"
  (let* ((input "[PERSON:John]-(agnt)->[EAT]")
         (expected "[person:John]-(agnt)->[eat]")
         (result (normalize-cgraph-string input :concept-case :downcase)))
    (string= result expected)))


(defun test-normalize-upcase-relations ()
  "Test relation normalization with upcase option"
  (let* ((input "[PERSON]-(agnt)->[EAT]")
         (expected "[PERSON]-(AGNT)->[EAT]")
         (result (normalize-cgraph-string input :relation-case :upcase)))
    (string= result expected)))


(defun test-normalize-both-custom-cases ()
  "Test both custom case options together"
  (let* ((input "[PERSON:John]-(AGNT)->[EAT:Quickly]")
         (expected "[person:John]-(AGNT)->[eat:Quickly]")
         (result (normalize-cgraph-string input :concept-case :downcase :relation-case :upcase)))
    (string= result expected)))


(defun test-normalize-complex-graph ()
  "Test complex graph with multiple concepts and relations"
  (let* ((input "[person: Sue]<-(agnt)<-[give]-(rcpt)->[dog: Spot]<-(agnt)<-[eat]-(obj)->[food]")
         (expected "[PERSON: Sue]<-(agnt)<-[GIVE]-(rcpt)->[DOG: Spot]<-(agnt)<-[EAT]-(obj)->[FOOD]")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-with-arrows ()
  "Test normalization preserves arrow characters"
  (let* ((input "[person:John]->(agnt)->[eat]<-(obj)<-[cake]")
         (expected "[PERSON:John]->(agnt)->[EAT]<-(obj)<-[CAKE]")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-empty-referent ()
  "Test concept with colon but empty referent"
  (let* ((input "[person:]-(agnt)->[eat]")
         (expected "[PERSON:]-(agnt)->[EAT]")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-with-newlines ()
  "Test normalization preserves newlines and whitespace"
  (let* ((input "[person: Sue]<-(agnt)<-[give]-
   (rcpt)->[dog: Spot]")
         (expected "[PERSON: Sue]<-(agnt)<-[GIVE]-
   (rcpt)->[DOG: Spot]")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-no-concepts-or-relations ()
  "Test string with no concepts or relations"
  (let* ((input "This is just text")
         (expected "This is just text")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-empty-string ()
  "Test empty string"
  (let* ((input "")
         (expected "")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-nested-brackets ()
  "Test nested graph notation"
  (let* ((input "[person:John]-(believes)->[proposition:[cat]-(on)->[mat]]")
         (expected "[PERSON:John]-(believes)->[PROPOSITION:[cat]-(on)->[mat]]")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-multiline-graph ()
  "Test realistic multiline graph"
  (let* ((input "[PERSON:Sue]<-(agnt)<-[GIVE]-
                         (obj)->[FOOD]<-(obj)<-[EAT:*x]
                         (rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*x].")
         (expected "[PERSON:Sue]<-(agnt)<-[GIVE]-
                         (obj)->[FOOD]<-(obj)<-[EAT:*x]
                         (rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*x].")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-with-variables ()
  "Test normalization with variable notation"
  (let* ((input "[eat:*x]-(obj)->[food:*y]")
         (expected "[EAT:*x]-(obj)->[FOOD:*y]")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun test-normalize-with-numbers ()
  "Test normalization with individual IDs"
  (let* ((input "[person:#123]-(agnt)->[eat:#456]")
         (expected "[PERSON:#123]-(agnt)->[EAT:#456]")
         (result (normalize-cgraph-string input)))
    (string= result expected)))


(defun normalize-test (&optional verbose)
  "Run all normalize-cgraph-string tests"
  (when verbose (format t "~%NORMALIZE-CGRAPH-STRING TEST~%"))
  (let ((tests '((test-normalize-basic-concepts . "Basic concept normalization")
                 (test-normalize-basic-relations . "Basic relation normalization")
                 (test-normalize-concepts-with-referents . "Concepts with referents")
                 (test-normalize-mixed-case . "Mixed case normalization")
                 (test-normalize-downcase-concepts . "Downcase concepts option")
                 (test-normalize-upcase-relations . "Upcase relations option")
                 (test-normalize-both-custom-cases . "Both custom case options")
                 (test-normalize-complex-graph . "Complex graph")
                 (test-normalize-with-arrows . "Preserve arrow characters")
                 (test-normalize-empty-referent . "Empty referent")
                 (test-normalize-with-newlines . "Preserve newlines")
                 (test-normalize-no-concepts-or-relations . "No concepts or relations")
                 (test-normalize-empty-string . "Empty string")
                 (test-normalize-nested-brackets . "Nested brackets")
                 (test-normalize-multiline-graph . "Multiline graph")
                 (test-normalize-with-variables . "Variables notation")
                 (test-normalize-with-numbers . "Individual IDs")))
        (collect (list))
        (failed (list)))

    (dolist (test-pair tests)
      (let* ((test-fn (car test-pair))
             (test-name (cdr test-pair))
             (pass (funcall test-fn)))

        (when verbose
          (format t "~&~a: ~:[FAILED~;passed~]" test-name pass))

        (unless pass
          (push test-name failed))
        (push pass collect)))

    (let ((test-passed (every #'identity collect)))
      (when verbose
        (format t "~2&~:[Some tests FAILED~;All tests passed~]" test-passed)
        (when (not test-passed)
          (format t "~%Failed tests:~%")
          (dolist (name (reverse failed))
            (format t "  - ~a~%" name))))
      test-passed)))


;; Helper function to show example usage
(defun normalize-examples ()
  "Print examples of normalize-cgraph-string usage"
  (format t "~%NORMALIZE-CGRAPH-STRING EXAMPLES~%")
  (format t "~%Default (concepts uppercase, relations lowercase):~%")
  (format t "  Input:  ~s~%" "[Person:John]-(Agnt)->[EAT]")
  (format t "  Output: ~s~%" (normalize-cgraph-string "[Person:John]-(Agnt)->[EAT]"))

  (format t "~%Custom cases (concepts lowercase, relations uppercase):~%")
  (format t "  Input:  ~s~%" "[PERSON:Sue]-(agnt)->[GIVE]")
  (format t "  Output: ~s~%" (normalize-cgraph-string "[PERSON:Sue]-(agnt)->[GIVE]"
                                                       :concept-case :downcase
                                                       :relation-case :upcase))

  (format t "~%Complex graph:~%")
  (let ((input "[dog:Spot]<-(agnt)<-[eat]->(obj)->[cake]"))
    (format t "  Input:  ~s~%" input)
    (format t "  Output: ~s~%" (normalize-cgraph-string input))))


#|
Usage:

;; Run all tests
(normalize-test t)

;; Run individual test
(test-normalize-basic-concepts)

;; See examples
(normalize-examples)

;; Interactive testing
(normalize-cgraph-string "[person:John]-(agnt)->[eat:quickly]")
;; => "[PERSON:John]-(agnt)->[EAT:quickly]"

(normalize-cgraph-string "[PERSON]-(AGNT)->[EAT]" :concept-case :downcase :relation-case :upcase)
;; => "[person]-(AGNT)->[eat]"
|#
