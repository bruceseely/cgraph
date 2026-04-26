2;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Utterance-path walking (Sowa 1984, Rules 1 and 6, Phase 1 subset).
;;  Phase 1 implements only the structural skeleton: locate the main
;;  predicate, group its arcs by syntactic role, hand off to the realizer.
;;  Anaphora (Rule 5), branch markers (Rule 3), and nesting (Rule 4) are
;;  added in later phases.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defstruct walk-state
  (uttered (make-hash-table :test 'eq))
  (traversed (make-hash-table :test 'eq)))

(defun mark-uttered (state concept)
  (setf (gethash concept (walk-state-uttered state)) t))

(defun uttered-p (state concept)
  (gethash concept (walk-state-uttered state)))

(defun mark-traversed (state relation)
  (setf (gethash relation (walk-state-traversed state)) t))

(defun traversed-p (state relation)
  (gethash relation (walk-state-traversed state)))

(defun graph-nodes (graph)
  "Normalize input to a list of nodes. Accepts a graph, a list of nodes, or a CG string."
  (cond ((stringp graph) (parse-cgraph graph))
        ((typep graph 'graph) (nodes graph))
        ((listp graph) graph)
        (t (error "graph-nodes: unrecognized argument ~s" graph))))

(defun graph-relations-of (nodes)
  (remove-if-not #'relation-p nodes))

(defun graph-concepts-of (nodes)
  (remove-if-not #'concept-p nodes))

(defun other-arcs (relation concept)
  "Return arcs of RELATION other than CONCEPT (preserving order)."
  (remove concept (arcs relation) :test #'eq))

(defun other-end (relation concept)
  "For a binary relation, the single other concept."
  (first (other-arcs relation concept)))

(defun concept-relations (concept)
  "All relations attached to CONCEPT (incoming + outgoing)."
  (arcs concept))

;;; --- Main predicate selection -----------------------------------------------

(defun verb-side-of-subject-rel (rel)
  "Given a subject-introducing relation (AGNT, EXPR, ...), return the
   concept on the verb side. By convention these relations have the
   animate/experiencer as outarc and the verb as the (single) inarc."
  (first (other-arcs rel (outarc rel))))

(defun find-subject-relation (relations)
  (find-if (lambda (r) (eq (relation-role r) :subject)) relations))

(defun act-or-event-concept-p (concept)
  (let ((ctype (concept-type concept)))
    (or (string-equal (label ctype) 'act)
        (string-equal (label ctype) 'event)
        (handler-case (subtype-p ctype 'act)   (error () nil))
        (handler-case (subtype-p ctype 'event) (error () nil)))))

(defun find-main-predicate (nodes)
  "Locate the concept that anchors the sentence's main clause.
   Preference order: verb-side of any subject relation (AGNT, EXPR, ...),
   then any act/event concept, then the most-connected concept."
  (let* ((relations (graph-relations-of nodes))
         (concepts  (graph-concepts-of nodes))
         (subj-rel  (find-subject-relation relations)))
    (or (and subj-rel (verb-side-of-subject-rel subj-rel))
        (find-if #'act-or-event-concept-p concepts)
        (first (sort (copy-list concepts) #'>
                     :key (lambda (c) (length (arcs c))))))))

;;; --- Copula (verbless) clause detection -----------------------------------

(defun copula-required-p (nodes)
  "True when the graph has no subject-introducing relation, so the realizer
   should produce a copular clause (X is Y) instead of a verbal one."
  (not (find-subject-relation (graph-relations-of nodes))))

(defun have-clause-p (nodes)
  "True when the graph has a POSS relation but no subject relation and no
   act/event concept — should render as 'X has Y' (Phase 6 polish)."
  (let ((relations (graph-relations-of nodes))
        (concepts  (graph-concepts-of nodes)))
    (and (some (lambda (r) (eq (relation-role r) :poss)) relations)
         (not (find-subject-relation relations))
         (not (find-if #'act-or-event-concept-p concepts)))))

(defun find-poss-source (nodes)
  "Return the (animate) source side of the first POSS relation."
  (let ((poss-rel (find-if (lambda (r) (eq (relation-role r) :poss))
                           (graph-relations-of nodes))))
    (when poss-rel
      ;; outarc = possessed (entity); the (single) inarc = possessor (animate).
      (first (other-arcs poss-rel (outarc poss-rel))))))

(defun find-copula-topic (nodes)
  "For a verbless graph, pick the topic — the entity side of an ATTR/CHRC/LOC
   relation. ATTR has the attribute as outarc and the entity as the inarc,
   so the topic is the (single) other end."
  (let* ((relations (graph-relations-of nodes))
         (concepts  (graph-concepts-of nodes))
         (copular-rel (find-if (lambda (r)
                                 (member (relation-role r) '(:adj :pp)))
                               relations)))
    (cond (copular-rel
           (or (first (other-arcs copular-rel (outarc copular-rel)))
               (outarc copular-rel)))
          (t (first (sort (copy-list concepts) #'>
                          :key (lambda (c) (length (arcs c)))))))))

;;; --- Arc grouping by role ---------------------------------------------------

(defun classify-relations (main-concept)
  "Group MAIN-CONCEPT's relations into a role -> list-of-relations alist.
   Unmapped relations are dropped silently for now (Phase 1)."
  (let ((buckets (make-hash-table :test 'eq)))
    (dolist (rel (concept-relations main-concept))
      (let ((role (relation-role rel)))
        (when role
          (push rel (gethash role buckets)))))
    ;; Sort PP bucket by configured priority so manner-before-time etc. holds.
    (when (gethash :pp buckets)
      (setf (gethash :pp buckets)
            (sort (gethash :pp buckets) #'< :key #'pp-priority-rank)))
    ;; Reverse the rest so insertion order is preserved.
    (maphash (lambda (k v)
               (unless (eq k :pp)
                 (setf (gethash k buckets) (nreverse v))))
             buckets)
    buckets))
