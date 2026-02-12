;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  coreference  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Co-reference links connect concepts in different graphs (possibly in
;;; different contexts) that refer to the same real-world entity.
;;;
;;; Syntax: ?label (e.g., ?c, ?cat)
;;; First occurrence defines the label, subsequent occurrences establish
;;; co-reference links to the defining concept.
;;;
;;; Unlike variables (*x, *y) which are for serializing a single node that
;;; appears multiple times in linear notation, co-reference labels connect
;;; distinct concept objects across context boundaries.

;;; Maps coref-label -> concept that defines it
(defvar *coref-labels* (make-hash-table :test 'equal))


(defun initialize-coreferences ()
  "Initialize the co-reference label cache for a new parse session"
  (setf *coref-labels* (make-hash-table :test 'equal)))


(defmethod coref-label-node ((label symbol))
  "Get the concept that defines a co-reference label"
  (gethash (intern (string label) :keyword) *coref-labels*))

(defmethod coref-label-node ((label string))
  (coref-label-node (intern (string-upcase label) :keyword)))

(defmethod coref-label-node ((label character))
  (coref-label-node (intern (string (char-upcase label)) :keyword)))


(defmethod set-coref-label ((concept concept) (label symbol))
  "Associate a concept with a co-reference label (defining occurrence)"
  (let ((key (intern (string label) :keyword)))
    (setf (gethash key *coref-labels*) concept))
  concept)

(defmethod set-coref-label ((concept concept) (label string))
  (set-coref-label concept (intern (string-upcase label) :keyword)))


(defmethod link-coreference ((c1 concept) (c2 concept))
  "Establish a bidirectional co-reference link between two concepts"
  (unless (eq c1 c2)
    (pushnew c2 (coreference c1) :test #'eq)
    (pushnew c1 (coreference c2) :test #'eq))
  (values c1 c2))


(defmethod coref-label-setp ((concept concept))
  "Check if a concept has a co-reference label defined"
  (maphash (lambda (label node)
             (when (eq node concept)
               (return-from coref-label-setp label)))
           *coref-labels*)
  nil)


(defmethod concept-coref-label ((concept concept))
  "Get the co-reference label for a concept, if any"
  (coref-label-setp concept))

(defmethod coref-text ((concept concept))
  "Return the co-reference label text for a concept (e.g., '?c')"
  (let ((label (concept-coref-label concept)))
    (cond (label (format nil "?~(~a~)" label))
          (t ""))))


(defun coref-labels-status ()
  "Return a list of all current co-reference label bindings"
  (let ((bindings (list)))
    (maphash (lambda (label concept)
               (push (list label concept) bindings))
             *coref-labels*)
    bindings))
