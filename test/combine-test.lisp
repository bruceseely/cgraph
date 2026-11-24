;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Testing combination of graphs
;;;

(in-package #:conceptual-graphs)


(defmethod test-combine ((expected list) (sources list) &optional verbose)
  (let ((constructed (car sources)))
    (dolist (src (cdr sources))
      (setf constructed (combine-conceptual-graph-lists constructed src)))
    (graphs-equal constructed expected)
    ))


(defmethod test-combine ((expected graph-node) (sources list) &optional verbose)
  (test-combine (collect-nodes expected)
                (mapcar (lambda (graph)
                         (collect-nodes graph))
                        sources)))


(defmethod test-combine ((expected string) (sources list) &optional verbose)
  (test-combine (graph-head (pcg expected))
                (mapcar (lambda (graph)
                         (graph-head (pcg graph)))
                        sources)))

(defun combine-test-defs ()
  ;; Thr CAR of each list is the expected result
  (list
   (list "[person: Sue]<-(agnt)<-[eat]->(manr)->[quickly]"
         "[person: Sue]<-(agnt)<-[eat]->(manr)->[quickly]")
   (list "[PERSON: Sue]←(agnt)←[EAT]- (manr)→[QUICKLY] (obj)→[FOOD]."
         "[person: Sue]<-(agnt)<-[eat]->(manr)->[quickly]"
         "[animate]<-(agnt)<-[eat]->(obj)->[food]")))


(defun combine-test (&optional verbose)
  (with-test-types
    (check-type-lattice)
    (let ((pass t))
      (dolist (rec (combine-test-defs))
        (setf pass (and (test-combine (car rec) (cdr rec) verbose) pass)))
      pass)))


;; (progn
;;     (setq g1 (pcg "[PERSON: Sue]←(agnt)←[EAT]->(manr)→[QUICKLY]"))
;;     (setq g2 (pcg "[ANIMATE]←(agnt)←[EAT]→(obj)→[FOOD]"))
;;     (setq result (combine-conceptual-graphs g1 g2))
;;     (print-cgraph result))


;;; --- the :INDIVIDUALS alignment strategy ------------------------------------
;;;
;;; :AUTOMATIC joins generic concepts of one type: two unrelated "a pie"s become
;;; one pie, and "a dog" collapses into a particular dog. :INDIVIDUALS joins only
;;; concepts that carry the same individual, so a store built from text says no
;;; more than the text did.

(defun %join-store (strategy &rest strings)
  "INCLUDE-CGRAPH each of STRINGS into a fresh context under STRATEGY; the
context's graphs."
  (let ((kb (make-context))
        (*alignment-strategy* strategy))
    (handler-bind ((warning #'muffle-warning))
      (dolist (s strings)
        (include-cgraph (make-cgraph s (make-context)) kb)))
    (graphs kb)))

(defun %concepts-of-type (graph label)
  (remove-if-not (lambda (c) (string-equal label (string (label (concept-type c)))))
                 (collect-concepts (head graph))))

(defun combine-individuals-test (&optional verbose)
  (with-test-types
    (let ((*allow-dynamic-individual-creation* t)
          (checks '()))
      (flet ((check (label ok) (push (cons label (and ok t)) checks)))
        ;; the over-merge :AUTOMATIC makes, kept as the contrast
        (check ":automatic joins two generic pies"
               (= 1 (length (%join-store :automatic
                                         "[EAT: #101]- (agnt)→[GIRL] (obj)→[PIE]."
                                         "[EAT: #102]- (agnt)→[BOY] (obj)→[PIE]."))))
        (check ":individuals keeps two generic pies apart"
               (= 2 (length (%join-store :individuals
                                         "[EAT: #101]- (agnt)→[GIRL] (obj)→[PIE]."
                                         "[EAT: #102]- (agnt)→[BOY] (obj)→[PIE]."))))
        ;; a shared name joins, and only the named concept is shared
        (let ((gs (%join-store :individuals
                               "[EAT: #103]- (agnt)→[PERSON: Sue] (obj)→[PIE]."
                               "[SEE: #104]- (agnt)→[PERSON: Sue] (obj)→[PIE].")))
          (check ":individuals joins on a shared name"
                 (= 1 (length gs)))
          (check "... with one Sue and still two pies"
                 (and (= 1 (length gs))
                      (= 1 (length (%concepts-of-type (first gs) "PERSON")))
                      (= 2 (length (%concepts-of-type (first gs) "PIE"))))))
        ;; a generic concept is not a particular one
        (check ":individuals does not fold \"a dog\" into [DOG: #105]"
               (= 2 (length (%join-store :individuals
                                         "[SEE: #106]- (agnt)→[DOG: #105] (obj)→[PERSON: Sue]."
                                         "[SEE: #107]- (agnt)→[DOG] (obj)→[PERSON: Bob]."))))
        (check ":individuals joins one numbered marker"
               (= 1 (length (%join-store :individuals
                                         "[SEE: #108]- (agnt)→[DOG: #105] (obj)→[PERSON: Sue]."
                                         "[SEE: #109]- (agnt)→[DOG: #105] (obj)→[PERSON: Bob]."))))
        ;; the bare # says "a particular one", not which
        (check ":individuals does not join on the bare #"
               (= 2 (length (%join-store :individuals
                                         "[SEE: #110]- (agnt)→[DOG: #] (obj)→[PERSON: Sue]."
                                         "[SEE: #111]- (agnt)→[DOG: #] (obj)→[PERSON: Bob].")))))
      (setf checks (reverse checks))
      (when verbose
        (dolist (c checks)
          (format t "~&  ~:[FAIL <<<~;pass~]  ~a~%" (cdr c) (car c))))
      (every #'cdr checks))))
