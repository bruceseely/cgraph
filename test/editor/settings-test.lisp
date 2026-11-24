(in-package :conceptual-graphs)

;;; The settings page's server half (system/web/settings.lisp): listing every
;;; declared option, changing one by its printed value, refusing what does not
;;; fit, resetting -- and the same over real HTTP, on a throwaway acceptor.
;;; Every option it touches is put back as it was.

(defun %settings-snapshot ()
  (mapcar (lambda (o) (cons o (clopt:option-value o))) (clopt:list-options)))

(defun %settings-restore (snapshot)
  (dolist (pair snapshot)
    (setf (clopt:option-value (car pair)) (cdr pair))))

(defun settings-test (&optional verbose)
  (let ((ok t)
        (snapshot (%settings-snapshot))
        (strategy "CONCEPTUAL-GRAPHS::*ALIGNMENT-STRATEGY*")
        (indent   "CONCEPTUAL-GRAPHS::*GRAPH-REFERENT-INDENT*")
        (arrows   "CONCEPTUAL-GRAPHS::*ALWAYS-PRINT-ASCII-ARROWS*"))
    (flet ((check (label pass)
             (setf ok (and ok (and pass t)))
             (when (or verbose (not pass))
               (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label)))
           (refused-p (thunk)
             (nth-value 1 (ignore-errors (funcall thunk)))))
      (unwind-protect
           (progn
             ;; --- the listing -------------------------------------------------
             (let ((json (settings-json)))
               (check "the listing has cgraph's system"
                      (search "\"name\":\"conceptual-graphs\"" json))
               (check "  and an option by its wire name, with its choices"
                      (and (search strategy json)
                           (search "\"choices\":[\":automatic\",\":individuals\"]" json)))
               (check "  and says how each is edited"
                      (and (search "\"kind\":\"boolean\"" json)
                           (search "\"kind\":\"choice\"" json)
                           (search "\"kind\":\"text\"" json))))

             ;; --- changing ----------------------------------------------------
             (change-setting strategy ":individuals")
             (check "a choice, by its printed form" (eq *alignment-strategy* :individuals))
             (check "  and the reply says it is no longer the default"
                    (search "\"isDefault\":false" (setting-json (find-setting strategy))))
             (check "a value that is not a choice is refused, and nothing changes"
                    (and (refused-p (lambda () (change-setting strategy ":sloppy")))
                         (eq *alignment-strategy* :individuals)))
             (change-setting arrows "t")
             (check "a boolean, by t" (eq *always-print-ascii-arrows* t))
             (change-setting arrows "nil")
             (check "  and back by nil -- a choice that is NIL itself"
                    (null *always-print-ascii-arrows*))
             (change-setting indent "6")
             (check "a text value is read" (eql *graph-referent-indent* 6))
             (check "  and must fit the type: -1 is not (integer 0)"
                    (and (refused-p (lambda () (change-setting indent "-1")))
                         (eql *graph-referent-indent* 6)))
             (check "  and must be one value"
                    (refused-p (lambda () (change-setting indent "6 7"))))
             (check "  and is never evaluated: #. is refused"
                    (and (refused-p (lambda () (change-setting indent "#.(+ 1 2)")))
                         (eql *graph-referent-indent* 6)))
             (check "an unknown option is refused, and nothing is interned"
                    (and (refused-p (lambda () (change-setting "CONCEPTUAL-GRAPHS::*NO-SUCH-SETTING*" "1")))
                         (null (find-symbol "*NO-SUCH-SETTING*" :conceptual-graphs))))
             (reset-setting indent)
             (check "reset puts the default back"
                    (and (eql *graph-referent-indent* 4)
                         (clopt:option-default-p (find-setting indent))))

             ;; --- over HTTP ---------------------------------------------------
             (let ((acceptor (%start-test-acceptor *environment*)))
               (check "a test acceptor started" acceptor)
               (when acceptor
                 (unwind-protect
                      (let ((port (hunchentoot:acceptor-port acceptor)))
                        (check "GET /settings serves the page"
                               (search "<title>CGraph Settings</title>"
                                       (%http-get-body port "/settings")))
                        (check "GET /api/settings lists the options"
                               (search strategy (%http-get-body port "/api/settings")))
                        (let ((reply (%http-get-body
                                      port (format nil "/api/settings/set?name=~a&value=~a"
                                                   (hunchentoot:url-encode strategy)
                                                   (hunchentoot:url-encode ":automatic")))))
                          (check "/api/settings/set changes it in the handler thread"
                                 (and (search "\"ok\":true" reply)
                                      (eq *alignment-strategy* :automatic))))
                        (check "  and a refusal comes back as ok:false with the reason"
                               (search "\"ok\":false"
                                       (%http-get-body
                                        port (format nil "/api/settings/set?name=~a&value=~a"
                                                     (hunchentoot:url-encode strategy)
                                                     (hunchentoot:url-encode ":sloppy"))))))
                   (hunchentoot:stop acceptor)))))
        (%settings-restore snapshot)))
    ok))


;;; --- saved sets --------------------------------------------------------------
;;;
;;; In a settings directory of its own, under the temporary directory, removed
;;; at the end: a person's ~/.cgraph/settings/ is never read or written.

