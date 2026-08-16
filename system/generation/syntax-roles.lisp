;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Mapping from CG relation types to English syntactic roles.
;;  Phase 1: covers the relations in default-types/relation-types.text.
;;  Each entry: (relation-label role &optional preposition)
;;  Roles: :subject :dobj :iobj :pp :adj :adv :poss :nmod :pred-cmp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; The third term is used only by :pp and :iobj
(defparameter *relation-syntax-table*
  '(
    ;;(relation-label   role   &optional preposition)
    (age   :pp     "aged")
    (agnt  :subject)
    (attr  :adj)
    (chrc  :nmod   "of")
    (cntns :pp     "containing")
    (dest  :pp     "to")
    (dur   :pp     "for")
    (elem  :pp     "of")
    (exch  :pp     "for")   ;; consideration: "paid $5 for the book"
    (expr  :subject)
    (from  :pp     "from")
    (goal  :dobj)
    (governs   :pp "governs")
    (hgt   :pp     "of height")
    (inst  :pp     "with")
    (life-stage :pp  "in")  ;; "during"?
    (loc   :pp     "in")
    (manr  :adv)
    (membr :pp     "of")
    (obj   :dobj)
    (on :pp "on")
    (part  :poss)
    (physical-part :pp "of")
    (ploc  :pp     "at")
    (poss  :poss)
    (psize :pp      "of size")
    (ptnt  :dobj)
    (rcpt  :iobj   "to")
    (rslt  :pp     "resulting in")
    (sex   :adj)
    (size  :pp     "of size")
    (stat  :dobj)   ;; clausal complement ("that S" / infinitival "to VP")
    (temp  :pp     "at temperature")
    (thme  :dobj)
    (time  :pp     "at")
    (to    :pp     "to")
    (wgt   :pp     "of weight")
    )
  "Each entry: (relation-label role-keyword &optional preposition).
   The BUILT-IN defaults; REGISTER-RELATION-SYNTAX overrides them, and
   RELATION-SYNTAX-ENTRIES is the effective merge of the two.")

;;; --- Registration ----------------------------------------------------------
;;;
;;; The table above used to be the only mapping: RELATION-ROLE-ENTRY read it
;;; directly, so a relation type defined in a user's own ontology had no way to
;;; reach the realizer short of editing this file and recompiling. That is the
;;; asymmetry recorded in notes/type-editor-integration.md §4 -- a concept type
;;; derives its part of speech from the lattice (POS-FROM-HIERARCHY) and can be
;;; corrected at runtime (REGISTER-LEXICON-ENTRY), while a relation type could
;;; do neither, so a user-authored relation was mute in generation and
;;; unfixable in-image.
;;;
;;; This is the override half of that pair, and deliberately the same shape as
;;; REGISTER-LEXICON-ENTRY: a hash consulted ahead of the declarative defaults.
;;; It does NOT give relation types a default -- that needs the relation
;;; hierarchy, §4(b) -- but it makes a custom ontology correctable, which it
;;; was not.

