;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)


;; (defun linkup-test ()
;;   (let ((source "[PERSON]←(agnt)←[EAT].")
;;         (computed (pcg (car (linkup (list (pcg "[person]") (pcg left-arrow-string) (pcg "(agnt)") left-arrow-arc (pcg "[eat]"))))))
;;         (from-strings  (pcg (car (linkup-strings  "[person]" "<-" "(agnt)" left-arrow-string "[eat]")))))

;;     (format t "~&source: ~s~%"  source)
;;     (format t "~&from-strings: ~s~%"  from-strings)
;;     (and
;;      (string-equal source from-strings)
;;      (string-equal source computed))))


(defun test-linkup (string &optional verbose)
  (setq *context* (make-context))
    (when verbose
      (format t "~2%>> (test-linkup: ~a" (canonicalize-graph-string string)))
  (let* ((source-string (canonicalize-graph-string string))
         (graph (pcg source-string))
         (str (pcg graph))
         (string-from-graph (canonicalize-graph-string (pcg graph)))
         (pass (graph-strings-equal (canonicalize-graph-string source-string) string-from-graph)))
    (when verbose
      (format t "~&source-string:   ~s~%"  (canonicalize-graph-string source-string))
      (format t "~&computed string: ~s~%"  string-from-graph)
      (format t "~&pass: ~s~%"  pass))
    pass))

(defun linkup-test (&optional verbose)

  (ensure-concept-types-exist
   '((:label entity :supertypes (⊤))
     (:label physobj :supertypes (entity))
     (:label animate :supertypes (entity))
     (:label mobile-entity :supertypes (physobj))
     (:label animal :supertypes (animate mobile-entity))
     (:label dog :supertypes (animal))
     (:label person :supertypes (animal))
     (:label event :supertypes (⊤))
     (:label act :supertypes (event))
     (:label eat :supertypes (act))
     (:label give :supertypes (act))
     (:label food :supertypes (entity physobj))
     (:label cake :supertypes (food))
     (:label characteristic :supertypes (⊤))
     (:label manner :supertypes (characteristic))
     (:label fast :supertypes (manner))))

  (ensure-relation-types-exist
   '((:label agnt :source-types act :dest-type animate)
     (:label inst :source-types act :dest-type entity)
     (:label manr :source-types act :dest-type manner)
     (:label obj  :source-types act :dest-type entity)
     (:label poss :source-types animate :dest-type entity)
     (:label rcpt :source-types act :dest-type animate)))

  (let ((*include-node-ref* nil)
        (graph-strings (list
                        "[DOG: Spot]<-(agnt)<-[EAT]."
                        "[DOG: Spot]<-(agnt)<-[EAT]->(obj)->[CAKE]."
                        "[DOG: Spot]<-(agnt)<-[EAT]- (manr)->[FAST] (obj)->[CAKE]."
                        "[PERSON: Sue]<-(agnt)<-[GIVE]- (obj)->[FOOD]<-(obj)<-[EAT:*x] (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*x]."
                        "[PERSON: Sue]<-(agnt)<-[GIVE]- (inst)->[FOOD]<-(obj)<-[EAT:*x]->(manr)->[FAST] (rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*x]."
                        ;;"[DOG: Spot]- (poss)->[CAKE]<-(obj)<-[EAT: *x] (agnt)<-[EAT: *x]."
                        "[DOG: Spot]- (agnt)<-[EAT: *x](poss)->[CAKE]<-(obj)<-[EAT: *x] ."
                        "[PERSON: Sue]<-(agnt)<-[GIVE]- (inst)->[FOOD]<-(obj)<-[EAT: *x] (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *x]."
                        "[GIVE]- (agnt)->[PERSON:Sue] (inst)->[FOOD]<-(obj)<-[EAT:*x] (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*x]."
                        "[GIVE]- (agnt)->[PERSON: Sue] (inst)->[FOOD]<-(obj)<-[EAT: *x] (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *x]."
                        "[GIVE]- (agnt)->[PERSON: Suez] (inst)->[FOOD]<-(obj)<-[EAT: *x] (rcpt)->[DOG: Spotz]<-(agnt)<-[EAT: *x]."
                        ;; "[PERSON]<-(betw)- <-1-[ROCK] <-2-[PLACE]->(attr)->[HARD]."
                        ))
        (result t)
        )
    (dolist (graph-string graph-strings)
      (let ((pass (test-linkup graph-string verbose)))
        (setf result (and result pass))))
    result))



;; (linkup-test "[PERSON]←(agnt)←[EAT].")


;; "[food]-
;;       (obj)<-[give]-
;;                 (agnt)->[person]
;;                 (rcpt)->[dog: *z],
;;       (obj)<-[eat]->(agnt)->[dog: *z]."
;;  ---- unhandled by linkup ------
;; tokens: ([FOOD] - (obj) ← [GIVE] - (agnt) → [PERSON] (rcpt) → [DOG: *z] #\, (obj) ← [EAT] → (agnt) → [DOG: *z])
;; sublist: ([DOG: *z] #\, (obj) ← [EAT] → (agnt) → [DOG: *z])
