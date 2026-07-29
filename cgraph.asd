;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-


(defpackage :conceptual-graphs
  (:use #:cl #:cl-user #:uiop)
  (:nicknames :cg :cgraph))


(declaim (sb-ext:disable-package-locks set))
;; cgraph rebinds/redefines several CL-standard symbols (SET, TYPE, CONJUGATE,
;; ...) as part of the conceptual-graph vocabulary. Unlock the COMMON-LISP
;; package here, in the system definition, so (ql:quickload :cgraph) works in
;; any SBCL image -- rather than relying on the user having
;; (sb-ext:unlock-package :common-lisp) in their own init (a silent onboarding
;; blocker for new users).
#+sbcl (sb-ext:unlock-package :common-lisp)
(in-package :asdf-user)

;;; (asdf:system-relative-pathname "cgraph" "concept-types.text")
;;; (asdf:system-source-directory "cgraph")
;;; (clear-system :cgraph)

(defsystem "cgraph"
  :description "basic implementation of Sowa's comceptual graphs"
  :version "0.0.1"
  :author "Bruce Seely <bruce@bseely.com>"
  ;;:licence "Public Domain"
  ;; swank must be present: source files reference swank::eval-in-emacs literally
  ;; at load time, so without it the load aborts ("package SWANK does not exist").
  ;; In a live SLIME image swank is already loaded; declaring it makes a plain
  ;; (ql:quickload :cgraph) self-sufficient too.
  :depends-on (:swank)
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
	        :components (;; support-functions is the "cgraph/support" system, below
                             (:file "debug")
                             ;;(:file "path")
                             ))

	       (:module "test"
                :serial t
	        :depends-on ("system")
	        :components ((:file "cgraph-tests")
                             (:file "graphs-for-testing")
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
                             (:file "generation-roots-lint-test")
                             ))))


;;; REPL and debugging tools -- SUP:RAPROPOS and friends, in package
;;; :cgraph-support (nickname :sup).  Kept as a secondary system so the main
;;; system needn't depend on cl-ppcre, which nothing else here uses.  It
;;; deliberately depends on nothing from :cgraph, so it can move to a
;;; repository of its own later without untangling anything.
;;; setup-cgraph loads it; on its own: (asdf:load-system "cgraph/support")
(defsystem "cgraph/support"
  :description "Lisp REPL and debugging tools, in package :cgraph-support (:sup)"
  :author "Bruce Seely <bruce@bseely.com>"
  :depends-on (:cl-ppcre)
  :components ((:module "support"
                :components ((:file "support-functions")))))
