;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  coreference tests  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-coref-basic (&optional verbose)
  "Test basic co-reference label parsing and linking"
  (initialize-variables)
  (initialize-coreferences)
  (initialize-context *context*)

  ;; Parse a graph with co-reference labels
  ;; Note: coref labels must be in the referent field (after the colon)
  (let* ((g1 (pcg "[person: John ?j]-(poss)->[cat: ?c]")))
    ;; Check that the coref labels were registered
    (assert (coref-label-node :j) nil "Coref label ?j should be registered")
    (assert (coref-label-node :c) nil "Coref label ?c should be registered")

    ;; Check that the concepts have the labels
    (let ((john-concept (coref-label-node :j))
          (cat-concept (coref-label-node :c)))
      (assert (eq (concept-coref-label john-concept) :j) nil "John concept should have label ?j")
      (assert (eq (concept-coref-label cat-concept) :c) nil "Cat concept should have label ?c")

      ;; At this point, no coreference links yet (only defining occurrences)
      (assert (null (coreference john-concept)) nil "John should have no coreference links yet")
      (assert (null (coreference cat-concept)) nil "Cat should have no coreference links yet")))

  (when verbose
    (format t "~&test-coref-basic passed~%"))
  t)


(defun test-coref-nested-graph (&optional verbose)
  "Test co-reference linking between outer and nested graph concepts"
  (initialize-variables)
  (initialize-coreferences)
  (initialize-context *context*)

  ;; Parse a graph with nested context and co-reference
  ;; The outer [cat: ?c] and inner [cat: ?c] should be linked
  (let* ((g1 (pcg "[person: John]-(poss)->[cat: ?c] (expr)<-[belief: [cat: ?c]->(attr)->[size: large]].")))

    ;; Check that coref label was registered
    (assert (coref-label-node :c) nil "Coref label ?c should be registered")

    ;; The defining concept should be the outer cat
    (let ((defining-cat (coref-label-node :c)))
      ;; The defining cat should now have a coreference link to the inner cat
      (assert (not (null (coreference defining-cat))) nil
              "Outer cat should have coreference link to inner cat")

      ;; The inner cat (in coreference list) should link back
      (let ((inner-cat (car (coreference defining-cat))))
        (assert (member defining-cat (coreference inner-cat) :test #'eq) nil
                "Inner cat should have coreference link back to outer cat"))))

  (when verbose
    (format t "~&test-coref-nested-graph passed~%"))
  t)


(defun test-coref-formatting (&optional verbose)
  "Test that co-reference labels are formatted correctly"
  (initialize-variables)
  (initialize-coreferences)
  (initialize-context *context*)

  (let* ((g1 (pcg "[person: John ?j]-(poss)->[cat: ?c]"))
         (john-concept (coref-label-node :j))
         (cat-concept (coref-label-node :c)))

    ;; Check that the formatted output includes the coref labels
    (let ((john-text (format-concept john-concept))
          (cat-text (format-concept cat-concept)))
      (assert (search "?j" john-text) nil
              (format nil "John format should include ?j, got: ~a" john-text))
      (assert (search "?c" cat-text) nil
              (format nil "Cat format should include ?c, got: ~a" cat-text))))

  (when verbose
    (format t "~&test-coref-formatting passed~%"))
  t)


(defun test-coref-link-method (&optional verbose)
  "Test the link-coreference method directly"
  (initialize-context *context*)

  (let ((c1 (make-concept 'cat nil))
        (c2 (make-concept 'cat nil)))

    ;; Link them
    (link-coreference c1 c2)

    ;; Check bidirectional linking
    (assert (member c2 (coreference c1) :test #'eq) nil "c1 should have c2 in coreference")
    (assert (member c1 (coreference c2) :test #'eq) nil "c2 should have c1 in coreference")

    ;; Linking same pair again should not duplicate
    (link-coreference c1 c2)
    (assert (= 1 (length (coreference c1))) nil "Should not duplicate coreference entries"))

  (when verbose
    (format t "~&test-coref-link-method passed~%"))
  t)


(defun coreference-test (&optional verbose)
  "Run all coreference tests"
  (when verbose
    (format t "~&~%Running coreference tests...~%"))

  (load-test-types)
  (and
   (test-coref-link-method verbose)
   (test-coref-basic verbose)
   (test-coref-formatting verbose)
   (test-coref-nested-graph verbose)
   ;;(format t "~&All coreference tests passed!~%")
   ))
