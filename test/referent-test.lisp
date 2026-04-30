
(in-package :conceptual-graphs)


(defmethod test-referent ((concept-text string) &optional verbose)

  ;;(defmethod unique-individual-p ((ind individual)) ind nil)

  ;;(format t "~&concept-text: ~s~%"  concept-text)
  (let* ((concept (car (pcg concept-text)))
         (concept-string (pcg (car (pcg concept-text))))
         (recreated-concept (car (pcg concept-text)))
         (recreated-concept-string (pcg (car (pcg (pcg (car (pcg concept-text)))))))
         (recreated-result (concepts-equal concept recreated-concept))
         (summary (string-equal concept-string recreated-concept-string)))

    (when verbose
      (format t "~2%")
      (format t "~&concept-string: ~s" concept-string)
      (format t "~&recreated-concept-string: ~s" recreated-concept-string)

      (format t "~&concept: ~s" concept)
      (format t "~&recreated-concept: ~s~%"  recreated-concept)
      (format t "~&summary: ~s~%"  summary)

      ;;(format t "~&recreated-result: ~s~%"  recreated-result)
      (cond (summary
             (format t "~:[~;pass: ~a ==> ~a~]" verbose concept-string (pcg recreated-concept)))
            (t
             (format t "~:[~;** FAIL: ~a : ~a~]" verbose concept-string concept-string))))
    summary))


(defmethod reftest ((def cons) verbose)
  (destructuring-bind (concept-string desc) def
    (format t "~:[~;~&~s - ~a~]" verbose concept-string desc)
    (test-referent concept-string verbose)))


;;; (pcg (pcg "[dog: *x]."))

(defun referent-test (&optional verbose)
  (when verbose
    (format t "~%REFERENT-TEST~%"))
  (initialize-cgraph)

  (let ((*include-node-ref* nil)
        (*allow-dynamic-individual-creation* t)
        (node-defs (list
                    (if *concise*
                        (list "[dog]"            "a generic dog; dog")
                        (list "[dog: *]"         "a generic dog, with a marker; dog"))
                    ;;(list "[dog: #]."             "a specific, unidentified dog; the dog")
                    (list "[dog: #3]"            "a specific, identified dog; the third dog")
                    (list "[dog: Fido]"          "a specific, named dog; the dog Fido")
                    (list "[length: @ 5 ft.]"    "a length of 5 feet")
                    (list "[length: @5ft.]"      "a length of 5 feet")
                    (list "[length: len1@5ft.]"  "a length of 5 feet, named len1")
                    (list "[length: @5 in #3 ]"  "the third specific length of 5 inches (with whitespace)")
                    (list "[length: @5in#3]"     "the third specific length of 5 inches (without whitespace)")
                    (if *concise*
                        (list "[dog: {}]"        "a set of dogs; plural, dogs")
                        (list "[dog: {*}]"       "a set of dogs, with generic marker"))
                    (if *concise*
                        (progn
                          (list "[dog: {} @ 5]"  "a set of 5 dogs; short for: [dog: {*}]->(qty)->[NUMBER: 5]")
                          (list "[dog: {}@5]"    "a set of 5 dogs; short for: [dog: {*}]->(qty)->[NUMBER: 5]"))
                        (list "[dog: {*}@5]"     "a set of 5 dogs, with generic marker"))
                    (list "[dog: {Fido, Spot}]"  "a set of 2 dogs; Fido and Spot")
                    (list "[dog: {Fido, #123}]"  "a set of 2 dogs; Fido and that dog")
                    (unless *concise*
                      (list "[dog: {Fido, *}]"   "a set of at least 2 dogs; Fido and some other dog(s)")
                      (list "[dog: {Fido, *} @ 3]" "a set of at 3 dogs; Fido and 2 other dogs")
                      (list "[dog: {Fido, *}@3]"   "a set of at 3 dogs; Fido and 2 other dogs"))
                    (list "[dog: #34 *x]"        "a generic dog, with a marker & variable; dog  ??")
                    (list "[person: Judy #2]"    "the second person named Judy"))))
    (format t "~:[~;~&Referent Test --~2%~]" verbose)
    (every #'identity
           (mapcar (lambda (def)
                     (when def
                       (prog1
                           (reftest def verbose)
                         (format t "~:[~;~2&--------------------------------------- ~]" verbose))))
                   (remove nil node-defs)))))


(defmethod c-ref ((concept-string string))
  (let* ((graph (parse-cgraph concept-string)))
    (format t "~&~s  --->  ~s" concept-string (pcg graph))
    graph))
