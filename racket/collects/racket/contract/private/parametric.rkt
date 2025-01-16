#lang racket/base
(require "prop.rkt"
         "blame.rkt"
         "guts.rkt"
         (for-syntax "arr-util.rkt" racket/base))
(provide parametric->/c)

(define-syntax (parametric->/c stx)
  (syntax-case stx ()
    [(_ [x ...] c)
     (begin
       (for ([x (in-list (syntax->list #'(x ...)))])
         (unless (identifier? x)
           (raise-syntax-error 'parametric->/c 
                               "expected an identifier"
                               stx
                               x)))
       (define dup (check-duplicate-identifier (syntax->list #'(x ...))))
       (when dup (raise-syntax-error
                  'parametric->/c 
                  "duplicate identifier"
                  stx
                  dup))
       #`(make-polymorphic-contract opaque/c
                                    '(x ...)
                                    (lambda (x ...) c)
                                    '#,(compute-quoted-src-expression #'c)))]))



(define-struct polymorphic-contract [barrier vars body body-src-exp]
  #:property prop:custom-write custom-write-property-proc
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:name
   (lambda (c)
     `(parametric->/c ,(polymorphic-contract-vars c) ,(polymorphic-contract-body-src-exp c)))
   #:first-order
   (λ (c)
      (and/c
        procedure?
        (lambda (p)
          (contract-first-order-passes?
            (apply (polymorphic-contract-body c)
              (for/list ([var (in-list (polymorphic-contract-vars c))])
                ((polymorphic-contract-barrier c) #t var)))
            p))))
   #:stronger
   (λ (this that)
     (cond
       [(polymorphic-contract? that)
        (define this-vars (polymorphic-contract-vars this))
        (define that-vars (polymorphic-contract-vars that))
        (define this-barrier/c (polymorphic-contract-barrier this))
        (define that-barrier/c (polymorphic-contract-barrier that))
        (cond
          [(and (eq? this-barrier/c that-barrier/c)
                (= (length this-vars) (length that-vars)))
           (define instances
             (for/list ([var (in-list this-vars)])
               (this-barrier/c #t var)))
           (contract-struct-stronger? (apply (polymorphic-contract-body this) instances)
                                      (apply (polymorphic-contract-body that) instances))]
          [else #f])]
       [else #f]))
   #:equivalent
   (λ (this that)
     (cond
       [(polymorphic-contract? that)
        (define this-vars (polymorphic-contract-vars this))
        (define that-vars (polymorphic-contract-vars that))
        (define this-barrier/c (polymorphic-contract-barrier this))
        (define that-barrier/c (polymorphic-contract-barrier that))
        (cond
          [(and (eq? this-barrier/c that-barrier/c)
                (= (length this-vars) (length that-vars)))
           (define instances
             (for/list ([var (in-list this-vars)])
               (this-barrier/c #t var)))
           (contract-struct-equivalent? (apply (polymorphic-contract-body this) instances)
                                        (apply (polymorphic-contract-body that) instances))]
          [else #f])]
       [else #f]))
   #:late-neg-projection
   (lambda (c)
     (lambda (orig-blame)
       (define blame (blame-add-context orig-blame #f))
       (define negative? (blame-swapped? blame))
       (define barrier/c (polymorphic-contract-barrier c))
       (define vars (polymorphic-contract-vars c))
       (define (wrap p neg-party blame+neg-party)
         (with-contract-continuation-mark
          blame+neg-party
          ;; values in polymorphic types come in from negative position,
          ;; relative to the poly/c contract
          (define instances
            (for/list ([var (in-list vars)])
              (barrier/c negative? var)))
          (define protector
            (apply (polymorphic-contract-body c) instances))
           (((get/build-late-neg-projection protector) blame) p neg-party)))

       (lambda (p neg-party)
         (unless (procedure? p)
           (raise-blame-error blame #:missing-party neg-party
                              p '(expected "a procedure" given: "~e") p))
         (define blame+neg-party (cons blame neg-party))
         (make-keyword-procedure
          (lambda (keys vals . args) (keyword-apply (wrap p neg-party blame+neg-party) keys vals args))
          (case-lambda
            [() ((wrap p neg-party blame+neg-party))]
            [(a) ((wrap p neg-party blame+neg-party) a)]
            [(a b) ((wrap p neg-party blame+neg-party) a b)]
            [(a b c) ((wrap p neg-party blame+neg-party) a b c)]
            [(a b c d) ((wrap p neg-party blame+neg-party) a b c d)]
            [(a b c d e) ((wrap p neg-party blame+neg-party) a b c d e)]
            [(a b c d e f) ((wrap p neg-party blame+neg-party) a b c d e f)]
            [(a b c d e f g) ((wrap p neg-party blame+neg-party) a b c d e f g)]
            [(a b c d e f g h) ((wrap p neg-party blame+neg-party) a b c d e f g h)]
            [args (apply (wrap p neg-party blame+neg-party) args)])))))))

(define (opaque/c positive? name)
  (define-values [ type make pred getter setter ]
    (make-struct-type name #f 1 0))
  (define get (make-struct-field-accessor getter 0))
  (make-barrier-contract name positive? make pred get))

(define-struct barrier-contract [name positive? make pred get]
  #:property prop:custom-write custom-write-property-proc
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:name (lambda (c) (barrier-contract-name c))
   #:first-order (λ (c) (barrier-contract-pred c))
   #:stronger (λ (this that) (eq? this that))
   #:equivalent (λ (this that) (eq? this that))
   #:late-neg-projection
   (lambda (c)
     (define mk (barrier-contract-make c))
     (define (mk-np x neg-party) (mk x))
     (define pred (barrier-contract-pred c))
     (define get (barrier-contract-get c))
     (define cp? (barrier-contract-positive? c))
     (lambda (blame)
       (if (equal? (blame-original? blame) cp?)
           mk-np
           (lambda (x neg-party)
             (if (pred x)
                 (get x)
                 (raise-blame-error blame #:missing-party neg-party
                                    x '(expected: "~a" given: "~e")
                                    (barrier-contract-name c)
                                    x))))))))
