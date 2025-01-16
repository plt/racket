#lang racket/base
(require (for-syntax racket/base)
         (only-in racket/private/template
                  template-metafunction
                  prop:template-metafunction
                  template-metafunction?))
(provide (rename-out [syntax template]
                     [syntax/loc template/loc]
                     [quasisyntax quasitemplate]
                     [quasisyntax/loc quasitemplate/loc]
                     [~? ??]
                     [~@ ?@])
         define-template-metafunction
         (for-syntax prop:template-metafunction
                     template-metafunction?))

;; ============================================================
;; Metafunctions

(define-syntax (define-template-metafunction stx)
  (syntax-case stx ()
    [(dsm (id arg ...) . body)
     #'(dsm id (lambda (arg ...) . body))]
    [(dsm id expr)
     (identifier? #'id)
     (with-syntax ([(internal-id) (generate-temporaries #'(id))])
       #'(begin (define internal-id (make-hygienic-metafunction expr))
                (define-syntax id
                  (template-metafunction (quote-syntax internal-id)))))]))

(define current-template-metafunction-introducer
  (make-parameter (lambda (stx) (if (syntax-transforming?) (syntax-local-introduce stx) stx))))

(define ((make-hygienic-metafunction transformer) stx)
  (define mark (make-syntax-introducer))
  (define old-mark (current-template-metafunction-introducer))
  (parameterize ((current-template-metafunction-introducer mark))
    (define r (call-with-continuation-barrier (lambda () (transformer (mark (old-mark stx))))))
    (unless (syntax? r)
      (raise-syntax-error #f "result of template metafunction was not syntax" stx))
    (old-mark (mark r))))
