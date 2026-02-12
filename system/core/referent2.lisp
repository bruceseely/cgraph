;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

(defgeneric read-referent (stream))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  referent  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; p 85


(defclass referent-mixin (basic-node)
  ;; only ENTITIES have names, other individuals do not
  ;; a named concept is an indiividual concept
  ;; :name "b" is shortcut in [a] for [a]->(NAME)->[WORD: "b"]

  ((concept :initform nil
            :initarg :concept
            :accessor concept)))

(defmethod concept-type ((referent referent))
  (concept-type (concept referent)))



(defgeneric make-referent (content &optional concept))

(defmethod make-referent ((content individual) &optional concept)
  (when concept
    (setf (concept



(defmethod make-rererent ((content list) &optional concept)
  (let* ((props (sans-prop content :id :variable))
        ;; (id (cond ((and content (getf content :id)))
        ;;           (t (next-individual-number))))
        (ctype (when concept (concept-type concept)))
        (individual (get-individual ctype :id (and content (getf content :id))
                                          :properties props)))
    (make-referent individual concept)))
