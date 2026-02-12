## Graphs

### Creating and Using Graphs

Two ways of creating graphs are provided. You can
	read a graph definition from a string, or
	create each object and link them together with function calls.

#### Reading the linear form of a graph from a string

The simplest way is to read the graph from a string. The function `parse-cgraph` accepts a string containing the linear representation of the graph. See `parse-test.lisp` for examples.

`parse-cgraph` has an alias (`pcg`) to facilitate use.

```lisp
CG> (setf g (pcg"[PERSON:Jane]<-(agnt)<-[EAT]->(obj)->[CAKE]"))
[PERSON: Jane]
CG>
```

This creates the graph and returns the concept-object for [PERSON: Jane], the first object in the string.
There is an alias for parse-cgraph (pcg) for ease of use.

#### Writing the linear form of a graph to a string

The simplistic way to generate a string of the linear form of a graph is to call `format-cgraph` on one of the concepts in the graph. The supplied concept will be the starting point for the string.

format-cgraph has an alias (`fcg`)

```lisp
CG> (setf g (pcg"[PERSON:Jane]<-(agnt)<-[EAT]->(obj)->[CAKE]"))
[PERSON: Jane]
CG> (fcg g)
"[PERSON: Jane]←(agnt)←[EAT]→(obj)→[CAKE]."
CG> (find-concept g 'eat)
[EAT]
CG> (fcg *)
"[EAT]-
   (agnt)→[PERSON: Jane]
   (obj)→[CAKE]."
CG>
```



#### Create graph objects with function calls

The other way to create a graph is to explicitly call functions that create the objects and link them.
See `format-test.lisp` for examples

Example:
To create this graph...
"[DOG: Spot]<-(agnt)<-[EAT]-
                                        (obj)->[CAKE]
                                        (manr)->[FAST]."

```lisp
CG>
  (setf dog-con    (make-concept 'dog '((:name "Spot"))))
  (setf eat-con    (make-concept 'eat  ()))
  (setf fast-con   (make-concept 'fast ()))
  (setf cake-con   (make-concept 'cake ()))

  (setf agnt-rel  (make-relation 'agnt))
  (setf obj-rel   (make-relation 'obj))
  (setf manr-rel  (make-relation 'manr))
(manr)

CG>
  ;; [eat]->(agnt)->[dog]
  (add-arc-into-relation eat-con agnt-rel)
  (set-arc-from-relation agnt-rel dog-con)

  ;; [eat]->(obj)->[cake]
  (add-arc-into-relation eat-con obj-rel)
  (set-arc-from-relation obj-rel cake-con)

  ;; [eat]->(manr)->[fast]
  (add-arc-into-relation eat-con manr-rel)
  (set-arc-from-relation manr-rel fast-con)
[FAST]
CG> (fcg *)
"[FAST]←(manr)←[EAT]-
                 (agnt)→[DOG: Spot]
                 (obj)→[CAKE]."
CG> (find-concept g 'dog)
[DOG: Spot]
CG> (fcg *)
"[DOG: Spot]←(agnt)←[EAT]-
                      (obj)→[CAKE]
                      (manr)→[FAST]."
CG>  (find-concept g 'eat)
[EAT]
CG> (fcg *)
"[EAT]-
   (agnt)→[DOG: Spot]
   (obj)→[CAKE]
   (manr)→[FAST]."
CG>
```



### Manipulating Graphs

#### Finding a concept in a graph

To find a concept in a graph, you need the graph, the concept-type of the concept you're looking for, and perhaps the annotations that define the concept if the type isn't unique within the graph. An example appears above.



### API

##### Creating objects

​	**make-concept** `(type-label annotations)`
​	*returns a concept*

​	**make-relation** `(relation-type)`
​	*returns a relation*

##### Linking concpt and relation objects

​	**add-arc-into-relation** `(concept  relation)`
​	*connects the concept and relation*
​	returns the concept

​	**add-arc-into-relation** `(relation  concept)`
​	*connects the concept and relation*
​	returns the concept

​	**set-arc-from-relation** `(concept  relation)`
​	*connects the concept and relation*
​	returns the concept

​	**set-arc-from-relation** `(relation  concept)`
​	*connects the concept and relation*
​	returns the concept

##### I/O

​	**parse-cgraph** (`graph-string`)
​	*creates a graph from the supplied string*
​	alias: **pcg** `(graph)`

​	**format-cgraph** `((concept-node) &key (initial-indent 0) (indent-delta 3) stream)`
​	*creates a graph-string from a concept in a graph*
​	alias:  **fcg** `(node &optional (indent 0) (delta 3))`



**find-concept** `(concept concept-type &optional features)`
