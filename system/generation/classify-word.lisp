;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  CLASSIFY-WORD: a guided interview that turns a native speaker's ear into
;;  lexicon entries.
;;
;;  The premise is that almost every lexicon slot is settled by a judgment a
;;  layman already has and the ontology author otherwise supplies from memory:
;;  nobody needs to know what :MASS-P is to know that "Sue has a furniture" is
;;  wrong. So the interview never names a slot. It shows sentences and asks
;;  which one sounds right.
;;
;;  Three rules the questions follow, each of which earns its keep:
;;
;;  1. GENERATED, NOT HAND-WRITTEN. Every sentence comes from GRAPH-TO-TEXT on
;;     a real graph. Hand-written examples go stale the moment a realizer
;;     changes and then quietly ask about behaviour the system no longer has.
;;
;;  2. FORCED CHOICE, NOT ACCEPTABILITY. People accept nearly anything in
;;     isolation. A boolean slot is asked by generating the sentence under BOTH
;;     settings and showing the pair, which differs in exactly the one place
;;     the slot controls -- so an answer localizes without the user knowing a
;;     slot exists.
;;
;;  3. ONLY WHAT IS UNDETERMINED. A question whose answer the lattice already
;;     settles is not asked. HUMAN-P and ANIMATE-CONCEPT-P consult the lattice
;;     when no override says otherwise, so a PERSON subtype is not asked
;;     whether it is animate.
;;
;;  And one rule about the answers, which matters more than any of the above:
;;  AN ANSWER CAN BE LOCALLY RIGHT AND GLOBALLY WRONG. "A time period" reads
;;  badly and a :LEMMA fixes it -- and silently breaks four sentences, because
;;  BASE-LEMMA ranks an override above a referent name, so the override hides
;;  [TIME-PERIOD: yesterday] and the deictic stops being recognized. A user
;;  answering "that sounds wrong" would have introduced that regression
;;  confidently. So the interview does not end at the answer: it applies the
;;  entry provisionally, re-realizes every canonical graph that mentions the
;;  type and every loaded test case that does, and shows what moved. Nothing
;;  is written until that has been seen.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; --- asking ---------------------------------------------------------------

(defun cw-prompt (stream)
  (format stream "~&> ")
  (force-output stream)
  (string-trim " " (or (read-line stream nil "") "")))

(defun cw-ask-yes-no (stream question &key (default t))
  "Ask QUESTION. Empty answer takes DEFAULT."
  (format stream "~&~%~a ~:[(y/N)~;(Y/n)~]" question default)
  (loop
    (let ((answer (string-downcase (cw-prompt stream))))
      (cond ((string= answer "") (return default))
            ((member answer '("y" "yes") :test #'string=) (return t))
            ((member answer '("n" "no")  :test #'string=) (return nil))
            (t (format stream "~&Please answer y or n."))))))

(defun cw-ask-choice (stream question options)
  "Ask QUESTION with OPTIONS, a list of (KEY . TEXT). Return the chosen KEY.
   The text is what the user judges; the key is what the caller acts on, so
   the slot being decided never has to appear on screen."
  (format stream "~&~%~a~%" question)
  (loop for (nil . text) in options
        for i from 1
        do (format stream "~&  ~d. ~a~%" i text))
  (loop
    (let* ((answer (cw-prompt stream))
           (n (ignore-errors (parse-integer answer))))
      (if (and n (<= 1 n (length options)))
          (return (car (nth (1- n) options)))
          (format stream "~&Please answer with a number from 1 to ~d." (length options))))))

(defun cw-ask-line (stream question)
  "Ask for a word or phrase. Empty answer means \"no change\" and returns NIL."
  (format stream "~&~%~a~%   (press return to leave it alone)" question)
  (let ((answer (cw-prompt stream)))
    (and (plusp (length answer)) answer)))

;;; --- generating the sentences ---------------------------------------------

