#lang typed/racket/base

(require racket/flonum
         racket/performance-hint
         (for-syntax racket/base)
         "private/exception.rkt")

(provide (all-from-out racket/flonum)
         (rename-out [real->double-flonum fl])
         flonum->bit-field bit-field->flonum
         flonum->ordinal ordinal->flonum
         flstep flnext flprev flonums-between
         -max.0 -min.0 +min.0 +max.0 epsilon.0
         +min-normal.0 +max-subnormal.0 -min-normal.0 -max-subnormal.0 flsubnormal?
         flnext* flprev*
         flulp flulp-error relative-error
         float-complex? (rename-out [inline-number->float-complex number->float-complex])
         find-least-flonum
         fleven? flodd? flsgn flhypot fllog/base
         flprobability?)

;; ===================================================================================================
;; Floating-point representation

(: flonum->bit-field (Float -> Nonnegative-Integer))
(define (flonum->bit-field x)
  (define y
    (integer-bytes->integer (real->floating-point-bytes x (ann 8 8)) #f))
  (with-asserts ([y exact-nonnegative-integer?]) y))

(: bit-field->flonum (Integer -> Float))
(define (bit-field->flonum i)
  (cond [(and (i . >= . 0) (i . <= . #xffffffffffffffff))
         (floating-point-bytes->real (integer->integer-bytes i 8 #f))]
        [else
         (raise-argument-error 'bit-field->flonum "Integer in [0,#xffffffffffffffff]" i)]))

(: flonum->ordinal (Float -> Integer))
(define (flonum->ordinal x)
  (cond [(x . < . 0)  (- (flonum->bit-field (- x)))]
        [else            (flonum->bit-field (abs x))])) ; abs for -0.0

(: ordinal->flonum (Integer -> Float))
(define (ordinal->flonum i)
  (cond [(and (i . >= . #x-7fffffffffffffff) (i . <= . #x7fffffffffffffff))
         (cond [(i . < . 0)  (- (bit-field->flonum (- i)))]
               [else            (bit-field->flonum i)])]
        [else
         (raise-argument-error
          'ordinal->flonum "Integer in [#x-7fffffffffffffff,#x7fffffffffffffff]" i)]))

(define +inf-ordinal (flonum->ordinal +inf.0))
(define -inf-ordinal (flonum->ordinal -inf.0))

(: flstep (Float Integer -> Float))
(define (flstep x n)
  (cond [(eqv? x +nan.0)  +nan.0]
        [(and (eqv? x +inf.0) (n . >= . 0))  +inf.0]
        [(and (eqv? x -inf.0) (n . <= . 0))  -inf.0]
        [else  (define i (+ n (flonum->ordinal x)))
               (cond [(i . < . -inf-ordinal)  -inf.0]
                     [(i . > . +inf-ordinal)  +inf.0]
                     [else  (ordinal->flonum i)])]))

(: flnext (Float -> Float))
(define (flnext x) (flstep x 1))

(: flprev (Float -> Float))
(define (flprev x) (flstep x -1))

(: flonums-between (Float Float -> Integer))
(define (flonums-between x y)
  (- (flonum->ordinal y) (flonum->ordinal x)))

(: flulp (Float -> (U Float-Nan Nonnegative-Float)))
(define (flulp x)
  (let ([x  (abs x)])
    (cond [(= x +inf.0)  +nan.0]
          [(eqv? x +nan.0)  +nan.0]
          [(= x 0.0)  0.0]
          [else
           (define ulp (abs (- (flnext x) x)))
           (cond [(= ulp +inf.0)  (abs (- x (flprev x)))]
                 [else  ulp])])))

;; ===================================================================================================
;; Constants

(define -max.0 (flnext -inf.0))
(define -min.0 (flprev 0.0))
(define +min.0 (flnext 0.0))
(define +max.0 (flprev +inf.0))

;; The smallest flonum that can be added to 1.0 to get a result != 1.0
(define epsilon.0 (flulp 1.0))

;; ===================================================================================================
;; Subnormal numbers

(define +min-normal.0 (ordinal->flonum #x10000000000000))
(define +max-subnormal.0 (flprev +min-normal.0))
(define -min-normal.0 (- +min-normal.0))
(define -max-subnormal.0 (- +max-subnormal.0))

(: flsubnormal? (Float -> Boolean))
(define (flsubnormal? x)
  (and ((flabs x) . < . +min-normal.0)
       (not (= x 0.0))))

;; ===================================================================================================
;; Faster flnext and flprev

(: flsubnormal-next* (Float -> Float))
(define (flsubnormal-next* x)
  (/ (+ (* x (flexpt 2.0 1022.0)) epsilon.0)
     (flexpt 2.0 1022.0)))

(: flsubnormal-prev* (Float -> Float))
(define (flsubnormal-prev* x)
  (/ (- (* x (flexpt 2.0 1022.0)) epsilon.0)
     (flexpt 2.0 1022.0)))

(: flnext* (Float -> Float))
(define (flnext* x)
  (cond [(x . < . 0.0)  (- (flprev* (- x)))]
        [(= x 0.0)  +min.0]
        [(= x +inf.0)  +inf.0]
        [else  (define next-x (+ x (* x (* 0.5 epsilon.0))))
               (cond [(= next-x x)  (+ x (* x epsilon.0))]
                     [else  next-x])]))

(: flprev* (Float -> Float))
(define (flprev* x)
  (cond [(x . < . 0.0)  (- (flnext* (- x)))]
        [(= x 0.0)  -min.0]
        [(= x +inf.0)  +max.0]
        [else  (define prev-x (- x (* x (* 0.5 epsilon.0))))
               (cond [(= prev-x x)  (- x (* x epsilon.0))]
                     [else  prev-x])]))

;; ===================================================================================================
;; Error measurement

(: flulp-error (Float Real -> Float))
(define (flulp-error x r)
  (cond [(eqv? r +nan.0)  (if (eqv? x +nan.0) 0.0 +nan.0)]
        [(= r +inf.0)     (if (= x +inf.0)    0.0 +inf.0)]
        [(= r -inf.0)     (if (= x -inf.0)    0.0 +inf.0)]
        [(zero? r)        (if (zero? x)       0.0 +inf.0)]
        [(eqv? x +nan.0)  +nan.0]
        [(= x +inf.0)     +inf.0]
        [(= x -inf.0)     +inf.0]
        [(zero? x)        +inf.0]
        [else  (real->double-flonum
                (/ (abs (- (inexact->exact x) (inexact->exact r)))
                   (inexact->exact (flulp x))))]))

(: relative-error (Real Real -> Float))
(define (relative-error x r)
  (cond [(eqv? r +nan.0)  (if (eqv? x +nan.0) 0.0 +nan.0)]
        [(= r +inf.0)     (if (= x +inf.0)    0.0 +inf.0)]
        [(= r -inf.0)     (if (= x -inf.0)    0.0 +inf.0)]
        [(zero? r)        (if (zero? x)       0.0 +inf.0)]
        [(eqv? x +nan.0)  +nan.0]
        [(= x +inf.0)     +inf.0]
        [(= x -inf.0)     +inf.0]
        [(zero? x)        +inf.0]
        [else  (let ([x  (inexact->exact x)]
                     [r  (inexact->exact r)])
                 (real->double-flonum (/ (abs (- x r)) r)))]))

;; ===================================================================================================
;; Types, conversion

(define-predicate float-complex? Float-Complex)

(define-syntax (inline-number->float-complex stx)
  (syntax-case stx ()
    [(_ z-expr)  (syntax/loc stx
                   (let: ([z : Number  z-expr])
                     (make-rectangular (real->double-flonum (real-part z))
                                       (real->double-flonum (imag-part z)))))]
    [(_ e ...)  (syntax/loc stx (number->float-complex e ...))]
    [_  (syntax/loc stx number->float-complex)]))

(: number->float-complex (Number -> Float-Complex))
(define (number->float-complex z) (inline-number->float-complex z))

;; ===================================================================================================
;; Search

(: find-least-flonum (case-> ((Float -> Any) Float -> (U Float #f))
                             ((Float -> Any) Float Float -> (U Float #f))))

(define find-least-flonum
  (case-lambda
    [(pred? x-start)
     (when (eqv? +nan.0 x-start)
       (raise-argument-error 'find-least-flonum "non-NaN Float" 1 pred? x-start))
     (let loop ([n-end  (flonum->ordinal x-start)] [step 1])
       (define x-end (ordinal->flonum n-end))
       (cond [(pred? x-end)  (find-least-flonum pred? x-start x-end)]
             [(= x-end +inf.0)  #f]
             [else  (loop (min +inf-ordinal (+ n-end step)) (* step 2))]))]
    [(pred? x-start x-end)
     (when (eqv? x-start +nan.0)
       (raise-argument-error 'find-least-flonum "non-NaN Float" 1 pred? x-start x-end))
     (when (eqv? x-end +nan.0)
       (raise-argument-error 'find-least-flonum "non-NaN Float" 2 pred? x-start x-end))
     (cond [(pred? x-start)  x-start]
           [(not (pred? x-end))  #f]
           [else
            (let loop ([n-start  (flonum->ordinal x-start)] [n-end  (flonum->ordinal x-end)])
              (cond [(= n-start n-end)  (define x (ordinal->flonum n-end))
                                        (if (pred? x) x #f)]
                    [else
                     (define n-mid (quotient (+ n-start n-end) 2))
                     (cond [(pred? (ordinal->flonum n-mid))
                            (loop n-start n-mid)]
                           [else
                            (loop (+ n-mid 1) n-end)])]))])]))

;; ===================================================================================================
;; More floating-point functions

(begin-encourage-inline
  
  (: flsgn (Float -> Float))
  (define (flsgn x)
    (cond [(< x 0.0) -1.0]
          [(< 0.0 x)  1.0]
          [else  0.0]))
  
  (: fleven? (Float -> Boolean))
  (define (fleven? x)
    (let ([x  (abs x)])
      (or (= x 0.0)
          (and (x . >= . 2.0)
               (let ([0.5x  (* 0.5 x)])
                 (= (truncate 0.5x) 0.5x))))))
  
  (define last-odd (- (flexpt 2.0 53.0) 1.0))
  
  (: flodd? (Float -> Boolean))
  (define (flodd? x)
    (let ([x  (abs x)])
      (and (x . >= . 1.0) (x . <= . last-odd)
           (let ([0.5x  (* 0.5 (+ 1.0 x))])
             (= (truncate 0.5x) 0.5x)))))
  
  (: flhypot (Float Float -> Float))
  (define (flhypot x y)
    (define xa (abs x))
    (define ya (abs y))
    (let ([xa  (min xa ya)]
          [ya  (max xa ya)])
      (cond [(= xa 0.0)  ya]
            [else  (define u (/ xa ya))
                   (* ya (flsqrt (+ 1.0 (* u u))))])))
  
  ;; todo: overflow not likely; underflow likely
  (: fllog/base (Float Float -> Float))
  (define (fllog/base b x)
    (/ (fllog x) (fllog b)))
  
  (: flprobability? (case-> (Float -> Boolean)
                            (Float Any -> Boolean)))
  (define (flprobability? p [log? #f])
    (cond [log?  (and (p . >= . -inf.0) (p . <= . 0.0))]
          [else  (and (p . >= . 0.0) (p . <= . 1.0))]))
  
  )  ; begin-encourage-inline
