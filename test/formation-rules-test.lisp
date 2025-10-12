

(in-package :conceptual-graphs)



(defvar *verbose*)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  copy  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun verify-not-identical (source-graph copy-graph)
  (let* ((source-concepts (collect-concepts source-graph))
         (copy-concepts (collect-concepts copy-graph))
         (comparison (mapcar (lambda (source copy)
                               (not (nodes-eq source copy)))
                             source-concepts copy-concepts)))
    (every #'identity comparison)))

(defmethod compare-with-self ((source-graph-string string) &optional verbose)
  (let* ((canonical-string (pcg (pcg source-graph-string)))
         (source-graph (parse-cgraph source-graph-string))
         (source-graph-string (pcg (pcg source-graph-string)))
         (copy-graph   (parse-cgraph source-graph-string))
         (source-graph-string (format-cgraph source-graph))
         (copy-graph-string (format-cgraph copy-graph))
         (compare-equal (string-equal (remove #\space canonical-string)
                                      (remove #\space copy-graph-string)))
         (compare-unique (verify-not-identical source-graph copy-graph))
         (result (and compare-equal compare-unique)))

    (when verbose
      (format t "~&____________________________~%")
      (format t "~&canonical-string:   ~s" canonical-string)
      (format t "~&source-graph head:  ~s" source-graph)
      (format t "~&copy-graph head:    ~s" copy-graph)
      (format t "~&copy-graph-string:  ~s"copy-graph-string )
      (format t "~&compare-equal:      ~s" compare-equal)
      (format t "~&compare-unique:     ~s" compare-unique)
      (format t "~&result:             ~s" result))

    (unless result
      (format t "~2%copy-graph test failed:"))
    (when (or (not result) verbose)
      (format t "~%source-graph-string: ~a" source-graph-string)
      (format t "~%canonical-string:    ~a" canonical-string)
      (format t "~%copy-graph-string:   ~a" copy-graph-string))
    (unless result
      (format t "~%graphs are equal: ~s" compare-equal)
      (format t "~%graphs are unique: ~s" compare-unique))
    result))

(defun compare-with-copy (source-graph-string &optional verbose)
  (let* ((canonical-string (pcg (pcg source-graph-string)))
         (source-graph (parse-cgraph source-graph-string))
         (copy-graph (parse-cgraph source-graph-string))
         ;;(copy-graph (copy-cgraph source-graph))
         (copy-graph-string (format-cgraph copy-graph))
         (compare-equal (string-equal (remove #\space canonical-string)
                                      (remove #\space copy-graph-string)))
         (compare-unique (verify-not-identical source-graph copy-graph))
         (result (and compare-equal compare-unique)))

    (when verbose
      (format t "~&____________________________~%")
      (format t "~&canonical-string:   ~s" canonical-string)
      (format t "~&source-graph:       ~s" source-graph)
      (format t "~&copy-graph:         ~s" copy-graph)
      (format t "~&copy-graph-string:  ~s"copy-graph-string )
      (format t "~&compare-equal:      ~s" compare-equal)
      (format t "~&compare-unique:     ~s" compare-unique)
      (format t "~&result:             ~s" result))

    (unless result
      (format t "~2%copy-graph test failed:"))
    (when (or (not result) verbose)
      (format t "~%source-graph-string: ~a" source-graph-string)
      (format t "~%canonical-string:    ~a" canonical-string)
      (format t "~%copy-graph-string:   ~a" copy-graph-string))
    (unless result
      (format t "~%graphs are equal: ~s" compare-equal)
      (format t "~%graphs are unique: ~s" compare-unique))
    result))


;; testing verify-not-identical code
(defun cgpp-indepentent-test01 (source-graph-string)
(initialize-cgraph)
  (clrhash (concepts *context*))
  (let* ((source-graph (pcg source-graph-string))
         (source-links (collect-concepts source-graph))
         (source-concepts (mapcar #'con source-links))

         (copy-graph (copy-cgraph source-graph))
         (copy-links (collect-concepts copy-graph))
         (copy-concepts (mapcar #'con copy-links))

         (different-p (mapcar (lambda (source copy)
                           ;;(format t "~&source: ~s;~35tcopy: ~s" source copy)
                           (not (nodes-eq source copy)))
                         source-concepts copy-concepts)))
    (every #'identity different-p)))


(defun cgpp-copy (source-graph)
  (initialize-cgraph)
  (clrhash (concepts *context*))
  (let* (;;(source-graph (pcg source-graph-string))
         (source-links (collect-concepts source-graph))
         (source-concepts (mapcar #'con source-links))

         (copy-graph (copy-cgraph source-graph))
         (copy-links (collect-concepts copy-graph))
         (copy-concepts (mapcar #'con copy-links))

         (different-p (mapcar (lambda (source copy)
                                ;;(format t "~&source: ~s;~35tcopy: ~s" source copy)
                                (not (nodes-eq source copy)))
                              source-concepts copy-concepts)))
    (every #'identity different-p)
    copy-graph))

;; (setq g (pcg "[DOG]<-(agnt)<-[EAT: foo]."))
;; (copy-cgraph g)
;; (collect-concepts g)
;; (collect-concepts (copy-cgraph g))


;; (cgpp-indepentent-test01 "[DOG]<-(agnt)<-[EAT: Spot]->(obj)->[CAKE].")

;;(source-graph-string "[DOG: Spot]<-(agnt)<-[EAT].")
;;(source-graph-string "[DOG: Spot].")
;;(source-graph-string "[DOG].")
;;(source-graph-string "[DOG]<-(agnt)<-[EAT].")
;;(source-graph-string "[DOG]<-(agnt)<-[EAT: foo].")
;;(source-graph-string "[DOG]<-(agnt)<-[EAT]->(obj)->[CAKE: Spot].")
;;(source-graph-string "[DOG]<-(agnt)<-[EAT: Spot]->(obj)->[CAKE].")

(defun test-copy-cgraph ( &optional verbose)
  (initialize-cgraph)
  (let* ((graph-string000 "[DOG: Spot]<-(agnt)<-[EAT].")
         (graph-string010 "[DOG: Spot]<-(agnt)<-[EAT]->(obj)->[CAKE].")
         (graph-string020 "[DOG: Spot]<-(agnt)<-[EAT]- (manr)->[FAST] (obj)->[CAKE].")
         (graph-string030 "[PERSON: Sue]<-(agnt)<-[GIVE]-
                                        (obj)->[FOOD]<-(obj)<-[EAT:*z]
                                        (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*z].")
         (graph-string040 "[PERSON: Sue]<-(agnt)<-[GIVE]-
                           (inst)->[FOOD]<-(obj)<-[EAT:*z]->(manr)->[FAST]
                           (rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*z].")
         (graph-string050 "[DOG:Spot]-
                               (poss)->[CAKE]<-(obj)<-[EAT:*z]
                               (agnt)<-[EAT:*z].")
         (graph-string060 "[GIVE]-
                             (agnt)->[PERSON: Sue]
                             (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *z]
                             (inst)->[FOOD]<-(obj)<-[EAT: *z].")
         (graph-string070 "[PERSON: Sue]<-(agnt)<-[GIVE]-
                             (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *z]
                             (inst)->[FOOD]<-(obj)<-[EAT: *z].")

         (graph-strings (list graph-string000 graph-string010 graph-string020 graph-string030
                              graph-string040 graph-string050 graph-string060 graph-string070))
         (results (mapcar #'compare-with-self   ;; copy
                          graph-strings
                          (make-list (length graph-strings) :initial-element verbose)
                          ))
         (pass (every #'identity results)))
    (cond (pass)
          (t (list results graph-strings )))))


(defparameter proc-string000 "[girl]<-(agnt)<-[eat]->(obj)->[pie].")
(defparameter proc-string010 "[GIRL:Sue]<-(AGNT)<-[EAT]->(MANR)->[FAST].")
(defparameter proc-string020 "[PERSON:Sue]<-(AGNT)<-[EAT]->(OBJ)->[PIE].")
(defparameter proc-string030 "[PERSON: Sue]<-(AGNT)<-[EAT]->(OBJ)->[PIE].")

(defun test-copy-graph (graph1-string)
  (let* ((graph1 (parse-cgraph graph1-string))
         (copy (copy-cgraph graph1))
         (copy-format (expand-arrows (format-cgraph copy)))
         (result (string-equal (remove #\space graph1-string)
                               (remove #\space copy-format))))
    (cond (result
           (when *verbose*
             (format t "~%tested ~s: passed" graph1-string))
           t)
          (t
           (format t "~%~s" graph1-string)
           (format t "~%~s" copy-format)
           (format t "~%... failed")
           nil))))

(defun test-copy (&optional verbose)
  (let ((*verbose* verbose))
    (format t "~2&test copy")
    (every #'identity
           (mapcar #'test-copy-graph
                   (list proc-string000 proc-string010
                         proc-string020 proc-string030)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  restrict  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;; (restrict-concept (pcg "[animal: Spot]") (get-concept-type 'dog))
;;; (setf indiv (make-individual (get-concept-type 'dog) '(:name "Spot")))
;;; (setf con1 (make-concept 'animal indiv))
;;; (restrict con1 'dog)
;;; (restrict con1 (get-concept-type 'dog))
;;; (test-restrict-concept (pcg "[animal: Spot]") (get-concept-type 'dog))

;; (let* ((indiv (make-individual (get-concept-type 'dog) '(:name "Spot")))
;;        (con1 (make-concept 'animal indiv)))
;;   (format t "~&con1: ~s~%"  con1)   ; debug
;;   (restrict con1 (get-concept-type 'dog))
;;   (format t "~&con1: ~s~%"  con1)   ; debug)


(defmethod test-restrict-concept ((concept concept) (restriction concept-type))
  (let ((ctype (concept-type concept)))
    (restrict concept restriction)
    (and
     (types-equal restriction (concept-type concept))
     (subtype-p (concept-type concept) ctype)
     )))

(defmethod test-restrict-concept ((concept concept) (restriction list))
  (when (generic-p concept)
    (let ((individual (get-individual (concept-type concept) restriction)))
      (setf (individual concept) individual))
    concept))

(defmethod test-restrict-concept ((concept concept) (restriction string))
  (when (generic-p concept)
    (let* ((individual (get-individual (concept-type concept) (parse-properties restriction)))
           ;;(individual (setf (individual concept) individual))
           )
      (setf (individual concept) individual)
      concept)))

(defun test-restrict (&optional verbose)
  verbose
  (not (null
        (and
         (test-restrict-concept (make-concept 'animal nil) (get-concept-type 'dog))
         (not (test-restrict-concept (make-concept 'dog nil) (get-concept-type 'animal)))
         (test-restrict-concept (make-concept 'dog nil) '(:name "Spot"))
         (test-restrict-concept (make-concept 'dog nil) "Spot#3")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  merge  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-merge0 ()
  (initialize-cgraph)
  (setq *debug-mode* t)
  (let (g1 g2 g3 g4 c1 c2 c3 c4 s1 s2 s3 s4)
    g1 g2 g3 g4 c1 c2 c3 c4 s1 s2 s3 s4
    (setq g1 (parse-cgraph "[girl]<-(agnt)<-[eat]->(manr)->[fast]"))
    (setq g2 (parse-cgraph "[person:Sue]<-(agnt)<-[eat]->(obj)->[pie]"))
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
         ;;(ignore (clear-concept-cache))
         (g1 (pcg s1))
         (ignore (clear-concept-cache))
         (g2 (pcg s2))
         (p1 (pcg g1))
         (p2 (pcg g2)))
    ignore
    ;;(declare (ignore ignore))
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
  (initialize-cgraph)
  (setq *debug-mode* nil)
  (let* ((s1 "[drive]->(inst)->[Chevy:#3]->(attr)->[old].")
         (s2 "[drive]->(inst)->[conveyance]->(attr)->[old].")
         (ignore1 (clear-concept-cache))
         (g1 (pcg s1))
         (ignore2 (clear-concept-cache))
         (g2 (pcg s2))
         (p1 (pcg g1))
         (p2 (pcg g2))
         (c0 (find-concept 'chevy g1 :id 3))
         (c1 (car (find-concepts 'chevy g1)))
         (c2 (car (find-concepts 'conveyance g2)))
         (c3 (combine-concepts c0 c2))
         (c4 (combine-concepts c1 c2))
         (head (head-node g1))
         copy
         )
    (declare (ignore ignore1 ignore2))
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
;;  ;;  join  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun test-join1 ()
  (initialize-cgraph)
  (format t "~2&test-join1")
  (let* ((graph1-string "[EAT]->(AGNT)->[CAT].")
         (graph2-string "[EAT]- (AGNT)->[ANIMATE] (OBJ)->[FOOD].")
         (zz (format t "~&joining:~&~5t~a~&~5t~a~%" graph1-string graph2-string))
         (graph1 (pcg graph1-string))
         (graph2 (pcg graph2-string))
         (cat-con (find-concept 'cat graph1))
         ;;(animate-con (find-concept 'animate graph1 :properties '(:name "Puff")))
         (animate-con (find-concept 'animate graph2))
         )
    (declare (ignore zz))
    (format t "~&cat-con: ~s~%"  cat-con)
    (format t "~&animate-con: ~s~%"  animate-con)

    (print "before")
    (restrict cat-con animate-con)
    (print "after")


    ;;(format t "~&graph1: ~s"  (pcg graph1))
    (join-graph (join graph1 graph2))
    )

  ;;(format t "~&restricting-join: ~s" (format-cgraph join-graph :initial-indent 18))
  )




(defun test-join2 ()
  (initialize-cgraph)
  (format t "~2&test-join0")
  (let* ((graph1-string "[cat]<-(agnt)<-[eat]->(manr)->[fast].")
         (graph1 (pcg graph1-string))
         (s1 (pcg graph1))
         (zz1 (format t "~%s1: ~s" s1))

         (graph2-string "[animate: Puff]<-(agnt)<-[eat]->(obj)->[food].")
         (graph2 (pcg graph2-string))
         (s2 (pcg graph2))
         (zz2 (format t "~%s2: ~s" s2))
         (zz3 (format t "~%"))

         ;;(eat1 (find-concept 'eat graph1))
         ;;(se1 (pcg eat1))
         ;;(zz (format t "~%se1: ~s" se1))

         ;;(eat2 (find-concept 'eat graph2))
         ;;(se2 (pcg eat2))
         ;;(zz (format t "~%se2: ~s" se2))
         ;;(zz (format t "~%"))

         (zz4 (combine-concepts graph1 graph2))
         (zz5 (format t "~%merge1: ~s" (pcg graph1)))

         ;;(z2 (combine-concepts eat1 eat2))
         (zz7 (simplify-from-node graph1))
         (zz8 (format t "~%merge2: ~s" (pcg graph1)))
         (zz9 (format t "~%")))
    zz1 zz2 zz3 zz4 zz5  zz7 zz8 zz9))

(defun test-join3 ()
  (format t "~2&test-join3")
  (let (g1 g2 g3)
    (initialize-cgraph)
    (setq g1 (parse-cgraph "[girl]<-(agnt)<-[eat]->(manr)->[fast]"))
    (setq g2 (parse-cgraph "[person:Sue]<-(agnt)<-[eat]->(obj)->[pie]"))
    (format t "~&g1: ~s" (pcg g1))
    (format t "~&g2: ~s" (pcg g2))
    (setq g3 (join-cgraphs g1 g2))
    (format t "~&g3: ~s" (pcg g3))
    (print-cgraph g3)))


(defun test-join4 ()
  (format t "~2&test-join4")
  (let* ((s1 "[pie]<-(obj)<-[eat]->(agnt)->[animate].")
         (s2 "[eat]- (obj)->[food] (agnt)->[dog:#].")
         (p1 (parse-cgraph s1))
         (p2 (parse-cgraph s2))
         (object-relation (find-object-in-list "OBJ" (arcs p1)))
         (concept (traverse-relation object-relation p1))
         (p3 (join-cgraphs concept p2)))
    (print-cgraph p3)
    ))


(defun test-join5 ()
  (format t "~2&test-join5")

  (let* ((graph1-string "[EAT]->(AGNT)->[CAT: #].")
         (graph2-string "[EAT]- (AGNT)->[ANIMATE] (OBJ)->[FOOD].")
         (zz (format t "~&joining:~&~3t- ~a~&~3t- ~a" graph1-string graph2-string))
         (graph1 (parse-cgraph graph1-string))
         (graph2 (parse-cgraph graph2-string))
         (join-graph (join-cgraphs graph1 graph2)))
    (declare (ignore zz))
    (format t "~&~s" (format-cgraph join-graph))))



(defun test-join ()
  (test-join1)
  (test-join2)
  (test-join3)
  (test-join4)
  (test-join5))








;; (defun join-test (graph1-string graph2-string)
;;   (format t "~2&test join")
;;   (format t "~&joining:~&~5t~a~&~5t~a" graph1-string graph2-string)
;;   (let* ((graph1 (parse-cgraph graph1-string))
;;          (graph2 (parse-cgraph graph2-string))
;;          (join-graph (join-cgraphs graph1 graph2)))
;;     (format t "~&join:~%~s" (format-cgraph join-graph))
;;     t))

;; (defun test-join1 ()
;;   (join-test "[EAT]->(AGNT)->[CAT: #]."
;;              "[EAT]- (AGNT)->[ANIMATE] (OBJ)->[FOOD]."))


;; (defun test-join2 ()
;;   (join-test "[CAT: #]<-(AGNT)<-[EAT]."
;;              "[ANIMATE]<-(AGNT)<-[EAT]- (OBJ)->[FOOD]."))

;; (defun test-join ()
;;   (test-join1)
;;   (test-join2))










;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  simplify  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



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

        (setq join-result1 (join-cgraphs graph1 graph2))
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

        (setq join-result2 (join-cgraphs head1 head2))
        (format t "~&~%Graphs are joined at 'girl'")
        (format t "~&~%")
        (setq simplify-result2 (simplify-cgraph join-result2))
        (print-cgraph join-result2 :stream *terminal-io*)
        (print-cgraph simplify-result2 :stream *terminal-io*)

        (values)))))


(defun copy-cgraph-test (graph)
  (let ((copy (copy-cgraph graph)))
    (let ((collected-graph (collect-concepts graph))
	  (collected-copy (collect-concepts copy)))
      (unmark-graph graph)
      (null (intersection collected-graph collected-copy :test #'nodes-eq)))))

(defun JOIN-TEST ()
  ;;(untrace)					;diag
  (let* ((graph-string-1 "[eat]- (agnt)->[person] (manr)->[old].")
	 (graph-string-2 "[act]- (agnt)->[girl] (obj)->[pie].")
	 (graph1 (parse-cgraph graph-string-1))
	 (graph2 (parse-cgraph graph-string-2))
	 join-result)
    (format t "~&~%Source graphs:")
    (format t "~&~%")
    (print-cgraph graph1 :stream *terminal-io*)
    ;;(print (pcg graph1) *terminal-io*)
    (format t "~&~%")
    (print-cgraph graph2 :stream *terminal-io*)
    ;;(print (pcg graph2) *terminal-io*)
    (setq join-result (join-cgraphs graph1 graph2))
    (format t "~&~%Graphs are joined")
    (format t "~&~%")
    (print-cgraph join-result :stream *terminal-io*)
    ;;(print (pcg join-result) *terminal-io*)
    join-result))


;; (defun SIMPLIFY-TEST ()
;;   ;;(untrace)					;diag
;;   (let* ((graph-string-1 "[eat]- (agnt)->[girl] (manr)->[fast].")
;; 	 (graph-string-2 "[eat]- (agnt)->[girl] (obj)->[pie].")
;; 	 (graph1 (parse-cgraph graph-string-1))
;; 	 (graph2 (parse-cgraph graph-string-2))
;; 	 join-result simplify-result)
;;     (format t "~&~%Source graphs:")
;;     (format t "~&~%")
;;     (print-cgraph graph1 :stream *terminal-io*)
;;     ;;(print (pcg graph1) *terminal-io*)
;;     (format t "~&~%")
;;     (print-cgraph graph2 :stream *terminal-io*)
;;     ;;(print (pcg graph2) *terminal-io*)
;;     (setq join-result (join-cgraphs graph1 graph2))
;;     (format t "~&~%Graphs are joined")
;;     (format t "~&~%")
;;     (print-cgraph join-result :stream *terminal-io*)
;;     ;;(print (pcg join-result) *terminal-io*)
;;     (setq simplify-result (simplify-cgraph join-result))
;;     (format t "~&~%Graph is simplified")
;;     (format t "~&~%")
;;     (print-cgraph simplify-result :stream *terminal-io*)
;;     ;;(print (pcg simplify-result) *terminal-io*)
;;     simplify-result))


#+nil
(pcg (join-cgraphs
      (pcg "[dog]<-(agnt)<-[eat]->(obj)->[food].")
      (pcg "[dog]<-(agnt)<-[walk].")))



(defun test-formation-rules ()
  (prog1
      (every #'identity
             (list
              (test-copy)
              (test-restrict)
              ;;(test-merge)
              ;;(test-join)
              ))
    (untrace)
    ))


#|
(progn (untrace)
       (let ((d (make-individual 'dog)))
         (print (id d))
         (record-individual d)
         (format-individual d)))

(progn (untrace)
       (let ((d (make-individual 'dog '(:name "spot"))))
         (print (id d))
         (record-individual d)
         (format-individual d)))

(progn (untrace)
       (let ((d (make-individual 'dog '(:name "spot" :id 678))))
         (print (id d))
         (record-individual d)
         (format-individual d)))




|#


(defun info (string)
  (let* ((obj (pcg string))
        (ref (referent obj))
        (num (node-ref obj)))
    (print (list obj ref num))))

;; (defun test (string)
;;   (setq x1 (pcg string))
;;   (setq x2 (collect-concepts x1))
;;   (setq z1 (pcg string))
;;   (setq z2 (collect-concepts z1))

;;   (print x2)
;;   (print (mapcar #'node-ref x2))
;;   (print (mapcar #'(lambda (x) (equal (referent x) "")) x2))
;;   (print z2)
;;   (print (mapcar #'node-ref z2))
;;   (print (mapcar #'(lambda (x) (equal (referent x) "")) z2))

;;   ;;(mapcar (lambda (num1 num2
;;   nil)


(defun copy-check (in-string &optional verbose)
  (let*((graph1 (pcg in-string))
        (collection1 (collect-concepts graph1))
        (graph2 (pcg in-string))
        (collection2 (collect-concepts graph2)))

    (when verbose
      (format t "~%~a" in-string)
      (format t "~%concepts1: ~s" collection1)
      (format t "~%concepts2: ~s" collection2))


    (mapcar (lambda (c1 c2)
              (format t "~2%" )
              (format t "~&(equal ~a ~a): ~a" c1 c2 (equal c1 c2))
              (format t "~&(eq    ~a ~a): ~a" c1 c2 (eq c1 c2))
              )


            collection1 collection2)))



;; (defun test-copy (&optional verbose)
;;   (let* ((graph-string000 "[DOG: Spot]<-(agnt)<-[EAT].")
;;          (graph-string010 "[DOG: Spot]<-(agnt)<-[EAT]->(obj)->[CAKE].")
;;          (graph-string020 "[DOG: Spot]<-(agnt)<-[EAT]- (obj)->[CAKE] (manr)->[FAST].")
;;          (graph-string030 "[PERSON: Sue]<-(agnt)<-[GIVE]-
;;                                         (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*z]
;;                                         (obj)->[FOOD]<-(obj)<-[EAT:*z].")
;;          (graph-string040 "[PERSON: Sue]<-(agnt)<-[GIVE]-
;;                            (rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*z]
;;                            (inst)->[FOOD]<-(obj)<-[EAT:*z]->(manr)->[FAST].")
;;          (graph-string050 "[DOG:Spot]-
;;                                (poss)->[CAKE]<-(obj)<-[EAT:*z]
;;                                (agnt)<-[EAT:*z].")
;;          (graph-string060 "[GIVE]-
;;                              (agnt)->[PERSON: Sue]
;;                              (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *z]
;;                              (inst)->[FOOD]<-(obj)<-[EAT: *z].")
;;          (graph-string070 "[PERSON: Sue]<-(agnt)<-[GIVE]-
;;                              (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *z]
;;                              (inst)->[FOOD]<-(obj)<-[EAT: *z].")

;;          (graph-strings (list graph-string000 graph-string010 graph-string020 graph-string030
;;                               graph-string040 graph-string050 graph-string060 graph-string070)))

;;     (every #'identity (mapcar #'(lambda (x) (copy-check x verbose)) graph-strings))))


;;;(copy-check "[DOG: Spot]<-(agnt)<-[EAT]- (obj)->[CAKE] (manr)->[FAST]." t)


(defun combine-test ()
  (let* ((str1 "[girl]<-(agnt)<-[eat]->(manr)->[fast]")
         (str2 "[person: Sue]<-(agnt)<-[eat]->(obj)->[pie]")
         (g1 (pcg str1))
         (g2 (pcg str2)))
    (let ((girl-con g1)
          (person-con g2)
          (eat1-con (find-concept 'eat g1))
          (eat2-con (find-concept 'eat g2)))
      (restrict person-con 'girl)

      (format t "~&g1: ~s~%"  (pcg g1))   ; debug
      (format t "~&g2: ~s~%"  (pcg g2))   ; debug

      ;;(join eat1-con eat2-con)

      )))





;; (setq str1 "[girl]<-(agnt)<-[eat]->(manr)->[fast]")
;; (setq str2 "[person: Sue]<-(agnt)<-[eat]->(obj)->[pie]")

(defun demo-join ()
  ;;(setf *INCLUDE-NODE-REF* t)
  (setq graph1-string "[cat]<-(agnt)<-[eat]->(manr)->[fast].")
  (setq graph1 (pcg graph1-string))
  (format t "~&: ~a~%" (pcg graph1))

  (setq graph2-string "[animate: Puff]<-(agnt)<-[eat]->(obj)->[food].")
  (setq graph2 (pcg graph2-string))
  (format t "~&: ~a~%" (pcg graph2))

  (restrict graph1 graph2)

  (setq eat1 (find-concept 'eat graph1))
  (setq eat2 (find-concept 'eat graph2))
  (restrict eat1 eat2)

  (join  graph1 graph2)
  (join  eat1 eat2)

  (simplify-cgraph graph1)

  (format t "~&~a ~a~%" right-arrow (pcg graph1))
  (pcg graph1))
