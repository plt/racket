#lang racket/base

(require redex/reduction-semantics
         (only-in redex/private/generate-term pick-an-index)
         racket/list
         racket/match
         racket/contract
         math/base)

(provide (all-defined-out))
(define the-error "substitutes inside of λ that binds the sub variable")


(define-language stlc
  (M N ::= 
     (λ (x σ) M)
     (M N)
     number
     x
     c)
  (Γ (x σ Γ)
     •)
  (σ τ ::=
     int
     (list int)
     (σ → τ))
  (c d ::= cons nil hd tl)
  ((x y) variable-not-otherwise-mentioned)
  
  (v (λ (x τ) M)
     c
     number
     (cons number)
     ((cons number) v))
  (E hole
     (E M)
     (v E)))

(define-judgment-form stlc
  #:mode (typeof I I O)
  #:contract (typeof Γ M σ)
  
  [---------------------
   (typeof Γ number int)]
  
  [---------------------------
   (typeof Γ c (const-type c))]
  
  [(where τ (lookup Γ x))
   ----------------------
   (typeof Γ x τ)]
  
  [(typeof (x σ Γ) M σ_2)
   --------------------------------
   (typeof Γ (λ (x σ) M) (σ → σ_2))]
  
  [(typeof Γ M (σ → σ_2))
   (typeof Γ M_2 σ)
   ----------------------
   (typeof Γ (M M_2) σ_2)])

(define-metafunction stlc
  const-type : c -> σ
  [(const-type nil)
   (list int)]
  [(const-type cons)
   (int → ((list int) → (list int)))]
  [(const-type hd)
   ((list int) → int)]
  [(const-type tl)
   ((list int) → (list int))])

