;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  arc  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass arc (graph-node)
  ((direction :initarg :direction
              :accessor direction
              :documentation "One of {:left :right :multi :unknown}")
   (arcnum :initarg :arcnum
           :accessor arcnum
           :type integer)))


(defclass m-arc (arc)
  ())

(defmethod print-object ((arc m-arc) stream)
  (format stream "~@[~a~]-"
          (and (arcnum arc) (plusp (arcnum arc)))))


;; (defmethod print-object ((arc arc) stream)
;;   (format stream "~@[~a~]~a"
;;           (and (arcnum arc) (plusp (arcnum arc)))
;;           (case (direction arc)
;;             (:right "->")
;;             (:left "<-"))))

(defmethod print-object ((arc arc) stream)
  (format stream "~@[~a~]~a"
          (and (arcnum arc) (plusp (arcnum arc))  (arcnum arc))
          (case (direction arc)
            (:right right-arrow)
            (:left left-arrow))))

(defmethod format-node ((node arc) &rest keys &key &allow-other-keys)
  (princ-to-string node))


(defmethod make-arc ((str string) &optional (arcnum 0))
  (let ((arc (cond ((string= str "->") (make-instance 'arc :direction :right :arcnum arcnum))
                   ((string= str "<-") (make-instance 'arc :direction :left  :arcnum arcnum))
                   ((string= str right-arrow-string) (make-instance 'arc :direction :right :arcnum arcnum))
                   ((string= str left-arrow-string) (make-instance  'arc :direction :left  :arcnum arcnum))
                   ((string= str "-")  (make-instance 'm-arc :direction :multi :arcnum arcnum)))))
    arc))


(defun left-arrow-arc (&optional arc-num)
  (make-arc "<-" arc-num))

(defun right-arrow-arc (&optional arc-num)
  (make-arc "->" arc-num))

(defmethod to-right ((arc arc))
  (eq (direction arc) :right))

(defmethod to-left ((arc arc))
  (eq (direction arc) :left))


(setf left-arrow-arc (left-arrow-arc))
(setf right-arrow-arc (right-arrow-arc))



(defmethod concept-inarc-p ((con concept) (rel relation))
  (nodes-equal con (outarc rel)))

(defmethod concept-outarc-p ((con concept) (rel relation))
  (find con (inarcs rel) :test #'nodes-equal))



;;; 1-based
(defmethod nth-arc ((n integer) (con concept))
  (when (<= 1 n (num-arcs con))
    (nth (1- n) (arcs con))))

;;; 1-based
(defmethod nth-arc ((n integer) (rel relation))
  (cond ((< 0 n (num-arcs rel))
         (nth (1- n) (arcs rel)))
        ((= n (num-arcs rel))
         (outarc rel))
        (t nil)))

(defmethod relation-outarc-p ((rel relation) (con concept))
  (nodes-equal con (outarc rel)))

(defmethod relation-inarc-p ((rel relation) (con concept))
  (find con (inarcs rel) :test #'nodes-equal))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  link  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; a link is an ephemeral association of a relation with a concept
;;; links aere not part of graphs
;;; If a single relation connects to three concepts, (link concept) provides two links
;;;

(defclass link ()
  ((relation :initarg :rel
             :accessor rel)
   (concept :initarg :con
            :accessor con)))

(defmethod print-object ((link link) stream)
    (let* ((arrow (cond ((eq (link-direction link) :left)
                         left-arrow)
                        (t right-arrow))))
      (format stream "~a~a~a" (rel link) arrow (con link))))



(defmethod link ((relation relation) (concept concept))
  (make-instance 'link :rel relation :con concept))

;;; handle either order of args
(defmethod link ((concept concept) (relation relation))
  (link relation concept))


(defmethod link-direction ((link link))
  (let ((pos (position (con link) (arcs (rel link)))))
    (case pos
      (0 :right)
      (1 :left))))


(defmethod link-p ((thing link))
  t)

(defmethod link-p ((thing t))
  nil)



(defmethod links ((concept concept))
  (let ((links (list)))
    (dolist (arc (arcs concept))
      (when arc
        (let ((other-concepts (remove concept (arcs arc))))

          ;; (format t "~2&concept:       ~s" concept)
          ;; (format t "~&links:          ~s" links)
          ;; (format t "~&arc:            ~s" arc)
          ;; (format t "~&other-concepts: ~s" other-concepts)
          ;; ;;(format t "~&: ~s" )

          (dolist (other-concept other-concepts)
            (push (link arc other-concept) links)))))
    ;; (format t "~&links: ~s" links)
    ;; (format t "~2%")
    links))


;;; find the link from concept that goes through relation
(defmethod link-through ((concept concept) (relation relation))
  (find relation (links concept) :key #'rel :test #'nodes-eq))


;; (defmethod links ((link link))
;;   (links (con link)))


;; (defmethod other-links ((node concept) )
;;   (let ((all-links (links node)))
;;     (cond (node
;;            (remove node all-links :key #'con :test #'nodes-eq))
;;           (t all-links))))

(defmethod other-links ((node concept) linked-concept)
  (let ((all-links (links node)))
    (cond (linked-concept
           (remove linked-concept all-links :key #'con :test #'nodes-eq))
          (t all-links))))


(defmethod links-equal ((link1 link) (link2 link))
  (and (nodes-equal (rel link1) (rel link2))
       (nodes-equal (con link1) (con link2))))

(defmethod links-eq ((link1 link) (link2 link))
  (and (nodes-equal (rel link1) (rel link2))
       (nodes-eq (con link1) (con link2))))

(defmethod marked ((link link))
  (marked (con link)))

(defmethod closed-p ((node concept))
  (every #'marked (links node)))

(defmethod closed-p ((link link))
  (closed-p (con link)))


;; (defmethod open-links ((node concept))
;;   (remove-if #'marked (links node) :key #'con))
;; (defmethod closed-links ((node concept))
;;   (remove-if-not #'marked (links node) :key #'con))


(defmethod open-links ((link link))
  (remove-if #'marked (links link)))

(defmethod open-links ((node graph-node))
  (remove-if #'marked (links node) :key #'con))


(defmethod closed-links ((link link))
  (remove-if-not #'marked (links link)))
