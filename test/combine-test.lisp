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

  (load-test-types)
  (check-type-lattice)

  (let ((pass t))
  (dolist (rec (combine-test-defs))
    (setf pass (and (test-combine (car rec) (cdr rec) verbose) pass)))
    pass))


;; (progn
;;     (setq g1 (pcg "[PERSON: Sue]←(agnt)←[EAT]->(manr)→[QUICKLY]"))
;;     (setq g2 (pcg "[ANIMATE]←(agnt)←[EAT]→(obj)→[FOOD]"))
;;     (setq result (combine-conceptual-graphs g1 g2))
;;     (print-cgraph result))
