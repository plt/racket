#lang racket/base

;; Static contracts for common data types.
;; These are used during optimizations as simplifications.
;; Ex: (listof/sc any/sc) => list?/sc

(require "simple.rkt" "structural.rkt"
         (for-template racket/base racket/set racket/promise))
(provide (all-defined-out))

(define identifier?/sc (flat/sc #'identifier?))
(define box?/sc (flat/sc #'box?))
(define syntax?/sc (flat/sc #'syntax?))
(define promise?/sc (flat/sc #'promise?))

(define list?/sc (flat/sc #'list?))

(define set?/sc (flat/sc #'set?))
(define empty-set/sc (and/sc set?/sc (flat/sc #'set-empty?)))

(define vector?/sc (flat/sc #'vector?))

(define hash?/sc (flat/sc #'hash?))
(define empty-hash/sc (and/sc hash?/sc (flat/sc #'(λ (h) (zero? (hash-count h))))))
