

(in-package #:conceptual-graphs)


(defun flatten (l)
  (cond ((null l) nil)
        ((atom l) (list l))
        (t (loop for a in l appending (flatten a)))))

(defmacro destructuring-setq (vars-map form)
 (let* ((symbols '(&rest &optional &key &allow-other-keys))
        (bindings (mapcar (lambda (s) (list (gensym) s))
                          (remove-if (lambda (x)
                                       (or (not (symbolp x))
                                           (member x symbols)))
                                     (flatten vars-map)))))
   `(let ,(mapcar #'car bindings)
      (destructuring-bind ,vars-map ,form
        (setq ,@(apply #'append bindings)))
      (setq ,@(apply #'append (mapcar #'reverse bindings))))))
