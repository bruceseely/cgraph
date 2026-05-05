;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-


(defpackage :conceptual-graphs
  (:use #:cl #:cl-user #:uiop)
  (:nicknames :cg :cgraph))


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
                                           (:file "properties")
                                           (:file "individual")
                                           (:file "referent")
                                           (:file "set")
                                           (:file "conformity")
                                           (:file "concept")
                                           (:file "relation")
                                           (:file "graph")
                                           (:file "actor")
                                           (:file "link")
                                           (:file "context")
                                           (:file "coreference")
                                           (:file "graph-utils")
                                           (:file "segment")
                                           (:file "formatter")
                                           (:file "reader")))
                             (:module "operations"
	                      :depends-on ("setup" "core")
	                      :components ((:file "formation-rules")
                                           (:file "graph-combination")
                                           (:file "projection")
                                           (:file "maximal-join")
			                   (:file "cg-env")
                                           (:file "type-definition")
                                           (:file "query")))
                             (:module "graphing"
	                      :depends-on ("setup" "core")
	                      :components ((:file "concept-type-graph")))
                             (:module "generation"
	                      :depends-on ("setup" "core")
	                      :serial t
	                      :components ((:file "syntax-roles")
                                           (:file "walker")
                                           (:file "lexicon")
                                           (:file "morphology")
                                           (:file "anaphora")
                                           (:file "realize-np")
                                           (:file "realize-pp")
                                           (:file "realize-clause")
                                           (:file "generate")
                                           (:file "lexicon-lint")))))

               (:module "support"
                :serial t
	        :depends-on ("system")
	        :components (;;(:file "support-functions")
                             (:file "debug")
                             ;;(:file "path")
                             ))

	       (:module "test"
                :serial t
	        :depends-on ("system")
	        :components ((:file "graphs-for-testing")
                             (:file "type-test")
                             (:file "linkup-test")
                             (:file "segment-test")
                             (:file "variable-test")
                             (:file "individual-test")
                             (:file "referent-test")
                             (:file "graph-referent-test")
                             (:file "concept-test")
                             (:file "format-test")
                             (:file "normalize-test")
                             (:file "parse-test")
                             (:file "cache-test")
                             (:file "coreference-test")
                             (:file "negative-context-test")
                             (:file "graph-every-test")

                             (:file "formation-rules-test")
                             ;;(:file "cg-processing-test")
                             ;;(:file "formation-rules-test")
                             (:file "combine-test")
                             (:file "projection-test")
                             (:file "maximal-join-test")
                             (:file "type-definition-test")
                             (:file "query-test")

                             (:file "generation-test")

                             (:file "cgraph-tests")
                             ))))
