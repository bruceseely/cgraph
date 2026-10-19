;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-


(defpackage :conceptual-graphs
  (:use #:cl #:uiop)
  ;; SET and TYPE are conceptual-graph vocabulary (the SET node class, the TYPE
  ;; reader on type objects). Shadow them so cgraph gets its own symbols instead
  ;; of redefining COMMON-LISP's, which would need CL's package lock removed.
  ;; UNION, INTERSECTION and SET-DIFFERENCE are cgraph's own versions with a
  ;; defined result order (system/setup/set-operations.lisp): the standard
  ;; leaves it unspecified, and the order graphs are walked in comes from it.
  (:shadow #:set #:type #:union #:intersection #:set-difference)
  (:nicknames :cg :cgraph)
  ;; The public API: what API.md documents, plus the entry points it doesn't
  ;; cover yet. Everything else is internal and reachable only as CG::NAME.
  (:export
   ;; --- classes and conditions
   #:concept #:relation #:graph #:concept-type #:relation-type
   #:individual #:referent #:context
   #:concept-type-lookup-failed #:relation-type-lookup-failed
   #:relation-signature-mismatch #:mismatch-concept #:mismatch-relation #:mismatch-side

   ;; --- setup and initialization
   #:init #:setup-cgraph #:initialize-cgraph #:reset-cgraph #:report-directories
   #:create-type-set
   #:ensure-concept-types-exist #:ensure-relation-types-exist

   ;; --- types: create / modify
   #:define-concept-type #:make-concept-type #:modify-concept-type
   #:remove-concept-type #:make-relation-type

   ;; --- types: look up
   #:get-concept-type #:get-relation-type #:lookup-concept-type
   #:concept-type-defined-p #:concept-type-exists #:relation-type-exists
   #:label #:source-types #:dest-type

   ;; --- types: hierarchy queries
   #:subtype-p #:supertype-p #:proper-subtype-p #:proper-supertype-p #:subsumes-p
   #:subtypes #:proper-subtypes #:supertypes #:proper-supertypes
   #:direct-subtypes #:direct-supertypes
   #:maximal-common-subtype #:minimal-common-supertype
   #:common-subtypes #:common-supertypes #:rel-use

   ;; --- types: listing, walking, I/O, validation
   #:all-concept-types #:all-relation-types #:collect-concept-types
   #:walk-concept-types #:walk-concept-types-down #:walk-concept-types-up
   #:print-concept-types #:print-relation-types #:describe-concept-types
   #:save-concept-types #:save-relation-types
   #:load-concept-types #:load-relation-types
   #:check-type-lattice

   ;; --- concepts
   #:make-concept #:get-concept
   #:properties #:referent-name #:generic-p #:is-type #:concept-p
   #:describe-concept #:concepts-equal #:referents-equal
   #:inarcs #:outarcs

   ;; --- relations
   #:make-relation #:relation-p #:outarc #:valence #:signature
   #:connecting-relation #:relations-equal

   ;; --- graphs
   #:make-cgraph #:parse-cgraph
   #:cgraph-parse-error #:parse-error-string #:parse-error-position
   #:parse-error-message #:parse-error-cause
   #:head #:graph-head #:nodes #:graph-concepts #:graph-relations
   #:concepts-of-type #:concept-count #:relation-count #:graph-p #:graphs-equal
   #:graph-referent #:graph-referent-p #:referent-concepts #:referent-relations

   ;; --- individuals and referents
   #:make-individual #:get-individual #:find-individual-with-id
   #:individual-p #:individuals-equal
   #:make-referent #:referent-p #:content #:name-property #:measure-property
   #:conforms

   ;; --- formatting and string utilities
   #:format-cgraph #:format-concept #:format-relation #:print-cgraph
   #:graph-every-concept
   #:normalize-cgraph-string #:flatten-cgraph
   #:arrows-to-ascii #:arrows-to-unicode

   ;; --- graph operations
   #:copy-concept #:copy-relation #:copy-cgraph
   #:restrict-by-type #:restrict-by-referent #:restrict
   #:join-concepts #:concepts-joinable-p #:types-joinable-p #:simplify
   #:project #:projection-p #:projection-mapping #:all-projections
   #:format-projection-mapping
   #:maximal-join #:maximal-join-mapping #:format-join-mapping
   #:combine-conceptual-graphs

   ;; --- queries and type definitions
   #:query #:format-query-results
   #:expand-type #:ensure-definition-parsed

   ;; --- contexts
   #:make-context #:add-cgraph #:include-cgraph
   #:add-concept #:remove-concept #:graph-present-p #:graphs
   #:retrieve-concepts-having-properties #:retrieve-concepts-having-individual
   #:retrieve-concept
   #:concepts-with-graph-referents #:all-graph-referents

   ;; --- text generation
   #:graph-to-text #:graphs-to-text #:say

   ;; --- visualization
   #:graph-concept-types #:generate-concept-type-digraph #:display-graph

   ;; --- web UI (defined only once cgraph-web / cgraph-editor are loaded)
   #:start-web-server #:stop-web-server #:edit-cgraph

   ;; --- special variables
   #:*context* #:*concept-type-top* #:*concept-type-bottom*
   #:*cgraph* #:*cgraph-types-directory* #:*cgraph-data-directory*
   #:*concise* #:*debug-mode* #:*include-node-ref*
   #:*allow-dynamic-individual-creation*
   #:*anaphora-cross-coref*))

(in-package :asdf-user)

;;; (asdf:system-relative-pathname "cgraph" "default-types/concept-types.lisp")
;;; (asdf:system-source-directory "cgraph")
;;; (clear-system :cgraph)

(defsystem "cgraph"
  :description "basic implementation of Sowa's comceptual graphs"
  :version "0.0.1"
  :author "Bruce Seely <bruce@bseely.com>"
  ;;:licence "Public Domain"
  ;; No SWANK dependency: what talks to Emacs finds SWANK at run time
  ;; (EMACS-CONNECTED-P, system/setup/basic-utilities.lisp) and does nothing
  ;; without a SLIME connection.
  :in-order-to ((test-op (test-op "cgraph/tests")))
  :components ((:module "default-types"
	        ;; The shipped type set, read in place and never written. Static, not
	        ;; compiled: these are data that LOAD-CONCEPT-TYPES reads.
	        :components ((:static-file "concept-types.lisp")
	                     (:static-file "relation-types.lisp")))

               (:module "system"
	        :depends-on ("default-types")
	        :components ((:module "setup"
                              :serial t
	                      :components ((:file "set-operations")
                                           (:file "definitions")
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
                                           (:file "parse-error")
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
                                           ;; After MAXIMAL-JOIN: decomposition
                                           ;; is join run backwards, and the
                                           ;; join is what checks it.
                                           (:file "decomposition")
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
                                           ;; lexicon before walker: WALKER's
                                           ;; ACT-OR-EVENT-CONCEPT-P consults a
                                           ;; :POS override, so the table has to
                                           ;; exist by the time it is compiled.
                                           (:file "lexicon")
                                           (:file "walker")
                                           (:file "morphology")
                                           (:file "anaphora")
                                           (:file "realize-np")
                                           (:file "realize-pp")
                                           (:file "realize-clause")
                                           (:file "generate")
                                           (:file "lexicon-lint")
                                           (:file "classify-word")))))))


;;; The test suites, as their own system so that loading cgraph doesn't compile
;;; them. (asdf:test-system :cgraph) runs them, and signals an error if any
;;; suite fails, so a script or CI job sees a non-zero exit; the per-suite
;;; report is printed either way. In a loaded image, (cg::test-all t).
(defsystem "cgraph/tests"
  :description "Test suites for cgraph"
  :author "Bruce Seely <bruce@bseely.com>"
  :depends-on ("cgraph")
  :components ((:module "test"
                :serial t
                :components ((:file "cgraph-tests")
                             (:file "graphs-for-testing")
                             (:file "set-operations-test")
                             (:file "type-test")
                             (:file "linkup-test")
                             (:file "segment-test")
                             (:file "variable-test")
                             (:file "individual-test")
                             (:file "graph-equality-test")
                             (:file "decomposition-test")
                             (:file "referent-test")
                             (:file "graph-referent-test")
                             (:file "concept-test")
                             (:file "package-independence-test")
                             (:file "format-test")
                             (:file "normalize-test")
                             (:file "parse-test")
                             (:file "parse-error-test")
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
                             (:file "domain-lexicon-test")
                             (:file "generation-roots-lint-test")
                             (:file "relation-tables-lint-test")
                             (:file "relation-hierarchy-test")
                             (:file "relation-join-test")
                             (:file "morphology-tables-lint-test")
                             (:file "lint-report-test"))))
  :perform (test-op (o c)
             (unless (uiop:symbol-call :conceptual-graphs :test-all t)
               (error "cgraph: some test suites failed (see the report above)."))))


;;; REPL and debugging tools -- SUP:RAPROPOS and friends, in package
;;; :cgraph-support (nickname :sup).  Kept as a secondary system so the main
;;; system needn't depend on cl-ppcre or closer-mop, which nothing else uses.  It
;;; deliberately depends on nothing from :cgraph, so it can move to a
;;; repository of its own later without untangling anything.
;;; setup-cgraph loads it; on its own: (asdf:load-system "cgraph/support")
(defsystem "cgraph/support"
  :description "Lisp REPL and debugging tools, in package :cgraph-support (:sup)"
  :author "Bruce Seely <bruce@bseely.com>"
  :depends-on (:cl-ppcre :closer-mop)
  :components ((:module "support"
                :components ((:file "support-functions")))))
