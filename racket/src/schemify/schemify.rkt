#lang racket/base
(require "wrap.rkt"
         "match.rkt"
         "known.rkt"
         "import.rkt"
         "export.rkt"
         "struct-convert.rkt"
         "simple.rkt"
         "source-sym.rkt"
         "find-definition.rkt"
         "mutated.rkt"
         "mutated-state.rkt"
         "left-to-right.rkt"
         "equal.rkt"
         "optimize.rkt"
         "find-known.rkt"
         "infer-known.rkt"
         "inline.rkt"
         "letrec.rkt"
         "unnest-let.rkt"
         "infer-name.rkt"
         "maybe-unsafe.rkt"
         "ptr-ref-set.rkt"
         "literal.rkt"
         "authentic.rkt"
         "single-valued.rkt"
         "id-to-var.rkt"
         "gensym.rkt"
         "aim.rkt")

(provide schemify-linklet
         schemify-body)

;; Convert a linklet to a Scheme `lambda`, dealing with several
;; issues:
;;
;;   - imports and exports are represented by `variable` objects that
;;     are passed to the function; to avoid obscuring the program to
;;     the optimizer, though, refer to the definitions of exported
;;     variables instead of going through the `variable`, whenever
;;     possible, and accept values instead of `variable`s for constant
;;     imports;
;;
;;   - wrap expressions in a sequence of definitions plus expressions
;;     so that the result body is a sequence of definitions followed
;;     by a single expression;
;;
;;   - convert function calls and `let` forms to enforce left-to-right
;;     evaluation;
;;
;;   - convert function calls to support applicable structs, using
;;     `#%app` whenever a call might go through something other than a
;;     plain function;
;;
;;   - convert all `letrec` patterns that might involve `call/cc` to
;;     ensure that locations are allocated at the right time;
;;
;;   - explicitly handle all potential too-early variable uses, so that
;;     the right name and enclosing module are reported;
;;
;;   - convert `make-struct-type` bindings to a pattern that Chez can
;;     recognize;
;;
;;   - optimize away `variable-reference-constant?` uses, which is
;;     important to make keyword-argument function calls work directly
;;     without keywords;
;;
;;  - similarly optimize away `variable-reference-from-unsafe?`;
;;
;;   - simplify `define-values` and `let-values` to `define` and
;;     `let`, when possible, and generally avoid `let-values`.

;; The given linklet can have parts wrapped as annotations. When
;; called from the Racket expander, those annotation will be
;; "correlated" objects that just support source locations.

