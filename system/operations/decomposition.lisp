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
;;  WHEN TO DO IT AT ALL, and WHICH seam, is the last section of this file and
;;  is kept apart from everything above it. The difference is not tidiness:
;;  everything above is answerable from the graph, and the policy is a
;;  judgement about English. Nothing calls it on your behalf -- GRAPH-TO-TEXT
;;  still returns one sentence for one graph, and GRAPH-TO-TEXT-DECOMPOSED is
;;  the door in.
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

(defmethod concept-individual ((concept concept))
  "The individual CONCEPT refers to, or NIL for anything else."
  (let* ((referent (referent concept))
         (content  (and referent (content referent))))
    (and (individual-p content) content)))

(defmethod concepts-corefer-p ((c1 concept) (c2 concept))
  "True when C1 and C2 are two mentions of ONE thing.

   Two ways to be one thing, and the walk below has to honour both. A
   coreference link -- what `*x' and `?x' leave behind -- and one individual
   mentioned twice, which needs no label because the id is the identity."
  (or (eq c1 c2)
      (member c2 (coreference c1) :test #'eq)
      (member c1 (coreference c2) :test #'eq)
      (let ((i1 (concept-individual c1))
            (i2 (concept-individual c2)))
        (and i1 i2 (id i1) (eql (id i1) (id i2))))))

(defun referent-group (concept concepts)
  "The members of CONCEPTS that are mentions of the same thing as CONCEPT.

   Coreference makes two nodes one REFERENT without making them one NODE, so
   an arc walk sees a tree where the meaning has a cycle. Everything here works
   in groups for that reason: `Sue eats the pie she owns' is a ring, and a ring
   has nothing that holds it together, but only if the two mentions of the pie
   are understood to be the pie."
  (remove-if-not (lambda (other) (concepts-corefer-p concept other)) concepts))

(defun concepts-reachable-from (start &key avoid concepts)
  "The concepts reachable from START without passing through AVOID.

   Reachability over referents rather than nodes: arriving at any mention of a
   thing arrives at all of them, and AVOID removes every mention of what it
   names. CONCEPTS is the graph's concept list, needed because two mentions of
   one individual are related by nothing but that fact -- there is no link
   between them to follow."
  (let* ((all (or concepts (list start)))
         (blocked (when avoid (referent-group avoid all)))
         (seen (list))
         (pending (referent-group start all)))
    (flet ((blockedp (c) (member c blocked :test #'eq)))
      (loop while pending
            for concept = (pop pending)
            unless (or (member concept seen :test #'eq) (blockedp concept))
              do (push concept seen)
                 ;; Both steps out of a concept: along its arcs, and across to
                 ;; its other mentions.
                 (dolist (next (append (concept-neighbours concept)
                                       (referent-group concept all)))
                   (unless (or (member next seen :test #'eq) (blockedp next))
                     (push next pending)))))
    (nreverse seen)))

(defun graph-components-without (graph concept)
  "The connected components GRAPH falls into when CONCEPT is removed, as lists
   of concepts. One component means CONCEPT holds nothing together."
  (let* ((all (decomposition-concepts graph))
         ;; Every mention of it, not just the node named: removing one mention
         ;; of a thing and leaving another would be removing nothing.
         (remaining (set-difference all (referent-group concept all)))
         (components (list)))
    (loop while remaining
          do (let ((component (concepts-reachable-from (first remaining)
                                                       :avoid concept
                                                       :concepts all)))
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
  (let ((all (decomposition-concepts graph))
        (found (list)))
    (dolist (concept all (nreverse found))
      ;; One entry per referent, not per mention. Two mentions of Dave are one
      ;; place the graph comes apart, and offering it twice would invite
      ;; cutting the same seam twice.
      (when (and (cut-concept-p concept graph)
                 (notany (lambda (kept) (concepts-corefer-p kept concept)) found))
        (push concept found)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  The cut itself.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun share-identity (copies)
  "Make COPIES -- the several copies of one cut concept -- mentions of one
   thing rather than several things that look alike.

   An individual needs nothing done: every copy holds the same individual, and
   the id is the identity. Anything else gets a coreference label, and must:
   without one the pieces assert as many dogs as there are copies, which is not
   what the graph said. This is the whole soundness condition of the cut."
  (let ((first-copy (first copies)))
    ;; Linked whether or not a label is needed. The label is what NOTATION
    ;; requires to carry identity; the link is what the realizer's anaphora
    ;; pass reads to know a second mention is a second mention, and an
    ;; individual needs the second without needing the first.
    (dolist (other (rest copies))
      (link-coreference first-copy other))
    (unless (concept-individual first-copy)
      (let* ((name  (string (next-variable-name)))
             (label (intern (string-upcase name) :keyword)))
        (set-coref-label first-copy label)
        (dolist (other (rest copies))
          (setf (coref-bound-label other) label))))
    copies))

(defun decompose-cgraph (graph &key at)
  "Break GRAPH into the separate graphs that AT holds together.

   Returns a list of graphs. AT defaults to the first cut concept; a graph with
   none comes back as itself in a list of one, which is an answer -- some graphs
   are one sentence and that is that.

   The original is not touched. The work happens in a copy, and COPY-CGRAPH
   hands back the copy of the very node it was given, which is how the cut
   concept is found again on the other side.

   Each piece keeps a copy of AT, since that is what the pieces have in common
   and what a reader needs in order to put them back together -- as a repeated
   noun phrase in the text, and as the join in the graphs."
  (let ((cut-here (or at (first (cut-concepts graph)))))
    (cond
      ((null cut-here) (list graph))
      (t
       (unless (cut-concept-p cut-here graph)
         (error "~a holds nothing together in this graph; cutting it would ~
                 copy a concept without separating anything. CUT-CONCEPTS ~
                 lists the places that do."
                (format-node cut-here)))
       (let* ((cut (copy-cgraph cut-here))
              (components (graph-components-without cut cut))
              (copies (list cut)))
         (dolist (component (rest components))
           (let ((piece (copy-concept cut)))
             ;; Hand this component's arcs over to the piece's own copy. A
             ;; relation reaching two components cannot arise: it would join
             ;; them without passing through the cut, and then they would be
             ;; one component.
             (dolist (relation (copy-list (arcs cut)))
               (when (intersection (remove cut (arcs relation)) component)
                 (setf (arcs relation) (substitute piece cut (arcs relation)))
                 (setf (arcs cut) (remove relation (arcs cut)))
                 (setf (arcs piece) (append (arcs piece) (list relation)))))
             (push piece copies)))
         (share-identity (setf copies (nreverse copies)))
         (mapcar #'make-cgraph copies))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Policy: which seam, and whether to cut at all.
;;
;;  Kept apart from the operation above on purpose. Everything before this
;;  point is answerable from the graph -- where it comes apart, and what a cut
;;  must preserve. Everything from here down is a judgement about English, and
;;  judgements should be easy to find, easy to change, and off by default.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defparameter *decomposition-threshold* 7
  "How many concepts a graph may hold before it is worth breaking up.

   A guess, and labelled as one. The number that matters is not a property of
   graphs but of sentences, and the only way to set it honestly is to read
   output that came out badly -- which is why the operation stays explicit and
   nothing calls it on your behalf. Raise it and nothing is ever decomposed;
   lower it and every second graph becomes two sentences.")

(defun graph-referent-count (graph)
  "How many distinct THINGS GRAPH is about.

   Not how many concept nodes it has. Dave mentioned twice is one thing to
   follow, and a sentence is hard in proportion to what a reader must keep
   track of -- the same reason the cut analysis above works in referents."
  (let ((counted (list)))
    (dolist (concept (decomposition-concepts graph) (length counted))
      (unless (some (lambda (seen) (concepts-corefer-p seen concept)) counted)
        (push concept counted)))))

(defun graph-complicated-p (graph &key (threshold *decomposition-threshold*))
  "True when GRAPH is about more things than THRESHOLD."
  (> (graph-referent-count graph) threshold))

(defun seam-rank (concept graph)
  "How good a place CONCEPT is to cut GRAPH, smaller being better, or NIL for
   somewhere not to cut at all.

   Two rules, both learned from output rather than assumed:

   Never the MAIN PREDICATE. Rule 6's first half has the utterance path
   returning to it, and cutting there leaves a piece with no head: [DRIVE]
   separated from its destination realizes as `Is driven to Baltimore.'

   Prefer a THING to an EVENT. English pronominalizes things readily and
   events barely at all, so a seam at an act gives two sentences a reader
   cannot rejoin -- `An old dog eats. A cake is eaten.' reads as two eatings,
   where the graph had one.

   Among the seams that remain, prefer the one that peels off the least. A
   short second sentence carrying one modifier -- `He is young.' -- is the
   shape this is for; splitting a graph down the middle produces two halves
   that each want the other."
  (let ((main (find-main-predicate (decomposition-concepts graph))))
    (cond
      ((and main (concepts-corefer-p concept main)) nil)
      ((act-or-event-concept-p concept) nil)
      (t (reduce #'min (mapcar #'length (graph-components-without graph concept)))))))

(defun best-seam (graph)
  "The seam worth cutting in GRAPH, or NIL when none is."
  (let ((ranked (remove nil
                        (mapcar (lambda (concept)
                                  (let ((rank (seam-rank concept graph)))
                                    (and rank (cons rank concept))))
                                (cut-concepts graph)))))
    (cdr (first (sort ranked #'< :key #'car)))))

(defun decompose-fully (graph &key (threshold *decomposition-threshold*))
  "Break GRAPH up while it is worth breaking up, and return the pieces.

   Recursive, because one cut off a large graph leaves a piece that may still
   be too much for one sentence. Terminates on either answer -- a piece under
   the threshold, or a piece with no seam worth cutting -- and a graph that was
   never complicated comes back as itself in a list of one."
  (cond
    ((not (graph-complicated-p graph :threshold threshold)) (list graph))
    (t (let ((seam (best-seam graph)))
         (cond
           ((null seam) (list graph))
           (t (predicate-piece-first
               (mapcan (lambda (piece)
                         (decompose-fully piece :threshold threshold))
                       (decompose-cgraph graph :at seam)))))))))

(defun predicate-piece-first (pieces)
  "PIECES with a piece that carries a predicate at the front.

   Components come back in whatever order the walk found them, which is no
   order at all to a reader -- the main clause turned up third in `Dave has an
   ancient bag. He drives to Baltimore. He is young.' The clause the graph is
   about goes first and the modifiers peeled off it follow, which is also what
   makes the anaphora fall the right way round: the first sentence is where a
   thing is worth naming in full.

   Asked of each piece rather than carried down from the original, because
   DECOMPOSE-CGRAPH works in copies -- the original's main predicate is not EQ
   to anything in the pieces, and looking for it there silently found nothing."
  (let ((lead (find-if (lambda (piece)
                         (some #'act-or-event-concept-p
                               (decomposition-concepts piece)))
                       pieces)))
    (if lead
        (cons lead (remove lead pieces))
        pieces)))

(defun graph-to-text-decomposed (graph &key (threshold *decomposition-threshold*))
  "GRAPH as English, broken into several sentences when it is too much for one.

   The whole of Rule 6 in one call, and still not what GRAPH-TO-TEXT does: a
   caller that wants one sentence per graph should keep getting one."
  (graphs-to-text (decompose-fully graph :threshold threshold)))
