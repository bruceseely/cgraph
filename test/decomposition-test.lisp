(in-package :conceptual-graphs)

;;; Rule 6, second half: breaking one graph into several.
;;;
;;; The contract is that decomposition is JOIN RUN BACKWARDS, so the test is
;;; the join: cut a graph, put the pieces back with MAXIMAL-JOIN, and require
;;; the result to be equivalent to what was cut.
;;;
;;; Equivalence here is MUTUAL PROJECTION -- each graph projects into the other
;;; -- and not GRAPHS-EQUAL, which compares concept labels while ignoring
;;; relations, and whose GRAPH method hands a node to a method expecting a
;;; list. Mutual projection is also the right notion rather than a convenient
;;; one: rejoining is free to hand back a different head, a different arc
;;; order, and different variable names, none of which are differences in what
;;; the graph says.
;;;
;;; Individuals here carry EXPLICIT ids in the 500s. Ids come from one global
;;; counter, so a test that mints them shifts every id allocated after it --
;;; and the editor suite hard-codes low ones for its own fixtures. Minting
;;; Baltimore here quietly took #7, which that suite expects to be Felix, and
;;; the failure surfaced two suites away from its cause.

(defun graphs-equivalent-p (g1 g2)
  "True when each of G1 and G2 projects into the other."
  (and (project g1 g2) (project g2 g1) t))

