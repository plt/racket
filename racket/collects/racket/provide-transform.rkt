(module provide-transform '#%kernel
  (#%require "private/stxcase-scheme.rkt"
             "private/stx.rkt"
             "private/define-struct.rkt"
             "private/define-et-al.rkt"
             "private/qq-and-or.rkt"
             "private/cond.rkt"
             "private/define.rkt"
             "phase+space.rkt")
  
  (#%provide expand-export pre-expand-export 
             syntax-local-provide-certifier 
             make-provide-transformer prop:provide-transformer provide-transformer?
             make-provide-pre-transformer prop:provide-pre-transformer provide-pre-transformer?
             ;; the export struct type:
             export struct:export make-export export?
             export-local-id export-out-id export-out-sym export-orig-stx export-protect? export-mode)

  ;; Note on history:
  ;;
  ;; The old "out-sym" field was a symbol, making it awkward to
  ;; preserve srcloc for things like rename-out, or syntax properties
  ;; for things like prefix-out.
  ;;
  ;; Now the field is named "out-id", an identifier. For backward
  ;; compatibilty, make-export accepts a symbol, and the old accessor
  ;; export-out-sym is available as a normal function.
  (define-struct* export (local-id out-id mode protect? orig-stx)
    #:guard (lambda (i out mode protect? stx info)
              (unless (identifier? i)
                (raise-argument-error 'make-export "identifier?" i))
              (unless (phase+space? mode)
                (raise-argument-error 'make-export "phase+space?" mode))
              (unless (syntax? stx)
                (raise-argument-error 'make-export "syntax?" stx))
              (let ([out-id
                     (cond [(identifier? out) out]
                           [(symbol? out)
                            (if (equal? out (syntax->datum stx))
                                stx
                                (datum->syntax #f out stx))]
                           [else
                            (raise-argument-error 'make-export
                                                  "(or/c identifier? symbol?)"
                                                  out)])])
                (values i out-id mode (and protect? #t) stx))))

  (define (export-out-sym e)
    (syntax-e (export-out-id e)))

  (define (raise-out-of-provide-error ignored stx)
    (raise-syntax-error #f "illegal placement for `provide-spec`;\n valid positions include the argument to `provide`" stx))

  (define-values (prop:provide-pre-transformer provide-pre-transformer? provide-pre-transformer-get-proc)
    (make-struct-type-property 'provide-pre-transformer))
  
  (define-values (prop:provide-transformer provide-transformer? provide-transformer-get-proc)
    (make-struct-type-property 'provide-transformer))
  
  (define-struct* pt (proc)
    #:property prop:procedure raise-out-of-provide-error
    #:property prop:provide-transformer (lambda (t) (pt-proc t)))
  (define-struct* p+t (pre-proc proc)
    #:property prop:procedure raise-out-of-provide-error
    #:property prop:provide-transformer (lambda (t) (p+t-proc t))
    #:property prop:provide-pre-transformer (lambda (t) (p+t-pre-proc t)))
  
  (define make-provide-transformer
    (case-lambda
     [(proc)
      (make-pt proc)]
     [(proc pre-proc)
      (make-p+t pre-proc proc)]))
  
  (define-struct* ppt (proc)
    #:property prop:procedure raise-out-of-provide-error
    #:property prop:provide-pre-transformer (lambda (t) (ppt-proc t)))
  
  (define (make-provide-pre-transformer proc)
    (make-ppt proc))
  
  ;; For backward compatibility:
  (define (syntax-local-provide-certifier)
    (case-lambda 
     [(v) v]
     [(v mark) v]))

  (define orig-insp (variable-reference->module-declaration-inspector
                     (#%variable-reference)))

  (define (pre-expand-export stx modes)
    (if (identifier? stx)
        stx
        (let ([disarmed-stx (syntax-disarm stx orig-insp)])
          (syntax-case disarmed-stx ()
            [(id . rest)
             (identifier? #'id)
             (let ([t (syntax-local-value #'id (lambda () #f))])
               (if (provide-pre-transformer? t)
                   (let ([v (((provide-pre-transformer-get-proc t) t) disarmed-stx modes)])
                     (unless (syntax? v)
                       (raise-syntax-error
                        #f
                        "result from provide pre-transformer is not a syntax object"
                        stx))
                     (syntax-property v
                                      'disappeared-use
                                      (cons (syntax-local-introduce #'id)
                                            (or (syntax-property v 'disappeared-use) null))))
                   stx))]
            [_ stx]))))

  ;; expand-export : stx -> (listof export)
  (define (expand-export stx modes)
    (if (identifier? stx)
        (apply
         append
         (map (lambda (mode)
                (list (make-export stx stx mode #f stx)))
              (if (null? modes)
                  '(0)
                  modes)))
        (let ([disarmed-stx (syntax-disarm stx orig-insp)])
          (syntax-case disarmed-stx ()
            [(id . rest)
             (identifier? #'id)
             (let ([t (syntax-local-value #'id (lambda () #f))])
               (if (provide-transformer? t)
                   (let ([v (((provide-transformer-get-proc t) t) disarmed-stx modes)])
                     (unless (and (list? v)
                                  (andmap export? v))
                       (raise-syntax-error
                        #f
                        "result from provide transformer is not a list of exports"
                        stx))
                     v)
                   (raise-syntax-error
                    #f
                    "not a provide sub-form"
                    stx)))]
            [_
             (raise-syntax-error
              #f
              "bad syntax for provide sub-form"
              stx)])))))
