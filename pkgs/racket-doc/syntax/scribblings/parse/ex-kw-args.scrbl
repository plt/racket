#lang scribble/doc
@(require scribble/manual
          scribble/struct
          scribble/decode
          scribble/eval
          "parse-common.rkt"
          (for-label racket/class))

@(define the-eval (make-sp-eval))

@title{Optional Keyword Arguments}

This section explains how to write a macro that accepts (simple)
optional keyword arguments. We use the example @racket[mycond], which
is like Racket's @racket[cond] except that it takes an optional
keyword argument that controls what happens if none of the clauses
match.

Optional keyword arguments are supported via @tech{head
patterns}. Unlike normal patterns, which match one term, head patterns
can match a variable number of subterms in a list. Some important
head-pattern forms are @racket[~seq], @racket[~or*], and
@racket[~optional].

Here's one way to do it:

@interaction[#:eval the-eval
(define-syntax (mycond stx)
  (syntax-parse stx
    [(mycond (~or* (~seq #:error-on-fallthrough who:expr)
                   (~seq))
             clause ...)
     (with-syntax ([error? (if (attribute who) #'#t #'#f)]
                   [who (or (attribute who) #'#f)])
       #'(mycond* error? who clause ...))]))

(define-syntax mycond*
  (syntax-rules ()
    [(mycond* error? who [question answer] . clauses)
     (if question answer (mycond* error? who . clauses))]
    [(mycond* #t who)
     (error who "no clauses matched")]
    [(mycond* #f _)
     (void)]))
]

We cannot simply write @racket[#'who] in the macro's right-hand side,
because the @racket[who] attribute does not receive a value if the
keyword argument is omitted. Instead we must first check the attribute
using @racket[(attribute who)], which produces @racket[#f] if matching
did not assign a value to the attribute.

@interaction[#:eval the-eval
(mycond [(even? 13) 'blue]
        [(odd? 4) 'red])
(mycond #:error-on-fallthrough 'myfun
        [(even? 13) 'blue]
        [(odd? 4) 'red])
]

There's a simpler way of writing the @racket[~or*] pattern above:
@racketblock[
(~optional (~seq #:error-on-fallthrough who:expr))
]


@section{Optional Arguments with @racket[~?]}

The @racket[~?] template form provides a compact alternative to
explicitly testing attribute values. Here's one way to do it:

@interaction[#:eval the-eval
(define-syntax (mycond stx)
  (syntax-parse stx
    [(mycond (~optional (~seq #:error-on-fallthrough who:expr))
             clause ...)
     #'(mycond* (~? (~@ #t who) (~@ #f #f)) clause ...)]))
]

If @racket[who] matched, then the @racket[~?] subtemplate splices in
the two terms @racket[#t who] into the enclosing template (@racket[~@]
is the template splicing form). Otherwise, it splices in @racket[#f #f].

Here's an alternative definition that re-uses Racket's @racket[cond] macro:

@interaction[#:eval the-eval
(define-syntax (mycond stx)
  (syntax-parse stx
    [(mycond (~optional (~seq #:error-on-fallthrough who:expr))
             clause ...)
     #'(cond clause ... (~? [else (error who "no clause matched")] (~@)))]))
]

In this version, we optionally insert an @racket[else] clause at the
end to signal the error; otherwise we use @racket[cond]'s fall-through
behavior (that is, returning @racket[(void)]).

If the second subtemplate of a @racket[~?] template is
@racket[(~@)]---that is, it produces no terms at all---the second
subtemplate can be omitted.

@section{Optional Keyword Arguments as flags}

Sometimes, you want your keywords to express an information by their presence,
without the need for an associated value.

@interaction[#:eval the-eval
(define-syntax (mycond stx)
  (syntax-parse stx
    [(mycond (~optional (~and error? #:error-on-fallthrough))
             clause ...)
     #:with fallthrough (if (attribute error?)
                            #'([else (error 'failure "no clause matched")])
                            #'())
     #'(cond clause ... (~@ . fallthrough))]))
]

@racket[~and] is useful for that: it binds a pattern to an attribute by
examining the structure of the term in place.

The tricky part here is that we don't want to generate any code when the
keyword is absent, hence the use of @racket[~@] to splice an empty list.

@section{Optional Arguments with @racket[define-splicing-syntax-class]}

Yet another way is to introduce a @tech{splicing syntax class}, which
is like an ordinary syntax class but for head patterns.

@interaction[#:eval the-eval
(define-syntax (mycond stx)

  (define-splicing-syntax-class maybe-fallthrough-option
    (pattern (~seq #:error-on-fallthrough who:expr)
             #:with error? #'#t)
    (pattern (~seq)
             #:with error? #'#f
             #:with who #'#f))

  (syntax-parse stx
    [(mycond fo:maybe-fallthrough-option clause ...)
     #'(mycond* fo.error? fo.who clause ...)]))
]

Defining a splicing syntax class also makes it easy to eliminate the
case analysis we did before using @racket[attribute] by defining
@racket[error?] and @racket[who] as attributes within both of the
syntax class's variants. This is possible to do in the inline pattern
version too, using @racket[~and] and @racket[~parse], but it is less
convenient. Splicing syntax classes also closely parallel the style of
grammars in macro documentation.

@(close-eval the-eval)
