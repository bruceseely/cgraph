;;; Support Functions that don't involve Spike.


(defpackage :cgraph-support
  (:use #:cl)
  (:nicknames :sup)
  (:documentation
   "Hand-loaded REPL tools: RAPROPOS and assorted debugging helpers.
Interned here rather than in COMMON-LISP so that redefining something in
this file can never shadow a CL builtin, and so the names need no export
into CL to be reachable -- SUP:RAPROPOS works from any package.")
  (:export #:rapropos
	   #:zzz
	   #:var-vals
	   #:describe-hashtable
	   #:describe-to-file
	   #:parse-time
	   #:subclasses
	   #:cleanup-dir
	   #:xmat
	   #:print-signature
	   #:extract-arg-types
	   #:in-repo
	   #:my-location))

(in-package #:cgraph-support)


;;(format t "~5&Loading support-functions.lisp~%")


;; (defun start-class-browser (&optional (port 8060))
;;   (unless (asdf:component-loaded-p :web-utilities)
;;     (asdf:load-system :web-utilities :force t))
;;   (clbr::web-class-browser :port 8040)
;;   (princ "http://localhost:8040")
;;   t)

;; (defun start-type-grapher (&optional (port 8060))
;;   (unless (asdf:component-loaded-p :cgraph-web)
;;     (asdf:load-system "cgraph-web"))
;;   (unless (server-started-p)
;;     (cg::start-web-server :port port))
;;   (princ "http://localhost:~a" port)
;;   t)



;;;#-noint
;;; (defun intersection-with-list (single-interval interval-list &optional accum)
;;;   "assumes interval list is sorted"
;;;   (cond ((null interval-list) (reverse accum))
;;;         (t (intersection-with-list single-interval
;;;                                    (cdr interval-list)
;;;                                    (let ((result (intersect-intervals single-interval
;;;                                                                       (car interval-list))))
;;;                                      (if result (cons result accum)
;;;                                          accum))))))


;;; ensure-period lives in system/operations/cg-env.lisp, in :CG



(defun in-repo (path)
  (format nil "~~/repo/~a" (string-left-trim (list #\/) path)))


;; (defmacro shhh (notice &rest forms)
;;   (let ((original-standard-output *standard-output*))
;;     `(unwind-protect
;; 	  (let ((*standard-output* (make-broadcast-stream))) ; null-output-stream
;; 	    (format ,original-standard-output "~&~a" ,notice)
;; 	    ,@forms
;; 	    t)
;;        (setf *standard-output* ,original-standard-output))))

;;;;;; #-noint
(defmacro zzz (var)
  "debug output of var's value"
  (let ((control-string (format nil "~~&>>> (zzz) ~(~a~): ~~s~~%" var)))
    `(format t ,control-string ,var)))


(defun describe-hashtable (table &optional (stream *standard-output*))
  (format stream "~&HT: ~a~%" table)
  (maphash #'(lambda (k v)
	       (format stream "~&+ ~s~20t~s~%" k v))
	   table))

(defun describe-to-file (object pathname &optional tag)
  (let ((*print-pretty* nil))
    (with-open-file (stream pathname
			    :direction :output
			    :if-does-not-exist :create
			    :if-exists :supersede)
      (format stream "~&~%--- ~a --------------------------------~&" (or tag ""))
      (describe object stream)
      (format stream "~&~%-------------------------------------------------~&" ))))

#-noint
(defun parse-time (time-in-secs)
  (let* ((seconds-per-minute 60)
	 (seconds-per-hour (* seconds-per-minute 60))
	 (seconds-per-day (* seconds-per-hour 24))
	 (time-partial-day (mod time-in-secs seconds-per-day))
	 (time-partial-hour (mod time-in-secs seconds-per-hour))
	 (time-partial-min (mod time-in-secs seconds-per-minute)))
    (format nil "~d ~2,'0d:~2,'0d:~4,1,,,'0f"
	    (truncate time-in-secs seconds-per-day)
	    (truncate time-partial-day seconds-per-hour)
	    (truncate time-partial-hour seconds-per-minute)
	    time-partial-min)))


;;; used to display the values of variables
;;; (setf foo 78 blorf 89)
;;; (var-vals foo blorf)
;;; (var-vals (foo blorf))
;;; todo: fix crash on unbound variables
#-noint
(defmacro var-vals (&rest vars)
  (let* ((var-list (if (listp (car vars)) (car vars) vars))
	 (indent (+ 2 (apply #'max (mapcar #'(lambda (v) (length (string v ))) var-list))))
	 (ctrlstrs (mapcar #'(lambda (var) (format nil "~~&~a:~~~at~~s" var indent)) var-list)))
    `(progn
       (mapcar #'(lambda (var ctrl)
		   (format t ctrl var))
	       ,(cons 'list var-list)
	       ',ctrlstrs)
       (values))))



;;; SBCL uses cl-ppcre for regular expressions

;;; These work from the symbols APROPOS-LIST returns rather than from the text
;;; APROPOS prints.  Scraping the printed form was ACL-specific: it looked for a
;;; "[type]" field SBCL doesn't emit, and it read the package off a prefix SBCL
;;; omits for symbols in *PACKAGE*.

(defun rapropos-qualified-name (symbol)
  "PKG:NAME for an external symbol, PKG::NAME for an internal one,
:NAME for a keyword, #:NAME for an uninterned symbol."
  (let ((package (symbol-package symbol))
	(name (symbol-name symbol)))
    (cond ((null package) (format nil "#:~a" name))
	  ((eq package (find-package :keyword)) (format nil ":~a" name))
	  (t (multiple-value-bind (found status) (find-symbol name package)
	       (declare (ignore found))
	       (format nil "~a~a~a" (package-name package)
		       (if (eq status :external) ":" "::")
		       name))))))

(defun rapropos-sort-key (symbol)
  "Sort key grouping by owning package, then by name.  The separating space
sorts below any name character, so packages stay in blocks and internal and
external symbols interleave alphabetically within one."
  (format nil "~a ~a"
	  (if (symbol-package symbol) (package-name (symbol-package symbol)) "")
	  (symbol-name symbol)))

(defun rapropos-abbreviate (object &optional (limit 100))
  "Printed representation of OBJECT, on one line and no longer than LIMIT.
Bound tightly because a variable's value may be large or circular -- the CG
structures are both."
  (let* ((*print-circle* t)
	 (*print-pretty* nil)
	 (*print-length* 6)
	 (*print-level* 3)
	 (text (or (ignore-errors (substitute #\space #\newline (prin1-to-string object)))
		   "#<error printing value>")))
    (if (> (length text) limit)
	(concatenate 'string (subseq text 0 limit) "...")
	text)))

(defun rapropos-function-p (symbol)
  "True when SYMBOL names something callable."
  (and (or (fboundp symbol) (special-operator-p symbol)) t))

(defun rapropos-definitions (symbol)
  "List of strings describing what SYMBOL names -- one per definition,
since a symbol can name several things at once."
  (let ((definitions nil))
    (cond ((special-operator-p symbol) (push "[special-operator]" definitions))
	  ((macro-function symbol) (push "[macro]" definitions))
	  ((fboundp symbol)
	   (push (if (typep (fdefinition symbol) 'generic-function)
		     "[generic-function]"
		     "[function]")
		 definitions)))
    (when (fboundp (list 'setf symbol))
      (push "[setf-function]" definitions))
    (when (boundp symbol)
      (push (format nil "~a = ~a"
		    (if (constantp symbol) "[constant]" "[variable]")
		    (rapropos-abbreviate (symbol-value symbol)))
	    definitions))
    (when (find-class symbol nil)
      (push "[class]" definitions))
    (nreverse definitions)))

(defmethod rapropos ((regexp string) &optional package
				     &key
				       (external-only nil)
				       (case-insensitive t)
				       ((:strict strict-package-inclusion) nil)
				       (functions-only nil)
				       ((:collapse-defs collapse-defs-p) nil))
  "regular-expression apropos.

REGEXP is matched against the symbol name without its package prefix, so
anchor it when you mean a whole name.  PACKAGE limits the search to the
symbols ACCESSIBLE there, which includes everything inherited; :STRICT
further limits it to the symbols that package OWNS -- usually what you
want, since :CG inherits all of CL, CL-USER and UIOP.

  (rapropos \"^\\\\*.*\\\\*$\" :cg :strict t)    ; CG's own special variables
  (rapropos \"CONCEPT\" :cg :functions-only t)  ; only what you can call
  (rapropos \"^FORMAT-\" nil :case-insensitive nil)

PACKAGE stays positional, so pass NIL explicitly when searching the whole
image with keywords.  :COLLAPSE-DEFS puts a symbol's definitions on one
line when it has more than one."
  (let ((re (cl-ppcre:create-scanner regexp :case-insensitive-mode case-insensitive))
	(home (when (and package strict-package-inclusion) (find-package package)))
	(seen (make-hash-table :test #'eq))
	(hits nil))
    ;; collect matching symbols; apropos-list can repeat one that is
    ;; accessible from several packages
    (dolist (symbol (apropos-list "" package external-only))
      (unless (gethash symbol seen)
	(setf (gethash symbol seen) t)
	(when (and (cl-ppcre:scan re (symbol-name symbol))
		   (or (null home) (eq home (symbol-package symbol)))
		   (or (not functions-only) (rapropos-function-p symbol)))
	  (push symbol hits))))
    (setf hits (sort hits #'string< :key #'rapropos-sort-key))
    ;; output
    (format t "~&")
    (dolist (symbol hits)
      (let ((name (rapropos-qualified-name symbol))
	    (definitions (rapropos-definitions symbol)))
	(cond ((null (rest definitions)) ; 0 or 1 definition: one line
	       (format t "~&~a~@[ ~a~]~%" name (first definitions)))
	      (collapse-defs-p
	       (format t "~&~a ~{~a~^ ~}~%" name definitions))
	      (t
	       (format t "~&~a~%" name)
	       (dolist (definition definitions)
		 (format t "  ~a~%" definition))))))
    (format t "~&~d symbol~:p~%" (length hits)))
  (values))


;; (defmethod rapropos ((regexp string) &optional (package nil)
;; 				     &key
;; 				       ;; added by Franz for ACL
;; 				       (external-only nil)
;; 				       (case-insensitive t)
;; 		     ;; added new for this function
;; 				       (strict-package-inclusion nil)
;; 				       (functions-only t))
;;   "regular-expression apropos"
;;   ;; see: https://franz.com/support/documentation/current/doc/implementation.htm#extensions-to-apropos-3
;;   ;; see: https://franz.com/support/documentation/current/doc/regexp.htm
;;   ;; The package argument to apropos returns symbols ACCESSIBLE in the package
;;   ;; strict-package-inclusion limits results to symbols owned by the package
;;   (let* ((text nil)
;; 	 (matched nil)
;; 	 (re (excl::compile-re regexp :case-fold case-insensitive :return :string))
;; 	 (collapse-defs-p nil)
;; 	 (reader-function (lambda (stream)
;; 			    (do ((line (read-line stream nil nil) (read-line stream nil nil)))
;; 				((null line))
;; 			      (unless (equal line "")

;; 				(cond ((eq (aref line 0) #\space) ; continue reading a spec
;; 				       (when matched
;; 					 ;; add the current line to the current spec
;; 					 (setf text (if collapse-defs-p
;; 							(format nil "~a ~a" text (string-trim '(#\space #\tab #\newline #\return #\linefeed) line))
;; 							(format nil "~a~a~a" text #\newline line)))))
;; 				      (t ;; start checking a new spec
;; 				       ;; output the previously extracted spec
;; 				       (when matched
;; 					 (format t "~&~a~%" text))

;; 				       (let* ((sindex (position #\space line))
;; 					      ;; name
;; 					      (full-name (subseq line 0 sindex))
;; 					      (cindex1 (position #\: full-name))
;; 					      (cindex2 (position #\: full-name :from-end t))
;; 					      (pkg (when cindex1 (subseq full-name 0 cindex1)))
;; 					      (name (if cindex2
;; 							(subseq full-name (1+ cindex2))
;; 							full-name))
;; 					      ;; type
;; 					      (lbindex (when sindex (position #\[ line :start sindex)))
;; 					      (rbindex (when sindex (position #\] line :start sindex)))
;; 					      (type (when (and lbindex rbindex)
;; 						      (subseq line (1+ lbindex) rbindex)))
;; 					      ;; match
;; 					      (re-match-p (excl::match-re re name))
;; 					      (function-p (if functions-only
;; 							      (or (equal type "generic-function")
;; 								  (equal type "function")
;; 								  (equal type "macro"))
;; 							      nil))
;; 					      (package-p (or (null package)
;; 							     (not strict-package-inclusion)
;; 							     (eq (find-package package)
;; 								 (find-package pkg))))
;; 					      (match-p (and re-match-p function-p package-p)))
;; 					 ;; remember whether to save this spec
;; 					 (setf matched match-p)
;; 					 (when match-p
;; 					   ;; start a new spec
;; 					   (setf text line))))))))))

;;     ;; bind pretty-print parameters?? - does it help/work on pipe stream??
;;     (multiple-value-bind (pipe-in pipe-out) (excl:make-pipe-stream)
;;       (mp:process-run-function "reader" reader-function pipe-out)
;;       (let ((*standard-output* pipe-in))
;; 	(apropos "" package external-only)
;; 	(finish-output))))
;;   (values))



;;; still useful????
#-noint
(defun my-location ()
  (let* ((stsci-p  (not (null (directory "/eng/lambda/*"))))
	 (remote-p (not (null (directory "/Volumes/Macintosh\ HD/eng/lambda/*")))))
    (cond (stsci-p :stsci)
	  (remote-p :remote)
	  (t :local))))


#-noint
(defun cleanup-dir (dir &optional (extensions '(fasl)))
  (let ((pathnames (directory dir)))
    (dolist (path pathnames)
      ;;(format t "~&~s " path )
      (let* ((file path)
	     ;;(file-name (pathname-name path))
	     (file-type (pathname-type path))
	     (dirfiles (directory file))
	     (subfiles (remove file dirfiles :test #'equal)))
	;; (format t "~&dirfiles: ~s" dirfiles)
	;; (format t "~&subfiles: ~s" subfiles)
	;; (format t "~&file: ~s" file)

	(cond (file-type
	       ;;(format t "~&~a.~a"  file-name file-type)
	       (when (find file-type extensions :test #'string-equal)
		 (delete-file path)))
	      ((not subfiles)
	       ;;(format t " ~a" file-name)
	       )
	      ((> (length subfiles) 1)
	       ;;(format t "~&~a"  path)
	       (dolist (subfile subfiles)
		 (cleanup-dir subfile extensions))))))))




;;; defined in spike-utilities
;;; (defmacro destructuring-setq (vars-map form)
;;;   (let* ((symbols '(&rest &optional &key &allow-other-keys))
;;;          (bindings (mapcar (lambda (s) (list (gensym) s))
;;;                            (remove-if (lambda (x)
;;;                                         (or (not (symbolp x))
;;;                                             (member x symbols)))
;;;                                       (flatten vars-map)))))
;;;     `(let ,(mapcar #'car bindings)
;;;        (destructuring-bind ,vars-map ,form
;;;          (setq ,@(apply #'append bindings)))
;;;        (setq ,@(apply #'append (mapcar #'reverse bindings))))))



#-noint
;; (load (in-repo "lisp-extensions/path.lisp"))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#-noint
(defmacro xmat (&rest arg-list)
  ;; if a list is supplied, (car arg-list) is a list, otherwise arg-list is a list
  (let* ((args (if (listp (car arg-list)) (car arg-list) arg-list))
	 (ctrlstrs (mapcar (lambda (arg) (format nil "~~&|- ~a~:[~~s~;~~a~]"
						 (if (stringp arg) ""
						     (format nil "~s:  " arg))
						 (stringp arg)))
			   args)))
    `(progn
       (mapcar #'(lambda (ctrl arg)
		   (format t ctrl arg))
	       ',ctrlstrs
	       (mapcar (lambda (a)
			   (if (and (symbolp a) (not (boundp a)))
			       :unbound
			       (eval a))
			   )
		       ',args)
	       ;;,(cons 'list args)
	       )
       (values))))




#-noint
(defun subclasses (class &optional (indent 2) (initial-indent 0))
  (labels ((subclasses-internal (class indentation)
	     (format t "~&~v,0t~a (~(~a~))~&" indentation
		     (class-name class)
		     (package-name (symbol-package (class-name class))))
	     (let ((direct-subclasses (copy-list (sb-mop:class-direct-subclasses class))))
	       (dolist (subclass (sort direct-subclasses #'string< :key #'class-name))
		 (subclasses-internal subclass (+ indent indentation))))))
    (subclasses-internal class initial-indent)))


#-noint
(defun extract-arg-types (lambda-list)
  (let ((types (list)))
    (block loop
      ;; (format t "~&lambda-list: ~s" lambda-list)
      (dolist (term lambda-list)
	;; (format t "~&term: ~s" term)
	(when (or (eql term '&key)
		  (eql term '&optional))
	  (return-from loop))
	(let ((type (cond ((atom term) t)
			  ((atom (second term)) (second term))
			  (t nil))))
	  (when type
	    (push type types)))))
    (reverse types)))


#-noint
(defun print-signature (sig &key tab-col (stream *standard-output*))
  (let* ((name (car sig))
	 (args (cadr sig))
	 ;;(num-args (length args))
	 )
    (format stream "~&")
    (format stream "~(~a~)" name)
    (format stream "~vt" tab-col)
    (format stream "~a" args)))


;;; might want to use this...
#+nil
(defun print-signature (sig &key tab-col (stream *standard-output*))
  (let* ((name (car sig))
	 (args (cadr sig))
	 (num-args (length args)))
    (format stream "~&")
    (format stream "~(~a~)" name)
    (format stream " ~vt(" tab-col)
    (block loop
      (dotimes (i (length args))
	(let* ((arg (nth i args)))
	  (cond ((consp arg)
		 (let ((arg-name (car arg))
		       (arg-type (cadr arg)))
		   (cond ((atom arg-type)
			  (format stream "~a" arg-type))
			 ((eq (car arg-type) 'eql)
			  (format stream "~a" arg-type)))
		   (when (< i (- num-args 1))
		     (format stream " "))))
		((eq arg '&key) (return-from loop))
		((eq arg '&optional) (return-from loop))
		(t t)))))
    (format stream ")")))



;;; :all - uses all passed types
;;; :any - uses some passed types
;;; :only - uses only passed types
;;(defparameter *gfuns* (excl::list-all-generic-functions))

;;; (defun find-qualified-method (class-names scope)
;;;   (let ((*print-pretty*)
;;; 	(gfuns *gfuns*))
;;;     (unless (consp class-names)
;;;       (setf class-names (list class-names)))
;;;     (let ( ;;(method-qualifiers (mapcar #'find-class class-names))
;;; 	  ;;(specializers nil)
;;; 	  ;;(errorp nil)
;;; 	  (found (list)))
;;;       (dolist (gf gfuns)
;;; 	(let ( ;;(gfll (mop:generic-function-lambda-list gf))
;;; 	      (methods (mop::generic-function-methods gf)))
;;; 	  (dolist (m methods)
;;; 	    (let* ((mll (mop::method-lambda-list m))
;;; 		   ;;(mq (mop::method-qualifiers m))
;;; 		   ;;(ms (mop::method-specializers m))
;;; 		   (arg-types (extract-arg-types mll))
;;; 		   (match (case scope
;;; 			    (:all (set-difference class-names arg-types))
;;; 			    (:any (not (null (intersection class-names arg-types))))
;;; 			    (:only (not (set-exclusive-or class-names arg-types)))
;;; 			    )))
;;; 	      (when match
;;; 		;;(push (list (mop:generic-function-name gf) mll (mapcar #'class-name ms)) found)
;;; 		(push (list (mop:generic-function-name gf) mll ) found))))))

;;;       (let* ((setf-methods (remove-if-not #'(lambda (z) (and (consp (car z)) (eq (caar z) 'setf))) found))
;;; 	     (methods (remove-if #'(lambda (z) (and (consp (car z)) (eq (caar z) 'setf))) found))
;;; 	     (sorted (sort (copy-list methods) #'string-lessp :key #'car))
;;; 	     (names (mapcar #'car sorted))
;;; 	     (max-name (when names (apply #'max (mapcar #'(lambda (x) (length (princ-to-string x))) names)))))
;;; 	(dolist (entry sorted)
;;; 	  (print-signature entry :tab-col (+ 2 max-name)))
;;; 	(dolist (entry setf-methods)
;;; 	  (print entry))
;;; 	;;(list sorted setf-methods)
;;; 	))))




;;;;;;;
;;; for defining things like #'caddadr
;;; if name is not supplied, term is used for the name
;;; if name is provided, the accessor function gets that name
;;; if (eql name t) the accessor is an anonymous function
;;; caddadr
;;; (setq list '(a1 (b1 b2 (c1 c2 c3 c4) b4) a3 a4 a5))
;;; (defaccessor caddadr)
;;; (defaccessor caddadr fred)
;;; (define-accessor "caddadr")
;;; (expand-accessor "caddadr" "x")

;; (defmacro defaccessor (term &optional name)
;;   (let* ((x (gensym))
;; 	 (term-string (string-upcase (princ-to-string term)))
;; 	 (name (cond ((null name) term-string)
;; 		     ((not (eql name t)) (princ-to-string name))
;; 		     (t t)))
;; 	 (term-chars (coerce term-string 'list))
;; 	 (chars (subseq term-chars 1 (1- (length term-chars)))))

;;     (unless (eql (nth 0 term-chars) #\C)
;;       (error "bad starting character (~a) in ~a" (car term-chars) term))
;;     (unless (eql (nth (1- (length term-chars)) term-chars) #\R)
;;       (error "bad ending character (~a) in ~a" (car (last term-chars)) term))
;;     (unless (every (lambda (x) (or (eql x #\A) (eql x #\D))) chars)
;;       (error "bad character (neither A nor D) found in C[~a]R"  (coerce chars 'string)))

;;     (let* ((form (reduce (lambda (l z)
;; 			   (list (case z
;; 				   (#\A 'car)
;; 				   (#\D 'cdr))
;; 				 l))
;; 			 (reverse chars)
;; 			 :initial-value 'x)))
;;       (if (eql name t)
;; 	  `(lambda (x) ,form)
;; 	  `(defun ,(intern name) (x) ,form)))))

#||
;; (let ((list '(a1 (b1 b2 (c1 c2 c3 c4) b4) a3 a4 a5)))
;;   (format t "~&list: ~s" list)
;;   (format t "~&(defaccessor caddadr) -> ~s" (defaccessor caddadr))
;;   (format t "~&(caddadr list) -> ~s" (caddadr list))
;;   (format t "~&(defaccessor caddadr fred) -> ~s" (defaccessor caddadr fred))
;;   (format t "~&(fred list) -> ~s" (fred list))
;;   (format t "~&(defaccessor caddadr t) -> ~s" (defaccessor caddadr t))
;;   (format t "~&(funcall (defaccessor caddadr t) list) -> ~s" (funcall (defaccessor caddadr t) list)))

;; (defaccessor caddadr) -> CADDADR
;; (caddadr list) -> (C1 C2 C3 C4)
;; (defaccessor caddadr fred) -> FRED
;; (fred list) -> (C1 C2 C3 C4)
;; (defaccessor caddadr t) -> #<Interpreted Closure (unnamed) @ #x1011a8c66e2>
;; (funcall (defaccessor caddadr t) list) -> (C1 C2 C3 C4)
NIL
VPS>
||#




;;; (edit-file '(method import-proposals (cons)))
;;; (edit-file 'LOAD-RPS2-PROPOSALS)
;;; (edit-file "LOAD-RPS2-PROPOSALS")


;;; swank-allegro.lisp is Allegro CL specific code for SLIME om github
;;; swank/allegro.lisp
;; (defmethod edit-file ((spec list))
;;   (when (= (length spec) 1)
;;     (setf spec (eval (cons 'function spec))))
;;   (let* ((loc (SWANK/ALLEGRO::function-source-location spec)))
;;     (unless (eq (car loc) :error)
;;       (let* ((location (cdr loc))
;; 	     (path (cadr (assoc :file location)))
;; 	     (position (cadr (assoc :position location)))
;; 	     (cmd `(open-file-at-position ,path ,position)))
;; 	(swank::with-connection (cl-user::*connection*)
;; 	  (swank::eval-in-emacs cmd t))))))
