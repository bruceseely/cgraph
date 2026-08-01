(in-package :conceptual-graphs)

;;; Tests for the graph editor's arc operations.
;;;
;;; Deliberately in test/editor/ rather than test/. EXTRACT-TEST-NAMES scans
;;; test/ by filename and calls the matching function, and UIOP:DIRECTORY-FILES
;;; is not recursive -- so a file here is invisible to TEST-CGRAPH. That is
;;; what we want: these need :CGRAPH-EDITOR loaded, and the main suite has to
;;; keep passing for anyone who loads only :CGRAPH. Run them with
;;; (EDITOR-TEST).
;;;
;;; The operations mutate the working graph IN PLACE. That is the property
;;; test B pins down: rebuilding by re-parsing mints new nodes and churns every
;;; node-ref, which would invalidate the browser's click map after every edit.
;;;
;;; Two behaviours here are emergent rather than coded, so they are the ones
;;; most likely to be broken quietly by a future change:
;;;
;;;   - coreference variables appear AND disappear on their own, because
;;;     sharing is node identity and the formatter renders it (C, E)
;;;   - removal prunes to reachability rather than walking outward guessing at
;;;     a stopping condition, which is what makes shared nodes survive (E)

(defun %editor-test-session (source)
  "A bare session over SOURCE, with no browser and no blocked caller."
  (let ((s (make-editor-session :original nil :kind :string
                                :working (make-working-graph source))))
    (register-editor-session s)
    s))

