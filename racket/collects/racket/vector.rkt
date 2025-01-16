#lang racket/base

(provide vector-empty? vector-set*! vector-copy vector-set/copy
         vector-map vector-map! vector-append
         vector-take vector-drop vector-split-at
         vector-take-right vector-drop-right vector-split-at-right
         vector-filter vector-filter-not
         vector-count vector-argmin vector-argmax
         vector-member vector-memq vector-memv
         vector-sort vector-sort!
         vector*-copy vector*-set/copy vector*-append
	 vector-extend vector*-extend)
(require racket/unsafe/ops
         (only-in '#%kernel
                  vector-copy vector-append vector-set/copy
                  vector*-copy vector*-append vector*-set/copy
		  vector-extend vector*-extend)
         (for-syntax racket/base)
         (rename-in (except-in "private/sort.rkt" sort)
                    [vector-sort! raw-vector-sort!]
                    [vector-sort raw-vector-sort]))

(define (vector-empty? v)
  (unless (vector? v)
    (raise-argument-error 'vector-empty? "vector?" v))
  (zero? (vector-length v)))

(define (vector-set*! v . pairs)
  (unless (and (vector? v) (not (immutable? v)))
    (apply raise-argument-error 'vector-set*! "(and/c vector? (not/c immutable?))" 0 v pairs))
  (unless (even? (length pairs))
    (raise-arguments-error
     'vector-set*!
     (format "expected ~a, but received ~a"
             "an even number of association elements"
             "an odd number of association elements")
     "association elements"
     pairs))
  (let loop ([pairs pairs])
    (unless (null? pairs)
      (vector-set! v (car pairs) (cadr pairs))
      (loop (cddr pairs)))))

;; do vector-map, putting the result in `target'
;; length is passed to save the computation
(define (vector-map/update f target length vs)
  (for ([i (in-range length)])
    (unsafe-vector-set!
     target i
     (apply f (map (lambda (vec) (unsafe-vector-ref vec i)) vs)))))

;; check that `v' is a vector
;; that `v' and all the `vs' have the same length
;; and that `f' takes |v + vs| args
;; uses name for error reporting
(define (varargs-check f v vs name need-mutable?)
  (unless (procedure? f)
    (apply raise-argument-error name "procedure?" 0 f v vs))
  (unless (and (vector? v)
               (or (not need-mutable?)
                   (not (immutable? v))))
    (apply raise-argument-error name
           (if need-mutable? "(and/c vector? (not/c immutable?))" "vector?")
           1 f v vs))
  (let ([len (unsafe-vector-length v)])
    (for ([e (in-list vs)]
          [i (in-naturals 2)])
      (unless (vector? e)
        (apply raise-argument-error name "vector?" e i f v vs))
      (unless (= len (unsafe-vector-length e))
        (raise
         (make-exn:fail:contract
          (format "~e: all vectors must have same size; ~a"
                  name
                  (let ([args (list* f v vs)])
                    (if ((length args) . < . 10)
                      (apply string-append
                             "arguments were:"
                             (for/list ([i (list* f v vs)])
                               (format " ~e" i)))
                      (format "given ~a arguments total"
                              (sub1 (length args))))))
          (current-continuation-marks)))))
    (unless (procedure-arity-includes? f (add1 (length vs)))
      (raise-arguments-error name "mismatch between procedure arity and argument count"
                             "procedure" f
                             "expected arity" (add1 (length vs))))
    len))

(define (vector-map f v . vs)
  (let* ([len (varargs-check f v vs 'vector-map #f)]
         [new-v (make-vector len)])
    (vector-map/update f new-v len (cons v vs))
    new-v))

(define (vector-map! f v . vs)
  (define len (varargs-check f v vs 'vector-map! #t))
  (vector-map/update f v len (cons v vs))
  v)

;; check that `v' is a vector and that `f' takes one arg
;; uses name for error reporting
(define (one-arg-check f v name)
  (unless (and (procedure? f) (procedure-arity-includes? f 1))
    (raise-argument-error name "(any/c . -> . any/c)" 0 f v))
  (unless (vector? v)
    (raise-argument-error name "vector?" 1 f v)))

(define (vector-filter f v)
  (one-arg-check f v 'vector-filter)
  (list->vector (for/list ([i (in-vector v)] #:when (f i)) i)))

(define (vector-filter-not f v)
  (one-arg-check f v 'vector-filter-not)
  (list->vector (for/list ([i (in-vector v)] #:unless (f i)) i)))

(define (vector-count f v . vs)
  (define len (varargs-check f v vs 'vector-count #f))
  (if (pair? vs)
      (for/fold ([c 0])
                ([i (in-range len)]
                 #:when
                 (apply f
                        (unsafe-vector-ref v i)
                        (map (lambda (v) (unsafe-vector-ref v i)) vs)))
        (add1 c))
      (for/fold ([cnt 0]) ([i (in-vector v)] #:when (f i))
        (add1 cnt))))

(define (check-vector/index v n name)
  (unless (vector? v)
    (raise-argument-error* name 'racket/primitive "vector?" v))
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error* name 'racket/primitive "exact-nonnegative-integer?" n))
  (let ([len (unsafe-vector-length v)])
    (unless (<= 0 n len)
      (raise-range-error* name 'racket/primitive "vector" "" n v 0 len))
    len))

(define (vector-take v n)
  (check-vector/index v n 'vector-take)
  (unsafe-vector-copy v 0 n))

(define (vector-drop v n)
  (unsafe-vector-copy v n (check-vector/index v n 'vector-drop)))

(define (vector-split-at v n)
  (let ([len (check-vector/index v n 'vector-split-at)])
    (values (unsafe-vector-copy v 0 n) (unsafe-vector-copy v n len))))

(define (vector-take-right v n)
  (let ([len (check-vector/index v n 'vector-take-right)])
    (unsafe-vector-copy v (unsafe-fx- len n) len)))

(define (vector-drop-right v n)
  (let ([len (check-vector/index v n 'vector-drop-right)])
    (unsafe-vector-copy v 0 (unsafe-fx- len n))))

(define (vector-split-at-right v n)
  (let ([len (check-vector/index v n 'vector-split-at-right)])
    (values (unsafe-vector-copy v 0 (unsafe-fx- len n))
            (unsafe-vector-copy v (unsafe-fx- len n) len))))

;; copied from `racket/list'
(define (mk-min cmp name f xs)
  (unless (and (procedure? f)
               (procedure-arity-includes? f 1))
    (raise-argument-error name "(any/c . -> . real?)" f))
  (unless (and (vector? xs)
               (< 0 (unsafe-vector-length xs)))
    (raise-argument-error name "(and/c vector? (lambda (v) (positive? (vector-length v))))" xs))
  (let ([init-min-var (f (unsafe-vector-ref xs 0))])
    (unless (real? init-min-var)
      (raise-result-error name "real?" init-min-var))
    (if (unsafe-fx= (unsafe-vector-length xs) 1)
        (unsafe-vector-ref xs 0)
        (let-values ([(min* min-var*)
                  (for/fold ([min (unsafe-vector-ref xs 0)]
                             [min-var init-min-var])
                      ([e (in-vector xs 1)])
                    (let ([new-min (f e)])
                      (unless (real? new-min)
                        (raise-result-error
                         name "real?" new-min))
                      (cond [(cmp new-min min-var)
                             (values e new-min)]
                            [else (values min min-var)])))])
      min*))))

(define (vector-argmin f xs) (mk-min < 'vector-argmin f xs))
(define (vector-argmax f xs) (mk-min > 'vector-argmax f xs))

(define-syntax (vm-mk stx)
  (syntax-case stx ()
    ((_ name cmp (opt-arg default check contract) ...)
     (with-syntax (((index ...) (build-list (length (syntax->datum #'(opt-arg ...)))
                                            (lambda (n) (+ 2 n)))))
       #'(define (name val vec (opt-arg default) ...)
           (unless (vector? vec)
             (raise-argument-error 'name "vector?" 1 val vec opt-arg ...))
           (unless check
             (raise-argument-error 'name contract index val vec opt-arg ...))
           ...
           (let ([sz (unsafe-vector-length vec)])
             (let loop ([k 0])
               (cond [(= k sz) #f]
                     [(cmp val
                           (unsafe-vector-ref vec k))
                      k]
                     [else (loop (unsafe-fx+ 1 k))]))))))))

(vm-mk vector-member is-equal?
       (is-equal? equal?
        (and (procedure? is-equal?) (procedure-arity-includes? is-equal? 2))
        "(procedure-arity-includes/c 2)"))
(vm-mk vector-memq eq?)
(vm-mk vector-memv eqv?)

(define-syntax-rule (perform-common-sort-arg-checks name vec less? start end getkey)
  (let ()
    ;; check other args are valid
    (unless (exact-nonnegative-integer? start)
      (raise-argument-error 'name "exact-nonnegative-integer?" start))
    (unless (exact-nonnegative-integer? end)
      (raise-argument-error 'name "exact-nonnegative-integer?" end))
    (unless (and (procedure? less?) (procedure-arity-includes? less? 2))
      (raise-argument-error 'name "(any/c any/c . -> . any/c)" less?))
    (when (and getkey (not (and (procedure? getkey)
                                (procedure-arity-includes? getkey 1))))
      (raise-argument-error 'name "(any/c . -> . any/c)" getkey))
    (let ([len (vector-length vec)])
      (unless (and (<= 0 start len))
        (raise-range-error 'name "vector" "starting " start vec 0 len))
      (unless (and (<= start end len))
        (raise-range-error 'name "vector" "ending " end vec start len 0)))))



;; vector sort
(define (vector-sort vec less? [start 0] [end #f]
                     #:key [getkey #f] #:cache-keys? [cache-keys? #f])
  ;; is the input vector the right kind? (mutable vs immutable allowed?)
  (unless (vector? vec)
    (raise-argument-error 'vector-sort "vector?" vec))
  
  ;; calculate end if not provided
  (let ([end (or end (vector-length vec))])
    (perform-common-sort-arg-checks vector-sort vec less? start end getkey)
    (if getkey
        (raw-vector-sort vec less? start end getkey cache-keys?)
        (raw-vector-sort vec less? start end))))

;; vector sort
(define (vector-sort! vec less? [start 0] [end #f]
                      #:key [getkey #f]
                      #:cache-keys? [cache-keys? #f])
  ;; is the input vector the right kind? (mutable vs immutable allowed?)
  (unless (and (vector? vec) (not (immutable? vec)))
    (raise-argument-error 'vector-sort!
                          "(and/c vector? (not/c immutable?))"
                          vec))
  
  ;; calculate end if not provided
  (let ([end (or end (vector-length vec))])
    (perform-common-sort-arg-checks vector-sort! vec less? start end getkey)
    (if getkey
        (raw-vector-sort! vec less? start end getkey cache-keys?)
        (raw-vector-sort! vec less? start end))))
