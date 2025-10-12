(asdf:load-system "hunchentoot")
(asdf:load-system "drakma")

;;; Subclass ACCEPTOR
(defclass vhost (hunchentoot:acceptor)
  ;; slots
  ((dispatch-table
    :initform '()
    :accessor dispatch-table
    :documentation "List of dispatch functions"))
  ;; options
  (:default-initargs                    ; default-initargs must be used
   :address "127.0.0.1"))               ; because ACCEPTOR uses it

;;; Specialise ACCEPTOR-DISPATCH-REQUEST for VHOSTs
(defmethod hunchentoot:acceptor-dispatch-request ((vhost vhost) request)
  ;; try REQUEST on each dispatcher in turn
  (mapc (lambda (dispatcher)
	  (let ((handler (funcall dispatcher request)))
	    (when handler               ; Handler found. FUNCALL it and return result
	      (return-from hunchentoot:acceptor-dispatch-request (funcall handler)))))
	(dispatch-table vhost))
  (call-next-method))

;;; ======================================================================
;;; Now all we need to do is test it

;;; Instantiate VHOSTs
(defvar vhost1 (make-instance 'vhost :port 50001))
(defvar vhost2 (make-instance 'vhost :port 50002))

;;; Populate each dispatch table
(push
 (hunchentoot:create-prefix-dispatcher "/foo" 'foo1)
 (dispatch-table vhost1))
(push
 (hunchentoot:create-prefix-dispatcher "/foo" 'foo2)
 (dispatch-table vhost2))

;;; Define handlers
(defun foo1 () "Hello")
(defun foo2 () "Goodbye")

;;; Start VHOSTs
(hunchentoot:start vhost1)
(hunchentoot:start vhost2)

;;; Make some requests
(drakma:http-request "http://127.0.0.1:50001/foo")
;;; =|
;;; 127.0.0.1 - [2012-06-08 14:30:39] "GET /foo HTTP/1.1" 200 5 "-" "Drakma/1.2.6 (SBCL 1.0.56; Linux; 2.6.32-5-686; http://weitz.de/drakma/)"
;;; =>
;;; "Hello"
;;; 200
;;; ((:CONTENT-LENGTH . "5") (:DATE . "Fri, 08 Jun 2012 14:30:39 GMT")
;;;  (:SERVER . "Hunchentoot 1.2.3") (:CONNECTION . "Close")
;;;  (:CONTENT-TYPE . "text/html; charset=utf-8"))
;;; #<PURI:URI http://127.0.0.1:50001/foo>
;;; #<FLEXI-STREAMS:FLEXI-IO-STREAM {CA90059}>
;;; T
;;; "OK"
(drakma:http-request "http://127.0.0.1:50002/foo")
;;; =|
;;; 127.0.0.1 - [2012-06-08 14:30:47] "GET /foo HTTP/1.1" 200 7 "-" "Drakma/1.2.6 (SBCL 1.0.56; Linux; 2.6.32-5-686; http://weitz.de/drakma/)"
;;; =>
;;; "Goodbye"
;;; 200
;;; ((:CONTENT-LENGTH . "7") (:DATE . "Fri, 08 Jun 2012 14:30:47 GMT")
;;;  (:SERVER . "Hunchentoot 1.2.3") (:CONNECTION . "Close")
;;;  (:CONTENT-TYPE . "text/html; charset=utf-8"))
;;; #<PURI:URI http://127.0.0.1:50002/foo>
;;; #<FLEXI-STREAMS:FLEXI-IO-STREAM {CAE8059}>
;;; T
;;; "OK"
