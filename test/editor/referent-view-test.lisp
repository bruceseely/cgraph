(in-package :conceptual-graphs)

;;; Stage 0 of the referent editor: does DESCRIBE-REFERENT account for every
;;; form the reader accepts?
;;;
;;; The table below is notes/referent-catalog.md, row for row. That is the
;;; point of it: the catalog is the specification of what a referent can be, so
;;; a decomposition is only trustworthy if it has been shown the whole thing.
;;; A row here that starts failing means either the reader grew a feature the
;;; view does not model, or the view lost one it used to.
;;;
;;; Each row states the notation, the identity KIND it should decompose to, and
;;; the identity text that kind should report. The modifiers are checked
;;; separately, because the whole claim of the split is that they are
;;; independent of the identity -- so they are tested against a matrix rather
;;; than one column of a table.

(defparameter *referent-view-cases*
  ;; notation                          kind          identity text
  '(("[DOG]"                           :none         "")
    ("[DOG: *]"                        :none         "")
    ;; *x and ?x are separate mechanisms, not two spellings -- see the KIND
    ;; comment in system/editor/referent.lisp.
    ("[DOG: *x]"                       :variable     "*x")
    ("[DOG: ?x]"                       :coref        "?x")
    ("[DOG: #]"                        :individual   "#")
    ("[DOG: #123]"                     :individual   "#123")
    ;; Both carry an id; the second wrote it down and the first was assigned
    ;; one. The view shows it either way, which the formatter does not.
    ("[DOG: Fido]"                     :individual   nil)
    ("[CAT: Felix #7]"                 :individual   "Felix #7")
    ("[DOG: {*}]"                      :set          "{}")
    ("[DOG: {Fido, Spot}]"             :set          "{Fido, Spot}")
    ("[DOG: {*} @ 5]"                  :set          "{}")
    ("[PROPOSITION: [DOG: *x]]"        :graph        nil)   ; text checked loosely
    ("[[PERSON: *x]]"                  :graph        nil)))

