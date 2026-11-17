(in-package :conceptual-graphs)

;;; FORMAT-CGIF and PARSE-CGIF, from the cgraph/cgif system: graphs written as
;;; extended CGIF (ISO/IEC 24707 Annex B) and read back. See notes/cgif.md for
;;; the design. Export cases give the exact CGIF expected; the round trip --
;;; linear form, to CGIF, back to a graph -- runs over them and over every
;;; graph in GENERATION-TEST that can be exported yet.

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
     . "[EAT: *x1] [PERSON: *x] [FOOD: *x2] [PERSON: ?x *x3] (agnt ?x1 ?x) (obj ?x1 ?x2) (rcpt ?x1 ?x3)")
    ;; A lone ?c is cgraph's legacy defining label; CGIF defines with *. With
    ;; nothing coreferent it means nothing, and import doesn't keep it.
    ("[CAT: ?c]."                   . "[CAT: *c]")
    ;; A concept with ?x is a concept of its own, coreferent with the *x one,
    ;; so its relations need a label of its own to tell it apart.
    ;; (Above: [PERSON: ?x *x3] and (rcpt ?x1 ?x3).)
    ;; The same name twice is two concepts of one individual. A relation can't
    ;; tell them apart by the name, so they get labels.
    ("[EAT]- (agnt)→[PERSON: Sue] (rcpt)→[PERSON: Sue]."
     . "[EAT: *x1] [PERSON: Sue *x2] [PERSON: Sue *x3] (agnt ?x1 ?x2) (rcpt ?x1 ?x3)")
    ;; A concept met twice in linear form is one concept on a cycle: once.
    ("[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z]."
     . "[BOY: *z] [GIVE: *x1] (agnt ?x1 ?z) (rcpt ?x1 ?z)")
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
    ("[CAT: @some]."                . "[CAT]")
    ;; Contexts: the graph inside the concept, ~ for a negation.
    ("~[[CAT]]."                    . "~[PROPOSITION: [CAT]]")
    ("[[CAT]->(on)->[MAT]]."        . "[PROPOSITION: [CAT: *x1] [MAT: *x2] (on ?x1 ?x2)]")
    ("[BELIEF]->(stat)->[PROPOSITION: [PERSON: ivan]->(loc)->[PLACE]]."
     . "[BELIEF: *x1] [PROPOSITION: *x2 [PERSON: ivan] [PLACE: *x3] (loc ivan ?x3)] (stat ?x1 ?x2)")
    ;; Coreference into a context.
    ("[PERSON: mary *x]<-(expr)<-[BELIEF]->(stat)->[PROPOSITION: [PERSON: ?x]->(loc)->[PLACE]]."
     . "[PERSON: mary *x] [BELIEF: *x1] [PROPOSITION: *x2 [PERSON: ?x *x3] [PLACE: *x4] (loc ?x3 ?x4)] (expr ?x1 ?x) (stat ?x1 ?x2)")
    ;; An if-then: the inner negation stands beside the graph, unconnected,
    ;; and is written -- which the linear form doesn't do.
    ("~[Proposition: [Dog: *x]<-(agnt)<-[Bark] ~[Proposition: [Dog: ?x]->(attr)->[Noisy]]]"
     . "~[PROPOSITION: [DOG: *x] [BARK: *x1] ~[PROPOSITION: [DOG: ?x *x2] [NOISY: *x3] (attr ?x2 ?x3)] (agnt ?x1 ?x)]")))

(defparameter *cgif-refused-cases*
  ;; (linear form . words the refusal must contain). Each gets its CGIF form
  ;; in a later step; until then it is refused, never silently dropped.
  '(("[CAT: #12]."                       . "an individual id without a name")
    ("[CAT: #]."                         . "the individual marker #")
    ("[DOG: {Fido, Spot}]."              . "a set")
    ("[DOG: @every]."                    . "the quantifier @every")
    ("[EAT: @past]."                     . "the annotation @past")
    ("[PERSON: Tom]->(wgt)->[MASS: @80 kg]." . "a measure")
    ("~[CAT]."                           . "a negated concept with no graph inside")
    ;; Inside a context too.
    ("[[CAT: #12]]."                     . "an individual id without a name")))

