#lang racket/base

(require (for-syntax racket/base
                     "arr-util.rkt")
         racket/promise
         (only-in "../../private/promise.rkt" prop:force promise-forcer)
         "prop.rkt"
         "blame.rkt"
         "guts.rkt"
         "rand.rkt"
         "generate.rkt"
         "generate-base.rkt")

(provide not/c
         =/c >=/c <=/c </c >/c between/c
         renamed->-ctc renamed-<-ctc
         char-in
         real-in
         (rename-out [-complex/c complex/c])
         natural-number/c
         string-len/c
         false/c
         printable/c
         promise/c
         syntax/c
         
         check-between/c
         check-unary-between/c
         parameter/c
         procedure-arity-includes/c
         
         make-any/c any make-none/c
         (rename-out [_any/c any/c] [_none/c none/c])

         prompt-tag/c
         continuation-mark-key/c

         channel/c
         evt/c

         flat-contract
         flat-contract-predicate
         flat-named-contract
         
         random-any/c

         rename-contract
         if/c

         pairwise-stronger-contracts?
         pairwise-equivalent-contracts?
         check-two-args

         suggest/c

         flat-contract-with-explanation

         (struct-out between/c-s)
         (struct-out </>-ctc)
         (struct-out <-ctc)
         (struct-out >-ctc)
         renamed-between/c)

