;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-
;;;
;;; The settings page: every option a loaded system declared with
;;; CLOPT:DEFOPTION, its value, its documentation, and a way to change it.
;;;
;;;   GET  /settings              the page (web/settings.html)
;;;   GET  /api/settings          every option, grouped by system, as JSON
;;;   POST /api/settings/set      name, value -> the option after the change
;;;   POST /api/settings/reset    name        -> the option, back at its default
;;;
;;; It lists every registered option, not only cgraph's: CG-FROM-PARSE's appear
;;; when it is loaded. Everything goes through clopt's public functions, so the
;;; page could move to a system of its own without change.
;;;
;;; A change is to the running image -- the variable's GLOBAL value, which is
;;; what a handler thread sees and sets -- and lasts until the image exits.
;;;
;;; NAMES AND VALUES ON THE WIRE. An option is named by its symbol's package and
;;; name, "CONCEPTUAL-GRAPHS::*ALIGNMENT-STRATEGY*", and found by comparing that
;;; with the registered options: a request can name only an option that exists,
;;; and never interns anything. A value is its printed Lisp form, lower case
;;; (":individuals", "nil", "4", "\"text\""). A value one of the option's choices
;;; prints as is taken to be that choice, without reading; anything else is READ
;;; with *READ-EVAL* off, in a package of its own so a stray symbol lands nowhere
;;; that matters, and must then satisfy the option's type or nothing changes.

(in-package #:conceptual-graphs)

(defpackage #:cgraph-settings-reader
  (:use #:cl)
  (:documentation "Where the settings page reads and prints values. Its own
package, so a symbol typed into a text field is interned here and nowhere else,
and keywords print with their colon."))

(defun setting-id (option)
  "The name OPTION goes by on the wire: PACKAGE::NAME."
  (let ((symbol (clopt:option-name option)))
    (format nil "~a::~a" (package-name (symbol-package symbol)) (symbol-name symbol))))

(defun find-setting (id)
  "The registered option whose SETTING-ID is ID, or NIL."
  (and (stringp id)
       (find id (clopt:list-options) :key #'setting-id :test #'string=)))

(defun print-setting-value (value)
  "VALUE as the page shows it and sends it back: its printed form, lower case."
  (let ((*package* (find-package '#:cgraph-settings-reader))
        (*print-case* :downcase)
        (*print-readably* nil)
        (*print-pretty* nil))
    (prin1-to-string value)))

(defun read-setting-value (option text)
  "The value TEXT names for OPTION. One of OPTION's choices, if TEXT is how that
choice prints; otherwise TEXT read as one Lisp datum with *READ-EVAL* off.
Signals an error for text that does not read as exactly one datum."
  (let* ((choices (clopt:option-choices option))
         ;; POSITION, not FIND: a choice may be NIL itself
         (pos (position text choices :key #'print-setting-value :test #'string-equal)))
    (if pos
        (nth pos choices)
        (let ((*read-eval* nil)
              (*package* (find-package '#:cgraph-settings-reader)))
          (multiple-value-bind (value end) (read-from-string text)
            (unless (every (lambda (c) (member c '(#\Space #\Tab #\Newline #\Return)))
                           (subseq text end))
              (error "~s is more than one value." text))
            value)))))

(defun setting-kind (option)
  "How the page edits OPTION: \"boolean\" (a checkbox), \"choice\" (a menu of
OPTION-CHOICES), or \"text\" (a field holding the printed value)."
  (let ((choices (clopt:option-choices option)))
    (cond ((equal choices '(nil t)) "boolean")
          (choices "choice")
          (t "text"))))

(defun setting-json (option)
  "OPTION as the page sees it."
  (format nil "{\"id\":\"~a\",\"name\":\"~a\",\"kind\":\"~a\",\"value\":\"~a\",~
               \"default\":\"~a\",\"isDefault\":~:[false~;true~],\"type\":\"~a\",~
               \"choices\":~a,\"doc\":\"~a\"}"
          (json-escape (setting-id option))
          (json-escape (string-downcase (symbol-name (clopt:option-name option))))
          (setting-kind option)
          (json-escape (print-setting-value (clopt:option-value option)))
          (json-escape (print-setting-value (clopt:option-default option)))
          (clopt:option-default-p option)
          (json-escape (print-setting-value (clopt:option-type option)))
          (json-string-array (mapcar #'print-setting-value (clopt:option-choices option)))
          (json-escape (or (clopt:option-doc option) ""))))

(defun settings-json ()
  "Every registered option, grouped by system."
  (format nil "{\"systems\":[~{~a~^,~}]}"
          (loop for system in (clopt:option-systems)
                collect (format nil "{\"name\":\"~a\",\"options\":[~{~a~^,~}]}"
                                (json-escape (string-downcase (symbol-name system)))
                                (mapcar #'setting-json
                                        (clopt:list-options :system system))))))

(defun change-setting (id text)
  "Set the option ID to the value TEXT names. Returns the JSON for the option
after the change, or signals an error -- an unknown option, text that does not
read, a value not of the option's type -- having changed nothing."
  (let ((option (or (find-setting id)
                    (error "There is no option ~a." id))))
    (setf (clopt:option-value option) (read-setting-value option text))
    (setting-json option)))

(defun reset-setting (id)
  "Set the option ID back to its default; the option's JSON."
  (let ((option (or (find-setting id)
                    (error "There is no option ~a." id))))
    (clopt:reset-option option)
    (setting-json option)))

(defun %settings-reply (thunk)
  "{\"ok\":true,\"option\":...} from THUNK's JSON, or {\"ok\":false,\"error\":...}
with status 400 when it signals."
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (handler-case (format nil "{\"ok\":true,\"option\":~a}" (funcall thunk))
    (error (e)
      (setf (hunchentoot:return-code*) hunchentoot:+http-bad-request+)
      (format nil "{\"ok\":false,\"error\":\"~a\"}"
              ;; not pretty: the page wraps the line itself, and the pretty
              ;; printer would break it mid-type -- "(INTEGER" / "0)"
              (json-escape (let ((*print-pretty* nil)) (princ-to-string e)))))))

(hunchentoot:define-easy-handler (handle-settings-page :uri "/settings") ()
  (setf (hunchentoot:content-type*) "text/html; charset=utf-8")
  (no-store)
  (read-static-file "settings.html"))

(hunchentoot:define-easy-handler (handle-api-settings :uri "/api/settings") ()
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (no-store)
  (settings-json))

(hunchentoot:define-easy-handler (handle-api-settings-set :uri "/api/settings/set")
    (name value)
  (%settings-reply (lambda () (change-setting name (or value "")))))

(hunchentoot:define-easy-handler (handle-api-settings-reset :uri "/api/settings/reset")
    (name)
  (%settings-reply (lambda () (reset-setting name))))
