
(in-package :conceptual-graphs)

(defmethod test-individual-io ((individual individual) &optional verbose)
  ;;(when verbose (format t "~&(test-individual-io ~s)~2%"  individual-string))
  (let* ((individual1 individual)
         (properties1  (properties individual1))
         (id1 (id individual1))
         (type1 (concept-type individual1))

         (individual2 (make-individual type1 properties1 ))
         (properties2  (properties individual2))
         (id2 (id individual2))
         (type2 (concept-type individual2))
         (result (and (equalp properties1 properties2)
                      (eql type1 type2))))
    (when verbose
      (format t "~&individual1:   ~s~%"  individual1)
      (format t "~&properties1: ~s~%"  properties1)
      (format t "~&id1: ~s~%"  id1)
      (format t "~&type1: ~s~%"  type1)
      (format t "~&individual2:   ~s~%"  individual2)
      (format t "~&properties2: ~s~%"  properties2)
      (format t "~&id2: ~s~%"  id2)
      (format t "~&type2: ~s~%"  type2)
      (format t "~&result - (equalp properties1 properties2):   ~s~%"  (equalp properties1 properties2))
      (format t "~&result - (eql type1 type2):   ~s~%"  (eql type1 type2))

      (format t "~&result:   ~s~%"  result)
      (cond ((null result)
             (format t "~&** FAIL: ~s : ~s~%"  (format-properties properties1) (format-properties properties2)))
            (t
             (format t "~&pass: ~s ==> ~s~%"  (format-properties properties1) (format-properties properties2)))))
    result))



