
(defparameter graph-string-0
  "[DOG: Spot]")

(defparameter graph-string-1
  "[DOG: Spot]←(agnt)←[EAT].")

(defparameter graph-string-2
  "[DOG]←(agnt)←[EAT]→(obj)→[FOOD].")

(defparameter graph-string-3
"[PERSON: Sue]←(agnt)←[GIVE]-
                        (obj)→[FOOD]←(obj)←[EAT:*x]
                        (rcpt)→[DOG: Spot]←(agnt)←[EAT:*x].")

(defparameter graph-string-4
"[PERSON: Sue]←(agnt)←[GIVE]-
                        (obj)→[FOOD]←(obj)←[EAT:*x]→(manr)→[QUICKLY]
                        (rcpt)→[DOG:Spot]←(agnt)←[EAT:*x].")

(defparameter graph-string-5
  "[DRIVE]-
    (agnt)→[PERSON: Bob]→(poss)→[CHEVY: *y]
    (dest)→[CITY: St. Louis].")

(defparameter graph-string-6
"[DOG: Spot]-
         (agnt)←[EAT: *x]
         (poss)→[CAKE]←(obj)←[EAT: *x].")

(defparameter graph-string-7
  "[FOOD]-
      (obj)←[GIVE]-
                (agnt)→[PERSON]
                (rcpt)→[DOG: *z],
      (obj)←[EAT]→(agnt)→[DOG: *z].")

(defparameter graph-string-8
  "[DOG: Fido]-
     (agnt)←[EAT]-
               (obj)→[FOOD: *x]
               (manr)→[QUICKLY],
     (rcpt)←[GIVE]-
               (agnt)→[PERSON]
               (obj)→[FOOD: *x].")

(defparameter graph-string-10
"[GIVE]-
    (agnt)→[PERSON:Sue]
    (obj)→[FOOD]←(obj)←[EAT:*x]
    (rcpt)→[DOG: Spot]←(agnt)←[EAT:*x].")

(defparameter graph-string-13
"[DOG: Spot]←(agnt)←[EAT]-
                      (obj)→[CAKE]
                      (manr)→[QUICKLY].")

(defparameter graph-string-14
"[DRIVE]-
     (agnt)→[PERSON: *x]
     (dest)→[CITY]
     (inst)→[CHEVY]-
               (attr)→[OLD]
               (poss)←[PERSON: *x].")

(defparameter graph-string-15
"[DRIVE]-
     (agnt)→[PERSON]→(poss)→[CHEVY: *x]
     (inst)→[CHEVY: *x]→(attr)→[OLD]
     (dest)→[CITY].")



(defun get-graph-string (n)
  (let* ((name (format nil "GRAPH-STRING-~d" n))
        (symbol (intern name))
        (bound-p (boundp symbol)))
    (when bound-p
      (symbol-value symbol))))

(defun get-graph-tokens (n)
  (let* ((text (get-graph-string n))
         (token-list (when text (cgraph-tokens text)))
         (linked (when token-list (remove-if #'arc-p (linkup token-list)))))
    linked))

(defun get-graph-segments (n)
  (let* ((text (get-graph-string n))
         (tokens (parse-cgraph text)))
    (collect-segments (car tokens))))



(defun build-every-graph ()
  (dotimes (n 16)
    (let ((graph-string (get-graph-string n)))
      (format t "~2%graph ~d" n)
      (format t "~%~a" (pcg (pcg graph-string))))))
