#lang racket/base
(require (for-syntax racket/base)
         rackunit
         (only-in "setup.rkt" convert-syntax-error tcerr)
         racket/promise
         racket/syntax
         syntax/parse
         syntax/parse/experimental/template)

;; See test-syntax.rkt for main syntax tests (now same as template).
;; This file has tests for features not exported by racket/base
;; (metafunctions).

(define-syntax (tc stx)
  (syntax-case stx ()
    [(tc expr expected)
     #`(test-equal? (format "line ~s" #,(syntax-line stx))
                    (syntax->datum (convert-syntax-error expr))
                    expected)]))

(define-syntax (terx stx)
  (syntax-case stx ()
    [(terx expr err-rx ...)
     #`(tcerr (format "line ~s" #,(syntax-line stx)) expr err-rx ...)]))

;; ----------------------------------------

;; Common pattern variable definitions
;; (avoids having to have 'with-syntax' in every test case)

(define/with-syntax uu #'abc)
(define/with-syntax (aa ...) #'(a b c))
(define/with-syntax (xx ...) #'(x y z))
(define/with-syntax (nn ...) #'(1 2 3))
(define/with-syntax ((yy ...) ...) #'((1 2 3) (4 5 6) (7 8 9)))

(define/syntax-parse (~or* oo:nat _:id) #'x)
(define/syntax-parse ((~or* pp:nat _:id) ...) #'(a 1 b 2 3))

;; ----------------------------------------

(define-template-metafunction (join stx)
  (syntax-parse stx
    [(join a:id b:id ...)
     (datum->syntax #'a
                    (string->symbol
                     (apply string-append
                            (map symbol->string
                                 (syntax->datum #'(a b ...)))))
                    stx)]))

(tc (template (join a b c))
    'abc)
(tc (template ((xx (join tmp- xx)) ...))
    '((x tmp-x) (y tmp-y) (z tmp-z)))
(tc (template ((xx (join uu - xx)) ...))
    '((x abc-x) (y abc-y) (z abc-z)))
(tc (template ((xx (join aa xx)) ...))
    '((x ax) (y by) (z cz)))

;; ============================================================

;; Error tests

(define-template-metafunction (bad-mf stx) 123)

(terx (template (bad-mf))
      #rx"result of template metafunction was not syntax")

;; ============================================================

;; Test prop:template-metafunction and template-metafunction?

(define-syntax (is-metafunction? stx)
  (syntax-case stx ()
    [(_ id)
     #`#,(template-metafunction? (syntax-local-value #'id))]))

(test-case "template-metafunction? on define-template-metafunction"
  (define-template-metafunction (mf1 stx)
    #'1)

  (check-true (is-metafunction? mf1)))

(begin-for-syntax
  (struct my-template-metafunction2 (proc-id)
    #:property prop:template-metafunction (struct-field-index proc-id)))
(test-case
    "template-metafunction? on custom prop:template-metafunction with field"
  (define (myproc2 stx) #'2)
  (define-syntax mf2 (my-template-metafunction2 (quote-syntax myproc2)))
  
  (check-true (is-metafunction? mf2)))


;; must be before the definition of my-template-metafunction3
(define (myproc3 stx) #'3)
;; must be outside of the (test-case …) form
(begin-for-syntax
  (struct my-template-metafunction3 ()
    #:property prop:template-metafunction (quote-syntax myproc3)))
(test-case "template-metafunction? on custom prop:template-metafunction with id"
  (define-syntax mf3 (my-template-metafunction3))
  
  (check-true (is-metafunction? mf3)))

(test-case "use define-template-metafunction"
  (define-template-metafunction (mf-def-for-use stx)
    (syntax-case stx ()
      [(_ n) #`#,(/ (syntax-e #'n) 2)]))

  (check-equal? (syntax->datum (template (x (mf-def-for-use 6) z)))
                '(x 3 z)))

(begin-for-syntax
  (struct my-template-metafunction4 (proc-id)
    #:property prop:template-metafunction (struct-field-index proc-id)))
(test-case "use custom prop:template-metafunction with field"
  (define (myproc4 stx)
    (syntax-case stx ()
      [(_ n) #`#,(add1 (syntax-e #'n))]))
  (define-syntax mf4 (my-template-metafunction4 (quote-syntax myproc4)))
  
  (check-equal? (syntax->datum (template (x (mf4 3) z)))
                '(x 4 z)))

;; must be before the definition of my-template-metafunction5
(define (myproc5 stx)
  (syntax-case stx ()
    [(_ n) #`#,(* (syntax-e #'n) 2)]))
;; must be outside of the (test-case …) form
(begin-for-syntax
  (struct my-template-metafunction5 ()
    #:property prop:template-metafunction (quote-syntax myproc5)))
(test-case "use custom prop:template-metafunction with id"
  (define-syntax mf5 (my-template-metafunction5))
  
  (check-equal? (syntax->datum (template (x (mf5 3) z)))
                '(x 6 z)))

(begin-for-syntax
  (struct my-template-metafunction6 (proc-id)
    #:property prop:template-metafunction
    (lambda (self) (my-template-metafunction6-proc-id self))))
(test-case "use custom prop:template-metafunction with a function"
  (define (myproc6 stx)
    (syntax-case stx ()
      [(_ n) #`#,(* 2 (syntax-e #'n))]))
  (define-syntax mf6 (my-template-metafunction6 (quote-syntax myproc6)))
  
  (check-equal? (syntax->datum (template (x (mf6 3) z)))
                '(x 6 z)))
