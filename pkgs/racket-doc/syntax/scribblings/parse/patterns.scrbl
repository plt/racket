#lang scribble/doc
@(require scribble/manual
          scribble/struct
          scribble/decode
          scribble/eval
          "parse-common.rkt")

@(define the-eval (make-sp-eval))

@(define-syntax-rule (define-dotsplus-names dotsplus def-dotsplus)
   (begin (require (for-label (only-in syntax/parse ...+)))
          (define dotsplus (racket ...+))
          (define def-dotsplus (defhere ...+))))
@(define-dotsplus-names dotsplus def-dotsplus)

@title[#:tag "stxparse-patterns"]{Syntax Patterns}

The grammar of @deftech{syntax patterns} used by
@racketmodname[syntax/parse] facilities is given in the following
table. There are four main kinds of syntax pattern:
@itemize[
@item{@tech{@Spatterns}, abbreviated @svar[S-pattern]}
@item{@tech{@Hpatterns}, abbreviated @svar[H-pattern]}
@item{@tech{@EHpatterns}, abbreviated @svar[EH-pattern]}
@item{@tech{@Apatterns}, abbreviated @svar[A-pattern]}
]
A fifth kind, @tech{@Lpatterns} (abbreviated
@svar[L-pattern]), is just a syntactically restricted subset of
@tech{@Spatterns}.

When a special form in this manual refers to @svar[syntax-pattern]
(eg, the description of the @racket[syntax-parse] special form), it
means specifically @tech{@Spattern}.

@racketgrammar*[#:literals (_ ~var ~literal ~or ~alt ~or* ~and ~not ~rest ~datum
                            ~describe ~seq ~optional ~rep ~once ~between
                            ~! ~bind ~fail ~parse ~peek ~peek-not ~do ~undo ~post)
                [S-pattern
                 pvar-id
                 pvar-id:syntax-class-id
                 pvar-id:literal-id
                 literal-id
                 (@#,ref[~var s-] id)
                 (@#,ref[~var s+] id syntax-class-id maybe-role)
                 (@#,ref[~var s+] id (syntax-class-id arg ...) maybe-role)
                 (~literal literal-id maybe-phase)
                 atomic-datum
                 (~datum datum)
                 (H-pattern . S-pattern)
                 (A-pattern . S-pattern)
                 (EH-pattern #,ellipses . S-pattern)
                 (H-pattern @#,dotsplus . S-pattern)
                 (@#,ref[~and s] proper-S/A-pattern ...+)
                 (@#,ref[~or* s] S-pattern ...+)
                 (~not S-pattern)
                 #((unsyntax @svar[pattern-part]) ...)
                 #s(prefab-struct-key (unsyntax @svar[pattern-part]) ...)
                 #&@#,svar[S-pattern]
                 (~rest S-pattern)
                 (@#,ref[~describe s] maybe-opaque maybe-role expr S-pattern)
                 (@#,ref[~commit s] S-pattern)
                 (@#,ref[~delimit-cut s] S-pattern)
                 (@#,ref[~post s] S-pattern)
                 A-pattern]
                [L-pattern
                 ()
                 (A-pattern . L-pattern)
                 (H-pattern . L-pattern)
                 (EH-pattern #,ellipses . L-pattern)
                 (H-pattern @#,dotsplus . L-pattern)
                 (~rest L-pattern)]
                [H-pattern
                 pvar-id:splicing-syntax-class-id
                 (@#,ref[~var h] id splicing-syntax-class-id maybe-role)
                 (@#,ref[~var h] id (splicing-syntax-class-id arg ...) 
                                 maybe-role)
                 (~seq . L-pattern)
                 (@#,ref[~and h] proper-H/A-pattern ...+)
                 (@#,ref[~or* h] H-pattern ...+)
                 (@#,ref[~optional h] H-pattern maybe-optional-option)
                 (@#,ref[~describe h] maybe-opaque maybe-role expr H-pattern)
                 (@#,ref[~commit h] H-pattern)
                 (@#,ref[~delimit-cut h] H-pattern)
                 (@#,ref[~post h] H-patter)
                 (~peek H-pattern)
                 (~peek-not H-pattern)
                 proper-S-pattern]
                [EH-pattern
                 (~alt EH-pattern ...)
                 (~once H-pattern once-option ...)
                 (@#,ref[~optional eh] H-pattern optional-option ...)
                 (~between H min-number max-number between-option)
                 H-pattern]
                [A-pattern
                 ~!
                 (~bind [attr-arity-decl expr] ...)
                 (~fail maybe-fail-condition maybe-message-expr)
                 (~parse S-pattern stx-expr)
                 (@#,ref[~and a] A-pattern ...+)
                 (@#,ref[~post a] A-pattern)
                 (~do defn-or-expr ...)
                 (~undo defn-or-expr ...)]
                [proper-S-pattern
                 #, @elem{a @svar{S-pattern} that is not a @svar{A-pattern}}]
                [proper-H-pattern
                 #, @elem{a @svar{H-pattern} that is not a @svar{S-pattern}}]]

The following pattern keywords can be used in multiple pattern
variants:

@defidform[~var]{

One of @ref[~var s-], @ref[~var s+], or @ref[~var h].
}

@defidform[~and]{

One of @ref[~and s], @ref[~and h], or @ref[~and a]:
@itemize[
@item{@ref[~and a] if all of the conjuncts are @tech{@Apatterns}}
@item{@ref[~and h] if any of the conjuncts is a @tech{proper
@Hpattern}}
@item{@ref[~and s] otherwise}
]
}

@defidform[~or*]{

One of @ref[~or* s] or @ref[~or* h]:
@itemize[
@item{@ref[~or* h] if any of the disjuncts is a @tech{proper @Hpattern}}
@item{@ref[~or* s] otherwise}
]
}

@defidform[~or]{

Behaves like @ref[~or* s], @ref[~or* h], or @racket[~alt]:
@itemize[
@item{like @racket[~alt] if the pattern occurs directly before ellipses
  (@ellipses) or immediately within another @racket[~alt] pattern}
@item{like @ref[~or* h] if any of the disjuncts is a @tech{proper @Hpattern}}
@item{like @ref[~or* s] otherwise}
]

The context-sensitive interpretation of @racket[~or] is a design
mistake and a common source of confusion. Use @racket[~alt] and
@racket[~or*] instead.
}

@defidform[~describe]{

One of @ref[~describe s] or @ref[~describe h]:
@itemize[
@item{@ref[~describe h] if the subpattern is a @tech{proper @Hpattern}}
@item{@ref[~describe s] otherwise}
]
}

@defidform[~commit]{

One of @ref[~commit s] or @ref[~commit h]:
@itemize[
@item{@ref[~commit h] if the subpattern is a @tech{proper @Hpattern}}
@item{@ref[~commit s] otherwise}
]
}

@defidform[~delimit-cut]{

One of @ref[~delimit-cut s] or @ref[~delimit-cut h]:
@itemize[
@item{@ref[~delimit-cut h] if the subpattern is a @tech{proper @Hpattern}}
@item{@ref[~delimit-cut s] otherwise}
]
}

@defidform[~post]{

One of @ref[~post s], @ref[~post h], or @ref[~post a]:
@itemize[
@item{@ref[~post a] if the subpattern is an @tech{@Apattern}}
@item{@ref[~post h] if the subpattern is a @tech{proper @Hpattern}}
@item{@ref[~post s] otherwise}
]
}

@defidform[~optional]{

One of @ref[~optional h] or @ref[~optional eh]:
@itemize[
@item{@ref[~optional eh] if it is an immediate disjunct of an @racket[~alt] pattern}
@item{@ref[~optional h] otherwise}
]
}


@;{--------}

@section{Single-term Patterns}

A @deftech{@Spattern} (abbreviated @svar[S-pattern]) is a pattern that
describes a single term. These are like the traditional patterns used
in @racket[syntax-rules] and @racket[syntax-case], but with additional
variants that make them more expressive.

``Single-term'' does not mean ``atomic''; a @Spattern can have
complex structure, and it can match terms that have many parts. For
example, @racket[(17 ...)] is a @Spattern that matches any
term that is a proper list of repeated @racketresult[17] numerals.

A @deftech{proper @Spattern} is one that is not an @tech{@Apattern}.

The @deftech{@Lpatterns} (for ``list pattern'') are @Spatterns
having a restricted structure that guarantees that they match only
terms that are proper lists.

Here are the variants of @elem{@Spattern}:

@specsubform[id]{

An identifier can be either a @tech{pattern variable}, an
@tech{annotated pattern variable}, or a @tech{literal}:

@itemize[

@item{If @racket[id] is the ``pattern'' name of an entry in the
  literals list, it is a @tech{literal} pattern that behaves
  like @racket[(~literal id)].

  @examples[#:eval the-eval
    (syntax-parse #'(define x 12)
      #:literals (define)
      [(define var:id body:expr) 'ok])
    (syntax-parse #'(lambda x 12)
      #:literals (define)
      [(define var:id body:expr) 'ok])
    (syntax-parse #'(define x 12)
      #:literals ([def define])
      [(def var:id body:expr) 'ok])
    (syntax-parse #'(lambda x 12)
      #:literals ([def define])
      [(def var:id body:expr) 'ok])
  ]
}

@item{If @racket[id] is of the form @racket[_pvar-id:syntax-class-id]
  (that is, two names joined by a colon character), it is an
  @tech{annotated pattern variable}, and the pattern is equivalent to
  @racket[(~var _pvar-id _syntax-class-id)].

  @examples[#:eval the-eval
    (syntax-parse #'a
      [var:id (syntax-e #'var)])
    (syntax-parse #'12
      [var:id (syntax-e #'var)])
    (define-syntax-class two
      #:attributes (x y)
      (pattern (x y)))
  (syntax-parse #'(a b)
    [t:two (syntax->datum #'(t t.x t.y))])
  (syntax-parse #'(a b)
    [t
     #:declare t two
     (syntax->datum #'(t t.x t.y))])
  ]

  Note that an @racket[id] of the form @racket[_:syntax-class-id] is
  legal; see the discussion of a @ref[~var s+] form with a zero-length
  @svar[pvar-id].
}

@item{If @racket[id] is of the form @racket[_pvar-id:literal-id],
  where @racket[_literal-id] is in the literals list, then it is
  equivalent to @racket[(~and (~var _pvar-id) literal-id)].

  @examples[#:eval the-eval
    (require (only-in racket/base [define def]))
    (syntax-parse #'(def x 7)
      #:literals (define)
      [(d:define var:id body:expr) #'d])
  ]
}

@item{Otherwise, @racket[id] is a @tech{pattern variable}, and the
pattern is equivalent to @racket[(~var id)].
}
]
}

@specsubform[(@#,def[~var s-] pvar-id)]{

A @deftech{pattern variable}. If @racket[pvar-id] has no syntax class
(by @racket[#:convention]), the pattern variable matches anything. The
pattern variable is bound to the matched subterm, unless the pattern
variable is the wildcard (@racket[_]), in which case no binding
occurs.

If @racket[pvar-id] does have an associated syntax class, it behaves
like an @tech{annotated pattern variable} with the implicit syntax
class inserted.
}

@specsubform[(@#,def[~var s+] pvar-id syntax-class-use maybe-role)
             #:grammar
             ([syntax-class-use syntax-class-id
                                (syntax-class-id arg ...)]
              [maybe-role (code:line)
                          (code:line #:role role-expr)])
             #:contracts ([role-expr (or/c string? #f)])]{

An @deftech{annotated pattern variable}. The pattern matches only
terms accepted by @svar[syntax-class-id] (parameterized by the
@racket[arg]s, if present).

In addition to binding @svar[pvar-id], an annotated pattern
variable also binds @deftech{nested attributes} from the syntax
class. The names of the nested attributes are formed by prefixing
@svar[pvar-id.] (that is, @svar[pvar-id] followed by a ``dot''
character) to the name of the syntax class's attribute.

If @svar[pvar-id] is @racket[_], no attributes are bound.  If
@svar[pvar-id] is the zero-length identifier (@racket[||]), then
@svar[pvar-id] is not bound, but the nested attributes of
@racket[syntax-class-use] are bound without prefixes.

If @racket[role-expr] is given and evaluates to a string, it is
combined with the syntax class's description in error messages.

@examples[#:eval the-eval
(syntax-parse #'a
  [(~var var id) (syntax-e #'var)])
(syntax-parse #'12
  [(~var var id) (syntax-e #'var)])
(define-syntax-class two
  #:attributes (x y)
  (pattern (x y)))
(syntax-parse #'(a b)
  [(~var t two) (syntax->datum #'(t t.x t.y))])
(define-syntax-class (nat-less-than n)
  (pattern x:nat #:when (< (syntax-e #'x) n)))
(syntax-parse #'(1 2 3 4 5)
  [((~var small (nat-less-than 4)) ... large:nat ...)
   (list #'(small ...) #'(large ...))])
(syntax-parse #'(m a b 3)
  [(_ (~var x id #:role "variable") ...) 'ok])
]
}

@specsubform[(@#,defhere[~literal] literal-id maybe-phase)
             #:grammar
             ([maybe-phase (code:line)
                           (code:line #:phase phase-expr)])]{

A @deftech{literal} identifier pattern. Matches any identifier
@racket[free-identifier=?] to @racket[literal-id].

@examples[#:eval the-eval
(syntax-parse #'(define x 12)
  [((~literal define) var:id body:expr) 'ok])
(syntax-parse #'(lambda x 12)
  [((~literal define) var:id body:expr) 'ok])
]

The identifiers are compared at the phase given by
@racket[phase-expr], if it is given, or
@racket[(syntax-local-phase-level)] otherwise.
}

@specsubform[atomic-datum]{

Numbers, strings, booleans, keywords, and the empty list match as
literals.

@examples[#:eval the-eval
(syntax-parse #'(a #:foo bar)
  [(x #:foo y) (syntax->datum #'y)])
(syntax-parse #'(a foo bar)
  [(x #:foo y) (syntax->datum #'y)])
]
}

@specsubform[(@#,defhere[~datum] datum)]{

Matches syntax whose S-expression contents (obtained by
@racket[syntax->datum]) is @racket[equal?] to the given
@racket[datum].

@examples[#:eval the-eval
(syntax-parse #'(a #:foo bar)
  [(x (~datum #:foo) y) (syntax->datum #'y)])
(syntax-parse #'(a foo bar)
  [(x (~datum #:foo) y) (syntax->datum #'y)])
]

The @racket[~datum] form is useful for recognizing identifiers
symbolically, in contrast to the @racket[~literal] form, which
recognizes them by binding.

@examples[#:eval the-eval
(define-syntax (is-define? stx)
  (syntax-parse stx
    [(_is-define? id)
     (syntax-parse #'id
       [(~literal define) #''yes]
       [(~datum   define) #''not-really]
       [_                 #''not-even-close])]))
(is-define? define)
(let ([define 42])
  (is-define? define))
(is-define? something-else)
]
}

@specsubform[(H-pattern . S-pattern)]{

Matches any term that can be decomposed into a list prefix matching
@racket[H-pattern] and a suffix matching @racket[S-pattern].

Note that the pattern may match terms that are not even improper
lists; if the head pattern can match a zero-length head, then the
whole pattern matches whatever the tail pattern accepts.

The first pattern can be a @tech{@Spattern}, in which case the whole
pattern matches any pair whose first element matches the first pattern
and whose rest matches the second.

See @tech{@Hpatterns} for more information.
}

@specsubform[(A-pattern . S-pattern)]{

Performs the actions specified by @racket[A-pattern], then matches
any term that matches @racket[S-pattern].

Pragmatically, one can throw an @tech{@Apattern} into any list
pattern. Thus, @racket[(x y z)] is a pattern matching a list of three
terms, and @racket[(x y ~! z)] is a pattern matching a list of three
terms, with a @tech{cut} performed after the second one. In other
words, @Apatterns ``don't take up space.''

See @tech{@Apatterns} for more information.
}

@specsubform[(EH-pattern #,ellipses . S-pattern)]{

Matches any term that can be decomposed into a list head matching some
number of repetitions of the @racket[EH-pattern] alternatives (subject
to its repetition constraints) followed by a list tail matching
@racket[S-pattern].

In other words, the whole pattern matches either the second pattern
(which need not be a list) or a term whose head matches one of the
alternatives of the first pattern and whose tail recursively matches
the whole sequence pattern.

See @tech{@EHpatterns} for more information.
}

@specsubform[(H-pattern @#,def-dotsplus . S-pattern)]{

Like an ellipses (@ellipses) pattern, but requires at least one occurrence
of the head pattern to be present.

That is, the following patterns are equivalent:
@itemize[
@item[@racket[(H @#,dotsplus . S)]]
@item[@racket[((~between H 1 +inf.0) ... . S)]]
]

@examples[#:eval the-eval
(syntax-parse #'(1 2 3)
  [(n:nat ...+) 'ok])
(syntax-parse #'()
  [(n:nat ...+) 'ok]
  [_ 'none])
]

}

@specsubform[(@#,def[~and s] S/A-pattern ...)]{

Matches any term that matches all of the subpatterns.

The subpatterns can contain a mixture of @tech{@Spatterns} and
@tech{@Apatterns}, but must contain at least one @tech{@Spattern}.

Attributes bound in subpatterns are available to subsequent
subpatterns. The whole pattern binds all of the subpatterns'
attributes.

One use for @racket[~and]-patterns is preserving a whole
term (including its lexical context, source location, etc) while also
examining its structure. Syntax classes are useful for the same
purpose, but @racket[~and] can be lighter weight.

@examples[#:eval the-eval
(define-syntax (import stx)
  (raise-syntax-error #f "illegal use of import" stx))
(eval:alts
  (define (check-imports stx) ....)
  (define (check-imports . _) #f))
(syntax-parse #'(m (import one two))
  #:literals (import)
  [(_ (~and import-clause (import i ...)))
   (let ([bad (check-imports
               (syntax->list #'(i ...)))])
     (when bad
       (raise-syntax-error
        #f "bad import" #'import-clause bad))
     'ok)])
]
}

@specsubform[(@#,def[~or* s] S-pattern ...)]{

Matches any term that matches one of the included patterns. The
alternatives are tried in order.

The whole pattern binds @emph{all} of the subpatterns' attributes. An
attribute that is not bound by the ``chosen'' subpattern has a value
of @racket[#f]. The same attribute may be bound by multiple
subpatterns, and if it is bound by all of the subpatterns, it is sure
to have a value if the whole pattern matches.

@examples[#:eval the-eval
(syntax-parse #'a
  [(~or* x:id y:nat) (values (attribute x) (attribute y))])
(syntax-parse #'(a 1)
  [(~or* (x:id y:nat) (x:id)) (values #'x (attribute y))])
(syntax-parse #'(b)
  [(~or* (x:id y:nat) (x:id)) (values #'x (attribute y))])
]
}

@specsubform[(@#,defhere[~not] S-pattern)]{

Matches any term that does not match the subpattern. None of the
subpattern's attributes are bound outside of the
@racket[~not]-pattern.

@examples[#:eval the-eval
(syntax-parse #'(x y z => u v)
  #:literals (=>)
  [((~and before (~not =>)) ... => after ...)
   (list #'(before ...) #'(after ...))])
]
}

@specsubform[#(#, @svar[pattern-part] ...)]{

Matches a term that is a vector whose elements, when considered as a
list, match the @tech{@Spattern} corresponding to
@racket[(pattern-part ...)].

@examples[#:eval the-eval
(syntax-parse #'#(1 2 3)
  [#(x y z) (syntax->datum #'z)])
(syntax-parse #'#(1 2 3)
  [#(x y ...) (syntax->datum #'(y ...))])
(syntax-parse #'#(1 2 3)
  [#(x ~rest y) (syntax->datum #'y)])
]
}

@specsubform[#s(prefab-struct-key #, @svar[pattern-part] ...)]{

Matches a term that is a prefab struct whose key is exactly the given
key and whose sequence of fields, when considered as a list, match the
@tech{@Spattern} corresponding to @racket[(pattern-part ...)].

@examples[#:eval the-eval
(syntax-parse #'#s(point 1 2 3)
  [#s(point x y z) 'ok])
(syntax-parse #'#s(point 1 2 3)
  [#s(point x y ...) (syntax->datum #'(y ...))])
(syntax-parse #'#s(point 1 2 3)
  [#s(point x ~rest y) (syntax->datum #'y)])
]
}

@specsubform[#&@#,svar[S-pattern]]{ 

Matches a term that is a box whose contents matches the inner
@tech{@Spattern}.

@examples[#:eval the-eval
(syntax-parse #'#&5
  [#&n:nat 'ok])
]
}

@specsubform[(#, @defhere[~rest] S-pattern)]{

Matches just like @racket[S-pattern]. The @racket[~rest] pattern form
is useful in positions where improper (``dotted'') lists are not
allowed by the reader, such as vector and structure patterns (see
above).

@examples[#:eval the-eval
(syntax-parse #'(1 2 3)
  [(x ~rest y) (syntax->datum #'y)])
(syntax-parse #'#(1 2 3)
  [#(x ~rest y) (syntax->datum #'y)])
]
}

@specsubform[(@#,def[~describe s] maybe-role maybe-opaque expr S-pattern)
             #:grammar
             ([maybe-opaque (code:line)
                            (code:line #:opaque)]
              [maybe-role (code:line)
                          (code:line #:role role-expr)])
             #:contracts ([expr (or/c string? #f)]
                          [role-expr (or/c string? #f)])]{

The @racket[~describe] pattern form annotates a pattern with a
description, a string expression that is evaluated in the scope of all
prior attribute bindings. If parsing the inner pattern fails, then the
description is used to synthesize the error message. A
@racket[~describe] pattern does not influence backtracking.

If @racket[#:opaque] is given, failure information from within
@racket[S-pattern] is discarded and the error is reported solely in
terms of the description given.

If @racket[role-expr] is given and produces a string, its value is
combined with the description in error messages.

@examples[#:eval the-eval
(syntax-parse #'(m 1)
  [(_ (~describe "id pair" (x:id y:id))) 'ok])
(syntax-parse #'(m (a 2))
  [(_ (~describe "id pair" (x:id y:id))) 'ok])
(syntax-parse #'(m (a 2))
  [(_ (~describe #:opaque "id pair" (x:id y:id))) 'ok])
(syntax-parse #'(m 1)
  [(_ (~describe #:role "formals" "id pair" (x y))) 'ok])
]
}

@specsubform[(@#,def[~commit s] S-pattern)]{

The @racket[~commit] pattern form affects backtracking in two ways:

@itemize[

@item{If the pattern succeeds, then all choice points created within
the subpattern are discarded, and a failure @emph{after} the
@racket[~commit] pattern backtracks only to choice points
@emph{before} the @racket[~commit] pattern, never one @emph{within}
it.}

@item{A cut (@racket[~!]) within a @racket[~commit] pattern only
eliminates choice-points created within the @racket[~commit]
pattern. In this sense, it acts just like @racket[~delimit-cut].}
]
}

@specsubform[(@#,def[~delimit-cut s] S-pattern)]{

The @racket[~delimit-cut] pattern form affects backtracking in the
following way:

@itemize[

@item{A cut (@racket[~!]) within a @racket[~delimit-cut] pattern only
eliminates choice-points created within the @racket[~delimit-cut]
pattern.}

]
}

@specsubform[(@#,def[~post s] S-pattern)]{

Marks failures within the subpattern as occurring in a ``post-order
check''; that is, they are considered to have made greater progress
than a normal failure.
}


@specsubform[A-pattern]{

An @tech{@Apattern} is considered a @Spattern when there is no
ambiguity; it matches any term.
}


@section{Head Patterns}

A @deftech{@Hpattern} (abbreviated @svar[H-pattern]) is a pattern that
describes some number of terms that occur at the head of some list
(possibly an improper list). A @Hpattern's usefulness comes from being
able to match heads of different lengths, such as optional forms like
keyword arguments.

A @deftech{proper @Hpattern} is a @Hpattern that is not a @elem{@Spattern}.

Here are the variants of @elem{@Hpattern}:

@specsubform[pvar-id:splicing-syntax-class-id]{

Equivalent to @racket[(~var pvar-id splicing-syntax-class-id)].

}

@specsubform[(@#,def[~var h] pvar-id splicing-syntax-class-use maybe-role)
             #:grammar
             ([splicing-syntax-class-use splicing-syntax-class-id
                                         (splicing-syntax-class-id arg ...)]
              [maybe-role (code:line)
                          (code:line #:role role-expr)])
             #:contracts ([role-expr (or/c string? #f)])]{

Pattern variable annotated with a @tech{splicing syntax
class}. Similar to a normal @tech{annotated pattern variable}, except
matches a head pattern.
}

@specsubform[(@#,defhere[~seq] . L-pattern)]{

Matches a sequence of terms whose elements, if put in a list, would
match @racket[L-pattern].

@examples[#:eval the-eval
(syntax-parse #'(1 2 3 4)
  [((~seq 1 2 3) 4) 'ok])
]

See also the section on @tech{@EHpatterns} for more interesting
examples of @racket[~seq].
}

@specsubform[(@#,def[~and h] H-pattern ...)]{

Like the @Spattern version, @ref[~and s], but matches a sequence of
terms instead.

@examples[#:eval the-eval
(syntax-parse #'(#:a 1 #:b 2 3 4 5)
  [((~and (~seq (~seq k:keyword e:expr) ...)
          (~seq keyword-stuff ...))
    positional-stuff ...)
   (syntax->datum #'((k ...) (e ...) (keyword-stuff ...)))])
]

The @Hpattern variant of @racket[~and] requires that all of the
subpatterns be @tech{proper @Hpatterns} (not @tech{@Spatterns}). This
is to prevent typos like the following, a variant of the previous
example with the second @racket[~seq] omitted:

@examples[#:eval the-eval
(syntax-parse #'(#:a 1 #:b 2 3 4 5)
  [((~and (~seq (~seq k:keyword e:expr) ...)
          (keyword-stuff ...))
    positional-stuff ...)
   (syntax->datum #'((k ...) (e ...) (keyword-stuff ...)))])
(code:comment "If the example above were allowed, it would be equivalent to this:")
(syntax-parse #'(#:a 1 #:b 2 3 4 5)
  [((~and (~seq (~seq k:keyword e:expr) ...)
          (~seq (keyword-stuff ...)))
    positional-stuff ...)
   (syntax->datum #'((k ...) (e ...) (keyword-stuff ...)))])
]
}

@specsubform[(@#,def[~or* h] H-pattern ...)]{

Like the @Spattern version, @ref[~or* s], but matches a sequence of
terms instead.

@examples[#:eval the-eval
(syntax-parse #'(m #:foo 2 a b c)
  [(_ (~or* (~seq #:foo x) (~seq)) y:id ...)
   (attribute x)])
(syntax-parse #'(m a b c)
  [(_ (~or* (~seq #:foo x) (~seq)) y:id ...)
   (attribute x)])
]
}

@specsubform[(@#,def[~optional h] H-pattern maybe-optional-option)
             #:grammar
             ([maybe-optional-option
                (code:line)
                (code:line #:defaults ([attr-arity-decl expr] ...))]
              [attr-arity-decl
                attr-id
                (attr-id depth)])]{

Matches either the given head subpattern or an empty sequence of
terms. If the @racket[#:defaults] option is given, the subsequent
attribute bindings are used if the subpattern does not match. The
default attributes must be a subset of the subpattern's attributes.

@examples[#:eval the-eval
(syntax-parse #'(m #:foo 2 a b c)
  [(_ (~optional (~seq #:foo x) #:defaults ([x #'#f])) y:id ...)
   (attribute x)])
(syntax-parse #'(m a b c)
  [(_ (~optional (~seq #:foo x) #:defaults ([x #'#f])) y:id ...)
   (attribute x)])
(syntax-parse #'(m a b c)
  [(_ (~optional (~seq #:foo x)) y:id ...)
   (attribute x)])
(syntax-parse #'(m #:syms a b c)
  [(_ (~optional (~seq #:nums n:nat ...) #:defaults ([(n 1) null]))
      (~optional (~seq #:syms s:id ...) #:defaults ([(s 1) null])))
   #'((n ...) (s ...))])
]
}

@specsubform[(@#,def[~describe h] expr H-pattern)]{

Like the @Spattern version, @ref[~describe s], but matches a head
pattern instead.
}

@specsubform[(@#,def[~commit h] H-pattern)]{

Like the @Spattern version, @ref[~commit s], but matches a head
pattern instead.
}

@specsubform[(@#,def[~delimit-cut h] H-pattern)]{

Like the @Spattern version, @ref[~delimit-cut s], but matches a head
pattern instead.
}

@specsubform[(@#,def[~post h] H-pattern)]{

Like the @Spattern version, @ref[~post s], but matches a head
pattern instead.
}

@specsubform[(@#,defhere[~peek] H-pattern)]{

Matches the @racket[H-pattern] but then resets the matching position,
so the @racket[~peek] pattern consumes no input. Used to look ahead in
a sequence.

@examples[#:eval the-eval
(define-splicing-syntax-class nf-id (code:comment "non-final id")
  (pattern (~seq x:id (~peek another:id))))

(syntax-parse #'(a b c 1 2 3)
  [(n:nf-id ... rest ...)
   (printf "nf-ids are ~s\n" (syntax->datum #'(n.x ...)))
   (printf "rest is ~s\n" (syntax->datum #'(rest ...)))])
]
}

@specsubform[(@#,defhere[~peek-not] H-pattern)]{

Like @racket[~peek], but succeeds if the subpattern fails and fails if
the subpattern succeeds. On success, the @racket[~peek-not] resets the
matching position, so the pattern consumes no input. Used to look
ahead in a sequence. None of the subpattern's attributes are bound
outside of the @racket[~peek-not]-pattern.

@examples[#:eval the-eval
(define-splicing-syntax-class final (code:comment "final term")
  (pattern (~seq x (~peek-not _))))

(syntax-parse #'(a b c)
  [((~alt f:final other) ...)
   (printf "finals are ~s\n" (syntax->datum #'(f.x ...)))
   (printf "others are ~s\n" (syntax->datum #'(other ...)))])
]
}

@specsubform[S-pattern]{

Matches a sequence of one element, which must be a term matching
@racket[S-pattern].
}


@;{--------}

@section{Ellipsis-head Patterns}

An @deftech{@EHpattern} (abbreviated @svar[EH-pattern]) is pattern
that describes some number of terms, like a @tech{@Hpattern}, but also
places constraints on the number of times it occurs in a
repetition. They are useful for matching, for example, keyword
arguments where the keywords may come in any order. Multiple
alternatives are grouped together via @racket[~alt].

Note:  @racketid[syntax-parser] is used in phase 0, so we need to use @racket[(require syntax/parse)] instead of @racket[(require (for-syntax syntax/parse))] as we would use for the phase 1 @racketid[syntax-parse].
  
  @examples[#:eval the-eval
  (require syntax/parse)
(define parser1
  (syntax-parser
   [((~alt (~once (~seq #:a x) #:name "#:a keyword")
           (~optional (~seq #:b y) #:name "#:b keyword")
           (~seq #:c z)) ...)
    'ok]))
(parser1 #'(#:a 1))
(parser1 #'(#:b 2 #:c 3 #:c 25 #:a 'hi))
(parser1 #'(#:a 1 #:a 2))
]

The pattern requires exactly one occurrence of the @racket[#:a]
keyword and argument, at most one occurrence of the @racket[#:b]
keyword and argument, and any number of @racket[#:c] keywords and
arguments. The ``pieces'' can occur in any order.

Here are the variants of @elem{@EHpattern}:

@specsubform[(@#,defhere[~alt] EH-pattern ...)]{

Matches if any of the inner @racket[EH-pattern] alternatives match.
}

@specsubform[(@#,defhere[~once] H-pattern once-option ...)
             #:grammar
             ([once-option (code:line #:name name-expr)
                           (code:line #:too-few too-few-message-expr)
                           (code:line #:too-many too-many-message-expr)])
             #:contracts ([name-expr (or/c string? #f)]
                          [too-few-message-expr (or/c string? #f)]
                          [too-many-message-expr (or/c string? #f)])]{

Matches if the inner @racket[H-pattern] matches. This pattern must be
matched exactly once in the match of the entire repetition sequence.

If the pattern is not matched in the repetition sequence, then the
ellipsis pattern fails with the message either
@racket[too-few-message-expr] or @racketvalfont{"missing required
occurrence of @racket[name-expr]"}.

If the pattern is chosen more than once in the repetition sequence,
then the ellipsis pattern fails with the message either
@racket[too-many-message-expr] or @racketvalfont{"too many occurrences
of @racket[name-expr]"}.
}

@specsubform[(@#,def[~optional eh] H-pattern optional-option ...)
             #:grammar
             ([optional-option (code:line #:name name-expr)
                               (code:line #:too-many too-many-message-expr)
                               (code:line #:defaults ([attr-id expr] ...))])
             #:contracts ([name-expr (or/c string? #f)]
                          [too-many-message-expr (or/c string? #f)])]{

Matches if the inner @racket[H-pattern] matches. This pattern may be used at
most once in the match of the entire repetition.

If the pattern is matched more than once in the repetition sequence,
then the ellipsis pattern fails with the message either
@racket[too-many-message-expr] or @racketvalfont{"too many occurrences
of @racket[name-expr]"}.

If the @racket[#:defaults] option is given, the following attribute
bindings are used if the subpattern does not match at all in the
sequence. The default attributes must be a subset of the subpattern's
attributes.
}

@specsubform[(@#,defhere[~between] H-pattern min-number max-number between-option ...)
             #:grammar
             ([between-option (code:line #:name name-expr)
                           (code:line #:too-few too-few-message-expr)
                           (code:line #:too-many too-many-message-expr)])
             #:contracts ([name-expr (or/c string? #f)]
                          [too-few-message-expr (or/c string? #f)]
                          [too-many-message-expr (or/c string? #f)])]{

Matches if the inner @racket[H-pattern] matches. This pattern must be
matched at least @racket[min-number] and at most @racket[max-number]
times in the entire repetition.

If the pattern is matched too few times, then the ellipsis pattern
fails with the message either @racket[too-few-message-expr] or
@racketvalfont{"too few occurrences of @racket[name-expr]"}, when
@racket[name-expr] is provided.

If the pattern is chosen too many times, then the ellipsis pattern
fails with the message either @racket[too-many-message-expr] or
@racketvalfont{"too many occurrences of @racket[name-expr]"}, when
@racket[name-expr] is provided.
}



@;{--------}

@section{Action Patterns}

An @deftech{@Apattern} (abbreviated @svar[A-pattern]) does not
describe any syntax; rather, it has an effect such as the binding of
attributes or the modification of the matching process.

@specsubform[@#,defhere[~!]]{

The @deftech{cut} operator, written @racket[~!], eliminates
backtracking choice points and commits parsing to the current branch
of the pattern it is exploring.

Common opportunities for cut-patterns come from recognizing special
forms based on keywords. Consider the following expression:

@interaction[#:eval the-eval
(syntax-parse #'(define-values a 123)
  #:literals (define-values define-syntaxes)
  [(define-values (x:id ...) e) 'define-values]
  [(define-syntaxes (x:id ...) e) 'define-syntaxes]
  [e 'expression])]

Given the ill-formed term @racket[(define-values a 123)],
@racket[syntax-parse] tries the first clause, fails to match
@racket[a] against the pattern @racket[(x:id ...)], and then
backtracks to the second clause and ultimately the third clause,
producing the value @racket['expression]. But the term is not an
expression; it is an ill-formed use of @racket[define-values]. The
proper way to write the @racket[syntax-parse] expression follows:

@interaction[#:eval the-eval
(syntax-parse #'(define-values a 123)
  #:literals (define-values define-syntaxes)
  [(define-values ~! (x:id ...) e) 'define-values]
  [(define-syntaxes ~! (x:id ...) e) 'define-syntaxes]
  [e 'expression])]

Now, given the same term, @racket[syntax-parse] tries the first
clause, and since the keyword @racket[define-values] matches, the
cut-pattern commits to the current pattern, eliminating the choice
points for the second and third clauses. So when the clause fails to
match, the @racket[syntax-parse] expression raises an error.

The effect of a @racket[~!] pattern is delimited by the nearest
enclosing @racket[~delimit-cut] or @racket[~commit] pattern. If there
is no enclosing @racket[~describe] pattern but the cut occurs within a
syntax class definition, then only choice points within the syntax
class definition are discarded. A @racket[~!]  pattern is not allowed
within a @racket[~not] pattern unless there is an intervening
@racket[~delimit-cut] or @racket[~commit] pattern.
}

@specsubform[(@#,defhere[~bind] [attr-arity-decl expr] ...)
             #:grammar
             ([attr-arity-decl attr-name-id
                               (attr-name-id depth)])]{

Evaluates the @racket[expr]s and binds them to the given
@racket[attr-id]s as attributes.
}

@specsubform[(@#,defhere[~fail] maybe-fail-condition maybe-message-expr)
             #:grammar
             ([maybe-fail-condition (code:line)
                                    (code:line #:when condition-expr)
                                    (code:line #:unless condition-expr)]
              [maybe-message-expr (code:line)
                                  (code:line message-expr)])
             #:contracts ([message-expr (or/c string? #f)])]{

If the condition is absent, or if the @racket[#:when] condition
evaluates to a true value, or if the @racket[#:unless] condition
evaluates to @racket[#f], then the pattern fails with the given
message. If the message is omitted, the default value @racket[#f] is
used, representing ``no message.''

Fail patterns can be used together with cut patterns to recognize
specific ill-formed terms and address them with custom failure
messages.
}

@specsubform[(@#,defhere[~parse] S-pattern stx-expr)]{

Evaluates @racket[stx-expr] and matches it against
@racket[S-pattern]. If @racket[stx-expr] does not produce a syntax
object, the value is implicitly converted to a syntax object, unless
the conversion would produce @tech{3D syntax}, in which case an
exception is raised instead.
}

@specsubform[(@#,def[~and a] A-pattern ...+)]{

Performs the actions of each @racket[A-pattern].
}

@specsubform[(@#,defhere[~do] defn-or-expr ...)]{

Takes a sequence of definitions and expressions, which may be
intermixed, and evaluates them in the scope of all previous attribute
bindings. The names bound by the definitions are in scope in the
expressions of subsequent patterns and clauses.

There is currently no way to bind attributes using a @racket[~do]
pattern. It is an error to shadow an attribute binding with a
definition in a @racket[~do] block.

@examples[#:eval the-eval
(syntax-parse #'(1 2 3)
  [(a b (~do (printf "a was ~s\n" #'a)) c:id) 'ok])
]
}

@specsubform[(@#,defhere[~undo] defn-or-expr ...)]{

Has no effect when initially matched, but if backtracking returns to a
point @emph{before} the @racket[~undo] pattern, the
@racket[defn-or-expr]s are executed. They are evaluated in the scope
of all previous attribute bindings.

Use @racket[~do] paired with @racket[~undo] to perform side effects
and then unwind them if the enclosing pattern is later discarded.

@examples[#:eval the-eval
(define total 0)
(define-syntax-class nat/add
  (pattern (~and n:nat
                 (~do (printf "adding ~s\n" (syntax-e #'n))
                      (set! total (+ total (syntax-e #'n))))
                 (~undo (printf "subtracting ~s\n" (syntax-e #'n))
                        (set! total (- total (syntax-e #'n)))))))

(syntax-parse #'(1 2 3)
  [(x:nat/add ...) 'ok])
total
(set! total 0)
(syntax-parse #'(1 2 3 bad)
  [(x:nat/add ...) 'ok]
  [_ 'something-else])
total
]
}

@specsubform[(@#,def[~post a] A-pattern)]{

Like the @Spattern version, @ref[~post s], but contains only
@tech{@Apatterns}.
}


@;{--------}

@section{Pattern Expanders}

The grammar of @tech{syntax patterns} is extensible through the use of
@deftech{pattern expanders}, which allow the definition of new pattern
forms by rewriting them into existing pattern forms.

@margin-note{As a convention to avoid ambiguity, @tech{pattern expander}
             names normally begin with a @code{~} character.}

@defproc[(pattern-expander [proc (-> syntax? syntax?)]) pattern-expander?]{

Returns a @tech{pattern expander} that uses @racket[proc] to transform the pattern.

@examples[#:eval the-eval
(define-syntax ~maybe
  (pattern-expander
   (lambda (stx)
     (syntax-case stx ()
       [(~maybe pat ...)
        #'(~optional (~seq pat ...))]))))
]}

@defthing[prop:pattern-expander (struct-type-property/c (-> pattern-expander? (-> syntax? syntax?)))]{

A @tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{structure type property} to
identify structure types that act as @tech{pattern expanders} like the
ones created by @racket[pattern-expander]. 

@racketblock[
(begin-for-syntax
  (struct thing (proc pattern-expander)
    #:property prop:procedure (struct-field-index proc)
    #:property prop:pattern-expander (λ (this) (thing-pattern-expander this))))
(define-syntax ~maybe
  (thing
   (lambda (stx) .... @#,(elem "macro behavior") ....)
   (lambda (stx) .... @#,(elem "pattern-expander behavior") ....)))
]}

@defproc[(pattern-expander? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a @tech{pattern expander},
@racket[#f] otherwise.
}

@defproc[(syntax-local-syntax-parse-pattern-introduce [stx syntax?]) syntax?]{

For backward compatibility only; equivalent to @racket[syntax-local-introduce].

@history[#:changed "6.90.0.29" @elem{Made equivalent to @racket[syntax-local-introduce].}]}

@(close-eval the-eval)
