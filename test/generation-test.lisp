;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)

;;; Phase 1 generation tests: structural skeleton only.
;;; Expected strings are deliberately telegraphic — no morphology yet.
;;; Each entry: (graph-string . expected-text-or-nil).
;;; If expected is NIL, we just verify generation succeeds without error.

(defparameter *generation-test-cases*
  '(("[girl]"                            . "A girl.")
    ("[girl: #]"                         . "The girl.")
    ("[girl: #9999]"                     . "The girl.")
    ("[girl: Sally]"                     . "Sally.")
    ("[dog: {}]"                         . "Dogs.")
    ("[dog: {*}]"                        . "Dogs.")
    ("[dog: {*}@3]"                      . "Three dogs.")
    ("[dog: {Spot, Fido}]"               . "The dogs Spot and Fido.")
    ("[dog: {Butch, Spot, Fido}]"        . "The dogs Butch, Spot, and Fido.")

    ("[DOG: {} @ 5]"                     . "Five dogs.")
    ("[DOG: {*} @ 5]"                    . "Five dogs.")
    ("[DOG: {Fido, *} @3]"               . "Fido and two other dogs.")
    ("[DOG: {Fido, #123}]"               . "Fido and another dog.")

    ("[PERSON: #2]" . "Sally.")
    ("[PERSON: Judy]" . "Judy.")
    ;;("[PERSON: Judy #2]" . "Sally.- should be an error")
    ("[PERSON: Judy #999]" . "Judy.")
    ("[PERSON: #2]" . "Sally.")
    ("[PERSON: Sally #2]" . "Sally.")

    ("[length: @ 5 ft.]"                 . "The length five feet.")
    ("[length: @5ft.]"                   . "The length five feet.")
    ("[rock]→(chrc)→[LENGTH:@25.4 cm]."  . "A rock of the length 25.4 centimeters.")

    ;; Sowa quantifiers: @every / @some on a singular concept.
    ("[CAT: @every]"                     . "Every cat.")
    ("[CAT: @all]"                       . "Every cat.")
    ("[CAT: @any]"                       . "Every cat.")
    ("[CAT: @some]"                      . "A cat.")
    ("[DOG: @every]"                     . "Every dog.")
    ;; Quantifier over a set referent: universal -> "all", existential -> "some".
    ("[DOG: {*}@every]"                  . "All dogs.")
    ("[DOG: {*}@some]"                   . "Some dogs.")
    ;; Quantified subject in a verbal clause.
    ("[DOG: @every]<-(agnt)<-[BARK]."    . "Every dog barks.")
    ("[DOG: {*}@every]<-(agnt)<-[BARK]." . "All dogs bark.")
    ("[DOG: {*}@some]<-(agnt)<-[BARK]."  . "Some dogs bark.")
    ;; Quantifiers in non-subject positions.
    ("[CAT: @every]->(attr)->[FAST]."                          . "Every cat is fast.")
    ("[CAT: {*}@every]->(attr)->[FAST]."                       . "All cats are fast.")
    ("[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE: @every]."            . "A girl eats every pie.")
    ("[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE: {*}@some]."          . "A girl eats some pies.")
    ("[PERSON: @every]<-(agnt)<-[EAT]->(obj)->[PIE: @some]."   . "Every person eats a pie.")
    ("[CAT: @every]<-(obj)<-[EAT]."                            . "Every cat is eaten.")
    ;; Quantifier inside a nested PROPOSITION referent.
    ("[PERSON: ivan]<-(expr)<-[KNOW]->(stat)->[PROPOSITION: [DOG: @every]<-(agnt)<-[BARK]]."
     . "Ivan knows that every dog barks.")
    ("[PERSON: ivan]<-(expr)<-[KNOW]->(stat)->[PROPOSITION: [DOG: {*}@every]<-(agnt)<-[BARK]]."
     . "Ivan knows that all dogs bark.")

    ;; Tense / aspect on the verb concept: @past / @future / @progressive.
    ("[GIRL]<-(agnt)<-[EAT: @past]->(obj)->[PIE]."        . "A girl ate a pie.")
    ("[GIRL]<-(agnt)<-[EAT: @future]->(obj)->[PIE]."      . "A girl will eat a pie.")
    ("[GIRL]<-(agnt)<-[EAT: @progressive]->(obj)->[PIE]." . "A girl is eating a pie.")
    ("[DOG: {*}@every]<-(agnt)<-[BARK: @past]."           . "All dogs barked.")
    ("[DOG: {*}@every]<-(agnt)<-[BARK: @progressive]."    . "All dogs are barking.")
    ;; Tense propagates through passive voice (be-form-for picks 'was'/'will be').
    ("[PIE]<-(obj)<-[EAT: @past]."                        . "A pie was eaten.")
    ("[PIE]<-(obj)<-[EAT: @future]."                      . "A pie will be eaten.")

    ;; Compound tense/aspect: hyphenated annotations on the verb concept.
    ("[GIRL]<-(agnt)<-[EAT: @perfect]->(obj)->[PIE]."             . "A girl has eaten a pie.")
    ("[GIRL]<-(agnt)<-[EAT: @past-perfect]->(obj)->[PIE]."        . "A girl had eaten a pie.")
    ("[GIRL]<-(agnt)<-[EAT: @past-progressive]->(obj)->[PIE]."    . "A girl was eating a pie.")
    ("[GIRL]<-(agnt)<-[EAT: @future-perfect]->(obj)->[PIE]."      . "A girl will have eaten a pie.")
    ("[GIRL]<-(agnt)<-[EAT: @future-progressive]->(obj)->[PIE]."  . "A girl will be eating a pie.")
    ("[GIRL]<-(agnt)<-[EAT: @perfect-progressive]->(obj)->[PIE]." . "A girl has been eating a pie.")
    ("[DOG: {*}@every]<-(agnt)<-[BARK: @perfect]."                . "All dogs have barked.")
    ("[DOG: {*}@every]<-(agnt)<-[BARK: @past-progressive]."       . "All dogs were barking.")
    ;; Compound aspect in passive voice.
    ("[PIE]<-(obj)<-[EAT: @perfect]."                             . "A pie has been eaten.")
    ("[PIE]<-(obj)<-[EAT: @past-perfect]."                        . "A pie had been eaten.")
    ("[PIE]<-(obj)<-[EAT: @progressive]."                         . "A pie is being eaten.")

    ;; Tense inferred from a TIME relation when no explicit @past/@future.
    ;; The deictic time word also surfaces as a bare adverb (no 'at').
    ("[GIRL]<-(agnt)<-[EAT]- (obj)→[PIE] (time)→[time-period: yesterday]."
     . "A girl ate a pie yesterday.")
    ("[GIRL]<-(agnt)<-[EAT]- (obj)→[PIE] (time)→[time-period: tomorrow]."
     . "A girl will eat a pie tomorrow.")
    ("[GIRL]<-(agnt)<-[EAT]- (obj)→[PIE] (time)→[time-period: now]."
     . "A girl eats a pie now.")
    ;; Explicit annotation wins over inference.
    ("[GIRL]<-(agnt)<-[EAT: @past]- (obj)→[PIE] (time)→[time-period: tomorrow]."
     . "A girl ate a pie tomorrow.")

    ;; Voice annotation: '@passive' forces the passive transformation even
    ;; when the head is on the agent; '@active' overrides the head-driven
    ;; passive default when the head is on the object.
    ("[GIRL]<-(agnt)<-[EAT: @passive]->(obj)->[PIE]."             . "A pie is eaten by a girl.")
    ("[GIRL]<-(agnt)<-[EAT: @passive @past]->(obj)->[PIE]."       . "A pie was eaten by a girl.")
    ("[GIRL]<-(agnt)<-[EAT: @passive @perfect]->(obj)->[PIE]."    . "A pie has been eaten by a girl.")
    ("[PIE]<-(obj)<-[EAT]->(agnt)->[GIRL]."                       . "A pie is eaten by a girl.")
    ("[PIE]<-(obj)<-[EAT: @active]->(agnt)->[GIRL]."              . "A girl eats a pie.")

    ;; Coordination via Sowa link relations on PROPOSITION concepts.
    ("[PROPOSITION: [GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]]->(and)->[PROPOSITION: [BOY]<-(agnt)<-[DRINK]]."
     . "A girl eats a pie and a boy drinks.")
    ("[PROPOSITION: [DOG]<-(agnt)<-[BARK]]->(or)->[PROPOSITION: [CAT]<-(agnt)<-[SIT]]."
     . "A dog barks or a cat sits.")
    ;; Tense flows through each conjunct independently.
    ("[PROPOSITION: [GIRL]<-(agnt)<-[EAT: @past]->(obj)->[PIE]]->(and)->[PROPOSITION: [BOY]<-(agnt)<-[DRINK: @past]]."
     . "A girl ate a pie and a boy drank.")

    ;; Phrasal verbs: lexicon override sets :lemma + :particle, the
    ;; particle surfaces after the inflected main verb in active and
    ;; passive voice and across tense/aspect.
    ("[GIRL]<-(agnt)<-[PICK-UP]->(obj)->[PIE]."                   . "A girl picks up a pie.")
    ("[GIRL]<-(agnt)<-[PICK-UP: @past]->(obj)->[PIE]."            . "A girl picked up a pie.")
    ("[GIRL]<-(agnt)<-[PICK-UP: @progressive]->(obj)->[PIE]."     . "A girl is picking up a pie.")
    ("[GIRL]<-(agnt)<-[PICK-UP: @perfect]->(obj)->[PIE]."         . "A girl has picked up a pie.")
    ("[PIE]<-(obj)<-[PICK-UP]."                                   . "A pie is picked up.")
    ("[PIE]<-(obj)<-[PICK-UP: @past]."                            . "A pie was picked up.")
    ("[GIRL]<-(agnt)<-[PICK-UP: @passive]->(obj)->[PIE]."         . "A pie is picked up by a girl.")

    ("[DOG]-(agnt)<-[SIT](loc)->[PLACE]."         . "A dog sits in a place.")
    ("[DOG]-(agnt)<-[SIT](ploc)->[PLACE]."        . "A dog sits at a place.")
    ("[DOG: #]-(agnt)<-[SIT] (ploc)->[PLACE]."    . "The dog sits at a place.")
    ("[PLACE: #]←(ploc)←[DOG: #]←(agnt)←[SIT]."   . "The dog sits at the place.")
    ("[SIT]→(agnt)→[DOG: #]→(ploc)→[PLACE: #]."   . "The dog sits at the place.")

    ("[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."          . "A girl eats a pie.")
    ("[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."   . "Sue eats a pie.")
    ("[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."  . "Sue eats somehow.")
    ("[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."          . "A dog eats food.")
    ("[DOG]->(loc)->[PLACE: #]."                     . "A dog is in the place.")
    ("[DOG]->(ploc)->[PLACE: #]."                    . "A dog is at the place.")
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
    ("[DOG]->(attr)->[FAST]."           . "A dog is fast.")
    ("[PERSON: ivan]->(loc)->[PLACE]."  . "Ivan is in a place.")
    ;; Phase 6: passive voice when there's an act with OBJ but no AGNT.
    ("[PIE]<-(obj)<-[EAT]."             . "A pie is eaten.")
    ("[FOOD]<-(obj)<-[EAT]."            . "Food is eaten.")
    ("[PIE]<-(obj)<-[GIVE]->(rcpt)->[GIRL]." . "A pie is given to a girl.")
    ;; POSS direction + HAVE construction.
    ("[PERSON: dave]->(poss)->[CHEVY-VEHICLE]." . "Dave has a chevy-vehicle.")
    ("[BOY]->(poss)->[DOG]."                    . "A boy has a dog.")
    ;; Leftover POSS: a verbal clause plus a possession assertion that the
    ;; parser didn't fold into the main NP (typically because coref across
    ;; commas didn't merge the two [DOG: Spot] tokens). Should be appended
    ;; as an 'and X has Y' coordination rather than silently dropped.
    ("[PERSON: sue]-(agnt)<-[GIVE]-(obj)->[FOOD] (rcpt)->[DOG: spot], (poss)->[DOG: spot]."
     . "Sue gives food to Spot, and she has Spot.")
    ("[PERSON: Dave]-(agnt)<-[GIVE]-(obj)->[FOOD] (rcpt)->[DOG: spot], (poss)->[DOG: spot]."
     . "Dave gives food to Spot, and he has Spot.")
    ("[PERSON: Dexter]-(agnt)<-[GIVE]-(obj)->[FOOD] (rcpt)->[DOG: spot], (poss)->[DOG: spot]."
     . "Dexter gives food to Spot, and he has Spot.")
    ("[CHEVY-VEHICLE]- (attr)→[OLD] (inst)←[DRIVE]- (agnt)→[PERSON: dave *j]→(attr)→[YOUNG] (dest)→[CITY: Baltimore],(poss)←[PERSON: dave *j]." . "Young Dave drives with Dave's old chevy-vehicle to Baltimore.")
    ("[CHEVY-VEHICLE]- (attr)→[OLD] (inst)←[DRIVE]- (agnt)→[PERSON: Dave *x]→(attr)→[YOUNG] (dest)→[CITY: Baltimore],(poss)←[PERSON: Dave *x]." . "Young Dave drives with Dave's old chevy-vehicle to Baltimore.")


    ))

(defun generation-test (&optional verbose)
  (with-test-types
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
             ;; Build through make-cgraph so the graph carries its head;
             ;; head is needed by graph-to-text's voice dispatch (Sowa
             ;; head-driven passive transformation).
             (actual   (handler-case (graph-to-text (make-cgraph input))
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
    (null failed))))
