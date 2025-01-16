#lang racket/base
(provide for/append-list
         for/append-lists
         for*/append-list
         for*/append-lists)

(require
 (for-syntax racket/base
             syntax/for-body))

;; ---------------------------------------------------------------------------------------------------

(define-syntaxes [for/append-lists for/append-list for*/append-lists for*/append-list]
  (let ()
    (define ((make-for/append-lists macro for/derived-id) stx)
      (syntax-case stx ()
        [(_ (name ...) (clause ...) . body)
         (with-syntax ([([pre-body ...] body*) (split-for-body stx #'body)]
                       [[tmp ...] (generate-temporaries #'[name ...])])
           #`(let-values ([(tmp ...)
                           (#,for/derived-id
                            #,stx
                            ([name '()] ...)
                            (clause ...)
                            pre-body ...
                            (let-values ([(tmp ...) (let-values () . body*)])
                              (values (rev-append '#,macro tmp name)
                                      ...)))])
               (values (reverse tmp)
                       ...)))]))

    (define ((make-for/append-list macro for/derived-id) stx)
      (syntax-case stx ()
        [(_ (clause ...) . body)
         (with-syntax ([([pre-body ...] body*) (split-for-body stx #'body)])
           #`(reverse
              (#,for/derived-id
               #,stx
               ([tmp '()])
               (clause ...)
               pre-body ...
               (rev-append '#,macro
                           (let-values () . body*)
                           tmp))))]))

    (values (make-for/append-lists 'for/append-lists  #'for/fold/derived)
            (make-for/append-list  'for/append-list   #'for/fold/derived)
            (make-for/append-lists 'for*/append-lists #'for*/fold/derived)
            (make-for/append-list  'for*/append-list  #'for*/fold/derived))))

;; symbol [listof X] [listof X] -> [listof X]
(define (rev-append blame xs tl)
  (unless (list? xs)
    (raise-argument-error blame "list?" xs))
  (let loop ([acc tl]
             [xs xs])
    (if (null? xs)
      acc
      (loop (cons (car xs) acc)
            (cdr xs)))))
