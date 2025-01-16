#lang racket/base
(require "../common/struct-star.rkt"
         "../common/set.rkt"
         "../syntax/syntax.rkt"
         "../syntax/property.rkt"
         "../syntax/scope.rkt"
         "../syntax/taint.rkt"
         "../syntax/match.rkt"
         "../namespace/namespace.rkt"
         "../common/module-path.rkt"
         "../syntax/binding.rkt"
         "env.rkt"
         "free-id-set.rkt"
         "../syntax/track.rkt"
         "../syntax/error.rkt"
         "syntax-id-error.rkt"
         "dup-check.rkt"
         "../namespace/core.rkt"
         "context.rkt"
         "allowed-context.rkt"
         "main.rkt"
         "body.rkt"
         "set-bang-trans.rkt"
         "rename-trans.rkt"
         "reference-record.rkt"
         "prepare.rkt"
         "log.rkt"
         "parsed.rkt"
         "../compile/correlate.rkt")

;; ----------------------------------------

;; Common expansion for `lambda` and `case-lambda`
(define (lambda-clause-expander s formals bodys ctx)
  (define sc (and (not (expand-context-parsing-expanded? ctx))
                  (new-scope 'local)))
  (define phase (expand-context-phase ctx))
  ;; Parse and check formal arguments:
  (define ids (parse-and-flatten-formals formals sc s))
  (check-no-duplicate-ids ids phase s #:what "argument name")
  ;; Bind each argument and generate a corresponding key for the
  ;; expand-time environment:
  (define counter (root-expand-context-counter ctx))
  (define local-sym (and (expand-context-normalize-locals? ctx) 'arg))
  (define keys (for/list ([id (in-list ids)])
                 (if sc
                     (add-local-binding! id phase counter #:in s #:local-sym local-sym)
                     (existing-binding-key id (expand-context-phase ctx)))))
  (define body-env (for/fold ([env (expand-context-env ctx)]) ([key (in-list keys)]
                                                               [id (in-list ids)])
                     (env-extend env key (local-variable id))))
  (define sc-formals (if sc (add-scope formals sc) formals))
  (define sc-bodys (if sc
                       (for/list ([body (in-list bodys)]) (add-scope body sc))
                       bodys))
  (log-expand ctx 'lambda-renames sc-formals sc-bodys)
  ;; Expand the function body:
  (define body-ctx (struct*-copy expand-context ctx
                                 [env body-env]
                                 [scopes (if sc
                                             (cons sc (expand-context-scopes ctx))
                                             (expand-context-scopes ctx))]
                                 [binding-layer (if sc
                                                    (increment-binding-layer ids ctx sc)
                                                    (expand-context-binding-layer ctx))]
                                 [frame-id #:parent root-expand-context #f]))
  (define exp-body (if sc
                       (expand-body sc-bodys body-ctx #:source (keep-as-needed ctx s #:keep-for-error? #t))
                       (for/list ([sc-body (in-list sc-bodys)])
                         (expand sc-body body-ctx))))
  ;; Return formals (with new scope) and expanded body:
  (values (if (expand-context-to-parsed? ctx) 
              (unflatten-like-formals keys formals)
              sc-formals)
          exp-body))

(add-core-form!
 'lambda
  (lambda (s ctx)
    (log-expand ctx 'prim-lambda s)
    (define-match m s '(lambda formals body ...+))
    (define rebuild-s (keep-as-needed ctx s #:keep-for-parsed? #t))
    (define-values (formals body)
      (lambda-clause-expander s (m 'formals) (m 'body) ctx))
    (if (expand-context-to-parsed? ctx)
        (parsed-lambda rebuild-s formals body)
        (rebuild
         rebuild-s
         `(,(m 'lambda) ,formals ,@body)))))

(add-core-form!
 'λ
 ;; A macro:
 (lambda (s)
   (define-match m s '(lam-id formals _ ...+))
   (define ids (parse-and-flatten-formals (m 'formals) #f s))
   (define ctx (get-current-expand-context #:fail-ok? #t))
   (define phase (if ctx
                     (expand-context-phase ctx)
                     0))
   (check-no-duplicate-ids ids phase s #:what "argument name")
   (datum->syntax
    s
    (cons (datum->syntax (syntax-shift-phase-level core-stx phase)
                         'lambda
                         (m 'lam-id)
                         (m 'lam-id))
          (cdr (syntax-e s)))
    s
    s)))

(add-core-form!
 'case-lambda
 (lambda (s ctx)
   (log-expand ctx 'prim-case-lambda s)
   (define-match m s '(case-lambda [formals body ...+] ...))
   (define-match cm s '(case-lambda clause ...))
   (define rebuild-s (keep-as-needed ctx s #:keep-for-parsed? #t))
   (define clauses
     (for/list ([formals (in-list (m 'formals))]
                [body (in-list (m 'body))]
                [clause (in-list (cm 'clause))])
       (log-expand ctx 'next)
       (define rebuild-clause (keep-as-needed ctx clause))
       (define-values (exp-formals exp-body)
         (lambda-clause-expander s formals body ctx))
       (if (expand-context-to-parsed? ctx)
           (list exp-formals exp-body)
           (rebuild rebuild-clause `[,exp-formals ,@exp-body]))))
   (if (expand-context-to-parsed? ctx)
       (parsed-case-lambda rebuild-s clauses)
       (rebuild
        rebuild-s
        `(,(m 'case-lambda) ,@clauses)))))

(define (parse-and-flatten-formals all-formals sc s)
  (let loop ([formals all-formals])
    (cond
     [(identifier? formals) (list (if sc
                                      (add-scope formals sc)
                                      formals))]
     [(syntax? formals)
      (define p (syntax-e formals))
      (cond
       [(pair? p) (loop p)]
       [(null? p) null]
       [else (raise-syntax-error #f "not an identifier" s p)])]
     [(pair? formals)
      (unless (identifier? (car formals))
        (raise-syntax-error #f "not an identifier" s (car formals)))
      (cons (if sc
                (add-scope (car formals) sc)
                (car formals))
            (loop (cdr formals)))]
     [(null? formals)
      null]
     [else
      (raise-syntax-error "bad argument sequence" s all-formals)])))

(define (unflatten-like-formals keys formals)
  (let loop ([keys keys] [formals formals])
    (cond
     [(null? formals) null]
     [(pair? formals) (cons (car keys) (loop (cdr keys) (cdr formals)))]
     [(syntax? formals) (loop keys (syntax-e formals))]
     [else (car keys)])))

;; ----------------------------------------

;; Common expansion for `let[rec]-[syntaxes+]values`
(define (make-let-values-form #:log-tag log-tag
                              #:syntaxes? [syntaxes? #f]
                              #:rec? [rec? #f]
                              #:split-by-reference? [split-by-reference? #f])
  (lambda (s ctx)
    (log-expand ctx log-tag s)
    (define-match stx-m s #:when syntaxes?
      '(letrec-syntaxes+values
        ([(id:trans ...) trans-rhs] ...)
           ([(id:val ...) val-rhs] ...)
        body ...+))
    (define-match val-m s #:unless syntaxes?
      '(let-values ([(id:val ...) val-rhs] ...)
         body ...+))
    (define sc (and (not (expand-context-parsing-expanded? ctx))
                    (new-scope 'local)))
    (when (and syntaxes? (not sc))
      (raise-syntax-error #f
                          "encountered `letrec-syntaxes` in form that should be fully expanded"
                          s))
    (define body-sc (and sc rec? (new-scope 'letrec-body)))
    (define phase (expand-context-phase ctx))
    (define frame-id (and syntaxes?
                          (make-reference-record))) ; accumulates info on referenced variables
    ;; Add the new scope to each binding identifier:
    (define trans-idss (for/list ([ids (in-list (if syntaxes? (stx-m 'id:trans) null))])
                         (for/list ([id (in-list ids)])
                           (add-scope id sc))))
    (define trans-rhss (if syntaxes? ; implies rec?
                           (for/list ([rhs (in-list (stx-m 'trans-rhs))])
                             (add-scope rhs sc))
                           '()))
    (define val-idss (let ([val-idss (if syntaxes? (stx-m 'id:val) (val-m 'id:val))])
                       (if sc
                           (for/list ([ids (in-list val-idss)])
                             (for/list ([id (in-list ids)])
                               (add-scope id sc)))
                           val-idss)))
    (define val-rhss (let ([val-rhss (if syntaxes? (stx-m 'val-rhs) (val-m 'val-rhs))])
                       (if (and rec? sc)
                           (for/list ([rhs (in-list val-rhss)])
                             (add-scope rhs sc))
                           val-rhss)))
    (define val-clauses ; for syntax tracking
      (cond
        [syntaxes?
         (define-match m s '(_ _ (clause ...) . _))
         (m 'clause)]
        [else
         (define-match m s '(_ (clause ...) . _))
         (m 'clause)]))
    (check-no-duplicate-ids (list trans-idss val-idss) phase s)
    ;; Bind each left-hand identifier and generate a corresponding key
    ;; fo the expand-time environment:
    (define counter (root-expand-context-counter ctx))
    (define local-sym (and (expand-context-normalize-locals? ctx) 'loc))
    (define trans-keyss (for/list ([ids (in-list trans-idss)])
                          (for/list ([id (in-list ids)])
                            (add-local-binding! id phase counter
                                                #:frame-id frame-id #:in s
                                                #:local-sym local-sym))))
    (define val-keyss (for/list ([ids (in-list val-idss)])
                        (for/list ([id (in-list ids)])
                          (if sc
                              (add-local-binding! id phase counter
                                                  #:frame-id frame-id #:in s
                                                  #:local-sym local-sym)
                              (existing-binding-key id  (expand-context-phase ctx))))))
    ;; Add new scope to body:
    (define bodys (let ([bodys (if syntaxes? (stx-m 'body) (val-m 'body))])
                    (if sc
                        (for/list ([body (in-list bodys)])
                          (define new-body (add-scope body sc))
                          (if rec?
                              (add-scope new-body body-sc)
                              new-body))
                        bodys)))
    (log-expand ctx 'letX-renames trans-idss trans-rhss val-idss val-rhss bodys)
    ;; Evaluate compile-time expressions (if any):
    (when syntaxes?
      (log-expand ctx 'prepare-env)
      (prepare-next-phase-namespace ctx))
    (define trans-valss (for/list ([rhs (in-list trans-rhss)]
                                   [ids (in-list trans-idss)])
                          (log-expand* ctx ['next] ['enter-bind])
                          (define trans-val (eval-for-syntaxes-binding 'letrec-syntaxes+values
                                                                       rhs ids ctx))
                          (log-expand ctx 'exit-bind)
                          trans-val))
    ;; Fill expansion-time environment:
    (define rec-val-env
      (for/fold ([env (expand-context-env ctx)]) ([keys (in-list val-keyss)]
                                                  [ids (in-list val-idss)]
                                                  #:when #t
                                                  [key (in-list keys)]
                                                  [id (in-list ids)])
        (env-extend env key (local-variable id))))
    (define rec-env (for/fold ([env rec-val-env]) ([keys (in-list trans-keyss)]
                                                   [vals (in-list trans-valss)]
                                                   [ids (in-list trans-idss)])
                      (for/fold ([env env]) ([key (in-list keys)]
                                             [val (in-list vals)]
                                             [id (in-list ids)])
                        (maybe-install-free=id-in-context! val id phase ctx)
                        (env-extend env key val))))
    (when syntaxes?
      (log-expand ctx 'next-group))
    ;; Expand right-hand sides and body
    (define expr-ctx (as-expression-context ctx))
    (define orig-rrs (expand-context-reference-records expr-ctx))
    (define rec-ctx (struct*-copy expand-context expr-ctx
                                  [env rec-env]
                                  [scopes (if sc
                                              (let ([scopes (cons sc (expand-context-scopes ctx))])
                                                (if rec?
                                                    (cons body-sc scopes)
                                                    scopes))
                                              (expand-context-scopes ctx))]
                                  [reference-records (if split-by-reference?
                                                         (cons frame-id orig-rrs)
                                                         orig-rrs)]
                                  [binding-layer (if sc
                                                     (increment-binding-layer
                                                      (cons trans-idss val-idss)
                                                      ctx
                                                      sc)
                                                     (expand-context-binding-layer ctx))]))
    (define letrec-values-id
      (and (not (expand-context-to-parsed? ctx))
           (if syntaxes?
               (core-id 'letrec-values phase)
               (val-m 'let-values))))
    
    (define rebuild-s (keep-as-needed ctx s #:keep-for-error? #t))
    (define val-name-idss (if (expand-context-to-parsed? ctx)
                              (for/list ([val-ids (in-list val-idss)])
                                (for/list ([val-id (in-list val-ids)])
                                  (datum->syntax #f (syntax-e val-id) val-id val-id)))
                              val-idss))

    (define (get-body rec-ctx)
      (cond
        [(expand-context-parsing-expanded? ctx)
         (for/list ([body (in-list bodys)])
           (expand body rec-ctx))]
        [else
         (define body-ctx (struct*-copy expand-context rec-ctx
                                        [reference-records orig-rrs]))
         (expand-body bodys (as-tail-context body-ctx #:wrt ctx) #:source rebuild-s)]))
    (define result-s
      (cond
        [(not split-by-reference?)
         (define clauses
           (for/list ([ids (in-list val-name-idss)]
                      [keys (in-list val-keyss)]
                      [rhs (in-list val-rhss)]
                      [clause (in-list val-clauses)])
             (log-expand ctx 'next)
             (define exp-rhs (expand rhs (if rec?                               
                                             (as-named-context rec-ctx ids)
                                             (as-named-context expr-ctx ids))))
             (if (expand-context-to-parsed? ctx)
                 (list keys exp-rhs)
                 (datum->syntax #f `[,ids ,exp-rhs] clause clause))))
         (define exp-body (get-body rec-ctx))
         (when frame-id
           (reference-record-clear! frame-id))
         (if (expand-context-to-parsed? ctx)
             (if rec?
                 (parsed-letrec-values rebuild-s val-name-idss clauses exp-body)
                 (parsed-let-values rebuild-s val-name-idss clauses exp-body))
             (rebuild
              rebuild-s
              `(,letrec-values-id ,clauses ,@exp-body)))]
        [else
         (expand-and-split-bindings-by-reference
          val-idss val-keyss val-rhss val-clauses
          #:split? #t
          #:frame-id frame-id #:ctx rec-ctx
          #:source rebuild-s #:had-stxes? syntaxes?
          #:get-body get-body #:track? #t)]))
    
    (if (expand-context-to-parsed? ctx)
        result-s
        (attach-disappeared-transformer-bindings result-s trans-idss))))

(add-core-form!
 'let-values
 (make-let-values-form #:log-tag 'prim-let-values))

(add-core-form!
 'letrec-values
 (make-let-values-form #:rec? #t #:log-tag 'prim-letrec-values))

(add-core-form!
 'letrec-syntaxes+values
 (make-let-values-form #:syntaxes? #t #:rec? #t #:split-by-reference? #t
                       #:log-tag 'prim-letrec-syntaxes+values))

;; ----------------------------------------

(add-core-form!
 '#%stratified-body
 (lambda (s ctx)
   (log-expand ctx 'prim-#%stratified s)
   (define-match m s '(#%stratified-body body ...+))
   (define rebuild-s (keep-as-needed ctx s #:keep-for-error? #t))
   (define exp-body (expand-body (m 'body) ctx #:stratified? #t #:source rebuild-s))
   (if (expand-context-to-parsed? ctx)
       (parsed-begin rebuild-s exp-body)
       (rebuild
        rebuild-s
        (if (null? (cdr exp-body))
            (car exp-body)
            `(,(core-id 'begin (expand-context-phase ctx))
              ,@exp-body))))))

;; ----------------------------------------

(add-core-form!
 '#%datum
 (lambda (s ctx)
   (log-expand ctx 'prim-#%datum s)
   (define-match m s '(#%datum . datum))
   (define datum (m 'datum))
   (when (and (syntax? datum)
              (keyword? (syntax-e datum)))
     (raise-syntax-error '#%datum "keyword misused as an expression" #f datum))
   (define phase (expand-context-phase ctx))
   (if (and (expand-context-to-parsed? ctx)
            (free-id-set-empty? (expand-context-stops ctx)))
       (parsed-quote (keep-properties-only~ s) (syntax->datum datum))
       (syntax-track-origin (rebuild s
                                     (list (core-id 'quote phase)
                                           datum)
                                     #:track? #f)
                            s
                            (m '#%datum)))))

;; '#%kernel `#%app` treats an empty combination as a literal null
(add-core-form!
 '#%app
 (lambda (s ctx)
   (log-expand ctx 'prim-#%app s)
   (define-match m s '(#%app e ...))
   (define es (m 'e))
   (cond
    [(null? es)
     (define phase (expand-context-phase ctx))
     (if (expand-context-to-parsed? ctx)
         (parsed-quote (keep-properties-only~ s) null)
         (rebuild
          s
          (list (core-id 'quote phase)
                null)))]
    [else
     (define keep-for-parsed? keep-source-locations?)
     (define rebuild-s (keep-as-needed ctx s #:keep-for-parsed? keep-for-parsed?))
     (define prefixless (cdr (syntax-e s)))
     (define rebuild-prefixless (and (syntax? prefixless)
                                     (keep-as-needed ctx prefixless #:keep-for-parsed? keep-for-parsed?)))
     (define expr-ctx (as-expression-context ctx))
     (log-expand expr-ctx 'next)
     (define rest-es (cdr es))
     (define exp-rator (expand (car es) expr-ctx))
     (define exp-es (for/list ([e (in-list rest-es)])
                      (log-expand expr-ctx 'next)
                      (expand e expr-ctx)))
     (cond
       [(expand-context-to-parsed? ctx)
        (parsed-app (or rebuild-prefixless rebuild-s) exp-rator exp-es)]
       [else
        (define es (let ([exp-es (cons exp-rator exp-es)])
                     (if rebuild-prefixless
                         (rebuild rebuild-prefixless exp-es)
                         exp-es)))
        (rebuild rebuild-s (cons (m '#%app) es))])])))


(add-core-form!
 'quote
 (lambda (s ctx)
   (log-expand ctx 'prim-quote #f)
   (define-match m s '(quote datum))
   (if (expand-context-to-parsed? ctx)
       (parsed-quote (keep-properties-only~ s) (syntax->datum (m 'datum)))
       s)))

(add-core-form!
 'quote-syntax
 (lambda (s ctx)
   (log-expand ctx 'prim-quote-syntax s)
   (define-match m-local s #:try '(quote-syntax datum #:local))
   (define-match m s #:unless (m-local) '(quote-syntax datum))
   (cond
    [(m-local)
     ;; #:local means don't prune, and it counts as a reference to
     ;; all variables for letrec splitting
     (reference-records-all-used! (expand-context-reference-records ctx))
     (define-match m-kw s '(_ _ kw))
     (if (expand-context-to-parsed? ctx)
         (parsed-quote-syntax (keep-properties-only~ s) (m-local 'datum))
         (rebuild
          s
          `(,(m-local 'quote-syntax) ,(m-local 'datum) ,(m-kw 'kw))))]
    [else
     ;; otherwise, prune scopes up to transformer boundary:
     (define use-site-scopes (root-expand-context-use-site-scopes ctx))
     (define datum-s (remove-scopes (remove-scopes (m 'datum) (expand-context-scopes ctx))
                                    (if use-site-scopes (unbox use-site-scopes) '())))
     (if (and (expand-context-to-parsed? ctx)
              (free-id-set-empty? (expand-context-stops ctx)))
         (parsed-quote-syntax (keep-properties-only~ s) datum-s)
         (rebuild
          s
          `(,(m 'quote-syntax)
            ,datum-s)))])))

(add-core-form!
 'if
 (lambda (s ctx)
   (log-expand ctx 'prim-if s)
   (define-match bad-m s #:try '(_ _ _))
   (when (bad-m) (raise-syntax-error #f "missing an \"else\" expression" s))
   (define-match m s '(if tst thn els))
   (define expr-ctx (as-expression-context ctx))
   (define tail-ctx (as-tail-context expr-ctx #:wrt ctx))
   (define rebuild-s (keep-as-needed ctx s))
   (define exp-tst (expand (m 'tst) expr-ctx))
   (log-expand ctx 'next)
   (define exp-thn (expand (m 'thn) tail-ctx))
   (log-expand ctx 'next)
   (define exp-els (expand (m 'els) tail-ctx))
   (if (expand-context-to-parsed? ctx)
       (parsed-if rebuild-s exp-tst exp-thn exp-els)
       (rebuild
        rebuild-s
        (list (m 'if) exp-tst exp-thn exp-els)))))

(add-core-form!
 'with-continuation-mark
 (lambda (s ctx)
   (log-expand ctx 'prim-with-continuation-mark s)
   (define-match m s '(with-continuation-mark key val body))
   (define expr-ctx (as-expression-context ctx))
   (define rebuild-s (keep-as-needed ctx s))
   (define exp-key (expand (m 'key) expr-ctx))
   (log-expand ctx 'next)
   (define exp-val (expand (m 'val) expr-ctx))
   (log-expand ctx 'next)
   (define exp-body (expand (m 'body) (as-tail-context expr-ctx #:wrt ctx)))
   (if (expand-context-to-parsed? ctx)
       (parsed-with-continuation-mark rebuild-s exp-key exp-val exp-body)
       (rebuild
        rebuild-s
        (list (m 'with-continuation-mark) exp-key exp-val exp-body)))))

(define (make-begin log-tag parsed-begin
                    #:last-is-tail? last-is-tail?)
 (lambda (s ctx)
   (log-expand ctx log-tag s)
   (define-match m s '(begin e ...+))
   (define expr-ctx (if last-is-tail?
                        (as-begin-expression-context ctx)
                        (as-expression-context ctx)))
   (define rebuild-s (keep-as-needed ctx s))
   (define exp-es
     (let loop ([es (m 'e)])
       (cond
        [(null? es) null]
        [else
         (define rest-es (cdr es))
         (log-expand ctx 'next)
         (cons (expand (car es) (if (and last-is-tail? (null? rest-es))
                                    (as-tail-context expr-ctx #:wrt ctx)
                                    expr-ctx))
               (loop rest-es))])))
   (if (expand-context-to-parsed? ctx)
       (parsed-begin rebuild-s exp-es)
       (rebuild
        rebuild-s
        (cons (m 'begin) exp-es)))))

(add-core-form!
 'begin
 (let ([nonempty-begin (make-begin 'prim-begin parsed-begin #:last-is-tail? #t)])
   (lambda (s ctx)
     ;; Empty `begin` allowed in 'top-level and 'module contexts,
     ;; which might get here via `local-expand`:
     (define context (expand-context-context ctx))
     (cond
      [(or (eq? context 'top-level) (eq? context 'module))
       (define-match m s #:try '(begin))
       (if (m)
           (if (expand-context-to-parsed? ctx)
               (parsed-begin (keep-as-needed ctx s) '())
               s)
           (nonempty-begin s ctx))]
      [else
       (nonempty-begin s ctx)]))))

(add-core-form!
 'begin0
 (make-begin 'prim-begin0 parsed-begin0 #:last-is-tail? #f))

(define (register-eventual-variable!? id ctx)
  (cond
   [(and (expand-context-need-eventually-defined ctx)
         ((expand-context-phase ctx) . >= . 1))
    ;; In top level or `begin-for-syntax`, encountered a reference to a
    ;; variable that might be defined later; record it for later checking
    (hash-update! (expand-context-need-eventually-defined ctx)
                  (expand-context-phase ctx)
                  (lambda (l) (cons id l))
                  null)
    #t]
   [else #f]))

;; returns whether the binding is to a primitive
(define (check-top-binding-is-variable ctx b id s)
  (define-values (t primitive? insp-of-t protected?)
    (lookup b ctx id
            #:in s
            #:out-of-context-as-variable? (expand-context-in-local-expand? ctx)))
  (unless (or (variable? t)
              (rename-transformer? t))
    (raise-syntax-error #f "identifier does not refer to a variable" id s))
  (values t primitive?))

(add-core-form!
 '#%top
 (lambda (s ctx [implicit-omitted? #f])
   (log-expand ctx 'prim-#%top s)
   (define id (cond
               [implicit-omitted?
                ;; As a special favor to `local-expand`, the expander
                ;; has avoided making `#%top` explicit
                s]
               [else
                (define-match m s '(#%top . id))
                (m 'id)]))
   (define b (resolve+shift id (expand-context-phase ctx)
                            #:ambiguous-value 'ambiguous))
   (cond
    [(eq? b 'ambiguous)
     (raise-ambiguous-error id ctx)]
    [(and b
          (module-binding? b)
          (eq? (module-binding-module b) (root-expand-context-self-mpi ctx)))
     ;; Within a module, check that binding is a variable, not syntax:
     (unless (expand-context-allow-unbound? ctx)
       (check-top-binding-is-variable ctx b id s))
     ;; Allow `#%top` in a module or top-level where it refers to the same
     ;; thing that the identifier by itself would refer to; in that case
     ;; `#%top` can be stripped within a module
     (if (expand-context-to-parsed? ctx)
         (parsed-id id b #f)
         (cond
          [(top-level-module-path-index? (module-binding-module b)) s]
          [else id]))]
    [(local-binding? b)
     ;; In all contexts, including the top level, count as unbound
     (raise-unbound-syntax-error #f "unbound identifier" id #f null
                                 (syntax-debug-info-string id ctx))]
    [(register-eventual-variable!? id ctx)
     ;; Must be in a module, and we'll check the binding later, so strip `#%top`:
     (if (expand-context-to-parsed? ctx)
         (parsed-id id b #f)
         id)]
    [else
     (cond
      [(not (expand-context-allow-unbound? ctx))
       ;; In a module, unbound or out of context:
       (raise-unbound-syntax-error #f "unbound identifier" id #f null
                                   (syntax-debug-info-string id ctx))]
      [else
       ;; At the top level:
       (define tl-id (add-scope id (root-expand-context-top-level-bind-scope ctx)))
       (define tl-b (resolve tl-id (expand-context-phase ctx)))
       (cond
        [tl-b
         ;; Expand to a reference to a top-level variable, instead of
         ;; a required variable; don't include the temporary
         ;; binding scope in an expansion, though, in the same way that
         ;; `define-values` expands without it
         (if (expand-context-to-parsed? ctx)
             (parsed-top-id tl-id tl-b #f)
             (cond
              [implicit-omitted? id]
              [else
               (define-match m s '(#%top . id))
               (rebuild s (cons (m '#%top) id))]))]
        [else (if (expand-context-to-parsed? ctx)
                  (parsed-top-id id b #f)
                  s)])])])))

(add-core-form!
 'set!
 (lambda (s ctx)
   (log-expand ctx 'prim-set! s)
   (define-match m s '(set! id rhs))
   (define orig-id (m 'id))
   (let rename-loop ([id orig-id] [from-rename? #f])
     (define binding (resolve+shift id (expand-context-phase ctx)
                                    #:ambiguous-value 'ambiguous
                                    #:immediate? #t))
     (when (eq? binding 'ambiguous)
       (raise-ambiguous-error id ctx))
     (define-values (t primitive? insp protected?) (if binding
                                                       (lookup binding ctx s)
                                                       (values #f #f #f #f)))
     (log-expand ctx 'resolve id)
     (cond
      [(or (variable? t)
           (and (not binding)
                (or (register-eventual-variable!? id ctx)
                    (expand-context-allow-unbound? ctx))))
       (when (and (module-binding? binding)
                  (not (inside-module-context? (module-binding-module binding)
                                               (root-expand-context-self-mpi ctx))))
         (raise-syntax-error #f "cannot mutate identifier that is defined in another module" s id
                             ))
       (log-expand ctx 'next)
       (register-variable-referenced-if-local! binding ctx)
       (define rebuild-s (keep-as-needed ctx s))
       (define exp-rhs (expand (m 'rhs) (as-expression-context ctx)))
       (if (expand-context-to-parsed? ctx)
           (parsed-set! rebuild-s (parsed-id id binding #f) exp-rhs)
           (rebuild
            rebuild-s
            (list (m 'set!)
                  (substitute-variable id t #:no-stops? (free-id-set-empty-or-just-module*? (expand-context-stops ctx)))
                  exp-rhs)))]
      [(not binding)
       (raise-unbound-syntax-error #f "unbound identifier" s id null
                                   (syntax-debug-info-string id ctx))]
      [(set!-transformer? t)
       (cond
        [(not-in-this-expand-context? t ctx)
         (expand (avoid-current-expand-context (substitute-set!-rename s (m 'set!) (m 'rhs) id from-rename? ctx) t ctx)
                 ctx)]
        [else
         (define-values (exp-s re-ctx)
           (apply-transformer t insp s orig-id ctx binding #:origin-id orig-id))
         (cond
          [(expand-context-just-once? ctx) exp-s]
          [else (expand exp-s re-ctx)])])]
      [(rename-transformer? t)
       (cond
        [(not-in-this-expand-context? t ctx)
         (expand (avoid-current-expand-context (substitute-set!-rename s (m 'set!) (m 'rhs) id from-rename? ctx) t ctx)
                 ctx)]
        [else (rename-loop (apply-rename-transformer t id ctx) #t)])]
      [else
       (raise-syntax-error #f "cannot mutate syntax identifier" s id)]))))

(define (substitute-set!-rename s set!-id id rhs-s from-rename? ctx)
  (cond
   [from-rename? (datum->syntax s (list set!-id id rhs-s) s s)]
   [else s]))

(add-core-form!
 '#%variable-reference
 (lambda (s ctx)
   (log-expand ctx 'prim-#%variable-reference s)
   (define-match id-m s #:try '(#%variable-reference id))
   (define-match top-m s #:unless (id-m) #:try '(#%variable-reference (#%top . id)))
   (define-match empty-m s #:unless (or (id-m) (top-m)) '(#%variable-reference))
   (cond
    [(or (id-m) (top-m))
     (when (top-m)
       (define phase (expand-context-phase ctx))
       (unless (and (identifier? (top-m '#%top))
                    (free-identifier=? (top-m '#%top) (core-id '#%top phase) phase phase))
         (raise-syntax-error #f "bad syntax" s)))
     (define var-id (if (id-m) (id-m 'id) (top-m 'id)))
     (let rename-loop ([var-id var-id] [from-rename? #f])
       (define binding (resolve+shift var-id (expand-context-phase ctx)
                                      #:ambiguous-value 'ambiguous
                                      #:immediate? (not (expand-context-to-parsed? ctx))))
       (when (eq? binding 'ambiguous)
         (raise-ambiguous-error var-id ctx))
       (unless (and (or binding
                        (expand-context-allow-unbound? ctx))
                    (not (and (top-m) (local-binding? binding))))
         (raise-unbound-syntax-error #f "unbound identifier" s var-id null
                                     (syntax-debug-info-string var-id ctx)))
       (define-values (t primitive?)
         (cond
           [(or (not binding)
                (and (expand-context-allow-unbound? ctx)
                     (top-m)))
            (values #f #f)]
           [else
            (check-top-binding-is-variable ctx binding var-id s)]))
       (define (substitute-vr-rename)
         (cond
           [(or from-rename?
                (local-variable? t))
            (define vr-id (if (id-m)
                              (id-m '#%variable-reference)
                              (top-m '#%variable-reference)))
            (define s-var-id (substitute-variable var-id t #:no-stops? (free-id-set-empty-or-just-module*?
                                                                        (expand-context-stops ctx))))
            (datum->syntax s (list vr-id s-var-id) s s)]
           [else s]))
       (cond
         [(expand-context-to-parsed? ctx)
          (parsed-#%variable-reference (keep-properties-only~ s)
                                       (cond
                                         [(top-m) (parsed-top-id var-id binding #f)]
                                         [primitive? (parsed-primitive-id var-id binding #f)]
                                         [else (parsed-id var-id binding #f)]))]
         [(rename-transformer? t)
          (cond
            [(not-in-this-expand-context? t ctx)
             (expand (avoid-current-expand-context (substitute-vr-rename) t ctx)
                     ctx)]
            [else (rename-loop (apply-rename-transformer t var-id ctx) #t)])]
         [else (substitute-vr-rename)]))]
    [else
     (if (expand-context-to-parsed? ctx)
         (parsed-#%variable-reference (keep-properties-only~ s) #f)
         s)])))

(add-core-form!
 '#%expression
 (lambda (s ctx)
   (log-expand ctx 'prim-#%expression s)
   (define-match m s '(#%expression e))
   (define rebuild-s (keep-as-needed ctx s #:for-track? #t))
   (define exp-e (expand (m 'e) (as-tail-context (as-expression-context ctx)
                                                 #:wrt ctx)))
   (if (expand-context-to-parsed? ctx)
       exp-e
       (cond
         [(or (and (expand-context-in-local-expand? ctx)
                   (expand-context-keep-#%expression? ctx))
              (eq? 'top-level (expand-context-context ctx)))
          (rebuild
           rebuild-s
           `(,(m '#%expression) ,exp-e))]
         [else
          (define result-s (syntax-track-origin exp-e rebuild-s))
          (log-expand ctx 'tag result-s)
          result-s]))))

;; ----------------------------------------

;; Historically in '#%kernel, should be moved out
(add-core-form!
 'unquote
 (lambda (s ctx)
   (raise-syntax-error #f "not in quasiquote" s)))
(add-core-form!
 'unquote-splicing
 (lambda (s ctx)
   (raise-syntax-error #f "not in quasiquote" s)))
