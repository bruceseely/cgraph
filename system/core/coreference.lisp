;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  coreference  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Co-reference links connect concepts in different graphs (possibly in
;;; different contexts) that refer to the same real-world entity.
;;;
;;; Standard CGIF notation:
;;;   *x — defining occurrence: introduces entity x into scope
;;;   ?x — bound occurrence: references entity already defined by *x
;;;
;;; Legacy notation (also supported):
;;;   ?x — first occurrence defines the label
;;;   ?x — subsequent occurrences establish co-reference links
;;;
;;; Scope: a ?x bound reference may point to a *x (or ?x) in the same
;;; context or any enclosing parent context.

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
  "Return the co-reference label text for a concept (e.g., '*c' or '?c').
   Standard CGIF: the defining occurrence renders *label (introduces the entity
   into scope) and each bound occurrence renders ?label (references it) -- BUT
   only when the label actually has a bound partner (a real coreference link).
   A lone defining label with nothing referencing it stays ?label (legacy style),
   so a single '[cat: ?c]' round-trips unchanged and no dangling *anchor is
   emitted."
  (let ((defining-label (concept-coref-label concept))
        (bound-label (coref-bound-label concept)))
    (cond (defining-label
           (format nil "~a~(~a~)"
                   (if (coreference concept) "*" "?")
                   defining-label))
          (bound-label    (format nil "?~(~a~)" bound-label))
          (t ""))))


(defun coref-labels-status ()
  "Return a list of all current co-reference label bindings"
  (let ((bindings (list)))
    (maphash (lambda (label concept)
               (push (list label concept) bindings))
             *coref-labels*)
    bindings))
