(module require-transform '#%kernel
  (#%require "private/stxcase-scheme.rkt"
             "private/stx.rkt"
             "private/define-struct.rkt"
             "private/define-et-al.rkt"
             "private/qq-and-or.rkt"
             "private/cond.rkt"
             "private/define.rkt"
             "private/require-lift.rkt"
             "phase+space.rkt"
             (for-template (only '#%kernel quote))
             (for-syntax '#%kernel))
  
  (#%provide expand-import
             syntax-local-lift-require-top-level-form
             current-require-module-path convert-relative-module-path
             syntax-local-require-certifier
             make-require-transformer prop:require-transformer require-transformer?
             ;; the import struct type:
             import struct:import make-import import?
             import-local-id import-src-sym import-src-mod-path import-orig-stx import-mode import-req-mode import-orig-mode
             ;; the import-source struct type:
             import-source struct:import-source make-import-source import-source?
             import-source-mod-path-stx import-source-mode)

  (define-struct* import (local-id src-sym src-mod-path mode req-mode orig-mode orig-stx)
    #:guard (lambda (i s path mode req-mode orig-mode stx info)
              (unless (identifier? i)
                (raise-argument-error 'make-import "identifier?" i))
              (unless (symbol? s)
                (raise-argument-error 'make-import "symbol?" s))
              (unless (or (module-path? path)
                          (and (syntax? path)
                               (module-path? (syntax->datum path))))
                (raise-argument-error 'make-import "(or/c module-path? module-path-syntax?)" path))
              (unless (phase+space? mode)
                (raise-argument-error 'make-import "phase+space?" mode))
              (unless (phase+space-shift? req-mode)
                (raise-argument-error 'make-import "phase+space-shift?" req-mode))
              (unless (phase+space? orig-mode)
                (raise-argument-error 'make-import "phase+space?" orig-mode))
              (unless (equal? mode (phase+space+ orig-mode req-mode))
                (raise-arguments-error 'make-import
                                       "original mode and require mode not consistent with mode" 
                                       "original mode" orig-mode 
                                       "require mode" req-mode
                                       "mode" mode))
              (unless (syntax? stx)
                (raise-argument-error 'make-import "syntax?" stx))
              (values i s path mode req-mode orig-mode stx)))
              
  (define-struct* import-source (mod-path-stx mode)
    #:guard (lambda (path mode info)
              (unless (and (syntax? path)
                           (module-path? (syntax->datum path)))
                (raise-argument-error 'make-import-source "(and/c syntax? (lambda (s) (module-path? (syntax->datum s))))" path))
              (unless (phase+space-shift? mode)
                (raise-argument-error 'make-import-source "phase+space-shift?" mode))
              (values path mode)))
    
  (define-values (prop:require-transformer require-transformer? require-transformer-get-proc)
    (make-struct-type-property 'require-transformer))
  
  (define (raise-out-of-require-error ignored stx)
    (raise-syntax-error #f "illegal placement for `require-spec`;\n valid positions include the argument to `require`" stx))

  (define-struct* rt (proc)
    #:property prop:procedure raise-out-of-require-error
    #:property prop:require-transformer (lambda (t) (rt-proc t)))
  
  (define (make-require-transformer proc)
    (make-rt proc))

  ;; For backward compatibility:
  (define (syntax-local-require-certifier)
    (case-lambda 
     [(v) v]
     [(v mark) v]))

  (define orig-insp (variable-reference->module-declaration-inspector
                     (#%variable-reference)))

  (define current-require-module-path 
    (make-parameter #f
                    (lambda (v)
                      (unless (or (not v)
                                  (module-path-index? v))
                        (raise-argument-error 'current-require-module-path 
                                              "(or/c module-path-index? #f)"
                                              v))
                      v)
                    'current-require-module-path))

  ;; a simplified version of `collapse-module-path-index', where
  ;; we don't have to normalize:
  (define (collapse-mpi mpi)
    (define-values (a b) (module-path-index-split mpi))
    (define (recur b)
      (cond
       [(not b) (collapse-mpi (module-path-index-join #f #f))]
       [(resolved-module-path? b)
        (let ([n (resolved-module-path-name b)])
          (if (pair? n)
              (cons 'submod n)
              n))]
       [else (collapse-mpi b)]))
    (define (extract-root bc)
      (if (and (pair? bc) (eq? 'submod (car bc)))
          (cadr bc)
          bc))
    (define (replace-last s a)
      ;; replace last path element, and also eliminate "." and "..":
      (regexp-replace* #rx"(?<=^|/)[.]/"
                       (regexp-replace* #rx"(?<=^|/)[-+_%a-zA-Z0-9]*/[.][.]/"
                                        (regexp-replace #rx"[^/]*$" s a)
                                        "")
                       ""))
    (define (string->path* s)
      ;; for now, module-path strings all works as paths
      (string->path s))
    (cond
     [(and (not a) (not b))
      (build-path (or (current-load-relative-directory)
                      (current-directory))
                  "here.rkt")]
     [(path? a) a]
     [(symbol? a) a]
     [(string? a)
      (define bc (extract-root (recur b)))
      (let loop ([bc bc])
        (cond
         [(path? bc)
          (define-values (base name dir?) (split-path bc))
          (if (eq? base 'relative)
              (string->path* a)
              (build-path base (string->path* a)))]
         [(symbol? bc)
          (loop `(lib ,(symbol->string bc)))]
         [(eq? (car bc) 'quote) 
          (build-path (or (current-load-relative-directory)
                          (current-directory))
                      (string->path* a))]
         [(eq? (car bc) 'file)
          (loop (string->path (cadr bc)))]
         [(eq? (car bc) 'lib)
          (cond
           [(and (null? (cddr bc))
                 (regexp-match? #rx"[/]" (cadr bc)))
            `(lib ,(replace-last (cadr bc) a))]
           [(and (null? (cddr bc))
                 (not (regexp-match? #rx"[/.]" (cadr bc))))
            (loop `(lib ,(string-append (cadr bc) "/main.rkt")))]
           [(and (null? (cddr bc))
                 (not (regexp-match? #rx"[/]" (cadr bc))))
            (loop `(lib ,(string-append "mzlib/" (cadr bc))))]
           [else
            (loop `(lib ,(apply
                          string-append 
                          (let loop ([l (cddr bc)])
                            (if (null? l)
                                (list (cadr bc))
                                (list* (car l) "/" (loop (cdr l))))))))])]
         [(eq? (car bc) 'planet)
          (cond
           [(symbol? (cadr bc))
            (loop `(planet ,(symbol->string (cadr bc))))]
           [(null? (cddr bc))
            (define s (cadr bc))
            (cond
             [(regexp-match? #rx"/.*/" s)
              `(planet ,(replace-last s a))]
             [else
              `(planet ,(string-append s "/" a))])]
           [else
            (define s (cadr bc))
            `(planet ,(if (regexp-match? #rx"/" s)
                          (replace-last s a)
                          a)
                     ,@(cddr bc))])]
         [else (error "collapse-mpi failed on recur shape: " bc)]))]
     [(eq? (car a) 'submod)
      (define (add bc l)
        (if (and (pair? bc) (eq? 'submod (car bc)))
            (append bc l)
            (list* 'submod bc l)))
      (cond
       [(equal? (cadr a) ".")
        (add (recur b) (cddr a))]
       [(equal? (cadr a) "..")
        (add (recur b) (cdr a))]
       [else
        (add (collapse-mpi (module-path-index-join (cadr a) b))
             (cddr a))])]
     [else a]))
  
  (define (convert-relative-module-path mp/stx)
    (define rmp (current-require-module-path))
    (cond
     [(not rmp) mp/stx]
     [else
      (define mp (if (syntax? mp/stx)
                     (syntax->datum mp/stx)
                     mp/stx))
      (define (d->s d)
        (if (syntax? mp/stx)
            (datum->syntax mp/stx d mp/stx mp/stx)
            d))
      (cond
       [(not (module-path? mp)) mp/stx]
       [(string? mp)
        ;; collapse a relative reference to an absolute one:
        (d->s (collapse-mpi (module-path-index-join mp rmp)))]
       [(symbol? mp) mp/stx]
       [(eq? (car mp) 'quote)
        ;; maybe a submodule...
        (define r (module-path-index-resolve rmp))
        (if (module-declared? (append '(submod)
                                      (if (list? r)
                                          r
                                          (list r))
                                      (cddr mp))
                              #t)
            ;; Yes, a submodule:
            (let ([rmp-mod (collapse-mpi rmp)])
              (if (and (pair? rmp-mod)
                       (eq? (car rmp-mod) 'submod))
                  (d->s (append rmp-mod (cadr mp)))
                  (d->s `(submod ,rmp-mod . ,(cddr mp)))))
            mp/stx)]
       [(eq? (car mp) 'file)
        (define base-path (resolved-module-path-name
                           (module-path-index-resolve rmp)))
        (define path (if (pair? base-path)
                         (car base-path)
                         base-path))
        (if (path? path) 
            (let-values ([(base name dir?) (split-path path)])
              (if (eq? base 'relative)
                  mp/stx
                  (d->s (build-path base (cadr mp)))))
            mp/stx)]
       [(eq? (car mp) 'submod)
        (define sub/stx (if (syntax? mp/stx)
                            (syntax-case mp/stx ()
                              [(_ sub . _) #'sub])
                            (cadr mp)))
        (define sub (if (syntax? sub/stx) (syntax->datum sub/stx) sub/stx))
        (define new-sub/stx
          (cond
           [(equal? sub ".") (d->s (collapse-mpi rmp))]
           [(equal? sub "..")
            (define old (collapse-mpi rmp))
            (if (and (pair? old)
                     (eq? (car old) 'submod))
                (d->s (append old (list "..")))
                sub/stx)]
           [else
            (convert-relative-module-path sub/stx)]))
        (cond
         [(eq? sub/stx new-sub/stx) mp/stx]
         [else
          (define new-sub (if (syntax? new-sub/stx)
                              (syntax->datum new-sub/stx)
                              new-sub/stx))
          (if (and (pair? new-sub)
                   (eq? (car new-sub) 'submod))
              (d->s (append new-sub (cddr mp)))
              (d->s `(submod ,new-sub/stx . ,(cddr mp))))])]
       [else mp/stx])]))

  ;; expand-import : stx bool -> (listof import)
  (define (expand-import stx)
    (let ([disarmed-stx (syntax-disarm stx orig-insp)])
      (syntax-case disarmed-stx ()
        [simple
         (or (identifier? #'simple)
             (string? (syntax-e #'simple))
             (syntax-case stx (quote)
               [(quote s) #t]
               [_ #f]))
         (let ([mod-path
                (if (pair? (syntax-e #'simple))
                    `(quote . ,(cdr (syntax->datum #'simple)))
                    (syntax->datum #'simple))])
           (unless (module-path? mod-path)
             (raise-syntax-error
              #f
              "invalid module-path form"
              stx))
           (let* ([mod-path (convert-relative-module-path mod-path)]
                  [namess (syntax-local-module-exports mod-path)])
             (values
              (apply
               append
               (map (lambda (names)
                      (let ([mode (car names)])
                        (map (lambda (name)
                               (make-import (datum->syntax
                                             stx
                                             name
                                             stx)
                                            name
                                            (if (equal? (syntax->datum #'simple) mod-path)
                                                #'simple
                                                mod-path)
                                            mode
                                            0
                                            mode
                                            stx))
                             (cdr names))))
                    namess))
              (list (make-import-source (if (equal? (syntax->datum #'simple) mod-path)
                                            #'simple
                                            (datum->syntax #'simple mod-path #'simple))
                                        0)))))]
        [(id . rest)
         (identifier? #'id)
         (let ([t (syntax-local-value #'id (lambda () #f))])
           (if (require-transformer? t)
               (call-with-values
                   (lambda ()
                     (((require-transformer-get-proc t) t) disarmed-stx))
                 (case-lambda
                  [(v mods)
                   (unless (and (list? v)
                                (andmap import? v))
                     (raise-syntax-error
                      #f
                      "first result from require transformer is not a list of imports"
                      stx))
                   (unless (and (list? mods)
                                (andmap import-source? mods))
                     (raise-syntax-error
                      #f
                      "second result from require transformer is not a list of import-sources"
                      stx))
                   (values v mods)]
                  [args
                   (raise-syntax-error
                    #f
                    (format "require transformer produced ~a result~a instead of 2"
                            (length args)
                            (if (= 1 (length args)) "" "s"))
                    stx)]))
               (raise-syntax-error
                #f
                "not a require sub-form"
                stx)))]
        [_
         (raise-syntax-error
          #f
          "bad syntax for require sub-form"
          stx)])))

  (define (syntax-local-lift-require-top-level-form exp)
    (unless (syntax? exp)
      (raise-argument-error 'syntax-local-lift-require-top-level-form
                            "syntax?"
                            exp))
    (define b (syntax-local-lift-require-definition-param))
    (unless b
      (error 'syntax-local-lift-require-definition
             "not currently expanding `require`"))
    (set-box! b (cons exp (unbox b)))))