(defparameter *cgif-import-cases*
  ;; (CGIF . linear form it reads as). CGIF written by others, not by
  ;; FORMAT-CGIF: labels on everything, mixed case, colons left out, comments.
  '(;; Sowa's example, from his CGIF summary.
    ("[Drive *x] [Person: Bob] [City: \"St. Louis\"] (Agnt ?x Bob) (Dest ?x \"St. Louis\")"
     . "[DRIVE]- (agnt)→[PERSON: Bob] (dest)→[CITY: \"St. Louis\"].")
    ;; Labels only relations use are wiring, and don't come in.
    ("[Cat *a] [Mat *b] (On ?a ?b)"       . "[CAT]→(on)→[MAT].")
    ("/* a comment */ [CAT: *a] /* another */ [MAT: *b] (on ?a ?b ; an end comment
     )"                                   . "[CAT]→(on)→[MAT].")
    ;; A constant no concept names gets a concept of the type its relation
    ;; allows there.
    ("[EAT *e] (agnt ?e Fido)"            . "[EAT]→(agnt)→[ANIMATE: Fido].")
    ;; The first concept is the head.
    ("[FOOD *f] [EAT *e] (obj ?e ?f)"     . "[FOOD]←(obj)←[EAT].")
    ;; Contexts. One with no type is a PROPOSITION, as [[...]] is.
    ("~[[Cat *x] [Mat *y] (On ?x ?y)]"    . "~[PROPOSITION: [CAT]→(on)→[MAT]].")
    ("[Proposition: [Cat]]"               . "[PROPOSITION: [CAT]].")
    ("[Belief *b] [Proposition *p [Person: ivan] [Place *l] (Loc ivan ?l)] (Stat ?b ?p)"
     . "[BELIEF]→(stat)→[PROPOSITION: [PERSON: ivan]→(loc)→[PLACE]].")
    ;; If/Then is ~[A ~[B]]: the inner negation stands beside the graph A.
    ("[If: [Cat *x] [Mat *y] (On ?x ?y) [Then: [Cat: ?x] [Old *z] (Attr ?x ?z)]]"
     . "~[PROPOSITION: [CAT: *x]→(on)→[MAT] ~[PROPOSITION: [CAT: ?x]→(attr)→[OLD]]].")))

(defparameter *cgif-idempotent-cases*
  ;; (CGIF . CGIF it comes back as, read and written again): the CGIF itself
  ;; checked, for a context's contents beside its graph.
  '(("[If: [Cat *x] [Mat *y] (On ?x ?y) [Then: [Cat: ?x] [Old *z] (Attr ?x ?z)]]"
     . "~[PROPOSITION: [CAT: *x] [MAT: *x1] ~[PROPOSITION: [CAT: ?x *x2] [OLD: *x3] (attr ?x2 ?x3)] (on ?x ?x1)]")
    ("[Either: [Or: [Cat]] [Or: [Dog]]]"
     . "~[PROPOSITION: ~[PROPOSITION: [CAT]] ~[PROPOSITION: [DOG]]]")
    ;; A relation in a context naming a concept outside it: the context gets
    ;; a coreferent concept of its own, [CAT: ?x].
    ("[If: [Cat *x] [Then: [Old *z] (Attr ?x ?z)]]"
     . "~[PROPOSITION: [CAT: *x] ~[PROPOSITION: [OLD: *x1] [CAT: ?x *x2] (attr ?x2 ?x1)]]")))

(defparameter *cgif-parse-error-cases*
  ;; (CGIF  words-the-message-must-contain  where-the-caret-goes), as in
  ;; PARSE-ERROR-TEST: a substring the error points at the start of.
  '(("[CAT] [DOG]"                  "isn't connected to [CAT]"       "[DOG]")
    ("[CAT: Tom] (agnt ?y Tom)"     "?y refers to *y, which no concept defines" "?y")
    ("[CAT *x] [DOG *x]"            "*x is defined twice"            "[DOG")
    ("[FOOBAR]"                     "no concept type FOOBAR"         "[FOOBAR]")
    ("[CAT *x] (foo ?x ?x)"         "no relation type foo"           "(foo")
    ("[CAT *x] [MAT *y] (on ?x ?y"  "has no closing )"               "(on")
    ("[CAT *x"                      "has no closing ]"               "[CAT")
    ("[CAT *x] [EAT *y] (agnt ?x ?y)" "[CAT] can't be the source of (agnt)" "(agnt")
    ("[CAT *x] (on ?x)"             "needs at least two arguments"   "(on")
    ("[CAT *x] (on *x ?x)"          "refers to a label with ?, not *" "*x ?x)")
    ("[CAT: \"Tom]"                "has no closing \""             "\"Tom")
    ("/* never closed [CAT]"        "has no closing */"              "/*")
    ("[CAT] junk"                   "expected a concept"             "junk")
    (""                             "there is no concept"            :end)
    ;; Contexts.
    ("~[CAT]"                       "a negation holds a graph"       "~")
    ("~ CAT"                        "~ negates a context"            "~")
    ("[If: [CAT] [MAT]]"            "only another context may stand apart" "[MAT]")
    ("[If:]"                        "a negation holds a graph"       "[If")
    ("~[If: [CAT]]"                 "a negation twice over"          "~")
    ("[PROPOSITION: [CAT]"          "a context has no closing ]"     :end)
    ("[CAT *x] [PROPOSITION: (stat ?x ?x)]" "holds no concept"       "[PROPOSITION")
    ;; What later steps will read, refused until then.
    ("[Equiv: [Iff: [CAT]] [Iff: [DOG]]]" "Equiv isn't supported"    "[Equiv")
    ("[PROPOSITION: Tom [CAT]]"     "also has a name"                "[PROPOSITION")
    ("[*x]"                         "no type (core CGIF)"            "[*x")
    ("[CAT: @every *x]"             "@every"                         "@every")
    ("[CAT *x] (Add ?x 7 | [*u])"   "An actor"                       "| [")))

