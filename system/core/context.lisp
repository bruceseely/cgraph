;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;; include NAME, MEASURE, ...  etc in concept
;;;    instead of explicit graph of concept objects
;;; (defvar *abbreviated-concepts* t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  context  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;; NOTE *context* is declared in definitions.lisp

(defclass context ()
  ((nodes :initform (list)           ; list containing graphs as lists
          :initarg :nodes
          :accessor nodes
          )
   (graphs :initform (list) ; list containing nodes that are head nodes
           :initarg :graphs
           :accessor graphs
           )
   (child-contexts  :initform (list) ; contexts contained by this context
                    :initarg :contexts
                    :accessor child-contexts
                    )
   (parent-context :initform nil
                   :initarg :parent
                   :accessor parent-context
                   )
   ;; Map for efficient graph referent queries
   ;; Maps from graph objects to lists of concepts using them
   (graph-referent-map :initform (list)
                        :accessor graph-referent-map
                        :documentation "association list mapping graphs to concepts")
   ;; Duplicate-detection index for ADD-CGRAPH; see GRAPH-INDEX below. Holds
   ;; structure-key -> list of graphs, plus the cons cell of (GRAPHS CONTEXT)
   ;; the index was built from, which is how staleness is detected.
   (graph-index :initform nil
                :accessor graph-index-table)
   (graph-index-source :initform :unbuilt
                       :accessor graph-index-source)
   ;; Last cons of (GRAPHS CONTEXT), so appending is O(1) rather than O(n) --
   ;; see GRAPHS-APPEND. Trusted only while GRAPH-INDEX-SOURCE still names the
   ;; current list, and only while it really is a last cons.
   (graphs-tail :initform nil
                :accessor graphs-tail)
   ;; Dedupe index for CACHE-CONCEPT; see CONCEPT-INDEX below. concept-key ->
   ;; list of cached concepts, plus the head cons of (NODES CONTEXT) it was
   ;; built from.
   (concept-index :initform nil
                  :accessor concept-index-table)
   (concept-index-source :initform :unbuilt
                         :accessor concept-index-source)
   (negated :initform nil
            :initarg :negated
            :accessor negated)))


(defmethod make-context (&optional (parent nil) &key negated)
  (let ((new-context (make-instance 'context :negated negated)))
    (when parent
      (setf (parent-context new-context) parent)
      (pushnew new-context (child-contexts parent)))
    new-context))

(defmethod initialize-context ((context context) &optional (parent nil parent-supplied))
  ;; (setf (child-contexts context) (list))
  ;; (when parent-supplied
  ;;   (setf (parent-context context) parent))
  (setf (graphs context) (list))
  (setf (nodes context) (list))
  (invalidate-graph-index context)
  (invalidate-concept-index context))

(defmethod initialize-context ((context (eql nil)) &optional (parent nil)))


(defmethod initialize-instance :after ((context context) &key &allow-other-keys)
  (initialize-context context))


;; (defmethod all-concepts ((context context))
;;   (let ((graph-concepts (list)))
;;     (dolist (graph (graphs context))
;;       (push (collect-concepts (car graph)) graph-concepts))
;;     (let ((concepts (apply #'append graph-concepts)))
;;       (remove-duplicates concepts))))


;; (defmethod all-concepts ((context (eql nil)))
;;   nil)

(define-condition cached-concept-lookup-failed (error)
  ((ctype :initarg :ctype :reader ctype)
   (msg :initarg :msg :reader msg)))


;;; ===========================================================================
;;; The concept cache, and its index
;;; ===========================================================================
;;;
;;; CACHE-CONCEPT runs from CONCEPT's INITIALIZE-INSTANCE :AFTER, so it is on the
;;; path of EVERY concept ever made. It used to do
;;;
;;;   (pushnew concept (nodes context) :test #'concepts-equal)
;;;
;;; which scans the whole cache on each call -- O(n) per concept, so building a
;;; corpus cost O(n^2) in the number of concepts, and that was where the time in
;;; graph construction went once ADD-CGRAPH was made linear.
;;;
;;; Same shape of fix as the graph index above: bucket by a cheap key, and run
;;; CONCEPTS-EQUAL only inside the bucket. The semantics are PUSHNEW's, unchanged
;;; -- the cache keeps one representative per equal concept, and a concept equal
;;; to one already cached is not added.
;;;
;;; BUCKETS, not key-as-identity. The key is allowed to be coarse: a concept
;;; whose referent is a whole GRAPH gets a constant key rather than a formatted
;;; nested graph, because formatting one is expensive and can recurse. Coarse is
;;; safe precisely because CONCEPTS-EQUAL still decides within the bucket; a key
;;; treated AS identity would merge concepts that are not equal, which is the one
;;; mistake that must not be made here.
;;;
;;; STALENESS. PUSHNEW changes the head of (NODES CONTEXT) on every add, so the
;;; recorded head is updated on each add rather than used to detect adds. It
;;; detects the other three writers -- INITIALIZE-CONTEXT, DECACHE-CONCEPT and
;;; CLEAR-CONCEPT-CACHE -- each of which replaces the list and calls
;;; INVALIDATE-CONCEPT-INDEX anyway. The head check is the backstop for anything
;;; that replaces (NODES CONTEXT) without saying so.

(defvar *concept-comparisons* 0
  "How many CONCEPTS-EQUAL comparisons CACHE-CONCEPT has made. Diagnostic, the
counterpart of *GRAPH-COMPARISONS*: this is the number that used to grow
quadratically with the size of a corpus.")

(defun concept-cache-key (concept)
  "A cheap bucket key for CONCEPT, coarse enough to be safe and selective enough
to be useful. Agrees with CONCEPTS-EQUAL (type + referent) in the sense that
equal concepts always share a key -- which is the direction that matters, since
sharing a key only means CONCEPTS-EQUAL gets asked."
  (let ((type (or (ignore-errors (label (concept-type concept))) "?")))
    (cond ((null (referent concept))
           (format nil "~a:" type))
          ;; a graph referent is not worth formatting; let CONCEPTS-EQUAL sort
          ;; these out among themselves
          ((ignore-errors (graph-referent concept))
           (format nil "~a:#g" type))
          (t
           (format nil "~a:~a" type
                   (or (ignore-errors (format-referent concept)) ""))))))

(defun invalidate-concept-index (context)
  "Forget CONTEXT's concept index; it is rebuilt on next use."
  (when context
    (setf (concept-index-table context) nil
          (concept-index-source context) :unbuilt))
  nil)

(defun concept-index (context)
  "CONTEXT's concept-key -> concepts index, rebuilt if (NODES CONTEXT) has been
replaced behind its back."
  (let ((nodes (nodes context)))
    (unless (and (concept-index-table context)
                 (eq (concept-index-source context) nodes))
      (let ((table (make-hash-table :test 'equal)))
        (dolist (c nodes)
          (push c (gethash (concept-cache-key c) table)))
        (setf (concept-index-table context) table
              (concept-index-source context) nodes)))
    (concept-index-table context)))

;;; cache all concepts for co-reference linking
(defmethod cache-concept ((concept concept)  &key (context *context*))
  (when context
    (setf (context concept) context)
    ;; PUSHNEW's semantics, with the scan replaced by a bucket lookup.
    (let* ((table (concept-index context))
           (key   (concept-cache-key concept))
           (bucket (gethash key table)))
      (unless (find-if (lambda (other)
                         (incf *concept-comparisons*)
                         (concepts-equal concept other))
                       bucket)
        (push concept (nodes context))
        (push concept (gethash key table))
        ;; PUSH changed the head; retake the marker so the index stays valid.
        (setf (concept-index-source context) (nodes context))))
    ;; If concept has a graph referent, add to map
    (let ((graph (graph-referent concept)))
      (when graph
        (map-add-graph-concept graph concept context))))
  concept)


(defmethod add-concept ((concept concept) &optional (context *context*))
  (cache-concept concept :context context))


(defmethod decache-concept ((concept concept))
  ;;(assert (typep concept 'concept))
  (let* ((context (or (context concept) *context*)))
    ;; If concept has a graph referent, remove from map and unregister from graph
    (let ((graph (graph-referent concept)))
      (when graph
        (map-remove-graph-concept graph concept context)
        (unregister-concept graph concept)))
    ;; Remove from nodes list
    (setf (nodes context) (remove concept (nodes context) :test #'concepts-equal))
    (invalidate-concept-index context)))


(defmethod retrieve-concepts-having-properties (properties &optional (context *context*))
  (remove-if-not (lambda (concept)
                   (let* ((referent (referent concept))
                          (props (properties referent)))
                     (properties-equal props properties)))
                 (nodes context)))

(defmethod retrieve-concepts-having-individual (individual &optional (context *context*))
  (remove-if-not (lambda (concept)
                   (let* ((referent (referent concept))
                          (object (when referent
                                    (content referent))))
                     (and (individual-p object)
                          (individuals-equal object individual))))
                 (nodes context)))

(defmethod retrieve-concepts-having-id (individual-id &optional (context *context*))
  (let ((individual (find-individual-with-id individual-id)))
    (retrieve-concepts-having-individual individual context)))



(defmethod retrieve-concept (concept-type (individual individual) &key (context *context*))
  (let ((candidates (retrieve-concepts-having-individual individual context))
        (ctype (get-concept-type concept-type)))
    ;; (remove-if-not (lambda (concept)
    ;;                  (types-equal (concept-type concept) ctype))
    ;;                candidates)
    (find ctype candidates :key #'concept-type)))

(defmethod retrieve-concept (concept-type (id number) &key (context *context*))
  (let ((candidates (retrieve-concepts-having-id id context))
        (ctype (get-concept-type concept-type)))
    ;; (remove-if-not (lambda (concept)
    ;;                  (types-equal (concept-type concept) ctype))
    ;;                candidates)
    (find ctype candidates :key #'concept-type)))

(defmethod retrieve-concept (concept-type (properties list) &key (context *context*))
  (let ((candidates (retrieve-concepts-having-properties properties context))
        (ctype (get-concept-type concept-type)))
    ;; (remove-if-not (lambda (concept)
    ;;                  (types-equal (concept-type concept) ctype))
    ;;                candidates)
    (find ctype candidates :key #'concept-type)))



(defmethod remove-concept ((concept concept) &optional (context *context*))
  (decache-concept concept))

;;; concept-type is added to the propertis list
(defmethod remove-concept ((properties list) &optional (context *context*))
  (let* ((ctype (cadr (assoc :type properties)))
         (concept (retrieve-concept ctype properties)))
    (when concept
      (remove-concept concept context))))


(defun graph-node-key (node)
  (string-trim " "
               (cond ((eq (type-of node) 'concept)
                      (format nil "concept-~a-~a" (node-type node)  (format-referent node)))
                     ((eq (type-of node) 'relation)
                      (format nil "relation-~a" (node-type node))))))

;;; ===========================================================================
;;; The duplicate-detection index
;;; ===========================================================================
;;;
;;; GRAPH-PRESENT-P used to compare the incoming graph against EVERY graph in the
;;; context, so ADD-CGRAPH cost O(n) graph comparisons and ingesting n graphs cost
;;; O(n^2) -- each comparison itself walking both graphs. Invisible at the two
;;; dozen graphs an experiment builds; not at ten thousand, and ADD-CGRAPH (the
;;; no-join path) is precisely the one a large knowledge base uses.
;;;
;;; So: hash the graph's STRUCTURE, keep an index from that key to the graphs
;;; carrying it, and run GRAPHS-EQUAL only against the graphs in the one bucket.
;;; Expected O(1) per add.
;;;
;;; THE KEY MUST AGREE WITH GRAPHS-EQUAL, which compares the multiset of
;;; concepts (type + referent) and the multiset of induced relations (type + arcs
;;; IN ORDER). So the key sorts both sets of sub-keys -- order within a graph
;;; must not matter, since GRAPHS-EQUAL does not care -- and a relation's key
;;; embeds its arcs' concept keys positionally, since GRAPHS-EQUAL does care
;;; about that.
;;;
;;; WHICH WAY IT CAN BE WRONG, and why that is the tolerable direction. A key
;;; COLLISION costs nothing: two different graphs landing in one bucket are still
;;; separated by GRAPHS-EQUAL, which decides. A key MISMATCH between two graphs
;;; that GRAPHS-EQUAL would call equal means the duplicate is not found and the
;;; graph is added -- the context ends up holding a redundant graph. That is the
;;; safe failure, and deliberately so: the bug this guard had for years was
;;; DROPPING distinct facts, and a store with a redundant assertion is recoverable
;;; where a store missing one is not.
;;;
;;; The mismatch case that actually exists: a graph MUTATED IN PLACE after it was
;;; indexed. The joins do that -- but they also replace (GRAPHS CONTEXT) wholesale
;;; (INCLUDE-CGRAPH, CONSOLIDATE-CGRAPHS, REMOVE-CGRAPH all SETF it), which
;;; changes the list's head cons and so invalidates the index. Anything that
;;; mutates an indexed graph WITHOUT touching that list should call
;;; INVALIDATE-GRAPH-INDEX.

(defvar *graph-comparisons* 0
  "How many GRAPHS-EQUAL comparisons GRAPH-PRESENT-P has made. Diagnostic: bind
it to 0 and ingest a corpus to see whether the index is doing its job -- this is
the number that used to grow quadratically.")

(defun graph-structure-key (graph)
  "A string that equal graphs share, in the sense GRAPHS-EQUAL means.

Concepts contribute type + referent; relations contribute type + their arcs'
concept keys IN ORDER. Both lists are sorted, because GRAPHS-EQUAL compares them
as multisets. O(n log n) in the size of the graph, computed once per add."
  (let* ((nodes     (collect-nodes (head graph)))
         (concepts  (remove-if-not #'concept-p nodes))
         (relations (induced-relations concepts)))
    (flet ((concept-key (c)
             (format nil "~a:~a"
                     (ignore-errors (label (concept-type c)))
                     (or (ignore-errors (format-referent c)) "")))
           (relation-key (r)
             (format nil "~a(~{~a~^,~})"
                     (ignore-errors (label (relation-type r)))
                     (mapcar (lambda (a)
                               (format nil "~a:~a"
                                       (ignore-errors (label (concept-type a)))
                                       (or (ignore-errors (format-referent a)) "")))
                             (arcs r)))))
      (format nil "~{~a~^|~}#~{~a~^|~}"
              (sort (mapcar #'concept-key concepts) #'string<)
              (sort (mapcar #'relation-key relations) #'string<)))))

(defun invalidate-graph-index (context)
  "Forget CONTEXT's duplicate index; it is rebuilt on next use. Call after
mutating a graph already in the context without replacing (GRAPHS CONTEXT)."
  (when context
    (setf (graph-index-table context) nil
          (graph-index-source context) :unbuilt
          (graphs-tail context) nil))
  nil)

(defun graph-index (context)
  "CONTEXT's structure-key -> graphs index, rebuilt if (GRAPHS CONTEXT) has been
replaced since it was built. Rebuilding is O(n) and happens after a join or a
removal, not on the ingest path."
  (let ((graphs (graphs context)))
    (unless (and (graph-index-table context)
                 (eq (graph-index-source context) graphs))
      (let ((table (make-hash-table :test 'equal)))
        (dolist (g graphs)
          (push g (gethash (graph-structure-key g) table)))
        (setf (graph-index-table context) table
              (graph-index-source context) graphs)))
    (graph-index-table context)))

(defun graphs-append (graph context)
  "Append GRAPH to the END of (GRAPHS CONTEXT) in constant time.

ADD-CGRAPH used to do this with (SETF (CDR (LAST (GRAPHS CONTEXT))) ...), and
LAST walks the list -- so even with the duplicate check indexed, ingesting n
graphs still cost O(n^2), just in pointer chases instead of graph comparisons.
Measured before this: 800 adds took 3.6x the time of 400.

Order is preserved rather than pushing to the front, because the store reads as
the record of what was asserted and callers print it.

The cached tail is trusted only when BOTH hold: GRAPH-INDEX-SOURCE still names
the list we last saw (so a join or removal that replaced it is caught), and the
cached cons really has nothing after it (so an append by any other route is
caught). Otherwise it is recomputed with LAST, which is correct at any cost."
  (let ((cell (list graph)))
    (if (null (graphs context))
        (setf (graphs context) cell)
        (let ((tail (graphs-tail context)))
          (unless (and tail
                       (eq (graph-index-source context) (graphs context))
                       (null (cdr tail)))
            (setf tail (last (graphs context))))
          (setf (cdr tail) cell)))
    (setf (graphs-tail context) cell)
    graph))

(defun index-graph (graph context)
  "Record GRAPH in CONTEXT's index under its structure key. Called by ADD-CGRAPH
after the graph is in (GRAPHS CONTEXT), so the index and the list stay in step."
  (let ((table (graph-index context)))
    (push graph (gethash (graph-structure-key graph) table))
    ;; ADD-CGRAPH appends with (SETF (CDR (LAST ...))), which leaves the head cons
    ;; alone, but the empty-list case SETFs (GRAPHS CONTEXT) outright -- so retake
    ;; the marker rather than assume it still holds.
    (setf (graph-index-source context) (graphs context))
    graph))

;;; GRAPHS-EQUAL, not a bag of node keys. This compared the sorted multiset of
;;; GRAPH-NODE-KEYs, and a node key carries a node's type and referent and
;;; NOTHING ABOUT ITS ARCS -- so two graphs over the same concepts were "present"
;;; in each other however they were wired:
;;;
;;;   [GIVE]- (agnt)→[PERSON: Sue] (rcpt)→[PERSON: Bob] (obj)→[BOOK]
;;;   [GIVE]- (agnt)→[PERSON: Bob] (rcpt)→[PERSON: Sue] (obj)→[BOOK]
;;;
;;; Sue gives Bob a book, and Bob gives Sue a book. ADD-CGRAPH is the only
;;; caller that acts on the answer, and it SKIPS a graph it believes present --
;;; so the second fact was not merged or reordered, it was silently dropped, and
;;; the context held a claim nobody made about the one that survived.
;;;
;;; GRAPHS-EQUAL had exactly this bug and was fixed for exactly this reason (the
;;; superseded version is still at graph.lisp:122, and the replacement's
;;; docstring names the failure and says its callers are "chiefly CONTEXT's
;;; bookkeeping"). REMOVE-CGRAPH was already using the fixed predicate; this was
;;; the half of the repair that never landed. It compares concepts AND the
;;; relations induced between them, with each relation's arcs IN ORDER, which is
;;; what carries direction.
;;;
;;; It is not an isomorphism test -- two graphs whose concepts and relations
;;; agree one for one can still differ in which of two identical-looking
;;; concepts a relation attaches to. That needs a search, and PROJECT is the
;;; function that searches; mutual projection is the CG notion of equivalence.
;;; This answers the narrower structural question ADD-CGRAPH actually asks.
;;;
;;; The old code also SORTED (nodes graph) in place -- destructively reordering
;;; the node list of the graph being tested AND of every graph in the context,
;;; from inside a predicate. Nothing depends on that order, so nothing broke
;;; visibly; it is gone with the rest.

(defmethod graph-present-p ((graph graph) &optional (context *context*))
  (let ((bucket (gethash (graph-structure-key graph) (graph-index context))))
    (and (find-if (lambda (other)
                    (incf *graph-comparisons*)
                    (graphs-equal graph other))
                  bucket)
         t)))

;;; These two convenience methods called MAKE-GRAPH, which does not exist and
;;; never did -- the constructor is MAKE-CGRAPH. Both were therefore dead: any
;;; call raised an undefined-function error. Nothing noticed because ADD-CGRAPH,
;;; the only caller that reaches GRAPH-PRESENT-P, always has a GRAPH in hand.
;;;
;;; MAKE-CGRAPH is not a drop-in, either: it ADDS what it builds to a context.
;;; Called with the default it would add the graph to the very context being
;;; searched and then find it -- a predicate that makes its own answer true. So
;;; each builds in a THROWAWAY context and asks about the real one.

(defmethod graph-present-p ((concept concept) &optional (context *context*))
  (let ((graph (make-cgraph concept (make-context))))
    (when graph
      (graph-present-p graph context))))

(defmethod graph-present-p ((graph-string string) &optional (context *context*))
  (let ((graph (make-cgraph graph-string (make-context))))
    (when graph
      (graph-present-p graph context))))



(defmethod remove-cgraph ((graph graph) &optional (context *context*))
  (when (graphs context)
    (when (find graph (graphs context) :test #'graphs-equal)
      (setf (graphs context) (remove graph (graphs context) :test #'graphs-equal))
      ;; REMOVE returns a fresh list, so the index's source marker no longer
      ;; matches and it would rebuild anyway; say so rather than rely on that.
      (invalidate-graph-index context))))


(defmethod remove-cgraph ((graph string ) &optional (context *context*))
  (remove-cgraph (make-cgraph graph context)))



;;; ===========================================================================
;;; Two ways to put a graph in a context, and the difference is a POLICY
;;; ===========================================================================
;;;
;;;   ADD-CGRAPH      (here)  append the graph. Nothing is joined. The context
;;;                           ends up holding exactly what was asserted, one
;;;                           graph per assertion.
;;;   INCLUDE-CGRAPH  (operations/graph-combination.lisp) append the graph AND
;;;                           combine it with every graph it shares a joinable
;;;                           concept with, transitively.
;;;
;;; ADD-CGRAPH is the primitive and the default: MAKE-CGRAPH calls it, so every
;;; graph built from a node, a node list or a string is already in its context
;;; this way. INCLUDE-CGRAPH is opt-in -- you ask for the join.
;;;
;;; WHICH ONE YOU WANT is a question about the store, not about graphs:
;;;
;;;   ADD-CGRAPH preserves the record. It cannot invent anything, because it
;;;   never combines two assertions, and it is therefore what you want when the
;;;   context is a log of what was said -- extraction from text, a corpus, a
;;;   transcript. Retrieval does not suffer for it: PROJECT and QUERY search
;;;   every graph in the context, so an unjoined store answers the same
;;;   questions. (Measured: `cg-from-parse/notes/kb-experiment-findings.md' §4
;;;   queries an unjoined store of two dozen extracted graphs and gets the right
;;;   distinct bindings; against the JOINED store the same questions return the
;;;   same bindings buried in many more paths.)
;;;
;;;   INCLUDE-CGRAPH draws inferences on the way in. Joining two graphs on a
;;;   shared concept asserts they are about the same thing, which is exactly
;;;   what Sowa's formation rules license and exactly what you want when the
;;;   graphs really do describe one situation being built up. The cost is that
;;;   the inference is made ONCE, AT INGEST, and cannot be taken back: the join
;;;   is destructive (see REMOVE-CGRAPH and the note on combining), so the
;;;   unjoined originals are gone.
;;;
;;; The failure mode to know about: joining generic concepts. Two referent-less
;;; [EAT] concepts are automatically correspondent, so a store built with
;;; INCLUDE-CGRAPH out of graphs whose events carry no individual referent
;;; collapses into one graph asserting things nobody said -- one eating with
;;; eight eaters. That is not a bug in the join; the graphs never said the
;;; eatings were different. It is an argument for individuating events before
;;; joining, which is what cg-from-parse's `system/identity.lisp' now does.
;;;
;;; So: ADD-CGRAPH to accumulate, INCLUDE-CGRAPH to accumulate AND conclude,
;;; and CONSOLIDATE-CGRAPHS to conclude later over a store built the first way
;;; -- which is the option that keeps both.

;;; intentionally defined for only graph objects
(defmethod add-cgraph ((graph graph) &optional (context *context*))
  "Append GRAPH to CONTEXT unless an equal graph is already there. No joining:
see the policy note above, and INCLUDE-CGRAPH for the other half of the pair.

`Already there' is GRAPH-PRESENT-P, i.e. GRAPHS-EQUAL -- the same concepts
joined the same way. It used to be a bag of node keys, which ignored the arcs
and so dropped one of `Sue gives Bob a book' / `Bob gives Sue a book'; skipping
is how this method acts on the answer, so a false positive here loses an
assertion outright. See notes/known-issues.md."
  (assert (graph-p graph))
  (unless (graph-present-p graph context)
    (graphs-append graph context)
    (index-graph graph context)))

(defmethod add-cgraph ((thing t) &optional context)
  nil)


(defmethod add-cgraphs ((graphs list) &optional (context *context*))
  (assert (every #'graph-p graphs))
  (mapcar (lambda (g) (add-cgraph g context)) graphs)
  t)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  Graph Referent Tracking  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Methods to track and query concepts that use graphs as referents

;; Find all concepts with graph referents in this context
(defmethod concepts-with-graph-referents (&optional (context *context*))
  "Return all concepts in the context that have graph referents"
  (remove-if-not (lambda (concept)
                   (graph-referent-p concept))
                 (nodes context)))

;; Find concepts that use a specific graph as their referent
(defmethod find-concepts-using-graph ((graph graph) &optional (context *context*))
  "Find all concepts in the context that use this specific graph as their referent (mapped)"
  ;; Use the map for O(1) lookup instead of O(n) linear search
  (map-lookup-concepts graph context))

;; Count concepts with graph referents
(defmethod count-concepts-with-graph-referents (&optional (context *context*))
  "Count how many concepts in the context have graph referents"
  (length (concepts-with-graph-referents context)))

;; Get all unique graphs used as referents in this context
(defmethod all-graph-referents (&optional (context *context*))
  "Return a list of all unique graph objects used as referents in this context (mapped)"
  ;; Use the map for O(1) lookup instead of building list from concepts
  (map-all-graphs context))

;; Report on graph referent usage
(defmethod graph-referent-report (&optional (context *context*) (stream *standard-output*))
  "Print a report of graph referent usage in the context"
  (let ((concepts (concepts-with-graph-referents context))
        (unique-graphs (all-graph-referents context)))
    (format stream "~%Graph Referent Report for Context:")
    (format stream "~%  Total concepts with graph referents: ~d" (length concepts))
    (format stream "~%  Unique graphs used as referents: ~d" (length unique-graphs))
    (when concepts
      (format stream "~%~%Concepts with graph referents:")
      (dolist (concept concepts)
        (format stream "~%  ~a" (format-concept concept))
        (let ((graph (graph-referent concept)))
          (when graph
            (format stream "~%    Graph: ~d concepts, ~d relations"
                    (concept-count graph) (relation-count graph))))))
    (terpri stream)
    t))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  Graph Referent Map Maintenance  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; GRAPH REFERENT MAP
;;;
;;; The graph-referent-map is an association list that maps graph objects
;;; to lists of concepts that use them as referents. This provides O(1) lookup
;;; for common queries instead of O(n) linear searches.
;;;
;;; Structure: ((graph1 . (concept1 concept2)) (graph2 . (concept3)) ...)
;;;
;;; The map is maintained automatically by cache-concept and decache-concept.

;; Add a graph-concept mapping to the map
(defmethod map-add-graph-concept ((graph graph) (concept concept) &optional (context *context*))
  "Add a concept to the map for this graph"
  (let* ((map (graph-referent-map context))
         (entry (assoc graph map :test #'graphs-equal)))
    (if entry
        ;; Graph already in map, add concept to its list
        (pushnew concept (cdr entry) :test #'eq)
        ;; New graph, create entry
        (push (cons graph (list concept)) (graph-referent-map context)))))

;; Remove a graph-concept mapping from the map
(defmethod map-remove-graph-concept ((graph graph) (concept concept) &optional (context *context*))
  "Remove a concept from the map for this graph"
  (let* ((map (graph-referent-map context))
         (entry (assoc graph map :test #'graphs-equal)))
    (when entry
      ;; Remove concept from the list
      (setf (cdr entry) (remove concept (cdr entry) :test #'eq))
      ;; If no more concepts use this graph, remove the entry
      (when (null (cdr entry))
        (setf (graph-referent-map context)
              (remove graph (graph-referent-map context)
                      :key #'car :test #'graphs-equal))))))

;; Lookup concepts by graph using the map
(defmethod map-lookup-concepts ((graph graph) &optional (context *context*))
  "Efficiently lookup which concepts use this graph (O(1) with map)"
  (let* ((map (graph-referent-map context))
         (entry (assoc graph map :test #'graphs-equal)))
    (when entry
      (cdr entry))))

;; Get all mapped graphs
(defmethod map-all-graphs (&optional (context *context*))
  "Return all graphs in the map"
  (mapcar #'car (graph-referent-map context)))

;; Get count of mapped graphs
(defmethod map-graph-count (&optional (context *context*))
  "Return the number of unique graphs in the map"
  (length (graph-referent-map context)))

;; Clear the entire graph referent map
(defmethod clear-graph-referent-map (&optional (context *context*))
  "Clear the graph referent map"
  (setf (graph-referent-map context) (list)))


(defmethod clear-concept-cache (&optional (context *context*))
  (assert (typep context 'context))
  (setf (nodes context) (list))
  (invalidate-concept-index context)
  ;; Also clear the graph referent map
  (clear-graph-referent-map context))


(defun cached-concepts-report (&optional (context *context*) (stream *standard-output*))
  (when context
    (let ((concept-list (nodes context)))
      (when concept-list
        (format stream "~&Cached Concepts Report:~%")
        (format stream "~&Total concepts: ~d~%" (length concept-list))
        (dolist (concept concept-list)
          (format stream "~&  ~a~%" (format-concept concept))))
      t)))
