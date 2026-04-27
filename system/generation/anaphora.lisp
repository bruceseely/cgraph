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
             megan andrea hannah jacqueline martha gloria teresa joyce
             molly polly sally holly dolly lily rose daisy ivy violet
             beth becky cathy kathy peggy patty mandy wendy cindy sandy
             nancy carol carolyn pamela pam debra debbie connie shirley
             judy judith heather amanda stephanie nicole rebecca brenda
             brittany kayla samantha sophia olivia ava mia chloe ella
             grace lily aria charlotte amelia abigail elizabeth liz
             beatrice beatrix harriet eleanor clara ada ruby))
  (register-name-gender n :fem))

(dolist (n '(john tom bob ivan james robert michael william david
             richard charles joseph thomas christopher daniel paul mark
             donald george kenneth steven edward brian ronald anthony
             kevin jason matthew gary timothy frank scott eric stephen
             andrew raymond gregory joshua dennis patrick peter samuel
             benjamin bruce harry fred jonathan justin philip nicholas
             dave dan mike steve carl ralph albert
             dexter henry charlie chuck rick rich nick nicky tony al
             ed eddie tim tony louis louie alex alexander jacob jack
             noah liam mason ethan logan lucas oliver elijah aiden
             carter jackson sebastian gabriel anthony grayson julian
             hugh hugo otto victor frank franklin ernest ernie
             todd jeff jeffrey doug douglas dean wayne arnold arthur
             arnie ronnie ron donnie don nigel ian ronald oscar))
  (register-name-gender n :masc))

(defun name-gender-of (concept)
  (let* ((ref  (referent concept))
         (name (and ref (referent-name concept))))
    (and name (stringp name) (plusp (length name))
         (gethash (string-downcase name) *given-name-genders*))))

(defun gender-of (concept)
  "Return :masc / :fem / :neuter / :unknown for CONCEPT.
   Lookup order: lexicon override on the type, then known given-name registry,
   then the same lookups walked across the coreference chain (so an inner
   coref'd duplicate inherits gender from its outer defining concept), then
   :neuter for non-humans / :unknown for humans."
  (flet ((local-gender (c)
           (or (lexicon-prop (concept-type c) :gender)
               (name-gender-of c))))
    (or (local-gender concept)
        (some #'local-gender (coreference concept))
        (cond ((human-p concept) :unknown)
              (t :neuter)))))

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

(defparameter *anaphora-cross-coref* nil
  "When true, the anaphora pass treats two concepts linked via the
   coreference slot as the same referent for pronoun selection — so a
   second mention of a coref'd concept becomes a pronoun ('he') instead
   of repeating the proper noun ('Bob'). Default NIL preserves the
   conservative behavior, which avoids pronoun ambiguity in nested
   mental-attitude contexts ('Dave believes that Bob desires that
   he/Bob eats a cake').")

(defun uttered-or-coref-uttered-p (state concept)
  "True if CONCEPT itself has been uttered, or — when *anaphora-cross-coref*
   is set — any concept on its coreference list has been uttered."
  (or (uttered-p state concept)
      (and *anaphora-cross-coref*
           (some (lambda (c) (uttered-p state c))
                 (coreference concept)))))

(defun pronoun-for (concept &key (case :nominative) state)
  "Return a pronoun for CONCEPT in the given grammatical case. When STATE
   is supplied and *anaphora-cross-coref* is on, look up gender/number on
   the already-uttered antecedent in the coreference chain (the canonical
   defining concept) rather than the local revisit, since the local one
   may not have its referent's name resolvable."
  (let ((source (or (and state *anaphora-cross-coref*
                         (find-if (lambda (c) (uttered-p state c))
                                  (coreference concept)))
                    concept)))
    (lookup-pronoun (gender-of source)
                    (concept-number source)
                    case)))

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
