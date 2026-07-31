;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

(defvar *web-acceptor* nil)

(defun web-static-dir ()
  "Return the absolute path to the web/ static files directory."
  (namestring (merge-pathnames "web/" (asdf:system-source-directory "cgraph-web"))))

;;; --- Request logging --------------------------------------------------------
;;; Hunchentoot defaults both log destinations to *ERROR-OUTPUT*, which under
;;; SLIME is the REPL -- so every request the type editor's browser makes
;;; prints a line there, and a session of clicking around buries whatever you
;;; were reading. Default to files under ~/.cgraph/logs/ instead; see
;;; *WEB-LOG-DESTINATION* for the other settings.
;;;
;;; A pathname destination is opened and appended for each entry, which
;;; Hunchentoot notes is costly at high throughput. Irrelevant here: this is a
;;; loopback server with one browser tab on it.

(defun web-log-file (kind)
  "Absolute namestring of the KIND (:ACCESS or :MESSAGE) log file."
  (let ((name (ecase kind
                (:access  "web-access.log")
                (:message "web-message.log"))))
    (namestring (merge-pathnames name (or *cgraph-log-directory*
                                          (user-homedir-pathname))))))

(defun web-log-destination (kind)
  "Resolve *WEB-LOG-DESTINATION* into a Hunchentoot log destination for KIND:
   a pathname to append to, a stream, or NIL for no logging."
  (ecase *web-log-destination*
    (:file  (pathname (web-log-file kind)))
    (:repl  *error-output*)
    ((nil)  nil)))

(defun apply-web-log-destinations (&optional (acceptor *web-acceptor*))
  "Push the current *WEB-LOG-DESTINATION* onto a running ACCEPTOR, so the
   setting can be changed without restarting the server."
  (when acceptor
    (setf (hunchentoot:acceptor-access-log-destination acceptor)
          (web-log-destination :access)
          (hunchentoot:acceptor-message-log-destination acceptor)
          (web-log-destination :message))
    acceptor))

(defun report-web-log-destination (&optional (stream *standard-output*))
  (case *web-log-destination*
    (:file (format stream "~&  request log:  ~a~%" (web-log-file :access)))
    (:repl (format stream "~&  request log:  this REPL ~
                           (set *web-log-destination* to :file to redirect)~%"))
    ((nil) (format stream "~&  request log:  off~%"))))

(defun start-web-server (&key (port 8080))
  "Start the Hunchentoot web server on PORT (default 8080)."
  (when *web-acceptor*
    (stop-web-server))
  (setf *web-acceptor*
        (make-instance 'hunchentoot:easy-acceptor
                       :port port
                       :address "127.0.0.1"
                       :access-log-destination  (web-log-destination :access)
                       :message-log-destination (web-log-destination :message)))
  (hunchentoot:start *web-acceptor*)
  (format t "~&CGraph web server started on http://localhost:~a~%" port)
  (report-web-log-destination)
  *web-acceptor*)

(defun stop-web-server ()
  "Stop the Hunchentoot web server."
  (when *web-acceptor*
    (hunchentoot:stop *web-acceptor*)
    (setf *web-acceptor* nil)
    (format t "~&CGraph web server stopped.~%")))

(defun show-web-log (&key (kind :access) (lines 20))
  "Print the last LINES of the KIND (:ACCESS or :MESSAGE) web-server log.
   Reads the whole file, which is fine at the sizes this server produces."
  (let ((path (web-log-file kind)))
    (cond ((not (probe-file path))
           (format t "~&No ~(~a~) log yet at ~a~%" kind path))
          (t
           (let ((all (with-open-file (in path :external-format :utf-8)
                        (loop for line = (read-line in nil) while line
                              collect line))))
             (format t "~&~a (last ~a of ~a line~:P)~%" path
                     (min lines (length all)) (length all))
             (dolist (line (last all lines))
               (format t "  ~a~%" line))))))
  (values))

(defun clear-web-logs ()
  "Truncate both web-server log files."
  (dolist (kind '(:access :message))
    (let ((path (web-log-file kind)))
      (when (probe-file path)
        (with-open-file (out path :direction :output
                                  :if-exists :supersede
                                  :if-does-not-exist :create)
          (declare (ignore out))))
      (format t "~&cleared ~a~%" path)))
  (values))

(defun web-server-started-p ()
  "Has the Hunchentoot web server started?"
  (let ((started (hunchentoot:started-p *web-acceptor*)))
    (format t "~&CGraph web server is running.~%")
    started))
