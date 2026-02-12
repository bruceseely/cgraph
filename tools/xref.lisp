;;; problem:
;;; GET-VALUE-CRITERIA likks the page


;;; getting error with SPIKE.GENERIC.SCHEDULER::GET-SCRIPT-REPORT-FILENAME
;;; tons of spaces...



;;;;;;;; todo ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;ep


;;; non-:after method found when clicking @ for after method
;;;     example: process-diagnostic :after
;;;
;;; add a bookmarks pane, and an easy way to add the current function to it!
;;; scroll each of callers & callees panes
;;; use a different color each time children are displayed (to disambiguate branches)
;;; add option to display package
;;; add option to sort by name or package
;;; fix scroll-to-top issue
;;; add buttons: expand all, collapse all
;;; in addition to elipsis, something (up, down arrows) that expands the tree as far as possible
;;; refreshing the page can close opened child-lists (read-proposals....
;;; provide some way of extracting the call path
;;; provide edit-function button ('@' ?
;;; uppercase types in signatures

#-aserve
(eval-when (:compile-toplevel :execute :load-toplevel)
  (require :aserve))

(excl:without-redefinition-warnings
  (defvar cl-user::*context-package*))

;;; try to keep from redefining the *context-package* if the code is recompiled
(eval-when (:compile-toplevel :execute :load-toplevel)
  (setf cl-user::*context-package* *package*))

(eval-when (:compile-toplevel :execute :load-toplevel)
  (unless (find-package :xref-browser)
    (let ((current (package-name cl-user::*context-package*))
	  (used (mapcar #'package-name (package-use-list *package*))))
      (excl::defpackage-1 :xref-browser
	  `((:use :common-lisp :excl :net.aserve :net.html.generator ,current ,@used)
	    (:nicknames "XB")
	    (:shadow #:start #:until #:exit)))))
  (in-package :xref-browser))


(defconstant nw-arrow "&#8598")
(defconstant ne-arrow "&#8599")
(defconstant se-arrow "&#8600")
(defconstant sw-arrow "&#8601")
(defconstant up-arrow "&#8593")
(defconstant down-arrow "&#8595")
(defconstant at-sign "&#64")
(defconstant less-than "&#60")
(defconstant greateer-than "&#62")

(defvar *aserve-host* "localhost")
(defvar *aserve-path* "/xref")
(defvar *aserve-port* 8040)
(defvar *urlbase* (format nil "http://~a:~a~a" *aserve-host* *aserve-port* *aserve-path*))
(defvar *default-port* 8040)

(defparameter *form-method* "get")
(defparameter *sort-by* t) ; {:package :filename}
(defparameter *display-package* t)
(defvar *tree-height* 0)

(defparameter *callees-tree* nil)
(defparameter *callers-tree* nil)
(defparameter *start-function* nil) ; interned symbol
(defparameter *fboundp-error-message* nil)

(defvar *package-selection-changed* t)

;; 240  15 285 30 210 120
(defparameter *colors* '("#3333ff" "#ff6633" "#cc33ff" "#ff9933" "#3399ff"  "#009933"  ))
;;(defparameter *colors* '(000000 990000 994900 997300 999900 739900 009900 007399 730099 990073))

;;; (parse-integer "3333ff" :radix 16)



;;;;;;;;;;; utilities ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun alpha-lessp (x y)
  ;; Returns T if printed representation of X is less than that of Y.
  ;; Characters and numbers sort before symbols/strings, before random objects,
  ;; before lists. Characters and numbers are compared using CHAR<; symbols/strings with STRING-LESSP;
  ;; random objecs by printing them(!); lists are compared recursively.
  (cond
    ((numberp x) (or (not (numberp y)) (< x y)))
    ((numberp y) (or (not (numberp x)) (< y x)))
    ((characterp x) (or (not (characterp y)) (char< x y)))
    ((characterp y) (or (not (characterp x)) (char< y x)))
    ((or (symbolp x) (stringp x)) (or (not (or (symbolp y) (stringp y))) (string-lessp x y)))
    ((or (symbolp y) (stringp y)) nil)
    ((atom x) (or (consp y) (string-lessp (prin1-to-string x) (prin1-to-string y))))
    ((atom y) nil)
    (t
     (do ((x1 x (cdr x1))
	  (y1 y (cdr y1)))
	 ((null y1))
       (or x1 (return t))
       (and (alpha-lessp (car x1) (car y1)) (return t))
       (and (alpha-lessp (car y1) (car x1)) (return ()))))))



(defun list-string-from-list (list)
  (format nil "(~a)" (format nil "~{~a~^, ~}" list)))

(defun px (val)
  (format nil "~dpx" val))

(defun em (val)
  (format nil "~dem" val))

(excl:without-redefinition-warnings
  (defun mission ()
    (let* ((package-name (package-name cl-user::*context-package*))
	   (dot1 (position #\. package-name))
	   (dot2 (when dot1 (position #\. package-name :start (1+ dot1)))))
      (when dot2
	(intern (subseq package-name (1+ dot1) dot2) :keyword)))))



(defun shorten (text)
  "remove duplicate spaces and newlines"
  (when text
    (let* ((text (substitute #\space #\newline
				  (substitute #\space #\return
					      (substitute #\space #\tab text))))
	   (in (coerce text 'vector))
	   (out (make-array 1 :fill-pointer 0 :adjustable t)))
      (labels ((prev-char () (when (> (fill-pointer out) 0) (aref out (1- (fill-pointer out)))))
	       (extra-space-p (char)
		 (and (eq char #\space)
		      (eq (prev-char) #\space))))
	(dotimes (i (length in))
	  (let ((char (aref in i)))
	    (when (find char '(#\return #\newline))
	      (setf char #\space))
	    (unless (extra-space-p char)
	      (Vector-push-extend char out))))
	(let ((compressed-text (coerce out 'string)))
	  (string-trim '(#\space #\tab #\return #\newline) compressed-text))))))


(defun parse-name (spec)
  (cond ((atom spec) spec)
	((and (find (car spec) '(method flet labels))
	      (not (and (consp (cadr spec))
			(eq (caadr spec) 'setf))))
	   (parse-name (cadr spec)))
	((eq (car spec) :INTERNAL)
	 (parse-name (cadr spec)))
	((eq (car spec) :OPERATOR)
	 (cadr spec))
	((eq (car spec) :DISCRIMINATOR)
	 (caadr spec))
	((eq (car spec) :ANONYMOUS-LAMBDA)
	 'anonymous)
	((eq (car spec) :PROPERTY)
	 spec)
	((eq (car spec) :TOP-LEVEL-FORM)
	 nil)
	((eq (car spec) 'SETF)
	 (parse-name (cadr spec)))
	((eq (car spec) 'COMPILER-MACRO)
	 (parse-name (cdr spec)))
	;; for paths
	(t (car spec))))


;;;; path manipulation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; an EXPANSION is a list of paths, where each path is a FUNCTION
;;;   followed by the FUNCTIONS visited to get to the fumction
(defun expand (expansion)
  (apply #'append
	 (mapcar #'(lambda (path)
		     (let ((head (if (listp (car path)) (cadar path) (car path)))
			   (temp (mapcar #'(lambda (node) (cons node path))
					 (xref:get-relation :calls :wild (parse-name (car path))))))
		       (remove head temp :key #'(lambda (x) (parse-name (car x))))))
		 expansion)))

(defun foundp (fn-spec horizon)
  "true if fn-spec is in horizon"
  (let ((name (parse-name fn-spec)))
    (not (null
	  (and name
	       (find name horizon :key #'parse-name))))))

(defun find-path (fn-spec expansion)
  (find-if #'(lambda (path)
	       (foundp fn-spec path))
	   expansion))

;;; try to collect multiple paths
(defun call-paths (fn1 fn2 &optional (limit 1))
  "call path from fn1 to fn2"
  (let ((expansion-list
	  (loop for expansion = (expand (list (list fn2))) then (expand expansion)
		for horizon = (mapcar #'car expansion)
		for depth = 0 then (1+ depth)
		for p = (foundp fn1 horizon)
		if p collect expansion into expansions
		  until (or (null horizon) (> depth limit))
		finally (progn
			  (return expansions))))
	(paths (list)))
    (when expansion-list
      (dolist (path-list expansion-list)
	(push (find-path fn1 path-list) paths)))
    paths))

(defun call-path (fn1 fn2 &optional (limit 1))
  "call path from fn1 to fn2"
  (let ((paths (call-paths fn1 fn2 limit)))
    paths))


(defmethod filter-packages ((fns list))
  "filter ignored packages; see *ignored-packages* & *ignored-packages-partials*"
  (remove-if #'(lambda (x)
		 (let ((package-name (intern
				      (package-name (symbol-package (parse-name x)))
				      :keyword)))
		   (let ((result
			   (or (find x *ignored-fns*)
			       (and (consp x) (eq (car x) 'setf))
			       ;;(find package-name *ignored-packages* :test #'eq)
			       (restricted-package-p package-name)
			       (block ok
				 (dolist (p *ignored-packages-partials*)
				   (when (search p (princ-to-string package-name) :test #'string-equal)
				     (return-from ok t)))
				 nil))))
		     result)))
	     fns))



;;; symbol => list of specs
(defmethod find-methods ((name symbol))
  ;;(format t "~&~a: ~s" name (excl::arglist name))
  (let ((fn (ignore-errors (symbol-function name))))
    (cond ((null fn) nil)
	  ((typep fn 'standard-generic-function)
	   (filter-packages (xref:get-relation :calls name :wild)))
	  (t
	   (list (list 'function name (mapcar #'intern (excl::arglist name))))))))

;;(list (list  name (mapcar #'intern (excl::arglist name))))

(defmethod find-methods ((spec cons))
  (when (eq (car spec) 'method)
    (find-methods (cadr spec))))

(defun macro-p (symbol)
  (not (null (macro-function symbol))))


(defmethod function-p ((symbol symbol))
  (and (fboundp symbol)
       (not (macro-function symbol))
       (not (special-operator-p symbol))))

(defmethod function-p ((spec list))
  (eq (car spec) 'method))


;;; use this to find the package of a function
;;; enable that package and proceed
(defun function-packages (function-name &optional (packages (available-packages)))
  "returns a list of packages where the function is defined"
  (remove nil
	  (mapcar #'(lambda (pkg)
		      (when (and (find-package pkg) (fboundp (intern (string-upcase function-name) pkg)))
			(intern pkg :keyword)))
		  packages)))


(defun accessor (path target)
  (format t "~&target: ~s" target)
  (let ((nodes `(quote ,target)))
    (format t "~&nodes: ~s" nodes)
    (dolist (index path)
      (setf nodes `(nth ,index (cdr ,nodes)))
    (format t "~&nodes: ~s" nodes))
    nodes))

#+nil
(defun accessor1 (path target)
  (format t "~&target: ~s" target)
  (let ((nodes target))
    (format t "~&nodes: ~s" nodes)
    (dolist (index path)
      (setf nodes `(nth ,index ,(cdr nodes)))
    (format t "~&nodes: ~s" nodes))
    nodes))


(defun (setf accessor) (val path target)
  (let ((node (find-node-by-path path target)))
    (setf (cdr node) val)))

(defun find-node-by-path (path target)
  (eval (accessor path target)))

(defun set-node-by-path (val path target)
  (let ((accessor (accessor path target)))
    (when (consp (eval accessor))
      (setf (accessor path target) val)
      ;;(setf accessor val)
      )))



#+nil
(defmacro set-node-by-path (val path target)
  `(setf (accessor ,path ,target) ',val))

#|

(setf tree '(a (b (x 1 2) (y 3 4)) (c (q 6 7) (r 9 8) (s 3 4))))
(accessor '(1 2) tree)
(eval (accessor '(1 2) tree))
(find-node-by-path  '(1 2) tree)
(set-node-by-path nil  '(1 2) tree)
(set-node-by-path '(3 4)  '(1 2) tree)
(set-node-by-path ((r 45 56) (f 5 7) (y 3 4))  '(1 2) tree)
(eval (accessor '(1 2 2) tree))
(find-node-by-path  '(1 2 2) tree)
|#



;;;; filtering - packages ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;

(defparameter *system-packages* '(:acl-socket
				  :aclmop
				  :alexandria
				  :asdf
				  :babel
				  :babel-encodings
				  :bordeaux-threads
				  :cffi
				  :common-lisp
				  :compiler
				  :cross-reference
				  :dbi
				  :defsystem
				  :develop
				  :excl
				  :foreign-functions
				  :lep
				  :lparallel
				  :lparallel.kernel
				  :lparallel.ptree
				  :mop
				  :multiprocessing
				  :net.uri
				  :profiler
				  :regexp
				  :swank-macrostep
				  :swank
				  :test
				  :uiop
				  ))

(defparameter *optional-packages* '(:common-lisp
				    :mop
				    :common-lisp-user
				    :cl-user
				    :climif
				    :excl
				    :climif2-package))


;;; this is a subset of *optional-packages*
(defparameter *selected-packages* '(:common-lisp))


;; (defparameter *spike-generic-packages* (list :spike.generic.domain :spike.generic.scheduler))
;; (defparameter *spike-hst-packages* (list :spike.hst.domain :spike.hst.scheduler))
;; (defparameter *spike-jwst-packages* (list :spike.jwst.domain :spike.jwst.scheduler :database))
;; (defparameter *spike-support-packages* (list :buffy :utilities :util :develop :test))
;; (defparameter *lisp-support-packages* (list :common-lisp :mop :excl :dbi))
;; (defparameter *franz-support-packages* (list :acl-socket :aclmop :compiler :lep :net.uri :profiler :cross-reference :multiprocessing :foreign-functions :regexp))
;; (defparameter *external-support-packages* (list :alexandria :babel :babel-encodings :bordeaux-threads :lparallel :lparallel.kernel :lparallel.ptree :asdf :defsystem :swank :swank-macrostep))


;;; get the base package name
(defmethod std-package ((package package))
  (std-package (package-name package)))

(defmethod std-package ((package-symbol symbol))
  (std-package (princ-to-string package-symbol)))

(defmethod std-package ((package-string string))
  (let* ((package-name (string-upcase package-string))
	 (slash (position #\/ package-name))
	 (dot (position #\. package-name)))
    (intern
     (cond (slash (subseq package-name 0 slash))
	   (dot (subseq package-name 0 dot))
	   (t package-name))
     :keyword)))

;;; test whether to show classes in the package
(defmethod restricted-package-p ((package t))
  (if (system-package-p package)
      (not (selected-package-p package))
      nil))

(defmethod restricted-package-p ((package-name (eql :aclmop)))
  (restricted-package-p :mop))

(defun mission-packages ()
  (let ((mission (mission)))
    (case mission
      ;;(:hst  *spike-hst-packages*)
      ;;(:jwst *spike-jwst-packages*)
      (t nil))))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; (mapcar #'xb::method-spec (mop:GENERIC-FUNCTION-METHODS #'save-plan))
(defmethod method-spec ((method method))
  (xref::object-to-function-name method))

(defmethod method-name ((method method))
  (mop:generic-function-name (mop:method-generic-function method)))


(defmethod method-signature ((method method))
  (let* ((gf-name (mop:generic-function-name (mop:method-generic-function method)))
	 (name (cond ((consp gf-name) (list (car gf-name) (cadr gf-name)))
		     (t gf-name)))
	 (qualifier (method-qualifiers method))
	 (lambda-list (mop::method-lambda-list method))
	 (setf-p (and (consp name) (eq (car name) 'setf)))
	 (accessor-p (typep method 'mop::standard-accessor-method))
	 (in-optionals nil)
	 (type-list (cond (setf-p
			   (cond ((consp (cadr lambda-list))
				  (list t (cadr (cadr lambda-list))))
				 (accessor-p (list t (cadr lambda-list)))
				 (t (list t t))))
			  (t (let ((defs (list)))
			       (dolist (x lambda-list)
				 (cond (in-optionals ) ; ????
				       ((or (equal x '&rest)
					    (equal x '&key)
					    (equal x '&optional))
					(setf in-optionals t))
				       ((consp x)
					(cond ((and (consp (cadr x)) (eq (caadr x) 'eql))
					       (push (cadr x) defs))
					      ((consp (cadr x)) (push t defs))
					      (t ;;(push (list (cadr x) 't) defs)
					       (push (cadr x) defs)
					       )))
				       (accessor-p
					(push x defs))
				       (t (push t defs))))
			       (reverse defs))))))
    (let ((sig (list 'method name)))
      (when qualifier
	(setf sig (append sig qualifier)))
      (setf sig (append sig (list type-list))))))

;;;; editing ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#||
;;; open-file-at-position needs to be defined in an elisp init file
(defun open-file-at-position (path position)
  (when (file-exists-p path)
    (find-file-other-window path)
    (goto-char position)))

(setq slime-enable-evaluate-in-emacs t)
||#

(defmethod open-file-for-edit (spec)
  (when (not (find (car spec) (list 'method 'function)))
    ;; function-source-location wants a function object, if a function
    (setf spec (eval (cons 'function spec))))
  (let ((loc (swank/allegro::function-source-location spec)))
    (cond ((eq (car loc) :error)
	   (format t "~%Can't open file, loc: ~a" loc))
	  (t
	   (let* ((location (cdr loc))
		  (path (cadr (assoc :file location)))
		  (offset-rec (assoc :offset location))
		  (offset-pos (when offset-rec (1+ (nth 2 offset-rec))))
		  (position (or offset-pos 0))
		  (cmd `(open-file-at-position ,path ,position))
		  (connection (or swank::*emacs-connection*
				  (swank::default-connection))))

	     (when connection
	       (swank::with-connection (connection) ;;(cl-user::*connection*)
		 ;; to go the other way use (slime-eval) in slime.el
		 (swank::eval-in-emacs cmd t))))))))

