#lang racket/base
(require "prop.rkt"
         "blame.rkt"
         "guts.rkt"
         "rand.rkt"
         "generate.rkt"
         "misc.rkt"
         racket/list
         (for-syntax racket/base))

(provide symbols or/c first-or/c one-of/c
         blame-add-or-context
         blame-add-ior-context
         (rename-out [_flat-rec-contract flat-rec-contract]
                     [_flat-murec-contract flat-murec-contract]))

(define or/c:none/c (let ([none/c (make-none/c '(or/c))]) none/c))
(define/subexpression-pos-prop/name or/c-name or/c
  (case-lambda
    [() or/c:none/c]
    [raw-arg*
     (define raw-args (remove-duplicates (filter-not prop:none/c? raw-arg*) eq?))
     (cond
       [(null? raw-args) (or/c)]
       [(null? (cdr raw-args)) (coerce-contract 'or/c (car raw-args))]
       [else
        (define args (coerce-contracts 'or/c raw-args))
        (define-values (ho-contracts flat-contracts)
          (let loop ([ho-contracts '()]
                     [flat-contracts '()]
                     [args args])
            (if (null? args)
                (values (reverse ho-contracts) (reverse flat-contracts))
                (let ([arg (car args)])
                  (if (flat-contract? arg)
                      (loop ho-contracts (cons arg flat-contracts) (cdr args))
                      (loop (cons arg ho-contracts) flat-contracts (cdr args)))))))
        (define pred (make-flat-predicate flat-contracts))
        (define the-or/c
          (cond
            [(null? ho-contracts)
             (if (and (pair? flat-contracts)
                      (pair? (cdr flat-contracts))
                      (null? (cddr flat-contracts))
                      (or (and (equal? false/c-contract (car flat-contracts))
                               (equal? true/c-contract (cadr flat-contracts)))
                          (and (equal? false/c-contract (cadr flat-contracts))
                               (equal? true/c-contract (car flat-contracts)))))
                 (coerce-contract 'or/c boolean?)
                 (make-flat-or/c pred flat-contracts))]
            [(null? (cdr ho-contracts))
             (define name (apply build-compound-type-name 'or/c args))
             (define ho-contract (car ho-contracts))
             (if (chaperone-contract? ho-contract)
                 (make-chaperone-single-or/c name pred flat-contracts ho-contract)
                 (make-impersonator-single-or/c name pred flat-contracts ho-contract))]
            [else
             (define name (apply build-compound-type-name 'or/c args))
             (if (andmap chaperone-contract? ho-contracts)
                 (make-chaperone-multi-or/c name flat-contracts ho-contracts)
                 (make-impersonator-multi-or/c name flat-contracts ho-contracts))]))
        (if (ormap prop:any/c? args)
            (make-any/c (contract-name the-or/c))
            the-or/c)])]))

(define first-or/c:none/c (let ([none/c (make-none/c '(first-or/c))]) none/c))
(define/subexpression-pos-prop first-or/c
  (case-lambda
    [() first-or/c:none/c]
    [raw-arg*
     (define raw-args (remove-duplicates (filter-not prop:none/c? raw-arg*) eq?))
     (cond
       [(null? raw-args) (first-or/c)]
       [(null? (cdr raw-args)) (coerce-contract 'first-or/c (car raw-args))]
       [else
        (define args (coerce-contracts 'first-or/c raw-args))
        (define the-or/c
          (cond
            [(andmap flat-contract? args)
             (make-flat-first-or/c (make-flat-predicate args) args)]
            [(andmap chaperone-contract? args)
             (make-chaperone-first-or/c args)]
            [else (make-impersonator-first-or/c args)]))
        (if (ormap prop:any/c? args)
            (make-any/c (contract-name the-or/c))
            the-or/c)])]))

(define (make-flat-predicate flat-contracts)
  (cond
    [(null? flat-contracts) not]
    [else
     (define-values (eqables noneqables)
       (let loop ([flat-contracts flat-contracts])
         (cond
           [(null? flat-contracts)
            (values '() '())]
           [else
            (define fst (car flat-contracts))
            (define-values (eqables noneqables)
              (loop (cdr flat-contracts)))
            (cond
              [(eq-contract? fst)
               (values (cons fst eqables) noneqables)]
              [else
               (values eqables (cons fst noneqables))])])))

     (define eqables-pred
       (cond
         [(pair? eqables)
          (define vals (map eq-contract-val eqables))
          (λ (x) (and (memq x vals) #t))]
         [else #f]))
     (define noneqables-pred
       (cond
         [(pair? noneqables)
          (let loop ([fst (car noneqables)]
                     [rst (cdr noneqables)])
            (define fst-pred (flat-contract-predicate fst))
            (cond
              [(null? rst) fst-pred]
              [else
               (define r (loop (car rst) (cdr rst)))
               (λ (x)
                 (or (fst-pred x) (r x)))]))]
         [else #f]))
     (cond
       [(and eqables-pred noneqables-pred)
        (λ (x) (or (eqables-pred x) (noneqables-pred x)))]
       [eqables-pred eqables-pred]
       [noneqables-pred noneqables-pred]
       [else (error 'ack.orc.rkt)])]))

(define (single-or/c-late-neg-projection ctc)
  (define c-proj (get/build-late-neg-projection (single-or/c-ho-ctc ctc)))
  (define pred (single-or/c-pred ctc))
  (λ (blame)
    (define p-app (c-proj (blame-add-or-context blame)))
    (λ (val neg-party)
      (cond 
       [(pred val) val]
       [else (p-app val neg-party)]))))

(define (blame-add-or-context blame)
  (blame-add-context blame "a part of the or/c of"))
(define (blame-add-ior-context blame)
  (blame-add-context blame "a part of the first-or/c of"))

(define (single-or/c-first-order ctc)
  (let ([pred (single-or/c-pred ctc)]
        [ho (contract-first-order (single-or/c-ho-ctc ctc))])
    (λ (x) (or (ho x) (pred x)))))

(define (single-or/c-stronger? this that)
  (or (and (single-or/c? that)
           (contract-struct-stronger? (single-or/c-ho-ctc this)
                                      (single-or/c-ho-ctc that))
           (pairwise-stronger-contracts? (single-or/c-flat-ctcs this)
                                         (single-or/c-flat-ctcs that)))
      (generic-or/c-stronger? this that)))

(define (single-or/c-equivalent? this that)
  (or (and (single-or/c? that)
           (contract-struct-equivalent? (single-or/c-ho-ctc this)
                                        (single-or/c-ho-ctc that))
           (pairwise-equivalent-contracts? (single-or/c-flat-ctcs this)
                                           (single-or/c-flat-ctcs that)))
      (generic-or/c-equivalent? this that)))

(define (generic-or/c-stronger? this that)
  (define this-sub-ctcs (or/c-sub-contracts this))
  (define that-sub-ctcs (or/c-sub-contracts that))
  (and this-sub-ctcs
       that-sub-ctcs
       (for/and ([this-sub-ctc (in-list this-sub-ctcs)])
         (for/or ([that-sub-ctc (in-list that-sub-ctcs)])
           (contract-struct-stronger? this-sub-ctc that-sub-ctc)))))

(define (generic-or/c-equivalent? this that)
  (define this-sub-ctcs (or/c-sub-contracts this))
  (define that-sub-ctcs (or/c-sub-contracts that))
  (and this-sub-ctcs
       that-sub-ctcs
       (pairwise-equivalent-contracts?
        (sort this-sub-ctcs < #:key (λ (x) (equal-hash-code (contract-name x))))
        (sort that-sub-ctcs < #:key (λ (x) (equal-hash-code (contract-name x)))))))

(define (or/c-sub-contracts ctc)
  (cond
    [(single-or/c? ctc)
     (cons (single-or/c-ho-ctc ctc)
           (single-or/c-flat-ctcs ctc))]
    [(multi-or/c? ctc)
     (append (multi-or/c-flat-ctcs ctc)
             (multi-or/c-ho-ctcs ctc))]
    [(flat-or/c? ctc)
     (flat-or/c-flat-ctcs ctc)]
    [(base-first-or/c? ctc) (base-first-or/c-ctcs ctc)]
    [else #f]))

(define (or/c-exercise ho-contracts)
  (λ (fuel)
    (define env (contract-random-generate-get-current-environment))
    (values (λ (val)
              (let loop ([ho-contracts ho-contracts])
                (unless (null? ho-contracts)
                  (define ctc (car ho-contracts))
                  (cond
                    [((contract-first-order ctc) val)
                     (define-values (exercise ctcs) ((contract-struct-exercise ctc) fuel))
                     (exercise val)
                     (contract-random-generate-stash env ctc val)]
                    [else
                     (loop (cdr ho-contracts))]))))
            '())))

(define ((or/c-generate or/c-ctc ctcs) fuel)
  (define directs 
    (filter
     values
     (for/list ([ctc (in-list ctcs)])
       ((contract-struct-generate ctc) fuel))))
  (define can-generate?
    (or (pair? directs)
        (for/or ([ctc (in-list ctcs)])
          (can-generate/env? ctc))))
  (cond
    [can-generate?
     ;; #f => try to use the entire or/c contract in the environment
     (define options (cons #f (append 
                               (map (λ (x) (cons 'direct x)) directs)
                               (map (λ (x) (cons 'env x)) ctcs))))
     (define env (contract-random-generate-get-current-environment))
     (λ ()
       (let loop ([options (permute options)])
         (cond
           [(null? options) contract-random-generate-fail]
           [else
            (define option (car options))
            (cond
              [(not option)
               (define candidate (try/env or/c-ctc env))
               (cond
                 [(contract-random-generate-fail? candidate)
                  (loop (cdr options))]
                 [else
                  candidate])]
              [(equal? (car option) 'env)
               (define candidate (try/env (cdr option) env))
               (cond
                 [(contract-random-generate-fail? candidate)
                  (loop (cdr options))]
                 [else
                  candidate])]
              [(equal? (car option) 'direct)
               (define-values (succ? val)
                 (let/ec k
                   (parameterize ([fail-escape (λ () (k #f #f))])
                     (k #t ((cdr option))))))
               (if (and succ? (not (contract-random-generate-fail? val)))
                   val
                   (loop (cdr options)))]
              [else (error 'racket/contract/orc.rkt "ack ~s" options)])])))]
    [else #f]))

(define (single-or/c-list-contract? c)
  (and (list-contract? (single-or/c-ho-ctc c))
       (for/and ([c (in-list (single-or/c-flat-ctcs c))])
         (list-contract? c))))

(define-struct single-or/c (name pred flat-ctcs ho-ctc)
  #:property prop:orc-contract
  (λ (this) (cons (single-or/c-ho-ctc this) 
                  (single-or/c-flat-ctcs this))))

(define-struct (chaperone-single-or/c single-or/c) ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:trusted trust-me
   #:late-neg-projection single-or/c-late-neg-projection
   #:name single-or/c-name
   #:first-order single-or/c-first-order
   #:stronger single-or/c-stronger?
   #:equivalent single-or/c-equivalent?
   #:generate (λ (ctc) (or/c-generate ctc
                                      (cons (single-or/c-ho-ctc ctc)
                                            (single-or/c-flat-ctcs ctc))))
   #:exercise (λ (ctc) (or/c-exercise (list (single-or/c-ho-ctc ctc))))
   #:list-contract? single-or/c-list-contract?))

(define-struct (impersonator-single-or/c single-or/c) ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:late-neg-projection single-or/c-late-neg-projection
   #:name single-or/c-name
   #:first-order single-or/c-first-order
   #:stronger single-or/c-stronger?
   #:equivalent single-or/c-equivalent?
   #:generate (λ (ctc) (or/c-generate ctc
                                      (cons (single-or/c-ho-ctc ctc)
                                            (single-or/c-flat-ctcs ctc))))
   #:exercise (λ (ctc) (or/c-exercise (list (single-or/c-ho-ctc ctc))))
   #:list-contract? single-or/c-list-contract?))

(define (multi-or/c-late-neg-proj ctc)  
  (define ho-contracts (multi-or/c-ho-ctcs ctc))
  (define c-projs (map get/build-late-neg-projection ho-contracts))
  (define first-order-checks (map (λ (x) (contract-first-order x)) ho-contracts))
  (define predicates (map flat-contract-predicate (multi-or/c-flat-ctcs ctc)))
  (λ (blame)
    (define blame-w-context (blame-add-or-context blame))
    (define c-projs+blame (map (λ (c-proj) (c-proj blame-w-context)) c-projs))
    (λ (val neg-party)
      (cond
        [(for/or ([pred (in-list predicates)])
           (pred val))
         val]
        [else
         (define (try)
           (let loop ([checks first-order-checks]
                      [c-projs c-projs+blame]
                      [contracts ho-contracts]
                      [candidate-c-proj #f]
                      [candidate-contract #f])
             (cond
               [(null? checks)
                (cond
                  [candidate-c-proj
                   (values candidate-c-proj #f)]
                  [else
                   (raise-none-or-matched blame val neg-party)])]
               [((car checks) val)
                (if candidate-c-proj
                    (values candidate-contract (car contracts))
                    (loop (cdr checks)
                          (cdr c-projs)
                          (cdr contracts)
                          (car c-projs)
                          (car contracts)))]
               [else
                (loop (cdr checks)
                      (cdr c-projs)
                      (cdr contracts)
                      candidate-c-proj
                      candidate-contract)])))

         (let loop ([how-hard '(10 100)])
           (cond
             [(null? how-hard)
              (define-values (last-try-first-one last-try-second-one) (try))
              (when (and last-try-first-one last-try-second-one)
                (raise-blame-error blame val #:missing-party neg-party
                                   '("two of the clauses in the or/c might both match: ~s and ~s"
                                     given:
                                     "~e")
                                   (contract-name last-try-first-one)
                                   (contract-name last-try-second-one)
                                   val))]
             [else
              (define-values (this-try-first-one this-try-second-one)
                (contract-first-order-only-try-so-hard (car how-hard) (try)))
              (cond
                [(not this-try-second-one) (this-try-first-one val neg-party)]
                [else (loop (cdr how-hard))])]))]))))

(define (raise-none-or-matched blame val neg-party)
  (raise-blame-error blame val #:missing-party neg-party
                              '("none of the branches of the or/c matched" given: "~e")
                              val))

(define (multi-or/c-first-order ctc)
  (let ([flats (map flat-contract-predicate (multi-or/c-flat-ctcs ctc))]
        [hos (map (λ (x) (contract-first-order x)) (multi-or/c-ho-ctcs ctc))])
    (λ (x)
      (or (ormap (λ (f) (f x)) hos)
          (ormap (λ (f) (f x)) flats)))))

(define (multi-or/c-stronger? this that)
  (or (and (multi-or/c? that)
           (pairwise-stronger-contracts? (multi-or/c-ho-ctcs this)
                                         (multi-or/c-ho-ctcs that))
           (pairwise-stronger-contracts? (multi-or/c-flat-ctcs this)
                                         (multi-or/c-flat-ctcs that)))
      (generic-or/c-stronger? this that)))

(define (multi-or/c-equivalent? this that)
  (or (and (multi-or/c? that)
           (pairwise-equivalent-contracts? (multi-or/c-ho-ctcs this)
                                           (multi-or/c-ho-ctcs that))
           (pairwise-equivalent-contracts? (multi-or/c-flat-ctcs this)
                                           (multi-or/c-flat-ctcs that)))
      (generic-or/c-equivalent? this that)))

(define (mult-or/c-list-contract? c)
  (and (for/and ([c (in-list (multi-or/c-flat-ctcs c))])
         (list-contract? c))
       (for/and ([c (in-list (multi-or/c-ho-ctcs c))])
         (list-contract? c))))

(define-struct multi-or/c (name flat-ctcs ho-ctcs)
  #:property prop:orc-contract
  (λ (this) (append (multi-or/c-ho-ctcs this) 
                    (multi-or/c-flat-ctcs this))))

(define-struct (chaperone-multi-or/c multi-or/c) ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:trusted trust-me
   #:late-neg-projection multi-or/c-late-neg-proj
   #:name multi-or/c-name
   #:first-order multi-or/c-first-order
   #:stronger multi-or/c-stronger?
   #:equivalent multi-or/c-equivalent?
   #:generate (λ (ctc) (or/c-generate ctc
                                      (append (multi-or/c-ho-ctcs ctc)
                                              (multi-or/c-flat-ctcs ctc))))
   #:exercise (λ (ctc) (or/c-exercise (multi-or/c-ho-ctcs ctc)))
   #:list-contract? mult-or/c-list-contract?))

(define-struct (impersonator-multi-or/c multi-or/c) ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:late-neg-projection multi-or/c-late-neg-proj
   #:name multi-or/c-name
   #:first-order multi-or/c-first-order
   #:stronger multi-or/c-stronger?
   #:equivalent multi-or/c-equivalent?
   #:generate (λ (ctc) (or/c-generate ctc
                                      (append (multi-or/c-ho-ctcs ctc)
                                              (multi-or/c-flat-ctcs ctc))))
   #:exercise (λ (ctc) (or/c-exercise (multi-or/c-ho-ctcs ctc)))
   #:list-contract? mult-or/c-list-contract?))

(define-struct flat-or/c (pred flat-ctcs)
  #:property prop:custom-write custom-write-property-proc
  #:property prop:orc-contract
  (λ (this) (flat-or/c-flat-ctcs this))
  #:property prop:flat-contract
  (build-flat-contract-property
   #:trusted trust-me
   #:name
   (λ (ctc)
      (apply build-compound-type-name 
             (if (flat-first-or/c? ctc) 'first-or/c 'or/c)
             (flat-or/c-flat-ctcs ctc)))
   #:stronger
   (λ (this that)
     (or (and (flat-or/c? that)
              (let ([this-ctcs (flat-or/c-flat-ctcs this)]
                    [that-ctcs (flat-or/c-flat-ctcs that)])
                (cond
                  [(and (<= (length this-ctcs) (length that-ctcs))
                        (for/and ([this-ctc (in-list this-ctcs)]
                                  [that-ctc (in-list that-ctcs)])
                          (contract-struct-stronger? this-ctc that-ctc)))
                   #t]
                  [(and (andmap (λ (x) (or (eq-contract? x) (equal-contract? x))) this-ctcs)
                        (andmap (λ (x) (or (eq-contract? x) (equal-contract? x))) that-ctcs))
                   (define ht (make-hash))
                   (for ([x (in-list that-ctcs)])
                     (hash-set! ht
                                (if (equal-contract? x)
                                    (equal-contract-val x)
                                    (eq-contract-val x))
                                #t))
                   (for/and ([x (in-list this-ctcs)])
                     (hash-ref ht 
                               (if (equal-contract? x)
                                   (equal-contract-val x)
                                   (eq-contract-val x))
                               #f))]
                  [else #f])))
         (generic-or/c-stronger? this that)))
   #:equivalent generic-or/c-equivalent?

   #:first-order
   (λ (ctc) (flat-or/c-pred ctc))
   #:generate (λ (ctc) (or/c-generate ctc (flat-or/c-flat-ctcs ctc)))
   #:list-contract? 
   (λ (ctc)
     (for/and ([c (in-list (flat-or/c-flat-ctcs ctc))])
       (list-contract? c)))))

(define-struct (flat-first-or/c flat-or/c) ())

(define (first-or/c-late-neg-proj ctc)  
  (define ho-contracts (base-first-or/c-ctcs ctc))
  (define c-projs (map get/build-late-neg-projection ho-contracts))
  (define first-order-checks (map (λ (x) (contract-first-order x)) ho-contracts))
  (λ (blame)
    (define blame-w-context (blame-add-ior-context blame))
    (define c-projs+blame (map (λ (c-proj) (c-proj blame-w-context)) c-projs))
    (λ (val neg-party)
      (let loop ([checks first-order-checks]
                 [c-projs c-projs+blame]
                 [contracts ho-contracts])
        (cond
          [(null? checks)
           (raise-none-ior-matched blame val neg-party)]
          [else
           (cond
             [((car checks) val)
              ((car c-projs) val neg-party)]
             [else
              (loop (cdr checks)
                    (cdr c-projs)
                    (cdr contracts))])])))))

(define (raise-none-ior-matched blame val neg-party)
  (raise-blame-error blame val #:missing-party neg-party
                              '("none of the branches of the first-or/c matched" given: "~e")
                              val))

(define (first-or/c-name ctc)
  (apply build-compound-type-name 
         'first-or/c
         (base-first-or/c-ctcs ctc)))

(define (first-or/c-first-order ctc)
  (define preds (map contract-first-order (base-first-or/c-ctcs ctc)))
  (λ (x) (ormap (lambda (p?) (p? x)) preds)))

(define (first-or/c-list-contract? c)
  (for/and ([c (in-list (base-first-or/c-ctcs c))])
    (list-contract? c)))

(define/final-prop (symbols s1 . s2s)
  (define ss (cons s1 s2s))
  (for ([arg (in-list ss)]
        [i (in-naturals)])
    (unless (symbol? arg)
      (raise-argument-error 'symbols
                            "symbol?"
                            i
                            ss)))
  (apply or/c ss))

(define-struct base-first-or/c (ctcs)
  #:property prop:custom-write custom-write-property-proc
  #:property prop:orc-contract
  (λ (this) (base-first-or/c-ctcs this)))

(define-struct (chaperone-first-or/c base-first-or/c) ()
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:trusted trust-me
   #:late-neg-projection first-or/c-late-neg-proj
   #:name first-or/c-name
   #:first-order first-or/c-first-order
   #:stronger multi-or/c-stronger?
   #:equivalent multi-or/c-equivalent?
   #:generate (λ (ctc) (or/c-generate ctc (base-first-or/c-ctcs ctc)))
   #:exercise (λ (ctc) (or/c-exercise (base-first-or/c-ctcs ctc)))
   #:list-contract? first-or/c-list-contract?))
(define-struct (impersonator-first-or/c base-first-or/c) ()
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:late-neg-projection first-or/c-late-neg-proj
   #:name first-or/c-name
   #:first-order first-or/c-first-order
   #:stronger generic-or/c-stronger?
   #:equivalent generic-or/c-equivalent?
   #:generate (λ (ctc) (or/c-generate ctc (base-first-or/c-ctcs ctc)))
   #:exercise (λ (ctc) (or/c-exercise (base-first-or/c-ctcs ctc)))
   #:list-contract? first-or/c-list-contract?))

(define/final-prop (one-of/c . elems)
  (for ([arg (in-list elems)]
        [i (in-naturals)])
    (unless (atomic-value? arg)
      (raise-argument-error 'one-of/c
                            "char, symbol, boolean, null, keyword, number, or void"
                            i
                            elems)))
  (define or/c-args
    (map (λ (x)
           (cond
             [(void? x) void?]
             [else x]))
         elems))
  (apply or/c or/c-args))

(define atomic-value? 
  (λ (x)
     (or (char? x) (symbol? x) (boolean? x)
         (null? x) (keyword? x) (number? x)
         (void? x))))

(define (get-flat-rec-me ctc)
  (define ans (flat-rec-contract-me ctc))
  (unless ans (error 'flat-rec-contract "attempted to access the contract too early"))
  ans)

(struct flat-rec-contract ([me #:mutable] [predicate #:mutable] name)
  #:property prop:custom-write custom-write-property-proc
  #:property prop:flat-contract
  (build-flat-contract-property
   #:trusted trust-me
   #:name
   (λ (ctc) (flat-rec-contract-name ctc))
   #:stronger
   (let ([recur? (make-parameter #t)])
     (λ (this that)
       (cond
         [(equal? this that) #t]
         [(recur?) 
          (parameterize ([recur? #f])
            (contract-struct-stronger? (get-flat-rec-me this) that))]
         [else #f])))
   #:equivalent
   (let ([recur? (make-parameter #t)])
     (λ (this that)
       (cond
         [(equal? this that) #t]
         [(recur?)
          (parameterize ([recur? #f])
            (contract-struct-equivalent? (get-flat-rec-me this) that))]
         [else #f])))
   #:first-order
   (λ (ctc)
     (λ (v)
       ((flat-rec-contract-predicate ctc) v)))
   #:generate 
   (λ (ctc) 
     (λ (fuel)
       (if (zero? fuel)
           #f
           (contract-random-generate/choose (get-flat-rec-me ctc) (- fuel 1)))))))

(define (flat-rec-contract-too-early murec? who)
  (λ (x)
    (error (if murec? 'flat-murec-contract 'flat-rec-contract)
           "attempted to check the contract too early\n  ctc: ~a\n  accessed via: contract-first-order" who)))

(define-syntax (_flat-rec-contract stx)
  (syntax-case stx  ()
    [(_ name ctc ...)
     (identifier? (syntax name))
     (with-syntax ([(x ...) (generate-temporaries #'(ctc ...))])
     (syntax
      (let ([name (flat-rec-contract #f (flat-rec-contract-too-early #f 'name) 'name)])
        (let ([x (coerce-flat-contract 'flat-rec-contract ctc)] ...)
          (set-flat-rec-contract-me! name (or/c x ...))
          (set-flat-rec-contract-predicate!
           name
           (let ([x (flat-contract-predicate x)] ...)
             (λ (v)
               (or (x v) ...)))))
        name)))]
    [(_ name ctc ...)
     (raise-syntax-error 'flat-rec-contract
                         "expected first argument to be an identifier"
                         stx
                         (syntax name))]))

(define-syntax (_flat-murec-contract stx)
  (syntax-case stx  ()
    [(_ ([name ctc ...] ...) body1 body ...)
     (andmap identifier? (syntax->list (syntax (name ...))))
     (with-syntax ([((x ...) ...)
                    (for/list ([names (in-list (syntax->list #'((ctc ...) ...)))])
                      (generate-temporaries names))])
       (syntax
        (let ([name (flat-rec-contract #f (flat-rec-contract-too-early #t 'name) 'name)] ...)
          (let ([x (coerce-flat-contract 'flat-murec-contract ctc)] ...)
            (set-flat-rec-contract-me! name (or/c x ...))
            (set-flat-rec-contract-predicate!
             name
             (let ([x (flat-contract-predicate x)] ...)
               (λ (v)
                 (or (x v) ...)))))
          ...
          body1
          body ...)))]
    [(_ ([name ctc ...] ...) body1 body ...)
     (for-each (λ (name)
                 (unless (identifier? name)
                   (raise-syntax-error 'flat-murec-contract
                                       "expected an identifier" stx name)))
               (syntax->list (syntax (name ...))))]
    [(_ ([name ctc ...] ...))
     (raise-syntax-error 'flat-murec-contract "expected at least one body expression" stx)]))
