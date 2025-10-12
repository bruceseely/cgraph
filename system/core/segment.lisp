;;; -*- Mode; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  segments  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass graph-segment (basic-node)
  (
   ;; (buffer :initform (list)
   ;;         :accessor buffer)
   ;; list of graph-nodes in order
   (path :initform (list)
	 :initarg :path
	 :accessor path)))

(defvar *segments* nil)


(defmethod print-object ((segment graph-segment) stream)
  (print-unreadable-object (segment stream :type nil :identity nil)
    ;;(format stream "SEG ~:a" (path segment))
    ;;(format stream "SEG ~:a" (format-segment-path segment))
    ;;(format stream "SEG ~:a" (apply #'strcat (format-path-tokens (path segment))))
    ;;(format stream "SEG ~:a" (format-segment segment))
    ;;(format stream "SEG ~{a~}" (path segment))
    (format stream "SEG ~a" (remove #\space (apply #'strcat (format-path-tokens (path segment)))))
    ))

(defmethod path-length ((segment graph-segment))
  (length (path segment)))




(defmethod make-segment ((node-list list))
  (assert (every #'graph-node-p node-list))
  (let ((segment (make-instance 'graph-segment :path node-list)))
    (push segment *segments*)
    segment))

(defmethod make-segment ((concept concept))
  (make-segment (list concept)))

;; (defmethod make-segment ((relation relation))
;;   (make-segment (list relation)))

(defmethod make-segment ((graph string))
  (make-segment (collect-nodes (pcg graph))))

(defmethod make-segment ((graph (eql nil)))
  (make-segment '(list)))



(defmethod segment-p ((thing graph-segment))
  t)

(defmethod segment-p ((thing t))
  nil)


(defmethod segment-reverse ((segment graph-segment))
  (setf (path segment) (reverse (path segment)))
  segment)

(defmethod segment-reverse ((segment (eql nil))) nil)


;;; true if the last node of path connects to more than one segment
(defmethod segment-multiple-next-p ((segment graph-segment))
  (> (length (arcs (segment-last-node))) 2))

(defmethod segment-multiple-prev-p ((segment graph-segment))
  (> (length (arcs (segment-first-node))) 2))


;;; the segment is not followed by any segments
(defmethod segment-end-p ((segment graph-segment))
  (< (length (arcs (segment-last-node))) 2))


;; (defmethod segment-previous-nodes ((segment graph-segment))
;;   (let ((first (segment-first-node segment)))
;;     (if (second (path segment))
;;       (remove (second (path segment)) (arcs first))
;;       (arcs first))))


;; (defmethod segment-sibling-p ((predecessor graph-segment))
;;   (segment-multiple-next-p predecessor))


(defmethod segment-first-node ((seg graph-segment))
  (car (path seg)))

(defmethod segment-second-node ((seg graph-segment))
  (cadr (path seg)))

(defmethod segment-last-node ((seg graph-segment))
  (car (last (path seg))))

(defmethod segment-penultimate-node ((seg graph-segment))
  (let ((len (length (path seg))))
    (cond ((> len 1)
           (nth (- len 2) (path seg)))
          (t nil))))


(defmethod segment-last-concept ((seg graph-segment))
  (let ((path (path seg)))
    (find-if (lambda (x) (typep x 'concept)) path :from-end t)))


(defmethod segment-penultimate-concept ((seg graph-segment))
  (let* ((last-con (segment-last-concept seg))
         (last-index (position last-con (path seg) :test #'nodes-eq)))
    (when (> last-index 1)
      (let ((con (nth (- last-index 2) (path seg))))
        con))))

(defmethod segment-contains-node-p ((segment graph-segment) (node graph-node))
  (not (null (find node (path segment) :test #'nodes-eq))))

(defmethod segments-connected-p ((seg1 graph-segment) (seg2 graph-segment))
  (cond ((nodes-eq (segment-last-node seg1) (segment-first-node seg2))
         (list seg1 seg2))
        ((nodes-eq (segment-last-node seg2) (segment-first-node seg1))
         (list seg2 seg1))
        (t nil)))


(defmethod extend-path ((segment graph-segment) (link link))
  (let* ((rel (rel link))
         (con (con link))
         (last-node-type (type-of (segment-last-node segment)))
         (suffix (typecase (segment-last-node segment)
                   (concept (list rel con))
                   (relation (list con rel)))))
    (mark rel)
    (mark con)
    (setf (path segment) (append (path segment) suffix))))

(defmethod extend-path ((segment graph-segment) (node graph-node))
  (mark node)
  (setf (cdr (last (path segment))) (list node)))


(defmethod segments-equal ((segment1 graph-segment) (segment2 graph-segment))
  (every (lambda (node1 node2) (nodes-eq node1 node2)) (path segment1) (path segment2)))

(defmethod segment-contains-node-p ((segment graph-segment) (node graph-node))
  (find node (path segment) :test #'nodes-eq))

(defmethod segments-containing-node ((node graph-node) (segments list))
  (let ((found (list)))
    (dolist (segment segments)
      (when (segment-contains-node-p segment node)
	(push segment found)))
    (reverse found)))


(defmethod segments-starting-with ((node graph-node) (segments list))
  (remove-if-not (lambda (seg)
                   (nodes-eq (car (path seg)) node))
                 segments))

(defmethod segments-ending-with ((node graph-node) (segments list))
  (remove-if-not (lambda (seg)
                   (nodes-eq (car (last (path seg))) node))
                 segments))


(defmethod segments-containing-node ((node graph-node) (segments list))
  (assert (every #'segment-p segments)
          (segments)
          "in segments-with-node(), \'segments\', ~s,  must be a list of segments" segments)
  (remove-if (lambda (segment)
               (not (find node (path segment) :test #'nodes-eq)))
             segments))

(defmethod segment-containing-node ((node graph-node) (segments list))
  (car (segments-containing-node node segments)))



(defmethod segment-graph ((segment graph-segment))
  (car (path segment)))


(defmethod segment-starting-with ((node graph-node) (segments list))
  (when segments
    (find node segments :key #'segment-first-node :test #'nodes-eq)))

(defmethod segment-ending-with ((node graph-node) (segments list))
  (when segments
    (find node segments :key #'segment-last-node :test #'nodes-eq)))

;;; list is sorted to be consistent with segment sorting
(defmethod next-nodes ((segment graph-segment))
  (let* ((prev (segment-penultimate-node segment))
         (pruned (remove prev (arcs (car (last (path segment)))) :test #'nodes-eq))
         (sorted (sort (copy-list pruned) #'alpha-lessp
                       :key (lambda (node) (label (node-type node) )))))
    sorted))

;; (defmethod next-segments ((current-segment graph-segment) (segments list))
;;   (let* ((last-node (segment-last-node current-segment))
;;          (next (segments-starting-with last-node segments))
;;          (all-enders (segments-ending-with last-node segments))
;;          (enders (remove current-segment all-enders))
;;          )
;;     (dolist (seg all-enders)
;;       (let ((new (segment-reverse seg)))
;;         (push new (remove seg segments))))
;;     (append next (mapcar #'segment-reverse enders))))




;; Deterministic segment ordering functions
(defun segment-sort-key (segment)
  "Generate a deterministic sort key for a segment"
  (let* ((first-node (segment-first-node segment))
         (seg-path (path segment))
         (path-length (length seg-path))
         (first-relation (when (and seg-path (> (length seg-path) 1))
                          (cadr seg-path))))  ; second element should be first relation
    ;; Create composite key for deterministic ordering
    (list
     ;; Primary: type of first node (concept vs relation)
     (if (concept-p first-node) 0 1)
     ;; Secondary: string representation of first node
     (format-node first-node)
     ;; Tertiary: first relation name (this is the key fix!)
     (if first-relation (format-node first-relation) "")
     ;; Quaternary: path length (shorter paths first)
     path-length
     ;; Quaternary: full path signature (for final tie-breaking)
     (mapcar #'format-node seg-path))))


(defmethod next-segments ((current-segment graph-segment) (segments list))
  (let* ((last-node (segment-last-node current-segment))
         (segments (remove current-segment segments))
         (enders (segments-ending-with last-node segments)))

    ;; adjust segment source list to accommodate reversed candidates
    (dolist (ender (remove current-segment enders))
      (let ((modified-seg (segment-reverse ender)))
        (setf segments (remove ender segments))
        (setf segments (cons modified-seg segments))))

    (let* ((next (segments-starting-with last-node segments))
           (remaining (set-difference segments next)))
      (values next (sort remaining #'segment-lessp)))))



(defmethod list-segments ((segments list) &optional (stream *standard-output*))
  ;;(format stream "~&| :segments (~d)" (length segments))
  ;;(format stream "~&| ~s~%" (car segments))
  (dolist (item segments)  ;;(cdr segments))
    (format stream "~&| ~s~%" item))
  (format stream "~&- - - - - - - - -~%"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  agendas  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass agenda ()
  ((contents :initform (list)
             :initarg :contents
             :accessor contents)))

(defmethod make-agenda ((segment graph-segment))
  (let ((agenda (make-instance 'agenda)))
    (agenda-add agenda segment)))

(defmethod list-agenda ((agenda agenda) &optional (stream *standard-output*))
  (when (contents agenda)
  (format stream "~&~s~%" (contents agenda))))

(defmethod print-object ((agenda agenda) stream)
  (print-unreadable-object (agenda stream :type t)
    (format stream "~:a" (contents agenda))))


;;; add to end of agenda
(defmethod agenda-add ((agenda agenda) (segment graph-segment))
  ;;(format t "~& >>>>>>> add ~a~%" segment)
  (let ((item segment))
    (cond ((null (contents agenda))
           (setf (contents agenda) (list item)))
          ((find item (contents agenda)))
          (t
           ;;(setf (contents agenda) (append (contents agenda) (list item)))
           (setf (cdr (last (contents agenda))) (list item)))))
  agenda)

(defmethod agenda-add ((agenda agenda) (segments list))
  ;;(assert ...
  (mapcar (lambda (seg) (agenda-add agenda seg)) segments))


(defmethod agenda-pop ((agenda agenda))
  (let ((seg (car (contents agenda))))
    (setf (contents agenda) (cdr (contents agenda)))
    seg))




(defmethod agenda-peek ((agenda agenda))
  (car (contents agenda)))

(defmethod agenda-empty-p ((agenda agenda))
  ;;(format;;  t "~&(agenda-empty-p ~a)" agenda)
  ;; (format t "~&  agenda: ~s~%"  (contents agenda))
  ;; (format t "~&  (contents agenda): ~s~%"  (contents agenda))
  ;; (format t "~&  (length (contents agenda)): ~s~%"  (length (contents agenda)))
  ;; (format t "~&  (zerop (length (contents agenda))): ~s~%"  (zerop (length (contents agenda))))
  (zerop (length (contents agenda))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; takes a segment and splits it at the supplied node or close to the middle
;;; the path of the second segment is reversed so both segments end with the same node
;;; the path of the first segment is truncated
;;; a new segment is created and returned containing the remainder of the path
;;; the split-node (last node of both segments) is a concept so a variable can be assigned
(defmethod split-segment ((segment graph-segment) &optional node)
  (let* ((original-path (path segment))
         (first-node (car original-path))
         (last-node (car (last node)))
         (path-length (length original-path))
         (split-point
           (cond ((< path-length 4) nil)
                 (node (position node original-path))
		 (t (floor (/ path-length 2))))))

    (when split-point
      (dolist (term (subseq original-path split-point))
        (if (typep term 'concept)
            (return)
            (incf split-point)))

      (let ((split-node (elt (path segment) split-point)))
        (when (concept-type-p split-node)
          (let ((path1 (subseq original-path 0 (1+ split-point)))
	        (path2 (reverse (subseq original-path split-point))))
            (setf (path segment) path1)
            (values (make-segment path2) segment)))))))




;;; nodes is a list of pairs (old-ref-num new-node)
(defmethod copy-segment ((segment graph-segment) &optional nodes)
  ;;(format t "~&segment path1: ~s" (path segment))
  (let* ((path1 (path segment))
         (new-nodes (mapcar (lambda (node)
                              (or (cadr (assoc (node-ref node) nodes))
                                  (let ((new-node
                                          (typecase node
                                            (concept (copy-concept node))
                                            (relation (copy-relation node)))))
                                    (push (list (node-ref node) new-node) nodes)
                                    ;;(format t "~&nodes: ~s" nodes)
                                    new-node)))
                            path1))
         ;;(zz (print (setq *new-nodes new-nodes)))
         (path2 (mapcar (lambda (node1 node2)
                          ;;(format t "~2&args: ~s, ~s" node1 node2)
                          (let ((node2-arcs (list)))
                            ;;(format t "~&node2-arcs: ~s" node2-arcs)
                            (dolist (arc1 (arcs node1))
                              ;;(format t "~&arc1: ~s" arc1)
                              (let ((index (position arc1 path1 :test #'nodes-eq)))
                                ;;(format t "~&index: ~s" index)
                                (when index
                                  (let ((arc2 (elt new-nodes index)))
                                    ;;(format t "~&arc2: ~s" arc2)
                                    (pushnew arc2 node2-arcs :test #'nodes-eq)))
                                ;;(format t "~&node2-arcs: ~s" node2-arcs)
                                (setf (arcs node2) (reverse node2-arcs))
                                ;; (format t "~&(arcs node2): ~s" (arcs node2))
                                ;; (format t "~&node2: ~s" node2)
                                )))
                          node2)
                        path1 new-nodes))
         ;;(zz (print (setq *path2 path2)))
         (new-segment (make-segment path2)))
    new-segment))


(defun copy-segments (segments)
  (let ((node-table (list))
        (new-segments (list)))
    (dolist (segment segments)
      (push (copy-segment segment node-table) new-segments))
    (reverse new-segments)))


;;; a segment is a one-dimensional path of nodes
;;; a segment has a path of one concept when it is created
;;; a link is a list of (relation concept)
;;; only links can be added to a segment
;;; nodes are marked when they are added to a segment
;;; traversal consists of collecting links
;;; when a link is encountered during traversal,
;;;     the concept is tested for marked
;;;     if marked, a variable is added


(defmethod collect-segments ((start-node concept))
  ;;(unmark-graph start-node)

  (let* ((debug (eval (= 5 7)))
         (seen-nodes (list)))

    (labels ((see (node)
               (cond ((null node) nil)
                     ((null seen-nodes)
                      (setf seen-nodes (list node)))
                     (t
                      (pushnew node seen-nodes :test #'nodes-eq))))
             (seen (node)
               (let ((s (find node seen-nodes :test #'nodes-eq)))
                 ;;(format t "~&? (seen ~a): ~a~%" node s)
                 (not (null s))))
             (unseen (node)
               (not (seen node))))

      (let* ((initial-segment (make-segment (list start-node)))
             (segments (list initial-segment))
             (agenda (make-agenda initial-segment)))

        (block loop
          (loop
            (when debug (format t  "~%=============================================================~%"))

            (when (agenda-empty-p agenda)
              (return-from loop))

            (let* ((current-segment (agenda-pop agenda))
                   (current-node (segment-last-node current-segment)))

              (cond ((concept-p current-node)
                     ;; penultimate-node is the node connected to current-node
                     (let* ((penultimate-node (segment-penultimate-node current-segment))
                            (other-arcs (remove penultimate-node (arcs current-node)))
                            (next-arcs (set-difference other-arcs seen-nodes)))

                       (when debug
                         ;;(format t "~&penultimate-node: ~s~%"  penultimate-node)
                         (format t "~&current-node: ~s~%"  current-node)
                         (format t "~&(arcs current-node): ~s~%"  (arcs current-node))
                         (format t "~&seen-nodes: ~s~%"  seen-nodes)
                         (format t "~&other-arcs: ~s~%"  other-arcs)
                         (format t "~&next-arcs: ~s~%"  next-arcs))

                       (cond ((null other-arcs)
                              (when debug (format t "~&!concept.0: end~%")))

                             ((= (length other-arcs) 1)
                              (when debug (format t "~&!concept.1: extend current node"))
		              (let ((relation (car next-arcs)))
                                (when relation
                                  (extend-path current-segment relation)
                                  (when (unseen relation)
                                    (agenda-add agenda current-segment)
                                    (see relation)))))

                             ((> (length other-arcs) 1)
                              (when debug (format t "~&!concept.2: end current segment and start new segments~%"))
	                      (dolist (relation next-arcs)
                                (when (and relation (unseen relation))
                                  (let ((new-segment (make-segment (list current-node relation)))) ; arc-num too?
                                    (push new-segment segments)
                                    (agenda-add agenda new-segment))
                                  (see relation))))

                             (t (warn "Unhandled node: ~s,~50tnext-arcs:~s" current-node next-arcs)))))

                    ((relation-p current-node)
                     (let* ((penultimate-node (segment-penultimate-node current-segment))
                            (other-arcs (remove penultimate-node (arcs current-node)))
                            (next-arcs (set-difference other-arcs seen-nodes)))

                       (when debug
                         ;;(format t "~&penultimate-node: ~s~%"  penultimate-node)
                         (format t "~&current-node: ~s~%"  current-node)
                         (format t "~&(arcs current-node): ~s~%"  (arcs current-node))
                         (format t "~&seen-nodes: ~s~%"  seen-nodes)
                         (format t "~&other-arcs: ~s~%"  other-arcs)
                         (format t "~&next-arcs: ~s~%"  next-arcs))

                       (cond ((null other-arcs) ; end of graph branch, do nothing
                              (when debug (format t "~&!relation.0: end")))

                             ((= (length other-arcs) 1)
                              (when debug (format t "~&!relation.1: extend current node"))
                              (let ((concept (car other-arcs))) ;length = 1
                                (when concept
                                  (extend-path current-segment concept)
                                  (when (unseen concept)
                                    (agenda-add agenda current-segment)
                                    (see concept)))))

                             ((> (length other-arcs) 1)
                              (when debug (format t "~&!relation.2: end current segment and start new segments"))
                              (dolist (concept other-arcs)
                                (when (and concept (unseen concept))
                                  (let ((new-segment (make-segment (list current-node concept))))
                                    (push new-segment segments)
                                    (agenda-add agenda new-segment))
                                  (see concept))))

                             (t (warn "Unhandled node: ~s,~50tnext-arcs:~s" current-node next-arcs)))))))

            ;;(when debug (list-segments (reverse segments)))
            ))

        ;;set variables where necessary
        (let ((ends (mapcar #'segment-last-node segments)))
          (unmark ends)
          (dolist (node ends)
            (when (and (concept-p node) (generic-p node))
              (let ((count (count node ends :test #'nodes-eq)))
                (when (> count 1)
                  (set-variable node))))
            (mark node))
          (unmark ends))
        (reverse segments)))))


(defvar *segments* (list))

;; (defmethod form-segments ((node graph-node) &optional previous)
;;   (let* ((current-node node)
;;          (path (list current-node))
;;          (segments (list)))
;;     (block null
;;       (loop
;;         (format t "~&current-node: ~s~%"  current-node)
;;         (unless (marked current-node)
;;           (push current-node path)
;;           (mark current-node))
;;         (format t "~&(arcs current-node): ~s~%"  (arcs current-node))
;;         (let* ((next-nodes (remove previous (arcs current-node))))
;;           (cond ((< (length next-nodes) 1)
;;                  (push (make-segment (reverse path)) *segments*)
;;                  (return))

;;                 ((= (length next-nodes) 1)
;;                  (setf previous current-node)
;;                  (setf current-node (car (arcs current-node))))

;;                 ((> (length next-nodes) 1)
;;                  (push (make-segment (reverse path)) *segments*)
;;                  (dolist (n next-nodes)
;;                    (unless (marked n)
;;                      (form-segments n current-node)))
;;                  (return))))
;;         (format t "~&segments: ~s~%"  *segments*)
;;         ))
;;     (make-segment (reverse path))))


;;; Walk the nodes of the graph to create graph-segments to represent the graph
;;; a segment is a piece of the graph that is linear, with no branching.
;;; - node argument is the next node to be processed
;;; - segment argument is the segment currently being constructed
;;; - segments argument is a list of segments already created
;;; The graph is traversed, processing each node such that each node is either
;;;  - added to the segment currently being constructed, or
;;;  - used as the initial node of a new segment.
;;; If the node currently being processed is already marked,
;;;   the current segment is ended with that node,
;;;   because that node is already in another segment,
;;;   the first and last nodes appear as the start or end of least one other segment
;;; ;;the supplied node is not already included in the passed segment
;;; returns a list of the segments created
;;;

(defmethod make-graph-segments ((node concept))
  (declare (special *segments))
  (let* ((segments (collect-segments node))
	 (added-segments (list)))

    ;; check for cycles
    (dolist (segment segments)
      (let ((segment-first-node (segment-first-node segment))
	    (segment-last-node (segment-last-node segment)))
	(when (and (> (length (path segment)) 1)
                   (nodes-equal segment-first-node segment-last-node))
	  (let ((new-segment (split-segment segment)))
            (when new-segment
	      (push new-segment added-segments))))))

    (remove nil (append segments (reverse added-segments)))))



;; (defmethod format-segment-path ((path list))
;;   (let* (;; (connecting-segments (remove-if-not (lambda (seg)
;; 	;; 				      (segments-connected-p segment seg))
;; 	;; 				    segments))
;;         ;; (multi-path-p (> (length connecting-segments) 1))
;;         ;;(suffix (if multi-path-p "-" ""))
;;         (text-list (format-path-tokens path))
;;         (text (apply #'strcat text-list))
;;         ;; (current-indent-string (if  (plusp indent)
;;         ;;                             (make-string indent :initial-element #\space)
;;         ;;                             ""))
;;         )
;;     (format nil "~%~a" text)))
;; (defmethod format-segment-path ((segment graph-segment))
;;   (format-segment-path (path segment)))

1

;;; split cycle segments
(defun preprocess-segments (segments)
  (let ((new-segments (list))
        (length-threshold 6))
    (dolist (segment segments)
      (when (nodes-eq (segment-first-node segment) (segment-last-node segment))
        (cond ((not (nodes-eq (segment-first-node segment) (segment-last-node segment)))
               (push segment new-segments))
              ((< (path-length segment) length-threshold)
               ;; ?? does this do what I want ???
               (set-variable (segment-first-node segment))
               (push segment new-segments))
              (t
               ;; ?is it necessary/helpful to keep the two segments together??
               (let ((pos (position segment segments)))
                 (remove segment segments)
                 (multiple-value-bind (second-segment first-segment)
                     (split-segment segment)
                   (set-variable (segment-last-node first-segment))
                   ;; ?is this the right order?
                   (push second-segment new-segments)
                   (push first-segment new-segments)))))))
    (reverse new-segments)))




(defmethod find-segment-with-node ((node graph-node) (segments list))
  (let* ((segment1 (segment-starting-with node segments))
         (segment2 (unless segment1 (segment-ending-with node segments)))
         (segment3 (unless segment2  (segment-containing-node node segments)))
         (segment4 (when segment3 (split-segment segment3 node))))
    (or  segment1 segment2 (list (reverse segment3) (reverse segment4)))))


;;; modify segments list so that start-node is the first node of the first segment
;;; if a segment starts with the start-node, make it the first segment
;;; else if a segment ends with the start-node, reverse it and make it the first segment
;;; else create a new segment for the start-node and make it the first node
;;;      split the segment containing the start node and add the two segments next
;;;      then add the remaining segments
;; (defmethod adjust-segments-for-start-node ((start-node graph-node) (segments list))
;;   (let* ((collected-segments (list))
;;          (segments-first (remove-if-not (lambda (seg)
;;                                           (nodes-eq (segment-first-node seg) start-node))
;;                                         segments))
;;          (segments-last (remove-if-not (lambda (seg)
;;                                          (nodes-eq (segment-last-node seg) start-node))
;;                                        segments))
;;          (segment-mid (remove-if-not (lambda (seg)
;;                                        (segment-contains-node-p seg start-node))
;;                                      (set-difference (set-difference segments
;;                                                                      segments-first)
;;                                                      segments-last))))
;;     (format t "~&segments-first: ~s~%"  segments-first)
;;     (format t "~&segments-last: ~s~%"  segments-last)
;;     (format t "~&segment-mid: ~s~%"  segment-mid)

;;     (when segments-first
;;       (setf collected-segments segments-first))

;;     (when segments-last
;;       (setf collected-segments
;;             (append collected-segments
;;                     (mapcar #'segment-reverse segments-last))))

;;     (when segment-mid
;;       (dolist (seg segment-mid)
;;         (multiple-value-bind (second-segment first-segment)
;;             (split-segment segment-mid start-node)
;;           (when second-segment
;;             (setf collected-segments
;;                   (append collected-segments
;;                           (list first-segment
;;                                 (segment-reverse second-segment))))))))

;;     collected-segments))



(defmethod adjust-segments-for-start-node ((start-node concept) (segments list))
  (let* ((collected-segments segments)
         (segment-mid (remove-if (lambda (seg)
                                       (or
                                       (not (segment-contains-node-p seg start-node))
                                       (nodes-eq (segment-first-node seg) start-node)
                                       (nodes-eq (segment-last-node seg) start-node)
                                       ))
                                     segments)))

    (when segment-mid
      (dolist (seg segment-mid)
        (multiple-value-bind (second-segment first-segment)
            (split-segment segment-mid start-node)
          (when second-segment
            (setf collected-segments
                  (append (remove seg collected-segments)
                          (list first-segment
                                (segment-reverse second-segment))))))))

    (remove-duplicates collected-segments)))

;;(adjust-segments-for-start-node node segments)


;; (defun make-format-segments-plan (segments &optional start-node)
;;   (let* ((segments (preprocess-segments segments))
;;          (plan (list))
;;          (current-segment (cond ((null start-node) (car segments))
;;                                 (t (find-if (lambda (segment) (segment-contains-node-p segment start-node))
;;                                       segments))))

;;          (current-node
;;            (cond ((nodes-eq start-node (segment-first-node containing-segment)) containing-segment)
;;                  ((nodes-eq start-node (segment-last-node containing-segment)) (segment-reverse containing-segment))
;;                  ((find start-node segments :key #'segment-last-node :test #'nodes-eq) (segment-reverse segment))
;;                  )))
;;     (find start-node segments :key #'segment-last-node :test #'nodes-eq)
;;     (setf segments (remove current-segment segments :test #'nodes-eq))
;;     (block loop
;;       (loop
;;         (wnen (null plan)
;;               (push current-segment plan))
;;         (setq current-segment (pop segments))
;;         (when (null current-segment)
;;           (return-from loop))))))



;; (defmethod as-string ((segment graph-segment))
;;   (apply #'concatenate 'string (format-path-tokens (path segment))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  testing  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod test-split-segment ((node graph-node))
  (let* ((segments (make-graph-segments node)))
    ;;(print segments)
    (dolist (seg segments)
      (terpri)
      (when (> (length (path seg)) 3)
	(let ((split-segments (split-segment seg)))
	  ;;(print split-segments)
          )))))


;; (defun test-copy-segments ()
;;   (let* ((*node-ref* nil)
;;          (graph-string
;;            "[food]-
;;               (obj)<-[give]-
;;                 (agnt)->[person]
;;                 (rcpt)->[dog:*z],
;;               (obj)<-[eat]->(agnt)->[dog:*z].")
;;          (graph (parse-cgraph graph-string))
;;          )
;;     ;; (format t "source graph string:~&~a" (format-cgraph graph))
;;     ;; (format t "processed graph string:~&~a" (format-cgraph graph))
;;     ))



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
(fcg *)
|#


#+nil
(defmethod extend-segment ((segment graph-segment))
  (let* ((current-concept (segment-last-node segment))
         (previous-concept (segment-penultimate-concept segment))
         (next-links (remove nil (other-links current-concept previous-concept))))

    ;; (format t "~&segment: ~s" segment)
    ;; (format t "~&current-concept: ~s" current-concept)
    ;; (format t "~&previous-concept: ~s" previous-concept)
    ;; (format t "~&next-links: ~s" next-links)
    ;; (format t "~&: ~s" )

    (cond ((> (length next-links) 1)
	   (dolist (next-link next-links)
             (let ((new-segment (make-segment current-concept)))
               (extend-path new-segment next-link))))

          ((= (length next-links) 1)
	   (let ((next-link (car next-links)))
             (extend-path segment next-link)))

          (t ;;(= (length next-links) 0)
           ;;do nothing
           )))
  segment)



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
