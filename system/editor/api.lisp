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

(defun json-canonical-guidance (session focus)
  "The canonical graphs bearing on FOCUS's concept type, as a JSON array.

   Null-safe by design: a focus whose type has no canonical graph anywhere up
   its branches yields an empty array, which is the common case -- 39 of 225
   concept types carry one -- and the pane simply says so."
  (let* ((node (ignore-errors (editor-concept session focus)))
         (type-label (and node (ignore-errors (label (concept-type node)))))
         (guidance (and type-label
                        (ignore-errors
                         (with-cg-thread-bindings (canonical-guidance type-label)))))
         ;; What the focus actually has, to judge the guidance against.
         (actual (and guidance
                      (ignore-errors (editor-focus-arcs session focus)))))
    (with-output-to-string (out)
      (write-char #\[ out)
      (loop for (entry . rest) on guidance do
        (multiple-value-bind (states conflicts)
            (canonical-arc-conformance (getf entry :arcs) actual)
          (format out "{\"source\":\"~a\",\"inherited\":~:[false~;true~],\"text\":\"~a\",\"arcs\":["
                  (json-escape (getf entry :source))
                  (getf entry :inherited)
                  (json-escape (getf entry :text)))
          (loop for ((arc . state) . more) on states do
            (format out "{\"relation\":\"~a\",\"direction\":\"~(~a~)\",\"type\":\"~a\",\"state\":\"~(~a~)\"}"
                    (json-escape (getf arc :relation))
                    (getf arc :direction)
                    (json-escape (getf arc :type))
                    state)
            (when more (write-char #\, out)))
          ;; Conflicts are per GROUP, not per row, so they are their own list
          ;; rather than a third row state: an (attr)→[START-TIME] arc satisfies
          ;; one of TIME-PERIOD's two (attr) rows and violates neither, and a
          ;; per-row verdict has nowhere to say that.
          (write-string "],\"conflicts\":[" out)
          (loop for (conflict . more) on conflicts do
            (let ((a (getf conflict :actual)))
              (format out "{\"relationRef\":~a,\"relation\":\"~a\",\"direction\":\"~(~a~)\",~
                           \"type\":\"~a\",\"concept\":\"~a\",\"expected\":["
                      (getf a :relation-ref)
                      (json-escape (getf a :relation))
                      (getf a :direction)
                      (json-escape (getf a :concept-type))
                      (json-escape (getf a :concept)))
              (loop for (want . others) on (getf conflict :expected) do
                (format out "\"~a\"" (json-escape want))
                (when others (write-char #\, out)))
              (write-string "]}" out))
            (when more (write-char #\, out)))
          (write-string "]}" out))
        (when rest (write-char #\, out)))
      (write-char #\] out))))

(defun editor-graph-json (session &optional focus created)
  "The working graph plus, when FOCUS is given, its neighbourhood.

   PARENT rides along because the page has no other way to learn it is a nested
   editor: it is loaded from a URL carrying only its own session id, and what
   UPDATE should do -- veil, or return to the graph above -- depends on the
   answer.

   CREATED is the node-ref of a concept the operation just made. The page needs
   it to keep that concept in the target slot afterwards: a referent can only be
   edited on a node that exists, so without the ref the only way to name what
   you just built is to go and find it again."
  (format nil "{\"ok\":true,\"withRefs\":\"~a\",\"plain\":\"~a\"~@[,\"created\":~a~]~@[,\"parent\":~a~]~@[,\"focus\":~a~]~@[,\"canonical\":~a~]}"
          (json-escape (session-render session))
          (json-escape (session-plain-render session))
          created
          (let ((p (session-parent session)))
            (and p (session-id p)))
          (when focus
            (with-output-to-string (out)
              (write-char #\[ out)
              (loop for (entry . rest) on (editor-focus-arcs session focus) do
                (format out "{\"relationRef\":~a,\"relation\":\"~a\",\"direction\":\"~(~a~)\",\"conceptRef\":~a,\"concept\":\"~a\",\"pruneCount\":~a}"
                        (getf entry :relation-ref)
                        (json-escape (getf entry :relation))
                        (getf entry :direction)
                        (getf entry :concept-ref)
                        (json-escape (getf entry :concept))
                        (getf entry :prune-count))
                (when rest (write-char #\, out)))
              (write-char #\] out)))
          ;; Guidance rides along with the arcs rather than answering a request
          ;; of its own: the pane shows the two beside each other and a second
          ;; round trip would let them disagree about which focus they describe.
          (when focus (json-canonical-guidance session focus))))

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
  (multiple-value-bind (new-rel new-target)
      (editor-add-arc s
                      :focus focus
                      :relation relation
                      :target (and target (plusp (length target)) target)
                      :target-type (and target_type (plusp (length target_type))
                                        target_type)
                      :direction (if (string-equal (or direction "forward") "reverse")
                                     :reverse :forward))
    (declare (ignore new-rel))
    (editor-graph-json s focus (node-ref new-target))))

;;; POST /api/editor/replace?session=N&focus=REF&relation=REF
;;;      &target=REF | &target_type=LABEL
;;;
;;; Change which concept an existing arc points at, keeping the relation and
;;; its direction. Not remove-then-add: see EDITOR-REPLACE-TARGET for why the
;;; two are not interchangeable.
(define-editor-post (handle-editor-replace "/api/editor/replace")
    (session focus relation target target_type)
  (multiple-value-bind (new-rel new-target)
      (editor-replace-target s
                             :focus focus
                             :relation relation
                             :target (and target (plusp (length target)) target)
                             :target-type (and target_type (plusp (length target_type))
                                               target_type))
    (declare (ignore new-rel))
    (editor-graph-json s focus (node-ref new-target))))

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
                 \"verbal\":~:[false~;true~],\"open\":~:[false~;true~],\"members\":~a}"
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
            (referent-verbal-p concept)
            ;; Whether the set is open -- `{Fido, *}' rather than `{Fido}'.
            ;; Sent because the page cannot derive it: the members alone say
            ;; nothing about whether there are others, and a page that guessed
            ;; hid the count box on every set with a name in it.
            (rview-open v)
            ;; Positional: the ✕ beside a member names it by index, so the
            ;; order the page shows has to be the order the server removes by.
            (with-output-to-string (out)
              (write-char #\[ out)
              (loop for (m . rest) on (rview-members v) do
                (format out "{\"id\":~a,\"name\":~:[null~;\"~:*~a\"~]}"
                        (or (getf m :id) "null")
                        (let ((n (getf m :name))) (and n (json-escape n))))
                (when rest (write-char #\, out)))
              (write-char #\] out)))))

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
          ;; Set membership. Add takes an identity (the same one the selector
          ;; offers); remove takes the position the page is showing.
          ((string= field "set-add")
           (add-referent-set-member
            node
            :id (cond ((blank id) nil)
                      (t (or (parse-integer (string-trim " #" id) :junk-allowed t)
                             (editor-error "~a is not an individual id" id))))
            :name (unless (blank name) name)))
          ((string= field "set-remove")
           (remove-referent-set-member
            node (or (parse-integer (string-trim " " (or value "")) :junk-allowed t)
                     (editor-error "which member? expected a position"))))
          ;; Openness is a field of the set, not of its membership: it says
          ;; whether there are members BESIDES the ones listed. Blank closes,
          ;; same convention as `raising'.
          ((string= field "set-open")
           (set-referent-open node (and (not (blank value))
                                        (not (string-equal value "false")))))
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
    (session focus relation direction target under)
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
                         (t (all-concept-type-objects))))
                 ;; UNDER is the canonical graph's far end, sent when an arc in
                 ;; the guidance pane was clicked. It narrows the column the
                 ;; signature already filtered -- (obj) may legally reach most
                 ;; of the catalog while the canonical graph says this one
                 ;; wants [INFORMATION]. Applied last, and never widening:
                 ;; what is legal is still the signature's call.
                 ;; A relation the canonical graph names more than once
                 ;; constrains its far end to the DISJUNCTION of those types,
                 ;; so UNDER arrives as a comma-separated list.
                 ;;
                 ;; Narrowing is based on the SIGNATURE-legal set whenever a
                 ;; relation is known, even though a populated target would
                 ;; otherwise fall through to the whole catalog. The two roads
                 ;; to a narrowed column -- clicking a guidance row, and
                 ;; pulling an arc that has one -- ask the same question and
                 ;; must answer it the same way; based on whatever the column
                 ;; happened to hold, they would not.
                 (concepts (if (and under (plusp (length under)))
                               (narrow-to-subtypes
                                (if (and relation (plusp (length relation)))
                                    (rel-far-end-types
                                     (intern (string-upcase relation) :conceptual-graphs)
                                     dir)
                                    concepts)
                                (remove "" (uiop:split-string under :separator ",")
                                        :test #'string=))
                               concepts)))
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
             (let ((parent (session-parent s))
                   (web    (session-web-owned s)))
               (cond (parent (finish-nested-editor-session s state))
                     (web    (finish-web-editor-session s state))
                     (t      (finish-editor-session s state)))
               ;; RESULT rides back only for a web-owned commit: it is the ONLY
               ;; way that string reaches anyone, since no caller is blocked to
               ;; receive it. On cancel the page keeps what it already had, so
               ;; sending SESSION-ORIGINAL back would at best be redundant and
               ;; at worst overwrite an edit made in the form meanwhile.
               ;; WEB rides back on both outcomes, not just the commit RESULT
               ;; does: a page with nowhere to return to has to say what kind of
               ;; session just ended, and it cannot infer that from RESULT --
               ;; a cancelled web session sends none, exactly like a REPL one.
               ;;
               ;; ~:[~;…~] and not ~@[…~]: a true ~@[ does NOT consume its
               ;; argument, so a clause with no directive inside it to do the
               ;; consuming leaves WEB in place for the next one, and RESULT
               ;; came out as "T". ~:[ always consumes.
               (format nil "{\"ok\":true,\"state\":\"~(~a~)\"~@[,\"parent\":~a~]~
                            ~:[~;,\"web\":true~]~@[,\"result\":\"~a\"~]}"
                       state
                       (and parent (session-id parent))
                       web
                       (and web (eq state :committed)
                            (json-escape (or (session-result s) ""))))))))))

;;; --- Sessions opened by the browser rather than by a REPL call ---------------
;;;
;;; EDIT-CGRAPH's contract is that the caller BLOCKS and receives the result.
;;; The type browser has no caller to block: it wants to hand a string to the
;;; editor, let the page go away and come back, and get the edited string
;;; through the response rather than a return value.
;;;
;;; OPEN-NESTED-EDITOR-SESSION already proved the shape -- a session created by
;;; a request, whose semaphore nobody waits on and which
;;; FINISH-NESTED-EDITOR-SESSION drops rather than an UNWIND-PROTECT. This is
;;; that same shape with no parent, so WEB-OWNED is what distinguishes it: a
;;; session with neither a parent nor a blocked caller.

(defun open-web-string-session (text)
  "A :STRING session over TEXT for the browser to edit, with nobody waiting on
   it. The caller is a web page, so there is no *STANDARD-OUTPUT* worth
   capturing and no REPL to announce a disconnect to."
  (let ((session (make-editor-session
                  :original (or text "")
                  :kind :string
                  :web-owned t
                  :working (make-working-graph (or text "")))))
    (register-editor-session session)
    session))

(defun finish-web-editor-session (session state)
  "Complete a browser-owned session and drop it from the registry -- the same
   reason FINISH-NESTED-EDITOR-SESSION does it: no blocked caller means no
   UNWIND-PROTECT, so nothing else would ever forget it and its URL would go on
   resolving for a tab that believes it is done."
  (prog1 (finish-editor-session session state)
    (forget-editor-session session)))

;;; POST /api/editor/open-string?text=... — start a session on a linear-notation
;;; string and return its id. The page then navigates to /editor?session=N.
(hunchentoot:define-easy-handler (handle-editor-open-string
                                  :uri "/api/editor/open-string")
    (text)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (unless (eq (hunchentoot:request-method*) :post)
    (return-from handle-editor-open-string
      (json-error "POST required" hunchentoot:+http-method-not-allowed+)))
  (handler-case
      (with-cg-thread-bindings
        ;; Parsed here rather than at the far end so a malformed graph is
        ;; refused by the form that submitted it, where the field it came from
        ;; is still on screen -- not by an editor page you have already
        ;; navigated to and would have to navigate back from.
        (let ((session (open-web-string-session text)))
          (format nil "{\"ok\":true,\"session\":~a}" (session-id session))))
    (error (e) (json-error (princ-to-string e)))))
