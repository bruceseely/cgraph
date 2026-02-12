

(defun class-hierarchy-to-json (root-class)
  "Generate JSON data for JavaScript visualization"
  (let ((nodes '())
        (edges '())
        (id-counter 0))
    (labels ((process-class (class parent-id level)
               (let ((id (incf id-counter))
                     (name (class-name class)))
                 (push `((:id . ,id)
                        (:label . ,(string name))
                        (:level . ,level))
                       nodes)
                 (when parent-id
                   (push `((:from . ,parent-id)
                          (:to . ,id))
                         edges))
                 (dolist (subclass (sb-mop:class-direct-subclasses class))
                   (process-class subclass id (1+ level))))))
      (process-class (find-class root-class) nil 0))
    (json:encode-json-to-string
      `((:nodes . ,(reverse nodes))
        (:edges . ,(reverse edges))))))






(defun concept-type-hierarchy-to-json (root-class)
  "Generate JSON data for JavaScript visualization"
  (let ((nodes '())
        (edges '())
        (id-counter 0))
    (labels ((process-class (type-node parent-id level)
               (let ((id (incf id-counter))
                     (name (label type-node)))
                 (push `((:id . ,id)
                        (:label . ,(string name))
                        (:level . ,level))
                       nodes)
                 (when parent-id
                   (push `((:from . ,parent-id)
                          (:to . ,id))
                         edges))
                 (dolist (subtype (subtypes type-node))
                   (process-class subtype id (1+ level))))))
      (process-class *concept-type-top* nil 0))
    (json:encode-json-to-string
      `((:nodes . ,(reverse nodes))
        (:edges . ,(reverse edges))))))
