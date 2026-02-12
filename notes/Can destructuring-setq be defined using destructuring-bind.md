destructuring-setq



# [Can destructuring-setq be defined using destructuring-bind?](https://stackoverflow.com/questions/18945290/can-destructuring-setq-be-defined-using-destructuring-bind)

​                                

​                        Asked                        11 years, 4 months ago                    

​                        Modified                        [11 years, 4 months ago](https://stackoverflow.com/questions/18945290/can-destructuring-setq-be-defined-using-destructuring-bind?lastactivity)                    

​                        Viewed                        260 times                    

​        

2        

​        



There is destructuring-bind but it seems there is no destructuring-setq. Is it possible to define it using destructuring-bind?

```lisp
(let (a b c d)
  (destructuring-setq ((a b) (c d)) '((1 2) (3 4)))
  `(,b ,d))

(destructuring-bind
    ((a b) (c d)) '((1 2) (3 4))
  `(,b ,d))
```

- [macros](https://stackoverflow.com/questions/tagged/macros)
- [lisp](https://stackoverflow.com/questions/tagged/lisp)
- [common-lisp](https://stackoverflow.com/questions/tagged/common-lisp)
- [destructuring](https://stackoverflow.com/questions/tagged/destructuring)

​            [Share](https://stackoverflow.com/q/18945290)        

​                        [Improve this question](https://stackoverflow.com/posts/18945290/edit)                    

​                                            Follow                                                            

​            asked Sep 22, 2013 at 15:10        

![Le Curious's user avatar](https://www.gravatar.com/avatar/1015d45450bbbc77f57faff789ba819e?s=64&d=identicon&r=PG)

[Le Curious](https://stackoverflow.com/users/1408564/le-curious)

​            1,48122 gold badges1313 silver badges1414 bronze badges        

- ​                    2            

  Clearly, if `destructuring-bind` were sufficient for your needs, you wouldn't need to have a `destructuring-setq`. :-P Anyway, if you *really* wanted to, you could implement `destructuring-setq` using `destructuring-bind` using this approach: 1. `gensym` a bunch of symbols, one for each symbol in your destructuring lambda list. 2. Set up a `destructuring-bind` with those gensyms. 3. Set up a `setq` in the `destructuring-bind` body which does the real setting.

  – [C. K. Young](https://stackoverflow.com/users/13/c-k-young)                

  [                     Commented                     Sep 22, 2013 at 17:07                 ](https://stackoverflow.com/questions/18945290/can-destructuring-setq-be-defined-using-destructuring-bind#comment27978127_18945290)

- ​            

  FWIW and to add to what @ChrisJester-Young said, a `destructuring-setq` would become more useful when wrapped in a `symbol-macrolet`. A `destructuring-setf` sounds more general and useful, but its syntax wouldn't be neat, e.g.  in optional and keyword parameters, how would you tell apart more  destructuring from a place form?

  – [acelent](https://stackoverflow.com/users/800524/acelent)                

  [                     Commented                     Sep 24, 2013 at 14:34                 ](https://stackoverflow.com/questions/18945290/can-destructuring-setq-be-defined-using-destructuring-bind#comment28042635_18945290)

​                    [Add a comment](https://stackoverflow.com/questions/18945290/can-destructuring-setq-be-defined-using-destructuring-bind#)                                    



##                                         1 Answer                                                                    

​                    Sorted by:                    

​        

​    



​        

3        

​        

​                                    





This would be a highly nontrivial endeavor.

What you would have to do is write a [lambda-list](http://www.lispworks.com/documentation/HyperSpec/Body/03_de.htm) [analyzer](http://sourceforge.net/p/clisp/clisp/ci/default/tree/src/lambdalist.lisp) which would

1. Find all variables to be bound
2. Replace them with [gensym](http://www.lispworks.com/documentation/HyperSpec/Body/f_gensym.htm)s (or use [`copy-symbol`](http://www.lispworks.com/documentation/HyperSpec/Body/f_cp_sym.htm) for total unreadability of the macroexpansion :-) and keep a map from the old symbols to the new ones.

Return something like

```lisp
(destructuring-bind (new-lambda-list)
     expression
   (setq old-var-1 new-gensym-1 ...))
```

The analyser is present in any Common Lisp implementation (see, e.g., the link above) and it is *not* simple.

I suggest that you ask yourself whether [`destructuring-bind`](http://www.lispworks.com/documentation/HyperSpec/Body/m_destru.htm) is *really* not enough.



​            [Share](https://stackoverflow.com/a/18948178)        

​                        [Improve this answer](https://stackoverflow.com/posts/18948178/edit)                    

​                                            Follow                                                            

​            [edited Sep 24, 2013 at 17:00](https://stackoverflow.com/posts/18948178/revisions)        

​            

​                    





​                                                                                                                                