#lang scribble/doc
@(require "utils.rkt")

@title{Miscellaneous Support}

@defproc[(list->cblock [lst list?]
                       [type ctype?]
                       [expect-length (or/c exact-nonnegative-integer? #f) #f]
                       [#:malloc-mode malloc-mode (or/c #f symbol?) #f])
         cpointer?]{

Allocates a memory block of an appropriate size---using
@racket[malloc] with @racket[type] and @racket[(length lst)]---and
initializes it using values from @racket[lst].  The
@racket[lst] must hold values that can all be converted to C values
according to the given @racket[type].

If @racket[expect-length] is not @racket[#f] and not the same as
@racket[(length lst)], then an exception is raised instead of
allocating memory.

If @racket[malloc-mode] is not @racket[#f], it is provided as an
additional argument to @racket[malloc].

@history[#:changed "7.7.0.2" @elem{Added the @racket[#:malloc-mode] argument.}]}


@defproc[(vector->cblock [vec vector?]
                         [type ctype?]
                         [expect-length (or/c exact-nonnegative-integer? #f) #f]
                         [#:malloc-mode malloc-mode (or/c #f symbol?) #f])
         cpointer?]{

Like @racket[list->cblock], but using values from a vector instead of
a list.

@history[#:changed "7.7.0.2" @elem{Added the @racket[#:malloc-mode] argument.}]}


@defproc[(vector->cpointer [vec vector?]) cpointer?]{

Returns a pointer to an array of @racket[_scheme] values, which is the
internal representation of @racket[vec].}

@defproc[(flvector->cpointer [flvec flvector?]) cpointer?]{

Returns a pointer to an array of @racket[_double] values, which is the
internal representation of @racket[flvec].}

@defproc*[([(saved-errno) exact-integer?]
           [(saved-errno [new-value exact-integer?]) void?])]{

Returns or sets the error code saved for the current Racket
thread. The saved error code is set after a foreign call with a
non-@racket[#f] @racket[#:save-errno] option (see @racket[_fun] and
@racket[_cprocedure]), but it can also be set explicitly (for example,
to create mock foreign functions for testing).

@history[#:changed "6.4.0.9"]{Added the one-argument variant.}}

@defproc[(lookup-errno [sym symbol?])
         (or/c exact-integer? #f)]{

Returns a platform-specific positive integer corresponding to a POSIX
@tt{errno} code, or @racket[#f] if the code is unknown. A code's value
is known if the code is one of the recognized symbols described below
@emph{and} the code was defined by the @tt{"errno.h"} header used to
compile Racket. Note that the contents of @tt{"errno.h"} vary based on
platform and compiler.

The recognized symbols currently consist of the 81 codes defined by
@hyperlink["http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/errno.h.html"]{IEEE
Std 1003.1, 2013 Edition} (also known as POSIX.1), including
@racket['EINTR], @racket['EEXIST], and @racket['EAGAIN].

@history[#:changed "6.6.0.5" @elem{Relaxed the contract and added
support for more symbols.}]}


@defproc[(cast [v any/c] [from-type ctype?] [to-type ctype?]) any/c]{

Converts @racket[v] from a value matching @racket[from-type] to a
value matching @racket[to-type], where @racket[(ctype-sizeof from-type)]
matches @racket[(ctype-sizeof to-type)].

The conversion is roughly equivalent to

@racketblock[
  (let ([p (malloc from-type)])
    (ptr-set! p from-type v)
    (ptr-ref p to-type))
]

If @racket[v] is a cpointer, @racket[(cpointer-gcable?  v)] is true,
and @racket[from-type] and @racket[to-type] are both based on
@racket[_pointer] or @racket[_gcpointer], then @racket[from-type] is
implicitly converted with @racket[_gcable] to ensure that the result
cpointer is treated as referring to memory that is managed by the
garbage collector.

If @racket[v] is a pointer with an offset component (e.g., from
@racket[ptr-add]), @racket[(cpointer-gcable? v)] is true, and the
result is a cpointer, then the result pointer has the same offset
component as @racket[v]. If @racket[(cpointer-gcable? v)] is false,
then any offset is folded into the pointer base for the result.}


@defproc[(cblock->list [cblock any/c] [type ctype?] [length exact-nonnegative-integer?])
         list?]{

Converts C @racket[cblock], which is a vector of @racket[type]s, to a
Racket list.  The arguments are the same as in the
@racket[list->cblock]. The @racket[length] must be specified because
there is no way to know where the block ends.}


@defproc[(cblock->vector [cblock any/c] [type ctype?] [length exact-nonnegative-integer?])
         vector?]{

Like @racket[cblock->list], but for Racket vectors.}


@defform*[[(_delay ctype)
           (_delay ctype base-ctype)]
          #:contracts ([type-expr ctype?]
                       [base-type-expr ctype?])]{

Returns a C type @racket[_delayed-ctype] that converts values like
@racket[ctype] but delays the evaluation of @racket[ctype] until it is need
to perform a conversion, such as for a foreign call or struct access. The
@racket[base-ctype] is used for the size and foreign representation of
@racket[_delayed-ctype]; if it is not specified, it defaults to
@racket[_pointer].

If @racket[ctype] and @racket[base-ctype] have different sizes, an exception
is raised when @racket[_delayed-ctype] is used to perform a conversion.

Use @racket[_delay] for forward references, for example in mutually
recursive C struct definitions:
@racketblock[
(define-cstruct _Person
  ([name _string]
   [friends (_delay _PersonList-pointer/null)]))
(define-cstruct _PersonList
  ([first _Person-pointer]
   [rest _PersonList-pointer/null]))
]

@history[#:added "8.4.0.7"]}
