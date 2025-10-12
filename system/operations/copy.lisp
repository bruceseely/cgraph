;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  copy rule  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defvar *new-relation* nil)


(defmethod find-or-make-concept-copy ((concept concept))
  (or (cadr (find concept *copy-map* :key #'car :test #'nodes-eq))
      (copy-concept concept)))

(defmethod find-or-make-relation-copy ((relation relation))
  (or (cadr (find relation *copy-map* :key #'car :test #'nodes-eq))
      (copy-relation relation)))


(defun relace-arc (node old-arc new-arc)
  (let ((pos (position old-arc (arcs node))))
    (setf (nth pos (arcs node)) new-arc)))


(defmethod copy-cgraph ((node graph-node))
  (let* ((old-nodes (collect-nodes node))
         (new-nodes (mapcar #'copy-node old-nodes))
         (node-map (mapcar (lambda (orig new) (cons orig new))
                           old-nodes new-nodes)))

    (flet ((lookup (node)
             (let ((pair (find (node-ref node) node-map
                               :key (lambda (n) (node-ref (car n)))
                               :test #'=)))
               (cdr pair))))

      ;; after copy, new nodes have no arc lists
      ;; replace old nodes with new nodes in the arc lists
      (dolist (old-node old-nodes)
        (let ((new-node (lookup old-node)))
          (setf (arcs new-node) (mapcar #'lookup (arcs old-node)))))

      ;;(format t "~&copy graph: ~s~%"  (pcg (lookup node)))

      ;; check for variables
      (dolist (old-node old-nodes)
        (when (node-variable old-node)
          (set-variable (lookup old-node))))

      ;;return the copy of the supplied node
      (lookup node))))


#|
;; example
(let* ((s "[PERSON: Sue]←(agnt)←[GIVE]-
                                  (obj)→[FOOD]←(obj)←[EAT: *x]
                                  (rcpt)→[DOG: Spot]←(agnt)←[EAT: *x].")
           (g (pcg s))
           (c (copy-cgraph g)))
      (initialize-variables)
      (print (pcg c))
      (initialize-variables)
      (string-equal (flatten-cgraph (pcg c)) (flatten-cgraph s)))
|#
