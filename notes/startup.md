## Startup

Code like the following is useful for loading and starting up the CGraph system:

```lisp
;; in package cl-user
(require :asdf)
  
(defpackage :conceptual-graphs
  (:use :cl :asdf :uiop)
  (:nicknames :cg :cgraph))

(defun cgraph ()
  (asdf:load-system :cgraph)
  (cg::setup-cgraph))
```



(Note: this assumes that the asdf cgraph definition file is stored in one of the places where asdf looks for definitions. Alternatively, Lisp cound explicitly load the asdf cgraph definition file before the asdf:load-system call.)

I have this in my .clinit.cl file, so after ACL starts in the cl-user package, I can just call (cgraph) to load and startup the CGraph system. Since the function is created in the user package, it must qualify its invocation of `setup-cgraph` with the cg package.

#### Directories

The first time CGraph starts up, it ensures a directory exists in the user's home directory, named .cgraph, and saves the path in `*cgraph*` special variable. The .cgraph directory is where individual customization occurs and temporary files are stored.  The variables `*cgraph-data*` and `*cgraph-types*` are bound to the `data/` and `types/` sub-directories of the `*cgraph*` directory.

The `*cgraph-types*` directory points at the /types subdirectory of .cgraph. That diirectory holds the Lisp files with concept-type definitions and relation-type Lisp definitions. The user can modify the type definitions and add new types here. At startup, the code looks for files named exactly 'concept-types.lisp' and 'relation-types.lisp' in the  `*cgraph-types*` directory.  If either file is missing when types are initialized, the file will be created. The initial contents for these files is contained in a couple text files in the default-types directory in the source code area. These files contain definitions mostly gleaned from Sowa's 1984 book 'Conceptual Structures'.

A practical way of maintaining custom type definitions is to store them in a git repo and link the two filenames mentioned above to the files in the repo. As long as the code sees a file with one of those names, that file will be left alone. 

The`(initialize-types)`function parses the type files in \*cgraph-types\* directory to create type objects and it evaluates the forms in the  `initializations.lisp` file. It should be run after changes are made to the type definitions.

The `*cgraph-data*` directory holds temporary files, like the dot files and png files generated when the concept-types are displayed as a graph, using  `(graph-concept-types)`.

#### Example

`;; Start Lisp.     (eg. m-x slime)`

`;; load and initialize the code`
`cl-user> (cgraph)`

`;; run the tests to see how graphs are used`
`CG> (concept-test)`
`CG> (format-test)`
`CG> (parse-test)`

- concept-test
  generates and displays concept nodes with various options
- format-test
  exercises the `format-cgraph` function, which prints a linear representation of a graph
- parse-test
  exercises the `parse-cg-string` function, which creates a graph by reading a linear representation

