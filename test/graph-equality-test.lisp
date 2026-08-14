(in-package :conceptual-graphs)

;;; GRAPHS-EQUAL had no test, which is how three faults lived in it at once:
;;; it ignored relations entirely, its GRAPH method handed a node to a method
;;; expecting a list, and NODES-EQUAL on two relations called a misspelled
;;; function that named nothing.
;;;
;;; What it answers is the STRUCTURAL question -- these concepts, joined this
;;; way -- and not the CG question of whether two graphs say the same thing.
;;; That one is mutual projection, and lives in `decomposition-test'.

(defun graph-equality-test (&optional verbose)
  (let ((ok t))
    (flet ((check (name result)
             (setf ok (and ok (and result t)))
             (when (or verbose (not result))
               (format t "~&  ~:[fail~;pass~] ~a~%" result name)))
           (g (source) (collect-nodes (graph-head (pcg source)))))
      (when verbose (format t "~&GRAPH-EQUALITY-TEST~%"))

      (check "a graph equals itself, parsed twice"
             (graphs-equal (g "[EAT]→(agnt)→[DOG].") (g "[EAT]→(agnt)→[DOG].")))

      ;; The correction. These share both concepts and were equal.
      (check "the same concepts joined by a different relation are not equal"
             (not (graphs-equal (g "[EAT]→(agnt)→[DOG].") (g "[EAT]→(obj)→[DOG]."))))

      (check "the same concepts joined by nothing are not equal"
             (not (graphs-equal (g "[EAT]→(agnt)→[DOG].")
                                (list (first (g "[EAT].")) (first (g "[DOG]."))))))

      (check "an extra concept is a different graph"
             (not (graphs-equal (g "[EAT]→(agnt)→[DOG].")
                                (g "[EAT]-(agnt)→[DOG](obj)→[CAKE]."))))

      (check "two graph NODES compare"
             (graphs-equal (graph-head (pcg "[EAT]→(agnt)→[DOG]."))
                           (graph-head (pcg "[EAT]→(agnt)→[DOG]."))))

      ;; This one used to hand (HEAD G) -- a node -- to the list method.
      (check "two GRAPH objects compare"
             (graphs-equal (pcg "[EAT]→(agnt)→[DOG].")
                           (pcg "[EAT]→(agnt)→[DOG].")))

      ;; A linked list of concepts is a whole graph: the relations hang off the
      ;; arcs rather than appearing in the list, and must still be compared.
      (let* ((full (g "[EAT]→(agnt)→[DOG]."))
             (concepts-only (remove-if-not #'concept-p full)))
        (check "a concept-only list still carries its relations"
               (graphs-equal concepts-only (g "[EAT]→(agnt)→[DOG]."))))

      ;; NODES-EQUAL on two relations reached a function that did not exist.
      (let ((r1 (first (remove-if-not #'relation-p (g "[EAT]→(agnt)→[DOG]."))))
            (r2 (first (remove-if-not #'relation-p (g "[EAT]→(agnt)→[DOG]."))))
            (r3 (first (remove-if-not #'relation-p (g "[EAT]→(obj)→[DOG].")))))
        (check "two relations can be compared at all"
               (nodes-equal r1 r2))
        (check "and told apart"
               (not (nodes-equal r1 r3))))

      (when verbose
        (format t "~&GRAPH-EQUALITY-TEST ~:[failed~;passed~]~%" ok))
      ok)))
