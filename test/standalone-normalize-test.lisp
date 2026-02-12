;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-
;;;
;;; Standalone test for normalize-cgraph-string function
;;; This file can be loaded independently of the full cgraph system
;;;

(defpackage :cgraph-normalize-test
  (:use :cl))

(in-package :cgraph-normalize-test)


;;; The normalize function (standalone version)
(defun normalize-cgraph-string (graph-string &key (concept-case :upcase) (relation-case :downcase))
  "Normalize the case of concept-type and relation-type labels in a conceptual graph string.

   Concept-type labels are text between '[' and ']' (or '[' and ':' if a ':' is present).
   Relation-type labels are text between '(' and ')'.

   :concept-case - either :upcase (default) or :downcase
   :relation-case - either :upcase or :downcase (default)"
  (let ((result (make-array (length graph-string) :element-type 'character :fill-pointer 0 :adjustable t))
        (i 0)
        (len (length graph-string)))

    (flet ((case-convert (text case-type)
             (ecase case-type
               (:upcase (string-upcase text))
               (:downcase (string-downcase text)))))

      (loop while (< i len) do
        (let ((ch (char graph-string i)))
          (cond
            ;; Handle concept: [TYPE...] or [TYPE:...]
            ((char= ch #\[)
             (vector-push-extend ch result)
             (incf i)
             ;; Read until we hit ':' or ']'
             (let ((type-start i)
                   (type-end nil))
               (loop while (and (< i len)
                               (not type-end)) do
                 (let ((current (char graph-string i)))
                   (cond
                     ((or (char= current #\:) (char= current #\]))
                      (setf type-end i)
                      ;; Convert the type label
                      (let* ((type-text (subseq graph-string type-start type-end))
                             (normalized (case-convert type-text concept-case)))
                        (loop for c across normalized do
                          (vector-push-extend c result)))
                      ;; Don't increment i here - we'll handle the ':' or ']' in next iteration
                      )
                     (t
                      (incf i)))))))

            ;; Handle relation: (TYPE)
            ((char= ch #\()
             (vector-push-extend ch result)
             (incf i)
             ;; Read until we hit ')'
             (let ((type-start i)
                   (type-end nil))
               (loop while (and (< i len)
                               (not type-end)) do
                 (let ((current (char graph-string i)))
                   (cond
                     ((char= current #\))
                      (setf type-end i)
                      ;; Convert the type label
                      (let* ((type-text (subseq graph-string type-start type-end))
                             (normalized (case-convert type-text relation-case)))
                        (loop for c across normalized do
                          (vector-push-extend c result)))
                      ;; Don't increment i here - we'll handle the ')' in next iteration
                      )
                     (t
                      (incf i)))))))

            ;; All other characters pass through unchanged
            (t
             (vector-push-extend ch result)
             (incf i))))))

    (coerce result 'string)))


;;; Test functions
(defun test-normalize-basic-concepts ()
  "Test basic concept normalization with default upcase"
  (let* ((input "[person]-(agnt)->[eat]")
         (expected "[PERSON]-(agnt)->[EAT]")
         (result (normalize-cgraph-string input)))
    (values (string= result expected) input expected result)))


(defun test-normalize-basic-relations ()
  "Test basic relation normalization with default downcase"
  (let* ((input "[PERSON]-(AGNT)->[EAT]")
         (expected "[PERSON]-(agnt)->[EAT]")
         (result (normalize-cgraph-string input)))
    (values (string= result expected) input expected result)))


(defun test-normalize-concepts-with-referents ()
  "Test concepts with referents - only type label should be normalized"
  (let* ((input "[person:John]-(agnt)->[eat:quickly]")
         (expected "[PERSON:John]-(agnt)->[EAT:quickly]")
         (result (normalize-cgraph-string input)))
    (values (string= result expected) input expected result)))


(defun test-normalize-mixed-case ()
  "Test mixed case normalization"
  (let* ((input "[PeRsOn:Sue]<-(AgNt)<-[GiVe]->(OBJ)->[DoG:Spot]")
         (expected "[PERSON:Sue]<-(agnt)<-[GIVE]->(obj)->[DOG:Spot]")
         (result (normalize-cgraph-string input)))
    (values (string= result expected) input expected result)))


(defun test-normalize-downcase-concepts ()
  "Test concept normalization with downcase option"
  (let* ((input "[PERSON:John]-(agnt)->[EAT]")
         (expected "[person:John]-(agnt)->[eat]")
         (result (normalize-cgraph-string input :concept-case :downcase)))
    (values (string= result expected) input expected result)))


(defun test-normalize-upcase-relations ()
  "Test relation normalization with upcase option"
  (let* ((input "[PERSON]-(agnt)->[EAT]")
         (expected "[PERSON]-(AGNT)->[EAT]")
         (result (normalize-cgraph-string input :relation-case :upcase)))
    (values (string= result expected) input expected result)))


(defun test-normalize-both-custom-cases ()
  "Test both custom case options together"
  (let* ((input "[PERSON:John]-(AGNT)->[EAT:Quickly]")
         (expected "[person:John]-(AGNT)->[eat:Quickly]")
         (result (normalize-cgraph-string input :concept-case :downcase :relation-case :upcase)))
    (values (string= result expected) input expected result)))


(defun test-normalize-complex-graph ()
  "Test complex graph with multiple concepts and relations"
  (let* ((input "[person: Sue]<-(agnt)<-[give]-(rcpt)->[dog: Spot]<-(agnt)<-[eat]-(obj)->[food]")
         (expected "[PERSON: Sue]<-(agnt)<-[GIVE]-(rcpt)->[DOG: Spot]<-(agnt)<-[EAT]-(obj)->[FOOD]")
         (result (normalize-cgraph-string input)))
    (values (string= result expected) input expected result)))


(defun test-normalize-with-arrows ()
  "Test normalization preserves arrow characters"
  (let* ((input "[person:John]->(agnt)->[eat]<-(obj)<-[cake]")
         (expected "[PERSON:John]->(agnt)->[EAT]<-(obj)<-[CAKE]")
         (result (normalize-cgraph-string input)))
    (values (string= result expected) input expected result)))


(defun test-normalize-empty-referent ()
  "Test concept with colon but empty referent"
  (let* ((input "[person:]-(agnt)->[eat]")
         (expected "[PERSON:]-(agnt)->[EAT]")
         (result (normalize-cgraph-string input)))
    (values (string= result expected) input expected result)))


(defun test-normalize-graph-string810 ()
  "Test the problematic graph-string810 with continuation and both arrow types"
  (let* ((input "[drive]-
      (agnt)→[person: Bob]
      (dest)→[city: St. Louis]
      (inst)→[chevy]-
                (attr)→[old]
                (poss)←[person: Bob].")
         (expected "[DRIVE]-
      (agnt)→[PERSON: Bob]
      (dest)→[CITY: St. Louis]
      (inst)→[CHEVY]-
                (attr)→[OLD]
                (poss)←[PERSON: Bob].")
         (result (normalize-cgraph-string input)))
    (values (string= result expected) input expected result)))


(defun normalize-test (&optional verbose)
  "Run all normalize-cgraph-string tests"
  (when verbose (format t "~%NORMALIZE-CGRAPH-STRING TEST~%~%"))
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
                 (test-normalize-graph-string810 . "Graph-string810 (with continuation and both arrows)")))
        (collect (list))
        (failed (list)))

    (dolist (test-pair tests)
      (let* ((test-fn (car test-pair))
             (test-name (cdr test-pair)))
        (multiple-value-bind (pass input expected result) (funcall test-fn)
          (when verbose
            (format t "~&~a: ~:[FAILED~;PASSED~]" test-name pass)
            (unless pass
              (format t "~%  Input:    ~s~%" input)
              (format t "  Expected: ~s~%" expected)
              (format t "  Got:      ~s~%" result)))

          (unless pass
            (push test-name failed))
          (push pass collect))))

    (let ((test-passed (every #'identity collect)))
      (when verbose
        (format t "~2&~:[Some tests FAILED~;All tests PASSED~]~%" test-passed)
        (when (not test-passed)
          (format t "Failed tests:~%")
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

;; Load this file
sbcl --load test/standalone-normalize-test.lisp

;; Run all tests
(in-package :cgraph-normalize-test)
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
