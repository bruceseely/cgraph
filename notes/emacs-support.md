## Emacs Support

There are a few things that require files to be loaded into Emacs.

### graphviz-dot-mode.el

This file supports the Lisp function  **graph-concept-types** which draws a tree (actually a lattice, because of multiple inheritance of concept types) of concept types. Lisp support is in the file **concept-type-graph.lisp**.

The **graph-concept-types** function accepts a concept-type name or a list of names. For each type, all types between that type and the top type, and all types between the type and the bottom type, are displayed. The idea is to assist in understanding how types are related when adding new types.  The generated plot is contained in a **.dot** file and a **.png** file in the  **~/.cgraph/data** directory. The name of the generated files is "type-hierarchy" unless a name is supplied with the **:graph-name** argument. The orientation of the plot is with the root (top type) at the top, growing downward unless the **:landscape** argument is non-nil.

The Emacs support allows the creation of the **.dot** file that displays the lattice to be drawn in an Emacs buffer. The **.png** file is created in the directory **~/.cgraph/data**, regardless of whether the **.dot** file can be generated.

An elisp function is provided that allows the function to be run in Emacs with **m-x graph-types**. It accepts a single type name or a list of names.


### cg-indent.el

This file supports indentation of strings containing conceptual graphs. 

**cg-format-graph** indents the graph in a string under the cursor. It is initially bound to the *control-meta-z* keystroke. The elisp function cg-newline-indent is bound to *control-return*, for use while typing a graph string.

### cg-utils.el

- cg-rel-use (input-type output-type)
  Returns relation types that are consistent with the supplied input and output concept types.
  In file cg-utils.el
  m-x rei-use prompts for types.

- cl-funcall (function &rest args)





The elisp files are included in the **cgraph/emacs** directory.