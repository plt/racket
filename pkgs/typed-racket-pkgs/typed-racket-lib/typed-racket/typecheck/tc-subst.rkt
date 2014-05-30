#lang racket/base

;; Functions in this file implement the substitution function in
;; figure 8, pg 8 of "Logical Types for Untyped Languages"

(require "../utils/utils.rkt"
         racket/match racket/list
         (contract-req)
         (except-in (types abbrev utils filter-ops) -> ->* one-of/c)
         (rep type-rep object-rep filter-rep rep-utils))

(provide add-scope)

(provide/cond-contract
  [values->tc-results (->* (SomeValues/c (listof Object?)) ((listof Type/c)) full-tc-results/c)]
  [replace-names (-> (listof (list/c identifier? Object?)) tc-results/c tc-results/c)])

(define (values->tc-results v os [ts (map (λ (o) Univ) os)])
  (match v
    [(AnyValues: f)
     (tc-any-results (open-Filter f os))]
    [(Values: results)
     (define-values (t-r f-r o-r)
       (for/lists (t-r f-r o-r)
         ([r (in-list results)])
         (open-Result r os ts)))
     (ret t-r f-r o-r)]
    [(ValuesDots: results dty dbound)
     (define-values (t-r f-r o-r)
       (for/lists (t-r f-r o-r)
         ([r (in-list results)])
         (open-Result r os ts)))
     (ret t-r f-r o-r (open-Type dty os) dbound)]))


