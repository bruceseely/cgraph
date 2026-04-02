;;; -*- Mode; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  paths  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun arc-string (first second)
  ;;(format t "~&(arcs ~a): ~s~%"  first (arcs first))

  (typecase first
    (concept
     ;;(format t "~&(outarc ~a): ~s~%" second  (outarc second))
     (cond ((nodes-equal first (outarc second))
            left-arrow-string)
	   ((find first (inarcs second) :test #'nodes-equal)
            right-arrow-string)))
    (relation
     ;;(format t "~&(outarc ~a): ~s~%" first  (outarc first))
     (cond ((nodes-equal second (outarc first))
            right-arrow-string)
	   ((find second (inarcs first) :test #'nodes-equal)
            left-arrow-string)))))


;;; a segment path may contain a multi-path-node as the first or last node
;;; multi-path-node is a concept, relation or nil}


(defun format-path-tokens (path)
  (let* ((text-list (list))
         (nodes-processed 0))  ; Track how many nodes we've processed

    ;; Special case: if path starts with an arrow string (from trim-path), handle it
    (when (and path (stringp (car path)))
      (push (car path) text-list)
      (setf path (cdr path)))

    ;; Special case: if path starts with a relation (from trimming), format it first
    (when (and path (relation-p (car path)) (cdr path))
      (push (format-node (car path)) text-list)
      (let ((arc (arc-string (car path) (cadr path))))
        (when arc (push (princ-to-string arc) text-list)))
      (setf nodes-processed 1))  ; Mark that we've processed the first node


    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (do ((node-list (nthcdr nodes-processed path) (cdr node-list)))
        ((null node-list))

      (let ((first-node (car node-list)))

        (let* ((first (car node-list))
	       (second (cadr node-list))
	       (arc (when second (arc-string first second))))
          ;; (format t "~2&__ loop ____ ~a~%text-list: ~s~%" first text-list)
          ;; (format t "~&node-list = ~s~%" node-list)
          ;; (format t "~&arc: ~s~%"  arc)

          ;; Handle single remaining node case
          (when (and (null second) (= 1 (length node-list)))
            (push (format-node first) text-list)
            (return)) ; Exit the loop after handling the single node

          ;;(format t "~& ---> ~s,  ~s,  ~a~%" first-node (arcs first-node) (length (arcs first-node)))

          (cond ((= 1 (length (arcs first-node)))
                 (push (format-node first) text-list)
                 (when arc
	           (push (princ-to-string arc) text-list)))

                ((> (length (arcs first-node)) 2)
                 (typecase first-node
                   (concept
                    (push (format-node first) text-list)  ; Include the first node!
                    (when arc
                      (push (princ-to-string arc) text-list))
                    ;; DON'T add the second node - let the next iteration handle it!
                    )
                   (relation
                    (let* ((relation first)
                           (concept second)
                           (place (position concept (arcs relation)))
                           (arrow (if (eql place 0) right-arrow-string left-arrow-string)))
                      (when place
                        (push "-" text-list)
                        (push (princ-to-string place) text-list)
                        (push arrow text-list))))))

                ((= 2 (length (arcs first-node)))
                 (push (format-node first) text-list)
                 (when arc
	           (push (princ-to-string arc) text-list)))
                (t
                 (error "Unhandled case for first-node ~s with ~s arcs" first-node (length (arcs first-node)))))
                )
          ) ;; Close the let block

        ;;(format t "~&(reverse text-list): ~s~%"  (reverse text-list))
        )
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    (reverse text-list)))


