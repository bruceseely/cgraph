;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

(defun alpha-lessp (x y)
  ;; Returns T if printed representation of X is less than that of Y.
  ;; Characters and numbers sort before symbols/strings, before random objects,
  ;; before lists. Characters and numbers are compared using CHAR<; symbols/strings with STRING-LESSP;
  ;; random objecs by printing them(!); lists are compared recursively.
  (cond
    ((numberp x) (or (not (numberp y)) (< x y)))
    ((numberp y) (not (numberp x)))
    ((characterp x) (or (not (characterp y)) (char< x y)))
    ((characterp y) (not (characterp x)))
    ((or (symbolp x) (stringp x)) (or (not (or (symbolp y) (stringp y))) (string-lessp x y)))
    ((or (symbolp y) (stringp y)) nil)
    ((atom x) (or (consp y) (string-lessp (prin1-to-string x) (prin1-to-string y))))
    ((atom y) nil)
    (t
     (do ((x1 x (cdr x1))
	  (y1 y (cdr y1)))
	 ((null y1))
       (or x1 (return t))
       (and (alpha-lessp (car x1) (car y1)) (return t))
       (and (alpha-lessp (car y1) (car x1)) (return ()))))))



(defun replace-in-string (new-text old-text string)
  (let ((collected (list))
        (index 0))
    (loop
      (let ((place (search old-text string :start2 index :test #'string-equal)))
        (cond ((null place)
               (push (subseq string index) collected)
               (return))
              ((< (+ place (length old-text)) (length string))
               (push (subseq string index place) collected)
               (push new-text collected)
               (setq index (+ place (length old-text))))
              )))
    (apply #'strcat (reverse collected))))



;;; from Common Lisp Recipes
(defun splice (list &key (start 0) (end (length list)) new)
  (setf list (cons nil list)) ;; add dummy cell
  (let ((reroute-start (nthcdr start list)))
    (setf (cdr reroute-start)
          (nconc (make-list (length new)) ;; empty cons cells
                 (nthcdr (- end start)    ;; tail of old list
                         (cdr reroute-start)))
          list (cdr list)))      ;; remove dummy cell
  (replace list new :start1 start) ;; fill empty cells
  list)


(defmethod hash-collect (item hashtable &key (key #'identity) (test #'eql))
  (let ((collection (list)))
    (block nil
      (maphash (lambda (k v)
                 ;;(format t "~&~s: ~s" k v)
                 (when (funcall test item (funcall key (car v)))
                   (push (list k v) collection)))
               hashtable))
    collection))


;;;; Admin stuff

(defmethod delete-files ((directory pathname) (pattern string) )
  (let ((files (directory-files directory pattern))
        (subdirectories (subdirectories (pathname directory))))
    (dolist (file files)
      (delete-file file))
    (dolist (subdir subdirectories)
      (delete-files subdir pattern))))

(defun cleanup-files (&optional (directory "~/repo/cgraph/"))
  (delete-files directory "*.lisp~")
  (delete-files directory "*.lisp#")
  (delete-files directory "*.fasl" ))
