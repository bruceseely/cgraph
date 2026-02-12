

(in-package :conceptual-graphs)


(defparameter graph-string1000 "[girl]<-(agnt)<-[eat]->(obj)->[pie].")
(defparameter graph-string1002 "[girl: *]<-(agnt)<-[eat]->(obj)->[pie:*].")


(defparameter graph-string1010 "[GIRL:Sue]<-(AGNT)<-[EAT]->(MANR)->[QUICKLY].")

(defparameter graph-string1020 "[PERSON:Sue]<-(AGNT)<-[EAT]->(OBJ)->[PIE].")
(defparameter graph-string1030 "[PERSON: Sue]<-(AGNT)<-[EAT]->(OBJ)->[PIE].")


(defparameter graph-string1040
  "[dog]-
      (agnt)<-[eat]-
                 (obj)->[food:*x]
                 (manr)->[quickly],
      (rcpt)<-[give]-
                 (agnt)->[person]
                 (obj)->[food:*x].")



(defparameter graph-string1050
  "[drive]-
       (agnt)->[person:bob]->(poss)->[chevy:*y]
       (inst)->[chevy:*y]->(attr)->[old]
       (dest)->[city: St. Louis].")

(defparameter graph-string1060
  "[Drive]->(INST)->[Chevy]->(attr)->[old].")

(defparameter graph-string1070
  "[Drive]-
        (agnt)->[Person:Bob]->(POSS)->[Chevy]
        (dest)->[City: St. Louis].")

(defparameter graph-string1080
  "[food]-
      (obj)<-[give]-
                (agnt)->[person]
                (rcpt)->[dog:*z],
      (obj)<-[eat]->(agnt)->[dog:*z].")

(defparameter graph-string1090
  "[food]-
      (obj)<-[give]-
                (agnt)->[person]
                (rcpt)->[dog].")

(defparameter graph-string1100
  "[food]-
      (obj)<-[eat]->(agnt)->[dog:*x].")

(defparameter graph-string1110
  "[dog:Fido]-
     (agnt)<-[eat]-
               (obj)->[food:*x]
               (manr)->[quickly],
     (rcpt)<-[give]-
               (agnt)->[person]
               (obj)->[food:*x].")

(defparameter graph-string1120
  "[Drive]-
    (agnt)->[Person:Bob]->(POSS)->[Chevy:*y]
    (dest)->[City: St. Louis].")

(defparameter graph-string1200
  "[EAT]-
    (agnt)->[Person:Bob]
    (obj)->[CITY]")


(defparameter graph-string1300
  "[drive]-
       (agnt)->[person:bob]->(poss)->[chevy:*y]
       (inst)->[chevy:*y]->(attr)->[old]
       (dest)->[city: St. Louis].")


(defun getest  (test-number &optional verbose)
  (reset-cgraph)
  (let* ((*print-pretty* nil)
         (graph-name (intern (format nil "GRAPH-STRING~4,'0d" test-number)))
         (graph-string (symbol-value graph-name)))
    (when verbose
      (format t "~&~s~%" graph-string))
    (let* ((graph (parse-cgraph graph-string)))
      (dolist (graph (graph-every-concept graph))
        (when verbose (format t "~2&~a~%" graph))
        ))))


(defun graph-every-test (&optional verbose)

  (ensure-concept-types-exist
   '((:label entity :supertypes (⊤))
     (:label physobj :supertypes (entity))
     (:label animate :supertypes (entity))
     (:label mobile-entity :supertypes (physobj))
     (:label stationary-entity :supertypes (entity))
     (:label animal :supertypes (animate mobile-entity))
     (:label dog :supertypes (animal))
     (:label person :supertypes (animal))
     (:label girl :supertypes (person))
     (:label event :supertypes (⊤))
     (:label act :supertypes (event))
     (:label eat :supertypes (act))
     (:label give :supertypes (act))
     (:label drive :supertypes (act))
     (:label food :supertypes (entity physobj))
     (:label pie :supertypes (food))
     (:label characteristic :supertypes (⊤))
     (:label manner :supertypes (characteristic))
     (:label fast :supertypes (manner))
     (:label age :supertypes (characteristic))
     (:label old :supertypes (age))
     (:label attribute :supertypes (characteristic))
     (:label place :supertypes (stationary-entity))
     (:label society :supertypes (⊤))
     (:label city :supertypes (place society))
     (:label conveyance :supertypes (mobile-entity))
     (:label automobile :supertypes (conveyance))
     (:label chevy :supertypes (automobile))))

  (ensure-relation-types-exist
   '((:label agnt :source-types act :dest-type animate)
     (:label attr :source-types entity :dest-type attribute)
     ;;(:label chrc :source-types entity :dest-type characteristic)
     (:label dest :source-types act :dest-type place)
     (:label inst :source-types act :dest-type entity)
     (:label manr :source-types act :dest-type manner)
     (:label obj  :source-types act :dest-type entity)
     (:label poss :source-types animate :dest-type entity)
     (:label rcpt :source-types act :dest-type animate)))

  (let ((tests '(1000 1002 1010 1020 1030 1040 1050 1060 1070 1080 1090 1100 1120 1200 1300)))
    (when verbose
      (format t "~%GRAPH-EVERY-TEST~2%"))

    (dolist (test-id tests)
      (getest test-id verbose)
      (when verbose
        (format t "~3&== test ~4,'0d ==========================================~%" test-id))))
  t)
