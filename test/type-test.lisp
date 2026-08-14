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


;;; Saving the relation catalog and reading it back must produce the same
;;; catalog. It did not, and the failure was the quiet kind: SOURCE-TYPES was
;;; written as a string of a list, which the reader turned into an unfindable
;;; type name and replaced with ⊤. Every relation came back accepting every
;;; source, and nothing anywhere signalled -- REL-USE simply started saying yes
;;; to everything. A test is the only thing that catches that class of bug,
;;; since the output looks right and the load succeeds.

(defvar *relation-roundtrip-mismatches* nil
  "What TYPE-TEST4 last found different, as (BEFORE AFTER) pairs.

   The suite runs each test with output going nowhere, so a failure would
   otherwise report only that something is wrong. This leaves the difference
   somewhere it can be read afterwards.")

(defun relation-catalog-snapshot ()
  "The relation catalog as comparable data: label, source labels, dest label,
   description. Labels rather than objects, since a reload mints new objects
   and identity is not what is being compared."
  (sort (loop for name in (all-relation-types)
              for rt = (get-relation-type name)
              collect (list (label rt)
                            (mapcar #'label (relation-source-list rt))
                            (label (dest-type rt))
                            (desc rt)))
        #'string< :key (lambda (entry) (string (first entry)))))

(defun type-test4 ()
  (let ((file (merge-pathnames "cgraph-relation-roundtrip.text"
                               (uiop:temporary-directory)))
        (before (relation-catalog-snapshot)))
    (save-relation-types file)
    ;; Read into a catalog of its own. Loading over the live one would install
    ;; whatever the round trip produced -- which, when it is broken, is exactly
    ;; the damage this test exists to detect, done to the image running it.
    (let* ((after (let ((*relation-type-catalog* (make-hash-table :test 'eql)))
                    (load-relation-types file t)
                    (relation-catalog-snapshot)))
           (diff (loop for b in before
                       for a in after
                       unless (equal a b) collect (list b a))))
      (setf *relation-roundtrip-mismatches* diff)
      (delete-file file)
      (and (plusp (length before))         ; an empty catalog proves nothing
           (= (length before) (length after))
           (null diff)))))

(defun type-test (&optional verbose)
  (with-test-types
    (when verbose (format t "~&TYPE-TEST~%"))
    (initialize-cgraph)
    (let ((result (not (null
                        (and
                         (type-test1)
                         (type-test2)
                         (type-test3)
                         (type-test4))))))
      (when verbose (format t "~&TYPE-TEST ~:[failed~;passed~]~%" result))
      result)))
