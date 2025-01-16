#lang scribble/doc
@(require scribble/manual scribble/eval "guide-utils.rkt")

@title[#:tag "application"]{Function Calls@aux-elem{ (Procedure Applications)}}

An expression of the form

@specsubform[
(proc-expr arg-expr ...)
]

is a function call---also known as a @defterm{procedure
application}---when @racket[_proc-expr] is not an identifier that is
bound as a syntax transformer (such as @racket[if] or
@racket[define]).

@section{Evaluation Order and Arity}

A function call is evaluated by first evaluating the
@racket[_proc-expr] and all @racket[_arg-expr]s in order (left to
right). Then, if @racket[_proc-expr] produces a function that accepts
as many arguments as supplied @racket[_arg-expr]s, the function is
called. Otherwise, an exception is raised.

@examples[
(cons 1 null)
(+ 1 2 3)
(cons 1 2 3)
(1 2 3)
]

Some functions, such as @racket[cons], accept a fixed number of
arguments. Some functions, such as @racket[+] or @racket[list], accept
any number of arguments. Some functions accept a range of argument
counts; for example @racket[substring] accepts either two or three
arguments. A function's @idefterm{arity} is the number of arguments
that it accepts.

@;------------------------------------------------------------------------
@section[#:tag "keyword-args"]{Keyword Arguments}

Some functions accept @defterm{keyword arguments} in addition to
by-position arguments. For that case, an @racket[_arg] can be an
@racket[_arg-keyword _arg-expr] sequence instead of just a
@racket[_arg-expr]:

@guideother{@secref["keywords"] introduces keywords.}

@specform/subs[
(_proc-expr arg ...)
([arg arg-expr
      (code:line arg-keyword arg-expr)])
]

For example,

@def+int[
(define (go file-name  #:mode mode-name)
  (println (string-append "filename: " file-name))
  (println (string-append "mode-name: " mode-name)))
]
@racketblock[(go "super.rkt" #:mode "fast")]

calls the function bound to @racket[go] with @racket["super.rkt"] as a
by-position argument, and with @racket["fast"] as an argument
associated with the @racket[#:mode] keyword. A keyword is implicitly
paired with the expression that follows it.

Since a keyword by itself is not an expression, then

@racketblock[(go "super.rkt" #:mode #:fast)]

is a syntax error. The @racket[#:mode] keyword must be followed by an
expression to produce an argument value, and @racket[#:fast] is not an
expression.

The order of keyword @racket[_arg]s determines the order in which
@racket[_arg-expr]s are evaluated, but a function accepts keyword
arguments independent of their position in the argument list. The
above call to @racket[go] can be equivalently written

@racketblock[(go #:mode "fast" "super.rkt")]

@refdetails["application"]{procedure applications}

@;------------------------------------------------------------------------
@section[#:tag "apply"]{The @racket[apply] Function}

The syntax for function calls supports any number of arguments, but a
specific call always specifies a fixed number of arguments. As a
result, a function that takes a list of arguments cannot directly
apply a function like @racket[+] to all of the items in a list:

@def+int[
(define (avg lst) (code:comment @#,elem{doesn't work...})
  (/ (+ lst) (length lst)))
(avg '(1 2 3))
]

@def+int[
(define (avg lst) (code:comment @#,elem{doesn't always work...})
  (/ (+ (list-ref lst 0) (list-ref lst 1) (list-ref lst 2))
     (length lst)))
(avg '(1 2 3))
(avg '(1 2))
]

The @racket[apply] function offers a way around this restriction. It
takes a function and a @italic{list} argument, and it applies the
function to the values in the list:

@def+int[
(define (avg lst)
  (/ (apply + lst) (length lst)))
(avg '(1 2 3))
(avg '(1 2))
(avg '(1 2 3 4))
]

As a convenience, the @racket[apply] function accepts additional
arguments between the function and the list. The additional arguments
are effectively @racket[cons]ed onto the argument list:

@def+int[
(define (anti-sum lst)
  (apply - 0 lst))
(anti-sum '(1 2 3))
]

The @racket[apply] function accepts keyword arguments, too, and it
passes them along to the called function:

@racketblock[
(apply go #:mode 'fast '("super.rkt"))
(apply go '("super.rkt") #:mode 'fast)
]

Keywords that are included in @racket[apply]'s list argument do not
count as keyword arguments for the called function; instead, all arguments in
this list are treated as by-position arguments. To pass a list of
keyword arguments to a function, use
the @racket[keyword-apply] function, which accepts a function to apply
and three lists. The first two lists are in parallel, where the first
list contains keywords (sorted by @racket[keyword<?]), and the second
list contains a corresponding argument for each keyword. The third
list contains by-position function arguments, as for @racket[apply].

@racketblock[
(keyword-apply go
               '(#:mode)
               '(fast)
               '("super.rkt"))
]
