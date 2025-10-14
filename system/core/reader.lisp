;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

;   thew.lyon@gmail
(in-package #:conceptual-graphs)


(defmethod whitespace-char-p ((char character))
  (find char '(#\space #\tab #\return #\newline) :test #'char=))


;; (defmethod compress-whitespace ((text string))
;;   (let ((output (list))
;;         (in-whitespace nil))
;;     (with-input-from-string (stream text)
;;       (loop
;;         (let ((char (read-char stream nil nil)))
;;           (unless char (return))
;;           (let ((ws-char-p (whitespace-char-p char)))
;;             (unless (and in-whitespace ws-char-p)
;;               (push char output))
;;             (setf in-whitespace ws-char-p)))))
;;     (coerce (reverse output) 'string)))


(defmethod compress-whitespace ((text string))
  (let ((output (list))
        (in-whitespace nil))
    (with-input-from-string (stream text)
      (loop
        (let ((char (read-char stream nil nil)))
          (unless char (return))
          (let ((ws-char-p (whitespace-char-p char)))
            (unless ws-char-p
              (push char output))
            ))))
    (coerce (reverse output) 'string)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmacro with-readtable-mods (mods body)
    `(let ((*readtable* (adjust-readtable ,mods)))
       ,body)))


(defun adjust-readtable (modifications &optional (readtable (copy-readtable)))
  (let ((modified-readtable (copy-readtable readtable)))
    (dolist (mod modifications)
      (destructuring-bind (character function) mod
        (set-macro-character character function nil modified-readtable)))
    modified-readtable))

;; (defmethod cg-read (stream)
;;   (with-cg-readtable
;;       (read stream nil nil nil)))


(defun consume-whitespace (stream &optional across-lines also)
  (unless (listp also)
    (setf also (list also)))
  (let ((skip (list* #\space #\tab also)) skipped)
    (if across-lines
        (setf skip (list* #\newline #\return skip)))
    (block nil
      (loop
        (let ((pchar (peek-char nil stream nil nil)))
          (cond ((and pchar (find pchar skip :test #'char-equal))
                 (read-char stream nil nil)
                 (setf skipped t))
                (t (return))))))
    skipped))


(defun skip-char (stream char)
  (consume-whitespace stream)
  (let ((pchar (peek-char nil stream nil nil)))
    (when (and pchar (char-equal pchar char))
      (read-char stream))))


;;; end-chars is a list of characters that will be left in the stream for the next read
;;; if single-line is non-nil, reading will stop at the end of the line
;;; Reading stops when max-length characters have been read
;;; skip: skip over leading whitespace before reading
(defun read-string (stream &key (end-chars  #\space) max-length (skip t) single-line)
  ;; (format *standard-output* "~&(delimited-read stream~@[ :end-chars '~s~]~@[ :max-length ~s~]~@[ :single-line ~s~])~%" end-chars max-length single-line)
  (let ((chars-read '())
        (length 0)
        (pchar nil)
        (terminators (if (listp end-chars) end-chars (list end-chars))))
    (when skip (consume-whitespace stream))

    (block nil
      (loop
        (setf pchar (peek-char nil stream nil nil))
        (when (or (null pchar)
                  (not (characterp pchar))
                  (and single-line (eq pchar #\newline))
                  (find pchar terminators :test #'char-equal)
                  (and max-length
                       (numberp max-length)
                       (>= length max-length)))
          (return))                     ; from block
        (let ((char (read-char stream nil nil)))
          (push char chars-read)
          (incf length))))

    (values
     (coerce (reverse chars-read) 'string)
     pchar)))

#|
(with-input-from-string (stream "Now is the time forall good men")
  (print (read-string stream))
  (print (read-string stream   :end-chars '(#\h)))
  (print (read-string stream   :end-chars '(#\h)))
  (print (read-string stream))
  (print (read-string stream :max-length 5))
  (print (read-string stream :max-length 5)))
|#

(defun read-number (stream &key (skip t) )
  ;; (format *standard-output* "~&(delimited-read stream~@[ :end-chars '~s~]~@[ :max-length ~s~]~@[ :single-line ~s~])~%" end-chars max-length single-line)
  ;;(declare (special *readtable*))
  (let ((chars-read '())
        (pchar nil)
        (terminators '(#\space #\newline #\return))
        (*readtable* UIOP/STREAM::*STANDARD-READTABLE*))
    (when skip (consume-whitespace stream))

    (block nil
      (loop
        (setf pchar (peek-char nil stream nil nil))
        (when (or (null pchar)
                  (not (characterp pchar))
                  (not (or (char-equal pchar #\.) (digit-char-p pchar)))
                  (find pchar terminators :test #'char-equal))
          (return))                     ; from block
        (let ((char (read-char stream nil nil)))
          (push char chars-read))))

    (let* ((string-num (coerce (reverse chars-read) 'string))
           (num (read-from-string string-num nil nil :end nil)))
      (values num pchar))))



;;; read a token in the referent stream
(defun read-term (stream &key (end-chars #\space) (skip t) )
  (when skip (consume-whitespace stream))
  (let ((ref-rt-mods (list (list #\# #'individual-reader)
                           (list #\@ #'measure-reader)
                           (list #\{ #'set-reader)
                           (list #\[ #'graph-reader)
                           (list #\* #'asterisk-reader)
                           (list #\- #'arc-reader)
                           (list #\] #'end-reader))))

    (with-readtable-mods ref-rt-mods
      (let ((pchar (peek-char nil stream nil nil)))
        (cond ((find pchar ref-rt-mods :key #'car)
               (read stream nil nil))
              (t
               ;; preserve case info for mame
               (let ((text (string-trim " " (read-string stream :end-chars end-chars :skip skip))))
                 (when (plusp (length text))
                   (list :name text)))))))))


(defmethod parse-term ((referent string))
  (with-input-from-string (stream referent)
    (read-term stream)))

#|
(with-input-from-string (stream "Luke #23")
  (print (read-term stream))
  (print (read-term stream))
)
|#


(defun read-simple-graph (stream &key end-chars (max-length 100) single-line)
  ;; (format *standard-output* "~&(delimited-read stream~@[ :end-chars '~s~]~@[ :max-length ~s~]~@[ :single-line ~s~])~%" end-chars max-length single-line)

  (let* ((chars-read '())
         (peek-char nil))

    (let* ((length 0)
           (in-concept 1)
           (char nil))
      (loop
        (setf char (read-char stream nil :eof))
        (when (not (characterp char)) (return))
        (cond ((char-equal char #\[)
               (incf in-concept))
              ((char-equal char #\])
               (decf in-concept)))
        (push char chars-read)
        (incf length)
        (setf peek-char (peek-char nil stream nil :eof))
        (when (or (and single-line (eq char #\newline))
                  (>= length max-length)
                  (and (char-equal char #\])
                       (find peek-char end-chars :test #'char=)
                       ;;(not (find peek-char (list #\< #\- #\space)))
                       )



                  ;; (and (find char end-chars :test #'char=)
                  ;;      (zerop in-concept))
                  )
          (return))))

    (let ((graph (coerce (reverse chars-read) 'string)))
      ;;(format t "~&graph: ~s" graph)

      (values
       graph
       peek-char))))


(defun graph-string-read (stream &key end-chars (max-length 100) single-line)
  ;; (format *standard-output* "~&(delimited-read stream~@[ :end-chars '~s~]~@[ :max-length ~s~]~@[ :single-line ~s~])~%" end-chars max-length single-line)
  (let ((chars-read '())
        (length 0)
        (in-concept -0)
        (peek-char nil)
        (char nil))
    (loop
      (setf char (read-char stream nil :eof))
      (when (not (characterp char)) (return))
      (cond ((char-equal char #\[)
             (incf in-concept))
            ((char-equal char #\])
             (decf in-concept)))
      (push char chars-read)
      (setf peek-char (peek-char nil stream nil :eof))
      (incf length)
      (when (or (and single-line (eq char #\newline))
                (>= length max-length)
                (and (find char end-chars :test #'char=)
                     (zerop in-concept)))
        (return)))
    (values
     (coerce (reverse chars-read) 'string)
     peek-char)))


;;; :until char - read up to this character
;;; reads only alpha characters
;;; alpha-only -> stops at any non-alpha character
;;; (null alpha-only) -> stops at non-alpha characters except digits
;;; if it's a string collect everything up to the closing "
;;; (alpha-char-p #\space) -> nil
;;; stops at #\space, #\", #\]
(defun alpha-read (stream &key until (max-length 200) alpha-only single-line)
  ;;(format tc "~&(alpha-read stream~@[ :until ~s~]~@[ :max-length ~s~]~@[ :single-line ~s~])~%" until max-length single-line)
  (let ((chars-read '())
        (peek-char nil)
        (string1 nil)
        (string2 nil))
    (loop
      (let ((char (read-char stream nil nil)))

        (when (char-equal char #\")
          (if string1
              (setf string2 t)
              (setf string1 t)))

        (when (and char (not (characterp char)) (return)))
        (push char chars-read)
        (setf peek-char (peek-char nil stream nil nil))

        (when (or (and single-line (eq char #\newline))
                  (>= (length chars-read) max-length)
                  string2
                  (null peek-char)
                  (and until (char= peek-char until))
                  (and (not string1)
                       (or alpha-only (not (digit-char-p peek-char)))
                       (not (alpha-char-p peek-char))))
          (return))))

    (let ((char-list (reverse chars-read)))
      (values
       (coerce char-list 'string)
       peek-char))))


(defun end-reader (stream initial-char)
  stream initial-char
  nil)


#+nil
(defun trim-type-string (string)
  (let ((last-alpha-char-position (position-if #'alpha-char-p string :from-end t)))
    (subseq string 0 (1+ last-alpha-char-position))))

;; (define-condition concept-parse-failed (error)
;;   ((text :initarg :text :reader text)))


(defvar *referent-contents* nil)

(defun graph-reader (stream initial-char)
  stream initial-char
  ;;(format t "~% ===> (graph-reader ~a ~s)~%" stream initial-char)
  )

(defun set-reader (stream initial-char)
  ;;(format t "~% ===> (set-reader ~a ~s)~%" stream initial-char)
  (unless (char-equal initial-char #\{)
    (error "set parse error"))

  (let ((set-contents nil)
        (terms (list #\space #\, #\} )))

    (consume-whitespace stream)
    ;; set-text does not include the #\{ and #\} characters
    (let ((set-text (read-string stream :end-chars '(#\}))))

      (with-input-from-string (stream (string-trim " " set-text))
        (block nil
          (loop
            (let ((feature (read-term stream :end-chars terms)))
              (skip-char stream #\,)
              (consume-whitespace stream)
              (when (and feature (not (equal feature "")))
                (setf set-contents (push feature set-contents)))

              (when (or (null feature)
                        (equal feature "")
                        (equal feature "}"))
                (return))))))
      (skip-char stream #\}))
    (list :set set-contents)))


(defun individual-reader (stream initial-char)
  ;;(format t "~% ===> (individual-reader ~a ~s)~%" stream initial-char)
  initial-char
  (consume-whitespace stream)
  (let ((char (peek-char nil stream nil nil)))
    (cond ((null char) 't)
          ((digit-char-p char)
           (let ((value (read stream nil nil t)))
             (list :id (or value 't))))
          ((char-equal char #\])
           (list :id 't))
          )))





(defun measure-reader (stream initial-char)
  ;;(format t "~% ===> (measure-reader ~a ~s)~%" stream initial-char)
  stream initial-char
  (consume-whitespace stream)
  (let* ((referent-rt-terms (list #\space #\#  #\@  #\[  #\*  #\{  #\]))
         (size (read-number stream)))

    ;;(format t "~&size: ~s" size)
    (consume-whitespace stream)
    (let ((units (read-string stream :end-chars referent-rt-terms)))
      ;;(push (list :measure size) *referent-contents*)
      (list :measure `(,size ,units)))))


(defun asterisk-reader (stream initial-char)
  ;;(format t "~% ===> (asterisk-reader ~a ~s)~%" stream initial-char)
  stream initial-char
  ;;(format t "~&asterisk-reader - initial-char: ~s" initial-char)
  (when (char-equal initial-char #\*)
    (let* ((next-char (peek-char nil stream nil nil)))
      ;;(format t "~&asterisk-reader - char: ~s" char)
      (cond ((and next-char (alpha-char-p next-char))
             (let ((term (read stream nil nil)))
               ;;(push (list :variable term) *referent-contents*)
               (list :variable term)))
            ((and next-char (whitespace-char-p next-char))
             nil)))))

(defmethod read-features (stream)
  (consume-whitespace stream)
  ;;(format t "~&read-features: peek ~s" (peek-char nil stream))

  (let* ((collect (list))
         (ref-rt-mods (list (list #\# #'individual-reader)
                            (list #\@ #'measure-reader)
                            (list #\{ #'set-reader)
                            (list #\[ #'graph-reader)
                            (list #\* #'asterisk-reader)
                            (list #\- #'arc-reader)
                            (list #\] #'concept-ender)))
         (terms (mapcar #'car ref-rt-mods)))
    (with-readtable-mods ref-rt-mods
      (loop
        (let ((token (read-term stream :end-chars terms)))
          (cond ((null token) (return)) ; exit loop
                ((equal token ""))      ; don't exit, don't save
                ((listp token)
                 ;; (push token collect)
                 (setf collect (list* (car token) (cadr token) collect)))))))
    collect))


(defun referent-reader (stream &optional initial-char)
  (format t "~% ===> (referent-reader ~a ~s)~%" stream initial-char)
  initial-char
  (let* ((terms (read-features stream))
         (variable (getf terms :variable)))
    (remf terms :variable)
    (values terms variable)))


(defmethod parse-referent ((referent string))
  (with-input-from-string (stream referent)
    (referent-reader stream)))



;;; initial-char is what was read that caused concept-reader to be called
(defun concept-reader (stream initial-char)
  ;;(format t "~& ===> (concept-reader ~a ~s)~%" stream initial-char)

  (with-readtable-mods (list (list #\: #'referent-reader)
                             (list #\] #'concept-ender))
    (let ((concept nil)
          (*referent-contents* (list)))

      (unless (char-equal initial-char #\[)
        (error "concept parse error"))

      (consume-whitespace stream)
      (multiple-value-bind (concept-type-string next-char)
          (alpha-read stream :alpha-only t)

        ;; we want to be able to read STRINGS as well as SYMBOLS
        (let* ((string-type-p (not (null (find #\" concept-type-string :test #'char-equal))))
               (stripped (remove #\" concept-type-string))
               (type-label (cond (string-type-p stripped)
                                 (t (intern (string-upcase stripped))))))

          ;;(format t "~&type-label: ~s~%"  type-label)

          (cond ((char-equal next-char #\]) ; generic concept, with no referent
                 ;; generic concepts are not cached
                 (setf concept (make-concept type-label nil)))

                ((skip-char stream #\:)
                 (consume-whitespace stream)

                 ;; read referent field
                 (cond ((char-equal (peek-char nil stream) #\[)
                        ;; read a graph from the referent field

                        ;; read the text of the graph and parse it
                        ;; need a context?
                        )
                       (t
                        ;; read features from the referent field
                        (let* ((features (read-features stream))
                               (id (getf features :id))
                               (variable (getf features :variable))
                               (props (sans-prop features :id :variable))
                               (ctype (get-concept-type type-label))
                               (target-concept (or
                                                (when variable
                                                  (variable-node variable))

                                                (get-concept ctype props :id id)
                                                (let ((individual (get-individual ctype :id id :properties props)))
                                                  (unless individual
                                                    (when (and *allow-dynamic-individual-creation*
                                                               (or id
                                                                   (plusp (length props))))
                                                      (unless id (setf id  (next-individual-number)))
                                                      (setf individual (make-individual ctype props :id id))))
                                                  (when individual
                                                    (let ((referent individual))
                                                      (make-concept ctype referent)))))))
                          ;;(format t "~&target-concept: ~s~%"  target-concept)
                          (setf concept target-concept)
                          (when variable
                            (set-variable concept variable))))))

                ;; skip the node-ref, if present
                ((skip-char stream #\+)
                 (read-number stream)))))

      ;; end of concept definition
      (skip-char stream #\] )

      ;;(format t "~&  === leaving concept-reader, returning concept >~s< ~%" concept)
      (when concept
        (values concept 'concept)))))


(defun relation-reader (stream initial-char)
  (when (char-equal initial-char #\()
    (multiple-value-bind (type-string next-char) (alpha-read stream)
      (cond ((char-equal next-char #\.))
            ((char-equal next-char #\))
             (let ((relation-type (get-relation-type (string-upcase type-string))))
               (when relation-type
                 (let ((relation (make-relation relation-type)))
                   ;; clear the next character ())
                   (read-char stream)
                   (return-from relation-reader relation)))))))))


(defun right-arc-reader (stream char)
  (let ((next-char (peek-char nil stream nil nil)))
    (cond ((char= char right-arrow-char)
           (make-arc "->"))
          ((and (char= char #\-) (char= next-char #\>))
           (read-char stream nil nil)
           (make-arc "->")))))

(defun left-arc-reader (stream char)
  (let ((next-char (peek-char nil stream nil nil)))
    (cond ((char= char left-arrow-char)
           (make-arc "<-"))
          ((and (char= char #\<) (char= next-char #\-))
           (read-char stream nil nil)
           (make-arc "<-")))))

(defun arc-reader (stream char)
  (let ((next-char (peek-char nil stream nil nil)))
    (cond ((char= char left-arrow-char)
           (make-arc "<-"))
          ((char= char right-arrow-char)
           (make-arc "->"))
          ((and (char= char #\-) (char= next-char #\>))
           (read-char stream nil nil)
           (make-arc "->"))
          ((and (char= char #\<) (char= next-char #\-))
           (read-char stream nil nil)
           (make-arc "<-"))
          ((char= char #\-)
           (make-arc "-")))))

(defun branch-ender (stream char)
  (declare (ignore stream char))
  #\,)

(defun colon-reader (stream char)
  (declare (ignore stream char))
  #\space)

(defun period-reader (stream char)
  (declare (ignore stream char))
  nil
  #\.)

(defun arc-ender (stream char)
  (declare (ignore stream char))
  #\,)

(defun concept-ender (stream char)
  (declare (ignore stream char))
  ;;(format t "~& --- concept-ender" )
  ;;(throw 'done nil)
  )

(defun cleanup-reader (stream char)
  (declare (ignore stream char))
  ;;(throw 'done nil)
  )



(defparameter *cg-readtable-mods* (list (list #\( #'relation-reader)
                                        (list #\[ #'concept-reader)
                                        ;;(list #\{ #'set-reader)
                                        ;;(list #\@ #'quantity-reader)
                                        (list #\) #'cleanup-reader)
                                        (list #\] #'cleanup-reader)
                                        ;;(list #\} #'cleanup-reader)

                                        (list #\, #'arc-ender)
                                        (list #\< #'left-arc-reader)
                                        (list #\- #'arc-reader)
                                        (list left-arrow-char  #'left-arc-reader)
                                        (list right-arrow-char #'right-arc-reader)
                                        (list #\: #'colon-reader)
                                        (list #\. #'period-reader)))

(defun cg-readtable ()
  (adjust-readtable *cg-readtable-mods* (copy-readtable)))

(defmacro with-cg-readtable (body)
  `(let ((*readtable* (cg-readtable)))
     ,body))

;; (defmethod cg-read (stream)
;;   (with-cg-readtable
;;       (read stream nil nil nil)))


(defmethod read-cg-tokens (stream)
  (let ((tokens (list))
        (cg-readtable-mods (list (list #\( #'relation-reader)
                                 (list #\[ #'concept-reader)
                                 (list #\) #'cleanup-reader)
                                 (list #\] #'cleanup-reader)
                                 (list #\< #'left-arc-reader)
                                 (list #\- #'arc-reader)
                                 (list #\, #'arc-ender)
                                 (list #.(code-char #x2190) #'left-arc-reader)
                                 (list #.(code-char #x2192) #'right-arc-reader)
                                 (list left-arrow-char  #'left-arc-reader)
                                 (list right-arrow-char #'right-arc-reader)
                                 (list #\: #'colon-reader)
                                 (list #\. #'period-reader))))

    (with-readtable-mods cg-readtable-mods
      (block nil
        (loop
          ;; gets an eof read error
          ;;(format t "~&(peek-char stream): ~s" (peek-char nil stream nil nil))
          (let ((token (read stream nil nil nil)))
            ;;(format t "~&token: ~s~%"  token)
            ;;(setq *token token)
            (cond (token
                   (when (or (not (characterp token)) (not (char-equal token #\.)))
                     (push token tokens))
                   (when (concept-p token)
                     ;;(describe token)
                     (pushnew token *concepts-in-graph* :test #'nodes-eq)))
                  (t (return)))))))
    (reverse tokens)))



;;; (frob-substrings s (list right-arrow-string) "->")
;;; (frob-substrings s (list left-arrow-string) "<-")


(defmethod remove-ref-number ((string string))
  (let* ((bang1 (position #\+ string))
         (bang2 (when bang1 (position #\] string :start (1+ bang1)))))
    (if bang2
      (strcat (subseq string 0 bang1) (subseq string (1+ bang2)))
      string)))




(defun parse-cgraph (string)
  (initialize-variables)
  (initialize-context *context*)
  ;; remove the reference number shown in debug mode
  (setf string (remove-ref-number string))
  (let ((*concepts-in-graph* (list)))

    ;; replace arrow-characters with strings
    (setf string (expand-arrows string))

    (with-input-from-string (stream string)
      (let* ((tokens (handler-case (read-cg-tokens stream)
                       (relation-type-lookup-failed (c)
                         (error "PARSE-CGRAPH cannot find relation-type '~a' while parsing '~a'" (text c)  string))
                       (concept-type-lookup-failed (c)
                         (error "PARSE-CGRAPH cannot find concept-type '~a' while parsing '~a'" (text c)  string))
                       (cached-concept-lookup-failed (c)
                         (error "PARSE-CGRAPH cannot lookup concept [~a] while parsing~%\"~a\"~%reason: ~a"
                                (ctype c) string (msg c)))
                       )))

        ;; (format t "~&string: ~s~%"  (remove #\newline (canonicalize-graph-string  string)))
        ;; (format t "~&tokens: ~s~%"  tokens)

        ;;(setq *concepts-in-graph *concepts-in-graph*)
        ;;(setq *tokens tokens)

        (car (linkup tokens))))))



(defmethod pcg ((graph string))
  (parse-cgraph (expand-arrows graph)))


;;; (defgraf foo "[person: Pat]<-(agnt)<-[eat]->(obj)->[food]" )
;;; (pcg foo)
(defmacro defgraf (name graph-string)
  `(progn
     (defvar ,name)
     (with-cg-readtable
         (progn
           (setf ,name (pcg ,graph-string))
           (add-graph ,name)))
     t))
