## Concept Type Browser

### setup

To start the browser, load the system definition and start the web server

`````lisp
(asdf:load-system :cgraph-web)
(cg::start-web-server :port 8060)
`````

After startup, this is printed in the REPL:
`CGraph web server started on http://localhost:8060`

To use the browser, open a browser window on the reported URL.

### overview

When a concept-type is selected, all inheritance paths that go from the top type node, to the bottom type node, through the selected type. are displayed. When multiple types are selected, the union of all paths are displayed. This is a way of visualizing the interaction of multiple types.

#### graphing pane

This pane displays the types that have been selected. Clicking on a type in this list removes the selected type and the lattice is redrawn.
At the right-end of the pane, two buttons are shown.

​	Initialize - reload type definitions and redraw the current lattice
​	Save - save the current configuration as a .dot file and a .png file in the data directory

#### concept-types pane

This pane displays an alphabetically sorted list of all currently defined concept-types. Clicking left on a type adds/removes it to/from the current display.

### display pane

This pane displays the lattice containing the selected types. 
Clicking right on a node causes the temporary display of all subtypes of the node.
Clicking left on a node adds/removes it to/from the current display.
Clicking left on the background removes temporarily displayed nodes.
double-clicking left on a node populates the relations-for pane for that concept-type

### relations-for pane

For the designated concept-type, two lists are presented

- all relation-types for which the designated type is an acceptable input
- all relation-types for which the designated type is an acceptable output