(defun %post-body (port path params)
  "Body of a POST to PATH with PARAMS, an alist, form-encoded."
  (let ((body (format nil "~{~a~^&~}"
                      (mapcar (lambda (p) (format nil "~a=~a" (car p)
                                                  (hunchentoot:url-encode (cdr p))))
                              params)))
        (socket (usocket:socket-connect "127.0.0.1" port :element-type 'character)))
    (unwind-protect
         (let ((stream (usocket:socket-stream socket)))
           (format stream "POST ~a HTTP/1.0~c~cHost: 127.0.0.1~c~c~
                           Content-Type: application/x-www-form-urlencoded~c~c~
                           Content-Length: ~d~c~c~c~c~a"
                   path #\Return #\Linefeed #\Return #\Linefeed #\Return #\Linefeed
                   (length body) #\Return #\Linefeed #\Return #\Linefeed body)
           (force-output stream)
           (loop for line = (read-line stream nil)
                 while (and line (plusp (length (string-trim '(#\Return) line)))))
           (with-output-to-string (out)
             (loop for line = (read-line stream nil)
                   while line
                   do (write-string (string-trim '(#\Return) line) out))))
      (usocket:socket-close socket))))

(defun settings-sets-test (&optional verbose)
  (let ((ok t)
        (snapshot (%settings-snapshot))
        (saved-directory clopt:*settings-directory*)
        (dir (merge-pathnames (format nil "cgraph-settings-test-~d-~d/"
                                      (get-universal-time) (random 100000))
                              (uiop:temporary-directory))))
    (flet ((check (label pass)
             (setf ok (and ok (and pass t)))
             (when (or verbose (not pass))
               (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))
      (unwind-protect
           (progn
             (let ((clopt:*settings-directory* nil))
               (check "no settings directory: the listing says so"
                      (search "\"directory\":null" (settings-sets-json))))
             ;; SETF, not LET: the handler threads below see only the GLOBAL
             ;; value -- as the page does, where INIT sets it.
             (setf clopt:*settings-directory* dir)
             (progn
               (mapc #'clopt:reset-option (clopt:list-options))
               (setf (clopt:option-value '*alignment-strategy*) :individuals)
               (save-settings-set "work" nil)
               (check "a saved set is listed, with what it holds"
                      (let ((json (settings-sets-json)))
                        (and (search "\"name\":\"work\"" json)
                             (search "\"entries\":1" json)
                             (search "\"changes\":[]" json))))
               (clopt:reset-option '*alignment-strategy*)
               (setf (clopt:option-value '*graph-referent-indent*) 8)
               (check "  and what loading it would change"
                      (let ((json (settings-sets-json)))
                        (and (search "\"name\":\"*alignment-strategy*\",\"current\":\":automatic\",\"saved\":\":individuals\"" json)
                             (search "\"name\":\"*graph-referent-indent*\",\"current\":\"8\",\"saved\":\"4\"" json))))
               (load-settings-set "work")
               (check "loading it sets what it lists and resets the rest"
                      (and (eq *alignment-strategy* :individuals)
                           (eql *graph-referent-indent* 4)))

               ;; the startup set: loaded on top, never stopping a session
               (mapc #'clopt:reset-option (clopt:list-options))
               (setf (clopt:option-value '*graph-referent-indent*) 2)
               (save-settings-set *startup-settings-name* nil)
               (mapc #'clopt:reset-option (clopt:list-options))
               (setf (clopt:option-value '*always-print-ascii-arrows*) t)
               (let ((*standard-output* (make-broadcast-stream)))
                 (load-startup-settings))
               (check "the startup set loads on top of what is already set"
                      (and (eql *graph-referent-indent* 2)
                           (eq *always-print-ascii-arrows* t)))
               (with-open-file (out (clopt:settings-path *startup-settings-name*)
                                    :direction :output :if-exists :supersede)
                 (write-line "(not a settings file" out))
               (check "a startup set that does not read is reported, not an error"
                      (search "was not loaded"
                              (with-output-to-string (*standard-output*)
                                (load-startup-settings))))
               (check "  and the listing shows the broken set with its error"
                      (search "\"name\":\"startup\",\"startup\":true,\"error\":" (settings-sets-json)))

               ;; over HTTP
               (let ((acceptor (%start-test-acceptor *environment*)))
                 (check "a test acceptor started" acceptor)
                 (when acceptor
                   (unwind-protect
                        (let ((port (hunchentoot:acceptor-port acceptor)))
                          (check "GET /api/settings/sets lists the sets"
                                 (search "\"name\":\"work\"" (%http-get-body port "/api/settings/sets")))
                          (check "POST save over an existing set: refused, and says it exists"
                                 (search "\"exists\":true"
                                         (%post-body port "/api/settings/save" '(("name" . "work")))))
                          (check "  and with replace=1 it is replaced"
                                 (search "\"ok\":true"
                                         (%post-body port "/api/settings/save"
                                                     '(("name" . "work") ("replace" . "1")))))
                          (check "a name that could leave the directory is refused"
                                 (and (search "\"ok\":false"
                                              (%post-body port "/api/settings/save"
                                                          '(("name" . "../escape"))))
                                      (not (probe-file (merge-pathnames "../escape.settings" dir)))))
                          (setf (clopt:option-value '*graph-referent-indent*) 9)
                          (check "POST load loads it in the handler thread"
                                 (and (search "\"ok\":true"
                                              (%post-body port "/api/settings/load" '(("name" . "work"))))
                                      (eql *graph-referent-indent* 2))))
                     (hunchentoot:stop acceptor))))))
        (%settings-restore snapshot)
        (setf clopt:*settings-directory* saved-directory)
        (uiop:delete-directory-tree dir :validate t :if-does-not-exist :ignore)))
    ok))
