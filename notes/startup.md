## Startup

Code like the following is useful for loading and starting up the CGraph system:

```lisp
;; in package cl-user
(require :asdf)
  
(defpackage :conceptual-graphs
  (:use :cl :cl-user :asdf :uiop)
  (:nicknames :cg :cgraph))

(defun cgraph ()
  (let* ((types-repo-path (format nil "~arepo/cgraph-types/" 
                                      (namestring (user-homedir-pathname))))
         (code-path (format nil "~arepo/cgraph/" (namestring (user-homedir-pathname))))
         (cgraph-definition (format nil "~acgraph.asd" code-path)))
    (unless (asdf:component-loaded-p (asdf:find-system :cgraph nil))
            (load cgraph-definition)
            (asdf:compile-system :cgraph)
            (asdf:load-system :cgraph))

   (cg::setup-cgraph))
```

(Note: this assumes that the asdf cgraph definition file is stored in one of the places where asdf looks for definitions. Alternatively, Lisp cound explicitly load the asdf cgraph definition file before the asdf:load-system call.)

I have this in my .sbclrc file, so after SBCL starts in the cl-user package, I can just call (cgraph) to load and startup the CGraph system. Since the function is created in the user package, it must qualify its invocation of `setup-cgraph` with the cg package. I have a repo where type definitions are saved.

#### Directories

The first time CGraph starts up, it ensures a directory exists in the user's home directory, named .cgraph, and saves the path in `*cgraph*` special variable. The .cgraph directory is where individual customization occurs and temporary files are stored.  The variables `*cgraph-data*` and `*cgraph-types*` are bound to the `data/` and `types/` sub-directories of the `*cgraph*` directory.

The `*cgraph-types*` directory points at the /types subdirectory of .cgraph. That diirectory holds the Lisp files with concept-type definitions and relation-type Lisp definitions. The user can modify the type definitions and add new types here. At startup, the code looks for files named exactly 'concept-types.lisp' and 'relation-types.lisp' in the  `*cgraph-types*` directory.  If either file is missing when types are initialized, the file will be created. The initial contents for these files is contained in a couple text files in the default-types directory in the source code area. These files contain definitions mostly gleaned from Sowa's 1984 book 'Conceptual Structures'.

A practical way of maintaining custom type definitions is to store them in a git repo and link the two filenames mentioned above to the files in the repo. As long as the code sees a file with one of those names, that file will be left alone. 

The`(initialize-types)`function parses the type files in \*cgraph-types\* directory to create type objects and it evaluates the forms in the  `initializations.lisp` file. It should be run after changes are made to the type definitions.

The `*cgraph-data*` directory holds temporary files, like the dot files and png files generated when the concept-types are displayed as a graph, using  `(graph-concept-types)`.

#### Startup sequence

- user starts Lisp with m-x slime or c-x l

- .sbclrc file loaded (when SBCL starts up)

  - load libraries
  - define conceptual-graphs package
  - defines cgraph() function in user package
    - reports version info
    - uses ASDF to compile and load the cgraph system 
    - calls cg::setup-cgraph() in initialize.lisp
  - REPL prompt in cl-user package

- user calls (cgraph) in REPL

  - cgraph calls setup-cgraph in the cg package

  - setup-cgraph() in initialize.lisp runs
    - ensure type files are available
    - load concept-types and relation-types
    - setup default package for SLIME worker thread
    - housekeeping
      - remove fasl files from code source
      - report locations of important directories
      - run regression tests and report results
    - REPL  is in the CG package

- The initialize.lisp file, containing the setup-cgraph function is within the cgraph system.
- The .sbcl file, containing the cgraph function, is not within the cgraph system
  and is not in the cgraph git repo. It needs to be installed separately.
