;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  CGIF import: extended CGIF text to cgraph nodes, the part of it cgraph's
;;  graphs use. notes/cgif.md has the design.
;;
;;    [CAT: Tom] [EAT: *x1] [FOOD: *x2] (agnt ?x1 Tom) (obj ?x1 ?x2)
;;      => the nodes of [CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]
;;
;;  The text is split into concepts and relations here. Each plain concept is
;;  handed to cgraph's own concept reader, as linear form, inside one reading
;;  session -- so names, individuals and *x/?x coreference behave exactly as
;;  they do for PARSE-CGRAPH -- and the relations are connected afterwards.
;;
;;  Labels. In CGIF a relation names its arguments by label, so nearly every
;;  concept in a CGIF text has one: [Drive *x] (Agnt ?x Bob). A label that
;;  only relation arguments in the same context refer to is wiring, and is
;;  not kept: cgraph connects the relation to the concept instead, and the
;;  concept comes in without a label. A label that another CONCEPT refers to,
;;  [Person: ?x], is coreference between two concepts, which cgraph
;;  represents with the same *x/?x, so it is kept.
;;
;;  Contexts. A concept holding a graph, [Proposition: [Cat] ...], or a
;;  negation, ~[ ... ], is built the way the linear-form reader builds one: a
;;  child context, the inner graph made in it, and a concept whose referent is
;;  that graph, created in the child context as the reader does it. A
;;  context with no type is a PROPOSITION, as [[...]] is in linear form.
;;  If/Then and Either/Or are negations with a type label, by the standard's
;;  own definition: [If: A [Then: B]] is ~[A ~[B]], and [Either: [Or: A]
;;  [Or: B]] is ~[~[A] ~[B]]. They come in as negated PROPOSITIONs.
;;
;;  Inside a context, cgraph keeps one connected graph, from its first
;;  concept; nested contexts may stand beside it unconnected, which is how
;;  ~[A ~[B]] is held (the inner negation is in the child context, not the
;;  graph). Any other concept left unconnected is an error.
;;
;;  A relation inside a context may name, with ?x, a concept defined outside
;;  it. cgraph can't connect a relation across contexts, so the context gets
;;  a concept of its own, [TYPE: ?x], coreferent with the outer one -- what
;;  the linear form would say.
;;
;;  The first concept becomes the head: FORMAT-CGIF writes the head first.
;;
;;  @every comes in as the universal quantifier. What :LOSSLESS export writes
;;  in cgraph's own notation -- @past and the other @ words, measures, sets,
;;  the indexical # -- goes to the concept reader as written, and an id
;;  written as the constant "#12" comes in as the id #12. Import reads all of
;;  it whatever mode wrote it.
;;
;;  Not yet read, and refused with a CGRAPH-PARSE-ERROR saying so: concepts
;;  without a type (core CGIF), Equiv/Iff, actors, and a text that is more
;;  than one connected graph (READ-CGIF-GRAPHS, step 5, will read those).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(export '(parse-cgif) :conceptual-graphs)

;;; --- Reading the text ------------------------------------------------------

(defstruct (cgif-concept (:conc-name cgif-concept-))
  start          ; where its [ (or ~) is
  type           ; the type label, as a string
  names          ; constants in it, as written ("Tom", "\"St. Louis\"")
  ids            ; individual ids in it, written as constants: "\"#12\""
  extras         ; linear-form text for the rest: "@every", "@past", "#",
                 ; a measure "@80 kg", a set "{Fido, Spot}"
  defines        ; the label it defines (*x), lower case, or NIL
  binds          ; the label it refers back to (?x), lower case, or NIL
  negated        ; true for ~[...], If, Then, Either, Or
  context        ; true when it holds a graph
  concepts       ; the inner concepts, when it does
  relations      ; and the inner relations
  frame          ; the context it is in (a CGIF-FRAME)
  node)          ; the concept made from it

(defstruct (cgif-relation (:conc-name cgif-relation-))
  start          ; where its ( is
  type           ; the relation label, as a string
  arguments      ; ((kind text position) ...), KIND :label or :constant
  frame)

(defstruct (cgif-frame (:conc-name cgif-frame-))
  "One context of the text: the top level, or what a context concept holds."
  parent
  (made (make-hash-table :test 'equal)))  ; label/constant -> concept made here

(defvar *cgif-text* nil "The text PARSE-CGIF is reading.")

(defun cgif-fail (position control &rest arguments)
  (error 'cgraph-parse-error
         :string *cgif-text*
         :position position
         :message (apply #'format nil control arguments)))

(defun cgif-scanner (text)
  "A closure over TEXT that hands out the pieces of it, for the reader below:
   (funcall s :peek), (funcall s :next), (funcall s :position) and
   (funcall s :skip), which skips white space and /* */ comments."
  (let ((i 0) (n (length text)))
    (lambda (op)
      (ecase op
        (:position i)
        (:peek (and (< i n) (char text i)))
        (:next (prog1 (and (< i n) (char text i)) (incf i)))
        (:skip
         (loop
           (cond ((>= i n) (return))
                 ((member (char text i) '(#\Space #\Tab #\Newline #\Return #\Page))
                  (incf i))
                 ((and (char= (char text i) #\/) (< (1+ i) n) (char= (char text (1+ i)) #\*))
                  (let ((end (search "*/" text :start2 (+ i 2))))
                    (unless end (cgif-fail i "this comment has no closing */"))
                    (setf i (+ end 2))))
                 (t (return)))))))))

(defun cgif-name-char-p (c)
  (or (alphanumericp c) (char= c #\_)))

(defun cgif-read-name (s)
  "A name at the scanner: an identifier or numeral, or a double-quoted name
   with its quotes. NIL when there is none here."
  (let ((c (funcall s :peek)))
    (cond ((null c) nil)
          ((char= c #\")
           (let ((start (funcall s :position)))
             (with-output-to-string (out)
               (write-char (funcall s :next) out)
               (loop (let ((d (funcall s :next)))
                       (cond ((null d) (cgif-fail start "this name has no closing \""))
                             ((char= d #\\)
                              (write-char d out)
                              (let ((e (funcall s :next)))
                                (when e (write-char e out))))
                             (t (write-char d out)
                                (when (char= d #\") (return)))))))))
          ((cgif-name-char-p c)
           (with-output-to-string (out)
             (loop while (and (funcall s :peek) (cgif-name-char-p (funcall s :peek)))
                   do (write-char (funcall s :next) out))))
          (t nil))))

(defun cgif-unquote (name)
  "NAME without its double quotes, for a type or relation label."
  (if (and (>= (length name) 2) (char= (char name 0) #\"))
      (subseq name 1 (1- (length name)))
      name))

(defun cgif-not-yet (position what)
  (cgif-fail position "~a isn't supported in CGIF import yet" what))

(defun cgif-read-label (s)
  "After * or ?, the label name, lower case."
  (let ((position (funcall s :position))
        (name (cgif-read-name s)))
    (unless (and name (cgif-identifier-p name))
      (cgif-fail position "a coreference label needs a name after it, as in *x or ?x"))
    (string-downcase name)))

(defparameter *cgif-negation-types* '("IF" "THEN" "EITHER" "OR")
  "Type labels that make a context a negation, by the standard's definition:
   [If: A [Then: B]] is ~[A ~[B]], [Either: [Or: A] [Or: B]] is ~[~[A] ~[B]].")

(defun cgif-start-of-graph-p (c)
  (member c '(#\[ #\~ #\()))

(defun cgif-read-concept (s frame &optional negated (start (funcall s :position)))
  "A concept, the scanner at its [. NEGATED for one read after a ~, whose
   position is START."
  (funcall s :next)                     ; [
  (funcall s :skip)
  (let ((concept (make-cgif-concept :start start :negated negated :frame frame))
        (c (funcall s :peek)))
    (cond ((null c) (cgif-fail start "this concept has no closing ]"))
          ;; A context with no type: [ [Cat] ... ] or ~[ ... ].
          ((cgif-start-of-graph-p c)
           (setf (cgif-concept-type concept) "PROPOSITION")
           (cgif-read-inner s concept)
           (return-from cgif-read-concept concept))
          ((member c '(#\* #\? #\:))
           (cgif-not-yet start "A concept with no type (core CGIF)")))
    (let* ((type-position (funcall s :position))
           (type (cgif-read-name s)))
      (unless type
        (cgif-fail type-position "a concept starts with its type, as in [Cat] or [Cat: Tom]"))
      (setf type (cgif-unquote type))
      (cond ((member (string-upcase type) *cgif-negation-types* :test #'string=)
             (when negated
               (cgif-fail start "~~[~a: ...] is a negation twice over: ~a is already one" type type))
             (setf (cgif-concept-negated concept) t
                   (cgif-concept-type concept) "PROPOSITION"))
            ((member (string-upcase type) '("EQUIV" "IFF") :test #'string=)
             (cgif-not-yet start type))
            (t (setf (cgif-concept-type concept) type))))
    (funcall s :skip)
    (when (eql (funcall s :peek) #\:) (funcall s :next))
    (loop
      (funcall s :skip)
      (let ((c (funcall s :peek))
            (position (funcall s :position)))
        (cond ((null c) (cgif-fail start "this concept has no closing ]"))
              ((char= c #\]) (funcall s :next) (return))
              ((char= c #\;)
               ;; an end comment, up to the ]
               (loop until (member (funcall s :peek) '(#\] nil)) do (funcall s :next)))
              ((char= c #\*)
               (funcall s :next)
               (when (cgif-concept-defines concept)
                 (cgif-fail position "a concept defines one label, and this one already defines *~a"
                            (cgif-concept-defines concept)))
               (setf (cgif-concept-defines concept) (cgif-read-label s)))
              ((char= c #\?)
               (funcall s :next)
               (setf (cgif-concept-binds concept) (cgif-read-label s)))
              ((char= c #\@)
               (setf (cgif-concept-extras concept)
                     (append (cgif-concept-extras concept) (list (cgif-read-at s)))))
              ((char= c #\{)
               (setf (cgif-concept-extras concept)
                     (append (cgif-concept-extras concept) (list (cgif-read-set s)))))
              ((char= c #\#)
               ;; the indexical #, as :lossless writes it (and #12 bare)
               (setf (cgif-concept-extras concept)
                     (append (cgif-concept-extras concept)
                             (list (with-output-to-string (out)
                                     (write-char (funcall s :next) out)
                                     (loop while (and (funcall s :peek) (digit-char-p (funcall s :peek)))
                                           do (write-char (funcall s :next) out)))))))
              ((cgif-start-of-graph-p c)
               ;; The rest of the concept is the graph it holds.
               (cgif-read-inner s concept)
               (return))
              (t (let ((name (cgif-read-name s)))
                   (unless name
                     (cgif-fail position "~a can't be in a concept: a concept holds its type, ~
                                          then names and *x or ?x labels, then any graph" c))
                   ;; "#12" is how an individual's id is written as a constant.
                   (if (cgif-id-name-p name)
                       (setf (cgif-concept-ids concept)
                             (append (cgif-concept-ids concept) (list name)))
                       (setf (cgif-concept-names concept)
                             (append (cgif-concept-names concept) (list name)))))))))
    (when (and (cgif-concept-negated concept) (not (cgif-concept-context concept)))
      (cgif-fail start "a negation holds a graph, as in ~~[[Cat]] or [If: [Cat] [Then: ...]]: ~
                        not ~~[Cat], and not an empty one"))
    concept))

(defun cgif-id-name-p (name)
  "True for a quoted name that is an individual id, \"#12\"."
  (let ((inner (cgif-unquote name)))
    (and (char= (char name 0) #\")
         (> (length inner) 1)
         (char= (char inner 0) #\#)
         (every #'digit-char-p (subseq inner 1)))))

(defun cgif-read-at (s)
  "An @ word or measure, the scanner at its @, as linear-form text: @every,
   @past-progressive, @80 kg, @5."
  (with-output-to-string (out)
    (write-char (funcall s :next) out)  ; @
    (loop while (eql (funcall s :peek) #\Space) do (funcall s :next))
    (let ((c (funcall s :peek)))
      (cond ((and c (alpha-char-p c))
             (loop while (and (funcall s :peek)
                              (or (alphanumericp (funcall s :peek)) (char= (funcall s :peek) #\-)))
                   do (write-char (funcall s :next) out)))
            ((and c (digit-char-p c))
             (loop while (and (funcall s :peek)
                              (or (digit-char-p (funcall s :peek)) (char= (funcall s :peek) #\.)))
                   do (write-char (funcall s :next) out))
             ;; a unit, if one follows: 80 kg, 5 ft.
             (let ((after (funcall s :position)))
               (declare (ignore after))
               (loop while (eql (funcall s :peek) #\Space) do (funcall s :next))
               (when (and (funcall s :peek) (alpha-char-p (funcall s :peek)))
                 (write-char #\Space out)
                 (loop while (and (funcall s :peek)
                                  (or (alphanumericp (funcall s :peek)) (char= (funcall s :peek) #\.)))
                       do (write-char (funcall s :next) out)))))
            (t (cgif-fail (funcall s :position) "@ needs a word or a number after it"))))))

(defun cgif-read-set (s)
  "A set referent, the scanner at its {, as linear-form text up to the }."
  (let ((start (funcall s :position)))
    (with-output-to-string (out)
      (loop (let ((c (funcall s :next)))
              (cond ((null c) (cgif-fail start "this set has no closing }"))
                    (t (write-char c out)
                       (when (char= c #\}) (return)))))))))

(defun cgif-read-inner (s concept)
  "The graph CONCEPT holds, up to and including the ] that closes CONCEPT."
  (let ((frame (make-cgif-frame :parent (cgif-concept-frame concept))))
    (multiple-value-bind (concepts relations) (cgif-read-items s frame #\])
      (setf (cgif-concept-context concept) t
            (cgif-concept-concepts concept) concepts
            (cgif-concept-relations concept) relations))
    (when (or (cgif-concept-names concept) (cgif-concept-binds concept))
      (cgif-not-yet (cgif-concept-start concept)
                    "A concept holding a graph that also has a name or a ?x label"))
    (unless (cgif-concept-concepts concept)
      (cgif-fail (cgif-concept-start concept) "this context holds no concept"))))

(defun cgif-read-relation (s frame)
  "A relation, the scanner at its (."
  (let ((start (funcall s :position)))
    (funcall s :next)                   ; (
    (funcall s :skip)
    (let* ((type-position (funcall s :position))
           (type (cgif-read-name s))
           (relation (make-cgif-relation :start start :frame frame
                                         :type (and type (cgif-unquote type)))))
      (unless type
        (cgif-fail type-position "a relation starts with its name, as in (Agnt ?x ?y)"))
      (loop
        (funcall s :skip)
        (let ((c (funcall s :peek))
              (position (funcall s :position)))
          (cond ((null c) (cgif-fail start "this relation has no closing )"))
                ((char= c #\)) (funcall s :next) (return))
                ((char= c #\;)
                 (loop until (member (funcall s :peek) '(#\) nil)) do (funcall s :next)))
                ((char= c #\|) (cgif-not-yet position "An actor (a relation with |)"))
                ((char= c #\[) (cgif-not-yet position "A concept as a relation's argument"))
                ((char= c #\?)
                 (funcall s :next)
                 (push (list :label (cgif-read-label s) position)
                       (cgif-relation-arguments relation)))
                ((char= c #\*)
                 (cgif-fail position "a relation refers to a label with ?, not *: ?~a"
                            (progn (funcall s :next) (cgif-read-label s))))
                (t (let ((name (cgif-read-name s)))
                     (unless name
                       (cgif-fail position "~a can't be a relation's argument: use a ?x label or a name" c))
                     (push (list :constant name position)
                           (cgif-relation-arguments relation)))))))
      (setf (cgif-relation-arguments relation) (nreverse (cgif-relation-arguments relation)))
      (when (< (length (cgif-relation-arguments relation)) 2)
        (cgif-fail start "the relation ~a needs at least two arguments" (cgif-relation-type relation)))
      relation)))

(defun cgif-read-items (s frame closer)
  "Concepts and relations up to CLOSER (a character, consumed) or the end of
   the text (CLOSER NIL), as two lists, in order."
  (let ((concepts '())
        (relations '()))
    (loop
      (funcall s :skip)
      (let ((c (funcall s :peek))
            (position (funcall s :position)))
        (cond ((null c)
               (when closer (cgif-fail position "a context has no closing ]"))
               (return))
              ((and closer (char= c closer)) (funcall s :next) (return))
              ((char= c #\[) (push (cgif-read-concept s frame) concepts))
              ((char= c #\() (push (cgif-read-relation s frame) relations))
              ((char= c #\~)
               (funcall s :next)
               (funcall s :skip)
               (unless (eql (funcall s :peek) #\[)
                 (cgif-fail position "~~ negates a context: ~~[ ... ]"))
               (push (cgif-read-concept s frame t position) concepts))
              (t (cgif-fail position "expected a concept [...] or a relation (...) here")))))
    (values (nreverse concepts) (nreverse relations))))

;;; --- Labels ----------------------------------------------------------------

(defun cgif-walk (concepts fn)
  "Call FN on every concept in CONCEPTS and in the contexts they hold."
  (dolist (c concepts)
    (funcall fn c)
    (when (cgif-concept-context c)
      (cgif-walk (cgif-concept-concepts c) fn))))

(defun cgif-walk-relations (concepts relations fn)
  (dolist (r relations) (funcall fn r))
  (dolist (c concepts)
    (when (cgif-concept-context c)
      (cgif-walk-relations (cgif-concept-concepts c) (cgif-concept-relations c) fn))))

(defun cgif-local-concept (label frame concepts)
  "The concept in FRAME, among CONCEPTS, that a relation there means by ?LABEL:
   the one defining *LABEL, else one carrying ?LABEL. NIL when neither is in
   FRAME."
  (let ((here (remove-if-not (lambda (c) (eq (cgif-concept-frame c) frame)) concepts)))
    (or (find label here :key #'cgif-concept-defines :test #'equal)
        (find label here :key #'cgif-concept-binds :test #'equal))))

(defun cgif-check-labels (concepts relations)
  "Each label defined once and every ?x defined. Returns the definitions, a
   hash table from label to the concept defining it, and the labels to keep
   on the concepts that define them: those another concept refers to, and
   those a relation in another context refers to (which gets a coreferent
   concept of its own there)."
  (let ((definitions (make-hash-table :test 'equal))
        (keep '())
        (all '()))
    (cgif-walk concepts
               (lambda (c)
                 (push c all)
                 (let ((d (cgif-concept-defines c)))
                   (when d
                     (when (gethash d definitions)
                       (cgif-fail (cgif-concept-start c) "*~a is defined twice" d))
                     (setf (gethash d definitions) c)))))
    (dolist (c all)
      (let ((b (cgif-concept-binds c)))
        (when b
          (unless (gethash b definitions)
            (cgif-fail (cgif-concept-start c) "?~a refers to *~a, which no concept defines" b b))
          (pushnew b keep :test #'string=))))
    (cgif-walk-relations
     concepts relations
     (lambda (r)
       (loop for (kind text position) in (cgif-relation-arguments r)
             when (eq kind :label)
               do (unless (gethash text definitions)
                    (cgif-fail position "?~a refers to *~a, which no concept defines" text text))
                  (unless (cgif-local-concept text (cgif-relation-frame r) all)
                    (when (cgif-concept-context (gethash text definitions))
                      (cgif-not-yet position
                                    "A relation naming a context from outside it"))
                    (pushnew text keep :test #'string=)))))
    (values definitions keep all)))

;;; --- Building the nodes ----------------------------------------------------

(defun cgif-read-node (lf position)
  "The concept or relation the linear-form token LF reads as, in the current
   reading session. An error in it is reported at POSITION in the CGIF text."
  (handler-case
      (let* ((stream (make-string-input-stream lf))
             (*parse-stream* stream)
             (*node-start* nil))
        (find-if #'graph-node-p (read-cgraph-tokens stream)))
    (cgraph-parse-error (e) (cgif-fail position "~a" (parse-error-message e)))
    (error (e) (cgif-fail position "~a" (parse-cause-message e)))))

(defun cgif-concept-lf (concept keep-labels)
  "CONCEPT, a plain one, as a linear-form concept token: its type, its names,
   and the labels in KEEP-LABELS."
  (let ((parts (append (cgif-concept-names concept)
                       (mapcar #'cgif-unquote (cgif-concept-ids concept))
                       (cgif-concept-extras concept)
                       (let ((d (cgif-concept-defines concept)))
                         (and d (member d keep-labels :test #'string=)
                              (list (format nil "*~a" d))))
                       (let ((b (cgif-concept-binds concept)))
                         (and b (list (format nil "?~a" b)))))))
    (format nil "[~a~@[: ~{~a~^ ~}~]]" (cgif-concept-type concept) parts)))

(defun cgif-signature-type (relation-node index count)
  "The type a relation allows at argument INDEX of COUNT: the destination
   type for the last, the first source type for the others."
  (let ((rtype (relation-type relation-node)))
    (if (= index (1- count))
        (label (dest-type rtype))
        (let ((source (first (source-types rtype))))
          (if (typep source 'concept-type) (label source) source)))))

(defstruct (cgif-session (:conc-name cgif-session-))
  definitions keep all)

(defun cgif-build-context-concept (c session)
  "The concept for C, which holds a graph: built as READ-GRAPH-REFERENT-CONCEPT
   builds one."
  (let ((ctype (handler-case (get-concept-type (type-label-symbol (cgif-concept-type c)))
                 (error (e) (cgif-fail (cgif-concept-start c) "~a" (parse-cause-message e))))))
    ;; *IN-GRAPH-REFERENT* stays NIL: it tells the reader a ] ends the graph
    ;; it is reading, and here each concept is read on its own.
    (let* ((*concepts-in-graph* (list))
           (*context* (make-context *context* :negated (cgif-concept-negated c)))
           (*negated-concept* nil)
           (nodes (cgif-build-level (cgif-concept-concepts c) (cgif-concept-relations c)
                                    session :inner t))
           (graph (make-cgraph nodes))
           (concept (make-concept ctype (make-referent graph nil))))
      (when (cgif-concept-negated c)
        (setf (negated concept) t))
      concept)))

(defun cgif-build-level (concepts relations session &key inner)
  "Make the nodes of one context: CONCEPTS and RELATIONS, the head first.
   INNER for a context's contents, where nested contexts may stand apart."
  (let ((made '())
        (relation-nodes '())
        (keep (cgif-session-keep session))
        (definitions (cgif-session-definitions session)))
    (dolist (c concepts)
      (setf (cgif-concept-node c)
            (if (cgif-concept-context c)
                (cgif-build-context-concept c session)
                (cgif-read-node (cgif-concept-lf c keep) (cgif-concept-start c)))))
    (flet ((made-here (key frame lf position)
             ;; A concept made for this context: one per label or constant.
             (or (gethash key (cgif-frame-made frame))
                 (let ((new (cgif-read-node lf position)))
                   (push new made)
                   (setf (gethash key (cgif-frame-made frame)) new)))))
      (dolist (r relations)
        (let* ((frame (cgif-relation-frame r))
               (node (cgif-read-node (format nil "(~a)" (cgif-relation-type r))
                                     (cgif-relation-start r)))
               (arguments (cgif-relation-arguments r))
               (count (length arguments)))
          (loop for (kind text position) in arguments
                for index from 0
                for concept
                  = (ecase kind
                      (:label
                       (let ((local (cgif-local-concept text frame (cgif-session-all session))))
                         (if local
                             (cgif-concept-node local)
                             ;; Defined outside this context: a coreferent
                             ;; concept here, as linear form would have it.
                             (made-here (format nil "?~a" text) frame
                                        (format nil "[~a: ?~a]"
                                                (cgif-concept-type (gethash text definitions))
                                                text)
                                        position))))
                      (:constant
                       (let ((c (find-if (lambda (c)
                                           (or (member text (cgif-concept-names c) :test #'string=)
                                               (member text (cgif-concept-ids c) :test #'string=)))
                                         concepts)))
                         (if c
                             (cgif-concept-node c)
                             ;; A constant no concept names, as (Agnt ?x Bob)
                             ;; with no [Person: Bob]: a concept of the type
                             ;; the relation allows there.
                             (made-here text frame
                                        (format nil "[~a: ~a]"
                                                (cgif-signature-type node index count) text)
                                        position)))))
                do (handler-case
                       (if (= index (1- count))
                           (connect node :right concept)
                           (connect concept :right node))
                     (error (e) (cgif-fail (cgif-relation-start r) "~a" (parse-cause-message e)))))
          (push node relation-nodes))))
    (let ((concept-nodes (append (mapcar #'cgif-concept-node concepts) (reverse made))))
      (cgif-check-connected concept-nodes concepts inner)
      (append concept-nodes (nreverse relation-nodes)))))

(defun cgif-check-connected (concept-nodes concepts inner)
  "Signal unless every concept is reachable from the first along relations:
   a cgraph graph is what can be reached from its head. In a context's
   contents (INNER), a nested context may stand apart -- that is how cgraph
   holds ~[A ~[B]]."
  (when (rest concept-nodes)
    (let ((seen (make-hash-table :test 'eq))
          (agenda (list (first concept-nodes))))
      (loop while agenda
            do (let ((c (pop agenda)))
                 (unless (gethash c seen)
                   (setf (gethash c seen) t)
                   (dolist (r (arcs c))
                     (dolist (other (arcs r))
                       (push other agenda))))))
      (let ((stray (find-if (lambda (c)
                              (and (not (gethash c seen))
                                   (not (and inner (graph-referent c)))))
                            concept-nodes)))
        (when stray
          (let ((cgif (find stray concepts :key #'cgif-concept-node)))
            (cgif-fail (if cgif (cgif-concept-start cgif) 0)
                       "~a isn't connected to ~a: ~:[PARSE-CGIF reads one connected graph~;~
                        inside a context, only another context may stand apart~]"
                       (format-node stray) (format-node (first concept-nodes)) inner)))))))

;;; --- Entry point -----------------------------------------------------------

(defun parse-cgif (text)
  "Read TEXT, extended CGIF, and return its nodes, the head (its first
   concept) first -- what PARSE-CGRAPH returns for linear form, so
   (make-cgraph (parse-cgif text)) makes a graph of it. Signals
   CGRAPH-PARSE-ERROR, pointing into TEXT, on anything it can't read. See
   notes/cgif.md."
  (let ((*cgif-text* text)
        (frame (make-cgif-frame)))
    (multiple-value-bind (concepts relations)
        (cgif-read-items (cgif-scanner text) frame nil)
      (unless concepts
        (cgif-fail 0 "there is no concept in it"))
      (multiple-value-bind (definitions keep all) (cgif-check-labels concepts relations)
        ;; One reading session for the whole text, as CGRAPH-TOKENS makes one
        ;; for a linear-form string, so a ?x finds the *x of an earlier concept.
        (initialize-variables)
        (initialize-coreferences)
        (let ((*concepts-in-graph* (list))
              (*in-graph-referent* nil)
              (*negated-concept* nil)
              (*parse-string* nil)
              (*token-positions* (make-hash-table :test #'eq))
              (*package* (find-package :conceptual-graphs)))
          (cgif-build-level concepts relations
                            (make-cgif-session :definitions definitions :keep keep :all all)))))))