(defun decomposition-round-trip-p (source &optional at-type)
  "Cut SOURCE at AT-TYPE (or the first cut concept), rejoin, and report whether
   the rejoined graph says what the original said."
  (let* ((nodes (parse-cgraph source))
         (head  (find-if #'concept-p nodes))
         (cut   (if at-type
                    (find at-type (cut-concepts nodes)
                          :key (lambda (c) (label (concept-type c))))
                    (first (cut-concepts nodes)))))
    (when cut
      (let* ((pieces   (decompose-cgraph nodes :at cut))
             (rejoined (reduce #'maximal-join pieces))
             ;; A fresh parse: the join mutates its inputs, and the original
             ;; node structure has been walked over by then.
             (again    (find-if #'concept-p (parse-cgraph source))))
        (declare (ignorable head))
        (and (> (length pieces) 1)
             (graphs-equivalent-p again rejoined))))))

(defun decomposition-test (&optional verbose)
  (let ((ok t))
    (flet ((check (name result)
             (setf ok (and ok (and result t)))
             (when (or verbose (not result))
               (format t "~&  ~:[fail~;pass~] ~a~%" result name))))
      (when verbose (format t "~&DECOMPOSITION-TEST~%"))

      ;; --- where a graph may be cut ---------------------------------------
      (check "a two-concept chain has nothing holding it together"
             (null (cut-concepts (parse-cgraph "[EAT]→(agnt)→[DOG]."))))

      ;; The ring closes through coreference rather than through arcs, so an
      ;; arc walk sees a path and would offer to cut it. Referents, not nodes.
      (check "a ring closed by coreference is still a ring"
             (null (cut-concepts
                    (parse-cgraph "[EAT]-
                                     (agnt)→[PERSON: sue #503]→(poss)→[PIE: *x]
                                     (obj)→[PIE: ?x]."))))

      (let ((cuts (cut-concepts
                   (parse-cgraph "[CHEVY-VEHICLE]-
                                    (attr)→[OLD]
                                    (inst)←[DRIVE]-
                                       (agnt)→[PERSON: dave #501 *x]→(attr)→[YOUNG]
                                       (dest)→[CITY: Baltimore #502],
                                    (poss)←[PERSON: dave #501 *x]."))))
        (check "a graph with three seams reports three"
               (= 3 (length cuts)))
        ;; Dave is mentioned twice and is one place to cut, not two.
        (check "one entry per referent, not per mention"
               (= 1 (count 'person cuts :key (lambda (c) (label (concept-type c)))))))

      ;; --- the cut is join run backwards -----------------------------------
      (check "an individual carries its own identity across the cut"
             (decomposition-round-trip-p
              "[CHEVY-VEHICLE]-
                 (attr)→[OLD]
                 (inst)←[DRIVE]-
                    (agnt)→[PERSON: dave #501 *x]→(attr)→[YOUNG]
                    (dest)→[CITY: Baltimore #502],
                 (poss)←[PERSON: dave #501 *x]."
              'person))

      ;; A generic has no identity of its own, so the cut has to leave a
      ;; coreference label -- without one the pieces would assert two dogs.
      (check "a generic gets a coreference label, and rejoins"
             (decomposition-round-trip-p
              "[EAT]-
                 (agnt)→[DOG]→(attr)→[OLD]
                 (obj)→[CAKE]."
              'dog))

      (let* ((nodes (parse-cgraph "[EAT]-
                                     (agnt)→[DOG]→(attr)→[OLD]
                                     (obj)→[CAKE]."))
             (pieces (decompose-cgraph nodes :at (first (cut-concepts nodes))))
             (texts (mapcar #'format-cgraph pieces)))
        (check "the pieces are labelled *x and ?x"
               (and (some (lambda (text) (search "*" text)) texts)
                    (some (lambda (text) (search "?" text)) texts))))

      ;; --- refusals ---------------------------------------------------------
      (let* ((nodes (parse-cgraph "[EAT]-
                                     (agnt)→[DOG]→(attr)→[OLD]
                                     (obj)→[CAKE]."))
             (leaf (find 'cake (decomposition-concepts nodes)
                         :key (lambda (c) (label (concept-type c))))))
        (check "cutting where nothing comes apart is refused"
               (handler-case (progn (decompose-cgraph nodes :at leaf) nil)
                 (error () t))))

      (check "a graph with no seam comes back as itself"
             (= 1 (length (decompose-cgraph (parse-cgraph "[EAT]→(agnt)→[DOG].")))))

      ;; --- and it is spoken as a sentence each ------------------------------
      ;; The point of the whole exercise. The second sentence must say the
      ;; repeated concept is the SAME one -- "A dog eats a cake. A dog is old"
      ;; is two dogs to a reader, whatever the graph says.
      ;; Cut at DOG deliberately, not at whichever seam comes first. The first
      ;; is EAT, and cutting a graph at its PREDICATE gives "An old dog eats. A
      ;; cake is eaten." -- two grammatical sentences that read as two eatings,
      ;; because English pronominalizes things far more readily than events.
      ;; That is a question for the policy stage: which seam is worth cutting.
      (let* ((nodes  (parse-cgraph "[EAT]-
                                      (agnt)→[DOG]→(attr)→[OLD]
                                      (obj)→[CAKE]."))
             (dog    (find 'dog (cut-concepts nodes)
                           :key (lambda (c) (label (concept-type c)))))
             (pieces (decompose-cgraph nodes :at dog)))
        (check "the pieces are spoken as two sentences, the second anaphoric"
               (string= "A dog eats a cake. It is old." (graphs-to-text pieces)))
        (check "cross-coref off names it again instead"
               (string= "A dog eats a cake. A dog is old."
                        (graphs-to-text pieces :cross-coref nil))))

      (let* ((nodes (parse-cgraph "[CHEVY-VEHICLE]-
                                     (attr)→[OLD]
                                     (inst)←[DRIVE]-
                                        (agnt)→[PERSON: dave #501 *x]→(attr)→[YOUNG]
                                        (dest)→[CITY: Baltimore #502],
                                     (poss)←[PERSON: dave #501 *x]."))
             (cut (find 'person (cut-concepts nodes)
                        :key (lambda (c) (label (concept-type c))))))
        (check "an individual is pronominalized on the second sentence"
               (string= "Dave drives with Dave's old chevy-vehicle to Baltimore. He is young."
                        (graphs-to-text (decompose-cgraph nodes :at cut)))))

      ;; --- policy: whether, and where ---------------------------------------
      (let* ((dave "[CHEVY-VEHICLE]-
                      (attr)→[OLD]
                      (inst)←[DRIVE]-
                         (agnt)→[PERSON: dave #501 *x]→(attr)→[YOUNG]
                         (dest)→[CITY: Baltimore #502],
                      (poss)←[PERSON: dave #501 *x].")
             (nodes (parse-cgraph dave)))
        ;; Six things, seven nodes: Dave is mentioned twice and is one thing to
        ;; keep track of, which is what makes a sentence hard.
        (check "complexity counts referents, not concept nodes"
               (= 6 (graph-referent-count nodes)))
        (check "under the threshold nothing is cut"
               (= 1 (length (decompose-fully nodes :threshold 7))))
        (check "over the threshold it is"
               (> (length (decompose-fully nodes :threshold 3)) 1))
        ;; DRIVE is a seam and is the worst one: cutting a graph at its
        ;; predicate leaves a piece with no head.
        (check "the seam chosen is never an act"
               (not (act-or-event-concept-p (best-seam nodes))))
        (check "the main predicate is refused as a seam"
               (null (seam-rank (find-main-predicate (decomposition-concepts nodes))
                                nodes)))
        (check "the piece carrying the clause is spoken first"
               (let ((pieces (decompose-fully nodes :threshold 3)))
                 (some #'act-or-event-concept-p
                       (decomposition-concepts (first pieces))))))

      (when verbose
        (format t "~&DECOMPOSITION-TEST ~:[failed~;passed~]~%" ok))
      ok)))
