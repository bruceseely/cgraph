;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Graph-editor sessions.
;;
;;  EDIT-CGRAPH is called from the REPL and blocks until the browser posts
;;  a commit or a cancel:
;;
;;    CG> (edit-cgraph g)
;;       ;; a window opens, you edit, you press UPDATE
;;    [DOG]<-(agnt)<-[EAT]->(obj)->[FOOD].
;;
;;  So a session spans two threads: the caller's (blocked on a semaphore)
;;  and Hunchentoot's worker threads (which apply operations and eventually
;;  signal). Everything here exists to make that handoff safe.
;;
;;  The central rule, from notes/graph-editor.md: NEVER MUTATE THE ORIGINAL
;;  UNTIL COMMIT. The session edits a working graph; commit installs it,
;;  cancel discards it and the original was never touched. That is what makes
;;  cancel free at every level of nesting, and it is the only affordable
;;  option anyway -- a live graph cannot be snapshotted by copying, because
;;  copying mints new node objects and a node-ref names a specific Lisp
;;  object.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar *editor-sessions* (make-hash-table :test 'eql)
  "Live editor sessions, keyed by integer id.")

(defvar *editor-sessions-lock* (bt:make-lock "cgraph-editor-sessions")
  "Guards *EDITOR-SESSIONS* and the counter. Handler threads and the caller's
   thread both reach the table.")

(defvar *editor-session-counter* 0)

(defvar *editor-port* 8060
  "Port the editor is served from. The editor registers its handlers on the
   same acceptor as the type browser, so this is the type browser's port.")

(defvar *editor-browser-command* :default
  "How EDIT-CGRAPH opens a window.
     :DEFAULT - hand the URL to the system default browser (macOS `open`).
     :APP     - Chrome in --app mode: a window with no tab strip or address
                bar, which is what you want beside the type browser.
     NIL      - don't open anything; print the URL and wait. Useful when
                driving the editor from a test, or when a window is already
                open.
   Any other value is taken as a list of program arguments, with the URL
   appended.")

(defvar *editor-open-timeout* nil
  "Seconds EDIT-CGRAPH will block before giving up, or NIL to wait forever.
   A closed tab currently leaves a session waiting -- see the session-lifetime
   question in notes/graph-editor.md -- so a timeout is the blunt safety net
   until that is designed.")

(defstruct (editor-session (:conc-name session-))
  id
  original          ; the graph (or string) the caller handed us; never mutated
  kind              ; :graph or :string
  working           ; the graph being edited -- a separate object
  parent            ; parent session, for nested editors
  (semaphore (bt:make-semaphore))
  (state :open)     ; :open | :committed | :cancelled -- the LIFECYCLE
  result
  ;; Connection state, which is orthogonal to lifecycle: a session with no
  ;; browser attached is still :OPEN and still holds its work. Closing a tab is
  ;; not a decision to discard anything -- cancel is an explicit act, with a
  ;; button -- so a disconnect leaves the session resumable at its URL.
  (connected nil)
  last-seen         ; universal-time of the last request; NIL until first seen
  (created (get-universal-time))
  ;; The caller's *STANDARD-OUTPUT*, captured at EDIT-CGRAPH time. Handler
  ;; threads inherit none of the caller's bindings, so without this there is no
  ;; way to tell the REPL that its browser went away -- and a blocked REPL that
  ;; looks identical whether you are mid-edit or long gone is the whole problem.
  out)

;;; --- Registry --------------------------------------------------------------

(defun register-editor-session (session)
  (bt:with-lock-held (*editor-sessions-lock*)
    (setf (session-id session) (incf *editor-session-counter*))
    (setf (gethash (session-id session) *editor-sessions*) session))
  session)

(defun find-editor-session (id)
  "Session for ID, or NIL. ID may be an integer or a string from a query
   parameter."
  (let ((n (etypecase id
             (integer id)
             (string (parse-integer id :junk-allowed t))
             (null nil))))
    (when n
      (bt:with-lock-held (*editor-sessions-lock*)
        (gethash n *editor-sessions*)))))

(defun forget-editor-session (session)
  (bt:with-lock-held (*editor-sessions-lock*)
    (remhash (session-id session) *editor-sessions*)))

(defun editor-sessions ()
  "All live sessions, for inspection from the REPL."
  (bt:with-lock-held (*editor-sessions-lock*)
    (loop for s being the hash-values of *editor-sessions* collect s)))

;;; --- Telling the caller what happened ---------------------------------------

(defun announce-to-caller (session control &rest args)
  "Write a line to the thread that called EDIT-CGRAPH. Best-effort: the caller
   may have been interrupted and its stream closed, and losing a notice must
   never break a request."
  (let ((out (session-out session)))
    (when out
      (ignore-errors
       (format out "~&;; ~?~%" control args)
       (finish-output out)))))

(defun session-age-string (session)
  (let ((secs (- (get-universal-time) (session-created session))))
    (cond ((< secs 60) (format nil "~ds" secs))
          ((< secs 3600) (format nil "~dm" (floor secs 60)))
          (t (format nil "~,1fh" (/ secs 3600.0))))))

(defun touch-editor-session (session)
  "Note that the browser is alive. Announces a RECONNECT -- but only when the
   session had been seen before and then dropped, so an ordinary first load is
   silent and a reload reads as disconnect-then-reconnect rather than an alarm."
  (let ((reconnected nil))
    (bt:with-lock-held (*editor-sessions-lock*)
      (when (and (not (session-connected session)) (session-last-seen session))
        (setf reconnected t))
      (setf (session-connected session) t
            (session-last-seen session) (get-universal-time)))
    (when reconnected
      (announce-to-caller session "editor session ~a: browser reconnected."
                          (session-id session)))
    session))

(defun disconnect-editor-session (session)
  "The page says it is going away. The session survives -- it keeps its working
   graph and stays resumable at its URL. Announce it, because otherwise the
   REPL sits blocked looking exactly as it did while you were editing, which is
   the one thing that must not happen."
  (let ((announce nil))
    (bt:with-lock-held (*editor-sessions-lock*)
      (when (and (session-connected session) (eq (session-state session) :open))
        (setf (session-connected session) nil
              announce t)))
    (when announce
      (announce-to-caller
       session
       "editor session ~a: browser disconnected; the call is still waiting.~%~
        ;;   reopen:  ~a~%~
        ;;   abandon: (cg::cancel-editor-session ~a)"
       (session-id session) (editor-session-url session) (session-id session)))
    session))

(defmethod print-object ((session editor-session) stream)
  (print-unreadable-object (session stream :type nil :identity nil)
    (let ((graph (ignore-errors
                  (let ((s (session-plain-render session)))
                    (if (> (length s) 46)
                        (concatenate 'string (subseq s 0 43) "...")
                        s)))))
      (format stream "EDITOR-SESSION ~a ~(:~a~)~@[ :disconnected~*~] ~a~@[ ~a~]"
              (session-id session)
              (session-state session)
              (and (eq (session-state session) :open)
                   (not (session-connected session))
                   (session-last-seen session))
              (session-age-string session)
              (substitute #\Space #\Newline (or graph ""))))))

;;; --- Working copies --------------------------------------------------------
;;;
;;; The working graph has to be a genuinely separate object graph, so that
;;; cancel is a no-op. Round-tripping through the linear form is the honest way
;;; to get one: PARSE-CGRAPH mints new nodes, which is exactly what we want
;;; here (and exactly what makes it useless as a snapshot mechanism elsewhere).
;;;
;;; *PACKAGE* is bound explicitly because this runs in Hunchentoot worker
;;; threads as well as the caller's, and a handler thread does not inherit the
;;; REPL's bindings -- the same reason FORMATTED-CANONICAL-GRAPH-STRING binds
;;; it (types.lisp).

(defmacro with-cg-thread-bindings (&body body)
  "Bindings the CG reader and formatter need, established explicitly so the
   code works the same in a Hunchentoot worker thread as at the REPL."
  `(let ((*package* (find-package "CONCEPTUAL-GRAPHS"))
         (*readtable* *readtable*))
     ,@body))

(defun graph-source-string (thing)
  "Linear notation for THING, whatever form it arrived in."
  (with-cg-thread-bindings
    (etypecase thing
      (string thing)
      (graph (format-cgraph thing))
      (cons (format-cgraph thing))
      (null ""))))

(defun make-working-graph (source)
  "A fresh, independent graph parsed from SOURCE (linear notation). Returns
   NIL for an empty source -- a new graph starts with no nodes.

   Deliberately NOT via MAKE-CGRAPH: that calls ADD-CGRAPH, which would file
   every throwaway working copy in the global *CONTEXT* and leave the
   cancelled ones there. A working graph is detached until commit installs it
   into an original that is already in the context."
  (with-cg-thread-bindings
    (when (and source (plusp (length (string-trim '(#\Space #\Tab #\Newline)
                                                  source))))
      (let ((nodes (parse-cgraph source)))
        (when nodes
          (make-instance 'graph :head (car nodes)))))))

(defun concept-owning-graph (concept)
  "The graph in the current context that CONCEPT belongs to, or NIL.
   `A concept, indicating the graph it is part of.'"
  (when (and *context* concept)
    (find-if (lambda (g) (member concept (nodes g) :test #'eq))
             (graphs *context*))))

;;; --- Rendering for the browser ---------------------------------------------
;;;
;;; Refs travel outbound only, as a rendering: the page strips them for display
;;; and keeps the mapping for click targets. They never come back as text --
;;; the reader rejects +NNNN deliberately, since a string that can assert node
;;; identity can forge it.

(defun session-render (session)
  "The working graph as linear notation WITH node-refs, for the browser."
  (with-cg-thread-bindings
    (let ((g (session-working session)))
      (if (null g)
          ""
          (let ((*always-show-node-ref* t))
            (format-cgraph g))))))

(defun session-plain-render (session)
  "The working graph as ordinary linear notation, no refs. What the caller
   gets back, and what the REPL prints."
  (graph-source-string (session-working session)))

;;; --- Finishing -------------------------------------------------------------

(defun session-node (session ref)
  "The node in SESSION's working graph whose node-ref is REF, or NIL.
   Refs are resolved against nodes the session already holds, so an unknown
   or forged ref is a rejected operation rather than a fabricated node."
  (let ((n (etypecase ref
             (integer ref)
             (string (parse-integer ref :junk-allowed t))
             (null nil)))
        (g (session-working session)))
    (when (and n g)
      (find n (nodes g) :key #'node-ref :test #'eql))))

(defun install-working-graph (session)
  "Install the working graph into the original. For a graph, this sets the
   original's HEAD -- preserving the original object's identity, and with it
   the HOLDERS back-pointers that make an enclosing concept's referent keep
   working. For a string, the caller just gets the new string."
  (ecase (session-kind session)
    (:string (session-plain-render session))
    (:graph
     (let ((original (session-original session))
           (working  (session-working session)))
       (when (and original working)
         (setf (head original) (head working)))
       original))
    ;; A nested graph referent. ORIGINAL is the enclosing CONCEPT, because the
    ;; graph it will hold need not exist until there is something to put in it
    ;; -- an empty graph cannot be formatted, so one attached early would break
    ;; rendering of the graph above.
    (:graph-referent
     (let* ((concept  (session-original session))
            (working  (session-working session))
            (existing (and concept (graph-referent concept))))
       (cond
         ;; Already had one: set its head, keeping the same graph OBJECT and
         ;; with it the HOLDERS back-pointer the concept's referent rests on.
         ((and existing working) (setf (head existing) (head working)))
         ;; First content it has ever had: attach the working graph itself.
         (working
          (let ((referent (make-referent working concept)))
            (setf (referent concept) referent)
            (setf (concept referent) concept)))
         ;; Emptied: a concept with a graph referent holding nothing is not a
         ;; thing the formatter can render, so committing nothing removes the
         ;; referent rather than leaving an unprintable husk.
         (t (setf (referent concept) nil)))
       concept))))

(defun finish-editor-session (session state)
  "Complete SESSION as :COMMITTED or :CANCELLED, and release the blocked
   caller. Safe to call more than once -- a double commit, or a cancel racing
   a commit, must not signal the semaphore twice."
  (let ((finished nil))
    (bt:with-lock-held (*editor-sessions-lock*)
      (when (eq (session-state session) :open)
        (setf (session-state session) state
              finished t)))
    (when finished
      (setf (session-result session)
            (ecase state
              (:committed (install-working-graph session))
              (:cancelled (session-original session))))
      (bt:signal-semaphore (session-semaphore session)))
    finished))

;;; --- Opening a window ------------------------------------------------------

(defun sync-editor-port ()
  "Point *EDITOR-PORT* at the port the server is actually listening on.

   The editor registers its handlers on the type browser's acceptor, so the
   8060 default is right until someone starts the server somewhere else -- and
   then every URL the editor prints is wrong in a way that reads as a broken
   editor rather than a mismatched port. Ask the acceptor instead of assuming.

   Silent when no server is running: the default then stands, which is what
   the tests want, since they never open a window."
  (when *web-acceptor*
    (setf *editor-port* (hunchentoot:acceptor-port *web-acceptor*))))

(defun editor-session-url (session)
  (format nil "http://localhost:~a/editor?session=~a"
          *editor-port* (session-id session)))

(defun open-editor-window (session)
  "Open a browser on SESSION, per *EDITOR-BROWSER-COMMAND*. Failing to open a
   window must not break the session -- the URL is printed either way, so the
   caller can always reach it by hand."
  (let* ((url (editor-session-url session))
         (argv (case *editor-browser-command*
                 ((nil)    nil)
                 (:default (list "open" url))
                 (:app     (list "open" "-na" "Google Chrome" "--args"
                                 (format nil "--app=~a" url)))
                 (t        (append *editor-browser-command* (list url))))))
    (format t "~&;; cgraph editor session ~a: ~a~%" (session-id session) url)
    (when argv
      (handler-case (uiop:run-program argv :ignore-error-status t)
        (error (e)
          (format t "~&;; could not open a browser (~a); open the URL above.~%"
                  e))))
    url))

;;; --- Entry points ----------------------------------------------------------

(defun edit-cgraph (&optional thing &key parent (open t))
  "Edit THING in a browser, blocking until UPDATE or CANCEL.

   THING may be a GRAPH (edited in place at commit, identity preserved), a
   STRING of linear notation (the edited string is returned), a CONCEPT (the
   graph it belongs to), or NIL/omitted to start a new graph.

   Returns (VALUES RESULT COMMITTED-P). On cancel, RESULT is what was passed
   in, untouched.

   OPEN NIL skips launching a browser -- the URL is printed and the call still
   blocks, which is how the tests drive it."
  (sync-editor-port)
  (let* ((kind (etypecase thing
                 (null    :graph)
                 (string  :string)
                 (graph   :graph)
                 (concept :graph)))
         (subject (if (typep thing 'concept)
                      (or (concept-owning-graph thing)
                          (error "~s does not belong to a graph in the current context."
                                 thing))
                      thing))
         (session (make-editor-session
                   :original subject
                   :kind kind
                   :parent parent
                   ;; Captured here, in the caller's thread, because handler
                   ;; threads have no way to reach it later.
                   :out *standard-output*
                   :working (make-working-graph (graph-source-string subject)))))
    (register-editor-session session)
    (unwind-protect
         (progn
           (let ((*editor-browser-command* (if open *editor-browser-command* nil)))
             (open-editor-window session))
           (let ((got (if *editor-open-timeout*
                          (bt:wait-on-semaphore (session-semaphore session)
                                                :timeout *editor-open-timeout*)
                          (bt:wait-on-semaphore (session-semaphore session)))))
             (unless got
               (finish-editor-session session :cancelled)
               (format t "~&;; editor session ~a timed out~%" (session-id session))))
           (values (session-result session)
                   (eq (session-state session) :committed)))
      (forget-editor-session session))))

(defun new-cgraph ()
  "Start the editor on an empty graph. Alias for (EDIT-CGRAPH)."
  (edit-cgraph))

(defun cancel-editor-session (&optional id)
  "Abandon editor session ID, releasing the EDIT-CGRAPH call that is waiting on
   it. With no ID, abandons every open session.

   For the session whose browser went away and is not coming back. Note that
   the waiting REPL cannot evaluate this -- its thread is blocked -- so call it
   from a source buffer, where SLIME uses a separate worker thread. C-c C-c in
   the blocked REPL is the guaranteed alternative: it unwinds the wait and the
   UNWIND-PROTECT in EDIT-CGRAPH cleans up."
  (let ((targets (if id
                     (let ((s (find-editor-session id)))
                       (if s (list s) (progn (format t "~&;; no editor session ~a~%" id)
                                             nil)))
                     (remove-if-not (lambda (s) (eq (session-state s) :open))
                                    (editor-sessions)))))
    (dolist (s targets)
      (when (finish-editor-session s :cancelled)
        (format t "~&;; editor session ~a cancelled~%" (session-id s))))
    (length targets)))
