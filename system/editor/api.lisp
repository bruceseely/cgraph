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
  "Bind VAR to the session named by ID, or return a JSON error."
  `(let ((,var (find-editor-session ,id)))
     (cond ((null ,var) (json-error "no such editor session"))
           ((not (eq (session-state ,var) :open))
            (json-error "editor session is already finished"))
           (t ,@body))))

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
  "The working graph plus, when FOCUS is given, its neighbourhood."
  (format nil "{\"ok\":true,\"withRefs\":\"~a\",\"plain\":\"~a\"~@[,\"focus\":~a~]}"
          (json-escape (session-render session))
          (json-escape (session-plain-render session))
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
            (t (finish-editor-session s state)
               (format nil "{\"ok\":true,\"state\":\"~(~a~)\"}" state))))))
