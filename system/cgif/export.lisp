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
;;  to by its name. A concept that already has a label keeps it -- *x defining,
;;  ?x bound, as cgraph writes them. Any other concept with relations gets a
;;  fresh *x1, *x2, ..., skipping labels the graph already uses.
;;
;;  Not yet written, and refused with CGIF-UNSUPPORTED rather than dropped:
;;  nested graphs, negation, sets, measures, individual ids without a name, and
;;  the @-words other than @some. Each is a row of the note's "No standard CGIF
;;  form" table, or one of its contexts, and gets its CGIF form in a later step.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(export '(format-cgif cgif-unsupported) :conceptual-graphs)

(define-condition cgif-unsupported (error)
  ((concept :initarg :concept :reader cgif-unsupported-concept)
   (feature :initarg :feature :reader cgif-unsupported-feature))
  (:report (lambda (condition stream)
             (format stream "Can't write ~a as CGIF: ~a isn't supported yet"
                     (format-node (cgif-unsupported-concept condition))
                     (cgif-unsupported-feature condition)))))

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

(defun cgif-check-supported (concept)
  "Signal CGIF-UNSUPPORTED for anything about CONCEPT this step can't write."
  (flet ((refuse (feature)
           (error 'cgif-unsupported :concept concept :feature feature)))
    (let* ((referent (referent concept))
           (content  (and referent (content referent))))
      (when (graph-referent concept) (refuse "a nested graph"))
      (when (negated concept)        (refuse "negation"))
      (when (set-p content)          (refuse "a set"))
      (when (or (getf (properties concept) :measure)
                (and referent (measure-property referent)))
        (refuse "a measure"))
      (when (and (typep content 'individual) (not (cgif-concept-name concept)))
        (refuse (if (eql (id content) t)
                    "the individual marker #"
                    "an individual id without a name")))
      ;; @some is what a concept means anyway, so it is dropped, not refused.
      (let ((quantifier (concept-quantifier concept)))
        (when (and quantifier (not (eq quantifier :existential)))
          (refuse (format nil "the quantifier @~(~a~)"
                          (if (eq quantifier :universal) "every" quantifier)))))
      (dolist (word (list (concept-tense concept)
                          (concept-aspect concept)
                          (concept-voice concept)))
        (when word (refuse (format nil "the annotation @~(~a~)" word)))))))

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
  (let* ((nodes (remove-if-not #'graph-node-p
                               (etypecase thing
                                 (graph  (nodes thing))
                                 (list   thing)
                                 (string (parse-cgraph thing)))))
         (concepts  (remove-if-not #'concept-p nodes))
         (relations (remove-if-not #'relation-p nodes))
         (head      (and (typep thing 'graph) (head thing))))
    (when (and head (member head concepts))
      (setf concepts (cons head (remove head concepts))))
    (values concepts relations)))

(defun cgif-assign-labels (concepts relations)
  "A hash table from each concept to (TEXT . REFERENCE): what goes in its
   referent field after any name, and what its relations call it."
  (let ((used (make-hash-table :test 'equal))
        (table (make-hash-table :test 'eq))
        (connected (make-hash-table :test 'eq))
        (counter 0))
    (dolist (c concepts)
      (dolist (label (list (cgif-defining-label c) (cgif-bound-label c)))
        (when label (setf (gethash label used) t))))
    (dolist (r relations)
      (dolist (c (arcs r)) (setf (gethash c connected) t)))
    (flet ((fresh ()
             (loop for label = (format nil "x~d" (incf counter))
                   unless (gethash label used)
                     return (progn (setf (gethash label used) t) label))))
      (dolist (c concepts)
        (let ((defining (cgif-defining-label c))
              (bound    (cgif-bound-label c))
              (name     (cgif-concept-name c)))
          (setf (gethash c table)
                (cond (defining (cons (format nil "*~a" defining) (format nil "?~a" defining)))
                      (bound    (cons (format nil "?~a" bound) (format nil "?~a" bound)))
                      (name     (cons nil (cgif-name name)))
                      ((gethash c connected)
                       (let ((label (fresh)))
                         (cons (format nil "*~a" label) (format nil "?~a" label))))
                      (t (cons nil nil)))))))
    table))

(defun cgif-concept-text (concept labels)
  (let* ((name  (cgif-concept-name concept))
         (label (car (gethash concept labels)))
         (parts (remove nil (list (and name (cgif-name name)) label))))
    (format nil "[~a~@[: ~{~a~^ ~}~]]" (cgif-type-name concept) parts)))

(defun cgif-relation-text (relation labels)
  (let ((arguments (append (inarcs relation) (list (outarc relation)))))
    (format nil "(~a~{ ~a~})" (cgif-relation-name relation)
            (mapcar (lambda (c)
                      (or (cdr (gethash c labels))
                          ;; An arc to a concept outside THING -- a node list
                          ;; cut from a larger graph. Name it as best we can.
                          (cgif-name (or (cgif-concept-name c) "?"))))
                    arguments))))

(defun format-cgif (thing &key stream)
  "THING as extended CGIF: concepts first, head first, then relations.
   THING is a graph, a node list or a linear-form string. Returns the string,
   or writes it to STREAM and returns NIL.

   Signals CGIF-UNSUPPORTED for what this version can't write yet -- nested
   graphs, negation, sets, measures, unnamed individuals, @-words. See
   notes/cgif.md."
  (multiple-value-bind (concepts relations) (cgif-nodes thing)
    (mapc #'cgif-check-supported concepts)
    (let* ((labels (cgif-assign-labels concepts relations))
           (text (format nil "~{~a~^ ~}"
                         (append (mapcar (lambda (c) (cgif-concept-text c labels)) concepts)
                                 (mapcar (lambda (r) (cgif-relation-text r labels)) relations)))))
      (if stream
          (progn (write-string text stream) nil)
          text))))
