
(defpackage :webserver
  (:use :common-lisp :hunchentoot :cl-who))

(in-package :webserver)


(defvar *acceptor* nil)


(defun start-server (port)
  (stop-server)
  (start (setf *acceptor*
               (make-instance 'easy-acceptor
                              :port port))))

(defun stop-server ()
  (when *acceptor*
    (when (started-p *acceptor*)
     (stop *acceptor*))))


#|
in a browser, go to localhost:4242  (or whatever port was used)
|#
#|
Prior to starting the server, acceptor is nil. After the server has been started (even if it has subsequently been stopped) it is no longer nil. The started-p test checks to see if an initialized easy-acceptor is started. If you try to stop an already stopped acceptor, you receive an error.
|#
