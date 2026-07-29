
;;; Remove the global-set-key and use the slime-mode-map bindings

;;; add this
;;; (global-set-key [(super e)] 'slime-eval-last-expression-in-repl)
;;; slime-eval-last-expression-in was c-c c-j
;;; s-e was isearch-yank-kill

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
         (result1 (multiple-value-list (query query1 *context*)))
         (plist (caar result1))
         (graph (caadr result1))
         (bindings (getf plist :bindings))
         (text (say graph)))
    (format t "~&query1: ~s~%"  query1)
    (format t "~&result1: ~s~%"  result1)
    (format t "~&plist: ~s~%"  plist)
    (format t "~&bindings: ~s~%"  bindings)
    (format t "~&graph: ~s~%"  graph)
    (format t "~&text: ~s~%"  text)
    )
  (let* ((query2 "[ENTITY: *x]→(attr)->[ATTRIBUTE: *y]")
         (result2 (multiple-value-list (query query2 *context*)))
         (plist (caar result2))
         (graphs (cadr result2))
         (bindings (mapcar (lambda (pl)
                             (getf pl :bindings))
                           (car result2)))
         (texts (mapcar (lambda (g)
                          (say g))
                        graphs)))

    (format t "~&query2: ~s~%"  query2)
    (format t "~&result2: ~s~%"  result2)
    (format t "~&plist: ~s~%"  plist)
    (format t "~&bindings: ~s~%"  bindings)
    (format t "~&graphs: ~s~%"  graphs)
    (format t "~&texts: ~s~%"  texts)
    )
  nil)


(multiple-value-list (query "[PERSON: *x]←(agnt)←[DRIVE]→(dest)→[CITY: *Y]" *context*))
(say (caadr *))



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

(progn
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
           (poss)←[PERSON: dave *x]. ")))


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
  (print (graph-to-text z))

  (setq h (find-concept 'baby g))
  (setq z (make-cgraph h))
  (print (graph-to-text z))

  t)





(let ((g (make-cgraph "[person: Molly]←(expr)←[belief]→(stat)→[proposition: [person: Bob]←(expr)←[desire]→(thme)→[cake] ].")))
  (graph-to-text g))

(let ((g (make-cgraph "[person: Molly]←(expr)←[belief]→(stat)→[proposition: [person: Bob *x]←(expr)←[desire]→(goal)→[situation: [person: Bob ?x]←(agnt)←[eat]→(obj)->[cake]].")))
  (graph-to-text g))

(let ((g (make-cgraph "[PERSON: Molly *y]←(expr)←[belief]→(stat)→[proposition: [person: Bob *x]←(expr)←[desire]→(goal)→[situation: [person: Bob ?x]←(agnt)←[INFORM]- (rcpt)→[PERSON: Molly ?y] (inst)→[TELEPHONE] (obj)→[NEWS]")))
  (format t "~%~a" (pcg g))
  (graph-to-text g))



(let ((kb (make-context)))
  (make-cgraph "[PERSON: Dave]←(agnt)←[DRIVE]" kb)
  (make-cgraph "[PERSON: Dave]→(poss)→[CHEVY-VEHICLE]" kb)
  (make-cgraph "[DRIVE]→(inst)→[CHEVY-VEHICLE]" kb)
  (make-cgraph "[CITY: Baltimore]←(dest)<-[DRIVE]" kb)
  (make-cgraph "[PERSON: Dave]→(attr)→[YOUNG]" kb)
  (make-cgraph "[CHEVY-VEHICLE]→(attr)→[OLD]" kb)
  (consolidate-cgraphs kb)
  (query "[PERSON: *x]←(agnt)←[DRIVE]→(dest)→[CITY: *Y]" kb))



(let ((kb (make-context)))
  (make-cgraph "[PERSON: Dave]←(agnt)←[DRIVE]" kb)
  (make-cgraph "[PERSON: Dave]→(poss)→[CHEVY-VEHICLE]" kb)
  (make-cgraph "[DRIVE]→(inst)→[CHEVY-VEHICLE]" kb)
  (make-cgraph "[CITY: Baltimore]←(dest)<-[DRIVE]" kb)
  (make-cgraph "[PERSON: Dave]→(attr)→[YOUNG]" kb)
  (make-cgraph "[CHEVY-VEHICLE]→(attr)→[OLD]" kb)
  (let (( result1 (query "[PERSON: *x]←(agnt)←[DRIVE]→(dest)→[CITY: *Y]" kb)))
    (consolidate-cgraphs kb)
    (let ((result2 (query "[PERSON: *x]←(agnt)←[DRIVE]→(dest)→[CITY: *Y]" kb)))
      (format t "~&result1: ~s~%"  result1)
      (format t "~&result2: ~s~%"  result2))))


(let ((g (make-cgraph "[PERSON: Molly *y]←(expr)←[belief]→(stat)→[proposition: [person: Bob *x]←(expr)←[desire]→(goal)→[situation: [person: Bob ?x]←(agnt)←[INFORM]- (rcpt)→[PERSON: Molly ?y] (inst)→[TELEPHONE] (obj)→[NEWS]")))
  (format t "~%~a" (pcg g))
  (graph-to-text g))
