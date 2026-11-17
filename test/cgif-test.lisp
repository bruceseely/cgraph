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

(defparameter *cgif-mode-cases*
  ;; (linear form  portable  strict  lossless). Each is the CGIF expected, or
  ;; (:refused words) for a CGIF-UNSUPPORTED whose message has WORDS, or
  ;; (:dropped CGIF words) for that CGIF written with a CGIF-DROPPED warning
  ;; whose message has WORDS. The rows of notes/cgif.md's "No standard CGIF
  ;; form" table.
  ;; Ids are high so that no individual made earlier in the run has them.
  '(;; Standard in every mode.
    ("[DOG: @every]."  "[DOG: @every *x1]" "[DOG: @every *x1]" "[DOG: @every *x1]")
    ("[PERSON: @every]<-(agnt)<-[EAT]."
     "[PERSON: @every *x1] [EAT: *x2] (agnt ?x2 ?x1)"
     "[PERSON: @every *x1] [EAT: *x2] (agnt ?x2 ?x1)"
     "[PERSON: @every *x1] [EAT: *x2] (agnt ?x2 ?x1)")
    ("[CAT: #9012]."   "[CAT: \"#9012\"]" "[CAT: \"#9012\"]" "[CAT: \"#9012\"]")
    ;; A named individual is written by name alone, as the linear form does.
    ("[CAT: Felix #9007]." "[CAT: Felix]" "[CAT: Felix]" "[CAT: Felix]")
    ;; No logical meaning: dropped with a warning, refused by :strict.
    ("[CAT: #]."       (:dropped "[CAT]" "the individual marker #")
                       (:refused "the individual marker # has no standard CGIF form")
                       "[CAT: #]")
    ("[EAT: @past]."   (:dropped "[EAT]" "the annotation @past")
                       (:refused "the annotation @past")
                       "[EAT: @past]")
    ("[EAT: *e @past-progressive @passive]."
                       (:dropped "[EAT: *e]" "the annotation @passive")
                       (:refused "the annotation @past-progressive")
                       "[EAT: @past-progressive @passive *e]")
    ;; @some is what a concept means anyway: dropped without a word.
    ("[CAT: @some]."   "[CAT]" (:refused "@some") "[CAT: @some]")
    ;; Can't be said: refused unless :lossless.
    ("[DOG: {Fido, Spot}]."  (:refused "a set has no standard CGIF form")
                             (:refused "a set") "[DOG: {Fido, Spot}]")
    ("[DOG: {Fido, Spot, *} @ 4]." (:refused "a set") (:refused "a set")
                                   "[DOG: {Fido, Spot, *}@4]")
    ("[PERSON: Tom]->(wgt)->[MASS: @80 kg]."
     (:refused "a measure") (:refused "a measure")
     "[PERSON: Tom] [MASS: @80 kg *x1] (wgt Tom ?x1)")
    ("[CAT: @most]."   (:refused "the quantifier @most") (:refused "@most") "[CAT: @most]")))

