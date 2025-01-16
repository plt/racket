#lang racket/base

(require
 racket/dict)

(module+ test
  (require rackunit)

  (check-true
   ((dict-mutability/c #f) '((a . 5))))

  (check-false
   ((dict-mutability/c #t) '((a . 5))))

  (check-false
   ((dict-mutability/c #t) (make-immutable-hash)))

  (check-true
   ((dict-mutability/c #t) (make-hash)))

  (check-true
   ((homogeneous-dictof symbol? integer?) '((a . 5))))

  (check-true
   ((homogeneous-dictof symbol? integer?) '((a . 5) (b . 5))))

  (check-false
   ((homogeneous-dictof symbol? integer?) '((a . b) (b . 5))))

  (check-false
   ((homogeneous-dictof symbol? integer?) '((a . b))))

  (check-false
   ((homogeneous-dictof symbol? integer?) '((5 . 6))))

  (check-true
   ((heterogeneous-dictof 'a integer?) '((a . 5))))

  (check-false
   ((heterogeneous-dictof 'a integer?) '((b . 5))))

  (check-false
   ((heterogeneous-dictof 'a integer?) '((a . b))))

  (check-true
   ((heterogeneous-dictof 'a integer?) '((a . 5) (b . 6))))

  (check-false
   ((heterogeneous-dictof #:exact-keys? #t 'a integer?) '((a . 5) (b . 6))))

  (check-true
   ((heterogeneous-dictof #:exact-keys? #t 'a integer? 'b integer?)
    '((a . 5) (b . 6))))

  (check-true
   ((heterogeneous-dictof 'a integer? 'b integer?)
    '((a . 5) (b . 6))))

  (check-true
   ((heterogeneous-dictof 'a integer? 'b integer?)
    '((a . 5) (b . 6) (c . 7))))

  (check-true
   ((heterogeneous-dictof #:mandatory-keys? #f 'a integer?) '((b . 5))))

  (check-true
   ((heterogeneous-dictof #:mandatory-keys? #f 'a integer?) '((a . 5) (b . 5))))

  (check-false
   ((heterogeneous-dictof #:mandatory-keys? #f 'a integer?) '((a . b) (b . 5))))

  (check-true
   ((heterogeneous-dictof symbol? integer?) '((a . 5) (b . 6))))

  (check-false
   ((heterogeneous-dictof symbol? integer? 'b 5) '((a . 5) (b . 6))))

  (check-true
   ((heterogeneous-dictof symbol? integer? 'b 6) '((a . 5) (b . 6))))

  (check-false
   ((heterogeneous-dictof symbol? symbol? 'b 6) '((a . 5) (b . 6))))

  (check-true
   ((heterogeneous-dictof 'a integer? 'b integer?)
    '((a . 5) (b . 6) (c . 7))))

  (check-true
   ((heterogeneous-dictof #:immutable? #t 'a integer?) '((a . 5))))

  (check-false
   ((heterogeneous-dictof #:immutable? #f 'a integer?) '((a . 5))))

  (check-false
   ((heterogeneous-dictof #:immutable? #t 'a integer?) (make-hash '((a . 5)))))

  (check-true
   ((heterogeneous-dictof #:immutable? #f 'a integer?) (make-hash '((a . 5)))))

  (check-true
   ((heterogeneous-dictof #:immutable? #t 'a integer?) (make-immutable-hash '((a . 5)))))

  (check-false
   ((heterogeneous-dictof #:immutable? #f 'a integer?) (make-immutable-hash '((a . 5))))))
