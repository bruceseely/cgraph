;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  The environment: everything that makes up one knowledge base, in one
;;  object, so that two of them can exist in one image.
;;
;;  The state used to be a set of global variables (*CONCEPT-TYPE-CATALOG*,
;;  *CONCEPT-TYPE-TOP*, ...). Those names still work: each is now a symbol
;;  macro for a slot of the environment in *ENVIRONMENT*, so reading one,
;;  SETFing one, or CLRHASHing one acts on the current environment, and the
;;  code that uses them did not have to change. Switching environments is
;;  binding *ENVIRONMENT*.
;;
;;  What a symbol macro can't do is be LET-bound as a special: (let
;;  ((*concept-type-catalog* ...)) ...) makes a LEXICAL variable that the
;;  functions called inside never see. Bind *ENVIRONMENT* to an environment
;;  holding what you want instead.
;;
;;  Must load before any file that names these variables, so that file is
;;  compiled with the macros in place -- a reference compiled before the
;;  macro exists is a reference to the symbol's (unbound) global value.
;;
;;  Moved in so far: the type hierarchy, individuals, nodes, coreference
;;  labels and variables. Still global: *CONTEXT* (a real special, LET-bound
;;  legitimately), the lexicon and relation syntax registrations.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass environment ()
  ((concept-type-catalog :initform (make-hash-table :test 'eql)
                         :initarg :concept-type-catalog
                         :accessor env-concept-type-catalog)
   (relation-type-catalog :initform (make-hash-table :test 'eql)
                          :initarg :relation-type-catalog
                          :accessor env-relation-type-catalog)
   (concept-type-top :initform nil
                     :initarg :concept-type-top
                     :accessor env-concept-type-top)
   (concept-type-bottom :initform nil
                        :initarg :concept-type-bottom
                        :accessor env-concept-type-bottom)
   (loaded-types-source :initform nil
                        :initarg :loaded-types-source
                        :accessor env-loaded-types-source
                        :documentation "Namestring of the type set the catalogs
                         were loaded from, or NIL.")
   ;; individuals
   (individuals :initform (list)
                :accessor env-individuals)
   (current-individual-number :initform 1
                              :accessor env-current-individual-number)
   (individual-type-table :initform (make-hash-table :test 'eql)
                          :accessor env-individual-type-table
                          :documentation "Concept-type symbol -> list of
                           individuals.")
   (individual-property-table :initform (make-hash-table :test 'equalp)
                              :accessor env-individual-property-table
                              :documentation "(type . properties) ->
                               individual, for [DOG: Spot #].")
   (id-cache :initform (make-hash-table :test 'equal)
             :accessor env-id-cache)
   ;; nodes
   (node-ref-counter :initform 1
                     :accessor env-node-ref-counter)
   (node-cache :initform (make-hash-table :test 'eql)
               :accessor env-node-cache
               :documentation "Node ref -> node, for every node built here.")
   ;; per-parse scratch: reset by every parse, but kept here so that two
   ;; environments parsing at once don't share them
   (coref-labels :initform (make-hash-table :test 'equal)
                 :accessor env-coref-labels
                 :documentation "Coreference label -> the concept that
                  defines it.")
   (variables :initform nil
              :accessor env-variables
              :documentation "A VARIABLE-CACHE, made by INITIALIZE-VARIABLES."))
  (:documentation "One knowledge base: its type hierarchy, individuals and
   nodes. A fresh one is empty; bind *ENVIRONMENT* to it and call
   INITIALIZE-CGRAPH to load it."))

(defun make-environment (&rest initargs)
  "A new, empty environment. Nothing is loaded into it."
  (apply #'make-instance 'environment initargs))

(defvar *environment* (make-environment)
  "The current environment. Every type lookup, and every graph built, uses the
   knowledge base this holds.")

(define-symbol-macro *concept-type-catalog*
    (env-concept-type-catalog *environment*))
(define-symbol-macro *relation-type-catalog*
    (env-relation-type-catalog *environment*))
(define-symbol-macro *concept-type-top*
    (env-concept-type-top *environment*))
(define-symbol-macro *concept-type-bottom*
    (env-concept-type-bottom *environment*))
(define-symbol-macro *loaded-types-source*
    (env-loaded-types-source *environment*))

(define-symbol-macro *individuals*
    (env-individuals *environment*))
(define-symbol-macro *current-individual-number*
    (env-current-individual-number *environment*))
(define-symbol-macro *individual-type-table*
    (env-individual-type-table *environment*))
(define-symbol-macro *individual-property-table*
    (env-individual-property-table *environment*))
(define-symbol-macro *id-cache*
    (env-id-cache *environment*))
(define-symbol-macro *node-ref-counter*
    (env-node-ref-counter *environment*))
(define-symbol-macro *node-cache*
    (env-node-cache *environment*))
(define-symbol-macro *coref-labels*
    (env-coref-labels *environment*))
(define-symbol-macro *variables*
    (env-variables *environment*))
