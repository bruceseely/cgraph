;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Decomposition -- Sowa's Rule 6, second half.
;;
;;  "The utterance path is a cyclic walk that visits every node of the graph
;;   and returns to the concept that represents the main predicate. If a graph
;;   is complicated, rules of inference may break it into multiple simpler
;;   graphs before expressing it in a sentence."
;;
;;  The first half is the realizer's business and is already done. This file is
;;  the second: breaking one graph into several, so a sentence that would have
;;  been unreadable becomes two that are not.
;;
;;  WHAT MAKES IT SOUND. Breaking up is JOIN run backwards. Sowa's join takes
;;  two graphs sharing a concept and returns one; so cutting one graph at a
;;  shared concept returns two, and the two conjoined say what the one said --
;;  PROVIDED the cut concept keeps its identity in both pieces. An individual
;;  carries its own identity. A generic does not, and splitting [DOG] into two
;;  copies asserts two dogs where the graph had one, so the cut has to leave a
;;  coreference label behind.
;;
;;  That gives the contract, and it is checkable rather than argued:
;;  MAXIMAL-JOIN of the pieces reproduces the original.
;;
;;  WHERE IT IS LEGITIMATE. Only at a CUT CONCEPT -- one whose removal
;;  disconnects the graph. Everywhere else the "split" copies a concept without
;;  separating anything: the pieces stay joined by some other path, so nothing
;;  was simplified and a node was duplicated for no reason. The graph itself
;;  says where it can come apart, which is why this file starts with finding
;;  those places rather than with a complexity heuristic.
;;
;;  WHEN TO DO IT AT ALL is deliberately not here yet. See
;;  notes/graph-to-text-todo.md: thresholds are bikeshedding-prone, and the
;;  honest order is to make the operation available and explicit first, and let
;;  real sentences that read badly say where it should fire.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod concept-neighbours ((concept concept))
  "The concepts one relation away from CONCEPT.

   A relation's ARCS are the concepts it links, so this steps concept →
   relation → concept. A relation joining a concept to itself contributes
   nothing, which is why CONCEPT is excluded rather than assumed absent."
  (let ((result (list)))
    (dolist (relation (arcs concept))
      (dolist (other (arcs relation))
        (when (and (concept-p other) (not (eq other concept)))
          (pushnew other result))))
    (nreverse result)))

(defun decomposition-concepts (graph)
  "The concepts of GRAPH, however GRAPH was handed over.

   A GRAPH object, a node to traverse from, and the node list PARSE-CGRAPH
   returns are all called `a graph' by different callers here, and the entry
   points below should not each have to know which they were given."
  (typecase graph
    (graph      (collect-concepts (head graph)))
    (graph-node (collect-concepts graph))
    (cons       (remove-if-not #'concept-p graph))
    (t (error "~s is not a graph, a graph node, or a list of nodes." graph))))

(defun concepts-reachable-from (start &key avoid)
  "The concepts reachable from START without passing through AVOID.

   Concept-to-concept reachability, hopping over the relations between them.
   AVOID is the concept being tested as a cut: removing it from the walk is
   what makes the remaining components visible."
  (let ((seen (list))
        (pending (list start)))
    (loop while pending
          for concept = (pop pending)
          unless (or (member concept seen) (eq concept avoid))
            do (push concept seen)
               (dolist (neighbour (concept-neighbours concept))
                 (unless (or (member neighbour seen) (eq neighbour avoid))
                   (push neighbour pending))))
    (nreverse seen)))

(defun graph-components-without (graph concept)
  "The connected components GRAPH falls into when CONCEPT is removed, as lists
   of concepts. One component means CONCEPT holds nothing together."
  (let ((remaining (remove concept (decomposition-concepts graph)))
        (components (list)))
    (loop while remaining
          do (let ((component (concepts-reachable-from (first remaining)
                                                       :avoid concept)))
               (push component components)
               (setf remaining (set-difference remaining component))))
    (nreverse components)))

(defmethod cut-concept-p ((concept concept) graph)
  "True when removing CONCEPT would break GRAPH into more than one piece.

   The one place a decomposition may cut. Two neighbours are necessary and not
   sufficient -- a concept in a cycle has two and holds nothing together, since
   the rest of the ring still connects them."
  (and (> (length (concept-neighbours concept)) 1)
       (> (length (graph-components-without graph concept)) 1)))

(defun cut-concepts (graph)
  "Every concept in GRAPH whose removal disconnects it, in graph order.

   These are the graph's own account of where it can be taken apart, as
   opposed to anywhere a concept happens to be shared. A graph with none --
   a chain of one clause, a ring -- cannot be decomposed at all, and that is
   an answer rather than a failure."
  (remove-if-not (lambda (concept) (cut-concept-p concept graph))
                 (decomposition-concepts graph)))
