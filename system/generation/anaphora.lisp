;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Anaphora generation (Sowa 1984, Rule 5).
;;  When the utterance path revisits a concept, emit a pronoun (or short
;;  noun phrase) instead of the full NP. Pronoun choice is driven by the
;;  concept's gender, animacy, and number, derived from the type lattice
;;  with optional lexicon overrides.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun human-p (concept)
  (let ((label (label (concept-type concept))))
    (or (lexicon-prop (concept-type concept) :human-p)
        (safe-subtype-p label 'person))))

(defun animate-concept-p (concept)
  (let ((label (label (concept-type concept))))
    (or (lexicon-prop (concept-type concept) :animate-p)
        (safe-subtype-p label 'animate))))

(defun gender-of (concept)
  "Return :masc / :fem / :neuter / :unknown for CONCEPT.
   Uses lexicon overrides; falls back to :neuter (non-human) or :unknown (human)."
  (or (lexicon-prop (concept-type concept) :gender)
      (cond ((human-p concept) :unknown)
            (t :neuter))))

;;; Register the small set of gendered common nouns we ship with.
(register-lexicon-entry 'man   :gender :masc :human-p t)
(register-lexicon-entry 'woman :gender :fem  :human-p t)
(register-lexicon-entry 'boy   :gender :masc :human-p t)
(register-lexicon-entry 'girl  :gender :fem  :human-p t)

(defparameter *pronoun-table*
  ;; (gender number case -> pronoun)
  '(((:masc    :singular :nominative) "he")
    ((:masc    :singular :accusative) "him")
    ((:masc    :singular :possessive) "his")
    ((:fem     :singular :nominative) "she")
    ((:fem     :singular :accusative) "her")
    ((:fem     :singular :possessive) "her")
    ((:neuter  :singular :nominative) "it")
    ((:neuter  :singular :accusative) "it")
    ((:neuter  :singular :possessive) "its")
    ((:unknown :singular :nominative) "they")
    ((:unknown :singular :accusative) "them")
    ((:unknown :singular :possessive) "their")
    ((t        :plural   :nominative) "they")
    ((t        :plural   :accusative) "them")
    ((t        :plural   :possessive) "their")))

(defun lookup-pronoun (gender number case)
  (or (second (assoc (list gender number case) *pronoun-table* :test #'equal))
      (second (assoc (list t      number case) *pronoun-table* :test #'equal))))

(defun pronoun-for (concept &key (case :nominative))
  "Return a pronoun for CONCEPT in the given grammatical case."
  (lookup-pronoun (gender-of concept)
                  (concept-number concept)
                  case))
