#lang scribble/doc
@(require scribble/manual
          scribble/struct
          scribble/decode
          scribble/eval
          "parse-common.rkt"
          (for-label syntax/parse/define))

@(define the-eval (make-sp-eval))

@title{Defining Simple Macros}

@defmodule[syntax/parse/define]

The @racketmodname[syntax/parse/define] library provides
@racket[for-syntax] all of @racketmodname[syntax/parse], as well as
providing some new forms.

@defform[(define-syntax-parse-rule (macro-id . pattern) pattern-directive ...
           template)]{

Defines a macro named @racket[macro-id]; equivalent to the following:

@racketblock[
(define-syntax (macro-id stx)
  (syntax-parse stx
    #:track-literals
    [((~var macro-id id) . pattern) pattern-directive ... (syntax template)]))
]

@(the-eval '(require syntax/parse/define))
@examples[#:eval the-eval
(define-syntax-parse-rule (fn x:id rhs:expr) (lambda (x) rhs))
((fn x x) 17)
(fn 1 2)

(define-syntax-parse-rule (fn2 x y rhs)
  #:declare x id
  #:declare y id
  #:declare rhs expr
  (lambda (x y) rhs))
((fn2 a b (+ a b)) 3 4)
(fn2 a #:b 'c)
]

@history[#:added "7.9.0.22"]
}

@defform[(define-syntax-parser macro-id parse-option ... clause ...+)]{

Defines a macro named @racket[macro-id]; equivalent to:

@racketblock[
(define-syntax macro-id
  (syntax-parser parse-option ... clause ...))
]

This form does not explicitly mention the syntax object being parsed,
but as in the case of any use of @racket[syntax-parse], you can access
it via @racket[this-syntax].

@examples[#:eval the-eval
(define-syntax-parser fn3
  [(fn3 x:id rhs:expr)
   #'(lambda (x) rhs)]
  [(fn3 x:id y:id rhs:expr)
   #'(lambda (x y) rhs)])
((fn3 x x) 17)
((fn3 a b (+ a b)) 3 4)
(fn3 1 2)
(fn3 a #:b 'c)
]}

@defform[(define-simple-macro (macro-id . pattern) pattern-directive ...
           template)]{
@deprecated[#:what "macro" @racket[define-syntax-parse-rule]]

Re-exports @racket[define-syntax-parse-rule] for backward-compatibility.

@history[#:changed "6.12.0.3" @elem{Changed pattern head to @racket[(~var macro-id id)] from
                                    @racket[macro-id], allowing tilde-prefixed identifiers or
                                    identifiers containing colons to be used as @racket[macro-id]
                                    without producing a syntax error.}
         #:changed "6.90.0.29" @elem{Changed to always use the @racket[#:track-literals]
                                     @racket[syntax-parse] option.}]
}

@(close-eval the-eval)
