#lang racket/base

(require (for-syntax racket/base
                     "arr-util.rkt")
         racket/promise
         racket/list
         (only-in "../../private/promise.rkt" prop:force promise-forcer)
         "../../private/math-predicates.rkt"
         "prop.rkt"
         "blame.rkt"
         "guts.rkt"
         "rand.rkt"
         "generate.rkt"
         "generate-base.rkt"
         "misc.rkt"
         "list.rkt")

(provide (rename-out [_and/c and/c]) integer-in)

(define (and-name ctc)
  (apply build-compound-type-name 'and/c (base-and/c-ctcs ctc)))

(define (and-first-order ctc)
  (let ([tests (map contract-first-order (base-and/c-ctcs ctc))])
    (λ (x) (for/and ([test (in-list tests)]) (test x)))))

(define (late-neg-and-proj ctc)
  (define mk-pos-projs (map get/build-late-neg-projection (base-and/c-ctcs ctc)))
  (λ (blame)
    (define projs
      (for/list ([c (in-list mk-pos-projs)]
                 [n (in-naturals 1)])
        (c (blame-add-context blame (format "the ~a conjunct of" (n->th n))))))
    (λ (val neg-party)
      (let loop ([projs (cdr projs)]
                 [val ((car projs) val neg-party)])
        (cond
          [(null? projs) val]
          [else
           (loop (cdr projs)
                 ((car projs) val neg-party))])))))

(define (first-order-late-neg-and-proj ctc)
  (define predicates (first-order-and/c-predicates ctc))
  (define blame-accepters (map get/build-late-neg-projection (base-and/c-ctcs ctc)))
  (λ (blame)
    (define new-blame (blame-add-context blame "an and/c case of"))
    (define projs (map (λ (f) (f new-blame)) blame-accepters))
    (λ (val neg-party)
      (let loop ([predicates predicates]
                 [projs projs])
        (cond
          [(null? predicates) val]
          [else
           (cond
             [((car predicates) val)
              (loop (cdr predicates) (cdr projs))]
             [else
              ((car projs) val neg-party)])])))))

(define (and-stronger? this that)
  (and (base-and/c? that)
       (pairwise-stronger-contracts? (base-and/c-ctcs this)
                                     (base-and/c-ctcs that))))

(define (and-equivalent? this that)
  (and (base-and/c? that)
       (pairwise-equivalent-contracts? (base-and/c-ctcs this)
                                       (base-and/c-ctcs that))))

(define (and/c-generate? ctc)
  (cond
    [(and/c-check-nonneg ctc real?) => values]
    [(and/c-check-nonneg ctc rational?) => values]
    [(null? (base-and/c-ctcs ctc)) => (λ (fuel) #f)]
    [else
     (define flat (filter flat-contract? (base-and/c-ctcs ctc)))
     (define ho (filter (λ (x) (not (flat-contract? x))) (base-and/c-ctcs ctc)))
     (cond
       [(null? ho)
        (λ (fuel)
          (define candidates
            (let loop ([sub-contracts-after (cdr (base-and/c-ctcs ctc))]
                       [sub-contract (car (base-and/c-ctcs ctc))]
                       [sub-contracts-before '()]
                       [candidates '()])
              (define sub-gen (contract-random-generate/choose sub-contract fuel))
              (define new-candidates
                (cond
                  [sub-gen
                   (cons (cons sub-gen (append (reverse sub-contracts-before) sub-contracts-after))
                         candidates)]
                  [else candidates]))
              (cond
                [(null? sub-contracts-after) new-candidates]
                [else (loop (cdr sub-contracts-after)
                            (car sub-contracts-after)
                            (cons sub-contract sub-contracts-before)
                            new-candidates)])))
          (cond
            [(null? candidates) #f]
            [else
             (λ ()
               (let loop ([attempts 10])
                 (cond
                   [(zero? attempts) contract-random-generate-fail]
                   [else
                    (define which (oneof candidates))
                    (define val ((car which)))
                    (cond
                      [(andmap (λ (p?) (p? val)) (cdr which))
                       val]
                      [else
                       (loop (- attempts 1))])])))]))]
       [(null? (cdr ho))
        (λ (fuel)
          (define ho-gen (contract-random-generate/choose (car ho) fuel))
          (cond
            [ho-gen 
             (λ ()
               (let loop ([attempts 10])
                 (cond
                   [(zero? attempts) contract-random-generate-fail]
                   [else
                    (define val (ho-gen))
                    (cond
                      [(andmap (λ (p?) (p? val)) flat)
                       val]
                      [else
                       (loop (- attempts 1))])])))]
            [else #f]))]
       [else
        (λ (fuel) #f)])]))

(define (and/c-check-nonneg ctc pred)
  (define sub-contracts (base-and/c-ctcs ctc))
  (cond
    [(pairwise-stronger-contracts?
      (list (coerce-contract 'and/c-check-nonneg pred) (not/c negative?))
      sub-contracts)
     (define go (hash-ref predicate-generator-table pred))
     (λ (fuel)
       (λ ()
         (abs (go fuel))))]
    [else #f]))

(define-struct base-and/c (ctcs))
(define-struct (first-order-and/c base-and/c) (predicates)
  #:property prop:custom-write custom-write-property-proc
  #:property prop:flat-contract
  (build-flat-contract-property
   #:trusted trust-me
   #:late-neg-projection first-order-late-neg-and-proj
   #:name and-name
   #:first-order and-first-order
   #:stronger and-stronger?
   #:generate and/c-generate?
   #:equivalent and-equivalent?))
(define-struct (chaperone-and/c base-and/c) ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:chaperone-contract
  (build-chaperone-contract-property
   #:trusted trust-me
   #:late-neg-projection late-neg-and-proj
   #:name and-name
   #:first-order and-first-order
   #:stronger and-stronger?
   #:generate and/c-generate?
   #:equivalent and-equivalent?))
(define-struct (impersonator-and/c base-and/c) ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:contract
  (build-contract-property
   #:trusted trust-me
   #:late-neg-projection late-neg-and-proj
   #:name and-name
   #:first-order and-first-order
   #:stronger and-stronger?
   #:generate and/c-generate?
   #:equivalent and-equivalent?))

(define-syntax (_and/c stx)
  (syntax-case stx (pair? listof)
    [(_ pair? (listof e))
     #'(non-empty-listof e)]
    [(_ (listof e) pair?)
     #'(non-empty-listof e)]
    [(_ . args)
     #'(and/c . args)]
    [x
     (identifier? #'x)
     #'and/c]))

(define/subexpression-pos-prop/name and/c-name and/c
  (case-lambda
    [() any/c]
    [raw-arg*
     (define raw-args (remove-duplicates (filter-not prop:any/c? raw-arg*) eq?))
     (cond
       [(null? raw-args) any/c]
       [(null? (cdr raw-args)) (coerce-contract 'and/c (car raw-args))]
       [else
        (define args (coerce-contracts 'and/c raw-args))
        (define the-and/c
          (cond
            [(andmap flat-contract? args)
             (define preds (map flat-contract-predicate args))
             (cond
               [(and (pair? (cdr preds))
                     (null? (cddr preds)))
                (cond
                  [(eq? (car preds) real?)
                   (define second-pred (cadr preds))
                   (cond
                     [(eq? second-pred negative?)
                      (renamed-<-ctc 0 `(and/c real? negative?))]
                     [(eq? second-pred positive?)
                      (renamed->-ctc 0 `(and/c real? positive?))]
                     [else
                      (define second-contract (cadr args))
                      (cond
                        [(equal? (contract-name second-contract) '(not/c positive?))
                         (renamed-between/c -inf.0 0 `(and/c real? (not/c positive?)))]
                        [(equal? (contract-name second-contract) '(not/c negative?))
                         (renamed-between/c 0 +inf.0 `(and/c real? (not/c negative?)))]
                        [else (make-first-order-and/c args preds)])])]
                  [(or (eq? (car preds) exact-nonnegative-integer?)
                       (eq? (car preds) natural?)
                       (eq? (cadr preds) exact-nonnegative-integer?)
                       (eq? (cadr preds) natural?))
                   (define other (if (procedure? (car preds)) (cadr args) (car args)))
                   (cond
                     [(between/c-s? other)
                      (define other-low (between/c-s-low other))
                      (define other-high (between/c-s-high other))
                      (integer-in (exact-ceiling (max 0 (if (= other-low -inf.0) 0 other-low)))
                                  (if (= other-high +inf.0) #f (exact-floor other-high)))]
                     [else (make-first-order-and/c args preds)])]
                  [(or (eq? (car preds) exact-positive-integer?)
                       (eq? (cadr preds) exact-positive-integer?))
                   (define other (if (procedure? (car preds)) (cadr args) (car args)))
                   (cond
                     [(between/c-s? other)
                      (define other-low (between/c-s-low other))
                      (define other-high (between/c-s-high other))
                      (integer-in (exact-ceiling (max 1 (if (= other-low -inf.0) 1 other-low)))
                                  (if (= other-high +inf.0) #f (exact-floor other-high)))]
                     [else (make-first-order-and/c args preds)])]
                  [(or (eq? (car preds) exact-integer?)
                       (eq? (cadr preds) exact-integer?))
                   (define other (if (procedure? (car preds)) (cadr args) (car args)))
                   (cond
                     [(between/c-s? other)
                      (define other-low (between/c-s-low other))
                      (define other-high (between/c-s-high other))
                      (integer-in (if (= other-low -inf.0) #f (exact-ceiling other-low))
                                  (if (= other-high +inf.0) #f (exact-floor other-high)))]
                     [else (make-first-order-and/c args preds)])]
                  [else (make-first-order-and/c args preds)])]
               [(and (pair? (cdr preds))
                     (pair? (cddr preds))
                     (null? (cdddr preds)))
                (cond
                  [(or (eq? (car preds) exact-integer?)
                       (eq? (cadr preds) exact-integer?)
                       (eq? (caddr preds) exact-integer?))
                   (define lb #f)
                   (define ub #f)
                   (for ([ctc (in-list args)])
                     (cond
                       [(between/c-s? ctc)
                        (define lo (between/c-s-low ctc))
                        (define hi (between/c-s-high ctc))
                        (cond
                          [(and (= lo -inf.0) (integer? hi))
                           (set! ub (inexact->exact hi))]
                          [(and (= hi +inf.0) (integer? lo))
                           (set! lb (inexact->exact lo))])]
                       [(</>-ctc? ctc)
                        (define x (</>-ctc-x ctc))
                        (when (integer? x)
                          (cond
                            [(<-ctc? ctc) (set! ub (- (inexact->exact x) 1))]
                            [(>-ctc? ctc) (set! lb (+ (inexact->exact x) 1))]))]))
                   (if (and lb ub)
                       (integer-in lb ub)
                       (make-first-order-and/c args preds))]
                  [else (make-first-order-and/c args preds)])]
               [else (make-first-order-and/c args preds)])]
            [(andmap chaperone-contract? args)
             (make-chaperone-and/c args)]
            [else (make-impersonator-and/c args)]))
        (if (ormap prop:none/c? args)
            (make-none/c (contract-name the-and/c))
            the-and/c)])]))

(define (exact-floor x) (floor (inexact->exact x)))
(define (exact-ceiling x) (ceiling (inexact->exact x)))

(define (integer-in-name ctc)
  (define start (integer-in-ctc-start ctc))
  (define end (integer-in-ctc-end ctc))
  (cond
    [(and (not end) (equal? start 0)) 'natural?]
    [(and (not end) (equal? start 1)) 'exact-positive-integer?]
    [(or start end)
     `(integer-in ,(integer-in-ctc-start ctc)
                  ,(integer-in-ctc-end ctc))]
    [else 'exact-integer?]))

(define (integer-in-first-order ctc)
  (define start (integer-in-ctc-start ctc))
  (define end (integer-in-ctc-end ctc))
  (cond
    [(and start end) (λ (x) (and (exact-integer? x) (<= start x end)))]
    [start
     (case start
       [(0) exact-nonnegative-integer?]
       [(1) exact-positive-integer?]
       [else
        (λ (x) (and (exact-integer? x) (<= start x)))])]
    [end (λ (x) (and (exact-integer? x) (<= x end)))]
    [else exact-integer?]))

(define (integer-in-stronger this that)
  (cond
    [(integer-in-ctc? that)
     (define this-start (or (integer-in-ctc-start this) -inf.0))
     (define this-end (or (integer-in-ctc-end this) +inf.0))
     (define that-start (or (integer-in-ctc-start that) -inf.0))
     (define that-end (or (integer-in-ctc-end that) +inf.0))
     (<= that-start this-start this-end that-end)]
    [(between/c-s? that)
     (define that-low (between/c-s-low that))
     (define that-high (between/c-s-high that))
     (define this-start (or (integer-in-ctc-start this) -inf.0))
     (define this-end (or (integer-in-ctc-end this) +inf.0))
     (<= that-low this-start this-end that-high)]
    [else #f]))

(define (integer-in-equivalent this that)
  (cond
    [(integer-in-ctc? that)
     (define this-start (or (integer-in-ctc-start this) -inf.0))
     (define this-end (or (integer-in-ctc-end this) +inf.0))
     (define that-start (or (integer-in-ctc-start that) -inf.0))
     (define that-end (or (integer-in-ctc-end that) +inf.0))
     (and (= that-start this-start) (= this-end that-end))]
    [else #f]))

(define (integer-in-generate ctc)
  (define start (integer-in-ctc-start ctc))
  (define end (integer-in-ctc-end ctc))
  (define max-random-range 4294967087)
  (cond
    [(or start end)
     (define _start (or start (- end max-random-range)))
     (define _end (or end (+ start max-random-range)))
     (define upper-bound (min 4294967087 (+ (- _end _start) 1)))
     (λ (fuel)
       (and (>= upper-bound 1)
            (λ ()
              (+ _start (random upper-bound)))))]
    [else
     (λ (fuel)
       (λ ()
         (cond
           [(zero? (random 20)) 0]
           [else
            (* (if (zero? (random 2)) -1 1)
               (+ (expt 2 (geo-dist 1/2))
                  (geo-dist 1/2)))])))]))

(struct integer-in-ctc (start end)
  #:property prop:custom-write custom-write-property-proc
  #:property prop:flat-contract
  (build-flat-contract-property
   #:trusted trust-me
   #:name integer-in-name
   #:first-order integer-in-first-order
   #:stronger integer-in-stronger
   #:generate integer-in-generate
   #:equivalent integer-in-equivalent))

(struct renamed-integer-in integer-in-ctc (name)
  #:property prop:flat-contract
  (build-flat-contract-property
   #:trusted trust-me
   #:name (λ (ctc) (renamed-integer-in-name ctc))
   #:first-order integer-in-first-order
   #:stronger integer-in-stronger
   #:equivalent integer-in-equivalent
   #:generate integer-in-generate))

(define (geo-dist p)
  (let loop ([n 0])
    (cond
      [(< (random) p) (loop (+ n 1))]
      [else n])))

(define/final-prop (integer-in start end)
  (define (|(or/c #f exact-integer?)| x) (or (not x) (exact-integer? x)))
  (check-two-args 'integer-in start end |(or/c #f exact-integer?)| |(or/c #f exact-integer?)|)
  (cond
    [(and start end (= start end))
     (_and/c start exact?)]
    [else
     (integer-in-ctc start end)]))

(define integer-in-ff (integer-in #f #f))
(define integer-in-0f (integer-in 0 #f))
(define integer-in-1f (integer-in 1 #f))

;; passing only defined names here gives the demodularizer license to prune:
(set-some-basic-integer-in-contracts! renamed-integer-in
                                      integer-in-ff
                                      integer-in-0f
                                      integer-in-1f)
