;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Referent decomposition -- stage 0 of the referent editor.
;;
;;  Design: notes/graph-editor.md, "Referent editors".
;;
;;  A concept is a type and a referent, and the referent is not one thing. It
;;  is an IDENTITY -- which individual, or which variable, or which set -- plus
;;  MODIFIERS that compose freely with any identity and with each other, plus
;;  whatever the reader did not recognise, which becomes arbitrary individual
;;  properties and is therefore unbounded.
;;
;;  That three-way split is the whole point, and it is not obvious from the
;;  list of forms in notes/referent-catalog.md. Read as a list, the forms look
;;  like modes to pick between; they are not. `:id :name :variable :coref :set'
;;  are mutually exclusive -- one selector, five states -- while
;;  `:quantifier :tense :aspect :voice :measure' are orthogonal to the
;;  selector and to each other. So the editor is one exclusive control plus
;;  several independent ones, not a mode picker.
;;
;;  This file is the READ side: it turns a live concept into that structure so
;;  a UI can show it. It deliberately does not build concepts. Editing happens
;;  by mutating the concept in place, for the same reason every other editor
;;  operation does -- re-parsing mints new nodes and churns every node-ref,
;;  which would invalidate the browser's click map (see session.lisp).
;;
;;  Nothing here is allowed to LOSE anything. A view that quietly dropped a
;;  feature would be a view the editor could then overwrite from, so the tail
;;  is carried verbatim even though no stage yet edits it.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defstruct (referent-view (:conc-name rview-))
  ;; --- identity: exactly one of these kinds ---
  ;; :none        a generic concept -- [DOG], or the `*' that formats to it
  ;; :variable    a re-entrancy variable -- *x
  ;; :coref       a co-reference label -- ?x
  ;; :individual  a specific individual -- #123, #, Fido, Felix #7
  ;; :set         a set referent -- {Fido, Spot}, {}@5
  ;; :graph       a nested graph -- [PROPOSITION: [...]]
  ;;
  ;; :VARIABLE and :COREF are separate kinds because they are separate
  ;; mechanisms, not two spellings of one. A `*x' is a NODE-VARIABLE and is
  ;; rendered by VARIABLE-TEXT; a `?x' is a coreference label rendered by
  ;; COREF-TEXT; a concept carrying both renders only the coref (see
  ;; VARIABLE-TEXT, concept.lisp:124). Collapsing them lost `*x' outright --
  ;; the concept has no referent and no coref label, so a view that consulted
  ;; only those reported a bare generic and the label vanished on write-back.
  (kind :none)
  label            ; label with the sigil stripped: "x" for both *x and ?x
  defining-p       ; T when it renders as *x rather than ?x
  id               ; individual id: an integer, or T for a bare `#'
  name             ; individual name string, or NIL
  set              ; the SET object, for :set
  graph            ; the GRAPH object, for :graph
  ;; --- modifiers: independent of the identity and of each other ---
  quantifier tense aspect voice raising
  measure          ; (SIZE UNITS), from a measure or a set's cardinality
  negated          ; `~' on the concept
  ;; --- everything the reader did not recognise, verbatim ---
  ;; Unbounded by construction: RESOLVE-TARGET-CONCEPT files any feature it has
  ;; no key for into the individual's properties. No stage edits this; every
  ;; stage must preserve it.
  tail)

(defun referent-tail-properties (individual)
  "INDIVIDUAL's properties minus the ones the view models explicitly.
   What is left is the unbounded tail -- features the reader accepted and had
   nowhere structured to put.

   :MEASURE is stripped even though RESOLVE-TARGET-CONCEPT leaves it in the
   properties (it is absent from that function's SANS-PROP list, so a measure
   on a non-set lands here rather than on the referent). The view models it as
   a modifier, and a feature that appeared in BOTH places would be written
   twice by anything that emitted the modifiers and then the tail."
  (sans-prop (properties individual) :name :id :variable :measure))

