#;
#<<END
TR opt: unboxed-letrec.rkt 29:5 x -- unbox float-complex
TR opt: unboxed-letrec.rkt 29:7 y -- unbox float-complex
TR opt: unboxed-letrec.rkt 29:2 (+ x y) -- unboxed binary float complex
TR opt: unboxed-letrec.rkt 29:5 x -- unbox float-complex
TR opt: unboxed-letrec.rkt 29:7 y -- unbox float-complex
TR opt: unboxed-letrec.rkt 29:2 (+ x y) -- unboxed binary float complex
TR opt: unboxed-letrec.rkt 27:31 1.0+2.0i -- unboxed literal
TR opt: unboxed-letrec.rkt 28:34 2.0+4.0i -- unboxed literal
TR opt: unboxed-letrec.rkt 28:43 3.0+6.0i -- unboxed literal
TR opt: unboxed-letrec.rkt 28:31 (+ 2.0+4.0i 3.0+6.0i) -- unboxed binary float complex
TR opt: unboxed-letrec.rkt 26:0 (letrec: ((f : (Any -> Any) (lambda: ((x : Any)) (f x))) (x : Float-Complex 1.0+2.0i) (y : Float-Complex (+ 2.0+4.0i 3.0+6.0i))) (+ x y)) -- unboxed let bindings
TR opt: unboxed-letrec.rkt 29:5 x -- leave var unboxed
TR opt: unboxed-letrec.rkt 29:7 y -- leave var unboxed
TR opt: unboxed-letrec.rkt 29:2 (+ x y) -- unboxed binary float complex
6.0+12.0i

END

#lang typed/scheme
#:optimize



(letrec: ((f : (Any -> Any) (lambda: ((x : Any)) (f x)))
          (x : Float-Complex   1.0+2.0i)
          (y : Float-Complex   (+ 2.0+4.0i 3.0+6.0i)))
  (+ x y))
