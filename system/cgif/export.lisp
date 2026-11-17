;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  CGIF export: a graph as the Conceptual Graph Interchange Format of
;;  ISO/IEC 24707 Annex B, extended CGIF, the part cgraph's graphs use.
;;  The design, and what is still to come, is notes/cgif.md.
;;
;;    [CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]
;;      => [CAT: Tom] [EAT: *x1] [FOOD: *x2] (agnt ?x1 Tom) (obj ?x1 ?x2)
;;
;;  Concepts come first, the graph's head first among them, since CGIF has no
;;  head and the first concept is where an import will put it back. Then the
;;  relations, each with its source arcs first and its destination last --
;;  CGIF's own usage, (Agnt ?act Bob).
;;
;;  A relation names its arguments by coreference label or by constant, so a
;;  concept with relations needs one or the other. A named concept is referred
;;  to by its name, if no other concept has that name. A concept that already
;;  has a label keeps it -- *x defining,
;;  ?x bound, as cgraph writes them. Any other concept with relations gets a
;;  fresh *x1, *x2, ..., skipping labels the graph already uses.
;;
;;  Not yet written, and refused with CGIF-UNSUPPORTED rather than dropped:
;;  nested graphs, negation, sets, measures, individual ids without a name, and
;;  the @-words other than @some. Each is a row of the note's "No standard CGIF
;;  form" table, or one of its contexts, and gets its CGIF form in a later step.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(export '(format-cgif write-cgif-graphs cgif-unsupported cgif-dropped) :conceptual-graphs)

;;; --- Modes -----------------------------------------------------------------
;;;
;;; Some of what a cgraph concept says has no standard CGIF form
;;; (notes/cgif.md, "No standard CGIF form"). FORMAT-CGIF's :MODE decides
;;; what becomes of it:
;;;
;;;   :portable  standard extended CGIF any tool can read (the default). What
;;;              has no logical meaning is dropped -- @some quietly, the
;;;              indexical # and @past and the like with a CGIF-DROPPED
;;;              warning -- and what can't be said is refused: sets,
;;;              measures, quantifiers other than @every and @some.
;;;   :strict    refuses whatever :portable would drop, too.
;;;   :lossless  cgraph's own notation in the referent field for all of it,
;;;              so a graph comes back from CGIF exactly as it went out.
;;;              Another tool may misread those parts, which is why it is
;;;              not the default.
;;;
;;; Every mode writes @every (standard), and an individual's id as the
;;; quoted name "#12" (a constant, which is what an id is) wherever the linear
;;; form writes an id. A named individual is written by its name alone, as
;;; the linear form writes it.

(defvar *cgif-mode* :portable
  "The mode FORMAT-CGIF is writing in: :PORTABLE, :STRICT or :LOSSLESS.")

