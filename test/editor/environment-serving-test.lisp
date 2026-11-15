(in-package :conceptual-graphs)

;;; The server and editor sessions run in the environment they were given, not
;;; whatever the handler thread happens to see (system/web/server.lisp,
;;; WITH-EDITOR-SESSION).
;;;
;;; The server half makes a real HTTP request: a binding of *ENVIRONMENT* in the
;;; test's thread is exactly what a Hunchentoot worker thread can NOT see, so
;;; nothing short of a request on a worker thread tests it. The acceptor is a
;;; throwaway one on a spare loopback port, and the handler answers only on it.

(defun %env-tagged (tag)
  "An empty environment told apart by TAG, kept in its *LOADED-TYPES-SOURCE*."
  (make-environment :loaded-types-source tag))

(hunchentoot:define-easy-handler (handle-environment-serving-test
                                  :uri "/test/environment-tag"
                                  :acceptor-names '(environment-serving-test))
    ()
  (setf (hunchentoot:content-type*) "text/plain")
  (or *loaded-types-source* "none"))

(defun %http-get-body (port path)
  "Body of GET http://127.0.0.1:PORT/PATH, by hand over usocket so the test
   needs no HTTP client library."
  (let ((socket (usocket:socket-connect "127.0.0.1" port :element-type 'character)))
    (unwind-protect
         (let ((stream (usocket:socket-stream socket)))
           (format stream "GET ~a HTTP/1.0~c~cHost: 127.0.0.1~c~c~c~c"
                   path #\Return #\Linefeed #\Return #\Linefeed #\Return #\Linefeed)
           (force-output stream)
           ;; skip the headers, up to the blank line
           (loop for line = (read-line stream nil)
                 while (and line (plusp (length (string-trim '(#\Return) line)))))
           (with-output-to-string (out)
             (loop for line = (read-line stream nil)
                   while line
                   do (write-string (string-trim '(#\Return) line) out))))
      (usocket:socket-close socket))))

(defun %start-test-acceptor (environment)
  "A CGRAPH-ACCEPTOR serving ENVIRONMENT on the first free port tried, or NIL."
  (loop for port from 18731 below 18751
        do (let ((acceptor (make-instance 'cgraph-acceptor
                                          :name 'environment-serving-test
                                          :environment environment
                                          :port port
                                          :address "127.0.0.1"
                                          :access-log-destination nil
                                          :message-log-destination nil)))
             (when (ignore-errors (hunchentoot:start acceptor))
               (return acceptor)))))

(defun environment-serving-test (&optional verbose)
  (let ((ok t)
        (served (%env-tagged "served"))
        (caller (%env-tagged "caller")))
    (flet ((check (label pass)
             (setf ok (and ok (and pass t)))
             (when (or verbose (not pass))
               (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

      ;; --- the server -------------------------------------------------------
      (let ((acceptor (%start-test-acceptor served)))
        (check "a test acceptor started" acceptor)
        (when acceptor
          (unwind-protect
               (let ((*environment* caller))
                 (check "a request is handled in the server's environment, not the caller's"
                        (string= "served"
                                 (%http-get-body (hunchentoot:acceptor-port acceptor)
                                                 "/test/environment-tag"))))
            (hunchentoot:stop acceptor))))

      ;; --- editor sessions --------------------------------------------------
      (let ((session (let ((*environment* caller))
                       (make-editor-session :original nil :kind :string))))
        (register-editor-session session)
        (unwind-protect
             (progn
               (check "a session keeps the environment it was opened in"
                      (eq caller (session-environment session)))
               (check "and its handlers run in it, whatever the server's is"
                      (string= "caller"
                               (let ((*environment* served))
                                 (with-editor-session (s (session-id session))
                                   *loaded-types-source*))))
               (check "a session opened inside one inherits it (a nested editor)"
                      (eq caller
                          (let ((*environment* served))
                            (with-editor-session (s (session-id session))
                              (session-environment
                               (make-editor-session :original nil :kind :string)))))))
          (forget-editor-session session))))
    (when verbose
      (format t "~&environment-serving-test: ~:[FAILED <<<~;passed~]~%" ok))
    ok))
