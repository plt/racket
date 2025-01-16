#lang racket/base

(provide
 dict-mutability/c
 dict-immutability/c
 homogeneous-dictof
 heterogeneous-dictof)

(require
 "dict.rkt"
 racket/contract/base
 "../list.rkt"
 "../set.rkt")

(define ((dict-mutability/c b) d)
  (and (dict? d)
       ((if b values not) (dict-mutable? d))))

(define (dict-immutability/c b)
  (dict-mutability/c (not b)))

;; Generalizes hash/c, but uses the same naming convention as listof and vectorof
(define ((homogeneous-dictof key-contract value-contract) d)
  (for/and ([(k c) (in-dict d)])
    (and
     (key-contract k)
     (value-contract c))))

(define (unzip-args . args)
  #;(->* () #:rest (and/c (lambda (x) (even? (length x)))
                        (listof contract?))
       (list/c (listof contract?) (listof contract?)))
  (let ([x (box 0)])
    (group-by (lambda (y)
                (begin
                  (set-box! x (add1 (unbox x)))
                  (even? (unbox x))))
              args)))

(define ((heterogeneous-dictof
                   #:mandatory-keys? [mandatory-keys? #t]
                   #:exact-keys? [exact? #f]
                   #:immutable? [immutable? #t]
                   . key-value-args) d)
  (let* ([k/v-contracts (apply unzip-args key-value-args)]
         [key-contracts (first k/v-contracts)]
         [value-contracts (second k/v-contracts)])
    (and ((dict-immutability/c immutable?) d)
         (if exact?
             (set=? (dict-keys d) key-contracts)
             #t)
         (for/and ([kc key-contracts]
                   [vc value-contracts])
           (let ([found-key (box #f)])
             (and
              (for/and ([(k v) (in-dict d)]
                       #:when ((flat-contract-predicate kc) k))
               (set-box! found-key #t)
               ((flat-contract-predicate vc) v))
              (if mandatory-keys? (unbox found-key) #t)))))))

