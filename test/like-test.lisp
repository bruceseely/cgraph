;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)

;;; A new type as a copy of another: (define-concept-type :label 'region
;;; :like 'place). One-time: the copy takes the source's supertypes,
;;; graph-compatibility and canonical graph -- retyped to the new name, so it
;;; describes itself -- and nothing links the two afterwards.

(defun like-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label)))
             (supers (type)
               (sort (mapcar (lambda (s) (symbol-name (label s)))
                             (direct-supertypes (get-concept-type type)))
                     #'string<)))

        ;; --- the rename ----------------------------------------------------
        (let ((renamed (rename-type-in-graph-string
                        "[APPLE]- (attr)→[RED] (part)→[APPLE-CORE] [PERSON: Apple] [ apple: #]"
                        '(apple) 'banana)))
          (check "the type after [ is renamed, keeping its case"
                 (and (search "[BANANA]-" renamed) (search "[ banana: #]" renamed)))
          (check "a longer name containing it is not"
                 (search "[APPLE-CORE]" renamed))
          (check "nor a referent spelled like it"
                 (search "[PERSON: Apple]" renamed)))
        (check "an alias of the source is renamed too"
               (equal "[TRUCK]→(poss)←[PERSON]"
                      (rename-type-in-graph-string "[CAR]→(poss)←[PERSON]"
                                                   '(automobile car auto) 'truck)))
        (check "no graph stays no graph"
               (equal "" (rename-type-in-graph-string "" '(apple) 'banana)))

        ;; --- the copy ------------------------------------------------------
        (define-concept-type :label 'lt-region :like 'place)
        (check "the copy has the source's supertypes"
               (equal (supers 'place) (supers 'lt-region)))
        (check "and its canonical graph, retyped"
               (equal "[LT-REGION]←(loc)←[⊤]."
                      (canonical-graph-string (get-concept-type 'lt-region))))
        (check "the source is untouched"
               (equal "[PLACE]←(loc)←[⊤]."
                      (canonical-graph-string (get-concept-type 'place))))
        (check "a copy is a sibling, not a subtype"
               (not (subtype-p 'lt-region 'place)))

        (define-concept-type :label 'lt-truck :like 'car)
        (check "copying by an alias copies the type it names"
               (equal (supers 'automobile) (supers 'lt-truck)))
        (check "aliases are not copied"
               (null (concept-type-aliases (get-concept-type 'lt-truck))))
        (check "nor subtypes"
               (null (proper-subtypes (get-concept-type 'lt-truck))))

        (define-concept-type :label 'lt-zone :like 'place :supertypes '(lt-region)
                             :canonical-graph "[LT-ZONE]")
        (check "given supertypes win over the source's"
               (equal '("LT-REGION") (supers 'lt-zone)))
        (check "a given canonical graph wins over the source's"
               (equal "[LT-ZONE]" (canonical-graph-string (get-concept-type 'lt-zone))))

        (check "an unknown source is an error, not an empty type"
               (handler-case (progn (define-concept-type :label 'lt-ghost :like 'lt-no-such-type)
                                    nil)
                 (error () t))))
      (when verbose
        (format t "~&like-test: ~:[FAILED <<<~;passed~]~%" ok))
      ok)))