(defun describe-referent (concept)
  "A REFERENT-VIEW of CONCEPT: identity, modifiers, and the unrecognised tail.

   Reads only. The identity kinds are mutually exclusive and tested in the
   order the reader resolves them, so a concept that is both -- a set with a
   coref label, say -- reports the one that actually governs its notation."
  (let* ((referent (referent concept))
         (content  (and referent (content referent)))
         (coref    (coref-text concept))
         (variable (variable-text concept))
         (view (make-referent-view
                :quantifier (concept-quantifier concept)
                :tense      (concept-tense concept)
                :aspect     (concept-aspect concept)
                :voice      (concept-voice concept)
                :raising    (concept-raising-p concept)
                :negated    (negated concept)
                ;; A measure sits on the referent for a set (the set object
                ;; does not carry it) and in the individual's properties
                ;; otherwise; read both so neither spelling is missed.
                :measure    (or (and referent (measure-property referent))
                                (and (individual-p content)
                                     (getf (properties content) :measure))))))
    (cond
      ;; A graph referent is an alternative to the whole identity panel rather
      ;; than one of its states: it opens a nested GRAPH editor instead.
      ((graph-referent concept)
       (setf (rview-kind view) :graph
             (rview-graph view) (graph-referent concept)))
      ((set-p content)
       (setf (rview-kind view) :set
             (rview-set view) content))
      ((individual-p content)
       (setf (rview-kind view) :individual
             (rview-id view)   (id content)
             (rview-name view) (getf (properties content) :name)
             (rview-tail view) (referent-tail-properties content)))
      ;; A label with no individual behind it -- [DOG: ?x], [DOG: *x] -- is
      ;; still an identity, and the only one whose text lives on the concept
      ;; rather than in a referent.
      ((plusp (length coref))    (setf (rview-kind view) :coref))
      ((plusp (length variable)) (setf (rview-kind view) :variable))
      (t (setf (rview-kind view) :none)))
    ;; The label is read whenever there is one, even for an individual: a
    ;; named concept can carry a variable too, and dropping either half loses
    ;; it. Coref wins the text when both are present, exactly as the formatter
    ;; resolves it.
    (let ((text (if (plusp (length coref)) coref variable)))
      (when (plusp (length text))
        (setf (rview-label view)      (string-left-trim "*?" text)
              (rview-defining-p view) (char= (char text 0) #\*))))
    view))

;;; --- What the view says about itself ---------------------------------------
;;;
;;; These exist so a UI never has to re-derive notation from the parts, and so
;;; the tests can state what a form decomposed TO without reaching into slots.

(defun referent-identity-text (view)
  "The identity half of the referent, as the EDITOR shows it. Empty for :NONE.

   Deliberately more explicit than FORMAT-CONCEPT for one case. The formatter
   drops an individual's id once it has a name and the name is unambiguous --
   `[CAT: Felix #7]' emits as `[CAT: Felix]' -- because the name resolves back
   to the same individual in the reading context. That is a fine thing for
   notation to do and a bad thing for an editor to do: the id is what the
   name resolves TO, and you cannot edit a field you are not shown. So the
   view reports both, and this string is a description of the referent rather
   than a reproduction of the formatter's output."
  (ecase (rview-kind view)
    (:none "")
    ((:coref :variable)
     (format nil "~:[?~;*~]~(~a~)" (rview-defining-p view) (rview-label view)))
    (:individual
     (let* ((name (rview-name view))
            (id   (rview-id view))
            (id-text (cond ((eql id t) "#")
                           ((numberp id) (format nil "#~d" id))
                           (t ""))))
       (cond ((and name (plusp (length id-text))) (format nil "~a ~a" name id-text))
             (name name)
             (t id-text))))
    (:set   (format-object (rview-set view)))
    (:graph (format-cgraph (rview-graph view)))))

(defun referent-modifier-text (view)
  "The @-words, in the order FORMAT-CONCEPT writes them. Empty when there are
   none. Measures are included; they are modifiers even though the catalog
   lists them under their own heading."
  (let ((words (list)))
    (when (rview-quantifier view)
      (push (format nil "@~(~a~)"
                    (case (rview-quantifier view)
                      (:universal "every")
                      (:existential "some")
                      (t (rview-quantifier view))))
            words))
    (let ((tense (rview-tense view))
          (aspect (rview-aspect view)))
      ;; Written as the one hyphenated word the reader derives them from --
      ;; @past-progressive, not @past @progressive.
      (when (or tense aspect)
        (push (format nil "@~(~{~a~^-~}~)"
                      (remove nil (list tense (unless (eq aspect :simple) aspect))))
              words)))
    (when (rview-voice view)   (push (format nil "@~(~a~)" (rview-voice view)) words))
    (when (rview-raising view) (push "@raising" words))
    (when (rview-measure view) (push (string-trim " " (format-measure (rview-measure view)))
                                     words))
    (format nil "~{~a~^ ~}" (nreverse words))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Editing -- in place, one field at a time.
;;
;;  Every setter here names ONE field and touches only that field. That is the
;;  whole losslessness argument, and it is structural rather than earned: a
;;  feature nothing names is a feature nothing can drop. The alternative
;;  considered -- compose notation from the view and re-parse it -- would make
;;  every referent edit mint a new concept, churning the node-ref the browser's
;;  click map is keyed on (session.lisp), and would put the unbounded tail on
;;  the round trip where a gap in the view becomes silent data loss.
;;
;;  The identity setters are the ones with real work to do, because identity is
;;  EXCLUSIVE: a concept that acquired an individual while keeping its old
;;  coref label would render as neither. So each one clears the others first.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-condition referent-edit-error (error)
  ((text :initarg :text :reader referent-edit-error-text))
  (:report (lambda (c s) (write-string (referent-edit-error-text c) s))))

(defun referent-edit-error (control &rest args)
  (error 'referent-edit-error :text (apply #'format nil control args)))

(defparameter *referent-modifiers* '(:quantifier :tense :aspect :voice :raising)
  "The @-word modifiers that live in concept slots. Orthogonal to the identity
   and to each other, which is why setting one can be this blunt.")

(defun set-referent-modifier (concept modifier value)
  "Set one @-word modifier on CONCEPT. VALUE NIL clears it.

   No validation of VALUE against the concept's type: whether [DOG: @past] is
   meaningful is a question for whoever offers the control, not for the setter.
   Gating tense/aspect/voice on the type is the UI's job -- the same
   show-only-real-choices rule the arc affordances follow."
  (unless (member modifier *referent-modifiers*)
    (referent-edit-error "~s is not an editable modifier; expected one of ~{~(~s~)~^, ~}"
                         modifier *referent-modifiers*))
  (ecase modifier
    (:quantifier (setf (concept-quantifier concept) value))
    (:tense      (setf (concept-tense concept) value))
    (:aspect     (setf (concept-aspect concept) value))
    (:voice      (setf (concept-voice concept) value))
    (:raising    (setf (concept-raising-p concept) value)))
  concept)

(defun set-referent-measure (concept measure)
  "Set or clear CONCEPT's measure, as (SIZE UNITS) or NIL.

   A measure has two homes: on the REFERENT for a set (the set object does not
   carry one) and in the individual's properties otherwise. Writing it to the
   wrong one leaves the formatter reading the other, so this follows the same
   split DESCRIBE-REFERENT reads."
  (let* ((referent (referent concept))
         (content  (and referent (content referent))))
    (cond ((null referent)
           (referent-edit-error
            "~a has no referent to measure; give it an identity first"
            (label (concept-type concept))))
          ((set-p content)
           (if measure
               (setf (getf (properties referent) :measure) measure)
               (remf (properties referent) :measure)))
          ((individual-p content)
           (if measure
               (setf (getf (properties content) :measure) measure)
               (remf (properties content) :measure)))
          (t (referent-edit-error "cannot attach a measure to ~s" content))))
  concept)

(defun clear-referent-identity (concept)
  "Strip whatever identity CONCEPT currently carries, leaving its modifiers,
   its negation and its type alone.

   All three mechanisms are cleared rather than the one that looks active,
   because they are independent registries and a concept can be in more than
   one at once -- which is exactly the state that renders as neither."
  (let ((var (ignore-errors (node-variable concept))))
    (when var (ignore-errors (unset-variable concept))))
  (let ((label (coref-label-setp concept)))
    (when label (remhash label *coref-labels*)))
  (setf (coref-bound-label concept) nil)
  (setf (coreference concept) (list))
  (setf (referent concept) nil)
  concept)

(defun set-referent-identity (concept kind &key label id name)
  "Give CONCEPT the identity KIND, replacing whatever it had.

   KIND is :NONE, :VARIABLE (LABEL), :COREF (LABEL) or :INDIVIDUAL (ID and/or
   NAME). Sets and graph referents are not handled here -- a set is stage 3 and
   a graph referent opens a nested graph editor instead of this panel.

   Pointing a concept at a different individual does NOT carry the previous
   individual's tail across, and should not: those properties describe the
   individual, not the concept that mentions it. Renaming in place is the case
   that must preserve them, and does."
  (ecase kind
    (:none (clear-referent-identity concept))
    ((:variable :coref)
     (unless (and label (plusp (length (string label))))
       (referent-edit-error "a ~(~a~) identity needs a label" kind))
     (clear-referent-identity concept)
     (if (eq kind :variable)
         (set-variable concept (string label))
         (setf (coref-bound-label concept) (intern (string-upcase (string label)) :keyword))))
    (:individual
     (unless (or id name)
       (referent-edit-error "an individual identity needs an id, a name, or both"))
     (let* ((current (let ((r (referent concept))) (and r (content r))))
            (renaming-in-place
              ;; Same individual, new name: mutate it so the tail survives.
              (and (individual-p current)
                   (or (null id) (eql id (id current))))))
       (cond
         (renaming-in-place
          (if name
              (setf (getf (properties current) :name) name)
              (remf (properties current) :name)))
         (t
          (let* ((ctype (concept-type concept))
                 (props (when name (list :name name)))
                 (found (and id (numberp id) (find-individual-with-id id)))
                 (indiv (or found
                            (make-individual ctype props
                                             :id (if (numberp id) id nil)))))
            (when (and found name)
              (setf (getf (properties found) :name) name))
            (clear-referent-identity concept)
            (setf (referent concept) (make-referent indiv))
            (setf (concept (referent concept)) concept)))))))
  concept)

(defun referent-view-complete-p (view concept)
  "True when VIEW accounts for everything CONCEPT's notation carries.

   The stage-0 guarantee, checkable on any concept: whatever the reader
   accepted is either modelled by a slot or sitting in the tail, and nothing
   fell on the floor in between. It is deliberately a question the view can be
   ASKED rather than a property asserted in a comment, because the tail is
   unbounded and the next feature added to the reader will not know about this
   file."
  (let* ((referent (referent concept))
         (content  (and referent (content referent))))
    (and
     ;; every identity the reader can produce lands in a kind
     (member (rview-kind view) '(:none :variable :coref :individual :set :graph))
     ;; an individual's properties are split into name + tail, nothing dropped
     (or (not (individual-p content))
         (null (set-difference (sans-prop (properties content) :id :variable)
                               (append (when (rview-name view) (list :name (rview-name view)))
                                       (rview-tail view))
                               :test #'equal)))
     t)))