(defmacro %with-editor-session ((var source) &body body)
  "Sessions live in a global registry, so drop this one on the way out
   whatever happens -- a failing assertion must not leak into later tests."
  `(let ((,var (%editor-test-session ,source)))
     (unwind-protect (progn ,@body)
       (forget-editor-session ,var))))

(defun %editor-ref (session label)
  "node-ref of the first concept in SESSION's working graph typed LABEL."
  (let ((n (find-if (lambda (n)
                      (and (concept-p n)
                           (string-equal (string (label (concept-type n))) label)))
                    (nodes (session-working session)))))
    (and n (node-ref n))))

(defun %editor-arc (session focus relation-label)
  "The relation-ref of FOCUS's arc whose relation is RELATION-LABEL."
  (let ((entry (find-if (lambda (e) (string-equal (getf e :relation) relation-label))
                        (editor-focus-arcs session focus))))
    (and entry (getf entry :relation-ref))))

(defun %editor-text (session)
  (session-plain-render session))

(defun %editor-mentions (session text)
  (search text (string-upcase (%editor-text session))))

(defun editor-operations-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

        ;; --- A. building a graph one arc at a time -------------------------

        (%with-editor-session (s nil)
          (let ((eat (editor-add-concept s "eat")))
            (check "an empty session's first concept becomes the graph"
                   (string= "[EAT]." (%editor-text s)))
            (editor-add-arc s :focus (node-ref eat) :relation "agnt"
                              :target-type "dog")
            (check "first arc attaches" (%editor-mentions s "DOG"))
            (editor-add-arc s :focus (node-ref eat) :relation "obj"
                              :target-type "food")
            (check "second arc attaches, giving a fork"
                   (and (%editor-mentions s "DOG") (%editor-mentions s "FOOD")))))

        ;; --- B. node-refs survive operations -------------------------------
        ;; The browser's click map is keyed on these.

        (%with-editor-session (s "[EAT]->(agnt)->[DOG]")
          (let ((eat (%editor-ref s "eat"))
                (dog (%editor-ref s "dog")))
            (editor-add-arc s :focus eat :relation "obj" :target-type "food")
            (check "the focus keeps its ref across an add"
                   (eql eat (%editor-ref s "eat")))
            (check "an untouched node keeps its ref across an add"
                   (eql dog (%editor-ref s "dog")))
            (editor-remove-arc s :focus eat
                                 :relation (%editor-arc s eat "obj"))
            (check "the focus keeps its ref across a remove"
                   (eql eat (%editor-ref s "eat")))
            (check "an untouched node keeps its ref across a remove"
                   (eql dog (%editor-ref s "dog")))))

        ;; --- C. an arc to an EXISTING concept shares the node ---------------
        ;; This is what clicking a concept in the graph pane does, and it is
        ;; how two paths come to share one node. Nothing mints the variable.

        (%with-editor-session (s "[EAT]->(agnt)->[PERSON]")
          (let ((eat (%editor-ref s "eat"))
                (person (%editor-ref s "person")))
            (multiple-value-bind (rel attend)
                (editor-add-arc s :focus eat :relation "part"
                                  :target-type "attend")
              (declare (ignore rel))
              (editor-add-arc s :focus (node-ref attend) :relation "agnt"
                                :target person))
            (check "the shared node is one node, not two"
                   (= 1 (count person (remove-duplicates
                                       (nodes (session-working s)))
                               :key #'node-ref)))
            (check "the formatter emits a coreference variable unprompted"
                   (search "*" (%editor-text s)))))

        ;; --- D. remove prunes the whole branch ------------------------------

        (%with-editor-session (s "[EAT]- (agnt)->[DOG] (obj)->[FOOD]")
          (let ((eat (%editor-ref s "eat")))
            (check "the focus reports both arcs"
                   (= 2 (length (editor-focus-arcs s eat))))
            (editor-remove-arc s :focus eat :relation (%editor-arc s eat "agnt"))
            (check "the removed branch is gone" (not (%editor-mentions s "DOG")))
            (check "the other branch survives" (%editor-mentions s "FOOD"))
            (check "the focus survives" (%editor-mentions s "EAT"))))

        ;; --- E. remove stops at a node reachable another way ----------------
        ;; The coreference variable must also DISAPPEAR once the node is no
        ;; longer shared -- the formatter derives it from identity each time.

        (%with-editor-session (s "[EAT]->(agnt)->[PERSON]")
          (let ((eat (%editor-ref s "eat"))
                (person (%editor-ref s "person")))
            (multiple-value-bind (rel attend)
                (editor-add-arc s :focus eat :relation "part"
                                  :target-type "attend")
              (declare (ignore rel))
              (editor-add-arc s :focus (node-ref attend) :relation "agnt"
                                :target person))
            (check "shared while two paths reach it" (search "*" (%editor-text s)))
            (editor-remove-arc s :focus eat :relation (%editor-arc s eat "agnt"))
            (check "the shared node survives -- still reached via ATTEND"
                   (%editor-mentions s "PERSON"))
            (check "and its coreference variable disappears"
                   (not (search "*" (%editor-text s))))))

        ;; --- F. the focus survives losing its last arc ----------------------

        (%with-editor-session (s "[EAT]->(agnt)->[DOG]")
          (let ((eat (%editor-ref s "eat")))
            (editor-remove-arc s :focus eat :relation (%editor-arc s eat "agnt"))
            (check "a one-concept graph is a valid result"
                   (string= "[EAT]." (%editor-text s)))))

        ;; --- G. the lattice is enforced at the model level ------------------
        ;; UI filtering keeps illegal arcs off the screen; CONNECT is the
        ;; backstop, and it must refuse rather than corrupt the graph.

        (%with-editor-session (s "[EAT]->(agnt)->[DOG]")
          (let* ((dog (%editor-ref s "dog"))
                 (before (%editor-text s))
                 (err (nth-value 1 (ignore-errors
                                    (editor-add-arc s :focus dog :relation "agnt"
                                                      :target-type "food")))))
            (check "an arc the lattice forbids signals" (not (null err)))
            (check "and the graph is unchanged" (string= before (%editor-text s)))))

        ;; --- H. refs are resolved, never fabricated -------------------------

        (%with-editor-session (s "[EAT]->(agnt)->[DOG]")
          (check "an unknown focus ref is refused"
                 (nth-value 1 (ignore-errors
                               (editor-add-arc s :focus 999999 :relation "obj"
                                                 :target-type "food"))))
          (check "an unknown target ref is refused"
                 (nth-value 1 (ignore-errors
                               (editor-add-arc s :focus (%editor-ref s "eat")
                                                 :relation "obj" :target 999999))))
          (check "an unknown relation type is refused"
                 (nth-value 1 (ignore-errors
                               (editor-add-arc s :focus (%editor-ref s "eat")
                                                 :relation "no-such-relation"
                                                 :target-type "food"))))
          (check "an unknown concept type is refused"
                 (nth-value 1 (ignore-errors
                               (editor-add-arc s :focus (%editor-ref s "eat")
                                                 :relation "obj"
                                                 :target-type "no-such-type"))))))

      (when verbose
        (format t "~&editor-operations-test: ~:[FAILED <<<~;passed~]~%" ok))
      ok)))

(defun editor-test (&optional verbose)
  "Run the editor system's tests. Not reached by TEST-CGRAPH -- see the
   comment at the top of this file."
  (let ((results (list (cons "editor-operations-test"
                             (editor-operations-test verbose)))))
    (dolist (r results)
      (format t "~&-=- ~a~34t~:[failed <<<~;passed~]~%" (car r) (cdr r)))
    (every #'cdr results)))
