#lang racket/base
(require racket/function rackunit)

(check-true ((conjoin) 'x #:y 'z)) ; no function
(check-true ((conjoin integer? exact?) 1))
(check-false ((conjoin integer? exact?) 1.0))
(check-false ((conjoin integer? exact?) 0.5))

(check-false ((disjoin) 'x #:y 'z)) ; no function
(check-true ((disjoin integer? exact?) 1))
(check-true ((disjoin integer? exact?) 1/2))
(check-false ((disjoin integer? exact?) 0.5))

(check-equal? (get-failure-result #f) #f)
(check-equal? (get-failure-result #t) #t)
(check-equal? (get-failure-result 'hello) 'hello)
(check-equal? (get-failure-result (λ () #f)) #f)
(check-equal? (get-failure-result (λ () #t)) #t)
(check-equal? (get-failure-result (λ () 'hello)) 'hello)
(check-exn exn:fail:contract? (λ () (get-failure-result (λ (x) x))))
