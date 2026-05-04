
(in-package :cgraph)

;;; This code depends on graphviz
;;; requires installation of graphviz-dot-mode in Emacs
;;; see https://graphviz.gitlab.io
;;;
;;; https://ppareit.github.io/graphviz-dot-mode
;;; https://raw.github.com/ppareit/graphviz-dot-mode/master/graphviz-dot-mode.el
;;; https://github.com/ppareit/graphviz-dot-mode

(defparameter *slot-alignment* "center")
(defparameter *slot-name-prefix* ":")

(defun type-traversal (type-name
                       visited
                       &key
                         (parents t)
                         (children t)
                         (std-and-t nil))

  (let ((ctype (get-concept-type type-name)))
    (unless (gethash ctype visited)
      (setf (gethash ctype visited) t)
      (when children
        (dolist (i (direct-subtypes ctype))
          (type-traversal i visited :parents nil :std-and-t std-and-t)))
      (when parents
        (dolist (i (direct-supertypes ctype))
          (unless (and (not std-and-t)
                       (or (eql i 'T)
                           (eql i 'STANDARD-OBJECT)))
            (type-traversal i visited :children nil :std-and-t std-and-t))))))
  visited)


(defun make-type-record (type-name      ; symbol
                         &key
                           (color "#FFFF99"))
  (let* ((rec (format nil
                      "~A    <TR><TD BGCOLOR=\"~A\"><FONT FACE=\"Arial Bold\">~A</FONT></TD></TR>~%"
                      "" color type-name)))
    #+nil

    (setf rec
          (concatenate 'string rec
                       (format nil "    <TR><TD align=\"~a\"><FONT FACE=\"Arial\">~a~A</FONT></TD></TR>~%"
			       *slot-alignment* *slot-name-prefix* "")))
    rec))


(defun generate-concept-type-digraph (&key (type-name-list (list 't))
                                           (stream *standard-output*)
                                           (parents t)
                                           (children t)
                                           (landscape nil)
                                           (hide-bottom t)
                                           (expand-sub nil)    ; list of type symbols/objects to expand downward
                                           (expand-super nil)) ; list of type symbols/objects to expand upward
  (let ((types-visited (make-hash-table))
        (type-id-table (make-hash-table))
        (name (princ-to-string (car type-name-list)))
        (index 1000))
    ;; Each type's path set is computed with a fresh table to prevent the
    ;; already-visited gate from suppressing siblings/descendants of earlier types.
    (dolist (type-name type-name-list)
      (let ((ps (make-hash-table)))
        (type-traversal type-name ps :parents parents :children children)
        (maphash (lambda (k v) (setf (gethash k types-visited) v)) ps)))

    ;; Expand subtypes: traverse down from each direct child of the expanded node.
    ;; We iterate children rather than the node itself to bypass the already-visited gate.
    (dolist (type-name expand-sub)
      (let ((ctype (get-concept-type type-name)))
        (when ctype
          (dolist (child (direct-subtypes ctype))
            (type-traversal child types-visited :parents nil :children t)))))

    ;; Expand supertypes: traverse up from each direct parent of the expanded node.
    (dolist (type-name expand-super)
      (let ((ctype (get-concept-type type-name)))
        (when ctype
          (dolist (parent (direct-supertypes ctype))
            (type-traversal parent types-visited :parents t :children nil)))))

    ;; it appears that margin specifies inches
    (format stream "digraph \"~(~a~)_concept_type_hierarchy\" {~%" name)
    (format stream "  graph [rankdir=\"~:[BT~;RL~]\"];~%" landscape)
    (format stream "  node [shape=box,color=snow3,width=0,height=0, margin=.03, fontname=Helvetica, fontsize=10];~%")
    (format stream "  edge [arrowhead=none,color=steelblue];~%")
    ;; arrowhead=  open, vee, normal

    ;; add node structures
    (maphash #'(lambda (super-type v)
                 (declare (ignore v))
                 (unless (and hide-bottom (bottom-concept-type-p super-type))
                   (setf (gethash super-type type-id-table) index)
                   (format stream " type~a [label=\"~a\" id=\"~(~a~)\"]~%"
                           index (label super-type) (label super-type)))
                 (incf index))
             types-visited)

    ;; add edges
    (maphash #'(lambda (supertype v)
                 (declare (ignore v))
                 (let ((subtypes (direct-subtypes supertype)))
                   (dolist (subtype subtypes)
                     (let ((subtype-id (gethash subtype type-id-table))
                           (supertype-id (gethash supertype type-id-table)))
                       ;; all subtypes are not necessarily known
                       ;; exclude bottom node
                       (when subtype-id
                         (format stream "  type~a -> type~a;~%" subtype-id supertype-id))))))
             types-visited)
    (format stream "}~%")))


;;; filedir ends with a "/"
;;; graph-name has no "/" or extension
;;; can be used to display .dot files generated by graph-concept-types()
#+swank
(defun display-graph (graph-name &optional (filedir *cgraph-data-directory*))
  (swank:eval-in-emacs
   `(let* ((file (format "%s%s" ,filedir ,graph-name))
           (dot-file (format "%s.dot" file)))
      (compile (format "dot -Tpng %s.dot -o %s.png" file file))
      (with-current-buffer (find-file-noselect dot-file t)
        (revert-buffer t t)
        (graphviz-dot-preview)))))

#-swank
(defun display-graph (graph-name &optional (filedir *cgraph-data-directory*))
  (declare (ignore graph-name filedir))
  (warn "display-graph requires SWANK/SLIME to be loaded"))

;;; (display-graph "animal" "~/.cgraph/data/")
;;; (display-graph "animal")

(defun redisplay (graph-name)
  (display-graph graph-name *cgraph-data-directory*))





;;; type-name-list is a list of symbols, or a single symbol
(defun graph-concept-types (type-name-list &key (landscape nil) (hide-bottom t))
  "Generate a type diagram for the specified type(es).
   This tool only works when the Graphviz application (www.graphviz.org)
   is installed in /Applications/Graphviz.app "

  (unless (listp type-name-list)
    (setf type-name-list (list type-name-list)))

  (let* ((graph-name (string-trim "()" (substitute #\- #\space (format nil "~(~a~)" type-name-list))))
         (file-dir (format nil "~a.cgraph/data/" (namestring (user-homedir-pathname))))
         (file-name (format nil "~a~(~a~).dot" file-dir graph-name)))

    (when (every #'(lambda (c) (get-concept-type c)) type-name-list)

      (with-open-file (stream file-name :direction :output :if-exists :supersede :if-does-not-exist :create)
        (generate-concept-type-digraph :type-name-list type-name-list
                                       :stream stream
                                       :parents t
                                       :children t
                                       :landscape landscape
                                       :hide-bottom hide-bottom))
      (display-graph graph-name file-dir))
    file-name))



;;; elisp function needed for graphing from minibuffer
(eval-when (:load-toplevel :execute)
  (when (and (find-package :swank)
             ;; Skip when no active SLIME connection (headless / test runs).
             (let ((conn (find-symbol "*EMACS-CONNECTION*" :swank)))
               (and conn (boundp conn) (symbol-value conn))))
    (funcall (intern "EVAL-IN-EMACS" :swank)
             '(defun graph-types (concept-types)
                "draw a graph of the types around the supplied concept types"
                (interactive "swhat concept type(s): ")
                (eval-in-repl  (format "(graph-concept-types '%s)" concept-types))))))
