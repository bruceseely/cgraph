;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

(defvar *web-acceptor* nil)

(defun web-static-dir ()
  "Return the absolute path to the web/ static files directory."
  (namestring (merge-pathnames "web/" (asdf:system-source-directory "cgraph-web"))))

(defun start-web-server (&key (port 8080))
  "Start the Hunchentoot web server on PORT (default 8080)."
  (when *web-acceptor*
    (stop-web-server))
  (setf *web-acceptor*
        (make-instance 'hunchentoot:easy-acceptor :port port))
  (hunchentoot:start *web-acceptor*)
  (format t "~&CGraph web server started on http://localhost:~a~%" port)
  *web-acceptor*)

(defun stop-web-server ()
  "Stop the Hunchentoot web server."
  (when *web-acceptor*
    (hunchentoot:stop *web-acceptor*)
    (setf *web-acceptor* nil)
    (format t "~&CGraph web server stopped.~%")))
