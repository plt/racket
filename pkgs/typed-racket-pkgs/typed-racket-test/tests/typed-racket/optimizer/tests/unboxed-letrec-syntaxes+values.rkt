#;#;
#<<END
TR opt: unboxed-letrec-syntaxes+values.rkt 25:27 x -- unbox float-complex
TR opt: unboxed-letrec-syntaxes+values.rkt 25:29 2.0+4.0i -- unboxed literal
TR opt: unboxed-letrec-syntaxes+values.rkt 25:24 (+ x 2.0+4.0i) -- unboxed binary float complex
TR opt: unboxed-letrec-syntaxes+values.rkt 24:33 1.0+2.0i -- unboxed literal
TR opt: unboxed-letrec-syntaxes+values.rkt 24:42 2.0+4.0i -- unboxed literal
TR opt: unboxed-letrec-syntaxes+values.rkt 24:30 (+ 1.0+2.0i 2.0+4.0i) -- unboxed binary float complex
TR opt: unboxed-letrec-syntaxes+values.rkt 23:0 (letrec-syntaxes+values (((s) (syntax-rules () ((_ x) x)))) (((x) (+ 1.0+2.0i 2.0+4.0i))) (+ x 2.0+4.0i)) -- unboxed let bindings
TR opt: unboxed-letrec-syntaxes+values.rkt 25:27 x -- leave var unboxed
TR opt: unboxed-letrec-syntaxes+values.rkt 25:29 2.0+4.0i -- unboxed literal
TR opt: unboxed-letrec-syntaxes+values.rkt 25:24 (+ x 2.0+4.0i) -- unboxed binary float complex

END
#<<END
5.0+10.0i

END

#lang typed/scheme
#:optimize

(letrec-syntaxes+values (((s) (syntax-rules () [(_ x) x])))
                        (((x) (+ 1.0+2.0i 2.0+4.0i)))
                        (+ x 2.0+4.0i))
