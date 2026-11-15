(in-package :conceptual-graphs)

;;; VALIDATE-CANONICAL-GRAPH, which the type browser's create and edit saves
;;; call before they change anything. Given the type's label, it refuses a
;;; graph headed by another type, as it refuses one that doesn't parse: BABY's
;;; graph was CHILD's line, copied and not edited, and the save took it.

(defun type-save-validation-test (&optional verbose)
  (let ((ok t))
    (flet ((check (label pass)
             (setf ok (and ok (and pass t)))
             (when (or verbose (not pass))
               (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))
      (check "a graph headed by its own type is accepted"
             (null (validate-canonical-graph "[CHILD]→(life-stage)→[CHILDHOOD]" "child")))
      (check "a graph headed by another type is refused, and says why"
             (let ((message (validate-canonical-graph "[CHILD]→(life-stage)→[CHILDHOOD]"
                                                      "boy")))
               (and message (search "BOY is headed by [CHILD]" message))))
      (check "without a label only the parse is checked, as before"
             (null (validate-canonical-graph "[CHILD]→(life-stage)→[CHILDHOOD]")))
      (check "a graph that doesn't parse is still refused for that"
             (let ((message (validate-canonical-graph "[CHILD]→[CHILDHOOD]" "boy")))
               (and message (search "arrow joins two concepts" message)))))
    (when verbose
      (format t "~&type-save-validation-test: ~:[FAILED <<<~;passed~]~%" ok))
    ok))