(define false/c #f)

(define/final-prop (string-len/c n)
  (unless (real? n)
    (raise-argument-error 'string-len/c "real?" n))
  (flat-named-contract 
   `(string-len/c ,n)
   (λ (x)
     (and (string? x)
          ((string-length x) . < . n)))))

(define (between/c-stronger this that)
  (define this-low (between/c-s-low this))
  (define this-high (between/c-s-high this))
  (cond
    [(between/c-s? that)
     (and (<= (between/c-s-low that) this-low)
          (<= this-high (between/c-s-high that)))]
    [(</>-ctc? that)
     (define that-x (</>-ctc-x that))
     (cond
       [(<-ctc? that)
        (and (= this-low -inf.0)
             (< this-high that-x))]
       [(>-ctc? that)
        (and (= this-high +inf.0)
             (< that-x this-low))])]
    [else #f]))

(define (between/c-equivalent this that)
  (define this-low (between/c-s-low this))
  (define this-high (between/c-s-high this))
  (cond
    [(between/c-s? that)
     (and (= (between/c-s-low that) this-low)
          (= this-high (between/c-s-high that)))]
    [else #f]))

(define (between/c-first-order ctc)
  (define n (between/c-s-low ctc))
  (define m (between/c-s-high ctc))
  (cond
    [(and (= n -inf.0) (= m +inf.0))
     real?]
    [else
     (λ (x) (and (real? x) (<= n x m)))]))

(define ((between/c-generate ctc) fuel)
  (define n (between/c-s-low ctc))
  (define m (between/c-s-high ctc))
  (cond
    [(= n m)
     (λ () 
       (define choice (rand-choice
                       [1/2 n]
                       [else m]))
       (rand-choice 
        [1/2 (if (exact? choice)
                 (if (= (exact->inexact choice) choice)
                     (exact->inexact choice)
                     choice)
                 (if (= (* 1.0 choice) choice)
                     (* 1.0 choice)
                     choice))]
        [else choice]))]
    [(> n m) #f]
    [else
     (λ ()
       (rand-choice
        [1/10 (if (<= n 0 m)
                  (rand-choice [1/3 0] [1/3 0.0] [else -0.0])
                  (rand-choice [1/2 n] [else m]))]
        [1/20 (if (<= n 1 m)
                  1
                  (rand-choice [1/2 n] [else m]))]
        [1/20 (if (<= n -1 m)
                  -1
                  (rand-choice [1/2 n] [else m]))]
        [1/10 m]
        [1/10 n]
        [1/10 (if (<= n 0 1 m)
                  (random)
                  (rand-choice [1/2 n] [else m]))]
        [else
         (cond
           [(or (= n -inf.0) (= m +inf.0))
            (define c (random 4294967087))
            (cond
              [(and (= n -inf.0) (= m +inf.0)) c]
              [(= m +inf.0) (+ n c)]
              [(= n -inf.0) (- m c)])]
           [else
            (+ n (* (random) (- m n)))])]))]))

(define-struct between/c-s (low high)
  #:property prop:custom-write custom-write-property-proc
  #:property prop:flat-contract
  (build-flat-contract-property
   #:trusted trust-me
   #:name
   (λ (ctc)
     (cond
       [(renamed-between/c? ctc) (renamed-between/c-name ctc)]
       [else
        `(between/c ,(between/c-s-low ctc) ,(between/c-s-high ctc))
        #;
        (cond
          [(and (= n -inf.0) (= m +inf.0))
           'real?]
          [(= n -inf.0) (if (= m 0) `(and/c real? (not/c positive?)) `(<=/c ,m))]
          [(= m +inf.0) (if (= n 0) `(and/c real? (not/c negative?)) `(>=/c ,n))]
          [(= n m) `(=/c ,n)]
          [else ])]))
   #:stronger between/c-stronger
   #:equivalent between/c-equivalent
   #:first-order between/c-first-order
   #:generate between/c-generate))
(define-struct (renamed-between/c between/c-s) (name))

(define (maybe-neg n) (rand-choice [1/2 n] [else (- n)]))

(define (check-unary-between/c sym x)
  (unless (real? x)
    (raise-argument-error sym "real?" x)))

(define/final-prop (=/c x) 
  (check-unary-between/c '=/c x)
  (make-renamed-between/c x x `(=/c ,x)))
(define/final-prop (<=/c x) 
  (check-unary-between/c '<=/c x)
  (make-renamed-between/c -inf.0 x `(<=/c ,x)))
(define/final-prop (>=/c x)
  (check-unary-between/c '>=/c x)
  (make-renamed-between/c x +inf.0 `(>=/c ,x)))
(define (check-between/c x y)
  (check-two-args 'between/c x y real? real?))
(define/final-prop (between/c x y)
  (check-between/c x y)
  (if (= x y)
      (make-renamed-between/c x x `(between/c ,x ,y))
      (make-between/c-s x y)))

(define (make-</c->/c-contract-property name </> -/+ less/greater)
  (build-flat-contract-property
   #:trusted trust-me
   #:name (λ (c)
            (cond
              [(renamed-<-ctc? c) (renamed-<-ctc-name c)]
              [(renamed->-ctc? c) (renamed->-ctc-name c)]
              [else `(,name ,(</>-ctc-x c))]))
   #:first-order (λ (ctc) (define x (</>-ctc-x ctc)) (λ (y) (and (real? y) (</> y x))))
   #:late-neg-projection
   (λ (ctc)
     (define x (</>-ctc-x ctc))
     (λ (blame)
       (λ (val neg-party)
         (if (and (real? val) (</> val x))
             val
             (raise-blame-error
              blame val #:missing-party neg-party
              '(expected:
                "a number strictly ~a than ~v"
                given: "~v")
              less/greater
              x
              val)))))
   #:generate
   (λ (ctc)
     (define x (</>-ctc-x ctc))
     (cond
       [(and (= x +inf.0) (equal? name '</c))
        (λ (fuel)
          (λ ()
            (rand-choice
             [1/10 -inf.0]
             [2/10 (random)]
             [2/10 (- (random))]
             [2/10 (random 4294967087)]
             [2/10 (- (random 4294967087))]
             [else 0])))]
       [(and (= x -inf.0) (equal? name '</c))
        (λ (fuel) #f)]
       [(and (= x +inf.0) (equal? name '>/c))
        (λ (fuel) #f)]
       [(and (= x -inf.0) (equal? name '>/c))
        (λ (fuel)
          (λ ()
            (rand-choice
             [1/10 +inf.0]
             [2/10 (random)]
             [2/10 (- (random))]
             [2/10 (random 4294967087)]
             [2/10 (- (random 4294967087))]
             [else 0])))]
       [else
        (λ (fuel)
          (λ ()
            (rand-choice
             [1/10 (-/+ +inf.0)]
             [1/10 (-/+ x 0.01)]
             [4/10 (-/+ x (random))]
             [else (-/+ x (random 4294967087))])))]))
   #:stronger </>-ctc-stronger
   #:equivalent </>-ctc-equivalent))

(define (</>-ctc-stronger this that)
  (define this-x (</>-ctc-x this))
  (cond
    [(</>-ctc? that)
     (cond
       [(and (<-ctc? this) (<-ctc? that))
        (<= this-x (</>-ctc-x that))]
       [(and (>-ctc? this) (>-ctc? that))
        (>= this-x (</>-ctc-x that))]
       [else #f])]
    [(between/c-s? that)
     (cond
       [(<-ctc? this)
        (and (= (between/c-s-low that) -inf.0)
             (<= this-x (between/c-s-high that)))]
       [else
        (and (= (between/c-s-high that) +inf.0)
             (<= (between/c-s-low that) this-x))])]))

(define (</>-ctc-equivalent this that)
  (define this-x (</>-ctc-x this))
  (cond
    [(</>-ctc? that)
     (cond
       [(and (<-ctc? this) (<-ctc? that))
        (= this-x (</>-ctc-x that))]
       [(and (>-ctc? this) (>-ctc? that))
        (= this-x (</>-ctc-x that))]
       [else #f])]
    [else #f]))

(struct </>-ctc (x))
(struct <-ctc </>-ctc ()
  #:property prop:flat-contract
  (make-</c->/c-contract-property '</c < - "less")
  #:property prop:custom-write custom-write-property-proc)
(struct renamed-<-ctc <-ctc (name))
(define (</c x) (<-ctc x))
(struct >-ctc </>-ctc ()
  #:property prop:flat-contract
  (make-</c->/c-contract-property '>/c > + "greater")
  #:property prop:custom-write custom-write-property-proc)
(struct renamed->-ctc >-ctc (name))
(define (>/c x) (>-ctc x))

(define (check-two-args name arg1 arg2 pred1? pred2?)
  (unless (pred1? arg1)
    (raise-argument-error name
                          (format "~a" (object-name pred1?))
                          0
                          arg1 arg2))
  (unless (pred2? arg2)
    (raise-argument-error name
                          (format "~a" (object-name pred2?))
                          1
                          arg1 arg2)))

(define between/c-inf+inf-as-real? (renamed-between/c -inf.0 +inf.0 'real?))

;; passing only defined names here gives the demodularizer license to prune:
(set-some-basic-misc-contracts! between/c-inf+inf-as-real?
                                renamed-between/c
                                between/c-s?
                                between/c-s-low
                                between/c-s-high)

(define -complex/c
  (let ()
    (define (complex/c rp ip)
      (make-complex/c (coerce-flat-contract 'complex/c rp)
                      (coerce-flat-contract 'complex/c ip)))
    complex/c))

(struct complex/c (real? imag?)
  #:extra-constructor-name make-complex/c
  #:property prop:custom-write custom-write-property-proc
  #:property prop:flat-contract
  (build-flat-contract-property
   #:trusted trust-me
   #:name (λ (c) (build-compound-type-name 'complex/c (complex/c-real? c) (complex/c-imag? c)))
   #:first-order (λ (ctc)
                   (define rp? (complex/c-real? ctc))
                   (define ip? (complex/c-imag? ctc))
                   (λ (v) (and (complex? v) (rp? (real-part v)) (ip? (imag-part v)))))
   #:late-neg-projection
   (λ (ctc)
     (define rp? (complex/c-real? ctc))
     (define ip? (complex/c-imag? ctc))
     (λ (blame)
       (λ (val neg-party)
         (if (and (complex? val)
                  (rp? (real-part val))
                  (ip? (imag-part val)))
             val
             (raise-blame-error
              blame val #:missing-party neg-party
              '(expected:
                "a complex number with\n"
                "  real part: ~s\n"
                "  imaginary part: ~s"
                given: "~v")
              (contract-name rp?)
              (contract-name ip?)
              val)))))
   #:generate
   (λ (ctc)
     (λ (fuel)
       (define gen-real (contract-random-generate/choose (complex/c-real? ctc) fuel))
       (define gen-imag (contract-random-generate/choose (complex/c-imag? ctc) fuel))
       (and gen-real
            gen-imag
            (λ ()
              (make-rectangular (gen-real) (gen-imag))))))
   #:stronger
   (λ (this that)
     (cond
       [(complex/c? that)
        (and (contract-stronger? (complex/c-real? this) (complex/c-real? that))
             (contract-stronger? (complex/c-imag? this) (complex/c-imag? that)))]
       [else #f]))
   #:equivalent
   (λ (this that)
     (cond
       [(complex/c? that)
        (and (contract-equivalent? (complex/c-real? this) (complex/c-real? that))
             (contract-equivalent? (complex/c-imag? this) (complex/c-imag? that)))]
       [else #f]))))

(define (char-in a b)
  (check-two-args 'char-in a b char? char?)
  (char-in/c a b))

(define/final-prop (real-in start end)
  (check-two-args 'real-in start end real? real?)
  (make-renamed-between/c start end `(real-in ,start ,end)))

(define/final-prop (not/c f)
  (let* ([ctc (coerce-flat-contract 'not/c f)]
         [pred (flat-contract-predicate ctc)])
    (flat-named-contract
     (build-compound-type-name 'not/c ctc)
     (λ (x) (not (pred x))))))

(struct syntax-ctc (ctc)
  #:property prop:custom-write custom-write-property-proc
  #:property prop:flat-contract
  (build-flat-contract-property
   #:trusted trust-me
   #:name (λ (ctc) (build-compound-type-name 'syntax/c (syntax-ctc-ctc ctc)))
   #:stronger (λ (this that)
                (and (syntax-ctc? that)
                     (contract-struct-stronger? (syntax-ctc-ctc this)
                                                (syntax-ctc-ctc that))))
   #:equivalent (λ (this that)
                  (and (syntax-ctc? that)
                       (contract-struct-equivalent? (syntax-ctc-ctc this)
                                                    (syntax-ctc-ctc that))))
   #:first-order (λ (ctc) 
                   (define ? (flat-contract-predicate (syntax-ctc-ctc ctc)))
                   (λ (v)
                     (and (syntax? v)
                          (? (syntax-e v)))))))

(define/subexpression-pos-prop (syntax/c ctc-in)
  (define ctc (coerce-flat-contract 'syntax/c ctc-in))
  (syntax-ctc ctc))

(define/subexpression-pos-prop promise/c
  (λ (ctc-in)
    (define ctc (coerce-contract 'promise/c ctc-in))
    (cond
      [(chaperone-contract? ctc)
       (chaperone-promise-ctc ctc)]
      [else
       (promise-ctc ctc)])))

(define (promise-contract-late-neg-proj ctc)
  (define chap? (chaperone-promise-ctc? ctc))
  (define c/i-struct (if chap? chaperone-struct impersonate-struct))
  (define c/i-procedure (if chap? chaperone-procedure impersonate-procedure))
  (define ctc-proc (get/build-late-neg-projection (promise-base-ctc-ctc ctc)))
  (λ (blame)
    (define promise-blame (blame-add-context blame "the promise from"))
    (define p-app (ctc-proc promise-blame))
    (λ (val neg-party)
      (define blame+neg-party (cons blame neg-party))
      (if (promise? val)
          (c/i-struct
           val
           promise-forcer
           (λ (_ proc)
             (c/i-procedure
              proc
              (λ (promise)
                (values (case-lambda
                          [(val) (with-contract-continuation-mark
                                     blame+neg-party
                                   (p-app val neg-party))]
                          [()
                           (raise-blame-error
                            promise-blame #:missing-party neg-party val
                            '("received 0 values" expected: "1 value"))]
                          [reses
                           (define length-reses (length reses))
                           (raise-blame-error
                            promise-blame #:missing-party neg-party val
                            '("received ~a values~a~a" expected: "1 value")
                            length-reses
                            (if (<= length-reses 10)
                                ":"
                                ", the first 10 of which are:")
                            (apply string-append
                                   (for/list ([v (in-list reses)]
                                              [_ (in-range 10)])
                                     (format "\n   ~e" v))))])
                        promise))))
           impersonator-prop:contracted ctc
           impersonator-prop:blame blame+neg-party)
          (raise-blame-error
           blame #:missing-party neg-party
           val
           '(expected: "<promise>" given: "~e")
           val)))))

(define (promise-contract-name ctc)
  (build-compound-type-name 'promise/c (promise-base-ctc-ctc ctc)))

(define (promise-ctc-stronger? this that)
  (and (promise-base-ctc? that)
       (contract-struct-stronger? (promise-base-ctc-ctc this)
                                  (promise-base-ctc-ctc that))))

(define (promise-ctc-equivalent? this that)
  (and (promise-base-ctc? that)
       (contract-struct-equivalent? (promise-base-ctc-ctc this)
                                    (promise-base-ctc-ctc that))))

(define (promise-ctc-generate ctc)
  (define base-ctc (promise-base-ctc-ctc ctc))
  (λ (fuel)
    (define gen-base (contract-random-generate/choose base-ctc fuel))
    (and gen-base
         (λ () (delay (gen-base))))))

(define (promise-ctc-exercise ctc)
  (define base-ctc (promise-base-ctc-ctc ctc))
  (λ (fuel)
    (define gen-base (contract-random-generate/choose base-ctc fuel))
    (values (λ (p) (force p))
            (list base-ctc))))

(struct promise-base-ctc (ctc))
(struct chaperone-promise-ctc promise-base-ctc ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:trusted trust-me
   #:name promise-contract-name
   #:late-neg-projection promise-contract-late-neg-proj
   #:stronger promise-ctc-stronger?
   #:equivalent promise-ctc-equivalent?
   #:generate promise-ctc-generate
   #:exercise promise-ctc-exercise
   #:first-order (λ (ctc) promise?)))

(struct promise-ctc promise-base-ctc ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:name promise-contract-name
   #:late-neg-projection promise-contract-late-neg-proj
   #:stronger promise-ctc-stronger?
   #:equivalent promise-ctc-equivalent?
   #:generate promise-ctc-generate
   #:exercise promise-ctc-exercise
   #:first-order (λ (ctc) promise?)))

;; (parameter/c in/out-ctc)
;; (parameter/c in-ctc out-ctc)
(define unsupplied (gensym))
(define/subexpression-pos-prop (parameter/c in [out unsupplied] #:impersonator? [impersonator? #t])
  (define ctc (coerce-contract 'parameter/c in))
  (define in-ctc (coerce-contract 'parameter/c in))
  (define out-ctc/f
    (if (equal? out unsupplied)
        #f
        (coerce-contract 'parameter/c out)))
  (cond
    [(and (not impersonator?)
          (chaperone-contract? in-ctc)
          (or (not out-ctc/f) (chaperone-contract? out-ctc/f)))
     (chaperone-parameter/c in-ctc out-ctc/f)]
    [else
     (impersonator-parameter/c in-ctc out-ctc/f)]))

(define ((parameter/c-lnp chaperone-or-impersonate-procedure) ctc)
  (define in-proc (get/build-late-neg-projection (base-parameter/c-in ctc)))
  (define out-proc (if (base-parameter/c-out/f ctc)
                       (get/build-late-neg-projection (base-parameter/c-out/f ctc))
                       in-proc))
  (λ (blame)
    (define blame/c (blame-add-context blame "the parameter of"))
    (define in-proj (in-proc (blame-swap blame/c)))
    (define out-proj (out-proc blame/c))
    (λ (val neg-party)
      (define blame+neg-party (cons blame/c neg-party))
      (cond
        [(parameter? val)
         (chaperone-or-impersonate-procedure
          val
          (case-lambda
            [(x)
             (with-contract-continuation-mark
                 blame+neg-party
               (in-proj x neg-party))]
            [() (λ (res)
                  (with-contract-continuation-mark
                      blame+neg-party
                    (out-proj res neg-party)))])
          impersonator-prop:contracted ctc
          impersonator-prop:blame blame+neg-party)]
        [else
         (raise-blame-error blame #:missing-party neg-party
                            val '(expected "a parameter"))]))))

(define (parameter/c-name ctc)
  (define out (base-parameter/c-out/f ctc))
  (apply build-compound-type-name
         `(parameter/c ,(base-parameter/c-in ctc)
                       ,@(if out
                             (list out)
                             (list)))))

(define (parameter/c-first-order ctc)
  (define tst (contract-first-order (base-parameter/c-out ctc)))
  (λ (x)
    (and (parameter? x)
         (tst (x)))))

(define (parameter/c-stronger this that)
  (and (base-parameter/c? that)
       (cond
         [(or (base-parameter/c-out/f this)
              (base-parameter/c-out/f that))
          (and (contract-struct-stronger? (base-parameter/c-in that)
                                          (base-parameter/c-in this))
               (contract-struct-stronger? (base-parameter/c-out this)
                                          (base-parameter/c-out that)))]
         [else
          (contract-struct-equivalent? (base-parameter/c-in this)
                                       (base-parameter/c-in that))])))

(define (parameter/c-equivalent this that)
  (and (base-parameter/c? that)
       (cond
         [(or (base-parameter/c-out/f this)
              (base-parameter/c-out/f that))
          (and (contract-struct-equivalent? (base-parameter/c-in this)
                                            (base-parameter/c-in that))
               (contract-struct-equivalent? (base-parameter/c-out this)
                                            (base-parameter/c-out that)))]
         [else
          (contract-struct-equivalent? (base-parameter/c-in this)
                                       (base-parameter/c-in that))])))
  
;; in - negative contract
;; out - positive contract or #f
;; out is #f if it was not supplied to `parameter/c`
(struct base-parameter/c (in out/f)
  #:property prop:custom-write custom-write-property-proc)

(define (base-parameter/c-out b-p/c)
  (or (base-parameter/c-out/f b-p/c)
      (base-parameter/c-in b-p/c)))

(struct impersonator-parameter/c base-parameter/c ()
  #:omit-define-syntaxes
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:late-neg-projection (parameter/c-lnp impersonate-procedure)
   #:name parameter/c-name
   #:first-order parameter/c-first-order
   #:stronger parameter/c-stronger
   #:equivalent parameter/c-equivalent))

(struct chaperone-parameter/c base-parameter/c ()
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:trusted trust-me
   #:late-neg-projection (parameter/c-lnp chaperone-procedure)
   #:name parameter/c-name
   #:first-order parameter/c-first-order
   #:stronger parameter/c-stronger
   #:equivalent parameter/c-equivalent))

(define (procedure-arity-includes-equivalent? this that)
  (and (procedure-arity-includes/c? that)
       (= (procedure-arity-includes/c-n this)
          (procedure-arity-includes/c-n that))))
(define-struct procedure-arity-includes/c (n)
  #:property prop:custom-write custom-write-property-proc
  #:omit-define-syntaxes
  #:property prop:flat-contract
  (build-flat-contract-property
   #:trusted trust-me
   #:stronger procedure-arity-includes-equivalent?
   #:equivalent procedure-arity-includes-equivalent?
   #:name (λ (ctc) `(procedure-arity-includes/c ,(procedure-arity-includes/c-n ctc)))
   #:first-order (λ (ctc)
                   (define n (procedure-arity-includes/c-n ctc))
                   (λ (x)
                     (and (procedure? x)
                          (procedure-arity-includes? x n))))))

(define/subexpression-pos-prop (procedure-arity-includes/c n)
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error 'procedure-arity-includes/c
                          "exact-nonnegative-integer?"
                          n))
  (make-procedure-arity-includes/c n))

(define (any/c-flat-contract-property get-name)
  (build-flat-contract-property
   #:trusted trust-me
   #:late-neg-projection (λ (ctc) any/c-blame->neg-party-fn)
   #:stronger (λ (this that) (prop:any/c? that))
   #:equivalent (λ (this that) (prop:any/c? that))
   #:name get-name
   #:generate any/c-random-generate
   #:first-order get-any?))

(define any/c-blame->neg-party-fn (λ (blame) any/c-neg-party-fn))
(define any/c-neg-party-fn (λ (val neg-party) val))

(define (random-any/c env fuel)
  (define env-hash (contract-random-generate-env-hash env))
  (cond
    [(zero? (hash-count env-hash))
     (rand-choice
      [1/3 (any/c-structured-value)]
      [1/3 (any/c-procedure env-hash fuel)]
      [else (any/c-from-predicate-generator env-hash fuel)])]
    [else
     (rand-choice
      [1/4 (oneof (hash-ref env-hash (oneof (hash-keys env-hash))))]
      [1/4 (any/c-structured-value)]
      [1/4 (any/c-procedure env-hash fuel)]
      [else (any/c-from-predicate-generator env-hash fuel)])]))

(define (any/c-structured-value)
  (let loop ([depth 3])
    (cond
      [(zero? depth) (any/c-simple-value)]
      [else
       (rand-choice
        [1/10 (cons (loop (- depth 1)) (loop (- depth 1)))]
        [1/10 (make-vector (random 10) (λ (_) (loop (- depth 1))))]
        [1/10 (make-hash (for/list ([i (in-range (random 10))])
                           (cons (loop (- depth 1))
                                 (loop (- depth 1)))))]
        [1/10 (make-immutable-hash (for/list ([i (in-range (random 10))])
                                     (cons (loop (- depth 1))
                                           (loop (- depth 1)))))]
        [1/10 (box (loop (- depth 1)))]
        [else (any/c-simple-value)])])))

(define (any/c-simple-value)
  (oneof '(0 #f "" () #() -1 1 #t elephant)))

(define (any/c-from-predicate-generator env fuel)
  ((hash-ref predicate-generator-table
             (oneof (hash-keys predicate-generator-table)))
   fuel))
(define (any/c-procedure env fuel)
  (procedure-rename
   (procedure-reduce-arity
    (λ args
      (apply
       values
       (for/list ([i (in-range (rand-nat))])
         (random-any/c env fuel))))
    (rand-nat))
   'random-any/c-generated-procedure))

(define ((any/c-random-generate ctc) fuel)
  (define env (contract-random-generate-get-current-environment))
  (λ () (random-any/c env fuel)))

(define-struct any/c ()
  #:constructor-name any/c
  #:property prop:custom-write custom-write-property-proc
  #:property prop:any/c #f
  #:property prop:flat-contract
  (any/c-flat-contract-property (λ (ctc) 'any/c)))

(define/final-prop _any/c (let ([any/c (any/c)]) any/c))

(define-struct (named-any/c any/c) (name)
  #:constructor-name make-any/c
  #:property prop:flat-contract
  (any/c-flat-contract-property (λ (ctc) (named-any/c-name ctc))))

(define-syntax (any stx)
  (raise-syntax-error 'any "use of 'any' outside the range of an arrow contract" stx))

(define (((none-curried-late-neg-proj ctc) blame) val neg-party)
  (raise-blame-error
   blame #:missing-party neg-party
   val
   '("~s allows no values" given: "~e")
   (none/c-name ctc)
   val))

(define-struct none/c (name)
  #:property prop:custom-write custom-write-property-proc
  #:property prop:none/c #f
  #:property prop:flat-contract
  (build-flat-contract-property
   #:trusted trust-me
   #:late-neg-projection none-curried-late-neg-proj
   #:stronger (λ (this that) #t)
   #:equivalent (λ (this that) (prop:none/c? that))
   #:name (λ (ctc) (none/c-name ctc))
   #:first-order get-none?))

(define/final-prop _none/c (let ([none/c (make-none/c 'none/c)]) none/c))

;; prompt-tag/c
(define-syntax prompt-tag/c
  (syntax-rules (values)
    [(_ ?ctc ... #:call/cc (values ?call/cc ...))
     (-prompt-tag/c (list ?ctc ...) (list ?call/cc ...))]
    [(_ ?ctc ... #:call/cc ?call/cc)
     (-prompt-tag/c (list ?ctc ...) (list ?call/cc))]
    [(_ ?ctc ...) (-prompt-tag/c (list ?ctc ...) (list))]))

;; procedural part of the contract
;; takes two lists of contracts (abort & call/cc contracts)
(define/subexpression-pos-prop (-prompt-tag/c ctc-args call/ccs)
  (define ctcs (coerce-contracts 'prompt-tag/c ctc-args))
  (define call/cc-ctcs (coerce-contracts 'prompt-tag/c call/ccs))
  (cond [(and (andmap chaperone-contract? ctcs)
              (andmap chaperone-contract? call/cc-ctcs))
         (chaperone-prompt-tag/c ctcs call/cc-ctcs)]
        [else
         (impersonator-prompt-tag/c ctcs call/cc-ctcs)]))

(define (prompt-tag/c-name ctc)
  (apply build-compound-type-name
         (append (list 'prompt-tag/c) (base-prompt-tag/c-ctcs ctc)
                 (list '#:call/cc) (base-prompt-tag/c-call/ccs ctc))))

;; build a projection for prompt tags
(define ((prompt-tag/c-late-neg-proj chaperone?) ctc)
  (define proxy (if chaperone? chaperone-prompt-tag impersonate-prompt-tag))
  (define proc-proxy (if chaperone? chaperone-procedure impersonate-procedure))
  (define ho-projs
    (map get/build-late-neg-projection (base-prompt-tag/c-ctcs ctc)))
  (define call/cc-projs
    (map get/build-late-neg-projection (base-prompt-tag/c-call/ccs ctc)))
  (λ (blame)
    (define swapped (blame-swap blame))
    (define ho-neg-projs (for/list ([proj (in-list ho-projs)]) (proj swapped)))
    (define ho-pos-projs (for/list ([proj (in-list ho-projs)]) (proj blame)))
    (define cc-neg-projs (for/list ([proj (in-list call/cc-projs)]) (proj swapped)))
    (define cc-pos-projs (for/list ([proj (in-list call/cc-projs)]) (proj blame)))
    (define (make-proj projs neg-party blame+neg-party)
      (λ vs
        (with-contract-continuation-mark
         blame+neg-party
         (apply values
                (for/list ([proj (in-list projs)]
                           [v (in-list vs)])
                  (proj v neg-party))))))
    (λ (val neg-party)
      (define blame+neg-party (cons blame neg-party))
      ;; now do the actual wrapping
      (cond
        [(continuation-prompt-tag? val)
         ;; prompt/abort projections
         (define proj1 (make-proj ho-pos-projs neg-party blame+neg-party))
         (define proj2 (make-proj ho-neg-projs neg-party blame+neg-party))
         ;; call/cc projections
         (define call/cc-guard (make-proj cc-pos-projs neg-party blame+neg-party))
         (define call/cc-proxy
           (λ (f)
             (proc-proxy
              f
              (λ args
                (apply values (make-proj cc-neg-projs neg-party blame+neg-party) args)))))
         (proxy val
                proj1 proj2
                call/cc-guard call/cc-proxy
                impersonator-prop:contracted ctc
                impersonator-prop:blame blame+neg-party)]
        [else
         (raise-blame-error
          blame #:missing-party neg-party val
          '(expected: "~s" given: "~e")
          (contract-name ctc)
          val)]))))

(define (prompt-tag/c-stronger? this that)
  (and (base-prompt-tag/c? that)
       (pairwise-stronger-contracts?
        (base-prompt-tag/c-ctcs this)
        (base-prompt-tag/c-ctcs that))
       (pairwise-stronger-contracts?
        (base-prompt-tag/c-call/ccs this)
        (base-prompt-tag/c-call/ccs that))))

(define (prompt-tag/c-equivalent? this that)
  (and (base-prompt-tag/c? that)
       (pairwise-equivalent-contracts?
        (base-prompt-tag/c-ctcs this)
        (base-prompt-tag/c-ctcs that))
       (pairwise-equivalent-contracts?
        (base-prompt-tag/c-call/ccs this)
        (base-prompt-tag/c-call/ccs that))))

;; (listof contract) (listof contract)
(define-struct base-prompt-tag/c (ctcs call/ccs))

(define-struct (chaperone-prompt-tag/c base-prompt-tag/c) ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:trusted trust-me
   #:late-neg-projection (prompt-tag/c-late-neg-proj #t)
   #:first-order (λ (ctc) continuation-prompt-tag?)
   #:stronger prompt-tag/c-stronger?
   #:equivalent prompt-tag/c-equivalent?
   #:name prompt-tag/c-name))

(define-struct (impersonator-prompt-tag/c base-prompt-tag/c) ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:late-neg-projection (prompt-tag/c-late-neg-proj #f)
   #:first-order (λ (ctc) continuation-prompt-tag?)
   #:stronger prompt-tag/c-stronger?
   #:equivalent prompt-tag/c-equivalent?
   #:name prompt-tag/c-name))


;; continuation-mark-key/c
(define/subexpression-pos-prop (continuation-mark-key/c ctc-arg)
  (define ctc (coerce-contract 'continuation-mark-key/c ctc-arg))
  (cond [(chaperone-contract? ctc)
         (chaperone-continuation-mark-key/c ctc)]
        [else
         (impersonator-continuation-mark-key/c ctc)]))

(define (continuation-mark-key/c-name ctc)
  (build-compound-type-name
   'continuation-mark-key/c
   (base-continuation-mark-key/c-ctc ctc)))

(define ((continuation-mark-key/c-late-neg-proj proxy) ctc)
  (define ho-proj
    (get/build-late-neg-projection (base-continuation-mark-key/c-ctc ctc)))
  (λ (blame)
    (define swapped (blame-swap blame))
    (define proj1 (ho-proj blame))
    (define proj2 (ho-proj (blame-swap blame)))
    (λ (val neg-party)
      (define blame+neg-party (cons blame neg-party))
      (cond
        [(continuation-mark-key? val)
         (proxy val 
                (λ (v) (with-contract-continuation-mark
                        blame+neg-party
                        (proj1 v neg-party)))
                (λ (v) (with-contract-continuation-mark
                        blame+neg-party
                        (proj2 v neg-party)))
                impersonator-prop:contracted ctc
                impersonator-prop:blame blame+neg-party)]
        [else 
         (unless (contract-first-order-passes? ctc val)
           (raise-blame-error
            blame #:missing-party neg-party
            val
            '(expected: "~s" given: "~e")
            (contract-name ctc)
            val))]))))

(define (continuation-mark-key/c-stronger? this that)
  (and (base-continuation-mark-key/c? that)
       (contract-struct-stronger?
        (base-continuation-mark-key/c-ctc this)
        (base-continuation-mark-key/c-ctc that))))

(define (continuation-mark-key/c-equivalent? this that)
  (and (base-continuation-mark-key/c? that)
       (contract-struct-equivalent?
        (base-continuation-mark-key/c-ctc this)
        (base-continuation-mark-key/c-ctc that))))

(define-struct base-continuation-mark-key/c (ctc))

(define-struct (chaperone-continuation-mark-key/c
                base-continuation-mark-key/c)
  ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:trusted trust-me
   #:late-neg-projection (continuation-mark-key/c-late-neg-proj chaperone-continuation-mark-key)
   #:first-order (λ (ctc) continuation-mark-key?)
   #:stronger continuation-mark-key/c-stronger?
   #:equivalent continuation-mark-key/c-equivalent?
   #:name continuation-mark-key/c-name))

(define-struct (impersonator-continuation-mark-key/c
                base-continuation-mark-key/c)
  ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:late-neg-projection (continuation-mark-key/c-late-neg-proj impersonate-continuation-mark-key)
   #:first-order (λ (ctc) continuation-mark-key?)
   #:stronger continuation-mark-key/c-stronger?
   #:equivalent continuation-mark-key/c-equivalent?
   #:name continuation-mark-key/c-name))

;; evt/c : Contract * -> Contract
;; Contract combinator for synchronizable events
(define (evt/c . maybe-ctcs)
  (define ctcs (coerce-contracts 'evt/c maybe-ctcs))
  (for ([ctc ctcs])
    (unless (chaperone-contract? ctc)
      (raise-argument-error 'evt/c "chaperone-contract?" ctc)))
  (make-chaperone-evt/c ctcs))

;; evt/c-proj : Contract -> (Blame -> Any -> Any)
;; Constructs the projection for evt/c
(define (evt/c-proj evt-ctc)
  (define ctcs (chaperone-evt/c-ctcs evt-ctc))
  (define projs (map contract-projection ctcs))
  (λ (blame)
    (define ((checker val blame+neg-party) . args)
      (with-contract-continuation-mark
       blame+neg-party
       (define expected-num (length ctcs))
       (unless (= (length args) expected-num)
         (raise-blame-error
          blame val
          `(expected: "event that produces ~a values"
            given: "event that produces ~a values")
          expected-num
          (length args)))
       (apply
        values
        (for/list ([proj projs] [val args])
          ((proj blame) val)))))
    (define ((generator blame+neg-party) evt)
      (values evt (checker evt blame+neg-party)))
    (λ (val neg-party)
      (unless (contract-first-order-passes? evt-ctc val)
        (raise-blame-error
         blame val #:missing-party neg-party
         '(expected: "~s" given: "~e")
         (contract-name evt-ctc)
         val))
      (define blame+neg-party (cons blame neg-party))
      (chaperone-evt val
                     (generator blame+neg-party)
                     impersonator-prop:contracted evt-ctc
                     impersonator-prop:blame blame+neg-party))))

;; evt/c-first-order : Contract -> Any -> Boolean
;; First order check for evt/c
(define ((evt/c-first-order ctc) v) (evt? v))

;; evt/c-name : Contract -> Sexp
;; Construct the name of the contract
(define (evt/c-name ctc)
  (apply build-compound-type-name
         (cons 'evt/c (chaperone-evt/c-ctcs ctc))))

;; evt/c-stronger? : Contract Contract -> Boolean
(define (evt/c-stronger? this that)
  (cond
    [(chaperone-evt/c? that)
     (define this-ctcs (chaperone-evt/c-ctcs this))
     (define that-ctcs (chaperone-evt/c-ctcs that))
     (pairwise-stronger-contracts? this-ctcs that-ctcs)]
    [else #f]))

(define (evt/c-equivalent? this that)
  (cond
    [(chaperone-evt/c? that)
     (define this-ctcs (chaperone-evt/c-ctcs this))
     (define that-ctcs (chaperone-evt/c-ctcs that))
     (pairwise-equivalent-contracts? this-ctcs that-ctcs)]
    [else #f]))

;; ctcs - Listof<Contract>
(define-struct chaperone-evt/c (ctcs)
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:trusted trust-me
   #:late-neg-projection evt/c-proj
   #:first-order evt/c-first-order
   #:stronger evt/c-stronger?
   #:equivalent evt/c-equivalent?
   #:name evt/c-name))

;; channel/c
(define/subexpression-pos-prop (channel/c ctc-arg)
  (define ctc (coerce-contract 'channel/c ctc-arg))
  (cond [(chaperone-contract? ctc)
         (chaperone-channel/c ctc)]
        [else
         (impersonator-channel/c ctc)]))

(define (channel/c-name ctc)
  (build-compound-type-name
   'channel/c
   (base-channel/c-ctc ctc)))

(define ((channel/c-late-neg-proj proxy) ctc)
  (define ho-proj
    (get/build-late-neg-projection (base-channel/c-ctc ctc)))
  (λ (blame)
    (define pos-proj (ho-proj blame))
    (define neg-proj (ho-proj (blame-swap blame)))
    (define (proj1 neg-party)
      (define blame+neg-party (cons blame neg-party))
      (λ (ch)
        (values ch (λ (v)
                     (with-contract-continuation-mark
                      blame+neg-party
                      (pos-proj v neg-party))))))
    (define (proj2 neg-party)
      (define blame+neg-party (cons blame neg-party))
      (λ (ch v)
        (with-contract-continuation-mark
         blame+neg-party
         (neg-proj v neg-party))))
    (λ (val neg-party)
      (cond
        [(channel? val)
         (proxy val 
                (proj1 neg-party)
                (proj2 neg-party)
                impersonator-prop:contracted ctc
                impersonator-prop:blame (cons blame neg-party))]
        [else
         (raise-blame-error
          blame #:missing-party neg-party
          val '(expected: "~s" given: "~e")
          (contract-name ctc)
          val)]))))

(define (channel/c-first-order ctc) channel?)

(define (channel/c-stronger? this that)
  (and (base-channel/c? that)
       (contract-struct-stronger?
        (base-channel/c-ctc this)
        (base-channel/c-ctc that))))

(define (channel/c-equivalent? this that)
  (and (base-channel/c? that)
       (contract-struct-equivalent?
        (base-channel/c-ctc this)
        (base-channel/c-ctc that))))

(define-struct base-channel/c (ctc))

(define-struct (chaperone-channel/c base-channel/c)
  ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:trusted trust-me
   #:late-neg-projection (channel/c-late-neg-proj chaperone-channel)
   #:first-order channel/c-first-order
   #:stronger channel/c-stronger?
   #:equivalent channel/c-equivalent?
   #:name channel/c-name))

(define-struct (impersonator-channel/c base-channel/c)
  ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:late-neg-projection (channel/c-late-neg-proj impersonate-channel)
   #:first-order channel/c-first-order
   #:stronger channel/c-stronger?
   #:equivalent channel/c-equivalent?
   #:name channel/c-name))


(define (flat-contract-predicate x)
  (contract-struct-first-order
   (coerce-flat-contract 'flat-contract-predicate x)))

(define (flat-contract predicate) (coerce-flat-contract 'flat-contract predicate))
(define (flat-named-contract name pre-contract [generate #f])
  (cond
    [(and (not generate)
          (coerce-contract/f pre-contract name))
     =>
     values]
    [(flat-contract? pre-contract)
     (make-predicate-contract name (flat-contract-predicate pre-contract) generate #f)]
    [else
     (raise-argument-error 'flat-named-contract
                           "flat-contract?"
                           pre-contract)]))

(define printable/c
  (flat-named-contract
   'printable/c
   (λ (x)
     (and (let printable? ([x x])
            (or (symbol? x)
                (string? x)
                (bytes? x)
                (boolean? x)
                (char? x)
                (null? x)
                (number? x)
                (regexp? x)
                (prefab-struct-key x) ;; this cannot be last, since it doesn't return just #t
                (and (pair? x)
                     (printable? (car x))
                     (printable? (cdr x)))
                (and (vector? x)
                     (andmap printable? (vector->list x)))
                (and (box? x)
                     (printable? (unbox x)))
                (and (hash? x)
                     (immutable? x)
                     (for/and ([(k v) (in-hash x)])
                       (and (printable? k)
                            (printable? v))))))
          #t))))


(define natural-number/c
  (flat-named-contract
   'natural-number/c
   (λ (x)
     (and (number? x)
          (integer? x)
          (exact? x)
          (x . >= . 0)))
   (λ (fuel) (λ () (exact-nonnegative-integer-gen fuel)))))

;; rename-contract : contract any/c -> contract
;; If the argument is a flat contract, so is the result.
(define (rename-contract ctc name)
  (unless (contract? ctc)
    (raise-type-error 'rename-contract "contract?" ctc))
  (let ([ctc (coerce-contract 'rename-contract ctc)])
    (if (flat-contract? ctc)
        (flat-named-contract name (flat-contract-predicate ctc) (contract-struct-generate ctc))
        (let* ([make-contract (if (chaperone-contract? ctc) make-chaperone-contract make-contract)])
          (define (rename-contract-stronger? this other)
            (contract-struct-stronger? ctc other))
          (define (rename-contract-equivalent? this other)
            (contract-struct-equivalent? ctc other))
          (make-contract #:name name
                         #:late-neg-projection (get/build-late-neg-projection ctc)
                         #:first-order (contract-first-order ctc)
                         #:stronger rename-contract-stronger?
                         #:equivalent rename-contract-equivalent?
                         #:generate (contract-struct-generate ctc)
                         #:exercise (contract-struct-exercise ctc)
                         #:list-contract? (list-contract? ctc))))))

(define (if/c predicate then/c else/c)
  (unless (procedure? predicate)
    (raise-type-error 'if/c "procedure?" predicate))
  (unless (procedure-arity-includes? predicate 1)
    (raise-type-error 'if/c "procedure that accepts 1 argument" predicate))
  (define then-ctc (coerce-contract 'if/c then/c))
  (define else-ctc (coerce-contract 'if/c else/c))
  (cond
    [(and (flat-contract? then-ctc)
          (flat-contract? else-ctc))
     (define then-pred (flat-contract-predicate then-ctc))
     (define else-pred (flat-contract-predicate else-ctc))
     (define name `(if/c ,(object-name predicate)
                         ,(contract-name then-pred)
                         ,(contract-name else-pred)))
     (define (pred x)
       (if (predicate x) (then-pred x) (else-pred x)))
     (flat-named-contract name pred)]
    [(and (chaperone-contract? then-ctc)
          (chaperone-contract? else-ctc))
     (chaperone-if/c predicate then-ctc else-ctc)]
    [else
     (impersonator-if/c predicate then-ctc else-ctc)]))

(define (if/c-first-order ctc)
  (define predicate (base-if/c-predicate ctc))
  (define thn (contract-first-order (base-if/c-thn ctc)))
  (define els (contract-first-order (base-if/c-els ctc)))
  (λ (x) (if (predicate x) (thn x) (els x))))

(define (if/c-name ctc)
  (define predicate (base-if/c-predicate ctc))
  (define thn (contract-name (base-if/c-thn ctc)))
  (define els (contract-name (base-if/c-els ctc)))
  `(if/c ,(object-name predicate) ,thn ,els))

(define (if/c-late-neg-proj ctc)
  (define predicate (base-if/c-predicate ctc))
  (define thn (get/build-late-neg-projection (base-if/c-thn ctc)))
  (define els (get/build-late-neg-projection (base-if/c-els ctc)))
  (λ (blame)
    (define thn-proj (thn blame))
    (define els-proj (els blame))
    (λ (val neg-party)
      (if (predicate val)
          (thn-proj val neg-party)
          (els-proj val neg-party)))))

(define-struct base-if/c (predicate thn els)
  #:property prop:custom-write custom-write-property-proc)
(define-struct (chaperone-if/c base-if/c) ()
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:trusted trust-me
   #:late-neg-projection if/c-late-neg-proj
   #:first-order if/c-first-order
   #:name if/c-name))

(define-struct (impersonator-if/c base-if/c) ()
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:late-neg-projection if/c-late-neg-proj
   #:first-order if/c-first-order
   #:name if/c-name))


(define (pairwise-stronger-contracts? c1s c2s)
  (let loop ([c1s c1s]
             [c2s c2s])
    (cond
      [(and (null? c1s) (null? c2s)) #t]
      [(and (pair? c1s) (pair? c2s))
       (and (contract-struct-stronger? (car c1s) (car c2s))
            (loop (cdr c1s) (cdr c2s)))]
      [else #f])))

(define (pairwise-equivalent-contracts? c1s c2s)
  (let loop ([c1s c1s]
             [c2s c2s])
    (cond
      [(and (null? c1s) (null? c2s)) #t]
      [(and (pair? c1s) (pair? c2s))
       (and (contract-struct-equivalent? (car c1s) (car c2s))
            (loop (cdr c1s) (cdr c2s)))]
      [else #f])))

(define (suggest/c _ctc field message)
  (define ctc (coerce-contract 'suggest/c _ctc))
  (unless (string? field)
    (raise-argument-error 'suggest/c
                          "string?"
                          1 _ctc field message))
  (unless (string? message)
    (raise-argument-error 'suggest/c
                          "string?"
                          2 _ctc field message))
  (define ctc-lnp (contract-late-neg-projection ctc))
  (define constructor
    (cond
      [(flat-contract? ctc) make-flat-contract]
      [(chaperone-contract? ctc) make-chaperone-contract]
      [else make-contract]))
  (constructor
   #:name (contract-name ctc)
   #:first-order (contract-first-order ctc)
   #:late-neg-projection (λ (b) (ctc-lnp (blame-add-extra-field b field message)))
   #:stronger (λ (this that) (contract-struct-stronger? ctc that))
   #:equivalent (λ (this that) (contract-struct-equivalent? ctc that))
   #:list-contract? (list-contract? ctc)))

(define (flat-contract-with-explanation ? #:name [name (object-name ?)])
  (define (call-? x)
    (define reason (? x))
    (unless (or (boolean? reason)
                (and (procedure? reason)
                     (procedure-arity-includes? reason 1)))
      (raise-argument-error 'flat-contract-with-explanation
                            (format "~s" '(or/c boolean? (-> blame? any)))
                            reason))
    reason)
  (make-flat-contract
   #:name name
   #:first-order (λ (x) (equal? #t (call-? x)))
   #:late-neg-projection
   (λ (b)
     (λ (x neg-party)
       (define accept-or-reason (call-? x))
       (cond
         [(equal? #t accept-or-reason)
          x]
         [(equal? #f accept-or-reason)
          (raise-blame-error
           b x
           '(expected: "~a" given: "~e")
           (object-name ?)
           x)]
         [else
          (accept-or-reason (blame-add-missing-party b neg-party))
          (error 'flat-contract-with-explanation
                 (string-append
                   "expected that result of the first argument, when it"
                   " is a procedure, to always escape when called"
                   " (by calling raise-blame-error with the arguments it was given)"))])))))
