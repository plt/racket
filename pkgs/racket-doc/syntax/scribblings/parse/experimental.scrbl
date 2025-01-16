#lang scribble/doc
@(require scribble/manual
          scribble/struct
          scribble/decode
          scribble/eval
          "parse-common.rkt"
          (for-label syntax/datum))

@(define the-eval (make-sp-eval))

@title{Experimental}

The following facilities are experimental.

@section{Contracts for Macro Sub-expressions}

@defmodule[syntax/parse/experimental/contract]

This module is deprecated; it reprovides @racket[expr/c] for backward
compatibility.

@section{Contracts for Syntax Classes}

@defmodule[syntax/parse/experimental/provide]

@defform[#:literals (syntax-class/c)
         (provide-syntax-class/contract
           [syntax-class-id syntax-class-contract] ...)
         #:grammar
         ([syntax-class-contract
           (syntax-class/c (mandatory-arg ...))
           (syntax-class/c (mandatory-arg ...)
                           (optional-arg ...))]
          [arg contract-expr (code:line keyword contract-expr)])
         #:contracts ([contract-expr contract?])]{

Provides the syntax class (or splicing syntax class)
@racket[syntax-class-id] with the given contracts imposed on its
formal parameters.
}

@defidform[syntax-class/c]{

Keyword recognized by @racket[provide-syntax-class/contract].
}

@section{Reflection}

@defmodule[syntax/parse/experimental/reflect]

A syntax class can be reified into a run-time value, and a reified
syntax class can be used in a pattern via the @racket[~reflect] and
@racket[~splicing-reflect] pattern forms.