(defmethod open-file-for-edit ((spec symbol))
  (open-file-for-edit (list spec)))

(defmethod open-file-for-edit ((spec string))
  (open-file-for-edit (intern spec)))



;;; (SWANK/ALLEGRO::function-source-location '(method import-proposals (cons)) )
;;; (open-file-for-edit '(method import-proposals (cons)))

(defmethod display-method-file-link ((method t))
  (let* ((gf (mop:method-generic-function method))
	 (name (mop:generic-function-name gf))
	 (method-signature (method-signature method))
	 ;; is method-spec the same thing as method-signature??
	 ;; (method-spec (method-signature method))
	 (package (cond ((symbolp name)
			 (symbol-package name))
			((consp name)
			 (symbol-package (cadr name)))
			(t :cl-user)))
	 (package-name (package-name package))
	 ;; no source-path is available for system functions
	 (path (ignore-errors (excl::source-file method-signature :operator))))

    (let ((name-string (string-downcase (princ-to-string name))))
      (let ((url (format nil "~a?edit=~a" *urlbase* path)))
	url
	(if path
	    (html (:br)
		  ((:span :class "method")
		   ((:a :href url :title "Edit method definition")
		    (format *html-stream* "~a::~a" package-name name-string))))
	    (html (:br)
		  (format *html-stream* "~a::~a" package-name name-string)))))))


;;;; filtering ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun available-packages ()
  (append (mission-packages) *selected-packages* *system-packages*))

;;; optional packages whose checkbox is checked
(defun selected-package-p (package)
  (not (null (and (find (std-package package) (append (mission-packages) *optional-packages*))
		  (find (std-package package) *selected-packages*)))))


;;; packages denoted as system packages (i.e. not necessarily shown)
(defun system-package-p (package)
  (not (null (find (std-package package) (append (mission-packages) *system-packages*)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ????
(defparameter *ignored-fns* '(get-exclude-executions lookup-stored-query program-ids-from-query store-query))


;; removed :excl
(defparameter *ignored-packages* '(:common-lisp
				   :excl
				   :aclmop
				   :multiprocessing :system :sql :dbi :bordeaux-threads :swank
				   :pset :xref-browser :typeclass :red-black :queue.simple   ))

;;; used to block packages that contain the names
(defparameter *ignored-packages-partials* '("SWANK" "ARNESI" "ALEXANDRIA" "FIVEAM" "LPARALLEL"))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;; calls who
;;;;;;;;;;; callees


(defmethod has-callees ((node symbol))
    (cdr (callees-tree node 1)))


;;; spec => list of symbols
(defmethod callees ((spec list))
  ;;(callees (cadr spec))
  (xref:get-relation :calls spec :wild))


;;; symbol => list of symbols
(defmethod callees ((name symbol))
  (when name
    (let* ( ;;(function-string (symbol-name name))
	   (fn (ignore-errors (symbol-function name)))
	   (callees-list (cond ((typep fn 'standard-generic-function)
				(let* ((methods (find-methods name))
				       (methods-called
					 (filter-packages
					  (apply #'append
						 (mapcar #'(lambda (method)
							     (xref:get-relation :calls method :wild))
							 methods)))))
				  methods-called))
			       (t
				(filter-packages (xref:get-relation :calls name :wild))))))
      (sort (copy-list callees-list) #'alpha-lessp))))


(defmethod callees ((name string))
  (let* ((function-name (let* ((pos (position #\: name :from-end t)))
			  (cond (pos (subseq name (1+ pos)))
				((> (length name) 0)
				 name)
				(t nil))))
	 (function-package (let* ((pos (position #\: name))
				  (package-string (when pos (subseq name 0 pos)))
				  (package (when pos (find-package package-string))))
			     (or package cl-user::*context-package*)))
	 (function (when function-name (intern function-name function-package))))
    (callees function)))



;;; (function-name is consed onto the list
(defmethod callees-tree ((function-name symbol) &optional (limit 1) (depth 0))
  (when function-name
    (let* ((fnames (remove-duplicates (mapcar #'parse-name (callees function-name))))
	   ;; this sorts alphabetically correctly, but unsorted may be in execution order, and better
	   ;;(fnames (sort (copy-list (remove-duplicates (mapcar #'parse-name (callees function-name)))) #'alpha-lessp))

	   (fns (mapcar #'(lambda (fname)
			    (let ((package (intern
					    (package-name (symbol-package (parse-name fname)))
					    :keyword)))
			      (intern fname package)))
			fnames))
	   (children (when (< depth limit)
		       (mapcar #'(lambda (f)
				   (when f
				     (let ((filename (cond ((not (eq function-name f))
							    (callees-tree f limit (1+ depth)))
							   (t
							    (list f)))))
				       filename)))
			       fns))))
      (cons function-name children))))

(defmethod callees-tree ((fn-spec list) &optional (limit 1) (depth 0))
  (callees-tree (parse-name fn-spec) limit depth))

(defmethod callees-tree ((fn-name string) &optional (limit 3) (depth 0))
  depth limit
  (callees-tree (intern fn-name) limit depth))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;; who calls
;;;;;;;;;;; callers
;;;;; (xref:get-relation :calls '(METHOD LOAD-PROPOSALS (cons))      :wild) => 64 generic functions
;;;;; (xref:get-relation :calls '(METHOD LOAD-PROPOSALS (string))    :wild) => 30 generic functions
;;;;; (xref:get-relation :calls '(METHOD LOAD-PROPOSALS :AROUND (T)) :wild) => 17 generic functions
;;;;; (xref:get-relation :calls '(METHOD LOAD-PROPOSALS :before (T)) :wild) => 3 generic functions
;;;;; (xref:get-relation :calls '(METHOD LOAD-PROPOSALS (t))         :wild) => 5 generic functions


(defmethod has-callers (node)
  (cdr (whocalls-tree node 1)))


;;; symbol => list of specs
(defmethod callers ((spec list))
  (when (eql (car spec) 'function)
    (setq spec (cdr spec)))
  (callers (parse-name spec)))

(defmethod callers ((function-name symbol))
  (filter-packages (xref:get-relation :calls :wild function-name)))

(defmethod callers ((name string))
  (unless (equal name "")
    (callers (intern (string-upcase name)))))


#+nil
(defmethod whocalls-tree ((function-name symbol) &optional (limit 1) (depth 0))
  (let* ((callers (callers function-name))
	 (fnames (remove-duplicates (mapcar #'parse-name callers)))
	 (fnsx (mapcar #'(lambda (fname)
			   (let ((package (intern
					   (package-name (symbol-package (parse-name fname)))
					   :keyword)))
			     (intern fname package)))
		       fnames))
	 (fns (remove function-name fnsx))
	 (children (when (< depth limit)
		     (mapcar #'(lambda (f)
				 (when f
				   (let ((filename (cond ((not (eq function-name f))
							  (whocalls-tree f limit (1+ depth)))
							 (t
							  f))))
				     filename)))
			     fns)))
	 (sorted-children (case *sort-by*
			    (:package
			     (sort (copy-list children) #'alpha-lessp :key #'package-key))
			    (:filename
			     (sort (copy-list children) #'alpha-lessp :key #'filename-key))
			    (nil
			     children)
			    (t
			     (sort (copy-list children) #'alpha-lessp :key #'filename-key)))))
    (cons function-name (or sorted-children children))))


(defmethod whocalls-tree ((function-spec list) &optional (limit 1) (depth 0))
  (let* ((fns (callers function-spec))
	 (children (when (< depth limit)
		     (mapcar #'(lambda (f)
				 (when f
				   (whocalls-tree f limit (1+ depth))))
			     fns)))
	 (sorted-children (case *sort-by*
			    (:package
			     (sort children #'alpha-lessp :key #'package-key))
			    (:filename
			     (sort children #'alpha-lessp :key #'filename-key))
			    (nil
			     children)
			    (t
			     (sort children #'alpha-lessp :key #'filename-key)))))
    (cons function-spec (or sorted-children children))))

(defmethod whocalls-tree ((fn-spec symbol) &optional (limit 1) (depth 0))
  (whocalls-tree (list fn-spec) limit depth))

(defmethod whocalls-tree ((fn-name string) &optional (limit 3) (depth 0))
  (whocalls-tree (intern fn-name) limit depth))




;;;; maybe this will work
;;;; function saveStringToClipboard (string) {
;;;;     function handler (event){
;;;;         event.clipboardData.setData('text/plain', string);
;;;;         event.preventDefault();
;;;;         document.removeEventListener('save', handler, true);
;;;;     }
;;;;     document.addEventListener('copy', handler, true);
;;;;     document.execCommand('save');
;;;; }


;;;; drawing nodes ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod remove-key (form (key (eql :INTERNAL)))
  (if (eql (car form) key)
      (remove-key (cadr form) key)
      form))

(defmethod present-callers-node ((passed-node list) path &key (depth 0) has-children displayed-children (tree-height 2) parent)
  tree-height

  (let* ((node-str (format nil "~s" passed-node))
	 (color (nth (mod depth (length *colors*)) *colors*))
	 (color-string (format nil "color: ~a;" color))
	 ;;(index (position #\& node-str))
	 ;;(source-files (excl:source-file node t))
	 (package (symbol-package (parse-name passed-node)))
	 (package-name (package-name package))
	 (indent-string (format nil "text-indent: ~dpx;" (* 20 depth)))
	 (font-string (format nil "font-family: Verdana, Geneva, sans-serif; font-size: 14px;" ))
	 (path-string (subseq (with-output-to-string (str) (dolist (z path) (format str " ~a" z))) 1))
	 (display-package (and *display-package* (> (length package-name) 0)))
	 (base (if *start-function*
		   (format nil "~a::~a"
			   (package-name (symbol-package *start-function*))
			   (symbol-name (parse-name *start-function*)))
		   ""))
	 ;; don't show node as a child of node
	 (true-children (remove node-str has-children
				:key (lambda (x)
				       (symbol-name (parse-name (car x))))
				:test #'string-equal)))
    parent tree-height display-package

    ;;(format t "~&passed-node: ~s" passed-node)


    ;; todo: should process :internal correctly
    (let* ((node (if (listp (cadr passed-node))
		     (remove-key passed-node :internal)
		     passed-node))
	   ;;(z1 (format t "~&node: ~s" node))
	   (fn (cond ((find (car node) '(labels flet))
		      ;; todo: not really right
		      (car (find-methods (cadr node))))
		     ((and (function-p (car node)) (null (cdr node)))
		      (car (find-methods (car node))))
		     ((macro-p (cadr node))
		      nil)
		     ((function-p (cadr node))
		      ;; (method foo ...)
		      node)
		     (t nil))))

      ;; error when
      ;; (setq fn '(METHOD CHECK-DIAGNOSTIC-SYNTAX OR (DIAGNOSTIC)))
      (when fn
	(destructuring-bind (type name &rest fn-args) fn
	  ;; type is METHOD or FUNCTION
	  (declare (ignore type))

	  (when (and (symbolp (car fn-args))
		     (find (car fn-args) '(or and after )))
	    (setf fn-args (cdr fn-args)))

	  (let* ((qualifier (when (find (car fn-args) '(:before :around :after))
			      (car fn-args)))
		 (args (if qualifier (cadr fn-args) (car fn-args)))
		 (rest-index (when (consp args) (position '&rest args)))
		 (prefix (when rest-index (subseq args 0 rest-index)))
		 ;; discard the &rrest arg
		 (suffix (when rest-index (nthcdr (+ 2 rest-index) args)))
		 (arglist (if rest-index (append prefix suffix) args))
		 (spec-string (format-method-spec node)))

	    (html
	     ((:div :style (format nil "~a" indent-string)
		    :contextmenu (format nil "~a-menu" node))

	      ;; >> edit-button ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      ((:a :class "source"
		   :style "color: black;"
		   :href (format nil "/xref?funcspec=~a" (uriencode-string (shorten spec-string))))
	       (when (> depth 0)
		 (html ((:span :title (format nil "edit ~a" node))
			(format *html-stream* "~a&nbsp" at-sign)))))

	      ;; >> node name - fn ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      ((:a :class "goto"
		   :href (format nil "/xref?goto=~s&path=~a&fname=~a&tree=callees"
				 (parse-name node) path-string base)
		   :title (format nil "~(~a~)" package-name))
	       ((:span :style (format nil "~a~a" font-string color-string)
		       :contextmenu (format nil "~a-menu" node))

		;;(format *html-stream* "(")
		;;(format *html-stream* "~(~a~) " type)
		(format *html-stream* "~:@(~a~)" name)
		(format *html-stream* " ~( ~s~)" arglist)
		;;(format *html-stream* ")")
		))

	      ;; >> package ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      #+nil
	      (when display-package
		(format *html-stream* "&nbsp[")
		;; node name - package
		(html (format *html-stream* "~(~a~)" package-name))
		;; node name :
		(format *html-stream* "]"))
	      (format *html-stream* "&nbsp")

	      ;; >> expand/contract button ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      (html
	       ((:a :class "open"
		    :style "color: black;"
		    :href (format nil "/xref?node=~s&path=~a&fname=~a&tree=callers"
				  node path-string base))
		;; draw the button
		(when true-children
		  (html
		   ((:span :style (format nil "~a~a" font-string color-string))
		    (format *html-stream* "~a"
			    (cond
			      ;; has children; not displayed
			      ((and (null displayed-children)
				    (consp true-children))
			       (html ((:span :title (format nil "show functions that call ~a" node))
				      (format *html-stream* "&nbsp~a;~a&nbsp" ne-arrow (length true-children)))))
			      ;; has children that are displayed
			      ;; show close-subtree button (<)
			      ((consp true-children)
			       (html ((:span :title (format nil "hide functions that call ~a" (parse-name node)))
				      (format *html-stream* "&nbsp&lt;&nbsp"))))
			      ;; no children
			      (t ""))))))))))))))))

(defmethod present-callees-node ((node symbol) path &key (depth 0) has-children displayed-children parent)
  (let* ((node-str (format nil "~s" node))
	 (color (nth (mod depth (length *colors*)) *colors*))
	 (color-string (format nil "color: ~a;" color))
	 (package (symbol-package node))
	 (package-name (package-name package))
	 (indent-string (format nil "text-indent: ~dpx;" (* 20 depth)))
	 (font-string (format nil "font-family: Verdana, Geneva, sans-serif; font-size: 14px;" ))
	 (path-string (subseq (with-output-to-string (str) (dolist (z path) (format str " ~a" z))) 1))
	 (display-package (and *display-package*
			       (> (length package-name) 0)
			       (not (find (intern package-name :keyword) (mission-packages)))))
	 ;; don't show node as a child of node
	 (base (if *start-function* (format nil "~a::~a" (package-name (symbol-package *start-function*)) (symbol-name *start-function*)) ""))
	 (true-children (remove node-str has-children :key #'(lambda (x)
							       (symbol-name (car x)))
						      :test #'string-equal)))

    (html
     ((:div :style (format nil "~a" indent-string)
	    :contextmenu (format nil "~a-menu" node))

      (if (equal node parent)
	  ;; don't make mouse-sensitive, we're already here
	  (html
	   ((:span :style (format nil "~acolor: ~a;" font-string (car *colors*))
		   :contextmenu (format nil "~a-menu" node))
	    (format *html-stream* "~(~a~)" node)))

	  (html
	   ;; node name - fn ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	   ((:a :class "goto"
		:href (format nil "/xref?goto=~s&path=~a&fname=~a&tree=callees"
			      node path-string base))
	    ((:span :style (format nil "~a~a" font-string color-string)
		    :contextmenu (format nil "~a-menu" node))
	     (format *html-stream* "~(~a~)" node)))

	   ;; package ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	   (when display-package
	     (format *html-stream* "&nbsp[")
	     ;; node name - package
	     (html (:em (format *html-stream* "~(~a~)" package-name)))
	     ;; node name :
	     (format *html-stream* "]"))
	   (format *html-stream* "&nbsp")

	   ;; expand/contract button ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	   ((:a :class "open"
		:style "color: black;"
		:href (format nil "/xref?node=~s&path=~a&fname=~a&tree=callees"
			      node path-string base))
	    ;; draw the button
	    (when true-children
	      (html
	       ((:span :style (format nil "~a~a" font-string color-string))
		(cond
		  ;; show expand-subtree button
		  ((and (null displayed-children)
			(consp true-children))
		   (html ((:span :title (format nil "show functions called by ~a" node))
			  (format *html-stream* "&nbsp~a~a&nbsp" (length true-children) se-arrow))))
		  ;; show close-subtree button (<)
		  ((consp true-children)
		   (html ((:span :title (format nil "hide functions called by ~a" (parse-name node)))
			  (format *html-stream* "&nbsp&lt;&nbsp"))))
		  (t ""))))))))))))

;;;; drawing trees ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun calc-tree-height (tree)
  (if (null tree)
       0
       (1+
	(if (null (cdr tree))
	    0
	    (apply #'max
		      (mapcar #'calc-tree-height (cdr tree)))))))

;;; always displays entire tree
;;; pruning/expanding is done when the tree is generated/modified
;;; variable 'tree is the tree at this level
;;; path is the list of nodes to get to this tree (the (car path) is the parent of tree)
;;;

(defun present-callers-tree (tree &key (children-accessor nil) (path (list)) (depth 0) height parent (hide-root nil))
  (cond ((consp tree)
	 ;; this should be fixed closer to source
	 ;; example problem: callers of handler-bind includes NIL
	 (setf tree (remove nil tree))
	 (let ((current-node (car tree))
	       (child-nodes (cdr tree))
	       ;; can't sort here because the path is then wrong
	       ;;(child-nodes (sort (copy-list (cdr tree)) #'alpha-lessp :key #'car))
	       ;;(tree-height (calc-tree-height tree))
	       )

	   ;; show children
	   (do* ((child-index 0 (1+ child-index))
		 (children child-nodes (cdr children)))
		((null (car children)))
	     (when children
	       (present-callers-tree (car children)
				     :children-accessor children-accessor
				     :path (cons child-index path)
				     :depth (1+ depth)
				     :height height
				     :parent current-node)))

	   ;; show node
	   ;;don't present the *start-function* unless requested
	   (when (or path (not hide-root))
	     (present-callers-node current-node
				   path
				   :depth depth
				   :has-children (funcall children-accessor current-node)
				   :displayed-children (cdr tree)
				   :tree-height height
				   :parent parent))))
	(t (present-callers-node tree
				 path
				 :depth depth
				 :has-children nil
				 :displayed-children ()
				 :tree-height height
				 :parent parent))))



(defun present-callees-tree (tree &key (children-accessor nil) (path (list)) (depth 0) parent (hide-root nil))
  (cond ((consp tree)
	 ;; maybe not a problem, but just in case, for now
	 (setf tree (remove nil tree))
	 (let ((current-node (car tree))
	       (child-nodes (cdr tree))
	       ;; can't sort here because the path is then wrong
	       ;;(child-nodes (sort (copy-list (cdr tree)) #'alpha-lessp :key #'car))
	       )

	   ;; show node
	   ;;don't present the *start-function* unless requested
	   (when (or path (not hide-root))
	     (present-callees-node current-node
				   path
				   :depth depth
				   :has-children (funcall children-accessor current-node)
				   :displayed-children (cdr tree)
				   :parent parent))


	   ;; show children
	   (do* ((child-index 0 (1+ child-index))
		 (children child-nodes (cdr children))
		 (child (car children) (car children)))
		((null (car children)))

	     (when children
	       (present-callees-tree child
				     :children-accessor children-accessor
				     :path (cons child-index path)
				     :depth (1+ depth)
				     :parent current-node)))))
	(t (present-callees-node tree
				 path
				 :depth depth
				 :has-children nil
				 :displayed-children ()
				 :parent parent))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun filename-key (branch)
  (let* ((str (princ-to-string (car branch)))
	 (index (position #\& str :test #'equal))
	 (fn-name (subseq str (if index (1+ index) 0))))
    fn-name))

(defun package-key (branch)
  (princ-to-string (car branch)))


;;; not called!!!
;;; (defun show-callers-tree ()
;;;   (when *start-function*
;;;     (let* ((list (whocalls-tree *start-function* 0)) ; 1 to always include children of root
;;;	   (tree (or *callers-tree*
;;;		     list)))
;;;       (setf *callers-tree* tree)
;;;       (let ((*tree-height* (calc-tree-height tree)))
;;;	(present-callers-tree tree :children-accessor #'has-callers :height (calc-tree-height tree))))))


(defmethod format-method-spec ((method-spec list) &optional stream)
  (let* ((spec method-spec)
	 (rest-index (position '&rest spec))
	 (prefix (when rest-index (subseq spec 0 rest-index)))
	 ;; discard the &rrest arg
	 (suffix (when rest-index (nthcdr (+ 2 rest-index) spec)))
	 (modified-spec (if rest-index (append prefix suffix) spec))
	 ;;(modified-spec (append (butlast method-spec) (list arglist)))
	 (print-space nil)
	 (string-stream nil))
    (unless stream
      (setq stream (make-string-output-stream))
      (setf string-stream t))

    (format stream "(")
    (dolist (term modified-spec)
      (if print-space
	  (format stream " ")
	  (setf print-space t))
      (if term
	  ;; using '~a' so package is not printed
	  (format stream "~s" term)
	  (format stream "()")))
    (format stream ")")
    (if string-stream
	(get-output-stream-string stream)
	t)))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;; top-level ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defmacro bare-cbox-option (form label name test &optional style)
  style
  (let ((submit-fn (format nil "document.getElementById('~a').submit();" form)))
    `(html (:span (:label ((:input :type "checkbox"
				   :name ,name
				   :value ,label
				   :onclick ,submit-fn
				   :if* ,test :checked t)
			   (:princ-safe ,label)))))))

(defmacro form-cbox-option (form label name test &optional style)
  (let ((submit-fn (format nil "document.getElementById('~a').submit();" form)))
    `(html ((:td :if* ,style :style ,style)
	    (:span (:label ((:input :type "checkbox"
				   :name ,name
				   :value ,label
				   :onclick ,submit-fn
				   :if* ,test :checked t)
			   (:princ-safe ,label))))))))

(defun present-xref-page (&optional (function-name *start-function*))
  (let* ((*start-function* function-name)
	 ;; 1 to always include children of root
	 (callers-tree (if (or *package-selection-changed* (not *callers-tree*))
			   (whocalls-tree function-name 1)
			   *callers-tree*))
	 (callees-tree (if (or *package-selection-changed* (not *callees-tree*))
			   (callees-tree function-name 1)
			   *callees-tree*))
	 (methods (sort (find-methods function-name) #'alpha-lessp))
	 (min-width 800))

    (setf *callees-tree* callees-tree)
    (setf *callers-tree* callers-tree)

    (html
     ((:div :style (format nil " display:table;border: 1px solid black;border-collapse: collapse;min-width: ~dpx;" min-width))

      ;;>> callers tree ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ((:form :name "combined-tree" :method *form-method* :action *urlbase*)
       ((:div :class "tree")
	(when function-name
	  (present-callers-tree callers-tree :children-accessor #'has-callers
					     :height (calc-tree-height callers-tree)))))

      ;;>> function name ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ((:form :name "combined-tree" :method *form-method* :action *urlbase*)
       ((:div :class "fname")
	((:span :id "input")
	 ((:input :style (format nil "width: ~dpx" min-width)
		  :type "text"
		  :name "fname"
		  :value (if function-name
			     (format nil "~a::~a"
				     (package-name (symbol-package function-name))
				     (symbol-name function-name))
			     ""))))))

      ;;>> method signatures ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ((:div :class "methods")
       ((:table :style "border: 0")
	(dolist (method-spec methods)
	  ;; remove &rest arg from printed spec
	  (let* ((arglist (car (last method-spec)))
		 (rest-index (position '&rest arglist))
		 (prefix (when rest-index (subseq arglist 0 rest-index)))
		 (suffix (when rest-index (nthcdr (+ 2 rest-index) arglist)))
		 (arglist (if rest-index (append prefix suffix) arglist))
		 (modified-spec (append (butlast method-spec) (list arglist)))
		 (spec-string (format-method-spec method-spec)))
	    (html
	     ((:tr :style "border: 0;text-align: left; padding: 2px 5px;  vertical-align: text-top; font-size: 12px;line-height: 110%;")
	      ;; edit-button
	      ((:td :style "border: 0" )
	       ((:a :class "source"
		    :style "color: black;"
		    :href (format nil "/xref?funcspec=~a" (uriencode-string (shorten spec-string))))
		((:span :title (format nil "edit ~a" (parse-name method-spec)))
		 (format *html-stream* "~a" at-sign))
		;; (html ((:span :title (format nil "edit ~a" (parse-name method-spec)))
		;;        (format *html-stream* "~a" at-sign)))
		))

	      ;; function signiture
	      ((:td :style "border: 0" )
	       (format-method-spec modified-spec *html-stream*))))))))


      ;;>> callees tree ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ((:form :name "combined-tree" :method *form-method* :action *urlbase*)
       ((:div :class "tree")
	(when function-name
	  (present-callees-tree callees-tree :children-accessor #'has-callees))))


      ;;>> package selection ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ((:form :id "pselection"
	      :action (format nil "http://~a:~s~a" *aserve-host* *aserve-port* *aserve-path* )
	      :method *form-method*)
       ((:div :class "pkg")
	(dolist (package (mission-packages))
	  (html (bare-cbox-option "pselection" package "selected-package"
				  (find package *selected-packages*)
				  "border:none; padding-left:2; padding-right:2;")
		(:princ "&nbsp")))
	(:br)
	(dolist (package *optional-packages*)
	  (html (bare-cbox-option "pselection" package "selected-package"
				  (find package *selected-packages*)
				  "border:none; padding-left:2; padding-right:2;")
		(:princ "&nbsp")))))))))

(defun present-error-message ()
  (html
   ((:div)
    (:br)
    (format *html-stream* "~a" *fboundp-error-message*))))

(defun show-top-level-view (&optional function-name)
  (let ((selected-color "background-color:#9966FF; color:#FFFFFF;")
	(other-color "background-color:#FFFFCC; color:#000000;"))
    selected-color other-color
    (html
     (:br)
     (if *fboundp-error-message*
	 (present-error-message)
	 (present-xref-page function-name)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; collect values of an arg specified multiple times, as with checkbox values
(defun collect-args (arg-name args &key (return :string))
  (let ((values (list)))
    (dolist (arg-spec args)
      (when (equal arg-name (car arg-spec))
	(let ((val (cdr arg-spec)))
	  (push (case return
		  (:intern (intern (string-upcase val)))
		  (:keyword (intern (string-upcase val) :keyword))
		  (:integer (parse-integer val))
		  (:string (princ-to-string val))
		  (t nil))
		values))))
    values))

(defun parse-package-args (args)
  (collect-args "selected-package" args :return :keyword))


#||
;;; operations:
refresh
expand callee
close callee
expand caller
close caller
edit caller
edit start-function
select caller
select callee
||#

(defmethod parse-args (req)
  (declare (special *callers-tree* *callees-tree*))
  (let* ((query (request-query req))
	 (passed-funcspec (shorten (cdr (assoc "funcspec" query :test #'string-equal))))
	 ;;(passed-funcspec (assoc "funcspec" query :test #'string-equal))
	 ;;(passed-source-package (cdr (assoc "source-package" query :test #'string-equal)))
	 (passed-function-name (cdr (assoc "fname" query :test #'string-equal)))
	 (passed-path (cdr (assoc "path" query :test #'string-equal)))
	 (passed-tree (cdr (assoc "tree" query :test #'string-equal)))
	 (passed-goto (cdr (assoc "goto" query :test #'string-equal)))


	 (tree-type (if passed-tree (intern (string-upcase passed-tree) :keyword) :none))
	 (path (when passed-path (read-from-string (format nil "(~a)" passed-path))))
	 (goto (when passed-goto (read-from-string (format nil "~a" passed-goto))))
	 (supplied-name-string (string-upcase (or passed-function-name "")))
	 (function-name (let* ((pos (position #\: supplied-name-string :from-end t)))
			  (cond (pos (subseq supplied-name-string (1+ pos)))
				((> (length supplied-name-string) 0)
				 supplied-name-string)
				(t nil))))
	 (function-package (let* ((pos (position #\: supplied-name-string))
				  (package-string (when pos (subseq supplied-name-string 0 pos)))
				  (package (when pos (find-package package-string))))
			     (or package cl-user::*context-package*)))
	 (function (when function-name (intern function-name function-package)))
	 (function-name-changed (and function (not (eq function *start-function*))))
	 (selected-packages (parse-package-args query))
	 (package-selection-changed (or (null query)
					(not (null (set-difference selected-packages *selected-packages*)))))
	 (*fboundp-error-message* nil))

    ;;;;;;;;(format t "~2&___________________________________________________" )
     ;; (format t "~2%req: ~s" req)
     ;;(format t "~2%query: ~s" query)
     ;; (format t "~&passed-function-name: ~s" passed-function-name)
     ;; (format t "~&supplied-name-string: ~s" supplied-name-string)
     ;; (format t "~&function-name: ~s" function-name)
     ;; (format t "~&function-package: ~s" function-package)
     ;; (format t "~&function: ~s" function)

    ;; (format t "~&: ~s" )
    #|
    (when passed-tree (format t "~&tree-type: ~s" tree-type))
    (when passed-path (format t "~&path: ~s" path))
    (when passed-goto (format t "~&goto: ~s" goto))
    (format t "~2&supplied-name-string: ~s" supplied-name-string)
    (format t "~&function-name: ~s" function-name)
    (format t "~&function-package: ~s" function-package)
    (format t "~&function: ~s" function)
    (format t "~&function-name-changed: ~s" function-name-changed)
    (format t "~2&selected-packages: ~s" selected-packages)
    (format t "~&package-selection-changed: ~s" package-selection-changed)
    |#


    ;; (format t "~5%" )
    ;; (format t "~2%query: ~s" query)
    ;; (format t "~&passed-function-name: ~s" passed-function-name)
    ;; (format t "~&passed-funcspec: ~s" passed-funcspec)
    ;; (format t "~&function-name-changed: ~s" function-name-changed)
    ;; (format t "~&goto: ~s" goto)
    ;; (format t "~&(fboundp *start-function*): ~s" (fboundp *start-function*))
    ;; (format t "~&*selected-packages*: ~s" *selected-packages*)
    ;; (format t "~&*start-function*: ~s" *start-function*)
    ;; (format t "~&tree-type: ~s" tree-type)

    ;;(format t "~&: ~s" )

      #+nil
      (let* ((spec (read-from-string passed-funcspec))
	     (sources (excl:source-file spec t))
	     (operator (find :operator sources :key #'car))
	     (path (cdr operator)))
	;; (format t "~&spec: ~a"  spec)
	;; (format t "~&sources: ~a"  sources)
	;; (format t "~&length: ~a" (length sources))
	;; (format t "~&operator: ~a"  operator)
	;; (format t "~&path: ~a"  path)
	;; this opens he file, but doesn't go to the function definition
	;;(excl::run-shell-command (format nil "open ~a" path))
	;; better to call via swank::eval-in-emacs
	(open-file-at-position spec))


      ;; https://www.reddit.com/r/lisp/comments/8jqu5j/how_to_use_swankevalinemacs_in_another_cl_thread/
      ;; (format t "~&passed-funcspec: ~s" passed-funcspec)

    (setf *package-selection-changed* package-selection-changed)

    (unless passed-function-name
      (setf *selected-packages* selected-packages))

    (when passed-funcspec
      (let* ((spec (read-from-string passed-funcspec)))
	;;(format t "~&spec: ~s" spec)
	(open-file-for-edit spec)))

    (when function-name-changed
      (setf *start-function* function)
      ;; could expand to the current depth
      (setf *callers-tree* nil)
      (setf *callees-tree* nil))

    (when goto
      (setf *start-function* goto)
      (setf *callers-tree* nil)
      (setf *callees-tree* nil))

    (unless (fboundp *start-function*)
      (setf *start-function* nil)
      (setf *fboundp-error-message* (format nil "~a is not a defined function" function-name)))

    (when (or *selected-packages* *start-function*)
      (case tree-type
	(:callers
	 (let* ((caller-node (find-node-by-path (reverse path) *callers-tree*))
		(caller-leafp (or (symbolp caller-node) (null (cdr caller-node))))
		(caller-subtree (when (and caller-node caller-leafp)
				  (cdr (whocalls-tree (if (consp caller-node)
							  (car caller-node)
							  caller-node))))))
	   (when *callers-tree*
	     (set-node-by-path caller-subtree (reverse path) *callers-tree*))))

	(:callees
	 (let* ((callee-node (find-node-by-path (reverse path) *callees-tree*))
		(callee-leafp (or (symbolp callee-node) (null (cdr callee-node))))
		(callee-subtree (when callee-leafp
				  (cdr (callees-tree (if (listp callee-node)
							 (car callee-node)
							 callee-node))))))
	   (when *callees-tree*
	     (set-node-by-path callee-subtree (reverse path) *callees-tree*))))

	(:none )))))


(defun show-xref-info (req ent)
  req ent
  (let ((*package* (find-package :xref-browser))
	;;(*connection* swank::*emacs-connection*)
	)
    (parse-args req)
    (net.aserve:with-http-response (req ent)
      (net.aserve:with-http-body (req ent)
	(net.html.generator:html
	 (:html
	  (:head (:title (:princ "XREF"))
		 ((:meta :charset "utf-8"))
		 #+nil
		 (:script "document.getScroll= function(){
			  if(window.pageYOffset!= undefined){
			  return [pageXOffset, pageYOffset] ;
			  }
			  else{
			  var sx, sy, d= document, r= d.documentElement, b= d.body ;
			  sx= r.scrollLeft || b.scrollLeft || 0	;
			  sy= r.scrollTop || b.scrollTop || 0	;
			  return [sx, sy]			;
			  }
			  }" )
		 ((:style :type "text/css")
		  ;;"table {border: 0px solid black;}"
		  ;; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
		  "div {font-family:sans-serif; padding: 2px 5px;}"
		  ".scroll tr:nth-child(even) {background: #F0F0F0 }"
		  ".scroll tr:nth-child(odd) {background: #FDFBF8 }"


		  ".fname {font-size:10px;font-family:Menlo, Monaco, monospace;line-height: 100%;border-bottom-style: solid;border-bottom-width: 1px; }"
		  ".tree {font-size:10px;font-family:Menlo, Monaco, monospace;line-height: 100%;border-bottom-style: solid;border-bottom-width: 1px; }"
		  ".methods {font-size:10px;font-family:Menlo, Monaco, monospace;line-height: 100%;border-bottom-style: solid;border-bottom-width: 1px;}"
		  ".pkg {font-size:12px;font-family:Menlo, Monaco, monospace;line-height: 100%;}"

		  "div.scroll  { line-height: .9; white-space:nowrap; max-height: 15em; overflow: auto;  }"
		  "a {text-decoration:none;}"
		  ;;"a:link {color:black}"
		  ;;"a:visited {color:black}"
		  "a:hover {color:black}"
		  "a:active {color:green}"

		  ;;"a.open:hover {text-decoration: underline; font-weight: bold;}"
		  "a.open:hover {font-weight: bold;}"
		  "a.goto:hover {font-style: italic;}"
		  "div.scrollable-container { position: relative; width: 552px; padding-top: 1.7em; margin: 40px; border: 1px solid #999; background: #aab; }"
		  "div.scrolling-area { height: 240px; overflow: auto;  }"))

	  ((:body :onload "document.results.newform.focus();")
	   (show-top-level-view *start-function*)
	   (:br)
	   (:princ "xref (:xb)"))))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun start-server (&key (port *default-port*))
  (let ((socket (net.aserve.client::wserver-socket net.aserve:*wserver*)))
    #+nil
    (when socket
      (net.aserve:shutdown :server net.aserve:*wserver* :save-cache nil))
    (unless socket
      (net.aserve:start :port port))
    (let* ((socket (net.aserve.client::wserver-socket net.aserve:*wserver*))
	   (port (acl-socket:local-port socket)))
      port)))


(defun xref-browser (&key (path *aserve-path*) (host *aserve-host*) (port *aserve-port*))
  (let ((port (start-server :port port)))
    (unless (slot-value *WSERVER* 'net.aserve::socket)
      (net.aserve:start :port port))
    (setf xb::*aserve-host* host)
    (setf xb::*aserve-path* path)
    (setf xb::*aserve-port* port)
    (setf xb::*urlbase* (format nil "~&http://~a:~a~a" *aserve-host* *aserve-port* *aserve-path*))
    (net.aserve:publish :path path
			:content-type "text/html"
			:function #'xb::show-xref-info)
    (format t "~&http://~a:~a~a~%" *aserve-host* *aserve-port* *aserve-path*)
    xb::*urlbase*))

(eval-when (:compile-toplevel :execute :load-toplevel)
  (xb::xref-browser))

;;; open the prowser when this file is loaded
(eval-when (:execute)
  (excl::run-shell-command (format nil "open ~a" *urlbase*)))


#|
	    (dev::graph-method 'lrp-display-visits)
	    (dev::graph-method 'execution-assigned-resource-pcf :callers nil)

	    lrp-display-visits

;;;;; problem				;
;;; lrp-load-proposals calls lrp-load-proposals, gui-send-proposal-data, load-proposal-plan-windows ;
;;; it shows no callees			;


	    |#

#||
(whocalls-tree 'SET-GUI-WARNING-MESSAGE 4)
(setf *start-function ''SET-GUI-WARNING-MESSAGE)
(setf *callers-tree* nil)
||#




;;; (open-file-at-position '(METHOD LOAD-PROPOSALS (STRING)))




;;; see
;;; https://franz.com/support/documentation/current/doc/implementation.htm
;;; https://franz.com/support/documentation/current/doc/variables/excl/s_load-source-file-info_s.htm
;;; https://franz.com/support/documentation/current/doc/variables/excl/s_record-source-file-info_s.htm
;;; https://franz.com/support/documentation/current/ansicl/dictentr/functio2.htm

#|
;;; works:				;
	    (SWANK/ALLEGRO::function-source-location (FUNCTION RUN-BATCH-PROCESS
(&REST REST-ARGS &KEY PRINT-LEVEL SOGS-START
SOGS-END OVERRIDES PW-FIRST-ANGLE-SEARCH
SUPPRESS-SCHEDULING SUPPRESS-PW-EXPANSION)))
;; fails:				;
;; it wants a function object, not a list ;
	    (SWANK/ALLEGRO::function-source-location '(FUNCTION RUN-BATCH-PROCESS
(&REST REST-ARGS &KEY PRINT-LEVEL SOGS-START
SOGS-END OVERRIDES PW-FIRST-ANGLE-SEARCH
SUPPRESS-SCHEDULING SUPPRESS-PW-EXPANSION)))

	    (SWANK/ALLEGRO::function-source-location (function GUI-DIALOG-RUN-SCHEDULER))
	    |#


;;; #-noint
;;; (defmethod edit-file ((spec list))
;;;   ;; need package in spec
;;;   ;;(format t "~%spec: ~a" spec)
;;;
;;;   ;; is this test sufficient??
;;;   (when (not (find (car spec) (list 'method 'function)))
;;;     ;; function-source-location wants a function object, if a function
;;;     (setf spec (eval (cons 'function spec))))
;;;
;;;   (let* ((loc (SWANK/ALLEGRO::function-source-location spec)))
;;;     (print loc)
;;;
;;;     (unless (eq (car loc) :error)
;;;       (let* ((location (cdr loc))
;;;	     (path (cadr (assoc :file location)))
;;;	     ;;(position (cadr (assoc :position location)))
;;;	     (offset-rec (assoc :offset location))
;;;	     (position (if offset-rec (1+ (nth 2 offset-rec)) 0))
;;;	     (cmd `(open-file-at-position ,path ,position)))
;;;	(swank::with-connection (cl-user::*connection*)
;;;	  (swank::eval-in-emacs cmd t))))))
;;;
;;; (defmethod edit-file ((spec symbol))
;;;   (edit-file (list spec)))
;;;
;;; (defmethod edit-file ((spec string))
;;;   (edit-file (intern spec)))


#||

;;; operations:
refresh
expand callee
close callee
expand caller
close caller
edit caller
edit start-function
select caller
select callee






;; >>>> on refresh:
;; after callee operation
query: (("node" . "DIAGNOSTIC")
	("path" . "4")
	("fname" . "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW")
	("tree" . "callees"))
passed-function-name: "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW"
passed-funcspec: NIL
function-name-changed: NIL
goto: NIL
(fboundp *start-function*): #<STANDARD-GENERIC-FUNCTION ASSIGN-WINDOW>
*selected-packages*: NIL
*start-function*: ASSIGN-WINDOW
tree-type: :CALLEES


;; after caller operation
query: (("node" . "(METHOD CONSTRAINT-WINDOWS-TO-PLAN-WINDOWS (PLAN-WINDOW-SCHEDULER))")
	("path" . "1 8")
	("fname" . "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW")
	("tree" . "callers"))
passed-function-name: "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW"
passed-funcspec: NIL
function-name-changed: NIL
goto: NIL
(fboundp *start-function*): #<STANDARD-GENERIC-FUNCTION ASSIGN-WINDOW>
*selected-packages*: NIL
*start-function*: ASSIGN-WINDOW
tree-type: :CALLERS



;; >>>> expand callee:
query: (("node" . "DIAGNOSTIC") ("path" . "4")
	("fname" . "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW")
	("tree" . "callees"))
passed-function-name: "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW"
passed-funcspec: NIL
function-name-changed: NIL
goto: NIL
(fboundp *start-function*): #<STANDARD-GENERIC-FUNCTION ASSIGN-WINDOW>
*selected-packages*: NIL
*start-function*: ASSIGN-WINDOW
tree-type: :CALLEES


;; >>>> close callees
query: (("node" . "DIAGNOSTIC") ("path" . "4")
	("fname" . "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW")
	("tree" . "callees"))
passed-function-name: "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW"
passed-funcspec: NIL
function-name-changed: NIL
goto: NIL
(fboundp *start-function*): #<STANDARD-GENERIC-FUNCTION ASSIGN-WINDOW>
*selected-packages*: NIL
*start-function*: ASSIGN-WINDOW
tree-type: :CALLEES



;; >>>> expand callers:
query: (("node" . "(METHOD SET-PLAN-WINDOW (OBSERVATION-BLOCK T T T))")
	("path" . "22")
	("fname" . "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW")
	("tree" . "callers"))
passed-function-name: "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW"
passed-funcspec: NIL
function-name-changed: NIL
goto: NIL
(fboundp *start-function*): #<STANDARD-GENERIC-FUNCTION ASSIGN-WINDOW>
*selected-packages*: NIL
*start-function*: ASSIGN-WINDOW
tree-type: :CALLERS

;; >>>> close callers:
query: (("node" . "(METHOD CONSTRAINT-WINDOWS-TO-PLAN-WINDOWS (OBSERVATION-BLOCK))")
	("path" . "8")
	("fname" . "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW")
	("tree" . "callers"))
passed-function-name: "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW"
passed-funcspec: NIL
function-name-changed: NIL
goto: NIL
(fboundp *start-function*): #<STANDARD-GENERIC-FUNCTION ASSIGN-WINDOW>
*selected-packages*: NIL
*start-function*: ASSIGN-WINDOW
tree-type: :CALLERS

query: (("node" . "(METHOD CONSTRAINT-WINDOWS-TO-PLAN-WINDOWS            (PLAN-WINDOW-SCHEDULER))")
	("path" . "1 1 8")
	("fname" . "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW")
	("tree" . "callers"))
passed-function-name: "SPIKE.GENERIC.SCHEDULER::ASSIGN-WINDOW"
passed-funcspec: NIL
function-name-changed: NIL
goto: NIL
(fboundp *start-function*): #<STANDARD-GENERIC-FUNCTION ASSIGN-WINDOW>
*selected-packages*: NIL
*start-function*: ASSIGN-WINDOW
tree-type: :CALLERS

||#
