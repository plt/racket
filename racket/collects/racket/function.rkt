#lang racket/base

(require (for-syntax racket/base racket/list syntax/name)
         racket/list racket/private/arity)

(provide identity
         const   const*
         thunk   thunk*
         curry   curryr
         conjoin disjoin
         negate
         get-failure-result
         (all-from-out racket/private/arity))

(define (identity x) x)

(define const (λ (c) (thunk* c)))

(define const*
  (let ([const* (thunk* (values))])
    (case-lambda
      [()    const*]
      [(c)   (thunk* c)]
      [(c d) (thunk* (values c d))]
      [c*    (thunk* (apply values c*))])))

(define-syntax (thunk stx)
  (syntax-case stx ()
    [(_ body0 body ...) (syntax/loc stx (lambda () body0 body ...))]))

(define-syntax (thunk* stx)
  (syntax-case stx ()
    [(_ body0 body ...)
     (with-syntax ([proc (syntax-property
                          (syntax/loc stx
                            ;; optimize 0- and 1-argument cases
                            (case-lambda [() body0 body ...]
                                         [(x) (th)] [xs (th)]))
                          'inferred-name (syntax-local-infer-name stx))])
       (syntax/loc stx
         (letrec ([th proc])
           (make-keyword-procedure (lambda (_1 _2 . _3) (th)) proc))))]))

(define (negate f)
  (unless (procedure? f) (raise-argument-error 'negate "procedure?" f))
  (let-values ([(arity) (procedure-arity f)] [(_ kwds) (procedure-keywords f)])
    (case (and (null? kwds) arity) ; optimize some simple cases
      [(0) (lambda () (not (f)))]
      [(1) (lambda (x) (not (f x)))]
      [(2) (lambda (x y) (not (f x y)))]
      [else (compose1 not f)]))) ; keyworded or more args => just compose

(define (get-failure-result v)
  (if (procedure? v)
      (if (procedure-arity-includes? v 0)
          (v)
          (raise-argument-error 'get-failure-result
                                "a procedure that accepts 0 non-keyword arguments"
                                v))
      v))

(define (make-curry right?)
  ; arity-mask? -> (or/c exact-nonnegative-integer? +inf.0 #f)
  ;
  ; Calculates the maximum number of arguments a function with the given arity may be applied to. If
  ; an unbounded number of arguments are permitted, returns +inf.0. If no number of arguments is valid
  ; (that is, the procedure is uninvokable), returns #f.
  (define (arity-upper-bound mask)
    (cond
      [(eqv? mask 0) #f]
      [(negative? mask) +inf.0]
      [else (sub1 (integer-length mask))]))

  ; arity-mask? exact-nonnegative-integer? -> arity-mask?
  ;
  ; Calculates the positional argument arity for a function produced by `curry` that has already been
  ; applied to num-args-so-far arguments.
  (define (partially-applied-procedure-arity-mask mask num-args-so-far)
    (if (negative? mask)
        -1
        (sub1 (arithmetic-shift 1 (- (integer-length mask) num-args-so-far)))))

  (define who (if right? 'curryr 'curry))

  (define incorporate-new-pos-args
    (if right?
        (lambda (pos-args-so-far new-pos-args) (append new-pos-args pos-args-so-far))
        (lambda (pos-args-so-far new-pos-args) (append pos-args-so-far new-pos-args))))

  ;; the actual implementation of curry[r] is here
  (define (do-curry f)
    (unless (procedure? f)
      (raise-argument-error who "procedure?" f))
    (let*-values ([(name) (object-name f)]
                  [(curried-name) (if (symbol? name)
                                      (string->symbol (string-append "curried:"
                                                                     (symbol->string name)))
                                      'curried)]
                  [(arity-mask) (procedure-arity-mask f)]
                  [(max-arity) (arity-upper-bound arity-mask)]
                  [(required-kws allowed-kws) (procedure-keywords f)])
      (cond
        ;; fast path for functions that don't accept any keywords
        [(null? allowed-kws)
         (define (reduce-arity/rename proc num-args-so-far)
           (procedure-reduce-arity-mask
            proc
            (partially-applied-procedure-arity-mask arity-mask num-args-so-far)
            curried-name))

         (define (make-curried args-so-far)
           (reduce-arity/rename
            (lambda new-args
              (let ([args (incorporate-new-pos-args args-so-far new-args)])
                (if (procedure-arity-includes? f (length args))
                    (apply f args)
                    (make-curried args))))
            (length args-so-far)))

         (reduce-arity/rename
          (lambda args
            (if (= (length args) max-arity)
                (apply f args)
                (make-curried args)))
          0)]

        ;; slow path for functions that accept keywords
        [else
         (define (incorporate-new-kws+args kws+args-so-far new-kws+args)
           (for/fold ([kws+args kws+args-so-far])
                     ([(kw arg) (in-hash new-kws+args)])
             (if (hash-has-key? kws+args kw)
                 (raise-arguments-error
                  curried-name
                  "duplicate keyword for procedure"
                  "keyword" kw
                  "first value" (hash-ref kws+args kw)
                  "second value" arg)
                 (hash-set kws+args kw arg))))

         (define (reduce-arity/rename proc num-args-so-far kw+args-so-far)
           (procedure-reduce-keyword-arity-mask
            proc
            (partially-applied-procedure-arity-mask arity-mask num-args-so-far)
            '()
            (and allowed-kws
                 (filter (lambda (kw) (not (hash-has-key? kw+args-so-far kw))) allowed-kws))
            curried-name))

         (define (make-curried pos-args-so-far kws+args-so-far)
           (reduce-arity/rename
            (make-keyword-procedure
             (lambda (new-kws new-kw-args . new-pos-args)
               (step (incorporate-new-pos-args pos-args-so-far new-pos-args)
                     (incorporate-new-kws+args
                      kws+args-so-far
                      (make-immutable-hasheq (map cons new-kws new-kw-args)))))
             (lambda new-pos-args
               (step (incorporate-new-pos-args pos-args-so-far new-pos-args) kws+args-so-far)))
            (length pos-args-so-far)
            kws+args-so-far))

         ; handles a curried application and applies f if enough arguments have been accumulated,
         ; otherwise produces a new curried function
         (define (step pos-args-so-far kw+args-so-far)
           (if (and (procedure-arity-includes? f (length pos-args-so-far) #t)
                    (for/and ([required-kw (in-list required-kws)])
                      (hash-has-key? kw+args-so-far required-kw)))
               (let* ([sorted-kw+args (sort (hash->list kw+args-so-far) keyword<? #:key car)]
                      [kws (map car sorted-kw+args)]
                      [kw-args (map cdr sorted-kw+args)])
                 (keyword-apply f kws kw-args pos-args-so-far))
               (make-curried pos-args-so-far kw+args-so-far)))

         (reduce-arity/rename
          (make-keyword-procedure
           (lambda (kws kw-args . pos-args)
             (if (and (= (length pos-args) max-arity)
                      allowed-kws
                      ; we're protected by procedure-reduce-arity, so the same number of keywords
                      ; means the call must be fully-saturated
                      (= (length kws) (length allowed-kws)))
                 (keyword-apply f kws kw-args pos-args)
                 (make-curried pos-args (make-immutable-hasheq (map cons kws kw-args)))))
           (lambda pos-args
             ; a non-keyword application can't possibly be fully-saturated, since we're on the keyword
             ; path, so just produce a curried function
             (make-curried pos-args #hasheq())))
          0
          #hasheq())])))

  ;; curry itself is curried; if we get any args, immediately invoke the curried function with them
  (procedure-rename
   (make-keyword-procedure
    (lambda (kws kw-args f . args)
      (let ([curried (do-curry f)])
        (if (null? kws)
            (if (null? args)
                curried
                (apply curried args))
            (keyword-apply curried kws kw-args args))))
    (case-lambda
      [(f) (do-curry f)]
      [(f . args) (apply (do-curry f) args)]))
   who))

(define curry  (make-curry #f))
(define curryr (make-curry #t))

;; Originally from `unstable/function`.
;; Originally written by Carl Eastlund

;; ryanc: adjusted limit of inner cases from 8 to 2
;; All uses so far seem to be predicates, so more cases seem
;; unnecessary. Also, all uses so far are first-order, so
;; outer case-lambda* might be better replaced with macro.

(define conjoin
  (case-lambda*
   [(f ... 8)
    (begin
      (for ([f* (in-list (list f ...))])
        (unless (procedure? f*)
          (raise-argument-error 'conjoin "procedure?" f*)))
      (make-intermediate-procedure
       'conjoined
       [(x (... ...) 2) (and (f x (... ...)) ...)]
       [xs (and (apply f xs) ...)]
       #:keyword
       [(keys vals . args)
        (and (keyword-apply f keys vals args) ...)]))]
   [fs
    (begin
      (for ([f* (in-list fs)])
        (unless (procedure? f*)
          (raise-argument-error 'conjoin "procedure?" f*)))
      (make-intermediate-procedure
       'conjoined
       [(x ... 2) (andmap (lambda (f) (f x ...)) fs)]
       [xs (andmap (lambda (f) (apply f xs)) fs)]
       #:keyword
       [(keys vals . args)
        (andmap (lambda (f) (keyword-apply f keys vals args)) fs)]))]))

(define disjoin
  (case-lambda*
   [(f ... 8)
    (begin
      (for ([f* (in-list (list f ...))])
        (unless (procedure? f*)
          (raise-argument-error 'conjoin "procedure?" f*)))
      (make-intermediate-procedure
       'disjoined
       [(x (... ...) 2) (or (f x (... ...)) ...)]
       [xs (or (apply f xs) ...)]
       #:keyword
       [(keys vals . args)
        (or (keyword-apply f keys vals args) ...)]))]
   [fs
    (begin
      (for ([f* (in-list fs)])
        (unless (procedure? f*)
          (raise-argument-error 'conjoin "procedure?" f*)))
      (make-intermediate-procedure
       'disjoined
       [(x ... 2) (ormap (lambda (f) (f x ...)) fs)]
       [xs (ormap (lambda (f) (apply f xs)) fs)]
       #:keyword
       [(keys vals . args)
        (ormap (lambda (f) (keyword-apply f keys vals args)) fs)]))]))

(define-syntax (make-intermediate-procedure stx)
  (syntax-case stx [quote]
    [(_ (quote name) positional-clause ... #:keyword keyword-clause)
     (syntax/loc stx
       (make-keyword-procedure
        (let* ([name (case-lambda keyword-clause)]) name)
        (let* ([name (case-lambda* positional-clause ...)]) name)))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Automatic case-lambda repetition
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-for-syntax (split-syntax-at orig stx id)
  (let loop ([found #f]
             [seen null]
             [stx stx])
    (syntax-case stx []
      [(head . tail)
       (and (identifier? #'head)
            (free-identifier=? #'head id))
       (if found
           (raise-syntax-error
            #f
            (format "duplicate occurrence of ~a" (syntax-e id))
            orig
            #'head)
           (loop (list (reverse seen) #'head #'tail)
                 (cons #'head seen)
                 #'tail))]
      [(head . tail) (loop found (cons #'head seen) #'tail)]
      [_ found])))

(define-for-syntax (expand-ellipsis-clause stx pattern expr)
  (cond
   [(split-syntax-at stx pattern #'(... ...))
    =>
    (lambda (found)
      (syntax-case found [...]
        [([pre ... repeat] (... ...) [count post ... . tail])
         (and (identifier? #'repeat)
              (exact-nonnegative-integer? (syntax-e #'count)))
         (build-list
          (add1 (syntax-e #'count))
          (lambda (i)
            (with-syntax ([(var ...)
                           (generate-temporaries
                            (build-list i (lambda (j) #'repeat)))]
                          [body expr])
              (list
               (syntax/loc pattern (pre ... var ... post ... . tail))
               (syntax/loc expr
                 (let-syntax ([the-body
                               (lambda _
                                 (with-syntax ([(repeat (... ...)) #'(var ...)])
                                   #'body))])
                   the-body))))))]
        [(pre mid post)
         (raise-syntax-error
          #f
          "expected ellipsis between identifier and natural number literal"
          stx
          #'mid)]))]
   [else (list (list pattern expr))]))

(define-syntax (case-lambda* stx)
  (syntax-case stx []
    [(_ [pattern body] ...)
     (with-syntax ([([pattern body] ...)
                    (append-map
                     (lambda (p e) (expand-ellipsis-clause stx p e))
                     (syntax->list #'(pattern ...))
                     (syntax->list #'(body ...)))])
       (syntax/loc stx
         (case-lambda [pattern body] ...)))]))
