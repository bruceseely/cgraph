;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;; --- Parse errors -------------------------------------------------------------
;;;
;;; Everything PARSE-CGRAPH can't read is reported as one condition,
;;; CGRAPH-PARSE-ERROR, which says what is wrong and shows where:
;;;
;;;   Can't parse the graph: an arrow joins two concepts, [CAT] and [DOG];
;;;   a relation goes between them, as in [CAT]→(rel)→[DOG]
;;;     [CAT]→[DOG]
;;;          ^
;;;
;;; The readers (reader.lisp) and the linker (LINKUP, graph-utils.lisp) signal
;;; it through PARSE-FAILURE, with a position in the string being read.
;;; PARSE-CGRAPH wraps every other error raised while parsing -- an unknown
;;; type, a concept that doesn't fit its relation -- in the same condition,
;;; keeping the original as its CAUSE, and maps the position back onto the
;;; string the caller passed. This file comes before both, so the readers and
;;; the linker can signal it.
;;;
;;; This replaced a TOKEN-PARSE-ERROR that said only "Unable to parse token
;;; after:" plus what had parsed so far, and a linker that printed "unhandled
;;; by linkup" and returned a different graph from the one written.

(define-condition cgraph-parse-error (error)
  ((string   :initarg :string   :initform nil :reader parse-error-string)
   (position :initarg :position :initform nil :reader parse-error-position)
   (message  :initarg :message  :initform nil :reader parse-error-message)
   (cause    :initarg :cause    :initform nil :reader parse-error-cause))
  (:report report-cgraph-parse-error)
  (:documentation "Signalled by PARSE-CGRAPH (and so MAKE-CGRAPH) on a graph
   string it can't read. STRING is the string as passed, POSITION the index in
   it where the problem was found (or NIL), MESSAGE what is wrong, and CAUSE
   the underlying condition when there was one."))

(defun report-cgraph-parse-error (condition stream)
  (format stream "Can't parse the graph: ~a" (parse-error-message condition))
  (let ((string   (parse-error-string condition))
        (position (parse-error-position condition)))
    (when string
      (if (and position (<= 0 position (length string)))
          ;; Show the line the problem is on, with a caret under it.
          (let* ((position (or (position-if-not (lambda (char)
                                                  (member char '(#\Space #\Tab #\Newline #\Return)))
                                                string :start position)
                               position))
                 (start    (let ((newline (position #\Newline string :end position
                                                    :from-end t)))
                             (if newline (1+ newline) 0)))
                 (end      (or (position #\Newline string :start position)
                               (length string))))
            (format stream "~%  ~a~%  ~a^" (subseq string start end)
                    (make-string (- position start) :initial-element #\Space)))
          (format stream "~%  in: ~a" string)))))

(defvar *parse-stream* nil
  "The stream PARSE-CGRAPH is reading, so a failure can say where it is.")

(defvar *token-positions* nil
  "Token -> the stream position it was read from, for the parse in progress.
   The linker runs after the whole string is read, so it finds the position of
   the token it can't link here.")

(defvar *node-start* nil
  "Where the concept or relation being read began: its [ or (. An unknown
   type is reported there, rather than after the name, where the reader has
   got to.")

(defvar *graph-referent-closed* nil
  "Set by the graph-referent reader when the inner graph's closing ] has been
   consumed, so the concept reader doesn't look for, and eat, another.")

(defun parse-stream-position ()
  (and *parse-stream* (ignore-errors (file-position *parse-stream*))))

(defun token-position (token)
  (and *token-positions* token (gethash token *token-positions*)))

(defun parse-failure (position format-control &rest arguments)
  "Signal a CGRAPH-PARSE-ERROR at POSITION in the stream being parsed (by
   default where the stream is now). PARSE-CGRAPH fills in the string."
  (error 'cgraph-parse-error
         :position (or position (parse-stream-position))
         :message (let ((*always-format-nodes* t))
                    (apply #'format nil format-control arguments))))
