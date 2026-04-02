;;; -*- Mode; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)




(defvar agnt-rel)
(defvar agnt1-rel)
(defvar agnt2-rel)
(defvar attr-rel)
;;(defvar betw-rel)
(defvar dest-rel)
(defvar inst-rel)
(defvar manr-rel)
(defvar manr1-rel)
(defvar obj-rel)
(defvar obj1-rel)
(defvar obj2-rel)
(defvar poss-rel)
(defvar rcpt-rel)

(defvar cake-con)
(defvar chevy-con)
(defvar city-con)
(defvar drive-con)
(defvar eat-con)
(defvar quickly-con)
(defvar quickly1-con)
;; (defvar fast-con)
;; (defvar fast1-con)
(defvar food-con)
(defvar give-con)
(defvar hard-con)
(defvar old-con)
(defvar person-con)
(defvar place-con)
(defvar rock-con)
(defvar spot-con)
(defvar spotz-con)
(defvar sue-con)
(defvar suez-con)

(defvar spot-indiv)
(defvar sue-indiv)



(defun init-test-graphs ()
  (clear-id-cache)
  (initialize-variables)

  ;; make individuals
  (setf spot-indiv    (make-individual 'dog '(:name "Spot")))
  (setf spot-con      (make-concept (get-concept-type 'dog) (make-referent spot-indiv)))

  (setf sue-indiv    (make-individual 'person '(:name "Sue")))
  (setf sue-con      (make-concept (get-concept-type 'person) (make-referent sue-indiv)))

  (let ((*allow-dynamic-individual-creation* t))
    (setf spotz-con  (make-concept (get-concept-type 'dog)    (list* :id 24 '(:name "Spotz"))))
    (setf suez-con   (make-concept (get-concept-type 'person) (list* :id 27 '(:name "Suez")))))

  ;;concepts
  (setf chevy-con  (make-concept 'chevy-vehicle ()))
  (setf city-con   (make-concept 'city ()))
  (setf drive-con  (make-concept 'drive ()))
  (setf eat-con    (make-concept 'eat ()))
  (setf quickly-con   (make-concept 'quickly ()))
  (setf quickly1-con  (make-concept 'quickly ()))
  (setf food-con   (make-concept 'food ()))
  (setf give-con   (make-concept 'give ()))
  (setf hard-con   (make-concept 'hard ()))
  (setf old-con    (make-concept 'old ()))
  (setf person-con (make-concept 'person ()))
  (setf place-con  (make-concept 'place ()))
  (setf rock-con   (make-concept 'rock ()))
  (setf cake-con   (make-concept 'cake ()))

  ;; relations
  (setf agnt-rel  (make-relation 'agnt))
  (setf agnt1-rel (make-relation 'agnt))
  (setf agnt2-rel (make-relation 'agnt))
  (setf attr-rel  (make-relation 'attr))
  ;;(setf betw-rel  (make-relation 'betw))
  (setf dest-rel  (make-relation 'dest))
  (setf inst-rel  (make-relation 'inst))
  (setf manr-rel  (make-relation 'manr))
  (setf manr1-rel (make-relation 'manr))
  (setf obj-rel   (make-relation 'obj))
  (setf obj1-rel  (make-relation 'obj))
  (setf obj2-rel  (make-relation 'obj))
  (setf obj3-rel  (make-relation 'obj))
  (setf poss-rel  (make-relation 'poss))
  (setf rcpt-rel  (make-relation 'rcpt)))


(defmethod make-test-graph ((id number))
  (let ((sym (intern (format nil "TEST-GRAPH-~d" id))))
    (multiple-value-bind (graph text) (funcall sym)
      (set sym (list graph text)))))


(defmethod make-test-graphs ((id number))
  (dotimes (test-num id)
    (make-test-graph test-num)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  graph definitions  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-graph-0 ()
  (init-test-graphs)
  (let ((graph-string "[DOG: Spot]<-(agnt)<-[EAT]."))
    ;;(format t "~s~&"  graph-string)

    ;; [eat]->(agnt)->[dog]
    (add-arc-into-relation  eat-con  agnt-rel)
    (set-arc-from-relation agnt-rel spot-con)

    (values spot-con graph-string)))


;;; "[dog]<-(agnt)<-[eat]->(obj)->[food]."
;;; "[food]-
;;;       (obj)<-[give]-
;;;                 (agnt)->[person]
;;;                 (rcpt)->[dog: *z],
;;;       (obj)<-[eat]->(agnt)->[dog: *z]."
;;; "[dog: Fido]-
;;;      (agnt)<-[eat]-
;;;                (obj)->[food: *x]
;;;                (manr)->[quickly],
;;;      (rcpt)<-[give]-
;;;                (agnt)->[person]
;;;                (obj)->[food: *x]."
;;; "[Drive]-
;;;     (agnt)->[Person: Bob]->(POSS)->[Chevy-Vehicle: *y]
;;;     (dest)->[City: St. Louis]."



;; [dog: Fido]<-(agnt)<-[eat]-
;;                 (obj)->[food: *x]
;;                 (manr)->[quickly]

;;; linear
(defun test-graph-1 ()
  (init-test-graphs)
  (let ((graph-string "[DOG: Spot]<-(agnt)<-[EAT]->(obj)->[CAKE]."))

  ;; [eat]->(agnt)->[dog]
  (add-arc-into-relation  eat-con  agnt-rel)
  (set-arc-from-relation agnt-rel spot-con)

  ;; [eat]->(obj)->[cake]
  (add-arc-into-relation  eat-con obj-rel)
  (set-arc-from-relation obj-rel cake-con)

  (values spot-con graph-string)))

;;; fork  -- problem
(defun test-graph-2 ()
  (init-test-graphs)
  (let ((graph-string "[DOG: Spot]←(agnt)←[EAT]-
                         (manr)→[QUICKLY]
                         (obj)→[CAKE]."))

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





(defun test-graph-3 ()
  (init-test-graphs)
  (let ((graph-string "[PERSON: Sue]<-(agnt)<-[GIVE]-
                           (obj)->[FOOD]<-(obj)<-[EAT:*x]
                           (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*x]."))


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



(defun test-graph-4 ()
  (init-test-graphs)
  (let ((graph-string
          "[PERSON: Sue]<-(agnt)<-[GIVE]-
                                    (obj)->[FOOD]<-(obj)<-[EAT:*x]->(manr)->[QUICKLY]
                                    (rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*x].")
        )

    ;; [PERSON: Sue]<-(agnt)<-[GIVE]
    (set-arc-from-relation agnt1-rel sue-con)
    (add-arc-into-relation give-con agnt1-rel)

    ;; [GIVE]->(rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*x]
    (add-arc-into-relation give-con rcpt-rel)
    (set-arc-from-relation spot-con rcpt-rel)
    (set-arc-from-relation agnt2-rel spot-con)
    (add-arc-into-relation eat-con agnt2-rel)

    ;; [GIVE]->(obj)->[FOOD]<-(obj)<-[EAT:*x]
    (add-arc-into-relation give-con obj3-rel)
    (set-arc-from-relation food-con obj3-rel)
    (set-arc-from-relation food-con obj-rel)
    (add-arc-into-relation eat-con obj-rel)

    ;; [EAT:*x]->(manr)->[QUICKLY]
    (add-arc-into-relation eat-con manr-rel)
    (set-arc-from-relation quickly-con manr-rel)

    (set-variable eat-con 'x)
    (values sue-con graph-string)))



;;; circle -- problem
;;; Spot can have his cake and eat it too
(defun test-graph-5 ()
  (init-test-graphs)
  (let ((graph-string
          "[DOG: Spot]-
               (agnt)<-[EAT: *x]
               (poss)->[CAKE]<-(obj)<-[EAT: *x]."))

    ;; [dog]<-(agnt)<-[eat]->(obj)->[cake]
    (set-arc-from-relation spot-con  agnt-rel)
    (add-arc-into-relation agnt-rel  eat-con)
    (add-arc-into-relation eat-con  obj-rel)
    (set-arc-from-relation obj-rel  cake-con)

    ;; [dog]->(poss)->[cake]
    (add-arc-into-relation  spot-con  poss-rel)
    (set-arc-from-relation  poss-rel cake-con)

    (values spot-con graph-string)))



;;; same graph as test-graph-5, with adifferent head
(defun test-graph-6 ()
  (init-test-graphs)
  (let ((graph-string "[PERSON: Sue]<-(agnt)<-[GIVE]-
                           (obj)->[FOOD]<-(obj)<-[EAT: *x]
                           (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *x]."))

    ;; [person]<-(agnt)<-[give]
    (add-arc-into-relation give-con agnt1-rel)
    (set-arc-from-relation agnt1-rel sue-con)

    ;; [give]->(rcpt)->[dog]
    (add-arc-into-relation give-con rcpt-rel)
    (set-arc-from-relation rcpt-rel spot-con)

    ;; [dog]<-(agnt)<-[eat]
    (add-arc-into-relation eat-con agnt2-rel)
    (set-arc-from-relation agnt2-rel spot-con)

    ;; [give]->(obj)->[food]
    (add-arc-into-relation give-con obj2-rel)
    (set-arc-from-relation obj2-rel food-con)

    ;; [food]<-(obj)<-[eat]
    (add-arc-into-relation eat-con obj1-rel)
    (set-arc-from-relation obj1-rel food-con)

    ;; add variables
    (set-variable eat-con 'x)

    (values sue-con graph-string)))

(defun test-graph-7 ()
  (init-test-graphs)
  (let ((graph-string
          "[GIVE]-
              (agnt)->[PERSON:Sue]
              (obj)->[FOOD]<-(obj)<-[EAT:*x]
              (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*x]."))

    ;; [give]->(agnt)->[person: Sue]
    (add-arc-into-relation give-con agnt1-rel)
    (set-arc-from-relation agnt1-rel sue-con)

    ;; [give]->(rcpt)->[dog: Spot]<-(agnt)<-[EAT]
    (add-arc-into-relation give-con  rcpt-rel)
    (set-arc-from-relation rcpt-rel  spot-con)
    (set-arc-from-relation spot-con  agnt2-rel)
    (add-arc-into-relation agnt2-rel eat-con)

    ;; [give]->(obj)->[food]<-(obj)<-[EAT]
    (add-arc-into-relation give-con obj2-rel)
    (set-arc-from-relation obj2-rel food-con)
    (set-arc-from-relation food-con obj1-rel)
    (add-arc-into-relation obj1-rel eat-con)

    (values give-con graph-string)))



;; circle
(defun test-graph-8 ()
  (init-test-graphs)
  (let ((graph-string "[GIVE]-
   (agnt)->[PERSON: Sue]
   (obj)->[FOOD]<-(obj)<-[EAT: *x]
   (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *x]."))

    ;; [give]->(agnt)->[person]
    (add-arc-into-relation give-con agnt1-rel)
    (set-arc-from-relation agnt1-rel sue-con)

    ;; [give]->(rcpt)->[dog]
    (add-arc-into-relation give-con rcpt-rel)
    (set-arc-from-relation rcpt-rel spot-con)

    ;; [give]->(obj)->[food]
    (add-arc-into-relation give-con obj2-rel)
    (set-arc-from-relation obj2-rel food-con)

    ;; [eat]->(obj)->[food]
    (add-arc-into-relation eat-con obj1-rel)
    (set-arc-from-relation obj1-rel food-con)

    ;; [eat]->(agnt)->[dog]
    (add-arc-into-relation eat-con agnt2-rel)
    (set-arc-from-relation agnt2-rel spot-con)

    ;; add variables
    ;;(set-variable eat-con)

    (values give-con graph-string)))



(defun test-graph-9 ()
  (init-test-graphs)

  (when *allow-dynamic-individual-creation*
    (setf spotz-con  (make-concept (get-concept-type 'dog) (list* :id 24 '(:name "Spotz"))))
    (setf suez-con   (make-concept (get-concept-type 'person)  (list* :id 27 '(:name "Suez")))))

  (let ((graph-string "[GIVE]-
              (agnt)->[PERSON: Suez]
              (obj)->[FOOD]<-(obj)<-[EAT: *x]
              (rcpt)->[DOG: Spotz]<-(agnt)<-[EAT: *x]."))

    ;; [give]->(agnt)->[person]
    (add-arc-into-relation give-con agnt1-rel)
    (set-arc-from-relation agnt1-rel suez-con)

    ;; [give]->(rcpt)->[dog]
    (add-arc-into-relation give-con rcpt-rel)
    (set-arc-from-relation rcpt-rel spotz-con)

    ;; [give]->(obj)->[food]
    (add-arc-into-relation give-con obj2-rel)
    (set-arc-from-relation obj2-rel food-con)

    ;; [eat]->(obj)->[food]
    (add-arc-into-relation eat-con obj1-rel)
    (set-arc-from-relation obj1-rel food-con)

    ;; [eat]->(agnt)->[dog]
    (add-arc-into-relation eat-con agnt2-rel)
    (set-arc-from-relation agnt2-rel spotz-con)

    ;; add variables
    ;;(set-variable eat-con)

    (values give-con graph-string)))

;;; (trace format-segment-path format-segments-from-node format-segments format-path-tokens format-node)
;; (defun test-graph-10 ()
;;   (init-test-graphs)
;;   (let ((graph-string
;;           "[PERSON]<-(betw)-
;;                <-1-[ROCK]
;;                <-2-[PLACE]->(attr)->[HARD]."))

;;     (set-arc-from-relation person-con  betw-rel)
;;     (add-arc-into-relation betw-rel rock-con)
;;     (add-arc-into-relation betw-rel place-con)
;;     (add-arc-into-relation place-con attr-rel)
;;     (set-arc-from-relation attr-rel hard-con)
;;     (values person-con graph-string)))


(defun test-graph-10 ()
  (init-simplify-test-nodes)
  (let ((graph-string "[DOG: Spot]<-(agnt)<-[EAT]-
                         (obj)->[CAKE]
                         (manr)->[QUICKLY *x]."))

  ;; [eat]->(agnt)->[dog]
  (add-arc-into-relation eat-con agnt-rel)
  (set-arc-from-relation agnt-rel spot-con)

  ;; [eat]->(obj)->[cake]
  (add-arc-into-relation eat-con obj-rel)
  (set-arc-from-relation obj-rel cake-con)

  ;; [eat]->(manr)->[quickly]
  (add-arc-into-relation eat-con manr1-rel)
  (set-arc-from-relation manr1-rel quickly1-con)


  (values spot-con graph-string)))



(defun test-graph-11 ()
  (init-test-graphs)
  (let ((graph-string "[DRIVE]-
     (agnt)→[PERSON: *x]
     (dest)→[CITY]
     (inst)→[CHEVY-VEHICLE]-
                  (attr)→[OLD]
                  (poss)←[PERSON: *x].")
        (graph-string2 "[DRIVE]-
     (agnt)->[PERSON]->(poss)->[CHEVY-VEHICLE: *x]
     (inst)->[CHEVY-VEHICLE: *x]->(attr)->[OLD]
     (dest)->[CITY]."))

    ;; [PERSON]<-(agnt)<-[DRIVE]
    (add-arc-into-relation drive-con  agnt-rel)
    (set-arc-from-relation person-con agnt-rel)


    ;; [DRIVE]->(inst)->[CHEVY-VEHICLE]
    (add-arc-into-relation drive-con inst-rel)
    (set-arc-from-relation chevy-vehicle-con inst-rel)


    ;; [PERSON]->(pos)->[CHEVY-VEHICLE]
    (add-arc-into-relation person-con poss-rel)
    (set-arc-from-relation chevy-vehicle-con  poss-rel)


    ;; [DRIVE]->(dest)->[CITY]
    (add-arc-into-relation drive-con dest-rel)
    (set-arc-from-relation city-con  dest-rel)


    ;; [CHEVY-VEHICLE]->(attr)->[OLD]
    (add-arc-into-relation chevy-con attr-rel)
    (set-arc-from-relation old-con   attr-rel)

    ;; person-con
    ;; old-con
    ;; drive-con
    ;; city-con
    ;; chevy-con

    ;; inst-rel
    ;; obj-rel
    ;; poss-rel
    ;; attr-rel
    ;; dest-rel
    ;; agnt-rel

    (values drive-con graph-string)))



;; (defun test-graph-12 ()
;;   (init-simplify-test-nodes)
;;   (let ((graph-string "[GIVE]-
;;    (agnt)->[PERSON: Suez]
;;    (rcpt)->[DOG: Spotz]<-(agnt)<-[EAT:]->(obj)->[food *x]
;;    (inst)->[FOOD *x]."))


;; (defun tst (test-num)
;;       (let* ((s1 (pcg (car (make-test-graph test-num))))
;;              (s2 (pcg (pcg (cadr (make-test-graph test-num))))))
;;         (princ s1)
;;         (princ s2)
;;         (graph-strings-equal s1 s2)))

;; (defun tst (test-num)
;;   (let* ((vals (make-test-graph test-num))
;;          (s1 (pcg (car vals)))
;;          (s2 (cadr vals))
;;          (s3 (pcg (pcg (cadr vals)))))
;;     (format t "~&s1:~&~a~%" s1)
;;     (format t "~&s2:~&~a~%" s2)
;;     (format t "~&s3:~&~a~%" s3)
;;     (graph-strings-equal s1 s2)))


;; (defun tst (test-num)
;;       (let* ((vals (make-test-graph test-num))
;;              (s1 (cadr vals))
;;              (s2 (pcg (car vals)))
;;              (s3 (pcg (pcg (cadr vals)))))
;;         (format t "~&s1:~&~a~%" s1)
;;         (format t "~&s2:~&~a~%" s2)
;;         (format t "~&s3:~&~a~%" s3)
;;         (graph-strings-equal s1 s2)))



;; (defun tst (test-num)
;;       (let* ((vals (make-test-graph test-num))
;;              (s1 (cadr vals))
;;              (s2 (pcg (car vals)))
;;              (s3 (pcg (pcg (cadr vals)))))
;;         (format t "~&source:~&~a~%" s1)
;;         (format t "~&s2:~&~a~%" s2)
;;         (format t "~&s3:~&~a~%" s3)
;;         (graph-strings-equal s1 s3)))
