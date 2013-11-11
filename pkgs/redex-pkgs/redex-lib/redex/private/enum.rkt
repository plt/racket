#lang racket/base
(require racket/bool
         racket/contract
         racket/function
         racket/list
         racket/math
         racket/match
         racket/set

         math/flonum

         "enumerator.rkt"
         "env.rkt"
         "error.rkt"
         "lang-struct.rkt"
         "match-a-pattern.rkt"
         "preprocess-pat.rkt"
         "preprocess-lang.rkt")

(provide 
 (contract-out
  [lang-enumerators (-> (listof nt?) lang-enum?)]
  [pat-enumerator (-> lang-enum?
                      any/c ;; pattern
                      enum?)]
  [enum-ith (-> enum? exact-nonnegative-integer? any/c)]
  [lang-enum? (-> any/c boolean?)]
  [enum? (-> any/c boolean?)]))

(struct lang-enum (enums unused-var/e))
(struct repeat (n terms) #:transparent)
(struct name-ref (name) #:transparent)
(struct misname-ref (name tag) #:transparent)
(struct nrep-ref (name subpat) #:transparent)
(struct decomp (ctx term) #:transparent)
(struct hide-hole (term) #:transparent)

;; Top level exports
(define enum-ith decode)

(define (lang-enumerators lang)
  (define l-enums (make-hash))
  (define unused-var/e
    (apply except/e
           var/e
           (used-vars lang)))
  (define (enumerate-lang! cur-lang enum-f)
    (for ([nt (in-list cur-lang)])
      (hash-set! l-enums
                 (nt-name nt)
                 (with-handlers ([exn:fail:redex? fail/e])
                   (enum-f (nt-rhs nt)
                           l-enums)))))
  (define-values (fin-lang rec-lang) (sep-lang lang))
  (enumerate-lang! fin-lang
                   (λ (rhs enums)
                      (enumerate-rhss rhs enums unused-var/e)))
  (enumerate-lang! rec-lang
                   (λ (rhs enums)
                      (thunk/e +inf.f
                               (λ ()
                                  (enumerate-rhss rhs enums unused-var/e)))))

  (lang-enum l-enums unused-var/e))

(define (pat-enumerator l-enum pat)
  (map/e
   to-term
   (λ (_)
      (redex-error 'pat-enum "Enumerator is not a  bijection"))
   (pat/e pat
          (lang-enum-enums l-enum)
          (lang-enum-unused-var/e l-enum))))

(define (enumerate-rhss rhss l-enums unused/e)
  (apply sum/e
         (for/list ([production (in-list rhss)])
           (pat/e (rhs-pattern production)
                  l-enums
                  unused/e))))

(define (pat/e pat l-enums unused/e)
  (match-define (ann-pat nv pp-pat) (preprocess pat))
  (map/e
   ann-pat
   (λ (ap)
      (values (ann-pat-ann ap)
              (ann-pat-pat ap)))
   (env/e nv l-enums unused/e)
   (pat-refs/e pp-pat l-enums unused/e)))

;; (: pat-refs/e : Pat (HashTable Symbol (Enum Pat)) (Enum Symbol) -> Enum RefPat)
(define (pat-refs/e pat nt-enums unused/e)
  (define (loop pat)
    (match-a-pattern
     pat
     [`any any/e]
     [`number num/e]
     [`string string/e]
     [`natural natural/e]
     [`integer integer/e]
     [`real real/e]
     [`boolean bool/e]
     [`variable var/e]
     [`(variable-except ,s ...)
      (apply except/e var/e s)]
     [`(variable-prefix ,s)
      (define as-str (symbol->string s))
      (map/e (compose string->symbol
                      (curry string-append as-str)
                      symbol->string)
             (compose string->symbol
                      list->string
                      (curry (flip drop) (string-length as-str))
                      string->list
                      symbol->string)
             var/e)]
     [`variable-not-otherwise-mentioned
      unused/e]
     [`hole (const/e the-hole)]
     [`(nt ,id)
      (hash-ref nt-enums id)]
     [`(name ,n ,pat)
      (const/e (name-ref n))]
     [`(mismatch-name ,n ,tag)
      (const/e (misname-ref n tag))]
     [`(in-hole ,p1 ,p2)
      (map/e decomp
             (match-lambda
              [(decomp ctx term)
               (values ctx term)])
             (loop p1)
             (loop p2))]
     [`(hide-hole ,p)
      (map/e hide-hole
             hide-hole-term
             (loop p))]
     [`(side-condition ,p ,g ,e)
      (unsupported pat)]
     [`(cross ,s)
      (unsupported pat)]
     [`(list ,sub-pats ...)
      (list/e
       (for/list ([sub-pat (in-list sub-pats)])
         (match sub-pat
           [`(repeat ,pat #f #f)
            (map/e
             (λ (ts)
                (repeat (length ts)
                        ts))
             (λ (rep)
                (repeat-terms rep))
             (many/e (loop pat)))]
           [`(repeat ,tag ,n #f)
            (const/e (nrep-ref n tag))]
           [`(repeat ,pat ,n ,m)
            (unimplemented "mismatch repeats (..._!_)")]
           [else (loop sub-pat)])))]
     [(? (compose not pair?)) 
      (const/e pat)]))
  (loop pat))

(define/match (env/e nv l-enums unused/e)
  [((env names misnames nreps) _ _)
   (define (val/e p)
     (pat-refs/e p l-enums unused/e))

   (define/match (misvals/e p-ts)
     [((cons p ts))
      (define p/e (val/e p))
      (fold-enum (λ (ts-excepts tag)
                    (define excepts
                      (map cdr ts-excepts))
                    (cons/e (const/e tag)
                            (apply except/e p/e excepts)))
                 (set->list ts))])
   
   (define/match (reprec/e nv-t)
     [((cons nv tpats))
      (define tpats/e
        (hash-traverse/e val/e tpats))
      (many/e
       (cons/e (env/e nv l-enums unused/e)
               tpats/e))])
   (define names-env
     (hash-traverse/e val/e names))

   (define misnames-env
     (hash-traverse/e misvals/e misnames))
   
   (define nreps-env
     (hash-traverse/e reprec/e nreps))
   (map/e
    t-env
    (match-lambda
     [(t-env  names misnames nreps)
      (values names misnames nreps)])
    names-env
    misnames-env
    nreps-env)])

;; to-term : (ann-pat t-env pat-with-refs) -> redex term
(define/match (to-term ap)
  [((ann-pat nv term))
   ((refs-to-fn term) nv)])

;; refs-to-fn : RefPat -> (TEnv -> Term)
(define (refs-to-fn refpat)
  (match refpat
    [(ann-pat _ _)
     (define term
       (to-term refpat))
     (λ (_) term)]
    [(decomp ctx-refs termpat-refs)
     (define ctx-fn (refs-to-fn ctx-refs))
     (define term-fn (refs-to-fn termpat-refs))
     (λ (nv)
        (define ctx (ctx-fn nv))
        (define term (term-fn term))
        (plug-hole ctx term))]
    [(hide-hole p)
     (define p-fn (refs-to-fn p))
     (λ (nv)
        (hide-hole (p-fn nv)))]
    [(name-ref n)
     (λ (nv)
        (t-env-name-ref nv n))]
    [(misname-ref n tag)
     (λ (nv)
        ((refs-to-fn (t-env-misname-ref nv n tag)) nv))]
    [(list subrefpats ...)
     (compose
      append*
      (sequence-fn
       (for/list ([subrefpat (in-list subrefpats)])
         (match subrefpat
           [(repeat _ subs)
            (sequence-fn (map refs-to-fn subs))]
           [(nrep-ref n tag)
            (λ (nv)
               (define env-ts (t-env-nrep-ref nv n))
               (for/list ([nv-t (in-list env-ts)])
                 (match nv-t
                   [(cons nv tterms)
                    ((refs-to-fn (hash-ref tterms tag)) nv)])))]
           [_ (sequence-fn (list (refs-to-fn subrefpat)))]))))]
    [else (λ (_) refpat)]))

(define (plug-hole ctx term)
  (define (plug ctx)
    (match ctx
      [(? (curry eq? the-hole)) term]
      [(list ctxs ...) (map plug ctxs)]
      [_ ctx]))
  (define (unhide term)
    (match term
      [(list ctxs ...) (map unhide ctxs)]
      [(hide-hole term) (unhide term)]
      [_ term]))
  (unhide (plug ctx)))

;; (: sequence-fn : (All (a b) (Listof (a -> b)) -> (a -> (Listof b))))
(define (sequence-fn fs)
  (λ (x)
     (for/list ([f (in-list fs)])
       (f x))))

;; Base Type enumerators
(define natural/e nats/e)

(define (between? x low high)
  (and (>= x low)
       (<= x high)))
(define (range-with-pred/e-p low high)
  (cons (range/e low high)
        (λ (n) (between? n low high))))
(define low/e-p
  (range-with-pred/e-p #x61 #x7a))
(define up/e-p
  (range-with-pred/e-p #x41 #x5a))
(define bottom/e-p
  (range-with-pred/e-p #x0 #x40))
(define mid/e-p
  (range-with-pred/e-p #x5b #x60))
(define above1/e-p
  (range-with-pred/e-p #x7b #xd7FF))
(define above2/e-p
  (range-with-pred/e-p #xe000 #x10ffff))

(define char/e
  (map/e
   integer->char
   char->integer
   (disj-sum/e #:append? #t
               low/e-p
               up/e-p
               bottom/e-p
               mid/e-p
               above1/e-p
               above2/e-p)))

(define string/e
  (map/e
   list->string
   string->list
   (many/e char/e)))

(define from-1/e
  (map/e add1
         sub1
         nats/e))

(define integer/e
  (disj-sum/e #:alternate? #t
              (cons (const/e 0) zero?)
              (cons from-1/e (λ (n) (> n 0)))
              (cons (map/e - - from-1/e)
                    (λ (n) (< n 0)))))

;; The last 3 here are -inf.0, +inf.0 and +nan.0
;; Consider moving those to the beginning
(define weird-flonums/e-p
  (cons (from-list/e '(+inf.0 -inf.0 +nan.0))
        (λ (n)
           (and (flonum? n)
                (or (infinite? n)
                    (nan? n))))))
(define normal-flonums/e-p
  (cons (take/e (map/e
                 ordinal->flonum
                 flonum->ordinal
                 integer/e)
                (+ 1 (* 2 9218868437227405311)))
        (λ (n)
           (and (flonum? n)
                (nor (infinite? n)
                     (nan? n))))))
(define float/e
  (disj-sum/e #:append? #t
              weird-flonums/e-p
              normal-flonums/e-p))

(define real/e
  (disj-sum/e #:alternate? #t
              (cons integer/e exact-integer?)
              (cons float/e flonum?)))

(define non-real/e
  (map/e make-rectangular
         (λ (z)
            (values (real-part z)
                    (imag-part z)))
         real/e
         (except/e real/e 0 0.0)))

(define num/e
  (disj-sum/e #:alternate? #t
              (cons real/e real?)
              (cons non-real/e complex?)))

(define bool/e
  (from-list/e '(#t #f)))

(define var/e
  (map/e
   (compose string->symbol list->string)
   (compose string->list symbol->string)
   (many1/e char/e)))

(define base/e
  (disj-sum/e #:alternate? #t
              (cons (const/e '()) null?)
              (cons num/e number?)
              (cons string/e string?)
              (cons bool/e boolean?)
              (cons var/e symbol?)))

(define any/e
  (fix/e +inf.f
         (λ (any/e)
            (disj-sum/e #:alternate? #t
                        (cons base/e (negate pair?))
                        (cons (cons/e any/e any/e) pair?)))))

(define (flip f)
  (λ (x y)
     (f y x)))
