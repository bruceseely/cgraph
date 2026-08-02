
(in-package #:conceptual-graphs)


;;; unicode characters
;;; https://symbl.cc/en/unicode-table/

(defvar marked-char (code-char #x2714))
(defvar marked-string (princ-to-string marked-char))


(defvar top-concept-type (intern (string (code-char #x22A4)) :cg)) ;a symbol
(defvar top-concept-type-string (princ-to-string top-concept-type))

(defvar bottom-concept-type (intern (string (code-char #x22A5)) :cg)) ;a symbol
(defvar bottom-concept-type-string (princ-to-string bottom-concept-type))



(defvar left-arrow (code-char #x2190))
(defvar left-arrow-char left-arrow)
(defvar left-arrow-string (princ-to-string left-arrow))
(defvar left-arrow-arc)

(defvar right-arrow (code-char #x2192))
(defvar right-arrow-char right-arrow)
(defvar right-arrow-string (princ-to-string right-arrow))
(defvar right-arrow-arc)

(defvar larrow left-arrow)
(defvar rarrow right-arrow)
(defvar marrow #\-)

(defvar nope (code-char #x2310))
(defvar nope-char nope)
(defvar nope-string (princ-to-string nope))

;;; directory containing the concept-types and relation-types directories
;;; values are set in setup-cgraph() in initialize.lisp

(defvar *home* (namestring (user-homedir-pathname)))
(defvar *cgraph* nil)

;;; set by user
(defvar *cgraph-types-repo* (format nil "~a/repo/cgraph-types/" *home*))

;;; for overriding the directories holding types and data diretories
(defvar *cgraph-types-directory* nil)
(defvar *cgraph-examples-directory* nil)
(defvar *cgraph-data-directory* nil)
(defvar *cgraph-log-directory* nil)
(defvar *external-types-directory* nil)

;;; Tracks which type catalog is currently in memory so callers can avoid
;;; redundant unload/reload cycles. NIL means no types loaded;
;;; :default means the example types were copied (no external source);
;;; otherwise holds the external-directory string that was loaded from.
(defvar *loaded-types-source* nil)

(defvar *cgraph-inits*  ())

;;; holds the current conttext
(defvar *context* nil)

;;; show [dog] instead of [dog:*]

(defvar *concepts-in-graph* ())

;;; modifies how segments & concepts are printed
(defvar *concise* t)
(defvar *debug-mode* nil)
(defvar *include-node-ref* nil)

(defvar *current-individual-number* 1)
(defvar *dynamically-create-individuals* t)
(defvar *node-ref-counter*)

(defvar *individuals* (list))

;;; store individual, indexed by id
;;; number -> indiv
(defvar *individual-id-table* (make-hash-table :test #'eql))

;;; all individuals are entered here
;;; cocept-type symbol -> (list of indiv)
(defvar *individual-type-table* (make-hash-table :test #'eql))

;; (cons type properties) -> indiv; for [DOG: Spot #]
(defvar *individual-property-table* (make-hash-table :test #'equalp))

(defvar *individual-id-assignment* :suitable)

(defvar *negated-concept* nil)
(defvar *in-graph-referent* nil)
(defvar *copy-map* (list))


(defvar *allow-dynamic-individual-creation* nil
  "The host system may want to define individuals, itself, and not have new individuals dynamically created. ")

(defvar *always-show-node-ref* nil
  "This is useful during debugging, so nodes that have the same printed representation can be distinguished.")

(defvar *always-format-nodes* nil
  "Causes nodes to be formatted as they look in graphs, rather than as Lisp objects.")

(defvar *mass-type-p* nil
  "Function of one concept type, true when that type names a mass noun.

   The reader needs this to tell `[DOG: @5]' (five dogs) from `[WATER: @5]'
   (five of whatever water is measured in), but mass-noun knowledge lives in
   the lexicon, which is part of generation and loads AFTER core. So core
   declares the hole and generation fills it, rather than core reaching
   forward into a module that depends on it.

   NIL means nothing has taught the reader about mass nouns yet, in which
   case every type is treated as countable.")

(defvar *always-print-ascii-arrows* nil
  "Use the string (eg. \"->\") instead of the single-character arrow (eg. →)")

(defvar *indent-graph-referents* nil
  "When non-nil, format-cgraph places each nested graph referent on a new
   line, indented one *graph-referent-indent* step further than its parent.
   Useful for reading deeply-nested contexts (PROPOSITION, SITUATION, etc.).")

(defvar *graph-referent-indent* 4
  "Number of spaces added per nesting level when *indent-graph-referents* is set.")

(defvar *print-without-variables* nil)

(defvar *run-tests-on-startup* t
  "When non-NIL, start-cgraph runs the test suite at startup.
   Useful while making modifications; can be disabled during regular
   use to skip the test report.")

(defvar *canonical-graph-format* :linear
  "How the concept-type editor's Canonical Graphs pane renders an entry.
   Values:
     :LINEAR - CG linear notation, as the formatter produces it. The
               default: it is the notation you write and read
               everywhere else in cgraph.
     :GRAPH  - the rendered graphviz diagram.
   Supplies the pane's initial View setting; the Graph/Linear buttons
   in the pane still switch it for the current page. An entry falls
   back to whichever form it has when the preferred one is
   unavailable.")

(defvar *web-log-destination* :file
  "Where the web server writes its access and message logs.
   Values:
     :FILE  - append to web-access.log / web-message.log in
              *CGRAPH-LOG-DIRECTORY* (~/.cgraph/logs/). The default:
              every browser request the type editor makes would
              otherwise print a line to the REPL.
     :REPL  - Hunchentoot's own default, *ERROR-OUTPUT*, which under
              SLIME is the REPL. Useful when actively debugging a
              handler and you want the requests interleaved with your
              own output.
     NIL    - no logging at all.
   Takes effect at START-WEB-SERVER. To change it on a server that is
   already running, call APPLY-WEB-LOG-DESTINATIONS.")

(defvar *run-lexicon-lint-on-startup* :all
  "Controls whether and how report-lexicon-lint runs at startup.
   Values:
     NIL               - don't run.
     :ERRORS-ONLY      - run, show only error-level findings (silent
                         unless something is broken).
     :ERRORS-WARNINGS  - run, show errors and warnings.
     :ALL (or T)       - run, show all findings (errors, warnings,
                         info).
   Default is :ALL, which matches the historical 'on' behavior. Set
   to :ERRORS-ONLY for regular use, switch back to :ALL while
   modifying types or relations.")
