#lang racket/base
(require racket/fixnum
         "match.rkt"
         "wrap.rkt"
         "known.rkt"
         "import.rkt"
         "mutated-state.rkt")

(provide ensure-single-valued
         single-valued-lambda?)

(define (ensure-single-valued v knowns prim-knowns imports mutated)
  (match v
    [`(quote ,_) v]
    [`(lambda . ,_) v]
    [`(case-lambda . ,_) v]
    [`(,proc-or-form . ,_)
     (define u (unwrap proc-or-form))
     (cond
       [(and (symbol? u)
             (simple-mutated-state? (hash-ref mutated u #f))
             (let ([k (or (hash-ref prim-knowns u #f)
                          (hash-ref-either knowns imports u))])
               (or (known-procedure/allocates? k)
                   (known-procedure/single-valued? k))))
        v]
       [else `($value ,v)])]
    [`,_ v]))

;; ----------------------------------------

;; Make some effort to detect single-valued functions. Knowing
;; single-valuedness is only worth a little beyond primitives, so we
;; don't try very hard.

(define INITIAL-SINGLE-VALUE-FUEL 16)

(define (single-valued-lambda? lam knowns prim-knowns imports mutated [fuel INITIAL-SINGLE-VALUE-FUEL])
  (match lam
    [`(lambda ,_ . ,body)
     (single-valued-body? body knowns prim-knowns imports mutated fuel)]
    [`(case-lambda [,_ . ,bodys] ...)
     (for/and ([body (in-list bodys)])
       (single-valued-body? body knowns prim-knowns imports mutated fuel))]
    [`,_ #f]))

(define (single-valued-body? body knowns prim-knowns imports mutated fuel)
  (let loop ([body body] [fuel fuel])
    (cond
      [(fx= fuel 0) #f]
      [(null? (cdr body))
       (single-valued? (car body) knowns prim-knowns imports mutated fuel)]
      [else
       (loop (cdr body) (fx- fuel 1))])))

(define (single-valued-call? proc knowns prim-knowns imports mutated)
  (let ([proc (unwrap proc)])
    (and (symbol? proc)
	 (let ([v (or (hash-ref-either knowns imports proc)
		      (hash-ref prim-knowns proc #f))])
	   (known-procedure/single-valued? v))
	 (simple-mutated-state? (hash-ref mutated proc #f)))))

(define (single-valued? e knowns prim-knowns imports mutated fuel)
  (cond
    [(fx= fuel 0) #f]
    [else
     (match e
       [`(lambda . ,_) #t]
       [`(case-lambda . ,_) #t]
       [`(quote . ,_) #t]
       [`(#%variable-reference . ,_) #t]
       [`(let-values ,_ . ,body)
        (single-valued-body? body knowns prim-knowns imports mutated (fx- fuel 1))]
       [`(let ,_ . ,body)
        (single-valued-body? body knowns prim-knowns imports mutated (fx- fuel 1))]
       [`(let-values ,_ . ,body)
        (single-valued-body? body knowns prim-knowns imports mutated (fx- fuel 1))]
       [`(letrec ,_ . ,body)
        (single-valued-body? body knowns prim-knowns imports mutated (fx- fuel 1))]
       [`(letrec-values ,_ . ,body)
        (single-valued-body? body knowns prim-knowns imports mutated (fx- fuel 1))]
       [`(letrec* ,_ . ,body)
        (single-valued-body? body knowns prim-knowns imports mutated (fx- fuel 1))]
       [`(begin . ,body)
        (single-valued-body? body knowns prim-knowns imports mutated (fx- fuel 1))]
       [`(begin-unsafe . ,body)
        (single-valued-body? body knowns prim-knowns imports mutated (fx- fuel 1))]
       [`(begin0 ,e . ,_)
        (single-valued? e knowns prim-knowns imports mutated (fx- fuel 1))]
       [`(set! ,_ ,_) #t]
       [`(if ,_ ,thn ,els)
        (and (single-valued? thn knowns prim-knowns imports mutated (fxrshift fuel 1))
             (single-valued? els knowns prim-knowns imports mutated (fxrshift fuel 1)))]
       [`(#%app/value . ,_) #t]
       [`(#%app/no-return . ,_) #t]
       [`(call-with-values ,_ ,recv)
	(single-valued-lambda? recv knowns prim-knowns imports mutated (fx- fuel 1))]
       [`(,proc . ,args)
	(single-valued-call? (unwrap proc) knowns prim-knowns imports mutated)]
       [`(apply ,proc . ,args)
	(single-valued-call? (unwrap proc) knowns prim-knowns imports mutated)]
       [`,_ #t])]))
