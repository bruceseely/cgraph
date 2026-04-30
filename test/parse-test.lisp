
(in-package :conceptual-graphs)



;;; pay attention to *concise*

(defparameter graph-string000 "[girl]<-(agnt)<-[EAT]->(obj)->[PIE].")
(defparameter graph-string010 "[girl:sue]<-(agnt)<-[EAT]->(manr)->[QUICKLY].")
(defparameter graph-string020 "[person:sue]<-(agnt)<-[EAT]->(obj)->[PIE].")
(defparameter graph-string030 "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE].")

(defparameter graph-string040
  "[dog]-
     (agnt)<-[EAT]-
               (manr)->[QUICKLY]
               (obj)->[FOOD],
     (rcpt)<-[GIVE]-
               (agnt)->[PERSON]
               (obj)->[FOOD].")

;; (defparameter graph-string041
;;   "[dog: *]<-(agnt)<-[EAT: *]->(obj)->[FOOD].")

(defparameter graph-string041
  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD].")

(defparameter graph-string042
  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD].")



;;; (ptestx 043)
(defparameter graph-string043
  "[DOG]<-(agnt)<-[EAT]-
                   (manr)->[QUICKLY]
                   (obj)->[FOOD] .")


(defparameter graph-string045
  "[DOG]-
     (agnt)<-[EAT]-
               (manr)->[QUICKLY]
               (obj)->[FOOD] ,
     (rcpt)<-[GIVE]->(obj)->[FOOD].")

(defparameter graph-string046
  "[PERSON: sue]<-(agnt)<-[GIVE]-
                           (obj)->[FOOD]<-(obj)<-[EAT:*x]
                           (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*x] .")


(defparameter graph-string047
  "[PERSON:sue]←(agnt)←[GIVE]-
                         (inst)→[FOOD]←(obj)←[EAT:*x]->(manr)→[QUICKLY]
                         (rcpt)→[DOG:Spot]←(agnt)←[EAT:*x].")


(defparameter graph-string050
  "[DRIVE]-
      (agnt)→[PERSON:bob]→(poss)→[CHEVY-VEHICLE:*x]→(attr)→[OLD]
      (dest)→[CITY:St.Louis]
      (inst)→[CHEVY-VEHICLE:*x].")


(defparameter graph-string060
  "[DRIVE]->(inst)->[CHEVY-VEHICLE]->(attr)->[OLD].")

(defparameter graph-string070
  "[DRIVE]-
     (agnt)->[PERSON:Bob]->(poss)->[CHEVY-VEHICLE]
     (dest)->[CITY: St. Louis].")

(defparameter graph-string080
  "[FOOD]-
     (obj)<-[GIVE]-
              (agnt)->[PERSON]
              (rcpt)->[DOG: #45],
     (obj)<-[EAT]->(agnt)->[DOG: #45].")

(defparameter graph-string085
  "[food]-
     (obj)<-[GIVE]-
              (agnt)->[PERSON]
              (rcpt)->[DOG:*z],
     (obj)<-[EAT]->(agnt)->[DOG:*z].")

(defparameter graph-string090
  "[FOOD]<-(obj)<-[GIVE]-
                    (agnt)->[PERSON]
                    (rcpt)->[DOG].")

(defparameter graph-string100
  "[FOOD]<-(obj)<-[EAT]->(agnt)->[DOG].")

(defparameter graph-string110
  "[DOG:fido]-
         (agnt)<-[EAT]-
                  (manr)->[QUICKLY]
                  (obj)->[FOOD: #78],
         (rcpt)<-[GIVE]-
                   (agnt)->[PERSON]
                   (obj)->[FOOD: #78].")

(defparameter graph-string120
  "[DRIVE]-
     (agnt)->[PERSON: Bob]->(poss)->[CHEVY-VEHICLE]
     (dest)->[CITY: St. Louis].")


(defparameter graph-string130
  "[FOOD]-
     (obj)←[GIVE]-
             (agnt)→[PERSON]
             (rcpt)→[DOG:Spot*x],
     (obj)←[EAT]→(agnt)→[DOG:Spot*x].")

(defparameter graph-string200
  "[EAT]-
     (agnt)->[PERSON:Bob]
     (obj)->[CITY].")

(defparameter graph-string240
  "[PERSON: sue]<-(agnt)<-[GIVE]-
                            (inst)->[FOOD]<-(obj)<-[EAT]
                            (rcpt)->[DOG: Spot]<-(agnt)<-[EAT] .")

(defparameter graph-string250
  "[PERSON: sue]<-(agnt)<-[GIVE]-
                            (inst)->[FOOD]<-(obj)<-[EAT: #1]
                            (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: #1] .")


;;; can't handle this yet
;; (defparameter graph-string300
;;   "[PERSON: sue]<-(agnt)<-[GIVE]-
;;                             (inst)->[FOOD: #1]<-(obj)<-[EAT: #1]
;;                             (inst)->[FOOD: #2]<-(obj)<-[EAT: #2]
;;                             (rcpt)->[DOG: Fido]<-(agnt)<-[EAT: #2]
;;                             (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: #1] .")



;; (defparameter graph-string400
;;   "[SPOON]-
;;       (inst)←[EAT]-
;;               (agnt)→[MONKEY]
;;               (obj)→[WALNUT:*y],
;;       (matr)→[SHELL:*x]←(part)←[WALNUT:*y].")


;; (defparameter graph-string410 "[SPOON]-
;;                                   (inst)←[EAT]-
;;                                           (agnt)→[MONKEY]
;;                                           (obj)→[WALNUT:*y],
;;                                   (matr)→[SHELL:*x]←(part)←[WALNUT:*y].")


;;; (ptestx 420)
(defparameter graph-string420
  "[GIRL: sue]-
      (agnt)←[EAT]-
           (manr)→[QUICKLY]
           (obj)→[PIE],
      (agnt)←[EAT]→(obj)→[FOOD].")



(defparameter graph-string430
  "[DRIVE]-
      (agnt)→[PERSON:Bob]→(poss)→[CHEVY-VEHICLE:*x]→(attr)→[OLD]
      (dest)→[CITY:St.Louis]
      (inst)→[CHEVY-VEHICLE:*x].")



(defparameter graph-string440
  "[DRIVE]-
      (agnt)→[PERSON:Bob]→(poss)→[CHEVY-VEHICLE:*x]→(attr)→[OLD]
      (dest)→[CITY:St.Louis]
      (inst)→[CHEVY-VEHICLE:*x].")



(defparameter graph-string450
  "[drive]-
      (agnt)→[PERSON:Bob]→(poss)→[CHEVY-VEHICLE:*x]→(attr)→[OLD]
      (dest)→[CITY:St.Louis]
      (inst)→[CHEVY-VEHICLE:*x].")



(defparameter graph-string500
  "[DRIVE]-
      (agnt)→[PERSON: *x]
      (dest)→[CITY: St. Louis]
      (inst)→[CHEVY-VEHICLE]-
                (attr)→[OLD]
                (poss)←[PERSON: *x].")


(defparameter graph-string550
  "[DRIVE]-
      (agnt)→[PERSON: Bob]
      (dest)→[CITY: St. Louis]
      (inst)→[CHEVY-VEHICLE]-
                (attr)→[OLD]
                (poss)←[PERSON: Bob].")



(defvar *graph)
(defvar *result)

;;; (ptest 'graph-string000)
(defun ptest  (graph-name)
  (initialize-cgraph)
  (let* ((*print-pretty* nil)
         (*allow-dynamic-individual-creation* t)
         (graph-string (arrows-to-unicode (symbol-value graph-name)))
         (zz (format t "~&~s~%"  graph-string))
         (graph (progn
                  (initialize-cgraph)
                  (parse-cgraph graph-string)))
         (formated-graph (progn (arrows-to-unicode (format-cgraph graph))))
         (result (string-equal (string-upcase (without-node-ref (remove #\space (remove #\newline graph-string))))
                               (string-upcase (without-node-ref (remove #\space (remove #\newline formated-graph)))))))
    (values result graph-string formated-graph)))


(defun ptestx  (test-id)
  (clear-id-cache)
  (let ((graph-name (intern (format nil "graph-string~3,'0d" test-id))))
    (ptest graph-name)))


(defun parse-test (&optional verbose)
  (when verbose (format t "~%parse-test~%"))
  (reset-cgraph)

  (let ((*concise* t)
        (*include-node-ref* nil)
        (failed (list))
        (collect (list)))
    (dotimes (i 500)
      (initialize-cgraph)
      (let* ((test-id i)
             (test-name (format nil "test-~d" test-id))
             (graph-name (intern (format nil "GRAPH-STRING~3,'0d" test-id))))

        (when (boundp graph-name)
          (when verbose
            (format t "~3%== ~a;  === ~3,'0d ======================================~%" test-name graph-name))
          (multiple-value-bind (pass initial result)
              (ptest graph-name)

            ;;(variables-report)
            ;; (format t "~&...pass: ~s" pass)
            ;; (format t "~&...initial: ~s" initial)
            ;; (format t "~&...result: ~s" result)

            (unless pass (push (intern test-name) failed))
            (push pass collect)

            (when (and verbose (plusp (variable-count)))
              (format t "~%variables:")
              (variables-report))

            (when (or verbose (not pass))
              (format t "~&parsing...      ~s~%" (flatten-cgraph (canonicalize-graph-string initial)))
              (format t "~&formatted to... ~s~%" (flatten-cgraph result)))
            (when verbose
              (format t "~&~a ~:[failed ********~;passed~]" test-name pass))))))

    (let ((test-passed (every #'identity collect)))
      (when failed
        (format t "~2&failed: ~:a~%"  (reverse failed)))
      test-passed)))


;;; (trace collect-segments make-graph-segments format-cgraph format-segments-from-node format-segments  )



;; (test-strings
;;  (list "[person: judy]."
;;        "[\"cicero\"]<-(name)<-[PERSON:#123]->(name)->[\"TULLY\"]."
;;        "[\"IV\"]<-(name)<-[NUMBER:#1234]->(name)->[\"4\"]."
;;        "[\"ELEPHANT\"]<-(name)<-[SPECIES]->(memb)->[ELEPHANT:{*}]."
;;        "[BAR]->(chrc)->[LENGTH]->(meas)->[MEASURE: @25.4 cm\"]."
;;        "[BAR]->(chrc)->[LENGTH]->(meas)->[MEASURE: @25.4 cm\"]."
;;        "[BAR]->(chrc)->[LENGTH:@25.4 cm]."
;;        "[LENGTH: @ 5 ft.]."
;;        "[LENGTH:@25.4 cm]."
;;        "[TEMPERATURE:#567]->(meas)->[MEASURE]->(name)->[\"90\"]."
;;        "[TEMPERATURE: @90 deg #567]."
;;        "[TEMPERATURE:#567@90 deg]."))
