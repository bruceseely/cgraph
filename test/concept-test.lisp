;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)



(defmethod test-concept ((concept-string string) &optional verbose)
  (let* ((source-string (remove #\space concept-string))
         (concept1 (graph-head (pcg source-string)))
         (concept1-string (arrows-to-ascii (pcg concept1)))
         (concept2 (car (pcg concept1-string)))
         (concept1-properties (properties concept1))
         (concept2-properties (properties concept2))
         (properties-equal (equalp concept1-properties concept2-properties))
         )
    (format t "~&properties-equal: ~s~%"  properties-equal)

    (when (or verbose (not properties-equal))
      (unless  properties-equal
        (format t "~&Failed:~%"))
      (format t "~&- source-string: ~s" source-string)
      (format t "~&- concept1 ~s" concept1)
      (format t "~&- concept1-string ~s" concept1-string)
      (format t "~&- concept2: ~s" concept2)
      (format t "~&- concept1-properties ~s" concept1-properties)
      (format t "~&- concept2-properties ~s" concept2-properties)
      (format t "~&- properties-equal ~s" properties-equal))
    properties-equal))


;; (defun test-concepts ( &optional verbose)
;;   (let ((test-passed t)
;;         (concept-strings
;;           (cond (*concise*
;;                  (list
;;                   "[dog]"
;;                   "[dog:*]"
;;                   ;;"[dog:#]"
;;                   "[dog:#3]"
;;                   ;;"[person:Judy]."
;;                   "[person: Judy#2]"
;;                   ;;"[length: @5ft.]."
;;                   ;;"[length:@25.4cm]."
;;                   "[length: len1@5ft.]"
;;                   ;;"[measure:@25.4cm]."
;;                   ;;"[temperature:@90deg#567]."
;;                   ;;"[temperature:#567@90 deg]."
;;                   "[dog:{Fido,Spot}]"
;;                   "[dog:{Fido,#123}]"
;;                   "[dog: #34*x]"
;;                   "[dog:{Fido,*}]"
;;                   "[dog:{Fido,*}@3]"
;;                   "[dog:{Fido,*}@3]"))
;;                 (t
;;                  (list
;;                   "[dog: *]"
;;                   "[dog: #]"
;;                   "[dog: #3]"
;;                   ;;"[person: Judy]."
;;                   "[person: Judy #2]"
;;                   ;;"[length: @5 ft.]."
;;                   ;;"[length: @25.4 cm]."
;;                   "[length: len1 @5ft.]"
;;                   ;;"[measure: @25.4 cm]."
;;                   ;;"[temperature: @90 deg #567]."
;;                   ;;"[temperature: #567@90 deg]."
;;                   "[dog: {Fido, Spot}]"
;;                   "[dog: {Fido, #123}]"
;;                   "[dog: #34 *x]"
;;                   "[dog: {Fido, *}]"
;;                   "[dog: {Fido, *} @ 3]"
;;                   "[dog: {Fido, *}@3]")))))

;;     (dolist (concept-string concept-strings)
;;       (when verbose
;;         (format t "~2&>Testing  ~a~%" concept-string))
;;       (setq test-passed (and (test-concept concept-string verbose) test-passed)))
;;     test-passed))


(defun test-concepts ( &optional verbose)
  (let ((test-passed t)
        (concept-strings
          (cond (*concise*
                 (list
                  ;;"[dog]"
                  ;;"[dog:*]"
                  ;;"[dog:#]"
                  ;;"[dog:#3]"
                  "[person:Judy]."
                  ;;"[person: Judy#2]"
                  "[length: @5ft.]."
                  "[length:@25.4cm]."
                  ;;"[length: len1@5ft.]"
                  "[measure:@25.4cm]."
                  "[temperature:@90deg#567]."
                  "[temperature:#567@90 deg]."
                  ;;"[dog:{Fido,Spot}]"
                  ;;"[dog:{Fido,#123}]"
                  ;;"[dog: #34*x]"
                  ;;"[dog:{Fido,*}]"
                  ;;"[dog:{Fido,*}@3]"
                  ;;"[dog:{Fido,*}@3]"
                  ))
                (t
                 (list
                  ;;"[dog: *]"
                  ;;"[dog: #]"
                  ;;"[dog: #3]"
                  "[person: Judy]."
                  ;;"[person: Judy #2]"
                  "[length: @5 ft.]."
                  "[length: @25.4 cm]."
                  ;;"[length: len1 @5ft.]"
                  "[measure: @25.4 cm]."
                  "[temperature: @90 deg #567]."
                  "[temperature: #567@90 deg]."
                  ;;"[dog: {Fido, Spot}]"
                  ;;"[dog: {Fido, #123}]"
                  ;;"[dog: #34 *x]"
                  ;;"[dog: {Fido, *}]"
                  ;;"[dog: {Fido, *} @ 3]"
                  ;;"[dog: {Fido, *}@3]"
                  )))))

    (dolist (concept-string concept-strings)
      (when verbose
        (format t "~2&>Testing  ~a~%" concept-string))
      (setq test-passed (and (test-concept concept-string verbose) test-passed)))
    test-passed))


(defun concept-test ( &optional verbose)
  (with-test-types
    (let ((*include-node-ref* nil))

      (when verbose
        (format t "~%CONCEPT-TEST~%"))
      (and
       (let ((*concise* t)
             )
         (when verbose
           (format t "~2&Concise:~%"))
         (test-concepts verbose))
       (let ((*concise* nil))
         (when verbose
           (format t "~2&Not Concise:~%"))
         (test-concepts verbose))))))


;;; --- MAKE-CONCEPT from a property list --------------------------------------
;;;
;;; (make-concept 'dog '(:name "Rover")) RETURNED NIL whenever the individual did
;;; not already exist: both creating branches built an individual and a referent
;;; and then returned a concept only when the referent came back NULL, so the
;;; normal case fell off the end of an inner COND. `Spot' worked and `Rover' did
;;; not, which is why it survived -- in a live image the individual usually has
;;; been made already. See notes/known-issues.md.

(defun make-concept-plist-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (name result)
               (setf ok (and ok (and result t)))
               (when (or verbose (not result))
                 (format t "~&  ~:[fail~;pass~] ~a~%" result name))))
        (when verbose (format t "~&MAKE-CONCEPT-PLIST-TEST~%"))

        ;; The case that returned NIL: an individual nothing has made yet.
        (let* ((ctx (make-context))
               (con (make-concept 'dog '(:name "Rover") :context ctx)))
          (check "a name not seen before yields a concept"
                 (typep con 'concept))
          (check "of the right type"
                 (and con (types-equal (concept-type con) (get-concept-type 'dog))))
          (check "carrying that name"
                 (and con (equal "Rover" (referent-name con)))))

        ;; And the case that always worked keeps working: asked twice, the second
        ;; call finds the individual the first one made and reuses it.
        (let* ((ctx (make-context))
               (a (make-concept 'dog '(:name "Lassie") :context ctx))
               (b (make-concept 'dog '(:name "Lassie") :context ctx)))
          (check "asking twice reuses the same individual"
                 (and a b (same-individual-p (content (referent a))
                                             (content (referent b))))))

        ;; Several distinct ones in a row -- the shape that exposed it, since only
        ;; the first name happened to exist already.
        (let ((ctx (make-context)))
          (check "three distinct names give three concepts"
                 (every (lambda (n)
                          (typep (make-concept 'dog (list :name n) :context ctx)
                                 'concept))
                        '("Ripper" "Snowy" "Bandit"))))

        ;; An explicit :id must still be honoured rather than replaced by a fresh
        ;; number -- MAKE-INDIVIDUAL defaults only a NIL id, which is what lets
        ;; the two old branches collapse into one.
        (let* ((ctx (make-context))
               (con (make-concept 'dog '(:name "Rex" :id 7777) :context ctx)))
          (check "an explicit :id is kept"
                 (and con (eql 7777 (id (content (referent con)))))))

        ;; :id t is the unspecified individual marker (#) and must survive too.
        (let* ((ctx (make-context))
               (con (make-concept 'dog '(:name "Hash" :id t) :context ctx)))
          (check ":id t stays the unspecified marker"
                 (and con (eq t (id (content (referent con)))))))

        (when verbose
          (format t "~&MAKE-CONCEPT-PLIST-TEST ~:[failed~;passed~]~%" ok))
        ok))))
