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
;;  functions called inside never see. Either bind *ENVIRONMENT* to an
;;  environment holding what you want, or use ENV-LET, which sets the slot
;;  for the extent of its body and puts it back after. BOUNDP and
;;  SYMBOL-VALUE on these names mean nothing.
;;
;;  Must load before any file that names these variables, so that file is
;;  compiled with the macros in place -- a reference compiled before the
;;  macro exists is a reference to the symbol's (unbound) global value.
;;
;;  Not in here: *CONTEXT* (a real special, LET-bound legitimately), and the
;;  settings that say how cgraph behaves rather than what it knows (*CONCISE*
;;  and friends).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun %env-slot-name (variable)
    "*CONCEPT-TYPE-CATALOG* -> CONCEPT-TYPE-CATALOG."
    (intern (string-trim "*" (symbol-name variable)) :conceptual-graphs)))

(defmacro define-environment (&body specs)
  "Define the ENVIRONMENT class from SPECS, each (VARIABLE INITFORM &optional
   DOC), and make each VARIABLE a symbol macro for its slot in *ENVIRONMENT*.
   The slot, its :INITARG keyword and its ENV- accessor are named after
   VARIABLE without the stars."
  `(progn
     (defclass environment ()
       ,(loop for (variable initform doc) in specs
              for slot = (%env-slot-name variable)
              collect `(,slot :initform ,initform
                              :initarg ,(intern (symbol-name slot) :keyword)
                              :accessor ,(intern (format nil "ENV-~a" slot)
                                                 :conceptual-graphs)
                              ,@(when doc `(:documentation ,doc))))
       (:documentation "One knowledge base: its type hierarchy, individuals,
        nodes and the English that goes with its types. A fresh one is empty;
        bind *ENVIRONMENT* to it and call INITIALIZE-CGRAPH to load it."))
     ,@(loop for (variable) in specs
             collect `(define-symbol-macro ,variable
                          (,(intern (format nil "ENV-~a" (%env-slot-name variable))
                                    :conceptual-graphs)
                           *environment*)))
     'environment))

(define-environment
  ;; --- the type hierarchy
  (*concept-type-catalog* (make-hash-table :test 'eql))
  (*relation-type-catalog* (make-hash-table :test 'eql))
  (*concept-type-top* nil)
  (*concept-type-bottom* nil)
  (*loaded-types-source* nil
   "Namestring of the type set the catalogs were loaded from, or NIL.")

  ;; --- individuals
  (*individuals* (list))
  (*current-individual-number* 1)
  (*individual-type-table* (make-hash-table :test 'eql)
   "Concept-type symbol -> list of individuals.")
  (*individual-property-table* (make-hash-table :test 'equalp)
   "(type . properties) -> individual, for [DOG: Spot #].")
  (*id-cache* (make-hash-table :test 'equal))

  ;; --- nodes
  (*node-ref-counter* 1)
  (*node-cache* (make-hash-table :test 'eql)
   "Node ref -> node, for every node built here.")

  ;; --- per-parse scratch: reset by every parse, but kept here so that two
  ;;     environments parsing at once don't share them
  (*coref-labels* (make-hash-table :test 'equal)
   "Coreference label -> the concept that defines it.")
  (*variables* nil
   "A VARIABLE-CACHE, made by INITIALIZE-VARIABLES.")

  ;; --- the English for these types (generation/lexicon.lisp,
  ;;     generation/syntax-roles.lisp). INITIALIZE-TYPES rebuilds all four
  ;;     along with the catalogs.
  (*lexicon-overrides* (make-hash-table :test 'equal)
   "Per-concept-type lexicon entries: *BUILTIN-LEXICON-OVERRIDES*, then the
    domain's lexicon-overrides.lisp, then any REGISTER-LEXICON-ENTRY calls.
    Key: upcased label string. Value: a plist; see *BUILTIN-LEXICON-OVERRIDES*.")
  (*relation-syntax-overrides* (make-hash-table :test 'equal)
   "Per-relation syntax registrations, from :ROLE in the relation definitions
    and REGISTER-RELATION-SYNTAX; consulted ahead of *RELATION-SYNTAX-TABLE*.")
  (*domain-lexicon-file* nil
   "The domain override file loaded into this environment, or NIL when the
    mounted domain ships none.")
  (*domain-lexicon-undo* nil
   "Alist of (KEY . PREVIOUS) for every entry the current domain file
    registered. PREVIOUS is the plist that was registered before it, or :NONE
    when nothing was. Mounting a second domain rewinds through this first, so
    one domain's English cannot leak into the next -- and a domain that
    overrode one of cgraph's own registrations (:LEMMA on CITY-GOVERNMENT,
    say) gives it back rather than deleting it."))

(defun make-environment (&rest initargs)
  "A new, empty environment. Nothing is loaded into it."
  (apply #'make-instance 'environment initargs))

(defvar *environment* (make-environment)
  "The current environment. Every type lookup, and every graph built, uses the
   knowledge base this holds.")

(defmacro env-let (bindings &body body)
  "LET, for names that may live in the environment. A binding of a symbol
   macro for an environment slot sets that slot of the current environment for
   the extent of BODY and puts the old value back on exit, however BODY exits;
   any other binding is an ordinary LET binding. All the values are computed
   first, as LET does.

   Setting the slot in place, rather than binding *ENVIRONMENT* to a copy,
   keeps everything else BODY does to the environment -- the node counter
   moving on, say. The price is that it is not a per-thread binding: another
   thread using this environment meanwhile sees the temporary value."
  (let ((env-bindings '()) (plain-bindings '()) (temps '()))
    (dolist (b bindings)
      (destructuring-bind (name &optional value) (if (consp b) b (list b))
        (let ((temp (gensym (symbol-name name))))
          (push (list temp value) temps)
          (if (and (symbolp name)
                   (nth-value 1 (macroexpand-1 name)))
              (push (list name temp (gensym "OLD")) env-bindings)
              (push (list name temp) plain-bindings)))))
    (setf env-bindings (nreverse env-bindings))
    (let ((env (gensym "ENV")))
      `(let (,@(nreverse temps)
             (,env *environment*))
         (let (,@(loop for (name nil old) in env-bindings
                       collect `(,old ,name)))
           (unwind-protect
                (progn
                  (setf ,@(loop for (name temp) in env-bindings
                                append `(,name ,temp)))
                  (let (,@(nreverse plain-bindings))
                    ,@body))
             (let ((*environment* ,env))
               (setf ,@(loop for (name nil old) in env-bindings
                             append `(,name ,old))))))))))
