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
       (test-concepts verbose)))))
