
(in-package :conceptual-graphs)



;;; pay attention to *concise*

(defparameter graph-string000 "[girl]<-(agnt)<-[eat]->(obj)->[pie].")
(defparameter graph-string010 "[GIRL:Sue]<-(AGNT)<-[EAT]->(MANR)->[FAST].")
(defparameter graph-string020 "[PERSON:Sue]<-(AGNT)<-[EAT]->(OBJ)->[PIE].")
(defparameter graph-string030 "[PERSON: Sue]<-(AGNT)<-[EAT]->(OBJ)->[PIE].")

(defparameter graph-string040
  "[dog]-
     (agnt)<-[eat]-
               (manr)->[fast]
               (obj)->[food],
     (rcpt)<-[give]-
               (agnt)->[person]
               (obj)->[food].")

;; (defparameter graph-string041
;;   "[dog: *]<-(agnt)<-[eat: *]->(obj)->[food].")

(defparameter graph-string041
  "[dog]<-(agnt)<-[eat]->(obj)->[food].")

(defparameter graph-string042
  "[dog]<-(agnt)<-[eat]->(obj)->[food].")



;;; (ptestx 043)
(defparameter graph-string043
  "[dog]<-(agnt)<-[eat]-
                   (manr)->[fast]
                   (obj)->[food] .")

;; (defparameter graph-string044
;;   "[dog]<-(agnt)<-[eat]-
;;                    (obj)->[food]
;;                    (manr)->[fast],
;; ")

(defparameter graph-string045
  "[dog]-
     (agnt)<-[eat]-
               (manr)->[fast]
               (obj)->[food] ,
     (rcpt)<-[give]->(obj)->[food].")

(defparameter graph-string046
  "[PERSON: Sue]<-(agnt)<-[GIVE]-
                           (obj)->[FOOD]<-(obj)<-[EAT:*x]
                           (rcpt)->[DOG: Spot]<-(agnt)<-[EAT:*x] .")

;; (defparameter graph-string047
;;   "[PERSON: Sue]<-(agnt)<-[GIVE]-
;;                            (inst)->[FOOD]<-(obj)<-[EAT:*x]->(manr)->[FAST]
;;                            (rcpt)->[DOG:Spot]<-(agnt)<-[EAT:*x] .")

(defparameter graph-string047
"[PERSON:Sue]←(agnt)←[GIVE]-
                      (inst)→[FOOD]←(obj)←[EAT:*x]->(manr)→[FAST]
                      (rcpt)→[DOG:Spot]←(agnt)←[EAT:*x].")


;; (defparameter graph-string050
;;   "[DRIVE]-
;;      (agnt)->[PERSON: bob]
;;      (dest)->[CITY: St. Louis]
;;      (inst)->[CHEVY]-
;;                (attr)->[OLD]
;;                (poss)<-[PERSON: bob].")

(defparameter graph-string050
  "[DRIVE]-
      (agnt)→[PERSON:bob]→(poss)→[CHEVY:*x]→(attr)→[OLD]
      (dest)→[CITY:St.Louis]
      (inst)→[CHEVY:*x].")



(defparameter graph-string060
  "[Drive]->(INST)->[Chevy]->(ATTR)->[old].")

(defparameter graph-string070
  "[Drive]-
     (agnt)->[Person:Bob]->(POSS)->[Chevy]
     (dest)->[City: St. Louis].")

(defparameter graph-string080
  "[FOOD]-
     (obj)<-[GIVE]-
              (agnt)->[PERSON]
              (rcpt)->[DOG: #45],
     (obj)<-[EAT]->(agnt)->[DOG: #45].")

(defparameter graph-string085
  "[food]-
     (obj)<-[give]-
              (agnt)->[person]
              (rcpt)->[dog:*z],
     (obj)<-[eat]->(agnt)->[dog:*z].")

(defparameter graph-string090
  "[FOOD]<-(obj)<-[GIVE]-
                    (agnt)->[PERSON]
                    (rcpt)->[DOG].")

(defparameter graph-string100
  "[FOOD]<-(obj)<-[EAT]->(agnt)->[DOG].")

(defparameter graph-string110
  "[dog:Fido]-
     (agnt)<-[eat]-
               (manr)->[fast]
               (obj)->[food: #78] ,
     (rcpt)<-[give]-
               (agnt)->[person]
               (obj)->[food: #78].")

(defparameter graph-string120
  "[DRIVE]-
     (agnt)->[PERSON: Bob]->(poss)->[CHEVY]
     (dest)->[CITY: St. Louis].")

;; (defparameter graph-string130
;;   "[food]-
;;       (obj)<-[give]-
;;                (agnt)->[person]
;;                (rcpt)->[dog: Spot],
;;       (obj)<-[eat]->(agnt)->[dog: Spot].")

(defparameter graph-string130
  "[FOOD]-
     (obj)←[GIVE]-
             (agnt)→[PERSON]
             (rcpt)→[DOG:Spot*x],
    (obj)←[EAT]→(agnt)→[DOG:Spot*x].")



(defparameter graph-string200
  "[EAT]-
     (agnt)->[Person:Bob]
     (obj)->[CITY].")

(defparameter graph-string240
  "[PERSON: Sue]<-(agnt)<-[GIVE]-
                            (inst)->[FOOD]<-(obj)<-[EAT]
                            (rcpt)->[DOG: Spot]<-(agnt)<-[EAT] .")

(defparameter graph-string250
  "[PERSON: Sue]<-(agnt)<-[GIVE]-
                            (inst)->[FOOD]<-(obj)<-[EAT: #1]
                            (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: #1] .")

(defparameter graph-string300
  "[PERSON: Sue]<-(agnt)<-[GIVE]-
                            (inst)->[FOOD: #1]<-(obj)<-[EAT: #1]
                            (inst)->[FOOD: #2]<-(obj)<-[EAT: #2]
                            (rcpt)->[DOG: Fido]<-(agnt)<-[EAT: #2]
                            (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: #1] .")

;; (defparameter graph-string400
;;   "[SPOON]-
;;      (inst)<-[EAT]-
;;               (agnt)->[MONKEY]
;;               (obj)->[WALNUT]->(part)->[SHELL: *x],
;;      (matr)->[SHELL: *x].")


(defparameter graph-string400
  "[SPOON]-
    (inst)←[EAT]-
            (agnt)→[MONKEY]
            (obj)→[WALNUT:*y],
    (matr)→[SHELL:*x]←(part)←[WALNUT:*y].")




;; (defparameter graph-string410
;;   "[SPOON]-
;;      (inst)←[EAT]-
;;               (agnt)→[MONKEY]
;;               (obj)→[WALNUT]→(part)→[SHELL: *x] ,
;;      (matr)→[SHELL: *x].")

(defparameter graph-string410
  "[SPOON]-(inst)←[EAT]-
                  (agnt)→[MONKEY]
                  (obj)→[WALNUT:*y],
        (matr)→[SHELL:*x]←(part)←[WALNUT:*y].")


;;; (ptestx 420)
(defparameter graph-string420
  "[GIRL: Sue]-
      (agnt)←[EAT]-
           (manr)→[FAST]
           (obj)→[PIE],
      (agnt)←[EAT]→(obj)→[FOOD].")


;; (defparameter graph-string430
;;   "[PERSON]<-(betw)-
;;                <-2-[ROCK]
;;                <-1-[PLACE]->(attr)->[HARD].")




;; (defparameter graph-string440
;;   "[drive]-
;;        (agnt)->[person: bob]->(poss)->[chevy: *y]
;;        (dest)->[city: St. Louis]
;;        (inst)->[chevy: *y]->(attr)->[old].")



;; (defparameter graph-string440
;;   "[drive]-
;;        (agnt)->[person: Bob]
;;        (dest)->[city: St. Louis]
;;        (inst)->[chevy]-
;;                       (attr)->[old]
;;                       (poss)<-[person: Bob].")


(defparameter graph-string440
  "[DRIVE]-
     (agnt)→[PERSON:Bob]→(poss)→[CHEVY:*x]→(attr)→[OLD]
     (dest)→[CITY:St.Louis]
     (inst)→[CHEVY:*x].")


;; (defparameter graph-string450
;;   "[DRIVE]-
;;        (agnt)->[PERSON: Bob]->(poss)->[CHEVY: *x]
;;        (inst)->[CHEVY: *x]->(attr)->[OLD]
;;        (dest)->[CITY: St. Louis].")



(defparameter graph-string450
  "[DRIVE]-
      (agnt)→[PERSON:Bob]→(poss)→[CHEVY:*x]→(attr)→[OLD]
      (dest)→[CITY:St.Louis]
      (inst)→[CHEVY:*x].")

(defparameter graph-string500
  "[DRIVE]-
     (agnt)→[PERSON: *x]
     (dest)→[CITY: St. Louis]
     (inst)→[CHEVY]-
                  (attr)→[OLD]
                  (poss)←[PERSON: *x].")


(defparameter graph-string550
  "[DRIVE]-
     (agnt)→[PERSON: Bob]
     (dest)→[CITY: St. Louis]
     (inst)→[CHEVY]-
                  (attr)→[OLD]
                  (poss)←[PERSON: Bob].")


(defvar *graph)
(defvar *result)

;;; (ptest 'graph-string000)
(defun ptest  (graph-name)
  (initialize-cgraph)
  (let* ((*print-pretty* nil)
         (*allow-dynamic-individual-creation* t)
         (graph-string (encode-arrows (symbol-value graph-name)))
         (zz (format t "~&~s~%"  graph-string))
         (graph (progn
                  (initialize-cgraph)
                  (parse-cgraph graph-string)))
         (formated-graph (progn (encode-arrows (format-cgraph graph))))
         (result (string-equal (string-upcase (without-node-ref (remove #\space (remove #\newline graph-string))))
                               (string-upcase (without-node-ref (remove #\space (remove #\newline formated-graph)))))))
    (values result graph-string formated-graph)))


(defun ptestx  (test-id)
  (CLEAR-ID-CACHE)
  (let ((graph-name (intern (format nil "GRAPH-STRING~3,'0d" test-id))))
    (ptest graph-name)))


(defun parse-test (&optional verbose)
  (when verbose (format t "~%PARSE-TEST~%"))
  (reset-cgraph)
  (let ((*concise* t)
        (*include-node-ref* nil)
        (failed (list))
        (collect (list)))
    (dotimes (i 500)
      (initialize-cgraph)
      (let* ((test-id i)
             (test-name (format nil "TEST-~d" test-id))
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
              (format t "~%Variables:")
              (variables-report))

            (when (or verbose (not pass))
              (format t "~&parsing...      ~s~%" (flatten-cgraph (canonicalize-graph-string initial)))
              (format t "~&formatted to... ~s~%" (flatten-cgraph result)))
            (when verbose
              (format t "~&~a ~:[FAILED ********~;passed~]" test-name pass))))))

    (let ((test-passed (every #'identity collect)))
      (when failed
        (format t "~2&failed: ~:a~%"  (reverse failed)))
      test-passed)))



;;; (trace collect-segments make-graph-segments format-cgraph format-segments-from-node format-segments  )



;; (test-strings
;;  (list "[person: Judy]."
;;        "[\"Cicero\"]<-(name)<-[person:#123]->(name)->[\"Tully\"]."
;;        "[\"IV\"]<-(name)<-[number:#1234]->(name)->[\"4\"]."
;;        "[\"elephant\"]<-(name)<-[species]->(memb)->[elephant:{*}]."
;;        "[bar]->(chrc)->[length]->(meas)->[measure: @25.4 cm\"]."
;;        "[bar]->(chrc)->[length]->(meas)->[measure: @25.4 cm\"]."
;;        "[bar]->(chrc)->[length:@25.4 cm]."
;;        "[length: @ 5 ft.]."
;;        "[length:@25.4 cm]."
;;        "[temperature:#567]->(meas)->[measure]->(name)->[\"90\"]."
;;        "[temperature: @90 deg #567]."
;;        "[temperature:#567@90 deg]."))


;; "[dog: *]-\n      (agnt)<-[eat]-\n                 (obj)->[food:*x]\n                 (manr)->[fast],\n      (rcpt)<-[give]-\n                 (agnt)->[person]\n                 (obj)->[food:*x]."
