;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  CGIF import: extended CGIF text to cgraph nodes, the part of it cgraph's
;;  graphs use. notes/cgif.md has the design.
;;
;;    [CAT: Tom] [EAT: *x1] [FOOD: *x2] (agnt ?x1 Tom) (obj ?x1 ?x2)
;;      => the nodes of [CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]
;;
;;  The text is split into concepts and relations here. Each concept is then
;;  handed to cgraph's own concept reader, as linear form, inside one reading
;;  session -- so names, individuals and *x/?x coreference behave exactly as
;;  they do for PARSE-CGRAPH -- and the relations are connected afterwards.
;;
;;  Labels. In CGIF a relation names its arguments by label, so nearly every
;;  concept in a CGIF text has one: [Drive *x] (Agnt ?x Bob). A label that
;;  only relation arguments refer to is wiring, and is not kept: cgraph
;;  connects the relation to the concept instead, and the concept comes in
;;  without a label. A label that another CONCEPT refers to, [Person: ?x], is
;;  coreference between two concepts, which cgraph represents with the same
;;  *x/?x, so it is kept.
;;
;;  The first concept becomes the head: FORMAT-CGIF writes the head first.
;;
;;  Not yet read, and refused with a CGRAPH-PARSE-ERROR saying so: contexts,
;;  negation, If/Then and Either/Or (build step 3), @every and @-words (step
;;  4), concepts without a type (core CGIF), actors, and a text that is more
;;  than one connected graph (READ-CGIF-GRAPHS, step 5, will read those).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(export '(parse-cgif) :conceptual-graphs)

;;; --- Reading the text ------------------------------------------------------

(defstruct (cgif-concept (:conc-name cgif-concept-))
  start          ; where its [ is
  type           ; the type label, as a string
  names          ; constants in it, as written ("Tom", "\"St. Louis\"")
  defines        ; the label it defines (*x), lower case, or NIL
  binds          ; the label it refers back to (?x), lower case, or NIL
  node)          ; the concept read from it

(defstruct (cgif-relation (:conc-name cgif-relation-))
  start          ; where its ( is
  type           ; the relation label, as a string
  arguments)     ; ((kind text position) ...), KIND :label or :constant

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

(defun cgif-read-concept (s)
  "A concept, the scanner at its [."
  (let ((start (funcall s :position)))
    (funcall s :next)                   ; [
    (funcall s :skip)
    (let ((c (funcall s :peek)))
      (cond ((null c) (cgif-fail start "this concept has no closing ]"))
            ((member c '(#\[ #\~))
             (cgif-not-yet start "A context (a concept holding a graph)"))
            ((member c '(#\* #\? #\:))
             (cgif-not-yet start "A concept with no type (core CGIF)"))))
    (let* ((type-position (funcall s :position))
           (type (cgif-read-name s))
           (concept (make-cgif-concept :start start :type (and type (cgif-unquote type)))))
      (unless type
        (cgif-fail type-position "a concept starts with its type, as in [Cat] or [Cat: Tom]"))
      (when (member (string-upcase (cgif-concept-type concept))
                    '("IF" "THEN" "EITHER" "OR" "EQUIV" "IFF") :test #'string=)
        (cgif-not-yet start (format nil "~a" (cgif-concept-type concept))))
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
                ((char= c #\@) (cgif-not-yet position "@every, or another @ word,"))
                ((member c '(#\[ #\~ #\())
                 (cgif-not-yet position "A graph inside a concept"))
                (t (let ((name (cgif-read-name s)))
                     (unless name
                       (cgif-fail position "~a can't be in a concept: a concept holds its type, ~
                                            then names and *x or ?x labels" c))
                     (setf (cgif-concept-names concept)
                           (append (cgif-concept-names concept) (list name))))))))
      concept)))

(defun cgif-read-relation (s)
  "A relation, the scanner at its (."
  (let ((start (funcall s :position)))
    (funcall s :next)                   ; (
    (funcall s :skip)
    (let* ((type-position (funcall s :position))
           (type (cgif-read-name s))
           (relation (make-cgif-relation :start start :type (and type (cgif-unquote type)))))
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

(defun cgif-read-text (text)
  "TEXT's concepts and relations, as two lists of structures, in order."
  (let ((s (cgif-scanner text))
        (concepts '())
        (relations '()))
    (loop
      (funcall s :skip)
      (let ((c (funcall s :peek))
            (position (funcall s :position)))
        (cond ((null c) (return))
              ((char= c #\[) (push (cgif-read-concept s) concepts))
              ((char= c #\() (push (cgif-read-relation s) relations))
              ((char= c #\~) (cgif-not-yet position "Negation"))
              (t (cgif-fail position "expected a concept [...] or a relation (...) here")))))
    (values (nreverse concepts) (nreverse relations))))

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
  "CONCEPT as a linear-form concept token: its type, its names, and the labels
   in KEEP-LABELS."
  (let ((parts (append (cgif-concept-names concept)
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

(defun cgif-build (concepts relations)
  "Read CONCEPTS and RELATIONS into nodes. Returns the node list."
  (let* ((by-label (make-hash-table :test 'equal))
         (coreferred (remove-duplicates
                      (remove nil (mapcar #'cgif-concept-binds concepts))
                      :test #'string=))
         (made '())                     ; concepts made for a bare constant
         (relation-nodes '()))
    ;; Each label is defined once.
    (dolist (c concepts)
      (let ((d (cgif-concept-defines c)))
        (when d
          (when (gethash d by-label)
            (cgif-fail (cgif-concept-start c) "*~a is defined twice" d))
          (setf (gethash d by-label) c))))
    ;; A ?x in a concept must have its *x.
    (dolist (c concepts)
      (let ((b (cgif-concept-binds c)))
        (when (and b (not (gethash b by-label)))
          (cgif-fail (cgif-concept-start c) "?~a refers to *~a, which no concept defines" b b))))
    ;; The concepts, through cgraph's reader.
    (dolist (c concepts)
      (setf (cgif-concept-node c)
            (cgif-read-node (cgif-concept-lf c coreferred) (cgif-concept-start c))))
    ;; The relations.
    (dolist (r relations)
      (let* ((node (cgif-read-node (format nil "(~a)" (cgif-relation-type r))
                                   (cgif-relation-start r)))
             (arguments (cgif-relation-arguments r))
             (count (length arguments)))
        (loop for (kind text position) in arguments
              for index from 0
              for concept
                = (ecase kind
                    (:label
                     (let ((c (gethash text by-label)))
                       (unless c
                         (cgif-fail position "?~a refers to *~a, which no concept defines" text text))
                       (cgif-concept-node c)))
                    (:constant
                     (let ((c (find text concepts :key #'cgif-concept-names
                                                  :test (lambda (name names)
                                                          (member name names :test #'string=)))))
                       (if c
                           (cgif-concept-node c)
                           ;; A constant no concept names, as (Agnt ?x Bob)
                           ;; with no [Person: Bob]: a concept of the type the
                           ;; relation allows there.
                           (let ((entry (assoc text made :test #'string=)))
                             (or (cdr entry)
                                 (let ((new (cgif-read-node
                                             (format nil "[~a: ~a]"
                                                     (cgif-signature-type node index count) text)
                                             position)))
                                   (push (cons text new) made)
                                   new)))))))
              do (handler-case
                     (if (= index (1- count))
                         (connect node :right concept)
                         (connect concept :right node))
                   (error (e) (cgif-fail (cgif-relation-start r) "~a" (parse-cause-message e)))))
        (push node relation-nodes)))
    (let ((concept-nodes (append (mapcar #'cgif-concept-node concepts)
                                 (reverse (mapcar #'cdr made)))))
      (cgif-check-connected concept-nodes concepts)
      (append concept-nodes (nreverse relation-nodes)))))

(defun cgif-check-connected (concept-nodes concepts)
  "Signal unless every concept is reachable from the first along relations
   and coreference: a cgraph graph is what can be reached from its head."
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
      (let ((stray (find-if-not (lambda (c) (gethash c seen)) concept-nodes)))
        (when stray
          (let ((cgif (find stray concepts :key #'cgif-concept-node)))
            (cgif-fail (if cgif (cgif-concept-start cgif) 0)
                       "~a isn't connected to ~a: PARSE-CGIF reads one connected graph"
                       (format-node stray) (format-node (first concept-nodes)))))))))

;;; --- Entry point -----------------------------------------------------------

(defun parse-cgif (text)
  "Read TEXT, extended CGIF, and return its nodes, the head (its first
   concept) first -- what PARSE-CGRAPH returns for linear form, so
   (make-cgraph (parse-cgif text)) makes a graph of it. Signals
   CGRAPH-PARSE-ERROR, pointing into TEXT, on anything it can't read. See
   notes/cgif.md."
  (let ((*cgif-text* text))
    (multiple-value-bind (concepts relations) (cgif-read-text text)
      (unless concepts
        (cgif-fail 0 "there is no concept in it"))
      ;; One reading session for the whole text, as CGRAPH-TOKENS makes one
      ;; for a linear-form string, so a ?x finds the *x of an earlier concept.
      (initialize-variables)
      (initialize-coreferences)
      (let ((*concepts-in-graph* (list))
            (*in-graph-referent* nil)
            (*parse-string* nil)
            (*token-positions* (make-hash-table :test #'eq))
            (*package* (find-package :conceptual-graphs)))
        (cgif-build concepts relations)))))