(define-metafunction stlc
  lookup : Γ x -> σ or #f
  [(lookup (x σ Γ) x)
   σ]
  [(lookup (x σ Γ) x_2)
   (lookup Γ x_2)]
  [(lookup • x)
   #f])

(define red
  (reduction-relation
   stlc
   (--> (in-hole E ((λ (x τ) M) v))
        (in-hole E (subst M x v))
        "βv")
   (--> (in-hole E (hd ((cons v_1) v_2)))
        (in-hole E v_1)
        "hd")
   (--> (in-hole E (tl ((cons v_1) v_2)))
        (in-hole E v_2)
        "tl")
   (--> (in-hole E (hd nil))
        "error"
        "hd-err")
   (--> (in-hole E (tl nil))
        "error"
        "tl-err")))


(define-metafunction stlc
  subst : M x M -> M
  [(subst x x M)
   M]
  [(subst y x M)
   y]
  [(subst (λ (x_1 τ) M) x_2 v)
   (λ (x_new τ) (subst (replace M x_1 x_new) x_2 v))
   (where x_new ,(variable-not-in (term (x_1 e x_2))
                                  (term x_1)))]
  [(subst (M N) x M_x)
   ((subst M x M_x) (subst N x M_x))]
  [(subst (c M) x M_x)
   (c (subst M x M_x))]
  [(subst M x M_x)
   M])

(define-metafunction stlc
  [(replace (any_1 ...) x_1 x_new)
   ((replace any_1 x_1 x_new) ...)]
  [(replace x_1 x_1 x_new)
   x_new]
  [(replace any_1 x_1 x_new)
   any_1])

(define M? (redex-match stlc M))
(define/contract (Eval M)
  (-> M? (or/c M? "error"))
  (define M-t (judgment-holds (typeof • ,M τ) τ))
  (unless (pair? M-t)
    (error 'Eval "doesn't typecheck: ~s" M))
  (define res (apply-reduction-relation* red M))
  (unless (= 1 (length res))
    (error 'Eval "internal error: not exactly 1 result ~s => ~s" M res))
  (define ans (car res))
  (if (equal? "error" ans)
      "error"
      (let ([ans-t (judgment-holds (typeof • ,ans τ) τ)])
        (unless (equal? M-t ans-t)
          (error 'Eval "internal error: type soundness fails for ~s" M))
        ans)))

(define x? (redex-match stlc x))

(define v? (redex-match stlc v))
(define τ? (redex-match stlc τ))
(define/contract (type-check M)
  (-> M? (or/c τ? #f))
  (define M-t (judgment-holds (typeof • ,M τ) τ))
  (cond
    [(empty? M-t)
     #f]
    [(null? (cdr M-t))
     (car M-t)]
    [else
     (error 'type-check "non-unique type: ~s : ~s" M M-t)]))

(test-equal (type-check (term 5))
            (term int))
(test-equal (type-check (term (5 5)))
            #f)

(define (progress-holds? M)
  (if (type-check M)
      (or (v? M)
          (not (null? (apply-reduction-relation red (term ,M)))))
      #t))

(define (interesting-term? M)
  (and (type-check M)
       (term (uses-bound-var? () ,M))))

(define-metafunction stlc
  [(uses-bound-var? (x_0 ... x_1 x_2 ...) x_1)
   #t]
  [(uses-bound-var? (x_0 ...) (λ (x τ) M))
   (uses-bound-var? (x x_0 ...) M)]
  [(uses-bound-var? (x ...) (M N))
   ,(or (term (uses-bound-var? (x ...) M))
        (term (uses-bound-var? (x ...) N)))]
  [(uses-bound-var? (x ...) (cons M))
   (uses-bound-var? (x ...) M)]
  [(uses-bound-var? (x ...) any)
   #f])

(define (really-interesting-term? M)
  (and (interesting-term? M)
       (term (applies-bv? () ,M))))

(define-metafunction stlc
  [(applies-bv? (x_0 ... x_1 x_2 ...) (x_1 M))
   #t]
  [(applies-bv? (x_0 ...) (λ (x τ) M))
   (applies-bv? (x x_0 ...) M)]
  [(applies-bv? (x ...) (M N))
   ,(or (term (applies-bv? (x ...) M))
        (term (applies-bv? (x ...) N)))]
  [(applies-bv? (x ...) (cons M))
   (applies-bv? (x ...) M)]
  [(applies-bv? (x ...) any)
   #f])

(define (reduction-step-count/func red v?)
  (λ (term)
    (let loop ([t term]
               [n 0])
      (define res (apply-reduction-relation red t))
      (cond 
        [(and (empty? res)
              (v? t))
         n]
        [(and (empty? res)
              (equal? t "error"))
         n]
        [(= (length res) 1)
         (loop (car res) (add1 n))]
        [else
         (error 'reduction-step-count "failed reduction: ~s\n~s\n~s" term t res)]))))

(define reduction-step-count
  (reduction-step-count/func red v?))

(define (generate-M-term)
  (generate-term stlc M 5))

(define (generate-M-term-from-red)
  (generate-term #:source red 5))

(define (generate-typed-term)
  (match (generate-term stlc 
                        #:satisfying
                        (typeof • M τ)
                        5)
    [`(typeof • ,M ,τ)
     M]
    [#f #f]))

(define (generate-typed-term-from-red)
  (match (case (random 5)
           [(0)
            (generate-term stlc #:satisfying (typeof • ((λ (x τ_x) M) v) ((list int) → (list int))) 5)]
           [(1)
            (generate-term stlc #:satisfying (typeof • (hd ((cons v_1) v_2)) ((list int) → (list int))) 5)]
           [(2)
            (generate-term stlc #:satisfying (typeof • (tl ((cons v_1) v_2)) ((list int) → (list int))) 5)]
           [(3)
            (generate-term stlc #:satisfying (typeof • (hd nil) ((list int) → (list int))) 5)]
           [(4)
            (generate-term stlc #:satisfying (typeof • (tl nil) ((list int) → (list int))) 5)])
    [`(typeof • ,M ,τ)
     M]
    [#f #f]))

(define (typed-generator)
  (let ([g (redex-generator stlc 
                            (typeof • M τ)
                            5)])
    (λ () 
      (match (g)
        [`(typeof • ,M ,τ)
         M]
        [#f #f]))))

(define (check term)
  (or (not term)
      (v? term)
      (let ([red-res (apply-reduction-relation red term)]
            [t-type (type-check term)])
        (and
         (= (length red-res) 1)
	 (or 
          (equal? (car red-res) "error")
          (equal? t-type (type-check (car red-res))))))))

(define (generate-enum-term)
  (generate-term stlc M #:i-th (pick-an-index)))
