#lang racket/base

(require "test-utils.rkt"
         rackunit racket/list racket/match racket/format
         syntax/srcloc syntax/location
         (types abbrev union tc-result)
         (utils tc-utils)
         (rep filter-rep object-rep type-rep)
         (typecheck check-below)
         (for-syntax racket/base syntax/parse))

(provide tests)
(gen-test-main)

;; Ensure that we never return a filter of NoFilter or an object of NoObject.
(define (check-filter f)
  (match f
    [(NoFilter:) (fail-check "Result has no filter (instead of a top filter).")]
    [_ (void)]))

(define (check-object o)
  (match o
    [(NoObject:) (fail-check "Result has no object (instead of an empty object).")]
    [_ (void)]))

(define (check-result result)
  (match result
    [(tc-results: ts fs os)
     (for-each check-filter fs)
     (for-each check-object os) ]
    [(tc-results: ts fs os dty bound)
     (for-each check-filter fs)
     (for-each check-object os)]
    [(or (tc-any-results:) (? Type/c?))
     (void)]))


(define-syntax (test-below stx)
  (syntax-parse stx
    [(_ t1:expr t2:expr (~optional (~seq #:result expected-result:expr)
                                     #:defaults [(expected-result #'t2)]))
     #`(test-case (~a 't1 " <: " 't2)
         (with-check-info (['location (build-source-location-list (quote-srcloc #,stx))]
                           ['expected expected-result])
           (define result (check-below t1 t2))
           (with-check-info (['actual result])
             (check-result result)
             (unless (equal? expected-result result)
               (fail-check "Check below did not return expected result.")))))]
    [(_ #:fail (~optional message:expr #:defaults [(message #'#rx"type mismatch")])
        t1:expr t2:expr
        (~optional (~seq #:result expected-result:expr)
                     #:defaults [(expected-result #'t2)]))
     #`(test-case (~a 't1 " !<: " 't2)
         (with-check-info (['location (build-source-location-list (quote-srcloc #,stx))]
                           ['expected expected-result])
           (define result
             (parameterize ([delay-errors? #t])
               (check-below t1 t2)))
           (with-check-info (['actual result])
             (define exn
               (let/ec exit
                 (with-handlers [(exn:fail? exit)]
                   (report-all-errors)
                   (fail-check "Check below did not fail."))))
             (check-result result)
             (unless (equal? expected-result result)
               (fail-check "Check below did not return expected result."))
             (check-regexp-match message (exn-message exn)))))]))


(define tests
  (test-suite "Check Below"
    (test-below -Bottom Univ)
    (test-below #:fail -Symbol -String)
    (test-below
      (ret (list -Symbol) (list -top-filter) (list -empty-obj))
      (ret (list Univ) (list -no-filter) (list -no-obj))
      #:result (ret (list Univ) (list -top-filter) (list -empty-obj)))

    ;; Currently returns -no-obj instead of empty-obj
    #;
    (test-below #:fail
      (ret (list -Symbol) (list -top-filter) (list -empty-obj))
      (ret (list Univ) (list -true-filter) (list -no-obj))
      #:result (ret (list Univ) (list -true-filter) (list -empty-obj)))

    (test-below #:fail #rx"no object"
      (ret (list -Symbol) (list -top-filter) (list -empty-obj))
      (ret (list Univ) (list -top-filter) (list (make-Path empty #'x))))

    (test-below #:fail #rx"no object"
      (ret (list -Symbol) (list -top-filter) (list -empty-obj))
      (ret (list Univ) (list -true-filter) (list (make-Path empty #'x))))


    ;; Enable these once check-below is fixed
    ;; Currently returns -no-obj instead of empty-obj
    #;
    (test-below #:fail
      (ret (list Univ) (list -top-filter) (list -empty-obj) Univ 'B)
      (ret (list Univ) (list -false-filter) (list -no-obj) Univ 'B)
      #:result (ret (list Univ) (list -false-filter) (list -empty-obj) Univ 'B))

    ;; Currently returns -no-obj instead of empty-obj
    #;
    (test-below #:fail
      (ret (list Univ) (list -top-filter) (list -empty-obj))
      (ret (list Univ) (list -false-filter) (list -no-obj) Univ 'B)
      #:result (ret (list Univ) (list -false-filter) (list -empty-obj) Univ 'B))

    ;; Currently returns -no-obj instead of empty-obj
    #;
    (test-below #:fail
      (ret (list Univ Univ) (list -top-filter -top-filter) (list -empty-obj -empty-obj))
      (ret (list Univ Univ) (list -false-filter -false-filter) (list -no-obj -no-obj))
      #:result (ret (list Univ Univ) (list -false-filter -false-filter) (list -no-obj -no-obj)))

  ))
