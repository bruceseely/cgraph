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
  "Each entry: (relation-label role-keyword &optional preposition).")

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

(defun relation-role-entry (rel-or-label)
  (let ((label (cond ((symbolp rel-or-label) rel-or-label)
                     ((typep rel-or-label 'relation)
                      (label (relation-type rel-or-label)))
                     (t nil))))
    (when label
      (assoc label *relation-syntax-table* :test #'string-equal))))

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
