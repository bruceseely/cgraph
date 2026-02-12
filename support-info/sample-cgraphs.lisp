

(PARSE-CGRAPH "[eat]-(agnt)->[monkey] (obj)->[walnut:*x] (inst)->[spoon]->(cons)->[shell]<-(part)<-[walnut:*x].")

[EAT]-
 (agnt)→[MONKEY]
 (inst)→[SPOON]→(cons)→[SHELL: *y]
 (obj)→[WALNUT: *x]→(part)→[SHELL: *y].


;; (pp (syntax-ppss))
