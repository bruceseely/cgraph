(in-package :conceptual-graphs)

;;; CANONICAL-GRAPH-INHERITANCE-PROBLEMS and CANONICAL-GRAPH-BUILD-PROBLEM, the
;;; canonical-graph checks in CHECK-TYPE-LATTICE. A subtype's canonical graph
;;; must be a restriction of its nearest ancestors': every arc they give their
;;; head kept, in the same direction, with the same type or a narrower one.
;;; The types are made here, under the test catalog's ACT and ANIMAL.

(defparameter *canonical-inheritance-types*
  '((:label cit-feed       :supertypes (act)
     :canonical-graph "[CIT-FEED]- (agnt)→[PERSON] (obj)→[SUBSTANCE]")
    ;; restrictions of it, right and wrong
    (:label cit-feed-full  :supertypes (cit-feed)
     :canonical-graph "[CIT-FEED-FULL]- (agnt)→[PERSON] (obj)→[FOOD]")
    (:label cit-feed-short :supertypes (cit-feed)
     :canonical-graph "[CIT-FEED-SHORT]→(obj)→[FOOD]")
    (:label cit-feed-wide  :supertypes (cit-feed)
     :canonical-graph "[CIT-FEED-WIDE]- (agnt)→[PERSON] (obj)→[ENTITY]")
    (:label cit-feed-off   :supertypes (cit-feed)
     :canonical-graph "[CIT-FEED-OFF]- (agnt)→[PERSON] (obj)→[CAT]")
    (:label cit-feed-none  :supertypes (cit-feed))
    (:label cit-feed-below :supertypes (cit-feed-none)
     :canonical-graph "[CIT-FEED-BELOW]- (agnt)→[PERSON] (obj)→[FOOD]")
    ;; poss runs either way between animates, so it can be turned round
    (:label cit-owned      :supertypes (animal)
     :canonical-graph "[CIT-OWNED]←(poss)←[PERSON]")
    (:label cit-owner      :supertypes (cit-owned)
     :canonical-graph "[CIT-OWNER]→(poss)→[PERSON]")
    ;; a relation deeper than the head's own arcs is checked by name
    (:label cit-keep       :supertypes (act)
     :canonical-graph "[CIT-KEEP]→(agnt)→[PERSON]→(poss)→[FOOD]")
    (:label cit-keep-less  :supertypes (cit-keep)
     :canonical-graph "[CIT-KEEP-LESS]→(agnt)→[PERSON]")
    ;; a graph that doesn't build: FOOD is not animate
    (:label cit-bad        :supertypes (act)
     :canonical-graph "[CIT-BAD]→(agnt)→[FOOD]")
    ;; a sibling's graph copied and not edited: about CIT-FEED-FULL, not this
    (:label cit-copied     :supertypes (cit-feed)
     :canonical-graph "[CIT-FEED-FULL]- (agnt)→[PERSON] (obj)→[FOOD]")))

(defun canonical-inheritance-problems-of (label)
  (canonical-graph-inheritance-problems (get-concept-type label)))

(defun canonical-inheritance-test (&optional verbose)
  (let ((ok t))
    (flet ((check (name result)
             (setf ok (and ok (and result t)))
             (when (or verbose (not result))
               (format t "~&  ~:[fail~;pass~] ~a~%" result name)))
           (says (label &rest words)
             (let ((problems (canonical-inheritance-problems-of label)))
               (and problems
                    (every (lambda (word)
                             (some (lambda (problem) (search word problem)) problems))
                           words)))))
      (when verbose (format t "~&CANONICAL-INHERITANCE-TEST~%"))
      (ensure-concept-types-exist *canonical-inheritance-types*)

      (check "a restriction that keeps every arc passes"
             (null (canonical-inheritance-problems-of 'cit-feed-full)))
      (check "a graph that drops an arc is reported"
             (says 'cit-feed-short "is missing →(agnt)→[PERSON], from CIT-FEED's"))
      (check "and only the dropped one"
             (= 1 (length (canonical-inheritance-problems-of 'cit-feed-short))))
      (check "widening a type is reported"
             (says 'cit-feed-wide "→(obj)→[ENTITY]" "SUBSTANCE or a kind of it"))
      (check "a type off the branch is reported"
             (says 'cit-feed-off "→(obj)→[CAT]" "SUBSTANCE or a kind of it"))
      (check "a type with no graph of its own owes nothing"
             (null (canonical-inheritance-problems-of 'cit-feed-none)))
      (check "the graph checked against is the nearest one, past a type without"
             (null (canonical-inheritance-problems-of 'cit-feed-below)))
      (check "an arc turned round is reported as turned, not missing"
             (says 'cit-owner "the arc runs the other way"))
      (check "a relation deeper in the ancestor's graph is checked by name"
             (says 'cit-keep-less "missing relation inherited from CIT-KEEP: (poss)"))
      (check "a canonical graph that doesn't build is reported"
             (let ((problem (canonical-graph-build-problem (get-concept-type 'cit-bad))))
               (and problem (search "doesn't build" problem)
                    (search "[FOOD] can't be the destination of (agnt)" problem))))
      (check "one that builds is not"
             (null (canonical-graph-build-problem (get-concept-type 'cit-feed-full))))
      (check "a graph headed by another type is reported"
             (let ((problem (canonical-graph-head-problem
                             'cit-copied
                             (canonical-graph-string (get-concept-type 'cit-copied)))))
               (and problem (search "CIT-COPIED is headed by [CIT-FEED-FULL]" problem))))
      (check "the inheritance check alone can't see it"
             (null (canonical-inheritance-problems-of 'cit-copied)))
      (check "a graph headed by its own type is not reported"
             (null (canonical-graph-head-problem
                    'cit-feed-full
                    (canonical-graph-string (get-concept-type 'cit-feed-full)))))
      (check "the lattice check reports it"
             (search "CIT-COPIED is headed by"
                     (with-output-to-string (*standard-output*) (check-type-lattice))))
      (check "no graph, no problem"
             (null (canonical-graph-head-problem 'cit-feed-none ""))))
    ok))
