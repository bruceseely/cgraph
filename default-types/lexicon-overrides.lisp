;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-
;;;
;;; lexicon-overrides.lisp -- how the shipped types are worded.
;;;
;;; The third file of a type set, beside concept-types.lisp and
;;; relation-types.lisp, read by the English generator. One form per entry,
;;; :label naming the type, then any keys REGISTER-LEXICON-ENTRY takes; see
;;; docs/lexicon-overrides.md. A type needs an entry only when the English
;;; departs from what the lattice implies, so most types have none.

;; Compound labels whose hyphen is ontology, not English: without these the
;; generator says "a body-part".
(:label body-part :lemma "body part")
(:label food-item :lemma "food item")
