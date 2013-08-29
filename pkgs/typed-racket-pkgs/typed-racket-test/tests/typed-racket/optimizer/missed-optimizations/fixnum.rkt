#;
#<<END
TR opt: fixnum.rkt 36:10 (* x y) -- fixnum bounded expr
TR missed opt: fixnum.rkt 39:0 (+ (ann z Fixnum) 234) -- out of fixnum range
TR missed opt: fixnum.rkt 40:0 (* (ann x Index) (ann y Index)) -- out of fixnum range
TR opt: fixnum.rkt 43:3 (+ 300 301) -- fixnum bounded expr
TR opt: fixnum.rkt 43:15 (+ 301 302) -- fixnum bounded expr
TR missed opt: fixnum.rkt 43:0 (+ (+ 300 301) (+ 301 302)) -- out of fixnum range
TR opt: fixnum.rkt 43:3 (+ 300 301) -- fixnum bounded expr
TR opt: fixnum.rkt 43:15 (+ 301 302) -- fixnum bounded expr
TR opt: fixnum.rkt 43:3 (+ 300 301) -- fixnum bounded expr
TR opt: fixnum.rkt 43:15 (+ 301 302) -- fixnum bounded expr
TR opt: fixnum.rkt 44:5 (+ 300 301) -- fixnum bounded expr
TR opt: fixnum.rkt 44:17 (+ 301 302) -- fixnum bounded expr
TR opt: fixnum.rkt 44:5 (+ 300 301) -- fixnum bounded expr
TR opt: fixnum.rkt 44:17 (+ 301 302) -- fixnum bounded expr
468
234
234
3
1204
1204
0

END
#lang typed/racket

(require racket/fixnum)





(define x 3)
(define y 78)
(define z (* x y)) ; this should be optimized

;; this should not, (+ Fixnum Byte), but it may look like it should
(+ (ann z Fixnum) 234)
(* (ann x Index) (ann y Index))
(fx* (values (ann x Index)) (values (ann y Index))) ; not reported, by design
(abs (ann -3 Fixnum))
(+ (+ 300 301) (+ 301 302))
(fx+ (+ 300 301) (+ 301 302)) ; not reported, by design
(fxquotient -4 -5) ; not reported, by design
