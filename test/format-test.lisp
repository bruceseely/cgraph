;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Testing formatting of conceptual graphs
;;;

(in-package #:conceptual-graphs)

(defun init-format-test-nodes ()
  (clear-id-cache)
  (initialize-variables)

  ;; make individuals
  (defparameter spot-indiv    (ensure-test-individual 'dog '(:name "Spot")))
  (defparameter spot-con      (make-concept (get-concept-type 'dog) (make-referent spot-indiv)))

  (defparameter sue-indiv    (ensure-test-individual 'person '(:name "Sue")))
  (defparameter sue-con      (make-concept (get-concept-type 'person) (make-referent sue-indiv)))

  (defvar spotz-con )
  (defvar suez-con  )

  (let ((*allow-dynamic-individual-creation* t))
    (setf spotz-con  (make-concept (get-concept-type 'dog) (list* :id 24 '(:name "Spotz"))))
    (setf suez-con   (make-concept (get-concept-type 'person)  (list* :id 27 '(:name "Suez")))))

  ;;concepts
  (defparameter cake-con   (make-concept 'cake ()))
  (defparameter eat-con    (make-concept 'eat ()))
  (defparameter quickly-con   (make-concept 'quickly ()))
  (defparameter food-con   (make-concept 'food ()))
  (defparameter give-con   (make-concept 'give ()))

  (defparameter person-con   (make-concept 'person ()))
  (defparameter rock-con     (make-concept 'rock ()))
  (defparameter place-con    (make-concept 'place ()))
  (defparameter hard-con     (make-concept 'hard ()))

  ;; relations
  (defparameter agnt-rel  (make-relation 'agnt))
  (defparameter agnt1-rel (make-relation 'agnt))
  (defparameter agnt2-rel (make-relation 'agnt))
  (defparameter inst-rel  (make-relation 'inst))
  (defparameter manr-rel  (make-relation 'manr))
  (defparameter obj-rel   (make-relation 'obj))
  (defparameter obj1-rel  (make-relation 'obj))
  (defparameter obj2-rel  (make-relation 'obj))
  (defparameter poss-rel  (make-relation 'poss))
  (defparameter rcpt-rel  (make-relation 'rcpt))

  (defparameter attr-rel  (make-relation 'attr))
  (defparameter attr-rel  (make-relation 'attr))
  )


(defun setup0 ()
  (init-format-test-nodes)
  (let ((graph-string "[DOG: Spot]<-(agnt)<-[EAT]."))
    ;;(format t "~s~&"  graph-string)

    ;; [eat]->(agnt)->[dog]
    (add-arc-into-relation  eat-con  agnt-rel)
    (set-arc-from-relation agnt-rel spot-con)

    (values spot-con graph-string)))


;;; linear
(defun setup1 ()
  (init-format-test-nodes)
  (let ((graph-string "[DOG: Spot]<-(agnt)<-[EAT]->(obj)->[CAKE]."))

  ;; [eat]->(agnt)->[dog]
  (add-arc-into-relation  eat-con  agnt-rel)
  (set-arc-from-relation agnt-rel spot-con)

  ;; [eat]->(obj)->[cake]
  (add-arc-into-relation  eat-con obj-rel)
  (set-arc-from-relation obj-rel cake-con)

  (values spot-con graph-string)))


;;; fork
(defun setup2 ()
  (init-format-test-nodes)
  (let ((graph-string "[DOG: Spot]<-(agnt)<-[EAT]-
                         (manr)->[QUICKLY]
                         (obj)->[CAKE] ."))

  ;; [eat]->(agnt)->[dog]
  (add-arc-into-relation eat-con agnt-rel)
  (set-arc-from-relation agnt-rel spot-con)

  ;; [eat]->(obj)->[cake]
  (add-arc-into-relation eat-con obj-rel)
  (set-arc-from-relation obj-rel cake-con)

  ;; [eat]->(manr)->[quickly]
  (add-arc-into-relation eat-con manr-rel)
  (set-arc-from-relation manr-rel quickly-con)

  (values spot-con graph-string)))


;;"[PERSON: Sue:#26]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: Sue#26]."
;; (format-cgraph (parse-cgraph "[PERSON: Sue#26]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: Sue#26]."))
;; (format-cgraph (parse-cgraph "[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z]."))
;;;
;;; (setq *node-ref* t)

;;; loop





(defun setup3 ()
  (init-format-test-nodes)
  (let ((graph-string "[PERSON: Sue]<-(agnt)<-[GIVE]-
                           (obj)->[FOOD]<-(obj)<-[EAT:*x]
                           (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*x] ."))


    ;; [give]->(agnt)->[person]
    (add-arc-into-relation give-con agnt1-rel)
    (set-arc-from-relation agnt1-rel sue-con)

    ;; [give]->(rcpt)->[dog]
    (add-arc-into-relation give-con rcpt-rel)
    (set-arc-from-relation rcpt-rel spot-con)

    ;; [give]->(obj)->[food]
    (add-arc-into-relation give-con obj1-rel)
    (set-arc-from-relation obj1-rel food-con)

    ;; [eat]->(obj)->[food]
    (add-arc-into-relation eat-con obj2-rel)
    (set-arc-from-relation obj2-rel food-con)

    ;; [eat]->(agnt)->[dog]
    (add-arc-into-relation eat-con agnt2-rel)
    (set-arc-from-relation agnt2-rel spot-con)

    ;; add variables
    (set-variable eat-con 'x)

    (values sue-con graph-string)))






;; (defun setup4 ()
;;   (init-format-test-nodes)
;;   (let ((graph-string "[PERSON: Sue]<-(agnt)<-[GIVE]-
;;                            (inst)->[FOOD]<-(obj)<-[EAT:*x]
;;                            (rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*x]->(manr)->[QUICKLY]."))

;;     ;; [give]->(agnt)->[person]
;;     (add-arc-into-relation give-con agnt1-rel)
;;     (set-arc-from-relation agnt1-rel sue-con)

;;     ;; [eat]->(obj)->[cake]
;;     (add-arc-into-relation give-con rcpt-rel)
;;     (set-arc-from-relation rcpt-rel spot-con)

;;     ;; [give]->(inst)->[food]
;;     (add-arc-into-relation give-con inst-rel)
;;     (set-arc-from-relation inst-rel food-con)

;;     ;; [eat]->(obj)->[food]
;;     (add-arc-into-relation eat-con obj1-rel)
;;     (set-arc-from-relation obj1-rel food-con)

;;     ;; [eat]->(agnt)->[dog]
;;     (add-arc-into-relation eat-con agnt2-rel)
;;     (set-arc-from-relation agnt2-rel spot-con)

;;     ;; added to setup4
;;     ;; [eat]->manr)->[quickly]
;;     (add-arc-into-relation eat-con manr-rel)
;;     (set-arc-from-relation manr-rel quickly-con)

;;     ;; add variables
;;     ;;(set-variable eat-con)

;;     (values sue-con graph-string)))


(defun setup4 ()
  (init-format-test-nodes)
  (let ((graph-string "[PERSON: Sue]<-(agnt)<-[GIVE]-
                           (inst)->[FOOD]<-(obj)<-[EAT:*x]->(manr)->[QUICKLY]
                           (rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*x]."))

    ;;[PERSON: Sue]<-(agnt)<-[GIVE]
    (set-arc-from-relation sue-con agnt1-rel)
    (add-arc-into-relation agnt1-rel give-con)

    ;;[GIVE]->(inst)->[FOOD]<-(obj)<-[EAT:*x]
    (add-arc-into-relation give-con inst-rel )
    (set-arc-from-relation inst-rel food-con)
    (set-arc-from-relation food-con obj-rel)
    (add-arc-into-relation obj-rel eat-con)

    ;;[GIVE]->(rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*x]->(manr)->[QUICKLY]."))
    (add-arc-into-relation give-con rcpt-rel )
    (set-arc-from-relation rcpt-rel spot-con)
    (set-arc-from-relation spot-con agnt-rel)
    (add-arc-into-relation agnt-rel eat-con)
    (add-arc-into-relation eat-con manr-rel)
    (set-arc-from-relation manr-rel quickly-con)

    ;; add variables -- can't this be calculated??
    (set-variable eat-con)

    (values sue-con graph-string)))


;;; circle
;;; Spot can have his cake and eat it too
(defun setup5 ()
  (init-format-test-nodes)
  (let ((graph-string "[DOG: Spot]-
                           (agnt)<-[EAT]->(obj)->[CAKE: *x]
                           (poss)->[CAKE: *x]."))

    ;; [dog]->(poss)->[cake]
    (add-arc-into-relation  spot-con  poss-rel)
    (set-arc-from-relation poss-rel cake-con)

    ;; [eat]->(agnt)->[dog]
    (add-arc-into-relation  eat-con  agnt-rel)
    (set-arc-from-relation agnt-rel spot-con)

    ;; [eat]->(obj)->[cake]
    (add-arc-into-relation  eat-con obj-rel)
    (set-arc-from-relation obj-rel cake-con)

    ;; add variables
    ;;(set-variable cake-con)

    (values spot-con graph-string)))


;;; same graph as setup5, with adifferent head
(defun setup6 ()
  (init-format-test-nodes)
  (let ((graph-string "[PERSON: Sue]<-(agnt)<-[GIVE]-
                           (inst)->[FOOD]<-(obj)<-[EAT: *x]
                           (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *x] ."))

    ;; [person]<-(agnt)<-[give]
    (add-arc-into-relation give-con agnt1-rel)
    (set-arc-from-relation agnt1-rel sue-con)

    ;; [give]->(rcpt)->[dog]
    (add-arc-into-relation give-con rcpt-rel)
    (set-arc-from-relation rcpt-rel spot-con)

    ;; [dog]<-(agnt)<-[eat]
    (add-arc-into-relation eat-con agnt2-rel)
    (set-arc-from-relation agnt2-rel spot-con)

    ;; [give]->(inst)->[food]
    (add-arc-into-relation give-con inst-rel)
    (set-arc-from-relation inst-rel food-con)

    ;; [food]<-(obj)<-[eat]
    (add-arc-into-relation eat-con obj1-rel)
    (set-arc-from-relation obj1-rel food-con)

    ;; add variables
    (set-variable eat-con 'x)

    (values sue-con graph-string)))

(defun setup7 ()
  (init-format-test-nodes)
  (let ((graph-string "[GIVE]-
   (agnt)->[PERSON:Sue]
   (inst)->[FOOD]<-(obj)<-[EAT:*x]
   (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*x] ."))

    ;; [give]->(agnt)->[person: Sue]
    (add-arc-into-relation give-con agnt1-rel)
    (set-arc-from-relation agnt1-rel sue-con)

    ;; [give]->(rcpt)->[dog: Spot]
    (add-arc-into-relation give-con rcpt-rel)
    (set-arc-from-relation rcpt-rel spot-con)

    ;; [give]->(inst)->[food]
    (add-arc-into-relation give-con inst-rel)
    (set-arc-from-relation inst-rel food-con)

    ;; [eat]->(obj)->[food]
    (add-arc-into-relation eat-con obj1-rel)
    (set-arc-from-relation obj1-rel food-con)

    ;; [eat]->(agnt)->[dog]
    (add-arc-into-relation eat-con agnt2-rel)
    (set-arc-from-relation agnt2-rel spot-con)

    ;; add variables
    ;;(set-variable eat-con)

    (values give-con graph-string)))


;; circle
(defun setup8 ()
  (init-format-test-nodes)
  (let ((graph-string "[GIVE]-
   (agnt)->[PERSON: Sue]
   (inst)->[FOOD]<-(obj)<-[EAT: *x]
   (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *x] ."))

    ;; [give]->(agnt)->[person]
    (add-arc-into-relation give-con agnt1-rel)
    (set-arc-from-relation agnt1-rel sue-con)

    ;; [give]->(rcpt)->[dog]
    (add-arc-into-relation give-con rcpt-rel)
    (set-arc-from-relation rcpt-rel spot-con)

    ;; [give]->(inst)->[food]
    (add-arc-into-relation give-con inst-rel)
    (set-arc-from-relation inst-rel food-con)

    ;; [eat]->(obj)->[food]
    (add-arc-into-relation eat-con obj1-rel)
    (set-arc-from-relation obj1-rel food-con)

    ;; [eat]->(agnt)->[dog]
    (add-arc-into-relation eat-con agnt2-rel)
    (set-arc-from-relation agnt2-rel spot-con)

    ;; add variables
    ;;(set-variable eat-con)

    (values give-con graph-string)))



(defun setup9 ()
  (init-format-test-nodes)

  (let ((*allow-dynamic-individual-creation* t))
    ;;(format t "~&> *allow-dynamic-individual-creation*: ~s~%"  *allow-dynamic-individual-creation*)
    (when *allow-dynamic-individual-creation*
      (setf spotz-con  (make-concept (get-concept-type 'dog) (list* :id 24 '(:name "Spotz"))))
      (setf suez-con   (make-concept (get-concept-type 'person)  (list* :id 27 '(:name "Suez")))))

    (format t "~%suez-con~%")
    (describe suez-con)

    (let ((graph-string "[GIVE]-
                          (agnt)->[PERSON: Suez]
                          (inst)->[FOOD]<-(obj)<-[EAT: *x]
                          (rcpt)->[DOG: Spotz]<-(agnt)<-[EAT: *x]."))

      ;; [give]->(agnt)->[person]
      (add-arc-into-relation give-con agnt1-rel)
      (set-arc-from-relation agnt1-rel suez-con)

      ;; [give]->(rcpt)->[dog]
      (add-arc-into-relation give-con rcpt-rel)
      (set-arc-from-relation rcpt-rel spotz-con)

      ;; [give]->(inst)->[food]
      (add-arc-into-relation give-con inst-rel)
      (set-arc-from-relation inst-rel food-con)

      ;; [eat]->(obj)->[food]
      (add-arc-into-relation eat-con obj1-rel)
      (set-arc-from-relation obj1-rel food-con)

      ;; [eat]->(agnt)->[dog]
      (add-arc-into-relation eat-con agnt2-rel)
      (set-arc-from-relation agnt2-rel spotz-con)

      ;; add variables
      ;;(set-variable eat-con)

      (values give-con graph-string))))


(defun ftest (test-number)
  (reset-cgraph)
  (setf *context* (make-context))
  (let* ((*print-pretty* nil)
         (setup-sym (intern (format nil "SETUP~d" test-number) :cg)))

    (when (ignore-errors (symbol-function setup-sym))
      (let ((setup-fn (symbol-function setup-sym)))
        (setf *fn setup-fn)
        (multiple-value-bind (graph graph-string)
            (funcall setup-fn)

          (print "hi")
          (let* ((linear2 (without-node-ref (arrows-to-ascii (format-cgraph graph))))
                 (pass (graph-strings-equal graph-string linear2)))

            (values pass graph-string linear2)))))))


(defun format-test (&optional verbose)
  (with-test-types
  (when verbose (format t "~%FORMAT-TEST~%"))
  (let ((collect (list))
        (failed (list))
        (*concise* t))
    (dotimes (i 10)
      (let ((test-number (format nil "TEST-~d" i)))
        (when verbose
          (format t "~3&+=== TEST-~a  ========================================================== ~%" i))
        (init-format-test-nodes)
        (multiple-value-bind (pass initial result)
            (ftest i)
          (when (or (null pass) verbose)
            (format t "~&graph from...~&~a~%" initial)
            (format t "~2&formatted to...~&~a~%" result)

            (when (plusp (variable-count))
              (format t "~%Variables:")
              (variables-report))

            (format t "~%~a ~:[FAILED *******~;passed~]" test-number pass))
          (unless pass (push i failed))
          (push pass collect))))

    (let ((test-passed (every #'identity collect)))
      (when (and verbose (not test-passed))
        (format t "~2&failed: ~a~%"  (reverse (mapcar (lambda (n) (format nil "test-~a" n)) failed)))
        (dolist (test (reverse failed))
          (format t "~&  (ftest ~a)" test)))
      test-passed))))

#|

"[drive]-
       (agnt)->[person: bob]->(poss)->[chevy: *y]
       (inst)->[chevy: *y]->(attr)->[old]
       (dest)->[city: St. Louis]."
|#


;;; A graph inside a concept -- [PROPOSITION: [KNOW]- ...] -- is laid out on its
;;; own, from column 0, and its later lines used to keep that layout wherever
;;; the concept landed: under the outer graph's arcs, left of the head they
;;; belong to. Each must now appear exactly as it does on its own, moved over to
;;; the column its first line starts at, at every depth -- and read back the same.

(defun nested-graph-layout-test (&optional verbose)
  (with-test-types
    (let* ((*allow-dynamic-individual-creation* t)
           (inner "[EAT]-(agnt)->[PERSON: Ann](obj)->[PIE]")
           (middle (format nil "[KNOW]-(expr)->[PERSON: Dave](stat)->[PROPOSITION: ~a]" inner))
           (outer (format nil "[KNOW]-(expr)->[PERSON: Sue](stat)->[PROPOSITION: ~a]" middle))
           (ok t))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label)))
             (text (string)
               ;; no trailing period: these are compared as pieces of a whole
               (string-right-trim "." (format-cgraph (parse-cgraph string))))
             (column-of (needle text)
               ;; column of the last occurrence of NEEDLE, within its own line
               (let* ((at (search needle text :from-end t))
                      (line-start (let ((nl (position #\Newline text :end at :from-end t)))
                                    (if nl (1+ nl) 0))))
                 (- at line-start))))
        (dolist (*concise* '(nil t))
          (let* ((whole (text outer))
                 (alone-inner (text inner))
                 (alone-middle (text middle)))
            (when verbose (format t "~&~a~%" whole))
            (check (format nil "the innermost graph keeps its own layout, moved under [EAT (concise ~a)"
                           *concise*)
                   (search (indent-embedded-lines alone-inner (column-of "[EAT" whole)) whole))
            (check (format nil "the middle graph keeps its own layout, moved under [KNOW (concise ~a)"
                           *concise*)
                   (search (indent-embedded-lines alone-middle (column-of "[KNOW" whole)) whole))
            (check (format nil "it reads back the same (concise ~a)" *concise*)
                   (equal whole (text whole)))))
        (let ((negated (let ((*concise* nil))
                         (text (format nil "[PERSON: Sue]<-(expr)<-[KNOW]->(stat)->~~[PROPOSITION: ~a]"
                                       inner)))))
          (when verbose (format t "~&~a~%" negated))
          (check "a negated context's graph sits under its head too"
                 (search (indent-embedded-lines (let ((*concise* nil)) (text inner))
                                                (column-of "[EAT" negated))
                         negated))))
      ok)))
