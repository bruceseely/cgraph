
(in-package #:conceptual-graphs)


;;; unicode characters
;;; https://symbl.cc/en/unicode-table/

(defvar marked-char (code-char #x2714))
(defvar marked-string (princ-to-string marked-char))

(defvar top-type (code-char #x22A4))
(defvar top-type-string (princ-to-string top-type))

(defvar bottom-type (code-char #x22A5))
(defvar bottom-type-string (princ-to-string bottom-type))


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
(defvar *cgraph* nil)
(defvar *cgraph-data-directory* nil)
(defvar *cgraph-types-directory* nil)

;;; for overriding the directories holding types and data diretories
(defvar *cgraph-types-directory-dir* nil)
(defvar *cgraph-data-directory-dir* nil)

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
(defvar *allow-dynamic-individual-creation* nil)

(defvar *always-show-id* nil)
(defvar *print-without-variables* nil)

(defvar *always-format-nodes* nil)

(defvar *copy-map* (list))
