#lang racket/base

(require "test-util.rkt")

(parameterize ([current-contract-namespace
                (make-basic-contract-namespace 
                 'racket/contract
                 'racket/promise
                 'racket/class
                 'racket/sequence)])

  (contract-eval '(define-contract-struct couple (hd tl)))
  
  (ctest #t contract-first-order-passes? (flat-contract integer?) 1)
  (ctest #f contract-first-order-passes? (flat-contract integer?) 'x)
  (ctest #t contract-first-order-passes? (flat-contract boolean?) #t)
  (ctest #f contract-first-order-passes? (flat-contract boolean?) 'x)
  (ctest #t contract-first-order-passes? any/c 1)
  (ctest #t contract-first-order-passes? any/c #t)
  (ctest #t contract-first-order-passes? (-> integer? integer?) (λ (x) #t))
  (ctest #f contract-first-order-passes? (-> integer? integer?) (λ (x y) #t))
  (ctest #f contract-first-order-passes? (-> integer? integer?) 'x)
  (ctest #t contract-first-order-passes? (-> integer? boolean? integer?) (λ (x y) #t))
  (ctest #f contract-first-order-passes? (-> integer? boolean? integer?) (λ (x) #t))
  (ctest #f contract-first-order-passes? (-> integer? boolean? integer?) (λ (x y z) #t))
  (ctest #f contract-first-order-passes? (-> integer? boolean? #:x integer? integer?) (λ (x y) #t))
  (ctest #t contract-first-order-passes? 
         (-> integer? boolean? #:x integer? integer?)
         (λ (x y #:x z) #t))

  (ctest #t contract-first-order-passes? 
         (->* (integer?) () #:rest any/c (values char? any/c))
         (λ (x . y) #f))
  (ctest #f contract-first-order-passes? 
         (->* (integer?) () #:rest any/c (values char? any/c))
         (λ (x y . z) #f))
  (ctest #f contract-first-order-passes?
         (->* (integer?) () #:rest any/c (values char? any/c))
         (λ (x) #f))
  (ctest #t contract-first-order-passes? 
         (->* (integer?) () #:rest any/c (values char? any/c))
         (λ x #f))

  (ctest #t contract-first-order-passes? (->d ((z any/c)) () (result any/c)) (λ (x) x))
  (ctest #f contract-first-order-passes? (->d ((z any/c)) () (result any/c)) (λ (x y) x))

  (ctest #t contract-first-order-passes? (->i ((z any/c)) () (result any/c)) (λ (x) x))
  (ctest #f contract-first-order-passes? (->i ((z any/c)) () (result any/c)) (λ (x y) x))

  (ctest #t contract-first-order-passes? (listof integer?) (list 1))
  (ctest #f contract-first-order-passes? (listof integer?) #f)

  (ctest #f contract-first-order-passes? (list/c #f #f #t) (list))
  (ctest #t contract-first-order-passes? (list/c #f 'x #t) (list #f 'x #t))
  (ctest #f contract-first-order-passes? (list/c (-> number? number?)) (list (λ (x y) x)))
  (ctest #t contract-first-order-passes? (list/c (-> number? number?)) (list (λ (x) x)))

  (ctest #t contract-first-order-passes? (non-empty-listof integer?) (list 1))
  (ctest #f contract-first-order-passes? (non-empty-listof integer?) (list))

  (ctest #t contract-first-order-passes? (*list/c integer? boolean? char?) '(1 2 3 4 #f #\a))
  (ctest #t contract-first-order-passes? (*list/c integer? boolean? char?) '(#f #\a))
  (ctest #f contract-first-order-passes? (*list/c integer? boolean? char?) '(1 2 #f 4 #f #\a))
  (ctest #f contract-first-order-passes? (*list/c integer? boolean? char?) '())
  (ctest #f contract-first-order-passes? (*list/c integer? boolean? char?) '(#f))
  (ctest #f contract-first-order-passes? (*list/c integer? boolean? char?) 1)
  
  (ctest #t contract-first-order-passes?
         (vector-immutableof integer?)
         (vector->immutable-vector (vector 1)))
  (ctest #f contract-first-order-passes? (vector-immutableof integer?) 'x)
  (ctest #f contract-first-order-passes? (vector-immutableof integer?) '())

  (ctest #t contract-first-order-passes? (promise/c integer?) (delay 1))
  (ctest #f contract-first-order-passes? (promise/c integer?) 1)

  (ctest #t contract-first-order-passes? 
         (and/c (-> positive? positive?) (-> integer? integer?))
         (λ (x) x))
  (ctest #t contract-first-order-passes?
         (and/c (-> positive? positive?) (-> integer? integer?))
         values)
  (ctest #f contract-first-order-passes? (and/c (-> integer?) (-> integer? integer?)) (λ (x) x))

  (ctest #t contract-first-order-passes?
        (cons/c boolean? (-> integer? integer?))
        (list* #t (λ (x) x)))
  (ctest #f contract-first-order-passes?
        (cons/c boolean? (-> integer? integer?))
        (list* 1 2))

  (ctest #f contract-first-order-passes? (flat-rec-contract the-name) 1)

  (ctest #f contract-first-order-passes?
         (flat-murec-contract ([one 1]) one)
         0)
  (ctest #t contract-first-order-passes?
         (flat-murec-contract ([one 1]) one)
         1)

  (ctest #t contract-first-order-passes?
         (couple/c any/c any/c)
         (make-couple 1 2))

  (ctest #f contract-first-order-passes?
         (couple/c any/c any/c)
         2)

  (ctest #t contract-first-order-passes?
         (couple/dc [hd any/c] [tl any/c])
         (make-couple 1 2))

  (ctest #f contract-first-order-passes?
         (couple/dc [hd any/c] [tl any/c])
         1)

  (ctest #t contract-first-order-passes?
         (couple/dc [hd any/c] [tl (hd) any/c])
         (make-couple 1 2))

  (ctest #f contract-first-order-passes?
         (couple/dc [hd any/c] [tl (hd) any/c])
         1)

  (ctest #t contract-first-order-passes? (or/c (-> (>=/c 5) (>=/c 5)) boolean?) #t)
  (ctest #t contract-first-order-passes? (or/c (-> (>=/c 5) (>=/c 5)) boolean?) (λ (x) x))
  (ctest #f contract-first-order-passes? (or/c (-> (>=/c 5) (>=/c 5)) boolean?) 'x)

  (ctest #t contract-first-order-passes?
        (or/c (-> integer? integer? integer?)
              (-> integer? integer?))
        (λ (x) x))
  (ctest #t contract-first-order-passes?
        (or/c (-> integer? integer? integer?)
              (-> integer? integer?))
        (λ (x y) x))
  (ctest #f contract-first-order-passes?
        (or/c (-> integer? integer? integer?)
              (-> integer? integer?))
        (λ () x))
  (ctest #f contract-first-order-passes?
        (or/c (-> integer? integer? integer?)
              (-> integer? integer?))
        1)

  (ctest #t contract-first-order-passes? (first-or/c (-> (>=/c 5) (>=/c 5)) boolean?) #t)
  (ctest #t contract-first-order-passes? (first-or/c (-> (>=/c 5) (>=/c 5)) boolean?) (λ (x) x))
  (ctest #f contract-first-order-passes? (first-or/c (-> (>=/c 5) (>=/c 5)) boolean?) 'x)

  (ctest #t contract-first-order-passes?
         (first-or/c (-> integer? integer? integer?)
                (-> integer? integer?))
         (λ (x) x))
  (ctest #t contract-first-order-passes?
         (first-or/c (-> integer? integer? integer?)
                (-> integer? integer?))
         (λ (x y) x))
  (ctest #f contract-first-order-passes?
         (first-or/c (-> integer? integer? integer?)
                (-> integer? integer?))
         (λ () x))
  (ctest #f contract-first-order-passes?
         (first-or/c (-> integer? integer? integer?)
                (-> integer? integer?))
         1)

  (ctest #t contract-first-order-passes? (hash/c any/c any/c) (make-hash))
  (ctest #f contract-first-order-passes? (hash/c any/c any/c) #f)
  (ctest #f contract-first-order-passes? (hash/c symbol? boolean?) (let ([ht (make-hash)])
                                                                     (hash-set! ht 'x 1)
                                                                     ht))
  (ctest #f contract-first-order-passes? (hash/c symbol? boolean? #:flat? #t)
         (let ([ht (make-hash)]) (hash-set! ht 'x 1) ht))
  (ctest #f contract-first-order-passes? (hash/c symbol? boolean?) (let ([ht (make-hash)])
                                                                     (hash-set! ht 1 #f)
                                                                     ht))
  (ctest #f contract-first-order-passes? (hash/c symbol? boolean? #:flat? #t)
         (let ([ht (make-hash)]) (hash-set! ht 1 #f) ht))
  (ctest #t contract-first-order-passes? (hash/c symbol? boolean?) (let ([ht (make-hash)])
                                                                     (hash-set! ht 'x #t)
                                                                     ht))

  
  (ctest 1
        length
        (let ([f (contract (-> integer? any)
                           (lambda (x)
                             (with-continuation-mark 'x 'x
                               (continuation-mark-set->list (current-continuation-marks) 'x)))
                           'pos
                           'neg)])
          (with-continuation-mark 'x 'x
            (f 1))))

  (ctest 2
        length
        (let ([f (contract (-> integer? list?)
                           (lambda (x)
                             (with-continuation-mark 'x 'x
                               (continuation-mark-set->list (current-continuation-marks) 'x)))
                           'pos
                           'neg)])
          (with-continuation-mark 'x 'x
            (f 1))))

  (ctest #t contract-first-order-passes? (or/c 'x "x" #rx"x") 'x)
  (ctest #t contract-first-order-passes? (or/c 'x "x" #rx"x") "x")
  (ctest #t contract-first-order-passes? (or/c 'x "x" #rx"x.") "xy")
  (ctest #f contract-first-order-passes? (or/c 'x "x" #rx"x.") "yx")
  (ctest #f contract-first-order-passes? (or/c 'x "x" #rx"x.") 'y)
  
  (ctest #t contract-first-order-passes? (first-or/c 'x "x" #rx"x") 'x)
  (ctest #t contract-first-order-passes? (first-or/c 'x "x" #rx"x") "x")
  (ctest #t contract-first-order-passes? (first-or/c 'x "x" #rx"x.") "xy")
  (ctest #f contract-first-order-passes? (first-or/c 'x "x" #rx"x.") "yx")
  (ctest #f contract-first-order-passes? (first-or/c 'x "x" #rx"x.") 'y)
  
  (ctest #f contract-first-order-passes? (->m integer? integer?) (λ (x) 1))
  (ctest #t contract-first-order-passes? (->m integer? integer?) (λ (this x) 1))
  
  (ctest #f contract-first-order-passes? (class/c) 1)
  (ctest #f contract-first-order-passes? (class/c [m (-> any/c integer? integer?)]) object%)
  (ctest #t contract-first-order-passes?
         (class/c [m (-> any/c integer? integer?)]) 
         (class object%
           (define/public (m x) x)))
  (ctest #t contract-first-order-passes?
         (class/c [m (->m integer? integer?)]) 
         (class object%
           (define/public (m x) x)))
  (ctest #f contract-first-order-passes?
         (class/c [m (-> any/c integer? integer?)]) 
         (class object%
           (define/public (m x y) x)))
  (ctest #f contract-first-order-passes?
         (class/c [m (->m integer? integer?)]) 
         (class object%
           (define/public (m x y) x)))
  
  (ctest #f contract-first-order-passes?
         (class/c [m (->m integer? integer?)]) 
         (class* object% ((interface () [m (-> any/c integer? integer? any/c)]))
           (define/public (m x y) x)))
  (ctest #t contract-first-order-passes?
         (class/c [m (-> any/c integer? integer?)]) 
         (class* object% ((interface () [m (-> any/c integer? integer?)]))
           (define/public (m x) x)))
  
  (ctest #t contract-first-order-passes?
         (sequence/c any/c)
         (list 1 2 3))
  (ctest #t contract-first-order-passes?
         (sequence/c any/c)
         (vector 1 2 3))
  (ctest #f contract-first-order-passes?
         (sequence/c any/c)
         (hash 'x 1 'y 2))
  (ctest #f contract-first-order-passes?
         (sequence/c any/c any/c)
         (list 1 2 3))
  (ctest #f contract-first-order-passes?
         (sequence/c any/c any/c)
         (vector 1 2 3))
  (ctest #t contract-first-order-passes?
         (sequence/c any/c any/c)
         (hash 'x 1 'y 2))

  (ctest #t contract-first-order-passes?
         (parametric->/c (x) (-> x x))
         (lambda (x) x))
  (ctest #f contract-first-order-passes?
         (parametric->/c (x) (-> x x))
         7)
  (ctest #f contract-first-order-passes?
         (parametric->/c (x y) (-> x y x))
         (lambda (x) x))
  )
