#lang racket/base

(require "blame.rkt"
         "generate-base.rkt"
         racket/pretty
         racket/private/performance-hint)

(provide prop:contract
         contract-struct?
         contract-struct-name
         contract-struct-first-order
         contract-struct-projection
         contract-struct-val-first-projection
         contract-struct-late-neg-projection
         contract-struct-collapsible-late-neg-projection
         contract-struct-stronger?
         trusted-contract-struct?
         trusted-contract-struct-stronger?
         contract-struct-equivalent?
         contract-struct-generate
         contract-struct-exercise
         contract-struct-list-contract?
         
         prop:flat-contract
         flat-contract-struct?
         
         prop:chaperone-contract
         chaperone-contract-struct?

         contract-property?
         build-contract-property
         
         chaperone-contract-property?
         build-chaperone-contract-property

         flat-contract-property?
         build-flat-contract-property

         make-contract
         make-chaperone-contract
         make-flat-contract

         prop:orc-contract
         prop:orc-contract?
         prop:orc-contract-get-subcontracts
         
         prop:recursive-contract
         prop:recursive-contract?
         prop:recursive-contract-unroll
         
         prop:arrow-contract 
         prop:arrow-contract?
         prop:arrow-contract-get-info
         (struct-out arrow-contract-info)

         get-any?
         get-none?

         prop:any/c prop:any/c?
         prop:none/c prop:none/c?
         
         build-context

         (protect-out trust-me))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Contract Property
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-struct contract-property [ name 
                                   first-order
                                   projection
                                   stronger
                                   equivalent
                                   generate
                                   exercise
                                   val-first-projection
                                   late-neg-projection
                                   collapsible-late-neg-projection
                                   list-contract? ])
(define-struct (trusted-contract-property contract-property) ())

(define (contract-property-guard prop info)
  (unless (contract-property? prop)
    (raise
     (make-exn:fail:contract
      (format "~a: expected a contract property; got: ~e"
              'prop:contract
              prop)
      (current-continuation-marks))))
  prop)

