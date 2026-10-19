;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :asdf-user)

;;; The conceptual-graph editor. A separate system from cgraph-web so it can be
;;; reloaded on its own, but NOT a separate server: its handlers register on the
;;; same acceptor, so it shares an origin with the type browser and reuses
;;; /api/types, /api/relations and /api/options without CORS.
;;;
;;; Design: notes/graph-editor.md

(defsystem "cgraph-editor"
  :description "Web-based conceptual-graph editor for cgraph"
  :depends-on ("cgraph" "cgraph-web" "hunchentoot" "bordeaux-threads")
  :in-order-to ((test-op (test-op "cgraph-editor/tests")))
  :serial t
  :components ((:module "system/editor"
                :serial t
                :components ((:file "session")
                             (:file "operations")
                             (:file "referent")
                             (:file "api")))))

;;; The editor's tests, as their own system, like cgraph/tests: loading the
;;; editor doesn't compile them, and (asdf:test-system :cgraph-editor) runs them
;;; and signals an error if any fails. They are kept out of (asdf:test-system
;;; :cgraph), which would otherwise need Hunchentoot to test the engine. They
;;; live in test/editor/ so that TEST-ALL, which looks for test/*-test.lisp,
;;; doesn't count them as cgraph suites. In a loaded image, (cg::editor-test t).
(defsystem "cgraph-editor/tests"
  :description "Test suites for the cgraph graph editor"
  :depends-on ("cgraph-editor" "cgraph/tests")
  :components ((:module "test/editor"
                :serial t
                :components ((:file "editor-operations-test")
                             (:file "referent-view-test"))))
  :perform (test-op (o c)
             (unless (uiop:symbol-call :conceptual-graphs :editor-test t)
               (error "cgraph-editor: some test suites failed (see the report above)."))))
