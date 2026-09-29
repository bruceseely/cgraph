;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Testing contexts in conceptual graphs
;;;

(in-package #:conceptual-graphs)

(defvar *pc)
(defmethod cache-test (&optional verbose)
  (with-test-types
    (setf verbose t) ; <==================================================<<<<
    (let* ((*include-node-ref* nil)
           (parent-context (make-context))
           (con1 (make-concept 'dog '(:name "Spot") :context parent-context))
           (computed-id (when con1
                          (when (referent con1) (id (content (referent con1)))))))

    (when verbose
      (format t "~&parent-context: ~s~%"  parent-context)
      (format t "~&con1, ~s, in context ~a~%"  con1 parent-context))

    (let* ((lookup-con1 (retrieve-concept 'dog '(:name "Spot") :context parent-context)))
      (when verbose
        (format t "~&lookup-con1: ~a~%"   lookup-con1)
        (format t  "~&---------------------------------------------~2%"))

      (let* ((context  (make-context parent-context))
             (con2 (make-concept 'dog '(:name "Spot") :context context))
             (computed-id (when con2
                            (when (referent con2) (id (content (referent con2)))))))
        (when verbose
          (format t "~&context: ~s~%"  context)
          (format t "~&con2, ~s, in context ~a~%"  con2 context))

        (let* ((lookup-con2 (retrieve-concept 'dog '(:name "Spot") :context context)))
          (when verbose
            (format t "~&lookup-con2: ~s~%"  lookup-con2)
            (format t  "~&---------------------------------------------~2%"))

          (let* ((lookup-con3 (retrieve-concept 'dog '(:name "Spot") :context parent-context)))
            (when verbose
              (format t "~&lookup-con3: ~s~%"  (pcg lookup-con3))
              (format t  "~&---------------------------------------------~2%"))

            (let* ((con (get-concept 'dog '(:name "Spot") :context parent-context))
                   (con2 (get-concept 'dog `(:name "Spot") :id computed-id ))
                   (con3 (get-concept 'dog `(:name "Spot") :id computed-id ))
                   )
              (when verbose
                (format t "~&computed-id: ~s~%"  computed-id)
                (format t "~&con: ~s~%" (pcg con))
                (format t "~&con2: ~s~%" (pcg con2))
                (format t  "~&---------------------------------------------~2%"))



              (and (concepts-equal con1 lookup-con1)
                   (concepts-equal con2 lookup-con2)
                   )))))))))

;;; --- the concept-cache index ------------------------------------------------
;;;
;;; CACHE-CONCEPT runs from CONCEPT's INITIALIZE-INSTANCE :AFTER, so it is on the
;;; path of every concept ever made. It used to do
;;;
;;;   (pushnew concept (nodes context) :test #'concepts-equal)
;;;
;;; which scans the whole cache per call: O(n) per concept, O(n^2) over a corpus,
;;; and once ADD-CGRAPH was made linear this was where the time in graph
;;; construction went. It now buckets by a cheap key and compares only inside the
;;; bucket. What must NOT change is PUSHNEW's semantics -- one representative per
;;; equal concept -- so that is what most of this checks.
;;;
;;; NB: these build concepts through MAKE-INDIVIDUAL + MAKE-REFERENT rather than
;;; handing MAKE-CONCEPT a property list, because that method RETURNS NIL unless
;;; the individual already exists -- its two creating branches only return
;;; something when the referent came back NULL. See notes/known-issues.md. Going
;;; the long way keeps this test about the cache.

(defun %cache-test-concept (type name context)
  "A concept of TYPE named NAME, cached in CONTEXT."
  (let* ((ctype (get-concept-type type))
         (indiv (make-individual ctype (list :name name)))
         (ref   (make-referent indiv)))
    (make-concept ctype ref :context context)))

(defun concept-cache-index-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (name result)
               (setf ok (and ok (and result t)))
               (when (or verbose (not result))
                 (format t "~&  ~:[fail~;pass~] ~a~%" result name))))
        (when verbose (format t "~&CONCEPT-CACHE-INDEX-TEST~%"))

        ;; PUSHNEW's semantics: an equal concept is not cached twice. Two
        ;; individuals of one type with the same name and the same id are equal.
        (let* ((ctx   (make-context))
               (ctype (get-concept-type 'dog))
               (indiv (make-individual ctype (list :name "Spot"))))
          (make-concept ctype (make-referent indiv) :context ctx)
          (make-concept ctype (make-referent indiv) :context ctx)
          (check "an equal concept is cached once"
                 (eql 1 (length (nodes ctx)))))

        ;; ... and concepts that differ are all kept.
        (let ((ctx (make-context)))
          (%cache-test-concept 'dog "Spot"  ctx)
          (%cache-test-concept 'dog "Rover" ctx)
          (%cache-test-concept 'cat "Spot"  ctx)
          (check "concepts differing in name or type are all cached"
                 (eql 3 (length (nodes ctx)))))

        ;; The point of the change. 400 distinct concepts used to cost
        ;; 400*399/2 = 79,800 CONCEPTS-EQUAL calls; bucketed it is a small
        ;; multiple of 400. Counted, not timed, so the check is deterministic.
        (let ((*concept-comparisons* 0)
              (ctx (make-context))
              (n 400))
          (dotimes (i n)
            (%cache-test-concept 'dog (format nil "Dog~d" i) ctx))
          (check "400 distinct concepts are all cached"
                 (eql n (length (nodes ctx))))
          (check "and cost far fewer than n^2 concept comparisons"
                 (< *concept-comparisons* (* 4 n))))

        ;; The index must notice the other writers of (NODES CONTEXT).
        (let ((ctx (make-context)))
          (%cache-test-concept 'dog "Spot" ctx)
          (clear-concept-cache ctx)
          (check "the cache is empty after CLEAR-CONCEPT-CACHE"
                 (null (nodes ctx)))
          (%cache-test-concept 'dog "Spot" ctx)
          (check "and caches again afterwards"
                 (eql 1 (length (nodes ctx)))))

        (let* ((ctx (make-context))
               (con (%cache-test-concept 'dog "Spot" ctx)))
          (decache-concept con)
          (check "a decached concept leaves the cache"
                 (null (nodes ctx)))
          (%cache-test-concept 'dog "Spot" ctx)
          (check "and an equal one can be cached again"
                 (eql 1 (length (nodes ctx)))))

        ;; Lookup still reads (NODES CONTEXT): the index accelerates the write
        ;; side, it is not a second store.
        (let* ((ctx (make-context))
               (con (%cache-test-concept 'dog "Fido" ctx)))
          (check "RETRIEVE-CONCEPTS-HAVING-INDIVIDUAL still finds it"
                 (member con (retrieve-concepts-having-individual
                              (content (referent con)) ctx))))

        (when verbose
          (format t "~&CONCEPT-CACHE-INDEX-TEST ~:[failed~;passed~]~%" ok))
        ok))))
