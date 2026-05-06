;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)

;;; Tests for graph referents
;;; This tests the new graph wrapper class and property delegation

(defvar *test-output* nil)

(defun setup-graph-referent-test-types ()
  (load-test-types)
  )

(defun test-graph-referent-creation (&optional verbose)
  "Test creating graph referents from parsed graphs"
  (format *test-output* "~2%Testing graph referent creation...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)

  (let* ((head-node (car (parse-cgraph "[Cat: Puff]->(On)->[Mat]")))
         (head-node-ref (make-referent head-node))
         (result (and (not (null head-node-ref))
                      (referent-p head-node-ref)
                      (graph-p head-node-ref))))
    (format *test-output* "~&  Graph referent creation: ~:[FAIL~;PASS~]" result)
    result))


(defun test-graph-structure-access (&optional verbose)
  "Test accessing graph structure through referents"
  (format *test-output* "~2%Testing graph structure access...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)

  (let* ((head-node (car (parse-cgraph "[Cat: Fido]->(On)->[Mat]")))
         (head-node-ref (make-referent head-node))
         (concepts (graph-concepts head-node-ref))
         (relations (graph-relations head-node-ref))
         (result (and (= (length concepts) 2)     ; Cat and Mat
                      (= (length relations) 1)))) ; On
    (format *test-output* "~&  Graph structure access: ~:[FAIL~;PASS~]" result)
    (when result
      (format *test-output* "~&    Found ~d concepts and ~d relations"
              (length concepts) (length relations)))
    result))


(defun test-graph-equality (&optional verbose)
  "Test that graphs are compared correctly"
  (format *test-output* "~2%Testing graph equality...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)

  (let* ((graph1 (make-cgraph "[SIT]- (agnt)->[DOG: Fido] (loc)->[MAT]"))
         (graph2 (make-cgraph "[SIT]- (agnt)->[DOG: Fido] (loc)->[MAT]"))
         (graph3 (make-cgraph "[SIT]- (agnt)->[DOG: Spot] (loc)->[MAT]"))
         (result1 (graphs-equal graph1 graph2))
         (result2 (not (graphs-equal graph1 graph3)))
         (result (and result1 result2)))
    (format *test-output* "~&  Graph equality: ~:[FAIL~;PASS~]" result)
    result))


(defun test-concept-with-graph-referent (&optional verbose)
  "Test creating a concept with a graph as its referent"
  (format *test-output* "~2%Testing concept with graph referent...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)

  (let* ((inner-graph (car (parse-cgraph "[DOG: Fido]->(on)->[MAT]")))
         (graph-referent (make-referent inner-graph))
         (outer-concept (make-instance 'concept
                                       :concept-type (get-concept-type 'Situation)
                                       :referent graph-referent))
         (result (and (not (null outer-concept))
                      (graph-referent-p outer-concept)
                      (not (null (referent-concepts outer-concept))))))
    (format *test-output* "~&  Concept with graph referent: ~:[FAIL~;PASS~]" result)
    (when result
      (format *test-output* "~&    Outer concept: [~a: <graph>]"
              (label (concept-type outer-concept)))
      (format *test-output* "~&    Inner graph has ~d concepts"
              (length (referent-concepts outer-concept))))
    result))


(defun test-property-delegation (&optional verbose)
  "Test that properties are delegated from head concepts"
  (format *test-output* "~2%Testing property delegation...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)

  (let* ((graph-obj (make-cgraph "[Cat: Fido]->(On)->[Mat]."))
         (head-node (graph-head graph-obj))
         (graph-props (properties graph-obj))
         (head-props (when head-node (properties head-node)))
         (result (equalp graph-props head-props)))
    (format *test-output* "~&  Property delegation: ~:[FAIL~;PASS~]" result)
    (when result
      (format *test-output* "~&    Properties delegated from head concept"))
    result))


(defun test-concept-graph-referent-conformity (&optional verbose)
  "Test conformity of a concept with a graph referent"
  (format *test-output* "~2%Testing concept with graph referent conformity...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)

  (let* ((inner-graph (car (parse-cgraph "[SIT]- (agnt)->[CAT: Fido] (loc)->[MAT]")))
         (inner-graph-ref (make-referent inner-graph))
         (situation-type (get-concept-type 'situation))
         (outer-concept (make-instance 'concept
                                       :concept-type situation-type
                                       :referent inner-graph-ref))
         ;; The concept should conform to Situation
         ;; The referent (graph) should conform if its head conforms
         (result (conforms outer-concept situation-type)))

    (format *test-output* "~&  Concept with graph referent conformity: ~:[FAIL~;PASS~]" result)
    (when result
      (format *test-output* "~&    Concept [Situation: <graph>] conforms to Situation type"))
    result))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



(defun test-bidirectional-linking-basic (&optional verbose)
  "Test basic bidirectional linking between graph and concept"
  (format *test-output* "~2%Testing bidirectional linking...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)

  (let* ((graph-obj (make-cgraph "[Cat: Fido]->(On)->[Mat]."))
         (graph-obj-ref (make-referent graph-obj))
         (outer-concept (make-instance 'concept
                                       :concept-type (get-concept-type 'Situation)
                                       :referent graph-obj-ref))
         ;; Check that concept is registered with graph
         (registered (concept-registered-p graph-obj outer-concept))
         ;; Check that graph knows about the concept
         (concepts-list (referencing-concepts graph-obj))
         (result (and registered
                      (= (length concepts-list) 1)
                      (eq (first concepts-list) outer-concept))))
    (format *test-output* "~&  Bidirectional linking: ~:[FAIL~;PASS~]" result)
    (when result
      (format *test-output* "~&    Graph registered concept correctly"))
    result))


(defun test-multiple-concepts-same-graph (&optional verbose)
  "Test that multiple concepts can reference the same graph"
  (format *test-output* "~2%Testing multiple concepts using same graph...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)

  (let* ((graph-obj (make-cgraph "[Cat: Fido]->(On)->[Mat]."))
         (graph-obj-ref1 (make-referent graph-obj))
         (graph-obj-ref2 (make-referent graph-obj))
         (concept1 (make-instance 'concept
                                  :concept-type (get-concept-type 'Situation)
                                  :referent graph-obj-ref1))
         (concept2 (make-instance 'concept
                                  :concept-type (get-concept-type 'Situation)
                                  :referent graph-obj-ref2))
         ;; Both concepts should be registered
         (ref-count (reference-count graph-obj))
         (result (= ref-count 2)))
    (format *test-output* "~&  Multiple concepts same graph: ~:[FAIL~;PASS~]" result)
    (when result
      (format *test-output* "~&    Graph tracks ~d referencing concepts" ref-count))
    result))


(defun test-context-graph-referent-tracking (&optional verbose)
  "Test context-level tracking of graph referents"
  (format *test-output* "~2%Testing context graph referent tracking...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)
  (let* ((context (make-context))
         (*context* context))

    ;; Create several concepts, some with graph referents
    (let* ((graph1 (car (parse-cgraph "[SIT]- (agnt)->[DOG: Fido] (loc)->[MAT]")))
           (graph1-ref (make-referent graph1))
           (concept1 (make-instance 'concept
                                    :concept-type (get-concept-type 'Situation)
                                    :referent graph1-ref
                                    :context context))
           (graph2 (car (parse-cgraph "[SIT]- (agnt)->[DOG: Spot] (loc)->[MAT]")))
           (graph2-ref (make-referent graph2))
           (concept2 (make-instance 'concept
                                    :concept-type (get-concept-type 'Event)
                                    :referent graph2-ref
                                    :context context))
           ;; Regular concept without graph referent
           (concept3 (make-instance 'concept
                                    :concept-type (get-concept-type 'Think)
                                    :context context)))

      ;; Cache all concepts
      (cache-concept concept1 :context context)
      (cache-concept concept2 :context context)
      (cache-concept concept3 :context context)

      ;; Test context queries
      (let* ((graph-concepts (concepts-with-graph-referents context))
             (graph-count (count-concepts-with-graph-referents context))
             (all-graphs (all-graph-referents context))
             (result (and (= graph-count 2)
                          (= (length all-graphs) 2)
                          (member concept1 graph-concepts)
                          (member concept2 graph-concepts)
                          (not (member concept3 graph-concepts)))))

        (format *test-output* "~&  Context graph tracking: ~:[FAIL~;PASS~]" result)
        (when result
          (format *test-output* "~&    Found ~d concepts with graph referents" graph-count)
          (format *test-output* "~&    Found ~d unique graphs" (length all-graphs)))
        result))))


(defun test-find-concepts-using-graph (&optional verbose)
  "Test finding which concepts use a specific graph"
  (format *test-output* "~2%Testing finding concepts by graph...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)
  (let* ((context (make-context))
         (*context* context))

    (let* ((graph-obj (make-cgraph "[SIT]- (agnt)->[CAT: Fido] (loc)->[MAT]."))
           (graph-obj-ref (make-referent graph-obj))
           (concept1 (make-instance 'concept
                                    :concept-type (get-concept-type 'Situation)
                                    :referent graph-obj-ref
                                    :context context))
           ;; Different graph
           (other-graph (make-cgraph "[Cat: Fido]->(On)->[Mat]."))
           (other-graph-ref (make-referent other-graph))
           (concept2 (make-instance 'concept
                                    :concept-type (get-concept-type 'Event)
                                    :referent other-graph-ref
                                    :context context)))

      (cache-concept concept1 :context context)
      (cache-concept concept2 :context context)

      ;; Find concepts using the first graph
      (let* ((found-concepts (find-concepts-using-graph graph-obj context))
             (result (and (= (length found-concepts) 1)
                          (eq (first found-concepts) concept1))))
        (format *test-output* "~&  Find concepts by graph: ~:[FAIL~;PASS~]" result)
        (when result
          (format *test-output* "~&    Correctly found concept using specific graph"))
        result))))


(defun test-register-unregister-concept (&optional verbose)
  "Test manual register/unregister of concepts"
  (format *test-output* "~2%Testing register/unregister concept...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)

  (let* ((graph-obj (make-cgraph "[Cat: Fido]->(On)->[Mat]."))
         (concept (make-instance 'concept
                                 :concept-type (get-concept-type 'Situation))))

    ;; Register manually
    (register-concept graph-obj concept)
    (let ((registered (concept-registered-p graph-obj concept)))
      ;; Unregister
      (unregister-concept graph-obj concept)
      (let* ((unregistered (not (concept-registered-p graph-obj concept)))
             (result (and registered unregistered)))
        (format *test-output* "~&  Register/unregister: ~:[FAIL~;PASS~]" result)
        (when result
          (format *test-output* "~&    Concept registration lifecycle works"))
        result))))


(defun test-map-maintenance (&optional verbose)
  "Test that the map is maintained correctly"
  (format *test-output* "~2%Testing map maintenance...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)
  (let* ((context (make-context))
         (*context* context))

    (let* ((graph-obj (make-cgraph "[Cat: Fido]->(On)->[Mat]."))
           (graph-obj-ref (make-referent graph-obj))
           (concept (make-instance 'concept
                                   :concept-type (get-concept-type 'Situation)
                                   :referent graph-obj-ref
                                   :context context)))

      ;; Cache the concept
      (cache-concept concept :context context)

      ;; Check that map was updated
      (let* ((maped-concepts (map-lookup-concepts graph-obj context))
             (graph-count (map-graph-count context))
             (result (and (= graph-count 1)
                          (= (length maped-concepts) 1)
                          (eq (first maped-concepts) concept))))
        (format *test-output* "~&  Map maintenance: ~:[FAIL~;PASS~]" result)
        (when result
          (format *test-output* "~&    Map correctly tracks ~d graph(s)" graph-count))
        result))))


(defun test-map-removal (&optional verbose)
  "Test that concepts are removed from map when decached"
  (format *test-output* "~2%Testing map removal...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)
  (let* ((context (make-context))
         (*context* context))

    (let* ((graph-obj (make-cgraph "[Cat: Fido]->(On)->[Mat]."))
           (graph-obj-ref (make-referent graph-obj))
           (concept (make-instance 'concept
                                   :concept-type (get-concept-type 'Situation)
                                   :referent graph-obj-ref
                                   :context context)))

      ;; Cache then decache
      (cache-concept concept :context context)
      (let ((before-count (map-graph-count context)))
        (decache-concept concept)
        (let* ((after-count (map-graph-count context))
               (maped-concepts (map-lookup-concepts graph-obj context))
               (result (and (= before-count 1)
                            (= after-count 0)
                            (null maped-concepts))))
          (format *test-output* "~&  Map removal: ~:[FAIL~;PASS~]" result)
          (when result
            (format *test-output* "~&    Map correctly cleared"))
          result)))))


(defun test-map-multiple-graphs (&optional verbose)
  "Test map with multiple different graphs"
  (format *test-output* "~2%Testing map with multiple graphs...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)
  (let* ((context (make-context))
         (*context* context))

    (let* ((graph1 (make-cgraph "[SIT]- (agnt)->[DOG: Fido] (loc)->[MAT]."))
           (ref1 (make-referent graph1))
           (concept1 (make-instance 'concept
                                    :concept-type (get-concept-type 'Situation)
                                    :referent ref1
                                    :context context))
           (graph2 (make-cgraph "[SIT]- (agnt)->[DOG: Spoy] (loc)->[MAT]."))
           (ref2 (make-referent graph2))
           (concept2 (make-instance 'concept
                                    :concept-type (get-concept-type 'Event)
                                    :referent ref2
                                    :context context)))

      (cache-concept concept1 :context context)
      (cache-concept concept2 :context context)

      (let* ((graph-count (map-graph-count context))
             (all-graphs (map-all-graphs context))
             (concepts1 (map-lookup-concepts graph1 context))
             (concepts2 (map-lookup-concepts graph2 context))
             (result (and (= graph-count 2)
                          (= (length all-graphs) 2)
                          (= (length concepts1) 1)
                          (= (length concepts2) 1))))
        (format *test-output* "~&  Map multiple graphs: ~:[FAIL~;PASS~]" result)
        (when result
          (format *test-output* "~&    Map tracks ~d unique graphs" graph-count))
        result))))


(defun test-maped-query-performance (&optional verbose)
  "Test that maped queries work correctly"
  (format *test-output* "~2%Testing maped queries...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)
  (let* ((context (make-context))
         (*context* context))

    (let* ((graph-obj (make-cgraph "[Cat: Fido]->(On)->[Mat].s"))
           (graph-obj-ref (make-referent graph-obj))
           (concept (make-instance 'concept
                                   :concept-type (get-concept-type 'Situation)
                                   :referent graph-obj-ref
                                   :context context)))

      (cache-concept concept :context context)

      ;; Test maped queries
      (let* ((found-concepts (find-concepts-using-graph graph-obj context))
             (all-graphs (all-graph-referents context))
             (result (and (= (length found-concepts) 1)
                          (eq (first found-concepts) concept)
                          (= (length all-graphs) 1)
                          (graphs-equal (first all-graphs) graph-obj))))
        (format *test-output* "~&  Maped queries: ~:[FAIL~;PASS~]" result)
        (when result
          (format *test-output* "~&    Queries use map correctly"))
        result))))


(defun test-map-clear (&optional verbose)
  "Test clearing the graph referent map"
  (format *test-output* "~2%Testing map clearing...")
  (initialize-cgraph)
  (setup-graph-referent-test-types)
  (let* ((context (make-context))
         (*context* context))

    (let* ((graph (make-cgraph "[Cat: Fido]->(On)->[Mat]"))
           (graph-ref (make-referent graph))
           (concept (make-instance 'concept
                                   :concept-type (get-concept-type 'Situation)
                                   :referent graph-ref
                                   :context context)))

      (cache-concept concept :context context)
      (let ((before-count (map-graph-count context)))
        (clear-graph-referent-map context)
        (let* ((after-count (map-graph-count context))
               (result (and (= before-count 1)
                            (= after-count 0))))
          (format *test-output* "~&  Map clearing: ~:[FAIL~;PASS~]" result)
          (when result
            (format *test-output* "~&    Map cleared successfully"))
          result)))))


(defun graph-referent-test (&optional verbose)
  "Run all graph referent tests"
  (with-test-types
  (setf *test-output* (when verbose *standard-output*))
  (when verbose
    (format *test-output* "~%~%========================================"))
  (format *test-output* "~%GRAPH REFERENT TEST")
  (when verbose
    (format *test-output* "~%========================================"))

  (let ((results (list
                  (test-graph-referent-creation verbose)
                  (test-graph-structure-access verbose)
                  (test-graph-equality verbose)
                  (test-concept-with-graph-referent verbose)
                  (test-property-delegation verbose)
                  (test-concept-graph-referent-conformity verbose)
                  (test-bidirectional-linking-basic verbose)
                  (test-multiple-concepts-same-graph verbose)
                  (test-context-graph-referent-tracking verbose)
                  (test-find-concepts-using-graph verbose)
                  (test-register-unregister-concept verbose)
                  (test-map-maintenance verbose)
                  (test-map-removal verbose)
                  (test-map-multiple-graphs verbose)
                  (test-maped-query-performance verbose)
                  (test-map-clear verbose))))

    (format *test-output* "~%~%Summary: ~d/~d tests passed"
            (count t results) (length results))
    (format *test-output* "~%Overall: ~:[FAIL~;PASS~]~%" (every #'identity results))
    (every #'identity results))))