(define-values [ prop:contract contract-struct? contract-struct-property ]
  (make-struct-type-property 'prop:contract contract-property-guard))

;; determines if `c` is a contract that is trusted
(define (trusted-contract-struct? c)
  (and (contract-struct? c)
       (trusted-contract-property? (contract-struct-property c))))

(define (contract-struct-name c)
  (let* ([prop (contract-struct-property c)]
         [get-name (contract-property-name prop)]
         [name (get-name c)])
    name))

(define (contract-struct-first-order c)
  (let* ([prop (contract-struct-property c)]
         [get-first-order (contract-property-first-order prop)]
         [first-order (get-first-order c)])
    first-order))

(define (contract-struct-projection c)
  (define prop (contract-struct-property c))
  (define get-projection (contract-property-projection prop))
  (and get-projection (get-projection c)))

(define (contract-struct-val-first-projection c)
  (define prop (contract-struct-property c))
  (define get-projection (contract-property-val-first-projection prop))
  (and get-projection 
       (get-projection c)))

(define (contract-struct-late-neg-projection c)
  (define prop (contract-struct-property c))
  (define get-projection (contract-property-late-neg-projection prop))
  (and get-projection
       (get-projection c)))

(define (contract-struct-collapsible-late-neg-projection c)
  (define prop (contract-struct-property c))
  (define get-collapsible-projection (contract-property-collapsible-late-neg-projection prop))
  (and get-collapsible-projection
       (get-collapsible-projection c)))

(define only-trusted? (make-parameter #f))
(define (contract-struct-stronger/equivalent?
         a b
         trail
         contract-property-stronger/equivalent
         special-or/c-any/c-handling?)
  (let loop ([a a][b b])
    (cond
      [(and (or (flat-contract-struct? a)
                (chaperone-contract-struct? a))
            (equal? a b))
       #t]
      [(and (only-trusted?)
            (not (trusted-contract-struct? a)))
       #f]
      [else
       (define prop (contract-struct-property a))
       (define stronger/equivalent? (contract-property-stronger/equivalent prop))
       (cond
         [(stronger/equivalent? a b)
          ;; optimistically try skip some of the more complex work below
          #t]
         [(and special-or/c-any/c-handling?
               (flat-contract-struct? a)
               (prop:any/c? b))
          ;; is the flat-check needed here?
          #t]
         [(let ([th (trail)])
            (and th
                 (for/or ([(a2 bs-h) (in-hash th)])
                   (and (eq? a a2)
                        (for/or ([(b2 _) (in-hash bs-h)])
                          (eq? b b2))))))
          #t]
         [(or (prop:recursive-contract? a) (prop:recursive-contract? b))
          (parameterize ([trail (or (trail) (make-hasheq))])
            (define trail-h (trail))
            (let ([a-h (hash-ref trail-h a #f)])
              (cond
                [a-h
                 (hash-set! a-h b #t)]
                [else
                 (define a-h (make-hasheq))
                 (hash-set! trail-h a a-h)
                 (hash-set! a-h b #t)]))
            (loop (if (prop:recursive-contract? a)
                      ((prop:recursive-contract-unroll a) a)
                      a)
                  (if (prop:recursive-contract? b)
                      ((prop:recursive-contract-unroll b) b)
                      b)))]
         [special-or/c-any/c-handling?
          ;; the 'later?' flag avoids checking
          ;; (stronger? a b) in the first iteration,
          ;; since it was checked in the "optimistically"
          ;; branch above
          (let loop ([b b] [later? #f])
            (cond
              [(and later? (stronger/equivalent? a b))
               #t]
              [(prop:orc-contract? b)
               (define sub-contracts ((prop:orc-contract-get-subcontracts b) b))
               (for/or ([sub-contract (in-list sub-contracts)])
                 (loop sub-contract #t))]
              [else
               #f]))]
         [else #f])])))

(define stronger-trail (make-parameter #f))
(define (contract-struct-stronger? a b)
  (contract-struct-stronger/equivalent?
   a b
   stronger-trail
   contract-property-stronger
   #t))

;; determines if `a` is stronger than `b` but using
;; the contract-stronger method only on trusted contracts
(define (trusted-contract-struct-stronger? a b)
  (parameterize ([only-trusted? #t])
    (contract-struct-stronger? a b)))

(define equivalent-trail (make-parameter #f))
(define (contract-struct-equivalent? a b)
  (contract-struct-stronger/equivalent?
   a b
   equivalent-trail
   contract-property-equivalent
   #f))


(define (contract-struct-generate c)
  (define prop (contract-struct-property c))
  (define generate (contract-property-generate prop))
  (if (procedure? generate)
      (generate c)
      (λ (fuel) #f)))

(define (contract-struct-exercise c)
  (define prop (contract-struct-property c))
  (define exercise (contract-property-exercise prop))
  (if (procedure? exercise)
      (exercise c)
      (λ (fuel) (values void '()))))

(define (contract-struct-list-contract? c)
  (define prop (contract-struct-property c))
  ((contract-property-list-contract? prop) c))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Chaperone Contract Property
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-struct chaperone-contract-property [implementation]
  #:omit-define-syntaxes)

(define (chaperone-contract-property-guard prop info)
  (unless (chaperone-contract-property? prop)
    (raise
     (make-exn:fail:contract
      (format "~a: expected a chaperone contract property; got: ~e"
              'prop:chaperone-contract
              prop)
      (current-continuation-marks))))
  prop)

;; We check to make sure the contract projection actually resulted in
;; a chaperone (or chaperone-friendly) version of the value.
(define (chaperone-contract-property->contract-property fc)
  (let ([impl (chaperone-contract-property-implementation fc)])
    impl))

(define-values [ prop:chaperone-contract
                 chaperone-contract-struct?
                 chaperone-contract-struct-property ]
  (make-struct-type-property
   'prop:chaperone-contract
   chaperone-contract-property-guard
   (list (cons prop:contract chaperone-contract-property->contract-property))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Flat Contract Property
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-struct flat-contract-property [implementation]
  #:omit-define-syntaxes)

(define (flat-contract-property-guard prop info)
  (unless (flat-contract-property? prop)
    (raise
     (make-exn:fail:contract
      (format "~a: expected a flat contract property; got: ~e"
              'prop:flat-contract
              prop)
      (current-continuation-marks))))
  prop)

(define (flat-contract-property->chaperone-contract-property fc)
  (let ([impl (flat-contract-property-implementation fc)])
    (make-chaperone-contract-property impl)))

(define (flat-contract-property->procedure-property prop)
  (let* ([impl (flat-contract-property-implementation prop)]
         [get-predicate (contract-property-first-order impl)])
    (lambda (c x) ((get-predicate c) x))))

(define (flat-contract-property->object-name-property prop)
  (define get-name (contract-property-name (flat-contract-property-implementation prop)))
  (λ (c)
    (string->symbol (pretty-format (get-name c) 'infinity #:mode 'write))))

(define-values [ prop:flat-contract
                 flat-contract-struct?
                 flat-contract-struct-property ]
  (make-struct-type-property
   'prop:flat-contract
   flat-contract-property-guard
   (list (cons prop:chaperone-contract flat-contract-property->chaperone-contract-property)
         (cons prop:procedure flat-contract-property->procedure-property)
         (cons prop:object-name flat-contract-property->object-name-property))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Friendly Property Construction
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-logger racket/contract)

(define ((build-property mk trusted-mk default-name proc-name first-order? equivalent-equal?)
         #:name [get-name #f]
         #:first-order [get-first-order #f]
         #:projection [get-projection #f]
         #:val-first-projection [get-val-first-projection #f]
         #:late-neg-projection [get-late-neg-projection #f]
         #:collapsible-late-neg-projection [get-collapsible-late-neg-projection #f]
         #:stronger [stronger #f]
         #:equivalent [equivalent #f]
         #:generate [generate (λ (ctc) (λ (fuel) #f))]
         #:exercise [exercise (λ (ctc) (λ (fuel) (values void '())))]
         #:list-contract? [list-contract? (λ (c) #f)]
         #:trusted [trusted #f])

  (unless (or (not get-name)
              (and (procedure? get-name)
                   (procedure-arity-includes? get-name 1)))
    (error proc-name
           (string-append
            "contract violation:\n"
            "  expected: ~s\n"
            "  given: ~e\n"
            "  in: the #:get-name argument")
           '(or/c #f (-> contract? any/c))
           get-name))

  (unless (or get-first-order
              get-projection
              get-val-first-projection
              get-late-neg-projection)
    (error
     proc-name
     (string-append
      "expected either the"
      " #:projection, #:val-first-projection, #:late-neg-projection, or #:first-order"
      " argument to not be #f, but all four were #f")))

  ;; TODO: update for collapsible late-neg-projection
  (unless get-late-neg-projection
    (unless get-collapsible-late-neg-projection
      (unless first-order?
        (log-racket/contract-info
         "no late-neg-projection passed to ~s~a"
         proc-name
         (build-context)))))

  (unless (and (procedure? list-contract?)
               (procedure-arity-includes? list-contract? 1))
    (error proc-name
           (string-append
            "contract violation\n"
            "  expected: (procedure-arity-includes/c 1)\n"
            "  given: ~e\n"
            "  in the #:list-contract? argument")
           list-contract?))

  ((if (equal? trusted trust-me) trusted-mk mk)
   (or get-name (λ (c) default-name))
      (or get-first-order get-any?)
      get-projection
      (or stronger weakest)
      (or equivalent (if equivalent-equal? equal? weakest))
      generate exercise 
      get-val-first-projection
      (cond
        [first-order?
         (cond
           [get-late-neg-projection get-late-neg-projection]
           [(and (not get-projection) (not get-val-first-projection) get-first-order)
            (λ (c) (late-neg-first-order-projection (get-name c) (get-first-order c)))]
           [else #f])]
        [else get-late-neg-projection])
      get-collapsible-late-neg-projection
      list-contract?))

(define trust-me (gensym 'trustme))

(define (build-context)
  (apply
   string-append
   (for/list ([i (in-list (continuation-mark-set->context
                           (current-continuation-marks)))])
     (format "\n  ~s" i))))
    
(define build-contract-property
  (procedure-rename
   (build-property make-contract-property make-trusted-contract-property
                   'anonymous-contract 'build-contract-property #f #f)
   'build-contract-property))

(define build-flat-contract-property
  (procedure-rename
   (build-property (compose make-flat-contract-property make-contract-property)
                   (compose make-flat-contract-property make-trusted-contract-property)
                   'anonymous-flat-contract 'build-flat-contract-property #t #t)
   'build-flat-contract-property))

(define build-chaperone-contract-property
  (procedure-rename
   (build-property (compose make-chaperone-contract-property make-contract-property)
                   (compose make-chaperone-contract-property make-trusted-contract-property)
                   'anonymous-chaperone-contract 'build-chaperone-contract-property #f #t)
   'build-chaperone-contract-property))

(define (get-any? c) any?)
(define (any? x) #t)

(define (get-none? c) none?)
(define (none? x) #f)

(define (weakest a b) #f)

(define ((val-first-projection->projection get-val-first-projection
                                           get-name
                                           get-first-order) c)
  (cond
    [(flat-contract-struct? c)
     (first-order-projection (get-name c) (get-first-order c))]
    [else
     (define vfp (get-val-first-projection c))
     (λ (blame)
       (define vp (vfp blame))
       (λ (val)
         ((vp val) #f)))]))

(begin-encourage-inline
  (define (first-order-projection name first-order)
    (λ (b)
      (λ (x)
        (if (first-order x)
            x
            (raise-blame-error b x
                               '(expected: "~s" given: "~e")
                               name 
                               x))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Simple Contract Construction
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-struct make-contract [ name first-order projection
                                    val-first-projection late-neg-projection
                                    collapsible-late-neg-projection
                                    stronger equivalent generate exercise list-contract? ]
  #:omit-define-syntaxes
  #:property prop:custom-write
  (λ (stct port display?)
    (write-string "#<contract: " port)
    (write-string (format "~.s" (make-contract-name stct)) port)
    (write-string ">" port))
  #:property prop:contract
  (build-contract-property
   #:name (lambda (c) (make-contract-name c))
   #:first-order (lambda (c) (make-contract-first-order c))
   #:projection (lambda (c) (make-contract-projection c))
   #:val-first-projection (lambda (c) (make-contract-val-first-projection c))
   #:late-neg-projection (lambda (c) (make-contract-late-neg-projection c))
   #:collapsible-late-neg-projection (lambda (c) (make-contract-collapsible-late-neg-projection c))
   #:stronger (lambda (a b) ((make-contract-stronger a) a b))
   #:generate (lambda (c) (make-contract-generate c))
   #:exercise (lambda (c) (make-contract-exercise c))
   #:list-contract? (λ (c) (make-contract-list-contract? c))))

(define-struct make-chaperone-contract [ name first-order projection
                                              val-first-projection late-neg-projection
                                              collapsible-late-neg-projection
                                              stronger equivalent generate exercise list-contract? ]
  #:omit-define-syntaxes
  #:property prop:custom-write
  (λ (stct port display?)
    (write-string "#<chaperone-contract: " port)
    (write-string (format "~.s" (make-chaperone-contract-name stct)) port)
    (write-string ">" port))
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:name (lambda (c) (make-chaperone-contract-name c))
   #:first-order (lambda (c) (make-chaperone-contract-first-order c))
   #:projection (lambda (c) (make-chaperone-contract-projection c))
   #:val-first-projection (lambda (c) (make-chaperone-contract-val-first-projection c))
   #:late-neg-projection (lambda (c) (make-chaperone-contract-late-neg-projection c))
   #:collapsible-late-neg-projection (lambda (c) (make-chaperone-contract-collapsible-late-neg-projection c))
   #:stronger (lambda (a b) ((make-chaperone-contract-stronger a) a b))
   #:generate (lambda (c) (make-chaperone-contract-generate c))
   #:exercise (lambda (c) (make-chaperone-contract-exercise c))
   #:list-contract? (λ (c) (make-chaperone-contract-list-contract? c))))

(define-struct make-flat-contract [ name first-order projection
                                         val-first-projection late-neg-projection
                                         collapsible-late-neg-projection
                                         stronger equivalent generate exercise list-contract? ]
  #:omit-define-syntaxes
  #:property prop:custom-write
  (λ (stct port display?)
    (write-string "#<flat-contract: " port)
    (write-string (format "~.s" (make-flat-contract-name stct)) port)
    (write-string ">" port))
  #:property prop:flat-contract
  (build-flat-contract-property
   #:name (lambda (c) (make-flat-contract-name c))
   #:first-order (lambda (c) (make-flat-contract-first-order c))
   #:val-first-projection (λ (c) (make-flat-contract-val-first-projection c))
   #:late-neg-projection (λ (c) (make-flat-contract-late-neg-projection c))
   #:collapsible-late-neg-projection (lambda (c) (make-flat-contract-collapsible-late-neg-projection c))
   #:projection (lambda (c) (make-flat-contract-projection c))
   #:stronger (lambda (a b) ((make-flat-contract-stronger a) a b))
   #:generate (lambda (c) (make-flat-contract-generate c))
   #:exercise (lambda (c) (make-flat-contract-exercise c))
   #:list-contract? (λ (c) (make-flat-contract-list-contract? c))))

(define ((build-contract mk default-name proc-name first-order? equivalent-equal?)
         #:name [name #f]
         #:first-order [first-order #f]
         #:projection [projection #f]
         #:val-first-projection [val-first-projection #f]
         #:late-neg-projection [late-neg-projection #f]
         #:collapsible-late-neg-projection [collapsible-late-neg-projection #f]
         #:stronger [stronger #f]
         #:equivalent [equivalent #f]
         #:generate [generate (λ (fuel) #f)]
         #:exercise [exercise (λ (fuel) (values void '()))]
         #:list-contract? [list-contract? #f])

  (unless (or first-order
              projection
              val-first-projection
              late-neg-projection)
    (error
     proc-name
     (string-append
      "expected either the"
      " #:projection, #:val-first-projection, #:late-neg-projection, or #:first-order"
      " argument to not be #f, but all four were #f")))
  
  ;; TODO: handle the addition of the collapsible-late-neg-projection
  (unless late-neg-projection
    (unless collapsible-late-neg-projection
      (unless first-order?
        (log-racket/contract-info
         "no late-neg-projection passed to ~s~a"
         proc-name
         (build-context)))))

  (mk (or name default-name)
      (or first-order any?) 
      projection val-first-projection
      (cond
        [first-order?
         (cond
           [late-neg-projection late-neg-projection]
           [(and (not projection) (not val-first-projection) first-order)
            (late-neg-first-order-projection name first-order)]
           [else #f])]
        [else late-neg-projection])
      collapsible-late-neg-projection
      (or stronger weakest)
      (or equivalent (if equivalent-equal? equal? weakest))
      generate exercise
      (and list-contract? #t)))

(define (late-neg-first-order-projection name p?)
  (λ (b)
    (λ (v neg-party)
      (if (p? v)
          v
          (raise-blame-error
           b #:missing-party neg-party
           v
           '(expected: "~s" given: "~e")
           name
           v)))))

(define make-contract
  (procedure-rename 
   (build-contract make-make-contract 'anonymous-contract 'make-contract #f #f)
   'make-contract))

(define make-chaperone-contract
  (procedure-rename
   (build-contract make-make-chaperone-contract
                   'anonymous-chaperone-contract
                   'make-chaperone-contract
                   #f #t)
   'make-chaperone-contract))

(define make-flat-contract
  (procedure-rename
   (build-contract make-make-flat-contract
                   'anonymous-flat-contract
                   'make-flat-contract
                   #t #t)
   'make-flat-contract))

;; property should be bound to a function that accepts the contract and
;; returns a list of contracts that were the original arguments to the or/c
(define-values (prop:orc-contract prop:orc-contract? prop:orc-contract-get-subcontracts)
  (make-struct-type-property 'prop:orc-contract))

;; property should be bound to a function that accepts the contract
;; and returns a new contract, after unrolling one time
(define-values (prop:recursive-contract
                prop:recursive-contract?
                prop:recursive-contract-unroll)
  (make-struct-type-property 'prop:recursive-contract))

;; this property's value isn't looked at; it is just a signal
;; that the contract accepts any value
(define-values (prop:any/c prop:any/c? prop:get-any/c)
  (make-struct-type-property 'prop:any/c))

;; this property's value isn't looked at; it is just a signal
;; that the contract accepts no value
(define-values (prop:none/c prop:none/c? prop:get-none/c)
  (make-struct-type-property 'prop:none/c))

;; get-info : (-> ctc arrow-contract-info?)
(define-values (prop:arrow-contract prop:arrow-contract? prop:arrow-contract-get-info)
  (make-struct-type-property 'prop:arrow-contract))

;; chaperone-procedure : 
;;   (-> any/c[val] blame? procedure[suitable for second argument to chaperone-procedure])
;; check-first-order : any/c[val] blame? -> void? 
;;     raises a blame error if val doesn't satisfy the first-order checks for the function
;; accepts-arglist : (-> (listof keyword?)[sorted by keyword<?] exact-nonnegative-integer? boolean?)
(struct arrow-contract-info (chaperone-procedure check-first-order accepts-arglist)
  #:transparent)
