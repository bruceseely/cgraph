## Individuals

Individuals are referred to by a concept's referent as proxies to represent objects in the domain.  An individual contains a unique *id* and a *type*, and is distinct from a concept. Different concepts may refer to the same individual eg. the individual #234 of type BOY may correctly be represented by concepts [PERSON: #234] and [BOY: #234]. 

The *id* is globally unique among individuals. The *type* is a concept-type, as used to specify the type of a concept. 

#### Ids

Ids are integers, and a variable keeps track of the maximum used value. A function is provided to update the variable and return the value.

#### Properties

Sowa introduces the use of shortcuts in the referent that express characters about the concept, for example

- named concept
  a generic dog named Fido - [DOG: Fido]
  a specific dog named Fido - [DOG: Fido #231]
- measure
  a length of 4 feet - [LENGTH: @4 ft]
  a specific length of 4 feet - [LENGTH: @4 ft #349]

- set
  a set of two named dogs - [DOG: {Fido, Spot}]
  a set of dogs, one named - [DOG: {Fido, #452}]
  a generic set of indeterminate size - [DOG: {\*}] (or [DOG: {}])
- combination
  a generic set of four dogs - [DOG: {\*} @4] or  [DOG: {} @4]
  a partially generic set of four dogs - [DOG: {Spot, \*} @4]







CGraph represents properties as a Lisp property-list, with keys :name :set :mean

Spaces in the referent section are (or at least should be) insignificant.
The referent-test.lisp file, in the test subdirectory,is a good place to see what variants are handled.





#### Conformity

An individual contains a concept type. When an individual is the referent of a concept, the individual must *conform* to the concept type of the concept. 

**conforms**  `(individual type)`
test if an individual conforms to the supplied type

**conforms** `(concept nil)`
test if a concepts referent individual conforms to its type

#### Parsing the text representation

The text representation of an individual is the text in the referent section (following the : character, preceding the ] character) in the concept text for most concepts. In a generic concept, there will be no text, and possibly no : character. In some concepts, the referent is a graph, not an individual.

A cache of existing Individuals is kept. After the text for an individual is read and parsed, the cache is checked to see if the Individual is already defined.

As a first implementation the cache is just a list. The id is optionally displayed. If the combination of type and properties make the Individual unique, then the id is not included when the concept is printed. So, when the text for the Individual is parsed, it may not contain an id, even though an id is required. 

The type of the individual is not displayed in the concept representation, but it is required to check that the Individual is compatible with the type of the concept representing it. 

Characteristics of the individual cache

- The cache is a flat list.
- Additions are made the head of the list, so searching the list from the front, examines latest defined Individuals first. 

Algorithm for the lookup:

- If the id is available from the text, find an Individual with that id. There should be only one.
- If the id is not available, find the first instance that has the same properties and type of the text representation. If a text representation is intentioned to be a new instance of an instance already defined, it should include a unique id.
- If no instance is found for the text, create a new instance and push it on the head of the cache.
- 

issues

- What to do if the text representation specifies an id number that is already used in an individual with a different type and properties list? 

- If a provided id number is unused and larger than the current max, is a gap left and the max set at the new value?

- What if the text has no id, and the type/properties match more than one Individual?

  - Use the most recently defined instance?

- How to handle the single "#" id. It represents a specific, but unidentified individual

  - [dog] - generic concept, has no referent, so no individual;   "a dog"
  - [dog: #34] - a specific, identified dog; '(:id 34)  "that dog"
  - [dog: #] - a specific, unidentified dog; '(:id t) "the dog"

  Set the id slot to 'T, 
  
  
  
  
  
  #### Tracking Individuals
  
  \*individuals\* - list of defined individuals
  
  add-individual - add an individual to the list
  
  remove-individual - remove an individual from the list
  
  
  
  get-individual (id)
  
  get-individuals (type, properties)
  
  make-individual
  
  format-individual
  
  unique-individual-p
  
  parse-individual-marker
  
  get-individual-marker
  
  individuals-equal
  
  individuals-eq
  
  