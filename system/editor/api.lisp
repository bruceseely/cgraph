;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Graph-editor HTTP surface.
;;
;;  Registered on the SAME acceptor as the type browser, so the editor shares
;;  its origin and can reuse /api/types, /api/relations and /api/options
;;  without CORS. A separate ASDF system, not a separate server.
;;
;;  Every handler here runs in a Hunchentoot worker thread and touches a
;;  session owned by a blocked REPL thread, so each one goes through the
;;  session lock (see session.lisp).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun editor-static-dir ()
  (namestring (merge-pathnames "editor/"
                               (asdf:system-source-directory "cgraph-editor"))))

(defun read-editor-file (filename)
  (uiop:read-file-string (merge-pathnames filename (editor-static-dir))))

(defun json-error (message &optional (code hunchentoot:+http-bad-request+))
  (setf (hunchentoot:return-code*) code)
  (format nil "{\"ok\":false,\"error\":\"~a\"}" (json-escape (princ-to-string message))))

(defmacro with-editor-session ((var id) &body body)
  "Bind VAR to the session named by ID, or return a JSON error.

   Touching the session here is what detects a browser coming back: any request
   at all means the page is alive, so reopening a disconnected session's URL
   reconnects it without a dedicated handshake. The disconnect endpoint
   deliberately does NOT use this macro, for the obvious reason."
  `(let ((,var (find-editor-session ,id)))
     (cond ((null ,var) (json-error "no such editor session"))
           ((not (eq (session-state ,var) :open))
            (json-error "editor session is already finished"))
           (t (touch-editor-session ,var)
              ,@body))))

;;; GET /editor?session=N — the editor page itself.
(hunchentoot:define-easy-handler (handle-editor :uri "/editor") (session)
  (declare (ignore session))
  (setf (hunchentoot:content-type*) "text/html; charset=utf-8")
  (no-store)
  (read-editor-file "editor.html"))

;;; GET /editor.js
(hunchentoot:define-easy-handler (handle-editor-js :uri "/editor.js") ()
  (setf (hunchentoot:content-type*) "application/javascript; charset=utf-8")
  (no-store)
  (read-editor-file "editor.js"))

;;; GET /api/editor/state?session=N — the working graph, rendered with refs.
(hunchentoot:define-easy-handler (handle-editor-state :uri "/api/editor/state") (session)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (with-editor-session (s session)
    (format nil "{\"ok\":true,\"session\":~a,\"withRefs\":\"~a\",\"plain\":\"~a\"}"
            (session-id s)
            (json-escape (session-render s))
            (json-escape (session-plain-render s)))))

;;; POST /api/editor/op?session=N&op=replace&text=... — apply one operation.
;;;
;;; The skeleton implements exactly one operation, `replace', which rebuilds
;;; the working graph from linear notation. It exists to prove that an edit
;;; made in a worker thread reaches the graph the blocked REPL thread holds --
;;; nothing more.
;;;
;;; It is NOT the model for the real operations. Rebuilding re-parses, and
;;; re-parsing mints new nodes, so every node-ref changes and the browser's
;;; click map goes stale. The arc-level operations (add by refs, remove with
;;; the prune cascade) must MUTATE the working graph in place, so refs stay
;;; stable for the life of the session. See notes/graph-editor.md.
(hunchentoot:define-easy-handler (handle-editor-op :uri "/api/editor/op") (session op text)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (unless (eq (hunchentoot:request-method*) :post)
    (return-from handle-editor-op
      (json-error "POST required" hunchentoot:+http-method-not-allowed+)))
  (with-editor-session (s session)
    (handler-case
        (cond
          ((string-equal (or op "") "replace")
           (setf (session-working s) (make-working-graph text))
           (format nil "{\"ok\":true,\"withRefs\":\"~a\",\"plain\":\"~a\"}"
                   (json-escape (session-render s))
                   (json-escape (session-plain-render s))))
          (t (json-error (format nil "unknown op: ~a" op))))
      (error (e) (json-error e)))))

;;; --- The real operations ---------------------------------------------------
;;; Every edit is one arc attached to or removed from the focus concept.
;;; These mutate the working graph in place so node-refs stay stable for the
;;; life of the session -- the browser's click map depends on it.

(defun editor-graph-json (session &optional focus)
  "The working graph plus, when FOCUS is given, its neighbourhood.

   PARENT rides along because the page has no other way to learn it is a nested
   editor: it is loaded from a URL carrying only its own session id, and what
   UPDATE should do -- veil, or return to the graph above -- depends on the
   answer."
  (format nil "{\"ok\":true,\"withRefs\":\"~a\",\"plain\":\"~a\"~@[,\"parent\":~a~]~@[,\"focus\":~a~]}"
          (json-escape (session-render session))
          (json-escape (session-plain-render session))
          (let ((p (session-parent session)))
            (and p (session-id p)))
          (when focus
            (with-output-to-string (out)
              (write-char #\[ out)
              (loop for (entry . rest) on (editor-focus-arcs session focus) do
                (format out "{\"relationRef\":~a,\"relation\":\"~a\",\"direction\":\"~(~a~)\",\"conceptRef\":~a,\"concept\":\"~a\"}"
                        (getf entry :relation-ref)
                        (json-escape (getf entry :relation))
                        (getf entry :direction)
                        (getf entry :concept-ref)
                        (json-escape (getf entry :concept)))
                (when rest (write-char #\, out)))
              (write-char #\] out)))))

(defmacro define-editor-post ((name uri) lambda-list &body body)
  "A POST-only editor handler that resolves the session and turns an
   EDITOR-OPERATION-ERROR into a JSON error rather than a 500."
  `(hunchentoot:define-easy-handler (,name :uri ,uri) ,lambda-list
     (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
     (no-store)
     (if (not (eq (hunchentoot:request-method*) :post))
         (json-error "POST required" hunchentoot:+http-method-not-allowed+)
         (with-editor-session (s session)
           (handler-case (progn ,@body)
             (editor-operation-error (e) (json-error e))
             (error (e) (json-error e)))))))

;;; POST /api/editor/add?session=N&focus=REF&relation=LABEL
;;;      &target=REF | &target_type=LABEL   [&direction=forward|reverse]
;;;
;;; target    -> an arc to an EXISTING concept; this is how two paths share a
;;;              node, and the coreference variable appears by itself when the
;;;              formatter linearizes it.
;;; targetType-> a NEW concept of that type.
(define-editor-post (handle-editor-add "/api/editor/add")
    (session focus relation target target_type direction)
  (editor-add-arc s
                  :focus focus
                  :relation relation
                  :target (and target (plusp (length target)) target)
                  :target-type (and target_type (plusp (length target_type))
                                    target_type)
                  :direction (if (string-equal (or direction "forward") "reverse")
                                 :reverse :forward))
  (editor-graph-json s focus))

;;; POST /api/editor/remove?session=N&focus=REF&relation=REF
(define-editor-post (handle-editor-remove "/api/editor/remove")
    (session focus relation)
  (editor-remove-arc s :focus focus :relation relation)
  (editor-graph-json s focus))

;;; POST /api/editor/concept?session=N&type=LABEL
;;; A free-standing concept -- how an empty graph gets its first node.
(define-editor-post (handle-editor-concept "/api/editor/concept")
    (session type)
  (let ((concept (editor-add-concept s type)))
    (format nil "{\"ok\":true,\"ref\":~a,\"withRefs\":\"~a\",\"plain\":\"~a\"}"
            (node-ref concept)
            (json-escape (session-render s))
            (json-escape (session-plain-render s)))))

;;; GET /api/editor/focus?session=N&focus=REF — the display pane's contents.
(hunchentoot:define-easy-handler (handle-editor-focus :uri "/api/editor/focus")
    (session focus)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (with-editor-session (s session)
    (handler-case (editor-graph-json s focus)
      (editor-operation-error (e) (json-error e))
      (error (e) (json-error e)))))

;;; --- The referent editor ---------------------------------------------------
;;;
;;; One concept's referent, read as the identity/modifiers/tail split and
;;; edited one named field at a time. The HTTP surface mirrors the setters
;;; deliberately: a request that could change two things at once would be a
;;; request whose failure could leave one of them changed.

(defun json-measure (measure)
  "(SIZE UNITS) as a JSON pair, or null."
  (if measure
      (format nil "[~a,\"~a\"]" (first measure) (json-escape (or (second measure) "")))
      "null"))

(defun json-tail (tail)
  "The unrecognised properties as a JSON object. Values are stringified: the
   tail is shown, not interpreted, so whatever the reader put there is
   displayable without this having to know what it meant."
  (with-output-to-string (out)
    (write-char #\{ out)
    (loop for (key value) on tail by #'cddr
          for first = t then nil
          do (unless first (write-char #\, out))
             (format out "\"~a\":\"~a\""
                     (json-escape (string-downcase (string key)))
                     (json-escape (princ-to-string value))))
    (write-char #\} out)))

(defun json-referent-view (concept)
  "CONCEPT's referent, decomposed. GRAPHCOMPATIBLE says whether this type may
   take a nested graph instead of the panel -- the one identity that is not a
   state of the selector but an alternative to the whole of it."
  (let ((v (describe-referent concept)))
    (format nil "{\"kind\":\"~(~a~)\",\"label\":~:[null~;\"~:*~(~a~)\"~],~
                 \"defining\":~:[false~;true~],\"id\":~a,\"name\":~:[null~;\"~:*~a\"~],~
                 \"identityText\":\"~a\",\"modifierText\":\"~a\",~
                 \"quantifier\":~:[null~;\"~:*~(~a~)\"~],\"tense\":~:[null~;\"~:*~(~a~)\"~],~
                 \"aspect\":~:[null~;\"~:*~(~a~)\"~],\"voice\":~:[null~;\"~:*~(~a~)\"~],~
                 \"raising\":~:[false~;true~],\"negated\":~:[false~;true~],~
                 \"measure\":~a,\"tail\":~a,\"graphCompatible\":~:[false~;true~],~
                 \"verbal\":~:[false~;true~]}"
            (rview-kind v)
            (rview-label v)
            (rview-defining-p v)
            (let ((id (rview-id v)))
              (cond ((numberp id) id)
                    ((eq id t) "\"#\"")
                    (t "null")))
            (and (rview-name v) (json-escape (rview-name v)))
            (json-escape (referent-identity-text v))
            (json-escape (referent-modifier-text v))
            (rview-quantifier v) (rview-tense v) (rview-aspect v) (rview-voice v)
            (rview-raising v) (rview-negated v)
            (json-measure (rview-measure v))
            (json-tail (rview-tail v))
            (ignore-errors (graph-compatible-p (concept-type concept)))
            (referent-verbal-p concept))))

;;; GET /api/editor/referent?session=N&concept=REF
(hunchentoot:define-easy-handler (handle-editor-referent :uri "/api/editor/referent")
    (session concept)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (with-editor-session (s session)
    (handler-case
        (with-cg-thread-bindings
          (let ((node (editor-concept s concept)))
            (format nil "{\"ok\":true,\"referent\":~a}" (json-referent-view node))))
      (editor-operation-error (e) (json-error e))
      (error (e) (json-error e)))))

;;; POST /api/editor/referent/set?session=N&concept=REF&field=F&...
;;;
;;; FIELD is one of the @-word modifiers, `measure', or `identity'.
;;; An empty VALUE clears -- which is a real edit, not a missing argument, so
;;; the parameter is distinguished by presence rather than by emptiness.
(define-editor-post (handle-editor-referent-set "/api/editor/referent/set")
    (session concept field value kind label id name)
  (with-cg-thread-bindings
    (let* ((node (editor-concept s concept))
           (field (string-downcase (or field ""))))
      (flet ((blank (x) (or (null x) (zerop (length (string-trim " " x)))))
             (kw (x) (and x (plusp (length x))
                          (intern (string-upcase x) :keyword))))
        (cond
          ;; The whole referent at once. Its own field rather than a loop in
          ;; the page, so a half-cleared referent is never a reachable state.
          ((string= field "all") (clear-referent node))
          ((string= field "identity")
           (let ((k (kw kind)))
             (unless k (editor-error "identity needs a kind"))
             (set-referent-identity
              node k
              :label (unless (blank label) label)
              :id (cond ((blank id) nil)
                        ((string= (string-trim " " id) "#") t)
                        (t (or (parse-integer (string-trim " #" id) :junk-allowed t)
                               (editor-error "~a is not an individual id" id))))
              :name (unless (blank name) name))))
          ((string= field "measure")
           (set-referent-measure
            node (unless (blank value)
                   ;; "5 ft." / "25.4cm" / "5" -- the number, then whatever
                   ;; follows it as the unit.
                   (let* ((v (string-trim " " value))
                          (end (or (position-if-not
                                    (lambda (c) (or (digit-char-p c) (char= c #\.)))
                                    v)
                                   (length v))))
                     (when (zerop end)
                       (editor-error "a measure starts with a number"))
                     (list (read-from-string (subseq v 0 end))
                           (string-trim " " (subseq v end)))))))
          ((member field '("quantifier" "tense" "aspect" "voice" "raising")
                   :test #'string=)
           (set-referent-modifier node (kw field)
                                  (if (string= field "raising")
                                      (and (not (blank value))
                                           (not (string-equal value "false")))
                                      (kw (unless (blank value) value)))))
          (t (editor-error "unknown referent field: ~a" field))))
      (format nil "{\"ok\":true,\"referent\":~a,\"withRefs\":\"~a\",\"plain\":\"~a\"}"
              (json-referent-view node)
              (json-escape (session-render s))
              (json-escape (session-plain-render s))))))

;;; POST /api/editor/referent/graph?session=N&concept=REF
;;;
;;; Descend into a concept's graph referent, creating an empty one if it has
;;; none. Returns a CHILD session; the page navigates to its URL, edits there,
;;; and comes back when it finishes. Sessions are already resumable at their
;;; URL -- that is what a disconnect leaves behind -- so navigating away from
;;; the parent and back is safe and needs nothing new.
(define-editor-post (handle-editor-referent-graph "/api/editor/referent/graph")
    (session concept)
  (with-cg-thread-bindings
    (let* ((node (editor-concept s concept))
           (child (open-nested-editor-session s node)))
      (format nil "{\"ok\":true,\"session\":~a,\"url\":\"~a\",\"subject\":\"~a\"}"
              (session-id child)
              (json-escape (editor-session-url child))
              (json-escape (format-node node))))))

;;; --- The graph in English --------------------------------------------------

(defun editor-english (session)
  "The working graph as an English sentence.

   Returns (VALUES TEXT NOTE). TEXT is \"\" when there is nothing to say, and
   NOTE then carries the reason, because the two silences mean different
   things: a graph with no nodes yet has nothing to generate FROM, while a
   graph the generator cannot realize has something to say about itself.

   Generation is a much larger surface than the rest of the editor -- lexicon
   lookups, morphology, the whole realizer -- and an arc the tables do not
   cover is a perfectly ordinary thing to be holding halfway through an edit.
   So an error here is reported IN the pane and nowhere else: a sentence that
   cannot yet be produced must not look like a failed edit."
  (let ((g (session-working session)))
    (cond ((null g) (values "" "no graph yet"))
          (t (handler-case
                 (with-cg-thread-bindings
                   (let ((text (graph-to-text g)))
                     (if (plusp (length text))
                         (values text nil)
                         (values "" "nothing to say about this graph yet"))))
               (error (e)
                 (values "" (format nil "cannot say it yet: ~a" e))))))))

;;; GET /api/editor/text?session=N — the working graph as English.
;;;
;;; Its own endpoint rather than a field on the graph responses, for two
;;; reasons. It is asked for only when the graph actually CHANGES -- an add, a
;;; remove, the first concept -- and not on the focus refresh that runs after
;;; every click, so generation stays off the hot path. And a generator that
;;; signals cannot then take an otherwise successful edit down with it.
(hunchentoot:define-easy-handler (handle-editor-text :uri "/api/editor/text")
    (session)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (with-editor-session (s session)
    (multiple-value-bind (text note) (editor-english s)
      (format nil "{\"ok\":true,\"text\":\"~a\"~@[,\"note\":\"~a\"~]}"
              (json-escape text)
              (and note (json-escape note))))))

;;; --- Contextual type lists -------------------------------------------------
;;; Filtering is computed from the lattice, not guessed. Which of the three
;;; states we are in depends on what the editor pane holds.

(defun relation-long-name (relation-type)
  "The relation's long name, which by convention leads its :DESC -- \"agent -
   links [ACT] to...\" or just \"characteristic\". Empty string when absent."
  (let* ((d (or (desc relation-type) ""))
         (dash (search " -" d)))
    (string-trim " " (if dash (subseq d 0 dash) d))))

(defun json-relation-choices (entries)
  "ENTRIES is a list of (RELATION-TYPE . DIRECTION). A relation offered in both
   directions is marked, because that is exactly when the editor pane's arrows
   become clickable."
  (let ((both (loop for (rel . nil) in entries
                    when (> (count (label rel) entries
                                   :key (lambda (e) (label (car e))))
                            1)
                      collect (label rel))))
    (with-output-to-string (out)
      (write-char #\[ out)
      (loop for ((rel . direction) . rest) on entries do
        (format out "{\"label\":\"~(~a~)\",\"name\":\"~a\",\"direction\":\"~(~a~)\",\"both\":~:[false~;true~]}"
                (json-escape (string (label rel)))
                (json-escape (relation-long-name rel))
                direction
                (member (label rel) both))
        (when rest (write-char #\, out)))
      (write-char #\] out))))

(defun json-concept-choices (concept-types)
  (json-string-array (mapcar (lambda (c) (string-downcase (string (label c))))
                             concept-types)))

(defun all-concept-type-objects ()
  (loop for k being the hash-keys of *concept-type-catalog*
        using (hash-value v)
        unless (bottom-concept-type-p v) collect v))

;;; GET /api/editor/choices?session=N[&focus=REF][&relation=LABEL]
;;;     [&direction=forward|reverse][&target=REF]
;;;
;;; focus + target    -> relations legal between them, both directions labelled
;;; focus + relation  -> concept types legal at the far end
;;; focus only        -> every relation the focus could hang off, either way
;;; nothing           -> everything
(hunchentoot:define-easy-handler (handle-editor-choices :uri "/api/editor/choices")
    (session focus relation direction target)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (with-editor-session (s session)
    (handler-case
        (with-cg-thread-bindings
          (let* ((focus-node (when (and focus (plusp (length focus)))
                               (editor-concept s focus)))
                 (target-node (when (and target (plusp (length target)))
                                (editor-concept s target)))
                 (dir (if (string-equal (or direction "forward") "reverse")
                          :reverse :forward))
                 (relations
                   (cond ((and focus-node target-node)
                          (rel-uses-between (label (concept-type focus-node))
                                            (label (concept-type target-node))))
                         (focus-node
                          (rel-uses-for (label (concept-type focus-node))))
                         (t nil)))
                 (concepts
                   (cond ((and focus-node relation (plusp (length relation))
                               (not target-node))
                          (rel-far-end-types
                           (intern (string-upcase relation) :conceptual-graphs)
                           dir))
                         (t (all-concept-type-objects)))))
            (format nil "{\"ok\":true,\"concepts\":~a,\"relations\":~a}"
                    (json-concept-choices
                     (sort (copy-list concepts) #'alpha-lessp :key #'label))
                    (json-relation-choices relations))))
      (editor-operation-error (e) (json-error e))
      (error (e) (json-error e)))))

;;; POST /api/editor/disconnect?session=N
;;;
;;; The page's pagehide beacon. Marks the session disconnected -- it is NOT
;;; cancelled: the working graph survives and the URL still resumes it. This
;;; also fires on an ordinary reload, which is exactly why it must not mean
;;; cancel; the reload's next request reconnects and both halves are announced,
;;; so a refresh reads as a pair rather than an alarm.
;;;
;;; Not wrapped in WITH-EDITOR-SESSION, which would mark the session live again.
(hunchentoot:define-easy-handler (handle-editor-disconnect :uri "/api/editor/disconnect")
    (session)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (let ((s (find-editor-session session)))
    (when s (disconnect-editor-session s))
    "{\"ok\":true}"))

;;; POST /api/editor/finish?session=N&action=commit|cancel
(hunchentoot:define-easy-handler (handle-editor-finish :uri "/api/editor/finish")
    (session action)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (unless (eq (hunchentoot:request-method*) :post)
    (return-from handle-editor-finish
      (json-error "POST required" hunchentoot:+http-method-not-allowed+)))
  (with-editor-session (s session)
    (let ((state (cond ((string-equal (or action "") "commit") :committed)
                       ((string-equal (or action "") "cancel") :cancelled)
                       (t nil))))
      (cond ((null state) (json-error "action must be commit or cancel"))
            (t
             ;; A child has no blocked caller and no UNWIND-PROTECT behind it,
             ;; so finishing one has to drop it from the registry as well --
             ;; otherwise its URL keeps resolving and a stale tab could go on
             ;; editing a graph the user believes they closed.
             (let ((parent (session-parent s)))
               (if parent
                   (finish-nested-editor-session s state)
                   (finish-editor-session s state))
               (format nil "{\"ok\":true,\"state\":\"~(~a~)\"~@[,\"parent\":~a~]}"
                       state (and parent (session-id parent)))))))))
