(in-package :conceptual-graphs)



(defmethod vartest ((graph-string string) &optional verbose)
  (reset-cgraph)
  (initialize-variables)
  (clear-id-cache)
  (setf *include-node-ref* nil)

  (let* ((graph (parse-cgraph graph-string))
         (var-specs (variables-status))
         ;; (zz (mapcar (lambda (spec)
         ;;               (format t "~&~s:  ~a" (car spec) (node-ref (car spec))))
         ;;             var-specs))
         (canonicalized-graph-string (canonicalize-graph-string graph-string))
         (formated-graph (canonicalize-graph-string (format-cgraph graph)))
         (match (graph-strings-equal graph-string formated-graph)))
    ;;(setq *gs graph-string *fg formated-graph)

    (when verbose
      (format t "~&_______")
      (format t "~&source:~&~s" (canonicalize-graph-string graph-string))
      (format t "~%formatted:~&~s~%" formated-graph)
      ;;(format t "~&match: ~s~%"  match)
      ;; (when var-specs
      ;;   (print (variables-report)))
      ;;(print var-specs
      (format t "variables: ~a" var-specs)
      (format t "~&~:[*** fail *****~;>>> pass~]~%" match))
    match))

(defmethod vartest ((test-number number) &optional verbose)
  (destructuring-bind (graph graph-string)
      (make-test-graph test-number)
    (when verbose
      (format t "~3%>>> Test ~d~&" test-number)
      (format t "~%~a~2%" graph-string))
    (vartest graph-string verbose)))


(defun variable-test (&optional verbose)
  (let ((*print-pretty* nil)
        (*concise* nil)
        (*include-node-ref* nil)
        (result t)
        (num-tests 10))

    (ensure-concept-types-exist
     '((:label entity :supertypes (⊤))
       (:label physobj :supertypes (entity))
       (:label animate :supertypes (entity))
       (:label mobile-entity :supertypes (physobj))
       (:label stationary-entity :supertypes (entity))
       (:label animal :supertypes (animate mobile-entity))
       (:label dog :supertypes (animal))
       (:label person :supertypes (animal))
       (:label event :supertypes (⊤))
       (:label act :supertypes (event))
       (:label eat :supertypes (act))
       (:label give :supertypes (act))
       (:label drive :supertypes (act))
       (:label food :supertypes (entity physobj))
       (:label cake :supertypes (food))
       (:label characteristic :supertypes (⊤))
       (:label manner :supertypes (characteristic))
       (:label fast :supertypes (manner))
       (:label hardness :supertypes (characteristic))
       (:label hard :supertypes (hardness))
       (:label age :supertypes (characteristic))
       (:label old :supertypes (age))
       (:label place :supertypes (stationary-entity))
       (:label substance :supertypes (entity))
       (:label rock :supertypes (substance))
       (:label conveyance :supertypes (mobile-entity))
       (:label automobile :supertypes (conveyance))
       (:label chevy :supertypes (automobile))
       (:label society :supertypes (⊤))
       (:label city :supertypes (place society))
       (:label attribute :supertypes (characteristic))))

    (ensure-relation-types-exist
     '((:label agnt :source-types act :dest-type animate)
       (:label attr :source-types entity :dest-type attribute)
       (:label betw :source-types (entity entity) :dest-type entity)
       (:label dest :source-types act :dest-type place)
       (:label inst :source-types act :dest-type entity)
       (:label manr :source-types act :dest-type manner)
       (:label obj  :source-types act :dest-type entity)
       (:label poss :source-types animate :dest-type entity)
       (:label rcpt :source-types act :dest-type animate)))
    (when verbose
      (format t "~%VARIABLE-TEST~%"))

    (dotimes (test-num num-tests)
      (let ((pass (vartest test-num verbose)))
        (setf result (and result pass))))

    result))
