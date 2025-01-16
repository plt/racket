#lang scribble/doc
@(require scribble/manual
          scribble/struct
          scribble/decode
          scribble/eval
          "../common.rkt"
          "parse-common.rkt"
          (for-label racket/syntax))

@(define the-eval (make-sp-eval))

@title{Parsing Syntax}

This section describes @racket[syntax-parse], the
@racketmodname[syntax/parse] library's facility for parsing
syntax. Both @racket[syntax-parse] and the specification facility,
@seclink["stxparse-specifying"]{syntax classes}, use a common language
of @tech{syntax patterns}, which is described in detail in
@secref{stxparse-patterns}.

@declare-exporting[syntax/parse]

Two parsing forms are provided: @racket[syntax-parse] and
@racket[syntax-parser].

@defform[(syntax-parse stx-expr parse-option ... clause ...+)
         #:grammar
         ([parse-option (code:line #:context context-expr)
                        (code:line #:literals (literal ...))
                        (code:line #:datum-literals (datum-literal ...))
                        (code:line #:literal-sets (literal-set ...))
                        #:track-literals
                        (code:line #:conventions (convention-id ...))
                        (code:line #:local-conventions (convention-rule ...))
                        (code:line #:disable-colon-notation)]
          [literal literal-id
                   (pattern-id literal-id)
                   (pattern-id literal-id #:phase phase-expr)]
          [datum-literal literal-id
                         (pattern-id literal-id)]
          [literal-set literal-set-id
                       (literal-set-id literal-set-option ...)]
          [literal-set-option (code:line #:at context-id)
                              (code:line #:phase phase-expr)]
          [clause (syntax-pattern pattern-directive ... body ...+)])
         #:contracts ([stx-expr syntax?]
                      [context-expr (or/c syntax? symbol? #f
                                          (list/c symbol? syntax?))]
                      [phase-expr (or/c exact-integer? #f)])]{

Evaluates @racket[stx-expr], which should produce a syntax object, and
matches it against the @racket[clause]s in order. If some clause's
pattern matches, its attributes are bound to the corresponding
subterms of the syntax object and that clause's side conditions and
@racket[expr] is evaluated. The result is the result of @racket[expr].

Each clause consists of a @tech{syntax pattern}, an optional sequence
of @tech{pattern directives}, and a non-empty sequence of body
forms.

If the syntax object fails to match any of the patterns (or all
matches fail the corresponding clauses' side conditions), a syntax
error is raised. 

The following options are supported:

@specsubform[(code:line #:context context-expr)
             #:contracts
             ([context-expr (or/c syntax? symbol? #f
                                  (list/c symbol? syntax?))])]{

When present, @racket[context-expr] is used in reporting parse
failures; otherwise @racket[stx-expr] is used. If
@racket[context-expr] evaluates to @racket[(list _who _context-stx)],
then @racket[_who] appears in the error message as the form raising
the error, and @racket[_context-stx] is used as the term. If
@racket[context-expr] evaluates to a symbol, it is used as
@racket[_who] and @racket[stx-expr] (the syntax to be destructured) is
used as @racket[_context-stx]. If @racket[context-expr] evaluates to a
syntax object, it is used as @racket[_context-stx] and @racket[_who]
is inferred as with @racket[raise-syntax-error].

The @racket[current-syntax-context] parameter is also set to the
syntax object @racket[_context-stx].

@examples[#:eval the-eval
(syntax-parse #'(a b 3)
  [(x:id ...) 'ok])
(syntax-parse #'(a b 3)
  #:context #'(lambda (a b 3) (+ a b))
  [(x:id ...) 'ok])
(syntax-parse #'(a b 3)
  #:context 'check-id-list
  [(x:id ...) 'ok])
]
}

@specsubform[(code:line #:literals (literal ...))
             #:grammar
             ([literal literal-id
                       (pattern-id literal-id)
                       (pattern-id literal-id #:phase phase-expr)])
             #:contracts ([phase-expr (or/c exact-integer? #f)])]{

@margin-note*{
  Unlike @racket[syntax-case], @racket[syntax-parse] requires all
  literals to have a binding. To match identifiers by their symbolic
  names, use @racket[#:datum-literals] or the @racket[~datum] pattern
  form instead.
}
@;
The @racket[#:literals] option specifies identifiers that should be
treated as @tech{literals} rather than @tech{pattern variables}. An
entry in the literals list has two components: the identifier used
within the pattern to signify the positions to be matched
(@racket[pattern-id]), and the identifier expected to occur in those
positions (@racket[literal-id]). If the entry is a single identifier,
that identifier is used for both purposes.

If the @racket[#:phase] option is given, then the literal is compared
at phase @racket[phase-expr]. Specifically, the binding of the
@racket[literal-id] at phase @racket[phase-expr] must match the
input's binding at phase @racket[phase-expr].

In other words, the @racket[syntax-pattern]s are interpreted as if each
occurrence of @racket[pattern-id] were replaced with the following pattern:
@racketblock[(~literal literal-id #:phase phase-expr)]
}

@specsubform[(code:line #:datum-literals (datum-literal ...))
             #:grammar
             ([datum-literal literal-id
                             (pattern-id literal-id)])]{

Like @racket[#:literals], but the literals are matched as symbols
instead of as identifiers.

In other words, the @racket[syntax-pattern]s are interpreted as if each
occurrence of @racket[pattern-id] were replaced with the following
pattern:
@racketblock[(~datum literal-id)]
}

@specsubform[(code:line #:literal-sets (literal-set ...))
             #:grammar
             ([literal-set literal-set-id
                           (literal-set-id literal-set-option ...)]
              [literal-set-option (code:line #:at lctx)
                                  (code:line #:phase phase-expr)])
             #:contracts ([phase-expr (or/c exact-integer? #f)])]{

Many literals can be declared at once via one or more @tech{literal
sets}, imported with the @racket[#:literal-sets] option. See
@tech{literal sets} for more information.

If the @racket[#:at] keyword is given, the lexical context of the
@racket[lctx] term is used to determine which identifiers in the
patterns are treated as literals; this option is useful primarily for
macros that generate @racket[syntax-parse] expressions.
}

@specsubform[(code:line #:track-literals)]{

If specified, each final @racket[body] expression is further constrained to
produce a single value, which must be a @tech[#:doc refman]{syntax object}, and
its @racket['disappeared-use] @tech[#:doc refman]{syntax property} is
automatically extended to include literals matched as part of pattern-matching.
Literals are automatically tracked from uses of @racket[#:literals],
@racket[#:literal-sets], or @racket[~literal], but they can also be manually
tracked using @racket[syntax-parse-state-cons!]. The property is added or
extended in the same way as a property added by
@racket[syntax-parse-track-literals].

Due to the way the @racket[body] forms are wrapped, specifying this option means
the final @racket[body] form will no longer be in tail position with respect to
the enclosing @racket[syntax-parse] form.

@history[#:added "6.90.0.29"]}

@specsubform[(code:line #:conventions (conventions-id ...))]{

Imports @tech{convention}s that give default syntax classes to pattern
variables that do not explicitly specify a syntax class.
}

@specsubform[(code:line #:local-conventions (convention-rule ...))]{

Uses the @tech{conventions} specified. The advantage of
@racket[#:local-conventions] over @racket[#:conventions] is that local
conventions can be in the scope of syntax-class parameter
bindings. See the section on @tech{conventions} for examples.
}

@specsubform[(code:line #:disable-colon-notation)]{

Suppresses the ``colon notation'' for annotated pattern variables.

@examples[#:eval the-eval
(syntax-parse #'(a b c)
  [(x:y ...) 'ok])
(syntax-parse #'(a b c) #:disable-colon-notation
  [(x:y ...) 'ok])
]
}
}

@defform[(syntax-parser parse-option ... clause ...+)]{

Like @racket[syntax-parse], but produces a matching procedure. The
procedure accepts a single argument, which should be a syntax
object. The syntax object is accessible within the body of the form
via @racket[this-syntax].
}

@defform[(define/syntax-parse syntax-pattern pattern-directive ... stx-expr)
         #:contracts ([stx-expr syntax?])]{

Definition form of @racket[syntax-parse]. That is, it matches the
syntax object result of @racket[stx-expr] against
@racket[syntax-pattern] and creates pattern variable definitions for
the attributes of @racket[syntax-pattern].

@examples[#:eval the-eval
(define/syntax-parse ((~seq kw:keyword arg:expr) ...)
  #'(#:a 1 #:b 2 #:c 3))
#'(kw ...)
]

Compare with @racket[define/with-syntax], a similar definition form
that uses the simpler @racket[syntax-case] patterns.
}

@(close-eval the-eval)
