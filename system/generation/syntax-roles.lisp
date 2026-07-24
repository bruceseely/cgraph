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
    (betw  :pp     "between")
    (chrc  :nmod   "of")
    (cntns :pp     "containing")
    (cont  :dobj)
    (dest  :pp     "to")
    (dur   :pp     "for")
    (elem  :pp     "of")
    (exch  :pp     "for")   ;; consideration: "paid $5 for the book"
    (expr  :subject)
    (from  :pp     "from")
    (goal  :dobj)
    (governs   :pp "governs")
    (has-part :pos)
    (hgt   :pp     "of height")
    (inst  :pp     "with")
    (life-stage :pp  "in")  ;; "during"?
    (loc   :pp     "in")
    (manr  :adv)
    (membr :pp     "of")
    (obj   :dobj)
    (on :pp "on")
    (part  :pp     "of")
    (ploc  :pp     "at")
    (poss  :poss)
    (prop  :dobj)   ;; generic clausal complement ("that S" / infinitival "to VP")
    (psize :pp      "of size")
    (ptnt  :dobj)
    (rcpt  :iobj   "to")
    (rslt  :pp     "resulting in")
    (sex   :adj)
    (size  :pp     "of size")
    (stat  :dobj)
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

;;; :pp roles that, when found on a clause's subject NP, are clause-level
;;; adjuncts ("the dog sits at the place") rather than NP post-modifiers
;;; ("the dog at the place sits"). Anything not in this list stays inside
;;; the subject NP — e.g. cntns/part/membr/inst describe the noun itself.
(defparameter *clause-level-pp-relations*
  '(loc ploc time dur on temp dest from to))

;;; Within a single bucket, modifier ordering preferences.
;;; English: adverbs of manner before adverbs of time (Rule 1 example).
(defparameter *pp-relation-priority*
  '(inst loc dest part membr elem cntns betw age hgt wgt temp size dur time))

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
    (part  "with"        "of")
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
