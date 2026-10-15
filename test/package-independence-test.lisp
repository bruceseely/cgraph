;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)


;;; Type names resolve the same way whatever package the caller is in.
;;;
;;; The type catalogs are keyed by :CG symbols, and a caller outside :CG -- a
;;; user at a CL-USER REPL, the README's examples -- hands in symbols interned
;;; somewhere else. Every other suite runs with *PACKAGE* = :CG and reads its
;;; symbols there, so none of them could see this break; this one builds its
;;; foreign symbols at run time, in a scratch package, and parses with
;;; *PACKAGE* bound to it.

(defun package-independence-test (&optional verbose)
  (with-test-types
    (let ((ok t)
          (elsewhere (make-package (symbol-name (gensym "CG-PACKAGE-TEST-")) :use nil)))
      (flet ((check (name result)
               (setf ok (and ok (and result t)))
               (when (or verbose (not result))
                 (format t "~&  ~:[fail~;pass~] ~a~%" result name)))
             (foreign (name) (intern name elsewhere)))
        (when verbose (format t "~&PACKAGE-INDEPENDENCE-TEST~%"))
        (unwind-protect
             (progn
               (check "a concept type from a foreign symbol"
                      (eq (ignore-errors (get-concept-type (foreign "DOG")))
                          (get-concept-type 'dog)))
               (check "a concept type from a keyword"
                      (eq (ignore-errors (get-concept-type :dog))
                          (get-concept-type 'dog)))
               (check "concept-type-exists with a foreign symbol"
                      (concept-type-exists (foreign "DOG")))
               (check "a relation type from a foreign symbol"
                      (eq (ignore-errors (get-relation-type (foreign "AGNT")))
                          (get-relation-type 'agnt)))
               (check "relation-type-exists with a foreign symbol"
                      (relation-type-exists (foreign "AGNT")))
               (check "subtype-p across foreign symbols"
                      (ignore-errors
                       (subtype-p (get-concept-type (foreign "DOG"))
                                  (get-concept-type (foreign "ANIMAL")))))

               (let ((*package* elsewhere)
                     (*context* (make-context)))
                 (check "a graph string parses with *PACKAGE* elsewhere"
                        (equal "[EAT]→(agnt)→[DOG]."
                               (ignore-errors
                                (format-cgraph (make-cgraph "[EAT]→(agnt)→[DOG].")))))
                 (check "and its labels are :CG symbols"
                        (eq (ignore-errors
                             (label (concept-type
                                     (graph-head (make-cgraph "[DOG].")))))
                            'dog)))

               (define-concept-type :label (foreign "PACKAGE-TEST-PUP")
                                    :supertypes (list (foreign "DOG")))
               (check "define-concept-type catalogues a foreign label under :CG"
                      (concept-type-exists 'package-test-pup))
               (check "and links its foreign supertype"
                      (ignore-errors
                       (subtype-p (get-concept-type 'package-test-pup)
                                  (get-concept-type 'animal)))))
          (let ((pup (ignore-errors (get-concept-type 'package-test-pup))))
            (when pup (remove-concept-type pup)))
          (delete-package elsewhere))
        ok))))
