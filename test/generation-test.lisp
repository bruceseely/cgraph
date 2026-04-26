;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)

;;; Phase 1 generation tests: structural skeleton only.
;;; Expected strings are deliberately telegraphic — no morphology yet.
;;; Each entry: (graph-string . expected-text-or-nil).
;;; If expected is NIL, we just verify generation succeeds without error.

(defparameter *generation-test-cases*
  '(("[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."          . "A girl eats a pie.")
    ("[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."   . "Sue eats a pie.")
    ("[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."  . "Sue eats somehow.")
    ("[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."          . "A dog eats food.")
    ("[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."         . "A cat sits in a place.")
    ;; Phase 3: anaphora on revisit. Subject and recipient are the same
    ;; node (coreffed via *z), so the second mention becomes a pronoun.
    ;; Uses GIVE because it's defined in the user's type hierarchy and
    ;; takes both AGNT (animate) and RCPT (animate).
    ("[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z]."     . "A boy gives to him.")
    ("[GIRL: *z]<-(agnt)<-[GIVE]->(rcpt)->[GIRL: *z]."   . "A girl gives to her.")
    ("[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z]." . "A person gives to them.")
    ;; Phase 4: relative clauses (Sowa Rule 3). The dobj/iobj NP is itself
    ;; the agent of an unrealized act, which becomes a "that"/"who" clause.
    ("[BOY]<-(agnt)<-[GIVE]->(obj)->[DOG]<-(agnt)<-[EAT]->(obj)->[PIE]."
     . "A boy gives a dog that eats a pie.")
    ("[BOY]<-(agnt)<-[GIVE]->(obj)->[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]."
     . "A boy gives a girl who eats a pie.")
    ;; Phase 5: nested-graph referent (Sowa Rule 4). The [PROPOSITION: ...]
    ;; concept holds an inner graph that becomes a 'that' clause.
    ("[PERSON: ivan]<-(expr)<-[KNOW]->(stat)->[PROPOSITION: [GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]]."
     . "Ivan knows that a girl eats a pie.")
    ;; Phase 6: copular (verbless) clauses — no AGNT/EXPR, just an entity
    ;; with attribute or location predicates. Renders with BE-copula.
    ("[CAT]->(attr)->[FAST]."           . "A cat is fast.")
    ("[PERSON: ivan]->(loc)->[PLACE]."  . "Ivan is in a place.")
    ;; Phase 6: passive voice when there's an act with OBJ but no AGNT.
    ("[PIE]<-(obj)<-[EAT]."             . "A pie is eaten.")
    ("[FOOD]<-(obj)<-[EAT]."            . "Food is eaten.")
    ("[PIE]<-(obj)<-[GIVE]->(rcpt)->[GIRL]." . "A pie is given to a girl.")))

(defun generation-test (&optional verbose)
  (when verbose (format t "~%generation-test~%"))
  (reset-cgraph)
  (initialize-cgraph)
  (let ((*allow-dynamic-individual-creation* t)
        (failed '())
        (count 0)
        (passed 0))
    (dolist (case *generation-test-cases*)
      (incf count)
      (let* ((input    (car case))
             (expected (cdr case))
             (actual   (handler-case (graph-to-text input)
                         (error (c)
                           (format nil "<error: ~a>" c))))
             (ok (cond ((null expected) (and actual (plusp (length actual))))
                       (t (string= actual expected)))))
        (cond (ok (incf passed))
              (t (push (list input expected actual) failed)))
        (when (or verbose (not ok))
          (format t "~&  ~:[FAIL~;pass~]  ~s~%" ok input)
          (format t "    expected: ~s~%" expected)
          (format t "    actual:   ~s~%" actual))))
    (when (and verbose (null failed))
      (format t "~&  all ~d generation cases passed.~%" count))
    (null failed)))