(defun cw-say (graph-string)
  "Realize GRAPH-STRING, or NIL if it will not parse. A frame that a type's
   canonical graph rejects is skipped rather than reported: the interview is
   about English, and a rejected frame is a question this type cannot be
   asked."
  (let ((*package* (find-package :conceptual-graphs)))
    (handler-case (graph-to-text (parse-cgraph graph-string))
      (error () nil))))

(defun cw-merge-plist (old new)
  "NEW over OLD, key by key. REGISTER-LEXICON-ENTRY replaces a label's whole
   plist rather than merging into it, so anything already registered -- an
   :ADV-FORM, a :PARTICLE -- has to be carried across by hand or it is lost."
  (let ((merged (copy-list old)))
    (loop for (key value) on new by #'cddr
          do (setf (getf merged key) value))
    merged))

(defmacro cw-with-entry ((label plist) &body body)
  "Run BODY with PLIST merged into LABEL's lexicon entry, then put the old
   entry back. This is how both halves of a minimal pair are produced: real
   generator output, differing only in the slot under test."
  (let ((key (gensym)) (old (gensym)))
    `(let* ((,key (string-upcase (string ,label)))
            (,old (gethash ,key *lexicon-overrides*)))
       (unwind-protect
            (progn (setf (gethash ,key *lexicon-overrides*)
                         (cw-merge-plist ,old ,plist))
                   ,@body)
         (if ,old
             (setf (gethash ,key *lexicon-overrides*) ,old)
             (remhash ,key *lexicon-overrides*))))))

;;; --- the frames -----------------------------------------------------------
;;;
;;; Kept as functions of the label so the same frame serves every type, and so
;;; a frame that a canonical graph rejects simply drops out.

(defun cw-noun-frame (label)     (format nil "[PERSON: Sue]→(poss)→[~a]." label))
(defun cw-plural-frame (label)   (format nil "[~a: {*}@2]←(poss)←[PERSON: Sue]." label))
(defun cw-verb-frame (label)     (format nil "[~a]→(agnt)→[PERSON: John]." label))

(defun cw-lone-frame (label)
  "A frame introducing the type and NOTHING ELSE. The pronoun question needs
   one: \"Sue has a cake. ___ was there too\" has two antecedents, so the
   question is ambiguous however it is worded, and Sue -- a name the gender
   registry knows -- primes the answer besides."
  (format nil "[~a]→(attr)→[OLD]." label))

(defun cw-subject-frame (label)
  "The frame whose lemma the user corrects: a noun in an NP, a verb inflected."
  (if (eq (pos-from-hierarchy (get-concept-type label)) :verb)
      (cw-verb-frame label)
      (cw-noun-frame label)))

;;; --- what an answer could disturb ------------------------------------------

(defun cw-canonical-graphs-mentioning (label)
  "Every (TYPE-NAME . GRAPH-STRING) whose canonical graph names LABEL. These
   are the sentences an entry can break without the user ever seeing them."
  (let ((needle (string-upcase (string label)))
        (hits '()))
    (maphash (lambda (key ctype)
               (declare (ignore key))
               (let ((cg (effective-canonical-graph-string ctype)))
                 (when (and cg (plusp (length cg))
                            (member needle (extract-cg-type-names cg) :test #'string=))
                   (push (cons (string-upcase (symbol-name (label ctype))) cg) hits))))
             *concept-type-catalog*)
    (sort hits #'string< :key #'car)))

(defun cw-test-cases-mentioning (label)
  "Loaded generation-test cases naming LABEL, or NIL when the test file has
   not been loaded. Those cases carry REFERENTS, which canonical graphs do
   not -- and a referent is exactly what an over-eager :LEMMA hides."
  (let ((sym (find-symbol "*GENERATION-TEST-CASES*" :conceptual-graphs))
        (needle (string-upcase (string label))))
    (when (and sym (boundp sym))
      (remove-if-not (lambda (case)
                       (search needle (string-upcase (car case))))
                     (symbol-value sym)))))

(defun cw-report-changes (stream label plist)
  "Realize everything LABEL touches, before and after PLIST, and print what
   moved. Returns T when a loaded test case stopped matching its expectation
   -- the signal that an answer is locally right and globally wrong."
  (let ((graphs (append (mapcar #'cdr (cw-canonical-graphs-mentioning label))
                        (mapcar #'car (cw-test-cases-mentioning label))))
        (moved 0)
        (broke nil))
    (format stream "~&~%--- what this changes ------------------------------~%")
    (dolist (graph graphs)
      (let ((before (cw-say graph))
            (after  (cw-with-entry (label plist) (cw-say graph))))
        (when (and before after (not (string= before after)))
          (incf moved)
          (format stream "~&  was: ~a~&  now: ~a~%~%" before after))))
    (dolist (case (cw-test-cases-mentioning label))
      (let ((after (cw-with-entry (label plist) (cw-say (car case)))))
        (when (and after (not (string= after (cdr case))))
          (setf broke t)
          (format stream "~&  !! a test case stops matching:~
                          ~&     graph:    ~a~
                          ~&     expected: ~a~
                          ~&     would be: ~a~%~%"
                  (car case) (cdr case) after))))
    (when (zerop moved)
      (format stream "~&  nothing else in the ontology says this word.~%"))
    (unless (cw-test-cases-mentioning label)
      (format stream "~&  (no test cases loaded for this type -- load test/generation-test.lisp~
                      ~&   to check the sentences that carry referents.)~%"))
    broke))

;;; --- the interview --------------------------------------------------------

(defun cw-confirm-parents (stream ctype)
  "Confirm the placement rather than elicit it. \"Is every X a kind of Y\" is
   an entailment judgment, not a grammaticality one, and it is where a layman
   is least reliable -- `is a kind of' gets read as `is associated with'. So
   the interview only asks whether the parent already chosen is right, and
   says something rather than fixing it when the answer is no."
  (let ((label (string-upcase (symbol-name (label ctype))))
        (parents (mapcar (lambda (p) (string-upcase (symbol-name (label p))))
                         (direct-supertypes ctype))))
    (when parents
      (unless (cw-ask-yes-no
               stream
               (format nil "Is every ~a a kind of ~{~a~^ and of ~}?" label parents))
        (format stream "~&~%  Then the type is in the wrong place, and no wording will fix~
                        ~&  that. Move it in the type browser first; the questions below~
                        ~&  are only about how ~a should READ.~%" label)))))

(defun cw-ask-lemma (stream label)
  (let ((sentence (cw-say (cw-subject-frame label))))
    (when sentence
      (format stream "~&~%Right now ~a comes out like this:~&~%    ~a~%" label sentence)
      (let ((word (cw-ask-line stream "If that is not the word you would use, type the word:")))
        (and word (list :lemma word))))))

(defun cw-ask-mass (stream label plist)
  "Mass or count, asked as the pair the slot produces."
  (let ((frame (cw-noun-frame label)))
    (let ((count-form (cw-with-entry (label (cw-merge-plist plist '(:mass-p nil))) (cw-say frame)))
          (mass-form  (cw-with-entry (label (cw-merge-plist plist '(:mass-p t)))   (cw-say frame))))
      (when (and count-form mass-form (not (string= count-form mass-form)))
        (let ((choice (cw-ask-choice stream "Which of these sounds right?"
                                     (list (cons :count count-form)
                                           (cons :mass  mass-form)))))
          (when (eq choice :mass) (list :mass-p t)))))))

(defun cw-ask-plural (stream label plist)
  (let ((sentence (cw-with-entry (label plist) (cw-say (cw-plural-frame label)))))
    (when sentence
      (format stream "~&~%And more than one:~&~%    ~a~%" sentence)
      (let ((word (cw-ask-line stream "If that plural is wrong, type the right one:")))
        (and word (list :plural word))))))

(defun cw-ask-pronoun (stream label plist)
  "Which pronoun the word takes -- the one question whose carrier sentence is
   fixed rather than generated, because a pronoun needs a second clause that
   no single-concept frame produces. The NP in it is still generated."
  (let* ((ctype (get-concept-type label))
         (sentence (cw-with-entry (label plist)
                     (or (cw-say (cw-lone-frame label))
                         (cw-say (cw-noun-frame label)))))
         ;; The word the question points at, taken from the answers so far --
         ;; so a lemma just corrected is the one the question uses.
         (target (or (getf plist :lemma)
                     (lexicon-prop ctype :lemma)
                     (string-downcase (symbol-name (label ctype))))))
    (when sentence
      (let ((choice (cw-ask-choice
                     stream
                     (format nil "\"~a ___ was there too.\"~
                                ~&Which word fits the blank, talking about the ~a?"
                             sentence target)
                     '((:masc . "he")
                       (:fem  . "she")
                       (:they . "they")
                       (:it   . "it")))))
        (case choice
          (:masc '(:gender :masc :human-p t :animate-p t))
          (:fem  '(:gender :fem  :human-p t :animate-p t))
          ;; Not (:gender :unknown): GENDER-OF consults the lexicon BEFORE the
          ;; given-name registry, so any gender value here would shadow a name
          ;; and turn [CHILD: Mary] from "she" into "they". :UNGENDERED records
          ;; that the lack was decided rather than overlooked.
          (:they '(:ungendered t :human-p t :animate-p t))
          (:it   (progn
                   (when (or (safe-subtype-p (label ctype) 'person)
                             (safe-subtype-p (label ctype) 'animate))
                     (format stream "~&~%  Noted, but the lattice outranks it: HUMAN-P and~
                                     ~&  ANIMATE-CONCEPT-P answer yes for anything under~
                                     ~&  PERSON or ANIMATE whatever the lexicon says, so~
                                     ~&  nothing is written. Move the type if that is wrong.~%"))
                   nil)))))))

(defun classify-word (label &key (stream *query-io*))
  "Interview a speaker about how LABEL should read, and offer the lexicon
   entry their answers imply. The type must already exist -- this decides how
   a word SOUNDS, not where it belongs."
  (let* ((label (intern (string-upcase (string label)) :cg))
         (ctype (ignore-errors (get-concept-type label))))
    (unless ctype
      (format stream "~&There is no type called ~a. Add it first, then classify it.~%" label)
      (return-from classify-word nil))
    (let* ((pos (or (lexicon-prop ctype :pos) (pos-from-hierarchy ctype)))
           (plist '()))
      (format stream "~&~%=== ~a ===~&Answer as a speaker, not as an ontologist:~
                      ~& judge what sounds right, and ignore what it says about the type.~%"
              label)
      (cw-confirm-parents stream ctype)
      (setf plist (cw-merge-plist plist (cw-ask-lemma stream label)))
      (when (eq pos :noun)
        (setf plist (cw-merge-plist plist (cw-ask-mass stream label plist)))
        (unless (getf plist :mass-p)
          (setf plist (cw-merge-plist plist (cw-ask-plural stream label plist))))
        (setf plist (cw-merge-plist plist (cw-ask-pronoun stream label plist))))
      (cond
        ((null plist)
         (format stream "~&~%Nothing to change -- ~a already reads the way you would say it.~%" label)
         nil)
        (t
         (let ((broke (cw-report-changes stream label plist)))
           (when broke
             (format stream "~&  An answer that is right about this word can still be wrong~
                             ~&  for the ontology: a :LEMMA outranks a referent name, so it~
                             ~&  can hide [~a: something] from the realizer.~%" label))
           (cond
             ((cw-ask-yes-no stream "Keep this?" :default (not broke))
              (apply #'register-lexicon-entry label
                     (cw-merge-plist (lexicon-entry label) plist))
              ;; Downcased so the line can be pasted straight into the file,
              ;; which is written in lower case throughout.
              (let ((*print-case* :downcase))
                (format stream "~&~%Registered for this session. To keep it, add this to~
                                ~& system/generation/lexicon.lisp:~&~%~
                                ~&(register-lexicon-entry '~(~a~)~{ ~s~})~%"
                        label (cw-merge-plist (lexicon-entry label) plist)))
              plist)
             (t (format stream "~&~%Left alone.~%") nil))))))))
