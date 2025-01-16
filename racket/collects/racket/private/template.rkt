(module template '#%kernel
(#%require "stx.rkt" "define-et-al.rkt" "qq-and-or.rkt" "cond.rkt" "performance-hint.rkt"
           (rename "define-et-al.rkt" define -define)
           (rename "define-et-al.rkt" define-syntax -define-syntax)
           "ellipses.rkt"
           (for-syntax "stx.rkt" "define-et-al.rkt" "qq-and-or.rkt" "cond.rkt"
                       "prop-template-metafunction.rkt"
                       (rename "define-et-al.rkt" define -define)
                       (rename "define-et-al.rkt" define-syntax -define-syntax)
                       #;"member.rkt" "sc.rkt" '#%kernel))
(#%provide syntax
           syntax/loc
           datum
           ~? ~@
           ~@! signal-absent-pvar
           (for-syntax prop:template-metafunction
                       template-metafunction
                       template-metafunction?)
           (protect
            (for-syntax attribute-mapping
                        attribute-mapping?
                        attribute-mapping-name
                        attribute-mapping-var
                        attribute-mapping-depth
                        attribute-mapping-check)))

;; ============================================================
;; Syntax of templates

;; A Template (T) is one of:
;;   - pattern-variable
;;   - constant (including () and non-pvar identifiers)
;;   - (template-metafunction . T)
;;     ; or any other structure that implements prop:template-metafunction
;;   - (H . T)
;;   - (H ... . T), (H ... ... . T), etc
;;   - (... T)          -- escapes inner ..., ~?, ~@
;;   - (~? T T)
;;   - #(T*)            -- actually, vector->list interpreted as T
;;   - #s(prefab-struct-key T*) -- likewise

;; A HeadTemplate (H) is one of:
;;   - T
;;   - (~? H)
;;   - (~? H H)
;;   - (~@ . T)

(define-syntax ~@! #f) ;; private, escape-ignoring version of ~@, used by unsyntax-splicing

;; ============================================================
;; Compile-time

;; Parse template syntax into a Guide (AST--the name is left over from
;; when the "guide" was a data structure interpreted at run time).

;; The AST representation is designed to coincide with the run-time
;; support, so compilation is just (datum->syntax #'here guide). The
;; variants listed below are the ones recognized and treated specially
;; by other functions (eg optimize-resyntax, relocate-guide).

;; A Guide (G) is one of:
;; - (list 't-resyntax Expr Expr G)
;; - (list 't-quote Datum)    ;; constant, but not null
;; - (list 't-quote-syntax Syntax)
;; - (list 't-var Id)         ;; trusted pattern variable
;; - (list 't-list G ...)
;; - (list 't-list* G ... G)
;; - (list 't-append HG G)
;; - (list 't-orelse G G)
;; - (list 't-subst Expr Expr '({Subst} ...) Expr ...) ;; apply susbstitutions
;;   -- where Subst = Nat           ;; replace nth car with arg
;;                  | 'tail Nat     ;; replace nth cdr with arg
;;                  | 'append Nat   ;; replace nth car by appending arg
;;                  | 'recur Nat    ;; replace nth car by recurring on it with arg
;; - other expression (must be pair!)

;; A HeadGuide (HG) is one of:
;; - (list 'h-t G)
;; - other expression (must be pair!)

(begin-for-syntax

  (define here-stx (quote-syntax here))

  (define template-logger (make-logger 'template (current-logger)))

  ;; An Attribute is an identifier statically bound to a syntax-mapping
  ;; (see sc.rkt) whose valvar is an identifier statically bound to an
  ;; attribute-mapping.

  ;; (struct attribute-mapping (var name depth check) ...)
  ;; check : #f (trusted) or Id, ref to Checker
  ;; Checker = ( Any d:Nat b:Boolean Syntax/#f -> (Listof^d (if b Syntax Any)) )
  (define-values (struct:attribute-mapping attribute-mapping attribute-mapping?
                                           attribute-mapping-ref _attribute-mapping-set!)
    (make-struct-type 'attribute-mapping #f 4 0 #f null (current-inspector)
                      (lambda (self stx)
                        (if (attribute-mapping-check self)
                            (let ([source-name
                                   (or (let loop ([p (syntax-property stx 'disappeared-use)])
                                         (cond [(identifier? p) p]
                                               [(pair? p) (or (loop (car p)) (loop (cdr p)))]
                                               [else #f]))
                                       (attribute-mapping-name self))])
                              (define code
                                `(,(attribute-mapping-check self)
                                  ,(attribute-mapping-var self)
                                  ,(attribute-mapping-depth self)
                                  #t
                                  (quote-syntax ,source-name)))
                              (datum->syntax here-stx code stx))
                            (attribute-mapping-var self)))))
  (define (attribute-mapping-var a) (attribute-mapping-ref a 0))
  (define (attribute-mapping-name a) (attribute-mapping-ref a 1))
  (define (attribute-mapping-depth a) (attribute-mapping-ref a 2))
  (define (attribute-mapping-check a) (attribute-mapping-ref a 3))

  (define (guide-is? x tag) (and (pair? x) (eq? (car x) tag)))

  (define (ht-guide? x) (guide-is? x 'h-t))
  (define (ht-guide-t x) (cadr x))

  (define (quote-guide? x) (guide-is? x 't-quote))
  (define (quote-guide-v x) (cadr x))
  (define (quote-syntax-guide? x) (guide-is? x 't-quote-syntax))
  (define (quote-syntax-guide-v x) (cadr x))

  (define (null-guide? x) (and (guide-is? x 't-list) (null? (cdr x))))

  (define (datum-guide? x) (or (quote-guide? x) (null-guide? x)))
  (define (datum-guide-v x) (if (null-guide? x) null (quote-guide-v x)))

  (define (list-guide? x) (guide-is? x 't-list))
  (define (list-guide-vs x) (cdr x))

  (define (list*-guide? x) (guide-is? x 't-list*))
  (define (list*-guide-vs x) (cdr x))

  (define (struct-guide? x) (guide-is? x 't-struct))
  (define (struct-guide-key x) (cadr (cadr x)))
  (define (struct-guide-v x) (caddr x))

  (define (vector-guide? x) (guide-is? x 't-vector))
  (define (vector-guide-v x) (cadr x))

  (define (box-guide? x) (guide-is? x 't-box))
  (define (box-guide-v x) (cadr x))

  (define (append-guide gh gt)
    (cond [(ht-guide? gh) (cons-guide (ht-guide-t gh) gt)]
          [(null-guide? gt) gh]
          [else `(t-append ,gh ,gt)]))

  (define (cons-guide g1 g2)
    (cond [(and (datum-guide? g1) (datum-guide? g2))
           `(t-quote ,(cons (datum-guide-v g1) (datum-guide-v g2)))]
          [(list-guide? g2) (list* 't-list g1 (list-guide-vs g2))]
          [(list*-guide? g2) (list* 't-list* g1 (list*-guide-vs g2))]
          [else (list 't-list* g1 g2)]))

  (define (const-stx-guide? x)
    (cond [(quote-guide? x) #t]
          [(quote-syntax-guide? x) #t]
          [(list-guide? x) (andmap const-stx-guide? (list-guide-vs x))]
          [(list*-guide? x) (andmap const-stx-guide? (list*-guide-vs x))]
          [(struct-guide? x) (const-stx-guide? (struct-guide-v x))]
          [(vector-guide? x) (const-stx-guide? (vector-guide-v x))]
          [(box-guide? x) (const-stx-guide? (box-guide-v x))]
          [else #f]))
  (define (const-stx-guide-v x)
    (cond [(quote-guide? x) (quote-guide-v x)]
          [(quote-syntax-guide? x) (quote-syntax-guide-v x)]
          [(list-guide? x) (map const-stx-guide-v (list-guide-vs x))]
          [(list*-guide? x) (apply list* (map const-stx-guide-v (list*-guide-vs x)))]
          [(struct-guide? x)
           (apply make-prefab-struct (struct-guide-key x) (const-stx-guide-v (struct-guide-v x)))]
          [(vector-guide? x) (list->vector (const-stx-guide-v (vector-guide-v x)))]
          [(box-guide? x) (box (const-stx-guide-v (box-guide-v x)))]
          [else (error 'const-stx-guide-v "bad guide: ~e" x)]))

  (define (dots-guide hguide frame head at-stx)
    (let ([cons? (ht-guide? hguide)]
          [hguide (if (ht-guide? hguide) (ht-guide-t hguide) hguide)]
          [env (dotsframe-env frame)])
      (cond [(and (guide-is? hguide 't-var) (= (length env) 1)
                  (eq? (cadr hguide) (caar env)))
             ;; (x ...), where x is trusted
             (cond [cons? `(t-var ,(cdar env))]
                   [else `(apply append (t-var ,(cdar env)))])]
            [else
             `(t-dots ,cons? ,hguide ,(map car env) ,(map cdr env)
                      (quote ,head) (quote-syntax ,at-stx))])))

  ;; A Depth is (Listof MapFrame)

  ;; A DotsFrame is (vector (Listof (cons Id Syntax)) (Hash Id => Id) Id Bool)
  ;; Each ellipsis in a template has a corresponding DotsFrame of the form
  ;; (vector env ht ellipsis-id any-vars?), where
  ;; -- env is (list (cons iter-id src-list-expr) ...), where src-list-expr
  ;;    is a src-list-id either by itself or wrapped in a check
  ;; -- ht maps a src-list-id to the corresponding iter-id
  ;; -- ellipsis-id is the identifier for the ellipsis (for error reporting)
  ;; -- any-vars? is a flag that indicates whether any pattern variables occur
  ;;    in this frame's subtemplate (for error reporting)
  ;; When a pattern variable of depth D is found, it is added to the D current
  ;; innermost (ie, topmost) dotsframes (see `lookup`).
  (define (new-dotsframe ellipsis-stx)
    (vector null (make-hasheq) ellipsis-stx #f))
  (define (dotsframe-env frame) (vector-ref frame 0))
  (define (dotsframe-ref frame src-id)
    (hash-ref (vector-ref frame 1) src-id #f))
  (define (dotsframe-add! frame iter-id src-id src-expr)
    (vector-set! frame 0 (cons (cons iter-id src-expr) (vector-ref frame 0)))
    (hash-set! (vector-ref frame 1) src-id iter-id))
  (define (dotsframe-index-iter frame) (vector-ref frame 2))
  (define (dotsframe-index-iter! frame)
    (cond [(vector-ref frame 2) => (lambda (x) x)]
          [else (let ([index-var (gentemp)])
                  (vector-set! frame 2 index-var)
                  index-var)]))
  (define (dotsframe-ellipsis-id frame) (vector-ref frame 2))
  (define (dotsframe-has-mapvars? frame) (pair? (vector-ref frame 0)))
  (define (dotsframe-has-any-vars? frame) (vector-ref frame 3))

  (define (frames-seen-pvar! frames)
    (when (pair? frames)
      (unless (vector-ref (car frames) 3)
        (vector-set! (car frames) 3 #t)
        (frames-seen-pvar! (cdr frames)))))

  (define (ellipsis? x)
    (and (identifier? x) (free-identifier=? x (quote-syntax ...))))

  ;; ----------------------------------------
  ;; Parsing templates

  ;; parse-template : Syntax Syntax Boolean -> (values Guide (Listof Id))
  (define (parse-template ctx t stx?)
    ;; wrong-syntax : Syntax Format-String Any ... -> (error)
    (define (wrong-syntax x fmt . args) (raise-syntax-error #f (apply format fmt args) ctx x))

    ;; disappeared-uses : (Listof Id)
    (define disappeared-uses null)
    ;; disappeared! : Id -> Void
    (define (disappeared! id) (set! disappeared-uses (cons id disappeared-uses)))

    ;; parse-t : Stx Nat Boolean -> Guide
    (define (parse-t t depth esc?)
      (cond [(stx-pair? t)
             (if (identifier? (stx-car t))
                 (parse-t-pair/command t depth esc?)
                 (parse-t-pair/dots t depth esc?))]
            [else (parse-t-nonpair t depth esc?)]))

    ;; parse-t-pair/command : Stx Nat Boolean -> ...
    ;; t is a stxpair w/ id in car; check if it is a "command" (metafun, escape, etc)
    (define (parse-t-pair/command t depth esc?)
      (cond [esc?
             (parse-t-pair/dots t depth esc?)]
            [(parse-form t (quote-syntax ...) 1)
             => (lambda (t)
                  (disappeared! (car t))
                  (parse-t (cadr t) depth #t))]
            [(parse-form t (quote-syntax ~?) 2)
             => (lambda (t)
                  (disappeared! (car t))
                  (define t1 (cadr t))
                  (define t2 (caddr t))
                  (define guide1 (parse-t t1 depth esc?))
                  (define guide2 (parse-t t2 depth esc?))
                  `(t-orelse ,guide1 ,guide2))]
            [(lookup-metafun (stx-car t))
             => (lambda (mf)
                  (unless stx? (wrong-syntax (stx-car t) "metafunctions are not supported"))
                  (disappeared! (stx-car t))
                  (define guide (parse-t (stx-cdr t) depth esc?))
                  `(t-metafun ,(template-metafunction-accessor mf) ,guide
                              (quote-syntax
                               ,(let ([tstx (and (syntax? t) t)])
                                  (datum->syntax tstx (cons (stx-car t) #f) tstx tstx)))))]
            [else (parse-t-pair/dots t depth esc?)]))

    ;; parse-t-pair/dots : Stx Nat Boolean -> ...
    ;; t is a stx pair; check for dots
    (define (parse-t-pair/dots t depth esc?)
      (define head (stx-car t))
      (define-values (tail frames) ;; first-in-stx = innermost is first in list
        (let loop ([tail (stx-cdr t)] [frames null])
          (cond [(and (not esc?) (stx-pair? tail) (ellipsis? (stx-car tail)))
                 (disappeared! (stx-car tail))
                 (loop (stx-cdr tail) (cons (new-dotsframe (stx-car tail)) frames))]
                [else (values tail (reverse frames))])))
      (define at-stx (datum->syntax #f '... head))
      (define hguide
        (let loop ([frames frames] [hguide (parse-h head (append frames depth) esc?)])
          (cond [(pair? frames)
                 (define frame (car frames))
                 (unless (dotsframe-has-mapvars? frame)
                   (unless (dotsframe-has-any-vars? frame)
                     (wrong-syntax head "no pattern variables before ellipsis in template"))
                   (wrong-syntax (dotsframe-ellipsis-id frame) "too many ellipses in template"))
                 (loop (cdr frames) (dots-guide hguide frame head at-stx))]
                [else hguide])))
      (define tguide (parse-t tail depth esc?))
      (resyntax t (append-guide hguide tguide)))

    ;; parse-t-nonpair : Syntax Nat Boolean -> ...
    ;; PRE: t is not a stxpair
    (define (parse-t-nonpair t depth esc?)
      (define td (if (syntax? t) (syntax-e t) t))
      (cond [(identifier? t)
             (cond [(and (not esc?)
                         (or (free-identifier=? t (quote-syntax ...))
                             (free-identifier=? t (quote-syntax ~?))
                             (free-identifier=? t (quote-syntax ~@))))
                    (wrong-syntax t "illegal use")]
                   [(lookup-metafun t)
                    (wrong-syntax t "illegal use of syntax metafunction")]
                   [(lookup t depth) => (lambda (ref) ref)]
                   [else (const-guide t)])]
            [(vector? td)
             (define guide (parse-t (vector->list td) depth esc?))
             (resyntax t `(t-vector ,guide))]
            [(prefab-struct-key td)
             => (lambda (key)
                  (define elems (cdr (vector->list (struct->vector td))))
                  (define guide (parse-t elems depth esc?))
                  (resyntax t `(t-struct (quote ,key) ,guide)))]
            [(box? td)
             (define guide (parse-t (unbox td) depth esc?))
             (resyntax t `(t-box ,guide))]
            [else (const-guide t)]))

    ;; parse-h : Syntax Depth Boolean -> HeadGuide
    (define (parse-h h depth esc?)
      (cond [(and (not esc?) (parse-form h (quote-syntax ~?) 1))
             => (lambda (h)
                  (disappeared! (car h))
                  (define guide (parse-h (cadr h) depth esc?))
                  `(h-orelse ,guide null))]
            [(and (not esc?) (parse-form h (quote-syntax ~?) 2))
             => (lambda (h)
                  (disappeared! (car h))
                  (define guide1 (parse-h (cadr h) depth esc?))
                  (define guide2 (parse-h (caddr h) depth esc?))
                  (if (and (ht-guide? guide1) (ht-guide? guide2))
                      `(h-t (t-orelse ,(ht-guide-t guide1) ,(ht-guide-t guide2)))
                      `(h-orelse ,guide1 ,guide2)))]
            [(and (stx-pair? h)
                  (let ([h-head (stx-car h)])
                    (and (identifier? h-head)
                         (or (and (free-identifier=? h-head (quote-syntax ~@)) (not esc?))
                             (free-identifier=? h-head (quote-syntax ~@!))))))
             (disappeared! (stx-car h))
             (define guide (parse-t (stx-cdr h) depth esc?))
             `(h-splice ,guide (quote ,h) (quote-syntax ,(stx-car h)))]
            [else
             (define guide (parse-t h depth esc?))
             `(h-t ,guide)]))

    ;; lookup : Identifier Depth -> Syntax/#f
    ;; If pattern variable with depth>0, insert into depth innermost ellipsis envs.
    (define (lookup id depth0)
      (define (make-pvar var check pvar-depth)
        (define (make-ref var)
          (cond [check `(t-check-var (,check ,var 0 ,stx? (quote-syntax ,id)))]
                [else `(t-var ,var)]))
        (define (make-src-ref var id)
          (cond [check `(#%expression (,check ,var 1 #f (quote-syntax ,id)))]
                [else var]))
        (disappeared! id)
        (frames-seen-pvar! depth0)
        (make-ref
         (let dloop ([depth depth0] [pvar-depth pvar-depth]) ;; ... -> Identifier
           ;; Returns variable reference whose value has not been checked yet.
           (cond [(zero? pvar-depth) var]
                 [(null? depth)
                  (if (null? depth0)
                      (wrong-syntax id "missing ellipsis with pattern variable in template")
                      (wrong-syntax id "too few ellipses for pattern variable in template"))]
                 [else
                  (define src (dloop (cdr depth) (sub1 pvar-depth)))
                  (or (dotsframe-ref (car depth) src)
                      (let ([iter (gentemp)])
                        (dotsframe-add! (car depth) iter src (make-src-ref src id))
                        iter))]))))
      (let ([v (syntax-local-value id (lambda () #f))])
        (cond [(syntax-pattern-variable? v)
               ;; syntax variables allowed in both syntax and datum templates
               (define pvar-depth (syntax-mapping-depth v))
               (define attr
                 (let ([attr (syntax-local-value (syntax-mapping-valvar v) (lambda () #f))])
                   (and (attribute-mapping? attr) attr)))
               (define var (if attr (attribute-mapping-var attr) (syntax-mapping-valvar v)))
               (define check (and attr (attribute-mapping-check attr)))
               (make-pvar var check pvar-depth)]
              [(s-exp-pattern-variable? v)
               (cond [stx?
                      ;; datum variable in syntax template is error
                      (wrong-syntax id "datum variable not allowed in syntax template")]
                     [else
                      ;; datum variable in datum template
                      (define pvar-depth (s-exp-mapping-depth v))
                      (define var (s-exp-mapping-valvar v))
                      (make-pvar var #f pvar-depth)])]
              [else
               ;; id is a constant; check that for all x s.t. id = x.y, x is not an attribute
               (for-each
                (lambda (pfx)
                  (let ([pfx-v (syntax-local-value pfx (lambda () #f))])
                    (if (and (syntax-pattern-variable? pfx-v)
                             (let ([valvar (syntax-mapping-valvar pfx-v)])
                               (attribute-mapping? (syntax-local-value valvar (lambda () #f)))))
                        (wrong-syntax id "undefined nested attribute of attribute `~a'"
                                      (syntax-e pfx))
                        (void))))
                (dotted-prefixes id))
               #f])))

    ;; resyntax : Stx Guide -> Guide
    (define (resyntax t g)
      (cond [(not (and stx? (syntax? t))) g]
            [(const-stx-guide? g)
             `(t-quote-syntax ,(datum->syntax t (const-stx-guide-v g) t t))]
            [#t (optimize-resyntax t g)]
            [else `(t-resyntax #f (quote-syntax ,(datum->syntax t 'STX t t)) ,g)]))

    ;; optimize-resyntax : Syntax Guide -> Guide
    (define (optimize-resyntax t0 g)
      (define HOLE (datum->syntax #f '_))
      (define (finish i rt rs re)
        (values (sub1 i) (reverse rs) (reverse re)
                (datum->syntax t0 (apply list* (reverse rt)) t0 t0)))
      (define (loop-gs list*? gs i rt rs re)
        (cond [(null? gs)
               (finish i (cons null rt) rs re)]
              [(and list*? (null? (cdr gs)))
               (loop-g (car gs) i rt rs re)]
              [else
               (define g0 (car gs))
               (cond [(quote-syntax-guide? g0)
                      (let ([const (quote-syntax-guide-v g0)])
                        (loop-gs list*? (cdr gs) (add1 i) (cons const rt) rs re))]
                     [(eq? (car g0) 't-subst) ;; (t-subst LOC STX <substs>)
                      (let ([subt (cadr (list-ref g0 2))] ;; extract from (quote-syntax _)
                            [subargs (list-tail g0 3)])
                        (loop-gs list*? (cdr gs) (add1 i) (cons subt rt)
                                 (list* i 'recur rs) (cons `(list . ,subargs) re)))]
                     [else (loop-gs list*? (cdr gs) (add1 i) (cons HOLE rt)
                                    (cons i rs) (cons g0 re))])]))
      (define (loop-g g i rt rs re)
        (cond [(list-guide? g)
               (loop-gs #f (list-guide-vs g) i rt rs re)]
              [(list*-guide? g)
               (loop-gs #t (list*-guide-vs g) i rt rs re)]
              [(guide-is? g 't-append)
               (loop-g (caddr g) (add1 i) (cons HOLE rt)
                       (list* i 'append rs) (cons (cadr g) re))]
              [(eq? (car g) 't-quote-syntax)
               (let ([const (quote-syntax-guide-v g)])
                 (finish i (cons const rt) rs re))]
              [else (finish i (cons HOLE rt) (list* i 'tail rs) (cons g re))]))
      (define-values (npairs substs exprs t*) (loop-g g 0 null null null))
      (cond [(and substs
                  ;; Tunable condition for choosing whether to create a t-subst.
                  ;; Avoid creating useless (t-subst loc stx '(tail 0) g).
                  (<= (length substs) (* 2 npairs)))
             #;(log-message template-logger 'debug
                            (format "OPTIMIZED ~s" (syntax->datum t0)) #f)
             `(t-subst #f (quote-syntax ,t*) (quote ,substs) . ,exprs)]
            [else
             #;(log-message template-logger 'debug
                            (format "NOT opt   ~s" (syntax->datum t0)) #f)
             (let ([rep (datum->syntax t0 'STX t0 t0)])
               `(t-resyntax #f (quote-syntax ,rep) ,g))]))

    ;; const-guide : Any -> Guide
    (define (const-guide x)
      (cond [(and stx? (syntax? x)) `(t-quote-syntax ,x)]
            [(null? x) `(t-list)]
            [else `(t-quote , x)]))

    (let ([guide (parse-t t null #f)])
      (values guide disappeared-uses)))

  ;; parse-form : Stx Id Nat -> (list[arity+1] Syntax)
  (define (parse-form stx form-id arity)
    (and (stx-pair? stx)
         (let ([stx-h (stx-car stx)] [stx-t (stx-cdr stx)])
           (and (identifier? stx-h) (free-identifier=? stx-h form-id)
                (let ([stx-tl (stx->list stx-t)])
                  (and (list? stx-tl)
                       (= (length stx-tl) arity)
                       (cons stx-h stx-tl)))))))

  ;; lookup-metafun : Identifier -> Metafunction/#f
  (define (lookup-metafun id)
    (define v (syntax-local-value id (lambda () #f)))
    (and (template-metafunction? v) v))

  (define (dotted-prefixes id)
    (let* ([id-string (symbol->string (syntax-e id))]
           [dot-locations
            (let loop ([i 0])
              (if (< i (string-length id-string))
                  (if (eqv? (string-ref id-string i) #\.)
                      (cons i (loop (add1 i)))
                      (loop (add1 i)))
                  null))])
      (map (lambda (loc) (datum->syntax id (string->symbol (substring id-string 0 loc))))
           dot-locations)))

  (define gentemp-counter 0)
  (define (gentemp)
    (set! gentemp-counter (add1 gentemp-counter))
    ((make-syntax-introducer)
     (datum->syntax #f (string->symbol (format "pv_~s" gentemp-counter)))))

  (define (stx-drop n x)
    (if (zero? n) x (stx-drop (sub1 n) (stx-cdr x))))

  ;; ----------------------------------------
  ;; Relocating (eg, syntax/loc)

  ;; Only relocate if relocation would affect a syntax pair originating
  ;; from template structure. For example (x,y are pvars):
  ;;   (syntax/loc loc-stx (1 2 3))    => relocate
  ;;   (syntax/loc loc-stx y)          => don't relocate
  ;;   (syntax/loc loc-stx (x ... . y) => relocate iff at least one x!
  ;; Deciding whether to relocate after the fact is hard. But with explicit
  ;; t-resyntax, it's much easier.

  ;; relocate-guide : Syntax Guide Id -> Guide
  (define (relocate-guide ctx g0 loc-id)
    (define (loop g)
      (define gtag (car g))
      (cond [(guide-is? g 't-resyntax)
             `(t-resyntax ,loc-id . ,(cddr g))]
            [(quote-syntax-guide? g)
             `(t-relocate ,g ,loc-id)]
            [(guide-is? g 't-subst)
             `(t-subst ,loc-id . ,(cddr g))]
            ;; ----
            [(guide-is? g 't-orelse)
             `(t-orelse ,(loop (cadr g)) ,(loop (caddr g)))]
            ;; ----
            ;; Nothing else should be relocated
            [else g]))
    (loop g0))

  ;; ----------------------------------------

  ;; do-template : Syntax Syntax Id/#f Boolean -> Syntax
  (define (do-template ctx tstx loc-id stx?)
    (define-values (pre-guide disappeared-uses)
      (parse-template ctx tstx stx?))
    (define guide (if loc-id (relocate-guide ctx pre-guide loc-id) pre-guide))
    (define code (syntax-arm (datum->syntax here-stx guide ctx)))
    (syntax-property code 'disappeared-use (map syntax-local-introduce disappeared-uses)))
  )

(define-syntax (syntax stx)
  (define s (syntax->list stx))
  (if (and (list? s) (= (length s) 2))
      (do-template stx (cadr s) #f #t)
      (raise-syntax-error #f "bad syntax" stx)))

(define-syntax (syntax/loc stx)
  (define s (syntax->list stx))
  (if (and (list? s) (= (length s) 3))
      (let ([loc-id (quote-syntax loc)])
        (define code
          `(let ([,loc-id (check-loc (quote ,(car s)) ,(cadr s))])
             ,(do-template stx (caddr s) loc-id #t)))
        (syntax-arm (datum->syntax here-stx code stx)))
      (raise-syntax-error #f "bad syntax" stx)))

(define-syntax (datum stx)
  (define s (syntax->list stx))
  (if (and (list? s) (= (length s) 2))
      (do-template stx (cadr s) #f #f)
      (raise-syntax-error #f "bad syntax" stx)))

(define (check-option pred x)
  (if x (pred x) #t))

;; check-loc : Symbol Any -> (U Syntax
;;                              (List Any (Option Pos) (Option Nonneg) (Option Pos) (Option Nonneg))
;;                              (Vector Any (Option Pos) (Option Nonneg) (Option Pos) (Option Nonneg))
;;                              Srcloc
;;                              #f)
;; Raise exn if not srcloc-like value. Returns same syntax if suitable for srcloc
;; (ie, if at least syntax-source or syntax-position set), #f otherwise.

(define (check-loc who x)
  (cond
    [(not x) x]
    [(srcloc? x) (if (or (srcloc-source x) (srcloc-position x))
                     x
                     #f)]
    [(syntax? x) (check-loc who (syntax-srcloc x))]
    [(and (list? x)
          (= (length x) 5)
          (check-option exact-positive-integer? (list-ref x 1))
          (check-option exact-nonnegative-integer? (list-ref x 2))
          (check-option exact-positive-integer? (list-ref x 3))
          (check-option exact-nonnegative-integer? (list-ref x 4)))
     (check-loc who (srcloc (list-ref x 0)
                            (list-ref x 1)
                            (list-ref x 2)
                            (list-ref x 3)
                            (list-ref x 4)))]
    [(and (vector? x)
          (= (vector-length x) 5)
          (check-option exact-positive-integer? (vector-ref x 1))
          (check-option exact-nonnegative-integer? (vector-ref x 2))
          (check-option exact-positive-integer? (vector-ref x 3))
          (check-option exact-nonnegative-integer? (vector-ref x 4)))
     (check-loc who (srcloc (vector-ref x 0)
                            (vector-ref x 1)
                            (vector-ref x 2)
                            (vector-ref x 3)
                            (vector-ref x 4)))]
    [else
     (raise-argument-error
      who
      (string-append "(or/c #f srcloc? syntax?\n"
                     "      (list/c any/c\n"
                     "              (or/c exact-positive-integer? #f)\n"
                     "              (or/c exact-nonnegative-integer? #f)\n"
                     "              (or/c exact-positive-integer? #f)\n"
                     "              (or/c exact-nonnegative-integer? #f))\n"
                     "      (vector/c any/c\n"
                     "                (or/c exact-positive-integer? #f)\n"
                     "                (or/c exact-nonnegative-integer? #f)\n"
                     "                (or/c exact-positive-integer? #f)\n"
                     "                (or/c exact-nonnegative-integer? #f)))")
      x)]))

;; ============================================================
;; Run-time support

;; (t-dots cons? hguide iter-vars src-vars head-datum at-stx) : Expr[(Listof Syntax)]
(define-syntax (t-dots stx)
  (define s (syntax->list stx))
  (define cons? (syntax-e (list-ref s 1)))
  (define head (list-ref s 2))
  (define iter-vars (syntax->list (list-ref s 3)))
  (define src-exprs (syntax->list (list-ref s 4)))
  (define in-stx (list-ref s 5))
  (define at-stx (list-ref s 6))
  (define code
    `(let ,(map list iter-vars src-exprs)
       ,(if (> (length iter-vars) 1) `(check-same-length ,in-stx ,at-stx . ,iter-vars) '(void))
       ,(if cons?
            `(map (lambda ,iter-vars ,head) . ,iter-vars)
            `(apply append (map (lambda ,iter-vars ,head) . ,iter-vars)))))
  (datum->syntax here-stx code stx))

(define-syntaxes (t-orelse h-orelse)
  (let ()
    (define (orelse-transformer stx)
      (define s (syntax->list stx))
      (datum->syntax here-stx
                     `(t-orelse* (lambda () ,(cadr s)) (lambda () ,(caddr s)))))
    (values orelse-transformer orelse-transformer)))

(#%require (rename '#%kernel t-quote    quote)
           (rename '#%kernel t-quote-syntax quote-syntax)
           (rename '#%kernel t-var      #%expression)
           (rename '#%kernel t-check-var #%expression)
           ;; (rename '#%kernel t-append   append)
           (rename '#%kernel t-list     list)
           (rename '#%kernel t-list*    list*)
           (rename '#%kernel t-escaped  #%expression)
           (rename '#%kernel t-vector   list->vector)
           (rename '#%kernel t-box      box-immutable)
           (rename '#%kernel h-t        list))

(begin-encourage-inline

(define (t-append xs ys) (if (null? ys) xs (append xs ys)))
(define (t-resyntax loc stx g) (datum->syntax stx g (or loc stx) stx))
(define (t-relocate g loc) (datum->syntax g (syntax-e g) (or loc g) g))
(define (t-orelse* g1 g2)
  ((let/ec escape
     (with-continuation-mark
       absent-pvar-escape-key
       (lambda () (escape g2))
       (let ([v (g1)]) (lambda () v))))))
(define (t-struct key g) (apply make-prefab-struct key g))
(define (t-metafun mf g stx)
  (mf (datum->syntax stx (cons (stx-car stx) g) stx stx)))
(define (h-splice g in-stx at-stx)
  (if (stx-list? g) (stx->list g) (error/splice g in-stx at-stx)))

#| end begin-encourage-inline |#)

;; t-subst : Syntax/#f Syntax Substs Any ... -> Syntax
;; where Substs = '() | (cons Nat Substs) | (list* (U 'tail 'append 'recur) Nat Substs)
;; There is one arg for each index in substs. See also defn of Guide above.
(define (t-subst loc stx substs . args)
  (define (loop/mode s i mode seek substs args)
    (cond [(< i seek) (cons (car s) (loop/mode (cdr s) (add1 i) mode seek substs args))]
          [(eq? mode #f) (cons (car args) (loop (cdr s) (add1 i) substs (cdr args)))]
          [(eq? mode 'tail) (car args)]
          [(eq? mode 'append) (append (car args) (loop (cdr s) (add1 i) substs (cdr args)))]
          [(eq? mode 'recur) (cons (apply t-subst #f (car s) (car args))
                                   (loop (cdr s) (add1 i) substs (cdr args)))]))
  (define (loop s i substs args)
    (cond [(null? substs) s]
          [(symbol? (car substs))
           (loop/mode s i (car substs) (cadr substs) (cddr substs) args)]
          [else (loop/mode s i #f (car substs) (cdr substs) args)]))
  (define v (loop (syntax-e stx) 0 substs args))
  (datum->syntax stx v (or loc stx) stx))

(define absent-pvar-escape-key (gensym 'absent-pvar-escape))

;; signal-absent-pvar : -> escapes or #f
;; Note: Only escapes if in ~? form.
(define (signal-absent-pvar)
  (let ([escape (continuation-mark-set-first #f absent-pvar-escape-key)])
    (if escape (escape) #f)))

;; error/splice : Any Stx Stx -> (escapes)
(define (error/splice r in-stx at-stx)
  (raise-syntax-error 'syntax
    (format "splicing template did not produce a syntax list\n  got: ~e" r) in-stx at-stx))

;; check-same-length : Stx Stx List ... -> Void
(define check-same-length
  (case-lambda
    [(in at a) (void)]
    [(in at a b)
     (if (= (length a) (length b))
         (void)
         (raise-syntax-error 'syntax "incompatible ellipsis match counts for template"
                             (list in '...) at))]
    [(in at a . bs)
     (define alen (length a))
     (for-each (lambda (b)
                 (if (= alen (length b))
                     (void)
                     (raise-syntax-error 'syntax "incompatible ellipsis match counts for template"
                                         (list in '...) at)))
               bs)]))

)
