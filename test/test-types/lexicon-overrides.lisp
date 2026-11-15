;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-
;;;
;;; lexicon-overrides.lisp -- how the test catalog's types are worded.
;;;
;;; The test type set's own generation overrides, loaded beside its type files
;;; as any domain's are (docs/lexicon-overrides.md). Entries for labels that
;;; say more than the English -- the same ones cgraph-types carries for these
;;; types; see the comments there.

(:label body-part       :lemma "body part")
(:label food-item       :lemma "food item")
(:label city-government :lemma "city government")

;; A marque used for the car is a capitalized count noun: "a Chevy".
(:label chevy-vehicle :lemma "Chevy")
(:label ford-vehicle  :lemma "Ford")
(:label tesla-vehicle :lemma "Tesla")