(defparameter *relation-syntax-overrides* (make-hash-table :test 'equal)
  "Per-relation syntax registrations, consulted by RELATION-ROLE-ENTRY ahead of
   *RELATION-SYNTAX-TABLE*. Key: upcased label string. Value: an entry of the
   same (LABEL ROLE &optional PREPOSITION) shape the table holds, so that
   everything downstream -- the accessors and all four lint checks -- reads the
   two sources identically.

   A DEFPARAMETER, like *LEXICON-OVERRIDES*, so reloading this file clears
   registrations back to the built-in table. Registrations therefore belong in
   a file that gets loaded, not in a one-off REPL call you would have to
   remember to repeat after every ASDF:LOAD-SYSTEM :FORCE T.")

(defun register-relation-syntax (label role &optional preposition)
  "Map LABEL to ROLE (and PREPOSITION, which only :PP and :IOBJ read),
   overriding any built-in entry. This is how an ontology teaches the realizer
   about a relation type this file has never heard of.

   ROLE is deliberately NOT validated here -- the same choice
   REGISTER-LEXICON-ENTRY makes, and for the same reason: the lint already
   walks the effective mapping (%LINT-UNREALIZABLE-SYNTAX-ROLES) and reports an
   unknown or unimplemented role with its consequence spelled out, which is a
   more useful error than a signal at registration time could give."
  (assert (and label (or (symbolp label) (stringp label))) (label)
          "REGISTER-RELATION-SYNTAX needs a relation label, got ~s." label)
  (let ((name (string-upcase (string label))))
    (setf (gethash name *relation-syntax-overrides*)
          ;; :CG explicitly, never the ambient *PACKAGE*. The lint hands this
          ;; symbol to GET-RELATION-TYPE, whose catalog is an EQL table keyed by
          ;; :CG symbols -- so a label interned anywhere else is a different key
          ;; and simply is not there. Same reason MAKE-RELATION-TYPE does it.
          (list* (intern name :conceptual-graphs)
                 role
                 (when preposition (list preposition))))
    role))

(defun unregister-relation-syntax (label)
  "Drop LABEL's registration, exposing whatever *RELATION-SYNTAX-TABLE* says
   underneath it (or nothing). True when there was one to drop."
  (remhash (string-upcase (string label)) *relation-syntax-overrides*))

(defun clear-relation-syntax-registrations ()
  "Discard every registration, leaving the built-in table exposed. Called when
   the relation catalog is cleared, so the two are forgotten together."
  (clrhash *relation-syntax-overrides*))

;;; Fill the holes core declared. Same move LEXICON makes for *MASS-TYPE-P*
;;; (lexicon.lisp:377): the dependency points generation -> core, never back.
;;;
;;; With these set, a relation definition carrying :ROLE registers itself as it
;;; loads, which is what gives REGISTER-RELATION-SYNTAX somewhere to be called
;;; from. The registrations then become a projection of the ontology file
;;; rather than hand-managed state -- which is also what makes
;;; *RELATION-SYNTAX-OVERRIDES* being a DEFPARAMETER correct rather than merely
;;; tolerable: cleared on reload, rebuilt by INITIALIZE-TYPES.
(setf *relation-syntax-hook* #'register-relation-syntax)
(setf *relation-syntax-reset-hook* #'clear-relation-syntax-registrations)

(defun relation-syntax-entries ()
  "The effective mapping: every registration, plus the built-in entries no
   registration shadows. Uniform entry shape, so the lint walks this exactly as
   it used to walk *RELATION-SYNTAX-TABLE*.

   APPEND rather than NCONC: REMOVE-IF may return the original list when it
   removes nothing, and destructively appending to that would splice the
   registrations onto the built-in table itself."
  (let ((shadowed (make-hash-table :test 'equal))
        (registered '()))
    (maphash (lambda (name entry)
               (setf (gethash name shadowed) t)
               (push entry registered))
             *relation-syntax-overrides*)
    (append (nreverse registered)
            (remove-if (lambda (e)
                         (gethash (string-upcase (string (first e))) shadowed))
                       *relation-syntax-table*))))

;;; Order in which roles are emitted in an English clause.
(defparameter *role-emission-order*
  '(:subject :verb :dobj :iobj :pp :adv :pred-cmp))

;;; The roles *RELATION-SYNTAX-TABLE* may assign, and what depends on each
;;; being reachable. This is the relation-side counterpart of
;;; *GENERATION-HIERARCHY-ROOTS*: there the risk is a missing concept-type
;;; root, here it is a role that no live relation maps to.
;;;
;;; Note this cannot be derived from *ROLE-EMISSION-ORDER*, which lists only
;;; the clause-level slots -- :adj, :poss and :nmod are emitted inside NPs and
;;; never appear there, and :verb is the predicate slot rather than a role a
;;; relation may be assigned.
(defparameter *generation-syntax-roles*
  '((:subject
     :severity :error
     :consequence "no relation introduces a clause subject, so ~
                   FIND-SUBJECT-RELATION never fires and COPULA-REQUIRED-P is ~
                   always true -- every graph renders as a copular clause"
     :remedy "map your agentive relations (AGNT, EXPR or their equivalents in ~
              your catalog) to :subject")
    (:dobj
     :severity :warn
     :consequence "transitive verbs lose their object -- 'the dog eats' where ~
                   'the dog eats a cake' was meant"
     :remedy "map OBJ, PTNT, THME or their equivalents to :dobj")
    (:pp
     :severity :info
     :consequence "no relation surfaces as a prepositional phrase, so the ~
                   locative/temporal/instrumental adjuncts are all dropped"
     :remedy "map LOC, TIME, INST or their equivalents to :pp")
    (:adj
     :severity :info
     :consequence "attributive adjectives are never emitted ('the pie' rather ~
                   than 'the red pie')"
     :remedy "map ATTR or its equivalent to :adj")
    (:adv
     :severity :info
     :consequence "manner adverbs are never emitted"
     :remedy "map MANR or its equivalent to :adv")
    (:poss
     :severity :info
     :consequence "possessives are never emitted, and HAVE-CLAUSE-P never ~
                   fires, so 'X has Y' graphs lose their verb"
     :remedy "map POSS or its equivalent to :poss")
    (:iobj
     :severity :info
     :consequence "ditransitive recipients are never emitted ('gives a pie' ~
                   rather than 'gives a pie to Mary')"
     :remedy "map RCPT or its equivalent to :iobj")
    (:nmod
     :severity :info
     :consequence "noun-modifier relations are never emitted as post-modifiers"
     :remedy "map CHRC or its equivalent to :nmod")
    (:pred-cmp
     :implemented nil
     :consequence "the role is listed in *ROLE-EMISSION-ORDER* but no realizer ~
                   consumes it, so any relation mapped to it is silently dropped"
     :remedy "use :dobj for clausal complements (as PROP does), or implement ~
              the role in realize-clause.lisp"))
  "Every role *RELATION-SYNTAX-TABLE* may assign, as
   (ROLE &key SEVERITY CONSEQUENCE REMEDY IMPLEMENTED).

   SEVERITY/CONSEQUENCE/REMEDY describe what happens when the catalog and the
   syntax table between them leave the role unreachable -- no surviving entry
   maps a relation that actually exists to it. IMPLEMENTED defaults to T;
   NIL marks a role that is declared here but that no realizer reads, so
   mapping a relation to it drops the relation.

   CONSEQUENCE and REMEDY are FORMAT control strings (so they may carry ~ line
   folds). Consumed by the relation checks in lexicon-lint.lisp; keep this the
   single source of truth so the checks and the realizer can't drift.")

(defun syntax-role-entry (role)
  (assoc role *generation-syntax-roles*))

(defun known-syntax-role-p (role)
  (and (syntax-role-entry role) t))

(defun implemented-syntax-role-p (role)
  (let ((entry (syntax-role-entry role)))
    (and entry (getf (rest entry) :implemented t) t)))

;;; Relation labels the generation code names literally, rather than reaching
;;; them through *RELATION-SYNTAX-TABLE*. Same failure shape as a missing
;;; hierarchy root: the STRING-EQUAL simply never matches and the special-case
;;; path goes dead, with no error.
(defparameter *generation-relation-labels*
  '((time
     :severity :info
     :consequence "REALIZE-PP's deictic-adverb path goes dead, so a TIME arc ~
                   to 'yesterday'/'tomorrow' is rendered as a prepositional ~
                   phrase ('at yesterday') rather than a bare adverb"
     :remedy "define the TIME relation, or accept the prepositional form"))
  "Relation labels hard-coded in the realizer, as
   (LABEL &key SEVERITY CONSEQUENCE REMEDY). Same shape and same purpose as
   *GENERATION-HIERARCHY-ROOTS*, for relations rather than concept types.")

;;; :pp roles that, when found on a clause's subject NP, are clause-level
;;; adjuncts ("the dog sits at the place") rather than NP post-modifiers
;;; ("the dog at the place sits"). Anything not in this list stays inside
;;; the subject NP — e.g. cntns/part/membr/inst describe the noun itself.
(defparameter *clause-level-pp-relations*
  '(loc ploc time dur on temp dest from to))

;;; Within a single bucket, modifier ordering preferences.
;;; English: adverbs of manner before adverbs of time (Rule 1 example).
(defparameter *pp-relation-priority*
  '(inst loc dest physical-part membr elem cntns age hgt wgt temp size dur time))

(defun %own-relation-syntax (label)
  "LABEL's OWN entry -- a registration if there is one, else the built-in. A
   direct hash probe plus the original ASSOC rather than a search of
   RELATION-SYNTAX-ENTRIES, because this runs once per arc per realization and
   the merged list would be rebuilt on every call."
  (or (gethash (string-upcase (string label)) *relation-syntax-overrides*)
      (assoc label *relation-syntax-table* :test #'string-equal)))

(defun relation-role-entry (rel-or-label)
  "LABEL's effective entry: its own if it has one, otherwise the nearest one
   INHERITED from a relation type above it.

   This is what makes a relation hierarchy worth having. It is the same move
   POS-FROM-HIERARCHY makes for concept types, which is why a custom concept
   type is born realizable and a custom relation type was not: define
   BENEFICIARY under RCPT and it surfaces as RCPT does until told otherwise,
   with nothing registered and nothing added to any table.

   RELATION-ANCESTORS is breadth-first and nearest-first, so the most specific
   answer wins when two ancestors disagree, and a cycle cannot hang this."
  (let ((label (cond ((symbolp rel-or-label) rel-or-label)
                     ((typep rel-or-label 'relation)
                      (label (relation-type rel-or-label)))
                     ((typep rel-or-label 'relation-type) (label rel-or-label))
                     (t nil))))
    (when label
      (or (%own-relation-syntax label)
          ;; Only then the walk, and only if the label names something with a
          ;; hierarchy at all -- the overwhelming majority of lookups are hits
          ;; on the line above and must not pay for a catalog probe.
          (let ((node (ignore-errors (get-relation-type label))))
            (when node
              (loop for ancestor in (rest (relation-ancestors node))
                    for entry = (%own-relation-syntax (label ancestor))
                    when entry return entry)))))))

(defun relation-role (rel-or-label)
  "Return the syntactic role keyword for a relation, or NIL if unmapped."
  (second (relation-role-entry rel-or-label)))

(defun relation-preposition (rel-or-label)
  "Return the preposition string associated with a relation, or NIL."
  (third (relation-role-entry rel-or-label)))

(defun pp-priority-rank (rel)
  "Rank for ordering PP-bucket relations within a clause."
  (let ((label (label (relation-type rel))))
    (or (position label *pp-relation-priority* :test #'string-equal)
        most-positive-fixnum)))

;;; --- NP-modifier prepositions ----------------------------------------------
;;; When a :pp relation hangs off an NP head (rather than off the main verb),
;;; we render it as a post-modifier — "milk in a bottle", "baby with a belly".
;;; The preposition depends on which SIDE of the relation the NP is on:
;;; the inarc (source) side and the outarc (dest) side need different preps
;;; because "bottle containing milk" and "milk in a bottle" are not symmetric.

(defparameter *np-pp-prepositions*
  ;; (relation-label  source-side-prep  dest-side-prep)
  '((loc   "in"          "of")
    (cntns "containing"  "in")
    (physical-part "with" "of")
    (inst  "with"        "for")
    (dest  "to"          "for")
    (time  "at"          nil)
    (dur   "for"         nil)
    (age   "aged"        nil))
  "Source-side: NP is the inarc (source) of the relation.
   Dest-side:   NP is the outarc (destination) of the relation.")

(defun np-pp-preposition (rel concept)
  "The preposition to use when REL is attached to CONCEPT as an NP modifier."
  (let* ((label (label (relation-type rel)))
         (entry (assoc label *np-pp-prepositions* :test #'string-equal))
         (source-side (not (eq (outarc rel) concept))))
    (and entry (if source-side (second entry) (third entry)))))
