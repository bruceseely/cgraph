## CGraph Setup

This describes my setup. If you use different systems, you'll need to do the translation. 
I am on MacOS, running SBCL Lisp under Emacs and Slime.

- Emacs - loaded from https://emacsformacosx.com/
- SBCL - loaded with Homebrew
- Slime - loaded with MELPA

The file **~/.sbcl** is loaded by SBCL after Lisp is setup.  The file contains the function **cgraph()** that users, still in the cl-users package, call to start CGraph. This function 

- is where the location of the cgraph code and an optional external directory containing types, are supplied
- loads the cgraph system definition and system, using asdf
- calls the setup-cgraph() function to load and initialize CGraph

This is my current version of the cgraph() function

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

The start-cgraph() function is in the CGraph code.  It ensures that \*package* contains  the conceptual-graphs package. The package is defined in the system file, but is replicated here, just in case. The :conceptual-graphs package has nicknames :cgraph and :cg. After the package is setup, the function setup-cgraph() is called. It 

- sets up some directories (see below)
- does some stuff for Slime
- removes detritus from the code area, resulting from debugging, like fasl files
- reports directory locations
- starts a web server
- runs regression tests

At that point, a REPL should open with a prompt indicating the :cg package.

#### external-types-directory

The concept-type and relation-type definitions are held in the directory ~/.cgraph/types/ 
The :external-types-directory argument allows the use of a git repo, or other directory, to hold concept-type and relation-type definitions. If provided, symbolic links are provided to the files in the supplied directory. 

On startup, cgraph ensures the directories are populated. Possible scenarios are:

- the directory contains the two files concept-types.lisp and relation-types.lisp:  nothing is done
- the directory is empty but :external-types-directory is provided: links are generated to the supplies directory
- the directory is empty and :external-types-directory is nil: two files of default types are copied into the directory

#### directories

When CGraph starts up, it ensures a directory exists in the user's home directory, named .cgraph, and saves the path in `*cgraph*` special variable. The .cgraph directory is where individual customization occurs and temporary files are stored.  The variables `*cgraph-data*` and `*cgraph-types*` are bound to the `data/` and `types/` sub-directories of the `*cgraph*` directory.

The `*cgraph-types*` directory points at the /types subdirectory of .cgraph. That diirectory holds the Lisp files with concept-type definitions and relation-type Lisp definitions. The user can modify the type definitions and add new types here. At startup, the code looks for files named exactly 'concept-types.lisp' and 'relation-types.lisp' in the  `*cgraph-types*` directory.  If either file is missing when types are initialized, the file will be created. The initial contents for these files is contained in a couple text files in the default-types directory in the source code area. These files contain definitions mostly gleaned from Sowa's 1984 book 'Conceptual Structures'.

A practical way of maintaining custom type definitions is to store them in a git repo and link the two filenames mentioned above to the files in the repo. As long as the code sees a file with one of those names, that file will be left alone. 

The`(initialize-types)`function parses the type files in \*cgraph-types\* directory to create type objects and it evaluates the forms in the  `initializations.lisp` file. It should be run after changes are made to the type definitions.

The `*cgraph-data*` directory holds temporary files, like the dot files and png files generated when the concept-types are displayed as a graph, using  `(graph-concept-types)`.



### Emacs connection

- copy dot-swank.lisp to `~/.swank`
  This file makes a modification to swank so that compiling a file durung debugging
  creates its fasl file in the location that asdf uses, not the source code directory.

- load .el files 
  The files are found in `cgraph/emacs/`

  - graphviz-dot-mode.el
    for graph-concept-types(), display-graph()

  - cg-indent.el

  - cg-utils.el




### Startup sequence

- user starts Lisp with m-x slime or c-x l

- .sbclrc file loaded (when SBCL starts up)

  - load libraries
  - define conceptual-graphs package
  - defines cgraph() function in user package
    - reports version info
    - uses ASDF to compile and load the cgraph system 
    - calls cg::setup-cgraph() in initialize.lisp
  - REPL opens with a prompt in cl-user package

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

- 
