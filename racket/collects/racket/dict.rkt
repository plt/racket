#lang racket/base
(require racket/contract/base
         "private/dict.rkt"
         "private/dict-contracts.rkt"
         "private/keyword-apply-dict.rkt"
         "private/custom-hash.rkt")

(define (dict-implements/c . syms)
  (if (null? syms)
      dict?
      (flat-named-contract
        `(dict-implements/c . ,syms)
        (lambda (x)
          (and (dict? x)
               (for/and ([sym (in-list syms)])
                 (dict-implements? x sym)))))))

(define dict-method-name/c
  (or/c 'dict-ref
        'dict-set!
        'dict-set
        'dict-remove!
        'dict-remove
        'dict-count
        'dict-iterate-first
        'dict-iterate-next
        'dict-iterate-key
        'dict-iterate-value
        'dict-has-key?
        'dict-ref!
        'dict-set*!
        'dict-set*
        'dict-update!
        'dict-update
        'dict-map
        'dict-for-each
        'dict-keys
        'dict-values
        'dict->list
        'dict-copy
        'dict-empty?
        'dict-clear
        'dict-clear!))

;; ----------------------------------------

(define-values (prop:dict/c dict/c-struct? dict/c-struct-ref)
  (make-struct-type-property 'dict/c #f))

(define-values (prop:dict/contract dict/contract? dict/contract-ref)
  (make-struct-type-property 'dict/contract #f
                             (list (cons prop:dict car)
                                   (cons prop:dict/c cadr))))

;; ----------------------------------------

(define (get-dict/c-type-key-c v)
  (vector-ref v 0))
(define (get-dict/c-type-value-c v)
  (vector-ref v 1))
(define (get-dict/c-type-iter-c v)
  (vector-ref v 2))
(define (get-dict/c-inst-key-c v)
  (vector-ref v 3))
(define (get-dict/c-inst-value-c v)
  (vector-ref v 4))
(define (get-dict/c-inst-iter-c v)
  (vector-ref v 5))

;; ----------------------------------------

(define (dict-key-contract d)
  (if (dict/c-struct? d)
      (let* ([cv (dict/c-struct-ref d)]
             [type-key-contract (get-dict/c-type-key-c cv)]
             [get-inst-key-contract (get-dict/c-inst-key-c cv)])
        (if get-inst-key-contract
            (and/c type-key-contract (get-inst-key-contract d))
            type-key-contract))
      (if (vector? d)
          exact-nonnegative-integer?
          any/c)))

(define (dict-value-contract d)
  (if (dict/c-struct? d)
      (let* ([cv (dict/c-struct-ref d)]
             [type-value-contract (get-dict/c-type-value-c cv)]
             [get-inst-value-contract (get-dict/c-inst-value-c cv)])
        (if get-inst-value-contract
            (and/c type-value-contract (get-inst-value-contract d))
            type-value-contract))
      any/c))

(define (dict-iter-contract d)
  (if (dict/c-struct? d)
      (let* ([cv (dict/c-struct-ref d)]
             [type-iter-contract (get-dict/c-type-iter-c cv)]
             [get-inst-iter-contract (get-dict/c-inst-iter-c cv)])
        (if get-inst-iter-contract
            (and/c type-iter-contract (get-inst-iter-contract d))
            type-iter-contract))
      any/c))

;; ----------------------------------------

(define dict-ref-contract
  (->i ([d dict?] [k (d) (dict-key-contract d)])
       ([default any/c])
       any)) ;; because default can be multi-valued procedure
(define dict-set!-contract
  (->i ([d (dict-implements/c 'dict-set!)]
        [k (d) (dict-key-contract d)]
        [value (d) (dict-value-contract d)])
       [_r void?]))
(define dict-set-contract
  (->i ([d (dict-implements/c 'dict-set)]
        [k (d) (dict-key-contract d)]
        [value (d) (dict-value-contract d)])
       [_r dict?]))
(define dict-remove!-contract
  (->i ([d (dict-implements/c 'dict-remove!)]
        [k (d) (dict-key-contract d)])
       [_r void?]))
(define dict-remove-contract
  (->i ([d (dict-implements/c 'dict-remove)]
        [k (d) (dict-key-contract d)])
       [_r dict?]))
(define dict-count-contract
  (-> dict? exact-nonnegative-integer?))
(define dict-iterate-first-contract
  (->i ([d dict?]) [_r (d) (or/c #f (dict-iter-contract d))]))
(define dict-iterate-next-contract
  (->i ([d dict?] [iter (d) (dict-iter-contract d)])
       [_r (d) (or/c #f (dict-iter-contract d))]))
(define dict-iterate-key-contract
  (->i ([d dict?] [iter (d) (dict-iter-contract d)])
       [_r (d) (dict-key-contract d)]))
(define dict-iterate-value-contract
  (->i ([d dict?] [iter (d) (dict-iter-contract d)])
       [_r (d) (dict-value-contract d)]))

(define prop:dict-contract
  (vector-immutable/c dict-ref-contract
                      (or/c #f dict-set!-contract)
                      (or/c #f dict-set-contract)
                      (or/c #f dict-remove!-contract)
                      (or/c #f dict-remove-contract)
                      dict-count-contract
                      dict-iterate-first-contract
                      dict-iterate-next-contract
                      dict-iterate-key-contract
                      dict-iterate-value-contract))

(define prop:dict/c-contract
  (vector-immutable/c contract?
                      contract?
                      contract?
                      (or/c #f (-> dict? contract?))
                      (or/c #f (-> dict? contract?))
                      (or/c #f (-> dict? contract?))))

(define (even-length-list? l) (even? (length l)))

;; ----------------------------------------

(provide/contract
 [prop:dict/contract
  (struct-type-property/c
   (list/c prop:dict-contract
           prop:dict/c-contract))]

 [dict?
  (-> any/c boolean?)]
 [dict-mutable?
  (-> dict? boolean?)]
 [dict-can-remove-keys?
  (-> dict? boolean?)]
 [dict-can-functional-set?
  (-> dict? boolean?)]

 [dict-has-key?
  (-> dict? any/c boolean?)]
 [dict-ref
  dict-ref-contract]
 [dict-ref!
  (->i ([d (dict-implements/c 'dict-set!)]
        [k (d) (dict-key-contract d)]
        [default (d) (or/c (dict-value-contract d) (-> (dict-value-contract d)))]) ;; use if/c ?
       [_r (d) (dict-value-contract d)])]
 [dict-set!
  dict-set!-contract]
 [dict-set
  dict-set-contract]
 [dict-set*!
  (->i ([d (dict-implements/c 'dict-set!)])
       #:rest [rst (d) (let ([key/c (dict-key-contract d)]
                             [val/c (dict-value-contract d)])
                         (letrec ([args/c
                                   (recursive-contract
                                    (or/c null
                                          (cons/c key/c (cons/c val/c args/c))))])
                           (and/c even-length-list?
                                  args/c)))]
       [_r void?])]
 [dict-set*
  (->i ([d (dict-implements/c 'dict-set)])
       #:rest [rst (d) (let ([key/c (dict-key-contract d)]
                             [val/c (dict-value-contract d)])
                         (letrec ([args/c
                                   (recursive-contract
                                    (or/c null
                                          (cons/c key/c (cons/c val/c args/c))))])
                           (and/c even-length-list?
                                  args/c)))]
       [_r dict?])]
 [dict-update!
  (->i ([d (dict-implements/c 'dict-set!)]
        [k (d) (dict-key-contract d)]
        [update (d) (-> (dict-value-contract d) (dict-value-contract d))])
       ([default (d) (or/c (dict-value-contract d) (-> (dict-value-contract d)))]) ;; use if/c
       [_r void?])]
 [dict-update
  (->i ([d (dict-implements/c 'dict-set)]
        [k (d) (dict-key-contract d)]
        [update (d) (-> (dict-value-contract d) (dict-value-contract d))])
       ([default (d) (or/c (dict-value-contract d) (-> (dict-value-contract d)))]) ;; use if/c ?
       [_r dict?])]
 [dict-remove!
  dict-remove!-contract]
 [dict-remove
  dict-remove-contract]
 [dict-count
  dict-count-contract]
 [dict-iterate-first
  dict-iterate-first-contract]
 [dict-iterate-next
  dict-iterate-next-contract]
 [dict-iterate-key
  dict-iterate-key-contract]
 [dict-iterate-value
  dict-iterate-value-contract]

 [dict-map
  (->i ([d dict?] [proc (d) (-> (dict-key-contract d) (dict-value-contract d) any)])
       [_r list?])]
 [dict-for-each
  (->i ([d dict?] [proc (d) (-> (dict-key-contract d) (dict-value-contract d) any)])
       [_r void?])]
 [dict-map/copy
  (->i ([d dict?]
        [proc (d) (-> (dict-key-contract d) (dict-value-contract d)
                      (values (dict-key-contract d) (dict-value-contract d)))])
       [_r dict?])]

 [dict-keys
  (->i ([d dict?])
       [_r (d) (listof (dict-key-contract d))])]
 [dict-values
  (->i ([d dict?])
       [_r (d) (listof (dict-value-contract d))])]
 [dict->list
  (->i ([d dict?])
       [_r (d) (listof (cons/c (dict-key-contract d) (dict-value-contract d)))])]

 [dict-empty? (-> dict? boolean?)]
 [dict-copy (-> dict? dict?)]
 [dict-clear
  (->i ([d dict?])
       [_r (d) (apply dict-implements/c
                      (for/list ([sym (in-list '(dict-set dict-set!))]
                                 #:when (dict-implements? d sym))
                        sym))])]
 [dict-clear!
  (->i ([d (dict-implements/c 'dict-remove!)])
       [_r void?]
       #:post (d) (dict-empty? d))]

 [dict-implements?
  (->* [dict?] [] #:rest (listof dict-method-name/c) boolean?)]
 [dict-implements/c
  (->* [] [] #:rest (listof dict-method-name/c) flat-contract?)]


 [dict-mutability/c
   (-> boolean? (-> any/c boolean?))]
 [dict-immutability/c
  (-> boolean? (-> any/c boolean?))]
 [homogeneous-dictof
  (-> flat-contract? flat-contract? (-> any/c boolean?))]
 [heterogeneous-dictof
  (->* () (#:mandatory-keys? boolean?
           #:exact-keys? boolean?
           #:immutable? boolean?)
       #:rest (and/c (lambda (x) (even? (length x)))
                     (listof flat-contract?))
       (-> any/c boolean?))])

(provide gen:dict
         prop:dict

         make-custom-hash
         make-immutable-custom-hash
         make-weak-custom-hash
         make-custom-hash-types
         define-custom-hash-types

         in-dict
         in-dict-keys
         in-dict-values
         in-dict-pairs

         keyword-apply/dict

         dict-key-contract
         dict-value-contract
         dict-iter-contract)
