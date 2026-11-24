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
