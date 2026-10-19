(in-package :conceptual-graphs)

;;; PARSE-CGRAPH on graph strings it can't read: each must signal a
;;; CGRAPH-PARSE-ERROR that says what is wrong and points at the right place.
;;; Before these were errors, most of them came back as a different graph from
;;; the one written -- [CAT]→[DOG] as [CAT], a stray ] ending the graph early
;;; -- or as a Lisp error that named neither.

(defparameter *parse-error-cases*
  ;; (string  words-the-message-must-contain  where-the-caret-goes)
  ;; The caret is given as a substring the error must point at the start of,
  ;; or :END for the end of the string.
  '(("[CAT: Tom"                               "has no closing ]"            :end)
    ("[CAT]→(agnt)→[EAT"                       "[EAT has no closing ]"       :end)
    ("[CAT]→[DOG]"                             "an arrow joins two concepts" "→[DOG]")
    ("[CAT: Tom]←agnt←[EAT]"                   "AGNT is neither a concept"   "agnt")
    ("[EAT]→(obj)→FOOD"                        "FOOD is neither a concept"   "FOOD")
    ("[EAT]→(foo)→[CAT]"                       "no relation type foo"        "(foo)")
    ("[FOOBAR]←(agnt)←[EAT]"                   "no concept type FOOBAR"      "[FOOBAR]")
    ("[CAT: Tom]]←(agnt)←[EAT]"                "a ] that closes nothing"     "]←")
    ("[CAT: Tom]←(agnt)"                       "has no arrow in"             "(agnt)")
    ("(agnt)→[CAT]"                            "has no arrow in"             "(agnt)")
    ("[EAT]→(obj)→"                            "doesn't lead to anything"    "→")
    ("[EAT]→(obj)→[FOOD]→"                     "doesn't lead to anything"    "→")
    ("[EAT]→(obj→[FOOD]"                       "(obj has no closing )"       "→[FOOD]")
    ("[EAT]→()→[FOOD]"                         "no relation name"            "→[FOOD]")
    ("[CAT: {Tom, ]"                           "has no closing }"            :end)
    ("[CAT: @@]"                               "@ needs a number"            "@]")
    ("~[PROPOSITION: [CAT]→(on)→[MAT]"         "no closing ]"                :end)
    (""                                        "there is no concept"         :end)
    ;; A concept whose type its relation doesn't allow: found while linking,
    ;; after the string is read, and pointed at by the concept.
    ("[CAT]←(agnt)←[MAT]"                      "[MAT] can't be the source of (agnt)" "[MAT]")
    ("[EAT]-(agnt)→[MAT] (obj)→[FOOD]"         "[MAT] can't be the destination of (agnt)" "[MAT]")
    ("[PROPOSITION: [CAT]←(agnt)←[MAT]]"       "can't be the source of (agnt)" "[MAT]")))

(defun parse-error-for (string)
  "The CGRAPH-PARSE-ERROR that parsing STRING signals, or NIL."
  (handler-case (progn (parse-cgraph string) nil)
    (cgraph-parse-error (condition) condition)))

(defun caret-index (string where)
  (if (eq where :end)
      (length string)
      ;; `→' in a case means the last arrow: a dangling one is always last.
      (if (string= where "→")
          (position (char where 0) string :from-end t)
          (search where string))))

(defun parse-error-test (&optional verbose)
  (let ((ok t))
    (flet ((check (name result)
             (setf ok (and ok (and result t)))
             (when (or verbose (not result))
               (format t "~&  ~:[fail~;pass~] ~a~%" result name))))
      (when verbose (format t "~&PARSE-ERROR-TEST~%"))

      (dolist (case *parse-error-cases*)
        (destructuring-bind (string words where) case
          (let ((condition (parse-error-for string)))
            (check (format nil "~s is an error" string) condition)
            (when condition
              (check (format nil "~s says ~s" string words)
                     (search words (parse-error-message condition)))
              (check (format nil "~s points at ~s" string where)
                     (eql (caret-index string where)
                          ;; The report skips whitespace forward from the
                          ;; position, so compare the same way.
                          (let ((position (parse-error-position condition)))
                            (and position
                                 (or (position-if-not (lambda (c) (member c '(#\Space #\Tab)))
                                                      string :start position)
                                     position)))))))))

      (check "the error keeps the condition underneath"
             (typep (parse-error-cause (parse-error-for "[FOOBAR]")) 'concept-type-lookup-failed))
      (check "the report shows the string with a caret under the problem"
             (search (format nil "[CAT]→[DOG]~%       ^")
                     (princ-to-string (parse-error-for "[CAT]→[DOG]"))))
      (check "a type mismatch keeps its condition, with no package prefixes"
             (let ((condition (parse-error-for "[CAT]←(agnt)←[MAT]")))
               (and (typep (parse-error-cause condition) 'relation-signature-mismatch)
                    (not (search "::" (parse-error-message condition))))))
      (check "make-cgraph signals it too"
             (handler-case (progn (make-cgraph "[CAT]→[DOG]") nil)
               (cgraph-parse-error () t)))

      ;; Valid graphs that sit close to the errors above.
      (dolist (string '("[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]."
                        "[CAT: Tom]<-(agnt)<-[EAT]->(obj)->[FOOD]"
                        "[EAT]-(agnt)→[CAT] (obj)→[FOOD]"
                        "[PROPOSITION: [CAT]→(on)→[MAT]]"
                        "[PROPOSITION: [CAT]→(on)→[MAT].]"
                        "~[PROPOSITION: [DOG: *x]<-(agnt)<-[BARK] ~[PROPOSITION: [DOG: ?x]->(attr)->[NOISY]]]"))
        (check (format nil "~s parses" string)
               (not (parse-error-for string)))))
    ok))
