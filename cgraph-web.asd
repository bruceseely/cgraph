;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :asdf-user)

(defsystem "cgraph-web"
  :description "Web UI for cgraph using Hunchentoot"
  :depends-on ("cgraph" "hunchentoot")
  :serial t
  :components ((:module "system/web"
                :serial t
                :components ((:file "server")
                             (:file "api")))))