;; Returns (values schemified-linklet import-abi export-info).
;; An import ABI is a list of list of booleans, parallel to the
;; linklet imports, where #t to means that a value is expected, and #f
;; means that a variable (which boxes a value) is expected.
;; If `serializable?-box` is not #f, it is filled with a
;; hash table of objects that need to be handled by `racket/fasl`.
(define (schemify-linklet lk serializable?-box datum-intern? target allow-set!-undefined?
                          unsafe-mode? enforce-constant? allow-inline? no-prompt?
                          prim-knowns primitives compiler-query get-import-knowns import-keys)
  (with-deterministic-gensym
    (define (im-int-id id) (unwrap (if (pair? id) (cadr id) id)))
    (define (im-ext-id id) (unwrap (if (pair? id) (car id) id)))
    (define (ex-int-id id) (unwrap (if (pair? id) (car id) id)))
    (define (ex-ext-id id) (unwrap (if (pair? id) (cadr id) id)))
    ;; Assume no wraps unless the level of an id or expression
    (match lk
      [`(linklet ,im-idss ,ex-ids . ,bodys)
       ;; For imports, map symbols to gensymed `variable` argument names,
       ;; keeping `import` records in groups:
       (define grps
         (for/list ([im-ids (in-list im-idss)]
                    [index (in-naturals)])
           ;; An import key from `import-keys` lets us get cross-module
           ;; information on demand
           (import-group index (and import-keys (vector-ref import-keys index))
                         get-import-knowns #f #f
                         '())))
       ;; Record import information in both the `imports` table and within
       ;; the import-group record
       (define imports
         (let ([imports (make-hasheq)])
           (for ([im-ids (in-list im-idss)]
                 [grp (in-list grps)])
             (set-import-group-imports!
              grp
              (for/list ([im-id (in-list im-ids)])
                (define id (im-int-id im-id))
                (define ext-id (im-ext-id im-id))
                (define int-id (deterministic-gensym id))
                (define im (import grp int-id id ext-id))
                (hash-set! imports id im)
                (hash-set! imports int-id im) ; useful for optimizer to look up known info late
                im)))
           imports))
       ;; Inlining can add new import groups or add imports to an existing group
       (define new-grps '())
       (define add-import!
         (make-add-import! imports
                           grps
                           get-import-knowns
                           (lambda (new-grp) (set! new-grps (cons new-grp new-grps)))))
       ;; For exports, too, map symbols to gensymed `variable` argument names
       (define exports
         (for/fold ([exports (hasheq)]) ([ex-id (in-list ex-ids)])
           (define id (ex-int-id ex-id))
           (hash-set exports id (export (deterministic-gensym id) (ex-ext-id ex-id)))))
       ;; Collect source names for defined identifiers, to the degree that the
       ;; original source name differs from the current name
       (define src-syms (get-definition-source-syms bodys))
       ;; Schemify the body, collecting information about defined names:
       (define-values (new-body defn-info mutated)
         (schemify-body* bodys prim-knowns primitives imports exports
                         serializable?-box datum-intern? allow-set!-undefined? add-import! target
                         unsafe-mode? enforce-constant? allow-inline? no-prompt? #t
                         compiler-query))
       (define all-grps (append grps (reverse new-grps)))
       (values
        ;; Build `lambda` with schemified body:
        `(lambda (instance-variable-reference
                  ,@(for*/list ([grp (in-list all-grps)]
                                [im (in-list (import-group-imports grp))])
                      (import-id im))
                  ,@(for/list ([ex-id (in-list ex-ids)])
                      (export-id (hash-ref exports (ex-int-id ex-id)))))
           ,@new-body)
        ;; Imports (external names), possibly extended via inlining:
        (for/list ([grp (in-list all-grps)])
          (for/list ([im (in-list (import-group-imports grp))])
            (import-ext-id im)))
        ;; Exports (external names, but paired with source name if it's different):
        (for/list ([ex-id (in-list ex-ids)])
          (define sym (ex-ext-id ex-id))
          (define int-sym (ex-int-id ex-id))
          (define src-sym (hash-ref src-syms int-sym sym)) ; external name unless 'source-name
          (if (eq? sym src-sym) sym (cons sym src-sym)))
        ;; Import keys --- revised if we added any import groups
        (if (null? new-grps)
            import-keys
            (for/vector #:length (length all-grps) ([grp (in-list all-grps)])
              (import-group-key grp)))
        ;; Import ABI: request values for constants, `variable`s otherwise
        (for/list ([grp (in-list all-grps)])
          (define im-ready? (import-group-lookup-ready? grp))
          (for/list ([im (in-list (import-group-imports grp))])
            (and im-ready?
                 (let ([k (import-group-lookup grp (import-ext-id im))])
                   (and (known-constant? k)
                        (cond
                          [(known-procedure? k)
                           ;; A call to the procedure is probably in unsafe form:
                           'proc]
                          [(known-struct-type? k)
                           ;; Struct-type operations turn into references of the struct type
                           ;; and unsafe accesses based on a known size, so make sure the size
                           ;; hasn't changed
                           (known-struct-type-field-count k)]
                          [else
                           ;; Otherwise, accept any value:
                           #t]))))))
        ;; Convert internal to external identifiers for known-value info
        (for/fold ([knowns (hasheq)]) ([ex-id (in-list ex-ids)])
          (define id (ex-int-id ex-id))
          (define v (known-inline->export-known (hash-ref defn-info id #f)
                                                prim-knowns imports exports
                                                serializable?-box))
          (cond
            [(not (set!ed-mutated-state? (hash-ref mutated id #f)))
             (define ext-id (ex-ext-id ex-id))
             (hash-set knowns ext-id (or v a-known-constant))]
            [else knowns])))])))

;; ----------------------------------------

(define (schemify-body l prim-knowns primitives imports exports
                       target unsafe-mode? no-prompt? explicit-unnamed?)
  (with-deterministic-gensym
    (define-values (new-body defn-info mutated)
      (schemify-body* l prim-knowns primitives imports exports
                      #f #f #f (lambda (im ext-id index) #f)
                      target unsafe-mode? #t #t no-prompt? explicit-unnamed?
                      (lambda (v) #f)))
    new-body))

(define (schemify-body* l prim-knowns primitives imports exports
                        serializable?-box datum-intern? allow-set!-undefined? add-import!
                        target unsafe-mode? enforce-constant? allow-inline? no-prompt? explicit-unnamed?
                        compiler-query)
  ;; For non-exported definitions, we may need to create some variables
  ;; to guard against multiple returns or early references
  (define extra-variables (make-hasheq))
  (define (add-extra-variables l)
    (append (for/list ([(int-id ex) (in-hash extra-variables)])
              `(define ,(export-id ex) (make-internal-variable ',int-id)))
            l))
  ;; Keep simple checking efficient by caching results
  (define simples (make-hasheq))
  ;; Various conversion steps need information about mutated variables,
  ;; where "mutated" here includes visible implicit mutation, such as
  ;; a variable that might be used before it is defined:
  (define mutated (mutated-in-body l exports extra-variables prim-knowns (hasheq) imports simples
                                   unsafe-mode? target enforce-constant?))
  ;; Make another pass to gather known-binding information:
  (define knowns
    (for/fold ([knowns (hasheq)]) ([form (in-list l)])
      (define-values (new-knowns info)
        (find-definitions form prim-knowns knowns imports mutated simples unsafe-mode? target
                          #:primitives primitives
                          #:optimize? #t
                          #:compiler-query compiler-query))
      new-knowns))
  ;; Mutated to communicate the final `knowns`
  (define final-knowns knowns)
  ;; While schemifying, add calls to install exported values in to the
  ;; corresponding exported `variable` records, but delay those
  ;; installs to the end, if possible
  (define schemified
    (let loop ([l l] [in-mut-l l] [accum-exprs null] [accum-ids null] [knowns knowns])
      (define mut-l (update-mutated-state! l in-mut-l mutated))
      (define (make-set-variables)
        ;; Resulting list of assinments will be reversed
        (cond
          [(or (aim? target 'cify) (aim? target 'interp))
           (for/list ([id (in-list accum-ids)]
                      #:when (or (hash-ref exports (unwrap id) #f)
                                 (hash-ref extra-variables (unwrap id) #f)))
             (make-set-variable id exports knowns mutated extra-variables))]
          [else
           ;; Group 'consistent variables in one `set-consistent-variables!/define` call
           (let loop ([accum-ids accum-ids] [consistent-ids null])
             (cond
               [(null? accum-ids)
                (make-set-consistent-variables consistent-ids exports knowns mutated extra-variables)]
               [else
                (define id (car accum-ids))
                (define u-id (unwrap id))
                (cond
                  [(or (hash-ref exports u-id #f)
                       (hash-ref extra-variables u-id #f))
                   (cond
                     [(eq? 'consistent (variable-constance u-id knowns mutated))
                      (loop (cdr accum-ids) (cons id consistent-ids))]
                     [else
                      (append (make-set-consistent-variables consistent-ids exports knowns mutated extra-variables)
                              (cons (make-set-variable id exports knowns mutated extra-variables)
                                    (loop (cdr accum-ids) '())))])]
                  [else
                   (loop (cdr accum-ids) consistent-ids)])]))]))
      (define (make-expr-defns es)
        (if (or (aim? target 'cify) (aim? target 'interp))
            (reverse es)
            (for/list ([e (in-list (reverse es))])
              (make-expr-defn e))))
      (cond
       [(null? l)
        (set! final-knowns knowns)
        ;; Finish by making sure that all pending variables in `accum-ids` are
        ;; moved into their `variable` records:
        (define set-vars (make-set-variables))
        (cond
         [(null? set-vars)
          (cond
           [(null? accum-exprs) '((void))]
           [else (reverse accum-exprs)])]
         [else (reverse (append set-vars accum-exprs))])]
       [else
        (define form (car l))
        (define schemified (schemify form
                                     prim-knowns primitives knowns mutated imports exports extra-variables simples
                                     allow-set!-undefined?
                                     add-import!
                                     serializable?-box datum-intern? target
                                     unsafe-mode? allow-inline? no-prompt? explicit-unnamed?
                                     compiler-query
                                     (if (and no-prompt? (null? (cdr l)))
                                         'tail
                                         'fresh)))
        ;; For the case that the right-hand side won't capture a
        ;; continuation or return multiple times, we can generate a
        ;; simple definition:
        (define (finish-definition ids [accum-exprs accum-exprs] [accum-ids accum-ids]
                                   #:knowns [knowns knowns]
                                   #:schemified [schemified schemified]
                                   #:next-k [next-k #f])
          ;; Maybe schemify made a known shape apparent:
          (define next-knowns
            (cond
              [(and (pair? ids)
                    (null? (cdr ids))
                    (can-improve-infer-known? (hash-ref knowns (unwrap (car ids)) #f)))
               (define id (car ids))
               (define k (match schemified
                           [`(define ,id ,rhs)
                            (infer-known rhs id knowns prim-knowns imports mutated simples unsafe-mode? target
                                         #:post-schemify? #t)]))
               (if k
                   (hash-set knowns (unwrap id) k)
                   knowns)]
              [else knowns]))
          (append
           (make-expr-defns accum-exprs)
           (cons
            schemified
            (let id-loop ([ids ids] [accum-exprs null] [accum-ids accum-ids])
              (cond
                [(null? ids) (if next-k
                                 (next-k accum-exprs accum-ids next-knowns)
                                 (loop (cdr l) mut-l accum-exprs accum-ids next-knowns))]
                [(or (or (aim? target 'interp) (aim? target 'cify))
                     (via-variable-mutated-state? (hash-ref mutated (unwrap (car ids)) #f)))
                 (define id (unwrap (car ids)))
                 (cond
                   [(or (hash-ref exports id #f)
                        (hash-ref extra-variables id #f))
                    (id-loop (cdr ids)
                             (cons (make-set-variable id exports knowns mutated extra-variables)
                                   accum-exprs)
                             accum-ids)]
                   [else
                    (id-loop (cdr ids) accum-exprs accum-ids)])]
                [else
                 (id-loop (cdr ids) accum-exprs (cons (car ids) accum-ids))])))))
        ;; For the case when the right-hand side might capture a
        ;; continuation or return multiple times, so we need a prompt.
        ;; The `variable` records are set within the prompt, while
        ;; definitions appear outside the prompt to just transfer the
        ;; value into a `variable` record (if it's not one that is
        ;; mutable, and therefore always access via the `variable`
        ;; record):
        (define (finish-wrapped-definition ids rhs)
          (append
           (make-expr-defns accum-exprs)
           (make-expr-defns (make-set-variables))
           (cond
             [no-prompt?
              (cons
               (cond
                 [(or unsafe-mode?
                      (aim? target 'system)
                      (and (pair? ids) (null? (cdr ids))))
                  schemified]
                 [else
                  `(define-values ,ids
                     (call-with-values
                      (lambda () ,rhs)
                      (case-lambda
                        [,ids (values . ,ids)]
                        [vals (raise-definition-result-arity-error ',ids vals)])))])
               (loop (cdr l) mut-l null (reverse ids) knowns))]
             [else
              (define expr
                `(call-with-module-prompt
                  (lambda () ,rhs)
                  ',ids
                  ',(for/list ([id (in-list ids)])
                      (variable-constance (unwrap id) knowns mutated))
                  ,@(for/list ([id (in-list ids)])
                      (id-to-variable (unwrap id) exports extra-variables))))
              (define defns
                (for/list ([id (in-list ids)])
                  (make-define-variable id exports knowns mutated extra-variables)))
              (cons
               (if (aim? target 'interp)
                   expr
                   (make-expr-defn expr))
               (append defns (loop (cdr l) mut-l null null knowns)))])))
        ;; Dispatch on the schemified form, distinguishing definitions
        ;; from expressions:
        (match schemified
          [`(define ,id ,rhs)
           (cond
             [(simple? #:pure? #f rhs prim-knowns knowns imports mutated simples unsafe-mode?)
              (finish-definition (list id))]
             [else
              (finish-wrapped-definition (list id) rhs)])]
          [`(define-values ,ids ,rhs)
           (cond
             [(simple? #:pure? #f rhs prim-knowns knowns imports mutated simples unsafe-mode?
                       #:result-arity (length ids))
              (match rhs
                [`(values ,rhss ...)
                 ;; Flatten `(define-values (id ...) (values rhs ...))` to
                 ;; a sequence `(define id rhs) ...`
                 (if (and (= (length rhss) (length ids))
                          ;; Must be simple enough, otherwise a variable might be referenced
                          ;; too early:
                          (for/and ([rhs (in-list rhss)])
                            (simple? #:ordered? #t rhs prim-knowns knowns imports mutated simples unsafe-mode?)))
                     (let values-loop ([ids ids] [rhss rhss] [accum-exprs accum-exprs] [accum-ids accum-ids] [knowns knowns])
                       (cond
                         [(null? ids) (loop (cdr l) mut-l accum-exprs accum-ids knowns)]
                         [else
                          (define id (car ids))
                          (define rhs (car rhss))
                          (finish-definition (list id) accum-exprs accum-ids
                                             #:knowns knowns
                                             #:schemified `(define ,id ,rhs)
                                             #:next-k (lambda (accum-exprs accum-ids knowns)
                                                        (values-loop (cdr ids) (cdr rhss) accum-exprs accum-ids knowns)))]))
                     (finish-definition ids))]
                [`,_ (finish-definition ids)])]
             [else
              (finish-wrapped-definition ids rhs)])]
          [`(quote ,_) ; useful to drop #<void>s for the interpreter
           #:guard (or (pair? (cdr l)) (pair? accum-ids))
           (loop (cdr l) mut-l accum-exprs accum-ids knowns)]
          [`,_
           (match form
             [`(define-values ,ids ,_)
              ;; This is a rearranged `struct` form where any necessary
              ;; prompt is in place already. There may be arbitrary expressions
              ;; for properties, though, so sync exported variables
              (define set-vars (make-set-variables))
              (finish-definition ids (append set-vars accum-exprs) null)]
             [`,_
              (cond
                [(simple? #:pure? #f schemified prim-knowns knowns imports mutated simples unsafe-mode?
                          #:result-arity #f)
                 (loop (cdr l) mut-l (cons schemified accum-exprs) accum-ids knowns)]
                [else
                 ;; In case `schemified` triggers an error, sync exported variables
                 (define set-vars (make-set-variables))
                 (define expr (if no-prompt?
                                  schemified
                                  `(call-with-module-prompt (lambda () ,schemified))))
                 (loop (cdr l) mut-l (cons expr (append set-vars accum-exprs)) null knowns)])])])])))
  ;; Return both schemified and known-binding information, where
  ;; the later is used for cross-linklet optimization
  (values (add-extra-variables schemified) final-knowns mutated))

(define (make-set-variable id exports knowns mutated [extra-variables #f])
  (define int-id (unwrap id))
  (define ex-id (id-to-variable int-id exports extra-variables))
  `(variable-set!/define ,ex-id ,id ',(variable-constance int-id knowns mutated)))

;; returns a list equilanet to a sequence of `variable-set!/define` forms
(define (make-set-consistent-variables ids exports knowns mutated extra-variables)
  (cond
    [(null? ids) null]
    [(null? (cdr ids)) (list (make-set-variable (car ids) exports knowns mutated extra-variables))]
    [else
     (define ex-ids (for/list ([id (in-list ids)])
                      (id-to-variable (unwrap id) exports extra-variables)))
     `((set-consistent-variables!/define (vector ,@ex-ids) (vector ,@ids)))]))

(define (make-define-variable id exports knowns mutated extra-variables)
  (define int-id (unwrap id))
  (define ex (or (hash-ref exports int-id #f)
                 (hash-ref extra-variables int-id)))
  `(define ,id (variable-ref/no-check ,(export-id ex))))

(define (make-expr-defn expr)
  `(define ,(deterministic-gensym "effect") (begin ,expr (void))))

(define (variable-constance id knowns mutated)
  (cond
    [(set!ed-mutated-state? (hash-ref mutated id #f))
     #f]
    [(known-consistent? (hash-ref knowns id #f))
     'consistent]
    [else
     'constant]))

;; ----------------------------------------

;; Schemify `let-values` to `let`, etc., and reorganize struct bindings.
;;
;; Non-simple `mutated` state overrides bindings in `knowns`; a
;; a 'too-early state in `mutated` for a `letrec`-bound variable can be
;; effectively canceled with a mapping in `knowns`.
(define (schemify v prim-knowns primitives knowns mutated imports exports extra-variables simples allow-set!-undefined? add-import!
                  serializable?-box datum-intern? target unsafe-mode? allow-inline? no-prompt? explicit-unnamed?
                  compiler-query
                  wcm-state)
  ;; `wcm-state` is one of: 'tail (= unknown), 'fresh (= no marks), or 'marked (= some marks)
  (let schemify/knowns ([knowns knowns] [inline-fuel init-inline-fuel] [wcm-state wcm-state] [unsafe-mode? unsafe-mode?] [v v])
    (define (schemify v wcm-state [unsafe-mode? unsafe-mode?])
      (define s-v
        (reannotate
         v 
         (match v
           [`(lambda ,formals ,body ...)
            (infer-procedure-name
             v
             `(lambda ,formals ,@(schemify-body (maybe-unsafe v body) 'tail))
              explicit-unnamed?)]
           [`(case-lambda [,formalss ,bodys ...] ...)
            (infer-procedure-name
             v
             `(case-lambda ,@(for/list ([formals (in-list formalss)]
                                        [body (in-list bodys)])
                               `[,formals ,@(schemify-body (maybe-unsafe v body) 'tail)]))
             explicit-unnamed?)]
           [`(define-values (,struct:s ,make-s ,s? ,acc/muts ...)
               (let-values (((,struct: ,make ,?1 ,-ref ,-set!) ,mk))
                 (values ,struct:2
                         ,make2
                         ,?2
                         ,make-acc/muts ...)))
            #:guard (not (or (aim? target 'interp) (aim? target 'cify)))
            (define new-seq
              (struct-convert v prim-knowns knowns imports exports mutated
                              (lambda (v knowns) (schemify/knowns knowns inline-fuel 'fresh unsafe-mode? v))
                              target no-prompt? #t))
            (or new-seq
                (match v
                  [`(,_ ,ids ,rhs)
                   `(define-values ,ids ,(schemify rhs 'fresh))]))]
           [`(define-values (,id) ,rhs)
            `(define ,id ,(schemify rhs 'fresh))]
           [`(define-values ,ids ,rhs)
            `(define-values ,ids ,(schemify rhs 'fresh))]
           [`(quote ,q)
            (when serializable?-box
              (register-literal-serialization q serializable?-box datum-intern?))
            v]
           [`(let-values () ,body)
            (schemify body wcm-state)]
           [`(let-values () ,bodys ...)
            (schemify `(begin . ,bodys) wcm-state)]
           [`(let-values ([(,ids) ,rhss] ...) ,bodys ...)
            (cond
              [(and (pair? ids) (null? (cdr ids))
                    (pair? bodys) (null? (cdr bodys))
                    (eq? (unwrap (car ids)) (unwrap (car bodys)))
                    (lambda? (car rhss)))
               ;; Simplify by discarding the binding; assume that any
               ;; needed naming is already reflected in properties
               (schemify (car rhss) wcm-state)]
              [else
               (define copy-rhs null) null ; => merely a copy
               (define-values (new-knowns rev-s-rhss)
                 (for/fold ([knowns knowns] [rev-s-rhss '()]) ([id (in-list ids)]
                                                               [rhs (in-list rhss)])
                   ;; early `infer-known` to detect "mere copies"
                   (define k (infer-known rhs id knowns prim-knowns imports mutated simples unsafe-mode? target))
                   (define (merely-a-copy? k)
                     (and (or (known-copy? k)
                              (known-literal? k))
                          (simple-mutated-state? (hash-ref mutated (unwrap id) #f))))
                   (cond
                     [(merely-a-copy? k)
                      (values (hash-set knowns (unwrap id) k)
                              (cons copy-rhs
                                    rev-s-rhss))]
                     [else
                      (define s-rhs (schemify rhs 'fresh))
                      (cond
                        [(known-procedure/can-inline? k)
                         (values (hash-set knowns (unwrap id) k)
                                 (cons s-rhs rev-s-rhss))]
                        [else
                         ;; try inferring from schemified, which has also been optimized
                         (define post-k (infer-known s-rhs id knowns prim-knowns imports mutated simples unsafe-mode? target
                                                     #:post-schemify? #t))
                         (cond
                           [(merely-a-copy? post-k)
                            (values (hash-set knowns (unwrap id) post-k)
                                    (cons copy-rhs rev-s-rhss))]
                           [post-k
                            (values (hash-set knowns (unwrap id) post-k)
                                    (cons s-rhs rev-s-rhss))]
                           [else
                            (values knowns
                                    (cons s-rhs rev-s-rhss))])])])))
               (define s-rhss (reverse rev-s-rhss))
               (unnest-let
                (left-to-right/let (for/list ([id (in-list ids)]
                                              [rhs (in-list s-rhss)]
                                              #:unless (eq? copy-rhs rhs))
                                     id)
                                   (for/list ([id (in-list ids)]
                                              [rhs (in-list s-rhss)]
                                              #:unless (eq? copy-rhs rhs))
                                     rhs)
                                   (for/list ([body (in-list bodys)])
                                     (schemify/knowns new-knowns inline-fuel wcm-state unsafe-mode? body))
                                   prim-knowns knowns imports mutated simples unsafe-mode?)
                prim-knowns knowns imports mutated simples unsafe-mode?)])]
           [`(let-values ([() (begin ,rhs (values))]) ,bodys ...)
            `(begin ,(schemify rhs 'fresh) ,@(schemify-body bodys wcm-state))]
           [`(let-values ([,idss ,rhss] ...) ,bodys ...)
            (or (and (not (or (aim? target 'interp) (aim? target 'cify)))
                     (struct-convert-local v prim-knowns knowns imports mutated simples
                                           (lambda (v knowns) (schemify/knowns knowns inline-fuel 'fresh unsafe-mode? v))
                                           #:unsafe-mode? unsafe-mode?
                                           #:target target))
                (unnest-let
                 (left-to-right/let-values idss
                                           (for/list ([rhs (in-list rhss)])
                                             (schemify rhs 'fresh))
                                           (schemify-body bodys wcm-state)
                                           mutated
                                           target
					   unsafe-mode?)
                 prim-knowns knowns imports mutated simples unsafe-mode?))]
           [`(letrec-values () ,bodys ...)
            (schemify `(begin . ,bodys) wcm-state)]
           [`(letrec-values ([() (values)]) ,bodys ...)
            (schemify `(begin . ,bodys) wcm-state)]
           [`(letrec-values ([(,id) (values ,rhs)]) ,bodys ...)
            ;; special case of splitable values:
            (schemify `(letrec-values ([(,id) ,rhs]) . ,bodys) wcm-state)]
           [`(letrec-values ([(,ids) ,rhss] ...) ,bodys ...)
            (define-values (rhs-knowns body-knowns)
              (for/fold ([rhs-knowns knowns] [body-knowns knowns]) ([id (in-list ids)]
                                                                    [rhs (in-list rhss)])
                (define k (infer-known rhs id knowns prim-knowns imports mutated simples unsafe-mode? target))
                (define u-id (unwrap id))
                (cond
                  [(too-early-mutated-state? (hash-ref mutated u-id #f))
                   (values rhs-knowns (hash-set knowns u-id (or k a-known-constant)))]
                  [k (values (hash-set rhs-knowns u-id k) (hash-set body-knowns u-id k))]
                  [else (values rhs-knowns body-knowns)])))
            (unnest-let
             (letrec-conversion
              ids mutated target
              `(letrec* ,(for/list ([id (in-list ids)]
                                    [rhs (in-list rhss)])
                           `[,id ,(schemify/knowns rhs-knowns inline-fuel 'fresh unsafe-mode? rhs)])
                 ,@(for/list ([body (in-list bodys)])
                     (schemify/knowns body-knowns inline-fuel wcm-state unsafe-mode? body))))
             prim-knowns knowns imports mutated simples unsafe-mode?)]
           [`(letrec-values ([,idss ,rhss] ...) ,bodys ...)
            (cond
              [(struct-convert-local v #:letrec? #t prim-knowns knowns imports mutated simples
                                     (lambda (v knowns) (schemify/knowns knowns inline-fuel 'fresh unsafe-mode? v))
                                     #:unsafe-mode? unsafe-mode?
                                     #:target target)
               => (lambda (form) form)]
              [(letrec-splitable-values-binding? idss rhss)
               (schemify
                (letrec-split-values-binding idss rhss bodys)
                wcm-state)]
              [else
               ;; Convert
               ;;  (letrec*-values ([(id ...) rhs] ...) ....)
               ;; to
               ;;  (letrec* ([vec (call-with-values rhs vector)]
               ;;            [id (vector-ref vec 0)]
               ;;            ... ...)
               ;;    ....)
               (letrec-conversion
                idss mutated target
                `(letrec* ,(apply
                            append
                            (for/list ([ids (in-list idss)]
                                       [rhs (in-list rhss)])
                              (let ([rhs (schemify rhs 'fresh)])
                                (cond
                                  [(null? ids)
                                   `([,(deterministic-gensym "lr")
                                      ,(make-let-values null rhs '(void) target unsafe-mode?)])]
                                  [(and (pair? ids) (null? (cdr ids)))
                                   `([,(car ids) ,rhs])]
                                  [else
                                   (define lr (deterministic-gensym "lr"))
                                   `([,lr ,(make-let-values ids rhs `(vector . ,ids) target unsafe-mode?)]
                                     ,@(for/list ([id (in-list ids)]
                                                  [pos (in-naturals)])
                                         `[,id (unsafe-vector*-ref ,lr ,pos)]))]))))
                   ,@(schemify-body bodys wcm-state)))])]
           [`(if ,tst ,thn ,els)
            `(if ,(schemify tst 'fresh) ,(schemify thn wcm-state) ,(schemify els wcm-state))]
           [`(with-continuation-mark ,key ,val ,body)
            (define s-key (schemify key 'fresh))
            (define s-val (schemify val 'fresh))
            (define s-body (schemify body 'marked))
            (define authentic-key?
              (authentic-valued? key knowns prim-knowns imports mutated))
            (define (build-wcm s-key s-val s-body)
              (cond
                [(aim? target 'cify)
                 `(with-continuation-mark ,s-key ,s-val ,s-body)]
                [else
                 (define mode
                   (case wcm-state
                     [(fresh) (if authentic-key? 'push-authentic 'push)]
                     [else (if authentic-key? 'authentic 'general)]))
                 `(with-continuation-mark* ,mode ,s-key ,s-val ,s-body)]))
            (define (build-begin s-key s-val s-body)
              (cond
                [(and (simple? s-key prim-knowns knowns imports mutated simples unsafe-mode?)
                      (simple? s-val prim-knowns knowns imports mutated simples unsafe-mode?))
                 ;; Avoid `begin` wrapper to help further `with-continuation-mark` optimizations
                 s-body]
                [else
                 `(begin ,(ensure-single-valued s-key knowns prim-knowns imports mutated)
                         ,(ensure-single-valued s-val knowns prim-knowns imports mutated)
                         ,s-body)]))
            (cond
              [authentic-key?
               (cond
                 [(simple? #:ordered? #t s-body prim-knowns knowns imports mutated simples unsafe-mode? #:result-arity #f)
                  (build-begin s-key s-val s-body)]
                 [else
                  ;; Simplify (with-continuation-mark <same-key> <val1>
                  ;;           (with-continuation-mark <same-key> <val2>
                  ;;            <body>)
                  ;; to       (begin <same-key> <val1>
                  ;;           (with-continuation-mark <same-key> <val2>
                  ;;            <body>))
                  ;; as long as <same-key> and <val2> don't use marks
                  (match s-body
                    [`(with-continuation-mark* ,mode2 ,s-key2 ,s-val2 ,s-body2)
                     (cond
                       [(and (always-eq/no-marks? s-key s-key2 mutated)
                             (simple? #:ordered? #t s-val2 prim-knowns knowns imports mutated simples unsafe-mode?))
                        (build-begin s-key s-val
                                     ;; rebuild to use current `wcm-state`:
                                     (build-wcm s-key2 s-val2 s-body2))]
                       [else (build-wcm s-key s-val s-body)])]
                    [`,_ (build-wcm s-key s-val s-body)])])]
              [else
               (build-wcm s-key s-val s-body)])]
           [`(begin ,exp)
            (schemify exp wcm-state)]
           [`(begin ,exps ...)
            `(begin . ,(schemify-body exps wcm-state))]
           [`(begin-unsafe ,exps ...)
            (if unsafe-mode?
                (schemify `(begin . ,exps) wcm-state)
                `(begin-unsafe . ,(schemify-body exps wcm-state #t)))]
           [`(begin0 ,exp)
            (schemify exp wcm-state)]
           [`(begin0 ,exp ,exps ...)
            `(begin0 ,(schemify exp 'fresh) . ,(schemify-body exps 'fresh))]
           [`(set! ,id ,rhs)
            (define int-id (unwrap id))
            (define ex (or (hash-ref exports int-id #f)
                           (hash-ref extra-variables int-id #f)))
            (define new-rhs (schemify rhs 'fresh))
            (define state (hash-ref mutated int-id #f))
            (cond
              [ex
               (define set-id
                 (if (or allow-set!-undefined?
                         (not (too-early-mutated-state? state)))
                     'variable-set!
                     'variable-set!/check-undefined))
               `(,set-id ,(export-id ex) ,new-rhs)]
              [else
               (cond
                 [(and (too-early-mutated-state? state)
                       (not (aim? target 'cify)))
                  (define tmp (deterministic-gensym "set"))
                  `(let ([,tmp ,new-rhs])
                     (check-not-unsafe-undefined/assign ,id ',(too-early-mutated-state-name state int-id))
                     (set! ,id ,tmp))]
                 [(not state)
                  ;; It's worrying that `id` is not marked as mutable, but this is
                  ;; possible when mutability inference determines that the `set!` is
                  ;; dead code. Since the variable is not mutated, it might even be
                  ;; optimized away by schemify; so, just in case, discard the `set!`.
                  `(void ,new-rhs)]
                 [else
                  `(set! ,id ,new-rhs)])])]
           [`(variable-reference-constant? (#%variable-reference ,id))
            (define u-id (unwrap id))
            (cond
              [(hash-ref mutated u-id #f) #f]
              [else
               (define im (hash-ref imports u-id #f))
               (cond
                 [(not im)
                  ;; Not imported and not mutable => a constant or local defined
                  ;; in this linklet or a direct primitive reference
                  #t]
                 [(known-constant? (import-lookup im)) #t]
                 [else
                  ;; Not statically known
                  `(variable-reference-constant? ,(schemify `(#%variable-reference ,id) 'fresh))])])]
           [`(variable-reference-from-unsafe? (#%variable-reference))
            unsafe-mode?]
           [`(#%variable-reference)
            'instance-variable-reference]
           [`(#%variable-reference ,id)
            (define u (unwrap id))
            (define v (or (let ([ex (or (hash-ref exports u #f)
                                        (hash-ref extra-variables u #f))])
                            (and ex (export-id ex)))
                          (let ([im (hash-ref imports u #f)])
                            (and im (import-id im)))))
            (if v
                `(make-instance-variable-reference 
                  instance-variable-reference
                  ,v)
                `(make-instance-variable-reference 
                  instance-variable-reference
                  ',(cond
                      [(hash-ref mutated u #f) 'mutable]
                      [(hash-ref prim-knowns u #f) u] ; assuming that `mutable` and `constant` are not primitives
                      [else 'constant])))]
           [`(equal? ,exp1 ,exp2)
            (optimize-equal 'equal? (schemify exp1 'fresh) (schemify exp2 'fresh)
                            target prim-knowns knowns imports mutated simples unsafe-mode?)]
           [`(equal-always? ,exp1 ,exp2)
            (optimize-equal 'equal-always? (schemify exp1 'fresh) (schemify exp2 'fresh)
                            target prim-knowns knowns imports mutated simples unsafe-mode?)]
	   [`(procedure-result-arity ,proc)
	    (cond [(single-valued-lambda? proc knowns prim-knowns imports mutated) 1]
		  [else `(procedure-result-arity ,(schemify proc 'fresh))])]
           [`(call-with-values ,generator ,receiver)
            (cond
	     [(and (single-valued-lambda? generator knowns prim-knowns imports mutated)
		   (match receiver
		     [`(lambda (,id) ,body)
		      `(let ([,id  ,(schemify `(,generator) 'fresh)])
                         ,(schemify body 'fresh))]
		     [`(case-lambda [(,id) ,body] . ,_)
		      `(let ([,id  ,(schemify `(,generator) 'fresh)])
                         ,(schemify body 'fresh))]
		     [`(lambda ,id (apply ,fun ,id2))
		      ;; it would be nice to generalize this to
		      ;; arbitrary numbers of arguments to apply
		      (and (symbol? id)
			   (eq? id id2)
			   `(let ([,id  ,(schemify `(,generator) 'fresh)])
			      (,(schemify fun 'fresh) ,id)))]
		     [`,_ #f]))] ;; no rhs, just returns match result
              [(and (lambda? generator)
                    (or (lambda? receiver)
                        (eq? (unwrap receiver) 'list)))
               `(call-with-values ,(schemify generator 'fresh) ,(schemify receiver 'fresh))]
              [else
               (left-to-right/app (if (aim? target 'cify) 'call-with-values '#%call-with-values)
                                  (list (schemify generator 'fresh) (schemify receiver 'fresh))
                                  #f target
                                  prim-knowns knowns imports mutated simples unsafe-mode?)])]
           [`(single-flonum-available?)
            ;; Fold to a boolean to allow earlier simplification
            (aim? target 'cify)]
           [`((letrec-values ,binds ,rator) ,rands ...)
            (schemify `(letrec-values ,binds (,rator . ,rands)) wcm-state)]
           [`(,rator ,exps ...)
            (define (left-left-lambda-convert rator inline-fuel)
              (match rator
                [`(lambda ,formal-args ,bodys ...)
                 ;; Try to line up `formal-args` with `exps`
                 (let loop ([formal-args formal-args] [args exps] [binds '()])
                   (cond
                     [(null? formal-args)
                      (and (null? args)
                           (let ([r (schemify/knowns knowns
                                                     inline-fuel
                                                     wcm-state
                                                     unsafe-mode?
                                                     `(let-values ,(reverse binds) . ,bodys))])
                             ;; make suure constant-fold to #f counts as success:
                             (or r `(quote #f))))]
                     [(null? args) #f]
                     [(not (pair? formal-args))
                      (loop '() '() (cons (list (list formal-args)
                                                (if (null? args)
                                                    ''()
                                                    (cons 'list args)))
                                          binds))]
                     [else
                      (loop (cdr formal-args)
                            (cdr args)
                            (cons (list (list (car formal-args))
                                        (car args))
                                  binds))]))]
                [`(case-lambda [,formal-args ,bodys ...] . ,rest)
                 (or (left-left-lambda-convert `(lambda ,formal-args . ,bodys) inline-fuel)
                     (left-left-lambda-convert `(case-lambda . ,rest) inline-fuel))]
                [`,_ #f]))
            (define (inline-rator)
              (define u-rator (unwrap rator))
              (and allow-inline?
                   (symbol? u-rator)
                   (let-values ([(k im) (find-known+import u-rator prim-knowns knowns imports mutated)])
                     (and (known-procedure/can-inline? k)
                          (or (aim? target 'cify)
                              (not unsafe-mode?)
                              (unsafe-body? (known-procedure/can-inline-expr k)))
                          (left-left-lambda-convert
                           (inline-clone k im add-import! mutated imports)
                           (sub1 inline-fuel))))))
            (define (maybe-tmp e name)
              ;; use `e` directly if it's ok to duplicate
              (if (simple/can-copy? e prim-knowns knowns imports mutated)
                  e
                  (deterministic-gensym name)))
            (define (wrap-tmp tmp e body)
              (if (eq? tmp e)
                  body
                  `(let ([,tmp ,e])
                     ,body)))
            (define (inline-struct-constructor k s-rator im args)
              (define type-id (and (bitwise-bit-set? (known-procedure-arity-mask k) (length args))
                                   (inline-type-id k im add-import! mutated imports)))
              (cond
                [type-id
                 (left-to-right/app 'unsafe-struct
                                    (cons (schemify type-id 'fresh) args)
                                    #f target
                                    prim-knowns knowns imports mutated simples unsafe-mode?)]
                [else #f]))
            (define (inline-struct-predicate k s-rator im args)
              (define type-id (and (pair? args)
                                   (null? (cdr args))
                                   (inline-type-id k im add-import! mutated imports)))
              (define unsafe-struct? (if (known-struct-predicate-sealed? k)
                                         'unsafe-sealed-struct?
                                         'unsafe-struct?))
              (cond
                [(not type-id) #f]
                [(known-struct-predicate-authentic? k)
                 (define tmp (maybe-tmp (car args) 'v))
                 (define ques `(,unsafe-struct? ,tmp ,(schemify type-id 'fresh)))
                 (wrap-tmp tmp (car args)
                           ques)]
                [else
                 (define tmp (maybe-tmp (car args) 'v))
                 (define schemified-type-id (schemify type-id 'fresh))
                 (define tmp-type-id (maybe-tmp schemified-type-id 'v))
                 (define ques `(if (,unsafe-struct? ,tmp ,tmp-type-id)
                                   #t
                                   (if (impersonator? ,tmp)
                                       (,unsafe-struct? (impersonator-val ,tmp) ,tmp-type-id)
                                       #f)))
                 (wrap-tmp tmp (car args)
                           (wrap-tmp tmp-type-id schemified-type-id 
                                     ques))]))
            (define (inline-field-access k s-rator im args)
              ;; Inline the selector with an `unsafe-struct?` test plus `unsafe-struct*-ref`.
              (define type-id (and (pair? args)
                                   (null? (cdr args))
                                   (inline-type-id k im add-import! mutated imports)))
              (cond
                [type-id
                 (define tmp (maybe-tmp (car args) 'v))
                 (define sel (if (and unsafe-mode?
                                      (known-field-accessor-authentic? k))
                                 `(unsafe-struct*-ref ,tmp ,(known-field-accessor-pos k))
                                 `(if (unsafe-struct? ,tmp ,(schemify type-id 'fresh))
                                      (unsafe-struct*-ref ,tmp ,(known-field-accessor-pos k))
                                      ,(let ([a `(,s-rator ,tmp)])
                                         (if (known-field-accessor-authentic? k)
                                             (cons '#%app/no-return a)
                                             a)))))
                 (wrap-tmp tmp (car args)
                           sel)]
                [else #f]))
            (define (inline-field-mutate k s-rator im args)
              (define type-id (and (pair? args)
                                   (pair? (cdr args))
                                   (null? (cddr args))
                                   (inline-type-id k im add-import! mutated imports)))
              (cond
                [type-id
                 (define tmp (maybe-tmp (car args) 'v))
                 (define tmp-rhs (maybe-tmp (cadr args) 'rhs))
                 (define mut (if (and unsafe-mode?
                                      (known-field-mutator-authentic? k))
                                 `(unsafe-struct*-set! ,tmp ,(known-field-mutator-pos k) ,tmp-rhs)
                                 `(if (unsafe-struct? ,tmp ,(schemify type-id 'fresh))
                                      (unsafe-struct*-set! ,tmp ,(known-field-mutator-pos k) ,tmp-rhs)
                                      ,(let ([a `(,s-rator ,tmp ,tmp-rhs)])
                                         (if (known-field-mutator-authentic? k)
                                             (cons '#%app/no-return a)
                                             a)))))
                 (wrap-tmp tmp (car args)
                           (wrap-tmp tmp-rhs (cadr args)
                                     mut))]
                [else #f]))
            (or (left-left-lambda-convert rator inline-fuel)
                (and (positive? inline-fuel)
                     (inline-rator))
                (let ([s-rator (schemify rator 'fresh)]
                      [args (schemify-body exps 'fresh)]
                      [u-rator (unwrap rator)])
                  (define-values (k im) (find-known+import u-rator prim-knowns knowns imports mutated))
                  (cond
                    [(or (and (eq? rator 'ptr-ref) (inline-ptr-ref args))
                         (and (eq? rator 'ptr-set!) (inline-ptr-set args)))
                     => (lambda (e)
                          (left-to-right/app (car e)
                                             (cdr e)
                                             #f target
                                             prim-knowns knowns imports mutated simples unsafe-mode?))]
                    [(and (not (or
                                ;; Don't inline in cify mode, because cify takes care of it
                                (aim? target 'cify)
                                ;; Don't inline in 'system mode, because there will
                                ;; be no `|#%struct-constructor| in the way, and
                                ;; it's more readable to use the normal constructor name
                                (aim? target 'system)))
                          (known-struct-constructor? k)
                          (inline-struct-constructor k s-rator im args))
                     => (lambda (e) e)]
                    [(and (not (or
                                (aim? target 'cify)
                                (aim? target 'system)))
                          (known-struct-predicate? k)
                          (inline-struct-predicate k s-rator im args))
                     => (lambda (e) e)]
                    [(and (not (or
                                (aim? target 'cify)
                                (aim? target 'system)))
                          (known-field-accessor? k)
                          (inline-field-access k s-rator im args))
                     => (lambda (e) e)]
                    [(and (not (or
                                (aim? target 'cify)
                                (aim? target 'system)))
                          (known-field-mutator? k)
                          (inline-field-mutate k s-rator im args))
                     => (lambda (e) e)]
                    [(and unsafe-mode?
                          (known-procedure/has-unsafe? k))
                     (left-to-right/app (known-procedure/has-unsafe-alternate k)
                                        args
                                        #f target
                                        prim-knowns knowns imports mutated simples unsafe-mode?)]
                    [(eq? (unwrap s-rator) 'ffi-maybe-call-and-callback-core)
                     ;; no left-to-right needed by use in `unsafe/ffi`, and avoiding a conversion helps optimization
                     `(,s-rator ,@args)]
                    [else
                     (left-to-right/app s-rator
                                        args
                                        (cond
                                          [(and (not (aim? target 'system))
                                                (known-procedure/no-return? k))
                                           '#%app/no-return]
                                          [(and im
                                                (known-procedure/single-valued? k))
                                           '#%app/value]
                                          [(or (known-procedure? k)
                                               (lambda? rator))
                                           #f]
                                          [else '|#%app|])
                                        target
                                        prim-knowns knowns imports mutated simples unsafe-mode?)])))]
           [`,_
            (let ([u-v (unwrap v)])
              (cond
                [(not (symbol? u-v)) v]
                [(eq? u-v 'call-with-values)
                 '#%call-with-values]
                [else
                 (define state (hash-ref mutated u-v #f))
                 (cond
                   [(and (via-variable-mutated-state? state)
                         (or (hash-ref exports u-v #f)
                             (hash-ref extra-variables u-v #f)))
                    => (lambda (ex)
                         (if (too-early-mutated-state? state)
                             `(variable-ref ,(export-id ex))
                             `(variable-ref/no-check ,(export-id ex))))]
                   [(hash-ref imports u-v #f)
                    => (lambda (im)
                         (define k (import-lookup im))
                         (if (known-constant? k)
                             ;; Not boxed:
                             (cond
                               [(known-literal? k)
                                ;; We'd normally leave this to `optimize`, but
                                ;; need to handle it here before generating a
                                ;; reference to the renamed identifier
                                (wrap-literal (known-literal-value k))]
                               [(and (known-copy? k)
                                     (hash-ref prim-knowns (known-copy-id k) #f))
                                ;; Directly reference primitive
                                (known-copy-id k)]
                               [else
                                (import-id im)])
                             ;; Will be boxed, but won't be undefined (because the
                             ;; module system won't link to an instance whose
                             ;; definitions didn't complete):
                             `(variable-ref/no-check ,(import-id im))))]
                   [(hash-ref knowns u-v #f)
                    => (lambda (k)
                         (cond
                           [(and (known-copy? k)
                                 (simple-mutated-state? (hash-ref mutated u-v #f)))
                            (schemify (known-copy-id k) wcm-state)]
                           [else v]))]
                   [(and (too-early-mutated-state? state)
                         (not (aim? target 'cify)))
                    ;; Note: we don't get to this case if `knowns` has
                    ;; a mapping that says the variable is ready by now
                    `(check-not-unsafe-undefined ,v ',(too-early-mutated-state-name state u-v))]
                   [else v])]))])))
      (optimize s-v prim-knowns primitives knowns imports mutated target compiler-query))

    (define (schemify-body l wcm-state [unsafe-mode? unsafe-mode?])
      (cond
        [(null? l) null]
        [(null? (cdr l))
         (list (schemify (car l) wcm-state unsafe-mode?))]
        [else
         (cons (schemify (car l) 'fresh unsafe-mode?)
               (schemify-body (cdr l) wcm-state unsafe-mode?))]))

    (schemify v wcm-state)))
