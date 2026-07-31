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
