(in-package :conceptual-graphs)

;;; Tests for relation join semantics — notes/type-editor-integration.md §5,
;;; "Joins are the actual design question".
;;;
;;; The question §5 left open was what two INCOMPARABLE relation types join to,
;;; given there is no ⊥ for relations and so no meet to give. The answer is that
;;; a join never needs one. A join is a CONJUNCTION: the result asserts what
;;; both graphs assert. A concept carries exactly one type, so joining
;;; [MAN: Dave] with [DOCTOR: Dave] has to find one type meaning both, which is
;;; what MAXIMAL-COMMON-SUBTYPE is for. A pair of concepts carries as many
;;; relations as you like, so two incomparable relations simply both stay:
;;; part(x,y) ∧ cntns(x,y) is a perfectly good thing to have written down.
;;;
;;; What the hierarchy does buy is a CORRESPONDENCE. (ploc) and (loc) over the
;;; same pair describe one arc at two precisions, so a mapping lining them up is
;;; legitimate; SIMPLIFY then drops the supertype the subtype already entails.
;;;
;;; Fixtures go through %WITH-TEST-RELATIONS (relation-hierarchy-test.lisp) for
;;; the same reason: the catalog is process-global.

(defun relation-join-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

        ;; --- SIMPLIFY drops what another relation entails ------------------
        (%with-test-relations '(j-ploc)
          (lambda ()
            (define-relation-type :label 'j-ploc :supertypes '(loc)
                                  :source-types '(physical) :dest-type 'place)
            ;; Both arcs on one pair. j-ploc ⊑ loc, so loc adds nothing.
            (let* ((g (make-cgraph "[PERSON: #601]- (loc)→[CITY: Annapolis] (j-ploc)→[CITY: Annapolis]"))
                   (person (find-if (lambda (c) (types-eq (concept-type c)
                                                          (get-concept-type 'person)))
                                    (collect-concepts g))))
              (dolist (c (collect-concepts g)) (simplify c))
              (let ((kinds (mapcar (lambda (r) (label (relation-type r))) (arcs person))))
                (check "the entailed supertype is dropped" (not (member 'loc kinds)))
                (check "the subtype survives" (member 'j-ploc kinds))
                (check "exactly one arc is left" (= 1 (length kinds)))))

            ;; Same relation family, DIFFERENT targets: nothing is entailed, so
            ;; nothing may go. This is the over-pruning guard — entailment is
            ;; about arcs as much as about types.
            ;;
            ;; NAMED cities, not #604/#605. Two concepts whose referents hold
            ;; distinct unregistered numeric individuals compare OBJECTS-EQUAL,
            ;; so this check written with ids passes or fails for a reason that
            ;; has nothing to do with relation types. See notes/known-issues.md.
            (let* ((g (make-cgraph "[PERSON: #603]- (loc)→[CITY: Annapolis] (j-ploc)→[CITY: Baltimore]"))
                   (person (find-if (lambda (c) (types-eq (concept-type c)
                                                          (get-concept-type 'person)))
                                    (collect-concepts g))))
              (dolist (c (collect-concepts g)) (simplify c))
              (check "different targets keep both arcs"
                     (= 2 (length (arcs person)))))))

        ;; --- a chain collapses to the most specific ------------------------
        (%with-test-relations '(j-mid j-deep)
          (lambda ()
            (define-relation-type :label 'j-mid  :supertypes '(loc)
                                  :source-types '(physical) :dest-type 'place)
            (define-relation-type :label 'j-deep :supertypes '(j-mid)
                                  :source-types '(physical) :dest-type 'place)
            (let* ((g (make-cgraph "[PERSON: #606]- (loc)→[CITY: Annapolis] (j-mid)→[CITY: Annapolis] (j-deep)→[CITY: Annapolis]"))
                   (person (find-if (lambda (c) (types-eq (concept-type c)
                                                          (get-concept-type 'person)))
                                    (collect-concepts g))))
              (dolist (c (collect-concepts g)) (simplify c))
              (let ((kinds (mapcar (lambda (r) (label (relation-type r))) (arcs person))))
                (check "a three-deep chain leaves only the deepest"
                       (equal kinds (list 'j-deep)))))))

        ;; --- incomparable relations are a conjunction, not a conflict ------
        ;; PART and CNTNS are unrelated, so neither entails the other and both
        ;; must survive. If SIMPLIFY ever pruned here it would be deleting an
        ;; assertion, which is the one thing it must never do.
        (let* ((g (make-cgraph "[BAG: #608]- (part)→[BOOK: #609] (cntns)→[BOOK: #609]"))
               (bag (find-if (lambda (c) (types-eq (concept-type c) (get-concept-type 'bag)))
                             (collect-concepts g))))
          (dolist (c (collect-concepts g)) (simplify c))
          (check "incomparable arcs both survive simplify" (= 2 (length (arcs bag)))))

        ;; --- the join lines up arcs of comparable type ---------------------
        (%with-test-relations '(j-ploc2)
          (lambda ()
            (define-relation-type :label 'j-ploc2 :supertypes '(loc)
                                  :source-types '(physical) :dest-type 'place)
            ;; Before the relaxation this mapped ONE pair, not two, and the join
            ;; came back with [PERSON]…←(j-ploc2)←[PERSON] — the person twice,
            ;; because the arcs were refused a correspondence and so the two
            ;; concepts were never identified.
            (let* ((g1 (make-cgraph "[PERSON: #610]→(loc)→[CITY: #611]"))
                   (g2 (make-cgraph "[PERSON: #610]→(j-ploc2)→[CITY: #611]")))
              (check "both concept pairs are mapped"
                     (= 2 (length (maximal-join-mapping g1 g2))))
              (let* ((j (maximal-join g1 g2))
                     (concepts (collect-concepts j)))
                (check "the joined graph has two concepts, not three"
                       (= 2 (length concepts)))
                (check "and keeps the more specific relation"
                       (equal (mapcar (lambda (r) (label (relation-type r)))
                                      (arcs (find-if (lambda (c) (types-eq (concept-type c)
                                                                           (get-concept-type 'person)))
                                                     concepts)))
                              (list 'j-ploc2)))))

            ;; Symmetric: which graph holds the subtype must not matter.
            (let* ((g1 (make-cgraph "[PERSON: #612]→(j-ploc2)→[CITY: #613]"))
                   (g2 (make-cgraph "[PERSON: #612]→(loc)→[CITY: #613]")))
              (check "the same both ways round"
                     (= 2 (length (maximal-join-mapping g1 g2)))))))

        ;; --- and the strict case is untouched ------------------------------
        ;; Two graphs whose arcs are of INCOMPARABLE type still do not have
        ;; their endpoints identified. That is deliberate and is where the
        ;; remaining choice lives: this operation looks for a maximal COMMON
        ;; SUBGRAPH, and relaxing it to admit any conjunction would make it a
        ;; different operation. See §5 of the note.
        (let* ((g1 (make-cgraph "[BAG: #614]→(part)→[BOOK: #615]"))
               (g2 (make-cgraph "[BAG: #614]→(cntns)→[BOOK: #615]")))
          (check "incomparable arcs still block the pairing"
                 (= 1 (length (maximal-join-mapping g1 g2)))))

        ;; --- equal types behave exactly as before --------------------------
        (let* ((g1 (make-cgraph "[PERSON: #616]→(loc)→[CITY: #617]"))
               (g2 (make-cgraph "[PERSON: #616]→(loc)→[CITY: #617]")))
          (check "identical graphs still join to one copy"
                 (and (= 2 (length (maximal-join-mapping g1 g2)))
                      (= 2 (length (collect-concepts (maximal-join g1 g2)))))))

        ok))))
