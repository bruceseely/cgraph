

(initialize-context *context*)
(graphs *context*)


(pcg "[person]")
(pcg "[person: John]")

(setf s1 "[person: Sue]←(agnt)←[eat]→(obj)→[pie].")
(setf s2 "[girl]←(agnt)←[eat]→(manr)→[quickly].")

(combine-conceptual-graphs s1 s2)
(pcg *)

(setf g1 (make-cgraph "[person: Sue]←(agnt)←[eat]→(obj)→[pie]."))
(setf g2 (make-cgraph "[girl]←(agnt)←[eat]→(manr)→[quickly]."))

(combine-conceptual-graphs g1 g2)


(combine-cgraphs (list "[PERSON: Dave]←(agnt)←[DRIVE]"
                       "[CHEVY-VEHICLE]→(attr)→[OLD]"
                       "[PERSON: Dave]→(poss)→[CHEVY-VEHICLE]"
                       "[DRIVE]→(inst)→[CHEVY-VEHICLE]"
                       "[CITY: Baltimore]←(dest)←[DRIVE]"
                       "[PERSON: Dave]→(attr)→[YOUNG]"))

(add-cgraphs
 (combine-cgraphs (list "[PERSON: Dave]←(agnt)←[DRIVE]"
                        "[person: Sue]←(agnt)←[eat]→(obj)→[pie]"
                        "[CHEVY-VEHICLE]→(attr)→[OLD]"
                        "[PERSON: Dave]→(poss)→[CHEVY-VEHICLE]"
                        "[DRIVE]→(inst)→[CHEVY-VEHICLE]"
                        "[dog: Spot]→(attr)→[fast]"
                        "[CITY: Baltimore]←(dest)←[DRIVE]"
                        "[PERSON: Dave]→(attr)→[YOUNG]"
                        "[girl]←(agnt)←[eat]→(manr)→[quickly]"
                        "[dog: Spot]→(poss)→[cake]"))
 )

(graphs *context*)
(initialize-context *context*)

(query "[PERSON: *x]←(agnt)←[DRIVE]→(dest)→[CITY: *Y]" *context*)
(query "[PERSON: *x]→(attr)->[ATTRIBUTE: *Y]" *context*)
(query "[ANIMATE: *x]→(attr)->[ATTRIBUTE: *Y]" *context*)


(progn
  (initialize-context *context*)
  (add-cgraphs
   (combine-cgraphs (list "[PERSON: Dave]←(agnt)←[DRIVE]"
                          "[person: Sue]←(agnt)←[eat]→(obj)→[pie]"
                          "[pie]→(attr)→[ROUGH]"
                          "[CHEVY-VEHICLE]→(attr)→[OLD]"
                          "[PERSON: Dave]→(poss)→[CHEVY-VEHICLE]"
                          "[DRIVE]→(inst)→[CHEVY-VEHICLE]"
                          "[dog: Spot]→(attr)→[fast]"
                          "[CITY: Baltimore]←(dest)<-[DRIVE]"
                          "[PERSON: Dave]→(attr)→[YOUNG]"
                          "[girl]←(agnt)←[eat]→(manr)→[quickly]"
                          "[dog: Spot]→(poss)→[cake]")))
  (format t "~&graphs:~%~&~a~%" (graphs *context*))
  (let* ((query1 "[PERSON: *x]←(agnt)←[DRIVE]→(dest)→[CITY: *Y]")
         (result1 (query query1 *context*)))
    (format t "~&query1: ~s~%"  query1)
    (format t "~&result1: ~s~%"  result1))
  (let* ((query2 "[ENTITY: *x]→(attr)->[ATTRIBUTE: *y]")
         (result2 (query query2 *context*)))
    (format t "~&query2: ~s~%"  query2)
    (format t "~&result2: ~s~%"  result2))
  nil)



(progn
  (initialize-context *context*)
  (mapc #'make-cgraph (list "[PERSON: Dave]←(agnt)←[DRIVE]"
                            "[PERSON: Dave]→(poss)→[CHEVY-VEHICLE]"
                            "[DRIVE]→(inst)→[CHEVY-VEHICLE]"
                            "[CITY: Baltimore]←(dest)<-[DRIVE]"
                            "[PERSON: Dave]→(attr)→[YOUNG]"
                            "[CHEVY-VEHICLE]→(attr)→[OLD]"))
  (format t "~&before: (graphs *context*): ~s~%"  (graphs *context*))
  (consolidate-cgraphs)
  (format t "~&after: (graphs *context*): ~s~%"  (graphs *context*))
  (query "[PERSON: *x]←(agnt)←[DRIVE]→(dest)→[CITY: *Y]" *context*))


(progn
  (setq kb (make-context))
  ;;(format t "~&(graphs kb): ~:a~%"  (graphs kb))
  (include-cgraph "[PERSON: Dave]←(agnt)←[DRIVE]" kb)
  (include-cgraph "[PERSON: Dave]→(poss)→[CHEVY-VEHICLE]" kb)
  (include-cgraph "[DRIVE]→(inst)→[CHEVY-VEHICLE]" kb)
  (include-cgraph "[CITY: Baltimore]←(dest)<-[DRIVE]" kb)
  (include-cgraph "[PERSON: Dave]→(attr)→[YOUNG]" kb)
  (include-cgraph "[CHEVY-VEHICLE]→(attr)→[OLD]" kb)
  ;;(format t "~&(graphs kb): ~:a~%"  (graphs kb))
  (let* ((query-string "[PERSON: *x]←(agnt)←[DRIVE]→(dest)→[CITY: *Y]")
         (q (query query-string kb)))
    (format t "~%graph: ~a" (pcg (getf (car q) :graph)))
    (format t "~%query: ~a" query-string kb)
    (format t "~%bindings: ~a" (getf (car q) :bindings))))


