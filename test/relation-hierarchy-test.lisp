(in-package :conceptual-graphs)

;;; Tests for the relation type hierarchy — notes/type-editor-integration.md §4(b).
;;;
;;; RELATION-TYPE inherited DIRECT-SUPERTYPES/DIRECT-SUBTYPES from TYPE-OBJECT
;;; from the start and nothing ever filled them. These cover the four things
;;; filling them changes: the lattice predicates now answer for relation types,
;;; a subtype inherits its signature and its syntax role, projection honours
;;; the hierarchy, and CHECK-RELATION-LATTICE refuses an unsound one.
;;;
;;; Fixtures build their relations inside %WITH-TEST-RELATIONS, which removes
;;; them afterwards — the catalog is process-global and a leaked relation type
;;; would follow the rest of the suite around.

(defun %with-test-relations (labels thunk)
  "Call THUNK, then remove LABELS from the relation catalog and unlink them from
   whatever they were made subtypes of. The unlink matters as much as the
   REMHASH: a parent left holding a DIRECT-SUBTYPES pointer at a forgotten
   relation would make SUBTYPES return a type no lookup can resolve."
  (unwind-protect (funcall thunk)
    (dolist (l labels)
      (let ((node (ignore-errors (get-relation-type l))))
        (when node
          (dolist (super (direct-supertypes node))
            (when (typep super 'relation-type)
              (setf (direct-subtypes super)
                    (remove node (direct-subtypes super) :test #'eq))))))
      (remhash l *relation-type-catalog*)
      (ignore-errors (unregister-relation-syntax l)))))

(defun relation-hierarchy-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

        ;; --- the widened predicates answer for relation types --------------
        (%with-test-relations '(t-ploc)
          (lambda ()
            (define-relation-type :label 't-ploc :supertypes '(loc)
                                  :source-types '(physical) :dest-type 'place)
            (let ((sub (get-relation-type 't-ploc))
                  (sup (get-relation-type 'loc)))
              (check "the link is made both ways"
                     (and (member sup (direct-supertypes sub) :test #'eq)
                          (member sub (direct-subtypes sup) :test #'eq)))
              (check "subtype-p answers for relation types" (subtype-p sub sup))
              (check "and is not symmetric" (not (subtype-p sup sub)))
              (check "subsumes-p: parent subsumes child" (subsumes-p sup sub))
              (check "subsumes-p: child does not subsume parent" (not (subsumes-p sub sup)))
              ;; TYPES-EQ had no relation-type method, so this was NIL and a
              ;; relation type failed to subsume itself.
              (check "subsumes-p is reflexive" (subsumes-p sub sub))
              (check "subtypes includes the child" (member sub (subtypes sup) :test #'eq)))))

        ;; --- concept types are unaffected by the widening ------------------
        (check "concept subtype-p still works" (subtype-p 'dog 'animal))
        (check "concept subtype-p still directional" (not (subtype-p 'animal 'dog)))
        (check "concept subsumes-p still works"
               (subsumes-p (get-concept-type 'entity) (get-concept-type 'dog)))

        ;; --- a subtype takes its parent's signature when it states none ----
        (%with-test-relations '(t-benef)
          (lambda ()
            (define-relation-type :label 't-benef :supertypes '(rcpt))
            (let ((r (get-relation-type 't-benef))
                  (p (get-relation-type 'rcpt)))
              (check "inherits its sources"
                     (equal (mapcar #'label (relation-source-list r))
                            (mapcar #'label (relation-source-list p))))
              (check "inherits its destination"
                     (eq (dest-type r) (dest-type p))))))

        ;; --- and its syntax role, which is the point of the exercise -------
        (%with-test-relations '(t-benef)
          (lambda ()
            (define-relation-type :label 't-benef :supertypes '(rcpt))
            (check "inherits the role with nothing registered"
                   (eq (relation-role 't-benef) (relation-role 'rcpt)))
            (check "inherits the preposition too"
                   (equal (relation-preposition 't-benef) (relation-preposition 'rcpt)))
            (check "the coverage lint counts it as covered"
                   (not (member 't-benef (mapcar #'fourth (%lint-relation-syntax-coverage)))))
            ;; An own entry has to beat an inherited one, or a subtype could
            ;; never differ from its parent -- which is most of why you would
            ;; make one.
            (register-relation-syntax 't-benef :dobj)
            (check "its own registration overrides the inherited role"
                   (eq :dobj (relation-role 't-benef)))))

        ;; --- projection ----------------------------------------------------
        (%with-test-relations '(t-ploc)
          (lambda ()
            (define-relation-type :label 't-ploc :supertypes '(loc)
                                  :source-types '(physical) :dest-type 'place)
            (let ((general  (make-cgraph "[DOG]→(loc)→[PLACE]."))
                  (specific (make-cgraph "[DOG]→(t-ploc)→[PLACE].")))
              (check "a general pattern projects onto a specific target"
                     (projection-p general specific))
              (check "a specific pattern does NOT project onto a general target"
                     (not (projection-p specific general)))
              (check "and a relation still does not project onto an unrelated one"
                     (not (projection-p (make-cgraph "[DOG]→(ploc)→[PLACE].")
                                        (make-cgraph "[DOG]→(loc)→[PLACE].")))))))

        ;; --- check-relation-lattice ----------------------------------------
        (check "the shipped catalog is sound" (null (check-relation-lattice :stream nil)))
        (%with-test-relations '(t-wide)
          (lambda ()
            ;; ENTITY is broader than PHYSICAL, so this widens where a subtype
            ;; must narrow -- the unsound direction.
            (define-relation-type :label 't-wide :supertypes '(ploc)
                                  :source-types '(entity) :dest-type 'place)
            (let ((problems (check-relation-lattice :stream nil)))
              (check "a widening subtype is reported"
                     (some (lambda (p) (search "t-wide" p)) problems))
              (check "and the message names what it failed to narrow"
                     (some (lambda (p) (and (search "t-wide" p) (search "ploc" p)))
                           problems)))))
        (%with-test-relations '(t-narrow)
          (lambda ()
            (define-relation-type :label 't-narrow :supertypes '(loc)
                                  :source-types '(physical) :dest-type 'place)
            (check "a narrowing subtype is not reported"
                   (notany (lambda (p) (search "t-narrow" p))
                           (check-relation-lattice :stream nil)))))

        ;; --- cycles must not hang the ancestor walk ------------------------
        (%with-test-relations '(t-a t-b)
          (lambda ()
            (define-relation-type :label 't-a :supertypes '(loc)
                                  :source-types '(physical) :dest-type 'place)
            (define-relation-type :label 't-b :supertypes '(t-a)
                                  :source-types '(physical) :dest-type 'place)
            ;; Force the cycle by hand; nothing offers a way to declare one.
            (add-relation-inheritance (get-relation-type 't-b) (get-relation-type 't-a))
            (check "relation-ancestors terminates on a cycle"
                   (<= 2 (length (relation-ancestors (get-relation-type 't-a))) 4))
            (check "the cycle is reported"
                   (some (lambda (p) (search "each above the other" p))
                         (check-relation-lattice :stream nil))))))

      (when verbose
        (format t "~&relation-hierarchy-test: ~:[FAILED <<<~;passed~]~%" ok))
      ok)))
