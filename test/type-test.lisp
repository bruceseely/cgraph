;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)



(defun type-test1 ()
  (and
   (and
    (make-concept-type 'foo)
    (concept-type-defined-p 'foo)
    (not (concept-type-defined-p 'blivit)))

   ;; top & bottom
   (and
    (concept-type-defined-p (intern top-concept-type-string :cg))
    (concept-type-defined-p (intern bottom-concept-type-string :cg))
    ;;(concept-type-defined-p 'dog)
    (not (concept-type-defined-p 'blorf))
    (let ((top (get-concept-type (intern top-concept-type-string :cg)))
          (bottom (get-concept-type (intern bottom-concept-type-string :cg)))
          (dog (or (get-concept-type 'dog)
                   (make-concept-type 'dog))))
      (and
       (concept-type-p top)
       (concept-type-p bottom)
       (concept-type-p dog)
       (concept-type-p *concept-type-top*)
       (concept-type-p *concept-type-bottom*)

       (top-concept-type-p top)
       (top-concept-type-p *concept-type-top*)
       (not (top-concept-type-p bottom))

       (bottom-concept-type-p bottom)
       (bottom-concept-type-p *concept-type-bottom*)
       (not (bottom-concept-type-p top))

       (not (bottom-concept-type-p dog))
       (not (top-concept-type-p dog)))))

   ;; type equality
   (let ((cat (or (get-concept-type 'cat)
                  (make-concept-type 'cat))))
     (concept-type-defined-p 'cat)
     (types-eq cat cat)
     (types-equal cat cat)
     (types-eq cat (get-concept-type 'cat))

     (types-eq (get-concept-type 'foo)
               (get-concept-type 'foo))
     (not (types-eq (get-concept-type 'foo) (make-concept-type 'foo)))
     (types-equal (get-concept-type 'foo) (make-concept-type 'foo))
     (types-equal (make-concept-type 'foo) (make-concept-type 'foo))
     (not (types-eq (make-concept-type 'foo) (make-concept-type 'foo))))))


(defun type-test2 ()
  (let* ((concept-type-defs
           '((:label T)
             (:label entity :supertypes (⊤))
             (:label animate :supertypes (entity))
             (:label animal :supertypes (animate))
             (:label dog :supertypes (animal))
             (:label person :supertypes (animal))
             (:label girl :supertypes (person))))
         (concept-types (mapcar #'parse-concept-type-def concept-type-defs)))

    (and
     (has-supertype (get-concept-type 'person) (get-concept-type 'animate))
     (supertype-p   (get-concept-type 'person) (get-concept-type 'animate))

     (has-subtype (get-concept-type 'person) (get-concept-type 'animate))
     (subtype-p   (get-concept-type 'person) (get-concept-type 'animate)))))

(defun type-test3 ()
  (let* ((concept-type-defs
           '((:label T)
             (:label entity :supertypes (⊤))
             (:label animate :supertypes (entity))
             (:label mobile-entity :supertypes (physobj))
             (:label angel :supertypes (animate mobile-entity))
             (:label saraphem :supertypes (angel))
             (:label archangels :supertypes (saraphem))
             (:label animal :supertypes (animate mobile-entity))
             (:label dog :supertypes (animal))
             (:label person :supertypes (animal))
             (:label girl :supertypes (person))
             (:label robot :supertypes (animate machine mobile-entity))
             ))
         (concept-types (mapcar #'parse-concept-type-def concept-type-defs)))
    (and
     (null (set-exclusive-or (common-direct-supertypes 'animal 'angel)
                             (mapcar #'get-concept-type '(mobile-entity animate))))
     (eq (minimal-common-supertype 'animal 'angel) (get-concept-type 'mobile-entity)) ; two??
     (supertype-p (get-concept-type 'animal) (get-concept-type 'animal))
     (proper-supertype-p (get-concept-type 'animal) (get-concept-type 'monkey))
     (is-common-supertype (get-concept-type 'mobile-entity) (get-concept-type 'monkey) (get-concept-type 'angel))

     (null (set-exclusive-or (common-direct-subtypes 'mobile-entity 'animate)
                             (mapcar #'get-concept-type '(animal angel robot))))
     (eq (maximal-common-subtype 'physobj 'tool) (get-concept-type 'robot))
     (subtype-p (get-concept-type 'animal) (get-concept-type 'animal))
     (proper-subtype-p (get-concept-type 'monkey) (get-concept-type 'animal))
     (common-subtype-p (get-concept-type 'robot) (get-concept-type 'machine) (get-concept-type 'animate)))))


(defun type-test (&optional verbose)
  (when verbose (format t "~&TYPE-TEST~%"))
  (initialize-cgraph)

  (load-test-types)
  (let ((result (not (null
                     (and
                      (type-test1)
                      (type-test2)
                      (type-test3))))))

    (when verbose (format t "~&TYPE-TEST ~:[failed~;passed~]~%" result))
    result))
