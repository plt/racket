#lang scribble/doc
@(require "mz.rkt" "match-grammar.rkt" racket/match)

@(define match-eval (make-base-eval))
@(define (match-kw s) (index (list s) (racketidfont s)))
@examples[#:hidden #:eval match-eval (require racket/match racket/list)]
@examples[#:hidden #:eval match-eval (require (for-syntax racket/base))]

@title[#:tag "match"]{Pattern Matching}

@guideintro["match"]{pattern matching}

The @racket[match] form and related forms support general pattern
matching on Racket values. See also @secref["regexp"] for information
on regular-expression matching on strings, bytes, and streams.

@note-lib[racket/match #:use-sources (racket/match)]

@defform/subs[(match val-expr clause ...)
              ([clause [pat option=> option ... body ...+]]
               [option=> (code:line)
                         (=> id)]
               [option (code:line #:when cond-expr)
                       (code:line #:do [do-body ...])])]{

Finds the first @racket[pat] that matches the result of
@racket[val-expr], and evaluates the corresponding @racket[body]s with
bindings introduced by @racket[pat] (if any). Bindings introduced by
@racket[pat] are not available in other parts of @racket[pat].
The last @racket[body]
in the matching clause is evaluated in tail position with respect to
the @racket[match] expression. 

To find a match, the @racket[clause]s are tried in order. If no
@racket[clause] matches, then the @exnraise[exn:misc:match?].

An optional @racket[#:when cond-expr] specifies that the pattern
should only match if @racket[cond-expr] produces a true value.
@racket[cond-expr] is in the scope of all of the variables bound in
@racket[pat]. @racket[cond-expr] must not mutate the object being
matched before calling the failure procedure, otherwise the behavior
of matching is unpredictable. See also @racket[failure-cont], which is
a lower-level mechanism achieving the same ends.

@examples[
#:eval match-eval
(define (m x)
  (match x
    [(list a b c)
     #:when (= 6 (+ a b c))
     'sum-is-six]
    [(list a b c) 'sum-is-not-six]))

(m '(1 2 3))
(m '(2 3 4))
]

An optional @racket[#:do [do-body ...]] executes @racket[do-body] forms.
In particular, the forms may introduce definitions that are visible in the remaining
options and the main clause body.
Both @racket[#:when] and @racket[#:do] options may appear multiple times

@examples[
#:eval match-eval
(define (m x)
  (match x
    [(list a b c)
     #:do [(define sum (+ a b c))]
     #:when (> sum 6)
     (format "the sum, which is ~a, is greater than 6" sum)]
    [(list a b c) 'sum-is-not-greater-than-six]))

(m '(1 2 3))
(m '(2 3 4))
]

An optional @racket[(=> id)], which must appear immediately after @racket[pat],
is bound to a @deftech{failure procedure} of zero
arguments.
@racket[id] is visible in all clause options and the clause body.
If this procedure is invoked, it escapes back to the
pattern matching expression, and resumes the matching process as if
the pattern had failed to match.  The @racket[body]s must not mutate
the object being matched before calling the failure procedure,
otherwise the behavior of matching is unpredictable. 

@examples[
#:eval match-eval
(define (m x)
  (match x
    [(list a b c)
     (=> exit)
     (f x exit)]
    [(list a b c) 'sum-is-not-six]))

(define (f x exit)
  (if (= 6 (apply + x))
      'sum-is-six
      (exit)))

(m '(1 2 3))
(m '(2 3 4))
]

The grammar of @racket[pat] is as follows, where non-italicized
identifiers are recognized symbolically (i.e., not by binding).

@|match-grammar|

In more detail, patterns match as follows:

@itemize[

 @item{@racket[_id] (excluding the reserved names @racketidfont{_},
       @racketidfont{...}, @racketidfont{___},
       @racketidfont{..}@racket[_k], and
       @racketidfont{__}@racket[_k] for non-negative integers
       @racket[_k]) @margin-note{Unlike in @racket[cond] and @racket[case],
       @racket[else] is not a keyword in @racket[match].
       Use the @racketidfont{_} pattern for the ``else'' clause.} or @racket[(var _id)]
       --- matches anything, and binds @racket[_id] to the
       matching values. If an @racket[_id] is used multiple times
       within a pattern, the corresponding matches must be the same
       according to @racket[(match-equality-test)], except that
       instances of an @racket[_id] in different @racketidfont{or} and
       @racketidfont{not} sub-patterns are independent. The binding for @racket[_id] is
       not available in other parts of the same pattern.

       @examples[
       #:eval match-eval
       (match '(1 2 3)
         [(list a b a) (list a b)]
         [(list a b c) (list c b a)])
       (match '(1 (x y z) 1)
         [(list a b a) (list a b)]
         [(list a b c) (list c b a)])
       (match #f
         [else
          (cond
            [#f 'not-evaluated]
            [else 'also-not-evaluated])])
       ]}

 @item{@match-kw{_} --- matches anything, without binding any
       identifiers.

       @examples[
       #:eval match-eval
       (match '(1 2 3)
         [(list _ _ a) a])
       ]}

 @item{@racket[#t], @racket[#f], @racket[_string], @racket[_bytes],
       @racket[_number], @racket[_char], or @racket[(#,(racketidfont
       "quote") _datum)] --- matches an @racket[equal?] constant.

       @examples[
       #:eval match-eval
       (match "yes"
         ["no" #f]
         ["yes" #t])
       ]}

 @item{@racket[(#,(match-kw "list") _lvp ...)] --- matches a list
       of elements. In the case of @racket[(#,(racketidfont "list")
       _pat ...)], the pattern matches a list with as many elements as
       @racket[_pat]s, and each element must match the corresponding
       @racket[_pat]. In the more general case, each @racket[_lvp]
       corresponds to a ``spliced'' list of greedy matches.

       For spliced lists, @racketidfont{...} and @racketidfont{___}
       are aliases for zero or more matches. The
       @racketidfont{..}@racket[_k] and @racketidfont{__}@racket[_k]
       forms are also aliases, specifying @racket[_k] or more
       matches. Pattern variables that precede these splicing
       operators are bound to lists of matching forms.

       @examples[
       #:eval match-eval
       (match '(1 2 3)
         [(list a b c) (list c b a)])
       (match '(1 2 3)
         [(list 1 a ...) a])
       (match '(1 2 3)
         [(list 1 a ..3) a]
         [_ 'else])
       (match '(1 2 3 4)
         [(list 1 a ..3) a]
         [_ 'else])
       (match '(1 2 3 4 5)
         [(list 1 a ..3 5) a]
         [_ 'else])
       (match '(1 (2) (2) (2) 5)
         [(list 1 (list a) ..3 5) a]
         [_ 'else])
       ]}

 @item{@racket[(#,(match-kw "list-rest") _lvp ... _pat)]
       or @racket[(#,(match-kw "list*") _lvp ... _pat)] ---
       similar to a @racketidfont{list} pattern, but the final
       @racket[_pat] matches the ``rest'' of the list after the last
       @racket[_lvp]. In fact, the matched value can be a non-list
       chain of pairs (i.e., an ``improper list'') if @racket[_pat]
       matches non-list values.

      @examples[
       #:eval match-eval
      (match '(1 2 3 . 4)
        [(list-rest a b c d) d])
      (match '(1 2 3 . 4)
        [(list-rest a ... d) (list a d)])
      ]}

 @item{@racket[(#,(match-kw "list-no-order") _pat ...)] ---
       similar to a @racketidfont{list} pattern, but the elements to
       match each @racket[_pat] can appear in the list in any order.

       @examples[
       #:eval match-eval
       (match '(1 2 3)
         [(list-no-order 3 2 x) x])
       ]

       @margin-note{
         Unlike other patterns, @racketidfont{list-no-order} doesn't
         allow duplicate identifiers between subpatterns. For example
         the patterns @racket[(list-no-order x 1 x)] and
         @racket[(list-no-order x 1 x ...)] both produce syntax errors.}}

 @item{@racket[(#,(racketidfont "list-no-order") _pat ... _lvp)] ---
       generalizes @racketidfont{list-no-order} to allow a pattern
       that matches multiple list elements that are interspersed in
       any order with matches for the other patterns.

       @examples[
       #:eval match-eval
       (match '(1 2 3 4 5 6)
         [(list-no-order 6 2 y ...) y])
       ]}

 @item{@racket[(#,(match-kw "vector") _lvp ...)] --- like a
       @racketidfont{list} pattern, but matching a vector.

       @examples[
       #:eval match-eval
       (match #(1 (2) (2) (2) 5)
         [(vector 1 (list a) ..3 5) a])
       ]}

 @item{@racket[(#,(match-kw "hash") _expr _pat ... ... _ht-opt)] ---
       matches against a hash table where @racket[_expr] matches
       a key and @racket[_pat] matches a corresponding value.

       @examples[
       #:eval match-eval
       (match (hash "aa" 1 "b" 2)
         [(hash "b" b (string-append "a" "a") a)
          (list b a)])
       (match (hash "aa" 1 "b" 2)
         [(hash "b" _ "c" _) 'matched]
         [_ 'not-matched])
       ]

       The key matchings use the key comparator of the matching hash table.

       @examples[
       #:eval match-eval
       (let ([k (string-append "a" "b")])
         (match (hasheq "ab" 1)
           [(hash k v) 'matched]
           [_ 'not-matched]))
       (let ([k (string-append "a" "b")])
         (match (hasheq k 1)
           [(hash k v) 'matched]
           [_ 'not-matched]))
       ]

       The behavior of residue key-value entries in the hash table value depends on @racket[_ht-opt].

       When @racket[_ht-opt] is not provided or when it is @racket[#:closed],
       all of the keys in the hash table value must be matched.
       I.e., the matching is closed to extension.

       @examples[
       #:eval match-eval
       (match (hash "a" 1 "b" 2)
         [(hash "b" _) 'matched]
         [_ 'not-matched])
       ]

       When @racket[_ht-opt] is @racket[#:open],
       there can be keys in the hash table value that are not specified in the pattern.
       I.e., the matching is open to extension.

       @examples[
       #:eval match-eval
       (match (hash "a" 1 "b" 2)
         [(hash "b" _ #:open) 'matched]
         [_ 'not-matched])
       ]

       When @racket[_ht-opt] is @racket[#:rest _pat], @racket[_pat] is further
       matched against the residue hash table.
       If the matching hash table is immutable, this residue matching is efficient.
       Otherwise, the matching hash table will be copied, which could be expensive.

       @examples[
       #:eval match-eval
       (match (hash "a" 1 "b" 2)
         [(hash "b" _ #:rest (hash "a" a)) a]
         [_ #f])
       ]

       Many key @racket[_expr]s could evaluate to the same value.

       @examples[
       #:eval match-eval
       (match (hash "a" 1 "b" 2)
         [(hash "b" _ "b" 2 "a" _) 'matched]
         [_ 'not-matched])
       ]}

 @item{@racket[(#,(match-kw "hash*") [_expr _pat _kv-opt] ... _ht-opt)] ---
       similar to @racketidfont{hash}, but with the following differences:

       @itemlist[
         @item{The key-value pattern must be grouped syntactically.}
         @item{If @racket[_ht-opt] is not specified, it behaves like @racket[#:open]
               (as opposed to @racket[#:closed]).}
         @item{If @racket[_kv-opt] is specified with @racket[#:default _def-expr],
               and the key does not exist in the hash table value, then the default value
               from @racket[_def-expr] will be matched against the value pattern,
               instead of immediately failing to match.}
       ]

       @examples[
       #:eval match-eval
       (match (hash "a" 1 "b" 2)
         [(hash* ["b" b] ["a" a]) (list b a)])
       (match (hash "a" 1 "b" 2)
         [(hash* ["b" b]) 'matched]
         [_ 'not-matched])
       (match (hash "a" 1 "b" 2)
         [(hash* ["a" a #:default 42] ["c" c #:default 100]) (list a c)]
         [_ #f])
       ]}

 @item{@racket[(#,(match-kw "hash-table") (_pat _pat) ...)] ---
       @bold{This pattern is deprecated because it can be incorrect.}
       However, many programs rely on the incorrect behavior,
       so we still provide this pattern for backward compatibility reasons.

       Similar to @racketidfont{list-no-order}, but matching against
       hash table's key--value pairs.

       @examples[
       #:eval match-eval
       (match #hash(("a" . 1) ("b" . 2))
         [(hash-table ("b" b) ("a" a)) (list b a)])
       ]}

 @item{@racket[(#,(racketidfont "hash-table") (_pat _pat) ...+ _ooo)] ---
       @bold{This pattern is deprecated because it can be incorrect.}
       However, many programs rely on the incorrect behavior,
       so we still provide this pattern for backward compatibility reasons.

       Generalizes @racketidfont{hash-table} to support a final
       repeating pattern.

       @examples[
       #:eval match-eval
       (match #hash(("a" . 1) ("b" . 2))
         [(hash-table (key val) ...) key])
       ]}

 @item{@racket[(#,(match-kw "cons") _pat1 _pat2)] --- matches a pair value.

       @examples[
       #:eval match-eval
       (match (cons 1 2)
         [(cons a b) (+ a b)])
       ]}

 @item{@racket[(#,(match-kw "mcons") _pat1 _pat2)] --- matches a mutable pair value.

       @examples[
       #:eval match-eval
       (match (mcons 1 2)
         [(cons a b) 'immutable]
	 [(mcons a b) 'mutable])
       ]}

 @item{@racket[(#,(match-kw "box") _pat)] --- matches a boxed value.

       @examples[
       #:eval match-eval
       (match #&1
         [(box a) a])
       ]}

 @item{@racket[(_struct-id _pat ...)] or
       @racket[(#,(match-kw "struct") _struct-id (_pat ...))] ---
       matches an instance of a structure type named
       @racket[_struct-id], where each field in the instance matches
       the corresponding @racket[_pat]. See also @racket[struct*].

       Usually, @racket[_struct-id] is defined with
       @racket[struct].  More generally, @racket[_struct-id]
       must be bound to expansion-time information for a structure
       type (see @secref["structinfo"]), where the information
       includes at least a predicate binding and field accessor
       bindings corresponding to the number of field
       @racket[_pat]s. In particular, a module import or a
       @racket[unit] import with a signature containing a
       @racket[struct] declaration can provide the structure type
       information.

       @examples[
       #:eval match-eval
       (eval:no-prompt (struct tree (val left right)))
       (match (tree 0 (tree 1 #f #f) #f)
         [(tree a (tree b  _ _) _) (list a b)])
       ]}

 @item{@racket[(#,(racketidfont "struct") _struct-id _)] ---
       matches any instance of @racket[_struct-id], without regard to
       contents of the fields of the instance.
       }

 @item{@racket[(#,(match-kw "regexp") _rx-expr)] --- matches a
       string that matches the regexp pattern produced by @racket[_rx-expr],
       where @racket[_rx-expr] can be either a @racket[regexp], a @racket[pregexp],
       a @racket[byte-regexp], a @racket[byte-pregexp], a string, or a byte string.
       A string and byte string value is converted to a pattern using
       @racket[regexp] and @racket[byte-regexp] respectively.
       See @secref["regexp"] for more information about regexps.

       @examples[
       #:eval match-eval
       (match "apple"
         [(regexp #rx"p+") 'yes]
         [_ 'no])
       (match "banana"
         [(regexp #px"(na){2}") 'yes]
         [_ 'no])
       (match "banana"
         [(regexp "(na){2}") 'yes]
         [_ 'no])
       (match #"apple"
         [(regexp #rx#"p+") 'yes]
         [_ 'no])
       (match #"banana"
         [(regexp #px#"(na){2}") 'yes]
         [_ 'no])
       (match #"banana"
         [(regexp #"(na){2}") 'yes]
         [_ 'no])
       ]}

 @item{@racket[(#,(racketidfont "regexp") _rx-expr _pat)] --- extends
       the @racketidfont{regexp} form to further constrain the match
       where the result of @racket[regexp-match] is matched against
       @racket[_pat].

       @examples[
       #:eval match-eval
       (match "apple"
         [(regexp #rx"p+(.)" (list _ "l")) 'yes]
         [_ 'no])
       (match "append"
         [(regexp #rx"p+(.)" (list _ "l")) 'yes]
         [_ 'no])
       ]}

 @item{@racket[(#,(match-kw "pregexp") _rx-expr)] or
       @racket[(#,(racketidfont "pregexp") _rx-expr _pat)] --- like the
       @racketidfont{regexp} patterns, but @racket[_rx-expr] must be either
       a @racket[pregexp], a @racket[byte-pregexp], a string, or a byte string.
       A string and byte string value is converted to a pattern using
       @racket[pregexp] and @racket[byte-pregexp] respectively.}

 @item{@racket[(#,(match-kw "and") _pat ...)] --- matches if all
       of the @racket[_pat]s match.  This pattern is often used as
       @racket[(#,(racketidfont "and") _id _pat)] to bind @racket[_id]
       to the entire value that matches @racket[pat]. The @racket[_pat]s are
       matched in the order that they appear.

       @examples[
       #:eval match-eval
       (match '(1 (2 3) 4)
        [(list _ (and a (list _ ...)) _) a])
       ]}

 @item{@racket[(#,(match-kw "or") _pat ...)] --- matches if any of
       the @racket[_pat]s match. Each @racket[_pat] must bind the same set
       of identifiers.

       @examples[
       #:eval match-eval
       (match '(1 2)
        [(or (list a 1) (list a 2)) a])
       ]}

 @item{@racket[(#,(match-kw "not") _pat ...)] --- matches when
       none of the @racket[_pat]s match, and binds no identifiers.

       @examples[
       #:eval match-eval
       (match '(1 2 3)
        [(list (not 4) ...) 'yes]
        [_ 'no])
       (match '(1 4 3)
        [(list (not 4) ...) 'yes]
        [_ 'no])
       ]}

 @item{@racket[(#,(match-kw "app") _expr _pats ...)] --- applies
       @racket[_expr] to the value to be matched; each result of the
       application is matched against one of the @racket[_pats],
       respectively.

       @examples[
       #:eval match-eval
       (match '(1 2)
        [(app length 2) 'yes])
       (match "3.14"
        [(app string->number (? number? pi))
         `(I got ,pi)])
       (match '(1 2)
        [(app (lambda (v) (split-at v 1)) '(1) '(2)) 'yes])
       (match '(1 2 3)
        [(app (λ (ls) (apply values ls)) x y (? odd? z))
         (list 'yes x y z)])
       ]}

 @item{@racket[(#,(match-kw "?") _expr _pat ...)] --- applies
       @racket[_expr] to the value to be matched, and checks whether
       the result is a true value; the additional @racket[_pat]s must
       also match; i.e., @racketidfont{?} combines a predicate
       application and an @racketidfont{and} pattern.  However,
       @racketidfont{?}, unlike @racketidfont{and}, guarantees that
       @racket[_expr] is matched before any of the @racket[_pat]s.

       @margin-note{The @racket[_expr] procedure may be called more than once
       on identical input (although this happens only rarely),
       and the order in which calls to @racket[_expr] are
       made should not be relied upon.}

       @examples[
       #:eval match-eval
       (match '(1 3 5)
        [(list (? odd?) ...) 'yes])
       ]}

  @item{@racket[(#,(match-kw "quasiquote") _qp)] --- introduces a
        quasipattern, in which identifiers match symbols. Like the
        @racket[quasiquote] expression form, @racketidfont{unquote}
        and @racketidfont{unquote-splicing} escape back to normal
        patterns.

        @examples[
       #:eval match-eval
        (match '(1 2 3)
          [`(1 ,a ,(? odd? b)) (list a b)])
        ]}

 @item{@racket[_derived-pattern] --- matches a pattern defined by a
       macro extension via @racket[define-match-expander].}

]

Note that the matching process may destructure the input multiple times, and
may evaluate expressions embedded in patterns such as @racket[(#,(racketidfont
"app") expr pat)] in arbitrary order, or multiple times.  Therefore, such
expressions must be safe to call multiple times, or in an order other than they
appear in the original program.

@history[#:changed "8.9.0.5" @elem{Added a support for @racket[#:do].}
         #:changed "8.11.1.10" @elem{Added the @racket[#,(racketidfont "hash")] and
                                     @racket[#,(racketidfont "hash*")] patterns.}]
}

@; ----------------------------------------------------------------------

@section{Additional Matching Forms}

@defform/subs[(match* (val-expr ...+) clause* ...)
              ([clause* [(pat ...+) option=> option ... body ...+]])]{
Matches a sequence of values against each clause in order, matching
only when all patterns in a clause match.  Each clause must have the
same number of patterns as the number of @racket[val-expr]s.

@examples[#:eval match-eval
(match* (1 2 3)
  [(_ (? number?) x) (add1 x)])

(match* (15 17)
  [((? number? a) (? number? b))
   #:when (= (+ a 2) b)
   'diff-by-two])
]
}

@defform[(match/values expr clause* clause* ...)]{
If @racket[expr] evaluates to @racket[n] values, then match all @racket[n]
values against the patterns in @racket[clause* ...]. Each clause must contain
exactly @racket[n] patterns. At least one clause is required to determine how
many values to expect from @racket[expr].

@examples[#:eval match-eval
(match/values (values 1 2 3)
  [(a (? number? b) (? odd? c)) (+ a b c)])
]
}


@defform/subs[
  (define/match (head args)
    match*-clause ...)
  ([head id (head args)]
   [args (code:line arg ...)
         (code:line arg ... @#,racketparenfont{.} rest-id)]
   [arg arg-id
        [arg-id default-expr]
        (code:line keyword arg-id)
        (code:line keyword [arg-id default-expr])]
   [match*-clause [(pat ...+) option=> option ... body ...+]])
]{
  Binds @racket[id] to a procedure that is defined by pattern matching
  clauses using @racket[match*]. Each clause takes a sequence of
  patterns that correspond to the arguments in the function header.
  The arguments are ordered as they appear in the function header for
  matching purposes.

  @examples[#:eval match-eval
    (eval:no-prompt
     (define/match (fact n)
       [(0) 1]
       [(n) (* n (fact (sub1 n)))]))
    (fact 5)
  ]

  The function header may also contain optional or keyword arguments,
  may have curried arguments, and may also contain a rest argument.

  @examples[#:eval match-eval
    (eval:no-prompt
     (define/match ((f x) #:y [y '(1 2 3)])
       [((regexp #rx"p+") `(,a 2 3)) a]
       [(_ _) #f]))
    ((f "ape") #:y '(5 2 3))
    ((f "dog"))

    (eval:no-prompt
     (define/match (g x y . rst)
       [(0 0 '()) #t]
       [(5 5 '(5 5)) #t]
       [(_ _ _) #f]))
    (g 0 0)
    (g 5 5 5 5)
    (g 1 2)
  ]
}

@deftogether[(@defform[(match-lambda clause ...)]
              @defform[(match-λ clause ...)])]{

Equivalent to @racket[(lambda (id) (match id clause ...))].

@history[#:changed "8.13.0.5" @elem{Added @racket[match-λ].}]
}

@deftogether[(@defform[(match-lambda* clause ...)]
              @defform[(match-λ* clause ...)])]{

Equivalent to @racket[(lambda lst (match lst clause ...))].

@history[#:changed "8.13.0.5" @elem{Added @racket[match-λ*].}]
}

@deftogether[(@defform[(match-lambda** clause* ...)]
              @defform[(match-λ** clause ...)])]{

Equivalent to @racket[(lambda (args ...) (match* (args ...) clause* ...))],
where the number of @racket[args ...] is computed from the number of patterns
appearing in each of the @racket[clause*].

@history[#:changed "8.13.0.5" @elem{Added @racket[match-λ**].}]
}


@defform[(match-let ([pat expr] ...) body ...+)]{

Generalizes @racket[let] to support pattern bindings. Each
@racket[expr] is matched against its corresponding @racket[pat] (the
match must succeed), and the bindings that @racket[pat] introduces are
visible in the @racket[body]s.

@examples[
#:eval match-eval
(match-let ([(list a b) '(1 2)]
            [(vector x ...) #(1 2 3 4)])
  (list b a x))
]}

@defform[(match-let* ([pat expr] ...) body ...+)]{

Like @racket[match-let], but generalizes @racket[let*], so that the
bindings of each @racket[pat] are available in each subsequent
@racket[expr].

@examples[
#:eval match-eval
(match-let* ([(list a b) '(#(1 2 3 4) 2)]
             [(vector x ...) a])
  x)
]}

@defform[(match-let-values ([(pat ...) expr] ...) body ...+)]{

Like @racket[match-let], but generalizes @racket[let-values].}

@defform[(match-let*-values ([(pat ...) expr] ...) body ...+)]{

Like @racket[match-let*], but generalizes @racket[let*-values].}

@defform[(match-letrec ([pat expr] ...) body ...+)]{

Like @racket[match-let], but generalizes @racket[letrec].}


@defform[(match-letrec-values ([(pat ...) expr] ...) body ...+)]{

Like @racket[match-let], but generalizes @racket[letrec-values].

@history[#:added "6.1.1.8"]
}
 
@defform[(match-define pat expr)]{

Defines the names bound by @racket[pat] to the values produced by
matching against the result of @racket[expr].

@examples[
#:eval match-eval
(match-define (list a b) '(1 2))
b
]}

@defform[(match-define-values (pat pats ...) expr)]{

Like @racket[match-define] but for when expr produces multiple values.
Like match/values, it requires at least one pattern to determine the
number of values to expect.

@examples[
#:eval match-eval
(match-define-values (a b) (values 1 2))
b
]}

@; ----------------------------------------

@defproc[(exn:misc:match? [v any/c]) boolean?]{
A predicate for the exception raised in the case of a match failure.
}

@defform[(failure-cont)]{
Continues matching as if the current pattern failed.  Note that unlike
use of the @racket[=>] form, this does @emph{not} escape the current
context, and thus should only be used in tail position with respect to
the @racket[match] form.
}


@; ----------------------------------------

@section{Extending @racket[match]}

@defform*[((define-match-expander id proc-expr)
           (define-match-expander id proc-expr proc-expr))]{

Binds @racket[id] to a @deftech{match expander}.

The first @racket[proc-expr] sub-expression must evaluate to a
 transformer that produces a @racket[_pat] for @racket[match].
 Whenever @racket[id] appears as the beginning of a pattern, this
 transformer is given, at expansion time, a syntax object
 corresponding to the entire pattern (including @racket[id]).  The
 pattern is replaced with the result of the transformer.

A transformer produced by a second @racket[proc-expr] sub-expression is
 used when @racket[id] is used in an expression context. Using the
 second @racket[proc-expr], @racket[id] can be given meaning both
 inside and outside patterns.

Match expanders are not invoked unless @racket[id] appears in the first
position in a sequence. Instead, identifiers bound by @racket[define-match-expander]
are used as binding identifiers (like any other identifier) when they appear
anywhere except the first position in a sequence.
 
For example, to extend the pattern matcher and destructure syntax lists,
@examples[#:label #f
  #:eval match-eval
  (eval:no-prompt
   (define (syntax-list? x)
     (and (syntax? x)
          (list? (syntax->list x))))
   (define-match-expander syntax-list 
     (lambda (stx)
       (syntax-case stx ()
         [(_ elts ...)
          #'(? syntax-list?
               (app syntax->list (list elts ...)))])))
   (define (make-keyword-predicate keyword)
     (lambda (stx)
       (and (identifier? stx)
            (free-identifier=? stx keyword))))
   (define or-keyword? (make-keyword-predicate #'or))
   (define and-keyword? (make-keyword-predicate #'and)))

  (match #'(or 3 4)
    [(syntax-list (? or-keyword?) b c)
     (list "OOORRR!" b c)]
    [(syntax-list (? and-keyword?) b c)
     (list "AAANND!" b c)])

  (match #'(and 5 6)
    [(syntax-list (? or-keyword?) b c)
     (list "OOORRR!" b c)]
    [(syntax-list (? and-keyword?) b c)
     (list "AAANND!" b c)])
 ]

And here is an example showing how 
@racket[define-match-expander]-bound identifiers are
@emph{not} treated specially unless they appear
in the first position of pattern sequence. Consider
this (incorrect) definition of a length function:
@examples[#:label #f
  #:eval match-eval
  (eval:no-prompt
   (define-match-expander nil
     (λ (stx) #''())
     (λ (stx) #''()))
   (define (len l)
     (match l
       [nil 0]
       [(cons hd tl) (+ 1 (len tl))])))]

Because there are no parenthesis around @racket[nil],
@racket[match] treats the first case as an identifier
(which matches everything) instead of a use of the match
expander and @racket[len] always returns @racket[0].

@examples[#:label #f #:eval match-eval
  (len nil)
  (len (cons 1 nil))
  (len (cons 1 (cons 2 nil)))]

Match expanders accept any syntax pair whose first element is an
@racket[identifier?] bound to the expander. The following example
shows a match expander which can be called with an improper syntax
list of the form @racket[(expander a b . rest)].
@examples[#:label #f
  #:eval match-eval
  (eval:no-prompt
   (define-match-expander my-vector
     (λ (stx)
       (syntax-case stx ()
         [(_ pat ...)
          #'(vector pat ...)]
         [(_ pat ... . rest-pat)
          #'(app vector->list (list-rest pat ... rest-pat))]))))
  (match #(1 2 3 4 5)
   [(my-vector a b . rest)
     (list->vector (append rest (list a b)))])]

@history[
 #:changed "7.7.0.2"
 @elem{Match expanders now allowed any syntax pair whose first element is an 
  @racket[identifier?] bound to the expander. The example above did not work
  with previous versions.}]
}

@defthing[prop:match-expander struct-type-property?]{

A @tech{structure type property} to identify structure types that act
as @tech{match expanders} like the ones created by
@racket[define-match-expander].

The property value must be an exact non-negative integer or a
procedure of one or two arguments.  In the former case, the integer
designates a field within the structure that should contain a
procedure; the integer must be between @racket[0] (inclusive) and the
number of non-automatic fields in the structure type (exclusive, not
counting supertype fields), and the designated field must also be
specified as immutable.

If the property value is a procedure of one argument, then the
procedure serves as the transformer for match expansion. If the property value is a procedure of two
arguments, then the first argument is the structure whose type has
@racket[prop:match-expander] property, and the second argument is a
syntax object as for a @tech{match expander}..

If the property value is a @tech{assignment transformer}, then the wrapped
procedure is extracted with
@racket[set!-transformer-procedure] before it is called.

This binding is provided @racket[for-syntax].
}

@defthing[prop:legacy-match-expander struct-type-property?]{
Like @racket[prop:match-expander], but for the legacy match syntax.

This binding is provided @racket[for-syntax].
}

@deftogether[[
@defproc[(match-expander? [v any/c]) boolean?]
@defproc[(legacy-match-expander? [v any/c]) boolean?]]]{
Predicates for values which implement the appropriate match expander
properties.
These bindings are provided @racket[for-syntax].
}

@defproc[(syntax-local-match-introduce [stx syntax?]) syntax?]{
For backward compatibility only; equivalent to @racket[syntax-local-introduce].

This binding is provided @racket[for-syntax].

@history[#:changed "6.90.0.29" @elem{Made equivalent to @racket[syntax-local-introduce].}]}


@defproc[(pattern-bound-identifiers #:legacy? [legacy? any/c #f] [pat syntax?]) (listof identifier?)]{
Parse @racket[pat] as a pattern, and compute the identifiers bound by
that pattern. If @racket[legacy?] is @racket[#f], use the legacy match
syntax instead of the standard syntax. 

This binding is provided @racket[for-syntax].
@history[#:added "8.2.0.1"]
}

@defparam[match-equality-test comp-proc (any/c any/c . -> . any)]{

A @tech{parameter} that determines the comparison procedure used to check
whether multiple uses of an identifier match the ``same'' value. The
default is @racket[equal?].}

@deftogether[[@defform[(match/derived val-expr original-datum clause ...)]
              @defform[(match*/derived (val-expr ...) original-datum clause* ...)]]]{
Like @racket[match] and @racket[match*] respectively, but includes a
sub-expression to be used as the source for all syntax errors within the form.
For example, @racket[match-lambda] expands to @racket[match/derived] so that
errors in the body of the form are reported in terms of @racket[match-lambda]
instead of @racket[match].}

@; ----------------------------------------------------------------------

@section{Library Extensions}

@defform*[[(== val comparator) (== val)]]{
A @tech{match expander} 
which checks if the matched value is the same as @racket[val] when
compared by @racket[comparator].  If @racket[comparator] is
not provided, it defaults to @racket[equal?].  

@examples[#:eval match-eval
(match (list 1 2 3)
  [(== (list 1 2 3)) 'yes]
  [_ 'no])
(match (list 1 2 3)
  [(== (list 1 2 3) eq?) 'yes]
  [_ 'no])
(match (list 1 2 3)
  [(list 1 2 (== 3 =)) 'yes]
  [_ 'no])
]
}


@defform[(struct* struct-id ([field pat] ...))]{
 A @racket[match] pattern form that matches an instance of a structure
 type named @racket[struct-id], where the field @racket[field] in the
 instance matches the corresponding @racket[pat].
 The fields do not include those from super types.

 Any field of @racket[struct-id] may be omitted, and such fields can
 occur in any order.

 @examples[
  #:eval match-eval
  (eval:no-prompt
   (struct tree (val left right))
   (struct tree* tree (val)))
  (match (tree 0 (tree 1 #f #f) #f)
    [(struct* tree ([val a]
                    [left (struct* tree ([right #f] [val b]))]))
     (list a b)])
  (match (tree* 0 #f #f 42)
    [(and (struct* tree* ([val a]))
          (struct* tree ([val b])))
     (list a b)])
 ]
 }

@; ----------------------------------------------------------------------

@close-eval[match-eval]