(defun indiv-test (def &optional (verbose t))
  (when def
    (destructuring-bind (str desc) def
      (let* ((properties (parse-properties str))
             (indiv (when properties (make-individual 'dog properties))))
        (when verbose
          (format t "~&testing ~s, ~a~%" str desc)
          (format t "~&indiv: ~s~%"  indiv)   ; debug
          )
        (prog1
            (if indiv
                (test-individual-io indiv  verbose)
                t)
          (when verbose
            (format t "~2&-----------------------------------------------------~%")))))))


;;; (indiv-test (list ""           "a generic concept; eg. dog"))

(defun individual-test-1 (&optional verbose)
  (when verbose (format t "~&Individual Test 1 --~%" ))
  (initialize-cgraph)
  (let ((node-defs (list
                    (list ""           "a generic concept; eg. dog")
                    (list "#"          "a specific, unidentified concept; the dog")
                    (list "#3"         "a specific, identified concept ; that dog")
                    (list "Spot"       "a specific concept; eg. the dog Spot")
                    (list "*x"         "a variable")
                    (if *concise*
                        (list ""       "generic")
                        (list "*"      "generic"))
                    (if *concise*
                        (list "Fido*x"      "a specific, named concept; the dog Fido")
                        (list "Fido *x"     "a specific, named concept; the dog Fido"))
                    (if *concise*
                        (list "@5.3ft."     "a length of 5 feet")
                        (list "@5.3 ft."    "a length of 5 feet"))
                    (if *concise*
                        (list "@5ft."       "a length of 5 feet")
                        (list "@5 ft."      "a length of 5 feet"))
                    (if *concise*
                        (list "len1@5ft."   "a length of 5 feet, named len1")
                        (list "len1 @5 ft." "a length of 5 feet, named len1"))
                    (if *concise*
                        (list "@5in#3"       "the third specific length of 5 inches (without whitespace)")
                        (list "@5 in #3"     "the third specific length of 5 inches (with whitespace)"))
                    (if *concise*
                        (list "{}"           "a set of dogs; plural, dogs")
                        (list "{*}"          "a set of dogs, with generic marker"))
                    (list "{fred, bill}"     "a set of two; ")
                    (list "{fred, #23}"      "a set of two; "))))

    ;;(format t "~3&node-defs: ~s~%" node-defs)
    (every #'identity
           (mapcar (lambda (def) (indiv-test def verbose))
                   (remove nil node-defs)))))



(defun individual-test-2 (&optional verbose)
  (when verbose (format t "~&Individual Test 2 --~%~%" ))
  (initialize-cgraph)
  (setf *always-show-node-ref* nil)
  (let (result1)
    (let* ((id (next-individual-number))
           (x (make-individual 'dog `(:name "Fido") :id id))
           (unique (unique-individual-p x))
           ;;(target (if unique "Fido" (format nil "Fido#~d" (id x))))
           (target (if unique "Fido" (format-individual x)))
           (name (when x (format-individual x)))
           (result (string-equal name target)))
      (setq result1 result)
      (when (or verbose (not result))
        (format t "~&x: ~s~%" x)
        (format t "~&id: ~s~%" id)
        (format t "~&unique: ~s~%" unique)
        (format t "~&target: ~s~%" target)
        (format t "~&name: ~s~%" name)
        (format t "~&result: ~s~%" result)
        (format t "~&(string-equal name ~a): target~%"  (string-equal name target))))
    result1))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun individual-test-3 (&optional verbose)
  (when verbose (format t "~2&Individual Test 3 --~%~%" ))
  (initialize-cgraph)
  (let (result1 result2 result3 result4)


    (let* ((id (next-individual-number))
           (x (make-individual 'dog `(:name "Fido") :id id))
           (unique (unique-individual-p x))
           (target (if unique "Fido" (format nil "Fido#~d" (id x))))
           (name (when x (format-individual x)))
           (result (string-equal name target)))
      (setq result1 result)
      (when (or verbose (not result))
        (format t "~&x: ~s~%" x)
        (format t "~&id: ~s~%" id)
        (format t "~&unique: ~s~%" unique)
        (format t "~&target: ~s~%" target)
        (format t "~&name: ~s~%" name)
        (format t "~&result: ~s~%" result)
        (format t "~&(string-equal name ~a): target~%"  (string-equal name target))))

    (make-individual 'dog  `(:name "Spot") :id 37)

    ;; lookup by properties and id
    (let* ((id (next-individual-number))
           (x (get-individual (get-concept-type 'dog) :id 37 :properties `(:name "Spot")))
           (unique (unique-individual-p x))
           (target (if unique "Spot" (format nil "Spot#~d" id)))
           (name (when x (format-individual x)))
           (result (string-equal name target)))
      (setq result2 result)
      (when (or verbose (not result))
        (format t "~2&x: ~s~%" x)
        (format t "~&id: ~s~%" id)
        (format t "~&unique: ~s~%" unique)
        (format t "~&target: ~s~%" target)
        (format t "~&name: ~s~%" name)
        (format t "~&result: ~s~%" result)
        (format t "~&(string-equal name target): ~s~%" (string-equal name target))))

    ;; lookup by properties
    (let* ((id (next-individual-number))
           (x (get-individual (get-concept-type 'dog) :properties `(:name "Fido")))
           (unique (unique-individual-p x))
           (target (if unique "Fido" (format nil "Fido#~d" id)))
           (name (when x (format-individual x)))
           (result (string-equal name target)))
      (setq result3 result)
      (when (or verbose (not result))
        (format t "~2&x: ~s~%" x)
        (format t "~&id: ~s~%" id)
        (format t "~&unique: ~s~%" unique)
        (format t "~&target: ~s~%" target)
        (format t "~&name: ~s~%" name)
        (format t "~&result: ~s~%" result)
        (format t "~&(string-equal name target): ~s~%"  (string-equal name target))))

    ;; lookup by id
    (let* ((id (next-individual-number))
           (x (get-individual (get-concept-type 'dog) :id 37 ))
           (unique (unique-individual-p x))
           (target (if unique "Spot" (format nil "Spot#~d" id)))
           (name (when x (format-individual x)))
           (result (string-equal name target)))
      (setq result4 result)
      (when (or verbose (not result))
        (format t "~2&x: ~s~%" x)
        (format t "~&id: ~s~%" id)
        (format t "~&unique: ~s~%" unique)
        (format t "~&target: ~s~%" target)
        (format t "~&name: ~s~%" name)
        (format t "~&result: ~s~%" result)
        (format t "~&(string-equal name target): ~s~%"  (string-equal name target))))

    (and result1 result2 result3 result4)))


;;; INDIVIDUALS-EQUAL used to compare type and properties and NOT the id, so two
;;; distinct individuals of one type with no properties were equal. See
;;; notes/known-issues.md. Named individuals hid it, because a name lives in
;;; properties: Annapolis and Baltimore differed, #604 and #605 did not.
;;;
;;; The consequence worth guarding is not the predicate but what it reached:
;;; OBJECTS-EQUAL → RELATIONS-EQUIVALENT-P → SIMPLIFY, which deleted a relation
;;; that duplicated nothing.
(defun individual-identity-test (&optional verbose)
  (when verbose (format t "~&Individual identity --~%"))
  (let ((ok t))
    (flet ((check (label pass)
             (setf ok (and ok (and pass t)))
             (when (or verbose (not pass))
               (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

      ;; Two bare individuals of one type: same shape, different things.
      (let ((a (make-individual 'city '() :id (next-individual-number)))
            (b (make-individual 'city '() :id (next-individual-number))))
        (check "distinct ids are not equal"        (not (individuals-equal a b)))
        (check "and same-individual-p agrees"      (not (same-individual-p a b)))
        (check "an individual equals itself"       (individuals-equal a a))
        (check "reflexive under same-individual-p" (same-individual-p a a)))

      ;; The reach: SIMPLIFY must not delete an arc to a DIFFERENT city.
      (let* ((g (make-cgraph "[PERSON: #603]- (loc)→[CITY: #604] (loc)→[CITY: #605]"))
             (person (find-if (lambda (c) (types-eq (concept-type c) (get-concept-type 'person)))
                              (collect-concepts g))))
        (dolist (c (collect-concepts g)) (simplify c))
        (check "simplify keeps arcs to different individuals"
               (= 2 (length (arcs person)))))

      ;; ...and must still drop a real duplicate, or the fix went too far.
      (let* ((g (make-cgraph "[PERSON: #606]- (loc)→[CITY: #607] (loc)→[CITY: #607]"))
             (person (find-if (lambda (c) (types-eq (concept-type c) (get-concept-type 'person)))
                              (collect-concepts g))))
        (dolist (c (collect-concepts g)) (simplify c))
        (check "simplify still drops a true duplicate"
               (= 1 (length (arcs person)))))

      ;; Named individuals behaved correctly before and must still.
      (let* ((g (make-cgraph "[PERSON: #608]- (loc)→[CITY: Annapolis] (loc)→[CITY: Baltimore]"))
             (person (find-if (lambda (c) (types-eq (concept-type c) (get-concept-type 'person)))
                              (collect-concepts g))))
        (dolist (c (collect-concepts g)) (simplify c))
        (check "two named cities both survive" (= 2 (length (arcs person)))))
      ok)))


(defun individual-test (&optional verbose)
  (with-test-types
    (when verbose
      (format t "~%INDIVIDUAL-TEST~%"))
    (and (individual-test-1 verbose)
         (individual-test-2 verbose)
         (individual-test-3 verbose)
         (individual-identity-test verbose))))
