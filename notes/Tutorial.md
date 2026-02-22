## Tutorial

The idea here is to provide some examples that demonstrate the functionality.

### Setup

Read the `cgraph/notes/setup.md` note for assistance in setting up CGraph.

### Types

list of all concept-type names (symbols):  `(all-concept-types)`
list of all relation-type names (symbols):  `(all-relation-types)`

summary of concept-types:  `(print-concept-types)`
summary of relation-types:  `(print-relation-types)`

(get-concept-type 'girl)
The argument can be a string,, symbol, or a concept-type
`(eq (get-concept-type "girl") (get-concept-type 'girl))`   ==> T
`(eq (get-concept-type (get-concept-type 'girl))  (get-concept-type 'girl))` ==> T

- Case doesn't matter. I represent concept-types in uppercase and relation-types in lowercase because I think it's easier to read. 

### Some handy functions

##### pcg()

`pcg(arg)`  is a shortcut for

- `(print-cgraph graph)`  returning a *string*
- `(parse-cgraph string)`  returning a *graph*

It is here just to make it easier to type concepts and relations into the REPL

`(pcg "[dog: Spot]←(agnt)←[eat]→(obj)→[pie].")` ==> 
	#<GRAPH [DOG:Spot]←(agnt)←[EAT]→(obj)→[PIE].>

`(pcg (pcg "[dog: Spot]←(agnt)←[eat]→(obj)→[pie]."))` ==> 
      "[DOG: Spot]←(agnt)←[EAT]→(obj)→[PIE]."

##### read-cgraph-tokens()

- to return just a concept, not a graph
  `(read-cgraph-tokens "[dog: Spot]")`  ==>
         `(#<CONCEPT DOG>)` 

- concepts can be printed either as an unprintable object or as formatted
  `(setf *ALWAYS-FORMAT-NODES* t)`

    `(read-cgraph-tokens "[dog: Spot]")` ==>
           ([DOG: Spot])

- read-cgraph-tokens returns a list of tokens
  `(read-cgraph-tokens "[dog: Spot]←(agnt)←[eat]→(obj)→[pie].")` ==>
          ([DOG: Spot] ← (agnt) ← [EAT] → (obj) → [PIE])

  

### concepts

#### referents

Most of the referent markers that Sowa describes are available. For more information, look at the code in the file `cgraph/test/referent-test.lisp`  
One difference is the way individuals are handled. Sowa refers just to an individual marker. CGraph has an Individual class. the referent markers, like a name, are properties of the individual-object of the referent. For more information, see the file `cgraph/notes/individuals.md`  Individual-objects are not part of CGraph in the sense that they don't affect the processing of graphs. In a sense, they are a connection to a host system that is using CGraph, providing a tie in to the objects of that system, maybe as mixins. There is a special variable that determines whether CGraph is permitted to create Individual-objects. The intent is to allow the host system to have exclusive control over the objects. However for activities like testing, CGraph needs to be able to create individual-objects.

`*ALLOW-DYNAMIC-INDIVIDUAL-CREATION*`   whether CGraph is permitted to create Individual-objects

- graphs are first-class objects:
  (setq g1 (pcg "[GIRL]←(agnt)←[EAT]→(manr)→[fast]"))
  (pcg g1)
  "[GIRL]←(agnt)←[EAT]→(manr)→[FAST]."

- graphs behave in the REPL

`````lisp
CG> (pcg "[GIRL]←(agnt)←[EAT]→(manr)→[fast]")
#<GRAPH [GIRL]←(agnt)←[EAT]→(manr)→[FAST].>
CG> (pcg "[PERSON: Sue]←(agnt)←[EAT]→(obj)→[PIE]")
#<GRAPH [PERSON:Sue]←(agnt)←[EAT]→(obj)→[PIE].>
CG> (combine-conceptual-graphs * **)
#<GRAPH [GIRL:Sue]←(agnt)←[EAT]-(manr)→[FAST](obj)→[PIE].>
CG> (pcg *)
"[GIRL: Sue]←(agnt)←[EAT]-
                    (manr)→[FAST]
                    (obj)→[PIE]."
`````

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
