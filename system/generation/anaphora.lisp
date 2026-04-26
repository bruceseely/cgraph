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

(defparameter *given-name-genders* (make-hash-table :test 'equalp)
  "Common given names -> :masc / :fem. Keys are downcased strings.
   Extend at runtime with REGISTER-NAME-GENDER.")

(defun register-name-gender (name gender)
  (setf (gethash (string-downcase (string name)) *given-name-genders*) gender))

(dolist (n '(sue susan mary alice jane jean joan kate katherine julia
             anna anne emily emma jennifer jessica lisa linda karen
             sandra donna betty helen deborah margaret ruth sarah sara
             rachel michelle laura amy angela melissa christine christina
             marie janet catherine frances diane victoria evelyn lauren
             megan andrea hannah jacqueline martha gloria teresa joyce))
  (register-name-gender n :fem))

(dolist (n '(john tom bob ivan james robert michael william david
             richard charles joseph thomas christopher daniel paul mark
             donald george kenneth steven edward brian ronald anthony
             kevin jason matthew gary timothy frank scott eric stephen
             andrew raymond gregory joshua dennis patrick peter samuel
             benjamin bruce harry fred jonathan justin philip nicholas
             dave dan mike steve carl ralph albert))
  (register-name-gender n :masc))

(defun name-gender-of (concept)
  (let* ((ref  (referent concept))
         (name (and ref (referent-name concept))))
    (and name (stringp name) (plusp (length name))
         (gethash (string-downcase name) *given-name-genders*))))

(defun gender-of (concept)
  "Return :masc / :fem / :neuter / :unknown for CONCEPT.
   Lookup order: lexicon override on the type, then known given-name registry,
   then :neuter for non-humans / :unknown for humans."
  (or (lexicon-prop (concept-type concept) :gender)
      (name-gender-of concept)
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

(defun singular-they-p (concept)
  "True for a singular human of unknown gender — the surface pronoun is
   'they' (singular-they), which takes plural verb agreement in standard
   English: 'they have', not 'they has'."
  (and (eq (concept-number concept) :singular)
       (human-p concept)
       (eq (gender-of concept) :unknown)))

(defun verb-agreement-number (concept state)
  "Number to use for verb agreement after CONCEPT. When CONCEPT has already
   been uttered and would surface as singular-they, the verb takes plural
   agreement."
  (cond ((eq (concept-number concept) :plural) :plural)
        ((and (uttered-p state concept) (singular-they-p concept))
         :plural)
        (t :singular)))
