

;;;make the slime-compile-defun and slime-compile-and-load-file functions replace the fasl file where asdf put it
(setf swank:*fasl-pathname-function*
        (lambda (lisp-pathname)
          (asdf:apply-output-translations lisp-pathname)))