(defparameter *cgif-refused-cases*
  ;; (linear form . words the refusal must contain), in every mode.
  '(("~[CAT]."                           . "a negated concept with no graph inside")))

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
    ;; @every is the universal quantifier; its label is wiring like any other.
    ("[Cat: @every *x] [Mat *y] (On ?x ?y)" . "[CAT: @every]→(on)→[MAT].")
    ;; An id written as a constant is the id.
    ("[Cat: \"#12\"]"                     . "[CAT: #12].")
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
    ("[CAT: @]"                     "@ needs a word or a number"     "]")
    ("[DOG: {Fido, Spot]"           "this set has no closing }"      "{Fido")
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

(defun cgif-round-trips-p (graph &optional (mode :portable))
  "True when GRAPH, written as CGIF in MODE and read back, is the same graph."
  (string= (cgif-normal-lf graph)
           (cgif-normal-lf (parse-cgif (format-cgif graph :mode mode)))))

(defparameter *cgif-referent-catalog*
  ;; The examples of docs/referents.md, each in a concept.
  ;; (#9123 for the catalog's #123: an id made earlier in the run would clash.)
  '("[DOG]." "[DOG: *]." "[DOG: *x]." "[DOG: ?x]." "[DOG: #9123]." "[DOG: #]." "[DOG: Fido]."
    "[DOG: {*}]." "[DOG: {}]." "[DOG: {Fido, Spot}]." "[DOG: {Fido, #9123, *}]."
    "[DOG: {*} @ 5]." "[DOG: {Fido, Spot, *} @ 4]."
    "[MASS: @ 5 ft.]." "[MASS: @25.4 cm]."
    "[EAT: @past]." "[EAT: @future]." "[EAT: @present]." "[EAT: @progressive]."
    "[EAT: @perfect-progressive]." "[EAT: @past-progressive]." "[EAT: @future-perfect]."
    "[EAT: @passive]." "[EAT: @active]."
    "[DOG: @every]." "[DOG: @all]." "[DOG: @some]." "[DOG: @most]."
    "[CAT: Felix #9007]." "[EAT: *e @past-progressive @passive]." "[PERSON: ?x @every]."
    "~[[PERSON: *x]->(attr)->[OLD]]."))

(defun cgif-lone-label-p (graph)
  "True when GRAPH has a label nothing else shares, [CAT: ?c] or [EAT: *x1]:
   it means nothing in CGIF, and import doesn't keep it."
  (some (lambda (node)
          (and (concept-p node)
               (or (concept-coref-label node) (coref-bound-label node)
                   (node-variable node))
               (null (coreference node))))
        ;; nested contexts too
        (cgif-all-nodes (remove-if-not #'concept-p (nodes graph)) nil)))

(defun cgif-drops-something-p (graph)
  "True when exporting GRAPH in :PORTABLE leaves out something, on purpose,
   without a warning: @some, and an individual's id beside its name. (What
   it drops with a warning is caught by the caller.)"
  (some (lambda (node)
          (and (concept-p node)
               (or (eq (concept-quantifier node) :existential)
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

      ;; The modes.
      (loop for (lf . expectations) in *cgif-mode-cases*
            do (loop for mode in '(:portable :strict :lossless)
                     for expected in expectations
                     for name = (format nil "~s as ~(~a~): ~s" lf mode expected)
                     do (let ((warning nil) (refusal nil) (text nil))
                          (handler-case
                              (handler-bind ((cgif-dropped
                                               (lambda (w)
                                                 (setf warning (princ-to-string w))
                                                 (muffle-warning w))))
                                (setf text (format-cgif (make-cgraph lf) :mode mode)))
                            (cgif-unsupported (c) (setf refusal (princ-to-string c)))
                            (error (c) (setf text (format nil "<error: ~a>" c))))
                          (check name
                                 (cond ((stringp expected)
                                        (and (equal text expected) (null warning)))
                                       ((eq (first expected) :refused)
                                        (and refusal (search (second expected) refusal)))
                                       ((eq (first expected) :dropped)
                                        (and (equal text (second expected))
                                             warning (search (third expected) warning))))))))

      ;; The round trip: every graph of the export cases, the referent
      ;; catalog (docs/referents.md) and GENERATION-TEST, in :LOSSLESS, which
      ;; promises it; and in :PORTABLE, the ones it drops nothing from.
      (let ((lossless 0) (portable 0) (failed '()))
        (dolist (lf (append (mapcar #'car *cgif-export-cases*)
                            (mapcar #'car *cgif-mode-cases*)
                            *cgif-referent-catalog*
                            (mapcar #'car *generation-test-cases*)))
          (let ((graph (ignore-errors (make-cgraph lf))))
            (when (and graph (not (cgif-lone-label-p graph)))
              (when (handler-case (progn (format-cgif graph :mode :lossless) t)
                      (cgif-unsupported () nil))
                (incf lossless)
                (unless (ignore-errors (cgif-round-trips-p graph :lossless))
                  (push (list :lossless lf) failed)))
              ;; A fresh graph: reading the CGIF back replaced the variable
              ;; table, which clears the *x labels of every graph made before
              ;; (notes/known-issues.md), this one included.
              (setf graph (make-cgraph lf))
              (when (and (not (cgif-drops-something-p graph))
                         (handler-case
                             (handler-bind ((cgif-dropped (lambda (w) (declare (ignore w))
                                                            (error 'cgif-unsupported))))
                               (progn (format-cgif graph) t))
                           (cgif-unsupported () nil)))
                (incf portable)
                (unless (ignore-errors (cgif-round-trips-p graph))
                  (push (list :portable lf) failed))))))
        (check (format nil "~d graphs come back from lossless CGIF as they went, ~
                            and ~d from portable~@[; not ~s~]"
                       lossless portable failed)
               (and (null failed) (> lossless 150) (> portable 50))))

      ;; Several graphs to a text: WRITE-CGIF-GRAPHS and READ-CGIF-GRAPHS.
      (let* ((sources '("[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]."
                        "[EAT]- (agnt)→[PERSON: *x] (obj)→[FOOD] (rcpt)→[PERSON: ?x]."
                        "[EAT]- (agnt)→[PERSON: *x] (obj)→[FOOD] (rcpt)→[PERSON: ?x]."
                        "~[Proposition: [Dog: *x]<-(agnt)<-[Bark] ~[Proposition: [Dog: ?x]->(attr)->[Noisy]]]"
                        "[DOG: {Fido, Spot}]."))
             ;; Each made and printed right away: parsing the next one clears
             ;; this one's *x labels (notes/known-issues.md).
             (expected '())
             (graphs (mapcar (lambda (lf)
                               (let ((g (make-cgraph lf)))
                                 (push (cgif-normal-lf g) expected)
                                 g))
                             sources))
             (expected (nreverse expected))
             (text (write-cgif-graphs graphs nil :mode :lossless))
             (back (let ((*context* (make-context nil)))
                     (read-cgif-graphs text))))
        (check "write-cgif-graphs writes a graph to a line"
               (= (length sources) (count #\Newline text)))
        (check "and read-cgif-graphs reads them back, the same graphs"
               (equal (mapcar #'cgif-normal-lf back) expected))
        (check "two graphs using the same label stay two graphs, not coreferent"
               (flet ((people (graph)
                        (remove-if-not (lambda (n) (and (concept-p n)
                                                        (string-equal (label (concept-type n)) "PERSON")))
                                       (nodes graph))))
                 (and (= 5 (length back))
                      (notany (lambda (p)
                                (intersection (coreference p) (people (third back))))
                              (people (second back))))))
        (check "a label defined in one line is not defined again in another"
               (let ((labels '()) (ok t))
                 (loop for i from 0 below (length text)
                       when (and (char= (char text i) #\*)
                                 (< (1+ i) (length text))
                                 (alpha-char-p (char text (1+ i))))
                         do (let* ((end (or (position-if-not #'alphanumericp text :start (1+ i))
                                            (length text)))
                                   (label (subseq text (1+ i) end)))
                              (when (member label labels :test #'string=) (setf ok nil))
                              (push label labels)))
                 ok))
        (check "the graphs go into the context"
               (let ((*context* (make-context nil)))
                 (read-cgif-graphs text)
                 (= 5 (length (graphs *context*))))))
      (let ((path (merge-pathnames (format nil "cgif-test-~d.cgif" (random 1000000))
                                   (uiop:temporary-directory))))
        (unwind-protect
             (let ((graphs (list (make-cgraph "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD].")
                                 (make-cgraph "[DOG]<-(agnt)<-[BARK]."))))
               (write-cgif-graphs graphs path)
               (check "through a file too"
                      (equal (mapcar #'cgif-normal-lf
                                     (let ((*context* (make-context nil)))
                                       (read-cgif-graphs path)))
                             (mapcar #'cgif-normal-lf graphs))))
          (when (probe-file path) (delete-file path))))
      ;; Another tool's text: parts side by side, linked only by ?p.
      (let ((back (let ((*context* (make-context nil)))
                    (read-cgif-graphs
                     "[Person: *p] [Eat *e] (Agnt ?e ?p) ~[ (Attr ?p ?o) [Old *o] ]"))))
        (check "a text of several parts reads as a graph for each"
               (equal (mapcar #'cgif-normal-lf back)
                      '("[PERSON:*v0]←(agnt)←[EAT]." "~[PROPOSITION:[OLD]←(attr)←[PERSON:?v0]].")))
        (check "and the coreference between them is kept"
               (let* ((person (head (first back)))
                      (inner (graph-referent (head (second back))))
                      (other (find-if (lambda (n) (and (concept-p n)
                                                       (string-equal (label (concept-type n)) "PERSON")))
                                      (nodes inner))))
                 (and other (member other (coreference person)) t))))
      (check "parse-cgif still reads only one connected graph"
             (handler-case (progn (parse-cgif "[CAT] [DOG]") nil)
               (cgraph-parse-error () t)))
      ;; The ISO text form, [Proposition: ...] around everything.
      (let ((iso "[Proposition: [Cat *x] [Mat *y] (On ?x ?y)]"))
        (check "a [Proposition: ...] text is a PROPOSITION graph by default"
               (equal (mapcar #'cgif-normal-lf (let ((*context* (make-context nil)))
                                                 (read-cgif-graphs iso)))
                      '("[PROPOSITION:[CAT]→(on)→[MAT]].")))
        (check ":unwrap reads what is inside"
               (equal (mapcar #'cgif-normal-lf (let ((*context* (make-context nil)))
                                                 (read-cgif-graphs iso :unwrap t)))
                      '("[CAT]→(on)→[MAT]."))))

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
