### Deviations

These are places where this implementation intentionally diverges from Sowa's design

- all relations have only two arcs
  - I don't think this is much of a limitation
  - I don't know what the linear form of a n-adic arc would look like 
  - The first arc of an arc list is the outgoing arc
    - just in case multiple input are accomodatedc later
- a type hierarchy for relation-types is not implemented