# Individuals

Sowa uses an individual-id to indicate the presence of an individual. The referent contains text indicating the characteristics of the referent. CGraph uses an Individual class. The characteristics of the individual are in the Individual object. This allows these features

- Individual objects can be defined independently of the graph creation.
- an Individual object can act as an interface with the host system, for example as a mixin to a host class.
- parsing of individual properties is separate from the concept syntax.
- recognizing that an Individual is shared by concepts becomes easier

An individual object contains a unique *id* and a *type*, and is distinct from a concept. Different concepts may refer to the same individual eg. the individual #234 of type BOY may correctly be represented by concepts [PERSON: #234] and [BOY: #234]. 

The *id* is globally unique among individuals. The *type* is a concept-type, as used to specify the type of a concept. 

#### Ids

Ids are integers. `make-individual` takes the next unused one, or the one you give it with `:id`; `(cg:init)` starts the numbering over.

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

CGraph represents properties as a Lisp property list, with the keys `:name`, `:set` and `:measure`.

Spaces in the referent section are (or at least should be) insignificant.
[Referents](referents.md) catalogs every form the reader accepts; `test/referent-test.lisp` exercises them.



