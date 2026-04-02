
;;; save this as .swank in user's home directory

;;; make the slime-compile-defun and slime-compile-and-load-file
;;; functions replace the fasl file where asdf put it

(setf swank:*fasl-pathname-function*
        (lambda (lisp-pathname options)
          (declare (ignore options))
          (asdf:apply-output-translations lisp-pathname)))
