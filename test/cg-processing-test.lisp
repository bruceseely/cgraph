
(in-package :conceptual-graphs)

(defvar *links nil)


;;; Things to test ...
;;; simplify
;;; restrict
;;; copy-cgraph
;;; join
;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  simplify-test  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; simplify-cgraph

(defvar eat-con)

(defvar spot-indiv)
(defvar spot-con)
(defvar cake-con)
(defvar fast1-con)
(defvar fast2-con)

(defvar obj-rel)
(defvar agnt-rel)
(defvar manr1-rel)
(defvar manr2-rel)

(defun init-simplify-test-nodes ()

  (setf eat-con (make-concept 'eat ()))

  (setf spot-indiv (make-individual 'dog '(:name "Spot")))
  (setf spot-con (make-concept (get-concept-type 'dog) spot-indiv))
  (setf cake-con (make-concept 'cake ()))
  (setf fast1-con (make-concept 'fast ()))
  (setf fast2-con (make-concept 'fast ()))

  (setf obj-rel (make-relation 'obj))
  (setf agnt-rel (make-relation 'agnt))
  (setf manr1-rel (make-relation 'manr))
  (setf manr2-rel (make-relation 'manr)))

(defun simplify-setup1 ()
  (init-simplify-test-nodes)
  (let ((graph-string "[DOG: Spot]<-(agnt)<-[EAT]-
                         (manr)->[FAST]
                         (manr)->[FAST].
                         (obj)->[CAKE].")

        (expected-string "[DOG: Spot]<-(agnt)<-[EAT]-
                         (manr)->[FAST]
                         (obj)->[CAKE]."))

  ;; [eat]->(agnt)->[dog]
  (add-arc-into-relation eat-con agnt-rel)
  (set-arc-from-relation agnt-rel spot-con)

  ;; [eat]->(obj)->[cake]
  (add-arc-into-relation eat-con obj-rel)
  (set-arc-from-relation obj-rel cake-con)

  ;; [eat]->(manr)->[fast]
  (add-arc-into-relation eat-con manr1-rel)
  (set-arc-from-relation manr1-rel fast1-con)

  ;; [eat]->(manr)->[fast]
  (add-arc-into-relation eat-con manr2-rel)
  (set-arc-from-relation manr2-rel fast2-con) ;; <---

  (values spot-con expected-string)))



(defun simplify-setup2 ()
  (init-simplify-test-nodes)
  (let ((graph-string "[DOG: Spot]<-(agnt)<-[EAT]-
                         (obj)->[CAKE]
                         (manr)->[FAST]
                         (manr)->[FAST].")
        (expected-string "[DOG: Spot]<-(agnt)<-[EAT]-
                         (obj)->[CAKE]
                         (manr)->[FAST]."))

  ;; [eat]->(agnt)->[dog]
  (add-arc-into-relation eat-con agnt-rel)
  (set-arc-from-relation agnt-rel spot-con)

  ;; [eat]->(obj)->[cake]
  (add-arc-into-relation eat-con obj-rel)
  (set-arc-from-relation obj-rel cake-con)

  ;; [eat]->(manr)->[fast]
  (add-arc-into-relation eat-con manr1-rel)
  (set-arc-from-relation manr1-rel fast1-con)

  ;; [eat]->(manr)->[fast]
  ;; (add-arc-into-relation eat-con manr2-rel)
  ;; (set-arc-from-relation manr2-rel fast1-con)

  ;; [eat]->(manr)->[fast]
  (add-arc-into-relation eat-con manr2-rel)
  (set-arc-from-relation manr2-rel fast1-con) ;; <---

  (values spot-con expected-string)))

;;; (graph-every-concept (simplify-setup))

(defun simplify-test (&optional verbose)
  (multiple-value-bind (graph expected-string)
      (simplify-setup1)
    (when verbose
      (format t "~&expected:~%~a" (encode-arrows expected-string)))

    (let ((initial (pcg graph)))
      (simplify-cgraph graph)
      (when verbose
        (format t "~&result:~%~a" (pcg graph)))
      (let ((pass
              (string-equal (compress-whitespace (expand-arrows (pcg graph)))
                            (compress-whitespace expected-string))))
        (when verbose
          (unless pass
            (format t "~&result:~%~a" (pcg graph))))
        pass))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  copy-test  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; see *print-without-variables*


(defun copy-check (in-string &optional verbose)
  (when verbose
    (format t "~2%==========================================================~%>> ~a" in-string)
    ;;(print (pcg (pcg in-string)))

    )
  (initialize-variables)
  (let*((*include-node-ref* nil)
        (string1 (canonicalize-graph-string in-string))
        (graph1 (pcg string1))
        (collection1 (collect-concepts graph1))
        (graph2 (copy-cgraph graph1))
        (collection2 (collect-concepts graph2))
        (string2 (flatten-cgraph (canonicalize-graph-string (expand-arrows (pcg graph2)))))


        (graphs-equal (graphs-equal graph1 graph2 t))
        (graphs-eq    (graphs-eq graph1 graph2))
        (strings-equal (string-equal string1 string2))
        (pass (and graphs-equal (not graphs-eq)))
        )

    ;; (format t "~&graph1: ~s~%"  (flatten-cgraph (pcg graph1)))   ; debug
    ;; (format t "~&graph2: ~s~%"  (flatten-cgraph (pcg graph2)))   ; debug
    ;; (format t "~&strings-equal: ~s~%"  strings-equal)

    (when (or verbose (not pass))
      (cond (pass
             (format t "~%=> pass: T" ))
            ((not graphs-equal)
             (let ((graph1-string (string-upcase (compress-whitespace (remove #\space string1))))
                   (graph2-string (string-upcase (compress-whitespace (remove #\space string2)))))
               (format t "~%Copy is not equal: ~%~a~%~a" graph1-string graph2-string)))
            (graphs-eq
             (format t "Graphs should not be identical ~%~a~%~a" collection1 collection2))))
    pass))




(defun copy-test (&optional verbose)
  (let* ((graph-string000 "[DOG: Spot]<-(agnt)<-[EAT].")
         (graph-string010 "[DOG: Spot]<-(agnt)<-[EAT]->(obj)->[CAKE].")
         (graph-string020 "[DOG: Spot]<-(agnt)<-[EAT]- (manr)->[FAST] (obj)->[CAKE].")
         (graph-string030 "[PERSON: Sue]<-(agnt)<-[GIVE]-
                                                     (obj)->[FOOD]<-(obj)<-[EAT:*x]
                                                     (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*x] .")
         (graph-string040 "[PERSON: Sue]<-(agnt)<-[GIVE]-
                                                     (inst)->[FOOD]<-(obj)<-[EAT:*x]->(manr)->[FAST]
                                                     (rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*x] .")
         (graph-string050 "[DOG:Spot]-
                               (agnt)<-[EAT:*x]
                               (poss)->[CAKE]<-(obj)<-[EAT:*x] .")
         (graph-string060 "[GIVE]-
                             (agnt)->[PERSON: Sue]
                             (inst)->[FOOD]<-(obj)<-[EAT: *x]
                             (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *x] .")
         (graph-string070 "[PERSON: Sue]<-(agnt)<-[GIVE]-
                                                    (inst)->[FOOD]<-(obj)<-[EAT: *x]
                                                    (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *x] .")

         (graph-strings (list graph-string000 graph-string010 graph-string020 graph-string030
                              graph-string040 graph-string050 graph-string060 graph-string070)))

    (every #'identity (mapcar #'(lambda (x) (copy-check x verbose)) graph-strings))))

(defun copy-test2 ()
  (let* ((graph-string "[DOG: Spot]<-(agnt)<-[EAT]->(obj)->[CAKE]."))
         (copy-check graph-string t)))



(defun copy-test3 ()
  (let* ((graph-string

"[PERSON: Sue]<-(agnt)<-[GIVE]- (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*z] (obj)->[FOOD]<-(obj)<-[EAT:*z]."

           ))
    ;;(print (pcg (pcg graph-string)))
         (copy-check graph-string t)))

#|
(#<SEG [PERSON: Sue]←(agnt)←[GIVE]>
 #<SEG [GIVE]→(rcpt)→[DOG: Spot]←(agnt)←[EAT: *z]>
 #<SEG [GIVE]→(obj)→[FOOD]←(obj)←[EAT: *z]>)
|#


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  restrict-test  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-restrict (candidate target expected &optional verbose)
  (let* ((candidate-original (princ-to-string candidate))
         (def-original (princ-to-string (list candidate target expected)))
         (result (restrict candidate target))
         (pass (concepts-equal candidate expected))
         (show (or verbose (not pass))))
    (when show
      (format t "~3&___testing: ~a~%" def-original)
      (format t "~&candidate before: ~a~%" candidate-original)
      (format t "~&target: ~s~%" target)
      (format t "~&calling (restrict ~s ~s)...~%" candidate target)
      (format t "~&modified candidate:  ~s~%" candidate)
      (format t "~&expected:            ~s~%"  expected)
      (format t "~&pass: ~s~%"  pass))
    (unless pass
      (describe candidate)
      (describe expected))
    pass))

(defun test-restrict-def (def &optional (verbose t))
  (destructuring-bind (candidate-terms target-terms expacted-terms) def
    (let* ((target (apply #'makit target-terms))
           (expected  (apply #'makit expacted-terms))
           (candidate (apply #'makit candidate-terms)))
      (test-restrict candidate target expected verbose))))

(defun makit (concept-type individual-type properties)
  (let* ((id (when (listp properties) (getf properties :id)))
         (props (cond ((symbolp properties)
                       (get-concept-type properties))
                      ((consp properties)
                       (sans-prop properties :id :variable))
                      (t ())))
         (individual (when individual-type
                       (make-individual individual-type props :id id)))
         (referent individual)
         (concept (when concept-type
                    (cond ;; ((eql individual-type 't)
                          ;;  (make-concept (get-concept-type concept-type) nil))
                          ((and concept-type (null individual))
                           (make-concept (get-concept-type concept-type) nil))
                          ((subtype-p  individual-type concept-type)
                           (make-concept (get-concept-type concept-type) referent))
                          (t nil)))))
    (or concept individual props)))

(defun restrict-test (&optional verbose)
  (let* ((dog-individual (make-individual 'dog))
         (defs ;;           candidate                target                      expected
           (list '((animal animal ())          (animal animal ())       (animal animal ()) )
                 '((animal nil ())             (dog dog ())             (dog dog ()))
                 '((animal dog ())             (dog dog (:name "Fido")) (dog dog (:name "Fido")))
                 '((animal dog ())             (nil nil dog)            (dog dog ()))
                 '((animal dog ())             (nil nil dog)            (dog dog ()))
                 '((animal dog (:name "Spot")) (dog dog ())             (dog dog (:name "Spot")))
                 '((dog dog ())                (nil dog (:name "Spot")) (dog dog (:name "Spot")))
                 '((dog dog ())                (nil nil (:name "Spot")) (dog dog (:name "Spot")))
                 '((animal dog ())             (nil dog ())             (dog dog ()))))
         (test-result t))

    (dolist (def defs)
      (destructuring-bind (candidate-terms target-terms expacted-terms) def
        (let* ((target (apply #'makit target-terms))
               (expected  (apply #'makit expacted-terms))
               (candidate (apply #'makit candidate-terms))
               (result (test-restrict candidate target expected verbose)))

          (setf test-result (and result test-result)))))
    test-result))





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  join-test  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun test-join1 (&optional verbose)
  (initialize-cgraph)
  (when verbose
    (format t "~2&test-join1"))
  (let* ((graph1-string "[EAT]- (AGNT)->[ANIMATE] (OBJ)->[FOOD].")
         (graph2-string "[EAT]->(AGNT)->[CAT: #].")
         (expected "[EAT]-(agnt)→[CAT: #](obj)→[FOOD].")
         (zz (when verbose (format t "~&joining:~&~5t~a~&~5t~a~%"
                                   graph1-string graph2-string)))
         (graph1 (pcg graph1-string))
         (graph2 (pcg graph2-string))
         (cat-con (find-concept 'cat graph2))
         (animate-con (find-concept 'animate graph1)))
    (restrict animate-con cat-con)
    (join graph1 graph2)
    (simplify graph1)
    (when verbose (princ (pcg graph1)))
    (graph-strings-equal expected (pcg graph1))))



(defun formation-demo1 ()
  (reset-cgraph)
  (format t "~2&formation-test")
  (let* ((graph1-string "[GIRL]<-(agnt)<-[EAT]->(manr)->[FAST].")
         (graph2-string "[PERSON: Sue]<-(agnt)<-[EAT]->(obj)->[PIE].")
         ;; try this in an automated environment:
         ;; (graph1-string "[GIRL]<-(agnt)<-[EAT]- (manr)->[FAST] (obj)->[FOOD].")

         (g1 (pcg graph1-string))
         (g2 (pcg graph2-string))
         (s1 (pcg g1))
         (s2 (pcg g2))

         ;; (g1 (graph-head g1))
         ;; (g2 (graph-head g2))

         (zz (format t "~&g1: ~s~%" (pcg g1)))
         (zz (format t "~&g2: ~s~%" (pcg g2)))
         (zz (format t "~2%________________~%"))

         (zz (format t "~&restrict  [PERSON: Sue] to 'GIRL in g2~%"))
         (zz (restrict g2 'girl))
         (zz (format t "~&g1: ~s~%" (pcg g1)))
         (zz (format t "~&g2: ~s~%" (pcg g2)))
         (zz (format t "~2%________________~%"))

         (zz (format t "~&restrict referent of [GIRL] in g1~%"))
         (girl1 (find-concept 'girl g1))
         (girl2 (find-concept 'girl g2))
         (zz (restrict girl1 girl2))
         (zz (format t "~&g1: ~s~%" (pcg g1)))
         (zz (format t "~&g2: ~s~%" (pcg g2)))
         (zz (format t "~2%________________~%"))

         (zz (format t "~&join [EAT] in g1 & [EAT] in g2~%"))
         (eat1 (find-concept 'eat g1))
         (eat2 (find-concept 'eat g2))
         (zz (join eat1 eat2))
         ;; the formatter messes this up
         (zz (format t "~&g1: ~s~%" (pcg g1)))
         (zz (format t "~&g2: ~s~%" (pcg g2)))
         (zz (format t "~2%________________~%"))


         (zz (format t "~&simplify [EAT], ~%"))
         (eat1 (find-concept 'eat g1))
         (zz (simplify eat1))
         (zz (format t "~&g1: ~s~%" (pcg g1)))
         (zz (format t "~&g2: ~s~%" (pcg g2)))
         (zz (format t "~2%________________~%"))


         (zz (format t "~&join [GIRL: Sue] in g1 & [GIRL: Sue] in g2~%"))
         (girl1 (find-concept 'girl g1))
         (girl2 (find-concept 'girl g2))
         (zz (join girl1 girl2))
         (zz (format t "~&g1: ~s~%" (pcg g1)))
         (zz (format t "~&g2: ~s~%" (pcg g2)))
         (zz (format t "~2%________________~%"))


         (zz (format t "~&simplify [GIRL: Sue]~%"))
         (zz (simplify girl1))
         (zz (format t "~&g1: ~s~%" (pcg g1)))
         (zz (format t "~&g2: ~s~%" (pcg g2)))
         (zz (format t "~2%________________~%"))


         (zz (format t "~&simplify [EAT], does nothing~%"))
         (zz (simplify eat1))
         (zz (format t "~&g1: ~s~%" (pcg g1)))
         )
    (declare (ignore zz))
    (variables-report)
    (cached-concepts-report)
    t))

(defun formation-demo2 ()
  (reset-cgraph)
  (format t "~2&formation-test")
  (let* ((sue (make-individual 'person '(:name "Sue")))
         (graph1-string "[GIRL]<-(agnt)<-[EAT]->(manr)->[FAST].")
         (graph2-string "[PERSON: Sue]<-(agnt)<-[EAT]->(obj)->[PIE].")
         ;; try this in an automated environment:
         ;; (graph1-string "[GIRL]<-(agnt)<-[EAT]- (manr)->[FAST] (obj)->[FOOD].")

         (g1 (pcg graph1-string))
         (g2 (pcg graph2-string))
         (girl1 (find-concept 'girl g1))
         (eat1 (find-concept 'eat g1))

         (person (find-concept 'person g2 :properties '(:name "Sue")))
         (girl2 person)
         (eat2 (find-concept 'eat g2))

         (s1 (pcg g1))
         (s2 (pcg g2)))

    ;; (g1 (graph-head g1))
    ;; (g2 (graph-head g2))

    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")


    (format t "~&restrict  [PERSON: Sue] to 'GIRL in g2~%")
    (restrict person girl1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&restrict referent of [GIRL] in g1~%")
    (restrict girl1 girl2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")


    (format t "~&join [GIRL: Sue] & [GIRL: Sue]~%")
    (join girl1 girl2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&join [EAT] & [EAT]~%")
    (join eat1 eat2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")


    (format t "~&simplify [GIRL: Sue]~%")
    (simplify girl1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")

    (format t "~&simplify [EAT]~%")
    (simplify eat1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")
    t))


(defun formation-demo3 ()
  (reset-cgraph)
  (format t "~2&formation-test")
  (let* ((sue (make-individual 'person '(:name "Sue")))
         (graph1-string "[GIRL]<-(agnt)<-[EAT]- (manr)->[FAST] (obj)->[FOOD].")
         (graph2-string "[PERSON: Sue]<-(agnt)<-[EAT]->(obj)->[PIE].")

         (g1 (pcg graph1-string))
         (g2 (pcg graph2-string))

         (eat1 (find-concept 'eat g1))
         (eat2 (find-concept 'eat g2))

         (food (find-concept 'food g1))
         (pie  (find-concept 'pie  g2))

         (girl1  (find-concept 'girl   g1))
         (person (find-concept 'person g2))
         (girl2 person))


    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&restrict  [FOOD] to 'PIE in g2~%")
    (restrict food pie)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&restrict  [PERSON: Sue] to 'GIRL in g2~%")
    (restrict person girl1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&restrict referent of [GIRL] in g1~%")
    (restrict girl1 girl2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")


    (format t "~&join [GIRL: Sue] & [GIRL: Sue]~%")
    (join girl1 girl2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&join [EAT] & [EAT]~%")
    (join eat1 eat2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")


    (format t "~&simplify [GIRL: Sue]~%")
    (simplify girl1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")

    (format t "~&simplify [EAT]~%")
    (simplify eat1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")
    t))

;;; doesn't work
(defun formation-demo4 ()
  (reset-cgraph)
  (format t "~2&formation-test")
  (let* ((sue (make-individual 'person '(:name "Sue")))
         (graph1-string "[GIRL]<-(agnt)<-[EAT]- (manr)->[FAST] (obj)->[FOOD].")
         (graph2-string "[PERSON: Sue]<-(agnt)<-[EAT]->(obj)->[PIE].")

         (g1 (pcg graph1-string))
         (g2 (pcg graph2-string))

         (eat1 (find-concept 'eat g1))
         (eat2 (find-concept 'eat g2))

         (food (find-concept 'food g1))
         (pie  (find-concept 'pie  g2))

         (girl1  (find-concept 'girl   g1))
         (person (find-concept 'person g2))
         (girl2 person))


    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")


    (format t "~&restrict  [FOOD] to 'PIE in g2~%")
    (restrict food pie)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&join [EAT] & [EAT]~%")
    (join eat1 eat2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")

    (format t "~&simplify [EAT]~%")
    (simplify eat1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")


    (format t "~&restrict  [PERSON: Sue] to 'GIRL in g2~%")
    (restrict person girl1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&restrict referent of [GIRL] in g1~%")
    (restrict girl1 girl2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&join [GIRL: Sue] & [GIRL: Sue]~%")
    (join girl1 girl2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&simplify [GIRL: Sue]~%")
    (simplify girl1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")

    t))


(defun formation-demo5 ()
  (reset-cgraph)
  (format t "~2&formation-test")
  (let* ((sue (make-individual 'person '(:name "Sue")))
         (graph1-string "[GIRL]<-(agnt)<-[EAT]- (manr)->[FAST] (obj)->[FOOD].")
         (graph2-string "[PERSON: Sue]<-(agnt)<-[EAT]->(obj)->[PIE].")

         (g1 (pcg graph1-string))
         (g2 (pcg graph2-string))

         (eat1 (find-concept 'eat g1))
         (eat2 (find-concept 'eat g2))

         (food (find-concept 'food g1))
         (pie  (find-concept 'pie  g2))

         (girl1  (find-concept 'girl   g1))
         (person (find-concept 'person g2))
         (girl2 person))


    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&restrict  [EAT] to 'EAT ~%")
    (restrict eat1 eat2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&restrict  [FOOD] to 'PIE in g2~%")
    (restrict food pie)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&restrict  [PERSON: Sue] to 'GIRL in g2~%")
    (restrict person girl1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&restrict referent of [GIRL] in g1~%")
    (restrict girl1 girl2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")



    (format t "~&join [GIRL: Sue] & [GIRL: Sue]~%")
    (join girl1 girl2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&g2: ~a~%" (pcg g2))
    (format t "~&---------------~2%")

    (format t "~&join [EAT] & [EAT]~%")
    (join eat1 eat2)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")


    (format t "~&simplify [GIRL: Sue]~%")
    (simplify girl1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")

    (format t "~&simplify [EAT]~%")
    (simplify eat1)
    (format t "~&g1: ~a~%" (pcg g1))
    (format t "~&---------------~2%")
    t))

(defun test-join3 (&optional verbose)
  (when verbose
    (format t "~2&test-join3"))
  (let (g1 g2 g3 expected)
    (initialize-cgraph)
    (setq g1 (parse-cgraph "[girl]<-(agnt)<-[eat]->(manr)->[fast]"))
    (setq g2 (parse-cgraph "[person:Sue]<-(agnt)<-[eat]->(obj)->[pie]"))
    (setq expected "[GIRL]-
   (agnt)←[EAT]→(manr)→[FAST]
   (agnt)←[EAT]→(obj)→[PIE].")
    (when verbose
      (format t "~&g1: ~s" (pcg g1))
      (format t "~&g2: ~s" (pcg g2)))
    (setq g3 (join g1 g2))
    (when verbose
    (format t "~&join result:~&~s" (pcg g3)))
    (string-equal (pcg g3) expected)))


;; (defun test-join4 ()
;;   (format t "~2&test-join4")
;;   (let* ((s1 "[pie]<-(obj)<-[eat]->(agnt)->[animate].")
;;          (s2 "[eat]- (obj)->[food] (agnt)->[dog:#].")
;;          (g1 (parse-cgraph s1))
;;          (g2 (parse-cgraph s2))
;;          (con1 (find-concept 'eat (nodes p1)))
;;          (con2 (find-concept 'eat (nodes p2)))
;;          (p3 (join con1 con2)))
;;     (print-cgraph p3)
;;     ))


;; (defun test-join5 ()
;;   (format t "~2&test-join5")

;;   (let* ((graph1-string "[EAT]->(AGNT)->[CAT: #].")
;;          (graph2-string "[EAT]- (AGNT)->[ANIMATE] (OBJ)->[FOOD].")
;;          (zz (format t "~&joining:~&~3t- ~a~&~3t- ~a" graph1-string graph2-string))
;;          (graph1 (parse-cgraph graph1-string))
;;          (graph2 (parse-cgraph graph2-string))
;;          (join-graph (join graph1 graph2)))
;;     (declare (ignore zz))
;;     (format t "~&~s" (format-cgraph join-graph))))




(defun join-demo1 (&optional verbose)
  (reset-cgraph)
  (let* ((graph-string-1 "[eat]- (agnt)->[person] (manr)->[fast].")
	 (graph-string-2 "[act]- (agnt)->[girl] (obj)->[pie].")
         (expected-string "[eat]- (agnt)->[girl] (manr)->[fast] (obj)->[pie].")
	 (graph1 (pcg graph-string-1))
	 (graph2 (pcg graph-string-2)))
    (when verbose
      (format t "~&~%Source graphs:")
      (print-cgraph graph1 :stream *terminal-io*)
      (print-cgraph graph2 :stream *terminal-io*))

    ;;(setq join-result (join graph1 graph2))
    (when verbose
      (format t "~&~%Graphs are joined on [EAT] / [ACT]")
      (print-cgraph graph1 :stream *terminal-io*))

    (let ((p (find-concept 'person graph1))
          (g (find-concept 'girl graph1)))
      (restrict p g))
    (when verbose
      (format t "~&~%[PERSON] is restricted with respect to [GIRL]")
      (print-cgraph graph1 :stream *terminal-io*))

    (simplify graph1)
    (when verbose
      (format t "~&~%Graph is simplified")
      (print-cgraph graph1 :stream *terminal-io*))

    (string-equal (compress-whitespace (expand-arrows (pcg graph1)))
                  (compress-whitespace expected-string))))



(defun join-test (&optional verbose)
  (test-join1 verbose)
  (test-join3 verbose)
  (cond (verbose
    (formation-demo)
    (join-demo1 verbose))
        (t t))
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  combine  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;







;; (defun test-combine1 ()
;;   (format t "~2&test-combine1")

;;   (let* ((graph1-string "[EAT]->(agnt)->[CAT: Puff].")
;;          (graph2-string "[EAT]- (agnt)->[ANIMATE] (obj)->[FOOD].")
;;          (zz (format t "~&joining:~&~3t- ~a~&~3t- ~a" graph1-string graph2-string))
;;          (graph1 (parse-cgraph graph1-string))
;;          (graph2 (parse-cgraph graph2-string))
;;          (join-graphs (combine-cgraphs graph1 graph2)))
;;     (declare (ignore zz))
;;     (format t "~&~s" (format-cgraph join-graph))))



(defun test-combine2 ()
  (format t "~2&test-combine2")
  (let* ((graph1-string "[EAT]->(agnt)->[CAT: #]->(loc)->[ROO].")
         (graph2-string "[EAT]- (agnt)->[ANIMATE] (obj)->[FOOD].")
         (g1 (pcg graph1-string))
         (g2 (pcg graph2-string)))
    (format t "~&graph1-string: ~s~%"  graph1-string)
    (format t "~&graph2-string: ~s~%"  graph2-string)
    (join-cgraphs g1 g2)))





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  merge  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-merge0 ()
  (initialize-cgraph)
  (setq *debug-mode* t)
  (let (g1 g2 g3 g4 c1 c2 c3 c4 s1 s2 s3 s4)
    g1 g2 g3 g4 c1 c2 c3 c4 s1 s2 s3 s4
    (setq g1 (pcg "[girl]<-(agnt)<-[eat]->(manr)->[fast]"))
    (setq g2 (pcg "[person:Sue]<-(agnt)<-[eat]->(obj)->[pie]"))
    (setq s1 (pcg g1))
    (setq s2 (pcg g2))

    (format t "~&s1: ~s~%" s1)
    (format t "~&s2: ~s~%" s2)
    (terpri)

    (untrace)
    (format t "~&Merging concepts ~a & ~a" g1 g2)
    (setq g3 (combine-concepts g1 g2))
    (setq s3 (pcg g3))

    (format t "~2&s3: ~s~%" (pcg g3))
    (format t "~&s1: ~s~%" (pcg g1))
    (format t "~&s2: ~s~%" (pcg g2))))


(defun test-merge1 ()
  (initialize-cgraph)
  (setq *debug-mode* t)
  (let (g1 g2 g3 g4 c1 c2 c3 c4 s1 s2 s3 s4 p1 p2)
    g1 g2 g3 g4 c1 c2 c3 c4 s1 s2 s3 s4 p1 p2
    (setq s1 "[girl]<-(agnt)<-[eat]->(manr)->[fast]")
    (setq s2 "[person:Sue]<-(agnt)<-[eat]->(obj)->[pie]")

    (clear-concept-cache)
    (setq g1 (pcg s1))
    (clear-concept-cache)
    (setq g2 (pcg s2))

    (setq p1 (pcg g1))
    (setq p2 (pcg g2))
    (format t "~&s1: ~s" s1)
    (format t "~&s2: ~s" s2)
    (format t "~&g1: ~s" g1)
    (format t "~&g2: ~s" g2)
    (format t "~&p1: ~s" p1)
    (format t "~&p2: ~s" p2)

    (format t "~2%Merging concepts g1 & g2")
    (let* ((g3 (combine-concepts g1 g2))
           (p3 (pcg g3)))
      ;;(format t "~&g3: ~s" g3)
      (format t "~&p3: ~s" p3)
      (format t "~&Cleared by the merge:")
      (format t "~&p1: ~s" (pcg g1))
      (format t "~&p2: ~s" (pcg g2)))))


(defun test-merge2 ()
  (initialize-cgraph)
  (setq *debug-mode* t)
  (let* ((s1 "[girl]<-(agnt)<-[eat]->(manr)->[fast]")
         (s2 "[person:Sue]<-(agnt)<-[eat]->(obj)->[pie]")
         (ignore (clear-concept-cache))
         (g1 (pcg s1))
         (ignore (clear-concept-cache))
         (g2 (pcg s2))
         (p1 (pcg g1))
         (p2 (pcg g2)))
    (declare (ignore ignore))
    (format t "~&s1: ~a" s1)
    (format t "~&s2: ~s" s2)
    (format t "~&g1: ~a" g1)
    (format t "~&g2: ~s" g2)
    (format t "~&p1: ~a" p1)
    (format t "~&p2: ~s" p2)
    (let* ((g3 (combine-concepts g1 g2))
           (p3 (pcg g3)))
      (format t "~&g3: ~s" g3)
      (format t "~&p3: ~s" p3)
      (format t "~&p1: ~s" (pcg g1))
      (format t "~&p2: ~s" (pcg g2))

    )))

;;; (pcg "[Chevy: #2]") - works but fails in situ
;;; (pcg "[Chevy #2]") - fails

(defun test-merge3 ()
  (reset-cgraph)
  (setq *debug-mode* nil)
  (let* ((s1 "[drive]->(inst)->[Chevy:#3]->(attr)->[old].")
         (s2 "[drive]->(inst)->[conveyance]->(attr)->[old].")
         (ignore (clear-concept-cache))
         (g1 (pcg s1))
         (ignore (clear-concept-cache))
         (g2 (pcg s2))
         (p1 (pcg g1))
         (p2 (pcg g2))
         (c0 (find-concept 'chevy g1 :id 3))
         (c1 (car (find-concepts 'chevy g1)))
         (c2 (car (find-concepts 'conveyance g2)))
         (c3 (combine-concepts c0 c2))
         (c4 (combine-concepts c1 c2))
         (head (graph-head g1))
         copy
         )
    (declare (ignore ignore))
    (format t "~&s1: ~s" s1)
    (format t "~&s2: ~s" s2)
    (format t "~&p1: ~s" p1)
    (format t "~&p2: ~s" p2)

    (format t "~2%")
    (format t "~&c1: ~s" c1)
    (format t "~&c2: ~s" c2)
    (format t "~&c3: ~s" c3)
    (format t "~&c4: ~s" c4)
    (format t "~&g1:\~&~s" (pcg g1))
    (format t "~&g2:~&~s" (pcg g2))
    (format t "~&(pcg head):~&~s" (pcg head))
    (format t "~&head: ~s" head)
    (format t "~2%")
    (simplify-from-node head)


    (setq copy (copy-cgraph head))

    (format t "~&(pcg copy):~&~s" (pcg copy))

    (format t "~&(simplify-from-node ~a)" head)
    (format t "~&(pcg head):~&~s" (pcg head))
    head))


(defun test-merge ()
  (test-merge0)
  (test-merge1)
  (test-merge2)
  (test-merge3))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  combined  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun rules-test ()
  (untrace)					;diag
  (let (graph-string-1 graph-string-2 graph1  graph2)

    (flet ((setup ()
             (setf graph-string-1 "[eat]- (agnt)->[girl] (manr)->[fast].")
	     (setf graph-string-2 "[eat]- (agnt)->[girl] (obj)->[pie].")
	     (setf graph1 (parse-cgraph graph-string-1))
	     (setf graph2 (parse-cgraph graph-string-2))))

      (let* (join-result1 join-result2
             simplify-result1 simplify-result2
	     head1 head2)

        ;; (format t "~&graph1: ~s~%" (pcg graph1))
        ;; (format t "~&graph2: ~s~%" (pcg graph2))

        (setup)
        (format t "~&~%Source graphs:")
        (setq graph1 (simplify-cgraph graph1))
        (format t "~&~%.graph1:")
        (print-cgraph graph1 :stream *terminal-io*)
        (setq graph2 (simplify-cgraph graph2))
        (format t "~&~%.graph2:")
        (print-cgraph graph2 :stream *terminal-io*)

        (setq join-result1 (join graph1 graph2))
        (format t "~&~%Graphs are joined at 'eat'")
        (setq simplify-result1 (simplify-cgraph join-result1))
        (print-cgraph join-result1 :stream *terminal-io*)
        (print-cgraph simplify-result1 :stream *terminal-io*)

        (setup)
        (setq head1 (find-concept 'girl graph1))
        (setq head2 (find-concept 'girl graph2))
        (format t "~&head1: ~s;   head2: ~s~%" head1 head2)
        (format t "~&~%")

        (format t "~&~%-graph1:")
        (print-cgraph graph1 :stream *terminal-io*)
        (format t "~&~%-graph2:")
        (print-cgraph graph2 :stream *terminal-io*)

        (setq join-result2 (join head1 head2))
        (format t "~&~%Graphs are joined at 'girl'")
        (format t "~&~%")
        (setq simplify-result2 (simplify-cgraph join-result2))
        (print-cgraph join-result2 :stream *terminal-io*)
        (print-cgraph simplify-result2 :stream *terminal-io*)

        (values)))))



#+nil
(pcg (join-cgraphs
      (pcg "[dog]<-(agnt)<-[eat]->(obj)->[food].")
      (pcg "[dog]<-(agnt)<-[walk].")))



(defun test-formation-rules ()
  (test-copy-cgraph)
  (copy-test)
  (test-merge)
  (test-join)
  (untrace))



;; (defun info (string)
;;   (let* ((obj (pcg string))
;;         (ref (referent obj))
;;         (num (node-ref obj)))
;;     (print (list obj ref num))))
