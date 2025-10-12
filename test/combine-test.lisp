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
  (test-combine (pcg expected)
                (mapcar (lambda (graph)
                         (pcg graph))
                        sources)))

(defun combine-test-defs ()
  ;; Thr CAR of each list is the expected result
  (list
   (list "[person: Sue]<-(agnt)<-[eat]->(manr)->[fast]"
         "[person: Sue]<-(agnt)<-[eat]->(manr)->[fast]")
   (list "[PERSON: Sue]←(agnt)←[EAT]- (manr)→[FAST] (obj)→[FOOD]."
         "[person: Sue]<-(agnt)<-[eat]->(manr)->[fast]"
         "[animate]<-(agnt)<-[eat]->(obj)->[food]")))


(defun combine-test (&optional verbose)
  (let ((pass t))
  (dolist (rec (combine-test-defs))
    (setf pass (and (test-combine (car rec) (cdr rec) verbose) pass)))
    pass))
