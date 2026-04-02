

(in-package :conceptual-graphs)


(defparameter graph-string1000 "[GIRL]←(agnt)←[EAT]→(obj)→[PIE].")
(defparameter graph-string1002 "[GIRL: *]←(agnt)←[EAT]→(obj)→[PIE:*].")


(defparameter graph-string1010 "[GIRL:Sue]←(agnt)←[EAT]→(manr)→[QUICKLY].")

(defparameter graph-string1020 "[PERSON:Sue]←(agnt)←[EAT]→(obj)→[PIE].")
(defparameter graph-string1030 "[PERSON: Sue]←(agnt)←[EAT]→(obj)→[PIE].")


(defparameter graph-string1040
  "[DOG]-
      (agnt)←[EAT]-
                 (obj)→[FOOD:*x]
                 (manr)→[QUICKLY],
      (rcpt)←[GIVE]-
                 (agnt)→[PERSON]
                 (obj)→[FOOD:*x].")



(defparameter graph-string1050
  "[DRIVE]-
       (agnt)→[PERSON:bob]→(poss)→[AUTOMOBILE: chevy-vehicle *y]
       (inst)→[AUTOMOBILE: chevy-vehicle *y]→(age)→[OLD]
       (dest)→[CITY: St. Louis].")

(defparameter graph-string1060
  "[DRIVE]→(inst)→[CHEVY-VEHICLE]→(age)→[OLD].")

(defparameter graph-string1070
  "[DRIVE]-
        (agnt)→[PERSON:Bob]→(poss)→[CHEVY-VEHICLE]
        (dest)→[CITY: St. Louis].")

(defparameter graph-string1080
  "[FOOD]-
      (obj)←[GIVE]-
                (agnt)→[PERSON]
                (rcpt)→[DOG:*z],
      (obj)←[EAT]→(agnt)→[DOG:*z].")

(defparameter graph-string1090
  "[FOOD]-
      (obj)←[GIVE]-
                (agnt)→[PERSON]
                (rcpt)→[DOG].")

(defparameter graph-string1100
  "[FOOD]-
      (obj)←[EAT]→(agnt)→[DOG:*x].")

(defparameter graph-string1110
  "[DOG:Fido]-
     (agnt)←[EAT]-
               (obj)→[FOOD:*x]
               (manr)→[QUICKLY],
     (rcpt)←[GIVE]-
               (agnt)→[PERSON]
               (obj)→[FOOD:*x].")

(defparameter graph-string1120
  "[DRIVE]-
    (agnt)→[PERSON:Bob]→(poss)→[AUTOMOBILE: Chevy-Vehicle *y]
    (dest)→[CITY: St. Louis].")

(defparameter graph-string1200
  "[EAT]-
    (agnt)→[PERSON:Bob]
    (obj)→[CITY]")


(defparameter graph-string1300
  "[DRIVE]-
       (agnt)→[PERSON:bob]→(poss)→[AUTOMOBILE: chevy-vehicle *y]
       (inst)→[AUTOMOBILE: chevy-vehicle *y]→(age)→[OLD]
       (dest)→[CITY: St. Louis].")


(defun getest  (test-number &optional verbose)
  (reset-cgraph)
  (load-cgraph-types)
  (let* ((*print-pretty* nil)
         (graph-name (intern (format nil "GRAPH-STRING~4,'0d" test-number)))
         (graph-string (symbol-value graph-name)))
    (when verbose
      (format t "~&~s~%" graph-string))
    (let* ((graph (car (parse-cgraph graph-string))))
      (dolist (graph (graph-every-concept graph))
        (when verbose (format t "~2&~a~%" graph))
        ))))

(defun graph-every-test (&optional verbose)


  (let ((tests '(1000 1002 1010 1020 1030 1040 1050 1060 1070 1080 1090 1100 1120 1200 1300)))
    (when verbose
      (format t "~%GRAPH-EVERY-TEST~2%"))

    (dolist (test-id tests)
      (getest test-id verbose)
      (when verbose
        (format t "~3&== test ~4,'0d ==========================================~%" test-id))))
  t)
