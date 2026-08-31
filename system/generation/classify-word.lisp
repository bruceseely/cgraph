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

;;; --- the questions, as data -----------------------------------------------
;;;
;;; One table, two front ends. The REPL driver below and the browser wizard
;;; behind /api/classify both walk this list, so the questions a layman is
;;; asked in the form and the questions asked at the listener cannot drift
;;; apart -- which they would within a week if each had its own copy.
;;;
;;; An ANSWERS alist maps question id -> the user's string. A question is
;;; "asked already" when its id is present, even with an empty string: empty
;;; means "leave it alone", and telling that apart from "not yet asked" is
;;; what lets the browser send its state back one question at a time without
;;; the server remembering anything.

(defstruct (cq (:constructor make-cq (id kind applicable prompt options to-plist
                                      &optional placeholder)))
  id kind applicable prompt options to-plist
  ;; :TEXT only -- the value the box would keep if left alone, shown in it as a
  ;; placeholder. An empty box asking "type the word you would use" gives no
  ;; clue WHICH word is under discussion; the sentence in the prompt has four.
  placeholder)

(defun cw-answer (answers id)
  (cdr (assoc id answers)))

(defun cw-answered-p (answers id)
  (and (assoc id answers) t))

(defun cw-answers-plist (label answers)
  "The lexicon plist ANSWERS add up to."
  (let ((plist '()))
    (dolist (question *classification-questions* plist)
      (when (cw-answered-p answers (cq-id question))
        (setf plist (cw-merge-plist
                     plist
                     (funcall (cq-to-plist question)
                              label answers (cw-answer answers (cq-id question)))))))))

(defparameter *classification-questions* nil
  "Filled in below; declared first so CW-ANSWERS-PLIST can close over it.")

(setf *classification-questions*
 (list
  (make-cq
   :parents :yes-no
   ;; Confirm the placement, never elicit it. "Is every X a kind of Y" is an
   ;; entailment judgment, not a grammaticality one, and it is where a layman
   ;; is least reliable -- `is a kind of' gets read as `is associated with'.
   (lambda (label answers)
     (declare (ignore answers))
     (and (direct-supertypes (get-concept-type label)) t))
   (lambda (label answers)
     (declare (ignore answers))
     (format nil "Is every ~:@(~A~) a kind of ~{~:@(~A~)~^ and of ~}?"
             label (mapcar (lambda (p) (symbol-name (label p)))
                           (direct-supertypes (get-concept-type label)))))
   (lambda (label answers) (declare (ignore label answers)) nil)
   (lambda (label answers answer) (declare (ignore label answers answer)) nil))

  (make-cq
   :lemma :text
   (lambda (label answers) (declare (ignore answers))
     (and (cw-say (cw-subject-frame label)) t))
   ;; Names the WORD, not just the sentence, and says what this step can and
   ;; cannot change. Shown only a sentence, a reader reaches for the sentence's
   ;; fault -- "Sue has a fruit" is wrong in its ARTICLE, and the box that
   ;; takes a word cannot fix that. The article is the next question; saying so
   ;; is what stops someone typing "some fruit" here.
   (lambda (label answers)
     (format nil "This type's word is \"~A\", so it comes out: \"~A\"~
                  ~&Is \"~:*~*~A\" the word you would use? If not, type the ~
                  one you would. (The article and the plural come next.)"
             (cw-question-target label answers)
             (cw-say (cw-subject-frame label))
             (cw-question-target label answers)))
   (lambda (label answers) (declare (ignore label answers)) nil)
   (lambda (label answers answer)
     (declare (ignore label answers))
     (when (and answer (plusp (length answer))) (list :lemma answer)))
   (lambda (label answers) (cw-question-target label answers)))

  (make-cq
   :mass :choice
   (lambda (label answers)
     (and (eq (pos-from-hierarchy (get-concept-type label)) :noun)
          (destructuring-bind (count-form . mass-form) (cw-mass-pair label answers)
            (and count-form mass-form (not (string= count-form mass-form))))))
   (lambda (label answers) (declare (ignore label answers))
     "Which of these sounds right?")
   (lambda (label answers)
     (destructuring-bind (count-form . mass-form) (cw-mass-pair label answers)
       (list (cons "count" count-form) (cons "mass" mass-form))))
   (lambda (label answers answer)
     (declare (ignore label answers))
     (when (equal answer "mass") (list :mass-p t))))

  (make-cq
   :plural :text
   (lambda (label answers)
     (and (eq (pos-from-hierarchy (get-concept-type label)) :noun)
          (not (getf (cw-answers-plist label answers) :mass-p))
          (cw-with-entry (label (cw-answers-plist label answers))
            (and (cw-say (cw-plural-frame label)) t))))
   (lambda (label answers)
     (format nil "And more than one: \"~A\"  If that plural is wrong, type the ~
                  right one."
             (cw-with-entry (label (cw-answers-plist label answers))
               (cw-say (cw-plural-frame label)))))
   (lambda (label answers) (declare (ignore label answers)) nil)
   (lambda (label answers answer)
     (declare (ignore label answers))
     (when (and answer (plusp (length answer))) (list :plural answer))))

  (make-cq
   :pronoun :choice
   (lambda (label answers)
     (declare (ignore answers))
     (eq (pos-from-hierarchy (get-concept-type label)) :noun))
   (lambda (label answers)
     ;; The one carrier sentence that is fixed rather than generated -- a
     ;; pronoun needs a second clause no single-concept frame produces. The
     ;; frame names ONLY this type, so there is nothing else the blank could
     ;; refer to, and the question names the word besides.
     (format nil "\"~A ___ was there too.\"  Which word fits the blank, ~
                  talking about the ~A?"
             (cw-with-entry (label (cw-answers-plist label answers))
               (or (cw-say (cw-lone-frame label)) (cw-say (cw-noun-frame label))))
             (cw-question-target label answers)))
   (lambda (label answers) (declare (ignore label answers))
     (list (cons "he" "he") (cons "she" "she")
           (cons "they" "they") (cons "it" "it")))
   (lambda (label answers answer)
     (declare (ignore label answers))
     (cond ((equal answer "he")  (list :gender :masc :human-p t :animate-p t))
           ((equal answer "she") (list :gender :fem  :human-p t :animate-p t))
           ;; Not (:gender :unknown): GENDER-OF consults the lexicon BEFORE the
           ;; given-name registry, so any gender value here would shadow a name
           ;; and turn [CHILD: Mary] from "she" into "they".
           ((equal answer "they") (list :ungendered t :human-p t :animate-p t))
           (t nil))))))

(defun cw-mass-pair (label answers)
  "The count and mass readings of the same frame -- a minimal pair, both of
   them real generator output, differing only in the slot under test."
  (let ((plist (cw-answers-plist label answers))
        (frame (cw-noun-frame label)))
    (cons (cw-with-entry (label (cw-merge-plist plist '(:mass-p nil))) (cw-say frame))
          (cw-with-entry (label (cw-merge-plist plist '(:mass-p t)))   (cw-say frame)))))

(defun cw-question-target (label answers)
  "The word a question points at, taken from the answers so far -- so a lemma
   just corrected is the one the next question uses."
  (let ((ctype (get-concept-type label)))
    (or (getf (cw-answers-plist label answers) :lemma)
        (lexicon-prop ctype :lemma)
        (string-downcase (symbol-name (label ctype))))))

(defun next-classification-question (label answers)
  "The next question to put, or NIL when there are none left."
  (find-if (lambda (question)
             (and (not (cw-answered-p answers (cq-id question)))
                  (funcall (cq-applicable question) label answers)))
           *classification-questions*))

;;; --- what the answers would do --------------------------------------------

(defun classification-preview (label answers)
  "(:PLIST p :CHANGES ((before . after) ...) :BREAKS ((graph expected actual) ...)
    :NOTES (string ...)) for the answers so far.

   The BREAKS list is the reason this exists. An answer can be locally right
   and globally wrong: \"a time period\" reads badly, a :LEMMA fixes it, and
   four sentences break, because BASE-LEMMA ranks an override above a referent
   name and the override hides [TIME-PERIOD: yesterday]. Nothing is written
   until this has been seen."
  (let* ((plist (cw-answers-plist label answers))
         (ctype (get-concept-type label))
         (graphs (append (mapcar #'cdr (cw-canonical-graphs-mentioning label))
                         (mapcar #'car (cw-test-cases-mentioning label))))
         (changes '())
         (breaks '())
         (notes '()))
    (when (and (cw-answered-p answers :parents)
               (not (cw-yes-p (cw-answer answers :parents))))
      (push (format nil "You said ~:@(~A~) is not a kind of its parents. No wording ~
                         will fix that -- move it in the type browser; these ~
                         questions only decide how it READS."
                    label)
            notes))
    (when (and (equal (cw-answer answers :pronoun) "it")
               (or (safe-subtype-p (label ctype) 'person)
                   (safe-subtype-p (label ctype) 'animate)))
      (push (format nil "Noted, but the lattice outranks it: HUMAN-P and ~
                         ANIMATE-CONCEPT-P answer yes for anything under PERSON ~
                         or ANIMATE whatever the lexicon says, so nothing is ~
                         written for that answer.")
            notes))
    (when plist
      (dolist (graph graphs)
        (let ((before (cw-say graph))
              (after  (cw-with-entry (label plist) (cw-say graph))))
          (when (and before after (not (string= before after)))
            (push (cons before after) changes))))
      (dolist (test-case (cw-test-cases-mentioning label))
        (let ((after (cw-with-entry (label plist) (cw-say (car test-case)))))
          (when (and after (not (string= after (cdr test-case))))
            (push (list (car test-case) (cdr test-case) after) breaks)))))
    (list :plist plist
          :changes (nreverse changes)
          :breaks (nreverse breaks)
          :notes (nreverse notes)
          :test-cases-loaded (and (cw-test-cases-mentioning label) t))))

(defun cw-yes-p (answer)
  (member answer '("y" "yes" "true" "1") :test #'string-equal))

(defun commit-classification (label answers)
  "Register what ANSWERS add up to, and return the line that makes it stick."
  (let ((plist (cw-answers-plist label answers)))
    (when plist
      (apply #'register-lexicon-entry label
             (cw-merge-plist (lexicon-entry label) plist))
      (let ((*print-case* :downcase))
        (format nil "(register-lexicon-entry '~(~A~)~{ ~S~})"
                label (cw-merge-plist (lexicon-entry label) plist))))))

;;; --- the REPL front end ---------------------------------------------------

(defun classify-word (label &key (stream *query-io*))
  "Interview a speaker about how LABEL should read, and offer the lexicon
   entry their answers imply. The type must already exist -- this decides how
   a word SOUNDS, not where it belongs.

   The browser wizard asks the same questions from the same table; this is the
   listener's way in."
  (let* ((label (intern (string-upcase (string label)) :cg))
         (ctype (ignore-errors (get-concept-type label))))
    (unless ctype
      (format stream "~&There is no type called ~A. Add it first, then classify it.~%" label)
      (return-from classify-word nil))
    (format stream "~&~%=== ~A ===~&Answer as a speaker, not as an ontologist:~
                    ~& judge what sounds right, and ignore what it says about the type.~%"
            label)
    (let ((answers '()))
      (loop for question = (next-classification-question label answers)
            while question
            do (let ((answer
                       (ecase (cq-kind question)
                         (:yes-no (if (cw-ask-yes-no stream (funcall (cq-prompt question) label answers))
                                      "yes" "no"))
                         (:text   (or (cw-ask-line stream (funcall (cq-prompt question) label answers)) ""))
                         (:choice (cw-ask-choice stream
                                                 (funcall (cq-prompt question) label answers)
                                                 (funcall (cq-options question) label answers))))))
                 (push (cons (cq-id question) answer) answers)))
      (let* ((preview (classification-preview label answers))
             (plist (getf preview :plist)))
        (dolist (note (getf preview :notes))
          (format stream "~&~%  ~A~%" note))
        (cond
          ((null plist)
           (format stream "~&~%Nothing to change -- ~A already reads the way you would say it.~%" label)
           nil)
          (t
           (format stream "~&~%--- what this changes ------------------------------~%")
           (if (getf preview :changes)
               (dolist (change (getf preview :changes))
                 (format stream "~&  was: ~A~&  now: ~A~%~%" (car change) (cdr change)))
               (format stream "~&  nothing else in the ontology says this word.~%"))
           (dolist (break (getf preview :breaks))
             (format stream "~&  !! a test case stops matching:~
                             ~&     graph:    ~A~
                             ~&     expected: ~A~
                             ~&     would be: ~A~%~%"
                     (first break) (second break) (third break)))
           (unless (getf preview :test-cases-loaded)
             (format stream "~&  (no test cases loaded for this type -- load ~
                             test/generation-test.lisp~&   to check the sentences ~
                             that carry referents.)~%"))
           (cond
             ((cw-ask-yes-no stream "Keep this?" :default (null (getf preview :breaks)))
              (let ((line (commit-classification label answers)))
                (format stream "~&~%Registered for this session. To keep it, add this to~
                                ~& system/generation/lexicon.lisp:~&~%~&~A~%" line))
              plist)
             (t (format stream "~&~%Left alone.~%") nil))))))))
