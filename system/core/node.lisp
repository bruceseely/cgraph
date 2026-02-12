;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

(defvar *node-ref-counter* 1)

(defun get-node-ref ()
  (declare (special *node-ref-counter*))
  (prog1
      *node-ref-counter*
    (incf *node-ref-counter*)))


(defclass basic-node ()
  ((marked :initform nil
	   :initarg :marked
	   :accessor marked)
   (node-ref :initform (get-node-ref)
             :reader node-ref)))



(defmethod marked ((x t))
  nil)

(defmethod mark ((node basic-node) &optional value)
  (prog1
      (marked node)
    (setf (marked node) (or value t))))

(defmethod mark ((node t) &optional value)
  (declare (ignore value))
  nil)

(defmethod mark ((list cons) &optional value)
  (assert (every #'(lambda (x) (typep x 'basic-node)) list))
  (mapc #'(lambda (item) (mark item value)) list))


(defmethod unmark ((node basic-node))
  (prog1
      (marked node)
    (setf (marked node) nil)))

(defmethod unmark ((node t))
  nil)

(defmethod unmark ((list cons))
  (assert (every #'(lambda (x) (typep x 'basic-node)) list))
  (mapc #'unmark list))


(defmethod nodes-eq ((node1 basic-node) (node2 basic-node))
  (eq node1 node2))

(defmethod nodes-eq ((node1 basic-node) (thing t))
  nil)

(defmethod nodes-eq ((thing t) (node2 basic-node))
  nil)




(defclass graph-node (basic-node)
  ((arcs :initarg :arcs
	 :initform (list)
	 :accessor arcs)
   (graph :initform nil
          :accessor graph
          :documentation "Back-pointer to the containing graph object")))

(defmethod num-arcs ((node graph-node))
  (length (arcs node)))

(defmethod num-unmarked-arcs ((node graph-node))
  (count-if-not #'marked (arcs node)))

(defmethod graph-node-p ((thing graph-node)) t)
(defmethod graph-node-p ((thing t)) nil)

(defmethod get-arc ((index integer) (node graph-node))
  (nth index (arcs node)))

(defmethod marked-arcs ((node graph-node))
  (remove-if-not #'marked (arcs node)))

(defmethod unmarked-arcs ((node graph-node))
  (remove-if #'marked (arcs node)))



(defmethod add-arc ((arc graph-node) (node graph-node) &key index)
  (let* ((arcs (arcs node))
	 (index (cond ((null arcs) 0)
		      ((null index) 0)
		      ((< index 0) 0)
		      ((> index (length arcs))
		       (length arcs))
		      (index)))
	 (start-arcs (subseq arcs 0 index))
	 (end-arcs (subseq arcs index)))
    (setf (arcs node) (append start-arcs (list arc) end-arcs)))
  arc)


(defmethod arc-lists-equal ((list1 list) (list2 list) &key (test #'nodes-equal))
  (and (= (length list1)
          (length list2))
       (null (set-difference list1 list2 :test test))
       (null (set-difference list2 list1 :test test))))

(defmethod arc-lists-equal ((node1 graph-node) (node2 graph-node) &key (test #'nodes-equal))
  (arc-lists-equal (arcs node1) (arcs node2) :test test))





(defgeneric copy-node (node))

(defmethod copy-node ((thing t))
  (error "COPY-NODE is not defined for the ~s, ~s" (type-of thing) thing))


;;; move to concept??
(defmethod closed-p ((node graph-node))
  (let* ((relations (arcs node))
         (concepts (apply #'append
                          (mapcar (lambda (r)
                                    (arcs r))
                                  relations)))
         (other-concepts (remove node concepts :test #'nodes-eq)))
    (every #'marked other-concepts)))


(defmethod without-node-ref ((text string))
  (let ((modified-text text))
    (block nil
      (loop
        (let ((pos (position #\+ modified-text)))
          (cond (pos
                 (let ((ref-end (position-if-not #'digit-char-p modified-text :start (1+ pos))))
                   (setf modified-text (format nil "~a~a"
                                               (subseq modified-text 0 pos)
                                               (subseq modified-text ref-end)))))
                (t
                 (return modified-text))))))
    modified-text))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  node-cache  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar *node-cache* (make-hash-table :test 'eql))

#+allegro
(defvar *node-cache* (make-hash-table :test 'eql :weak-keys t))

;;; gets bound to the cache in use
;;(defvar *node-cache* )


(defun make-node-cache ()
  (make-hash-table :test 'eql))

(defmethod cache-node ((node basic-node) )
  (setf (gethash (node-ref node) *node-cache*) node))

(defmethod remove-node ((node basic-node) )
  (remhash (node-ref node) *node-cache*))

(defmethod remove-node ((node-ref integer) )
  (remhash node-ref *node-cache*))

(defmethod cached-node ((node-ref integer) )
  (gethash node-ref *node-cache*))

(defun clear-cache (cache)
  (clrhash cache))
