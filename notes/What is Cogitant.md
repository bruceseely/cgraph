[![img](https://cogitant.sourceforge.io/cogitant_html/cogitantpetit.jpg)](https://cogitant.sourceforge.io/cogitant_html/index.html)

Quick links: [Tutorial](https://cogitant.sourceforge.io/cogitant_html/pages.html) - [Examples](https://cogitant.sourceforge.io/cogitant_html/examples.html) - [Files](https://cogitant.sourceforge.io/cogitant_html/files.html) - [Symbols](https://cogitant.sourceforge.io/cogitant_html/globals.html). 
Classes: [Hierarchy](https://cogitant.sourceforge.io/cogitant_html/hierarchy.html) - [Index](https://cogitant.sourceforge.io/cogitant_html/classes.html) - [List](https://cogitant.sourceforge.io/cogitant_html/annotated.html) - [Members](https://cogitant.sourceforge.io/cogitant_html/functions.html). 
Namespaces: [Index](https://cogitant.sourceforge.io/cogitant_html/namespaces.html) - [base](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html) - [cs](https://cogitant.sourceforge.io/cogitant_html/namespacecogitantcs.html) - [display](https://cogitant.sourceforge.io/cogitant_html/namespacecogitantdisplay.html).
[Cette page est disponible en français](https://cogitant.sourceforge.io/cogitant_html/fr_prog_graph.html). ![img](https://cogitant.sourceforge.io/cogitant_html/flag_fr.png)

Conceptual graph manipulation 





[![img](https://cogitant.sourceforge.io/cogitant_html/cogitantpetit.jpg)](https://cogitant.sourceforge.io/cogitant_html/index.html)

# What is Cogitant? 

The *Cogitant* library is a set of *C++* classes enabling to easily handle conceptual graphs as well as the other objects of the model (support, rules, etc.). To each *object of the model* matches a *class* in Cogitant, and the data structures used are a basic implementation of the objects of the model (for example, a graph is a set of vertices and a set of edges), by this way, it is easy for someone already knowing  the model of conceptual graphs to understand the structure of Cogitant,  and the extensions are eased.

## Functions

The main functions offered by the library are the following ones: 

- Handling in memory of **conceptual graphs**. It is possible to handle basic or nested conceptual graphs, not necessarily connexs, that may  contain coreference links. The types of concept vertices can be  conjunctive types. 
- Handling in memory of a **support** (sets of types of concepts, types of relationships, types of nestings and individual tags). Several  supports can coexist in memory, but a conceptual graph is defined on a  single support. The support also includes a range of banned types. The  headings of the support elements can be provided in different languages. 
- **Basic operations** on graphs (vertex addition, vertex junction, separated sum, etc.)  
- **Projection** operations between conceptual graphs.  
- Input/output operations in **BCGCT**, **CoGXML** and **CGIF** formats. Graph output under **linear form**. 
- **Conceptual graph rules** handling, and operations involving rules  (searching for potential applications of a rule on a graph, application  of a rule on a graph, graph closure by a set of rules, etc.) 
- Handling of conceptual graph **constraints**, and graph checking operations being given a constraint. 
- **Access** to Cogitant's functions from an application written in **Java** thanks to the presence of Java classes (partly) giving access to  Cogitant's classes via JNI. It is also possible to access Cogitant's  functions, remotely, by network, thanks to the presence of a **client-server architecture** based on the exchange of XML messages. 

## Goals

The main goals of the Cogitant library are the following ones: 

- **Usability.** The class hierarchy provides an easy-to-use  implementation of the objects of the model and enables to easily execute operations of the model. In addition, the main methods of the library  check the arguments that are sent to them, what enables to correct  quickly a wrong program. Finally, the use of sophisticated mechanisms  such as generic classes, exceptions, namespaces or *"iterators"* (as in std library) eases the use of classes. 
- **Extensions possibilities**. The class library was designed to be  easily extensible, regarding the definition of new operations or the  inclusion of new classes in order to represent objects of the model. The addition of new file formats has been particularly simplified. 
- **Performance.** The operations of the model have been implemented so as to be quickly executed. In order to easily manage supports or large  size graphs (or large quantities of small graphs) classes were written  so as to fill a reasonable size. 
- **Portability.** The library has been tested with all major operating systems (*GNU/Linux, MS Windows, MacOS X, Solaris/OpenSolaris, FreeBSD*) and compilers (*GNU C++, Microsoft Visual C++, XCode, Intel C++, Cygwin G++, Mingw G++, LLVM Clang*) of the market. 
- **Sustainability.** The current version of the library has been  developed since 2000 and CoGITo date from 1994. Since 2000, numerous  extensions have been included in the library, keeping the objective of  providing a relatively stable API. 

## Documentation

A [HTML documentation](https://cogitant.sourceforge.io/cogitant_html/index.html) is provided in the archive file of the source of the library, and this documentation can be accessed [online](http://cogitant.sourceforge.net/cogitant_html/index.html) on the [Cogitant's website](http://cogitant.sourceforge.net). This documentation is made up of more than 200 HTML pages and details  every class of the library, and provides for each method of each class a description of the parameters, of the returned value, and of the  process carried out. In addition to the description of the [ class hierarchy](https://cogitant.sourceforge.io/cogitant_html/hierarchy.html),  a complete [tutorial](https://cogitant.sourceforge.io/cogitant_html/intro.html) is available, and describes how to compile and use Cogitant, as well as a reference of file formats. The documentation is also available in PDF format. The PDF file of over 1000 pages can be downloaded at the [download page](http://cogitant.sourceforge.net/download.php) of the website.

## History

The *Cogitant* library is an extension of the *CoGITo* library developed since 1994 in the team *Représentation de connaissances par des graphes (knowledge representation by graphs)* *LIRMM* (formerly "Graphes conceptuels (conceptual graphs)" team), headed by *Michel Chein* and *Marie-Laure Mugnier*.
 CoGITo (***Co**nceptual **G**raphs **I**ntegrated **To**ols*) was created by *Ollivier Haemmerlé*, who has defined and developed the general architecture of the library.  The various PhDs who have succeeded one another in the team have  corrected bugs, brought out extensions (usually corresponding to their  PhD work), and managed relationships with users: *Boris Carbonneill*, *Michel Leclère*, *Olivier Guinaldo*.
 In 1997, the library has changed its name to *Cogitant* v-4 (***CoGIT**o **a**llowing **N**ested **T**yped graphs*) for the occasion of the consideration of rules (developed by *Eric Salvat*) and typed nested graphs with coreference links (developed by *David Genest*). Since then, the latter has maintained the library and carried out  version 5, which is, since 2001, developed jointly by the LIRMM - [GraphIK team](http://team.inria.fr/graphik) and the LERIA - [ICLN team](http://www.info.univ-angers.fr/leria/icln.php).

## To learn more...

After this brief introduction, we have now to get in a little more technical description, and the tutorial, starting with the [Introduction](https://cogitant.sourceforge.io/cogitant_html/intro.html) which is designed for this purpose. Good luck. 

[Project page on Sourceforge](http://www.sourceforge.net/projects/cogitant).
Documentation: [General/C++](https://cogitant.sourceforge.io/cogitant_html/index.html) - [Java](https://cogitant.sourceforge.io/cogitantjava_html/index.html).

[![Get Cogitant at SourceForge.net. Fast, secure and Free Open Source software downloads](http://sflogo.sourceforge.net/sflogo.php?group_id=40204&type=13)](http://sourceforge.net/projects/cogitant)



# Conceptual graph manipulation 



https://cogitant.sourceforge.io/cogitant_html/prog_graph.html

The first part of this presentation describes the data structure used to represent typed nested conceptual graphs [[Chein and Mugnier, 1997\]](https://cogitant.sourceforge.io/cogitant_html/bibliographie.html#bibcheinmugnier97) in memory. While you don't have to perfectly know this data structure  in order to use the library (it is possible to use the class [cogitant::Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html) without having to know what data structures are actually used), it is  better to have a sight on these structures in order to better understand the functioning of the library. The second part precisely describes  methods available in the class of conceptual graphs representation,  while the third describes mechanisms available to browse the various  objects (concepts, relations, etc.) forming a graph. Finally, the last  section describes how coreference links are handled.

## Nodes of a graph

A conceptual graph ([cogitant::Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html)) is represented as a set of nodes ([cogitant::GraphObject](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1GraphObject.html)) and a set of edges ([cogitant::Edge](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Edge.html)). More precisely, a conceptual graph contains objects that can be instances of different classes (subclasses of [cogitant::GraphObject](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1GraphObject.html)). Each object of a graph is identified in a unique way by the [cogitant::iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) which marks that object in the set of objects. These objects are accessible by calling the method [cogitant::Graph::nodes()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#aee3da71ddb00e62247822d897e9a1866) which returns the `Set<GraphObject*>` containing the objects, or simply by using the [cogitant::Graph::nodes(iSet)](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a8fbab1785a2386fec61ab6c5970ce1bb) method that returns the object corresponding to the passed identifier.  Several classes are used to represent a conceptual graph: 

- The [cogitant::InternalGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1InternalGraph.html) class represents a possibly nested graph structure. Indeed, in a nested conceptual graph, there may be "several" graphs, one of which being of  level 0, and the others being nested in nestings which are themselves in concept vertices. 
- [cogitant::Concept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Concept.html) and [cogitant::Relation](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Relation.html) classes represent concept vertices and relations. These objects are  always attached to an InternalGraph (by a parent/child link). 
- The [cogitant::Nesting](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Nesting.html) class represents the nestings. Such an object is always daughter  (single) of a Concept and has as a daughter (single) an InternalGraph. 

To each object (identifier *i*) is associated a set of [cogitant::Edge](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Edge.html) (obtained calling to the [cogitant::Graph::edges(iSet)](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a6f9e65dd27c5f6a4e06f13d152114ebb) method and passing *i* as a parameter) which represents the links of this object with other objects of [cogitant::Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html). These links are stored in the form of a data structure that contains the link label ([cogitant::Edge::m_label](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Edge.html#a4b787e3773016833c9f1694463fd8ac1), of type [cogitant::Edge::Label](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Edge.html#ab28fa7dfa095d67594c54c912ad5c871)) and the extremity ([cogitant::Edge::m_end](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Edge.html#a238f4ab2a71faa808f2926469603da82)). The link origin is not explicitly represented as such a link is always  associated with an object which is the link origin. Labels of these  links enable to represent parent/child relations ([cogitant::Edge::PARENT](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Edge.html#a4f3a34e69e55f079433c918a4b1026bb) and [cogitant::Edge::CHILD](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Edge.html#adac007d1d92aaa0f5b8519b1c476eb16)) as well as edges labeled in the sense of conceptual graphs (i.e.  labeled by positive integers). For example, the conceptual graph in  Figure 1 is represented in memory by a data structure such as that shown in Figure 2.

![simplenested.png](https://cogitant.sourceforge.io/cogitant_html/simplenested.png)

**Figure 1.** A conceptual graph. 

In the machine representation of a conceptual graph, there is always a root (whose identifier is returned by [cogitant::Graph::root()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a8d0a59c0c4953a92b4e6f1767f90bea1)). Although not shown in Figure 2, the root object has an Edge  representing a PARENT link to an identifier object ISET_NULL. This root, of type [cogitant::InternalGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1InternalGraph.html), has as a daughter the concepts and relations of the graph of level 0.  The phrase "has as daughter" means here the existence of links labeled  CHILD associated with the InternalGraph and having the concepts and  relations at the extremity, as well as links labeled PARENT associated  with the concepts and relations and having the InternalGraph at the  extremity. The edges (in the sense of "conceptual graph model") between  concepts and relations are represented by Edge associated with [cogitant::Concept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Concept.html) and [cogitant::Relation](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Relation.html), having as a label the edge label and as an extremity the linked vertex. Note that *there is a **PARENT** link between **A** and **B***  if and only if *there is a **CHILD** link between 
 B and **A***  and *there is a link **n** (**n** natural integer) between **A** and **B***  if and only if *there is a link **n** between **B** and **A*** .

![graphstructure.png](https://cogitant.sourceforge.io/cogitant_html/graphstructure.png)

**Figure 2.** Representation of the conceptual graph of the Figure  1. Each object is represented by a frame, the number in the upper right  corner of each box represents the object identifier in the set (iSet).  The edges (Edge) associated with an object are represented by arrows  that have as an origin the object, the label of each edge is given next  to the arrow. 

If a concept vertex has nestings (as the vertex *3* in Figure 2), their daughters will be the corresponding [cogitant::Nesting](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Nesting.html). These objects have each of them one and only one daughter which is a [cogitant::InternalGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1InternalGraph.html). These internal graphs obviously have as daughters the concepts and  relations of the nested graph. When a graph is built "empty" (by [cogitant::Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html), which is called by [cogitant::Environment::newGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#ab05cb2230482087df795a2aae8fa4a42)), it actually contains a [cogitant::InternalGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1InternalGraph.html), in this way, it is possible to immediately add vertices to the object. 

## Modifying a conceptual graph

### Adding vertices

To add a new generic concept vertex to a graph, you have to call the [cogitant::Graph::newGenericConcept()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a17a7ce6f06f385db02e12b28ae4ecc95) method. This method is actually overloaded and can be called by passing as a parameter the identifier (in the support) of concept type, or the  type label string. A second optional parameter can be passed to this  method: the identifier in the graph of the [cogitant::InternalGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1InternalGraph.html) which will get the built vertex as a daughter. If no identifier is  passed, the built vertex is daughter of the root, which makes it  possible to manipulate basic graphs without considering parent/child  links. These methods, like other methods (below-cited) for adding  objects in the graph return the identifier of the created object. 

The addition of an individual concept vertex is done by calling the [cogitant::Graph::newIndividualConcept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a838b13a3935b5223365ff40aace2586f) method that takes as parameters the type identifier, the marker  identifier and (possibly) the InternalGraph parent identifier. This  method can also be called by passing the label strings of the concept  type and the marker. 

To add a relation vertex, you have to call the [cogitant::Graph::newRelation](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#ad58be6ef298bd21a19db8ede6a247c71) method which takes as a parameter the relation type identifier (or the type label string), an optional `vector<iSet>` representing the relation neighborhood to be created and (optionally) the InternalGraph parent identifier. If no `vector<iSet>` is passed, the edges linked to the relation are "pending". However, if a vector *v* is passed, an edge labeled *1* is created from the relation to the concept vertex of identifier *v[0]*, an edge labeled *2* to the vertex *v[1]*, and so on. Obviously, the passed vector must have a size of the  relation arity, and the vector elements must be concept vertex  identifiers having as a parent the same InternalGraph than the one in  which the relation is created. To create a binary relation, the [cogitant::Graph::newBinaryRelation()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a9e27a229fe79131d4cdbf960432b7b25) method can be used and does not require the use of a `vector`: identifiers of concept vertices being neighbor to the relation to be create are directly passed to the method. 

The addition of a nesting to a concept vertex, is done in a comparable manner, by the [cogitant::Graph::newNesting()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a789417fd364f9f027ab7b15a64568687) method which takes as a parameter the nesting type identifier (or the  string) and the parent concept identifier. Caution: the call to this  method does not create a daughter [cogitant::InternalGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1InternalGraph.html), which must be explicitly created by a call to [cogitant::Graph::newInternalGraph()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a18e386611d62e038c91046c33a977102) which takes as a parameter the parent nesting identifier. 

**Example.** The graph in Figure 1 is created in memory after having loaded the corresponding support from a BCGCT file.

\#include <iostream>

\#include "[cogitant/cogitant.h](https://cogitant.sourceforge.io/cogitant_html/cogitant_8h.html)"

using namespace [std](https://cogitant.sourceforge.io/cogitant_html/namespacestd.html);

using namespace [cogitant](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html);

int main(int, char* [])

{

​    [cogitant::Environment](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html) env;

​    env.[readSupport](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#a6b2d0a20d0c44060c04f5b8fb6149a74)("bcgct/bucolic/bucolic.bcs");

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) id_g = env.[newGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#ab05cb2230482087df795a2aae8fa4a42)();

​    [Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html) * g = env.[graphs](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#a535440b8669ae51afb99eeb7b6d011ec)(id_g);

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) c_person = g->[newGenericConcept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a17a7ce6f06f385db02e12b28ae4ecc95)("Person");

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) c_think = g->[newGenericConcept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a17a7ce6f06f385db02e12b28ae4ecc95)("Think");

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) c_entity = g->[newGenericConcept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a17a7ce6f06f385db02e12b28ae4ecc95)("Entity");

​    vector<iSet> s;

​    s.push_back(c_think); s.push_back(c_person);

​    g->[newRelation](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#ad58be6ef298bd21a19db8ede6a247c71)("agent", s);

​    g->[newBinaryRelation](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a9e27a229fe79131d4cdbf960432b7b25)("object", c_think, c_entity);

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) nesting = g->[newNesting](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a789417fd364f9f027ab7b15a64568687)("Representation", c_entity);

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) nestedgraph = g->[newInternalGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a18e386611d62e038c91046c33a977102)(nesting);

​    g->[newGenericConcept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a17a7ce6f06f385db02e12b28ae4ecc95)("Scene", nestedgraph);

​    cout << *g << endl;

​    return 0;

}

The built graph being displayed on the screen, the execution of this  program returns the display below. The analysis of the display shows the graph structure, and more particularly parent (referred to as `P`) / child (referre to as `C`) relations. The structure given in Figure 2 can be found in exactly this display: the object of identifier *0* has as daughters the objects *1, 2, 3, 4, 5*, there is an Edge from *2*, labeled *1* and pointing to *4*, and so on.

Q28cogitant5Graph

 Nodes : 0:Q28cogitant13InternalGraph, 1:Q28cogitant7Concept 11, 2:Q28cogitant7C

oncept 15, 3:Q28cogitant7Concept 6, 4:Q28cogitant8Relation 0, 5:Q28cogitant8Rela

tion 3, 6:Q28cogitant7Nesting 2, 7:Q28cogitant13InternalGraph, 8:Q28cogitant7Con

cept 13

 Edges :

 0:(P *)(C 1)(C 2)(C 3)(C 4)(C 5)

 1:(P 0)(2 4)

 2:(P 0)(1 4)(1 5)

 3:(P 0)(2 5)(C 6)

 4:(P 0)(1 2)(2 1)

 5:(P 0)(1 2)(2 3)

 6:(P 3)(C 7)

 7:(P 6)(C 8)

 8:(P 7)

### Removing nodes

Removing graph nodes is done by calling the  cogitant::Graph::deleteObject(iSet) method, which takes as a parameter  the identifier of a node to be destroyed. If the node has children, they are also destroyed (recursively). If the destroyed object is a concept  vertex, any edge linked to this vertex are made pending. 

### Other modification operations

The [cogitant::Graph::link()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#ae1e7a50f68fb2697d731ada9030692bb) method enables the linking of a relation vertex to a concept vertex.  More precisely, this method must get as parameters the identifier of a  relation vertex, an edge label (i.e. an `unsigned int`  comprised between 1 and the relation arity) and the identifier of a  concept vertex. If an edge corresponding to the passed label already  exists among the relation Edges, it is "unbound" from its previous  extremity to be linked to the passed concept vertex. 

Joining two concept vertices of the same label and having no nestings can be done by the cogitant::Graph::joint(iSet,iSet) method which takes as parameters the vertex identifiers. After the execution of this  method, only the identifier of the first vertex is still valid, as the  object of the second identifier has been deleted. [cogitant::Graph::merge()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a11ccf2168425dde36edb0ffb3018298f) provides a better control on the fusion of two concept nodes. 

After changing the type of a relation vertex (with a call to the [cogitant::Relation::setType()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1LabeledGraphObject.html#ab545e389ab6499265f96da1778978825) method), the arity relation may change. In this case, you have to call the [cogitant::Graph::recreateNeighbourhood()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a9d8fe23e70dc4bc904af30b8ba629928) method which takes as a parameter a relation vertex identifier. This  method may create pending edges (when the new type arity is greater than the previous type) or removes supernumerary edges (otherwise).

## Accessing graph objects and traversal

Objects forming the [cogitant::Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html) structure can be accessed through the [cogitant::Graph::nodes()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#aee3da71ddb00e62247822d897e9a1866) method which returns a (pointer to a) set of (pointers to) [cogitant::GraphObject](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1GraphObject.html). This class is actually an abstract class, the mother of all classes that can represent graph nodes. More particularly, [cogitant::InternalGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1InternalGraph.html) and [cogitant::LabeledGraphObject](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1LabeledGraphObject.html) classes derive from this class. The [cogitant::LabeledGraphObject](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1LabeledGraphObject.html) class is an abstract class which enables to factorize properties common to objects labeled: [cogitant::Concept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Concept.html), [cogitant::Relation](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Relation.html), [cogitant::Nesting](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Nesting.html). 

Accessing graph components being done through `GraphObject*` objects, you cannot therefore call on these objects methods of its  subclasses. You can know from which class an object is instance of by  calling the [cogitant::GraphObject::objectType()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1GraphObject.html#a94c6cace8f90d4f405080eaa3f96d9c9) method which returns a [cogitant::GraphObject::Type](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1GraphObject.html#a67f6c4b1549bda4d804e0872bb825138), which is an enumerated type taking values OT_CONCEPT, OT_RELATION,  OT_NESTING and OT_INTERNALGRAPH. By using this information, you can thus explicitly and safely convert a `GraphObject*` into a `Concept*`, etc. Nevertheless, you should rather use methods [cogitant::GraphObject::asConcept()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1GraphObject.html#a4b00468eeb73b26b3e988da5a11a148d), [cogitant::GraphObject::asRelation()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1GraphObject.html#af011ac517a8fac9b3a42e7cee787f2f5), [cogitant::GraphObject::asNesting()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1GraphObject.html#a97fbf63b034fea7bba8ab07fe4d459e8) and [cogitant::GraphObject::asInternalGraph()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1GraphObject.html#aa8a8e34699b3a3f21a511b0767720974) which return a pointer to, respectively, a Concept, a Relation, a  Nesting, an InternalGraph. These methods first ensure that the  conversion is permitted (otherwise, an exception is raised) before  returning a pointer of the desired type. 

The different classes corresponding to graph objects have methods that can modify objects, for example: 

- Concepts, relations and nestings have the methods [cogitant::LabeledGraphObject::setType()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1LabeledGraphObject.html#ab545e389ab6499265f96da1778978825) and [cogitant::LabeledGraphObject::type()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1LabeledGraphObject.html#a6c3f3976b2fb53264d0ea237c72f8550) enabling to set or get the type (of concept, relation, nesting) of the object. 
- The [cogitant::Concept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Concept.html) class disposes, in addition to [cogitant::Concept::setGeneric()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Concept.html#ac380e6f4350bd5ced5c7b442cacb3591) methods enabling to make the concept vertex "generic", of [cogitant::Concept::setIndividual()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Concept.html#a0f45317b011eeb52b1575298ae9abb8c) that takes as a parameter the identifier of a concept type and the identifier of an individual marker, of [cogitant::Concept::referentType()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Concept.html#a6ce743a93fa5bad4c3b4433e08546809) which returns the referent type of the vertex ([cogitant::Concept::RT_GENERIC](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Concept.html#a8f029ac55430b772ec7cc85cd1db0e38afa0729c822c502b5e4b152739aeb514f) or [cogitant::Concept::RT_INDIVIDUAL](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Concept.html#a8f029ac55430b772ec7cc85cd1db0e38aa9c8dd4f559e5c69de679060c8d93fe2)) and of [cogitant::Concept::individual()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Concept.html#a54aa9064bbaafa93325226cfd4730058) which returns the identifier of the individual marker of the vertex. 

### Traversal

In many cases, you need to traverse objects of a graph, and very  often, you need to only traverse certain object types (only concept  vertices, only level 0 graph relations, etc.). Traversing all concept  vertices of a graph can be done for example by the following program,  which uses only methodes of the [cogitant::Set](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Set.html) class.

\#include <iostream>

\#include "[cogitant/cogitant.h](https://cogitant.sourceforge.io/cogitant_html/cogitant_8h.html)"

using namespace [std](https://cogitant.sourceforge.io/cogitant_html/namespacestd.html);

using namespace [cogitant](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html);

int main(int, char* [])

{

​    [Environment](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html) env;

​    env.[readSupport](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#a6b2d0a20d0c44060c04f5b8fb6149a74)("bcgct/bucolic/bucolic.bcs");

​    [Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html) * g = env.[graphs](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#a535440b8669ae51afb99eeb7b6d011ec)(env.[readGraphs](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#aa9be5104a374c72f34691ce9e41cf134)("bcgct/bucolic/simplenested.bcg"));

​    for ([Set::const_iterator](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1SetIterator.html) i = g->[nodes](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#aee3da71ddb00e62247822d897e9a1866)()->[begin](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Set.html#a32530eedd8547f529b327b8b3ef4db82)(); i != g->[nodes](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#aee3da71ddb00e62247822d897e9a1866)()->[end](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Set.html#a4ec2d5eadc3bd9ac835f3476544ac3e7)(); i++)

​        if ((*i)->objectType() == GraphObject::OT_CONCEPT)

​            cout << "Type : " << (*i)->asConcept()->primitiveType() << endl;

​    return 0;

}

However, it is easier to use methods provided in the [cogitant::Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html) class and which enable a selective traversal on objects. So, methods  cogitant::Graph::conceptBegin() and cogitant::Graph::conceptEnd(),  cogitant::Graph::relationBegin() and cogitant::Graph::relationEnd()...  return iterators of a particular type  (cogitant::Graph::concept_iterator, cogitant::Graph::relation_iterator,  etc.) which enable a simplified traversal of the chosen object type. In  this way, the example program above can be rewrited in the following  manner:

\#include <iostream>

\#include "[cogitant/cogitant.h](https://cogitant.sourceforge.io/cogitant_html/cogitant_8h.html)"

using namespace [std](https://cogitant.sourceforge.io/cogitant_html/namespacestd.html);

using namespace [cogitant](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html);

int main(int, char* [])

{

​    [Environment](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html) env;

​    env.[readSupport](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#a6b2d0a20d0c44060c04f5b8fb6149a74)("bcgct/bucolic/bucolic.bcs");

​    [Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html) * g = env.[graphs](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#a535440b8669ae51afb99eeb7b6d011ec)(env.[readGraphs](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#aa9be5104a374c72f34691ce9e41cf134)("bcgct/bucolic/simplenested.bcg"));

​    for ([cogitant::Graph::concept_const_iterator](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1GraphObjectCondIterator.html) i = g->conceptBegin(); i != g->conceptEnd(); i++)

​        cout << "Type : " << (*i)->primitiveType() << endl;

​    return 0;

}

Methods *xxx*Begin and *xxx*End accept an optional parameter which is the identifier of the object  whose daughters have to be traversed. If this parameter is omitted (or  if ISET_NULL is passed), all objects of the chosen type are traversed:  in the case of a nested graph, all concept vertices (for example) are  traversed. The program example below shows the use of this feature: only concept vertices of the level 0 graph (those which are daughters of the root) are traversed, which corresponds, in the case of the graph in  Figure 1, to the concept vertices *Person, Think, Entity*.

\#include <iostream>

\#include "[cogitant/cogitant.h](https://cogitant.sourceforge.io/cogitant_html/cogitant_8h.html)"

using namespace [std](https://cogitant.sourceforge.io/cogitant_html/namespacestd.html);

using namespace [cogitant](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html);

int main(int, char* [])

{

​    [Environment](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html) env;

​    env.[readSupport](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#a6b2d0a20d0c44060c04f5b8fb6149a74)("bcgct/bucolic/bucolic.bcs");

​    [Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html) * g = env.[graphs](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#a535440b8669ae51afb99eeb7b6d011ec)(env.[readGraphs](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#aa9be5104a374c72f34691ce9e41cf134)("bcgct/bucolic/simplenested.bcg"));

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) r = g->[root](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a8d0a59c0c4953a92b4e6f1767f90bea1)();

​    for ([cogitant::Graph::concept_const_iterator](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1GraphObjectCondIterator.html) i = g->conceptBegin(r); i != g->conceptEnd(r); i++)

​        cout << "Type : " << (*i)->primitiveType() << endl;

​    return 0;

}

## Coreference classes

### Coreference representation

Coreference links are not explicitly represented between concept  vertices, but through coreference classes. More precisely, a coreference class contains a set of concept vertices in coreference: if there is a  coreference link between *A* and *B*, and that there is a same link between *B* and *C*, then these three vertices are coreferent, they belong to the same  coreference class. In the data structure representing a conceptual  graph, it is represented as an instance of [cogitant::CoreferenceClass](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1CoreferenceClass.html) that appears in the set of graph objects ([cogitant::Graph::nodes()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#aee3da71ddb00e62247822d897e9a1866)). This object has ISET_NULL as a parent and has a link ([cogitant::Edge](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Edge.html)) to all concept vertices belonging to the class. Each of these links is labeled by [cogitant::Edge::COREFERENCE](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Edge.html#a9f7fcc1059e125ab37fbdd4e4d549559) and also exists in the direction of concept vertex to coreference class.

Only "non-trivial" coreference classes are represented: at the  creation of a concept vertex, whatever its label, the vertex belongs to  the coreference class formed of this single vertex. Such classes are **not** represented.

### Using the coreference

Using methods available from the [cogitant::Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html) class makes it possible to use coreference links regardless of the  representation in memory, even if it is recommended to know the data  structures in order to use certain operations. 

Each coreference class is marked with a unique name (a string used  for saving in BCGCT or CoGXML) and when creating a new coreference  class, by calling the [cogitant::Graph::newCoreferenceClass()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a5bbd2953094db894d832983386af2ec0) method, you can pass a string to set the name of the created class. If  no string is passed, a (unique) name will be automatically assigned.  This method returns the identifier of the created class. 

This identifier can then be used to add objects to the coreference class: the [cogitant::Graph::addCoreference(iSet,iSet)](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#acd01fd531c818058e7d495ef47242a09) method accepts two parameters: a generic vertex identifier and a  coreference class identifier. This method adds the concept vertex to the coreference class provided this vertex does not already belong to a  coreference class (a vertex can only be in a *single* coreference class, but you can merge two coreference classes using the [cogitant::Graph::fusionCoreferenceClasses()](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a125423e47bf4b7a2d8d89e59fc5d4834) method). An additional condition must be met in order to call this  method: all concept vertices of a coreference class must be generic and  of the same type. Otherwise, a [cogitant::ExceptionStructure](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1ExceptionStructure.html) is raised. 

To remove a concept vertex of a coreference class, just call the [cogitant::Graph::removeCoreference(iSet,iSet)](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#ad3db944fb28945228865a015fe8d42d7) method, which takes as a parameter the concept vertex identifier and  the identifier of its coreference class. Finally, to access the  coreference class that owns a concept vertex, you can call the  cogitant::Graph::coreferenceClass(iSet) method, which takes as a  parameter a concept vertex identifier and returns the coreference class  identifier at which it belongs or ISET_NULL if the vertex does not  belong to any coreference class. 

Coreference classes are obviously taken into account when calculating projections in accordance with the model: two vertices of a same  coreference class should have as an image either a single vertex, or two vertices having the same individual marker, or two vertices of the same coreference class.

**Example.** Loading a support, and creating a conceptual graph  representing "a person thinking about a scene describing the same  person". To represent the fact that it is the same person, a coreference link is created between the two concept vertices *"Person"*. More precisely, a coreference class is created and the two concept vertices are attached to this class.

\#include <iostream>

\#include <vector>

\#include "[cogitant/cogitant.h](https://cogitant.sourceforge.io/cogitant_html/cogitant_8h.html)"

using namespace [std](https://cogitant.sourceforge.io/cogitant_html/namespacestd.html);

using namespace [cogitant](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html);

int main(int, char* [])

{

​    [cogitant::Environment](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html) env;

​    env.[readSupport](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#a6b2d0a20d0c44060c04f5b8fb6149a74)("bcgct/bucolic/bucolic.bcs");

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) id_g = env.[newGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#ab05cb2230482087df795a2aae8fa4a42)();

​    [Graph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html) * g = env.[graphs](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Environment.html#a535440b8669ae51afb99eeb7b6d011ec)(id_g);

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) c_person = g->[newGenericConcept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a17a7ce6f06f385db02e12b28ae4ecc95)("Person");

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) c_think = g->[newGenericConcept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a17a7ce6f06f385db02e12b28ae4ecc95)("Think");

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) c_scene = g->[newGenericConcept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a17a7ce6f06f385db02e12b28ae4ecc95)("Scene");

​    vector<iSet> s;

​    s.push_back(c_think); s.push_back(c_person);

​    g->[newRelation](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#ad58be6ef298bd21a19db8ede6a247c71)("agent", s);

​    s[0] = c_think; s[1] = c_scene;

​    g->[newRelation](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#ad58be6ef298bd21a19db8ede6a247c71)("object", s);

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) nesting = g->[newNesting](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a789417fd364f9f027ab7b15a64568687)("Description", c_scene);

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) nestedgraph = g->[newInternalGraph](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a18e386611d62e038c91046c33a977102)(nesting);

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) c_person2 = g->[newGenericConcept](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a17a7ce6f06f385db02e12b28ae4ecc95)("Person", nestedgraph);

​    [iSet](https://cogitant.sourceforge.io/cogitant_html/namespacecogitant.html#a937249e6cbebcbd7038964d0e161035d) coref = g->[newCoreferenceClass](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a5bbd2953094db894d832983386af2ec0)();

​    g->[addCoreference](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#acd01fd531c818058e7d495ef47242a09)(c_person, coref);

​    g->[addCoreference](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#acd01fd531c818058e7d495ef47242a09)(c_person2, coref);

​    cout << *g << endl;

​    return 0;

}

The program execution leads to the following display, which allows you to  note that the coreference link between a concept vertex and its  coreference class is represented by "`=`" when displaying variables of the [cogitant::Edge](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Edge.html) type.

Q28cogitant5Graph

 Nodes : 0:Q28cogitant13InternalGraph, 1:Q28cogitant7Concept 11, 2:Q28cogitant7C

oncept 15, 3:Q28cogitant7Concept 13, 4:Q28cogitant8Relation 0, 5:Q28cogitant8Rel

ation 3, 6:Q28cogitant7Nesting 0, 7:Q28cogitant13InternalGraph, 8:Q28cogitant7Co

ncept 11, 9:Q28cogitant16CoreferenceClass cc9

 Edges :

 0:(P *)(C 1)(C 2)(C 3)(C 4)(C 5)

 1:(P 0)(2 4)(2 5)(C 6)(= 9)

 2:(P 0)(1 4)(1 5)

 3:(P 0)

 4:(P 0)(1 2)(2 1)

 5:(P 0)(1 2)(2 1)

 6:(P 1)(C 7)

 7:(P 6)(C 8)

 8:(P 7)(= 9)

 9:(P *)(= 1)(= 8)

Finally, you can use the coreference without handling coreference classes: the [cogitant::Graph::addCoreferenceLink(iSet,iSet)](https://cogitant.sourceforge.io/cogitant_html/classcogitant_1_1Graph.html#a956ff83e67fe7229a8b6e8861c49ac95) method takes as parameters two concept vertex identifiers and creates  the data structures corresponding to the addition of a coreference link  between these two vertices. This operation can create a coreference  class (if none of the vertices already belongs to such a class), add a  vertex to a coreference class (if one of the two vertices belongs to a  coreference class but not the other) or merge two coreference classes  (if both vertices already belong to distinct coreference classes). 

[Project page on Sourceforge](http://www.sourceforge.net/projects/cogitant).
Documentation: [General/C++](https://cogitant.sourceforge.io/cogitant_html/index.html) - [Java](https://cogitant.sourceforge.io/cogitantjava_html/index.html).

[![Get Cogitant at SourceForge.net. Fast, secure and Free Open Source software downloads](http://sflogo.sourceforge.net/sflogo.php?group_id=40204&type=13)](http://sourceforge.net/projects/cogitant)