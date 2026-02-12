;;; todo:
;;; edit method is not going to the form, just the file
;;; cleanup so only desired, pedictable things happen. eg. ...
;;;   don't open a file unless that is what is requested
;;;   don't change class when opening a file
;;; fix the scrolling problem
;;; provide slot information, like setter and getter method names, initarg name, expand inline?
;;; when a slot is clicked, display methods that use / call the slot


#-aserveb*inf
(eval-when (:compile-toplevel :execute :load-toplevel)
  (require :aserve))

(excl:without-redefinition-warnings
  (defvar cl-user::*context-package*))

;;; try to keep from redefining the *context-package* if the code is recompiled
(eval-when (:compile-toplevel :execute :load-toplevel)
  (setf cl-user::*context-package* *package*))

(eval-when (:compile-toplevel :execute :load-toplevel)
  (unless (find-package :class-browser)
    (let ((current (package-name cl-user::*context-package*))
	  (used (mapcar #'package-name (package-use-list *package*))))
      (excl::defpackage-1 :class-browser
	  `((:use :common-lisp ,current ,@used)
	    (:nicknames "CLBR")
	    (:shadow #:start #:until #:exit)))))
  (in-package :class-browser))



;; CLBR> (describe *package*)
;; #<The CLASS-BROWSER package> is the package named CLASS-BROWSER.
;; It has nickname: CLBR.
;; It has 0 external symbols, 254 internal symbols, and shadows 3 names.
;; It uses packages: NET.ASERVE, NET.HTML.GENERATOR, COMMON-LISP-USER,
;;   COMMON-LISP, EXCL.
;; ; No value
;; CLBR>



(defconstant nw-arrow "&#8598")
(defconstant ne-arrow "&#8599")
(defconstant se-arrow "&#8600")
(defconstant sw-arrow "&#8601")
(defconstant up-arrow "&#8593")
(defconstant down-arrow "&#8595")
(defconstant at-sign "&#64")
(defconstant less-than "&#60")
(defconstant greateer-than "&#62")

;;; (defvar *context-package* cl-user::*context-package*)
(defvar *aserve-host* "localhost")
(defvar *aserve-path* "/clbr")
(defvar *aserve-port* 8040)
(defvar *urlbase* (format nil "http://~a:~a~a" *aserve-host* *aserve-port* *aserve-path*))
(defvar *default-port* 8040)
(defvar *include-system-classes* nil)
(defvar *show-methods* :superclasses) ; :subclasses

;;; maybe separate out utilities, common-lisp, & mop  so they can be selectively enabled???
(defparameter *system-packages* '(:acl-socket
				  :aclmop
				  :chandra-gui
				  ;; :assist
				  :asdf
				  :babel
				  :babel-encodings
				  :bordeaux-threads
				  :buffy
				  :cffi
				  :class-browser
				  :common-lisp
				  :compiler
				  :cross-reference
				  :dbi
				  :defsystem
				  :develop
				  :foreign-functions
				  :ga
				  :it
				  :lep
				  :lparallel
				  :lparallel.kernel
				  :lparallel.ptree
				  :mop
				  :multiprocessing
				  :net
				  :net.uri
				  :profiler
				  :regexp
				  :swank-macrostep
				  :swank
				  :test
				  :uiop
				  :util
				  :utilities))


;;; this is a subset of *system-packages*
(defparameter *optional-packages* '(:common-lisp
				    :mop
				    :common-lisp-user
				    :cl-user
				    :climif
				    :climif2-package))

;;; this is a subset of *optional-packages*
(defparameter *selected-packages* '(:common-lisp))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defparameter *form-method* "get")
(defvar *error-no-class* nil)

(defvar *current-class* nil)
(defvar *subclass-tree* nil)

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


(defun reset-clbr ()
  )

(defun init ()
  (declare (special *context-package* cl-user::*context-package*))
  (setf *context-package* cl-user::*context-package*)
  (setf *aserve-host* "localhost")
  (setf *aserve-path* "/clbr")
  ;;(setf *aserve-port* 8040)
  ;;(setf *urlbase* (format nil "http://~a:~a~a" *aserve-host* *aserve-port* *aserve-path*))
  (setf *current-class* nil)
  (setf *subclass-tree* nil))



(defun accessor (path target)
  (let ((nodes `',target))
    (dolist (index path)
      (setf nodes `(nth ,index (cdr ,nodes))))
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



(defun as-class (class)
  (cond ((symbolp class) (get-class class))
	((stringp class)
	 (get-class (intern (string-upcase class))))
	((typep class 'class) class)
	(t nil)))

;;; need to test for limit?
(defmethod transitive-closure (function set)
  (let ((immediate (ignore-errors (mapcar function set))))
    (remove-duplicates
     (apply #'append immediate (mapcar #'(lambda (c)
					   (transitive-closure function c))
				       immediate)))))

;;; remove classes T and STANDARD-OBJECT
(defun prune-classes (classes)
  (if *include-system-classes*
   classes
   (remove-duplicates
    (remove (find-class t)
	    (remove (find-class 'standard-object)
		    classes)))))

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

(excl:without-redefinition-warnings
  (defun mission ()
    (let* ((package-name (package-name cl-user::*context-package*))
	   (dot1 (position #\. package-name))
	   (dot2 (when dot1 (position #\. package-name :start (1+ dot1)))))
      (when dot2
	(intern (subseq package-name (1+ dot1) dot2) :keyword)))))

(defun mission-packages ()
  (let ((mission (mission)))
    (case mission
      (:roman  *roman-packages*)
      (:hst  *hst-packages*)
      (:jwst *jwst-packages*)
      (t nil))))


;;; optional packages whose checkbox is checked
(defun selected-package-p (package)
  (not (null (and (find (std-package package) (append (mission-packages) *optional-packages*))
		  (find (std-package package) *selected-packages*)))))


;;; packages denoted as system packages (i.e. not necessarily shown)
(defun system-package-p (package)
  (not (null (find (std-package package) (append (mission-packages) *system-packages*)))))


;;; test whether to show classes in the package
(defmethod restricted-package-p (package)
  (if (system-package-p package)
      (not (selected-package-p package))
      nil))

(defmethod restricted-package-p ((package-name (eql :aclmop)))
  (restricted-package-p :mop))


(defmethod restricted-method-p (method)
  (let ((package-name (intern (package-name (symbol-package method)) :keyword)))
    (system-package-p package-name)))


;;; filter out methods in system packages
(defun prune-system-methods (methods)
  (remove-if #'(lambda (method)
		 (let ((name (mop:generic-function-name (mop:method-generic-function method))))
		   (cond ((consp name)
			  (restricted-method-p (cadr name)))
			 (t
			  (restricted-method-p name)))))
	     methods))

;;; xref::object-to-function-name:
;;; extract the function name from the function object, as in
;;;         (function-name #'car) ==> 'car

(defmethod method-spec ((method method))
  (xref::object-to-function-name method))

(defmethod method-name ((method method))
  (mop:generic-function-name (mop:method-generic-function method)))



(defun class-slot-value (class slot-name)
  "Returns the value of a class-allocated slot, using the class"
  (unless (typep class 'class)
    (setq class (get-class class)))
  (when class
    (let* ((slot-list (mop::class-slots class))
	   (slot (find-if #'(lambda (a) (eql (mop:slot-definition-name a) slot-name)) slot-list)))
      (when slot
	(let ((location (mop:slot-definition-location slot)))
	  (when (listp location)
	    (cdr location)))))))

(defun instance-values (inst)
  "returns a slot-name - value plist"
  (let ((slot-names (mapcar #'mop:slot-definition-name
			    (mop:class-slots (class-of inst)))))
    (mapcan #'(lambda (slot-name)
		(list (intern slot-name :keyword)
		      (if (slot-boundp inst slot-name)
			  (slot-value inst slot-name)
			  "<unbound>")))
	    slot-names)))



;;; todo: should order the resulting list?
(defmethod direct-superclasses ((class excl::std-class)) ; was standard-class
  (unless (mop:class-finalized-p class)
    (mop:finalize-inheritance class))
  (mop:class-direct-superclasses class))

(defmethod direct-superclasses ((class symbol))
  (direct-superclasses (get-class class)))

(defmethod direct-superclasses ((class string))
  (direct-superclasses (get-class (intern (string-upcase class)))))

(defmethod direct-superclasses ((thing (eql nil)))
  (list))

(defmethod direct-superclasses ((thing t))
  nil)


;;; return nested lists?
(defun all-superclasses (class)
  (reverse (cdr (precedence-list class))))

(defun precedence-list (class)
  (let ((class-object (as-class class)))
    (when class-object
      (mop:class-precedence-list class-object)
      #+nil
      (remove (find-class t)
	      (cdr (mop:class-precedence-list class-object))))))

;;; (class excl::std-class)
(defmethod direct-subclasses ((class class)) ; was standard-class
  ;; spike has an issue with a forward reference class
  (ignore-errors
    (unless (mop:class-finalized-p class)
      (mop:finalize-inheritance class)))
    (mop:class-direct-subclasses class))

(defmethod direct-subclasses ((class symbol))
  (let ((class-object (get-class class)))
    (when class-object
      (direct-subclasses class-object))))

(defmethod direct-subclasses ((class string))
  (let ((class-object (get-class (intern (string-upcase class)))))
    (when class-object
      (direct-subclasses class-object))))

(defmethod direct-subclasses ((thing (eql nil)))
  (list))

(defmethod direct-subclasses ((class t))
  (let ((class-object (get-class class)))
    (when class-object
      (direct-subclasses class-object)))
  #+nil
  (format t "~% CALLED DIRECT-SUBCLASSES WITH ~s of type ~s~%" thing (type-of thing)))


;;; return nested lists? ; :flat argument
(defun all-subclasses (class)
  (prune-classes (apply #'append (transitive-closure #'direct-subclasses (list class)))))

(defun subclass-tree (class)
  (cons (as-class class)
	(sort (copy-list (mapcar #'(lambda (c)
				     (subclass-tree c))
				 (direct-subclasses class)))
	      #'alpha-lessp)))

(defmethod direct-slots ((class class))
  (unless (mop:class-finalized-p class)
    (mop:finalize-inheritance class))
  (mop:class-direct-slots class))

(defmethod direct-slots ((class t))
  nil)

(defun all-slots (class)
  (let ((classes (cons class (all-superclasses class))))
    (when classes
      (remove-duplicates (apply #'append (mapcar #'direct-slots classes))
			 :key #'mop::slot-definition-name))))


(defmethod direct-methods ((class class))
  (apply #'append (slot-value class 'excl::direct-methods)))

;;; for superclasses
(defmethod applicable-superclasses-methods ((class class))
  (unless (mop:class-finalized-p class)
    (mop:finalize-inheritance class))
  (let ((classes (remove (find-class t) (mop:class-precedence-list class))))
    (apply #'append (mapcar #'direct-methods classes))))

;;; for subclasses
(defmethod applicable-subclasses-methods ((class class))
  (let ((classes (all-subclasses class)))
    (apply #'append (mapcar #'direct-methods classes))))


;;; standard-class fails for ACLMOP:FUNCALLABLE-STANDARD-CLASS
(defmethod applicable-methods ((class class))
  (case *show-methods*
    (:superclasses
     (applicable-superclasses-methods class))
    (:subclasses
     (applicable-subclasses-methods class))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun radio-option (label name value var &optional style)
  (html ((:td :if* style :style style)
	 (:div (:label ((:input :type "radio"
				:name name
				:value value
				:if* var :checked t)
			(format *html-stream* "~a" label)))))))

(defun cbox-option (label name value var)
  (html (:td (:label ((:input :type "checkbox"
			      :name name
			      :value value
			      :if* var :checked t)
		      (format *html-stream* "~a" label))))))

(defun cbox-collection-option (label name value collection)
  (html (:label ((:input :type "checkbox"
			 :name name
			 :value value
			 :if* (find label collection) :checked t)
		 (format *html-stream* "~a" label)))))

(defmacro form-cbox-option (form label name test &optional style)
  (let ((submit-fn (format nil "document.getElementById('~a').submit();" form)))
    `(html ((:td :if* ,style :style ,style)
	    (:span (:label ((:input :type "checkbox"
				   :name ,name
				   :value ,label
				   :onclick ,submit-fn
				   :if* ,test :checked t)
			   (:princ-safe ,label))))))))



#-noint
(defmethod edit-function (spec)
  (when (not (find (car spec) (list 'method 'function)))
    ;; function-source-location wants a function object, if a function
    (setf spec (eval (cons 'function spec))))
  ;;(let* ((loc (SWANK/ALLEGRO::function-source-location spec)))
  (let ((loc (SWANK/ALLEGRO::find-source-location spec)))
    (cond ((eq (car loc) :error)
	   (format t "~%Can't open file, loc: ~a" loc))
	  (t
	   (let* ((location (cdr loc))
		  (path (cadr (assoc :file location)))
		  ;;(position (cadr (assoc :position location)))
		  (offset-rec (assoc :offset location))
		  (position (if offset-rec (1+ (nth 2 offset-rec)) 0))
		  (cmd `(open-file-at-position ,path ,position)))
	     (swank::with-connection (cl-user::*connection*)
	       (swank::eval-in-emacs cmd t)))))))

#-noint
(defmethod edit-function ((spec symbol))
  (edit-function (list spec)))

#-noint
(defmethod edit-function ((spec string))
  ;; (intern spec) causes an error when spec = "(METHOD CATALOG (CATALOG-MIXIN))"
  (edit-function (read-from-string spec)))


(defmethod edit-class ((class-name symbol))
  (let* ((loc (swank::find-source-location class-name)))
    (cond ((eq (car loc) :error)
	   (format t "~%Can't open file, loc: ~a" loc))
	  (t
	   (let* ((location (cdr loc))
		  (path (cadr (assoc :file location)))
		  (offset-rec (assoc :offset location))
		  (position (if offset-rec (1+ (nth 2 offset-rec)) 0))
		  (cmd `(open-file-at-position ,path ,position)))
	     (swank::with-connection (cl-user::*connection*)
	       (swank::eval-in-emacs cmd t)))))))




#+nil(defun edit-function (pathname)
  (let ((command-string (format nil "open -a aquamacs ~a " pathname)))
    (ensure-directories-exist pathname)
    (excl.osi:command-output command-string)))

#+nil
;;; It would be nice to go to the location in the file
(defmethod display-method-file-link ((method t) (class-name t))
  (let* ((gf (mop:method-generic-function method))
	 (name (mop:generic-function-name gf))
	 (method-signature (method-signature method))
	 (direct-methods (direct-methods (as-class class-name)))
	 ;; (package (cond ((symbolp name)
	 ;;              (symbol-package name))
	 ;;             ((consp name)
	 ;;              (symbol-package (cadr name)))
	 ;;             (t :cl-user)))
	 ;;(package-name (package-name package))
	 ;; no source-path is available for system functions
	 (path (ignore-errors (excl::source-file method-signature :operator)))
	 (bold-p (find method direct-methods)))

    (let ((name-string (string-downcase (princ-to-string name))))

      (setq spec (method-spec method))

      (let ( ;;(url (format nil "~a?edit=~s" *urlbase* path))
	    ;;(url (format nil "~a?edit=~a" *urlbase* name-string))
	    (url (format nil "~a?edit=~a" *urlbase* path)))
	    ;;(url (format nil "~a?edit=~a" *urlbase* spec)))
	url bold-p
	(format t "~&path: ~s" path)
	(format t "~&spec: ~s" spec)
	(if path
	    (html (:br)
		  ((:span :class "method")
		   #+nil
		   ((:a ;;:class "source"
		     ;;:style "color: black;"
		     :href url
		     :title "Edit method definition"
		     :if* bold-p :style "font-weight: bold;")
		    (format *html-stream* "~a&nbsp" at-sign))

		   (format *html-stream* "~a " name-string)

		   ;; have this open an xref page??
		   ;;#+nil
		   ((:a :href url
			:title "Edit method definition"
			:if* bold-p :style "font-weight: bold;" )
		    (format *html-stream* "~a " name-string))
		   ))
	    (if bold-p
		(html (:br)
		      (:b (format *html-stream* "~a " name-string)))
		(html (:br)
		      (format *html-stream* "~a " name-string))))))))

(defmethod display-method-file-link ((method t) (class-name t))
  (let* ((gf (mop:method-generic-function method))
	 (name (mop:generic-function-name gf))
	 (method-signature (method-signature method))
	 (direct-methods (direct-methods (as-class class-name)))
	 ;; (package (cond ((symbolp name)
	 ;;              (symbol-package name))
	 ;;             ((consp name)
	 ;;              (symbol-package (cadr name)))
	 ;;             (t :cl-user)))
	 ;;(package-name (package-name package))
	 ;; NOTE: ignore-errors because no source-path is available for system functions
	 (path (ignore-errors (excl::source-file method-signature :operator)))
	 (direct-p (find method direct-methods))
	 (bold-p direct-p)
	 (name-string (string-downcase (princ-to-string name)))
	 (spec (method-spec method))
	 (url (format nil "~a?editfun=~a" *urlbase* (princ-to-string spec))))

    (when t ;;direct-p
    (html (if path
	      (html
	       ((:span :class "method")
		((:a :href url
		     :title "Edit method definition"
		     :if* bold-p :style "font-weight: bold;")
		 (format *html-stream* "~a " name-string))))
	      ;; no source-path is available for system functions
	      (if bold-p
		  (html (:b (format *html-stream* "~a " name-string)))
		  (html (format *html-stream* "~a " name-string))))))))


(defmethod display-class-file-link ((class-name symbol) &optional (font-size 12))
  (let* ((name-string (string-upcase (princ-to-string class-name)))
	 (path (ignore-errors (excl::source-file (get-class class-name) :operator)))
	 (url (format nil "~a?editclass=~a" *urlbase* (intern class-name))))
    (if path
	(html (:br)
	      ((:span :class "class")
	       ((:a :href url :title "Edit class definition"
		    :style (format nil "font-size: ~dpx; font-family:menlo, monospace; font-weight: bold;" font-size))
		(format *html-stream* "~a " name-string))))
	(html (:br)
	      ((:span :style (format nil "font-size: ~dpx; font-family:monospace; font-weight: bold;" font-size))
	       (format *html-stream* "~a " name-string))))))




#+nil
(defmethod display-class-link ((class symbol) &key bold package-p)
  (let* ((package (package-name (symbol-package class)))
	 (url (format nil "~a?class=~a::~a" *urlbase* package (symbol-name class))))


    (html
     ((:a :href url
	  :if* bold :style "font-weight: bold; font-family: menlo;"
	  :if* (not bold) :style "font-weight: normal; font-family: menlo;")
      ;;(format *html-stream* "~a ~:[~;(~a)~]" class package-p package)
      (format *html-stream* "~a" class))


     ((:span :style "font-size: 10px;")
      (format *html-stream* "   ~:[~;&nbsp&nbsp:~a~]" package-p package)))))


(defmethod display-class-link-and-package ((class symbol) &key bold package-p)
  (let* ((package (package-name (symbol-package class))))
    (html
     (display-class-link class :bold bold)
     ((:span :style "font-size: 10px;")
      (format *html-stream* "   ~:[~;&nbsp&nbsp:~a~]" package-p package)))))

(defmethod display-class-link ((class symbol) &key bold)
  (let* ((package (package-name (symbol-package class)))
	 (url (format nil "~a?class=~a::~a" *urlbase* package (symbol-name class))))
    (html
     ((:a :href url
	  :if* bold :style "font-weight: bold; font-family: menlo;"
	  :if* (not bold) :style "font-weight: normal; font-family: menlo;")
      (format *html-stream* "~a" class)))))

(defmethod display-class-link ((class (eql nil)) &key bold package-p)
  (declare (ignore package-p bold)))

;;; to catch defaults for key and optional args
(defmethod display-class-link ((class t) &key bold package-p)
  bold package-p
  (format *html-stream* "~a" class))





(defun display-superclasses (class-name)
  (let ((direct-superclasses (direct-superclasses class-name))
	(all-superclasses (all-superclasses class-name)))
    (html
     (dolist (sclass all-superclasses)
       (let* ((direct (find sclass direct-superclasses))
	      (class-name (class-name sclass))
	      ;; do this for subclasses, too??
	      ;;(url (format nil "~a?class=~a::~a" *urlbase* (package-name (symbol-package class-name)) (symbol-name class-name)))
	      ;;(bold (not (null direct)))
	      )

	 (if (eql class-name 'T)
	     (html (:princ class-name))
	     (display-class-link class-name :bold (not (null direct))))
	 (html (:br)))))))


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

(defun package-restricted-tree-p (tree)
  (setq *tree tree)
  (when tree
    (let* ((class (car tree))
	   (package (symbol-package (class-name class)))
	   (package-name (intern (package-name package) :keyword))
	   (restricted
	     (not (null (and (restricted-package-p package-name)
			     (every #'package-restricted-tree-p (cdr tree)))))))
      restricted)))

(defun display-subclass-tree (tree &optional (depth 0))
  (when tree
    (html
     (let* ( (class (car tree))
	     (package (symbol-package (class-name class)))
	     (package-name (intern (package-name package) :keyword))
	     )
       package-name  package class

       ;; This should restrict ONLY if the tree has only restricted packages
       (unless (package-restricted-tree-p tree)

	 ;; indent
	 (dotimes (i depth)
	   (if (evenp i)
	       (if (< i (1- depth))
		   (html (:princ "&nbsp.&nbsp"))
		   (html (:princ "&nbsp&nbsp&nbsp")))
	       (html (:princ "&nbsp&nbsp&nbsp"))))

	 (display-class-link-and-package (class-name (car tree)) :bold (= depth 0))
	 (html (:br))
	 (dolist (stree (cdr tree))
	   (display-subclass-tree stree (1+ depth))))))))



(defmethod display-subclasses (class)
  (let ((subclasses (subclass-tree class)))
    ;; why?
    (setf *subclass-tree* subclasses)
    (dolist (stree (cdr subclasses))
       (display-subclass-tree stree 0))))

(defmethod display-subclasses ((class standard-object)))


(defun slot-class (slot classes)
  (dolist (cl classes)
    (let* ((cl-slots (direct-slots cl))
	   (slot-cl (find slot cl-slots)))
      (when slot-cl
	(return-from slot-class cl)))))


(defun display-slots (class-name)
  (let ((class-object (as-class class-name)))
    (when class-object
      (let* ((all-slots (all-slots class-object))
	     (direct-slots (direct-slots class-object))
	     (sorted-slots (sort (copy-list all-slots) #'alpha-lessp :key #'mop:slot-definition-name)))
	(dolist (slot sorted-slots)
	  (let* ((direct-slot (find slot direct-slots))
		 (slot-class (slot-class slot (cdr (precedence-list class-object))))
		 (slot-class-name (when slot-class (class-name slot-class)))
		 (name (string-downcase (mop::slot-definition-name slot))))

	    (if direct-slot
		(html
		 (:b (format *html-stream* "~a" name)))
		(html
		 (format *html-stream* "~a [" name)
		 (display-class-link slot-class-name)
		 (format *html-stream* "]" )))
	    (html (:br))))))))


(defun m-key (method)
  (flet ((m-name (x)
	   (mop:generic-function-name (mop:method-generic-function x)))
	 (m-lambda-list (x)
	   (mop::method-lambda-list x)))
    (let ((m-name (m-name method))
	  (m-ll (m-lambda-list method)))
      (cond ((and (consp m-name) (eq (car m-name) 'setf))
	     (cons (format nil "~a--" (cadr m-name)) m-ll))
	    (t (cons m-name m-ll))))))

(defun method-sort-predicate (m1 m2)
  ;; args are method objects
  (let* ((m1-key (m-key m1))
	 (m2-key (m-key m2)))
    (string< (princ-to-string m1-key) (princ-to-string m2-key))
    #+nil(alpha-lessp m1-key m2-key)))


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
				    (cond (in-optionals )
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

(defun present-accessor-method (class-name slot-name method)
  (when method
    (let* ((lambda-list (mop::method-lambda-list method))
	   (qualifiers (method-qualifiers method))
	   (ll-length (length lambda-list))
	   (accessor-p (typep method 'mop::standard-accessor-method))
	   (opt nil))


      (html (:br))
      (format *html-stream* "~%~(~s~) -  " (intern slot-name))

      ;; method name ;;;;;;;;;;;;;;;;;;;;;;;;;;
      (display-method-file-link method class-name)

      ;; qualifier ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      (when qualifiers
	(format *html-stream* "~(~s~) " (car qualifiers)))

      ;; lambda list ;;;;;;;;;;;;;;;;;;;;;;;;;;
      (format *html-stream* "(")
      (dotimes (i ll-length)
	(let ((x (nth i lambda-list)))


	  (when accessor-p
	    (when (and (typep method 'mop::standard-reader-method) (= i 0))
	      (setf x (list x x)))
	    (when (and (typep method 'mop::standard-writer-method) (= i 1))
	      (setf x (list x x))))

	  (cond ((equal (aref (princ-to-string x) 0) #\&) ; &key, &optional
		 (setf opt t)
		 (html
		  (:i (format *html-stream* "~a"  (string-downcase x)))))

		((and (listp x) opt)
		 (format *html-stream* "~a"  (string-downcase (princ-to-string x))))

		((listp x)
		 (format *html-stream* "(~a " (string-downcase (car x)))
		 (display-class-link (cadr x))
		 (format *html-stream* ")" ))

		(opt
		 (format *html-stream* "~a"  (list (string-downcase (princ-to-string x)) "NIL")))

		(t (format *html-stream* "(~a "  (string-downcase x))
		   (display-class-link 'T)
		   (format *html-stream* ")" )))

	  (when (< i (1- ll-length))
	    (format *html-stream* " "))))


      (format *html-stream* ")"))))


(defun present-general-method (class-name method)
  (let* ((lambda-list (when method (mop::method-lambda-list method)))
	 (qualifiers (method-qualifiers method))
	 (ll-length (length lambda-list))
	 (accessor-p (typep method 'mop::standard-accessor-method))
	 (opt nil))

    ;; method name ;;;;;;;;;;;;;;;;;;;;;;;;;;
    (html (:br))
    (display-method-file-link method class-name)

    ;; qualifier ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (when qualifiers
      (format *html-stream* "~(~s~) " (car qualifiers)))

    ;; lambda list ;;;;;;;;;;;;;;;;;;;;;;;;;;
    (format *html-stream* "(")
    (dotimes (i ll-length)
      (let ((x (nth i lambda-list)))

	(when accessor-p
	  (when (and (typep method 'mop::standard-reader-method) (= i 0))
	    (setf x (list x x)))
	  (when (and (typep method 'mop::standard-writer-method) (= i 1))
	    (setf x (list x x))))

	(cond ((equal (aref (princ-to-string x) 0) #\&) ; &key, &optional
	       (setf opt t)
	       (html
		(:i (format *html-stream* "~a"  (string-downcase x)))))

	      ((and (listp x) opt)
	       (format *html-stream* "~a"  (string-downcase (princ-to-string x))))

	      ((listp x)
	       (format *html-stream* "(~a " (string-downcase (car x)))
	       (display-class-link (cadr x))
	       (format *html-stream* ")" ))

	      (opt
	       (format *html-stream* "~a"  (list (string-downcase (princ-to-string x)) "NIL")))

	      (t (format *html-stream* "(~a "  (string-downcase x))
		 (display-class-link 'T)
		 (format *html-stream* ")" )))

	(when (< i (1- ll-length))
	  (format *html-stream* " "))))
    (format *html-stream* ")")))



(defmethod slot-methods (class-name methods)
  (let* ((class (find-class (intern class-name *context-package*)))
	 (slots (mop:class-direct-slots class))
	 (reader-slots (list))
	 (writer-slots (list)))

    (dolist (slot slots)
      (let* ((name (mop::slot-definition-name slot))
	     ;;(type (mop:slot-definition-type slot))
	     (reader-names (mop:slot-definition-readers slot))
	     (writer-names (mop:slot-definition-writers slot))
	     (readers (mapcar (lambda (name)
				(find name methods :key #'method-name))
			      reader-names))
	     (writers (mapcar (lambda (name)
				(find name methods :key #'method-name :test #'equalp))
			      writer-names)))
	(push (cons name readers) reader-slots)
	(push (cons name writers) writer-slots)))

      (list reader-slots writer-slots)))



(defmethod collect-methods (class-name)
  (let* ((class-object (as-class class-name))
	 (applicable-methods (when class-object (applicable-methods class-object))))
    (when applicable-methods
      (let* ((all-methods (remove-duplicates (prune-system-methods (applicable-methods (as-class class-name)))
					     :key #'m-key
					     :test #'equalp))
	     (accessor-methods (mapcan (lambda (m) (when (typep m 'mop::standard-accessor-method)
						     (list m)))
				       all-methods))
	     (general-methods (set-difference all-methods accessor-methods :test #'equalp))
	     (sorted-general-methods (sort general-methods #'method-sort-predicate))
	     (sorted-accessor-methods (sort (copy-list accessor-methods) #'method-sort-predicate))
	     (direct-methods (direct-methods (as-class class-name)))
	     (direct-accessor-methods (intersection direct-methods sorted-accessor-methods))
	     (direct-accessor-slot-methods (slot-methods class-name direct-accessor-methods))
	     (accessor-slot-methods (slot-methods class-name accessor-methods)))

	;;(values sorted-general-methods accessor-slot-methods)
	(values sorted-general-methods direct-accessor-slot-methods)))))


(defun display-methods (class-name)
  (multiple-value-bind (sorted-general-methods direct-accessor-slots)
      (collect-methods class-name)
    (destructuring-bind (readers writers) direct-accessor-slots

      (let ((direct-accessor-methods
	      (sort (append (copy-list readers) (copy-list writers)) #'alpha-lessp :key (lambda (x) (princ-to-string (intern  (car x)))))))

	(cond ((null direct-accessor-methods)
	       (html
		((:div :style "font-weight: bold;font-size: 13px;")
		 (format *html-stream* "No direct accessors or mutators for ~a" class-name))))
	      (t
	       (html
		((:div :style "font-weight: bold;font-size: 13px;")
		 (format *html-stream* "Class direct accessors and mutators of ~a" class-name)))

	       (dolist (method-spec direct-accessor-methods)
		 (cond ((null (cdr method-spec))
			;;(format t "~2%NOTE: method-spec in direct-accessor-methods is: ~a" method-spec)
			)
		       (t

		   (destructuring-bind (slot-name method) method-spec
		     (present-accessor-method class-name slot-name method)

		     ;; accessor annotations ;;;;;;;;;;;;;;;;;;;;;;;;;;
		     (when (or (typep method 'mop::standard-accessor-method)
			       (typep method 'mop::standard-reader-method)
			       (typep method 'mop::standard-writer-method))

		       (cond ((typep method 'mop::standard-reader-method)
			      (format *html-stream* "&nbsp&nbsp[" )
			      (html (:i (format *html-stream* "reader method" )))
			      (format *html-stream* " ]"))

			     ((typep method 'mop::standard-writer-method)
			      (format *html-stream* "&nbsp&nbsp[" )
			      (html (:i (format *html-stream* "writer method" )))
			      (format *html-stream* " ]"))

			     ((typep method 'mop::standard-accessor-method)
			      (format *html-stream* "&nbsp&nbsp[" )
			      (html (:i (format *html-stream* "accessor method" )))
			      (format *html-stream* " ]"))))))))))

	;; ;;;;;;;;;;;;;;

	;; Methods that accept an argument of type class-name
	(when (eq *show-methods* :superclasses)
	  (html
	   ((:div :style "font-weight: bold;font-size: 13px;")
	    (:br *html-stream* )
	    (format *html-stream* "Methods that accept an argument of type: ~a" class-name)))
	  (dolist (method sorted-general-methods)
	    (present-general-method class-name method)))))))


(defmethod display-header ((class-name symbol))
  (let ((package (symbol-package class-name)))
    (html
     (display-class-file-link class-name 14)
     ((:span :style "font-size: 12px; font-family:menlo, monospace;")
      (format *html-stream* " (:~a)" (package-name package))))))


;;; This is the top-level function
(defmethod display-browser ((class-name symbol))
  (display-header class-name)
  (html
   (:div
    (:table
     ;; labels row
     (:tr
      (:th (format *html-stream* "Precedence List"))
      (:th (format *html-stream* "Slots"))
      (:th (format *html-stream* "Subclasses")))

     ;; class info
     (:tr
      (:td (display-superclasses class-name))
      ((:td :style "font-family:menlo, monospace;") (display-slots class-name))
      (:td (display-subclasses class-name)))

     ;; method info
     (:tr
      ((:td :colspan "3")
       ((:div :id "container" )
	(display-methods class-name))))

    ;; package selection
    ((:tr :style "padding: 0;")
     ((:td :colspan "3" :style "padding: 0;")
      ((:form :id "pselection"
		  :action (format nil "http://~a:~s~a" *aserve-host* *aserve-port* *aserve-path* )
		  :method *form-method*)
       ((:table :style "border: none; border-collapse: collapse;")
	((:tr :style "padding: 0;")
	 (dolist (package (append (mission-packages) *optional-packages*))
	   (html
	    (form-cbox-option "pselection" package "selected-package"
			      (find package *selected-packages*)
			      "border:none; padding-left:2; padding-right:2;"))))))))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; utilities

(defun string->symbol (sym-name)
  (let* ((index (position #\: sym-name))
	 (index2 (position #\: sym-name :from-end t))
	 (sym (if index2
		  (subseq sym-name (1+ index2))
		  sym-name))
	 (pkg (when index (subseq sym-name 0 index))))
    (if pkg
	(intern sym pkg)
	(intern sym)))
  )

(defun string->class (sym-name)
  (let ((symbol (string->symbol sym-name)))
    (when symbol
      (get-class symbol))))

(defun parse-package-args (args)
  (collect-args "selected-package" args :return :keyword))


;;; collect values of an arg specified multiple times, as in checkbox values
(defun collect-args (arg-name args &key (return :string))
  (let ((values (list)))
    (dolist (arg-spec args)
      (when (equal arg-name (car arg-spec))
	(let ((val (cdr arg-spec)))
	  (push (case return
		  (:intern (intern (string-upcase val)))
		  (:keyword (intern (string-upcase val) :keyword))
		  (:integer (parse-integer val))
		  (:string val)
		  (t nil))
		values))))
    values))


#-noint
(defmethod edit-file ((spec list))
  (when (= (length spec) 1)
    (setf spec (eval (cons 'function spec))))
  (let* ((loc (SWANK/ALLEGRO::function-source-location spec)))
    (unless (eq (car loc) :error)
      (let* ((location (cdr loc))
	     (path (cadr (assoc :file location)))
	     (position (cadr (assoc :position location)))
	     (cmd `(open-file-at-position ,path ,position)))
	(swank::with-connection (cl-user::*connection*)
	  (swank::eval-in-emacs cmd t))))))

(defmethod edit-file ((spec symbol))
  (edit-file (list spec)))

(defmethod edit-file ((spec string))
  (edit-file (intern spec)))



(defmethod find-class-in-package ((class string) (package package))
  (multiple-value-bind (symbol status)
      (find-symbol (string-upcase class) package)
    (when symbol
      (values
       (find-class (intern (string-upcase class) (find-package package)) nil)
       package
       status))))

(defmethod find-class-in-package ((class string) (pkg symbol))
  (let ((package (find-package pkg)))
    (cond (package
	   (find-class-in-package class package))
	  (t (warn "~a is not a known package" pkg)))))


(defmethod find-class-in-package ((class string) (pkgs list))
  (dolist (pkg pkgs)
    (multiple-value-bind (symbol package status)
	(find-class-in-package class pkg)
      (when symbol (return-from find-class-in-package (values symbol package status))))))

#+nil
(defmethod find-class-in-package ((class string) (pkgs list))
  (let ((collected (list)))
    (dolist (pkg pkgs)
      (multiple-value-bind (symbol package status)
	  (find-class-in-package class pkg)
	(when symbol (push (list symbol package status) collected))))
    collected))

(defmethod get-class ((class string))
  (let ((packages (list-all-packages)))
    (find-class-in-package (string-upcase class) packages)))

(defmethod get-class ((class symbol))
  (let ((packages (list-all-packages)))
    (find-class-in-package (princ-to-string class) packages)))


(defun parse-args (req)
  (let* ((query (request-query req))
	 ;; (options (parse-option-args query))
	 (passed-subclass (cdr (assoc "subclass" query :test #'equal)))
	 (passed-superclass (cdr (assoc "superclass" query :test #'equal)))
	 (passed-editclass (cdr (assoc "editclass" query :test #'equal)))
	 (passed-editfun (cdr (assoc "editfun" query :test #'equal)))
	 (passed-class (string-upcase (cdr (assoc "class" query :test #'equal))))
	 (selected-packages (parse-package-args query))
	 (class-name (cond (passed-superclass
			    (string->symbol passed-superclass))
			   (passed-subclass
			    (string->symbol passed-subclass))
			   (passed-class
			    (string->symbol passed-class))
			   (t nil)))
	 (class-name-changed (not (eq class-name *current-class*)))
	 (passed-path (cdr (assoc "path" query :test #'string-equal)))
	 (path (when passed-path (read-from-string (format nil "(~a)" passed-path))))
	 (class-node (find-node-by-path (reverse path) *subclass-tree*))
	 (leafp (or (symbolp class-node) (null (cdr class-node))))
	 (subtreex (when (and class-node leafp)
		     (cdr (subclass-tree (if (consp class-node)
					     (car class-node)
					     class-node)))))
	 ;;(subtree (sort (copy-list subtreex) #'alpha-lessp :key #'filename-key))
	 (subtree subtreex))

    (setf *error-no-class* nil)

    (unless class-name
      (setf *selected-packages* selected-packages))

    (when passed-editfun
      (edit-function passed-editfun)
      )

    (when passed-editclass
      (edit-class (intern passed-editclass))
      )

    (cond ((not (get-class class-name))
	   ;; show an error message
	   (when class-name
	     (setf *error-no-class* (format nil "No class named: ~a" class-name))))
	  (class-name
	   (setf *current-class* class-name)
	   (setf *subclass-tree* nil))
	  (class-name-changed
	   (setf *current-class* class-name)
	   (setf *subclass-tree* nil)))

    (cond ((null *current-class*))
	  ((and path *subclass-tree*)
	   (set-node-by-path subtree (reverse path) *subclass-tree*)))))


(defun browse-classes (req ent)
  (let ((*package* (find-package :class-browser)))
    (parse-args req)

    (let* ((header-host (net.aserve::request-header-host req))
	   (header-port (parse-integer (subseq header-host (1+ (position #\: header-host))))))
      header-host header-port
      ;;(setf *aserve-port* header-port)
      ;;(setf *urlbase* (format nil "http://~a:~a~a" *aserve-host* *aserve-port* *aserve-path*))
      )

    (let ((*package* :class-browser))
      (net.aserve:with-http-response (req ent)
	(net.aserve:with-http-body (req ent)
	  (net.html.generator:html
	   (:html
	    ((:script :type "text/javascript")
	     "
// Cookie functions from http://www.quirksmode.org/js/cookies.html
function createCookie(name,value,days) {
  if(days) {
    var date = new Date();
    date.setTime(date.getTime()+(days * 24 * 60 * 60 * 1000));
    var expires = '; expires='+ date.toGMTString();
  }
  else var expires = '';
  document.cookie = name +'='+ value + expires + '; path=/';
}

function readCookie(name) {
  var nameEQ = name + '=';
  var ca = document.cookie.split(';');
  for(var i = 0; i < ca.length; i++) {
    var c = ca[i];
    while(c.charAt(0) == ' ') c = c.substring(1, c.length);
    if(c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
  }
  return null;
}

function eraseCookie(name) {
  createCookie(name, '', -1);
}

window.onscroll = function(e) {
  var scrollTop = document.documentElement.scrollTop || document.body.scrollTop;
  createCookie(document.location +'-scrollTop', scrollTop, 2);
}
window.onload = function() {
  var scrollTop = readCookie(document.location +'-scrollTop');
  if(scrollTop) {
    document.documentElement.scrollTop = document.body.scrollTop = scrollTop;
  }
}
"
	     )
	    (:head (:title (:princ "Browse Classes"))
		   ((:meta :charset "utf-8"))
		   ((:style :type "text/css")
		    ;;"thead {background-color: #C8C8C8; text-align: left }"
		    "html, body { height: 100%; }"
		    "#container { min-height: 100%;  margin: 0 auto; }"
		    ;;"* html #container { height: 100%; }"

		    "table {border: 1px solid black;}"
		    "div {font-family:sans-serif; padding: 2px 5px;}"
		    "td {border: 1px solid black; text-align: left; padding: 2px 5px;  vertical-align: text-top; font-size: 12px;line-height: 110%;}"
		    "th {border: 1px solid black; font-size: 13px;line-height: 120%;}"
		    ;; no underline on anchors
		    "a {text-decoration:none;}"
		    "a:link {color:blue}"
		    ;; don't distinguish visited links
		    "a:visited {color:blue}"
		    "a:hover {color:red}"
		    ".method a:hover {color:green}"
		    ".class a:hover {color:green}"
		    ))

	    ((:body :onload "document.results.newform.focus();")

	     ((:form :name "cname" :method *form-method* :action *urlbase*)

	       ((:span :style "font-size: 20px;" :id "input" :float "left")
		(:princ "Class: ")
		;; :size is the width of the input field
		((:input :style "font-size: 13px;" :size "45" :type "text" :name "class" :value (or *current-class* ""))))
	      )

	     (when *error-no-class*
	       (html (format *html-stream* *error-no-class*)
		     (:br)
		     ))

	     (when *current-class*
	       (display-browser *current-class*))
	     (:br)
	     (:princ "class-browser (:clbr)")))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun start-server (&key (port clbr::*default-port*))
  (let ((socket (net.aserve.client::wserver-socket net.aserve:*wserver*)))
    #+nil
    (when socket
      (net.aserve:shutdown :server net.aserve:*wserver* :save-cache nil))
    (unless socket
      (net.aserve:start :port port))
    (let* ((socket (net.aserve.client::wserver-socket net.aserve:*wserver*))
	   (port (acl-socket:local-port socket)))
      port)))


(defun start-aserver (&key (port 8040) (host "localhost")
			   (tries 10) (increment 10))
  (dotimes (i tries)
    (handler-case
	(net.aserve:start :host host :port port)
      (condition (c) c (incf port increment))
      (:no-error (c) c
	(format t "~%Started ~s" net.aserve:*wserver*)
	(return net.aserve:*wserver*)))))

(defun get-aserver (&key port (host "localhost") (reuse nil))
  (unless reuse
    (net.aserve:shutdown)
    #+nil
    (when net.aserve:*wserver*
      (net.aserve:shutdown :server net.aserve:*wserver*)))
  (let ((server net.aserve:*wserver*))
    (when server
      (let ((socket (net.aserve.client::wserver-socket net.aserve:*wserver*)))
	(if socket
	    server
	    (start-aserver :port port :host host))))))

(defun web-class-browser (&key (host *aserve-host*) (port *aserve-port*) (path *aserve-path*))
  (let ((server (get-aserver :port 8040 :reuse t)))
    (when server
      (let ((socket (net.aserve.client::wserver-socket net.aserve:*wserver*)))
	(when socket
	  (let ((port (or (acl-socket:local-port socket) port)))
	    (when port
	      (setf clbr::*aserve-host* host)
	      (setf clbr::*aserve-path* path)
	      (setf clbr::*aserve-port* port)

	      (setf clbr::*urlbase* (format nil "~&http://~a:~a~a" *aserve-host* *aserve-port* *aserve-path*))
	      (net.aserve:publish :path path
			:content-type "text/html"
			:function #'clbr::browse-classes)
	      (clbr::init)
	      clbr::*urlbase*)))))))




#+nil(defun web-class-browser (&key (host *aserve-host*) (port *aserve-port*) (path *aserve-path*))
  (let ((server (get-server "localhost"))
	(port (start-server :port port)))
    (unless (slot-value *WSERVER* 'net.aserve::socket)
      (net.aserve:start :port port))
    (setf clbr::*aserve-host* host)
    (setf clbr::*aserve-path* path)
    (setf clbr::*aserve-port* port)
    (setf clbr::*urlbase* (format nil "~&http://~a:~a~a" *aserve-host* *aserve-port* *aserve-path*))
    (net.aserve:publish :path path
			:content-type "text/html"
			:function #'clbr::browse-classes)
    (clbr::init)
    ;; (format t "~&~a~%" clbr::*urlbase*)
    clbr::*urlbase*))

(eval-when (:compile-toplevel :execute :load-toplevel)
    (web-class-browser))

;;; open the prowser when this file is loaded
(eval-when (:execute)
  (excl::run-shell-command (format nil "open ~a" *urlbase*)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#|
<script type="text/javascript">
// Cookie functions from http://www.quirksmode.org/js/cookies.html
function createCookie(name,value,days) {
  if(days) {
    var date = new Date();
    date.setTime(date.getTime()+(days * 24 * 60 * 60 * 1000));
    var expires = '; expires='+ date.toGMTString();
  }
  else var expires = '';
  document.cookie = name +'='+ value + expires + '; path=/';
}

function readCookie(name) {
  var nameEQ = name + '=';
  var ca = document.cookie.split(';');
  for(var i = 0; i < ca.length; i++) {
    var c = ca[i];
    while(c.charAt(0) == ' ') c = c.substring(1, c.length);
    if(c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
  }
  return null;
}

function eraseCookie(name) {
  createCookie(name, '', -1);
}

window.onscroll = function(e) {
  var scrollTop = document.documentElement.scrollTop || document.body.scrollTop;
  createCookie(document.location +'-scrollTop', scrollTop, 2);
}
window.onload = function() {
  var scrollTop = readCookie(document.location +'-scrollTop');
  if(scrollTop) {
    document.documentElement.scrollTop = document.body.scrollTop = scrollTop;
  }
}
</script>
|#

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
