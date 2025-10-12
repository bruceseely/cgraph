;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  simplify rule  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; returns a list of pairs where each pair is a duplicate as defined by :key :test
(defmethod collect-duplicates ((list list) &key (key #'identity) (test #'eql))
  (let ((collections (list)))
    (do* ((src-list list (cdr src-list)))
         ((null src-list))
      (let ((first (car src-list))
            (dups (list)))
        (dolist (item (cdr src-list))
          (when (funcall test (funcall key first) (funcall key item))
            (push (list first item) dups)))

        (when (plusp (length dups)) ; i.e. duplicates found
          (setf collections (append collections dups))
          ;; (pushnew (reverse dups) collections
          ;;          :key #'car
          ;;          :test (lambda (item list-element)
          ;;                  (funcall test
          ;;                           (funcall key item)
          ;;                           (funcall key list-element))))
          )
          (setf collections (funcall #'append collections))
        ))
   (reverse collections)))

;; (collect-duplicates '(a b c d a d r t y))
;; (collect-duplicates '(4 5 3 9 4 3 8 3 2 7) :test #'=)
;; (collect-duplicates '((4 a) (5 b) (3 g) (9 k) (4 r) (3 w) (8 f) (2 p) (3 k)  (7 q)) :test #'= :key #'car)



(defmethod collect-common-relations ((list1 list) (list2 list) &key (key #'identity) (test #'eql))
  (let ((collection (list)))
    (flet ((eq-test (node1 node2)
             (and (funcall test node1 node2)
                  ;;(arc-lists-equal node1 node2 :test test)
                  )))
      (dolist (item1 list1)
        (let ((item2 (find item1 list2 :key #'identity :test #'eq-test)))
          (when item2
            (push (list item1 item2) collection)))))
    (reverse collection)))




(defmethod find-duplicate-relations ((concept concept))
  (collect-duplicates (arcs concept) :test #'equal :key #'relation-type))

(defmethod find-duplicate-links ((concept concept) &key (key #'identity) (test #'eql))
  (collect-duplicates (links concept) :test test :key key))


;; (defmethod simplify ((concept concept))
;;   "Deletes duplicate links linked to the concept."
;;   (let (;;(duplicate-links (find-duplicate-links concept :key #'rel))
;;         (duplicate-links (find-duplicate-links concept :key #'princ-to-string :test #'equal)))

;;     ; duplicates may be more than two
;;     (dolist (link-pair duplicate-links)
;;       (let* ((link1 (car link-pair))
;;              (link2 (cadr link-pair)))
;;         (cond ((and (nodes-equal (rel link1) (rel link2))
;;                     (nodes-eq (con link1) (con link2)))
;;                (remove-arc (rel link2) concept)
;;                (remove-arc (rel link2) (con link1))
;;                ;; should do something like this
;;                ;; (dispose-node (rel link2))
;;                )
;;               ((and (nodes-equal (rel link1) (rel link2))
;;                     (nodes-equal (con link1) (con link2)))
;;                (remove-arc (rel link2) concept))))))
;;   concept)


(defmethod simplify ((concept concept))
  "Deletes duplicate links linked to the concept."
  (let (;;(duplicate-links (find-duplicate-links concept :key #'rel))
        (duplicate-arcs (find-duplicate-relations concept))
        ;;(duplicate-links (find-duplicate-links concept :key #'princ-to-string :test #'equal))
        )

                                        ; duplicates may be more than two
    (dolist (arc-pair duplicate-arcs)
      (let ((arc1 (car arc-pair))
            (arc2 (cadr arc-pair)))
        (let ((link1 (link-through concept arc1))
              (link2 (link-through concept arc2)))
          (cond ((null link1)
                 (remove-arc arc1 concept))
                ((null link2)
                 (remove-arc arc2 concept))
                ((and (nodes-equal (rel link1) (rel link2))
                      (nodes-equal (con link1) (con link2)))
                 (remove-arc (rel link2) concept)
                 (remove-arc (rel link2) (con link1))
                 ;; should do something like this
                 ;; (dispose-node (rel link2))
                 )
                ((and (nodes-equal (rel link1) (rel link2))
                      (nodes-equal (con link1) (con link2)))
                 (remove-arc (rel link2) concept)))))))
  concept)

;; (progn
;;   (initialize-cgraph)
;;   (setq eat-con (find-concept 'eat graph))
;;   (simplify eat-con)
;;   )

(defmethod simplify-cgraph ((node concept))
  "Deletes duplicate relations in the cgraph."
  (let ((concepts (collect-concepts node)))
    ;;(format t "~&concepts: ~s~%"  concepts)
    (dolist (node concepts)
      (simplify node)))
  node)