(defun cgif-normal-lf (thing)
  "THING's linear form with its coreference labels renamed v1, v2, ... in
   order of first appearance. The formatter makes up the labels it shows for
   a concept met twice, and which letters it picks is not part of the graph."
  (let ((text (format-cgraph thing))
        (names (make-hash-table :test 'equal)))
    (with-output-to-string (out)
      (let ((i 0) (n (length text)))
        (loop while (< i n)
              do (let ((c (char text i)))
                   (if (and (member c '(#\* #\?))
                            (< (1+ i) n)
                            (alpha-char-p (char text (1+ i))))
                       (let* ((end (or (position-if-not #'alphanumericp text :start (1+ i)) n))
                              (label (subseq text (1+ i) end)))
                         (format out "~c~a" c
                                 (or (gethash label names)
                                     (setf (gethash label names)
                                           (format nil "v~d" (hash-table-count names)))))
                         (setf i end))
                       (progn (write-char c out) (incf i)))))))))

(defun cgif-round-trips-p (graph)
  "True when GRAPH, written as CGIF and read back, is the same graph."
  (string= (cgif-normal-lf graph)
           (cgif-normal-lf (parse-cgif (format-cgif graph)))))

(defun cgif-drops-something-p (graph)
  "True when exporting GRAPH and reading it back leaves out something, on
   purpose: @some, and an individual's id when it also has a name, which
   portable mode drops; and a label nothing else shares, [CAT: ?c] or
   [EAT: *x1], which means nothing in CGIF and is not read back."
  (some (lambda (node)
          (and (concept-p node)
               (or (eq (concept-quantifier node) :existential)
                   (and (or (concept-coref-label node) (coref-bound-label node)
                            (node-variable node))
                        (null (coreference node)))
                   (let ((content (and (referent node) (content (referent node)))))
                     (and (typep content 'individual)
                          (cgif-concept-name node)
                          (plusp (length (id-text node))))))))
        (nodes graph)))

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

      ;; Import.
      (loop for (cgif . lf) in *cgif-import-cases*
            for actual = (handler-case (cgif-normal-lf (parse-cgif cgif))
                           (error (c) (format nil "<error: ~a>" c)))
            for expected = (cgif-normal-lf (parse-cgraph lf))
            do (check (format nil "~s reads as ~s~@[ (got ~s)~]" cgif lf
                              (and (string/= actual expected) actual))
                      (string= actual expected)))

      (loop for (text words where) in *cgif-parse-error-cases*
            for condition = (handler-case (progn (parse-cgif text) nil)
                              (cgraph-parse-error (c) c))
            do (check (format nil "~s is an error" text) condition)
               (when condition
                 (check (format nil "~s says ~s" text words)
                        (search words (parse-error-message condition)))
                 (check (format nil "~s points at ~s" text where)
                        (eql (if (eq where :end) (length text) (search where text))
                             (let ((p (parse-error-position condition)))
                               (and p (or (position-if-not (lambda (c) (member c '(#\Space #\Tab #\Newline)))
                                                           text :start p)
                                          p)))))))

      (loop for (cgif . expected) in *cgif-idempotent-cases*
            for actual = (handler-case (format-cgif (parse-cgif cgif))
                           (error (c) (format nil "<error: ~a>" c)))
            do (check (format nil "~s comes back as ~s~@[ (got ~s)~]" cgif expected
                              (and (string/= actual expected) actual))
                      (string= actual expected))
               ;; and that is a fixed point
               (check (format nil "~s is written the same once read again" expected)
                      (string= (handler-case (format-cgif (parse-cgif expected))
                                 (error (c) (format nil "<error: ~a>" c)))
                               expected)))

      ;; The round trip, over the export cases and over GENERATION-TEST's graphs.
      (let ((tried 0) (failed '()))
        (dolist (lf (append (mapcar #'car *cgif-export-cases*)
                            (mapcar #'car *generation-test-cases*)))
          (let ((graph (ignore-errors (make-cgraph lf))))
            (when (and graph
                       (not (cgif-drops-something-p graph))
                       (handler-case (progn (format-cgif graph) t)
                         (cgif-unsupported () nil)))
              (incf tried)
              (unless (ignore-errors (cgif-round-trips-p graph))
                (push lf failed)))))
        (check (format nil "~d graphs come back from CGIF as they went~@[; not ~s~]"
                       tried failed)
               (and (null failed) (> tried 50))))

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
