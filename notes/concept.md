## Concept

A concept is composed of a concept-type and a referent. The referent holds an optional individual marker. If the individual is missing the concept is generic. A concept of a generic dog is written as [DOG], The concept of the specific dog 231 is represented by [DOG: #231]. A concept representing a specific, but unidentified dog is represented by [DOG: #].

#### Concept Type

The concept type of a concept determines the semantics of the concept. An example set of concept types is supplied in the source code and copied to the `*cgraph-types*` directory on startup, if the directory does not contain a concept-types.lisp file. If the file already exists, it is left alone. This is the file of definitions used by CGraph, and is loaded on startup. These definitions can be edited and extended. The concept type of a concept is accessed with the *concept-type* function that accepts the concept as its only argument. 

For more information on concept-types see the type note.

#### Referent

The referent of a concept determines what the concept refers to. It indicates whether a concept represents

- a generic concept
- an individual
- a set of individuals
- a context containing  a graph

For more information see the referents note.

#### Variables

When a graph is presented in linear form as a tree, one concept may appear multiple times.  If a concept is generic, having no individual to indicate identity, a variable is used to associate the concepts. This variable is not part of the concept's identity, and is used only while drawing the graph.

For example:

```lisp
[DOG]-
   (agnt)<-[EAT]- 
              (obj)->[FOOD: *x] 
              (manr)->[FAST], 
   (rcpt)<-[GIVE]- 
              (obj)->[FOOD: *x] 
              (agnt)->[PERSON]. 
```

  The FOOD concepts in lines 3 and 6 refer to the same concept.



