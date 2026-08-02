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
  :serial t
  :components ((:module "system/editor"
                :serial t
                :components ((:file "session")
                             (:file "operations")
                             (:file "referent")
                             (:file "api")))
               ;; Under test/editor/ rather than test/, because
               ;; EXTRACT-TEST-NAMES scans test/ by filename and
               ;; UIOP:DIRECTORY-FILES is not recursive -- so TEST-CGRAPH
               ;; keeps passing for anyone who loads only :cgraph. Run these
               ;; with (EDITOR-TEST).
               (:module "test/editor"
                :depends-on ("system/editor")
                :serial t
                :components ((:file "editor-operations-test")
                             (:file "referent-view-test")))))