@defform[(reify-syntax-class syntax-class-id)]{

Reifies the syntax class named @racket[syntax-class-id] as a run-time
value. The same form also handles splicing syntax classes. Syntax
classes with the @racket[#:no-delimit-cut] option cannot be reified.
}

@deftogether[[
@defproc[(reified-syntax-class? [x any/c]) boolean?]
@defproc[(reified-splicing-syntax-class? [x any/c]) boolean?]
]]{

Returns @racket[#t] if @racket[x] is a reified (normal) syntax class
or a reified splicing syntax class, respectively.
}

@defproc[(reified-syntax-class-attributes
           [r (or/c reified-syntax-class? reified-splicing-syntax-class?)])
         (listof (list/c symbol? exact-nonnegative-integer?))]{

Returns the reified syntax class's attributes.
}

@deftogether[[
@defproc[(reified-syntax-class-arity
           [r (or/c reified-syntax-class? reified-splicing-syntax-class?)])
         procedure-arity?]
@defproc[(reified-syntax-class-keywords
           [r (or/c reified-syntax-class? reified-splicing-syntax-class?)])
         (values (listof keyword?) (listof keyword?))]]]{

Returns the reified syntax class's arity and keywords,
respectively. Compare with @racket[procedure-arity] and
@racket[procedure-keywords].
}

@defproc[(reified-syntax-class-curry
           [r (or/c reified-syntax-class? reified-splicing-syntax-class?)]
           [arg any/c] ...
           [#:<kw> kw-arg any/c] ...)
         (or/c reified-syntax-class? reified-splicing-syntax-class?)]{

Partially applies the reified syntax class to the given arguments. If
more arguments are given than the reified syntax class accepts, an
error is raised.
}

@racketgrammar*[#:literals (~reflect ~splicing-reflect)
                [S-pattern ....
                           (~reflect var-id (reified-expr arg-expr ...) maybe-attrs)]
                [H-pattern ....
                           (~splicing-reflect var-id (reified-expr arg-expr ...)
                                              maybe-attrs)]]

@specsubform[(@#,(defhere ~reflect) var-id (reified-expr arg-expr ...) maybe-attrs)
             #:grammar
         ([maybe-attrs (code:line)
                                  (code:line #:attributes (attr-arity-decl ...))])]{

Like @racket[~var], except that the syntax class position is an
expression evaluating to a reified syntax object, not a syntax class
name, and the attributes bound by the reified syntax class (if any)
must be specified explicitly.
}

@specsubform[(@#,(defhere ~splicing-reflect) var-id (reified-expr arg-expr ...) maybe-attrs)]{

Like @racket[~reflect] but for reified splicing syntax classes.
}

@examples[#:eval the-eval
(define-syntax-class (nat> x)
  #:description (format "natural number greater than ~s" x)
  #:attributes (diff)
  (pattern n:nat
           #:when (> (syntax-e #'n) x)
           #:with diff (- (syntax-e #'n) x)))
(define-syntax-class (nat/mult x)
  #:description (format "natural number multiple of ~s" x)
  #:attributes (quot)
  (pattern n:nat
           #:when (zero? (remainder (syntax-e #'n) x))
           #:with quot (quotient (syntax-e #'n) x)))

(define r-nat> (reify-syntax-class nat>))
(define r-nat/mult (reify-syntax-class nat/mult))

(define (partition/r stx r n)
  (syntax-parse stx
    [((~alt (~reflect yes (r n)) no) ...)
     #'((yes ...) (no ...))]))

(partition/r #'(1 2 3 4 5) r-nat> 3)
(partition/r #'(1 2 3 4 5) r-nat/mult 2)

(define (bad-attrs r)
  (syntax-parse #'6
    [(~reflect x (r 3) #:attributes (diff))
     #'x.diff]))

(bad-attrs r-nat>)
(bad-attrs r-nat/mult)
]

@;{--------}

@section{Procedural Splicing Syntax Classes}

@defmodule[syntax/parse/experimental/splicing]

@defform[(define-primitive-splicing-syntax-class (name-id param-id ...) 
           #:description description-expr
           #:attributes (attr-arity-decl ...)
           parser-expr)
          #:contracts ([parser-expr (-> syntax?
                                        (->* () ((or/c string? #f)) any)
                                        (cons/c exact-positive-integer? list?))])]{

Defines a splicing syntax via a procedural parser.

The parser procedure is given two arguments, the syntax to parse and a
failure procedure. To signal a successful parse, the parser procedure
returns a list of @racket[N]+1 elements, where @racket[N] is the
number of attributes declared by the splicing syntax class. The first
element is the size of the prefix consumed. The rest of the list
contains the values of the attributes.

To indicate failure, the parser calls the failure procedure with an
optional message argument.
}

@;{--------}

@section{Ellipsis-head Alternative Sets}

@defmodule[syntax/parse/experimental/eh]

Unlike @tech{@Spatterns} and @tech{@Hpatterns}, @tech{@EHpatterns}
cannot be encapsulated by syntax classes, since they describe not only
sets of terms but also repetition constraints.

This module provides @deftech{ellipsis-head alternative sets},
reusable encapsulations of @|EHpatterns|.

@defform[#:literals (pattern)
         (define-eh-alternative-set name eh-alternative ...)
         #:grammar
         ([alternative (pattern EH-pattern)])]{

Defines @racket[name] as an ellipsis-head alternative set. Using
@racket[name] (via @racket[~eh-var]) in an ellipsis-head pattern is
equivalent to including each of the alternatives in the pattern via
@racket[~alt], except that the attributes bound by the alternatives
are prefixed with the name given to @racket[~eh-var].

Unlike syntax classes, ellipsis-head alternative sets must be defined
before they are referenced, and they do not delimit cuts (use
@racket[~delimit-cut] instead).
}

@racketgrammar*[#:literals (~eh-var)
                [EH-pattern ....
                            (~eh-var name eh-alternative-set-id)]]

@specsubform[(@#,(defhere ~eh-var) name eh-alternative-set-id)]{

Includes the alternatives of @racket[eh-alternative-set-id], prefixing
their attributes with @racket[name].
}

@examples[#:eval the-eval
(define-eh-alternative-set options
  (pattern (~once (~seq #:a a:expr) #:name "#:a option"))
  (pattern (~seq #:b b:expr)))
(define (parse/options stx)
  (syntax-parse stx
    [(_ (~eh-var s options) ...)
     #'(s.a (s.b ...))]))
(parse/options #'(m #:a 1 #:b 2 #:b 3))
(parse/options #'(m #:a 1 #:a 2))

(define (parse/more-options stx)
  (syntax-parse stx
    [(_ (~alt (~eh-var s options)
              (~seq #:c c1:expr c2:expr))
        ...)
     #'(s.a (s.b ...) ((c1 c2) ...))]))
(parse/more-options #'(m #:a 1 #:b 2 #:c 3 4 #:c 5 6))

(define-eh-alternative-set ext-options
  (pattern (~eh-var s options))
  (pattern (~seq #:c c1 c2)))

(syntax-parse #'(m #:a 1 #:b 2 #:c 3 4 #:c 5 6)
  [(_ (~eh-var x ext-options) ...)
   #'(x.s.a (x.s.b ...) ((x.c1 x.c2) ...))])
]


@section{Syntax Class Specialization}

@defmodule[syntax/parse/experimental/specialize]

@defform[(define-syntax-class/specialize header syntax-class-use)
         #:grammar
         ([header id
                  (id . kw-formals)]
          [syntax-class-use target-stxclass-id
                            (target-stxclass-id arg ...)])]{

Defines @racket[id] as a syntax class with the same attributes,
options (eg, @racket[#:commit], @racket[#:no-delimit-cut]), and
patterns as @racket[target-stxclass-id] but with the given
@racket[arg]s supplied.

@examples[#:eval the-eval
(define-syntax-class/specialize nat>10 (nat> 10))

(syntax-parse #'(11 12) [(n:nat>10 ...) 'ok])
(syntax-parse #'(8 9) [(n:nat>10 ...) 'ok])
]
}


@section{Syntax Templates}

@defmodule[syntax/parse/experimental/template]

@deftogether[[
@defform[(template tmpl)]
@defform[(template/loc loc-expr tmpl)]
@defform[(quasitemplate tmpl)]
@defform[(quasitemplate/loc loc-expr tmpl)]
]]{

Equivalent to @racket[syntax], @racket[syntax/loc],
@racket[quasisyntax], and @racket[quasisyntax/loc], respectively.
}

@defform[(datum-template tmpl)]{

Equivalent to @racket[datum].
}

@deftogether[[
@defidform[??]
@defidform[?@]
]]{

Equivalent to @racket[~?] and @racket[~@], respectively.
}

@defform*[[(define-template-metafunction metafunction-id expr)
           (define-template-metafunction (metafunction-id . formals) body ...+)]]{

Defines @racket[metafunction-id] as a @deftech{template
metafunction}. A metafunction application in a @racket[syntax]
or @racket[template] expression is evaluated by
applying the metafunction to the result of processing the ``argument''
part of the template.

@examples[#:eval the-eval
(define-template-metafunction (join stx)
  (syntax-parse stx
    [(join (~optional (~seq #:lctx lctx)) a:id b:id ...)
     (datum->syntax (or (attribute lctx) #'a)
                    (string->symbol
                     (apply string-append
                            (map symbol->string
                                 (syntax->datum #'(a b ...)))))
                    stx)]))
(template (join a b c))
(with-syntax ([(x ...) #'(a b c)])
  (template ((x (join tmp- x)) ...)))
]

Metafunctions are useful for performing transformations in contexts
where macro expansion does not occur, such as binding occurrences. For
example:

@interaction[#:eval the-eval
(syntax->datum 
 (with-syntax ([name #'posn]
               [(field ...) #'(x y)])
   (template (let-values ([((join name ?) 
                            (join #:lctx name make- name)
                            (join name - field) ...)
                           (make-struct-type ___)])
               ___))))
]

If @racket[join] were defined as a macro, it would not be usable in
the context above; instead, @racket[let-values] would report an
invalid binding list.
}

@deftogether[
 ((defthing prop:template-metafunction struct-type-property?)
  (defthing template-metafunction? (-> any/c boolean?)))]{

 A structure type property, and the associated predicate. The property value is
 one of:

 @itemlist[
   @item{an identifier bound to a run-time procedure implementing the
         metafunction}
   @item{the index of a field containing such an an identifier}
   @item{a procedure that takes an instance of the structure and produces
         such an identifier}]

 The metafunction's implementation should accept a syntax object representing
 its use, and produce a new syntax object as a result.

 When an identifier is bound as syntax to a structure instance with this
 property, it is treated as a template metafunction as if the identifier had
 been declared with @racket[define-template-metafunction].

 @examples[#:eval the-eval
           (define (my-metafunction-proc stx)
             (syntax-case stx ()
               [(_ n) (datum->syntax #'n (add1 (syntax-e #'n)) #'n #'n)]))

           (begin-for-syntax
             (struct mf-struct (proc-id)
               #:property prop:template-metafunction
                          (struct-field-index proc-id)))

           (define-syntax mf (mf-struct #'my-metafunction-proc))

           #'(mf 3)
           (with-syntax ([(x ...) #'(1 2 3)])
             #'((mf x) ...))]

 In the example below, a @racketid[macro] defined as a phase 0 syntax
 transformer refers to a phase 1 @racketid[macro-implementation]. In other
 words, the implementation is a phase 1 expression, which runs at compile-time
 with respect to the phase 0 code. Such a macro can make use of template
 metafunctions inside its uses of @racket[#'…]. These metafunctions will be
 implemented by phase 1 functions, i.e. they run at compile-time with respect to
 the phase 0 code, and run at the same phase as the macro's code. The
 @racketid[metafunction-identifier] is bound as phase 1 syntax transformers
 which contain, via @racket[prop:template-metafunction], the name of the phase 1
 function implementing the metafunction.

 @examples[#:eval the-eval
           (require (for-syntax racket/base))
           (require (for-meta 2 racket/base))
           (begin-for-syntax
             (define (macro-implementation stx)
               #'(metafunction-identifier metafunction-arguments)))
           (define-syntax macro macro-implementation)
           
           ]

 @history[#:added "8.2"]}

@(close-eval the-eval)
