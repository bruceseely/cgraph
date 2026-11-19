;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)

;;; Concept type aliases: (:label automobile :supertypes (vehicle) :aliases
;;; (car auto)) in test/test-types/concept-types.lisp. CAR and AUTO are other
;;; names for AUTOMOBILE -- one node in the lattice, three names that look it
;;; up. A concept keeps the name it was written with.

(defun alias-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label)))
             (english (string)
               (ignore-errors (graph-to-text (parse-cgraph string))))
             (formatted (string)
               (ignore-errors (format-cgraph (parse-cgraph string)))))

        ;; --- one type, several names --------------------------------------
        (let ((automobile (get-concept-type 'automobile)))
          (check "an alias looks up the same type object"
                 (and (eq automobile (get-concept-type 'car))
                      (eq automobile (get-concept-type "auto"))))
          (check "and exists"
                 (concept-type-exists 'car))
          (check "the type lists its aliases"
                 (equal '(auto car) (concept-type-aliases automobile)))
          (check "an alias is not a catalog entry (the lattice has one node)"
                 (not (nth-value 1 (gethash 'car *concept-type-catalog*))))
          (check "subtypes asked by alias are the type's"
                 (equal (sort (mapcar #'label (proper-subtypes (get-concept-type 'car)))
                              #'string< :key #'symbol-name)
                        (sort (mapcar #'label (proper-subtypes automobile))
                              #'string< :key #'symbol-name)))
          (check "FORD-VEHICLE is a subtype of CAR"
                 (subtype-p 'ford-vehicle 'car))
          (check "CAR is a subtype of VEHICLE"
                 (subtype-p 'car 'vehicle)))

        ;; --- spelling -------------------------------------------------------
        (check "[CAR] formats as CAR"
               (search "[CAR]" (formatted "[PERSON: Bob]→(poss)→[CAR]")))
        (check "[AUTOMOBILE] still formats as AUTOMOBILE"
               (search "[AUTOMOBILE]" (formatted "[PERSON: Bob]→(poss)→[AUTOMOBILE]")))
        (check "a referent survives the alias"
               (search "[CAR:Herbie]" (formatted "[PERSON: Bob]→(poss)→[CAR: Herbie]")))
        (check "[CAR] says \"car\""
               (equal "Bob has a car." (english "[PERSON: Bob]→(poss)→[CAR]")))
        (check "[AUTO] says \"auto\", with its own article"
               (equal "Bob has an auto." (english "[PERSON: Bob]→(poss)→[AUTO]")))
        (check "a name still beats the alias"
               (equal "Bob has Herbie." (english "[PERSON: Bob]→(poss)→[CAR: Herbie]")))
        (let* ((concept (make-concept 'car nil)))
          (check "make-concept by alias records the spelling"
                 (eq 'car (concept-type-name concept)))
          (check "a copy keeps it"
                 (eq 'car (concept-type-name (copy-concept concept))))
          (setf (concept-type concept) (get-concept-type 'ford-vehicle))
          (check "a spelling that no longer names the type is ignored"
                 (eq 'ford-vehicle (concept-type-name concept))))

        ;; --- interchangeable in queries ------------------------------------
        (let ((kb (make-context)))
          (make-cgraph "[PERSON: Bob]→(poss)→[AUTOMOBILE: Herbie]" kb)
          (make-cgraph "[PERSON: Sue]→(poss)→[CAR: Bumblebee]" kb)
          (flet ((owners (pattern)
                   (sort (loop for r in (query pattern kb)
                               collect (referent-name
                                        (cdr (assoc 'p (getf r :bindings)
                                                    :test #'string-equal))))
                         #'string<)))
            (check "a CAR query finds the AUTOMOBILE fact and the CAR one"
                   (equal '("Bob" "Sue") (owners "[PERSON: *p]→(poss)→[CAR]")))
            (check "an AUTOMOBILE query finds the CAR fact too"
                   (equal '("Bob" "Sue") (owners "[PERSON: *p]→(poss)→[AUTOMOBILE]")))))

        ;; --- conflicts ------------------------------------------------------
        (check "an alias cannot be defined as a type of its own"
               (typep (nth-value 1 (ignore-errors
                                    (define-concept-type :label 'car :supertypes '(vehicle))))
                      'concept-type-alias-conflict))
        (check "and the attempt leaves AUTOMOBILE alone"
               (subtype-p 'automobile 'vehicle))
        (check "a type's label cannot become an alias"
               (typep (nth-value 1 (ignore-errors (register-concept-type-alias 'vehicle 'automobile)))
                      'concept-type-alias-conflict))
        (check "one alias cannot name two types"
               (typep (nth-value 1 (ignore-errors (register-concept-type-alias 'car 'vehicle)))
                      'concept-type-alias-conflict))
        (check "an alias cannot name an alias"
               (typep (nth-value 1 (ignore-errors (register-concept-type-alias 'motorcar 'car)))
                      'concept-type-alias-conflict))
        (check "a written type file keeps the aliases"
               (search ":aliases (AUTO CAR)"
                       (format-concept-type (get-concept-type 'automobile))))

        ;; --- a type file that uses an alias before declaring it -------------
        (let* ((dir (uiop:ensure-directory-pathname
                     (merge-pathnames (format nil "cgraph-alias-test-~d/" (random 1000000))
                                      (uiop:temporary-directory))))
               (test-types (asdf:system-relative-pathname "cgraph" "test/test-types/")))
          (ensure-directories-exist dir)
          (unwind-protect
               (progn
                 ;; The test types, with a first line naming AUTO as a
                 ;; supertype -- seventeen lines before AUTOMOBILE declares it.
                 (with-open-file (out (merge-pathnames "concept-types.lisp" dir)
                                      :direction :output :if-exists :supersede)
                   (format out "(:label beetle :supertypes (auto))~%~a"
                           (uiop:read-file-string
                            (merge-pathnames "concept-types.lisp" test-types))))
                 (uiop:copy-file (merge-pathnames "relation-types.lisp" test-types)
                                 (merge-pathnames "relation-types.lisp" dir))
                 (let ((env (ignore-errors
                             (let ((*error-output* (make-broadcast-stream)))
                               (make-environment :types (namestring dir))))))
                   (check "a forward reference to an alias loads"
                          (and env
                               (with-environment (env)
                                 (and (not (nth-value 1 (gethash 'auto *concept-type-catalog*)))
                                      (subtype-p 'beetle 'automobile)))))))
            (uiop:delete-directory-tree dir :validate t :if-does-not-exist :ignore))))
      ok)))
