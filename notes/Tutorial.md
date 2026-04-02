## Tutorial

The idea here is to provide some examples that demonstrate the functionality.

### Setup

Read the `cgraph/notes/setup.md` note for assistance in setting up CGraph.

### Types

list of all concept-type names (symbols):  `(all-concept-types)`
list of all relation-type names (symbols):  `(all-relation-types)`

summary of concept-types:  `(print-concept-types)`
summary of relation-types:  `(print-relation-types)`

(get-concept-type 'girl) - returns a concept-type-object 
The argument can be a string, symbol, or a concept-type object.
(The function accepts a concept-type object so there is no need to test its argument to see if it is already a concept-type-object)

`(eq (get-concept-type "girl") (get-concept-type 'girl))`   ==> T
`(eq (get-concept-type (get-concept-type 'girl))  (get-concept-type 'girl))` ==> T

- Case doesn't matter. I represent concept-types in uppercase and relation-types in lowercase because I think it's easier to read. 

### Some handy functions

##### pcg(*arg*)  is a shortcut for

- `(print-cgraph graph)`  returning a *string*
- `(parse-cgraph string)`  returning a linked list of concepts  in the graph

​	It is here just to make it easier to type concepts and relations into the REPL

​	`(pcg "[dog: Spot]←(agnt)←[eat]→(obj)→[pie].")` ==> 
​		`(#<CONCEPT DOG> #<CONCEPT EAT> #<CONCEPT PIE>)`

##### make-cgraph (*string  &optional context*) - returns a graph object

​	`(make-cgraph "[dog: Spot]←(agnt)←[eat]→(obj)→[pie].")` ==>
​		`#<GRAPH [DOG:Spot]←(agnt)←[EAT]→(obj)→[PIE].>`

​	make-cgraph can also be called on a list of connected nodes:
​		`(make-cgraph (pcg "[dog: Spot]←(agnt)←[eat]→(obj)→[pie].")))`
​	or just a graph node: 
​		`(make-cgraph  (car (pcg "[dog: Spot]←(agnt)←[eat]→(obj)→[pie].")))`

make-cgraph adds the created graph to the \*context\*.

### concepts

#### referents

Most of the referent markers that Sowa describes are available. For more information, look at the code in the file `cgraph/test/referent-test.lisp` for examples
One difference is the way individuals are handled. Sowa refers just to an individual marker. CGraph has an Individual class. the referent markers, like a name, are properties of the individual-object of the referent. For more information, see the file `cgraph/notes/individuals.md`  Individual-objects are not part of CGraph in the sense that they don't affect the processing of graphs. In a sense, they are a connection to a host system that is using CGraph, providing a tie in to the objects of that system, maybe as mixins. There is a special variable that determines whether CGraph is permitted to create Individual-objects. The intent is to allow the host system to have exclusive control over the objects. However for activities like testing, CGraph needs to be able to create individual-objects.

`*ALLOW-DYNAMIC-INDIVIDUAL-CREATION*`   whether CGraph is permitted to create Individual-objects

- graphs are first-class objects:
  (setq g1 (make-cgraph "[GIRL]←(agnt)←[EAT]→(manr)→[fast]"))
  (pcg g1)
  "[GIRL]←(agnt)←[EAT]→(manr)→[FAST]."

- how graphs behave in the REPL

  - combining two graphs with `combine-conceptual-graphs`

    

    `````lisp
    CG> (pcg "[GIRL]←(agnt)←[EAT]→(manr)→[fast]")
    ([GIRL] [EAT] [FAST])
    CG> (make-cgraph "[PERSON: Sue]←(agnt)←[EAT]→(obj)→[PIE]")
    #<GRAPH [PERSON:Sue]←(agnt)←[EAT]→(obj)→[PIE].>
    CG> (combine-conceptual-graphs * **)
    #<GRAPH [GIRL:Sue]←(agnt)←[EAT]-(manr)→[FAST](obj)→[PIE].>
    CG> (pcg *)
    "[GIRL: Sue]←(agnt)←[EAT]-
                        (manr)→[FAST]
                        (obj)→[PIE]."
    `````

  - combining multiple graphs


```Lisp
CG> (initialize-context *context*)
NIL
CG> (make-cgraph "[person: Jim]→(poss)→[car]")
[PERSON: Jim]→(poss)→[CAR].
CG> (combine-cgraphs (list "[PERSON: Dave]←(agnt)←[DRIVE]"
                       "[person: Sue]←(agnt)←[eat]→(obj)→[pie]"
                       "[CHEVY]→(attr)→[OLD]"
                       "[PERSON: Dave]→(poss)→[CHEVY]"
                       "[DRIVE]→(inst)→[CHEVY]"
                       "[dog: Spot]→(attr)→[fast]"
                       "[CITY: Baltimore]←(dest)<-[DRIVE]"
                       "[PERSON: Dave]→(attr)→[YOUNG]"
                       "[girl]←(agnt)←[eat]→(manr)→[quickly]"
                       "[dog: Spot]→(poss)→[cake]"))
([CHEVY]-
   (attr)→[OLD]
   (inst)←[DRIVE]-
              (agnt)→[PERSON: Dave *x]→(attr)→[YOUNG]
              (dest)→[CITY: Baltimore],
   (poss)←[PERSON: Dave *x].
 [GIRL: Sue]←(agnt)←[EAT]-
                    (manr)→[QUICKLY]
                    (obj)→[PIE].
 [DOG: Spot]-
       (attr)→[FAST]
       (poss)→[CAKE].)
CG> (graphs *context*)
([CHEVY]-
   (attr)→[OLD]
   (inst)←[DRIVE]-
              (agnt)→[PERSON: Dave *x]→(attr)→[YOUNG]
              (dest)→[CITY: Baltimore],
   (poss)←[PERSON: Dave *x].
 [GIRL: Sue]←(agnt)←[EAT]-
                    (manr)→[QUICKLY]
                    (obj)→[PIE].
 [DOG: Spot]-
       (attr)→[FAST]
       (poss)→[CAKE].
 [PERSON: Jim]→(poss)→[CAR].)
CG> 
```



### Some settings

`*ALWAYS-FORMAT-NODES*`
When nil, concepts and relations are displayed as non-printable objects.
When non-nil, they are formatted, as they appear in graphs.

`*ALWAYS-SHOW-INDIVIDUAL-ID*` 
Each individual has a unique id. It is displayed in a concept-referent when there is a need to distinguish one referent from another because they look the same otherwise, but it is frequently not displayed. Tho force it to be displayed set to non-nil.

`*ALWAYS-SHOW-NODE-REF*`
Each concept and relation node has a unique reference id that is not typically displayed.  However sometimes two concepts look the same but may not be the same concept. To force display of the ref id, set  to non nil.

On startup, any forms in the file `cgraph/system/setup/initializations.lisp` are evaluated. That is the best place for setting these variables automatically.



### Concept type browser

It is assumed that the user will provide definitions for concept-types and relation-types that are consistent with the domain of their system.  The setup note describes how type definitions are accessed.  A web-based concept-type browser is provided to help in process of defining concept definitions. 



#### Emacs

keybindings

| **Key** | **Description**                                              |
| ------- | ------------------------------------------------------------ |
| C-M-‘   | normalize graph string; upcase concept-types, downcase relation-types |
| C-c t   | insert concept-type -top symbol, ⊤                           |
| C-c b   | insert concept-type-bottom symbol, ⊥                         |

typing <- followed by space or punctuation automatically converts to ←.
typing -> followed by space or punctuation automatically converts to →.



There is an API document and a readme document  in the cgraph directory.
