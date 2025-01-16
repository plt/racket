#lang racket/base

(provide first second third fourth fifth sixth seventh eighth ninth tenth eleventh twelfth thirteenth fourteenth fifteenth

         last-pair last rest

         cons?
         empty
         empty?

         make-list

         list-update
         list-set

         index-of
         index-where
         indexes-of
         indexes-where

         drop
         take
         split-at
         takef
         dropf
         splitf-at
         drop-right
         take-right
         split-at-right
         takef-right
         dropf-right
         splitf-at-right

         list-prefix?
         split-common-prefix
         take-common-prefix
         drop-common-prefix

         append*
         flatten
         add-between
         remove-duplicates
         check-duplicates
         filter-map
         count
         partition

         ;; convenience
         range
         inclusive-range
         append-map
         filter-not
         shuffle
         combinations
         in-combinations
         permutations
         in-permutations
         argmin
         argmax
         group-by
         cartesian-product
         remf
         remf*

         ;; for loops
         for/append-list
         for/append-lists
         for*/append-list
         for*/append-lists)

(require (for-syntax racket/base)
         racket/private/list-predicates
         racket/private/for-append-list)

(define (first x)
  (if (and (pair? x) (list? x))
    (car x)
    (raise-argument-error 'first "(and/c list? (not/c empty?))" x)))

(define-syntax define-lgetter
  (syntax-rules ()
    [(_ name npos)
     (define (name l0)
       (if (list? l0)
         (let loop ([l l0] [pos npos])
           (if (pair? l)
             (if (eq? pos 1) (car l) (loop (cdr l) (sub1 pos)))
             (raise-arguments-error 'name
                                    "list contains too few elements"
                                    "list" l0)))
         (raise-argument-error 'name "list?" l0)))]))
(define-lgetter second      2)
(define-lgetter third       3)
(define-lgetter fourth      4)
(define-lgetter fifth       5)
(define-lgetter sixth       6)
(define-lgetter seventh     7)
(define-lgetter eighth      8)
(define-lgetter ninth       9)
(define-lgetter tenth      10)
(define-lgetter eleventh   11)
(define-lgetter twelfth    12)
(define-lgetter thirteenth 13)
(define-lgetter fourteenth 14)
(define-lgetter fifteenth  15)

(define (last-pair l)
  (if (pair? l)
    (let loop ([l l] [x (cdr l)])
      (if (pair? x)
        (loop x (cdr x))
        l))
    (raise-argument-error 'last-pair "pair?" l)))

(define (last l)
  (if (and (pair? l) (list? l))
    (let loop ([l l] [x (cdr l)])
      (if (pair? x)
        (loop x (cdr x))
        (car l)))
    (raise-argument-error 'last "(and/c list? (not/c empty?))" l)))

(define (rest l)
  (if (and (pair? l) (list? l))
    (cdr l)
    (raise-argument-error 'rest "(and/c list? (not/c empty?))" l)))

(define empty '())

(define (make-list n x)
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error 'make-list "exact-nonnegative-integer?" 0 n x))
  (let loop ([n n] [r '()])
    (if (zero? n) r (loop (sub1 n) (cons x r)))))

(define (list-update l i f)
  (unless (list? l)
    (raise-argument-error 'list-update "list?" 0 l i f))
  (unless (exact-nonnegative-integer? i)
    (raise-argument-error 'list-update "exact-nonnegative-integer?" 1 l i f))
  (unless (and (procedure? f)
               (procedure-arity-includes? f 1))
    (raise-argument-error 'list-update "(-> any/c any/c)" 2 l i f))
  (cond
   [(zero? i) (cons (f (car l)) (cdr l))]
   [else (cons (car l) (list-update (cdr l) (sub1 i) f))]))

(define (list-set l k v)
  (unless (list? l)
    (raise-argument-error 'list-set "list?" 0 l k v))
  (unless (exact-nonnegative-integer? k)
    (raise-argument-error 'list-set "exact-nonnegative-integer?" 1 l k v))
  (list-update l k (lambda (_) v)))

;; internal use below
(define (drop* list n) ; no error checking, returns #f if index is too large
  (if (zero? n) list (and (pair? list) (drop* (cdr list) (sub1 n)))))
(define (too-large who list n)
  (define proper? (list? list))
  (raise-argument-error who
                        (format "a ~alist with at least ~a ~a"
                                (if proper? "" "(possibly improper) ")
                                n
                                (if proper? "elements" "pairs"))
                        list))

(define (take list0 n0)
  (unless (exact-nonnegative-integer? n0)
    (raise-argument-error 'take "exact-nonnegative-integer?" 1 list0 n0))
  (let loop ([list list0] [n n0])
    (cond [(zero? n) '()]
          [(pair? list) (cons (car list) (loop (cdr list) (sub1 n)))]
          [else (too-large 'take list0 n0)])))

(define (drop list n)
  ;; could be defined as `list-tail', but this is better for errors anyway
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error 'drop "exact-nonnegative-integer?" 1 list n))
  (or (drop* list n) (too-large 'drop list n)))

(define (split-at list0 n0)
  (unless (exact-nonnegative-integer? n0)
    (raise-argument-error 'split-at "exact-nonnegative-integer?" 1 list0 n0))
  (let loop ([list list0] [n n0] [pfx '()])
    (cond [(zero? n) (values (reverse pfx) list)]
          [(pair? list) (loop (cdr list) (sub1 n) (cons (car list) pfx))]
          [else (too-large 'split-at list0 n0)])))

(define (takef list pred)
  (unless (procedure? pred)
    (raise-argument-error 'takef "procedure?" 1 list pred))
  (let loop ([list list])
    (if (pair? list)
      (let ([x (car list)])
        (if (pred x)
          (cons x (loop (cdr list)))
          '()))
      ;; could return `list' here, but make it behave like `take'
      ;; example: (takef '(a b c . d) symbol?) should be similar
      ;; to (take '(a b c . d) 3)
      '())))

(define (dropf list pred)
  (unless (procedure? pred)
    (raise-argument-error 'dropf "procedure?" 1 list pred))
  (let loop ([list list])
    (if (and (pair? list) (pred (car list)))
      (loop (cdr list))
      list)))

(define (splitf-at list pred)
  (unless (procedure? pred)
    (raise-argument-error 'splitf-at "procedure?" 1 list pred))
  (let loop ([list list] [pfx '()])
    (if (and (pair? list) (pred (car list)))
      (loop (cdr list) (cons (car list) pfx))
      (values (reverse pfx) list))))

;; take/drop-right are originally from srfi-1, uses the same lead-pointer trick

(define (take-right list n)
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error 'take-right "exact-nonnegative-integer?" 1 list n))
  (let loop ([list list]
             [lead (or (drop* list n) (too-large 'take-right list n))])
    ;; could throw an error for non-lists, but be more like `take'
    (if (pair? lead)
      (loop (cdr list) (cdr lead))
      list)))

(define (drop-right list n)
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error 'drop-right "exact-nonnegative-integer?" 1 list n))
  (let loop ([list list]
             [lead (or (drop* list n) (too-large 'drop-right list n))])
    ;; could throw an error for non-lists, but be more like `drop'
    (if (pair? lead)
      (cons (car list) (loop (cdr list) (cdr lead)))
      '())))

(define (split-at-right list n)
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error 'split-at-right "exact-nonnegative-integer?" 1 list n))
  (let loop ([list list]
             [lead (or (drop* list n) (too-large 'split-at-right list n))]
             [pfx '()])
    ;; could throw an error for non-lists, but be more like `split-at'
    (if (pair? lead)
      (loop (cdr list) (cdr lead) (cons (car list) pfx))
      (values (reverse pfx) list))))

;; For just `takef-right', it's possible to do something smart that
;; scans the list in order, keeping a pointer to the beginning of the
;; "current good block".  This avoids a double scan *but* the payment is
;; in applying the predicate on all emlements.  There might be a point
;; in that in some cases, but probably in most cases it's best to apply
;; it in reverse order, get the index, then do the usual thing -- in
;; many cases applying the predicate on all items could be more
;; expensive than the allocation needed for reverse.
;;
;; That's mildly useful in a completely unexciting way, but when it gets
;; to the other *f-right functions, it gets worse in that the first
;; approach won't work, so there's not much else to do than the second
;; one -- reverse the list, look for the place where the predicate flips
;; to #f, then use the non-f from-right functions above to do the work.

(define (count-from-right who list pred)
  (unless (procedure? pred)
    (raise-argument-error who "procedure?" 1 list pred))
  (let loop ([list list] [rev '()] [n 0])
    (if (pair? list)
      (loop (cdr list) (cons (car list) rev) (add1 n))
      (let loop ([n n] [list rev])
        (if (and (pair? list) (pred (car list)))
          (loop (sub1 n) (cdr list))
          n)))))

(define (takef-right list pred)
  (drop list (count-from-right 'takef-right list pred)))
(define (dropf-right list pred)
  (take list (count-from-right 'dropf-right list pred)))
(define (splitf-at-right list pred)
  (split-at list (count-from-right 'splitf-at-right list pred)))

; list-prefix? : list? list? -> boolean?
; Is ls a prefix of rs?
(define (list-prefix? ls rs [same? equal?])
  (unless (list? ls)
    (raise-argument-error 'list-prefix? "list?" 0 ls rs))
  (unless (list? rs)
    (raise-argument-error 'list-prefix? "list?" 1 ls rs))
  (unless (and (procedure? same?)
               (procedure-arity-includes? same? 2))
    (raise-argument-error 'list-prefix? "(any/c any/c . -> . any/c)" 2 ls rs same?))
  (let loop ((ls ls) (rs rs))
    (or (null? ls)
        (and (pair? rs)
             (same? (car ls) (car rs))
             (loop (cdr ls) (cdr rs))))))

;; Eli: How about a version that removes the equal prefix from two lists
;; and returns the tails -- this way you can tell if they're equal, or
;; one is a prefix of the other, or if there was any equal prefix at
;; all.  (Which can be useful for things like making a path relative to
;; another path.)  A nice generalization is to make it get two or more
;; lists, and return a matching number of values.

(define (internal-split-common-prefix as bs same? keep-prefix? name)
  (unless (list? as)
    (raise-argument-error name "list?" 0 as bs))
  (unless (list? bs)
    (raise-argument-error name "list?" 1 as bs))
  (unless (and (procedure? same?)
               (procedure-arity-includes? same? 2))
    (raise-argument-error name "(any/c any/c . -> . any/c)" 2 as bs same?))
  (let loop ([as as] [bs bs])
    (if (and (pair? as) (pair? bs) (same? (car as) (car bs)))
        (let-values ([(prefix atail btail) (loop (cdr as) (cdr bs))])
          (values (and keep-prefix? (cons (car as) prefix)) atail btail))
        (values null as bs))))

(define (split-common-prefix as bs [same? equal?])
  (internal-split-common-prefix as bs same? #t 'split-common-prefix))

(define (take-common-prefix as bs [same? equal?])
  (let-values ([(prefix atail btail)
                (internal-split-common-prefix as bs same? #t 'take-common-prefix)])
    prefix))

(define (drop-common-prefix as bs [same? equal?])
  (let-values ([(prefix atail btail)
                (internal-split-common-prefix as bs same? #f 'drop-common-prefix)])
    (values atail btail)))

(define append*
  (case-lambda [(ls) (apply append ls)] ; optimize common case
               [(l1 l2) (apply append l1 l2)]
               [(l1 l2 l3) (apply append l1 l2 l3)]
               [(l1 l2 l3 l4) (apply append l1 l2 l3 l4)]
               [(l . lss) (apply apply append l lss)]))

(define (flatten orig-sexp)
  (let loop ([sexp orig-sexp] [acc null])
    (cond [(null? sexp) acc]
          [(pair? sexp) (loop (car sexp) (loop (cdr sexp) acc))]
          [else (cons sexp acc)])))

;; General note: many non-tail recursive, which are just as fast in racket

(define (add-between l x
                     #:splice? [splice? #f]
                     #:before-first [before-first '()]
                     #:before-last [before-last x]
                     #:after-last [after-last '()])
  (unless (list? l)
    (raise-argument-error 'add-between "list?" 0 l x))
  (cond
    [splice?
     (define (check-list x which)
       (unless (list? x)
         (raise-arguments-error
          'add-between
          (string-append "list needed in splicing mode" which)
          "given" x
          "given list..." l)))
     (check-list x "")
     (check-list before-first " for #:before-first")
     (check-list before-last  " for #:before-last")
     (check-list after-last   " for #:after-last")]
    [else
     (define (check-not-given x which)
       (unless (eq? '() x)
         (raise-arguments-error
          'add-between
          (string-append which " can only be used in splicing mode")
          "given" x
          "given list..." l)))
     (check-not-given before-first "#:before-first")
     (check-not-given after-last   "#:after-last")])
  (cond
    [(or (null? l) (null? (cdr l)))
     (if splice? (append before-first l after-last) l)]
    ;; two cases for efficiency, maybe not needed
    [splice?
     (let* ([x (reverse x)]
            ;; main loop
            [r (let loop ([i (cadr l)] [l (cddr l)] [r '()])
                 (if (pair? l)
                   (loop (car l) (cdr l) (cons i (append x r)))
                   (cons i (append (reverse before-last) r))))]
            ;; add `after-last' & reverse
            [r (reverse (append (reverse after-last) r))]
            ;; add first item and `before-first'
            [r `(,@before-first ,(car l) ,@r)])
       r)]
    [else
     (cons (car l)
           (reverse (let loop ([i (cadr l)] [l (cddr l)] [r '()]) ; main loop
                      (if (pair? l)
                        (loop (car l) (cdr l) (cons i (cons x r)))
                        (cons i (cons before-last r))))))]))

(define (remove-duplicates l [=? equal?] #:key [key #f])
  ;; `no-key' is used to optimize the case for long lists, it could be done for
  ;; shorter ones too, but that adds a ton of code to the result (about 2k).
  (define-syntax-rule (no-key x) x)
  (unless (list? l) (raise-argument-error 'remove-duplicates "list?" l))
  (let* ([len (length l)]
         [h (cond [(<= len 1) #t]
                  [(<= len 40) #f]
                  [(eq? =? eq?) (make-hasheq)]
                  [(eq? =? equal?) (make-hash)]
                  [(eq? =? equal-always?) (make-hashalw)]
                  [else #f])])
    (case h
      [(#t) l]
      [(#f)
       ;; plain n^2 list traversal (optimized for common cases) for short lists
       ;; and for equalities other than `eq?' or `equal?'  The length threshold
       ;; above (40) was determined by trying it out with lists of length n
       ;; holding (random n) numbers.
       (let ([key (or key (λ (x) x))])
         (let-syntax ([loop (syntax-rules ()
                              [(_ search)
                               (let loop ([l l] [seen null])
                                 (if (null? l)
                                   l
                                   (let* ([x (car l)] [k (key x)] [l (cdr l)])
                                     (if (search k seen)
                                       (loop l seen)
                                       (cons x (loop l (cons k seen)))))))])])
           (cond [(eq? =? equal?) (loop member)]
                 [(eq? =? eq?)    (loop memq)]
                 [(eq? =? eqv?)   (loop memv)]
                 [(eq? =? equal-always?) (loop memw)]
                 [else (loop (λ(x seen) (ormap (λ(y) (=? x y)) seen)))])))]
      [else
       ;; Use a hash for long lists with simple hash tables.
       (let-syntax ([loop
                     (syntax-rules ()
                       [(_ getkey)
                        (let loop ([l l])
                          (if (null? l)
                            l
                            (let* ([x (car l)] [k (getkey x)] [l (cdr l)])
                              (if (hash-ref h k #f)
                                (loop l)
                                (begin (hash-set! h k #t)
                                       (cons x (loop l)))))))])])
         (if key (loop key) (loop no-key)))])))

;; check-duplicates : (listof X)
;;                    [(K K -> bool)]
;;                    #:key (X -> K)
;;                -> X or #f
(define (check-duplicates items
                          [same? equal?]
                          #:key [key values]
                          #:default [failure-result (λ () #f)])
  (unless (list? items)
    (raise-argument-error 'check-duplicates "list?" 0 items))
  (unless (and (procedure? key)
               (procedure-arity-includes? key 1))
    (raise-argument-error 'check-duplicates "(-> any/c any/c)" key))
  (let ([fail-k (if (procedure? failure-result) failure-result (λ () failure-result))])
    (cond [(eq? same? equal?)
           (check-duplicates/t items key (make-hash) fail-k)]
          [(eq? same? eq?)
           (check-duplicates/t items key (make-hasheq) fail-k)]
          [(eq? same? eqv?)
           (check-duplicates/t items key (make-hasheqv) fail-k)]
          [(eq? same? equal-always?)
           (check-duplicates/t items key (make-hashalw) fail-k)]
          [else
           (unless (and (procedure? same?)
                        (procedure-arity-includes? same? 2))
             (raise-argument-error 'check-duplicates
                                   "(any/c any/c . -> . any/c)"
                                   1 items same?))
           (check-duplicates/list items key same? fail-k)])))
(define (check-duplicates/t items key table fail-k)
  (let loop ([items items])
    (if (pair? items)
        (let ([key-item (key (car items))])
          (if (hash-ref table key-item #f)
               (car items)
               (begin (hash-set! table key-item #t)
                      (loop (cdr items)))))
        (fail-k))))
(define (check-duplicates/list items key same? fail-k)
  (let loop ([items items] [sofar null])
    (if (pair? items)
        (let ([key-item (key (car items))])
          (if (for/or ([prev (in-list sofar)])
                 (same? key-item prev))
               (car items)
               (loop (cdr items) (cons key-item sofar))))
        (fail-k))))

;; Eli: Just to have a record of this: my complaint about having this
;; code separately from `remove-duplicates' still stands.  Specifically,
;; that function decides when to use a hash table to make things faster,
;; and this code would benefit from the same.  It would be much better
;; to extend that function so it can be used for both tasks rather than
;; a new piece of code that does it (only do it in a worse way, re
;; performance).  Doing this can also benefit `remove-duplicates' -- for
;; example, make it accept a container so that users can choose how
;; when/if to use a hash table.


(define (check-filter-arguments who f l ls)
  (unless (procedure? f)
    (apply raise-argument-error who "procedure?" 0 f l ls))
  (unless (procedure-arity-includes? f (add1 (length ls)))
    (raise-arguments-error
     who "mismatch between procedure arity and argument count"
     "procedure" f
     "expected arity" (add1 (length ls))))
  (unless (and (list? l) (andmap list? ls))
    (for ([(x i) (in-indexed (cons l ls))])
      (unless (list? x)
        (apply raise-argument-error who "list?" (add1 i) f l ls)))))

(define (filter-map f l . ls)
  (check-filter-arguments 'filter-map f l ls)
  (if (pair? ls)
    (let ([len (length l)])
      (if (andmap (λ(l) (= len (length l))) ls)
        (let loop ([l l] [ls ls])
          (if (null? l)
            null
            (let ([x (apply f (car l) (map car ls))])
              (if x
                (cons x (loop (cdr l) (map cdr ls)))
                (loop (cdr l) (map cdr ls))))))
        (raise-arguments-error 'filter-map "all lists must have same size")))
    (let loop ([l l])
      (if (null? l)
        null
        (let ([x (f (car l))])
          (if x (cons x (loop (cdr l))) (loop (cdr l))))))))

;; very similar to `filter-map', one more such function will justify some macro
(define (count f l . ls)
  (check-filter-arguments 'count f l ls)
  (if (pair? ls)
    (let ([len (length l)])
      (if (andmap (λ(l) (= len (length l))) ls)
        (let loop ([l l] [ls ls] [c 0])
          (if (null? l)
            c
            (loop (cdr l) (map cdr ls)
                  (if (apply f (car l) (map car ls)) (add1 c) c))))
        (raise-arguments-error 'count "all lists must have same size")))
    (let loop ([l l] [c 0])
      (if (null? l) c (loop (cdr l) (if (f (car l)) (add1 c) c))))))

;; Originally from srfi-1 -- shares common tail with the input when possible
;; (define (partition f l)
;;   (unless (and (procedure? f) (procedure-arity-includes? f 1))
;;     (raise-argument-error 'partition "procedure (arity 1)" f))
;;   (unless (list? l) (raise-argument-error 'partition "proper list" l))
;;   (let loop ([l l])
;;     (if (null? l)
;;       (values null null)
;;       (let* ([x (car l)] [x? (f x)])
;;         (let-values ([(in out) (loop (cdr l))])
;;           (if x?
;;             (values (if (pair? out) (cons x in) l) out)
;;             (values in (if (pair? in) (cons x out) l))))))))

;; But that one is slower than this, probably due to value packaging
(define (partition pred l)
  (unless (and (procedure? pred) (procedure-arity-includes? pred 1))
    (raise-argument-error 'partition "(any/c . -> . any/c)" 0 pred l))
  (unless (list? l) (raise-argument-error 'partition "list?" 1 pred l))
  (let loop ([l l] [i '()] [o '()])
    (if (null? l)
      (values (reverse i) (reverse o))
      (let ([x (car l)] [l (cdr l)])
        (if (pred x) (loop l (cons x i) o) (loop l i (cons x o)))))))

;; similar to in-range, but returns a list
(define range-proc
  (let ()
    ; make sure range has the right runtime name
    (define range
      (case-lambda
        [(end)            (for/list ([i (in-range end)])            i)]
        [(start end)      (for/list ([i (in-range start end)])      i)]
        [(start end step) (for/list ([i (in-range start end step)]) i)]))
    range))

(define inclusive-range-proc
  (let ()
    ; make sure range has the right runtime name
    (define inclusive-range
      (case-lambda
        [(start end)      (for/list ([i (in-inclusive-range start end)])      i)]
        [(start end step) (for/list ([i (in-inclusive-range start end step)]) i)]))
    inclusive-range))

(define-sequence-syntax range
  (λ () #'range-proc)
  (λ (stx)
    (syntax-case stx ()
      [[(n) (_ end)]            #'[(n) (in-range end)]]
      [[(n) (_ start end)]      #'[(n) (in-range start end)]]
      [[(n) (_ start end step)] #'[(n) (in-range start end step)]]
      [[ids range-expr]         #'[ids (#%expression range-expr)]])))

(define-sequence-syntax inclusive-range
  (λ () #'inclusive-range-proc)
  (λ (stx)
    (syntax-case stx ()
      [[(n) (_ start end)]      #'[(n) (in-inclusive-range start end)]]
      [[(n) (_ start end step)] #'[(n) (in-inclusive-range start end step)]]
      [[ids range-expr]         #'[ids (#%expression range-expr)]])))

(define append-map
  (case-lambda [(f l)      (apply append (map f l))]
               [(f l1 l2)  (apply append (map f l1 l2))]
               [(f l . ls) (apply append (apply map f l ls))]))

;; this is an exact copy of `filter' in racket/private/list, with the
;; `if' branches swapped.
(define (filter-not f list)
  (unless (and (procedure? f)
               (procedure-arity-includes? f 1))
    (raise-argument-error 'filter-not "(any/c . -> . any/c)" 0 f list))
  (unless (list? list)
    (raise-argument-error 'filter-not "list?" 1 f list))
  ;; accumulating the result and reversing it is currently slightly
  ;; faster than a plain loop
  (let loop ([l list] [result null])
    (if (null? l)
      (reverse result)
      (loop (cdr l) (if (f (car l)) result (cons (car l) result))))))

;; Fisher-Yates Shuffle
(define (shuffle l)
  (unless (list? l) (raise-argument-error 'shuffle "list?" 0 l))
  (define a (make-vector (length l)))
  (for ([x (in-list l)] [i (in-naturals)])
    (define j (random (add1 i)))
    (unless (= j i) (vector-set! a i (vector-ref a j)))
    (vector-set! a j x))
  (vector->list a))

(define (combinations l [k #f])
  (for/list ([x (in-combinations l k)]) x))

;; Generate combinations of the list `l`.
;; - If `k` is a natural number, generate all combinations of size `k`.
;; - If `k` is #f, generate all combinations of any size (powerset of `l`).
(define (in-combinations l [k #f])
  (unless (list? l)
    (raise-argument-error 'in-combinations "list?" 0 l))
  (when (and k (not (exact-nonnegative-integer? k)))
    (raise-argument-error 'in-combinations "exact-nonnegative-integer?" 1 l k))
  (define v (list->vector l))
  (define N (vector-length v))
  (define N-1 (- N 1))
  (define gen-combinations
    (cond
      [(not k)
       ;; Enumerate all binary numbers [1..2**N].
       ;; Produce the combination with elements in `v` at the same
       ;;  positions as the 1's in the binary number.
       (define limit (expt 2 N))
       (define curr-box (box 0))
       (lambda ()
         (let ([curr (unbox curr-box)])
           (if (< curr limit)
             (begin0
               (for/fold ([acc '()])
                         ([i (in-range N-1 -1 -1)])
                 (if (bitwise-bit-set? curr i)
                   (cons (vector-ref v i) acc)
                   acc))
               (set-box! curr-box (+ curr 1)))
             #f)))]
      [(< N k)
       (lambda () #f)]
      [else
       (define running? #t)
       ;; Keep a vector `k*` that contains `k` indices
       ;; Use `k*` to generate combinations
       ;;
       ;; Initialize the vector `k*` to the first {0..k-1} indices
       (define k* (build-vector k (lambda (i) i))) ; (Vectorof Index)
       (define k-1 (- k 1))

       ;; the generator produces a result and tries to increment
       ;; positions in `k*`.
       (λ ()
         (cond
           [running?
            (begin0 (for/list ([i (in-vector k*)]) (vector-ref v i))
              (let ([index-to-change #f])
                ;; Find a rightmost index that could be incremented.
                ;; E.g., if N = 10 and we have #(3 4 8 9),
                ;; the element 4 is incrementable
                (for ([i (in-range k-1 -1 -1)])
                  #:break
                  (and (not (eq? (vector-ref k* i) (+ i N (- k))))
                       (begin (set! index-to-change i) #t))
                  (void))
                (cond
                  ;; If there is an incrementable index, increase it by one
                  ;; and reset all elements after the incrementable index
                  ;; E.g., if N = 10 and we have #(3 4 8 9)
                  ;; then we change it to #(3 5 6 7)
                  [index-to-change
                   (define val-to-change (add1 (vector-ref k* index-to-change)))
                   (for ([i (in-range index-to-change k)]
                         [v (in-naturals val-to-change)])
                     (vector-set! k* i v))]
                  ;; Otherwise, there's no incrementable index. E.g.,
                  ;; N = 10 and we have #(6 7 8 9), so we quit enumeration
                  [else (set! running? #f)])))]
           [else #f]))]))

      (in-producer gen-combinations #f))

;; This implements an algorithm known as "Ord-Smith".  (It is described in a
;; paper called "Permutation Generation Methods" by Robert Sedgewick, listed as
;; Algorithm 8.)  It has a number of good properties: it is very fast, returns
;; a list of results that has a maximum number of shared list tails, and it
;; returns a list of reverses of permutations in lexical order of the input,
;; except that the list itself is reversed so the first permutation is equal to
;; the input and the last is its reverse.  In other words, (map reverse
;; (permutations (reverse l))) is a list of lexicographically-ordered
;; permutations (but of course has no shared tails at all -- I couldn't find
;; anything that returns sorted results with shared tails efficiently).  I'm
;; not listing these features in the documentation, since I'm not sure that
;; there is a need to expose them as guarantees -- but if there is, then just
;; revise the docs.  (Note that they are tested.)
;;
;; In addition to all of this, it has just one loop, so it is easy to turn it
;; into a "streaming" version that spits out the permutations one-by-one, which
;; could be used with a "callback" argument as in the paper, or can implement
;; an efficient `in-permutations'.  It uses a vector to hold state -- it's easy
;; to avoid this and use a list instead (in the loop, the part of the c vector
;; that is before i is all zeros, so just use a list of the c values from i and
;; on) -- but that makes it slower (by about 70% in my timings).
(define (swap+flip l i j)
  ;; this is the main helper for the code: swaps the i-th and j-th items, then
  ;; reverses items 0 to j-1; with special cases for 0,1,2 (which are
  ;; exponentially more frequent than others)
  (case j
    [(0) `(,(cadr l) ,(car l) ,@(cddr l))]
    [(1) (let ([a (car l)] [b (cadr l)] [c (caddr l)] [l (cdddr l)])
           (case i [(0)  `(,b ,c ,a ,@l)]
                 [else `(,c ,a ,b ,@l)]))]
    [(2) (let ([a (car l)] [b (cadr l)] [c (caddr l)] [d (cadddr l)]
               [l (cddddr l)])
           (case i [(0)  `(,c ,b ,d ,a ,@l)]
                   [(1)  `(,c ,d ,a ,b ,@l)]
                   [else `(,d ,b ,a ,c ,@l)]))]
    [else (let loop ([n i] [l1 '()] [r1 l])
            (if (> n 0) (loop (sub1 n) (cons (car r1) l1) (cdr r1))
                (let loop ([n (- j i)] [l2 '()] [r2 (cdr r1)])
                  (if (> n 0) (loop (sub1 n) (cons (car r2) l2) (cdr r2))
                      `(,@l2 ,(car r2) ,@l1 ,(car r1) ,@(cdr r2))))))]))
(define (permutations l)
  (cond [(not (list? l)) (raise-argument-error 'permutations "list?" 0 l)]
        [(or (null? l) (null? (cdr l))) (list l)]
        [else
         (define N (- (length l) 2))
         ;; use a byte-string instead of a vector -- doesn't matter much for
         ;; speed, but permutations of longer lists are impractical anyway
         (when (> N 254) (error 'permutations "input list too long: ~e" l))
         (define c (make-bytes (add1 N) 0))
         (let loop ([i 0] [acc (list (reverse l))])
           (define ci (bytes-ref c i))
           (cond [(<= ci i) (bytes-set! c i (add1 ci))
                            (loop 0 (cons (swap+flip (car acc) ci i) acc))]
                 [(< i N)   (bytes-set! c i 0)
                            (loop (add1 i) acc)]
                 [else      acc]))]))
(define (in-permutations l)
  (cond [(not (list? l)) (raise-argument-error 'in-permutations "list?" 0 l)]
        [(or (null? l) (null? (cdr l))) (in-value l)]
        [else
         (define N (- (length l) 2))
         (when (> N 254) (error 'permutations "input list too long: ~e" l))
         (define c (make-bytes (add1 N) 0))
         (define i 0)
         (define cur l)
         (define (next)
           (define r cur)
           (define ci (bytes-ref c i))
           (cond [(<= ci i) (bytes-set! c i (add1 ci))
                            (begin0 (swap+flip cur ci i) (set! i 0))]
                 [(< i N)   (bytes-set! c i 0)
                            (set! i (add1 i))
                            (next)]
                 [else      #f]))
         (in-producer (λ() (begin0 cur (set! cur (next)))) #f)]))

;; mk-min : (number number -> boolean) symbol (X -> real) (listof X) -> X
(define (mk-min cmp name f xs)
  (unless (and (procedure? f)
               (procedure-arity-includes? f 1))
    (raise-argument-error name "(any/c . -> . real?)" 0 f xs))
  (unless (and (list? xs)
               (pair? xs))
    (raise-argument-error name "(and/c list? (not/c empty?))" 1 f xs))
  (let ([init-min-var (f (car xs))])
    (unless (real? init-min-var)
      (raise-result-error name "real?" init-min-var))
    (let loop ([min (car xs)]
               [min-var init-min-var]
               [xs (cdr xs)])
      (cond
        [(null? xs) min]
        [else
         (let ([new-min (f (car xs))])
           (unless (real? new-min)
             (raise-result-error name "real?" new-min))
           (cond
             [(cmp new-min min-var)
              (loop (car xs) new-min (cdr xs))]
             [else
              (loop min min-var (cdr xs))]))]))))
(define (argmin f xs) (mk-min < 'argmin f xs))
(define (argmax f xs) (mk-min > 'argmax f xs))

;; (x -> y) (listof x) [(y y -> bool)] -> (listof (listof x))
;; groups together elements that are considered equal
;; =? should be reflexive, transitive and commutative
(define (group-by key l [=? equal?])

  (unless (and (procedure? key)
               (procedure-arity-includes? key 1))
    (raise-argument-error 'group-by "(-> any/c any/c)" 0 key l))
  (unless (and (procedure? =?)
               (procedure-arity-includes? =? 2))
    (raise-argument-error 'group-by "(any/c any/c . -> . any/c)" 2 key l =?))
  (unless (list? l)
    (raise-argument-error 'group-by "list?" 1 key l))

  ;; like hash-update, but for alists
  (define (alist-update al k up fail)
    (let loop ([al al])
      (cond [(null? al)
             ;; did not find equivalence class, create one
             (list (cons k (up '())))]
            [(=? (car (car al)) k)
             ;; found the right equivalence class
             (cons
              (cons k (up (cdr (car al)))) ; updater takes elements, w/o key
              (cdr al))]
            [else ; keep going
             (cons (car al) (loop (cdr al)))])))

  ;; In cases where `=?` is a built-in equality, can use hash tables instead
  ;; of lists to compute equivalence classes.
  (define-values (base update)
    (cond [(equal? =? eq?)    (values (hasheq)  hash-update)]
          [(equal? =? eqv?)   (values (hasheqv) hash-update)]
          [(equal? =? equal?) (values (hash)    hash-update)]
          [else               (values '()       alist-update)]))

  (define classes
    (for/fold ([res base])
        ([elt (in-list l)]
         [idx (in-naturals)]) ; to keep ordering stable
      (define k (key elt))
      (define v (cons idx elt))
      (update res k (lambda (o) (cons v o)) '())))
  (define sorted-classes
    (if (list? classes)
        (for/list ([p (in-list classes)])
          (sort (cdr p) < #:key car))
        (for/list ([(_ c) (in-hash classes)])
          (sort c < #:key car))))
  ;; sort classes by order of first appearance, then remove indices
  (for/list ([c (in-list (sort sorted-classes < #:key caar))])
    (map cdr c)))

;; (listof x) ... -> (listof (listof x))
(define (cartesian-product . ls)
  (for ([(l i) (in-indexed ls)])
    (unless (list? l)
      (apply raise-argument-error 'cartesian-product "list?" i ls)))
  (define (cp-2 as bs)
    (for*/list ([i (in-list as)] [j (in-list bs)]) (cons i j)))
  (foldr cp-2 (list (list)) ls))

(define (remf f ls)
  (unless (list? ls)
    (raise-argument-error 'remf "list?" 1 f ls))
  (unless (and (procedure? f)
               (procedure-arity-includes? f 1))
    (raise-argument-error 'remf "(-> any/c any/c)" 0 f ls))
  (cond [(null? ls) '()]
        [(f (car ls)) (cdr ls)]
        [else
         (cons (car ls)
               (remf f (cdr ls)))]))

(define (remf* f ls)
  (unless (list? ls)
    (raise-argument-error 'remf* "list?" 1 f ls))
  (unless (and (procedure? f)
               (procedure-arity-includes? f 1))
    (raise-argument-error 'remf* "(-> any/c any/c)" 0 f ls))
  (cond [(null? ls) '()]
        [(f (car ls)) (remf* f (cdr ls))]
        [else
         (cons (car ls)
               (remf* f (cdr ls)))]))

(define (index-of ls v [=? equal?])
  (unless (list? ls)
    (raise-argument-error 'index-of "list?" 0 ls v))
  (unless (and (procedure? =?)
               (procedure-arity-includes? =? 2))
    (raise-argument-error 'index-of "(-> any/c any/c any/c)" 2 ls v =?))
  (let loop ([ls ls]
             [i 0])
    (cond [(null? ls) #f]
          [(=? (car ls) v) i]
          [else (loop (cdr ls) (add1 i))])))

(define (index-where ls f)
  (unless (list? ls)
    (raise-argument-error 'index-where "list?" 0 ls f))
  (unless (and (procedure? f)
               (procedure-arity-includes? f 1))
    (raise-argument-error 'index-where "(-> any/c any/c)" 1 ls f))
  (let loop ([ls ls]
             [i 0])
    (cond [(null? ls) #f]
          [(f (car ls)) i]
          [else (loop (cdr ls) (add1 i))])))

(define (indexes-of ls v [=? equal?])
  (unless (list? ls)
    (raise-argument-error 'indexes-of "list?" 0 ls v))
  (unless (and (procedure? =?)
               (procedure-arity-includes? =? 2))
    (raise-argument-error 'indexes-of "(-> any/c any/c any/c)" 2 ls v =?))
  (let loop ([ls ls]
             [i 0])
    (cond [(null? ls) '()]
          [(=? (car ls) v) (cons i (loop (cdr ls) (add1 i)))]
          [else (loop (cdr ls) (add1 i))])))

(define (indexes-where ls f)
  (unless (list? ls)
    (raise-argument-error 'indexes-where "list?" 0 ls f))
  (unless (and (procedure? f)
               (procedure-arity-includes? f 1))
    (raise-argument-error 'indexes-where "(-> any/c any/c)" 1 ls f))
  (let loop ([ls ls]
             [i 0])
    (cond [(null? ls) '()]
          [(f (car ls)) (cons i (loop (cdr ls) (add1 i)))]
          [else (loop (cdr ls) (add1 i))])))