(define-condition cgif-unsupported (error)
  ((concept :initarg :concept :reader cgif-unsupported-concept)
   (feature :initarg :feature :reader cgif-unsupported-feature)
   (mode    :initarg :mode    :initform nil :reader cgif-unsupported-mode))
  (:report (lambda (condition stream)
             (let ((mode (cgif-unsupported-mode condition)))
               (format stream "Can't write ~a as ~@[~(~a~) ~]CGIF: ~a ~
                               ~:[has no CGIF form~;has no standard CGIF form~@[; ~
                               :mode :lossless writes it in cgraph's notation~]~]"
                       (format-node (cgif-unsupported-concept condition))
                       mode
                       (cgif-unsupported-feature condition)
                       mode
                       (and mode (not (eq mode :lossless)) t))))))

(define-condition cgif-dropped (warning)
  ((concept :initarg :concept :reader cgif-dropped-concept)
   (feature :initarg :feature :reader cgif-dropped-feature))
  (:report (lambda (condition stream)
             (format stream "Writing ~a as CGIF left out ~a, which standard CGIF ~
                             can't say; :mode :lossless keeps it"
                     (format-node (cgif-dropped-concept condition))
                     (cgif-dropped-feature condition)))))

;;; --- Names ---------------------------------------------------------------

(defun cgif-identifier-p (string)
  "True when STRING can be written unquoted: a letter, then letters, digits
   and underscores. Unicode letters count; CGIF allows them in names. A hyphen
   does not, so CHEVY-VEHICLE and life-stage are written quoted."
  (and (plusp (length string))
       (alpha-char-p (char string 0))
       (every (lambda (c) (or (alphanumericp c) (char= c #\_))) string)))

(defun cgif-name (string)
  "STRING as a CGIF name: bare when it is an identifier, else double-quoted.
   A name cgraph stored with its quotes ([CITY: \"St. Louis\"] keeps them) is
   already in that form and is written as it is."
  (cond ((cgif-identifier-p string) string)
        ((and (>= (length string) 2)
              (char= (char string 0) #\")
              (char= (char string (1- (length string))) #\"))
         string)
        (t (with-output-to-string (out)
             (write-char #\" out)
             (loop for c across string
                   do (when (member c '(#\" #\\)) (write-char #\\ out))
                      (write-char c out))
             (write-char #\" out)))))

(defun cgif-type-name (concept)
  (cgif-name (princ-to-string (label (concept-type concept)))))

(defun cgif-relation-name (relation)
  (cgif-name (string-downcase (princ-to-string (label (relation-type relation))))))

;;; --- What a concept says -------------------------------------------------

(defun cgif-concept-name (concept)
  "CONCEPT's individual's name, or NIL."
  (let ((name (ignore-errors (referent-name concept))))
    (and (stringp name) (plusp (length name)) name)))

(defun cgif-universal-p (concept)
  (eq (concept-quantifier concept) :universal))

(defun cgif-extras-for (concept)
  "What goes in CONCEPT's referent field besides its name and labels, as a
   list of strings, for *CGIF-MODE*. Signals CGIF-UNSUPPORTED for what the
   mode can't write and warns CGIF-DROPPED for what :PORTABLE leaves out."
  (let* ((mode *cgif-mode*)
         (lossless (eq mode :lossless))
         (referent (referent concept))
         (content  (and referent (content referent)))
         (extras '())
         (*concise* nil))
    (labels ((refuse (feature &optional (in-mode mode))
               (error 'cgif-unsupported :concept concept :feature feature :mode in-mode))
             (keep (text) (push text extras))
             ;; Something with no logical meaning: :lossless keeps TEXT,
             ;; :strict refuses, :portable leaves it out (and says so unless
             ;; QUIETLY).
             (meaningless (feature text &optional quietly)
               (case mode
                 (:lossless (keep text))
                 (:strict (refuse feature))
                 (t (unless quietly
                      (warn 'cgif-dropped :concept concept :feature feature)))))
             ;; Something CGIF can't say: kept by :lossless, refused otherwise.
             (unsayable (feature text)
               (if lossless (keep text) (refuse feature))))
      ;; CGIF negates a context, ~[ ... ]. cgraph can also mark a concept
      ;; holding no graph, ~[CAT], which has no CGIF form in any mode.
      (when (and (negated concept) (not (graph-referent concept)))
        (refuse "a negated concept with no graph inside" nil))
      (cond ((set-p content)
             ;; Braces and any count, as cgraph writes them: {Fido, Spot}, {}@5.
             (unsayable "a set" (string-trim " " (format-referent referent))))
            ((typep content 'individual)
             ;; An id is written where the linear form writes one -- ID-TEXT
             ;; decides -- which is never beside a name: a named individual is
             ;; known by its name, and its id is the image's own numbering,
             ;; which another image would not share.
             (let ((id-text (id-text concept)))
               (cond ((string= id-text "#")
                      (meaningless "the individual marker #" "#"))
                     ((plusp (length id-text))
                      (keep (format nil "\"~a\"" id-text)))))))
      ;; A set's count is in its braces' text already.
      (unless (set-p content)
        (let ((measure (or (getf (properties concept) :measure)
                           (and referent (measure-property referent)))))
          (when measure (unsayable "a measure" (format-measure measure)))))
      (let ((quantifier (concept-quantifier concept)))
        (case quantifier
          ((nil :universal))            ; @every is written with its label
          (:existential (meaningless "@some" "@some" t))
          (t (unsayable (format nil "the quantifier @~(~a~)" quantifier)
                        (format nil "@~(~a~)" quantifier)))))
      (let ((tense (concept-tense concept))
            (aspect (concept-aspect concept))
            (voice (concept-voice concept)))
        (when (or tense aspect)
          (let ((word (cond ((and tense aspect) (format nil "@~(~a-~a~)" tense aspect))
                            (tense (format nil "@~(~a~)" tense))
                            (t (format nil "@~(~a~)" aspect)))))
            (meaningless (format nil "the annotation ~a" word) word)))
        (when voice
          (let ((word (format nil "@~(~a~)" voice)))
            (meaningless (format nil "the annotation ~a" word) word)))))
    (nreverse extras)))

(defun cgif-defining-label (concept)
  "The label CONCEPT defines (*x), as a lower-case string, or NIL."
  (let ((label (or (concept-coref-label concept) (node-variable concept))))
    (and label (string-downcase (string label)))))

(defun cgif-bound-label (concept)
  "The label CONCEPT refers back to (?x), as a lower-case string, or NIL."
  (let ((label (coref-bound-label concept)))
    (and label (string-downcase (string label)))))

;;; --- The graph -----------------------------------------------------------

(defun cgif-nodes (thing)
  "THING's concepts, head first, and its relations, as two values. THING is a
   graph, a node list as PARSE-CGRAPH returns it, or a linear-form string."
  (let* ((nodes (remove-duplicates
                 (remove-if-not #'graph-node-p
                                (etypecase thing
                                  (graph  (nodes thing))
                                  (list   thing)
                                  (string (parse-cgraph thing))))
                 ;; A node met twice -- [BOY: *z] ... [BOY: *z] is one concept
                 ;; on a cycle -- is listed twice. Keep its first place, so the
                 ;; head stays first.
                 :from-end t))
         (concepts  (remove-if-not #'concept-p nodes))
         (relations (remove-if-not #'relation-p nodes))
         (head      (and (typep thing 'graph) (head thing))))
    (when (and head (member head concepts))
      (setf concepts (cons head (remove head concepts))))
    (values concepts relations)))

(defun cgif-coreference-roles (concepts fresh)
  "A hash table from each concept in CONCEPTS that takes part in coreference
   to (ROLE . LABEL): ROLE :DEFINE for the one that writes *LABEL, :BIND for
   the ones that write ?LABEL.

   Worked out from the coreference links, not from the labels the concepts
   carry, because those can't be trusted: FORMAT-CGRAPH clears a concept's *x
   as it prints, leaving its partner's ?x pointing at nothing. Each set of
   coreferent concepts here gets one label -- one of theirs if any is left,
   else FRESH's -- defined by the concept that had it as *x, or by the first.
   A concept whose partners are all outside CONCEPTS keeps its own label."
  (let ((roles (make-hash-table :test 'eq))
        (members (make-hash-table :test 'eq))
        (taken (make-hash-table :test 'equal)))
   ;; A label defined once in the text. Two graphs written together can each
   ;; have their own *x; the second becomes a fresh one, or reading the text
   ;; back would join them.
   (flet ((claim (label)
            (if (or (null label) (gethash label taken))
                (let ((new (funcall fresh)))
                  (setf (gethash new taken) t)
                  new)
                (setf (gethash label taken) label))))
    (dolist (c concepts) (setf (gethash c members) t))
    (dolist (c concepts)
      (unless (gethash c roles)
        (let ((partners (remove-if-not (lambda (p) (gethash p members))
                                       (ignore-errors (coreference c)))))
          (cond
            (partners
             ;; The coreference set, within CONCEPTS, in their order.
             (let ((set (list c)) (agenda (copy-list partners)))
               (loop while agenda
                     do (let ((p (pop agenda)))
                          (unless (member p set)
                            (push p set)
                            (dolist (q (ignore-errors (coreference p)))
                              (when (gethash q members) (push q agenda))))))
               (setf set (remove-if-not (lambda (x) (member x set)) concepts))
               (let* ((definer (or (find-if #'cgif-defining-label set) (first set)))
                      (label   (claim (or (cgif-defining-label definer)
                                          (some #'cgif-bound-label set)))))
                 (dolist (m set)
                   (setf (gethash m roles)
                         (cons (if (eq m definer) :define :bind) label))))))
            ((cgif-defining-label c)
             (setf (gethash c roles) (cons :define (claim (cgif-defining-label c)))))
            ;; Its *x is outside the text: the name has to stay as it is.
            ((cgif-bound-label c)
             (setf (gethash c roles) (cons :bind (cgif-bound-label c)))))))))
    roles))

(defun cgif-assign-labels (concepts relations)
  "A hash table from each concept to (TEXT . REFERENCE): what goes in its
   referent field after any name, and what its relations call it."
  (let ((used (make-hash-table :test 'equal))
        (table (make-hash-table :test 'eq))
        (connected (make-hash-table :test 'eq))
        (names (make-hash-table :test 'equal))
        (counter 0))
    ;; A name is a relation's way to refer to a concept only when one concept
    ;; has it. [PERSON: Sue] twice is two concepts of one individual; naming
    ;; both "Sue" in their relations would leave an import unable to tell
    ;; which relation went to which, so those get labels instead.
    (dolist (c concepts)
      (let ((name (cgif-concept-name c)))
        (when name (incf (gethash name names 0)))))
    (dolist (c concepts)
      (dolist (label (list (cgif-defining-label c) (cgif-bound-label c)))
        (when label (setf (gethash label used) t))))
    (dolist (r relations)
      (dolist (c (arcs r)) (setf (gethash c connected) t)))
    (flet ((fresh ()
             (loop for label = (format nil "x~d" (incf counter))
                   unless (gethash label used)
                     return (progn (setf (gethash label used) t) label))))
      (let ((roles (cgif-coreference-roles concepts #'fresh)))
        (dolist (c concepts)
          (let ((role (gethash c roles))
                (name (cgif-concept-name c)))
            (setf (gethash c table)
                  (cond ;; @every quantifies a defining label: [PERSON: @every *x].
                        ((and (cgif-universal-p c) (eq (car role) :define))
                         (cons (format nil "@every *~a" (cdr role)) (format nil "?~a" (cdr role))))
                        ((cgif-universal-p c)
                         (let ((label (fresh)))
                           (cons (format nil "~@[?~a ~]@every *~a"
                                         (and (eq (car role) :bind) (cdr role)) label)
                                 (format nil "?~a" label))))
                        ((eq (car role) :define)
                         (cons (format nil "*~a" (cdr role)) (format nil "?~a" (cdr role))))
                        ;; [PERSON: ?x] is a concept of its own, coreferent with
                        ;; the *x one. A relation that said ?x would mean the *x
                        ;; concept, so a connected one also gets a label of its
                        ;; own for its relations: [PERSON: ?x *x3].
                        ((and (eq (car role) :bind) (gethash c connected))
                         (let ((label (fresh)))
                           (cons (format nil "?~a *~a" (cdr role) label) (format nil "?~a" label))))
                        ((eq (car role) :bind)
                         (cons (format nil "?~a" (cdr role)) (format nil "?~a" (cdr role))))
                        ((and name (= 1 (gethash name names)))
                         (cons nil (cgif-name name)))
                        ((gethash c connected)
                         (let ((label (fresh)))
                           (cons (format nil "*~a" label) (format nil "?~a" label))))
                        (t (cons nil nil))))))))
    table))

;;; --- Contexts -------------------------------------------------------------
;;;
;;; A concept holding a graph is written with the graph inside it:
;;; [PROPOSITION: [CAT: *x1] [MAT: *x2] (on ?x1 ?x2)], and ~[...] when it is
;;; negated. Its contents are its graph's nodes, head first, and any context
;;; standing beside that graph unconnected: cgraph holds ~[A ~[B]] (an
;;; if-then) as a graph A whose context also has the negation ~[B], which is
;;; not part of the graph. GRAPH-SIDE-CONTEXTS (graph.lisp) finds those, for
;;; the linear-form printer and for this.

(defun cgif-inner-nodes (concept)
  "What CONCEPT's graph holds, as two values: its concepts, head first, then
   the contexts beside it; and its relations."
  (let* ((graph (graph-referent concept))
         (nodes (remove-duplicates (remove-if-not #'graph-node-p (nodes graph))
                                   :from-end t))
         (concepts (remove-if-not #'concept-p nodes))
         (relations (remove-if-not #'relation-p nodes))
         (head (head graph)))
    (when (and head (member head concepts))
      (setf concepts (cons head (remove head concepts))))
    (dolist (owner (graph-side-contexts graph))
      (unless (member owner concepts)
        (setf concepts (append concepts (list owner)))))
    (values concepts relations)))

(defun cgif-all-nodes (concepts relations)
  "Every concept and relation in CONCEPTS and RELATIONS and the contexts they
   hold, outer first, as two values."
  (let ((all-concepts '()) (all-relations '())
        (agenda (list (cons concepts relations))))
    (loop while agenda
          do (destructuring-bind (cs . rs) (pop agenda)
               (setf all-concepts (append all-concepts cs)
                     all-relations (append all-relations rs))
               (dolist (c cs)
                 (when (graph-referent c)
                   (multiple-value-bind (inner-cs inner-rs) (cgif-inner-nodes c)
                     (setf agenda (append agenda (list (cons inner-cs inner-rs)))))))))
    (values all-concepts all-relations)))

(defvar *cgif-extras* nil
  "While FORMAT-CGIF writes: a hash table from each concept to the strings
   CGIF-EXTRAS-FOR gave it.")

(defun cgif-concept-text (concept labels)
  (let* ((name  (cgif-concept-name concept))
         (label (car (gethash concept labels)))
         (parts (remove nil (append (list (and name (cgif-name name)))
                                    (and *cgif-extras* (gethash concept *cgif-extras*))
                                    (list label)))))
    (if (graph-referent concept)
        (multiple-value-bind (concepts relations) (cgif-inner-nodes concept)
          (format nil "~:[~;~~~][~a: ~{~a ~}~a]"
                  (negated concept) (cgif-type-name concept) parts
                  (cgif-text concepts relations labels)))
        (format nil "[~a~@[: ~{~a~^ ~}~]]" (cgif-type-name concept) parts))))

(defun cgif-text (concepts relations labels)
  (format nil "~{~a~^ ~}"
          (append (mapcar (lambda (c) (cgif-concept-text c labels)) concepts)
                  (mapcar (lambda (r) (cgif-relation-text r labels)) relations))))

(defun cgif-relation-text (relation labels)
  (let ((arguments (append (inarcs relation) (list (outarc relation)))))
    (format nil "(~a~{ ~a~})" (cgif-relation-name relation)
            (mapcar (lambda (c)
                      (or (cdr (gethash c labels))
                          ;; An arc to a concept outside THING -- a node list
                          ;; cut from a larger graph. Name it as best we can.
                          (cgif-name (or (cgif-concept-name c) "?"))))
                    arguments))))

(defun cgif-texts (things mode)
  "THINGS written as CGIF in MODE, one string each, with one assignment of
   labels over all of them: unique in the whole text, and shared where a
   concept in one is coreferent with a concept in another."
  (check-type mode (member :portable :strict :lossless))
  (let* ((parts (mapcar (lambda (thing)
                          (multiple-value-call #'cons (cgif-nodes thing)))
                        things))
         (all-concepts '())
         (all-relations '()))
    (dolist (part parts)
      (multiple-value-bind (cs rs) (cgif-all-nodes (car part) (cdr part))
        (setf all-concepts (append all-concepts cs)
              all-relations (append all-relations rs))))
    (let ((*cgif-mode* mode)
          (*cgif-extras* (make-hash-table :test 'eq)))
      (dolist (c all-concepts)
        (setf (gethash c *cgif-extras*) (cgif-extras-for c)))
      ;; Labels over the whole text, nested contexts too, so they are unique
      ;; in it and coreference across contexts finds its partners.
      (let ((labels (cgif-assign-labels all-concepts all-relations)))
        (mapcar (lambda (part) (cgif-text (car part) (cdr part) labels)) parts)))))

(defun format-cgif (thing &key stream (mode :portable))
  "THING as extended CGIF: concepts first, head first, then relations.
   THING is a graph, a node list or a linear-form string. Returns the string,
   or writes it to STREAM and returns NIL.

   MODE is :PORTABLE (standard CGIF; drops what has no logical meaning, with
   a CGIF-DROPPED warning, and refuses what can't be said), :STRICT (refuses
   what :PORTABLE would drop) or :LOSSLESS (keeps all of it in cgraph's
   notation, so the graph comes back exactly). CGIF-UNSUPPORTED is the
   refusal. See notes/cgif.md."
  (let ((text (first (cgif-texts (list thing) mode))))
    (if stream
        (progn (write-string text stream) nil)
        text)))

(defun write-cgif-graphs (graphs destination &key (mode :portable))
  "Write GRAPHS as one CGIF text, a graph to a line, for READ-CGIF-GRAPHS or
   another tool. Labels are unique across the whole text, so the graphs stay
   apart when read back, and a concept coreferent with one in another graph
   keeps the link. DESTINATION is a stream, a pathname (the file is
   replaced), or NIL to return the text as a string. MODE is as for
   FORMAT-CGIF."
  (let ((text (format nil "~{~a~%~}" (cgif-texts graphs mode))))
    (etypecase destination
      (null text)
      (stream (write-string text destination) nil)
      ((or pathname string)
       (with-open-file (out destination :direction :output :if-exists :supersede
                                        :external-format :utf-8)
         (write-string text out))
       (pathname destination)))))
