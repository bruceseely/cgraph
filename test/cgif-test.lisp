(in-package :conceptual-graphs)

;;; FORMAT-CGIF, from the cgraph/cgif system: a graph written as extended CGIF
;;; (ISO/IEC 24707 Annex B). See notes/cgif.md for the design. This is build
;;; step 1 -- the direct mappings -- so there is no import yet to round-trip
;;; through, and each case gives the exact CGIF expected.

(defparameter *cgif-export-cases*
  ;; (linear form . CGIF)
  '(;; The shape of it: concepts first, the head first among them, then
    ;; relations with their source first and destination last. Unnamed
    ;; concepts with relations get fresh labels; a named one is referred to by
    ;; its name.
    ("[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]."
     . "[CAT: Tom] [EAT: *x1] [FOOD: *x2] (agnt ?x1 Tom) (obj ?x1 ?x2)")
    ("[PERSON: Sue]<-(agnt)<-[EAT]."
     . "[PERSON: Sue] [EAT: *x1] (agnt ?x1 Sue)")
    ;; A concept with no relations needs no label.
    ("[CAT]."                       . "[CAT]")
    ;; Labels the graph has are kept, and fresh ones skip them.
    ("[DOG: *x]."                   . "[DOG: *x]")
    ("[EAT: *x1]->(obj)->[FOOD]."   . "[EAT: *x1] [FOOD: *x2] (obj ?x1 ?x2)")
    ;; Coreference: *x defines, ?x refers back, as in cgraph.
    ("[EAT]- (agnt)→[PERSON: *x] (obj)→[FOOD] (rcpt)→[PERSON: ?x]."
     . "[EAT: *x1] [PERSON: *x] [FOOD: *x2] [PERSON: ?x] (agnt ?x1 ?x) (obj ?x1 ?x2) (rcpt ?x1 ?x)")
    ;; A lone ?c is cgraph's legacy defining label; CGIF defines with *.
    ("[CAT: ?c]."                   . "[CAT: *c]")
    ;; The same name twice is the same individual, in CGIF as in cgraph.
    ("[EAT]- (agnt)→[PERSON: Sue] (rcpt)→[PERSON: Sue]."
     . "[EAT: *x1] [PERSON: Sue] [PERSON: Sue] (agnt ?x1 Sue) (rcpt ?x1 Sue)")
    ;; A name with an id: the name only (notes/cgif.md, portable mode).
    ("[CAT: Felix #7]."             . "[CAT: Felix]")
    ;; Names that aren't CGIF identifiers are quoted. A hyphen isn't allowed
    ;; unquoted, so hyphenated types and relations are quoted too.
    ("[CITY: \"St. Louis\"]."       . "[CITY: \"St. Louis\"]")
    ("[CHEVY-VEHICLE]<-(inst)<-[DRIVE]->(agnt)->[PERSON: dave]."
     . "[\"CHEVY-VEHICLE\": *x1] [DRIVE: *x2] [PERSON: dave] (inst ?x2 ?x1) (agnt ?x2 dave)")
    ("[PERSON: Tom]->(life-stage)->[CHILDHOOD]."
     . "[PERSON: Tom] [CHILDHOOD: *x1] (\"life-stage\" Tom ?x1)")
    ;; @some is what a concept means anyway: dropped, not refused.
    ("[CAT: @some]."                . "[CAT]")))

(defparameter *cgif-refused-cases*
  ;; (linear form . words the refusal must contain). Each gets its CGIF form
  ;; in a later step; until then it is refused, never silently dropped.
  '(("[CAT: #12]."                       . "an individual id without a name")
    ("[CAT: #]."                         . "the individual marker #")
    ("[DOG: {Fido, Spot}]."              . "a set")
    ("[DOG: @every]."                    . "the quantifier @every")
    ("[EAT: @past]."                     . "the annotation @past")
    ("[PERSON: Tom]->(wgt)->[MASS: @80 kg]." . "a measure")
    ("~[[CAT]]."                         . "a nested graph")
    ("[PROPOSITION: [CAT]->(on)->[MAT]]." . "a nested graph")))

(defun cgif-test (&optional verbose)
  (let ((ok t))
    (flet ((check (name result)
             (setf ok (and ok (and result t)))
             (when (or verbose (not result))
               (format t "~&  ~:[fail~;pass~] ~a~%" result name))))
      (when verbose (format t "~&CGIF-TEST~%"))

      (loop for (lf . expected) in *cgif-export-cases*
            for actual = (handler-case (format-cgif (make-cgraph lf))
                           (error (c) (format nil "<error: ~a>" c)))
            do (check (format nil "~s => ~s~@[ (got ~s)~]" lf expected
                              (and (string/= actual expected) actual))
                      (string= actual expected)))

      (loop for (lf . words) in *cgif-refused-cases*
            for message = (handler-case (progn (format-cgif (make-cgraph lf)) nil)
                            (cgif-unsupported (c) (princ-to-string c)))
            do (check (format nil "~s is refused: ~a" lf words)
                      (and message (search words message))))

      (let ((graph (make-cgraph "[FOOD]<-(obj)<-[EAT]->(agnt)->[CAT].")))
        (check "the graph's head is written first"
               (eql 0 (search "[FOOD" (format-cgif graph)))))
      (check "a linear-form string is accepted"
             (string= (format-cgif "[CAT: Tom]<-(agnt)<-[EAT].")
                      "[CAT: Tom] [EAT: *x1] (agnt ?x1 Tom)"))
      (check "so is a node list"
             (string= (format-cgif (parse-cgraph "[CAT: Tom]<-(agnt)<-[EAT]."))
                      "[CAT: Tom] [EAT: *x1] (agnt ?x1 Tom)"))
      (check "with a stream, it writes there and returns NIL"
             (let ((result :unset))
               (and (string= (with-output-to-string (s)
                               (setf result (format-cgif "[CAT]." :stream s)))
                             "[CAT]")
                    (null result))))
      (check "names are quoted unless they are CGIF identifiers"
             (and (string= (cgif-name "Tom") "Tom")
                  (string= (cgif-name "x_1") "x_1")
                  (string= (cgif-name "life-stage") "\"life-stage\"")
                  (string= (cgif-name "St. Louis") "\"St. Louis\"")
                  (string= (cgif-name "1st") "\"1st\"")
                  (string= (cgif-name "say \"hi\"") "\"say \\\"hi\\\"\"")
                  (string= (cgif-name "⊤") "\"⊤\""))))
    ok))
