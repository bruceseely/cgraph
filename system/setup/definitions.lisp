
(in-package #:conceptual-graphs)


;;; unicode characters
;;; https://symbl.cc/en/unicode-table/

(defvar marked-char (code-char #x2714))
(defvar marked-string (princ-to-string marked-char))


(defvar top-concept-type (intern (string (code-char #x22A4)) :cg)) ;a symbol
(defvar top-concept-type-string (princ-to-string top-concept-type))

(defvar bottom-concept-type (intern (string (code-char #x22A5)) :cg)) ;a symbol
(defvar bottom-concept-type-string (princ-to-string bottom-concept-type))



(defvar left-arrow (code-char #x2190))
(defvar left-arrow-char left-arrow)
(defvar left-arrow-string (princ-to-string left-arrow))
(defvar left-arrow-arc)

(defvar right-arrow (code-char #x2192))
(defvar right-arrow-char right-arrow)
(defvar right-arrow-string (princ-to-string right-arrow))
(defvar right-arrow-arc)

(defvar larrow left-arrow)
(defvar rarrow right-arrow)
(defvar marrow #\-)

(defvar nope (code-char #x2310))
(defvar nope-char nope)
(defvar nope-string (princ-to-string nope))

;;; directory containing the concept-types and relation-types directories
;;; values are set in setup-cgraph() in initialize.lisp

(defvar *home* (namestring (user-homedir-pathname)))
(defvar *cgraph* nil)

;;; set by user
(defvar *cgraph-types-repo* (format nil "~a/repo/cgraph-types/" *home*))

;;; for overriding the directories holding types and data diretories
(defvar *cgraph-types-directory* nil)
(defvar *cgraph-examples-directory* nil)
(defvar *cgraph-data-directory* nil)

(defvar *cgraph-inits*  ())

;;; holds the current conttext
(defvar *context* nil)

;;; show [dog] instead of [dog:*]

(defvar *concepts-in-graph* ())

;;; modifies how segments & concepts are printed
(defvar *concise* t)
(defvar *debug-mode* nil)
(defvar *include-node-ref* nil)

(defvar *current-individual-number* 1)
(defvar *dynamically-create-individuals* t)
(defvar *node-ref-counter*)

(defvar *individuals* (list))

;;; store individual, indexed by id
;;; number -> indiv
(defvar *individual-id-table* (make-hash-table :test #'eql))

;;; all individuals are entered here
;;; cocept-type symbol -> (list of indiv)
(defvar *individual-type-table* (make-hash-table :test #'eql))

;; (cons type properties) -> indiv; for [DOG: Spot #]
(defvar *individual-property-table* (make-hash-table :test #'equalp))

(defvar *individual-id-assignment* :suitable)

(defvar *negated-concept* nil)
(defvar *in-graph-referent* nil)
(defvar *copy-map* (list))


(defvar *allow-dynamic-individual-creation* nil
  "The host system may want to define individuals, itself, and not have new individuals dynamically created. ")

(defvar *always-show-node-ref* nil
  "This is useful during debugging, so nodes that have the same printed representation can be distinguished.")

(defvar *always-format-nodes* nil
  "Causes nodes to be formatted as they look in graphs, rather than as Lisp objects.")

(defvar *always-print-ascii-arrows* nil
  "Use the string (eg. \"->\") instead of the single-character arrow (eg. →)")

(defvar *print-without-variables* nil)
