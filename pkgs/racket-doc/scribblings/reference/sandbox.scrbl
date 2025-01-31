#lang scribble/doc
@(require "mz.rkt" racket/sandbox
          (for-label racket/sandbox
                     racket/port
                     (only-in racket/gui make-gui-namespace)
                     racket/gui/dynamic))

@(define box-eval (make-base-eval))
@examples[#:hidden #:eval box-eval (require racket/sandbox)]

@title{Sandboxed Evaluation}

@note-lib-only[racket/sandbox]

The @racketmodname[racket/sandbox] module provides utilities for
creating ``sandboxed'' evaluators, which are configured in a
particular way and can have restricted resources (memory and time),
filesystem and network access, and much more.  Sandboxed evaluators can be
configured through numerous parameters --- and the defaults are set
for the common use case where sandboxes are very limited.

@defproc*[([(make-evaluator [language (or/c module-path?
                                            (list/c 'special symbol?)
                                            (cons/c 'begin list?))]
                            [input-program any/c] ...
                            [#:requires requires 
                                        (listof (or/c module-path? path-string? 
                                                      (cons/c 'for-syntax (listof module-path?))))
                                        null]
                            [#:allow-for-require allow-for-require (listof (or/c module-path? path?)) null]
                            [#:allow-for-load allow-for-load (listof path-string?) null]
                            [#:allow-read allow-read (listof (or/c module-path? path-string?)) null]
                            [#:allow-syntactic-requires allow-syntactic-requires (or/c #f (listof module-path?)) #f])
            (any/c . -> . any)]
           [(make-module-evaluator [module-decl (or/c syntax? pair? path? input-port? string? bytes?)]
                                   [#:language  lang  (or/c #f module-path?) #f]
                                   [#:readers   readers  (or/c #f (listof module-path?)) (and lang (default-language-readers lang))]
                                   [#:allow-for-require allow-for-require (listof (or/c module-path? path?)) null]
                                   [#:allow-for-load allow-for-load (listof path-string?) null]
                                   [#:allow-read allow-read (listof (or/c module-path? path-string?)) null]
                                   [#:allow-syntactic-requires allow-syntactic-requires (or/c #f (listof module-path?)) #f])
            (any/c . -> . any)])]{

The @racket[make-evaluator] function creates an evaluator with a
@racket[language] and @racket[requires] specification, and starts
evaluating the given @racket[input-program]s. The
@racket[make-module-evaluator] function creates an evaluator that
works in the context of a given module. The result in either case is a
function for further evaluation.

The returned evaluator operates in an isolated and limited
environment. In particular, filesystem access is restricted, which may
interfere with using modules from the filesystem that are not
in a @tech{collection}.  See below for
information on the @racket[allow-for-require],
@racket[allow-for-load], and @racket[allow-read] arguments; collection-based
module files typically do not need to be included in those lists.  When
@racket[language] is a module path or when @racket[requires] is
provided, the indicated modules are implicitly included in the
@racket[allow-for-require] list. When @racket[allow-syntactic-requires]
is not @racket[#f], it constraints the set of modules that can be directly
referenced in a module; see below for more information.
(For backward compatibility,
non-@racket[module-path?] path strings are allowed in arguments like
@racket[requires]; they are implicitly converted to paths before
addition to @racket[allow-for-require].)

Each @racket[input-program] or @racket[module-decl] argument provides
a program in one of the following forms:

@itemize[

 @item{an input port used to read the program;}

 @item{a string or a byte string holding the complete input;}

 @item{a path that names a file holding the input; or}

 @item{an S-expression or a @tech{syntax object}, which is evaluated
       as with @racket[eval] (see also
       @racket[get-uncovered-expressions]).}
]

In the first three cases above, the program is read using
@racket[sandbox-reader], with line-counting enabled for sensible error
messages, and with @racket['program] as the source (used for testing
coverage).  In the last case, the input is expected to be the complete
program, and is converted to a @tech{syntax object} (using
@racket['program] as the source), unless it already is a @tech{syntax
object}.

The returned evaluator function accepts additional expressions
(each time it is called) in essentially the same form: a string or
byte string holding a sequence of expressions, a path for a file
holding expressions, an S-expression, or a @tech{syntax object}.  If
the evaluator receives an @racket[eof] value, it is terminated and
raises errors thereafter.  See also @racket[kill-evaluator], which
terminates the evaluator without raising an exception.

For @racket[make-evaluator], multiple @racket[input-program]s are
effectively concatenated to form a single program. The way that the
@racket[input-program]s are evaluated depends on the @racket[language]
argument:

@itemize[

 @item{The @racket[language] argument can be a module path (i.e., a
       datum that matches the grammar for @racket[_module-path] of
       @racket[require]).

       In this case, the @racket[input-program]s are automatically
       wrapped in a @racket[module], and the resulting evaluator works
       within the resulting module's namespace.}

 @item{The @racket[language] argument can be a list starting with
       @racket['special], which indicates a built-in language with
       special input configuration. The possible values are
       @racket['(special r5rs)] or a value indicating a teaching
       language: @racket['(special beginner)], @racket['(special
       beginner-abbr)], @racket['(special intermediate)],
       @racket['(special intermediate-lambda)], or @racket['(special
       advanced)].

       In this case, the @racket[input-program]s are automatically
       wrapped in a @racket[module], and the resulting evaluator works
       within the resulting module's namespace. In addition, certain
       parameters (such as such as @racket[read-accept-infix-dot]) are
       set to customize reading programs from strings and ports.

       This option is provided mainly for older test systems. Using
       @racket[make-module-evaluator] with input starting with
       @racketmodfont{#lang} is generally better.}

 @item{Finally, @racket[language] can be a list whose first element is
       @racket['begin].

       In this case, a new namespace is created using
       @racket[sandbox-namespace-specs], which by default creates a
       new namespace using @racket[sandbox-make-namespace] (which, in
       turn, uses @racket[make-base-namespace] or
       @racket[make-gui-namespace] depending on
       @racket[sandbox-gui-available] and @racket[gui-available?]).

       In the new namespace, @racket[language] is evaluated as an
       expression to further initialize the namespace.}

]

The @racket[requires] list adds additional imports to the module or
namespace for the @racket[input-program]s, even in the case that
@racket[require] is not made available through the @racket[language].
The @racket[allow-syntactic-requires] argument, if non-@racket[#f],
constrains @racket[require] references expanded in the module when the
@racket[language] argument implies a @racket[module] wrapper; more
precisely, it constrains the module paths that can be resolved when a
syntax object is provided to the @tech{module name resolver}, which
will include @racket[require] forms that are created by macro
expansion. A relative-submodule path using @racket[submod] followed by
either @racket["."] or @racket[".."] is always allowed.

The following examples illustrate the difference between an evaluator
that puts the program in a module and one that merely initializes a
top-level namespace:

@examples[#:label #f
#:eval box-eval
(eval:error
 (define base-module-eval 
   (code:comment @#,t{a module cannot have free variables...})
   (make-evaluator 'racket/base '(define (f) later))))
(define base-module-eval 
  (make-evaluator 'racket/base '(define (f) later)
                               '(define later 5)))
(base-module-eval '(f))

(define base-top-eval 
  (code:comment @#,t{non-module code can have free variables:})
  (make-evaluator '(begin) '(define (f) later)))
(base-top-eval '(+ 1 2))
(base-top-eval '(define later 5))
(base-top-eval '(f))
]

The @racket[make-module-evaluator] function is essentially a
restriction of @racket[make-evaluator], where the program must be a
module, and all imports are part of the program.  In some cases it is
useful to restrict the program to be a module using a specific module
in its language position; use the optional @racket[lang] argument
to specify such a restriction, where @racket[#f] means that no
restriction is enforced. The @racket[readers] argument similarly
constrains the paths that can follow @hash-lang[] or @schememetafont{#reader}
if it is not @racket[#f], and the default is based on @racket[lang].
The @racket[allow-syntactic-requires] argument is treated the same as
for @racket[make-evaluator] in the module-wrapper case.

When the program is specified as a path, then
the path is implicitly added to the @racket[allow-for-load] list.

@racketblock[
(define base-module-eval2
  (code:comment @#,t{equivalent to @racket[base-module-eval]:})
  (make-module-evaluator '(module m racket/base
                            (define (f) later)
                            (define later 5))))
]

The @racket[make-module-evaluator] function can be convenient for testing
module files: pass in a path value for the file
name, and you get back an evaluator in the module's context which you
can use with your favorite test facility.

In all cases, the evaluator operates in an isolated and limited
environment:
@itemize[

 @item{It uses a new custodian and namespace. When 
       @racket[gui-available?] and @racket[sandbox-gui-available] produce
       true, it is also runs in its own eventspace.}

 @item{The evaluator works under the @racket[sandbox-security-guard],
       which restricts file system and network access.}

 @item{The evaluator is contained in a memory-restricted environment,
       and each evaluation is wrapped in a @racket[call-with-limits]
       (when memory accounting is available); see also
       @racket[sandbox-memory-limit], @racket[sandbox-eval-limits] and
       @racket[set-eval-limits].}
]
Note that these limits apply to the creation of the sandbox
environment too --- so, for example, if the memory that is required to
create the sandbox is higher than the limit, then
@racket[make-evaluator] will fail with a memory limit exception.

The @racket[allow-for-require] and @racket[allow-for-load] arguments
adjust filesystem permissions to extend the set of files that
are usable by the evaluator. Modules that are in a collection
are automatically accessible, but the @racket[allow-for-require] argument lists
additional modules that can be @racket[require]d along with their imports
(transitively) through a filesystem path. The @racket[allow-for-load] argument
similarly lists files that can
be @racket[load]ed. (The precise permissions needed for
@racket[require] versus @racket[load] can differ.)  The
@racket[allow-read] argument is for backward compatibility, only; each
@racket[module-path?] element of @racket[allow-read] is effectively
moved to @racket[allow-for-require], while other elements are moved to
@racket[allow-for-load].

The sandboxed environment is well isolated, and the evaluator function
essentially sends it an expression and waits for a result.  This form
of communication makes it impossible to have nested (or concurrent)
calls to a single evaluator.  Usually this is not a problem, but in
some cases you can get the evaluator function available inside the
sandboxed code, for example:
@examples[#:label #f #:eval box-eval
(eval:error
 (let ([e (make-evaluator 'racket/base)])
   (e `(,e 1))))
]
An error will be signaled in such cases.

If the value of @racket[sandbox-propagate-exceptions] is true (the
default) when the sandbox is created, then exceptions (both syntax and
run-time) are propagated as usual to the caller of the evaluation
function (i.e., catch them with @racket[with-handlers]). See below
for a caveat about using raised exceptions directly. If the value
of @racket[sandbox-propagate-exceptions] is @racket[#f] when the
sandbox is created, then uncaught exceptions in a sandbox evaluation
cause the error to be printed to the sandbox's error port, and the
caller of the evaluation receives @|void-const|.

Take care when using a value returned from a sandbox or raised as an
exception by a sandbox. The value might by an impersonator, or it
might be a structure whose structure type redirects equality
comparisons or printing operations. To safely handle an unknown value
produced by a sandbox, manipulate it within the sandbox, possibly
using @racket[call-in-sandbox-context].

An evaluator can be used only by one thread at a time, and detected
concurrent use triggers an exception. Beware of using an evaluator in
a non-main thread, because the default value of
@racket[sandbox-make-plumber] registers a callback in the current
plumber to flush the evaluator's plumber, and that means a flush of
the current plumber (such as when the Racket process is about to exit)
implies a use of the evaluator.

@history[#:changed "1.2" @elem{Added the @racket[#:readers] and
         @racket[#:allow-syntactic-require] arguments.}]}


@defproc*[([(exn:fail:sandbox-terminated? [v any/c]) boolean?]
           [(exn:fail:sandbox-terminated-reason [exn exn:fail:sandbox-terminated?])
            symbol?])]{

A predicate and accessor for exceptions that are raised when a sandbox
is terminated.  Once a sandbox raises such an exception, it will
continue to raise it on further evaluation attempts.}

@; ----------------------------------------------------------------------

@section{Security Considerations}

Although the sandbox is designed to provide a safe environment for executing
Racket programs with restricted access to system resources, executing untrusted
programs in a sandbox still carries some risk. Because a malicious program can
exercise arbitrary functionality from the Racket runtime and installed collections,
an attacker who identifies a vulnerability in Racket or an installed collection
may be able to escape the sandbox.

To mitigate this risk, programs that use the sandbox should employ additional
precautions when possible. Suggested measures include:
@itemlist[
@item{Supplying a custom module language to @racket[make-evaluator] or
@racket[make-module-evaluator] that gives untrusted code access to only
the language constructs it absolutely requires.}
@item{If untrusted code needs access to installed collections, installing only
the collections required by your program.}
@item{Using operating-system-level security features to provide defense-in-depth
in case the process running the sandbox is compromised.}
@item{Making sure your Racket installation and installed packages are up-to-date
with the latest release.}
]

@; ----------------------------------------------------------------------

@section{Customizing Evaluators}

The sandboxed evaluators that @racket[make-evaluator] creates can be
customized via many parameters.  Most of the configuration parameters
affect newly created evaluators; changing them has no effect on
already-running evaluators.

The default configuration options are set for a very restricted
sandboxed environment --- one that is safe to make publicly available.
Further customizations might be needed in case more privileges are
needed, or if you want tighter restrictions.  Another useful approach
for customizing an evaluator is to begin with a relatively
unrestricted configuration and add the desired restrictions.  This approach is made
possible by the @racket[call-with-trusted-sandbox-configuration]
function.

The sandbox environment uses two notions of restricting the time that
evaluations takes: @tech{shallow time} and @tech{deep
time}. @deftech{Shallow time} refers to the immediate execution of an
expression. For example, a @tech{shallow time} limit of five seconds
would restrict @racket[(sleep 6)] and other computations that take
longer than five seconds. @deftech{Deep time} refers to the total
execution of the expression and all threads and sub-processes that the
expression creates. For example, a @tech{deep time} limit of five
seconds would restrict @racket[(thread (λ () (sleep 6)))], which
@tech{shallow time} would not, @emph{as well as} all expressions that
@tech{shallow time} would restrict. By default, most sandboxes only
restrict @tech{shallow time} to facilitate expressions that use
threads.

@defproc[(call-with-trusted-sandbox-configuration [thunk (-> any)])
         any]{

Invokes the @racket[thunk] in a context where sandbox configuration
parameters are set for minimal restrictions.  More specifically, there
are no memory or time limits, and the existing existing @tech{inspectors},
@tech{security guard}, @tech{exit handler}, @tech{logger}, @tech{plumber}, and
@tech{environment variable set} are used.  (Note that the I/O
ports settings are not included.)}


@defparam[sandbox-init-hook thunk (-> any)]{

A @tech{parameter} that determines a thunk to be called for initializing a
new evaluator.  The hook is called just before the program is
evaluated in a newly-created evaluator context.  It can be used to
setup environment parameters related to reading, writing, evaluation,
and so on.  Certain languages (@racket['(special r5rs)] and the
teaching languages) have initializations specific to the language; the
hook is used after that initialization, so it can override settings.}


@defparam[sandbox-reader proc (any/c . -> . any)]{

A @tech{parameter} that specifies a function that reads all expressions from
@racket[(current-input-port)].  The function is used to read program
source for an evaluator when a string, byte string, or port is
supplied.  The reader function receives a value to be used as input
source (i.e., the first argument to @racket[read-syntax]), and it
should return a list of @tech{syntax objects}.  The default reader
calls @racket[read-syntax], accumulating results in a list until it
receives @racket[eof].

Note that the reader function is usually called as is, but when it is
used to read the program input for @racket[make-module-evaluator],
@racket[read-accept-lang] and @racket[read-accept-reader] are set to
@racket[#t].}


@defparam[sandbox-input in (or/c #f
                                 string? bytes?
                                 input-port?
                                 'pipe
                                 (-> input-port?))]{

A @tech{parameter} that determines the initial @racket[current-input-port]
setting for a newly created evaluator. It defaults to @racket[#f],
which creates an empty port.  The following other values are allowed:

@itemize[

 @item{a string or byte string, which is converted to a port using
       @racket[open-input-string] or @racket[open-input-bytes];}

 @item{an input port;}

 @item{the symbol @racket['pipe], which triggers the creation of a
       pipe, where @racket[put-input] can return the output end of the
       pipe or write directly to it;}

 @item{a thunk, which is called to obtain a port (e.g., using
       @racket[current-input-port] means that the evaluator input is
       the same as the calling context's input).}

]}


@defparam[sandbox-output in (or/c #f
                                  output-port? 
                                  'pipe
                                  'bytes
                                  'string
                                  (-> output-port?))]{

A @tech{parameter} that determines the initial @racket[current-output-port]
setting for a newly created evaluator. It defaults to @racket[#f],
which creates a port that discards all data.  The following other
values are allowed:

@itemize[

 @item{an output port, which is used as-is;}

 @item{the symbol @racket['bytes], which causes @racket[get-output] to
       return the complete output as a byte string as long as the
       evaluator has not yet terminated (so that the size of the bytes
       can be charged to the evaluator);}

 @item{the symbol @racket['string], which is similar to
       @racket['bytes], but makes @racket[get-output] produce a
       string;}

 @item{the symbol @racket['pipe], which triggers the creation of a
       pipe, where @racket[get-output] returns the input end of the
       pipe;}

 @item{a thunk, which is called to obtain a port (e.g., using
       @racket[current-output-port] means that the evaluator output is
       not diverted).}

]}


@defparam[sandbox-error-output in (or/c #f
                                        output-port? 
                                        'pipe
                                        'bytes
                                        'string
                                        (-> output-port?))]{

Like @racket[sandbox-output], but for the initial
@racket[current-error-port] value. An evaluator's error output is set
after its output, so using @racket[current-output-port] (the parameter
itself, not its value) for this parameter value means that the error
port is the same as the evaluator's initial output port.

The default is @racket[(lambda () (dup-output-port
(current-error-port)))], which means that the error output of the
generated evaluator goes to the calling context's error port.}


@defboolparam[sandbox-coverage-enabled enabled?]{

A @tech{parameter} that controls whether syntactic coverage information is
collected by sandbox evaluators.  Use
@racket[get-uncovered-expressions] to retrieve coverage information.

The default value is @racket[#f].
}


@defboolparam[sandbox-propagate-breaks propagate?]{

When both this boolean parameter and @racket[(break-enabled)] are true, 
breaking while an evaluator is
running propagates the break signal to the sandboxed
context.  This makes the sandboxed evaluator break, typically, but
beware that sandboxed evaluation can capture and avoid the breaks (so
if safe execution of code is your goal, make sure you use it with a
time limit).  Also, beware that a break may be received after the
evaluator's result, in which case the evaluation result is lost. Finally,
beware that a break may be propagated after an evaluator has produced
a result, so that the break is visible on the next interaction with
the evaluator (or the break is lost if the evaluator is not used
further). The default is @racket[#t].}


@defboolparam[sandbox-propagate-exceptions propagate?]{

A @tech{parameter} that controls how uncaught exceptions during a sandbox
evaluation are treated. When the parameter value is @racket[#t], 
then the exception is propagated to the caller of sandbox.
When the parameter value is @racket[#f], the exception message
is printed to the sandbox's error port, and the caller of the
sandbox receives @|void-const| for the evaluation. The default
is @racket[#t].}


@defparam[sandbox-namespace-specs spec (cons/c (-> namespace?) 
                                               (listof module-path?))]{

A @tech{parameter} that holds a list of values that specify how to create a
namespace for evaluation in @racket[make-evaluator] or
@racket[make-module-evaluator].  The first item in the list is a thunk
that creates the namespace, and the rest are module paths for modules
to be attached to the created namespace using
@racket[namespace-attach-module].

The default is @racket[(list sandbox-make-namespace)].

The module paths are needed for sharing module instantiations between
the sandbox and the caller.  For example, sandbox code that returns
@racket[posn] values (from the @racketidfont{lang/posn} module) will
not be recognized as such by your own code by default, since the
sandbox will have its own instance of @racketidfont{lang/posn} and
thus its own struct type for @racket[posn]s.  To be able to use such
values, include @racket['lang/posn] in the list of module paths.

When testing code that uses a teaching language, the following piece
of code can be helpful:

@racketblock[
(sandbox-namespace-specs
 (let ([specs (sandbox-namespace-specs)])
   `(,(car specs)
     ,@(cdr specs)
     lang/posn
     ,@(if (gui-available?) '(mrlib/cache-image-snip) '()))))
]}


@defproc[(sandbox-make-namespace) namespace?]{

Calls @racket[make-gui-namespace] when @racket[(sandbox-gui-available)]
produces true, @racket[make-base-namespace] otherwise.}


@defboolparam[sandbox-gui-available avail?]{

Determines whether the @racketmodname[racket/gui] module can be used
when a sandbox evaluator is created. If @racket[gui-available?]
produces @racket[#f] during the creation of a sandbox evaluator, this
parameter is forced to @racket[#f] during initialization of the
sandbox. The default value of the parameter is @racket[#t].

Various aspects of the library change when the GUI library is
available, such as using a new eventspace for each evaluator.}

@defboolparam[sandbox-gui-yield? yield? #:value #f]{

Determines whether the evaluator thread handles GUI events between sandbox
interactions. If the value is @racket[#f], then any GUI windows created in the
evaluator's initial eventspace will be unresponsive unless the evaluator is
instructed to handle events by calling @racket[yield] or @racket[sleep/yield].

The default value is @racket[#f] for backwards compatibility.

@history[#:added "8.5.0.8"]}

@defparam[sandbox-override-collection-paths paths (listof path-string?)]{

A @tech{parameter} that determines a list of collection directories to prefix
@racket[current-library-collection-paths] in an evaluator. This
parameter is useful for cases when you want to test code using an
alternate, test-friendly version of a collection, for example, testing
code that uses a GUI (like the @racket[htdp/world] teachpack) can be
done using a fake library that provides the same interface but no
actual interaction. The default is @racket[null].}


@defparam[sandbox-security-guard guard
          (or/c security-guard? (-> security-guard?))]{

A @tech{parameter} that determines the initial
@racket[(current-security-guard)] for sandboxed evaluations.  It can
be either a security guard, or a function to construct one.  The
default is a function that restricts the access of the current
security guard by forbidding all filesystem I/O except for
specifications in @racket[sandbox-path-permissions], and it uses
@racket[sandbox-network-guard] for network connections.}


@defparam[sandbox-path-permissions perms
          (listof (list/c (or/c 'execute 'write 'delete 
                                'read-bytecode 'read 'exists)
                          (or/c byte-regexp? bytes? string? path?)))]{

A @tech{parameter} that configures the behavior of the default sandbox
security guard by listing paths and access modes that are allowed for
them.  The contents of this parameter is a list of specifications,
each is an access mode and a byte-regexp for paths that are granted this
access.

The access mode symbol is one of: @racket['execute], @racket['write],
@racket['delete], @racket['read], or @racket['exists].  These symbols
are in decreasing order: each implies access for the following modes
too (e.g., @racket['read] allows reading or checking for existence).

The path regexp is used to identify paths that are granted access.  It
can also be given as a path (or a string or a byte string), which is
(made into a complete path, cleansed, simplified, and then) converted
to a regexp that allows the path and sub-directories; e.g.,
@racket["/foo/bar"] applies to @racket["/foo/bar/baz"].

An additional mode symbol, @racket['read-bytecode], is not part of the
linear order of these modes.  Specifying this mode is similar to
specifying @racket['read], but it is not implied by any other mode.
(For example, even if you specify @racket['write] for a certain path,
you need to also specify @racket['read-bytecode] to grant this
permission.)  The sandbox usually works in the context of a lower code
inspector (see @racket[sandbox-make-code-inspector]) which prevents
loading of untrusted bytecode files --- the sandbox is set-up to allow
loading bytecode from files that are specified with
@racket['read-bytecode].  This specification is given by default to
the Racket collection hierarchy (including user-specific libraries) and
to libraries that are explicitly specified in an @racket[#:allow-read]
argument.  (Note that this applies for loading bytecode files only,
under a lower code inspector it is still impossible to use protected
module bindings (see @secref["modprotect"]).)

The default value is null, but when an evaluator is created, it is
augmented by @racket['read-bytecode] permissions that make it possible
to use collection libraries (including
@racket[sandbox-override-collection-paths]). See
@racket[make-evaluator] for more information.}


@defparam[sandbox-network-guard proc
          (symbol?
           (or/c (and/c string? immutable?) #f)
           (or/c (integer-in 1 65535) #f)
           (or/c 'server 'client)
           . -> . any)]{

A @tech{parameter} that specifies a procedure to be used (as is) by the
default @racket[sandbox-security-guard].  The default forbids all
network connection.}


@defparam[sandbox-exit-handler handler (any/c . -> . any)]{

A @tech{parameter} that determines the initial @racket[(exit-handler)] for
sandboxed evaluations.  The default kills the evaluator with an
appropriate error message (see
@racket[exn:fail:sandbox-terminated-reason]).}


@defparam[sandbox-memory-limit limit (or/c (>=/c 0) #f)]{

A @tech{parameter} that determines the total memory limit on the sandbox in
megabytes (it can hold a rational or a floating point number).  When
this limit is exceeded, the sandbox is terminated.  This value is used
when the sandbox is created and the limit cannot be changed
afterwards.  It defaults to 30mb.  See @racket[sandbox-eval-limits]
for per-evaluation limits and a description of how the two limits work
together.

Note that (when memory accounting is enabled) memory is attributed to
the highest custodian that refers to it.  This means that if you
inspect a value that sandboxed evaluation returns outside of the
sandbox, your own custodian will be charged for it.  To ensure that it
is charged back to the sandbox, you should remove references to such
values when the code is done inspecting it.

This policy has an impact on how the sandbox memory limit interacts
with the per-expression limit specified by
@racket[sandbox-eval-limits]: values that are reachable from the
sandbox, as well as from the interaction will count against the
sandbox limit.  For example, in the last interaction of this code,
@racketblock[
  (define e (make-evaluator 'racket/base))
  (e '(define a 1))
  (e '(for ([i (in-range 20)]) (set! a (cons (make-bytes 500000) a))))
]
the memory blocks are allocated within the interaction limit, but
since they're chained to the defined variable, they're also reachable
from the sandbox --- so they will count against the sandbox memory
limit but not against the interaction limit (more precisely, no more
than one block counts against the interaction limit).}


@defparam[sandbox-eval-limits limits
          (or/c (list/c (or/c (>=/c 0) #f)
                        (or/c (>=/c 0) #f))
                #f)]{

A @tech{parameter} that determines the default limits on @italic{each}
use of a @racket[make-evaluator] function, including the initial
evaluation of the input program.  Its value should be a list of two
numbers; where the first is a @tech{shallow time} value in seconds,
and the second is a memory limit in megabytes (note that they don't
have to be integers).  Either one can be @racket[#f] for disabling the
corresponding limit; alternately, the parameter can be set to
@racket[#f] to disable all per-evaluation limits (useful in case more
limit kinds are available in future versions). The default is
@racket[(list 30 20)].

Note that these limits apply to the creation of the sandbox
environment too --- even @racket[(make-evaluator 'racket/base)] can
fail if the limits are strict enough.  For example,
@racketblock[
  (parameterize ([sandbox-eval-limits '(0.25 5)])
    (make-evaluator 'racket/base '(sleep 2)))
]
will throw an error instead of creating an evaluator.  Therefore, to
avoid surprises you need to catch errors that happen when the sandbox
is created.

When limits are set, @racket[call-with-limits] (see below) is wrapped
around each use of the evaluator, so consuming too much time or memory
results in an exception.  Change the limits of a running evaluator
using @racket[set-eval-limits].

@margin-note{A custodian's limit is checked only after a garbage
             collection, except that it may also be checked during
             certain large allocations that are individually larger
             than the custodian's limit.}

The memory limit that is specified by this parameter applies to each
individual evaluation, but not to the whole sandbox --- that limit is
specified via @racket[sandbox-memory-limit].  When the global limit is
exceeded, the sandbox is terminated, but when the per-evaluation limit
is exceeded, an exception recognizable by @racket[exn:fail:resource?] is raised.  For example, say that
you evaluate an expression like
@racketblock[
  (for ([i (in-range 1000)])
    (set! a (cons (make-bytes 1000000) a))
    (collect-garbage))
]
then, assuming sufficiently small limits,
@itemize[

 @item{if a global limit is set but no per-evaluation limit, the
       sandbox will eventually be terminated and no further
       evaluations possible;}

 @item{if there is a per-evaluation limit, but no global limit, the
       evaluation will abort with an error and it can be used again
       --- specifically, @racket[a] will still hold a number of
       blocks, and you can evaluate the same expression again which
       will add more blocks to it;}

  @item{if both limits are set, with the global one larger than the
        per-evaluation limit, then the evaluation will abort and you
        will be able to repeat it, but doing so several times will
        eventually terminate the sandbox (this will be indicated by
        the error message, and by the @racket[evaluator-alive?]
        predicate).}

]}


@defparam[sandbox-eval-handlers handlers
          (list/c (or/c #f ((-> any) . -> . any))
                  (or/c #f ((-> any) . -> . any)))]{

A @tech{parameter} that determines two (optional) handlers that wrap
sandboxed evaluations.  The first one is used when evaluating the
initial program when the sandbox is being set-up, and the second is
used for each interaction.  Each of these handlers should expect a
thunk as an argument, and they should execute these thunks ---
possibly imposing further restrictions.  The default values are
@racket[#f] and @racket[call-with-custodian-shutdown], meaning no
additional restrictions on initial sandbox code (e.g., it can start
background threads), and a custodian-shutdown around each interaction
that follows.  Another useful function for this is
@racket[call-with-killing-threads] which kills all threads, but leaves
other resources intact.}


@defparam[sandbox-run-submodules submod-syms (list/c symbol?)]{

A @tech{parameter} that determines submodules to run when a sandbox is
created by @racket[make-module-evaluator]. The parameter's default
value is the empty list.}


@defparam[sandbox-make-inspector make (-> inspector?)]{

A @tech{parameter} that determines the (nullary) procedure that is used to
create the inspector for sandboxed evaluation.  The procedure is called
when initializing an evaluator.  The default parameter value is
@racket[(lambda () (make-inspector (current-inspector)))].}


@defparam[sandbox-make-code-inspector make (-> inspector?)]{

A @tech{parameter} that determines the (nullary) procedure that is used to
create the code inspector for sandboxed evaluation.  The procedure is
called when initializing an evaluator.  The default parameter value is
@racket[(lambda () (make-inspector (current-code-inspector)))].

The @racket[current-load/use-compiled] handler is setup to allow loading
of bytecode files under the original code inspector when
@racket[sandbox-path-permissions] allows it through a
@racket['read-bytecode] mode symbol, which makes loading libraries
possible.}


@defparam[sandbox-make-logger make (-> logger?)]{

A @tech{parameter} that determines the procedure used to create the logger
for sandboxed evaluation.  The procedure is called when initializing
an evaluator, and the default parameter value is
@racket[current-logger].  This means that it is not creating a new
logger (this might change in the future).}


@defparam[sandbox-make-plumber make (or/c (-> plumber?) 'propagate)]{

A @tech{parameter} that determines the procedure used to create the
plumber for sandboxed evaluation.  The procedure is called when
initializing an evaluator.

If the value is @racket['propagate] (the default), then a new plumber
is created, and a @tech{flush callback} is added to the current
plumber to propagate the request to the new plumber within the created
sandbox (if the sandbox has not already terminated).

@history[#:added "6.0.1.8"]}


@defparam[sandbox-make-environment-variables make (-> environment-variables?)]{

A @tech{parameter} that determines the procedure used to create the
@tech{environment variable set} for sandboxed evaluation.  The
procedure is called when initializing an evaluator, and the default
parameter value constructs a new @tech{environment variable set} using
@racket[(environment-variables-copy
(current-environment-variables))].}

@defproc[(default-language-readers [lang module-path?]) (listof module-path?)]{

Creates a default list of readers that should be allowed to produce a
module that uses @racket[lang] as the language.

This default list includes the following (and more paths may be added
in the future):

@itemlist[

 @item{@racket[`(submod ,lang reader)]}

 @item{@racketvalfont{'}@racket[lang]@racketvalfont{/lang/reader} if @racket[lang] is a symbol}

 @item{the module path producing by adding the relative path @racket["lang/reader.rkt"]
       to @racket[lang] if @racket[lang] is not a symbol}

 @item{@racket['(submod at-exp reader)]}

 @item{@racket['at-exp/lang/reader]}

]

@history[#:added "1.2"]}

@; ----------------------------------------------------------------------

@section{Interacting with Evaluators}

The following functions are used to interact with a sandboxed
evaluator in addition to using it to evaluate code.


@defproc[(evaluator-alive? [evaluator (any/c . -> . any)]) boolean?]{

Determines whether the evaluator is still alive.}


@defproc[(kill-evaluator [evaluator (any/c . -> . any)]) void?]{

Releases the resources that are held by @racket[evaluator] by shutting
down the evaluator's custodian.  Attempting to use an evaluator after
killing raises an exception, and attempts to kill a dead evaluator are
ignored.

Killing an evaluator is similar to sending an @racket[eof] value to
the evaluator, except that an @racket[eof] value will raise an error
immediately.}


@defproc[(break-evaluator [evaluator (any/c . -> . any)]) void?]{

Sends a break to the running evaluator.  The effect of this is as if
Ctrl-C was typed when the evaluator is currently executing, which
propagates the break to the evaluator's context.}


@defproc[(get-user-custodian [evaluator (any/c . -> . any)]) void?]{

Retrieves the @racket[evaluator]'s toplevel custodian.  This returns a
value that is different from @racket[(evaluator '(current-custodian))]
or @racket[(call-in-sandbox-context evaluator current-custodian)] --- each
sandbox interaction is wrapped in its own custodian, which is what these
would return.

(One use for this custodian is with @racket[current-memory-use], where
the per-interaction sub-custodians will not be charged with the memory
for the whole sandbox.)}


@defproc[(set-eval-limits [evaluator (any/c . -> . any)]
                          [secs (or/c exact-nonnegative-integer? #f)]
                          [mb (or/c exact-nonnegative-integer? #f)])
         void?]{

Changes the per-expression limits that @racket[evaluator] uses to
@racket[secs] seconds of @tech{shallow time} and @racket[mb]
megabytes (either one can be @racket[#f], indicating no limit).

This procedure should be used to modify an existing evaluator limits,
because changing the @racket[sandbox-eval-limits] parameter does not
affect existing evaluators. See also @racket[call-with-limits].}


@defproc[(set-eval-handler [evaluator (any/c . -> . any)]
                           [handler (or/c #f ((-> any) . -> . any))])
         void?]{

Changes the per-expression handler that the @racket[evaluator] uses
around each interaction.  A @racket[#f] value means no handler is
used.

This procedure should be used to modify an existing evaluator handler,
because changing the @racket[sandbox-eval-handlers] parameter does not
affect existing evaluators. See also
@racket[call-with-custodian-shutdown] and
@racket[call-with-killing-threads] for two useful handlers that are
provided.}


@defproc*[([(call-with-custodian-shutdown [thunk (-> any)]) any]
           [(call-with-killing-threads [thunk (-> any)]) any])]{

These functions are useful for use as an evaluation handler.
@racket[call-with-custodian-shutdown] will execute the @racket[thunk]
in a fresh custodian, then shutdown that custodian, making sure that
@racket[thunk] could not have left behind any resources.
@racket[call-with-killing-threads] is similar, except that it kills
threads that were left, but leaves other resources as is.}


@defproc*[([(put-input [evaluator (any/c . -> . any)]) output-port?]
           [(put-input [evaluator (any/c . -> . any)]
                       [i/o (or/c bytes? string? eof-object?)]) void?])]{

If @racket[(sandbox-input)] is @racket['pipe] when an evaluator is
created, then this procedure can be used to retrieve the output port
end of the pipe (when used with no arguments), or to add a string or a
byte string into the pipe.  It can also be used with @racket[eof],
which closes the pipe.}


@defproc*[([(get-output [evaluator (any/c . -> . any)]) (or/c #f input-port? bytes? string?)]
           [(get-error-output [evaluator (any/c . -> . any)]) (or/c #f input-port? bytes? string?)])]{

Returns the output or error-output of the @racket[evaluator],
in a way that depends on the setting of @racket[(sandbox-output)] or
@racket[(sandbox-error-output)] when the evaluator was created:

@itemize[

 @item{if it was @racket['pipe], then @racket[get-output] returns the
      input port end of the created pipe;}

 @item{if it was @racket['bytes] or @racket['string], then the result
       is the accumulated output, and the output port is reset so each
       call returns a different piece of the evaluator's output (note
       that results are available only until the evaluator has
       terminated, and any allocations of the output are subject to
       the sandbox memory limit);}

  @item{otherwise, it returns @racket[#f].}
]}


@defproc[(get-uncovered-expressions [evaluator (any/c . -> . any)]
                                    [prog? any/c #t]
                                    [src any/c _default-src])
         (listof syntax?)]{

Retrieves uncovered expression from an evaluator, as longs as the
@racket[sandbox-coverage-enabled] parameter had a true value when the
evaluator was created. Otherwise, an exception is raised to indicate
that no coverage information is available.

The @racket[prog?] argument specifies whether to obtain expressions that
were uncovered after only the original input program was evaluated
(@racket[#t]) or after all later uses of the evaluator (@racket[#f]).
Using @racket[#t] retrieves a list that is saved after the input
program is evaluated, and before the evaluator is used, so the result is
always the same.

A @racket[#t] value of @racket[prog?] is useful for testing student
programs to find out whether a submission has sufficient test coverage
built in. A @racket[#f] value is useful for writing test suites for a
program to ensure that your tests cover the whole code.

The second optional argument, @racket[src], specifies that the result
should be filtered to hold only @tech{syntax objects} whose source
matches @racket[src]. The default is the source that was used in the
program code, if there was one.  Note that @racket['program] is used as
the source value if the input program was given as S-expressions or as a
string (and in these cases it will be the default for filtering).  If given
@racket[#f], the result is the unfiltered list of expressions.

The resulting list of @tech{syntax objects} has at most one expression
for each position and span.  Thus, the contents may be unreliable, but
the position information is reliable (i.e., it always indicates source
code that would be painted red in DrRacket when coverage information
is used).

Note that if the input program is a sequence of syntax values, either
make sure that they have @racket['program] as the source field, or use
the @racket[src] argument.  Using a sequence of S-expressions (not
@tech{syntax objects}) for an input program leads to unreliable
coverage results, since each expression may be assigned a single
source location.}

@defproc[(call-in-sandbox-context [evaluator (any/c . -> . any)]
                                  [thunk (-> any)]
                                  [unrestricted? boolean? #f])
         any]{

Calls the given @racket[thunk] in the context of a sandboxed
evaluator.  The call is performed under the resource limits and
evaluation handler that are used for evaluating expressions, unless
@racket[unrestricted?] is specified as true.

This process is usually similar to @racket[(evaluator (list thunk))],
except that it does not rely on the common meaning of a sexpr-based
syntax with list expressions as function application (which is not true
in all languages).  Note that this is more useful for meta-level
operations such as namespace manipulation, it is not intended to be used
as a safe-evaluation replacement (i.e., using the sandbox evaluator as
usual).

In addition, you can avoid some of the sandboxed restrictions by using
your own permissions, for example,
@racketblock[
  (let ([guard (current-security-guard)])
    (call-in-sandbox-context
      ev
      (lambda ()
        (parameterize ([current-security-guard guard])
          (code:comment @#,t{can access anything you want here})
          (delete-file "/some/file")))))
]}

@; ----------------------------------------------------------------------

@section{Miscellaneous}

@defthing[gui? boolean?]{

For backward compatibility, only: the result of @racket[gui-available?]
at the time that @racketmodname[racket/sandbox] was instantiated.

The value of @racket[gui?] is no longer used by
@racketmodname[racket/sandbox] itself. Instead,
@racket[gui-available?]  and @racket[sandbox-gui-available] are
checked at the time that a sandbox evaluator is created.}


@defproc[(call-with-limits [secs (or/c exact-nonnegative-integer? #f)]
                           [mb (or/c exact-nonnegative-integer? #f)]
                           [thunk (-> any)])
         any]{

Executes the given @racket[thunk] with memory and time restrictions:
if execution consumes more than @racket[mb] megabytes or more than
@racket[secs] @tech{shallow time} seconds, then the computation is
aborted and an exception recognizable by @racket[exn:fail:resource?] is raised.  Otherwise, the result of
the thunk is returned as usual (a value, multiple values, or an
exception).  Each of the two limits can be @racket[#f] to indicate the
absence of a limit. See also @racket[custodian-limit-memory] for
information on memory limits.

To enforce limits, @racket[thunk] is run in a new thread. As usual,
the new thread starts with the same parameter values as the one that
calls @racket[call-with-limits]. @emph{Not} as usual, parameter values
from the thread used to run @racket[thunk] are copied back to the
thread that called @racket[call-with-limits] when @racket[thunk]
completes.

Sandboxed evaluators use @racket[call-with-limits], according to the
@racket[sandbox-eval-limits] setting and uses of
@racket[set-eval-limits]: each expression evaluation is protected from
timeouts and memory problems. Use @racket[call-with-limits] directly
only to limit a whole testing session, instead of each expression.}

@defform[(with-limits sec-expr mb-expr body ...)]{

A macro version of @racket[call-with-limits].}

@defproc[(call-with-deep-time-limit [secs exact-nonnegative-integer?]
                                    [thunk (-> any)])
         any]{
Executes the given @racket[thunk] with @tech{deep time} restrictions,
and returns the values produced by @racket[thunk].

The given @racket[thunk] is run in a new thread. If it errors or if
the thread terminates returning a value, then @racket[(values)] is
returned.

@history[#:changed "1.1" @elem{Changed to return @racket[thunk]'s result
                               if it completes normally.}]}

@defform[(with-deep-time-limit secs-expr body ...)]{

A macro version of @racket[call-with-deep-time-limit].}

@defproc*[([(exn:fail:resource? [v any/c]) boolean?]
           [(exn:fail:resource-resource [exn exn:fail:resource?])
            (or/c 'time 'memory 'deep-time)])]{

A predicate and accessor for exceptions that are raised by
@racket[call-with-limits].  The @racket[resource] field holds a
symbol, representing the resource that was expended. @racket['time] is
used for @tech{shallow time} and @racket['deep-time] is used for
@tech{deep time}.}

@; ----------------------------------------------------------------------

@close-eval[box-eval]
