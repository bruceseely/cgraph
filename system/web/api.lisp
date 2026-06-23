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