(setq g1 (make-cgraph "[person: Bob]←(expr)←[desire]→(thme)→[cake]."))
(setq g2 (make-cgraph "[person: Bob]←(agnt)←[eat]→(obj)->[cake]."))
(setq g3  (make-cgraph "[person: Bob]←(expr)←[desire]→(goal)→[situation: [dog]←(agnt)←[eat]→(obj)->[cake] ]."))
(setq g11 (make-cgraph "[person: Bob *x]←(expr)←[desire]→(goal)→[situation: [person: Bob ?x]←(agnt)←[eat]→(obj)->[cake] ]."))
(setq g12 (make-cgraph "[person: Molly]←(expr)←[belief]→(stat)→[proposition: [person: Bob]←(expr)←[desire]→(thme)→[cake] ]."))
(setq g13 (make-cgraph "[person: Molly]←(expr)←[belief]→(stat)→[proposition: [person: Bob *x]←(expr)←[desire]→(goal)→[situation: [person: Bob ?x]←(agnt)←[eat]→(obj)->[cake]]."))
(setq g14 (make-cgraph "[PERSON: Molly *y]←(expr)←[belief]→(stat)→[proposition: [person: Bob *x]←(expr)←[desire]→(goal)→[situation: [person: Bob ?x]←(agnt)←[INFORM]- (rcpt)→[PERSON: Molly ?y] (inst)→[TELEPHONE] (obj)→[NEWS]"))


(setq g15 (make-cgraph "[CHEVY-VEHICLE]-
           (attr)→[OLD]
           (inst)←[DRIVE]-
                      (agnt)→[PERSON: dave *x]→(attr)→[YOUNG]
                      (dest)→[CITY: Baltimore],
           (poss)←[PERSON: dave *x]. "))


(query "[person: *x]←(expr)←[belief]→(stat)→[proposition: [person: *y]←(expr)←[desire]→(goal)→[situation: *z]]" *context* )



(let ((graph (make-cgraph "[PERSON: Sue]-
                             (agnt)←[GIVE]-
                                      (obj)→[FOOD]
                                      (rcpt)→[DOG: Spot],
                             (poss)→[DOG: Spot].")))
  (graph-to-text graph))

(let ((graph (make-cgraph "[PERSON: Dave]-
                             (agnt)←[GIVE]-
                                      (obj)→[FOOD]
                                      (rcpt)→[DOG: Spot],
                             (poss)→[DOG: Spot].")))
  (graph-to-text graph))


(let ((graph (make-cgraph "[CHEVY-VEHICLE]-
           (attr)→[OLD]
           (inst)←[DRIVE]-
                      (agnt)→[PERSON: dave *x]→(attr)→[YOUNG]
                      (dest)→[CITY: Baltimore],
           (poss)←[PERSON: dave *x]. ")))
  (print graph)
  (graph-to-text graph))





(progn
  (initialize-context *context*)
  (initialize-types :external-types-directory "~/repo/cgraph-types/")
  (setq g (make-cgraph "[DRINK]-
      (obj)→[MILK]-
               (cntns)←[BOTTLE]→(attr)→[NEW]
               (attr)→[FRESH],
      (agnt)→[BABY]-
                (attr)→[BLITHE]
                (part)→[BELLY]→(attr)→[FAT]"))
  (graph-to-text g))

(progn
  (initialize-context *context*)
  (initialize-types :external-types-directory "~/repo/cgraph-types/")
  (setq g (make-cgraph "[DRINK]-
      (obj)→[MILK]-
               (cntns)←[BOTTLE: {*}]→(attr)→[NEW]
               (attr)→[FRESH],
      (agnt)→[BABY: {*}]-
                (attr)→[BLITHE]
                (part)→[BELLY: {*}]→(attr)→[FAT]"))
  (graph-to-text g))

(progn
  (initialize-context *context*)
  (initialize-types :external-types-directory "~/repo/cgraph-types/")
  (setq g (make-cgraph "[DRINK]-
      (obj)→[MILK]-
               (cntns)←[BOTTLE: {*}]→(attr)→[NEW]
               (attr)→[FRESH],
      (agnt)→[BABY: {*}]-
                (attr)→[BLITHE]
                (part)→[BELLY:{*}]→(attr)→[FAT]"))
  (setq h (find-concept 'milk g))
  (setq z (make-cgraph h))
  (graph-to-text z))





(let ((g (make-cgraph "[person: Molly]←(expr)←[belief]→(stat)→[proposition: [person: Bob]←(expr)←[desire]→(thme)→[cake] ].")))
  (graph-to-text g))

(let ((g (make-cgraph "[person: Molly]←(expr)←[belief]→(stat)→[proposition: [person: Bob *x]←(expr)←[desire]→(goal)→[situation: [person: Bob ?x]←(agnt)←[eat]→(obj)->[cake]].")))
  (graph-to-text g))

(let ((g (make-cgraph "[PERSON: Molly *y]←(expr)←[belief]→(stat)→[proposition: [person: Bob *x]←(expr)←[desire]→(goal)→[situation: [person: Bob ?x]←(agnt)←[INFORM]- (rcpt)→[PERSON: Molly ?y] (inst)→[TELEPHONE] (obj)→[NEWS]")))
  (graph-to-text g))
