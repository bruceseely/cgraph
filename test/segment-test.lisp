;;; -*- Mode; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)


(defun test-segment-collect-segments (test-number &optional verbose)
  ;;(reset-cgraph) ;; this kills the temporary type definitions
  (setf *context* (make-context))
  (let ((*print-pretty* nil))
    (destructuring-bind (graph-node graph-string)
        (make-test-graph test-number)
      (let* ((segments (collect-segments graph-node))
             (graph-string (canonicalize-graph-string graph-string))
             (text (canonicalize-graph-string (format-segments-from-node graph-node segments 0 3)))

             (pass (and text (graph-strings-equal graph-string text))))
        (when verbose
          (format t "~3&test: ~a" test-number)
          (format t "   ===================================~%~s~%"  graph-string)
          (unless pass
            (format t "~2&segments: ~s~%"  segments)
            (format t "~&supplied:  ~s~%"  graph-string)
            (format t "~&generated: ~s~%"  text))
          (format t "~&>> pass: ~s~%"  pass))
        (values pass graph-string text)))))

(defun test-segments-collect-segments (&optional verbose)
  (let ((result t))
    (dotimes (i 10)
      (setq result (and (test-segment-collect-segments i verbose) result)))
    result))



(defmethod test-segment-split-segment ((node graph-node) &optional verbose)
  (when verbose
    (format t "~%test segment split~%"))
  (let* ((segments (make-graph-segments node)))
    (dolist (seg segments)
      (terpri)
      (when (> (length (path seg)) 3)
        (multiple-value-bind (seg1 seg2)
	    (split-segment seg)
          (when  verbose
	    (format t "~&seg1: ~s" seg1)
	    (format t "~&seg2: ~s" seg2))))
      t)))

(defun make-test-segment (simple-graph-string)
  (let* ((graph (pcg simple-graph-string))
         (nodes (nodes graph)))
    (make-segment (path nodes))))

(defun test-segments-split-segment (&optional verbose)
  (let* ((segment (make-test-segment "[DOG: Spotz]<-(agnt)<-[EAT]->(obj)->[food]."))
         (node (car (path segment))))
    (test-segment-split-segment node verbose))
  t)



(defun segment-test (&optional verbose)
  (with-test-types
    (let ((result t)
          (*allow-dynamic-individual-creation* t)
          (*include-node-ref* nil))
      (setq result (and (test-segments-collect-segments verbose) result))
      (setq result (and (test-segments-split-segment verbose) result))
      result)))
