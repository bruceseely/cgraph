;;; -*- mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;; Helper: read a file from the web/ static directory as a string.
(defun read-static-file (filename)
  (uiop:read-file-string
   (merge-pathnames filename (web-static-dir))))

;;; Helper: split a string on commas and/or whitespace, dropping empty tokens.
(defun split-type-string (str)
  (let ((tokens '())
        (start nil))
    (loop for i from 0 below (length str)
          for c = (char str i)
          do (cond
               ((or (char= c #\,) (char= c #\Space) (char= c #\Tab)
                    (char= c #\Newline) (char= c #\Return))
                (when start
                  (push (subseq str start i) tokens)
                  (setf start nil)))
               (t
                (unless start (setf start i))))
          finally (when start
                    (push (subseq str start) tokens)))
    (nreverse tokens)))

;;; Helper: build a JSON array of strings without an external library.
(defun json-string-array (strings)
  (with-output-to-string (out)
    (write-char #\[ out)
    (loop for (s . rest) on strings do
      (write-char #\" out)
      ;; Escape backslash and double-quote only — type names are plain symbols.
      (loop for c across s do
        (when (or (char= c #\\) (char= c #\"))
          (write-char #\\ out))
        (write-char c out))
      (write-char #\" out)
      (when rest (write-char #\, out)))
    (write-char #\] out)))

;;; GET / — serve index.html
;;; Tell the browser never to cache the static assets — during active development
;;; a cached graph.js/index.html silently runs old code against new markup.
(defun no-store ()
  (setf (hunchentoot:header-out :cache-control) "no-store, must-revalidate"
        (hunchentoot:header-out :pragma) "no-cache"))

(hunchentoot:define-easy-handler (handle-index :uri "/") ()
  (setf (hunchentoot:content-type*) "text/html; charset=utf-8")
  (no-store)
  (read-static-file "index.html"))

;;; GET /graph.js — serve graph.js
(hunchentoot:define-easy-handler (handle-graph-js :uri "/graph.js") ()
  (setf (hunchentoot:content-type*) "application/javascript; charset=utf-8")
  (no-store)
  (read-static-file "graph.js"))

;;; GET /viz.js — serve vendored @viz-js/viz ES module
(hunchentoot:define-easy-handler (handle-viz-js :uri "/viz.js") ()
  (setf (hunchentoot:content-type*) "application/javascript; charset=utf-8")
  (no-store)
  (read-static-file "viz.js"))

;;; GET /api/dot?types=animal[,dog,...]&expand_sub=animal&expand_super=dog&reveal=cat
(hunchentoot:define-easy-handler (handle-api-dot :uri "/api/dot") (types expand_sub expand_super reveal)
  (setf (hunchentoot:content-type*) "text/plain; charset=utf-8")
  (let* ((raw (or types ""))
         ;; Split on commas and/or whitespace, drop empty tokens.
         (tokens (split-type-string raw))
         ;; Validate and resolve each token to a concept-type object.
         (validated
          (handler-case
              (mapcar #'(lambda (tok)
                          (let ((ct (get-concept-type tok)))
                            (unless ct
                              (error "Unknown concept type: ~a" tok))
                            ct))
                      tokens)
            (error (e)
              (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
              (return-from handle-api-dot
                (format nil "Bad request: ~a" e))))))
    (if (null validated)
        (progn
          (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
          "Bad request: no types specified")
        ;; Build name list as symbols (get-concept-type already resolved them,
        ;; but generate-concept-type-digraph wants symbols).
        (let ((name-list (mapcar #'(lambda (tok)
                                     (intern (string-upcase tok) :cg))
                                 tokens))
              ;; Expansion lists: intern each token and silently skip unknown types.
              (expand-sub-names
               (loop for tok in (split-type-string (or expand_sub ""))
                     for sym = (intern (string-upcase tok) :cg)
                     when (get-concept-type sym) collect sym))
              (expand-super-names
               (loop for tok in (split-type-string (or expand_super ""))
                     for sym = (intern (string-upcase tok) :cg)
                     when (get-concept-type sym) collect sym))
              (reveal-names
               (loop for tok in (split-type-string (or reveal ""))
                     for sym = (intern (string-upcase tok) :cg)
                     when (get-concept-type sym) collect sym)))
          (with-output-to-string (s)
            (generate-concept-type-digraph :type-name-list name-list
                                           :stream s
                                           :parents t
                                           :children t
                                           :hide-bottom t
                                           :expand-sub expand-sub-names
                                           :expand-super expand-super-names
                                           :reveal reveal-names))))))

;;; POST /api/initialize — reinitialize the concept-type system and reload types.
(hunchentoot:define-easy-handler (handle-api-initialize :uri "/api/initialize") ()
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (unless (eq (hunchentoot:request-method*) :post)
    (setf (hunchentoot:return-code*) hunchentoot:+http-method-not-allowed+)
    (return-from handle-api-initialize "{\"error\":\"POST required\"}"))
  (handler-case
      (progn
        (initialize-cgraph)
        "{\"ok\":true}")
    (error (e)
      (setf (hunchentoot:return-code*) hunchentoot:+http-internal-server-error+)
      (format nil "{\"error\":\"~a\"}" (json-escape (princ-to-string e))))))

;;; POST /api/save?types=...&expand_sub=...&reveal=...
;;; Writes <name>.dot and <name>.png to *cgraph-data-directory*.
(hunchentoot:define-easy-handler (handle-api-save :uri "/api/save") (types expand_sub reveal)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (unless (eq (hunchentoot:request-method*) :post)
    (setf (hunchentoot:return-code*) hunchentoot:+http-method-not-allowed+)
    (return-from handle-api-save "{\"error\":\"POST required\"}"))
  (let* ((raw    (or types ""))
         (tokens (split-type-string raw))
         (validated
          (handler-case
              (mapcar (lambda (tok)
                        (let ((ct (get-concept-type tok)))
                          (unless ct (error "Unknown concept type: ~a" tok))
                          ct))
                      tokens)
            (error (e)
              (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
              (return-from handle-api-save
                (format nil "{\"error\":\"~a\"}" (json-escape (princ-to-string e))))))))
    (when (null validated)
      (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
      (return-from handle-api-save "{\"error\":\"no types specified\"}"))
    (let* ((name-list (mapcar (lambda (tok) (intern (string-upcase tok) :cg)) tokens))
           (expand-sub-names
            (loop for tok in (split-type-string (or expand_sub ""))
                  for sym = (intern (string-upcase tok) :cg)
                  when (get-concept-type sym) collect sym))
           (reveal-names
            (loop for tok in (split-type-string (or reveal ""))
                  for sym = (intern (string-upcase tok) :cg)
                  when (get-concept-type sym) collect sym))
           ;; Derive filename the same way graph-concept-types does.
           (graph-name (string-trim "()"
                         (substitute #\- #\Space
                           (format nil "~(~a~)" name-list))))
           (dot-path (format nil "~a~a.dot" *cgraph-data-directory* graph-name))
           (png-path (format nil "~a~a.png" *cgraph-data-directory* graph-name))
           (dot-string
            (with-output-to-string (s)
              (generate-concept-type-digraph :type-name-list name-list
                                             :stream s
                                             :parents t :children t
                                             :hide-bottom t
                                             :expand-sub expand-sub-names
                                             :reveal reveal-names))))
      (ensure-directories-exist dot-path)
      (with-open-file (out dot-path :direction :output
                           :if-exists :supersede :if-does-not-exist :create)
        (write-string dot-string out))
      (let ((png-ok
             (handler-case
                 (progn (uiop:run-program (list "dot" "-Tpng" dot-path "-o" png-path)) t)
               (error () nil))))
        (format nil "{\"ok\":true,\"dot\":\"~a\",\"png\":~a}"
                (json-escape dot-path)
                (if png-ok (format nil "\"~a\"" (json-escape png-path)) "null"))))))

;;; POST /api/kill-ring?text=... — push text onto the Emacs kill-ring via SWANK.
(hunchentoot:define-easy-handler (handle-api-kill-ring :uri "/api/kill-ring") (text)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (unless (eq (hunchentoot:request-method*) :post)
    (setf (hunchentoot:return-code*) hunchentoot:+http-method-not-allowed+)
    (return-from handle-api-kill-ring "{\"error\":\"POST required\"}"))
  #+swank
  (handler-case
      (progn (swank:eval-in-emacs `(kill-new ,text)) "{\"ok\":true}")
    (error (e)
      (format nil "{\"ok\":false,\"error\":\"~a\"}" (json-escape (princ-to-string e)))))
  #-swank
  "{\"ok\":false,\"error\":\"SWANK not available\"}"
  )

;;; GET /api/options — the CL-side settings the browser UI honors.
;;; The page has no other channel to the option system, so anything the user
;;; sets through M-M-x customize-group cgraph (or initializations.lisp) reaches
;;; the browser here. Keys are the JSON spelling of the defvar name.
(hunchentoot:define-easy-handler (handle-api-options :uri "/api/options") ()
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (format nil "{\"canonical_graph_format\":\"~(~a~)\"}"
          (case *canonical-graph-format*
            (:graph "graph")
            (t      "linear"))))

;;; GET /api/types — list all registered concept types as a JSON array.
(hunchentoot:define-easy-handler (handle-api-types :uri "/api/types") ()
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (let ((names (loop for k being the hash-keys of *concept-type-catalog*
                     using (hash-value v)
                     unless (bottom-concept-type-p v)
                     collect (string-downcase (symbol-name k)))))
    (json-string-array (sort names #'string<))))

;;; ── Concept-type editor: create + persist ─────────────────────────────────────
;;; Slice 1 is append-only: create a new type (or persist a runtime-only :create
;;; type) and add its form to the ontology source file. Editing a type already IN
;;; the file needs an in-place splice and is deliberately out of scope here.

(defun concept-types-file ()
  "TRUENAME of the concept-types source file. Resolving the ~/.cgraph symlink up
front means every write targets the REAL file (the repo it links to), and never
replaces the link with a plain copy the way a write-then-rename save would."
  (truename (merge-pathnames "concept-types.lisp" *cgraph-types-directory*)))

;;; --- Type-definition files, either kind ------------------------------------
;;;
;;; concept-types.lisp and relation-types.lisp are both flat sequences of
;;; (:label ... ) plists, and the four functions below never look at any key
;;; but :label -- so they were already generic over the two files and only the
;;; names said otherwise. Splitting the label-neutral half out is what lets the
;;; relation endpoints reuse the whole read/splice/remove path rather than
;;; growing a parallel copy of it.

(defun type-def-in-file-p (label file)
  "True if FILE already carries a (:label LABEL ...) form (case-insensitive). Reads
under the standard readtable/:cg package so the CG readtable can't skew the plists."
  (with-open-file (in file :direction :input)
    (let ((*readtable* (copy-readtable nil))
          (*package* (find-package :cg)))
      (loop for def = (read in nil 'eof)
            until (eq def 'eof)
            thereis (let ((l (and (consp def) (getf def :label))))
                      (and l (string-equal (string l) (string label))))))))

(defun concept-type-def-string (label supertypes canonical note)
  "The one-line (:label ...) source form (no trailing newline). LABEL/SUPERTYPES are
lowercased to match the file's style; CANONICAL and NOTE appear only when non-empty
(:note is a comment key the loader tolerates via &allow-other-keys and keeps in file)."
  (format nil "(:label ~(~a~) :supertypes (~{~(~a~)~^ ~})~
               ~@[ :canonical-graph ~s~]~@[ :note ~s~])"
          (string label)
          (mapcar #'string supertypes)
          (and canonical (plusp (length canonical)) canonical)
          (and note (plusp (length note)) note)))

(defun append-concept-type-def (label supertypes canonical note file)
  "Append one (:label ...) form to FILE in place (:append never renames, so a
symlinked source keeps pointing at the edited file)."
  (with-open-file (out file :direction :output :if-exists :append :if-does-not-exist :error)
    (format out "~&~a~%" (concept-type-def-string label supertypes canonical note))))

(defun %skip-to-form (stream)
  "Advance STREAM past whitespace and ; line comments; return the file-position of the
next form's first character (STREAM left positioned there), or NIL at end of stream."
  (loop
    (let* ((pos (file-position stream))
           (c   (read-char stream nil :eof)))
      (cond ((eq c :eof) (return nil))
            ((member c '(#\Space #\Tab #\Newline #\Return #\Page #\Linefeed)) nil) ; whitespace
            ((char= c #\;)                                                          ; comment → skip to EOL
             (loop for d = (read-char stream nil :eof)
                   until (or (eq d :eof) (char= d #\Newline))))
            (t (file-position stream pos) (return pos))))))               ; found a form; rewind onto it

(defun type-def-form-span (label text)
  "The (START . END) character span of the (:label LABEL ...) top-level form within
TEXT — START at its opening paren, END just past its close — or NIL if absent. Reads
whole FORMS, so it matches a form that spans several lines. Standard readtable/:cg."
  (with-input-from-string (s text)
    (let ((*readtable* (copy-readtable nil))
          (*package* (find-package :conceptual-graphs)))
      (loop
        (let ((start (%skip-to-form s)))
          (when (null start) (return nil))
          (let ((form (ignore-errors (read s nil 'eof))))
            (when (or (null form) (eq form 'eof)) (return nil))
            (when (and (consp form)
                       (let ((l (getf form :label)))
                         (and l (string-equal (string l) (string label)))))
              ;; READ can advance file-position past a trailing delimiter (e.g. the
              ;; newline after the form); trim END back to just past the form's own
              ;; closing paren so the separating whitespace stays with the NEXT form.
              (let* ((fp    (file-position s))
                     (close (position #\) text :from-end t :end fp)))
                (return (cons start (if close (1+ close) fp)))))))))))

(defun splice-type-def (label new-text file)
  "Replace the (:label LABEL ...) form in FILE with NEW-TEXT, preserving every
other byte — comments, ordering, other types and their manual (even multi-line)
formatting — verbatim. Returns T if replaced, NIL if the form was absent (caller then
appends). Writes the truename'd path, so a ~/.cgraph symlink stays intact.

NEW-TEXT is rendered by the caller rather than by a def-string function passed in,
because the two kinds of definition take entirely different arguments and a
lambda-list that covered both would say less than the two call sites do."
  (let* ((text (uiop:read-file-string file))
         (span (type-def-form-span label text)))
    (when span
      (let ((out-text (concatenate 'string
                                   (subseq text 0 (car span))
                                   new-text
                                   (subseq text (cdr span)))))
        (with-open-file (out file :direction :output :if-exists :supersede :if-does-not-exist :error)
          (write-string out-text out)))
      t)))

(defun remove-type-def (label file)
  "Cut the (:label LABEL ...) form out of FILE, preserving every other byte.
Returns T if a form was removed, NIL if it was not there (a runtime-only type,
which is not an error -- the live catalog is still the thing being deleted).

The span ends just past the form's closing paren, so the newline the form was
written with is still ahead of it; taking that too is what keeps a delete from
leaving a blank line where the type used to be."
  (let* ((text (uiop:read-file-string file))
         (span (type-def-form-span label text)))
    (when span
      (let* ((end       (cdr span))
             (with-eol  (if (and (< end (length text)) (char= (char text end) #\Newline))
                            (1+ end)
                            end))
             (out-text  (concatenate 'string
                                     (subseq text 0 (car span))
                                     (subseq text with-eol))))
        (with-open-file (out file :direction :output :if-exists :supersede
                                  :if-does-not-exist :error)
          (write-string out-text out)))
      t)))

(defun type-name-mentioned-p (label text)
  "True when TEXT uses LABEL as a whole token. Tokens run over alphanumerics and
hyphens, so ABSTRACT-OBJECT is one name rather than two, and CAT does not match
inside CATALOG."
  (and text
       (let ((needle (string-downcase (string label)))
             (token-char (lambda (c) (or (alphanumericp c) (char= c #\-)))))
         (loop with down = (string-downcase text)
               with n = (length down)
               for start = 0 then (1+ pos)
               for pos = (search needle down :start2 start)
               while pos
               thereis (and (or (zerop pos)
                                (not (funcall token-char (char down (1- pos)))))
                            (let ((after (+ pos (length needle))))
                              (or (>= after n)
                                  (not (funcall token-char (char down after))))))))))

(defun concept-type-referrers (label)
  "Everything that would be left dangling by deleting LABEL: the types that
inherit from it, the types whose canonical graph names it, and the relation
types that list it as a source or destination. Returns a list of human-readable
strings, empty when the type is free to go."
  (let ((sym (intern (string-upcase (string label)) :cg))
        (found (list)))
    ;; Subtypes first -- deleting a type with children orphans them. The bounds
    ;; do not count: the lattice puts BOTTOM under everything, so every leaf has
    ;; it as a subtype, and counting it would make every leaf permanently
    ;; undeletable -- which is precisely the case a delete is FOR.
    (let ((node (ignore-errors (get-concept-type sym))))
      (when node
        (dolist (sub (direct-subtypes node))
          (unless (or (bottom-concept-type-p sub) (top-concept-type-p sub))
            (push (format nil "~(~a~) inherits from it" (label sub)) found)))))
    ;; canonical graphs of OTHER types
    (loop for other being the hash-values of *concept-type-catalog* do
      (unless (string-equal (string (label other)) (string label))
        (let ((canon (ignore-errors (canonical-graph-string other))))
          (when (type-name-mentioned-p label canon)
            (push (format nil "~(~a~)'s canonical graph names it" (label other))
                  found)))))
    ;; relation signatures
    (loop for rel being the hash-values of *relation-type-catalog* do
      (let ((dest (ignore-errors (dest-type rel)))
            (srcs (ignore-errors (source-types rel))))
        (when (and dest (string-equal (string (label dest)) (string label)))
          (push (format nil "relation (~(~a~)) points at it" (label rel)) found))
        (when (find-if (lambda (s) (string-equal (string (label s)) (string label)))
                       srcs)
          (push (format nil "relation (~(~a~)) comes from it" (label rel)) found))))
    (nreverse found)))

(defun type-def-file-note (label file)
  "The :note string stored for LABEL in FILE, or NIL. Notes live only in the file
(the loader drops them), so this is the only way to pre-fill a note for editing."
  (with-open-file (in file :direction :input)
    (let ((*readtable* (copy-readtable nil))
          (*package* (find-package :conceptual-graphs)))
      (loop for def = (read in nil 'eof)
            until (eq def 'eof)
            when (and (consp def)
                      (let ((l (getf def :label)))
                        (and l (string-equal (string l) (string label)))))
              return (getf def :note)))))

(defun rollback-concept-type (label)
  "Undo a just-created concept type named LABEL: unlink it from the hierarchy AND
drop it from the catalog. remove-concept-type only unlinks inheritance — it leaves
the catalog entry, so without the remhash the type would still surface in /api/types."
  (let ((node (ignore-errors (get-concept-type (intern (string-upcase label) :cg)))))
    (when node (ignore-errors (remove-concept-type node))))
  (let ((key (loop for k being the hash-keys of *concept-type-catalog*
                   when (string-equal (symbol-name k) (string-upcase label)) return k)))
    (when key (remhash key *concept-type-catalog*))))

(defun collapse-graph-whitespace (string)
  "Flatten a (possibly multi-line, indented) canonical graph to a single line:
every run of whitespace — spaces, tabs, and the RETURN/NEWLINE characters the editor
adds for readability — becomes one space. Canonical graphs are stored and parsed
without line breaks, so this runs on save. Collapsing runs (never to zero) keeps
tokens separated, so it can't merge adjacent tokens."
  (with-output-to-string (out)
    (let ((in-ws nil))
      (loop for c across string do
        (cond ((member c '(#\Space #\Tab #\Newline #\Return))
               (unless in-ws (write-char #\Space out))
               (setf in-ws t))
              (t (write-char c out)
                 (setf in-ws nil)))))))

(defun canonical-as-served (label node)
  "The canonical text /api/type-def hands the editor for LABEL: the stored string
re-emitted with line breaks and indentation, or the raw string when it will not
parse (so the type still opens to edit)."
  (let ((raw (or (canonical-graph-string node) "")))
    (if (plusp (length raw))
        (or (ignore-errors (formatted-canonical-graph-string label)) raw)
        "")))

(defun canonical-unchanged-p (submitted label node)
  "True when SUBMITTED — already whitespace-collapsed — is the canonical the editor
was handed for LABEL, either the stored string verbatim or the formatted form
collapsed back to one line.

Both arms are needed because format-cgraph walks the segment graph breadth-first,
so parse→format need not reproduce the stored text. Without this test, opening a
type and saving it untouched would splice a different-but-equivalent string into
concept-types.lisp — a spurious diff produced by having looked at the type."
  (let ((sub    (string-trim '(#\Space) (or submitted "")))
        (raw    (string-trim '(#\Space) (or (canonical-graph-string node) "")))
        (served (string-trim '(#\Space)
                             (collapse-graph-whitespace (canonical-as-served label node)))))
    (or (string= sub raw) (string= sub served))))

(defun supertypes-unchanged-p (tokens node)
  "True when TOKENS name exactly the direct supertypes NODE already has. Compared
the way /api/type-def presents them — top and bottom excluded, case-insensitive."
  (let ((current (loop for s in (direct-supertypes node)
                       unless (or (eq s *concept-type-top*) (eq s *concept-type-bottom*))
                         collect (symbol-name (label s)))))
    (and (= (length tokens) (length current))
         (null (set-difference tokens current :test #'string-equal))
         (null (set-difference current tokens :test #'string-equal)))))

(defun validate-canonical-graph (string)
  "Parse STRING as a conceptual graph against the live catalog; return NIL when it
is well-formed, else a one-line error message. Covers the three failure modes PCG
surfaces — unknown concept type, unknown relation type, malformed syntax.
parse-cgraph already re-signals concept-type and token errors with good text; the
relation lookup leaks its raw condition, so it is named here. *package* must be :cg:
reader.lisp interns bracketed type names in *package*, and the catalog is keyed :cg."
  (handler-case
      (progn (let ((*package* (find-package :conceptual-graphs)))
               (with-cg-readtable (pcg string)))
             nil)
    (relation-type-lookup-failed () "unknown relation type in the canonical graph")
    (error (e)
      (string-trim " " (substitute #\Space #\Newline (princ-to-string e))))))

;;; POST /api/create-type?label=...&supertypes=a,b&canonical=...&note=...
;;; Create the type live (so it shows at once — the catalog is process-global),
;;; validate any canonical graph, and append the form to the source file. Refuses a
;;; type already defined in the file; rejects (and rolls back) an invalid canonical.
(hunchentoot:define-easy-handler (handle-api-create-type :uri "/api/create-type")
    (label supertypes canonical note)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (unless (eq (hunchentoot:request-method*) :post)
    (setf (hunchentoot:return-code*) hunchentoot:+http-method-not-allowed+)
    (return-from handle-api-create-type "{\"error\":\"POST required\"}"))
  (handler-case
      (let* ((label        (and label (string-trim '(#\Space #\Tab) label)))
             (super-tokens (split-type-string (or supertypes "")))
             ;; collapse to one line: the stored/parsed form never has line breaks.
             (canonical    (and canonical (collapse-graph-whitespace canonical)))
             (canonical    (and canonical (string-trim '(#\Space) canonical)))
             (canonical    (and canonical (plusp (length canonical)) canonical))
             (note         (and note (string-trim '(#\Space #\Tab #\Newline #\Return) note)))
             (note         (and note (plusp (length note)) note)))
        (when (or (null label) (zerop (length label)))
          (error "a type name is required"))
        (when (null super-tokens)
          (error "at least one supertype is required"))
        ;; get-concept-type SIGNALS on an unknown label (it does not return nil),
        ;; so guard with ignore-errors to give a clean message.
        (dolist (s super-tokens)
          (unless (ignore-errors (get-concept-type s))
            (error "unknown supertype: ~a" s)))
        (let* ((file        (concept-types-file))
               (sym         (intern (string-upcase label) :cg))
               (super-syms  (mapcar (lambda (s) (intern (string-upcase s) :cg)) super-tokens))
               (pre-existed (ignore-errors (get-concept-type sym))))
          (when (type-def-in-file-p label file)
            (error "~a is already defined in the ontology file; ~
                    editing existing types is not yet supported" label))
          ;; live: create the type first (canonical attached only after it validates)
          ;; so a self-referential canonical — [WANT] in WANT's own graph — resolves.
          (define-concept-type :label sym :supertypes super-syms :canonical-graph "")
          (when canonical
            (let ((verr (validate-canonical-graph canonical)))
              (when verr
                ;; roll back a freshly-created type; leave a pre-existing one alone.
                (unless pre-existed (rollback-concept-type label))
                (error "invalid canonical graph: ~a" verr))
              (define-concept-type :label sym :supertypes super-syms
                                   :canonical-graph canonical)))
          ;; persist: append the form to the source file.
          (append-concept-type-def label super-tokens canonical note file)
          (format nil "{\"ok\":true,\"label\":\"~a\"}"
                  (json-escape (string-downcase label)))))
    (error (e)
      (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
      (format nil "{\"error\":\"~a\"}" (json-escape (princ-to-string e))))))

;;; GET /api/type-def?label=X — the editable definition for the Edit form: supertypes
;;; and canonical from the live catalog, note from the source file (the loader drops
;;; notes, so the file is the only place a note survives).
(hunchentoot:define-easy-handler (handle-api-type-def :uri "/api/type-def") (label)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (handler-case
      (let* ((label (and label (string-trim '(#\Space #\Tab) label)))
             (node  (and label (plusp (length label))
                         (ignore-errors (get-concept-type (intern (string-upcase label) :cg))))))
        (unless node (error "no such type: ~a" (or label "")))
        (let ((supers (loop for s in (direct-supertypes node)
                            unless (or (eq s *concept-type-top*) (eq s *concept-type-bottom*))
                              collect (string-downcase (symbol-name (label s)))))
              ;; format for the editor: parse the one-line stored string and re-emit
              ;; it with line breaks + indentation. (Saved back, the line breaks are
              ;; collapsed out again — see collapse-graph-whitespace, and
              ;; canonical-unchanged-p, which recognizes this exact text as "no edit".)
              (canon (canonical-as-served label node))
              (note  (or (type-def-file-note label (concept-types-file)) "")))
          (format nil "{\"label\":\"~a\",\"supertypes\":~a,\"canonical\":\"~a\",\"note\":\"~a\"}"
                  (json-escape (string-downcase label))
                  (json-string-array (sort supers #'string<))
                  (json-escape canon)
                  (json-escape note))))
    (error (e)
      (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
      (format nil "{\"error\":\"~a\"}" (json-escape (princ-to-string e))))))

;;; POST /api/edit-type?label=...&supertypes=a,b&canonical=...&note=...
;;; Replace an EXISTING type's definition: same checks as create, but the new
;;; definition supplants the old one — live and in the file (splice in place, or
;;; append if the type was runtime-only). The type must exist; because it does, the
;;; canonical is validated BEFORE mutating, so a bad graph leaves everything unchanged.
(hunchentoot:define-easy-handler (handle-api-edit-type :uri "/api/edit-type")
    (label supertypes canonical note)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (unless (eq (hunchentoot:request-method*) :post)
    (setf (hunchentoot:return-code*) hunchentoot:+http-method-not-allowed+)
    (return-from handle-api-edit-type "{\"error\":\"POST required\"}"))
  (handler-case
      (let* ((label        (and label (string-trim '(#\Space #\Tab) label)))
             (super-tokens (split-type-string (or supertypes "")))
             ;; the editor shows the canonical formatted (multi-line); strip those
             ;; line breaks back out so the stored/parsed form stays single-line.
             (canonical    (and canonical (collapse-graph-whitespace canonical)))
             (canonical    (and canonical (string-trim '(#\Space) canonical)))
             (canonical    (and canonical (plusp (length canonical)) canonical))
             (note         (and note (string-trim '(#\Space #\Tab #\Newline #\Return) note)))
             (note         (and note (plusp (length note)) note)))
        (when (or (null label) (zerop (length label)))
          (error "a type name is required"))
        (when (null super-tokens)
          (error "at least one supertype is required"))
        (let* ((sym  (intern (string-upcase label) :cg))
               (node (ignore-errors (get-concept-type sym))))
          (unless node
            (error "no such type to edit: ~a" label))
          (dolist (s super-tokens)
            (unless (ignore-errors (get-concept-type s))
              (error "unknown supertype: ~a" s)))
          (when (member label super-tokens :test #'string-equal)
            (error "a type cannot be its own supertype"))
          (let* ((file        (concept-types-file))
                 (canon-same  (canonical-unchanged-p canonical label node))
                 (supers-same (supertypes-unchanged-p super-tokens node))
                 (note-same   (string= (or note "")
                                       (or (type-def-file-note label file) ""))))
            ;; Nothing actually changed — leave the file alone. Merely opening a type
            ;; reformats its canonical for display, so without this a look-and-save
            ;; would rewrite the source line.
            (when (and canon-same supers-same note-same)
              (return-from handle-api-edit-type
                (format nil "{\"ok\":true,\"unchanged\":true,\"label\":\"~a\"}"
                        (json-escape (string-downcase label)))))
            ;; Something changed, but not the graph: persist the stored text rather
            ;; than the reformatted one, so a note or supertype edit does not drag a
            ;; relinearized canonical into the file with it.
            (let ((canonical (if canon-same
                                 (let ((raw (canonical-graph-string node)))
                                   (and raw (plusp (length raw)) raw))
                                 canonical)))
              ;; validate before mutating — the type already exists, so a self-ref resolves.
              (when canonical
                (let ((verr (validate-canonical-graph canonical)))
                  (when verr (error "invalid canonical graph: ~a" verr))))
              ;; live: replace the definition (modify supertypes + canonical).
              (define-concept-type :label sym
                                   :supertypes (mapcar (lambda (s) (intern (string-upcase s) :cg))
                                                       super-tokens)
                                   :canonical-graph (or canonical ""))
              ;; persist: splice the form in place, or append if it wasn't in the file.
              (unless (splice-type-def label (concept-type-def-string label super-tokens canonical note) file)
                (append-concept-type-def label super-tokens canonical note file))
              (format nil "{\"ok\":true,\"label\":\"~a\"}"
                      (json-escape (string-downcase label)))))))
    (error (e)
      (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
      (format nil "{\"error\":\"~a\"}" (json-escape (princ-to-string e))))))

;;; POST /api/delete-type?label=X — remove a concept type, live and on disk.
;;;
;;; The counterpart create has always needed: a type added by hand is a type
;;; that can be added by MISTAKE, and until now a misspelling was permanent --
;;; you could not rename it, because the label IS the identity, and you could
;;; not remove it either. So a typo lived in the ontology forever.
;;;
;;; Refuses rather than cascades. Everything that would be left dangling is
;;; reported in one message, so a refusal tells you what to fix instead of
;;; making you delete one referrer at a time to discover the next. Cascading
;;; would be the wrong default anyway: deleting a type that others inherit from
;;; is nearly always a mistake, and the one case it is not -- a fresh typo with
;;; nothing attached -- is exactly the case that passes these checks.
(hunchentoot:define-easy-handler (handle-api-delete-type :uri "/api/delete-type")
    (label)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (unless (eq (hunchentoot:request-method*) :post)
    (setf (hunchentoot:return-code*) hunchentoot:+http-method-not-allowed+)
    (return-from handle-api-delete-type "{\"error\":\"POST required\"}"))
  (handler-case
      (let ((label (and label (string-trim '(#\Space #\Tab) label))))
        (when (or (null label) (zerop (length label)))
          (error "a type name is required"))
        (let* ((sym  (intern (string-upcase label) :cg))
               (node (ignore-errors (get-concept-type sym))))
          (unless node
            (error "no such type: ~a" label))
          (when (or (top-concept-type-p node) (bottom-concept-type-p node))
            (error "~a is a bound of the lattice and cannot be deleted" label))
          ;; Validate everything before mutating anything -- same order create
          ;; follows, so a refusal leaves the catalog and the file untouched.
          (let ((referrers (concept-type-referrers label)))
            (when referrers
              (error "~a is still in use: ~{~a~^; ~}" label referrers)))
          (let* ((file    (concept-types-file))
                 (in-file (type-def-in-file-p label file)))
            ;; live first: rollback-concept-type unlinks the inheritance AND
            ;; drops the catalog entry, which is what keeps it out of /api/types.
            (rollback-concept-type label)
            (when in-file (remove-type-def label file))
            (format nil "{\"ok\":true,\"label\":\"~a\",\"removedFromFile\":~:[false~;true~]}"
                    (json-escape (string-downcase label))
                    in-file))))
    (error (e)
      (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
      (format nil "{\"error\":\"~a\"}" (json-escape (princ-to-string e))))))

;;; Helper: JSON-escape a string (handles the characters JSON requires escaping).
(defun json-escape (s)
  (with-output-to-string (out)
    (loop for c across s do
      (case c
        (#\" (write-string "\\\"" out))
        (#\\ (write-string "\\\\" out))
        (#\Newline (write-string "\\n" out))
        (#\Return  (write-string "\\r" out))
        (#\Tab     (write-string "\\t" out))
        (otherwise (write-char c out))))))

;;; Helper: serialize one relation entry as a JSON object.
(defun json-relation-entry (rel-type exact-p)
  (let* ((dest      (dest-type rel-type))
         (dest-name (if dest (string-upcase (symbol-name (label dest))) ""))
         (src-names (mapcar (lambda (st) (string-upcase (symbol-name (label st))))
                            (source-types rel-type))))
    (format nil "{\"name\":\"~a\",\"exact\":~a,\"desc\":\"~a\",\"dest\":\"~a\",\"sources\":~a}"
            (string-downcase (symbol-name (label rel-type)))
            (if exact-p "true" "false")
            (json-escape (or (desc rel-type) ""))
            dest-name
            (json-string-array src-names))))

;;; Helper: serialize a list of relation entries as a JSON array.
(defun json-relation-array (entries)
  (with-output-to-string (out)
    (write-char #\[ out)
    (loop for (entry . rest) on entries do
      (write-string entry out)
      (when rest (write-char #\, out)))
    (write-char #\] out)))

;;; GET /api/relations?type=animal
;;; Returns {as_input:[{name,exact,desc}…], as_output:[…]}
;;; "exact" is true when the relation's slot directly names this type
;;; (vs. inherited via a supertype).
(hunchentoot:define-easy-handler (handle-api-relations :uri "/api/relations") (type)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (let ((ct (and type (get-concept-type type))))
    (unless ct
      (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
      (return-from handle-api-relations
        (format nil "{\"error\":\"Unknown type: ~a\"}" (json-escape (or type "")))))
    (let ((input-entries '())
          (output-entries '()))
      (maphash
       #'(lambda (key rel)
           (declare (ignore key))
           ;; ── as input (source-types) ──────────────────────────────────────
           (let ((src-types (source-types rel)))
             (when (find ct src-types :test #'subtype-p)
               (let ((exact (not (null (member ct src-types :test #'eq)))))
                 (push (json-relation-entry rel exact) input-entries))))
           ;; ── as output (dest-type) ────────────────────────────────────────
           (let ((dst (dest-type rel)))
             (when (and dst (subtype-p ct dst))
               (let ((exact (eq ct dst)))
                 (push (json-relation-entry rel exact) output-entries)))))
       *relation-type-catalog*)
      ;; Sort each list: exact matches first, then alphabetically within each group.
      (flet ((entry-name (e) (let* ((s (search "\"name\":\"" e))
                                    (s2 (+ s 8)))
                               (subseq e s2 (position #\" e :start s2))))
             (entry-exact (e) (search "\"exact\":true" e)))
        (let ((sort-fn #'(lambda (a b)
                           (let ((ea (entry-exact a)) (eb (entry-exact b)))
                             (cond ((and ea (not eb)) t)
                                   ((and (not ea) eb) nil)
                                   (t (string< (entry-name a) (entry-name b))))))))
          (setf input-entries  (sort input-entries  sort-fn))
          (setf output-entries (sort output-entries sort-fn))))
      (let* ((cg-str (effective-canonical-graph-string ct))
             (type-name (string-downcase (symbol-name (label ct))))
             (cg-format-error nil)
             (cg-formatted
              (when (and cg-str (plusp (length cg-str)))
                (handler-case
                    (formatted-canonical-graph-string type-name)
                  (error (e)
                    (setf cg-format-error (princ-to-string e))
                    nil)))))
        (format nil "{\"canonical_graph\":\"~a\",\"canonical_graph_formatted\":\"~a\",\"canonical_graph_format_error\":\"~a\",\"as_input\":~a,\"as_output\":~a}"
                (json-escape (or cg-str ""))
                (json-escape (or cg-formatted ""))
                (json-escape (or cg-format-error ""))
                (json-relation-array input-entries)
                (json-relation-array output-entries))))))


;;;; ==========================================================================
;;;; Relation types: browse, create, edit, delete
;;;; ==========================================================================
;;;
;;; The concept-type endpoints above and these differ in what a definition
;;; HOLDS, not in how it is stored: both files are flat sequences of (:label ...)
;;; plists, so everything from TYPE-DEF-IN-FILE-P down through SPLICE-TYPE-DEF
;;; is shared and only the def-string differs.
;;;
;;; What is genuinely different is that a relation type's identity is a PAIR of
;;; concept types -- see notes/type-editor-integration.md §3 -- and that its
;;; English behaviour rides on the same form, as :role/:prep. That last part is
;;; why creating a relation from the UI is worth doing at all: a relation
;;; created without a role is silently dropped by the realizer, and this is the
;;; layer that can say so at the moment it happens.

(defun relation-types-file ()
  "TRUENAME of the relation-types source file. Resolved for the same reason
CONCEPT-TYPES-FILE resolves: ~/.cgraph/types/* are symlinks, and writing through
the link is what keeps the real file in the types repo as the thing being edited."
  (truename (merge-pathnames "relation-types.lisp" *cgraph-types-directory*)))

(defun relation-source-tokens-text (sources)
  "SOURCE-TYPES as the catalog file writes them: a bare name for one, a
parenthesised list for several. Mirrors RELATION-SOURCE-TEXT (types.lisp), which
does this for a live relation-type; this one works from the tokens a form submits,
before any type object exists."
  (if (= 1 (length sources))
      (format nil "~(~a~)" (string (first sources)))
      (format nil "(~{~(~a~)~^ ~})" (mapcar #'string sources))))

(defun relation-type-def-string (label sources dest role prep desc note)
  "The one-line (:label ...) source form for a relation type (no trailing newline).
Keys are emitted in the order the shipped file uses, and each optional one only
when non-empty, so a definition carrying no role reads exactly like the ones that
were there before :role existed."
  (format nil "(:label ~(~a~) :source-types ~a :dest-type ~(~a~)~
               ~@[ :role ~(~s~)~]~@[ :prep ~s~]~@[ :desc ~s~]~@[ :note ~s~])"
          (string label)
          (relation-source-tokens-text sources)
          (string dest)
          (and role (plusp (length role)) (intern (string-upcase role) :keyword))
          (and prep (plusp (length prep)) prep)
          (and desc (plusp (length desc)) desc)
          (and note (plusp (length note)) note)))

(defun append-relation-type-def (label sources dest role prep desc note file)
  "Append one (:label ...) relation form to FILE in place (:append never renames,
so a symlinked source keeps pointing at the edited file)."
  (with-open-file (out file :direction :output :if-exists :append :if-does-not-exist :error)
    (format out "~&~a~%" (relation-type-def-string label sources dest role prep desc note))))

(defun rollback-relation-type (label)
  "Undo a just-created relation type: drop it from the catalog AND drop any syntax
it registered. The second half matters because a rolled-back relation that left its
:role behind would keep answering RELATION-ROLE for a relation that no longer exists
-- exactly the stale registration CLEAR-RELATION-CATALOG exists to prevent."
  (let ((key (loop for k being the hash-keys of *relation-type-catalog*
                   when (string-equal (symbol-name k) (string-upcase (string label)))
                     return k)))
    (when key (remhash key *relation-type-catalog*)))
  (ignore-errors (unregister-relation-syntax label)))

(defun relation-type-referrers (label)
  "Everything left dangling by deleting relation LABEL: the concept types whose
canonical graph uses it. Returns human-readable strings, empty when it is free to go.

Shorter than CONCEPT-TYPE-REFERRERS because relation types have no hierarchy to
orphan and nothing else points at them -- the three PP support tables name them, but
an entry there that stops firing is what %LINT-STALE-RELATION-ENTRIES already reports
as :info, so blocking a delete on it would be stronger than the lint's own verdict."
  (let ((found (list)))
    (loop for ct being the hash-values of *concept-type-catalog* do
      (let ((canon (ignore-errors (canonical-graph-string ct))))
        (when (type-name-mentioned-p label canon)
          (push (format nil "~(~a~)'s canonical graph uses it" (label ct)) found))))
    (nreverse found)))

(defun relation-syntax-warning (label)
  "The warning to show after creating or editing relation LABEL, or NIL.

The CONDITION comes from %LINT-RELATION-SYNTAX-COVERAGE rather than being
restated here, so the form and the startup lint can never disagree about what
counts as unrealizable. The REMEDY is reworded, because the lint's own text
tells you to call REGISTER-RELATION-SYNTAX or edit a source file, and neither is
what someone looking at a form with a Role field should be told to do.

Not an error. A relation with no role is legal and sometimes right -- one used
only for projection needs none -- so the write succeeds and this is advice."
  (let ((finding (find (intern (string-upcase (string label)) :cg)
                       (ignore-errors (%lint-relation-syntax-coverage))
                       :key #'fourth)))
    (and finding
         (format nil "~a has no syntax role, so it will not appear in generated ~
                      English. Set Role to say how it should surface."
                 (string-downcase (string label))))))

(defun relation-type-json (rel &optional extra-pairs)
  "One relation type as the browser pane wants it: signature, description, and the
syntax role, which is the part no existing endpoint reports.

EXTRA-PAIRS is a list of pre-rendered \"key\":value strings appended inside the
object, so the Edit endpoint can add its note and warning without either
re-listing these fields or splicing braces back together."
  (let* ((label (string-downcase (string (label rel))))
         (dest  (ignore-errors (dest-type rel)))
         (srcs  (relation-source-list rel))
         (role  (ignore-errors (relation-role (label rel))))
         (prep  (ignore-errors (relation-preposition (label rel)))))
    (format nil "{\"label\":\"~a\",\"sources\":~a,\"dest\":\"~a\",\"desc\":\"~a\",~
                 \"role\":\"~a\",\"prep\":\"~a\"~{,~a~}}"
            (json-escape label)
            (json-string-array
             (mapcar (lambda (s) (string-downcase (string (label s)))) srcs))
            (json-escape (if dest (string-downcase (string (label dest))) ""))
            (json-escape (or (ignore-errors (desc rel)) ""))
            (json-escape (if role (string-downcase (symbol-name role)) ""))
            (json-escape (or prep ""))
            extra-pairs)))

;;; GET /api/relation-types — the whole relation catalog, for the browser pane.
(hunchentoot:define-easy-handler (handle-api-relation-types :uri "/api/relation-types") ()
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (handler-case
      (let ((rels (sort (loop for r being the hash-values of *relation-type-catalog*
                              collect r)
                        #'string< :key (lambda (r) (string (label r))))))
        (format nil "[~{~a~^,~}]" (mapcar #'relation-type-json rels)))
    (error (e)
      (setf (hunchentoot:return-code*) hunchentoot:+http-internal-server-error+)
      (format nil "{\"error\":\"~a\"}" (json-escape (princ-to-string e))))))

;;; GET /api/relation-type-def?label=X — the editable definition for the Edit form.
(hunchentoot:define-easy-handler (handle-api-relation-type-def :uri "/api/relation-type-def")
    (label)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (handler-case
      (let* ((label (and label (string-trim '(#\Space #\Tab) label)))
             (rel   (and label (plusp (length label))
                         (ignore-errors (get-relation-type
                                         (intern (string-upcase label) :cg))))))
        (unless rel (error "no such relation type: ~a" (or label "")))
        ;; The note lives only in the file -- the loader drops it -- so it is read
        ;; from there, exactly as /api/type-def does on the concept side.
        (let ((note (or (ignore-errors
                         (type-def-file-note label (relation-types-file)))
                        "")))
          (relation-type-json
           rel
           (list (format nil "\"note\":\"~a\"" (json-escape note))
                 (format nil "\"warning\":\"~a\""
                         (json-escape (or (relation-syntax-warning label) "")))))))
    (error (e)
      (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
      (format nil "{\"error\":\"~a\"}" (json-escape (princ-to-string e))))))

(defun parse-relation-form (label sources dest role prep desc note)
  "Validate and normalize a relation form's fields, returning them as a plist.
Signals with a one-line message on anything the catalog would refuse.

Everything is checked BEFORE any mutation, which is what lets both create and
edit leave the catalog and the file untouched when a submission is bad."
  (let* ((label   (and label (string-trim '(#\Space #\Tab) label)))
         (src-tok (split-type-string (or sources "")))
         (dest    (and dest (string-trim '(#\Space #\Tab) dest)))
         (role    (and role (string-trim '(#\Space #\Tab) role)))
         (role    (and role (plusp (length role)) role))
         (prep    (and prep (string-trim '(#\Space #\Tab) prep)))
         (prep    (and prep (plusp (length prep)) prep))
         (desc    (and desc (string-trim '(#\Space #\Tab #\Newline #\Return) desc)))
         (desc    (and desc (plusp (length desc)) desc))
         (note    (and note (string-trim '(#\Space #\Tab #\Newline #\Return) note)))
         (note    (and note (plusp (length note)) note)))
    (when (or (null label) (zerop (length label)))
      (error "a relation name is required"))
    (when (null src-tok)
      (error "at least one source type is required"))
    (when (or (null dest) (zerop (length dest)))
      (error "a destination type is required"))
    ;; get-concept-type SIGNALS on an unknown label rather than returning nil,
    ;; so each lookup is guarded to give a clean message instead of a backtrace.
    (dolist (s src-tok)
      (unless (ignore-errors (get-concept-type s))
        (error "unknown source type: ~a" s)))
    (unless (ignore-errors (get-concept-type dest))
      (error "unknown destination type: ~a" dest))
    ;; A preposition without a role reads as a field left behind by changing the
    ;; role to one that has no preposition, and would be written to the file
    ;; where nothing would ever read it.
    (when (and prep (null role))
      (error "a preposition needs a role (:pp or :iobj) to belong to"))
    (list :label label :sources src-tok :dest dest
          :role role :prep prep :desc desc :note note)))

(defun install-relation-type (fields)
  "Create or replace the live relation type described by FIELDS, syntax included.
Goes through PARSE-RELATION-TYPE-DEF -- the loader's own entry point -- rather
than MAKE-RELATION-TYPE, so a type created here takes exactly the path a type
loaded from the file takes, :role hook and all."
  (destructuring-bind (&key label sources dest role prep desc note) fields
    (declare (ignore note))
    (parse-relation-type-def
     (append (list :label (intern (string-upcase label) :cg)
                   :source-types (mapcar (lambda (s) (intern (string-upcase s) :cg))
                                         sources)
                   :dest-type (intern (string-upcase dest) :cg))
             (when desc (list :desc desc))
             (when role (list :role (intern (string-upcase role) :keyword)))
             (when prep (list :prep prep)))
     t)))

(defun relation-write-response (label warning)
  "The shared success shape for create and edit. WARNING is a message, not an
error: the write succeeded either way, and the UI decides how loudly to say it."
  (format nil "{\"ok\":true,\"label\":\"~a\",\"warning\":\"~a\"}"
          (json-escape (string-downcase label))
          (json-escape (or warning ""))))

;;; POST /api/create-relation-type?label=&sources=a,b&dest=&role=&prep=&desc=&note=
;;; Create the relation live (the catalog is process-global, so it shows at once)
;;; and append the form to the source file. Refuses one already in the file.
;;;
;;; The response carries a WARNING, not just an error or an ok: a relation with no
;;; syntax role is perfectly legal and completely invisible in generated English,
;;; and that is precisely the failure notes/type-editor-integration.md §4 is about.
;;; Refusing it would be wrong -- a relation used only for projection needs no role
;;; -- and staying silent is what made the gap hard to find in the first place.
(hunchentoot:define-easy-handler (handle-api-create-relation-type
                                  :uri "/api/create-relation-type")
    (label sources dest role prep desc note)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (unless (eq (hunchentoot:request-method*) :post)
    (setf (hunchentoot:return-code*) hunchentoot:+http-method-not-allowed+)
    (return-from handle-api-create-relation-type "{\"error\":\"POST required\"}"))
  (handler-case
      (let* ((fields (parse-relation-form label sources dest role prep desc note))
             (label  (getf fields :label))
             (file   (relation-types-file)))
        (when (type-def-in-file-p label file)
          (error "~a is already defined in the relation file; use Edit to change it"
                 label))
        (install-relation-type fields)
        (handler-case
            (destructuring-bind (&key sources dest role prep desc note &allow-other-keys)
                fields
              (append-relation-type-def label sources dest role prep desc note file))
          ;; The live half succeeded and the file half did not: leave nothing
          ;; behind that the next reload would silently drop.
          (error (e) (rollback-relation-type label) (error e)))
        (relation-write-response label (relation-syntax-warning label)))
    (error (e)
      (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
      (format nil "{\"error\":\"~a\"}" (json-escape (princ-to-string e))))))

;;; POST /api/edit-relation-type — same checks as create; the new definition
;;; supplants the old one live and in the file (spliced in place, or appended if
;;; the relation was runtime-only). The relation must already exist.
(hunchentoot:define-easy-handler (handle-api-edit-relation-type
                                  :uri "/api/edit-relation-type")
    (label sources dest role prep desc note)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (unless (eq (hunchentoot:request-method*) :post)
    (setf (hunchentoot:return-code*) hunchentoot:+http-method-not-allowed+)
    (return-from handle-api-edit-relation-type "{\"error\":\"POST required\"}"))
  (handler-case
      (let* ((fields (parse-relation-form label sources dest role prep desc note))
             (label  (getf fields :label)))
        (unless (ignore-errors (get-relation-type (intern (string-upcase label) :cg)))
          (error "no such relation type: ~a" label))
        ;; An edit that drops :role must drop the registration too. Nothing else
        ;; would: INSTALL-RELATION-TYPE only ever ADDS a registration, so without
        ;; this the old role would survive its own removal.
        (ignore-errors (unregister-relation-syntax label))
        (install-relation-type fields)
        (destructuring-bind (&key sources dest role prep desc note &allow-other-keys)
            fields
          (let ((file (relation-types-file)))
            (unless (splice-type-def
                     label
                     (relation-type-def-string label sources dest role prep desc note)
                     file)
              ;; Runtime-only until now -- persist it rather than losing the edit.
              (append-relation-type-def label sources dest role prep desc note file))))
        (relation-write-response label (relation-syntax-warning label)))
    (error (e)
      (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
      (format nil "{\"error\":\"~a\"}" (json-escape (princ-to-string e))))))

;;; POST /api/delete-relation-type?label=X
(hunchentoot:define-easy-handler (handle-api-delete-relation-type
                                  :uri "/api/delete-relation-type")
    (label)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (unless (eq (hunchentoot:request-method*) :post)
    (setf (hunchentoot:return-code*) hunchentoot:+http-method-not-allowed+)
    (return-from handle-api-delete-relation-type "{\"error\":\"POST required\"}"))
  (handler-case
      (let ((label (and label (string-trim '(#\Space #\Tab) label))))
        (when (or (null label) (zerop (length label)))
          (error "a relation name is required"))
        (unless (ignore-errors (get-relation-type (intern (string-upcase label) :cg)))
          (error "no such relation type: ~a" label))
        ;; Validate before mutating, the order create and the concept-side delete
        ;; both follow: a refusal leaves catalog and file untouched.
        (let ((referrers (relation-type-referrers label)))
          (when referrers
            (error "~a is still in use: ~{~a~^; ~}" label referrers)))
        (let* ((file    (relation-types-file))
               (in-file (type-def-in-file-p label file)))
          (rollback-relation-type label)
          (when in-file (remove-type-def label file))
          (format nil "{\"ok\":true,\"label\":\"~a\",\"removedFromFile\":~:[false~;true~]}"
                  (json-escape (string-downcase label))
                  in-file)))
    (error (e)
      (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
      (format nil "{\"error\":\"~a\"}" (json-escape (princ-to-string e))))))
