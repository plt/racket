#lang scribble/doc
@(require "mz.rkt" (for-label racket/generic))

@(define dict-eval (make-base-eval))
@examples[#:hidden #:eval dict-eval
          (require racket/dict racket/generic racket/contract racket/string)]

@title[#:tag "dicts"]{Dictionaries}

A @deftech{dictionary} is an instance of a datatype that maps keys to
values. The following datatypes are all dictionaries:

@itemize[

 @item{@techlink{hash tables};}

 @item{@techlink{vectors} (using only exact integers as keys);}

 @item{@techlink{lists} of @techlink{pairs} as an @deftech{association
       list} using @racket[equal?] to compare keys, which must be distinct; and}

 @item{@techlink{structures} whose types implement the @racket[gen:dict]
       @tech{generic interface}.}

]

When list of pairs is used as @tech{association list} but does not
have distinct keys (so it's not an association list), operations like
@racket[dict-ref] and @racket[dict-remove] operate on the first
instance of the key, while operations like @racket[dict-map] and
@racket[dict-keys] produce an element for every instance of the key.

@note-lib[racket/dict]

@section{Dictionary Predicates and Contracts}

@defproc[(dict? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a @tech{dictionary}, @racket[#f]
otherwise.

Beware that @racket[dict?] is not a constant-time test on pairs, since
checking that @racket[v] is an @tech{association list} may require
traversing the list.

@examples[
#:eval dict-eval
(dict? #hash((a . "apple")))
(dict? '#("apple" "banana"))
(dict? '("apple" "banana"))
(dict? '((a . "apple") (b . "banana")))
]}

@defproc[(dict-implements? [d dict?] [sym symbol?] ...) boolean?]{

Returns @racket[#t] if @racket[d] implements all of the methods from
@racket[gen:dict] named by the @racket[sym]s; returns @racket[#f] otherwise.
Fallback implementations do not affect the result; @racket[d] may support the
given methods via fallback implementations yet produce @racket[#f].

@examples[
#:eval dict-eval
(dict-implements? (hash 'a "apple") 'dict-set!)
(dict-implements? (make-hash '((a . "apple") (b . "banana"))) 'dict-set!)
(dict-implements? (make-hash '((b . "banana") (a . "apple"))) 'dict-remove!)
(dict-implements? (vector "apple" "banana") 'dict-set!)
(dict-implements? (vector 'a 'b) 'dict-remove!)
(dict-implements? (vector 'a "apple") 'dict-set! 'dict-remove!)
]

}

@defproc[(dict-implements/c [sym symbol?] ...) flat-contract?]{

Recognizes dictionaries that support all of the methods from @racket[gen:dict]
named by the @racket[sym]s. Note that the generated contract is not similar to
@racket[hash/c], but closer to @racket[dict-implements?].
@examples[
 #:eval dict-eval
 (struct deformed-dict ()
   #:methods gen:dict [])
 (define/contract good-dict
   (dict-implements/c)
   (deformed-dict))
 (eval:error
  (define/contract bad-dict
    (dict-implements/c 'dict-ref)
    (deformed-dict)))]

}


@defproc[(dict-mutable? [d dict?]) boolean?]{

Returns @racket[#t] if @racket[d] is mutable via @racket[dict-set!],
@racket[#f] otherwise.

Equivalent to @racket[(dict-implements? d 'dict-set!)].

@examples[
#:eval dict-eval
(dict-mutable? #hash((a . "apple")))
(dict-mutable? (make-hash))
(dict-mutable? '#("apple" "banana"))
(dict-mutable? (vector "apple" "banana"))
(dict-mutable? '((a . "apple") (b . "banana")))
]}


@defproc[(dict-mutability/c [b boolean?]) flat-contract?]{

Recognizes a mutable dictionary when @racket[b] is true, and otherwise
recognizes an immutable dictionary.

@examples[
#:eval dict-eval
((dict-mutability/c #t) '())
((dict-mutability/c #f) '())
((dict-mutability/c #t) (make-hash))
((dict-mutability/c #f) (make-hash))
((dict-mutability/c #t) (make-immutable-hash))
((dict-mutability/c #f) (make-immutable-hash))
]
}

@defproc[(dict-immutability/c [b boolean?]) flat-contract?]{

Recognizes an immutable dictionary when @racket[b] is true, and otherwise
recognizes an mutable dictionary.

@examples[
#:eval dict-eval
((dict-immutability/c #t) '())
((dict-immutability/c #f) '())
((dict-immutability/c #t) (make-hash))
((dict-immutability/c #f) (make-hash))
((dict-immutability/c #t) (make-immutable-hash))
((dict-immutability/c #f) (make-immutable-hash))
]
}

@defproc[(dict-can-remove-keys? [d dict?]) boolean?]{

Returns @racket[#t] if @racket[d] supports removing mappings via
@racket[dict-remove!] and/or @racket[dict-remove], @racket[#f]
otherwise.

Equivalent to
@racket[(or (dict-implements? d 'dict-remove!) (dict-implements? d 'dict-remove))].

@examples[
#:eval dict-eval
(dict-can-remove-keys? #hash((a . "apple")))
(dict-can-remove-keys? '#("apple" "banana"))
(dict-can-remove-keys? '((a . "apple") (b . "banana")))
]}


@defproc[(dict-can-functional-set? [d dict?]) boolean?]{

Returns @racket[#t] if @racket[d] supports functional update via
@racket[dict-set], @racket[#f] otherwise.

Equivalent to @racket[(dict-implements? d 'dict-set)].

@examples[
#:eval dict-eval
(dict-can-functional-set? #hash((a . "apple")))
(dict-can-functional-set? (make-hash))
(dict-can-functional-set? '#("apple" "banana"))
(dict-can-functional-set? '((a . "apple") (b . "banana")))
]}


@defproc[(homogenous-dictof [key-contract flat-contract?] [value-contract flat-contract?])
          flat-contract?]{
Recognizes a dictionary whose all satisfy the @racket[key-contract] and whose
values all satisfy the @racket[value-contract].

@examples[
#:eval dict-eval
((homogeneous-dictof symbol? integer?) '((a . 5)))
((homogeneous-dictof symbol? integer?) '((a . 5) (b . 5)))
((homogeneous-dictof symbol? integer?) '((a . 5) (b . a)))
]
}

@defproc[(heterogeneous-dictof [#:mandatory-keys? mandatory-keys? boolean? #t]
                               [#:exact-keys? exact-keys? boolean? #f]
                               [#:immutable? immutable? boolean? #t]
                               [key-contract flat-contract?] [value-contract flat-contract?] ... ...)
         flat-contract?]{
Recognizes a dictionary for which every key that satsifies a key contract maps
to a value satisfying the corresponding value contract.
Each @racket[key-contract] must be followed by a @racket[value-contract], so the
total number of non-keyword arguments is even.

@examples[
#:eval dict-eval

((heterogeneous-dictof symbol? integer? integer? symbol?) '())
((heterogeneous-dictof symbol? integer? integer? symbol?) '((a . 5) (6 . b)))
((heterogeneous-dictof symbol? integer? integer? symbol?) '((a . 5) (a . b)))
((heterogeneous-dictof symbol? integer? integer? symbol?) '((a . 5)))
((heterogeneous-dictof symbol? integer? integer? symbol?) '((6 . b)))
((heterogeneous-dictof 'a integer?) '((a . 5)))
((heterogeneous-dictof 'a integer?) '((b . 5)))
]

If @racket[exact-keys?] is specified, then the @racket[key-contract]s are
interpreted as keys in contracted dictionary, and the dictionary is required to
contain exactly the keys specified.

@examples[
#:eval dict-eval
((heterogeneous-dictof #:exact-keys? #f 'a integer?) '((a . 5)))
((heterogeneous-dictof #:exact-keys? #f 'a integer?) '((a . 5) (b . 5)))
]

If @racket[mandatory-keys?] is specified (the default), then a key matching each
key contracts is required to be in the dictionary.
Otherwise, contracted keys are optional, but if present, their value must match
the corresponding contract.

@examples[
#:eval dict-eval

((heterogeneous-dictof #:mandatory-keys? #f symbol? integer? integer? symbol?) '())
((heterogeneous-dictof #:mandatory-keys? #f 'a integer?) '((b . 6)))
((heterogeneous-dictof #:mandatory-keys? #f 'a integer?) '((a . 5)))
((heterogeneous-dictof #:mandatory-keys? #f 'a integer?) '((a . 5) (b . 6)))
((heterogeneous-dictof #:mandatory-keys? #f 'a integer?) '((a . b)))
]

If @racket[immutable?] is specified (the default), then the contracted
dictionary is only recognized if it is immutable, and otherwise it is recognized
if it is mutable.

@examples[
#:eval dict-eval
((heterogeneous-dictof 'a integer?) '((a . 5)))
((heterogeneous-dictof #:immutable? #f 'a integer?) '((a . 5)))
((heterogeneous-dictof 'a integer?) (make-hash '((a . 5))))
((heterogeneous-dictof #:immutable? #f 'a integer?) (make-hash '((a . 5))))
((heterogeneous-dictof 'a integer?) (hash 'a 5))
((heterogeneous-dictof #:immutable? #f 'a integer?) (hash 'a 5))
]
}

@section{Generic Dictionary Interface}

@defidform[gen:dict]{

A @tech{generic interface} (see @secref["struct-generics"]) that
supplies dictionary method implementations for a structure type via the
@racket[#:methods] option of @racket[struct] definitions.  This interface can
be used to implement any of the methods documented as
@secref["primitive-dict-methods"] and @secref["derived-dict-methods"].

@examples[#:eval dict-eval
(struct alist (v)
  #:methods gen:dict
  [(define (dict-ref dict key
                     [default (lambda () (error "key not found" key))])
     (cond [(assoc key (alist-v dict)) => cdr]
           [else (if (procedure? default) (default) default)]))
   (define (dict-set dict key val)
     (alist (cons (cons key val) (alist-v dict))))
   (define (dict-remove dict key)
     (define al (alist-v dict))
     (alist (remove* (filter (λ (p) (equal? (car p) key)) al) al)))
   (define (dict-count dict)
     (length (remove-duplicates (alist-v dict) #:key car)))]) (code:comment "etc. other methods")

  (define d1 (alist '((1 . a) (2 . b))))
  (dict? d1)
  (dict-ref d1 1)
  (dict-remove d1 1)
]

}

@defthing[prop:dict struct-type-property?]{
  A structure type property used to define custom extensions
  to the dictionary API. Using the @racket[prop:dict] property is
  discouraged; use the @racket[gen:dict] @tech{generic interface}
  instead. Accepts a vector of 10 method implementations:

  @itemize[
           @item{@racket[dict-ref]}
           @item{@racket[dict-set!], or @racket[#f] if unsupported}
           @item{@racket[dict-set], or @racket[#f] if unsupported}
           @item{@racket[dict-remove!], or @racket[#f] if unsupported}
           @item{@racket[dict-remove], or @racket[#f] if unsupported}
           @item{@racket[dict-count]}
           @item{@racket[dict-iterate-first]}
           @item{@racket[dict-iterate-next]}
           @item{@racket[dict-iterate-key]}
           @item{@racket[dict-iterate-value]}
           ]
}

@subsection[#:tag "primitive-dict-methods"]{Primitive Dictionary Methods}

These methods of @racket[gen:dict] have no fallback implementations; they are
only supported for dictionary types that directly implement them.

@defproc[(dict-ref [dict dict?]
                   [key any/c]
                   [failure-result failure-result/c
                                   (lambda () (raise (make-exn:fail ....)))])
         any]{

Returns the value for @racket[key] in @racket[dict]. If no value
is found for @racket[key], then @racket[failure-result] determines the
result:

@itemize[

 @item{If @racket[failure-result] is a procedure, it is called
       (through a tail call) with no arguments to produce the result.}

 @item{Otherwise, @racket[failure-result] is returned as the result.}

]

@examples[
#:eval dict-eval
(dict-ref #hash((a . "apple") (b . "beer")) 'a)
(eval:error (dict-ref #hash((a . "apple") (b . "beer")) 'c))
(dict-ref #hash((a . "apple") (b . "beer")) 'c #f)
(dict-ref '((a . "apple") (b . "banana")) 'b)
(dict-ref #("apple" "banana") 1)
(dict-ref #("apple" "banana") 3 #f)
(eval:error (dict-ref #("apple" "banana") -3 #f))
]}

@defproc[(dict-set! [dict (and/c dict? (not/c immutable?))]
                    [key any/c]
                    [v any/c]) void?]{

Maps @racket[key] to @racket[v] in @racket[dict], overwriting any
existing mapping for @racket[key]. The update can fail with a
@racket[exn:fail:contract] exception if @racket[dict] is not mutable
or if @racket[key] is not an allowed key for the dictionary (e.g., not
an exact integer in the appropriate range when @racket[dict] is a
@tech{vector}).

@examples[
#:eval dict-eval
(define h (make-hash))
(dict-set! h 'a "apple")
h
(define v (vector #f #f #f))
(dict-set! v 0 "apple")
v
]}

@defproc[(dict-set [dict (and/c dict? immutable?)]
                   [key any/c]
                   [v any/c])
          (and/c dict? immutable?)]{

Functionally extends @racket[dict] by mapping @racket[key] to
@racket[v], overwriting any existing mapping for @racket[key], and
returning an extended dictionary. The update can fail with a
@racket[exn:fail:contract] exception if @racket[dict] does not support
functional extension or if @racket[key] is not an allowed key for the
dictionary.

@examples[
#:eval dict-eval
(dict-set #hash() 'a "apple")
(dict-set #hash((a . "apple") (b . "beer")) 'b "banana")
(dict-set '() 'a "apple")
(dict-set '((a . "apple") (b . "beer")) 'b "banana")
]}


@defproc[(dict-remove! [dict (and/c dict? (not/c immutable?))]
                       [key any/c])
         void?]{

Removes any existing mapping for @racket[key] in @racket[dict]. The
update can fail if @racket[dict] is not mutable or does not support
removing keys (as is the case for @tech{vectors}, for example).

@examples[
#:eval dict-eval
(define h (make-hash))
(dict-set! h 'a "apple")
h
(dict-remove! h 'a)
h]}


@defproc[(dict-remove [dict (and/c dict? immutable?)]
                      [key any/c])
         (and/c dict? immutable?)]{

Functionally removes any existing mapping for @racket[key] in
@racket[dict], returning the fresh dictionary.  The update can fail
if @racket[dict] does not support functional update or does not
support removing keys.

@examples[
#:eval dict-eval
(define h #hash())
(define h (dict-set h 'a "apple"))
h
(dict-remove h 'a)
h
(dict-remove h 'z)
(dict-remove '((a . "apple") (b . "banana")) 'a)
]}


@defproc[(dict-iterate-first [dict dict?]) any/c]{

Returns @racket[#f] if @racket[dict] contains no elements, otherwise
it returns a non-@racket[#f] value that is an index to the first
element in the dict table; ``first'' refers to an unspecified ordering
of the dictionary elements. For a mutable @racket[dict], this index is
guaranteed to refer to the first item only as long as no mappings are
added to or removed from @racket[dict].

@examples[
#:eval dict-eval
(dict-iterate-first #hash((a . "apple") (b . "banana")))
(dict-iterate-first #hash())
(dict-iterate-first #("apple" "banana"))
(dict-iterate-first '((a . "apple") (b . "banana")))
]}


@defproc[(dict-iterate-next [dict dict?]
                            [pos any/c])
         any/c]{

Returns either a non-@racket[#f] that is an index to the element in
@racket[dict] after the element indexed by @racket[pos] or @racket[#f]
if @racket[pos] refers to the last element in @racket[dict]. If
@racket[pos] is not a valid index, then the
@exnraise[exn:fail:contract]. For a mutable @racket[dict], the result
index is guaranteed to refer to its item only as long as no items are
added to or removed from @racket[dict]. The @racket[dict-iterate-next]
operation should take constant time.

@examples[
#:eval dict-eval
(define h #hash((a . "apple") (b . "banana")))
(define i (dict-iterate-first h))
i
(dict-iterate-next h i)
(dict-iterate-next h (dict-iterate-next h i))
]}


@defproc[(dict-iterate-key [dict dict?]
                           [pos any/c])
         any]{

Returns the key for the element in @racket[dict] at index
@racket[pos]. If @racket[pos] is not a valid index for @racket[dict],
the @exnraise[exn:fail:contract]. The @racket[dict-iterate-key]
operation should take constant time.

@examples[
#:eval dict-eval
(define h '((a . "apple") (b . "banana")))
(define i (dict-iterate-first h))
(dict-iterate-key h i)
(dict-iterate-key h (dict-iterate-next h i))
]}



@defproc[(dict-iterate-value [dict dict?]
                             [pos any/c])
         any]{

Returns the value for the element in @racket[dict] at index
@racket[pos]. If @racket[pos] is not a valid index for @racket[dict],
the @exnraise[exn:fail:contract]. The @racket[dict-iterate-key]
operation should take constant time.

@examples[
#:eval dict-eval
(define h '((a . "apple") (b . "banana")))
(define i (dict-iterate-first h))
(dict-iterate-value h i)
(dict-iterate-value h (dict-iterate-next h i))
]}

@subsection[#:tag "derived-dict-methods"]{Derived Dictionary Methods}

These methods of @racket[gen:dict] have fallback implementations in terms of
the other methods; they may be supported even by dictionary types that do not
directly implement them.

@defproc[(dict-has-key? [dict dict?] [key any/c])
         boolean?]{

Returns @racket[#t] if @racket[dict] contains a value for the given
@racket[key], @racket[#f] otherwise.

Supported for any @racket[dict] that implements @racket[dict-ref].

@examples[
#:eval dict-eval
(dict-has-key? #hash((a . "apple") (b . "beer")) 'a)
(dict-has-key? #hash((a . "apple") (b . "beer")) 'c)
(dict-has-key? '((a . "apple") (b . "banana")) 'b)
(dict-has-key? #("apple" "banana") 1)
(dict-has-key? #("apple" "banana") 3)
(dict-has-key? #("apple" "banana") -3)
]}

@defproc[(dict-set*! [dict (and/c dict? (not/c immutable?))]
                     [key any/c]
                     [v any/c]
                     ...
                     ...) void?]{

Maps each @racket[key] to each @racket[v] in @racket[dict], overwriting any
existing mapping for each @racket[key]. The update can fail with a
@racket[exn:fail:contract] exception if @racket[dict] is not mutable
or if any @racket[key] is not an allowed key for the dictionary (e.g., not
an exact integer in the appropriate range when @racket[dict] is a
@tech{vector}). The update takes place from the left, so later mappings overwrite
earlier mappings.

Supported for any @racket[dict] that implements @racket[dict-set!].

@examples[
#:eval dict-eval
(define h (make-hash))
(dict-set*! h 'a "apple" 'b "banana")
h
(define v1 (vector #f #f #f))
(dict-set*! v1 0 "apple" 1 "banana")
v1
(define v2 (vector #f #f #f))
(dict-set*! v2 0 "apple" 0 "banana")
v2
]}

@defproc[(dict-set* [dict (and/c dict? immutable?)]
                    [key any/c]
                    [v any/c]
                    ...
                    ...)
          (and/c dict? immutable?)]{

Functionally extends @racket[dict] by mapping each @racket[key] to
each @racket[v], overwriting any existing mapping for each @racket[key], and
returning an extended dictionary. The update can fail with a
@racket[exn:fail:contract] exception if @racket[dict] does not support
functional extension or if any @racket[key] is not an allowed key for the
dictionary. The update takes place from the left, so later mappings overwrite
earlier mappings.

Supported for any @racket[dict] that implements @racket[dict-set].

@examples[
#:eval dict-eval
(dict-set* #hash() 'a "apple" 'b "beer")
(dict-set* #hash((a . "apple") (b . "beer")) 'b "banana" 'a "anchor")
(dict-set* '() 'a "apple" 'b "beer")
(dict-set* '((a . "apple") (b . "beer")) 'b "banana" 'a "anchor")
(dict-set* '((a . "apple") (b . "beer")) 'b "banana" 'b "ballistic")
]}

@defproc[(dict-ref! [dict dict?]
                    [key any/c]
                    [to-set any/c])
         any]{

Returns the value for @racket[key] in @racket[dict]. If no value
is found for @racket[key], then @racket[to-set] determines the
result as in @racket[dict-ref] (i.e., it is either a thunk that computes a value
or a plain value), and this result is stored in @racket[dict] for the
@racket[key].  (Note that if @racket[to-set] is a thunk, it is not
invoked in tail position.)

Supported for any @racket[dict] that implements @racket[dict-ref] and
@racket[dict-set!].

@examples[
#:eval dict-eval
(dict-ref! (make-hasheq '((a . "apple") (b . "beer"))) 'a #f)
(dict-ref! (make-hasheq '((a . "apple") (b . "beer"))) 'c 'cabbage)
(define h (make-hasheq '((a . "apple") (b . "beer"))))
(eval:error (dict-ref h 'c))
(dict-ref! h 'c (λ () 'cabbage))
(dict-ref h 'c)
]}

@defproc[(dict-update! [dict (and/c dict? (not/c immutable?))]
                       [key any/c]
                       [updater (any/c . -> . any/c)]
                       [failure-result failure-result/c
                                       (lambda () (raise (make-exn:fail ....)))]) void?]{

Composes @racket[dict-ref] and @racket[dict-set!] to update an
existing mapping in @racket[dict], where the optional @racket[failure-result]
argument is used as in @racket[dict-ref] when no mapping exists for
@racket[key] already.

Supported for any @racket[dict] that implements @racket[dict-ref] and
@racket[dict-set!].

@examples[
#:eval dict-eval
(define h (make-hash))
(eval:error (dict-update! h 'a add1))
(dict-update! h 'a add1 0)
h
(define v (vector #f #f #f))
(dict-update! v 0 not)
v
]}


@defproc[(dict-update [dict dict?]
                      [key any/c]
                      [updater (any/c . -> . any/c)]
                      [failure-result failure-result/c
                                      (lambda () (raise (make-exn:fail ....)))])
          (and/c dict? immutable?)]{

Composes @racket[dict-ref] and @racket[dict-set] to functionally
update an existing mapping in @racket[dict], where the optional @racket[failure-result]
argument is used as in @racket[dict-ref] when no mapping exists for
@racket[key] already.

Supported for any @racket[dict] that implements @racket[dict-ref] and
@racket[dict-set].

@examples[
#:eval dict-eval
(eval:error (dict-update #hash() 'a add1))
(dict-update #hash() 'a add1 0)
(dict-update #hash((a . "apple") (b . "beer")) 'b string-length)
]}


@defproc[(dict-map [dict dict?]
                   [proc (any/c any/c . -> . any/c)])
         (listof any/c)]{

Applies the procedure @racket[proc] to each element in
@racket[dict] in an unspecified order, accumulating the results
into a list. The procedure @racket[proc] is called each time with a
key and its value.

Supported for any @racket[dict] that implements @racket[dict-iterate-first],
@racket[dict-iterate-next], @racket[dict-iterate-key], and
@racket[dict-iterate-value].

@examples[
#:eval dict-eval
(dict-map #hash((a . "apple") (b . "banana")) vector)
]}


@defproc[(dict-map/copy [dict dict?]
                        [proc (any/c any/c . -> . (values any/c any/c))])
         dict?]{

Applies the procedure @racket[proc] to each element in
@racket[dict] in an unspecified order, accumulating the results
into a dict of the same kind.
The procedure @racket[proc] is called each time with a key
and its value, and must return a corresponding key and
value.

Supported for any @racket[dict] that implements
@racket[dict-iterate-first], @racket[dict-iterate-next],
@racket[dict-iterate-key], and @racket[dict-iterate-value],
and either @racket[dict-set] and @racket[dict-clear], or
@racket[dict-set!], @racket[dict-copy], and
@racket[dict-clear!].

@examples[
#:eval dict-eval
(dict-map/copy #hash((a . "apple") (b . "banana")) (lambda (k v) (values k (string-upcase v))))
]

@history[#:added "8.5.0.2"]}


@defproc[(dict-for-each [dict dict?]
                        [proc (any/c any/c . -> . any)])
         void?]{

Applies @racket[proc] to each element in @racket[dict] (for the
side-effects of @racket[proc]) in an unspecified order. The procedure
@racket[proc] is called each time with a key and its value.

Supported for any @racket[dict] that implements @racket[dict-iterate-first],
@racket[dict-iterate-next], @racket[dict-iterate-key], and
@racket[dict-iterate-value].

@examples[
#:eval dict-eval
(dict-for-each #hash((a . "apple") (b . "banana"))
               (lambda (k v)
                 (printf "~a = ~s\n" k v)))
]}


@defproc[(dict-empty? [dict dict?]) boolean?]{

Reports whether @racket[dict] is empty.

Supported for any @racket[dict] that implements @racket[dict-iterate-first].

@examples[
#:eval dict-eval
(dict-empty? #hash((a . "apple") (b . "banana")))
(dict-empty? (vector))
]

}

@defproc[(dict-count [dict dict?])
         exact-nonnegative-integer?]{

Returns the number of keys mapped by @racket[dict], usually in
constant time.

Supported for any @racket[dict] that implements @racket[dict-iterate-first]
and @racket[dict-iterate-next].

@examples[
#:eval dict-eval
(dict-count #hash((a . "apple") (b . "banana")))
(dict-count #("apple" "banana"))
]}

@defproc[(dict-copy [dict dict?]) dict?]{

Produces a new, mutable dictionary of the same type as @racket[dict] and with
the same key/value associations.

Supported for any @racket[dict] that implements @racket[dict-clear],
@racket[dict-set!], @racket[dict-iterate-first], @racket[dict-iterate-next],
@racket[dict-iterate-key], and @racket[dict-iterate-value].

@examples[
#:eval dict-eval
(define original (vector "apple" "banana"))
(define copy (dict-copy original))
original
copy
(dict-set! copy 1 "carrot")
original
copy
]

}

@defproc[(dict-clear [dict dict?]) dict?]{

Produces an empty dictionary of the same type as @racket[dict].  If
@racket[dict] is mutable, the result must be a new dictionary.

Supported for any @racket[dict] that supports @racket[dict-remove],
@racket[dict-iterate-first], @racket[dict-iterate-next], and
@racket[dict-iterate-key].

@examples[
#:eval dict-eval
(dict-clear #hash((a . "apple") ("banana" . b)))
(dict-clear '((1 . two) (three . "four")))
]

}

@defproc[(dict-clear! [dict dict?]) void?]{

Removes all of the key/value associations in @racket[dict].

Supported for any @racket[dict] that supports @racket[dict-remove!],
@racket[dict-iterate-first], and @racket[dict-iterate-key].

@examples[
#:eval dict-eval
(define table (make-hash))
(dict-set! table 'a "apple")
(dict-set! table "banana" 'b)
table
(dict-clear! table)
table
]

}

@defproc[(dict-keys [dict dict?]) list?]{
Returns a list of the keys from
@racket[dict] in an unspecified order.

Supported for any @racket[dict] that implements @racket[dict-iterate-first],
@racket[dict-iterate-next], and @racket[dict-iterate-key].

@examples[
#:eval dict-eval
(define h #hash((a . "apple") (b . "banana")))
(dict-keys h)
]}

@defproc[(dict-values [dict dict?]) list?]{
Returns a list of the values from
@racket[dict] in an unspecified order.

Supported for any @racket[dict] that implements @racket[dict-iterate-first],
@racket[dict-iterate-next], and @racket[dict-iterate-value].

@examples[
#:eval dict-eval
(define h #hash((a . "apple") (b . "banana")))
(dict-values h)
]}

@defproc[(dict->list [dict dict?]) list?]{
Returns a list of the associations from
@racket[dict] in an unspecified order.

Supported for any @racket[dict] that implements @racket[dict-iterate-first],
@racket[dict-iterate-next], @racket[dict-iterate-key], and
@racket[dict-iterate-value].

@examples[
#:eval dict-eval
(define h #hash((a . "apple") (b . "banana")))
(dict->list h)
]}
@section{Dictionary Sequences}

@defproc[(in-dict [dict dict?]) sequence?]{ Returns a @tech{sequence}
whose each element is two values: a key and corresponding value from
@racket[dict].

Supported for any @racket[dict] that implements @racket[dict-iterate-first],
@racket[dict-iterate-next], @racket[dict-iterate-key], and
@racket[dict-iterate-value].

@examples[
#:eval dict-eval
(define h #hash((a . "apple") (b . "banana")))
(for/list ([(k v) (in-dict h)])
  (format "~a = ~s" k v))
]}


@defproc[(in-dict-keys [dict dict?]) sequence?]{
Returns a sequence whose elements are the keys of @racket[dict].

Supported for any @racket[dict] that implements @racket[dict-iterate-first],
@racket[dict-iterate-next], and @racket[dict-iterate-key].

@examples[
#:eval dict-eval
(define h #hash((a . "apple") (b . "banana")))
(for/list ([k (in-dict-keys h)])
  k)
]}

@defproc[(in-dict-values [dict dict?]) sequence?]{
Returns a sequence whose elements are the values of @racket[dict].

Supported for any @racket[dict] that implements @racket[dict-iterate-first],
@racket[dict-iterate-next], and @racket[dict-iterate-value].

@examples[
#:eval dict-eval
(define h #hash((a . "apple") (b . "banana")))
(for/list ([v (in-dict-values h)])
  v)
]}

@defproc[(in-dict-pairs [dict dict?]) sequence?]{ Returns a sequence
whose elements are pairs, each containing a key and its value from
@racket[dict] (as opposed to using @racket[in-dict], which gets the
key and value as separate values for each element).

Supported for any @racket[dict] that implements @racket[dict-iterate-first],
@racket[dict-iterate-next], @racket[dict-iterate-key], and
@racket[dict-iterate-value].

@examples[
#:eval dict-eval
(define h #hash((a . "apple") (b . "banana")))
(for/list ([p (in-dict-pairs h)])
  p)
]}

@section{Contracted Dictionaries}

@defthing[prop:dict/contract struct-type-property?]{

A structure type property for defining dictionaries with
contracts. The value associated with @racket[prop:dict/contract] must
be a list of two immutable vectors:

@racketblock[
(list _dict-vector
      (vector _type-key-contract
              _type-value-contract
              _type-iter-contract
              _instance-key-contract
              _instance-value-contract
              _instance-iter-contract))
]

The first vector must be a vector of 10 procedures which match the
@racket[gen:dict] @tech{generic interface} (in addition, it must be an
immutable vector). The second vector must contain six elements; each
of the first three is a contract for the dictionary type's keys,
values, and positions, respectively. Each of the second three is
either @racket[#f] or a procedure used to extract the contract from
a dictionary instance.
}

@deftogether[[
@defproc[(dict-key-contract [d dict?]) contract?]
@defproc[(dict-value-contract [d dict?]) contract?]
@defproc[(dict-iter-contract [d dict?]) contract?]]]{

Returns the contract that @racket[d] imposes on its keys, values, or
iterators, respectively, if @racket[d] implements the
@racket[prop:dict/contract] interface.
}

@section{Custom Hash Tables}

@defform[(define-custom-hash-types name
                                   optional-predicate
                                   comparison-expr
                                   optional-hash-functions)
         #:grammar ([optional-predicate
                     (code:line)
                     (code:line #:key? predicate-expr)]
                    [optional-hash-functions
                     (code:line)
                     (code:line hash1-expr)
                     (code:line hash1-expr hash2-expr)])]{

Creates a new dictionary type based on the given comparison
@racket[comparison-expr], hash functions @racket[hash1-expr] and
@racket[hash2-expr], and key predicate @racket[predicate-expr]; the interfaces
for these functions are the same as in @racket[make-custom-hash-types].
The new dictionary type has three variants: immutable, mutable with
strongly-held keys, and mutable with weakly-held keys.

Defines seven names:

@itemize[
@item{@racket[name]@racketidfont{?} recognizes instances of the new type,}
@item{@racketidfont{immutable-}@racket[name]@racketidfont{?} recognizes
      immutable instances of the new type,}
@item{@racketidfont{mutable-}@racket[name]@racketidfont{?} recognizes
      mutable instances of the new type with strongly-held keys,}
@item{@racketidfont{weak-}@racket[name]@racketidfont{?} recognizes
      mutable instances of the new type with weakly-held keys,}
@item{@racketidfont{make-immutable-}@racket[name] constructs
      immutable instances of the new type,}
@item{@racketidfont{make-mutable-}@racket[name] constructs
      mutable instances of the new type with strongly-held keys, and}
@item{@racketidfont{make-weak-}@racket[name] constructs
      mutable instances of the new type with weakly-held keys.}
]

The constructors all accept a dictionary as an optional argument, providing
initial key/value pairs.

@examples[
#:eval dict-eval
(define-custom-hash-types string-hash
                          #:key? string?
                          string=?
                          string-length)
(define imm
  (make-immutable-string-hash
   '(("apple" . a) ("banana" . b))))
(define mut
  (make-mutable-string-hash
   '(("apple" . a) ("banana" . b))))
(dict? imm)
(dict? mut)
(string-hash? imm)
(string-hash? mut)
(immutable-string-hash? imm)
(immutable-string-hash? mut)
(dict-ref imm "apple")
(dict-ref mut "banana")
(dict-set! mut "banana" 'berry)
(dict-ref mut "banana")
(equal? imm mut)
(equal? (dict-remove (dict-remove imm "apple") "banana")
        (make-immutable-string-hash))
]

}

@defproc[(make-custom-hash-types
          [eql?
           (or/c (any/c any/c . -> . any/c)
                 (any/c any/c (any/c any/c . -> . any/c) . -> . any/c))]
          [hash1
           (or/c (any/c . -> . exact-integer?)
                 (any/c (any/c . -> . exact-integer?) . -> . exact-integer?))
           (const 1)]
          [hash2
           (or/c (any/c . -> . exact-integer?)
                 (any/c (any/c . -> . exact-integer?) . -> . exact-integer?))
           (const 1)]
          [#:key? key? (any/c . -> . boolean?) (const #true)]
          [#:name name symbol? 'custom-hash]
          [#:for who symbol? 'make-custom-hash-types])
         (values (any/c . -> . boolean?)
                 (any/c . -> . boolean?)
                 (any/c . -> . boolean?)
                 (any/c . -> . boolean?)
                 (->* [] [dict?] dict?)
                 (->* [] [dict?] dict?)
                 (->* [] [dict?] dict?))]{

Creates a new dictionary type based on the given comparison function
@racket[eql?], hash functions @racket[hash1] and @racket[hash2], and predicate
@racket[key?].  The new dictionary type has variants that are immutable,
mutable with strongly-held keys, and mutable with weakly-held keys.  The given
@racket[name] is used when printing instances of the new dictionary type, and
the symbol @racket[who] is used for reporting errors.

The comparison function @racket[eql?] may accept 2 or 3 arguments.  If it
accepts 2 arguments, it given two keys to compare them.  If it accepts
3 arguments and does not accept 2 arguments, it is also given a
recursive comparison function that handles data cycles when comparing sub-parts
of the keys.

The hash functions @racket[hash1] and @racket[hash2] may accept 1 or 2
arguments.  If either hash function accepts 1 argument, it is applied to a key
to compute the corresponding hash value.  If either hash function accepts 2
arguments and does not accept 1 argument, it is also given a recursive hash
function that handles data cycles when computing hash values of sub-parts of
the keys.

The predicate @racket[key?] must accept 1 argument and is used to recognize
valid keys for the new dictionary type.

Produces seven values:

@itemize[
@item{a predicate recognizing all instances of the new dictionary type,}
@item{a predicate recognizing immutable instances,}
@item{a predicate recognizing mutable instances,}
@item{a predicate recognizing weak instances,}
@item{a constructor for immutable instances,}
@item{a constructor for mutable instances, and}
@item{a constructor for weak instances.}
]

See @racket[define-custom-hash-types] for an example.

}

@deftogether[(
@defproc[(make-custom-hash
          [eql?
           (or/c (any/c any/c . -> . any/c)
                 (any/c any/c (any/c any/c . -> . any/c) . -> . any/c))]
          [hash1
           (or/c (any/c . -> . exact-integer?)
                 (any/c (any/c . -> . exact-integer?) . -> . exact-integer?))
           (const 1)]
          [hash2
           (or/c (any/c . -> . exact-integer?)
                 (any/c (any/c . -> . exact-integer?) . -> . exact-integer?))
           (const 1)]
          [#:key? key? (any/c . -> . boolean?) (λ (x) #true)])
         dict?]
@defproc[(make-weak-custom-hash
          [eql?
           (or/c (any/c any/c . -> . any/c)
                 (any/c any/c (any/c any/c . -> . any/c) . -> . any/c))]
          [hash1
           (or/c (any/c . -> . exact-integer?)
                 (any/c (any/c . -> . exact-integer?) . -> . exact-integer?))
           (const 1)]
          [hash2
           (or/c (any/c . -> . exact-integer?)
                 (any/c (any/c . -> . exact-integer?) . -> . exact-integer?))
           (const 1)]
          [#:key? key? (any/c . -> . boolean?) (λ (x) #true)])
         dict?]
@defproc[(make-immutable-custom-hash
          [eql?
           (or/c (any/c any/c . -> . any/c)
                 (any/c any/c (any/c any/c . -> . any/c) . -> . any/c))]
          [hash1
           (or/c (any/c . -> . exact-integer?)
                 (any/c (any/c . -> . exact-integer?) . -> . exact-integer?))
           (const 1)]
          [hash2
           (or/c (any/c . -> . exact-integer?)
                 (any/c (any/c . -> . exact-integer?) . -> . exact-integer?))
           (const 1)]
          [#:key? key? (any/c . -> . boolean?) (λ (x) #true)])
         dict?]
)]{

 Creates an instance of a new dictionary type, implemented
 in terms of a hash table where keys are compared with
 @racket[eql?], hashed with @racket[hash1] and
 @racket[hash2], and where the key predicate is
 @racket[key?]. See @racket[gen:equal-mode+hash] and @racket[gen:equal+hash] for information
 on suitable equality and hashing functions.

The @racket[make-custom-hash] and @racket[make-weak-custom-hash]
functions create a mutable dictionary that does not support functional
update, while @racket[make-immutable-custom-hash] creates an immutable
dictionary that supports functional update. The dictionary created by
@racket[make-weak-custom-hash] retains its keys weakly, like the result
of @racket[make-weak-hash].

Dictionaries created by @racket[make-custom-hash] and company are
@racket[equal?] when they have the same mutability and key strength,
the associated procedures are @racket[equal?], and the key--value
mappings are the same when keys and values are compared with
@racket[equal?].

See also @racket[define-custom-hash-types].

@examples[
#:eval dict-eval
(define h (make-custom-hash (lambda (a b)
                              (string=? (format "~a" a)
                                        (format "~a" b)))
                            (lambda (a)
                              (equal-hash-code
                               (format "~a" a)))))
(dict-set! h 1 'one)
(dict-ref h "1")
]


}

@section{Passing Keyword Arguments in Dictionaries}

@defproc[
 (keyword-apply/dict [proc procedure?]
                     [kw-dict dict?] ; (dict/c keyword? any/c)
                     [pos-arg any/c] ...
                     [pos-args (listof any/c)]
                     [#:<kw> kw-arg any/c] ...)
 any]{
Applies the @racket[proc] using the positional arguments
from @racket[(list* pos-arg ... pos-args)], and the keyword
arguments from @racket[kw-dict] in addition to the directly
supplied keyword arguments in the @racket[#:<kw> kw-arg]
 sequence.

All the keys in @racket[kw-dict] must be keywords.
The keywords in the @racket[kw-dict] do not have to be
sorted. However, the keywords in @racket[kw-dict] and the
directly supplied @racket[#:<kw>] keywords must not overlap.
The given @racket[proc] must accept all of the keywords in
@racket[kw-dict] plus the @racket[#:<kw>]s.

@examples[
#:eval dict-eval
(define (sundae #:ice-cream [ice-cream '("vanilla")]
                #:toppings [toppings '("brownie-bits")]
                #:sprinkles [sprinkles "chocolate"]
                #:syrup [syrup "caramel"])
  (format "A sundae with ~a ice cream, ~a, ~a sprinkles, and ~a syrup."
          (string-join ice-cream #:before-last " and ")
          (string-join toppings #:before-last " and ")
          sprinkles
          syrup))
(keyword-apply/dict sundae '((#:ice-cream . ("chocolate"))) '())
(keyword-apply/dict sundae
                    (hash '#:toppings '("cookie-dough")
                          '#:sprinkles "rainbow"
                          '#:syrup "chocolate")
                    '())
(keyword-apply/dict sundae
                    #:sprinkles "rainbow"
                    (hash '#:toppings '("cookie-dough")
                          '#:syrup "chocolate")
                    '())
]
@history[#:added "7.9"]}


@close-eval[dict-eval]
