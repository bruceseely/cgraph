;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  negative context tests  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-neg-parse-basic (&optional verbose)
  "Test parsing ~[Proposition: [graph]]"
  (initialize-variables)
  (initialize-coreferences)
  (initialize-context *context*)

  (let* ((graph (pcg "~[Proposition: [Cat]->(on)->[Mat]]"))
         (head-concept (head graph)))

    (assert (not (null head-concept)) nil "Head concept should not be nil")
    (assert (negated head-concept) nil "Head concept should be negated")
    (assert (types-equal (concept-type head-concept)
                         (get-concept-type 'proposition))
            nil "Head concept type should be Proposition"))

  (when verbose
    (format t "~&test-neg-parse-basic passed~%"))
  t)


(defun test-neg-format-roundtrip (&optional verbose)
  "Test that negated concepts format back with ~ prefix"
  (initialize-variables)
  (initialize-coreferences)
  (initialize-context *context*)

  (let* ((graph (pcg "~[Proposition: [Cat]->(on)->[Mat]]"))
         (head-concept (head graph))
         (formatted (format-concept head-concept)))

    (assert (eql (char formatted 0) #\~) nil
            (format nil "Formatted negated concept should start with ~~, got: ~a" formatted))
    (assert (eql (char formatted 1) #\[) nil
            (format nil "Formatted negated concept should have [ after ~~, got: ~a" formatted)))

  (when verbose
    (format t "~&test-neg-format-roundtrip passed~%"))
  t)


(defun test-neg-nested (&optional verbose)
  "Test nested negation (if-then pattern)"
  (initialize-variables)
  (initialize-coreferences)
  (initialize-context *context*)

  (let* ((graph (pcg "~[Proposition: [Dog: *x]<-(agnt)<-[Bark] ~[Proposition: [Dog: ?x]->(attr)->[Noisy]]]"))
         (head-concept (head graph)))

    (assert (negated head-concept) nil "Outer proposition should be negated")

    ;; Find the inner negated proposition. It stands beside the outer graph,
    ;; connected to nothing, so it is not in the graph; GRAPH-SIDE-CONTEXTS
    ;; finds it. This used to look for "a negated concept in the inner
    ;; context", and the one it found was the OUTER proposition -- the reader
    ;; makes a context's own concept inside that context -- so it passed
    ;; whether or not the inner negation was there.
    (let* ((inner-graph (graph-referent head-concept))
           (inner-nodes (when inner-graph (nodes inner-graph))))
      (assert (not (null inner-graph)) nil "Outer proposition should have a graph referent")
      (let ((inner-neg (first (graph-side-contexts inner-graph))))
        (assert (not (null inner-neg)) nil "Should find the inner negation beside the outer graph")
        (assert (not (eq inner-neg head-concept)) nil "The inner negation is not the outer one")
        (assert (negated inner-neg) nil "The inner proposition should be negated")
        ;; The negated concept should be a Proposition
        (assert (types-equal (concept-type inner-neg)
                             (get-concept-type 'proposition))
                nil "Inner negated concept should be a Proposition")
        ;; Non-negated concepts should NOT be marked negated
        (let ((non-neg (find-if (lambda (n)
                                  (and (concept-p n) (not (negated n))))
                                inner-nodes)))
          (assert (not (null non-neg)) nil "Should have non-negated concepts in the inner graph")))))

  (when verbose
    (format t "~&test-neg-nested passed~%"))
  t)


(defun test-neg-context-flag (&optional verbose)
  "Test that child context of negated concept is marked negated"
  (initialize-variables)
  (initialize-coreferences)
  (initialize-context *context*)

  (let* ((graph (pcg "~[Proposition: [Cat]->(on)->[Mat]]"))
         (head-concept (head graph))
         (child-graph (graph-referent head-concept)))

    (assert (not (null child-graph)) nil "Should have a graph referent")
    ;; The child context was created with :negated t
    ;; Check via the context of a concept inside the child graph
    (let* ((inner-nodes (nodes child-graph))
           (inner-concept (find-if #'concept-p inner-nodes)))
      (assert (not (null inner-concept)) nil "Should find an inner concept")
      (let ((inner-context (context inner-concept)))
        (assert (negated inner-context) nil "Child context should be marked negated"))))

  (when verbose
    (format t "~&test-neg-context-flag passed~%"))
  t)


(defun test-neg-anon-context (&optional verbose)
  "Test parsing [[graph]] as anonymous PROPOSITION context"
  (initialize-variables)
  (initialize-coreferences)
  (initialize-context *context*)

  (let* ((graph (pcg "[[Cat]->(on)->[Mat]]"))
         (head-concept (head graph)))

    (assert (not (null head-concept)) nil "Head concept should not be nil")
    (assert (not (negated head-concept)) nil "Anonymous context should not be negated")
    (assert (types-equal (concept-type head-concept)
                         (get-concept-type 'proposition))
            nil "Anonymous context type should be Proposition")
    ;; Should have a graph referent containing the inner graph
    (let ((inner-graph (graph-referent head-concept)))
      (assert (not (null inner-graph)) nil "Should have a graph referent")
      (let ((inner-nodes (nodes inner-graph)))
        (assert (>= (length inner-nodes) 2) nil
                "Inner graph should have at least 2 nodes (Cat and Mat)"))))

  (when verbose
    (format t "~&test-neg-anon-context passed~%"))
  t)


(defun test-neg-anon-negated (&optional verbose)
  "Test parsing ~[[graph]] as negated anonymous PROPOSITION context"
  (initialize-variables)
  (initialize-coreferences)
  (initialize-context *context*)

  (let* ((graph (pcg "~[[Cat]->(on)->[Mat]]"))
         (head-concept (head graph)))

    (assert (not (null head-concept)) nil "Head concept should not be nil")
    (assert (negated head-concept) nil "~[[graph]] head concept should be negated")
    (assert (types-equal (concept-type head-concept)
                         (get-concept-type 'proposition))
            nil "~[[graph]] type should be Proposition")
    ;; Should have a graph referent
    (let ((inner-graph (graph-referent head-concept)))
      (assert (not (null inner-graph)) nil "Should have a graph referent")
      ;; The child context should be marked negated
      (let* ((inner-nodes (nodes inner-graph))
             (inner-concept (find-if #'concept-p inner-nodes)))
        (assert (not (null inner-concept)) nil "Should find an inner concept")
        (let ((inner-context (context inner-concept)))
          (assert (negated inner-context) nil "Child context should be marked negated")))))

  (when verbose
    (format t "~&test-neg-anon-negated passed~%"))
  t)


(defun test-neg-anon-equivalence (&optional verbose)
  "Test that ~[[graph]] and ~[Proposition: [graph]] produce equivalent results"
  (initialize-variables)
  (initialize-coreferences)
  (initialize-context *context*)

  (let* ((graph1 (pcg "~[[Cat]->(on)->[Mat]]"))
         (head1 (head graph1)))

    (initialize-variables)
    (initialize-coreferences)
    (initialize-context *context*)

    (let* ((graph2 (pcg "~[Proposition: [Cat]->(on)->[Mat]]"))
           (head2 (head graph2)))

      ;; Both should be negated PROPOSITION concepts
      (assert (negated head1) nil "Anon form should be negated")
      (assert (negated head2) nil "Explicit form should be negated")
      (assert (types-equal (concept-type head1) (concept-type head2)) nil
              "Both should have same concept type (Proposition)")))

  (when verbose
    (format t "~&test-neg-anon-equivalence passed~%"))
  t)


(defun test-neg-if-then-prints (&optional verbose)
  "An if-then prints with its consequent, and reads back the same.

   The inner negation of ~[A ~[B]] is connected to nothing, so it is not in
   the outer graph, which is what the printer printed: the \"then\" was gone
   from the text, and from anything copied by printing and reading back. And
   a *x whose ?x partner was only in that inner negation printed without its
   label, so even once the negation was printed the coreference was lost."
  (initialize-variables)
  (initialize-coreferences)
  (initialize-context *context*)
  (let* ((source "~[Proposition: [Dog: *x]<-(agnt)<-[Bark] ~[Proposition: [Dog: ?x]->(attr)->[Noisy]]]")
         (once (format-cgraph (pcg source)))
         (twice (format-cgraph (pcg once))))
    (assert (search "NOISY" once) nil
            (format nil "The consequent should be printed, got: ~a" once))
    (assert (string= once twice) nil
            (format nil "Printing should be a fixed point:~%~a~%~a" once twice)))
  (let* ((source "~[[EAT]- (agnt)->[CAT: *c] (obj)->[FOOD] ~[[CAT: ?c]->(attr)->[OLD]]]")
         (back (pcg (format-cgraph (pcg source))))
         (inner (graph-referent (head back)))
         (cat-of (lambda (graph)
                   (find-if (lambda (n) (and (concept-p n)
                                             (string-equal (label (concept-type n)) "CAT")))
                            (nodes graph))))
         (cat (funcall cat-of inner))
         (other-cat (let ((side (first (graph-side-contexts inner))))
                      (and side (funcall cat-of (graph-referent side))))))
    (assert (and cat other-cat (member other-cat (coreference cat))) nil
            "The two cats should still be coreferent after printing and reading back"))
  (when verbose
    (format t "~&test-neg-if-then-prints passed~%"))
  t)


(defun negative-context-test (&optional verbose)
  "Run all negative context tests"
  (with-test-types
    (when verbose
      (format t "~&~%Running negative context tests...~%"))
    (and
     (test-neg-parse-basic verbose)
     (test-neg-format-roundtrip verbose)
     (test-neg-nested verbose)
     (test-neg-if-then-prints verbose)
     (test-neg-context-flag verbose)
     (test-neg-anon-context verbose)
     (test-neg-anon-negated verbose)
     (test-neg-anon-equivalence verbose))))
