
(referent-string (referent referent))

(cache-concept concept &optional (context *context*))
(retrieve-concept concept-type (individual individual) &key (context *context*))
(retrieve-concept concept-type id (properties list) &key (context *context*))

(concept-cache-key (concept concept))
(concept-cache-key (concept-info list))

(clear-concept-cache (context context))
(cached-concepts-report &optional (stream *standard-output*))



(get-concept type-label (referent string) :id id)
(get-concept (concept-type concept-type) (referent string) :id id)

(find-node (node-type symbol) (referent string) (start-node graph-node))

;; variable-cache
(set-variable (&optional new-name)
;; concept-variable
;; variable-node
;; variable-node

(variables-report)


(render-features (features string) &optional variable)
(render-features (referent referent) &optional variable)

;;(conformity (node concept-type) &optional referent)


(format-referent (referent referent) &key variable)
(format-concept (node concept) &key &allow-other-keys)


;; nodes-equal
;; referents-equal
(graphs-equal (g1 graph-node) (g2 graph-node))
;; segments-equal

------------------------------------------------------------------------------
(progn
  (clear-concept-cache *context*)
  (initialize-cgraph))

;; (progn
;;   (setq test-id 40)
;;   (ptestx test-id)
;;   (setq root *)
;;   (setq node (find-node 'food "" root))
;;   (concept-variable node)
;;   (format-concept node)
;;   )

(defvar *head)
(defvar *node)

#+nil
(progn
  (clear-concept-cache *context*)
  (initialize-cgraph)
  (setq test-id 40)
  (setq graph-name (intern (format nil "GRAPH-STRING~3,'0d" test-id)))
  (setq graph-string (symbol-value graph-name))
  (setq head (parse-cgraph graph-string))
  (setq *head head)
  (setq node (find-node 'food "" head))
  (setq *node node)
  (setq var (concept-variable node))

  (setq formated-graph (format-cgraph head))
  )


(ptestx 110)

(progn
  (clear-concept-cache *context*)
  (initialize-cgraph)
  (setq test-id 110)
  (setq graph-name (intern (format nil "GRAPH-STRING~3,'0d" test-id)))
  (setq graph-string (symbol-value graph-name))
  (format t "~2&graph-string: ~s~2%" graph-string)
  (setq head (parse-cgraph graph-string))
  (setq formated-graph (format-cgraph head))
  (setq node (find-node 'food "" head))
  (setq *node node)
  (setq var (concept-variable node))
  (setq formated-graph (format-cgraph head))
  )
