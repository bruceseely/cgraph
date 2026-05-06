;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Testing contexts in conceptual graphs
;;;

(in-package #:conceptual-graphs)

(defvar *pc)
(defmethod cache-test (&optional verbose)
  (with-test-types
    (setf verbose t) ; <==================================================<<<<
    (let* ((*include-node-ref* nil)
           (parent-context (make-context))
           (con1 (make-concept 'dog '(:name "Spot") :context parent-context))
           (computed-id (when con1
                          (when (referent con1) (id (content (referent con1)))))))

    (when verbose
      (format t "~&parent-context: ~s~%"  parent-context)
      (format t "~&con1, ~s, in context ~a~%"  con1 parent-context))

    (let* ((lookup-con1 (retrieve-concept 'dog '(:name "Spot") :context parent-context)))
      (when verbose
        (format t "~&lookup-con1: ~a~%"   lookup-con1)
        (format t  "~&---------------------------------------------~2%"))

      (let* ((context  (make-context parent-context))
             (con2 (make-concept 'dog '(:name "Spot") :context context))
             (computed-id (when con2
                            (when (referent con2) (id (content (referent con2)))))))
        (when verbose
          (format t "~&context: ~s~%"  context)
          (format t "~&con2, ~s, in context ~a~%"  con2 context))

        (let* ((lookup-con2 (retrieve-concept 'dog '(:name "Spot") :context context)))
          (when verbose
            (format t "~&lookup-con2: ~s~%"  lookup-con2)
            (format t  "~&---------------------------------------------~2%"))

          (let* ((lookup-con3 (retrieve-concept 'dog '(:name "Spot") :context parent-context)))
            (when verbose
              (format t "~&lookup-con3: ~s~%"  (pcg lookup-con3))
              (format t  "~&---------------------------------------------~2%"))

            (let* ((con (get-concept 'dog '(:name "Spot") :context parent-context))
                   (con2 (get-concept 'dog `(:name "Spot") :id computed-id ))
                   (con3 (get-concept 'dog `(:name "Spot") :id computed-id ))
                   )
              (when verbose
                (format t "~&computed-id: ~s~%"  computed-id)
                (format t "~&con: ~s~%" (pcg con))
                (format t "~&con2: ~s~%" (pcg con2))
                (format t  "~&---------------------------------------------~2%"))



              (and (concepts-equal con1 lookup-con1)
                   (concepts-equal con2 lookup-con2)
                   )))))))))
