;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-


(declaim (sb-ext:disable-package-locks set))
(in-package :asdf-user)

;;; (asdf:system-relative-pathname "cgraph" "concept-types.text")
;;; (asdf:system-source-directory "cgraph")
;;; (clear-system :cgraph)

(defsystem "cgraph"
    :description "basic implementation of Sowa's comceptual graphs"
  :version "0.0.1"
  :author "Bruce Seely <bruce@bseely.com>"
  ;;:licence "Public Domain"
  ;;:depends-on  <libraries>
  :components ((:module "default-types"
	        :components ((:static-file "concept-types.text")
	                     (:static-file "relation-types.text")))

               (:module "system"
	        :depends-on ("default-types")
	        :components ((:module "setup"
                              :serial t
	                      :components ((:file "definitions")
                                           (:file "initialize")
                                           (:file "basic-utilities")))
                             (:module "core"
	                      :depends-on ("setup")
                              :serial t
	                      :components ((:file "node")
			                   (:file "types")
                                           (:file "variable")
                                           (:file "individual")
                                           (:file "set")
                                           (:file "conformity")
			                   (:file "referent")
                                           (:file "concept")
                                           (:file "relation")
                                           (:file "actor")
                                           (:file "link")
                                           (:file "context")
                                           (:file "graph-utils")
                                           (:file "segment")
                                           (:file "formatter")
                                           (:file "reader")))
                             (:module "operations"
	                      :depends-on ("setup" "core")
	                      :components ((:file "formation-rules")
                                           (:file "graph-combination")
			                   (:file "cg-env")))
                             (:module "graphing"
	                      :depends-on ("setup" "core")
	                      :components ((:file "concept-type-graph")))))

               (:module "support"
                :serial t
	        :depends-on ("system")
	        :components ((:file "support-functions")
                             (:file "debug")
                             ;;(:file "path")
                             ))

	       (:module "test"
                :serial t
	        :depends-on ("system")
	        :components ((:file "graphs-for-test")
                             (:file "type-test")
                             (:file "linkup-test")
                             (:file "segment-test")
                             (:file "variable-test")
                             (:file "individual-test")
                             (:file "referent-test")
                             (:file "concept-test")
                             (:file "format-test")
                             (:file "parse-test")
                             (:file "cache-test")
                             (:file "context-test")
                             (:file "graph-every-test")

                             (:file "cg-processing-test")
                             ;;(:file "formation-rules-test")
                             (:file "atomic-formation-rules-test")
                             (:file "combine-test")

                             (:file "test-all")
                             ))))