(defun %rview-of (source)
  "The view of the first concept parsed from SOURCE.

   Individuals are allowed to be minted here: half the catalog's identity forms
   name one that does not exist yet, and the alternative is a fixture that
   would have to be kept in step with the table."
  (let* ((*allow-dynamic-individual-creation* t)
         (nodes (parse-cgraph source))
         (concept (find-if #'concept-p nodes)))
    (values (describe-referent concept) concept)))

(defun referent-view-test (&optional verbose)
  (with-test-types
   (let ((ok t))
    (flet ((check (label pass)
             (setf ok (and ok (and pass t)))
             (when (or verbose (not pass))
               (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

      ;; --- A. every identity form in the catalog decomposes ----------------
      (dolist (row *referent-view-cases*)
        (destructuring-bind (source kind identity) row
          (multiple-value-bind (view concept) (%rview-of source)
            (check (format nil "~a decomposes to ~(~a~)" source kind)
                   (eq kind (rview-kind view)))
            (when identity
              (check (format nil "~a identity reads ~s" source identity)
                     (string= identity (referent-identity-text view))))
            (check (format nil "~a is fully accounted for" source)
                   (referent-view-complete-p view concept)))))

      ;; --- B. modifiers are independent of the identity ---------------------
      ;; The claim the split rests on. If it holds, every modifier survives on
      ;; every identity, so the editor can offer them as separate controls
      ;; rather than as a mode picker.
      (dolist (identity '("" "*x" "?x" "#7" "Fido"))
        (dolist (modifier '(("@past"        :tense  :past)
                            ("@progressive" :aspect :progressive)
                            ("@passive"     :voice  :passive)
                            ("@every"       :quantifier :universal)))
          (destructuring-bind (word slot value) modifier
            (let* ((body (string-trim " " (format nil "~a ~a" identity word)))
                   (source (format nil "[EAT: ~a]" body))
                   (view (%rview-of source)))
              (check (format nil "~a keeps ~a" source word)
                     (eql value (ecase slot
                                  (:tense (rview-tense view))
                                  (:aspect (rview-aspect view))
                                  (:voice (rview-voice view))
                                  (:quantifier (rview-quantifier view)))))))))

      ;; --- C. a compound tense/aspect recomposes as one word ----------------
      (let ((view (%rview-of "[EAT: *e @past-progressive @passive]")))
        (check "compound tense/aspect reads back as one hyphenated word"
               (search "@past-progressive" (referent-modifier-text view)))
        (check "voice survives beside it"
               (search "@passive" (referent-modifier-text view))))

      ;; --- D. a measure is a modifier, not an identity ----------------------
      ;; A measure on a non-set mints an anonymous individual to hang itself
      ;; on, so the identity is :INDIVIDUAL rather than :NONE. What matters is
      ;; that the measure is reported as a modifier and does NOT also sit in
      ;; the tail -- it lands in the individual's properties, so a view that
      ;; did not strip it would carry it twice and write it out twice.
      (let ((view (%rview-of "[DISTANCE: @ 5 ft.]")))
        (check "a measure is reported as a modifier"
               (search "5" (referent-modifier-text view)))
        (check "a measure is not duplicated into the tail"
               (null (getf (rview-tail view) :measure))))

      ;; A set's cardinality is a measure on the referent, so it must show up
      ;; as a modifier WITHOUT swallowing the set identity.
      (let ((view (%rview-of "[DOG: {*} @ 5]")))
        (check "a set keeps its identity when it has a cardinality"
               (eq :set (rview-kind view)))
        (check "the cardinality is reported as a modifier"
               (search "5" (referent-modifier-text view))))

      ;; --- E. the unbounded tail is carried, not dropped --------------------
      ;; The feature the reader has no key for. No stage edits it; every stage
      ;; has to preserve it, so stage 0 has to be able to SEE it.
      (let* ((indiv (make-individual 'dog '(:name "Rex" :collar "red") :id 91))
             (concept (make-concept (get-concept-type 'dog) (make-referent indiv)))
             (view (describe-referent concept)))
        (check "an unrecognised property lands in the tail"
               (equal "red" (getf (rview-tail view) :collar)))
        (check "the name is not left in the tail as well"
               (null (getf (rview-tail view) :name)))
        (check "the name is modelled" (equal "Rex" (rview-name view)))
        (check "a tail-carrying concept is fully accounted for"
               (referent-view-complete-p view concept)))

      ;; --- F. negation is on the concept, not the referent ------------------
      (let ((view (%rview-of "~[DOG: Fido]")))
        (check "negation is captured" (rview-negated view))
        (check "negation does not disturb the identity"
               (and (eq :individual (rview-kind view))
                    (equal "Fido" (rview-name view)))))

      ;; --- G. editing is in place, and touches only what it names -----------
      ;; The losslessness claim. Not "the re-emitted text still parses" but the
      ;; stronger "nothing else moved", which is checkable field by field.

      ;; A modifier does not disturb the identity.
      (multiple-value-bind (view concept) (%rview-of "[EAT: Fido @past]")
        (declare (ignore view))
        (let ((before (describe-referent concept)))
          (set-referent-modifier concept :voice :passive)
          (let ((after (describe-referent concept)))
            (check "setting voice leaves the identity kind alone"
                   (eq (rview-kind before) (rview-kind after)))
            (check "setting voice leaves the name alone"
                   (equal (rview-name before) (rview-name after)))
            (check "setting voice leaves the id alone"
                   (eql (rview-id before) (rview-id after)))
            (check "setting voice leaves the tense alone"
                   (eq :past (rview-tense after)))
            (check "setting voice sets voice" (eq :passive (rview-voice after))))))

      ;; Clearing a modifier clears only it.
      (multiple-value-bind (view concept) (%rview-of "[EAT: @past-progressive @passive]")
        (declare (ignore view))
        (set-referent-modifier concept :voice nil)
        (let ((after (describe-referent concept)))
          (check "clearing voice clears voice" (null (rview-voice after)))
          (check "clearing voice keeps tense"  (eq :past (rview-tense after)))
          (check "clearing voice keeps aspect" (eq :progressive (rview-aspect after)))))

      ;; A rename in place keeps the individual, and with it the tail.
      (let* ((indiv (make-individual 'dog '(:name "Rex" :collar "red") :id 92))
             (concept (make-concept (get-concept-type 'dog) (make-referent indiv))))
        (set-referent-identity concept :individual :id 92 :name "Rexx")
        (let ((after (describe-referent concept)))
          (check "a rename in place takes effect" (equal "Rexx" (rview-name after)))
          (check "a rename in place keeps the id" (eql 92 (rview-id after)))
          (check "a rename in place PRESERVES THE TAIL"
                 (equal "red" (getf (rview-tail after) :collar)))))

      ;; Identity is exclusive: acquiring one clears the others, or the concept
      ;; renders as neither.
      (multiple-value-bind (view concept) (%rview-of "[DOG: ?x]")
        (declare (ignore view))
        (set-referent-identity concept :individual :name "Fido")
        (let ((after (describe-referent concept)))
          (check "coref -> individual switches kind"
                 (eq :individual (rview-kind after)))
          (check "coref -> individual drops the old label"
                 (null (rview-label after)))
          (check "the concept still formats as one thing"
                 (let ((text (format-concept concept)))
                   (and (search "Fido" text) (not (search "?x" text)))))))

      ;; And back the other way.
      (multiple-value-bind (view concept) (%rview-of "[DOG: Fido]")
        (declare (ignore view))
        (set-referent-identity concept :coref :label "y")
        (let ((after (describe-referent concept)))
          (check "individual -> coref switches kind" (eq :coref (rview-kind after)))
          (check "individual -> coref drops the referent"
                 (null (rview-name after)))
          (check "individual -> coref formats as the label"
                 (search "?y" (format-concept concept)))))

      ;; :none strips the identity and nothing else.
      (multiple-value-bind (view concept) (%rview-of "[EAT: Fido @past]")
        (declare (ignore view))
        (set-referent-identity concept :none)
        (let ((after (describe-referent concept)))
          (check ":none clears the identity" (eq :none (rview-kind after)))
          (check ":none keeps the modifiers"  (eq :past (rview-tense after)))))

      ;; Editing never mints a new node -- the click map depends on it.
      (multiple-value-bind (view concept) (%rview-of "[DOG: Fido]")
        (declare (ignore view))
        (let ((ref (node-ref concept)))
          (set-referent-modifier concept :tense :past)
          (set-referent-identity concept :coref :label "z")
          (set-referent-identity concept :individual :name "Spot")
          (check "the node-ref survives every kind of edit"
                 (eql ref (node-ref concept)))))

      ;; --- H. clearing the whole referent ----------------------------------
      ;; The one operation that is ALLOWED to drop the tail, so the test says
      ;; exactly what it drops and what it only detaches.
      (let* ((indiv (make-individual 'dog '(:name "Rex" :collar "red") :id 94))
             (concept (make-concept (get-concept-type 'dog) (make-referent indiv))))
        (set-referent-modifier concept :tense :past)
        (set-referent-modifier concept :voice :passive)
        (set-referent-measure concept '(5 "kg"))
        (clear-referent concept)
        (let ((after (describe-referent concept)))
          (check "clear drops the identity"  (eq :none (rview-kind after)))
          (check "clear drops the modifiers" (and (null (rview-tense after))
                                                  (null (rview-voice after))))
          (check "clear drops the measure"   (null (rview-measure after)))
          (check "clear leaves a bare concept"
                 (string= "[DOG]" (format-concept concept))))
        ;; Detached, not destroyed -- which is what makes the clear reversible.
        (check "the individual survives the clear"
               (let ((found (find-individual-with-id 94)))
                 (and found (equal "red" (getf (properties found) :collar)))))
        (set-referent-identity concept :individual :id 94)
        (let ((back (describe-referent concept)))
          (check "giving the id back re-attaches the individual"
                 (equal "Rex" (rview-name back)))
          (check "and the tail comes back with it"
                 (equal "red" (getf (rview-tail back) :collar)))))

      ;; Refusals are errors, not silent no-ops.
      (multiple-value-bind (view concept) (%rview-of "[DOG]")
        (declare (ignore view))
        (check "an unknown modifier is refused"
               (handler-case (progn (set-referent-modifier concept :colour :red) nil)
                 (referent-edit-error () t)))
        (check "a labelless variable is refused"
               (handler-case (progn (set-referent-identity concept :variable) nil)
                 (referent-edit-error () t)))
        (check "a measure with nothing to hang it on is refused"
               (handler-case (progn (set-referent-measure concept '(5 "ft.")) nil)
                 (referent-edit-error () t))))

      ok))))
