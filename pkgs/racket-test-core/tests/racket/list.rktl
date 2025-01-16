
(load-relative "loadtest.rktl")

(Section 'list)

(require racket/list)

(define (test-equal-always . args)
  (apply test (append args (list equal-always?)))
  (apply test (append args (list (λ (x y) (equal-always? x y))))))

(test (list 1 2 3 4) foldl cons '() (list 4 3 2 1))
(test (list 1 2 3 4) foldr cons '() (list 1 2 3 4))
(test (list (list 5 6) (list 3 4) (list 1 2))
      foldl (lambda (x y sofar) (cons (list x y) sofar))
      '()
      (list 1 3 5)
      (list 2 4 6))
(test (list (list 1 2) (list 3 4) (list 5 6))
      foldr (lambda (x y sofar) (cons (list x y) sofar))
      '()
      (list 1 3 5)
      (list 2 4 6))

(arity-test foldl 3 -1)
(arity-test foldr 3 -1)

(err/rt-test (foldl 'list 0 10))
(err/rt-test (foldl list 0 10))
(err/rt-test (foldl add1 0 '()))
(err/rt-test (foldl cons 0 '() '()))
(err/rt-test (foldl list 0 '() 10))
(err/rt-test (foldl list 0 '() '() 10))
(err/rt-test (foldl list 0 '() '() 10)
             exn:fail:contract?
             "expected.*list\\?.*5th")
(err/rt-test (foldl list 0 '() '() '() 10)
             exn:fail:contract?
             "expected.*list\\?.*6th")
(err/rt-test (let/ec k (foldl k 0 '(1 2) '(1 2 3))))
(err/rt-test (let/ec k (foldl k 0 '(1 2) '(1 2) '(1 2 3))))
(err/rt-test (foldr 'list 0 10))
(err/rt-test (foldr list 0 10))
(err/rt-test (foldr add1 0 '()))
(err/rt-test (foldr cons 0 '() '()))
(err/rt-test (foldr list 0 '() 10))
(err/rt-test (foldr list 0 '() '() 10))
(err/rt-test (foldr list 0 '() '() 10)
             exn:fail:contract?
             "expected.*list\\?.*5th")
(err/rt-test (foldr list 0 '() '() '() 10)
             exn:fail:contract?
             "expected.*list\\?.*6th")
(err/rt-test (let/ec k (foldr k 0 '(1 2) '(1 2 3))))
(err/rt-test (let/ec k (foldr k 0 '(1 2) '(1 2) '(1 2 3))))

(test '(0 1 2) memf add1 '(0 1 2))
(test '(2 (c 17)) memf number? '((a 1) (0 x) (1 w) 2 (c 17)))
(test '("ok" (2 .7) c) memf string? '((a 0) (0 a) (1 w) "ok" (2 .7) c))
(err/rt-test (memf cons '((1) (2) (3))))
(err/rt-test (memf string? '((1) (2) (3) . 4)) exn:application:mismatch?)

(err/rt-test (assf add1 '(0 1 2)) exn:application:mismatch?)
(test '(0 x) assf number? '((a 1) (0 x) (1 w) (2 r) (c 17)))
(test '("ok" . 10) assf string? '((a 0) (0 a) (1 w) ("ok" . 10) (2 .7) c))
(err/rt-test (assf cons '((1) (2) (3))))
(err/rt-test (assf string? '((1) (2) (3) . 4)) exn:application:mismatch?)

;; ---------- last, last-pair ----------
(let ()
  (test 3        last '(1 2 3))
  (test '(3)     last-pair '(1 2 3))
  (err/rt-test  (last '(1 2 3 . 4)))
  (test '(3 . 4) last-pair '(1 2 3 . 4))
  (err/rt-test  (last '()))
  (err/rt-test  (last 1))
  (err/rt-test  (last-pair '()))
  (err/rt-test  (last-pair 1)))

;; ---------- sort ----------
(test '("a" "b" "c" "c" "d" "e" "f")
      sort
      '("d" "f" "e" "c" "a" "c" "b")
      string<?)
(let ()
  (define (car< x y) (< (car x) (car y)))
  (define (random-list n range)
    (let loop ([n n] [r '()])
      (if (zero? n) r (loop (sub1 n) (cons (list (random range)) r)))))
  (define (sort* lst)
    (let ([s1 (sort lst car<)]
          [s2 (sort lst < #:key car)]
          [s3 (sort lst < #:key car #:cache-keys? #t)])
      (test #t andmap eq? s1 s2)
      (test #t andmap eq? s1 s3)
      s1))
  (define (test-sort len times)
    (or (zero? times)
        (and (let* ([rand (random-list len (if (even? times) 1000000 10))]
                    [orig< (lambda (x y) (memq y (cdr (memq x rand))))]
                    [sorted (sort* rand)]
                    [l1 (reverse (cdr (reverse sorted)))]
                    [l2 (cdr sorted)])
               (and (= (length sorted) (length rand))
                    (andmap (lambda (x1 x2)
                              (and (not (car< x2 x1)) ; sorted?
                                   (or (car< x1 x2) (orig< x1 x2)))) ; stable?
                            l1 l2)))
             (test-sort len (sub1 times)))))
  (test #t test-sort    1  10)
  (test #t test-sort    2  20)
  (test #t test-sort    3  60)
  (test #t test-sort    4 100)
  (test #t test-sort    5 100)
  (test #t test-sort   10 100)
  (test #t test-sort  100 100)
  (test #t test-sort 1000 100)
  ;; test stability
  (test '((1) (2) (3 a) (3 b) (3 c)) sort* '((3 a) (1) (3 b) (2) (3 c)))
  ;; test short lists (+ stable)
  (test '() sort* '())
  (test '((1 1)) sort* '((1 1)))
  (test '((1 2) (1 1)) sort* '((1 2) (1 1)))
  (test '((1) (2)) sort* '((2) (1)))
  (for-each (lambda (l) (test '((0 3) (1 1) (1 2)) sort* l))
            '(((1 1) (1 2) (0 3))
              ((1 1) (0 3) (1 2))
              ((0 3) (1 1) (1 2))))
  (for-each (lambda (l) (test '((0 2) (0 3) (1 1)) sort* l))
            '(((1 1) (0 2) (0 3))
              ((0 2) (1 1) (0 3))
              ((0 2) (0 3) (1 1))))
  ;; exhaustive tests for 2 and 3 item lists
  (for-each (lambda (l) (test '((1 x) (2 y)) sort* l))
            '(((1 x) (2 y))
              ((2 y) (1 x))))
  (for-each (lambda (l) (test '((1 x) (2 y) (3 z)) sort* l))
            '(((1 x) (2 y) (3 z))
              ((2 y) (1 x) (3 z))
              ((2 y) (3 z) (1 x))
              ((3 z) (2 y) (1 x))
              ((3 z) (1 x) (2 y))
              ((1 x) (3 z) (2 y)))))
;; test #:key and #:cache-keys?
(let ()
  (define l '((0) (9) (1) (8) (2) (7) (3) (6) (4) (5)))
  (define sorted '((0) (1) (2) (3) (4) (5) (6) (7) (8) (9)))
  (test sorted sort l < #:key car)
  (let ([c1 0] [c2 0] [touched '()])
    (test sorted
          sort l (lambda (x y) (set! c1 (add1 c1)) (< x y))
                 #:key (lambda (x)
                         (set! c2 (add1 c2))
                         (set! touched (cons x touched))
                         (car x)))
    ;; test that the number of key uses is half the number of comparisons
    (test #t = (* 2 c1) c2)
    ;; and that this is larger than the number of items in the list
    (test #t < (length l) c2)
    ;; and that every item was touched
    (test null remove* touched l))
  (let ([c 0] [touched '()])
    ;; now cache the keys
    (test sorted
          sort l <
               #:key (lambda (x)
                       (set! c (add1 c))
                       (set! touched (cons x touched))
                       (car x))
               #:cache-keys? #t)
    ;; test that the number of key uses is the same as the list length
    (test #t = c (length l))
    ;; and that every item was touched
    (test null remove* touched l))
  (let* ([c 0] [getkey (lambda (x) (set! c (add1 c)) x)])
    ;; either way, we never use the key proc on no arguments
    (test '() sort '() < #:key getkey #:cache-keys? #f)
    (test '() sort '() < #:key getkey #:cache-keys? #t)
    (test #t = c 0)
    ;; we also don't use it for 1-arg lists
    (test '(1) sort '(1) < #:key getkey #:cache-keys? #f)
    (test #t = c 0)
    ;; but we do use it once if caching happens (it's a consistent interface)
    (test '(1) sort '(1) < #:key getkey #:cache-keys? #t)
    (test #t = c 1)
    ;; check a few other short lists
    (test '(1 2) sort '(2 1) < #:key getkey #:cache-keys? #t)
    (test '(1 2 3) sort '(2 3 1) < #:key getkey #:cache-keys? #t)
    (test '(1 2 3 4) sort '(4 2 3 1) < #:key getkey #:cache-keys? #t)
    (test #t = c 10)))

;; ---------- make-list ----------
(let ()
  (test '()    make-list 0 'x)
  (test '(x)   make-list 1 'x)
  (test '(x x) make-list 2 'x)
  (err/rt-test (make-list -3 'x)))

;; ---------- take/drop/splt-at[-right] ----------
(let ()
  (define (vals f)
    (procedure-reduce-arity
     (lambda xs (call-with-values (lambda () (apply f xs)) list))
     (procedure-arity f)))
  (define split-at*        (vals split-at))
  (define split-at-right*  (vals split-at-right))
  (define splitf-at*       (vals splitf-at))
  (define splitf-at-right* (vals splitf-at-right))
  (define funs (list take drop take-right drop-right
                     split-at* split-at-right*))
  (define ffuns (list takef dropf takef-right dropf-right
                      splitf-at* splitf-at-right*))
  (define tests
    ;; -----args------ --take--- --drop--- ---take-r---- --drop-r-
    '([((a b c d) 0)   (       ) (a b c d)   (       )   (a b c d)]
      [((a b c d) 1)   (a      ) (  b c d)   (      d)   (a b c  )]
      [((a b c d) 2)   (a b    ) (    c d)   (    c d)   (a b    )]
      [((a b c d) 3)   (a b c  ) (      d)   (  b c d)   (a      )]
      [((a b c d) 4)   (a b c d) (       )   (a b c d)   (       )]
      [((a b c . d) 0) (     )   (a b c . d)        d    (a b c  )]
      [((a b c . d) 1) (a    )   (  b c . d) (    c . d) (a b    )]
      [((a b c . d) 2) (a b  )   (    c . d) (  b c . d) (a      )]
      [((a b c . d) 3) (a b c)            d  (a b c . d) (       )]
      [(() 0)          ()        ()          ()          ()       ]
      [(99 0)          ()        99          99          ()       ]))
  (define ftests ; the predicate is always `symbol?'
    ;; ---args---- --takef-- ---dropf--- --takef-r-- --dropf-r--
    `([(a b c d)   (a b c d) (       )   (a b c d)   (       )  ]
      [(a b c 4)   (a b c  ) (      4)   (       )   (a b c 4)  ]
      [(a b 3 4)   (a b    ) (    3 4)   (       )   (a b 3 4)  ]
      [(a 2 3 4)   (a      ) (  2 3 4)   (       )   (a 2 3 4)  ]
      [(1 2 3 4)   (       ) (1 2 3 4)   (       )   (1 2 3 4)  ]
      [(1 2 3 d)   (       ) (1 2 3 d)   (      d)   (1 2 3  )  ]
      [(1 2 c d)   (       ) (1 2 c d)   (    c d)   (1 2    )  ]
      [(1 b c d)   (       ) (1 b c d)   (  b c d)   (1      )  ]
      [(a 2 3 d)   (a      ) (  2 3 d)   (      d)   (a 2 3  )  ]
      [(1 b c 4)   (       ) (1 b c 4)   (       )   (1 b c 4)  ]
      [(a b c . d) (a b c  )          d  (a b c . d) (         )]
      [(a b c . 4) (a b c  )          4  (a b c . 4) (         )]
      [(a b 3 . 4) (a b    ) (    3 . 4)          4  (a b 3    )]
      [(a 2 3 . 4) (a      ) (  2 3 . 4)          4  (a 2 3    )]
      [(1 2 3 . 4) (       ) (1 2 3 . 4)          4  (1 2 3    )]
      [(1 2 3 . d) (       ) (1 2 3 . d)          d  (1 2 3    )]
      [(1 2 c . d) (       ) (1 2 c . d) (    c . d) (1 2      )]
      [(1 b c . d) (       ) (1 b c . d) (  b c . d) (1        )]
      [(a 2 c . d) (a      ) (  2 c . d) (    c . d) (a 2      )]
      [(1 b 3 . 4) (       ) (1 b 3 . 4)          4  (1 b 3    )]
      [()          ()        ()          ()          ()         ]
      [99          ()        99          99          ()         ]))
  (for ([t tests]
        #:when #t
        [expect `(,@(cdr t)
                  ,(list (list-ref t 1) (list-ref t 2))
                  ,(list (list-ref t 4) (list-ref t 3)))]
        [fun funs])
    (apply test expect fun (car t)))
  (for ([t ftests]
        #:when #t
        [expect `(,@(cdr t)
                  ,(list (list-ref t 1) (list-ref t 2))
                  ,(list (list-ref t 4) (list-ref t 3)))]
        [fun ffuns])
    (test expect fun (car t) symbol?))
  (for ([fun (append funs ffuns)])
    (arity-test fun 2 2)
    (err/rt-test (fun 1 1) exn:application:mismatch?)
    (err/rt-test (fun '(1 2 3) 2.0))
    (err/rt-test (fun '(1) '(1)))
    (err/rt-test (fun '(1) -1))
    (err/rt-test (fun '(1) 2) exn:application:mismatch?)
    (err/rt-test (fun '(1 2 . 3) 3) exn:application:mismatch?)))

;; ---------- append* ----------
(let ()
  (test '()        append* '())
  (test '()        append* '(()))
  (test '()        append* '(() ()))
  (test '(0 1 2 3) append* '((0 1 2 3)))
  (test '(0 1 2 3) append* '(0 1 2 3) '())
  (test '(0 1 2 3) append* '(0 1 2 3) '(()))
  (test '(0 1 2 3) append* '(0 1 2 3) '(() ()))
  (test '(0 1 2 3) append* '(0 1) '((2) (3)))
  (test '(0 1 0 2 0 3) append* (map (lambda (x) (list 0 x)) '(1 2 3)))
  (test '(1 2 3 4 5 6 7 8 9) append* '(1 2 3) '(4 5) '((6 7 8) (9))))

;; ---------- flatten ----------
(let ()
  (define (all-sexps n)
    (if (zero? n)
      '(x ())
      (let ([r (all-sexps (sub1 n))])
        (append r (for*/list ([x r] [y r]) (cons x y))))))
  (define sexps (all-sexps 3)) ; can use 4 on fast machines
  (define (flat? x) (and (list? x) (andmap (lambda (x) (eq? 'x x)) x)))
  (for ([x sexps]) (test #t flat? (flatten x))))

;; ---------- add-between ----------
(let ()
  ;; simple cases
  (for ([l  (in-list '(() (x) (x y) (x y z) (x y z w)))]
        [r1 (in-list '(() (x) (x 5 y) (x 5 y 5 z) (x 5 y 5 z 5 w)))]
        [r2 (in-list '(() (x) (x 7 y) (x 5 y 7 z) (x 5 y 5 z 7 w)))]
        [r3 (in-list '(() (x) (x (5) y) (x (5) y (5) z)
                       (x (5) y (5) z (5) w)))])
    (test r1 add-between l 5)
    ;; (test `(0 ,@r1) add-between l 5 #:before-first 0)
    ;; (test `(,@r1 9) add-between l 5 #:after-last 9)
    ;; (test `(0 ,@r1 9) add-between l 5 #:before-first 0 #:after-last 9)
    (test r2 add-between l 5 #:before-last 7)
    ;; (test `(0 ,@r2) add-between l 5 #:before-first 0 #:before-last 7)
    ;; (test `(,@r2 9) add-between l 5 #:after-last 9 #:before-last 7)
    ;; (test `(0 ,@r2 9) add-between l 5 #:before-first 0 #:after-last 9 #:before-last 7)
    (test r3 add-between l '(5))
    ;; (test `(0 ,@r3) add-between l '(5) #:before-first 0)
    ;; (test `(,@r3 9) add-between l '(5) #:after-last 9)
    ;; (test `(0 ,@r3 9) add-between l '(5) #:before-first 0 #:after-last 9)
    ;; (test r1 add-between l 5 #:nothing #f #:before-first #f)
    ;; (test r1 add-between l 5 #:nothing #f #:after-last #f)
    )
  ;; spliced cases
  (for* ([x (in-list '(() (4) (4 5)))]
         [y (in-list '(() (6) (6 7)))])
    (for ([l  (in-list '(() (x) (x y) (x y z) (x y z w)))]
          [r1 (in-list `(() (x) (x ,@x y) (x ,@x y ,@x z)
                         (x ,@x y ,@x z ,@x w)))]
          [r2 (in-list `(() (x) (x ,@y y) (x ,@x y ,@y z)
                         (x ,@x y ,@x z ,@y w)))])
      (test r1 add-between l x #:splice? #t)
      (test r2 add-between l x #:splice? #t #:before-last y)
      (for ([fst (in-list '(() (0) (0 1)))])
        (test `(,@fst ,@r1) add-between l x
              #:splice? #t #:before-first fst)
        (test `(,@fst ,@r2) add-between l x
              #:splice? #t #:before-first fst #:before-last y))
      (for ([lst (in-list '(() (9) (8 9)))])
        (test `(,@r1 ,@lst) add-between l x
              #:splice? #t #:after-last lst)
        (test `(,@r2 ,@lst) add-between l x
              #:splice? #t #:after-last lst #:before-last y))
      (for* ([fst (in-list '(() (0) (0 1)))]
             [lst (in-list '(() (9) (8 9)))])
        (test `(,@fst ,@r1 ,@lst) add-between l x
              #:splice? #t #:before-first fst #:after-last lst)
        (test `(,@fst ,@r2 ,@lst) add-between l x
              #:splice? #t #:before-first fst #:after-last lst #:before-last y)))))

;; ---------- check-duplicates ----------

(test #f check-duplicates '())
(test 'a check-duplicates '(a a))
(test 'a check-duplicates '(a b a))
(test 'a check-duplicates '(a a b))
(test '(a 3) check-duplicates '((a 1) (b 2) (a 3)) #:key car)
(test 4 check-duplicates '(1 2 3 4 5 6) (lambda (x y) (equal? (modulo x 3) (modulo y 3))))
(test #f check-duplicates '(#t #f #f) #:default "no dups")
(test "no dups" check-duplicates '(#t #f) #:default "no dups")
(test "no dups" check-duplicates '(#t #f) #:default (lambda () "no dups"))
(test (box 1) check-duplicates (list (box 1) (box 1)) equal?)
(test-equal-always #f check-duplicates (list (box 1) (box 1)))
(let ([b (box 1)])
  (test-equal-always b check-duplicates (list b b)))
(err/rt-test (check-duplicates 'a))
(err/rt-test (check-duplicates '(1) #f))
(err/rt-test (check-duplicates '(1) #:key #f))

;; ---------- remove-duplicates ----------
(let ()
  (define rd remove-duplicates)
  ;; basic 'naive tests
  (test '() rd '())
  (test '(a) rd '(a a a a))
  (test '(a b) rd '(a b))
  (test '(a b) rd '(a b a b a b))
  (test '(a b) rd '(a a a b b b))
  (test '(a b) rd '(a b b a)) ; keeps first occurrences
  (test '("a" "b") rd '("a" "A" "b" "B" "a") #:key string-downcase)
  (let ([long (for/list ([i (in-range 300)]) i)])
    (test long rd long)
    (test long rd (append long long))
    (test long rd (append long (reverse long))) ; keeps first
    (test long rd (append* (map (lambda (x) (list x x)) long)))
    (test long rd (append long (map (lambda (x) (- x)) long)) #:key abs)
    (test long rd (append long (map (lambda (x) (- x)) long)) = #:key abs))
  (test (list (box 1)) rd (list (box 1) (box 1)) equal?)
  (test (list* (box 1) (box 0) (map box (range 2 100))) rd
        (append (list (box 1)) (map box (range 100)) (list (box 1)))
        equal?)
  (test-equal-always (list (box 1) (box 1)) rd (list (box 1) (box 1)))
  (test-equal-always
   (append (list (box 1)) (map box (range 100)) (list (box 1))) rd
   (append (list (box 1)) (map box (range 100)) (list (box 1))))
  (let ([b (box 1)])
    (test-equal-always (list b) rd (list b b))
    (test-equal-always
     (cons b (map box (range 100))) rd
     (append (list b) (map box (range 100)) (list b)))))

;; ---------- filter and filter-not ----------
(let ()
  (define f filter)
  (define fn filter-not)

  (test '()              f  number? '())
  (test '()              fn number? '())
  (test '(1 2 3)         f  number? '(1 a 2 b 3 c d))
  (test '(a b c d)       fn number? '(1 a 2 b 3 c d))
  (test '()              f  string? '(1 a 2 b 3 c d))
  (test '(1 a 2 b 3 c d) fn string? '(1 a 2 b 3 c d))
  (err/rt-test (f string? '(1 2 3 . 4)) exn:application:mismatch?)
  (err/rt-test (fn string? '(1 2 3 . 4)) exn:application:mismatch?)
  (err/rt-test (f  2 '(1 2 3)))
  (err/rt-test (fn 2 '(1 2 3)))
  (err/rt-test (f cons '(1 2 3)))
  (err/rt-test (fn cons '(1 2 3)))
  (arity-test f  2 2)
  (arity-test fn 2 2))

;; ---------- partition ----------
(let ()
  (define (p pred l) (call-with-values (lambda () (partition pred l)) list))
  (test '(() ()) p (lambda (_) #t) '())
  (test '(() ()) p (lambda (_) #f) '())
  (test '((1 2 3 4) ()) p (lambda (_) #t) '(1 2 3 4))
  (test '(() (1 2 3 4)) p (lambda (_) #f) '(1 2 3 4))
  (test '((2 4) (1 3)) p even? '(1 2 3 4))
  (test '((1 3) (2 4)) p odd? '(1 2 3 4)))

;; ---------- filter-map ----------
(let ()
  (define fm filter-map)
  (test '() fm values '())
  (test '(1 2 3) fm values '(1 2 3))
  (test '() fm values '(#f #f #f))
  (test '(1 2 3) fm values '(#f 1 #f 2 #f 3 #f))
  (test '(4 8 12) fm (lambda (x) (and (even? x) (* x 2))) '(1 2 3 4 5 6)))

;; ---------- count ----------

(let ()
  (test 0 count even? '())
  (test 4 count even? '(0 2 4 6))
  (test 0 count even? '(1 3 5 7))
  (test 2 count even? '(1 2 3 4))
  (test 2 count < '(1 2 3 4) '(4 3 2 1)))

;; ---------- append-map ----------
(let ()
  (define am append-map)
  (test '() am list '())
  (test '(1 2 3) am list '(1 2 3))
  (test '(1 1 2 2 3 3) am (lambda (x) (list x x)) '(1 2 3)))

;; ---------- shuffle ----------
(let loop ([l (reverse '(1 2 4 8 16 32))])
  (define (length+sum l) (list (length l) (apply + l)))
  (define expected (length+sum l))
  (for ([i (in-range 100)])
    (test expected length+sum (shuffle l)))
  (when (pair? l) (loop (cdr l))))

;; ---------- combinations ----------
(let ()
  (define (comb<? l1 l2) ; (works only on tests with numeric lists)
    (define L1 (length l1))
    (define L2 (length l2))
    (or (< L1 L2)
        (and (= L1 L2)
             (let loop ([l1 l1] [l2 l2])
               (or (< (car l1) (car l2))
                   (and (= (car l1) (car l2))
                        (loop (cdr l1) (cdr l2))))))))
  (define (sorted-combs l k)
    (define l1 (sort (combinations l k) comb<?))
    (define l2 (sort (for/list ([c (in-combinations l k)]) c) comb<?))
    (test #t equal? l1 l2)
    l1)
  (test '(()) sorted-combs '() #f)
  (test '(()) sorted-combs  '() 0)
  (test '() sorted-combs '() 9)
  (test '(() (6)) sorted-combs '(6) #f)
  (test '(()) sorted-combs '(6) 0)
  (test '((6)) sorted-combs '(6) 1)
  (test '() sorted-combs '(6) 2)
  (test '(() (8) (9) (9 8)) sorted-combs '(9 8) #f)
  (test '((8) (9)) sorted-combs '(9 8) 1)
  (test '((9 8)) sorted-combs '(9 8) 2)
  (test
   '(() (1) (2) (3) (4) (5) (1 2) (1 3) (1 5) (2 3) (2 5) (4 1) (4 2) (4 3) (4 5)
     (5 3) (1 2 3) (1 2 5) (1 5 3) (2 5 3) (4 1 2) (4 1 3) (4 1 5) (4 2 3)
     (4 2 5) (4 5 3) (1 2 5 3) (4 1 2 3) (4 1 2 5) (4 1 5 3) (4 2 5 3) (4 1 2 5 3))
   sorted-combs '(4 1 2 5 3) #f)
  (test '(()) sorted-combs '(4 1 2 5 3) 0)
  (test
   '((1 2) (1 3) (1 5) (2 3) (2 5) (4 1) (4 2) (4 3) (4 5) (5 3))
   sorted-combs '(4 1 2 5 3) 2)
  (test
   '((1 2 3) (1 2 5) (1 5 3) (2 5 3) (4 1 2) (4 1 3) (4 1 5) (4 2 3) (4 2 5) (4 5 3))
   sorted-combs '(4 1 2 5 3) 3)
  (test
   21
   (lambda (n k)
     (length (combinations n k)))
   '(1 2 3 4 5 6 7)
   5))

;; ---------- permutations ----------
(let ()
  (define (perm<? l1 l2) ; (works only on tests with numeric lists)
    (let loop ([l1 l1] [l2 l2])
      (and (pair? l1) (or (< (car l1) (car l2))
                          (and (= (car l1) (car l2))
                               (loop (cdr l1) (cdr l2)))))))
  (define (sorted-perms l)
    (define l1 (permutations l))
    (define l2 (for/list ([p (in-permutations l)]) p))
    (test #t equal? l1 l2)
    (sort l1 perm<?))
  (test '(())  sorted-perms '())
  (test '((1)) sorted-perms '(1))
  (test '((1 2) (2 1)) sorted-perms '(1 2))
  (test '((1 2 3) (1 3 2) (2 1 3) (2 3 1) (3 1 2) (3 2 1))
        sorted-perms '(1 2 3))
  (define ll (range 7))
  (define pl (permutations ll))
  (test (* 1 2 3 4 5 6 7) length pl)
  (test (* 1 2 3 4 5 6 7) length (remove-duplicates pl))
  ;; check maximal sharing, and reverse-lexicographic order; these properties
  ;; are not documented guarantees (see comment in the implementation), but
  ;; it's worth testing for them to avoid losing them if they're needed in the
  ;; future.  (The above tests don't rely on this, it explicitly sorts the
  ;; result.)
  (test #t equal? (reverse (map reverse pl)) (sort pl perm<?))
  (test '((x y) (y x)) permutations '(x y))
  (test '((x x) (x x)) permutations '(x x))
  (test '((x y z) (y x z) (x z y) (z x y) (y z x) (z y x))
        permutations '(x y z))
  (test '((x y x) (y x x) (x x y) (x x y) (y x x) (x y x))
        permutations '(x y x))
  (define (count-cons x)
    (define t (make-hasheq))
    (let loop ([x x])
      (when (and (pair? x) (not (hash-ref t x #f)))
        (hash-set! t x #t) (loop (car x)) (loop (cdr x))))
    (hash-count t))
  (define (minimize-cons l)
    (let ([t (make-hash)])
      (let loop ([x l])
        (if (pair? x)
          (hash-ref! t x (λ() (cons (loop (car x)) (loop (cdr x)))))
          x))))
  (test #t = (count-cons pl) (count-cons (minimize-cons pl))))

;; ---------- argmin & argmax ----------

(let ()

  (define ((check-regs . regexps) exn)
    (and (exn:fail? exn)
         (andmap (λ (reg) (regexp-match reg (exn-message exn)))
                 regexps)))

  (test 'argmin object-name argmin)
  (test 1 argmin (lambda (x) 0) (list 1))
  (test 1 argmin (lambda (x) x) (list 1 2 3))
  (test 1 argmin (lambda (x) 1) (list 1 2 3))

  (test 3
        'argmin-makes-right-number-of-calls
        (let ([c 0])
          (argmin (lambda (x) (set! c (+ c 1)) 0)
                  (list 1 2 3))
          c))

  (test '(1 banana) argmin car '((3 pears) (1 banana) (2 apples)))

  (err/rt-test (argmin 1 (list 1)) (check-regs #rx"argmin" #rx"any/c . -> . real[?]"))
  (err/rt-test (argmin (lambda (x) x) 3) (check-regs #rx"argmin" #rx"list"))
  (err/rt-test (argmin (lambda (x) x) (list 1 #f)) (check-regs #rx"argmin" #rx"real"))
  (err/rt-test (argmin (lambda (x) x) (list #f)) (check-regs #rx"argmin" #rx"real"))

  (err/rt-test (argmin (lambda (x) x) (list +i)) (check-regs #rx"argmin" #rx"real"))
  (err/rt-test (argmin (lambda (x) x) (list)) (check-regs #rx"argmin" #rx".and/c list[?] .not/c empty[?].."))

  (test 'argmax object-name argmax)
  (test 1 argmax (lambda (x) 0) (list 1))
  (test 3 argmax (lambda (x) x) (list 1 2 3))
  (test 1 argmax (lambda (x) 1) (list 1 2 3))

  (test 3
        'argmax-makes-right-number-of-calls
        (let ([c 0])
          (argmax (lambda (x) (set! c (+ c 1)) 0)
                  (list 1 2 3))
          c))

  (test '(3 pears) argmax car '((3 pears) (1 banana) (2 apples)))

  (err/rt-test (argmax 1 (list 1)) (check-regs #rx"argmax" #rx"any/c . -> . real[?]"))
  (err/rt-test (argmax (lambda (x) x) 3) (check-regs #rx"argmax" #rx"list"))
  (err/rt-test (argmax (lambda (x) x) (list 1 #f)) (check-regs #rx"argmax" #rx"real"))
  (err/rt-test (argmax (lambda (x) x) (list #f)) (check-regs #rx"argmax" #rx"real"))

  (err/rt-test (argmax (lambda (x) x) (list +i)) (check-regs #rx"argmax" #rx"real?"))
  (err/rt-test (argmax (lambda (x) x) (list)) (check-regs #rx"argmax" #rx".and/c list[?] .not/c empty[?]..")))

;; ---------- range ----------

(let ()
  (test '(0 1 2 3) range 4)
  (test '() range 0)
  (test '(0 1 2 3 4 5 6 7) range 8)
  (test '() range 3 2)
  (test '(3) range 3 2 -1)
  (test '(3 4 5 6 7 8) range 3 9)
  (test '(3 5 7) range 3 9 2)
  (test '(3 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5) range 3 9 0.5)
  (test '(9 7 5) range 9 3 -2)
  (test '(0 1 2 3 4 5 6 7 8 9) range 10)
  (test '(10 11 12 13 14 15 16 17 18 19) range 10 20)
  (test '(20 22 24 26 28 30 32 34 36 38) range 20 40 2)
  (test '(20 19 18 17 16 15 14 13 12 11) range 20 10 -1)
  (test '(10 11.5 13.0 14.5) range 10 15 1.5))

;; ---------- inclusive-range ----------

(let ()
  (test '() inclusive-range 3 2)
  (test '(3) inclusive-range 3 3)
  (test '(3 2) inclusive-range 3 2 -1)
  (test '(3 4 5 6 7 8 9) inclusive-range 3 9)
  (test '(3 5 7 9) inclusive-range 3 9 2)
  (test '(3 5 7) inclusive-range 3 8 2)
  (test '(3 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0) inclusive-range 3 9 0.5)
  (test '(9 7 5 3) inclusive-range 9 3 -2)
  (test '(10 11 12 13 14 15 16 17 18 19 20) inclusive-range 10 20)
  (test '(20 22 24 26 28 30 32 34 36 38 40) inclusive-range 20 40 2)
  (test '(20 19 18 17 16 15 14 13 12 11 10) inclusive-range 20 10 -1)
  (test '(10 11.5 13.0 14.5) inclusive-range 10 15 1.5))

;; ---------- group-by ----------

(test '((1) (4) (2 2) (56) (3)) group-by values '(1 4 2 56 2 3))
(test '((1 1 1) (2 2 2 2 2) (54) (5) (43) (7) (643) (0))
      group-by values '(1 2 1 2 54 2 5 43 7 2 643 1 2 0))
(test '((1 3) (4 2 56 2))
      group-by values '(1 4 2 56 2 3) (lambda (x y) (or (and (even? x) (even? y))
                                                        (and (odd?  x) (odd?  y)))))
(test '(((1 a)) ((4 b)) ((2 c) (2 e)) ((56 d)) ((3 f)))
      group-by car '((1 a) (4 b) (2 c) (56 d) (2 e) (3 f)))
(test '((1 3 5) (2 4 6)) group-by even? '(1 2 3 4 5 6))
(err/rt-test (group-by #f))
(err/rt-test (group-by '() #f))
(err/rt-test (group-by '() values #f))

;; ---------- cartesian-product ----------

(test '((1 a) (1 b) (1 c)
        (2 a) (2 b) (2 c)
        (3 a) (3 b) (3 c))
      cartesian-product '(1 2 3) '(a b c))
(test '((4 d #t) (4 d #f) (4 e #t) (4 e #f) (4 f #t) (4 f #f)
        (5 d #t) (5 d #f) (5 e #t) (5 e #f) (5 f #t) (5 f #f)
        (6 d #t) (6 d #f) (6 e #t) (6 e #f) (6 f #t) (6 f #f))
      cartesian-product '(4 5 6) '(d e f) '(#t #f))
(err/rt-test (cartesian-product 3))

;; ---------- list-update ----------

(test '("zero" one two) list-update '(zero one two) 0 symbol->string)
(test '(zero "one" two) list-update '(zero one two) 1 symbol->string)
(err/rt-test (list-update '(zero one two) 3 symbol->string))
(err/rt-test (list-update '(zero one two) -1 symbol->string))
(err/rt-test (list-update '(zero one two) #f symbol->string))
(err/rt-test (list-update #f 0 symbol->string))
(err/rt-test (list-update '(zero one two) 0 #f))

;; ---------- list-update* ----------
(test '(0 2 1) list-update* '(0 1 2) 2 sub1 1 add1)
(test '(0 2 1) list-update* '(0 1 2) 1 add1 2 sub1)
(test '(0 2 2) list-update* '(0 1 2) 1 add1 1 add1)
(err/rt-test (list-update* '(0 1 2) 0 sub1 3 add1))
(err/rt-test (list-update* '(zero one two) 3 symbol->string))
(err/rt-test (list-update* '(zero one two) 1 symbol->string -1 symbol->string))
(err/rt-test (list-update* '(zero one two) #f symbol->string))
(err/rt-test (list-update* #f 0 symbol->string))
(err/rt-test (list-update* '(zero one two) 0 #f))

;; ---------- list-set ----------

(test '(zero one "two") list-set '(zero one two) 2 "two")
(err/rt-test (list-set '(zero one two) 3 "two"))
(err/rt-test (list-set '(zero one two) -1 "two"))
(err/rt-test (list-set '(zero one two) #f "two"))

;; ---------- list-set* ----------

(test '(3 4 2) list-set* '(0 1 2) 0 3 1 4)
(test '(3 4 2) list-set* '(0 1 2) 1 4 0 3)
(test '(4 1 2) list-set* '(0 1 2) 0 3 0 4)
(test '("zero" one "two") list-set* '(zero one two) 2 "two" 0 "zero")
(err/rt-test (list-set* '(zero one two) 1 "one" 0 "zero" #f "false"))
(err/rt-test (list-set* '(zero one two) 3 "two"))
(err/rt-test (list-set* '(zero one two) -1 "two"))
(err/rt-test (list-set* '(zero one two) #f "two"))

;; ---------- list prefix functions ----------

(test #t list-prefix? '(1 2) '(1 2 3 4 5))
(test #f list-prefix? '(2 1) '(1 2 3 4 5))
(test #t list-prefix? '(1 2) '(1 2 3 4 5) =)
(test #f list-prefix? '(2 1) '(1 2 3 4 5) =)
(err/rt-test (list-prefix? #t '()))
(err/rt-test (list-prefix? '() #t))
(test '(a b) take-common-prefix '(a b c d) '(a b x y z))
(test '() take-common-prefix '(1 a b c d) '(a b x y z))
(test '(a b c d) take-common-prefix '(a b c d) '(a b c d))
(test '(1 2) take-common-prefix '(1 2 3 4) '(1 2 4 3) =)
(err/rt-test (take-common-prefix '() '() #f))
(define (drop*-list xs ys [=? equal?])
  (define-values (a b)
    (drop-common-prefix xs ys =?))
  (list a b))
(test '((c d) (x y z)) drop*-list '(a b c d) '(a b x y z))
(test '((1 a b c d) (a b x y z)) drop*-list '(1 a b c d) '(a b x y z))
(test '(() ()) drop*-list '(a b c d) '(a b c d))
(test '((3 4) (4 3)) drop*-list '(1 2 3 4) '(1 2 4 3) =)
(err/rt-test (drop*-list '() '() #f))
(define (split*-list xs ys [=? equal?])
  (define-values (a b c)
    (split-common-prefix xs ys =?))
  (list a b c))
(test '((a b) (c d) (x y z)) split*-list '(a b c d) '(a b x y z))
(test '(() (1 a b c d) (a b x y z)) split*-list '(1 a b c d) '(a b x y z))
(test '((a b c d) () ()) split*-list '(a b c d) '(a b c d))
(test '((1 2) (3 4) (4 3)) split*-list '(1 2 3 4) '(1 2 4 3) =)
(err/rt-test (split*-list '() '() #f))
(err/rt-test (take-common-prefix 1 1))

;; ---------- remove / remove* ----------
(test '() remove 2 '())
(test '(1 3 2 4) remove 2 '(1 2 3 2 4))
(test '((1) (3)) remove '(2) '((1) (2) (3)))
(test '("1" "3") remove "2" '("1" "2" "3"))
(test '(#\a #\b) remove #\c '(#\a #\b #\c))
(test '("a" "A" "B") remove "B" '("a" "A" "b" "B") string-ci=?)
(test '(1 2 3 2 4) remove 5 '(1 2 3 2 4))
(let ([xs '(1 2 3 2 4)])
  (test #t eq? xs (remove 5 xs)))

(test '() remove* '(2) '())
(test '(1 3 4) remove* '(2) '(1 2 3 2 4))
(test '(1 3) remove* '(4 2) '(1 2 3 2 4))
(test '(1 2 3 2 4) remove* '() '(1 2 3 2 4))
(let ([xs '(1 2 3 2 4)])
  (test #t eq? xs (remove* '() xs)))

;; ---------- remf / remf* ----------

(test '() remf positive? '())
(test '(-2 3 4 -5) remf positive? '(1 -2 3 4 -5))
(test '(1 3 4 -5) remf even? '(1 -2 3 4 -5))
(test '(1 -2 3 4 -5) remf (λ (x) #f) '(1 -2 3 4 -5))
(test '() remf* positive? '())
(test '(-2 -5) remf* positive? '(1 -2 3 4 -5))
(test '(1 3 -5) remf* even? '(1 -2 3 4 -5))
(test '(1 -2 3 4 -5) remf* (λ (x) #f) '(1 -2 3 4 -5))

;; ---------- index(es)-of / index(es)-where ----------

(test #f index-of '() 'a)
(test #f index-of '(a b) 'c)
(test 0 index-of '(a b c) 'a)
(test 1 index-of '(a b c) 'b)
(test 0 index-of (list #'a #'b #'c) #'a free-identifier=?)
(test 1 index-of (list #'a #'b #'c) #'b free-identifier=?)

(test #f index-where '() even?)
(test #f index-where '(1 3 5) even?)
(test 0 index-where '(1 2 3 4 5) odd?)
(test 1 index-where '(1 2 3 4 5) even?)

(test '() indexes-of '() 'a)
(test '() indexes-of '(a b) 'c)
(test '(0) indexes-of '(a b c) 'a)
(test '(1) indexes-of '(a b c) 'b)
(test '(0 1) indexes-of '(a a b) 'a)
(test '(1 2) indexes-of '(a b b) 'b)
(test '(0 1 2) indexes-of '(a a a) 'a)
(test '(0 1) indexes-of (list #'a #'a #'b) #'a free-identifier=?)
(test '(1 2) indexes-of (list #'a #'b #'b) #'b free-identifier=?)

(test '() indexes-where '() even?)
(test '() indexes-where '(1 3 5) even?)
(test '(1 3) indexes-where '(1 2 3 4 5) even?)
(test '(0 2 4) indexes-where '(1 2 3 4 5) odd?)

(report-errs)
