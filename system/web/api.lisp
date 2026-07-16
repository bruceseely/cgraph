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
(hunchentoot:define-easy-handler (handle-index :uri "/") ()
  (setf (hunchentoot:content-type*) "text/html; charset=utf-8")
  (read-static-file "index.html"))

;;; GET /graph.js — serve graph.js
(hunchentoot:define-easy-handler (handle-graph-js :uri "/graph.js") ()
  (setf (hunchentoot:content-type*) "application/javascript; charset=utf-8")
  (read-static-file "graph.js"))

;;; GET /viz.js — serve vendored @viz-js/viz ES module
(hunchentoot:define-easy-handler (handle-viz-js :uri "/viz.js") ()
  (setf (hunchentoot:content-type*) "application/javascript; charset=utf-8")
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

(defun concept-type-in-file-p (label file)
  "True if FILE already carries a (:label LABEL ...) form (case-insensitive). Reads
under the standard readtable/:cg package so the CG readtable can't skew the plists."
  (with-open-file (in file :direction :input)
    (let ((*readtable* (copy-readtable nil))
          (*package* (find-package :cg)))
      (loop for def = (read in nil 'eof)
            until (eq def 'eof)
            thereis (let ((l (and (consp def) (getf def :label))))
                      (and l (string-equal (string l) (string label))))))))

(defun append-concept-type-def (label supertypes canonical note file)
  "Append one (:label ...) form to FILE in place (:append never renames, so a
symlinked source keeps pointing at the edited file). LABEL/SUPERTYPES are written
lowercased to match the file's style; CANONICAL and NOTE are added only when
non-empty (:note is a comment key the loader tolerates and keeps in the file)."
  (with-open-file (out file :direction :output :if-exists :append
                            :if-does-not-exist :error)
    (format out "~&(:label ~(~a~) :supertypes (~{~(~a~)~^ ~})~
                 ~@[ :canonical-graph ~s~]~@[ :note ~s~])~%"
            (string label)
            (mapcar #'string supertypes)
            (and canonical (plusp (length canonical)) canonical)
            (and note (plusp (length note)) note))))

(defun rollback-concept-type (label)
  "Undo a just-created concept type named LABEL: unlink it from the hierarchy AND
drop it from the catalog. remove-concept-type only unlinks inheritance — it leaves
the catalog entry, so without the remhash the type would still surface in /api/types."
  (let ((node (ignore-errors (get-concept-type (intern (string-upcase label) :cg)))))
    (when node (ignore-errors (remove-concept-type node))))
  (let ((key (loop for k being the hash-keys of *concept-type-catalog*
                   when (string-equal (symbol-name k) (string-upcase label)) return k)))
    (when key (remhash key *concept-type-catalog*))))

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
             (canonical    (and canonical (string-trim '(#\Space #\Tab #\Newline #\Return)
                                                       canonical)))
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
          (when (concept-type-in-file-p label file)
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
