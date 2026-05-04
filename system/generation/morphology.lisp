;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  English morphology (Phase 2): pluralization, verb conjugation,
;;  article/determiner choice, adjective-to-adverb derivation.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defparameter *vowels* "aeiou")

(defun ends-with (s suffix)
  (and (>= (length s) (length suffix))
       (string-equal (subseq s (- (length s) (length suffix))) suffix)))

(defun last-char (s)
  (and (plusp (length s)) (char s (1- (length s)))))

(defun second-last-char (s)
  (and (>= (length s) 2) (char s (- (length s) 2))))

(defun vowel-p (c)
  (and c (find (char-downcase c) *vowels*)))

(defun consonant-p (c)
  (and c (alpha-char-p c) (not (vowel-p c))))

(defun chop (s n)
  "Return S with its last N chars removed."
  (subseq s 0 (- (length s) n)))

(defun cap (s)
  (cond ((zerop (length s)) s)
        (t (concatenate 'string (string (char-upcase (char s 0))) (subseq s 1)))))

;;; --- Pluralization ----------------------------------------------------------

(defun pluralize (noun)
  "Return the plural form of a singular English NOUN."
  (or (irregular-plural noun)
      (cond ((or (ends-with noun "s") (ends-with noun "x")
                 (ends-with noun "z") (ends-with noun "ch")
                 (ends-with noun "sh"))
             (concatenate 'string noun "es"))
            ((and (ends-with noun "y")
                  (consonant-p (second-last-char noun)))
             (concatenate 'string (chop noun 1) "ies"))
            ((or (ends-with noun "fe"))
             (concatenate 'string (chop noun 2) "ves"))
            ((and (ends-with noun "f")
                  (not (vowel-p (second-last-char noun))))
             (concatenate 'string (chop noun 1) "ves"))
            (t (concatenate 'string noun "s")))))

;;; --- Verb conjugation -------------------------------------------------------

(defun present-3sg (vlemma)
  "Conjugate VLEMMA for 3rd person singular present (he/she/it eats, runs, ...)"
  (or (irregular-verb-form vlemma :present-3sg)
      (cond ((or (ends-with vlemma "s") (ends-with vlemma "x")
                 (ends-with vlemma "z") (ends-with vlemma "ch")
                 (ends-with vlemma "sh") (ends-with vlemma "o"))
             (concatenate 'string vlemma "es"))
            ((and (ends-with vlemma "y")
                  (consonant-p (second-last-char vlemma)))
             (concatenate 'string (chop vlemma 1) "ies"))
            (t (concatenate 'string vlemma "s")))))

(defun past-tense (vlemma)
  (or (irregular-verb-form vlemma :past)
      (cond ((ends-with vlemma "e")
             (concatenate 'string vlemma "d"))
            ((and (ends-with vlemma "y")
                  (consonant-p (second-last-char vlemma)))
             (concatenate 'string (chop vlemma 1) "ied"))
            (t (concatenate 'string vlemma "ed")))))

(defun past-participle (vlemma)
  "Past participle for passive constructions ('is eaten', 'is given').
   For regular verbs this equals the past tense."
  (or (irregular-verb-form vlemma :past-participle)
      (past-tense vlemma)))

(defun inflect-verb (vlemma &key (tense :present) (person 3) (numbr :singular))
  "Return the inflected form of VLEMMA. Phase 2 supports :present and :past.
   Named INFLECT-VERB rather than CONJUGATE because cl:conjugate is a
   built-in function (complex-conjugate) whose ftype declaration would
   collide and type-check our first argument as a NUMBER."
  (ecase tense
    (:present
     (cond ((and (eql person 3) (eq numbr :singular))
            (present-3sg vlemma))
           (t vlemma)))
    (:past (past-tense vlemma))))

;;; --- Articles / determiners -------------------------------------------------

(defun starts-with-vowel-sound-p (word)
  "Crude approximation: leading orthographic vowel = vowel sound."
  (and (plusp (length word))
       (vowel-p (char word 0))))

(defun indefinite-article (word)
  (if (starts-with-vowel-sound-p word) "an" "a"))

(defparameter *cardinal-words*
  #("zero" "one" "two" "three" "four" "five" "six" "seven" "eight" "nine"
    "ten" "eleven" "twelve"))

(defparameter *unit-words*
  ;; canonical-singular abbrev-or-symbols-spellings -> long form
  '(("ft"    "foot"     "feet")
    ("in"    "inch"     "inches")
    ("yd"    "yard"     "yards")
    ("mi"    "mile"     "miles")
    ("cm"    "centimeter" "centimeters")
    ("mm"    "millimeter" "millimeters")
    ("m"     "meter"    "meters")
    ("km"    "kilometer" "kilometers")
    ("lb"    "pound"    "pounds")
    ("kg"    "kilogram" "kilograms")
    ("g"     "gram"     "grams")
    ("oz"    "ounce"    "ounces")
    ("sec"   "second"   "seconds")
    ("min"   "minute"   "minutes")
    ("hr"    "hour"     "hours")))

(defun expand-units (units count)
  "Expand a units abbreviation ('ft' / 'ft.') to the singular or plural long
   form. Counts of exactly 1 take the singular; everything else (including
   non-integers like 25.4) takes the plural. Pass through unknown units."
  (let* ((trimmed (string-right-trim ".," units))
         (key     (string-downcase trimmed))
         (row     (assoc key *unit-words* :test #'string=)))
    (cond ((null row) units)
          ((or (eql count 1) (equal count 1.0)) (second row))
          (t (third row)))))

(defun number-word (n)
  "Spell out small non-negative integers; pass through as digits otherwise."
  (cond ((and (integerp n) (<= 0 n) (< n (length *cardinal-words*)))
         (aref *cardinal-words* n))
        ((integerp n) (princ-to-string n))
        (t (princ-to-string n))))

(defun article-for (concept lemma)
  "Choose a determiner for CONCEPT preceding LEMMA. Returns NIL for no article.
   Plural NPs of unspecified count use the bare plural form ('dogs bark'),
   not 'some dogs bark', which matches default English usage for generic
   plurals."
  (let ((definiteness (concept-definiteness concept))
        (number       (concept-number concept)))
    (cond ((mass-noun-p concept)        nil)
          ((eq definiteness :proper)    nil)
          ((eq definiteness :universal) "every")
          ((concept-count-word concept))
          ((eq definiteness :definite)  "the")
          ((eq number :plural)          nil)
          (t (indefinite-article lemma)))))

(defun concept-count-word (concept)
  "Spelled-out cardinal for a counted set referent ('{*}@3' -> 'three').
   The measure annotation may live on the concept (parsed annotations) or on
   the wrapping referent. The value comes in two shapes: a raw string like
   '@5' or a parsed (size units) pair where size is already a number and
   units is a (possibly empty) string. Only emit a determiner when there
   are no units — '@5 lb' is a weight, not a count."
  (let* ((ref (referent concept))
         ;; Read the raw value directly: the concept-level `measure` method
         ;; assumes a string and crashes on the parsed (size units) shape.
         (raw (or (getf (properties concept) :measure)
                  (and ref (measure-property ref)))))
    (cond ((null raw) nil)
          ((and (consp raw) (integerp (first raw))
                (or (null (second raw))
                    (and (stringp (second raw))
                         (zerop (length (second raw))))))
           (number-word (first raw)))
          ((stringp raw)
           (let* ((digits (string-left-trim "@ " raw))
                  (n      (parse-integer digits :junk-allowed t)))
             (when n (number-word n)))))))

;;; --- Adjective -> adverb ---------------------------------------------------

(defun adverbify (root)
  "Derive an adverb from an adjective ROOT. Crude rules; OK for Phase 2."
  (cond ((zerop (length root)) root)
        ((ends-with root "ly") root)                              ; already adverb
        ((ends-with root "ic")
         (concatenate 'string root "ally"))                        ; basic -> basically
        ((and (ends-with root "y")
              (consonant-p (second-last-char root)))
         (concatenate 'string (chop root 1) "ily"))                ; happy -> happily
        ((ends-with root "le")
         (concatenate 'string (chop root 1) "y"))                  ; simple -> simply
        ((ends-with root "ll")
         (concatenate 'string root "y"))                           ; full -> fully
        (t (concatenate 'string root "ly"))))                      ; quick -> quickly