(defmethod format-segment ((segment graph-segment) &key trim-path)
  (let* ((original-path (path segment))
         (path (if trim-path
                   (cdr original-path)
                   original-path))
         (text-list (format-path-tokens path))
         (text (apply #'strcat text-list)))
    text))


(defmethod next-arrow ((current-node concept) (next-node relation))
  (let ((pos (position current-node (arcs next-node) :test #'nodes-eq)))
    (case pos
      (0 "<-")
      (t "->"))))

(defmethod next-arrow ((current-node relation) (next-node concept))
  (let ((pos (position next-node (arcs current-node) :test #'nodes-eq)))
    (case pos
      (0 "->")
      (t "<-"))))

(defmethod next-arrow ((current-node graph-node) (next-node graph-node))
  "!!!!")


(defvar *text-result* "")

(defvar *segment-pool* (list))
(defun setit (pool)
  (setf *segment-pool* pool))
(defun addit (seg)
  (setf *segment-pool* (cons seg *segment-pool*)))
(defun remit (seg)
  (setf *segment-pool* (sort (copy-list (remove seg *segment-pool* :test #'nodes-eq))
                                 #'segment-lessp))
  )

;;; The 'branched' argument says that this segment is one of multiple segments starting
;;; from the same segment
(defmethod format-segments ((current-segment graph-segment)
                            (indent integer)
                            (indent-delta integer)
			    &key (branched 0) initial)

  ;; (format t "~3&*text-result*:~&~a~2%"  *text-result*)
  ;; (format t "~&________________________________~%")
  ;; (format t "~&initial: ~s~%"  initial)
  ;; (format t "~&branched: ~s~%"  branched)

  (let ((text-line ""))

    (flet ((add-text (text)
             (setf text-line (strcat text-line text))))


      (remit current-segment)
      ;; (setf *segment-pool* (sort (copy-list (remove current-segment *segment-pool* :test #'nodes-eq))
      ;;                            #'segment-lessp))




      (multiple-value-bind (connected-segments pool)
          (next-segments current-segment *segment-pool*)
        (setit pool)

        ;; figure out variables
        (if (> (length (arcs (segment-last-node current-segment)))
               ;;; account for current-segment
               (1+ (length connected-segments)))
          (set-variable (segment-last-node current-segment))
          (when (node-variable (segment-last-node current-segment))
            (unset-variable (segment-last-node current-segment))))

        (let* ((branching-factor (- (length (arcs (segment-last-node current-segment)))
                                    (cond ((= (path-length current-segment) 1) 0)
                                          (t 1)))))

          ;; format current node
          (let* ((original-path (path current-segment))
                 (first (car original-path))
                 (second (cadr original-path))
                 ;; (newline-before-p (or (not (and (node-variable first)
                 ;;                                 (> branched (length connected-segments))))
                 ;;                       ;;(> (length connected-segments) 2)
                 ;;                       (and (not (node-variable first))
                 ;;                            (> branched 2))))
                 (newline-before-p (cond ((node-variable first)
                                         (not (> branched (length connected-segments)))
                                         )
                                         ((> branched 1))

                                         (t
                                          (> branched 2)
                                         )))

                 (indent-string (make-string (cond ((zerop indent) 0)
                                                   ((plusp branched)
                                                    (max  0 (- indent indent-delta 2)))
                                                   (t (+ indent indent-delta)))
                                             :initial-element #\space))
                 (prefix (cond (initial "")
                               ((null second) "")
                               ((typep first 'relation)
                                (format nil "~%~a~a~a-"
                                        indent-string
                                        (arc-string first second)
                                        (princ-to-string (position second (arcs first)))))
                               ((typep first 'concept)
                                (cond (newline-before-p
                                       (format nil "~%~a" indent-string))
                                      (t (arc-string first second))))
                               (t "")))
                 (suffix (cond ((null connected-segments) "")
                               ((> (length connected-segments) 1)
                                "-")
                               (t "")))

                 ;;(trim-path (> branched 1))
                 (trim-path (not initial))

                 (segment-text (format-segment current-segment :trim-path trim-path))

                 (text (strcat prefix segment-text suffix))
                 )


            ;; (format t "~&current-segment: ~s~%"  current-segment)
            ;; (format t "~&connected-segments:   ~:a~%"  connected-segments)
            ;; (format t "~&*segment-pool*: ~%")
            ;; (list-segments *segment-pool* )
            ;; (format t "~&(segment-last-node current-segment): ~s~%"  (segment-last-node current-segment))
            ;; (format t "~&(arcs ~a): ~a~%"  (segment-last-node current-segment) (arcs (segment-last-node current-segment)))
            ;; (format t "~&branching-factor: ~s~%"  branching-factor)
            ;; (format t "~&branched: ~s~%"  branched)
            ;; (format t "~&trim-path: ~s~%"  trim-path)
            ;; (format t "~&segment-text: ~s~%"  segment-text)
            ;; (format t "~&connected-segments: ~s~%"  connected-segments)
            ;; (format t "~&(node-variable first): ~s~%"  (node-variable first))
            ;; (format t "~&(not (and (node-variable first) (> branched (length connected-segments)))): ~s~%"  (not (and (node-variable first) (> branched (length connected-segments)))))
            ;; (format t "~&(and (node-variable first) (not (> branched (length connected-segments)))): ~s~%"  (and (node-variable first) (not (> branched (length connected-segments)))))
            ;; (format t "~&(and (not (node-variable first)) (> branched 2)): ~s~%"  (and (not (node-variable first)) (> branched 2)))
            ;; (format t "~&newline-before-p: ~s~%"  newline-before-p)
            ;; (format t "~&prefix: ~s~%"  prefix)
            ;; (format t "~&suffix: ~s~%"  suffix)
            ;; (format t "~&text: ~s~4%"  text)



            (add-text text)
            (setf *text-result* (strcat *text-result* text-line))



            (when connected-segments
                (let ((base-indent (length text-line)))
                  (dolist (next-segment connected-segments)

                    (format-segments next-segment base-indent indent-delta :branched branching-factor)
                       ))))


          (when (and (plusp branching-factor) (> (length connected-segments) 1))
            (setf *text-result* (strcat *text-result* ",")))


          *text-result*)))))


(defmethod format-segments-from-node ((node graph-node) (segments list) &optional (initial-indent 0) (indent-delta 3))
  (let* ((first-segment (segment-starting-with node segments))
         (segments (cons first-segment (remove first-segment segments :test #'nodes-eq)))
         ;;(*text-result* "")
         (*segment-pool* (copy-list segments)))
    (setf *text-result* "")
    (setf *segment-pool* (copy-list segments))
    (format-segments first-segment initial-indent indent-delta :initial t)))

(defmethod cgraph-text ((node graph-node) &key (initial-indent 0) (indent-delta 3))
  (let* ((segments (make-graph-segments node))
         (start-segments (segments-starting-with node segments))
         (first-segment (car (sort (copy-list start-segments) #'< :key (lambda (seg) (length (path seg))))))
         (segments (cons first-segment (remove first-segment segments :test #'nodes-eq)))
         (segments (adjust-segments-for-start-node node segments))
         (agenda (make-agenda first-segment))
         (*text-result* "")
         (*segment-pool* (sort (copy-list segments) #'segment-lessp))
         (base-text (format-segments first-segment initial-indent indent-delta :initial t))
         (graph-text (string-trim (list #\, #\- #\space #\newline) base-text)))
    graph-text))

(defmethod format-cgraph ((node graph-node) &key (initial-indent 0) (indent-delta 3))
  (let* ((graph-text (cgraph-text node))
         (result (strcat graph-text #\.)))
    (if *always-print-ascii-arrows*
        (arrows-to-ascii result)
        result)))

(defmethod format-cgraph ((nodes list) &key (initial-indent 0) (indent-delta 3))
  (format-cgraph (car nodes) :initial-indent initial-indent :indent-delta indent-delta))


(defmethod format-cgraph ((graph graph) &key (initial-indent 0) (indent-delta 3) (start-concept (head graph)))
  (format-cgraph start-concept))


;; (let* ((graph (pcg "[DRIVE]-
;;                          (agnt)→[PERSON: *x]
;;                          (dest)→[CITY: Baltimore]
;;                          (inst)→[CHEVY]-
;;                                    (attr)→[OLD]
;;                                    (poss)←[PERSON: *x]."))
;;        (start-concept (find-concept 'city graph)))
;; (format-cgraph start-concept))



(defun segment-lessp (seg1 seg2)
  "Compare two segments for deterministic ordering"
  (string< (format nil "~A" (segment-sort-key seg1))
           (format nil "~A" (segment-sort-key seg2))))


(defmethod print-cgraph ((node graph-node) &key (indent 0) (delta 3) (stream *standard-output*))
  ;;(declare (special *node-ref* *debug-mode*))
  (let ((text (format-cgraph node :initial-indent indent
                                  :indent-delta delta)))
    (print text stream)
    nil))


(defgeneric pcg (thing))

(defmethod pcg ((graph-node graph-node))
  (format-cgraph graph-node))

(defmethod pcg ((graph graph))
  (format-cgraph graph))

(defmethod pcg ((graph list))
  (pcg (car graph)))

(defmethod pcg ((thing (eql nil)))
  nil)




(defmethod flatten-cgraph ((text string))
  (let ((tokens '(#\space #\tab #\return #\newline ))
        (text (copy-seq text)))
    (dolist (token tokens)
      (setf text (remove token text)))
    text))

(defmethod graph-every-concept ((node graph-node))
  (let ((concepts (collect-concepts node)))
    (mapcar #'format-cgraph concepts)))

(defmethod graph-every-concept ((str string))
  (graph-every-concept (pcg str)))

(defmethod graph-every-concept ((graph graph))

  (let ((concepts (remove-if-not (lambda (node)
                                   (typep node 'concept))
                                 (nodes graph))))
    (mapcar #'format-cgraph concepts)))

(defmethod graph-every-concept ((concepts list))
  (assert (every #'concept-p concepts))
  (mapcar #'format-cgraph concepts))







(defun arrows-to-ascii (graph-string)
  (setf graph-string (frob-substrings graph-string (list right-arrow-string) "->"))
  (setf graph-string (frob-substrings graph-string (list left-arrow-string) "<-"))
  graph-string)

(defun arrows-to-unicode (graph-string)
  (setf graph-string (frob-substrings graph-string (list "->") right-arrow-string))
  (setf graph-string (frob-substrings graph-string (list "<-") left-arrow-string))
  (setf graph-string (frob-substrings graph-string (list "](") "] ("))
  (setf graph-string (frob-substrings graph-string (list ")[") ") ["))
  (setf graph-string (frob-substrings graph-string (list "-[") "- ["))
  (setf graph-string (frob-substrings graph-string (list "-(") "- ("))
  graph-string)


(defun normalize-cgraph-string (graph-string &key (concept-case :upcase) (relation-case :downcase))
  "Normalize the case of concept-type and relation-type labels in a conceptual graph string.

   Concept-type labels are text between '[' and ']' (or '[' and ':' if a ':' is present).
   Relation-type labels are text between '(' and ')'.

   :concept-case - either :upcase (default) or :downcase
   :relation-case - either :upcase or :downcase (default)"
  (let ((result (make-array (length graph-string) :element-type 'character :fill-pointer 0 :adjustable t))
        (i 0)
        (len (length graph-string)))

    (flet ((case-convert (text case-type)
             (ecase case-type
               (:upcase (string-upcase text))
               (:downcase (string-downcase text)))))
      (loop while (< i len) do
        (let ((ch (char graph-string i)))
          (cond
            ;; Handle concept: [TYPE...] or [TYPE:...]
            ((char= ch #\[)
             (vector-push-extend ch result)
             (incf i)
             ;; Read until we hit ':' or ']'
             (let ((type-start i)
                   (type-end nil))
               (loop while (and (< i len)
                                (not type-end))
                     do (let ((current (char graph-string i)))
                          (cond ((or (char= current #\:) (char= current #\]))
                                 (setf type-end i)
                                 ;; Convert the type label (with bounds checking)
                                 (when (and type-start type-end (<= type-start type-end len))
                                   (let* ((type-text (subseq graph-string type-start type-end))
                                          (normalized (case-convert type-text concept-case)))
                                     (loop for c across normalized do
                                       (vector-push-extend c result))))
                                 ;; Don't increment i here - we'll handle the ':' or ']' in next iteration
                                 )
                                (t
                                 (incf i)))))))

            ;; Handle relation: (TYPE)
            ((char= ch #\()
             (vector-push-extend ch result)
             (incf i)
             ;; Read until we hit ')'
             (let ((type-start i)
                   (type-end nil))
               (loop while (and (< i len)
                                (not type-end))
                     do (let ((current (char graph-string i)))
                          (cond ((char= current #\))
                                 (setf type-end i)
                                 ;; Convert the type label (with bounds checking)
                                 (when (and type-start type-end (<= type-start type-end len))
                                   (let* ((type-text (subseq graph-string type-start type-end))
                                          (normalized (case-convert type-text relation-case)))
                                     (loop for c across normalized do
                                       (vector-push-extend c result))))
                                 ;; Don't increment i here - we'll handle the ')' in next iteration
                                 )
                                (t
                                 (incf i)))))))

            ;; All other characters pass through unchanged
            (t
             (vector-push-extend ch result)
             (incf i))))))

    (arrows-to-unicode (coerce result 'string))))



#|
(initialize-cgraph)
(setq s2 "[PERSON: Sue]<-(agnt)<-[GIVE]-
                           (rcpt)->[DOG: Spot]<-(agnt)<-[EAT: #1]
                           (rcpt)->[DOG: Fido]<-(agnt)<-[EAT: #2]
                           (inst)->[FOOD: #1]<-(obj)<-[EAT: #1]
                           (inst)->[FOOD: #2]<-(obj)<-[EAT: #2].")
(setq g2 (parse-cgraph s2))
(format-cgraph g2)
(find-concept (get-concept-type 'give) (pcg s2) )
|#




;;;; ;;; Make cgraph from segments
;;;;
;;;; ;;; see FORMAT-SEGMENTS for example
;;;; (defmethod combine-segments ((start-segment graph-segment) (remaining-segments list))
;;;;   )
;;;;
;;;; (defmethod graph-from-segments ((start-node graph-node) (segments list))
;;;;   (let* ((start-segment (segment-starting-with start-node segments))
;;;;          (remaining-segments (reverse (remove start-segment segments)))
;;;;          (connected (combine-segments start-segment remaining-segments)))
;;;;     ;; what else needs to be done
;;;;     connected))
;;;;
;;;; (defmethod make-graph-from-segments ((node graph-node))
;;;;   (reset-cgraph)
;;;;   (let* ((segments (make-graph-segments node))
;;;;          (first-segment (find node segments :key #'segment-first-node :test #'nodes-eq))
;;;;          (remaining-segments (remove first-segment segments :test #'nodes-eq))
;;;;          (seg-list (cons first-segment remaining-segments))
;;;;          (graph (graph-from-segments node seg-list)))
;;;;     graph))
