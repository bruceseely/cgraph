;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

(defmethod nodes-equal ((con concept) (anything t)) nil)

(defmethod nodes-equal ((anything t) (con concept)) nil)

;; (defmethod nodes-equal ((con1 concept) (con2 concept))
;;   (or (nodes-eq con1 con2)
;;       (and
;;        (nodes-eq (concept-type con1) (concept-type con2))
;;        (equalp (properties (individual (referent con1)))
;;                (properties (individual (referent con2)))))))

(defmethod nodes-equal ((con1 concept) (con2 concept))
  (concepts-equal con1 con2))



(defmethod nodes-equal ((rel relation) (anything t)) nil)

(defmethod nodes-equal ((anything t) (rel relation)) nil)

(defmethod nodes-equal ((rel1 relation) (rel2 relation))
  (or (nodes-eq rel1 rel2)
      (and
       (equal (relation-type rel1) (relation-type rel2))
       (equal (num-arcs rel1) (num-arcs rel1))
       (every #'identity
              (mapcar #'(lambda (con1 con2)
                          (equal (concept-type con1) (concept-type con2)))
                      (arcs rel1)
                      (arcs rel2))))))


;; (defmethod other-relation-concepts ((rel relation) (con concept))
;;   (remove con (arcs rel)))

(defmethod other-concepts ((relation relation) (this-concept concept))
  ;;(assert (every (lambda (node) (typep node 'concept)) this-concept))
  (remove this-concept (arcs relation) :test #'nodes-eq))


(defmethod remove-arc ((arc relation) (con concept))
  (let ((pos (position con (arcs arc) :test #'nodes-eq :key #'identity)))
    (when pos
      (setf (arcs con) (remove arc (arcs con) :test #'nodes-eq))
      (setf (arcs arc) (remove con (arcs arc) :test #'nodes-eq))
      pos)))

(defmethod remove-arc ((arc concept) (rel relation))
  (let ((pos (position arc (arcs rel) :test #'nodes-eq :key #'identity)))
    (when pos
      (setf (arcs rel) (remove arc (arcs rel) :test #'nodes-eq))
      (setf (arcs arc) (remove rel (arcs arc) :test #'nodes-eq))
      pos)))


(defmethod remove-arc ((index integer) (con concept))
  (let ((arc (nth index (arcs con))))
    (remove-arc arc con)))

(defmethod remove-arc ((index integer) (rel relation))
  (let ((arc (nth index (arcs rel))))
    (remove-arc arc rel)))


;;; adding arcs  ;;;;;;;;;;;;;;;;;;;;

;;; return the concept that that is related to the supplied concept by the passed relation
(defmethod link-value ((concept concept) (relation symbol))
  (let* ((links (links concept))
         (link (find relation links
                     :key (lambda (l)
                            (label (relation-type (rel l)))))))
    (when link
      (con link))))




(defmethod add-arc ((arc relation) (node concept) &key (index 0 index-supplied))
  (let ((index (cond (index)
                     ((not index-supplied) 0)
                     ((null index) (length (arcs node))))))
    (call-next-method arc node :index index)))

;;; default to adding an 'in' arc
(defmethod add-arc ((arc concept) (node relation) &key (index 1 index-supplied))
  (let ((index (cond (index)
                     ((not index-supplied) 1)
                     ((null index) (length (arcs node))))))
    (call-next-method arc node :index index)))



;;;; should use a confomity test
;;; todo check expliciitly for each arc
(defmethod add-arc-into-relation ((concept concept) (relation relation) &optional index)
  (assert (or (null index) (plusp index)))
  (let* ((relation-type (relation-type relation))
         (relation-source-types (source-types relation-type))
         (concept-type (concept-type concept)))
    (cond ((or (some (lambda (type) (is-type concept type)) relation-source-types)
               (some (lambda (type) (supertype-p concept-type type))  relation-source-types)
               (some (lambda (type) (equal concept-type type)) relation-source-types))
           (add-arc concept relation :index index)
           (add-arc relation concept)
           concept)
          (t
           (let ((rtype (relation-type relation))
                 (ctype1 (concept-type concept))
                 (supertypes (supertypes  (concept-type concept))))

             (error "Concept-type ~a is not consistent with the in-arc of the '~a' relation type (~a).~%The in-arc should be one of ~a"
                    ctype1 rtype relation-source-types supertypes))))))

(defmethod add-arc-into-relation ((relation relation) (concept concept) &optional index)
  (add-arc-into-relation concept relation index))


(defmethod set-arc-from-relation ((relation relation) (concept concept))
  (let* ((relation-type (relation-type relation))
         (relation-dest-type (dest-type relation-type))
         (concept-type (concept-type concept)))
    ;; (format t "~&relation-dest-type: ~s~%"  relation-dest-type)
    ;; (format t "~&concept-type: ~s~%"  concept-type)

    ;; (format t "~&(set-arc-from-relation ~s ~s) ~&~s~%~s~%~s~%~s~3%" relation concept
    ;;         (typep (concept-type concept) 'string)
    ;;         (supertype-p concept-type relation-dest-type)
    ;;         (subtype-p concept-type relation-dest-type)
    ;;         (equal concept-type relation-dest-type)
    ;;         (or (typep (concept-type concept) 'string) ; for WORD concept
    ;;            (supertype-p concept-type relation-dest-type)
    ;;            (equal concept-type relation-dest-type)))

    (cond ((or (typep (concept-type concept) 'string) ; for WORD concept
               (supertype-p concept-type relation-dest-type)
               (equal concept-type (label relation-dest-type)))
           (add-arc concept relation :index 0)
           (add-arc relation concept)
           concept)
          (t
           (let ((supertypes (supertypes (get-concept-type relation-dest-type))))
             (error "The concept type, ~a, is not consistent with the ~a relation out-arc type, ~a.~%The out-arc should be one of ~a~%"
                    (princ-to-string concept-type) relation (princ-to-string relation-dest-type) supertypes))))))

(defmethod set-arc-from-relation ((concept concept) (relation relation))
  (set-arc-from-relation relation concept))



;;; (link-concept->relation
(defmethod connect ((con concept) direction (rel relation))
  (case direction
    (:right (add-arc-into-relation con rel))
    (:left (set-arc-from-relation con rel)))
  ;; (format t "~&(arcs rel): ~s~%" (arcs rel))
  ;; (format t "~&(arcs con): ~s~%" (arcs con))
  (values con rel))

(defmethod connect ((rel relation) direction (con concept))
  (case direction
    (:left (add-arc-into-relation con rel))
    (:right (set-arc-from-relation con rel)))
  ;; (format t "~&(arcs rel): ~s~%" (arcs rel))
  ;; (format t "~&(arcs con): ~s~%" (arcs con))
  (values rel con))


;;; using arcs
(defmethod connect ((rel relation) (arc arc) (con concept))
  (connect rel (direction arc) con))

(defmethod connect ((con concept) (arc arc) (rel relation))
  (connect con (direction arc) rel))

;;; using arrow strings
(defmethod connect ((rel relation) (arc string) (con concept))
  (let ((direction (cond ((equal arc left-arrow-string) :left)
                         ((equal arc right-arrow-string) :right))))
    (connect rel direction con)))

(defmethod connect ((con concept) (arc string) (rel relation))
  (let ((direction (cond ((equal arc left-arrow-string) :left)
                         ((equal arc right-arrow-string) :right))))
    (connect con direction rel)))


;;; using arrow characters
(defmethod connect ((rel relation) (arc character) (con concept))
  (let ((direction (cond ((eql arc left-arrow) :left)
                         ((eql arc right-arrow) :right))))
    (connect rel direction con)))

(defmethod connect ((con concept) (arc character) (rel relation))
  (let ((direction (cond ((eql arc left-arrow) :left)
                         ((eql arc right-arrow) :right))))
    (connect con direction rel)))




#|
(linkup (list (pcg "[dog]") (pcg left-arrow-string) (pcg "(agnt)") (pcg left-arrow-string) (pcg "[eat]") (pcg right-arrow-string) (pcg "(obj)") (pcg right-arrow-string) (pcg "[pie]")))

(let ((la (pcg left-arrow-string))
      (ra (pcg right-arrow-string)))
    (linkup (list (pcg "[dog]") la (pcg "(agnt)") la (pcg "[eat]") ra (pcg "(obj)") ra (pcg "[pie]"))))

(let* ((l  (list "[dog]" left-arrow-string "(agnt)" left-arrow-string "[eat]" right-arrow-string "(obj)" right-arrow-string "[pie]"))
      (tokens (mapcar (lambda (x) (pcg x)) l)))
  (funcall #'linkup tokens))

|#

  ;; examples
  ;; "[dog]-
  ;;    (agnt)<-[eat]-
  ;;              (obj)->[food]
  ;;              (manr)->[fast],
  ;;    (rcpt)<-[give]->(obj)->[food]."

  ;; "[PERSON]<-(betw)-
  ;;     <-1-[ROCK]
  ;;     <-2-[PLACE]->(attr)->[HARD]."

  ;; "[PERSON]<-(betw)-
  ;;     <-1-[PLACE]->(attr)->[HARD]
  ;;     <-2-[ROCK]."


;;;
(defmethod linkup ((tokens list))
  ;;(format t "~&tokens: ~s~%"  tokens)
  ;;(mapc #'unmark tokens)

  (let ((multi-arcs nil)
        (failed-inputs (list))
        (length (length tokens))
        (sublist tokens)
        (remaining (list))
        (debug (eval  (= 5 6))))        ; this avoids a stupid warning

    (block nil
      (loop
        (when (< (length sublist) 2) (return))
        ;; clauses that match on m-arc must preceed clauses that match on arc

        (flet ((match (types)
                 ;;(format t "~&? (match ~s)" types)
                 (let* ((match-list (mapcar (lambda (type-term token)
                                              (typep token type-term))
                                            types sublist))
                        (match (every #'identity match-list)))

                   (setf length (when match (length match-list)))
                   #+nil(when match
                     (format t "~&match-list: ~s~%"  match-list)
                     (format t "~&>> ~a matched ~a~%"  (subseq sublist 0 length) types))
                   match)))


          ;;(format t "~2&----sublist: ~s~%"  sublist)

          (cond
            ((match '(concept arc relation m-arc arc number))
             ;; (format t "~& multi-input relation~%")
             ;; (format t "~& input tokens: ~s~%"  tokens)
             (destructuring-bind (concept arc relation &rest ignore) sublist
               (connect concept arc relation)))

            ;; transition INTO concept mult-arcs
            ((match '(concept m-arc relation arc))
             (when debug (format t  "~&-01 (concept m-arc relation arc) :~37t~s~%" (subseq sublist 0 3)))
             (destructuring-bind (concept m-arc relation arc &rest ignore) sublist
               (push concept multi-arcs)
               (connect concept arc relation)))

            ;; transition INTO relation multiple-source arcs
            ((match '(relation m-arc arc integer m-arc))
             (when debug (format t  "~&-02 (relation m-arc arc integer) :~37t~s~%" (subseq sublist 0 3)))
             (destructuring-bind (relation m-arc arc arcnum &rest ignore) sublist
               (push relation multi-arcs)))

            ;; parsing a multiple relation source arcs
            ((match '(arc integer m-arc concept))
             (when debug (format t  "~&-04 (arc integer m-arc concept) :~37t~s~%" (subseq sublist 0 3)))
             (destructuring-bind (arc arcnum dash concept &rest ignore) sublist
               (connect (car multi-arcs) arc concept)
               (pop sublist)))

            ;; basic link
            ;; transition FROM relation multiple-source arcs
            ((match '(concept arc relation))
             (when debug (format t  "~&-05 (concept arc relation) :~37t~s~%" (subseq sublist 0 3)))
             (destructuring-bind (concept arc relation &rest ignore) sublist
               (connect concept arc relation)))

            ;; basic link
            ((match '(relation arc concept))
             (when debug (format t  "~&-07 (relation arc concept) :~37t~s~%" (subseq sublist 0 3)))
             (destructuring-bind (relation arc concept &rest ignore) sublist
               (connect relation arc concept)))

            ;; NEXT relation multiple-source arc
            ((match '(concept arc integer))
             (when debug (format t  "~&-08 (concept arc integer) :~37t~s~%" (subseq sublist 0 3)))
             ;;(destructuring-bind (concept arc arcnum dash concept2 &rest ignore) sublist
             (push nil sublist))

            ;; NEXT concept multi-arcs
            ((match '(concept relation arc concept))
             (when debug (format t  "~&-09 (concept relation arc concept) :~37t~s~%" (subseq sublist 0 3)))
             (destructuring-bind (concept relation arc &rest ignore) sublist
               ;; ignore concept
               (connect (car multi-arcs) arc relation)
               (push nil sublist)))

            ;; transition FROM concept multi-arcs
            ((and (match '(concept standard-char)) (char-equal (second sublist) #\,))
             (when debug (format t  "~&-10 (and (match '(concept character)) (char-equal (second sublist) #\,)) :~37t~s" (subseq sublist 0 3)))
             (destructuring-bind (first second third fourth &rest ignore) sublist
               (pop multi-arcs)
               (connect (car multi-arcs) fourth third)
               ))


            (t (format t "~2% ---- unhandled by linkup ------~%")
               ;;(format t "~& ---- types ~s~%" types)
               (format t "~& ---- sampling ~s~%" sublist)
               (format t "~& ---- input tokens: ~s~%"  tokens)
               (push tokens failed-inputs)))

          ;;(setf sublist (subseq sublist (1- length)))
          ;;(print (pcg (car tokens)))
          (setf sublist (cddr sublist))))

      (values tokens failed-inputs))))




(defmethod segment-path ((tokens list))
  ;;(mapc #'unmark tokens)
  (let ((path (linkup tokens)))
    (remove-if (lambda (x) (typep x 'arc)) path)))


(defun linkup-strings (&rest strings)
  (funcall #'linkup (mapcar #'pcg strings)))



#|
(parse-cgraph "[dog].")
(parse-cgraph "[dog]<-(agnt)<-[eat].")
(parse-cgraph "[dog]<-(agnt)<-[eat]->(obj)->[cake].")
(parse-cgraph "[dog]<-(agnt)<-[eat]- (obj)->[cake] (manr)->[fast].")
(parse-cgraph "[dog]<-(agnt)<-[eat]- (obj)->[cake]->(attr)->[color] (manr)->[fast].")
(parse-cgraph "[dog]<-(agnt)<-[eat]- (obj)->[cake]- (attr)->[color:red] (attr)->[old], (manr)->[fast].")
(parse-cgraph "[dog]-
                       (agnt)<-[eat]-
                                    (obj)->[cake]-
                                                 (attr)<-[color:white]
                                                 (attr)<-[old],
                                    (manr)->[fast],
                       (attr)<-[old].")

(read-cgraph-tokens "[dog]<-(agnt)<-[eat]->(obj)->[cake].")
(read-cgraph-tokens "[dog]<-(agnt)<-[eat]- (obj)->[cake] (manr)->[fast].")
(read-cgraph-tokens "[dog]<-(agnt)<-[eat]- (obj)->[cake]->(attr)->[color], (manr)->[fast].")
(read-cgraph-tokens "[dog]<-(agnt)<-[eat]- (obj)->[cake]- (attr)->[color:red] (attr)->[old], (manr)->[fast].")
(read-cgraph-tokens "[dog]- (agnt)<-[eat]- (obj)->[cake]- (attr)<-[color:white] (attr)<-[old],(manr)->[fast],(attr)<-[old].")
|#





(defmethod first-unmarked-arc ((rel relation))
  (let ((unmarked-inarc (find-if #'marked (arcs rel))))
    (or unmarked-inarc
        (unless (marked (outarc rel))
          (outarc rel)))))

(defmethod marked-arcs ((con concept))
  (remove-if-not #'marked (arcs con)))

(defmethod unmarked-arcs ((con concept))
  (remove-if #'marked (arcs con)))

(defmethod unmarked-arcs ((rel relation))
  (remove-duplicates
   (append
    (remove-if #'marked (arcs rel))
    (unless (marked (outarc rel))
      (list (outarc rel))))))




;; direction is with respect to the relation
(defmethod dir ((rel relation) (con concept))
  (if (nodes-equal con (outarc rel))
      :out
      :in))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun pnode (node &optional stream)
  (princ node stream)
  (length (princ-to-string node)))




;; (defmethod print-cgraph ((con concept) &key from-rel (indent 0) (stream *standard-output*))
;;   (flet ((pnode (node &optional stream)
;;            (princ node stream)
;;            (incf indent (length (princ-to-string node)))))
;;     (let ((arcs (remove from-rel (arcs con))))
;;       (when from-rel
;;         (if (nodes-equal con (outarc from-rel))
;;             (pnode "->" stream)
;;             (pnode "<-" stream)))
;;       (pnode con stream)
;;       (case (length arcs)
;;         (0 )
;;         (1 (print-cgraph (car arcs) :from-con con :indent indent :stream stream))
;;         (t (princ "-" stream)
;;          (dolist (next-relation arcs)
;;            (format stream "~&~a" (make-string indent :initial-element #\space))
;;            (print-cgraph next-relation :from-con con :indent indent :stream stream)))))))

;; (defmethod print-cgraph ((rel relation) &key from-con (indent 0) (stream *standard-output*))
;;   (flet ((pnode(node &optional stream)
;;            (princ node stream)
;;            (incf indent (length (princ-to-string node)))))
;;     (let ((arcs (remove from-con (arcs rel))))
;;       (when from-con
;;         (cond ((> (length arcs) 1))
;;               ((nodes-equal from-con (outarc rel))
;;                (pnode "<-" stream))
;;               (t (pnode "->" stream))))
;;       (pnode rel stream)
;;       (case (length arcs)
;;         (0 )
;;         (1 (print-cgraph (car arcs) :from-rel rel :indent indent :stream stream))
;;         (t (princ "-" stream)
;;          (dolist (next-relation arcs)
;;            (format stream "~&~a" (make-string indent :initial-element #\space))
;;            (print-cgraph next-relation :from-rel rel :indent indent :stream stream)))))))



(defmethod nodes-equal ((arc arc) (something t)) nil)
(defmethod nodes-equal ((something t) (arc arc)) nil)

(defmethod nodes-equal ((arc1 arc) (arc2 arc))
  (cond ((not (eq (direction arc1) (direction arc2))) nil)
        ((not (eq (arcnum arc1) (arcnum arc2))) nil)
        (t)))



(defmethod node-type ((node concept))
  (concept-type node))

(defmethod node-type ((node relation))
  (relation-type node))

(defmethod node-type ((node t))
  nil)


(defmethod node-class ((object concept))
  :concept)

(defmethod node-class ((object relation))
  :relation)


;; (setq g (parse-cgraph "[PERSON: Sue]<-(agnt)<-[GIVE]-
;;                                                     (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: *z]
;;                                                     (inst)->[FOOD]<-(obj)<-[EAT: *z]."))
;; (find-concept 'eat g)

;;; will add a method to find-concepts in a context later
;;;
;; (defmethod find-concepts (concept-type (graph concept) &key (properties (list))
;;                                                             (ignored-num-refs (list)))
;;   (let ((targets (list)))
;;     (walk-graph graph (lambda (link)
;;                         (push link *links)
;;                         (when (and
;;                                (not (find (node-ref (con link)) ignored-num-refs :test #'=))
;;                                (typep link 'link)
;;                                (types-equal (get-concept-type concept-type) (concept-type (con link)))
;;                                (or
;;                                 (null properties)
;;                                 (properties-equal properties
;;                                                   (properties (referent (con link)))
;;                                                   :ignore-id t)))
;;                           (push (con link) targets))))
;;     targets))







;; (defmethod find-concepts (concept-type (graph concept) &key (properties (list))
;;                                                             (ignored-num-refs (list)))
;;   (let ((targets (list)))
;;     (walk-graph graph (lambda (link)
;;                         (push link *links)
;;                         (when (and
;;                                (not (find (node-ref (con link)) ignored-num-refs :test #'=))
;;                                (typep link 'link)
;;                                (types-equal (get-concept-type concept-type) (concept-type (con link)))
;;                                (or
;;                                 (null properties)
;;                                 (properties-equal properties
;;                                                   (properties (referent (con link)))
;;                                                   :ignore-id t)))
;;                           (push (con link) targets))))
;;     targets))


(defmethod find-concepts (concept-type (graph concept) &key (properties (list))
                                                            (ignored-num-refs (list)))
  (remove-if (lambda (node)
               (or
                (find (node-ref node) ignored-num-refs :test #'=)
                (not (types-equal (get-concept-type concept-type) (concept-type node)))
                (and
                 properties
                 (not (properties-equal properties
                                        (properties (referent node))
                                        :ignore-id t)))))
             (collect-concepts graph)))

(defmethod find-concept (concept-type (graph concept) &key id (properties (list)) (ignore-num-refs (list)))
  (let ((collected (find-concepts concept-type graph :properties properties :ignored-num-refs ignore-num-refs)))
    (cond (id (find id collected :key #'id))
          (t (car collected)))))



;;;
(defmethod mark-graph ((node graph-node) &optional (marked-nodes (list)))
  (mark node)
  (dolist (next-node (remove node (arcs node)))
    (when next-node
      (unless (find next-node marked-nodes)
        (mark-graph next-node (cons node marked-nodes))))))

(defmethod unmark-graph ((node graph-node) &optional (unmarked-nodes (list)))
  (unmark node)
  (dolist (next-node (arcs node))
    (when next-node
      (unless (find next-node unmarked-nodes)
        (unmark-graph next-node (cons node unmarked-nodes))))))



;;; depth-first
(defmethod walk-graph ((node concept) function)
  (let* ((seen (list))
         (current-concept node)
         (agenda (list)))
    (block nil
      (loop
        (let* ((links (links current-concept))
               (available (set-difference links seen
                                          :key #'(lambda (link)
                                                   (node-ref (con link)))
                                          :test #'=)))
          (setf agenda (append agenda available))
          (when (null agenda) (return))
          ;;(format t "~&agenda: ~s~%"  agenda)


          (funcall function (car agenda))
          (push (car agenda) seen)
          (setf current-concept (con (pop agenda))))))))

(defmethod walk-graph+ ((node concept) function)
  (let* ((seen (list))
         (agenda (list node))
         current-node)
    (block nil
      (loop
        (setf current-node (pop agenda))
        (funcall function current-node)
        (push current-node seen)
        (setf agenda (append agenda
                             (set-difference (arcs current-node) seen
                                             :key #'node-ref
                                             :test #'=)))
        (when (null agenda) (return))))))





;;;; breadth-first
(defmethod crawl-graph ((node graph-node) function)
  (let ((seen-list (list))
        (horizon (list node)))
    (block loop
      (loop
        (cond (horizon
               (let* ((node (car horizon))
                      (seen (find node seen-list :test #'nodes-eq)))
                 (setf (cdr (last horizon)) (unmarked-arcs node))
                 (unless seen
                   (funcall function node)
                   (mark node)
                   (push node seen-list))
                 (pop horizon)))
              (t (return-from loop)))))))



(defmethod collect-nodes ((start-node graph-node))
  (let* ((nodes (list)))
    (walk-graph+ start-node
                 (lambda (node)
                   (push node nodes)))
    (reverse nodes)))

(defmethod collect-relations ((start-node graph-node))
  (remove-if-not (lambda (node)
                   (typep node 'relation))
                 (collect-nodes start-node)))

(defmethod collect-concepts ((start-node graph-node))
  (remove-if-not (lambda (node)
                   (typep node 'concept))
                 (collect-nodes start-node)))


;;; node with greatest number of arcs
;; (defmethod head-node ((node graph-node))
;;   (let ((head-len 0)
;;         head)
;;     (walk-graph node (lambda (link)
;;                        (let* ((x (con link))
;;                               (x-len (length (arcs x))))
;;                          (when (> x-len head-len)
;;                            (setf head x
;;                                  head-len x-len)))))
;;     head))

(defmethod head-node ((node graph-node))
  (let ((head-len 0)
        head)
    (dolist (node (collect-nodes node))
      (let ((arcs-len (length (arcs node))))
        (when (> arcs-len head-len)
          (setf head node
                head-len arcs-len))))
    head))







(defmethod same-object-p ((object1 basic-node) (object2 basic-node))
  (nodes-eq object1 object2))

(defmethod same-object-p ((object1 t) (object2 t))
  nil)


(defmethod identical-objects-p ((object1 concept) (object2 concept))
  (types-equal (concept-type object1) (concept-type object2))
  (string-equal (referent object1) (referent object2)))

(defmethod identical-objects-p ((object1 t) (object2 t))
  nil)


#|
(progn
(initialize-cgraph)
(setq s2 "[PERSON: Sue]<-(agnt)<-[GIVE]-
                           (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: #1]
                           (rcpt)->[DOG: Fido]<-(agnt)<-[EAT: #2]
                           (inst)->[FOOD: #1]<-(obj)<-[EAT: #1]
                           (inst)->[FOOD: #2]<-(obj)<-[EAT: #2].")
(setq g2 (parse-cgraph s2))

(find-concepts 'food g2)
(find-concept 'food g2 :id 1)
(find-concept 'food g2 :id 2)
(find-concepts 'food g2)
;; ([FOOD: #2] [FOOD: #1])
(find-concepts 'food g2)
;; NIL

(find-concepts 'dog g2 :properties '(:name "Spot"))
(find-concepts 'dog g2 :properties '(:name "Fido"))
(find-concepts 'dog g2)
;; ([DOG: Fido] [DOG: Spot])
(find-concepts 'dog g2)
;; NIL

(find-concepts 'eat g2)
;; ([EAT: #2] [EAT: #1])
)
|#




;; (defmethod cgraph-marked-arcs ((node graph-node))
;;   (let ((marked (list)))
;;     (walk-graph node (lambda (x)
;;                     (when (marked x)
;;                       (push x marked))))
;;     marked))

;; (defmethod cgraph-unmarked-arcs ((node graph-node))
;;   (let ((unmarked (list)))
;;     (walk-graph node (lambda (x)
;;                     (unless (marked x)
;;                       (push x unmarked))))
;;     unmarked))


(defmethod cgraph-marked-arcs ((node graph-node))
  (remove-if-not #'marked
                 (collect-nodes node)))

(defmethod cgraph-unmarked-arcs ((node graph-node))
  (remove-if #'marked
             (collect-nodes node)))

(defmethod duplicate-p ((node-1 concept) (node-2 concept))
  (let ((node-1-arc-types (mapcar #'node-type (arcs node-1)))
        (node-2-arc-types (mapcar #'node-type (arcs node-2))))
    (and (types-eq node-1 node-2)
         (equalp node-1-arc-types node-2-arc-types)
         ;; (null (append (set-difference node-1-arc-types node-2-arc-types :test #'nodes-equal)
         ;;               (set-difference node-2-arc-types node-1-arc-types :test #'nodes-equal)))
         )))

(defmethod duplicate-p ((node-1 relation) (node-2 relation))
  (let ((node-1-arc-types (mapcar #'node-type (arcs node-1)))
        (node-2-arc-types (mapcar #'node-type (arcs node-2))))
    (and (types-eq node-1 node-2)
         (equalp node-1-arc-types node-2-arc-types)
         ;; (types-eq (car node-1-arc-types) (car node-2-arc-types))
         ;; (null (set-difference (cdr node-1-arc-types) (cdr node-2-arc-types) :test #'nodes-equal))
         ;; (null (set-difference (cdr node-2-arc-types) (cdr node-1-arc-types) :test #'nodes-equal))
         )))

(defmethod duplicate-p ((thing-1 t) (thing-2 t))
  (eq thing-1 thing-2))



;; (defun graphs-eq (graph1 graph2)
;;   (let* ((concepts1 (collect-concepts graph1))
;;          (concepts2 (collect-concepts graph2))
;;          (nodes-eq (mapcar (lambda (c1 c2)
;;                              (nodes-eq c1 c2))
;;                            concepts1 concepts2)))
;;     (cond ((every #'identity nodes-eq) :eq)
;;           ((some #'identity nodes-eq) :some)
;;           (t nil))))



(defun graphs-eq (graph1 graph2)
  (let* ((concepts1 (collect-concepts graph1))
         (concepts2 (collect-concepts graph2))
         (nodes-eq (mapcar (lambda (c1 c2)
                             (nodes-eq c1 c2))
                           concepts1 concepts2)))
    (cond ((every #'identity nodes-eq) t)
          ;;((some #'identity nodes-eq) :some)
          (t nil))))



(defmethod graphs-equal ((g1 list) (g2 list) &optional debug)
  (let* ((concepts1 (remove-if-not #'concept-p g1))
         (concepts2 (remove-if-not #'concept-p g2))
         (concepts-equalp (null (set-exclusive-or concepts1 concepts2 :test #'nodes-equal)))
         (pass concepts-equalp))
    pass))

(defmethod graphs-equal ((g1 graph-node) (g2 graph-node) &optional debug)
  (graphs-equal (collect-nodes g1) (collect-nodes g2) debug))

;; (defmethod graphs-equal ((g1 graph-node) (g2 graph-node) &optional debug)
;;   ;; (f "~&(pcg g1): ~s~%" (pcg g1))
;;   ;; (format t "~&(pcg g2): ~s~%" (pcg g2))
;;   (let* ((*include-node-ref* nil)
;;          (graph1-string (string-upcase (compress-whitespace (remove #\space (format-cgraph g1)))))
;;          (graph2-string (string-upcase (compress-whitespace (remove #\space (format-cgraph g2)))))
;;          (concepts1 (collect-concepts g1))
;;          ;;(zz (format t "~&concepts1: ~s~%"  concepts1))
;;          (concepts2 (collect-concepts g2))
;;          ;;(zz (format t "~&concepts2: ~s~%"  concepts2))
;;          (string-equalp (string-equal graph1-string graph2-string))
;;          (concepts-equalp (null (set-exclusive-or concepts1 concepts2 :test #'concepts-equal)))
;;          (pass (or string-equalp concepts-equalp)))
;;     ;; (when (and debug (not pass))
;;     ;;   (format t "~&pass: ~s~%"  pass)
;;     ;;   (format t "~&graph1-string: ~s~%"  graph1-string)
;;     ;;   (format t "~&graph2-string: ~s~%"  graph2-string)
;;     ;;   (format t "~&concepts1: ~s~%"  concepts1)
;;     ;;   (format t "~&concepts2: ~s~%"  concepts2)
;;     ;;   (format t "~&concepts-equalp: ~s~%"  concepts-equalp))
;;     pass))


(defmethod graphs-equal ((g1 string) (g2 string) &optional debug)
  (graphs-equal (pcg g1) (pcg g2) debug))



(defun fix-concept-strings (text)
  (let* ((contype-strings (list))
         (times (count #\[ text))
         (open-marker -1)
         (close-marker -1)
         (result ""))
    (dotimes (i times)
      (setf open-marker (1+ (position #\[ text :start (1+ open-marker))))
      (setf close-marker (when open-marker
                           (let* ((concept-end (position #\] text :start open-marker))
                                  (colon-pos (position #\: text :start open-marker)))
                             ;; it might pickup the rong colon
                             (if colon-pos (min colon-pos concept-end) concept-end))))
      (when open-marker
        (push (list open-marker close-marker) contype-strings)))

   ;;(format t "~&contype-strings: ~s~%"  contype-strings)

    (let ((start 0)
          (contype-strings (reverse contype-strings)))
      ;; (format t "~&contype-strings: ~s~%"  contype-strings)
      (dolist (rec contype-strings)
        (destructuring-bind (contype-start contype-end) rec
          ;; (format t "~&contype-start: ~s~%"  contype-start)
          ;; (format t "~&contype-end: ~s~%"  contype-end)
          (let* ((end (or (position #\] text :start contype-end)
                          (length text)))
                 (concept-end (when end (1+ end)))
                 (concept-token (format nil "~a~:@(~a~)~a"
                                (subseq text start contype-start)
                                (subseq text contype-start contype-end)
                                (subseq text contype-end concept-end))))

            ;; (format t "~&(subseq text start contype-start): ~s~%"  (subseq text start contype-start))
            ;; (format t "~&(subseq text contype-start contype-end): ~s~%"  (subseq text contype-start contype-end))
            ;; (format t "~&(subseq text contype-end end): ~s~%"  (subseq text contype-end end))

            ;; (format t "~&end: ~s~%"  end)
            ;; (format t "~&concept-end: ~s~%"  concept-end)
            ;; (format t "~&concept-token: ~s~%"  concept-token)


            (setf result (strcat result concept-token))
            (setq start concept-end)))))
    result))


(defun fix-relation-strings (text)
  (let* ((rel-strings (list))
         (times (count #\( text))
         (open-paren -1)
         (close-paren -1)
         (result ""))
    (dotimes (i times)
      (setf open-paren (position #\( text :start (1+ open-paren)))
      (setf close-paren (when open-paren (position #\) text :start open-paren)))
      (when open-paren
        (push (list (1+ open-paren) close-paren) rel-strings)))

    (let ((start 0)
          (rel-strings (reverse rel-strings)))
      (dolist (rec rel-strings)
        (destructuring-bind (rel-start rel-end) rec
          (let* ((end (or (position #\( text :start rel-end)
                          (length text)))
                 (token (format nil "~a~(~a~)~a"
                                (subseq text start rel-start)
                                (subseq text rel-start rel-end)
                                (subseq text rel-end end))))
            (setf result (strcat result token))
            (setq start end)))))
    result))

(defun canonicalize-graph-string (string)
  (fix-relation-strings
   (fix-concept-strings
    (compress-whitespace
     (encode-arrows string)))))


(defmethod graph-strings-equal ((g1 string) (g2 string))
  (let ((graph1-string (canonicalize-graph-string g1))
        (graph2-string (canonicalize-graph-string g2)))
    (string-equal graph1-string graph2-string)))


;;; <:EQ T> - all nodes are eq, started from same node
;;; <:EQ NIL>  - all nodes are eq, not started from same node
;;; <:SOME T> - some nodes are eq, started from same node
;;; <:SOME NIL>  - some nodes are eq, not started from same node
;;; <:EQUAL T>  - all nodes are equal, not eq, started from same node
;;; <:EQUAL NIL>  - all nodes are equal, not eq, not started from same node
;;; NIL
(defmethod compare-graphs ((g1 graph-node) (g2 graph-node))
  (let ((result (cond ((graphs-eq (head-node g1) (head-node g2)))
                      ((graphs-equal (head-node g1) (head-node g2)) :equal))))
    (values result (nodes-equal g1 g2))))



;;; concept instances of the supplied type
(defmethod denotation ((ctype concept-type))
  (let ((concepts (list)))
    (maphash (lambda (key node)
               (declare (ignore key))
               (when (and (eq (type-of node) 'concept) (eq (concept-type node) ctype))
                 (push node concepts)))
             *node-cache*)
    (values concepts (length concepts))))

(defmethod denotation ((ctype symbol))
  (let ((concept-type (get-concept-type ctype)))
    (when concept-type
      (denotation concept-type))))


(defmethod delete-concept ((concept concept))
  (remove-node concept)
  (decache-concept concept)
  )
