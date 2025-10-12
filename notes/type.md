## Types

Conceptual Graphs types comprise both `concept-types` and `relation-types`. 

The `concept-type` objects are created from definitions in the `concept-types.lisp` file. The  `relation-type` objects are created from definitions in the `relation-types.lisp` file.  These files are in the \*cgraph-types\* direcrory. The files are parsed, creating type objects, when`(initialize-types),`is evaluated. More information is provided in the Setup section.

**\*cgraph\***
*conceotual-graphs directory in the user's home directory*

***cgraph-types\***
*directory that holds the concept-type and relation-type directories*

**(initialize-types)**
*ensures the type directories and type files exist and loads the type files to create the type objects*
*If a file is not found, its prototype file is copied from the source code*



### Concept Types

Concept types are used to indicate the type of a concept. Concept types are organized as a lattice where multiple inheritance is supported. Every concept type is a subtype of the top type, \*concept-type-top\*, and a supertype of the bottom type, \*concept-type-bottom\*.

Concept type objects are shared by all concepts of the same type. Two concepts of type DOG both point to exactly the same type object as their type.

**\*concept-type-top\***
*the concept-type object representing the top of the concept-type lattice; supertype to every concept-type*

**\*concept-type-bottom\***
*the concept-type object representing the bottom of the concept-type lattice; subtype to every concept-type*



**get-concept-type** `(type-label)`
*returns the concept-type object of the supplied type-label symbol*

**define-concept-type**`(type-label supertypes cgraph)`
*creates a new concept-type object*
   `supertypes` is s list of types this type that inherits from
   `cgraph` is a string with the canonical-graph for the type

**print-concept-types**` ()`
*prints a simple sideways tree representation of the type lattice*.

**graph-concept-types** `(type-labels &key (graph-name "type_hierarchy")
                                      (landscape nil))`
*draws a graph of the concept-types around the supplied type-labels*
    `type-labels`is a symbol or list of symbols
    `graph-name`speciifies the generated dot-file name
(graph-concept-types (list 'physobj 'animate))

**concept-type-exists** `(type-label)`
*takes a type-label symbol, returns a Boolean*

**concept-type-defined-p** `(type-label)`



### Relation Types

**print-relation-types** `()`
*prints a description of each relation-type*

**get-relation-type**  `(type-label)`
*returns the relation-type object of the supplied type-label symbol*
*If a type-object is supplied, it will be returned*

**relation-type-exists** `(type-label)`



