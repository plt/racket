#lang racket/base
(require "test-util.rkt")

(parameterize ([current-contract-namespace
                (make-basic-contract-namespace 'racket/contract
                                               'racket/list
                                               'racket/class
                                               'racket/math
                                               'racket/sequence)])

  (contract-eval '(define-contract-struct couple (hd tl)))
  (contract-eval '(define-contract-struct triple (a b c)))
  (contract-eval '(require (only-in racket/contract/private/prop
                                    trusted-contract-struct-stronger?)
                           (only-in racket/contract/private/guts
                                    coerce-contract)))
  (contract-eval '(define (trust/not-stronger? a b)
                    (define normal (contract-stronger? a b))
                    (define trusted (trusted-contract-struct-stronger?
                                     (coerce-contract 'trust/not-stronger? a)
                                     (coerce-contract 'trust/not-stronger? b)))
                    (unless (equal? normal trusted)
                      (error 'trust/not-stronger
                             (string-append
                              "got different results trusted vs non-trusted mode\n"
                              "  trusted ~s\n"
                              "  normal  ~s\n"
                              "  ~s\n"
                              "  ~s")
                             trusted normal
                             a b))
                    normal))

  (ctest #t trust/not-stronger? any/c any/c)
  (ctest #t trust/not-stronger? none/c none/c)
  (ctest #t trust/not-stronger? integer? any/c)
  (ctest #t trust/not-stronger? none/c integer?)

  (ctest #t trust/not-stronger? (integer-in 0 4) (integer-in 0 4))
  (ctest #t trust/not-stronger? (integer-in 1 3) (integer-in 0 4))
  (ctest #f trust/not-stronger? (integer-in 0 4) (integer-in 1 3))
  (ctest #f trust/not-stronger? (integer-in 0 4) (integer-in 1 #f))
  (ctest #f trust/not-stronger? (integer-in 0 4) (integer-in #f 3))
  (ctest #t trust/not-stronger? (integer-in 0 4) (integer-in #f 4))
  (ctest #t trust/not-stronger? (integer-in 0 #f) (integer-in #f #f))
  (ctest #t trust/not-stronger? (integer-in #f 0) (integer-in #f #f))
  (ctest #t trust/not-stronger? (integer-in 0 0) (and/c 0 exact?))
  (ctest #t trust/not-stronger? (and/c 0 exact?) (integer-in 0 0))
  (ctest #t trust/not-stronger? (and/c exact-integer? (>=/c 1) (<=/c 10)) (integer-in 1 10))
  (ctest #t trust/not-stronger? (integer-in 1 10) (and/c exact-integer? (>=/c 1) (<=/c 10)))
  (ctest #t trust/not-stronger? (and/c exact-integer? (<=/c 10) (>/c 1)) (integer-in 2 10))
  (ctest #t trust/not-stronger? (integer-in 2 10) (and/c exact-integer? (<=/c 10) (>/c 1)))
  (ctest #t trust/not-stronger? (and/c exact-integer? (</c 10) (>/c 1)) (integer-in 2 9))
  (ctest #t trust/not-stronger? (integer-in 2 9) (and/c exact-integer? (</c 10) (>/c 1)))
  (ctest #t trust/not-stronger? (integer-in 2 9) (and/c exact-integer? (</c 10.0) (>/c 1.0)))
  (ctest #t trust/not-stronger? exact-integer? (integer-in #f #f))
  (ctest #t trust/not-stronger? (integer-in #f #f) exact-integer?)
  (ctest #t trust/not-stronger? (integer-in 0 #f) exact-nonnegative-integer?)
  (ctest #t trust/not-stronger? (integer-in 0 #f) natural?)
  (ctest #t trust/not-stronger? natural? (integer-in 0 #f))
  (ctest #t trust/not-stronger? (integer-in 1 #f) exact-positive-integer?)
  (ctest #t trust/not-stronger? exact-positive-integer? (integer-in 1 #f))
  (ctest #t trust/not-stronger? natural? exact-integer?) ;; this actually is `integer-in`

  (ctest #t trust/not-stronger? (integer-in 0 5) (and/c natural? (<=/c 5)))
  (ctest #t trust/not-stronger? (and/c natural? (<=/c 5)) (integer-in 0 5))
  (ctest #t trust/not-stronger? (integer-in 0 5) (and/c exact-nonnegative-integer? (<=/c 5)))
  (ctest #t trust/not-stronger? (and/c exact-nonnegative-integer? (<=/c 5)) (integer-in 0 5))
  (ctest #t trust/not-stronger? (integer-in 5 #f) (and/c natural? (>=/c 5)))
  (ctest #t trust/not-stronger? (and/c natural? (>=/c 5)) (integer-in 5 #f))
  (ctest #t trust/not-stronger? (integer-in 0 #f) (and/c exact-nonnegative-integer? (>=/c -4)))
  (ctest #t trust/not-stronger? (and/c exact-nonnegative-integer? (>=/c -4)) (integer-in 0 #f))

  (ctest #t trust/not-stronger? (integer-in -1 10) (between/c -1 10))
  (ctest #t trust/not-stronger? (integer-in  2 10) (between/c -1 10))
  (ctest #t trust/not-stronger? (integer-in -1 6) (between/c -1 10))
  (ctest #f trust/not-stronger? (integer-in -1 11) (between/c -1 10))
  (ctest #t trust/not-stronger? (integer-in -1 10) real?)
  (ctest #t trust/not-stronger? exact-integer? real?)

  (ctest #t trust/not-stronger? #\a (char-in #\a #\c))
  (ctest #f trust/not-stronger? #\a (char-in #\b #\c))
  (ctest #t trust/not-stronger? (char-in #\f #\q) (char-in #\a #\z))
  (ctest #f trust/not-stronger? (char-in #\a #\z) (char-in #\f #\q))
  (ctest #t trust/not-stronger? (between/c 1 3) (between/c 0 4))
  (ctest #f trust/not-stronger? (between/c 0 4) (between/c 1 3))
  (ctest #t trust/not-stronger? (between/c -inf.0 +inf.0) real?)
  (ctest #t trust/not-stronger? real? (between/c -inf.0 +inf.0))
  (ctest #t trust/not-stronger? (>=/c 3) (>=/c 2))
  (ctest #f trust/not-stronger? (>=/c 2) (>=/c 3))
  (ctest #f trust/not-stronger? (<=/c 3) (<=/c 2))
  (ctest #t trust/not-stronger? (<=/c 2) (<=/c 3))
  (ctest #t trust/not-stronger? (>/c 3) (>/c 2))
  (ctest #f trust/not-stronger? (>/c 2) (>/c 3))
  (ctest #f trust/not-stronger? (</c 3) (</c 2))
  (ctest #t trust/not-stronger? (</c 2) (</c 3))
  (ctest #f trust/not-stronger? (</c 2) (>/c 2))
  (ctest #t trust/not-stronger? (</c 2) (<=/c 2))
  (ctest #f trust/not-stronger? (</c 2) (>=/c 2))
  (ctest #f trust/not-stronger? (>/c 2) (<=/c 2))
  (ctest #t trust/not-stronger? (>/c 2) (>=/c 2))
  (ctest #t trust/not-stronger? (</c 2) (<=/c 200))
  (ctest #f trust/not-stronger? (<=/c 2) (</c 2))
  (ctest #t trust/not-stronger? (<=/c 1) (</c 2))
  (ctest #f trust/not-stronger? (>=/c 2) (</c 2))
  (ctest #f trust/not-stronger? (<=/c 2) (>/c 2))
  (ctest #f trust/not-stronger? (>=/c 2) (>/c 2))
  (ctest #t trust/not-stronger? (>=/c 3) (>/c 2))

  (ctest #t trust/not-stronger? (>/c 0) (and/c real? positive?))
  (ctest #t trust/not-stronger? (and/c real? positive?) (>/c 0))
  (ctest #t trust/not-stronger? (</c 0) (and/c real? negative?))
  (ctest #t trust/not-stronger? (and/c real? negative?) (</c 0))
  (ctest #t trust/not-stronger? (<=/c 0) (and/c real? (not/c positive?)))
  (ctest #t trust/not-stronger? (and/c real? (not/c positive?)) (<=/c 0))
  (ctest #t trust/not-stronger? (>=/c 0) (and/c real? (not/c negative?)))
  (ctest #t trust/not-stronger? (and/c real? (not/c negative?)) (>=/c 0))

  (ctest #t trust/not-stronger? (recursive-contract (<=/c 2)) (recursive-contract (<=/c 3)))
  (ctest #f trust/not-stronger? (recursive-contract (<=/c 3)) (recursive-contract (<=/c 2)))
  (let ([f (contract-eval '(λ (x) (recursive-contract (<=/c x))))])
    (test #t (contract-eval 'trust/not-stronger?) (contract-eval `(,f 1)) (contract-eval `(,f 1))))
  (ctest #t trust/not-stronger?
         (letrec ([c (recursive-contract (-> (<=/c 5) c))]) c)
         (letrec ([c (recursive-contract (-> (<=/c 3) c))]) c))
  (ctest #t trust/not-stronger?
         (letrec ([c (recursive-contract (-> (<=/c 3) c))]) c)
         (letrec ([c (recursive-contract (-> (<=/c 1) c))]) c))
  (ctest #t trust/not-stronger?
         (letrec ([c (recursive-contract (-> (<=/c 3) c))]) c)
         (letrec ([c (recursive-contract (-> (<=/c 1) (-> (<=/c 1) c)))]) c))
  (ctest #t trust/not-stronger?
         (letrec ([c (recursive-contract (-> (<=/c 1) (-> (<=/c 1) c)))]) c)
         (letrec ([c (recursive-contract (-> (<=/c 1) (-> (<=/c 1) (-> (<=/c 1) c))))]) c))
  (ctest #t trust/not-stronger? (-> integer? integer?) (-> integer? integer?))
  (ctest #f trust/not-stronger? (-> boolean? boolean?) (-> integer? integer?))
  (ctest #t trust/not-stronger? (-> (>=/c 3) (>=/c 3)) (-> (>=/c 4) (>=/c 3)))
  (ctest #f trust/not-stronger? (-> (>=/c 4) (>=/c 3)) (-> (>=/c 3) (>=/c 3)))
  (ctest #t trust/not-stronger? (-> (>=/c 3) (>=/c 3)) (-> (>=/c 3) (>=/c 2)))
  (ctest #f trust/not-stronger? (-> (>=/c 3) (>=/c 2)) (-> (>=/c 3) (>=/c 3)))
  (ctest #f trust/not-stronger? (-> (>=/c 2)) (-> (>=/c 3) (>=/c 3)))
  (ctest #f trust/not-stronger?
         (-> integer? #:x integer? integer?)
         (-> integer? #:y integer? integer?))
  (ctest #f trust/not-stronger?
         (-> integer? #:y integer? integer?)
         (-> integer? #:x integer? integer?))
  (ctest #t trust/not-stronger?
         (-> integer? #:x integer? integer?)
         (-> integer? #:x integer? integer?))
  (ctest #t trust/not-stronger? (-> #:x (>=/c 3) (>=/c 3)) (-> #:x (>=/c 3) (>=/c 2)))
  (ctest #t trust/not-stronger? (-> any/c any/c any) (-> any/c any/c any))
  (ctest #f trust/not-stronger? (-> any/c any/c any/c any) (-> any/c any/c any))
  (ctest #t trust/not-stronger? (-> (-> any/c) integer?) (-> (-> any/c) any/c))
  (ctest #f trust/not-stronger? (-> (-> any/c) any/c) (-> (-> any/c) integer?))

  (let ([c (contract-eval '(->* () () any))])
    (test #t (contract-eval 'trust/not-stronger?) c c))
  (let ([c (contract-eval '(->d () () any))])
    (test #t (contract-eval 'trust/not-stronger?) c c))
  (let ([c (contract-eval '(->i () () any))])
    (test #t (contract-eval 'trust/not-stronger?) c c))

  (ctest #f trust/not-stronger?
         (->* () #:pre (zero? (random 10)) any)
         (->* () #:pre (zero? (random 10)) any))
  (ctest #f trust/not-stronger?
         (->* () integer? #:post (zero? (random 10)))
         (->* () integer? #:post (zero? (random 10))))

  (ctest #t trust/not-stronger? (or/c null? #f) (or/c null? #f))
  (ctest #f trust/not-stronger? (or/c null? #f) (or/c boolean? #f))
  (ctest #t trust/not-stronger? (or/c null? boolean?) (or/c null? boolean?))
  (ctest #t trust/not-stronger? (or/c null? boolean?) (or/c boolean? null?))
  (ctest #t trust/not-stronger?
         (or/c null? (-> integer? integer?))
         (or/c null? (-> integer? integer?)))
  (ctest #f trust/not-stronger?
         (or/c null? (-> boolean? boolean?))
         (or/c null? (-> integer? integer?)))
  (ctest #f trust/not-stronger? (or/c number? #f) number?)
  (ctest #t trust/not-stronger? number? (or/c number? #f))
  (ctest #f trust/not-stronger? (or/c (-> number? number?) #f) (-> number? number?))
  (ctest #t trust/not-stronger? (-> number? number?) (or/c (-> number? number?) #f))
  (ctest #f trust/not-stronger? (or/c (-> number? number?) (-> number? number? number?) #f) #f)
  (ctest #t trust/not-stronger? #f (or/c (-> number? number?) (-> number? number? number?) #f))
  (ctest #t trust/not-stronger? (or/c real?) (or/c integer? real?))
  (ctest #t trust/not-stronger? (-> number?) (-> (or/c #f number?)))
  (ctest #t trust/not-stronger? (-> (or/c #f number?) any/c) (-> number? any/c))
  (ctest #f trust/not-stronger? (-> (or/c #f number?)) (-> number?))
  (ctest #f trust/not-stronger? (-> number? any/c) (-> (or/c #f number?) any/c))

  (ctest #t trust/not-stronger? (first-or/c null? #f) (first-or/c null? #f))
  (ctest #f trust/not-stronger? (first-or/c null? #f) (first-or/c boolean? #f))
  (ctest #t trust/not-stronger? (first-or/c null? boolean?) (first-or/c null? boolean?))
  (ctest #t trust/not-stronger? (first-or/c null? boolean?) (first-or/c boolean? null?))
  (ctest #t trust/not-stronger?
         (first-or/c null? (-> integer? integer?))
         (first-or/c null? (-> integer? integer?)))
  (ctest #f trust/not-stronger?
         (first-or/c null? (-> boolean? boolean?))
         (first-or/c null? (-> integer? integer?)))
  (ctest #f trust/not-stronger? (first-or/c number? #f) number?)
  (ctest #t trust/not-stronger? number? (first-or/c number? #f))
  (ctest #f trust/not-stronger? (first-or/c (-> number? number?) #f) (-> number? number?))
  (ctest #t trust/not-stronger? (-> number? number?) (first-or/c (-> number? number?) #f))
  (ctest #f trust/not-stronger? (first-or/c (-> number? number?) (-> number? number? number?) #f) #f)
  (ctest #t trust/not-stronger? #f (first-or/c (-> number? number?) (-> number? number? number?) #f))
  (ctest #t trust/not-stronger? (first-or/c real?) (first-or/c integer? real?))
  (ctest #t trust/not-stronger? (-> number?) (-> (first-or/c #f number?)))
  (ctest #t trust/not-stronger? (-> (first-or/c #f number?) any/c) (-> number? any/c))
  (ctest #f trust/not-stronger? (-> (first-or/c #f number?)) (-> number?))
  (ctest #f trust/not-stronger? (-> number? any/c) (-> (first-or/c #f number?) any/c))

  (ctest #t trust/not-stronger? (first-or/c null? #f) (or/c null? #f))
  (ctest #f trust/not-stronger? (first-or/c null? #f) (or/c boolean? #f))
  (ctest #t trust/not-stronger? (first-or/c null? boolean?) (or/c null? boolean?))
  (ctest #t trust/not-stronger? (first-or/c null? boolean?) (or/c boolean? null?))

  (ctest #t trust/not-stronger? (or/c null? #f) (first-or/c null? #f))
  (ctest #f trust/not-stronger? (or/c null? #f) (first-or/c boolean? #f))
  (ctest #t trust/not-stronger? (or/c null? boolean?) (first-or/c null? boolean?))
  (ctest #t trust/not-stronger? (or/c null? boolean?) (first-or/c boolean? null?))

  (ctest #t trust/not-stronger? number? number?)
  (ctest #f trust/not-stronger? boolean? number?)

  (ctest #t trust/not-stronger? (parameter/c (between/c 0 5)) (parameter/c (between/c 0 5)))
  (ctest #f trust/not-stronger? (parameter/c (between/c 0 5)) (parameter/c (between/c 1 4)))
  (ctest #f trust/not-stronger? (parameter/c (between/c 1 4)) (parameter/c (between/c 0 5)))

  (ctest #f trust/not-stronger? (parameter/c (between/c 1 4) (between/c 0 5))
                               (parameter/c (between/c 0 5)))
  (ctest #t trust/not-stronger? (parameter/c (between/c 0 5) (between/c 1 4))
                               (parameter/c (between/c 1 4)))
  (ctest #t trust/not-stronger? (parameter/c (between/c 0 5))
                               (parameter/c (between/c 1 4) (between/c 0 5)))
  (ctest #f trust/not-stronger? (parameter/c (between/c 1 4))
                               (parameter/c (between/c 0 5) (between/c 0 5)))
  (ctest #t trust/not-stronger? (parameter/c (between/c 0 5) (between/c 1 4))
                               (parameter/c (between/c 1 4) (between/c 0 5)))
  (ctest #f trust/not-stronger? (parameter/c (between/c 1 4) (between/c 0 5))
                               (parameter/c (between/c 0 5) (between/c 1 4)))
  (ctest #f trust/not-stronger? (parameter/c (between/c 0 5)) (parameter/c (between/c 0 5) (between/c 1 6)))

  (ctest #t trust/not-stronger? (symbols 'x 'y) (symbols 'x 'y 'z))
  (ctest #f trust/not-stronger? (symbols 'x 'y 'z) (symbols 'x 'y))
  (ctest #t trust/not-stronger? (symbols 'x 'y) (symbols 'z 'x 'y))
  (ctest #f trust/not-stronger? (symbols 'z 'x 'y) (symbols 'x 'y))
  (ctest #t trust/not-stronger? (one-of/c (expt 2 100)) (one-of/c (expt 2 100) 12))

  (ctest #t trust/not-stronger?
        (or/c (-> (>=/c 3) (>=/c 3)) (-> string?))
        (or/c (-> (>=/c 4) (>=/c 3)) (-> string?)))
  (ctest #f trust/not-stronger?
        (or/c (-> string?) (-> integer? integer?))
        (or/c (-> string?) (-> any/c integer?)))
  (ctest #f trust/not-stronger?
        (or/c (-> string?) (-> #f integer?))
        (or/c (-> string?) (-> integer? integer?)))
  (ctest #t trust/not-stronger?
        (or/c (-> string?) (-> integer? integer?) integer? boolean?)
        (or/c (-> string?) (-> integer? integer?) integer? boolean?))
  (ctest #f trust/not-stronger?
        (or/c (-> string?) (-> integer? integer?) integer? char?)
        (or/c (-> string?) (-> integer? integer?) integer? boolean?))
  (ctest #t trust/not-stronger?
        (or/c (-> string?) (-> integer? integer?) integer?)
        (or/c (-> string?) (-> integer? integer?) integer? boolean?))
  (ctest #f trust/not-stronger?
        (or/c (-> string?) (-> integer? integer?) integer?)
        (or/c (-> integer? integer?) integer?))

  (ctest #t trust/not-stronger? (list/c) '())
  (ctest #t trust/not-stronger? '() (list/c))
  (ctest #t trust/not-stronger? (cons/c boolean? integer?) (cons/c boolean? integer?))
  (ctest #f trust/not-stronger? (cons/c boolean? integer?) (cons/c integer? boolean?))
  (ctest #t trust/not-stronger? (cons/c number? (listof number?)) (non-empty-listof number?))
  (ctest #t trust/not-stronger? (and/c pair? (listof number?)) (non-empty-listof number?))
  (ctest #t trust/not-stronger? (non-empty-listof number?) (and/c (listof number?) pair?))
  (ctest #t trust/not-stronger? (non-empty-listof number?) (cons/c number? (listof number?)))
  (ctest #t trust/not-stronger? (cons/c number? (list/c number? number?)) (non-empty-listof number?))
  (ctest #t trust/not-stronger? (cons/c number? (cons/c number? (listof number?))) (listof number?))
  (ctest #t trust/not-stronger?
         (cons/c (<=/c 1) (cons/c (<=/c 2) (listof (<=/c 3))))
         (listof (<=/c 4)))
  (ctest #f trust/not-stronger? (listof number?) (cons/c number? (cons/c number? (listof any/c))))
  (ctest #t trust/not-stronger? (list*of (<=/c 2)) (list*of (<=/c 3)))
  (ctest #f trust/not-stronger? (list*of (<=/c 3)) (list*of (<=/c 2)))
  (ctest #t trust/not-stronger? (list*of (<=/c 2) char?) (list*of (<=/c 3) char?))
  (ctest #f trust/not-stronger? (list*of (<=/c 3) char?) (list*of (<=/c 2) char?))
  (ctest #t trust/not-stronger? (list*of char? (<=/c 2)) (list*of char? (<=/c 3)))
  (ctest #f trust/not-stronger? (list*of char? (<=/c 3)) (list*of char? (<=/c 2)))
  (ctest #t trust/not-stronger? (list*of char? null?) (listof char?))
  (ctest #t trust/not-stronger? (listof char?) (list*of char? null?))
  (ctest #f trust/not-stronger? (list*of char? any/c) (listof char?))

  (ctest #t trust/not-stronger? (treelist/c integer?) (treelist/c integer?))
  (ctest #f trust/not-stronger? (treelist/c integer?) (treelist/c natural?))
  (ctest #t trust/not-stronger? (treelist/c (between/c 1 10)) (treelist/c (between/c 0 100)))
  (ctest #t trust/not-stronger? (mutable-treelist/c integer?) (mutable-treelist/c integer?))
  (ctest #f trust/not-stronger? (mutable-treelist/c integer?) (mutable-treelist/c natural?))
  (ctest #f trust/not-stronger? (mutable-treelist/c (between/c 1 10)) (mutable-treelist/c (between/c 0 100)))
  
  (ctest #f trust/not-stronger? (vectorof (<=/c 3)) (vectorof (<=/c 4)))
  (ctest #f trust/not-stronger? (vectorof (<=/c 3)) (vectorof (<=/c 4)))
  (ctest #t trust/not-stronger? (vectorof (<=/c 3) #:immutable #t) (vectorof (<=/c 4) #:immutable #t))
  (ctest #t trust/not-stronger? (vectorof (<=/c 3) #:immutable #t) (vectorof (<=/c 3)))
  (ctest #f trust/not-stronger? (vectorof (<=/c 3)) (vectorof (<=/c 3) #:immutable #t))
  (ctest #f trust/not-stronger? (vectorof (<=/c 3)) (vectorof (<=/c 3) #:immutable #f))
  (ctest #t trust/not-stronger? (vectorof (<=/c 3) #:immutable #f) (vectorof (<=/c 3)))
  (ctest #t trust/not-stronger? (vectorof (<=/c 3)) (vectorof (<=/c 3)))

  (ctest #t trust/not-stronger? (vector/c (<=/c 3) (<=/c 3) (<=/c 3)) (vectorof (<=/c 3)))
  (ctest #f trust/not-stronger? (vector/c (<=/c 3) (<=/c 3) (<=/c 3)) (vectorof (<=/c 4)))
  (ctest #f trust/not-stronger? (vector/c (<=/c 3) (<=/c 3) (<=/c 3)) (vectorof (<=/c 2)))
  (ctest #t trust/not-stronger? (vector/c (<=/c 3) (<=/c 3)) (vector/c (<=/c 3) (<=/c 3)))
  (ctest #f trust/not-stronger? (vector/c (<=/c 3) (<=/c 3)) (vector/c (<=/c 3) (<=/c 2)))
  (ctest #f trust/not-stronger? (vector/c (<=/c 3) (<=/c 2)) (vector/c (<=/c 3) (<=/c 3)))
  (ctest #t trust/not-stronger? (vector/c (<=/c 3) #:immutable #t) (vector/c (<=/c 3)))
  (ctest #t trust/not-stronger? (vector/c (<=/c 3) #:immutable #f) (vector/c (<=/c 3)))
  (ctest #f trust/not-stronger? (vector/c (<=/c 3)) (vector/c (<=/c 3) #:immutable #t))
  (ctest #f trust/not-stronger? (vector/c (<=/c 3)) (vector/c (<=/c 3) #:immutable #f))
  (ctest #t trust/not-stronger? (vector/c (<=/c 2) #:immutable #t) (vector/c (<=/c 3) #:immutable #t))
  (ctest #f trust/not-stronger? (vector/c (<=/c 3) #:immutable #t) (vector/c (<=/c 2) #:immutable #t))

  (ctest #t trust/not-stronger? (box/c (<=/c 3)) (box/c (<=/c 3)))
  (ctest #f trust/not-stronger? (box/c (<=/c 3)) (box/c (<=/c 2)))
  (ctest #f trust/not-stronger? (box/c (<=/c 2)) (box/c (<=/c 3)))
  (ctest #t trust/not-stronger? (box/c (<=/c 2) #:immutable #t) (box/c (<=/c 3) #:immutable #t))
  (ctest #f trust/not-stronger? (box/c (<=/c 3) #:immutable #t) (box/c (<=/c 2) #:immutable #t))
  (ctest #t trust/not-stronger? (box/c (<=/c 3) #:immutable #t) (box/c (<=/c 3)))
  (ctest #t trust/not-stronger? (box/c (<=/c 3) #:immutable #f) (box/c (<=/c 3)))
  (ctest #f trust/not-stronger? (box/c (<=/c 3)) (box/c (<=/c 3) #:immutable #t))
  (ctest #f trust/not-stronger? (box/c (<=/c 3)) (box/c (<=/c 3) #:immutable #f))

  (ctest #t trust/not-stronger? (hash/c integer? symbol?) (hash/c integer? symbol?))
  (ctest #f trust/not-stronger? (hash/c integer? symbol?) (hash/c symbol? integer?))
  (ctest #f trust/not-stronger? (hash/c (<=/c 2) symbol?) (hash/c (<=/c 3) symbol?))
  (ctest #t trust/not-stronger?
         (hash/c (<=/c 2) symbol? #:immutable #t)
         (hash/c (<=/c 3) symbol? #:immutable #t))
  (ctest #f trust/not-stronger?
         (hash/c (<=/c 3) symbol? #:immutable #t)
         (hash/c (<=/c 2) symbol? #:immutable #t))
  (ctest #t trust/not-stronger?
         (hash/c (<=/c 2) symbol? #:immutable #f)
         (hash/c (<=/c 2) symbol?))
  (ctest #f trust/not-stronger?
         (hash/c (<=/c 2) symbol?)
         (hash/c (<=/c 2) symbol? #:immutable #f))

  (contract-eval
   `(let ()
      (define x (flat-rec-contract x (or/c (cons/c x '()) '())))
      (,test #t trust/not-stronger? x (or/c (cons/c x '()) '()))))
  (contract-eval
   `(let ()
      (define x (flat-rec-contract x (first-or/c (cons/c x '()) '())))
      (,test #t trust/not-stronger? x (first-or/c (cons/c x '()) '()))))

  (contract-eval
   `(let ()
      (define x (flat-murec-contract ([x (or/c (cons/c x '()) '())]) x))
      (,test #t trust/not-stronger? x (or/c (cons/c x '()) '()))))
  (contract-eval
   `(let ()
      (define x (flat-murec-contract ([x (first-or/c (cons/c x '()) '())]) x))
      (,test #t trust/not-stronger? x (first-or/c (cons/c x '()) '()))))

  (ctest #t trust/not-stronger? "x" string?)
  (ctest #f trust/not-stronger? string? "x")

  (ctest #t trust/not-stronger? 1 real?)
  (ctest #t trust/not-stronger? 1 (between/c -10 10))
  (ctest #f trust/not-stronger? real? 1)

  (ctest #t trust/not-stronger? 'x symbol?)
  (ctest #f trust/not-stronger? symbol? 'x)

  (ctest #t trust/not-stronger?
         (flat-named-contract 'name1 #f)
         (flat-named-contract 'name2 #f))
  (ctest #t trust/not-stronger?
         (flat-named-contract 'name1 (flat-named-contract 'name2 #f))
         (flat-named-contract 'name3 (flat-named-contract 'name4 #f)))
  (ctest #t trust/not-stronger? (flat-named-contract 'name1 1) (flat-named-contract 'name2 1))
  (ctest #t trust/not-stronger? (flat-named-contract 'name1 "x") (flat-named-contract 'name2 "x"))
  (ctest #t trust/not-stronger?
         (flat-named-contract 'name2 (regexp "x"))
         (flat-named-contract 'name2 (regexp "x")))
  (ctest #t trust/not-stronger? (listof (<=/c 3)) (listof (<=/c 5)))
  (ctest #t trust/not-stronger? (list/c (<=/c 3) (<=/c 3)) (list/c (<=/c 3) (<=/c 3)))
  (ctest #f trust/not-stronger? (list/c (<=/c 3) (<=/c 3)) (list/c (<=/c 3) (<=/c 3) (<=/c 3)))
  (ctest #f trust/not-stronger? (list/c (<=/c 3) (<=/c 3) (<=/c 3)) (list/c (<=/c 3) (<=/c 3)))
  (ctest #t trust/not-stronger? (list/c (<=/c 3) (<=/c 3)) (listof (<=/c 5)))
  (ctest #t trust/not-stronger? (list/c (<=/c 3) (<=/c 3)) (non-empty-listof (<=/c 5)))
  (ctest #t trust/not-stronger? (list/c (<=/c 3)) (non-empty-listof (<=/c 5)))
  (ctest #f trust/not-stronger? (list/c) (non-empty-listof (<=/c 5)))
  (ctest #t trust/not-stronger? (list/c) (listof (<=/c 5)))

  (ctest #t trust/not-stronger? (*list/c integer? boolean? char?) (*list/c integer? boolean? char?))
  (ctest #t trust/not-stronger? (list/c integer? boolean? char?) (listof (or/c integer? boolean? char?)))

  (ctest #t trust/not-stronger? (promise/c (<=/c 2)) (promise/c (<=/c 3)))
  (ctest #f trust/not-stronger? (promise/c (<=/c 3)) (promise/c (<=/c 2)))

  (ctest #t trust/not-stronger? (syntax/c (<=/c 3)) (syntax/c (<=/c 4)))
  (ctest #f trust/not-stronger? (syntax/c (<=/c 4)) (syntax/c (<=/c 3)))

  (ctest #t trust/not-stronger? (sequence/c (<=/c 3)) (sequence/c (<=/c 4)))
  (ctest #f trust/not-stronger? (sequence/c (<=/c 3) (<=/c 3)) (sequence/c (<=/c 3)))
  (ctest #f trust/not-stronger? (sequence/c (<=/c 3)) (sequence/c (<=/c 3) (<=/c 3)))
  (ctest #f trust/not-stronger? (sequence/c (<=/c 4)) (sequence/c (<=/c 3)))
  (ctest #t trust/not-stronger? (sequence/c (<=/c 3) #:min-count 5) (sequence/c (<=/c 3)))
  (ctest #f trust/not-stronger? (sequence/c (<=/c 3)) (sequence/c (<=/c 3) #:min-count 5))
  (ctest #t trust/not-stronger? (sequence/c (<=/c 3) #:min-count 5) (sequence/c (<=/c 3) #:min-count 4))
  (ctest #f trust/not-stronger? (sequence/c (<=/c 3) #:min-count 4) (sequence/c (<=/c 3) #:min-count 5))

  (ctest #t trust/not-stronger? (parametric->/c (x) (-> x x)) (parametric->/c (x) (-> x (or/c x #f))))
  (ctest #t trust/not-stronger? (parametric->/c (x) (-> x x)) (parametric->/c (x) (-> x (first-or/c x #f))))
  (ctest #f trust/not-stronger? (parametric->/c (x y) (-> x y)) (parametric->/c (x y) (-> x x y)))
  (contract-eval `(define α (new-∀/c)))
  (ctest #t trust/not-stronger? (-> α α) (-> α (or/c #f α)))
  (ctest #f trust/not-stronger? (-> α (or/c #f α)) (-> α α))
  (ctest #t trust/not-stronger? (-> α α) (-> α (first-or/c #f α)))
  (ctest #f trust/not-stronger? (-> α (first-or/c #f α)) (-> α α))

  (ctest #t trust/not-stronger?
         (class/c (m (-> any/c (<=/c 3))))
         (class/c (m (-> any/c (<=/c 4)))))
  (ctest #f trust/not-stronger?
         (class/c (m (-> any/c (<=/c 4))))
         (class/c (m (-> any/c (<=/c 3)))))
  (ctest #t trust/not-stronger?
         (class/c (field [f integer?]))
         (class/c (field [f integer?])))
  (ctest #f trust/not-stronger?
         (class/c (field [f (<=/c 3)]))
         (class/c (field [f (<=/c 4)])))
  (ctest #f trust/not-stronger?
         (class/c (field [f (<=/c 4)]))
         (class/c (field [f (<=/c 3)])))
  (ctest #t trust/not-stronger?
         (class/c (init [f (<=/c 3)]))
         (class/c (init [f (<=/c 4)])))
  (ctest #f trust/not-stronger?
         (class/c (init [f (<=/c 4)]))
         (class/c (init [f (<=/c 3)])))
  (ctest #t trust/not-stronger?
         (class/c (inherit [m (-> any/c (<=/c 3))]))
         (class/c (inherit [m (-> any/c (<=/c 4))])))
  (ctest #f trust/not-stronger?
         (class/c (inherit [m (-> any/c (<=/c 4))]))
         (class/c (inherit [m (-> any/c (<=/c 3))])))
  (ctest #t trust/not-stronger?
         (class/c (super [m (-> any/c (<=/c 3))]))
         (class/c (super [m (-> any/c (<=/c 4))])))
  (ctest #f trust/not-stronger?
         (class/c (super [m (-> any/c (<=/c 4))]))
         (class/c (super [m (-> any/c (<=/c 3))])))
  (ctest #t trust/not-stronger?
         (class/c (inner [m (-> any/c (<=/c 3))]))
         (class/c (inner [m (-> any/c (<=/c 4))])))
  (ctest #f trust/not-stronger?
         (class/c (inner [m (-> any/c (<=/c 4))]))
         (class/c (inner [m (-> any/c (<=/c 3))])))
  (ctest #t trust/not-stronger?
         (class/c (override [m (-> any/c (<=/c 3))]))
         (class/c (override [m (-> any/c (<=/c 4))])))
  (ctest #f trust/not-stronger?
         (class/c (override [m (-> any/c (<=/c 4))]))
         (class/c (override [m (-> any/c (<=/c 3))])))
  (ctest #t trust/not-stronger?
         (class/c (augment [m (-> any/c (<=/c 3))]))
         (class/c (augment [m (-> any/c (<=/c 4))])))
  (ctest #f trust/not-stronger?
         (class/c (augment [m (-> any/c (<=/c 4))]))
         (class/c (augment [m (-> any/c (<=/c 3))])))
  (ctest #t trust/not-stronger?
         (class/c (augride [m (-> any/c (<=/c 3))]))
         (class/c (augride [m (-> any/c (<=/c 4))])))
  (ctest #f trust/not-stronger?
         (class/c (augride [m (-> any/c (<=/c 4))]))
         (class/c (augride [m (-> any/c (<=/c 3))])))
  (ctest #t trust/not-stronger?
         (class/c (absent m n))
         (class/c (absent m)))
  (ctest #f trust/not-stronger?
         (class/c (absent m))
         (class/c (absent m n)))
  (ctest #t trust/not-stronger?
         (class/c (absent (field f g)))
         (class/c (absent (field f))))
  (ctest #f trust/not-stronger?
         (class/c (absent (field f)))
         (class/c (absent (field f g))))
  (ctest #f trust/not-stronger?
         (class/c (absent (field x)))
         (class/c (absent x)))
  (ctest #f trust/not-stronger?
         (class/c (absent x))
         (class/c (absent (field x))))

  (ctest #t trust/not-stronger?
         (instanceof/c (class/c (m (-> any/c (<=/c 3)))))
         (instanceof/c (class/c (m (-> any/c (<=/c 4))))))
  (ctest #f trust/not-stronger?
         (instanceof/c (class/c (m (-> any/c (<=/c 4)))))
         (instanceof/c (class/c (m (-> any/c (<=/c 3))))))

  (ctest #t trust/not-stronger?
         (object/c (m (-> any/c (<=/c 3))))
         (object/c (m (-> any/c (<=/c 4)))))
  (ctest #t trust/not-stronger?
         (object/c (field (f (<=/c 4))))
         (object/c (field (f (<=/c 4)))))
  (ctest #t trust/not-stronger?
         (object/c (field (f (<=/c 4))))
         (object/c))
  (ctest #t trust/not-stronger?
         (object/c (m (-> any/c (<=/c 3)))
                   (n (-> any/c any/c)))
         (object/c (m (-> any/c (<=/c 4)))))
  (ctest #f trust/not-stronger?
         (object/c (m (-> any/c (<=/c 4))))
         (object/c (m (-> any/c (<=/c 3)))))
  (ctest #f trust/not-stronger?
         (object/c (field (f (<=/c 4))))
         (object/c (field (f (<=/c 3)))))
  (ctest #f trust/not-stronger?
         (object/c (m (-> any/c (<=/c 3))))
         (object/c (n (-> any/c (<=/c 4)))))
  (ctest #f trust/not-stronger?
         (object/c (field (x any/c)))
         (object/c (field (y any/c))))
  (ctest #f trust/not-stronger?
         (object/c (m (-> any/c (<=/c 4))))
         (object/c (m (-> any/c (<=/c 3)))
                   (n (-> any/c any/c))))

  (ctest #t trust/not-stronger? (is-a?/c object%) (is-a?/c object%))
  (ctest #t trust/not-stronger? (is-a?/c (class object% (super-new))) (is-a?/c object%))
  (ctest #f trust/not-stronger? (is-a?/c object%) (is-a?/c (class object% (super-new))))
  (contract-eval `(define one-interface<%> (interface ())))
  (contract-eval `(define another-interface<%> (interface (one-interface<%>))))
  (ctest #t trust/not-stronger? (is-a?/c another-interface<%>) (is-a?/c one-interface<%>))
  (ctest #f trust/not-stronger? (is-a?/c one-interface<%>) (is-a?/c another-interface<%>))
  (ctest #t trust/not-stronger?
         (is-a?/c (class* object% (one-interface<%>) (super-new)))
         (is-a?/c one-interface<%>))
  (ctest #f trust/not-stronger?
         (is-a?/c one-interface<%>)
         (is-a?/c (class* object% (one-interface<%>) (super-new))))

  (ctest #t trust/not-stronger? (subclass?/c (class object% (super-new))) (subclass?/c object%))
  (ctest #f trust/not-stronger? (subclass?/c object%) (subclass?/c (class object% (super-new))))
  (ctest #t trust/not-stronger?
         (implementation?/c another-interface<%>)
         (implementation?/c one-interface<%>))
  (ctest #f trust/not-stronger?
         (implementation?/c one-interface<%>)
         (implementation?/c another-interface<%>))

  (ctest #t trust/not-stronger? (evt/c integer?) (evt/c integer?))
  (ctest #f trust/not-stronger? (evt/c integer?) (evt/c boolean?))

  (ctest #t trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))))
  (ctest #f trust/not-stronger?
         (case-> (-> (integer-in 0 10) boolean? (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))))
  (ctest #f trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 1 5) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))))
  (ctest #t trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 1 5) (integer-in 0 10))))
  (ctest #t trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 1 5)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))))
  (ctest #f trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 1 5))))
  (ctest #t trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                 (-> (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                 (-> (integer-in 0 10) (integer-in 0 10))))
  (ctest #t trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                 (-> (integer-in 0 10) (integer-in 1 5)))
         (case-> (-> (integer-in 0 10) (integer-in 1 5) (integer-in 0 10))
                 (-> (integer-in 0 10) (integer-in 0 10))))
  (ctest #f trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 1 5) (integer-in 0 10))
                 (-> (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                 (-> (integer-in 0 10) (integer-in 1 5))))
  (ctest #f trust/not-stronger?
         (case->m (-> (integer-in 0 10) (integer-in 1 5) (integer-in 0 10))
                  (-> (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                 (-> (integer-in 0 10) (integer-in 1 5))))
  (ctest #t trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 0 10) any)
                 (-> (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) any)
                 (-> (integer-in 0 10) (integer-in 0 10))))
  (ctest #f trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 0 10) any)
                 (-> (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                 (-> (integer-in 0 10) (integer-in 0 10))))
  (ctest #t trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                 (-> (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) any)
                 (-> (integer-in 0 10) (integer-in 0 10))))
  (ctest #t trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (values (integer-in 0 10) (integer-in 1 11)))
                 (-> (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) any)
                 (-> (integer-in 0 10) (integer-in 0 10))))
  (ctest #f trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 0 10) any)
                 (-> (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 0 10) (values (integer-in 0 10) (integer-in 1 11)))
                 (-> (integer-in 0 10) (integer-in 0 10))))
  (ctest #f trust/not-stronger?
         (case-> (-> any/c (integer-in 0 10) (integer-in 0 10) (values (integer-in 0 10) (integer-in 1 11)))
                 (-> (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> (integer-in 0 10) (integer-in 1 5) (integer-in 1 10))
                 (-> (integer-in 0 10) (integer-in 0 10))))
  (ctest #f trust/not-stronger?
         (case-> (-> (integer-in 0 10) (integer-in 1 5) (integer-in 1 10))
                 (-> (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> any/c (integer-in 0 10) (integer-in 0 10) (values (integer-in 0 10) (integer-in 1 11)))
                 (-> (integer-in 0 10) (integer-in 0 10))))
  (ctest #t trust/not-stronger?
         (case->m (->       (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                  (->       (integer-in 0 10) (integer-in 1 5)))
         (case->  (-> any/c (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                  (-> any/c (integer-in 0 10) (integer-in 1 5))))
  (ctest #t trust/not-stronger?
         (case-> (-> any/c (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                 (-> any/c (integer-in 0 10) (integer-in 1 5)))
         (case->m (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                  (-> (integer-in 0 10) (integer-in 0 10))))
  (ctest #t trust/not-stronger?
         (case->m (->       (integer-in 0 10) (integer-in 0 10) (integer-in 1 5))
                  (->       (integer-in 0 10) (integer-in 0 10)))
         (case->  (-> any/c (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                  (-> any/c (integer-in 0 10) (integer-in 0 10))))
  (ctest #f trust/not-stronger?
         (case-> (-> any/c (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                 (-> any/c (integer-in 0 10) (integer-in 1 5)))
         (case->m (-> (integer-in 0 10) (integer-in 0 10) (integer-in 1 5))
                  (-> (integer-in 0 10) (integer-in 0 10))))
  (ctest #f trust/not-stronger?
         (case->m (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                  (-> (integer-in 0 10) (integer-in 0 10)))
         (case-> (-> any/c (integer-in 0 10) (integer-in 0 10) (integer-in 1 5))
                 (-> any/c (integer-in 0 10) (integer-in 1 5))))
  (ctest #t trust/not-stronger?
         (case-> (-> any/c (integer-in 0 10) (integer-in 0 10) (integer-in 1 5))
                 (-> any/c (integer-in 0 10) (integer-in 1 5)))
         (case->m (-> (integer-in 0 10) (integer-in 0 10) (integer-in 0 10))
                  (-> (integer-in 0 10) (integer-in 0 10))))

  ;; chances are, this predicate will accept "x", but
  ;; we don't want to consider it stronger, since it
  ;; will not always accept "x".
  (ctest #f trust/not-stronger? "x" (λ (x) (not (zero? (random 10000)))))

  (contract-eval
   `(let ()
      (define (non-zero? x) (not (zero? x)))
      (define list-of-numbers
        (or/c null?
              (couple/c number?
                        (recursive-contract list-of-numbers))))
      (define (short-list/less-than n)
        (or/c null?
              (couple/c (<=/c n)
                        (or/c null?
                              (couple/c (<=/c n)
                                        any/c)))))
      (define (short-sorted-list/less-than n)
        (or/c null?
              (couple/dc
               [hd (<=/c n)]
               [tl (hd) (or/c null?
                              (couple/c (<=/c hd)
                                        any/c))])))

      (define (sorted-list/less-than n)
        (or/c null?
              (couple/dc
               [hd (<=/c n)]
               [tl (hd) (sorted-list/less-than hd)])))

      ;; for some reason, the `n' makes it harder to optimize.
      ;; without it, this test isn't as good a test
      (define (closure-comparison-test n)
        (couple/dc
         [hd any/c]
         [tl (hd) any/c]))

      (,test #t trust/not-stronger? (couple/c any/c any/c) (couple/c any/c any/c))
      (,test #f trust/not-stronger? (couple/c (>=/c 2) (>=/c 3)) (couple/c (>=/c 4) (>=/c 5)))
      (,test #t trust/not-stronger? (couple/c (>=/c 4) (>=/c 5)) (couple/c (>=/c 2) (>=/c 3)))
      (,test #f trust/not-stronger? (couple/c (>=/c 1) (>=/c 5)) (couple/c (>=/c 5) (>=/c 1)))
      (let ([ctc (couple/dc [hd any/c] [tl (hd) any/c])])
        (,test #t trust/not-stronger? ctc ctc))
      (let ([ctc (couple/dc [hd any/c] [tl (hd) (<=/c hd)])])
        (,test #t trust/not-stronger? ctc ctc))
      (,test #t trust/not-stronger? list-of-numbers list-of-numbers)
      (,test #t trust/not-stronger? (short-list/less-than 4) (short-list/less-than 5))
      (,test #f trust/not-stronger? (short-list/less-than 5) (short-list/less-than 4))
      (,test #t trust/not-stronger? (short-sorted-list/less-than 4) (short-sorted-list/less-than 5))
      (,test #f trust/not-stronger? (short-sorted-list/less-than 5) (short-sorted-list/less-than 4))
      (,test #t trust/not-stronger? (sorted-list/less-than 4) (sorted-list/less-than 5))
      (,test #f trust/not-stronger? (sorted-list/less-than 5) (sorted-list/less-than 4))
      (,test #t trust/not-stronger? (closure-comparison-test 4) (closure-comparison-test 5))

      (letrec ([mk-c
                (λ (x)
                  (triple/dc [a (<=/c x)]
                             [b any/c]
                             [c (a b) (or/c #f (mk-c a))]))])
        (,test #t trust/not-stronger? (mk-c 1) (mk-c 2)))))

  (contract-eval
   `(let ()
      (define (non-zero? x) (not (zero? x)))
      (define list-of-numbers
        (first-or/c null?
               (couple/c number?
                         (recursive-contract list-of-numbers))))
      (define (short-list/less-than n)
        (first-or/c null?
              (couple/c (<=/c n)
                        (first-or/c null?
                              (couple/c (<=/c n)
                                        any/c)))))
      (define (short-sorted-list/less-than n)
        (first-or/c null?
              (couple/dc
               [hd (<=/c n)]
               [tl (hd) (first-or/c null?
                              (couple/c (<=/c hd)
                                        any/c))])))

      (define (sorted-list/less-than n)
        (first-or/c null?
              (couple/dc
               [hd (<=/c n)]
               [tl (hd) (sorted-list/less-than hd)])))

      ;; for some reason, the `n' makes it harder to optimize.
      ;; without it, this test isn't as good a test
      (define (closure-comparison-test n)
        (couple/dc
         [hd any/c]
         [tl (hd) any/c]))

      (,test #t trust/not-stronger? (couple/c any/c any/c) (couple/c any/c any/c))
      (,test #f trust/not-stronger? (couple/c (>=/c 2) (>=/c 3)) (couple/c (>=/c 4) (>=/c 5)))
      (,test #t trust/not-stronger? (couple/c (>=/c 4) (>=/c 5)) (couple/c (>=/c 2) (>=/c 3)))
      (,test #f trust/not-stronger? (couple/c (>=/c 1) (>=/c 5)) (couple/c (>=/c 5) (>=/c 1)))
      (let ([ctc (couple/dc [hd any/c] [tl (hd) any/c])])
        (,test #t trust/not-stronger? ctc ctc))
      (let ([ctc (couple/dc [hd any/c] [tl (hd) (<=/c hd)])])
        (,test #t trust/not-stronger? ctc ctc))
      (,test #t trust/not-stronger? list-of-numbers list-of-numbers)
      (,test #t trust/not-stronger? (short-list/less-than 4) (short-list/less-than 5))
      (,test #f trust/not-stronger? (short-list/less-than 5) (short-list/less-than 4))
      (,test #t trust/not-stronger? (short-sorted-list/less-than 4) (short-sorted-list/less-than 5))
      (,test #f trust/not-stronger? (short-sorted-list/less-than 5) (short-sorted-list/less-than 4))
      (,test #t trust/not-stronger? (sorted-list/less-than 4) (sorted-list/less-than 5))
      (,test #f trust/not-stronger? (sorted-list/less-than 5) (sorted-list/less-than 4))
      (,test #t trust/not-stronger? (closure-comparison-test 4) (closure-comparison-test 5))

      (letrec ([mk-c
                (λ (x)
                  (triple/dc [a (<=/c x)]
                             [b any/c]
                             [c (a b) (or/c #f (mk-c a))]))])
        (,test #t trust/not-stronger? (mk-c 1) (mk-c 2)))))


  (contract-eval
   `(let ()

      (struct s (a b))
      (struct t (a b))

      (,test #f trust/not-stronger?
             (struct/dc s
                        [a (>=/c 1)]
                        [b (>=/c 2)])
             (struct/dc s
                        [a (>=/c 2)]
                        [b (>=/c 3)]))
      (,test #t trust/not-stronger?
              (struct/dc s
                         [a (>=/c 2)]
                         [b (>=/c 3)])
              (struct/dc s
                         [a (>=/c 1)]
                         [b (>=/c 2)]))

      (,test #f trust/not-stronger?
             (struct/dc s
                    [a number?]
                    [b number?])
             (struct/dc t
                        [a number?]
                        [b number?]))

      (,test #f trust/not-stronger?
             (struct/dc t
                        [a number?]
                        [b number?])
             (struct/dc s
                        [a number?]
                        [b number?]))

      (,test #f
             trust/not-stronger?
             (struct/dc s
                        [a integer?]
                        [b integer?])
             (struct/dc s
                        [a integer?]
                        [b integer?]
                        #:inv (a b) #f))

      (,test #t
             trust/not-stronger?
             (struct/dc s
                        [a integer?]
                        [b integer?]
                        #:inv (a b) #f)
             (struct/dc s
                        [a integer?]
                        [b integer?]))


      (define (mk c)
        (struct/dc s
                   [a (>=/c c)]
                   [b (a) (>=/c a)]))
      (set! mk mk) ;suppress inlining
      (define one (mk 1))
      (define two (mk 2))
      (,test #f trust/not-stronger? one two)
      (,test #t trust/not-stronger? two one)))

  (contract-eval
   `(define imp-ctc
      (make-contract
       #:late-neg-projection (λ (blame) (λ (val neg) (add1 val))))))
  (contract-eval
   `(define imp-struct-ctc
      (let ()
        (struct imp-ctc-struct ()
          #:property prop:contract
          (build-contract-property
           #:late-neg-projection
           (λ (ctc)
             (λ (blame)
               (λ (val neg)
                 (add1 val))))))
        (imp-ctc-struct))))

  (ctest #f trust/not-stronger? imp-ctc imp-ctc)
  (ctest #f trust/not-stronger? imp-struct-ctc imp-struct-ctc))
