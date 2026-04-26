;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Mapping from CG relation types to English syntactic roles.
;;  Phase 1: covers the relations in default-types/relation-types.text.
;;  Each entry: (relation-label role &optional preposition)
;;  Roles: :subject :dobj :iobj :pp :adj :adv :poss :nmod :pred-cmp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defparameter *relation-syntax-table*
  '((agnt  :subject)
    (expr  :subject)
    (obj   :dobj)
    (ptnt  :dobj)
    (thme  :dobj)
    (stat  :dobj)
    (cont  :dobj)
    (rcpt  :iobj   "to")
    (inst  :pp     "with")
    (loc   :pp     "in")
    (dest  :pp     "to")
    (manr  :adv)
    (attr  :adj)
    (chrc  :adj)
    (poss  :poss)
    (part  :pp     "of")
    (cntns :pp     "containing")
    (membr :pp     "of")
    (elem  :pp     "of")
    (betw  :pp     "between")
    (age   :pp     "aged")
    (hgt   :pp     "of height")
    (wgt   :pp     "of weight")
    (temp  :pp     "at temperature")
    (size  :pp     "of size")
    (dur   :pp     "for")
    (time  :pp     "at"))
  "Each entry: (relation-label role-keyword &optional preposition).")

;;; Order in which roles are emitted in an English clause.
(defparameter *role-emission-order*
  '(:subject :verb :dobj :iobj :pp :adv :pred-cmp))

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