(define/cond-contract (open-Type t objs)
  (-> (Type/c (listof Object?) (listof Type/c) Filter/c))
  (for/fold ([t t])
            ([(o arg) (in-indexed (in-list objs))])
    (define key (list 0 arg))
    (subst-type t key o #t)))


(define/cond-contract (open-Filter f objs)
  (-> (Filter/c (listof Object?) (listof Type/c) Filter/c))
  (for/fold ([f f])
            ([(o arg) (in-indexed (in-list objs))])
    (define key (list 0 arg))
    (subst-filter f key o #t)))


;; Substitutes the given objects into the type, filters, and object
;; of a Result for function application. This matches up to the substitutions
;; in the T-App rule from the ICFP paper.
(define/cond-contract (open-Result r objs [ts #f])
  (->* (Result? (listof Object?)) ((listof (or/c #f Type/c))) (values Type/c FilterSet? Object?))
  (match-define (Result: t fs old-obj) r)
  (for/fold ([t t] [fs fs] [old-obj old-obj])
            ([(o arg) (in-indexed (in-list objs))]
             [arg-ty (if ts (in-list ts) (in-cycle (in-value #f)))])
    (define key (list 0 arg))
    (values (subst-type t key o #t)
            (subst-filter-set fs key o #t arg-ty)
            (subst-object old-obj key o #t))))

;; replace-names: (listof (list/c identifier? Object?) tc-results? -> tc-results?
;; For each name replaces all uses of it in res with the corresponding object.
;; This is used so that names do not escape the scope of their definitions
(define (replace-names names+objects res)
  (for/fold ([res res]) ([name/object (in-list names+objects)])
    (subst-tc-results res (first name/object) (second name/object) #t)))

;; Substitution of objects into a tc-results
(define/cond-contract (subst-tc-results res k o polarity)
  (-> full-tc-results/c name-ref/c Object? boolean? full-tc-results/c)
  (define (st t) (subst-type t k o polarity))
  (define (sf f) (subst-filter f k o polarity))
  (define (sfs fs) (subst-filter-set fs k o polarity))
  (define (so ob) (subst-object ob k o polarity))
  (match res
    [(tc-any-results: f) (tc-any-results (sf f))]
    [(tc-results: ts fs os)
     (ret (map st ts) (map sfs fs) (map so os))]
    [(tc-results: ts fs os dt db)
     (ret (map st ts) (map sfs fs) (map so os) dt db)]))


;; Substitution of objects into a filter set
;; This is essentially ψ+|ψ- [o/x] from the paper
(define/cond-contract (subst-filter-set fs k o polarity [t #f])
  (->* ((or/c FilterSet? NoFilter?) name-ref/c Object? boolean?) ((or/c #f Type/c)) FilterSet?)
  (define extra-filter (if t (-filter t k) -top))
  (define (add-extra-filter f)
    (define f* (-and extra-filter f))
    (match f*
      [(Bot:) f*]
      [_ f]))
  (match fs
    [(FilterSet: f+ f-)
     (-FS (subst-filter (add-extra-filter f+) k o polarity)
          (subst-filter (add-extra-filter f-) k o polarity))]
    [_ -top-filter]))

;; Substitution of objects into a type
;; This is essentially t [o/x] from the paper
(define/cond-contract (subst-type t k o polarity)
  (-> Type/c name-ref/c Object? boolean? Type/c)
  (define (st t) (subst-type t k o polarity))
  (define/cond-contract (sf fs) (FilterSet? . -> . FilterSet?) (subst-filter-set fs k o polarity))
  (type-case (#:Type st
              #:Filter sf
              #:Object (lambda (f) (subst-object f k o polarity)))
              t
              [#:arr dom rng rest drest kws
                     (let* ([st* (if (pair? k)
                                     ;; Add a scope if we are substituting an index and
                                     ;; not a free variable by name
                                     (λ (t) (subst-type t (add-scope k) o polarity))
                                     st)])
                       (make-arr (map st dom)
                                 (st* rng)
                                 (and rest (st rest))
                                 (and drest (cons (st (car drest)) (cdr drest)))
                                 (map st kws)))]))

;; add-scope : name-ref/c -> name-ref/c
;; Add a scope from an index object
(define (add-scope key)
  (list (+ (car key) 1) (cadr key)))

;; Substitution of objects into objects
;; This is o [o'/x] from the paper
(define/cond-contract (subst-object t k o polarity)
  (-> Object? name-ref/c Object? boolean? Object?)
  (match t
    [(NoObject:) t]
    [(Empty:) t]
    [(Path: p i)
     (if (name-ref=? i k)
         (match o
           [(Empty:) -empty-obj]
           ;; the result is not from an annotation, so it isn't a NoObject
           [(NoObject:) -empty-obj]
           [(Path: p* i*) (make-Path (append p p*) i*)])
         t)]))

;; Substitution of objects into a filter in a filter set
;; This is ψ+ [o/x] and ψ- [o/x]
(define/cond-contract (subst-filter f k o polarity)
  (-> Filter/c name-ref/c Object? boolean? Filter/c)
  (define (ap f) (subst-filter f k o polarity))
  (define (tf-matcher t p i k o polarity maker)
    (match o
      [(or (Empty:) (NoObject:))
       (cond [(name-ref=? i k)
              (if polarity -top -bot)]
             [(index-free-in? k t) (if polarity -top -bot)]
             [else f])]
      [(Path: p* i*)
       (cond [(name-ref=? i k)
              (maker
               (subst-type t k o polarity)
               i*
               (append p p*))]
             [(index-free-in? k t) (if polarity -top -bot)]
             [else f])]))
  (match f
    [(ImpFilter: ant consq)
     (-imp (subst-filter ant k o (not polarity)) (ap consq))]
    [(AndFilter: fs) (apply -and (map ap fs))]
    [(OrFilter: fs) (apply -or (map ap fs))]
    [(Bot:) -bot]
    [(Top:) -top]
    [(TypeFilter: t p i)
     (tf-matcher t p i k o polarity -filter)]
    [(NotTypeFilter: t p i)
     (tf-matcher t p i k o polarity -not-filter)]))

;; Determine if the object k occurs free in the given type
(define (index-free-in? k type)
  (let/ec
   return
   (define (for-object o)
     (object-case (#:Type for-type)
                  o
                  [#:Path p i
                          (if (name-ref=? i k)
                              (return #t)
                              o)]))
   (define (for-filter o)
     (filter-case (#:Type for-type
                   #:Filter for-filter)
                  o
                  [#:NotTypeFilter t p i
                                   (if (name-ref=? i k)
                                       (return #t)
                                       o)]
                  [#:TypeFilter t p i
                                (if (name-ref=? i k)
                                    (return #t)
                                    o)]))
   (define (for-type t)
     (type-case (#:Type for-type
                 #:Filter for-filter
                 #:Object for-object)
                t
                [#:arr dom rng rest drest kws
                       (let* ([st* (if (pair? k)
                                       (lambda (t) (index-free-in? (add-scope k) t))
                                       for-type)])
                         (for-each for-type dom)
                         (st* rng)
                         (and rest (for-type rest))
                         (and drest (for-type (car drest)))
                         (for-each for-type kws)
                         ;; dummy return value
                         (make-arr* null Univ))]))
   (for-type type)
    #f))
