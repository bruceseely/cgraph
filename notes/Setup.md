## CGraph Setup

This describes my setup. If you use different systems, you'll need to do the translation. 
I am on MacOS, running SBCL under Emacs and Slime, optionally using Graphviz.

- Emacs - loaded from  https://emacsformacosx.com
- SBCL - loaded with `Homebrew`
- Slime - loaded with MELPA

The file **~/.sbcl** is loaded by SBCL after Lisp is setup.  The file contains the function *cgraph*() that users, still in the `cl-user` package, call to start CGraph. This function 

- is where the location of the cgraph code and an optional external directory containing types, are supplied
- loads the cgraph system definition and system, using `asdf`
- calls the *setup-cgraph*() function to load and initialize CGraph

This is my current version of the *cgraph*() function

````lisp
(defun cgraph ()
  (report-version-info)
  (let* ((repo-base (uiop:strcat (namestring (user-homedir-pathname)) "repo/"))
         (types-repo-path (uiop:strcat repo-base "cgraph-types/"))
         (code-path (uiop:strcat repo-base "cgraph/"))
         (cgraph-definition-file (uiop:strcat code-path "cgraph.asd"))
         (system-definition (asdf:find-system :cgraph nil)))
    (unless (asdf:component-loaded-p system-definition)
      (load cgraph-definition-file)
      (asdf:compile-system :cgraph)
      (asdf:load-system :cgraph))
    (start-cgraph code-path :external-types-directory types-repo-path)))
````

NOTE: The *cgraph*() function source is included here because it is not included in the cgraph repository, since the function is outside the cgraph system and used to start the system running.

The *start-cgraph*() function is in the `CGraph` code.  It ensures that `*package*` indicates the conceptual-graphs package. The package is defined in the system file, but is replicated as insurance. The :conceptual-graphs package has nicknames :cgraph and :cg. After the package is created, the function *setup-cgraph*() is called. It does the following:

- sets up some directories (see below)
- does some stuff for `Slime`
- removes detritus from the code area, resulting from debugging, like `fasl` files
- reports directory locations
- starts a web server
- runs regression tests

At that point, a REPL should open with a prompt indicating the `:cg` package.

#### directories

When CGraph starts up, it ensures that a directory named `~/.cgraph/` exists and saves the path in the `*cgraph*` special variable. The `.cgraph` directory is where individual customization occurs and temporary files are stored.  The variables `*cgraph-data*` and `*cgraph-types*` are bound to the `~/.cgraph/data/` and `~/.cgraph/types/` directories.

##### external-types-directory

The concept-type and relation-type definitions used during operation are held in the directory `~/.cgraph/types/` The user can modify these type definitions and add new type definitions here.

The `:external-types-directory`  argument, to *setup-cgraph*() function, allows the use of an external directory, such as a directory in a git repository, to hold concept-type and relation-type definitions. If provided, symbolic links are established from  ``~/.cgraph/types/`` to the files in the supplied directory. 

On startup, cgraph ensures the directories are populated. The function *setup-cgraph*() looks for files named exactly `concept-types.lisp` and `relation-types.lisp` in the  `*cgraph-types*` directory. If either file is missing then the types are initialized as described here:

- the `~/.cgraph/types/` directory contains the two files `concept-types.lisp` and `relation-types.lisp`:  nothing is done
- the `~/.cgraph/types/` directory is empty but `:external-types-directory` is provided: links are generated to the supplied directory
- the `~/.cgraph/types/` directory is empty and :external-types-directory is NIL, the files concept-types.lisp and relation-types.lisp containing default concept and relation types are copied from a source code directory into the ``~/.cgraph/types/`` directory

The `~/.cgraph/types/` directory holds the Lisp files with concept-type definitions and relation-type definitions that are actively used. 

So, a practical way of maintaining custom type definitions is to store them in a git repo called cgraph-types and link the two filenames mentioned above to the files in the repo. As long as the code sees a file with one of those names, that file will be left alone. 

The `(initialize-types)` function parses the type files in `*cgraph-types*` directory to create type objects and it evaluates the forms in the  `initializations.lisp` file. It should be run after changes are made to the type definitions.

The `*cgraph-data*` directory holds temporary files, like the dot files and png files generated when the concept-types are displayed as a graph, using  `(graph-concept-types)`.

### Emacs connection

CGraph was designed to be run from an Emacs REPL. This allows the definition of aids to facilitate use of the program. The relevant code is in the  `emacs` directory in the `*cgraph*` source directory.   

- file `dot-swank.lisp`
  
  Copy the file to the  directory `~/.swank`
  This file makes a modification to swank so that compiling a file during debugging
  creates its fasl file in the location that asdf uses, not the source code directory.
  
- .el files 
  The files are found in `cgraph/emacs/`

  - graphviz-dot-mode.el
    for graph-concept-types() and display-graph()

  - cg-utils.el

  - cg-mode.el
    not currently used
  - cg-indent.el
    used with cg-mode
  




### Startup sequence

- user starts Lisp with m-x slime or c-x l

- `.sbclrc` file is loaded (when SBCL starts up)

  - load libraries
  - define conceptual-graphs package
  - defines cgraph() function in user package
    - reports version info
    - uses ASDF to compile and load the cgraph system 
    - calls *cg::setup-cgraph*() in initialize.lisp
  - REPL opens with a prompt in `cl-user` package

- user calls `(cgraph)` in the REPL,  in `cl-user` package

  - *cgraph*() calls *setup-cgraph*() in the `cg` package

  - *setup-cgraph*() in `initialize.lisp` runs
    - ensure type files are available
    - load concept-types and relation-types
    - setup default package for SLIME worker thread
    - housekeeping
      - remove any fasl files from code source
      - report locations of important directories
      - run regression tests and report results
    - REPL  is in the CG package

  
