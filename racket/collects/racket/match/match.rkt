#lang racket/base

(require (only-in "runtime.rkt"
                  match-equality-test
                  exn:misc:match?)
         (only-in "match-expander.rkt"
                  define-match-expander)
         "define-forms.rkt"
         "struct.rkt"
         (for-syntax racket/lazy-require
                     racket/base
                     "patterns.rkt"
                     "syntax-local-match-introduce.rkt"
                     (only-in "stxtime.rkt"
                              match-...-nesting
                              match-expander?
                              legacy-match-expander?
                              prop:match-expander
                              prop:legacy-match-expander)))

(begin-for-syntax
  (lazy-require [racket/match/parse (parse)])
  (lazy-require [racket/match/parse-legacy (parse/legacy)]))

(define-for-syntax (pattern-bound-identifiers pstx #:legacy? [legacy? #f])
  (unless (syntax? pstx)
    (raise-argument-error 'pattern-bound-identifiers "syntax?" pstx))
  (pats->bound-vars (if legacy? parse/legacy parse) pstx))

(provide (for-syntax match-...-nesting match-expander? legacy-match-expander?
                     prop:match-expander prop:legacy-match-expander
                     syntax-local-match-introduce
                     pattern-bound-identifiers)
         match-equality-test
         define-match-expander
         struct* ==
         exn:misc:match?)

(define-forms parse
  match match* match/values
  match-lambda match-lambda* match-lambda**
  match-λ match-λ* match-λ**
  match-let match-let*
  match-let-values match-let*-values
  match-define match-define-values
  match-letrec match-letrec-values
  match/derived match*/derived
  define/match)
