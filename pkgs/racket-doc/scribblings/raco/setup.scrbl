#lang scribble/doc

@(require scribble/manual
          scribble/bnf
          "common.rkt"
         (for-label racket
                    racket/future
                    setup/setup-unit
                    setup/option-unit
                    setup/option-sig
                    setup/dirs
                    setup/getinfo
                    setup/main-collects
                    setup/collection-name
                    setup/collection-search
                    setup/matching-platform
                    setup/cross-system
                    setup/path-to-relative
                    setup/xref scribble/xref
                    ;; info -- no bindings from this are used
                    (only-in info)
                    setup/pack
                    setup/unpack
                    setup/link
                    compiler/compiler
                    compiler/module-suffix
                    compiler/find-exe
                    launcher/launcher
                    compiler/sig
                    launcher/launcher-sig
                    dynext/file-sig
                    racket/gui/base
                    racket/future
                    mrlib/terminal
                    (only-in ffi/unsafe ffi-lib)
                    racket/path
                    setup/collects
                    syntax/modcollapse
                    racket/runtime-path
                    pkg/path))

@(define-syntax-rule (local-module mod . body)
   (begin
     (define-syntax-rule (go)
       (begin
         (require (for-label mod))
         . body))
     (go)))

@(define ref-src
   '(lib "scribblings/reference/reference.scrbl"))

@(define (defaults v) 
   @elem{The default is @|v|.})

@(define pkg-doc '(lib "pkg/scribblings/pkg.scrbl"))

@title[#:tag "setup" #:style 'toc]{@exec{raco setup}: Installation Management}

The @exec{raco setup} command builds bytecode, documentation,
executables, and metadata indexes for all installed collections.

The collections that are built by @exec{raco setup} can be part of the
original Racket distribution, installed via the package manager (see
@other-manual[pkg-doc]), installed via
@|PLaneT| (see @other-manual['(lib "planet/planet.scrbl")]), linked
via @exec{raco link}, in a directory that is listed in the
@envvar{PLTCOLLECTS} environment variable, or placed into one of the
default collection directories.

The @exec{raco setup} tool itself does not directly support the
installation of collections, except through the now-discouraged
@Flag{A} flag (see @secref["raco-setup-A"]). The @exec{raco setup} command is
used by installation tools such as the package manager or @|PLaneT|.
Programmers who modify installed collections may find it useful to run
@exec{raco setup} as an alternative to un-installing and re-installing
a set of collections.

@local-table-of-contents[]

@; ------------------------------------------------------------------------

@section[#:tag "running"]{Running @exec{raco setup}}

With no command-line arguments, @exec{raco setup} finds all of the
current collections---see @secref[#:doc ref-src]{collects}---and
compiles libraries in each collection.  (Directories that are named
@filepath{.git} or @filepath{.svn} are not treated as collections.)

To restrict @exec{raco setup} to a set of collections, provide the
collection names as arguments. For example, @exec{raco setup
scribblings/raco} would only compile and render the documentation for
@exec{raco}, which is implemented in a @filepath{scribblings/raco}
collection.

An optional @filepath{info.rkt} within the collection can indicate
specifically how the collection's files are to be compiled and other
actions to take in setting up a collection, such as creating
executables or building documentation. See @secref["setup-info"] for
more information.

The @exec{raco setup} command accepts the following command-line
flags:

@itemize[

@item{Constraining to specified collections or @|PLaneT| packages:
@itemize[

 @item{@DFlag{only} --- restrict setup to specified collections and
   @|PLaneT| packages, even if none are specified. This mode is the
   default if any collection is specified as a command-line argument
   or through the @Flag{l}, @DFlag{pkgs}, or @Flag{P} flag.}

 @item{@Flag{l} @nonterm{collection} @racket[...] --- constrain setup
  actions to the specified @nonterm{collection}s (i.e., the same as
  providing @nonterm{collections}s without a flag, but with no
  possibility that a @nonterm{collection} is interpreted as a flag).}

 @item{@DFlag{pkgs} @nonterm{pkg} @racket[...] --- constrain setup
  actions to collections that are within (or partially within) the
  named @nonterm{pkg}s.}

 @item{@Flag{P} @nonterm{owner} @nonterm{package-name} @nonterm{maj}
  @nonterm{min} --- constrain setup actions to the specified @|PLaneT|
  package, in addition to any other specified @|PLaneT| packages or
  collections.}

 @item{@DFlag{doc-index} --- build collections that implement
  documentation indexes (when documentation building is enabled), in
  addition to specified collections.}

 @item{@DFlag{tidy} --- remove metadata cache information and
  documentation for non-existent collections or documentation to
  clean up after removal, even when setup actions are otherwise
  confined to specified collections. Although tidying is not confined
  to specified collections, it can be constrained with @DFlag{avoid-main}
  or @DFlag{no-user}.}

]}
@item{Constraining to specific tasks:
@itemize[

 @item{@DFlag{clean} or @Flag{c} --- delete existing @filepath{.zo}
   files, thus ensuring a clean build from the source files. The exact
   set of deleted files can be controlled by @filepath{info.rkt}; see
   @elemref["clean"]{@racket[clean]} for more information. Unless
   @DFlag{no-info-domain} or @Flag{d} is also specified, the @filepath{info.rkt}
   cache is cleared. Unless @DFlag{no-docs} or @Flag{D} is also
   specified, the documentation-index database is reset.}

 @item{@DFlag{fast-clean} --- like @DFlag{clean}, but
   without forcing a bootstrap of @exec{raco setup} from source (which
   means that @DFlag{fast-clean} cannot clean corruption that affects
   @exec{raco setup} itself).}

 @item{@DFlag{no-zo} or @Flag{n} --- refrain from compiling source
   files to @filepath{.zo} files.}

 @item{@DFlag{trust-zos} --- fix timestamps on @filepath{.zo} files on
   the assumption that they are already up-to-date (unless the
   @envvar{PLT_COMPILED_FILE_CHECK} environment variable is set to
   @litchar{exists}, in which case timestamps are ignored).}

 @item{@DFlag{recompile-only} --- disallow recompilation of modules
  from source, imposing the constraint that each @filepath{.zo} file
  is up-to-date, needs only a timestamp adjustment, or can be
  recompiled from an existing @filepath{.zo} in machine-independent
  format (when compiling to a machine-dependent format).}

 @item{@DFlag{sync-docs-only} --- synchronize or move documentation
   into place to ``build'' it, but do not run or render documentation
   sources.}

 @item{@DFlag{no-launcher} or @Flag{x} --- refrain from creating
   executables or installing @tt{man} pages (as specified in
   @filepath{info.rkt}; see @secref["setup-info"]).}

 @item{@DFlag{no-foreign-libs} or @Flag{F} --- refrain from installing foreign
   libraries (as specified in @filepath{info.rkt}; see
   @secref["setup-info"]).}

 @item{@DFlag{only-foreign-libs} --- disable actions other than
   installing foreign libraries; equivalent to @Flag{nxiIdD}, except
   that @DFlag{only-foreign-libs} doesn't reject (redundant)
   specification of those individual flags.}

 @item{@DFlag{no-install} or @Flag{i} --- refrain from running
   pre-install actions (as specified in @filepath{info.rkt} files; see
   @secref["setup-info"]).}

 @item{@DFlag{no-post-install} or @Flag{I} --- refrain from running
   post-install actions (as specified in @filepath{info.rkt} files; see
   @secref["setup-info"]).}

 @item{@DFlag{no-info-domain} or @Flag{d} --- refrain from building
   a cache of metadata information from @filepath{info.rkt}
   files. This cache is needed by other tools. For example,
   @exec{raco} itself uses the cache to locate plug-in tools.}

 @item{@DFlag{no-docs} or @Flag{D} --- refrain from building
   documentation.}

 @item{@DFlag{doc-pdf} @nonterm{dir} --- in addition to building HTML
   documentation, render documentation to PDF and place files in
   @nonterm{dir}.}

 @item{@DFlag{no-pkg-deps} or @Flag{K} --- refrain from checking
  whether dependencies among libraries are properly reflected by
  package-level dependency declarations, whether modules are declared
  by multiple packages, and whether package version dependencies are
  satisfied. See @secref["setup-check-deps"] for more information.}

 @item{@DFlag{check-pkg-deps} --- checks package dependencies (unless
  explicitly disabled) even when specific collections are provided to
  @exec{raco setup}, and even for packages that have no dependency
  declarations. See @secref["setup-check-deps"] for more information.}

 @item{@DFlag{fix-pkg-deps} --- attempt to correct dependency
  mismatches by adjusting package @filepath{info.rkt} files (which
  makes sense only for packages that are installed as links). See
  @secref["setup-check-deps"] for more information.}

 @item{@DFlag{unused-pkg-deps} --- attempt to report dependencies that
  are declared but are unused. Beware that some package dependencies
  may be intentionally unused (e.g., declared to force installation of
  other packages as a convenience), and beware that package
  dependencies may be reported as unused only because compilation of
  relevant modules has been suppressed.  See
  @secref["setup-check-deps"] for more information.}

]}
@item{Constraining user versus installation setup:
@itemize[

 @item{@DFlag{no-user} or @Flag{U} --- refrain from any user-specific
  (as opposed to installation-specific) setup actions.}

 @item{@DFlag{no-planet} --- refrain from any setup actions for
  @|PLaneT| actions; this flag is implied by @DFlag{no-user}.}

 @item{@DFlag{avoid-main} --- refrain from any setup actions that
  affect the installation, as opposed to user-specific actions.}

 @item{@DFlag{force-user-docs} --- when building documentation, create
  a user-specific documentation entry point even if it has the same
  content as the main installation.}

]}
@item{Selecting parallelism and other build modes:
@itemize[

 @item{@DFlag{jobs} @nonterm{n}, @DFlag{workers} @nonterm{n},
   or @Flag{j} @nonterm{n} --- use up
   to @nonterm{n} parallel processes.  By default, @exec{raco setup}
   uses @racket[(processor-count)] jobs, which typically uses
   all of the machine's processing cores.}

 @item{@DFlag{places} --- use Racket places for parallel jobs; this
   mode is the default if Racket places run in parallel.}

 @item{@DFlag{processes} --- use separate processes for parallel jobs;
   this mode is the default if Racket places cannot run in parallel.}

 @item{@DFlag{verbose} or @Flag{v} --- more verbose output about
   @exec{raco setup} actions.}

 @item{@DFlag{make-verbose} or @Flag{m} --- more verbose output about
   dependency checks.}

 @item{@DFlag{compiler-verbose} or @Flag{r} --- even more verbose
   output about dependency checks and compilation.}

 @item{@DFlag{mode} @nonterm{mode} --- use a @filepath{.zo} compiler
   other than the default compiler, and put the resulting
   @filepath{.zo} files in a subdirectory (of the usual place) named
   by @nonterm{mode}. The compiler is obtained by using @nonterm{mode}
   as a collection name, finding a @filepath{zo-compile.rkt} module in
   that collection, and extracting its @racket[zo-compile] export. The
   @racket[zo-compile] export should be a function like
   @racket[compile]; see the @filepath{errortrace} collection for an
   example.}

 @item{@DFlag{fail-fast} --- attempt to break as soon as any error is
  discovered.}

 @item{@DFlag{error-out} @nonterm{file} --- handle survivable errors
  by writing @nonterm{file} and exiting as successful, which
  facilitates chaining multiple @exec{raco setup} invocations in
  combination with @DFlag{error-in}. If there are no errors and
  @nonterm{file} already exists, it is deleted.}

 @item{@DFlag{error-in} @nonterm{file} --- treat the existence of
  @nonterm{file} as a ``errors were reported by a previous process''
  error. Typically, @nonterm{file} is created by previous @exec{raco
  setup} run using @DFlag{error-out}. A file for @DFlag{error-in} is
  detected before creating a file via @DFlag{error-out}, so the same
  file can be used to chain a sequence of @exec{raco setup} steps.}

 @item{@DFlag{pause} or @Flag{p} --- pause for user input if any
  errors are reported (so that a user has time to inspect output that
  might otherwise disappear when the @exec{raco setup} process ends).}

]}
@item{Unpacking @filepath{.plt} archives:
@itemize[

 @item{@Flag{A} @nonterm{archive} @racket[...] --- Install each
  @nonterm{archive}; see @secref["raco-setup-A"].}

 @item{@DFlag{force} --- for use with @Flag{A}, treat version
  mismatches for archives as mere warnings.}

 @item{@DFlag{all-users} or @Flag{a} --- for use with @Flag{A},
  install archive into the installation instead of a user-specific
  location.}

]}
@item{Bootstrapping:
@itemize[

 @item{@DFlag{boot} @nonterm{module-file} @nonterm{build-dir} --- For
       use by directly running @racketmodname[setup] instead of
       through @exec{raco setup}, loads @nonterm{module-file} in the
       same way that @exec{raco setup} normally loads itself,
       auto-detecting the need to start from sources and rebuild the
       compiled files---even for the compilation manager itself. The
       @nonterm{build-dir} path is installed as the only path in
       @racket[current-compiled-file-roots], so all compiled files
       go there.}

 @item{@DFlag{chain} @nonterm{module-file} @nonterm{build-dir} ---
       Like @DFlag{boot}, but adds @nonterm{build-dir} to the start of
       @racket[current-compiled-file-roots] instead of replacing the
       current value, which means that libraries already built in the
       normal location (including the compilation manager itself) will
       be used instead of rebuilt. This mode makes sense for
       cross-compilation.}

]}

]

When building @exec{racket}, flags can be provided to @exec{raco
setup} as run by @exec{make install} by setting the
@as-index{@envvar{PLT_SETUP_OPTIONS}} makefile variable. For
example, the following command line uses a single process to build
collections during an install:

   @commandline{make install PLT_SETUP_OPTIONS="-j 1"}

Running @exec{raco setup} is sensitive to the
@envvar{PLT_COMPILED_FILE_CHECK} environment variable in the same way
as @exec{raco make}. Specifically, if @envvar{PLT_COMPILED_FILE_CHECK}
is set to @litchar{exists}, then @exec{raco make} does not attempt to
update a compiled file's timestamp if the file is not recompiled.

Some additional environment variables are useful for performance
debugging:

@itemlist[

 @item{@indexed-envvar{PLT_SETUP_DMS_ARGS} triggers a call to
       @racket[dump-memory-stats] after each collection is compiled,
       where the environment variable's value is parsed with
       @racket[read] to obtain a list of arguments to
       @racket[dump-memory-stats].}

 @item{@indexed-envvar{PLT_SETUP_LIMIT_CACHE} (set to anything) avoids
       caching compiled-file information across different collections,
       which is useful to reduce noise when looking for memory leaks.}

 @item{@indexed-envvar{PLT_SETUP_NO_FORCE_GC} (set to anything)
       suppresses a call to @racket[collect-garbage] that is issued by
       default for non-parallel builds after each collection is
       compiled and after each document is run or rendered.}

 @item{@indexed-envvar{PLT_SETUP_SHOW_TIMESTAMPS} (set to anything)
       appends the current process time after @litchar[" @ "] for each
       status message printed by @exec{raco setup}.}

]

@history[#:changed "6.1" @elem{Added the @DFlag{pkgs},
                               @DFlag{check-pkg-deps}, and
                               @DFlag{fail-fast} flags.}
         #:changed "6.1.1" @elem{Added the @DFlag{force-user-docs} flag.}
         #:changed "6.1.1.6" @elem{Added the @DFlag{only-foreign-libs} flag.}
         #:changed "6.6.0.3" @elem{Added support for @envvar{PLT_COMPILED_FILE_CHECK}.}
         #:changed "7.0.0.19" @elem{Added @DFlag{places} and  @DFlag{processes}.}
         #:changed "7.2.0.7" @elem{Added @DFlag{error-in} and  @DFlag{error-out}.}
         #:changed "7.2.0.8" @elem{Added @DFlag{recompile-only}.}
         #:changed "7.9.0.3" @elem{Added @envvar{PLT_SETUP_NO_FORCE_GC},
                                   @envvar{PLT_SETUP_SHOW_TIMESTAMPS},
                                   and @DFlag{sync-docs-only}.}]

@; ------------------------------------------------------------------------

@section[#:tag "raco-setup-A"]{Installing @filepath{.plt} Archives}

A @filepath{.plt} file is a platform-independent distribution archive
for software based on Racket. A typical @filepath{.plt} file can be
installed as a package using @exec{raco pkg} (see @other-manual['(lib
"pkg/scribblings/pkg.scrbl")]), in which case @exec{raco pkg} supplies
facilities for uninstalling the package and managing dependencies.

An older approach is to supply a @filepath{.plt} file to @exec{raco
setup} with the @Flag{A} flag; the files contained in the
@filepath{.plt} archive are unpacked (according to specifications
embedded in the @filepath{.plt} file) and only collections specified
by the @filepath{.plt} file are compiled and setup. Archives processed
in this way can include arbitrary code that is executed at install
time, in addition to any actions triggered by the normal
collection-setup part of @exec{raco setup}.

Finally, the @exec{raco unpack} (see @secref["unpack"]) command can
list the content of a @filepath{.plt} archive or unpack the archive
without installing it as a package or collection.

@; ------------------------------------------------------------------------

@section[#:tag "setup-info"]{Controlling @exec{raco setup} with @filepath{info.rkt} Files}

To compile a collection's files to bytecode, @exec{raco setup} uses the
@racket[compile-collection-zos] procedure. That procedure, in turn,
consults the collection's @filepath{info.rkt} file, if it exists, for
specific instructions on compiling the collection. See
@racket[compile-collection-zos] for more information on the fields of
@filepath{info.rkt} that it uses, and see @secref["info.rkt"] for
information on the format of an @filepath{info.rkt} file.

Additional fields are used by the
@seclink["top" #:doc '(lib "pkg/scribblings/pkg.scrbl") "Racket package manager"]
and are documented in @secref["metadata" #:doc '(lib "pkg/scribblings/pkg.scrbl")].
The @exec{raco test} command also recognizes additional fields, which are
documented in @secref["test-config-info" #:doc '(lib "scribblings/raco/raco.scrbl")].

Optional @filepath{info.rkt} fields trigger additional actions by
@exec{raco setup}:

@itemize[

 @item{@as-index{@racketidfont{scribblings}} : @racket[(listof (cons/c string? list?))] ---
   A list of documents to build. Each document in the list is itself
   represented as a list, where each document's list starts with a
   string that is a collection-relative path to the document's source
   file. A document name (which is derived from the source module's
   name by default) is intended to be globally unique in the same way
   as a package or module name.

   More precisely a @racketidfont{scribblings} entry must be a value
   that can be generated from an expression matching the following
   @racket[_entry] grammar:

   @racketgrammar*[
     #:literals (list)
     [entry (list doc ...)]
     [doc (list src-string)
          (list src-string flags)
          (list src-string flags category)
          (list src-string flags category name)
          (list src-string flags category name out-k)
          (list src-string flags category name out-k order-n)]
     [flags (list mode-symbol ...)]
     [category (list category-string-or-symbol)
               (list category-string-or-symbol sort-number)]
     [name string
           #f]
   ]

   A document's list optionally continues with information on how to
   build the document. If a document's list contains a second item,
   @racket[_flags], it must be a list of mode symbols (described
   below). If a document's list contains a third item,
   @racket[_category], it must be a list that categorizes the document
   (described further below). If a document's list contains a fourth
   item, @racket[_name], it is a name to use for the generated
   documentation, instead of defaulting to the source file's name
   (sans extension), where @racket[#f] means to use the default; a
   non-@racket[#f] value for @racket[_name] must fit the grammar
   of a collection-name element as checked by 
   @racket[collection-name-element?]. If a
   document's list contains a fifth item, @racket[_out-k], it is used
   a hint for the number of files to use for the document's
   cross-reference information; see below. If a document's list
   contains a fourth item, @racket[_order-n], it is used a hint for
   the order of rendering; see below.

   Each mode symbol in @racket[_flags] can be one of the following,
   where only @racket['multi-page] is commonly used:

   @itemize[

     @item{@racket['multi-page] : Generates multi-page HTML output,
           instead of the default single-page format.}

     @item{@racket['main-doc] : Indicates that the generated
           documentation should be written into the main installation
           directory, instead of to a user-specific directory. This
           mode is the default for a collection that is itself located
           in the main installation.}

     @item{@racket['user-doc] : Indicates that the generated
           documentation should be written a user-specific
           directory. This mode is the default for a collection that
           is not itself located in the main installation.}

     @item{@racket['depends-all] : Indicates that the document should
           be rebuilt if any other document is rebuilt---except for
           documents that have the @racket['no-depend-on] flag.}

     @item{@racket['depends-all-main] : Indicates that the document
           should be rebuilt if any other document is rebuilt that is
           installed into the main installation---except for documents
           that have the @racket['no-depend-on] flag.}

     @item{@racket['depends-all-user] : Indicates that the document
           should be rebuilt if any other document is rebuilt that is
           installed into the user's space---except for documents
           that have the @racket['no-depend-on] flag.}

     @item{@racket['always-run] : Build the document every time that
           @exec{raco setup} is run, even if none of its dependencies
           change.}

     @item{@racket['no-depend-on] : Removes the document for
           consideration for other dependencies. Furthermore,
           references from the document to other documents are always
           direct, instead of potentially indirect (i.e., resolved at
           document-viewing time and potentially redirected to a
           remote site).}

     @item{@racket['main-doc-root] : Designates the root document for
           the main installation. The document that currently has this
           mode should be the only one with the mode.}

     @item{@racket['user-doc-root] : Designates the root document for
           the user-specific documentation directory. The document
           that currently has this mode should be the only one with
           the mode.}

     @item{@racket['keep-style] : Leave the document's style as-is,
           instead of imposing the document style for manuals.}

     @item{@racket['no-search] : Build the document without a search
           box.}

     @item{@racket['every-main-layer] : With @racket['main-doc],
           indicates that the document should be rendered separately
           at every installation layer (see @secref["layered-install"]).}

    ]

    The @racket[_category] list specifies how to show the document in
    the root table of contents. The list must start with a category,
    which determines where the manual appears in the root
    documentation page. A category is either a string or a symbol. If
    it is a string, then the string is the category label on the root
    page. If it is a symbol, then a default category label is
    used. The available symbols and the order of categories on the
    root documentation page is as below:

   @itemize[

     @item{@racket['getting-started] : High-level, introductory
           documentation, typeset at the same level as other
           category titles.}

     @item{@racket['language] : Documentation for a prominent
           programming language.}

     @item{@racket['tool] : Documentation for an executable.}

     @item{@racket['gui-library] : Documentation for GUI and graphics
           libraries.}

     @item{@racket['net-library] : Documentation for networking
           libraries.}

     @item{@racket['parsing-library] : Documentation for parsing
           libraries.}

     @item{@racket['tool-library] : Documentation for programming-tool
           libraries (i.e., not important enough for the more
           prominent @racket['tool] category).}

     @item{@racket['interop] : Documentation for interoperability
           tools and libraries.}

     @item{All string categories as ordered by @racket[string<=?].}
     
     @item{@racket['library] : Documentation for libraries; this
           category is the default and used for unrecognized category
           symbols.}

     @item{@racket['drracket-plugin] : Documentation for DrRacket 
           Plugins.}

     @item{@racket['legacy] : Documentation for deprecated libraries,
           languages, and tools.}

     @item{@racket['experimental] : Documentation for an experimental
           language or library.}

     @item{@racket['other] : Other documentation.}

     @item{@racket['omit] : Documentation that should not be listed on
           the root page or indexed for searching.}

     @item{@racket['omit-start] : Documentation that should not be
           listed on the root page but should be indexed for
           searching.}

   ]
   Libraries using category symbols not listed are added to the 
   Miscellaneous Libraries category on the documentation index page.

   This example lists the documentation in the 'Slideshow Libraries' category:
   
   @racketblock[
   (define scribblings
     '(("ppict.scrbl" () ("Slideshow Libraries"))))
   ]

   If the category list has a second element, it must be a real number
   that designates the manual's sorting position with the category;
   manuals with the same sorting position are ordered
   alphabetically. For a pair of manuals with sorting numbers
   @racket[_n] and @racket[_m], the groups for the manuals are
   separated by space if @racket[(truncate (/ _n 10))]and
   @racket[(truncate (/ _m 10))] are different.

   The @racket[_out-k] specification is a hint on whether to break the
   document's cross-reference information into multiple parts, which
   can reduce the time and memory use for resolving a cross-reference
   into the document. It must be a positive, exact integer, and the
   default is @racket[1].

   The @racket[_order-n] specification is a hint for ordering document
   builds, since documentation references can be mutually recursive.
   The order hint can be any real number. A value of @racket[-10] or
   less disables running the document in parallel to other documents.
   The main Racket reference is given a value of @racket[-11], the
   search page is given a value of @racket[10], and the default is
   @racket[0].

   A directory for pre-rendered documentation is computed from the
   source file name by starting with the directory of the
   @filepath{info.rkt} file, adding @filepath{doc}, and then using the
   document name (which is usually the source file's name without a
   suffix); if such a directory exists and does not have a
   @filepath{synced.rktd} file, then it is treated as pre-rendered
   documentation and moved into place, in which case the documentation
   source file need not be present. Moving documentation into place
   may require no movement at all, depending on the way that the
   enclosing collection is installed, but movement includes adding a
   @filepath{synced.rktd} file to represent the installation.

   @history[#:changed "6.4" @elem{Allow a category to be a string
                                 instead of a symbol.}
            #:changed "8.9.0.6" @elem{Add 'drracket-plugin category 
                                      symbol.}]}

 @item{@as-index{@racketidfont{release-note-files}} : @racket[(listof (cons/c string? (cons/c string? list?)))] ---
   A list of release-notes text files to link from the main documentation pages.
   Each note is itself represented as a list, and the list can specify auxiliary
   notes that are grouped with the main note.

   A @racketidfont{release-note-files} entry must be a value
   that can be generated from an expression matching the following
   @racket[_entry] grammar:

   @racketgrammar*[
     #:literals (list)
     [entry (list note ...)]
     [doc (list label-string note-path)
          (list label-string note-path order-integer)
          (list label-string note-path order-integer
                (list sub-note ...))]
     [sub-note (list label-string note-path)]
   ]

   The @racket[_order-integer] is used to order notes and defaults to @racket[0].}

 @item{@indexed-racket[racket-launcher-names] : @racket[(listof string?)]
   --- @elemtag["racket-launcher-names"] A list of executable names
   to be generated in the installation's executable directory to run
   Racket-based programs implemented by the collection. A parallel
   list of library names must be provided by
   @racket[racket-launcher-libraries] or
   @racket[racket-launcher-flags].

   For each name, a launching executable is set up using
   @racket[make-racket-launcher].  The arguments are @Flag{l-} and
   @tt{@nonterm{colls}/.../@nonterm{file}}, where @nonterm{file} is
   the file named by @racket[racket-launcher-libraries] and
   @tt{@nonterm{colls}/...}  are the collections (and subcollections)
   of the @filepath{info.rkt} file.

   In addition,

   @racketblock[
    (build-aux-from-path
     (build-path (collection-path #,(nonterm "colls") _...) #,(nonterm "suffixless-file")))
   ]

   is provided for the optional @racket[_aux] argument (for icons,
   etc.) to @racket[make-racket-launcher], where
   @nonterm{suffixless-file} is @nonterm{file} without its suffix.

   If @racket[racket-launcher-flags] is provided, it is used as a
   list of command-line arguments passed to @exec{racket} instead of
   the above default, allowing arbitrary command-line arguments. If
   @racket[racket-launcher-flags] is specified together with
   @racket[racket-launcher-libraries], then the flags will override
   the libraries, but the libraries can still be used to specify a
   name for @racket[build-aux-from-path] (to find related information
   like icon files etc).}

 @item{@indexed-racket[racket-launcher-libraries] : @racket[(listof
   path-string?)] --- A list of library names in parallel to
   @elemref["racket-launcher-names"]{@racket[racket-launcher-names]}.}

 @item{@indexed-racket[racket-launcher-flags] : @racket[(listof string?)]
   --- A list of command-line flag lists, in parallel to
   @elemref["racket-launcher-names"]{@racket[racket-launcher-names]}.}

 @item{@indexed-racket[mzscheme-launcher-names],
   @racket[mzscheme-launcher-libraries], and
   @racket[mzscheme-launcher-flags] --- Backward-compatible variant of
   @racket[racket-launcher-names], etc.}

 @item{@indexed-racket[gracket-launcher-names] : @racket[(listof string?)]  ---
   @elemtag["gracket-launcher-names"] Like
   @elemref["racket-launcher-names"]{@racket[racket-launcher-names]},
   but for GRacket-based executables. The launcher-name list is treated
   in parallel to @racket[gracket-launcher-libraries] and
   @racket[gracket-launcher-flags].}

 @item{@indexed-racket[gracket-launcher-libraries] : @racket[(listof path-string?)]
   --- A list of library names in parallel to
   @elemref["gracket-launcher-names"]{@racket[gracket-launcher-names]}.}

 @item{@indexed-racket[gracket-launcher-flags] : @racket[(listof string?)] --- A
   list of command-line flag lists, in parallel to
   @elemref["gracket-launcher-names"]{@racket[gracket-launcher-names]}.}

 @item{@indexed-racket[mred-launcher-names],
   @racket[mred-launcher-libraries], and
   @racket[mred-launcher-flags] --- Backward-compatible variant of
   @racket[gracket-launcher-names], etc.}

 @item{@indexed-racket[copy-foreign-libs] : @racket[(listof (and/c
   path-string? relative-path?))] --- Files to copy into a
   directory where foreign libraries are found by @racket[ffi-lib].
   If @racket[install-platform] is defined, then the files are copied
   only if the current platform matches the definition.

   On Mac OS, when a Mach-O file is copied, if the copied file
   includes a library reference that starts @litchar{@"@"loader_path/},
   and if the referenced library exists in a different location among
   the paths listed by @racket[(get-lib-search-dirs)], then the
   library reference is updated to an absolute path.

   On Unix, when an ELF file is copied, if the copied file includes an
   RPATH setting of @litchar{$ORIGIN} and the file is being installed
   to a user-specific location, then the file's RPATH is adjusted to
   @litchar{$ORIGIN:} followed by the path to the main installation's
   library directory as reported by @racket[(find-lib-dir)].

   On Windows, deleting a previously installed foreign library may be
   complicated by a lock on the file, if it is in use. To compensate,
   @exec{raco setup} deletes a foreign-library file by first renaming
   the file to have the prefix @filepath{raco-setup-delete-}; it then
   attempts to delete the renamed file and merely issues a warning on
   a failure to delete the renamed file. Meanwhile, in modes where
   @exec{raco setup} removes uninstalled libraries, it attempts to
   delete any file in the foreign-library directory whose name starts
   with @filepath{raco-setup-delete-} (in an attempt to clean up after
   previous failures).}

 @item{@indexed-racket[move-foreign-libs] : @racket[(listof (and/c
   path-string? relative-path?))] --- Like @racket[copy-foreign-libs],
   but the original file is removed after it is copied (which makes sense
   for precompiled packages).}

 @item{@indexed-racket[copy-shared-files] : @racket[(listof (and/c
   path-string? relative-path?))] --- Files to copy into a
   directory where shared files are found.
   If @racket[install-platform] is defined, then the files are copied
   only if the current platform matches the definition.

   On Windows, uninstalled files are deleted in the same way as for
   @racket[copy-foreign-libs], and the name prefix
   @filepath{raco-setup-delete-} is similarly special.}

 @item{@indexed-racket[move-shared-files] : @racket[(listof (and/c
   path-string? relative-path?))] --- Like @racket[copy-shared-files],
   but the original file is removed after it is copied (which makes sense
   for precompiled packages).}

 @item{@indexed-racket[copy-man-pages] : @racket[(listof (and/c
   path-string? relative-path? filename-extension))] --- Files to copy
   into a @tt{man} directory. The file suffix determines its category;
   for example, @litchar{.1} should be used for a @tt{man} page
   describing an executable.

   On Windows, uninstalled files are deleted in the same way as for
   @racket[copy-foreign-libs], and the name prefix
   @filepath{raco-setup-delete-} is similarly special.}

 @item{@indexed-racket[move-man-pages] : @racket[(listof (and/c
   path-string? relative-path? filename-extension))] --- Like
   @racket[copy-man-pages], but the original file is removed after it
   is copied (which makes sense for precompiled packages).}

 @item{@indexed-racket[install-platform] : @racket[platform-spec?]
   If this specification matches the current platform, the foreign
   libraries associated with this package are copied or moved into
   useful locations. See @racket[copy-foreign-libs],
   @racket[move-foreign-libs], @racket[copy-shared-files], and
   @racket[move-shared-files]. Also see @racket[matching-platform?] for
   information on the way that the specification is compared to
   @racket[(system-type)] and @racket[(system-library-subpath #f)].}

 @item{@indexed-racket[install-collection] : @racket[path-string?] ---
   A library module relative to the collection that provides
   @racket[installer]. The @racket[installer] procedure must accept
   one, two, three, or four arguments:

   @itemlist[

   @item{The first argument is a directory path to the parent of the
   Racket installation's @filepath{collects} directory.}

   @item{The second argument, if accepted, is a path to the
   collection's own directory.}

   @item{The third argument, if accepted, is a boolean indicating
   whether the collection is installed as user-specific (@racket[#t])
   or installation-wide (@racket[#f]).}

   @item{The fourth argument, if accepted, is a boolean indicating
   whether the collection is installed as installation-wide and should
   nevertheless avoid modifying the installation; an
   @racket[installer] procedure that does not accept this argument is
   never called when the argument would be @racket[#t]. An installer
   that does accept this argument is called with @racket[#t] to that
   it can perform user-specific work, even though the collection is
   installed installation-wide.}

   ]}

 @item{@indexed-racket[pre-install-collection] : @racket[path-string?] ---
   Like @racket[install-collection], except that the corresponding
   installer procedures are called @emph{before} the normal @filepath{.zo} build,
   instead of after. The provided procedure is
   @racket[pre-installer], so it can be provided by the
   same file that provides an @racket[installer] procedure.}

 @item{@indexed-racket[post-install-collection] : @racket[path-string?]  ---
   Like @racket[install-collection] for a procedure that is called right after the
   @racket[install-collection] procedure is executed. The
   @DFlag{no-install} flag can be provided to @exec{raco setup}
   to disable @racket[install-collection] and @racket[pre-install-collection],
   but not @racket[post-install-collection].  The @racket[post-install-collection]
   function is therefore expected to perform operations that are always needed,
   even after an installation that contains pre-compiled files. The
   provided procedure is @racket[post-installer], so it
   can be provided by the same file that provides an
   @racket[installer] procedure.}

 @item{@indexed-racket[assume-virtual-sources] : @racket[any/c] ---
   A true value indicates that bytecode files without a corresponding
   source file should not be removed from @filepath{compiled} directories,
   and no files should not be removed when the
   @DFlag{clean} or @Flag{c} flag is passed to @exec{raco setup}.}

 @item{@indexed-racket[clean] : @racket[(listof path-string?)] ---
   @elemtag["clean"] A list of pathnames to be deleted when the
   @DFlag{clean} or @Flag{c} flag is passed to @exec{raco setup}. The
   pathnames must be relative to the collection. If any path names a
   directory, each of the files in the directory are deleted, but none
   of the subdirectories of the directory are checked. If the path
   names a file, the file is deleted. The default, if this flag is not
   specified, is to delete all files in the @filepath{compiled}
   subdirectory, and all of the files in the platform-specific
   subdirectory of the compiled directory for the current platform.

   Just as compiling @filepath{.zo} files will compile each module
   used by a compiled module, deleting a module's compiled image will
   delete the @filepath{.zo} of each module that is used by the
   module. More specifically, used modules are determined when
   deleting a @filepath{.dep} file, which would have been created to
   accompany a @filepath{.zo} file when the @filepath{.zo} was built
   by @exec{raco setup} or @exec{raco make} (see
   @secref["Dependency\x20Files"]). If the @filepath{.dep} file
   indicates another module, that module's @filepath{.zo} is deleted
   only if it also has an accompanying @filepath{.dep} file. In that
   case, the @filepath{.dep} file is deleted, and additional used
   modules are deleted based on the used module's @filepath{.dep}
   file, etc. Supplying a specific list of collections to @exec{raco
   setup} disables this dependency-based deletion of compiled files.}

 @item{@racket[compile-omit-paths], @racket[compile-omit-files], and
   @racket[compile-include-files] --- Used indirectly via
   @racket[compile-collection-zos].}

@item{@racket[module-suffixes] and @racket[doc-module-suffixes] ---
   Used indirectly via @racket[get-module-suffixes].}

]

@; ------------------------------------------------------------------------

@include-section["info.scrbl"]

@; ------------------------------------------------------------------------

@section[#:tag "setup-check-deps"]{Package Dependency Checking}

When @exec{raco setup} is run with no arguments,@margin-note*{Unless
@DFlag{check-pkg-deps} is specified, dependency checking is disabled
if any collection is specified for @exec{raco setup}.} after building
all collections and documentation, @exec{raco setup} checks package
dependencies. Specifically, it inspects compiled files and
documentation to check that references across package boundaries are
reflected by dependency declarations in each package-level
@filepath{info.rkt} file (see @secref[#:doc pkg-doc "metadata"]).

Dependency checking in @exec{raco setup} is intended as an aid to
package developers to help them declare dependencies correctly. The
@exec{raco setup} process itself does not depend on package dependency
declarations. Similarly, a package with a missing dependency
declaration may install successfully for other users, as long as they
happen to have the dependencies installed already. A missing
dependency creates trouble for others who install a package without
having the dependency installed already.

Practically every package depends on the @filepath{base} package,
which includes the collections that are in a minimal variant of
Racket. Declaring a dependency on @filepath{base} may seem
unnecessary, since its collections are always installed. In a future
version of Racket, however, the minimal collections may change, and
the new set of minimal collections will then have a package name, such
as @filepath{base2}. Declaring a dependency on @filepath{base} ensures
forward compatibility, and @exec{raco setup} complains if the
declaration is missing.

To accommodate the early stages of package development, missing
dependencies are not treated as an error for a package that has no
dependency declarations.

@subsection{Declaring Build-Time Dependencies}

A build-time dependency is one that is not present in a package if it
is converted to a @tech[#:doc pkg-doc]{binary package} (see
@secref[#:doc pkg-doc "strip"]). For example, @filepath{tests} and
@filepath{scribblings} directories are stripped away in a binary
package by default, so cross-package references from directories with
those names are treated as build dependencies. Similarly,
@racketidfont{test} and @racketidfont{doc} submodules are stripped
away, so references within those submodules create build dependencies.

Build-time-only dependencies can be listed as @racket[build-deps]
instead of @racket[deps] in a package's @filepath{info.rkt} file.
Dependencies listed in @racket[deps], meanwhile, are treated as both
run-time and build-time dependencies. The advantage of using
@racket[build-deps], instead of listing all dependencies in
@racket[deps], is that a binary version of the package can install
with fewer dependencies.

@subsection{How Dependency Checking Works}

Dependency checking uses @filepath{.zo} files, associated
@filepath{.dep} files (see @secref["Dependency Files"]), and the
documentation index. Dynamic references, such as through
@racket[dynamic-require], are not visible to the dependency checker;
only dependencies via @racket[require],
@racket[define-runtime-module-path-index], and other forms that
cooperate with @racket[raco make] are visible for dependency checking.

Dependency checking is sensitive to whether a dependency is needed
only as a build-time dependency. If @exec{raco setup} detects that a
missing dependency could be added as a build-time dependency, it will
suggest the addition, but @exec{raco setup} will not suggest
converting a normal dependency to a build-time dependency (since every
normal dependency counts as a build-time dependency, too).

@; ------------------------------------------------------------------------

@section[#:tag "setup-plt-plt"]{API for Setup}

@defmodule[setup/setup]

@defproc[(setup [#:file file (or/c #f path-string?) #f]
                [#:collections collections (or/c #f (listof (listof path-string?))) #f]
                [#:pkgs pkgs (or/c #f (listof string?)) #f]
                [#:planet-specs planet-specs (or/c #f 
                                                   (listof (list/c string?
                                                                   string?
                                                                   exact-nonnegative-integer?
                                                                   exact-nonnegative-integer?)))
                                             #f]
                [#:make-user? make-user? any/c #t]
                [#:avoid-main? avoid-main? any/c #f]
                [#:make-docs? make-docs? any/c #t]
                [#:make-doc-index? make-doc-index? any/c #f]
                [#:force-user-docs? force-user-docs? any/c #f]
                [#:check-pkg-deps? check-pkg-deps? any/c #f]
                [#:fix-pkg-deps? fix-pkg-deps? any/c #f]
                [#:unused-pkg-deps? unused-pkg-deps? any/c #f]
                [#:clean? clean? any/c #f]
                [#:tidy? tidy? any/c #f]
                [#:recompile-only? recompile-only? any/c #f]
                [#:jobs jobs exact-nonnegative-integer? #f]
                [#:fail-fast? fail-fast? any/c #f]
                [#:get-target-dir get-target-dir (or/c #f (-> path-string?)) #f])
          boolean?]{
Runs @exec{raco setup} with various options:

@itemlist[

 @item{@racket[file] --- if not @racket[#f], installs @racket[file] as
       a @filepath{.plt} archive.}

 @item{@racket[collections] --- if not @racket[#f], constrains setup to
       the named collections (along with @racket[pkgs] and
       @racket[planet-specs], if any)}

 @item{@racket[pkgs] --- if not @racket[#f], constrains setup to the
       named packages (along with @racket[collections] and
       @racket[planet-specs], if any)}

 @item{@racket[planet-spec] --- if not @racket[#f], constrains setup to
       the named @|PLaneT| packages (along with @racket[collections] and
       @racket[pkgs], if any)}

 @item{@racket[make-user?] --- if @racket[#f], disables any
       user-specific setup actions}

 @item{@racket[avoid-main?] --- if true, avoids setup actions that affect
       the main installation, as opposed to user directories}

 @item{@racket[make-docs?] --- if @racket[#f], disables any
       documentation-specific setup actions}

 @item{@racket[make-doc-index?] --- if true, builds
       documentation index collections in addition to @racket[collections],
       assuming that documentation is built}

 @item{@racket[force-user-docs?] --- if true, then when building
       documentation, creates a user-specific documentation entry point
       even if it has the same content as the installation}

 @item{@racket[check-pkg-deps?] --- if true, enables
       package-dependency checking even when @racket[collections],
       @racket[pkgs], or @racket[planet-specs] is non-@racket[#f].}

 @item{@racket[fix-pkg-deps?] --- if true, implies
       @racket[check-pkg-deps?] and attempts to automatically correct
       discovered package-dependency problems}
 
 @item{@racket[unused-pkg-deps?] --- if true, implies
       @racket[check-pkg-deps?] and also reports dependencies that
       appear to be unused}

 @item{@racket[clean?] --- if true, enables cleaning mode instead of setup mode}

 @item{@racket[tidy?] --- if true, enables global tidying of
       documentation and metadata indexes even when @racket[collections]
       or @racket[planet-specs] is non-@racket[#f]}

 @item{@racket[recompile-only?] --- if true, disallows compilation
       from source, allowing only timestamp adjustments and recompilation
       from machine-independent form}

 @item{@racket[jobs] --- if not @racket[#f], determines the maximum number of parallel
       tasks used for setup}

 @item{@racket[fail-fast?] --- if true, breaks the current thread as soon as an
       error is discovered}

 @item{@racket[get-target-dir] --- if not @racket[#f], treated as a
       value for @sigelem[setup-option^ current-target-directory-getter]}

]

The result is @racket[#t] if @exec{raco setup} completes without error,
@racket[#f] otherwise.

Instead of using @envvar{PLT_COMPILED_FILE_CHECK}, @racket[setup] is
sensitive to the @racket[use-compiled-file-check] parameter.

@history[#:changed "6.1" @elem{Added the @racket[fail-fast?] argument.}
         #:changed "6.1.1" @elem{Added the @racket[force-user-docs?] argument.}
         #:changed "7.2.0.7" @elem{Added the @racket[check-pkg-deps?],
                                   @racket[fix-pkg-deps?] , and @racket[unused-pkg-deps?]
                                   arguments.}
         #:changed "7.2.0.8" @elem{Added the @racket[recompile-only?] argument.}]}



@subsection{@exec{raco setup} Unit}

@defmodule[setup/setup-unit]

The @racketmodname[setup/setup-unit] library provides @exec{raco setup} in unit
form. The associated @racket[setup/option-sig] and
@racket[setup/option-unit] libraries provides the interface for
setting options for the run of @exec{raco setup}.

For example, to unpack a single @filepath{.plt} archive
@filepath{x.plt}, set the @sigelem[setup-option^ archives] parameter
to @racket[(list "x.plt")] and leave @sigelem[setup-option^
specific-collections] as @racket[null].

Link the options and setup units so that your option-setting code is
initialized between them, e.g.:

@racketblock[
(compound-unit
  _...
  (link _...
    [((OPTIONS : setup-option^)) setup:option@]
    [() my-init-options@ OPTIONS]
    [() setup@ OPTIONS _...])
  _...)
]

@defthing[setup@ unit?]{

Imports

  @itemize[#:style "compact"]{
    @item{@racket[setup-option^]}
    @item{@racket[compiler^]}
    @item{@racket[compiler:option^]}
    @item{@racket[launcher^]}
    @item{@racket[dynext:file^]}
  }

and exports nothing. Invoking @racket[setup@] starts the setup process.}

@; ----------------------------------------

@subsection[#:tag "setup-plt-options"]{Options Unit}

@defmodule[setup/option-unit]

@defthing[setup:option@ unit?]{

Imports nothing and exports @racket[setup-option^].}

@; ----------------------------------------

@subsection{Options Signature}

@defmodule[setup/option-sig]

@defsignature[setup-option^ ()]{

@signature-desc{Provides parameters used to control @exec{raco setup} in unit
form.}

  @defparam[setup-program-name name string?]{
    The prefix used when printing status messages.
    @defaults[@racket["raco setup"]]
  }

@defparam[setup-compiled-file-paths paths (or/c #f (listof (and/c path? relative-path?)))]{
 If not @racket[#f], supplies a value like the one for @racket[use-compiled-file-paths]
 to control operations such as cleaning, where @racket[use-compiled-file-paths]
 may have been set to @racket[null] to avoid loading bytecode.

 @history[#:added "1.7"]}

@defboolparam[verbose on?]{
  If on, prints messages from @exec{make} to @envvar{stderr}.
  @defaults[@racket[#f]]}

@defboolparam[make-verbose on?]{
  If on, verbose @exec{make}. @defaults[@racket[#f]]}

@defboolparam[compiler-verbose on?]{
  If on, verbose @exec{compiler}. @defaults[@racket[#f]]}

@defboolparam[clean on?]{
 If on, delete @filepath{.zo} and
 @filepath{.so}/@filepath{.dll}/@filepath{.dylib} files in the
 specified collections. @defaults[@racket[#f]]}

@defparam[compile-mode path (or/c path? #f)]{
  If a @racket[path] is given, use a @filepath{.zo} compiler other than plain
  @exec{compile}, and build to @racket[(build-path "compiled" (compile-mode))].
  @defaults[@racket[#f]]}

@defboolparam[make-zo on?]{
  If on, compile @filepath{.zo}. @defaults[@racket[#t]]}

@defboolparam[make-info-domain on?]{
  If on, update @filepath{info-domain/compiled/cache.rkt} for each
  collection path. @defaults[@racket[#t]]}

@defboolparam[make-launchers on?]{
  If on, make collection @filepath{info.rkt}-specified launchers and @tt{man} pages. @defaults[@racket[#t]]}

@defboolparam[make-foreign-lib on?]{
  If on, install collection @filepath{info.rkt}-specified libraries. @defaults[@racket[#t]]}

  @defboolparam[make-docs on?]{
    If on, build documentation.
    @defaults[@racket[#t]]
  }
  
  @defboolparam[make-user on?]{
    If on, build the user-specific collection tree.
    @defaults[@racket[#t]]
  }
  
  @defboolparam[make-planet on?]{
    If on, build the planet cache.
    @defaults[@racket[#t]]
  }
  
@defboolparam[avoid-main-installation on?]{
 If on, avoid building bytecode in the main installation tree when building
 other bytecode (e.g., in a user-specific collection). @defaults[@racket[#f]]}

@defboolparam[make-tidy on?]{
 If on, remove metadata cache information and
  documentation for non-existent collections (to clean up after removal)
  even when @racket[specific-collections] or @racket[specific-planet-dirs]
  is non-@racket['()] or @racket[make-only] is true. @defaults[@racket[#f]]}

@defboolparam[call-install on?]{
  If on, call collection @filepath{info.rkt}-specified setup code.
  @defaults[@racket[#t]]}

@defboolparam[call-post-install on?]{
  If on, call collection @filepath{info.rkt}-specified post-install code.
  @defaults[@racket[#t]]}

@defboolparam[pause-on-errors on?]{
  If on, in the event of an error, prints a summary error and waits for
  @envvar{stdin} input before terminating. @defaults[@racket[#f]]}

  @defparam[parallel-workers num exact-nonnegative-integer?]{
    Determines the number of places to use for compiling bytecode
    and for building the documentation.
    @defaults[@racket[(min (processor-count) 8)]]
  }

@defboolparam[fail-fast on?]{
  If on, breaks the original thread as soon as an error is discovered.
  @defaults[@racket[#f]]

  @history[#:added "1.2"]}
  
@defboolparam[force-unpacks on?]{
  If on, ignore version and already-installed errors when unpacking a
  @filepath{.plt} archive. @defaults[@racket[#f]]}
  
@defparam[specific-collections colls (listof (listof path-string?))]{
  A list of collections to set up; the empty list means set-up all
  collections if the archives list and @racket[specific-planet-dirs]
  is also @racket['()]. @defaults[@racket['()]]}

  @defparam[specific-planet-dirs dir (listof (list/c string?
                                                     string?
                                                     exact-nonnegative-integer?
                                                     exact-nonnegative-integer?))]{
    A list of planet package version specs to set up; the empty list means to
    set-up all planet collections if the archives list and @racket[specific-collections]
    is also @racket['()]. @defaults[@racket['()]]
  }

@defboolparam[make-only on?]{
 If true, set up no collections if @racket[specific-collections]
 and @racket[specific-planet-dirs] are both @racket['()].}
  
@defparam[archives arch (listof path-string?)]{
  A list of @filepath{.plt} archives to unpack; any collections specified
  by the archives are set-up in addition to the collections listed in
  specific-collections. @defaults[@racket[null]]}

@defboolparam[archive-implies-reindex on?]{
  If on, when @racket[archives] has a non-empty list of packages, if any
  documentation is built, then suitable documentation start pages, search pages,
  and master index pages are rebuilt. @defaults[@racket[#t]]}

@defparam[current-target-directory-getter thunk (-> path-string?)]{
  A thunk that returns the target directory for unpacking a relative
  @filepath{.plt} archive; when unpacking an archive, either this or
  the procedure in @racket[current-target-plt-directory-getter] will
  be called. @defaults[@racket[current-directory]]}

@defparam[current-target-plt-directory-getter
          proc (path-string?
                path-string?
                (listof path-string?) . -> . path-string?)]{
  A procedure that takes a preferred path, a path to the parent of the main
  @filepath{collects} directory, and a list of path choices; it returns
  a path for a "plt-relative" install; when unpacking an archive, either
  this or the procedure in @racket[current-target-directory-getter] will
  be called, and in the former case, this procedure may be called
  multiple times. @defaults[@racket[(lambda (preferred main-parent-dir choices) preferred)]]}

}

@; ----------------------------------------

@subsection{Setup Start Module}

@defmodule[setup]{The @racketmodname[setup] library implements
@exec{raco setup}, including the part that bootstraps @exec{raco setup}
if its own implementation needs to be compiled.}

When running @racketmodname[setup] via @exec{racket}, supply the
@exec{@Flag{N} raco} to ensure that command-line arguments are parsed
the same way as for @exec{raco setup}, as opposed to a legacy
command-line mode.

@; ------------------------------------------------------------------------

@section[#:tag ".plt-archives"]{API for Installing @filepath{.plt} Archives}

The @racketmodname[setup/plt-single-installer] module provides a
function for installing a single @filepath{.plt} file.

@subsection{Non-GUI Installer}

@local-module[setup/plt-single-installer]{

@defmodule[setup/plt-single-installer]

@defproc[(run-single-installer
          (file path-string?)
          (get-dir-proc (-> (or/c path-string? #f)))
          [#:show-beginning-of-file? show-beginning-of-file? any/c #f])
         void?]{
   Creates a separate thread and namespace, runs the installer in that
   thread with the new namespace, and returns when the thread
   completes or dies. It also creates a custodian
   (see @secref[#:doc ref-src]{custodians}) to manage the
   created thread, sets the exit handler for the thread to shut down
   the custodian, and explicitly shuts down the custodian
   when the created thread terminates or dies.

   The @racket[get-dir-proc] procedure is called if the installer needs a
   target directory for installation, and a @racket[#f] result means that
   the user canceled the installation. Typically, @racket[get-dir-proc] is
   @racket[current-directory].
   
   If @racket[show-beginning-of-file?] is a true value and the installation
   fails, then @racket[run-single-installer] prints the first 1,000 characters
   of the file (in an attempt to help debug the cause of failures).
}

@defproc[(install-planet-package [file path-string?] 
                                 [directory path-string?] 
                                 [spec (list/c string? string? 
                                               (listof string?) 
                                               exact-nonnegative-integer?
                                               exact-nonnegative-integer?)])
         void?]{

 Similar to @racket[run-single-installer], but runs the setup process
 to install the archive @racket[file] into @racket[directory] as the
 @|PLaneT| package described by @racket[spec]. The user-specific
 documentation index is not rebuilt, so @racket[reindex-user-documentation]
 should be run after a set of @|PLaneT| packages are installed.}

@defproc[(reindex-user-documentation) void?]{
  Similar to @racket[run-single-installer], but runs only the part of
  the setup process that rebuilds the user-specific documentation
  start page, search page, and master index.}

@defproc[(clean-planet-package [directory path-string?] 
                               [spec (list/c string? string? 
                                             (listof string?) 
                                             exact-nonnegative-integer?
                                             exact-nonnegative-integer?)])
         void?]{
  Undoes the work of @racket[install-planet-package]. The user-specific
 documentation index is not rebuilt, so @racket[reindex-user-documentation]
 should be run after a set of @|PLaneT| packages are removed.}}


@; ----------------------------------------------------------

@section[#:tag "dirs"]{API for Finding Installation Directories}

@defmodule[setup/dirs]{ The @racketmodname[setup/dirs] library
  provides several procedures for locating installation directories.
  Many of these paths can be configured through the
  @tech{configuration directory} (see @secref["config-file"]).}

In cross-platform build mode (see @secref["cross-system"]), the
functions provided by @racketmodname[setup/dirs] generally report
target-system paths, instead of current-system paths. The exceptions are
@racket[get-lib-search-dirs] and @racket[find-dll-dir], which report
current-system paths while @racket[get-cross-lib-search-dirs] and
@racket[find-cross-dll-dir] report target-system paths.

@(define-syntax-rule (see-config id)
   @elem{See also @racket['id] in @secref["config-file"].})

@defproc[(find-collects-dir) (or/c path? #f)]{
  Returns a path to the installation's main @filepath{collects} directory, or
  @racket[#f] if none can be found. A @racket[#f] result is likely only
  in a stand-alone executable that is distributed without libraries.}

@(define-syntax user-path
   (syntax-rules ()
     [(_ dir vers)
      @list{The user-specific path depends on at least
            @racket[(find-system-path 'addon-dir)] and
            @racket[vers].}]
     [(_ dir)
      (user-path dir (get-installation-name))]))

@defproc[(find-user-collects-dir) path?]{
  Returns a path to the user-specific @filepath{collects} directory; the
  directory indicated by the returned path may or may not exist.

  @user-path["collects"]}

@defproc[(get-collects-search-dirs) (listof path?)]{
  Returns the same result as @racket[(current-library-collection-paths)],
  which means that this result is not sensitive to the value of the 
  @racket[use-user-specific-search-paths] parameter.}

@defproc[(get-main-collects-search-dirs) (listof path?)]{
  Returns a list of paths to installation @filepath{collects}
  directories, normally including the result of @racket[find-collects-dir].
  These directories are normally included in the result of
  @racket[(current-library-collection-paths)], but a
  @envvar{PLTCOLLECTS} setting or change to the parameter may cause
  them to be omitted. Any other path in
  @racket[(current-library-collection-paths)] is treated as
  user-specific. The directories indicated by the returned paths may
  or may not exist.

  The main-collections search path can be configured via
  @racket['collects-search-dirs] in @filepath{config.rktd} (see
  @secref["config-file"]).}

@defproc[(find-config-dir) (or/c path? #f)]{
  Returns a path to the installation's @filepath{etc} directory, which
  contains configuration and package information---including
  configuration of some of the other directories (see @secref["config-file"]).
  A @racket[#f] result indicates that no configuration directory
  is available.}

@defproc[(find-links-file) (or/c path? #f)]{
  Returns a path to the installation's @tech[#:doc
  reference-doc]{collection links file}.  The file indicated by the
  returned path may or may not exist. A @racket[#f] result indicates
  that no links file is available.

  @see-config[links-file]}

@defproc[(find-user-links-file [vers string? (get-installation-name)]) path?]{
  Returns a path to the user's @tech[#:doc reference-doc]{collection
  links file}.  The file indicated by the returned path may or may not
  exist.

  @user-path["links.rktd" vers]}

@defproc[(get-links-search-files) (listof path?)]{
  Returns a list of paths to installation @tech[#:doc
  reference-doc]{collection links files} to search in
  order. (Normally, the result includes the result of
  @racket[(find-links-file)], which is where new installation-wide
  links are installed by @exec{raco link} or @racket[links].) The
  result of @racket[find-user-links-file]
  is @emph{not} added to the returned list. The
  files indicated by the returned paths may or may not exist.

  @see-config[links-search-files]}

@defproc[(find-pkgs-dir) (or/c path? #f)]{
  Returns a path to the directory containing packages with
  installation scope; the directory indicated by the returned path may
  or may not exist. A @racket[#f] result indicates that no package-installation
  directory is available.

  @see-config[pkgs-dir]}

@defproc[(find-user-pkgs-dir [vers string? (get-installation-name)]) path?]{
  Returns a path to the directory containing packages with
  user-specific scope for installation name @racket[vers]; the directory indicated by
  the returned path may or may not exist.

  @user-path["pkgs" vers]}

@defproc[(get-pkgs-search-dirs) (listof path?)]{
  Returns a list of paths to the directories containing packages in
  installation scope.  (Normally, the result includes the result of
  @racket[(find-pkgs-dir)], which is where new packages are installed
  by @exec{raco pkg install}.) The result of @racket[find-user-pkgs-dir]
  is @emph{not} added to the returned list. The directories indicated by the returned
  paths may or may not exist.

  @see-config[pkgs-search-dirs]}

@defproc[(find-doc-dir) (or/c path? #f)]{
  Returns a path to the installation's @filepath{doc} directory.
  The result is @racket[#f] if no such directory is available.

  @see-config[doc-dir]}

@defproc[(find-user-doc-dir) path?]{
  Returns a path to a user-specific @filepath{doc} directory. The directory
  indicated by the returned path may or may not exist.

  @user-path["doc"]}

@defproc[(get-doc-search-dirs) (listof path?)]{
  Returns a list of paths to search for documentation, not including
  documentation stored in individual collections. Unless it is
  configured otherwise, the result includes any non-@racket[#f] result of
  @racket[(find-doc-dir)] and @racket[(find-user-doc-dir)]---but the latter is
  included only if the value of the @racket[use-user-specific-search-paths]
  parameter is @racket[#t].

  @see-config[doc-search-dirs]}

@defproc[(get-doc-extra-search-dirs) (listof path?)]{
  Like @racket[get-doc-search-dirs], but refrains from adding
  @racket[(find-doc-dir)] and @racket[(find-user-doc-dir)] to the
  underlying @racket['doc-search-dirs] configuration.

  @history[#:added "8.1.0.6"]}

@defproc[(find-lib-dir) (or/c path? #f)]{
  Returns a path to the installation's @filepath{lib} directory, which contains
  libraries and other build information. The result is @racket[#f] if no such
  directory is available.

  @see-config[lib-dir]}

@defproc[(find-user-lib-dir) path?]{
  Returns a path to a user-specific @filepath{lib} directory; the directory
  indicated by the returned path may or may not exist.

  @user-path["lib"]}

@defproc[(get-lib-search-dirs) (listof path?)]{
  Returns a list of paths to search for foreign libraries.

  Unless it is configured otherwise, and except in cross-platform
  build mode, the result includes any non-@racket[#f] result of
  @racket[(find-lib-dir)] and @racket[(find-user-lib-dir)]---but the
  latter is included only if the value of the
  @racket[use-user-specific-search-paths] parameter is @racket[#t].

  In cross-platform build mode (see @secref["cross-system"]),
  @racket[get-lib-search-dirs] reports a result suitable for the
  current system, instead of the target system. See also
  @racket[get-cross-lib-search-dirs].

  @see-config[lib-search-dirs]

  @history[#:changed "6.1.1.4" @elem{Dropped @racket[(find-dll-dir)]
                                     from the set of paths to
                                     explicitly include in the
                                     default.}
           #:changed "6.9.0.1" @elem{Changed behavior in cross-platform build mode.}]}

@defproc[(get-cross-lib-search-dirs) (listof path?)]{
  Like @racket[get-lib-search-dirs], but in cross-platform build mode,
  reports directories for the target system (including any
  non-@racket[#f] result of @racket[(find-lib-dir)], etc.)
  instead of the current system.

  @history[#:added "6.9.0.1"]}

@defproc[(get-cross-lib-extra-search-dirs) (listof path?)]{
  Like @racket[get-cross-lib-search-dirs], but refrains from adding
  @racket[(find-lib-dir)] and @racket[(find-user-lib-dir)] to the
  underlying @racket['lib-search-dirs] configuration.

  @history[#:added "8.1.0.6"]}

@defproc[(find-dll-dir) (or/c path? #f)]{
  Returns a path to the directory that contains DLLs for use with the
  current executable (e.g., @filepath{libracket.dll} on Windows).
  The result is @racket[#f] if no such directory is available, or if no
  specific directory is available (i.e., other than the platform's normal
  search path).

  In cross-platform build mode (see @secref["cross-system"]),
  @racket[find-dll-dir] reports a result suitable for the current
  system, instead of the target system. See also
  @racket[find-cross-dll-dir].

  @history[#:changed "6.9.0.1" @elem{Changed behavior in cross-platform build mode.}]}

@defproc[(find-cross-dll-dir) (or/c path? #f)]{
  Like @racket[find-dll-dir], but in cross-platform build mode,
  reports a directory for the target system
  instead of the current system.

  @history[#:added "6.9.0.1"]}

@defproc[(find-share-dir) (or/c path? #f)]{ Returns a path to the
  installation's @filepath{share} directory, which contains installed
  packages and other platform-independent files. The result is
  @racket[#f] if no such directory is available.

  @see-config[share-dir]}

@defproc[(find-user-share-dir) path?]{
  Returns a path to a user-specific @filepath{share} directory; the directory
  indicated by the returned path may or may not exist.

  @user-path["share"]}

@defproc[(get-share-search-dirs) (listof path?)]{
  Returns a list of paths to search for files that are normally in a
  @filepath{share} directory. 

  Unless it is configured otherwise, the result includes any
  non-@racket[#f] result of @racket[(find-share-dir)] and
  @racket[(find-user-share-dir)]---but the latter is included only if
  the value of the @racket[use-user-specific-search-paths] parameter
  is @racket[#t].

  @see-config[share-search-dirs]

  @history[#:added "8.1.0.6"]}

@defproc[(get-share-extra-search-dirs) (listof path?)]{
  Like @racket[get-share-search-dirs], but refrains from adding
  @racket[(find-share-dir)] and @racket[(find-user-share-dir)] to the
  underlying @racket['share-search-dirs] configuration.

  @history[#:added "8.1.0.6"]}

@defproc[(find-include-dir) (or/c path? #f)]{
  Returns a path to the installation's @filepath{include} directory, which
  contains @filepath{.h} files for building Racket extensions and embedding
  programs. The result is @racket[#f] if no such directory is available.

  @see-config[include-dir]}

@defproc[(find-user-include-dir) path?]{
  Returns a path to a user-specific @filepath{include} directory; the
  directory indicated by the returned path may or may not exist.

  @user-path["include"]}

@defproc[(get-include-search-dirs) (listof path?)]{
  Returns a list of paths to search for @filepath{.h} files. Unless it is
  configured otherwise, the result includes any non-@racket[#f] result of
  @racket[(find-include-dir)] and @racket[(find-user-include-dir)]---but the
  latter is included only if the value of the
  @racket[use-user-specific-search-paths] parameter is @racket[#t].

  @see-config[include-search-dirs]}

@defproc[(find-console-bin-dir) (or/c path? #f)]{
  Returns a path to the installation's executable directory, where the
  stand-alone Racket executable resides. The result is @racket[#f] if no
  such directory is available.

  @see-config[bin-dir]}

@defproc[(find-gui-bin-dir) (or/c path? #f)]{
  Returns a path to the installation's executable directory, where the
  stand-alone GRacket executable resides. The result is @racket[#f] if no such
  directory is available.

  @see-config[gui-bin-dir]}

@defproc[(find-user-console-bin-dir) path?]{
  Returns a path to the user's executable directory; the directory
  indicated by the returned path may or may not exist.

  @user-path[#f]}

@defproc[(find-user-gui-bin-dir) path?]{
  Returns a path to the user's executable directory for graphical
  programs; the directory indicated by the returned path may or may
  not exist.

  @user-path[#f]}

@defproc[(get-console-bin-search-dirs) (listof path?)]{
  Analogous to @racket[get-share-search-dirs], but for paths to search
  for executables such as @exec{racket}.

  @see-config[bin-search-dirs]

  @history[#:added "8.1.0.6"]}

@defproc[(get-console-bin-extra-search-dirs) (listof path?)]{
  Analogous to @racket[get-share-extra-search-dirs] for the underlying
  @racket['bin-search-dirs] configuration.

  @history[#:added "8.1.0.6"]}

@defproc[(get-gui-bin-search-dirs) (listof path?)]{
  Analogous to @racket[get-share-search-dirs], but for paths to search
  for executables such as @exec{gracket}.

  @see-config[gui-bin-search-dirs]

  @history[#:added "8.1.0.6"]}

@defproc[(get-gui-bin-extra-search-dirs) (listof path?)]{
  Analogous to @racket[get-share-extra-search-dirs] for the underlying
  @racket['gui-bin-search-dirs] configuration.

  @history[#:added "8.1.0.6"]}

@defproc[(find-apps-dir) (or/c path? #f)]{
  Returns a path to the installation's directory @filepath{.desktop}
  files (for Unix). The result is @racket[#f] if no such directory
  exists.

  @see-config[apps-dir]}

@defproc[(find-user-apps-dir) path?]{
  Returns a path to the user's directory for @filepath{.desktop} files
  (for Unix); the directory indicated by the returned path may or may
  not exist.

  @user-path[#f]}

@defproc[(find-man-dir) (or/c path? #f)]{
  Returns a path to the installation's man-page directory. The result is
  @racket[#f] if no such directory exists. @see-config[man-dir]}

@defproc[(find-user-man-dir) path?]{
  Returns a path to the user's man-page directory; the directory
  indicated by the returned path may or may not exist.

  @user-path["man"]}

@defproc[(get-man-search-dirs) (listof path?)]{
  Analogous to @racket[get-share-search-dirs], but for paths to search
  for man pages.

  @see-config[man-search-dirs]

  @history[#:added "8.1.0.6"]}

@defproc[(get-man-extra-search-dirs) (listof path?)]{
  Analogous to @racket[get-share-extra-search-dirs] for the underlying
  @racket['man-search-dirs] configuration.

  @history[#:added "8.1.0.6"]}

@defproc[(get-doc-search-url) string?]{
  Returns a string that is used by the documentation system, augmented
  with a version and search-key query, for remote documentation links.

  @see-config[doc-search-url]}

@defproc[(get-doc-open-url) (or/c string? #f)]{
  Returns @racket[#f] or a string for a root URL to be used as an
  alternative to opening a local file for documentation. A
  non-@racket[#f] configuration means that DrRacket, for example,
  performs keyword searches for documentation via the specified URL
  instead of from locally installed documentation.

  @see-config[doc-open-url]

  @history[#:added "6.0.1.6"]}

@defproc[(get-installation-name [config (read-installation-configuration-table)]) string?]{

 Returns the current installation's name, which is often
 @racket[(version)], but an installation name can be set through a
 combination of a @racket['installation-name] value in @racket[config]
 plus a user-specific directory state if
 @racket[(use-user-specific-search-paths)] is @racket[#t].

 A user-specific result depends on whether a directory
 @as-index{@filepath{other-version}} exists within
 @racket[(find-system-path 'addon-dir)]. If that directory exists, and
 it no directory with the installation's configured name exists, then
 @racket["other-version"] is used as the installation name. So, by
 creating the @filepath{other-version} directory, a user can opt into
 sharing of packages and collections across installations/versions,
 while opting out for a specific installation/version by creating
 a directory with that installation's name.

 @history[#:changed "8.4.0.3" @elem{Added the @racket[config] argument and support for a
                                    user-specific installation name.}]}

@defproc[(get-build-stamp) (or/c #f string?)]{ Returns a string
   that identifies an installation build, which can be used to augment
   the Racket version number to more specifically identify the
   build. An empty string is normally produced for a release build.
   The result is @racket[#f] if no build stamp is available.}

@defproc[(get-absolute-installation?) boolean?]{
  Returns @racket[#t] if this installation uses
  absolute path names for executable and library references, 
  @racket[#f] otherwise.}

@deftogether[(
@defproc[(find-addon-tethered-console-bin-dir) (or/c #f path?)]
@defproc[(find-addon-tethered-gui-bin-dir) (or/c #f path?)]
@defproc[(find-addon-tethered-apps-dir) (or/c #f path?)]
)]{
  Returns a path to a user-specific directory to hold an extra copy of
  each installed executable and @filepath{.desktop}
  file (for Unix), where the extra copy is created by
  @exec{raco setup} and tethered to a particular result for
  @racket[(find-system-path 'addon-dir)] and
  @racket[(find-config-dir)].

  Unlike other directories, which are configured via
  @filepath{config.rktd} in the @racket[(find-config-dir)] directory
  (see @secref["config-file"]), these paths are configured via
  @racket['addon-tethered-console-bin-dir],
  @racket['addon-tethered-gui-bin-dir], and
  @racket['addon-tethered-apps-dir] entries in
  @filepath{config.rktd} in @racket[(build-path (find-system-path
  'addon-dir) "etc")]. If no configuration is present, the result from
  the corresponding function,
  @racket[find-addon-tethered-console-bin-dir],
  @racket[find-addon-tethered-gui-bin-dir], or
  @racket[find-addon-tethered-apps-dir], is @racket[#f] instead of
  a path.

  See @secref["tethered-install"] for more information.

  @history[#:added "6.5.0.2"
           #:changed "8.3.0.11" @elem{Added @racket[find-addon-tethered-apps-dir].}]]}


@deftogether[(
@defproc[(find-config-tethered-console-bin-dir) (or/c #f path?)]
@defproc[(find-config-tethered-gui-bin-dir) (or/c #f path?)]
@defproc[(find-config-tethered-apps-dir) (or/c #f path?)]
)]{
  Similar to @racket[find-addon-tethered-console-bin-dir],
  @racket[find-addon-tethered-gui-bin-dir], and
  @racket[find-addon-tethered-apps-dir], but configured via
  @filepath{config.rktd} in the @racket[(find-config-dir)] directory
  (see @secref["config-file"]) and triggers executables that are
  tethered only to a particular value of @racket[(find-config-dir)].

  See @secref["tethered-install"] for more information.

  @history[#:added "6.5.0.2"
           #:changed "8.3.0.11" @elem{Added @racket[find-addon-tethered-apps-dir].}]}
 
@; ------------------------------------------------------------------------

@section[#:tag "getinfo"]{API for Reading @filepath{info.rkt} Files}

@defmodule[setup/getinfo]{ The @racketmodname[setup/getinfo] library
   provides functions for accessing fields in @filepath{info.rkt}
   files. The file format for @filepath{info.rkt} files is documented
   in @secref["info.rkt" #:doc '(lib "scribblings/raco/raco.scrbl")].
}

@defproc[(get-info [collection-names (listof string?)]
                   [#:namespace namespace (or/c namespace? #f) #f]
                   [#:bootstrap? bootstrap? any/c #f])
         (or/c
          (symbol? [(-> any)] . -> . any)
          #f)]{
   Accepts a list of strings naming a collection or sub-collection,
   and calls @racket[get-info/full] with the full path corresponding to the
   named collection and the @racket[namespace] argument.}

@defproc[(get-info/full [path path-string?]
                        [#:namespace namespace (or/c namespace? #f) #f]
                        [#:bootstrap? bootstrap? any/c #f])
         (or/c (->* (symbol?) ((-> any)) any)
               #f)]{

   Accepts a path to a directory. If it finds either a well-formed
   @filepath{info.rkt} file or an @filepath{info.ss} file (with
   preference for the @filepath{info.rkt} file), 
   it returns an info procedure that accepts either one
   or two arguments. The first argument to the info procedure is
   always a symbolic name, and the result is the value of the name in
   the @filepath{info.rkt} file, if the name is defined. The optional
   second argument, @racket[_thunk], is a procedure that takes no
   arguments to be called when the name is not defined; the result of
   the info procedure is the result of the @racket[_thunk] in that
   case. If the name is not defined and no @racket[_thunk] is
   provided, then an exception is raised.

   The @racket[get-info/full] function returns @racket[#f] if there is
   no @filepath{info.rkt} (or @filepath{info.ss}) file in the directory. If there is a
   @filepath{info.rkt} (or @filepath{info.ss}) file that has the wrong shape (i.e., not a module
   using @racketmodname[info] or @racketmodname[setup/infotab]),
   or if the @filepath{info.rkt} file fails to load, then an exception
   is raised. If the @filepath{info.rkt} file loaded, @racket[get-info/full]
   returns the @racket[get-info] file. If the @filepath{info.rkt} file does not exist, 
   then @racket[get-info/full] does
   the same checks for the @filepath{info.ss} file, either raising an exception
   or returning the @racket[get-info] function from the @filepath{info.ss} file.

   The @filepath{info.rkt} (or @filepath{info.ss}) module is loaded
   into @racket[namespace] if it is not @racket[#f], or a private,
   weakly-held namespace otherwise.

   If @racket[bootstrap?] is true, then
   @racket[use-compiled-file-paths] is set to @racket['()] while
   reading @filepath{info.rkt} (or @filepath{info.ss}), in case an
   existing compiled file is broken. Furthermore, the
   @racketmodname[info] and @racketmodname[setup/infotab] modules are
   attached to @racket[namespace] from the namespace of
   @racket[get-info/full] before attempting to load
   @filepath{info.rkt} (or @filepath{info.ss}).

   As the module is loaded, the @tech[#:doc reference-doc]{environment variable set}
   is pruned to contain only environment variables that are listed in the
   @envvar{PLT_INFO_ALLOW_VARS} environment variable, which contains a
   @litchar{;}-separated list of names. By default, the list of allowed
   variable names is empty.

   @history[#:changed "6.5.0.2" @elem{Added environment-variable
                                      pruning and @envvar{PLT_INFO_ALLOW_VARS} support.}]}

@defproc[(find-relevant-directories
          (syms (listof symbol?))
          (mode (or/c 'preferred 'all-available 'no-planet 'no-user) 'preferred)) 
         (listof path?)]{

   Returns a list of paths identifying
   collections and installed @|PLaneT| packages whose
   @filepath{info.rkt} file defines one or more of the given
   symbols. The result is based on a cache that is computed by
   @exec{raco setup}.

   Note that the cache may be out of date by the time you call
   @racket[get-info/full], so do not assume that every returned
   directory's @filepath{info.rkt} file will supply one of the
   requested symbols.

   The result is in a canonical order (sorted lexicographically by
   directory name), and the paths it returns are suitable for
   providing to @racket[get-info/full].

   If @racket[mode] is specified, it must be either
   @racket['preferred] (the default), @racket['all-available],
   @racket['no-planet], or @racket['no-user]. If @racket[mode] is
   @racket['all-available], @racket[find-relevant-directories] returns
   all installed directories whose info files contain the specified
   symbols---for instance, all versions of all installed PLaneT
   packages will be searched if @racket['all-available] is
   specified. If @racket[mode] is @racket['preferred], then only a
   subset of ``preferred'' packages will be searched: only the
   directory containing the most recent version of any PLaneT package
   will be returned. If @racket[mode] is @racket['no-planet], then
   PLaneT packages are not included in the search. If @racket[mode] is
   @racket['no-user], then only installation-wide directories are
   searched, which means omitting @|PLaneT| package directories.

   Collection links from the installation-wide @tech[#:doc
   reference-doc]{collection links file} or packages with installation
   scope are cached with the installation's main @filepath{lib}
   directory, and links from the user-specific @tech[#:doc
   reference-doc]{collection links file} and packages are cached with
   the user-specific directory @racket[(build-path (find-system-path
   'addon-dir) "collects")] for all-version cases, and in @racket[(build-path
   (find-system-path 'addon-dir) (version) "collects")] for
   version-specific cases.}

@defproc[(find-relevant-directory-records
          [syms (listof symbol?)]
          [key (or/c 'preferred 'all-available 'no-planet 'no-user)])
         (listof directory-record?)]{
  Like @racket[find-relevant-directories], but returns @racket[directory-record] structs
  instead of @racket[path?]s.
}

@defstruct[directory-record ([maj integer?]
                             [min integer?]
                             [spec any/c]
                             [path path?]
                             [syms (listof symbol?)])]{
  A struct that records information about a collection or a @PLaneT package that has been installed.
  Collections will have the major version being @racket[1] and the minor version being @racket[0].
  The @racket[spec] field is a quoted module spec; the @racket[path] field is where the @tt{info.rkt}
  file for this collection or @PLaneT package exists on the filesystem; the @racket[syms] field holds the
  identifiers defined in that file.
}

@defproc[(reset-relevant-directories-state!) void?]{
   Resets the cache used by @racket[find-relevant-directories].}

@; ------------------------------------------------------------------------

@section[#:tag "relative-paths"]{API for Relative Paths}

The Racket installation tree can usually be moved around the filesystem.
To support this, care must be taken to avoid absolute paths.  The
following two APIs cover two aspects of this: a way to convert a path to
a value that is relative to the @filepath{collects} tree, and a way to
display such paths (e.g., in error messages).

@subsection{Representing Collection-Based Paths}

@defmodule[setup/collects]

@defproc[(path->collects-relative [path path-string?]
                                  [#:cache cache (or/c #f (and/c hash? (not/c immutable?)))])
         (or/c path-string?
               (cons/c 'collects
                       (cons/c bytes? (non-empty-listof bytes?))))]{

Checks whether @racket[path] (normalized by
@racket[path->complete-path] and @racket[simplify-path] with
@racket[#f] as its second argument) matches the result of
@racket[collection-file-path]. If so, the result is a list starting
with @racket['collects] and containing the relevant path elements as
byte strings. If not, the path is returned as-is.

The @racket[cache] argument is used with @racket[path->pkg], if needed.}

@defproc[(collects-relative->path
          [rel (or/c path-string?
                     (cons/c 'collects
                             (cons/c bytes? (non-empty-listof bytes?))))])
         path-string?]{

The inverse of @racket[path->collects-relative]: if @racket[rel]
is a pair that starts with @racket['collects], then it is converted
back to a path using @racket[collection-file-path].}

@defproc[(path->module-path [path path-string?]
                            [#:cache cache (or/c #f (and/c hash? (not/c immutable?)))])
         (or/c path-string? module-path?)]{

Like @racket[path->collects-relative], but the result is either
@racket[path] or a normalized (in the sense of
@racket[collapse-module-path]) module path.}

@subsection{Representing Paths Relative to @filepath{collects}}

@defmodule[setup/main-collects]

@defproc[(path->main-collects-relative [path (or/c bytes? path-string?)])
         (or/c path? (cons/c 'collects (non-empty-listof bytes?)))]{

Checks whether @racket[path] has a prefix that matches the prefix to
the main @filepath{collects} directory as determined by
@racket[(find-collects-dir)]. If so, the result is a list starting
with @racket['collects] and containing the remaining path elements as
byte strings. If not, the path is returned as-is.

The @racket[path] argument should be a complete path. Applying
@racket[simplify-path] before @racket[path->main-collects-relative] is
usually a good idea.

For historical reasons, @racket[path] can be a byte string, which is
converted to a path using @racket[bytes->path].

See also @racket[collects-relative->path].}

@defproc[(main-collects-relative->path
          [rel (or/c bytes?
                     path-string?
                     (cons/c 'collects (non-empty-listof bytes?)))])
         path?]{

The inverse of @racket[path->main-collects-relative]: if @racket[rel]
is a pair that starts with @racket['collects], then it is converted
back to a path relative to @racket[(find-collects-dir)].}

@subsection{Representing Paths Relative to the Documentation}

@defmodule[setup/main-doc]

@defproc[(path->main-doc-relative [path (or/c bytes? path-string?)])
         (or/c path? (cons/c 'doc (non-empty-listof bytes?)))]{
 Like @racket[path->main-collects-relative], except that it checks
 for a prefix relative to @racket[(find-doc-dir)] and returns a list
 starting with @racket['doc] if so.
}

@defproc[(main-doc-relative->path
          [rel (or/c bytes?
                     path-string?
                     (cons/c 'doc (non-empty-listof bytes?)))])
         path>]{

 Like @racket[path->main-collects-relative], except it is the inverse
 of @racket[path->main-doc-relative].
}


@subsection{Displaying Paths Relative to a Common Root}

@defmodule[setup/path-to-relative]

@defproc[(path->relative-string/library
          [path path-string?]
          [default (or/c (-> path-string? any/c) any/c)
                   (lambda (x) (if (path? x) (path->string x) x))]
          [#:cache cache (or/c #f (and/c hash? (not/c immutable?))) #f])
         any/c]{
  Produces a string suitable for display in error messages.  If the path
  is an absolute one that is inside a package, the
  result is a string that begins with @racket["<pkgs>/"]. If the path
  is an absolute one that is inside the @filepath{collects} tree, the
  result is a string that begins with @racket["<collects>/"].
  Similarly, a path in the user-specific collects results in a prefix of
  @racket["<user-collects>/"], a @PLaneT path results in
  @racket["<planet>/"], and a path into documentation results in
  @racket["<doc>/"] or @racket["<user-doc>/"].

  If @racket[cache] is not @racket[#f], it is used as a cache argument
  for @racket[pkg->path] to speed up detection and conversion of
  package paths.

  If the path is not absolute, or if it is not in any of these, it is
  returned as-is (converted to a string if needed).  If @racket[default]
  is given, it specifies the return value instead: it can be a procedure
  that is applied onto the path to get the result, or the result
  itself.

  Note that this function can return a non-string only if
  @racket[default] is given and it does not return a string.
}

@defproc[(path->relative-string/setup
          [path path-string?]
          [default (or/c (-> path-string? any/c) any/c)
                   (lambda (x) (if (path? x) (path->string x) x))]
          [#:cache cache (or/c #f (and/c hash? (not/c immutable?))) #f])
         any/c]{

The same as @racket[path->relative-string/library], for backward
compatibility.}


@defproc[(make-path->relative-string
          [dirs (listof (cons (-> path?) string?))]
          [default (or/c (-> path-string? any/c) any/c)
                   (lambda (x) (if (path? x) (path->string x) x))])
         (path-string? any/c . -> . any)]{
  This function produces functions like
  @racket[path->relative-string/library] and
  @racket[path->relative-string/setup].

  The @racket[dirs] argument determines the prefix substitutions.  It must be an
  association list mapping a path-producing thunk to a prefix string for
  paths in the specified path.

  @racket[default] determines the default for the resulting function
  (which can always be overridden by an additional argument to this
  function).
}

@; ------------------------------------------------------------------------

@section[#:tag "collection-names"]{API for Collection Names}

@defmodule[setup/collection-name]

@defproc[(collection-name? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a string that is syntactically
valid as a collection name, which means that it is one or more
@litchar{/}-separated strings for which
@racket[collection-name-element?] returns true.}


@defproc[(collection-name-element? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a string that is syntactically
valid as a top-level collection name or as a part of a collection
name, which means that it is non-empty and contains only ASCII
letters, ASCII digits, @litchar{-}, @litchar{+}, @litchar{_}, and
@litchar{%}, where a @litchar{%} is allowed only when followed by two
lowercase hexadecimal digits, and the digits must form a number that
is not the ASCII value of a letter, digit, @litchar{-}, @litchar{+},
or @litchar{_}.}


@; ------------------------------------------------------------------------

@section[#:tag "collection-search"]{API for Collection Searches}

@defmodule[setup/collection-search]

@history[#:added "6.3"]

@defproc[(collection-search [mod-path normalized-lib-module-path?]
                            [#:init result any/c #f]
                            [#:combine combine (any/c (and/c path? complete-path?) . -> . any/c) (lambda (r v) v)]
                            [#:break? break? (any/c . -> . any/c) (lambda (r) #f)]
                            [#:all-possible-roots? all-possible-roots? any/c #f])
         any/c]{

Generalizes @racket[collection-file-path] to support folding over all
possible locations of a collection-based file in the current
configuration. Unlike @racket[collection-file-path],
@racket[collection-search] takes the file to location in module-path
form, but always as a @racket['lib] path.

Each possible path for the file (not counting a @filepath{.ss} to/from
@filepath{.rkt} conversion) is provided as a second argument to the
@racket[combine] function, where the first argument is the current
result, and the value produced by @racket[combine] becomes the new
result. The @racket[#:init] argument provides the initial result.

The @racket[break?] function short-circuits a search based on the
current value. For example, it could be used to short-circuit a search
after a suitable path is found.

If @racket[all-possible-roots?] is @racket[#f], then @racket[combine]
is called only on paths within @filepath{collects}-like directories
(for the current configuration) where at least a matching collection
directory exists.}


@defproc[(normalized-lib-module-path? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a module path (in the sense of
@racket[module-path?]) of the form @racket['(lib _str)] where
@racket[_str] contains at least one slash. The
@racket[collapse-module-path] function produces such module paths for
collection-based module references.}

@; ------------------------------------------------------------------------

@section[#:tag "matching-platform"]{API for Platform Specifications}

@defmodule[setup/matching-platform]

@history[#:added "6.0.1.13"]

@defproc[(platform-spec? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a symbol, string, or regexp value
(in the sense of @racket[regexp?]), @racket[#f] otherwise.}

@defproc[(matching-platform? [spec platform-spec?]
                             [#:cross? cross? any/c #f]
                             [#:system-type sys-type (or/c #f symbol?) (if cross?
                                                                           (cross-system-type)
                                                                           (system-type))]
                             [#:system-library-subpath sys-lib-subpath (or/c #f path-for-some-system?)
                                                       (if cross?
                                                           (cross-system-library-subpath #f)
                                                           (system-library-subpath #f))])
         boolean?]{

Reports whether @racket[spec] matches @racket[sys-type] or
@racket[sys-lib-subpath], where @racket[#f] values for the latter are
replaced with the default values.

If @racket[spec] is a symbol, then the result is @racket[#t] if
@racket[sys-type] is the same symbol, @racket[#f] otherwise.

If @racket[spec] is a string, then the result is @racket[#t] if
@racket[(path->string sys-lib-subpath)] is the same string,
@racket[#f] otherwise.

If @racket[spec] is a regexp value, then the result is @racket[#t] if
the regexp matches @racket[(path->string sys-lib-subpath)],
@racket[#f] otherwise.

@history[#:changed "6.3" @elem{Added @racket[#:cross?] argument and
                                      changed the contract on @racket[sys-lib-subpath]
                                      to accept @racket[path-for-some-system?]
                                      instead of just @racket[path?].}]}

@; ------------------------------------------------------------------------

@section[#:tag "cross-system"]{API for Cross-Platform Configuration}

See @other-doc[#:indirect @exec{raco cross} '(lib
"raco/private/cross/raco-cross.scrbl")] for information about
@exec{raco cross}, a tool that is provided by the
@filepath{raco-cross} package as a convenient interface to
cross-compilation for Racket. The underlying API documented here
supports @exec{raco cross} and other tools.

@defmodule[setup/cross-system]{The @racketmodname[setup/cross-system]
library provides functions for querying the system properties of a
destination platform, which can be different than the current platform
in cross-installation modes.}

A Racket installation includes a @filepath{system.rktd} file in the
directory reported by @racket[(find-lib-dir)]. When the information in that file
does not match the running Racket's information, then the
@racketmodname[setup/cross-system] module infers that Racket is being
run in cross-installation mode.

For example, if an in-place Racket @BC
installation for a different platform resides at @nonterm{cross-dir},
then running Racket BC as

@commandline{racket -C -G @nonterm{cross-dir}/etc -X @nonterm{cross-dir}/collects -l- raco pkg}

runs @exec{raco pkg} using the current platform's @exec{racket}
executable, but using the collections and other configuration
information of @nonterm{cross-dir}, as well as modifying the packages
of @nonterm{cross-dir}. That can work as long as no platform-specific
libraries need to run to perform the requested @exec{raco pkg} action
(e.g., when installing built packages), or as long as the current
platform's installation already includes those libraries.

For Racket @CS, cross compilation is more
complicated, because Racket CS @filepath{.zo} files are
platform-specific:

@itemlist[

 @item{A target installation @nonterm{cross-dir} is needed that
       includes cross-compilation support for the host platform as
       plug-in within the installation's
       @filepath{@nonterm{cross-dir}/lib} directory. That installation
       might be created by compiling from source on the host platform.
       Only Racket CS can use a CS cross-compilation plug-in.

       When running @exec{racket} in cross mode, use the
       @DFlag{cross-compiler} flag to specify the target machine and
       path to the @filepath{@nonterm{cross-dir}/lib} directory.}

 @item{A flag combination @Flag{MCR} with argument
       @filepath{@nonterm{absolute-zo-dir}:} is needed to enable
       @filepath{.zo} file creation for both the host platform (which
       uses the directory before a @litchar{:}) and the target
       platform (which uses the normal compiled-file subdirectory when
       the path after the @litchar{:} is empty).

       The @nonterm{absolute-zo-dir} can be any absolute path. It
       generally should be populated by running @exec{raco setup} in
       cross mode before commands like @exec{raco pkg}.}

]

For example, the @exec{raco pkg} example for Racket CS is

@verbatim[#:indent 2]{
  racket --cross-compiler @nonterm{target-machine} @nonterm{cross-dir}/lib \
    -MCR @nonterm{absolute-zo-dir}: \
    -G @nonterm{cross-dir}/etc -X @nonterm{cross-dir}/collects -l- raco pkg
}

The @nonterm{target-machine} provided to @DFlag{cross-compiler} should
be the same as the @racketidfont{target-machine} entry in
@filepath{@nonterm{cross-dir}/lib/systemd.rktd}.

The @Flag{C} flag is shorthand for @DFlag{cross}, @Flag{M} is short
for @DFlag{compile-any}, @Flag{R} is short for @DFlag{compiled},
@Flag{G} is short for @DFlag{config}, @Flag{X} is short for
@DFlag{collects}, and @Flag{MCR} is short for @exec{@Flag{M} @Flag{C}
@Flag{R}}.

@history[#:added "6.3"]

@defproc[(cross-system-type [mode (or/c 'os 'word 'gc 'vm 'link 'machine
                                        'so-suffix 'so-mode 'fs-change)
                            'os])
         (or/c symbol? string? bytes? exact-positive-integer? vector?)]{

Like @racket[system-type], but for the target platform instead of the
current platform in cross-installation mode. When not in
cross-installation mode, the results are the same as for
@racket[system-type].

See also @racket['cross] mode for @racket[system-type].}


@defproc[(cross-system-library-subpath [mode (or/c 'cgc '3m 'cs #f)
                                             (system-type 'gc)])
         path-for-some-system?]{

Like @racket[system-library-subpath], but for the target platform
instead of the current platform in cross-installation mode. When not
in cross-installation mode, the results are the same as for
@racket[system-library-subpath].

In cross-installation mode, the target platform may have a different
path convention than the current platform, so the result is
@racket[path-for-some-system?] instead of @racket[path?].}


@defproc[(cross-installation?) boolean?]{

Returns @racket[#t] if cross-installation mode has been detected,
@racket[#f] otherwise.}


@; ------------------------------------------------------------------------

@section[#:tag "xref"]{API for Cross-References for Installed Manuals}

@defmodule[setup/xref]

@defproc[(load-collections-xref [on-load (-> any/c) (lambda () (void))])
         xref?]{

Either creates and caches or returns a cached cross-reference record
created with @racket[make-collections-xref]. The @racket[on-load]
function is called only when a previously cached record is not
returned.}


@defproc[(make-collections-xref [#:no-user? no-user? any/c #f]
                                [#:no-main? no-main? any/c #f]
                                [#:doc-db db-path (or/c #f path?) #f]
                                [#:quiet-fail? quiet-fail? any/c #f]
                                [#:register-shutdown! register-shutdown! ((-> any) . -> . any) void])
         xref?]{

Like @racket[load-xref], but automatically finds all cross-reference
files for manuals that have been installed with @exec{raco setup}.
The resulting cross-reference record takes advantage of a
cross-reference database @racket[db-path], when support is available,
to delay the loading of cross-reference details until needed.

Cross-reference information is skipped when it is installed in the
main installation or in a user-specific location, respectively, if
@racket[no-main?] or @racket[no-user?] is @racket[#t].

If @racket[quiet-fail?] is true, then errors are suppressed while
loading cross-reference information.

The @racket[register-shutdown!] callback may be called to register a
function that closes database connections when the result of
@racket[make-collections-xref] is no longer needed. If
@racket[register-shutdown!] is not supplied or if a function sent to
@racket[register-shutdown!] is never called, database connections will
be closed only though a @tech[#:doc reference-doc]{custodian}.}


@defproc[(get-rendered-doc-directories [no-user? any/c]
                                       [no-main? any/c])
         (listof path?)]{

Returns a list of directories for all documentation for all installed
collections, omitting documentation that is installed in the main
installation or in a user-specific location, respectively, if
@racket[no-main?] or @racket[no-user?] is @racket[#t].}


@defproc[(get-current-doc-state) doc-state?]{
 Records the time stamps of files that are touched whenever the
 documentation is changed.
 
 @history[#:added "1.2"]
}

@defproc[(doc-state-changed? [doc-state doc-state?]) boolean?]{
 Returns @racket[#t] when the time stamps of the files in
 @racket[doc-state] changed (or new files appeared) and @racket[#f] otherwise.

 If the result is @racket[#t], then the documentation in this installation of
 Racket has changed and otherwise it hasn't.

 @history[#:added "1.2"]
}
@defproc[(doc-state? [v any/c]) boolean?]{
 A predicate to recognize the result of @racket[get-current-doc-state].
 
 @history[#:added "1.2"]
}

@; ------------------------------------------------------------------------

@section[#:tag "materialize-user-docs"]{API for Materializing User-Specific Documentation}

@defmodule[setup/materialize-user-docs]

@history[#:added "1.1"]

@defproc[(materialize-user-docs [on-setup ((-> boolean?) -> any) (lambda (setup) (setup))]
                                [#:skip-user-doc-check? skip-user-doc-check? any/c #f])
         void?]{

Checks whether a user-specific documentation entry point already
exists in @racket[(find-user-doc-dir)], and if not, runs @exec{raco
setup} in a mode that will create the entry point (to have the same
content as the installation's documentation entry point.) If
@racket[skip-user-doc-check?] is not @racket[#f], then skips the
check for the user-specific documentation entry point.

The run of @exec{raco setup} is packaged in a thunk that is provided to
@racket[on-setup], which can adjust the current output and error ports
as appropriate and check the thunk's result for success.

The @racket[on-setup] argument is not called if the documentation entry
point already exists in @racket[(find-user-doc-dir)].

@history[#:changed "1.1" @list{Added the @racket[skip-user-doc-check?] argument.}]
}

@; ------------------------------------------------------------------------

@section[#:tag "layered-install"]{Layered Installations}

A typical Racket configuration includes two layers: an
@defterm{installation} layer and a @defterm{user} layer. The intent is
that the @defterm{installation} layer is read-only to all users of a
system, while the @defterm{user} layer allows each individual user to
install additional packages that extend the @defterm{installation}
layer. The @defterm{installation} layer is intended not only to be
read-only, but to not change after users start installing in their own
layers.

In an environment where Racket itself is under development, the
@defterm{installation} layer will change. In that setting, if the
@defterm{user} layer is used at all, care must be taken to not create
conflicts for the user layer when modifying the installation
layer---or else the user layer must be repaired on occasion.

By default, @exec{raco setup} updates both layers whenever it is run;
if a user does not have write permission the installation, @exec{raco
setup} with no arguments is all but certain to report permission
errors. The actions of @exec{raco setup} can be constrained to the
@defterm{user} layer by supplying the @DFlag{avoid-main} argument, or
@exec{raco setup} can be constrained to the @defterm{installation}
layer by using the @DFlag{no-user} argument. When @exec{raco pkg}
performs setup actions, it effectively supplies one of the other of
those based on the package's scope (and @exec{raco pkg} refuses to
operate on both scopes/layers at once).

The @defterm{user} layer is always both user- and version-specific.
More precisely, it is specific to the user and an installation's name,
where the installation's name is typically its version number.
However, the name of an installation can be changed through the
@racket['installation] setting in @filepath{config.rktd} (see
@secref["config-file"]). Setting an installation name changes the
directory where packages and executables reside within
@racket[(find-system-path 'addon-dir)]. The result of
@racket[(find-system-path 'addon-dir)] itself can be changed through
@racket['addon-dir] in @filepath{config.rktd}.

The @defterm{installation} and @defterm{user} configuration layers can
be generalized to multiple layers by setting search paths in
@filepath{config.rktd}. These search paths essentially treat the layer
closest to @defterm{user} as the @defterm{installation} layer that
might be adjusted by @exec{raco setup} and @exec{raco pkg}, but search
paths can chain to an existing (unchanging) implementation in much the
same way that @defterm{user} chains to @defterm{installation}. To
build a new layer, create new @filepath{config.rktd} that is like the
underlying layer's @filepath{config.rktd}, but
@;
@itemlist[

 @item{each of @racket['lib-dir], @racket['share-dir],
       @racket['links-file], @racket['pkgs-dir], @racket['bin-dir],
       @racket['gui-bin-dir], @racket['apps-dir], @racket['doc-dir],
       and @racket['man-dir] is a new directory or file; and}

 @item{the corresponding search lists @racket['lib-search-dirs],
       @racket['share-search-dirs], @racket['links-search-files],
       @racket['pkgs-search-dirs], @racket['bin-search-dirs],
       @racket['gui-bin-search-dirs], (no @racket['apps-dir] search
       needed), @racket['doc-search-dirs], and
       @racket['man-search-dirs] each add the old directory or file to
       the search list just after @racket[#f]; note that the default
       for each search list is @racket[(list #f)].}

]
@;
There is no argument to @exec{raco setup} that is analogous to
@DFlag{avoid-main} to avoid modifying nested layer; instead, nested
layers are expected to be fully set up so that @exec{raco setup}
need not change them. When @exec{raco setup} would otherwise install
an executable into the directory configured as @racket['bin-dir], it
consults the @racket['bin-search-dirs] list to check whether the
executable is already installed in one of those directories, and if so,
it will refrain from creating a copy in the new layer. The same
search-list check also applies to native libraries, shared files, and
man pages, but with the additional check that the file to install matches
the one that is already installed.

The default path to @filepath{config.rktd} is hardwired within a
@exec{racket} executable. In some cases, it can make sense for the
innermost layer's configuration to point to another layer, perhaps
because the filesystem provides an indirection. For example, on Unix,
a Racket installation in @filepath{/usr} might reasonably configure
the @defterm{installation} layer's directories to be in
@filepath{/usr/local} with @filepath{/usr} directories included in the
search lists.

To use @exec{racket} with a new @filepath{config.rktd}, you can supply
the @DFlag{config} or @DFlag{G} flag to @exec{racket} or set the
@envvar{PLTCONFIGDIR} environment variable to point to the directory
containing @filepath{config.rktd}. Alternatively, you can create a
@tech{tethered} layer that creates replacement executables like
@exec{racket} that are hardwired to the layer's configuration
directory.

@; ------------------------------------------------------------------------

@section[#:tag "tethered-install"]{Tethered Installations}

A @deftech{tethered} installation of Racket is a layer (see
@secref["layered-install"]) that includes a wrapper executable for
every executable across the installation's layers. Each wrapper
executable points back to the new layer's @filepath{config.rktd} (see
@secref["config-file"]) without the use of a @envvar{PLTCONFIGDIR}
environment variable or @DFlag{config} flag. In other words, a
tethered installation provides executables such as @exec{racket},
@exec{raco}, and @exec{drracket} that are tied to the layer. Tethering
thus helps to create a layer of installation that behaves in a more
self-contained way, but with minimal duplication of the underlying
layers.

Tethering works at either a @defterm{user} or @defterm{installation}
layer:

@itemlist[

 @item{A @defterm{user} layer with tethering is represented by a fresh
       directory @nonterm{addon-dir} and a
       @filepath{@nonterm{addon-dir}/etc/config.rktd} file that maps
       @racket['addon-tethered-console-bin-dir] to
       @nonterm{tethered-bin-dir},
       @racket['addon-tethered-gui-bin-dir] to
       @nonterm{tethered-gui-bin-dir}, and (optionally)
       @racket['addon-tethered-apps-dir] to
       @nonterm{tethered-apps-dir}. Initialize the tethered layer
       with

       @commandline{racket -A @nonterm{addon-dir} -l- raco setup --avoid-main}}

 @item{An @defterm{installation} layer with tethering is like a one
       without tethering (see @secref["layered-install"]), but where
       the layer's @filepath{@nonterm{layer-dir}/etc/config.rktd} file
       maps @racket['config-tethered-console-bin-dir] to
       @nonterm{tethered-bin-dir},
       @racket['config-tethered-gui-bin-dir] to
       @nonterm{tethered-gui-bin-dir}, and (optionally)
       @racket['config-tethered-apps-dir] to
       @nonterm{tethered-apps-dir}. The @racket['bin-dir] and
       @racket['gui-bin-dir] configurations can point to the same
       directories, but executables are not specifically created there by
       @exec{raco setup}. Initialize the tethered layer with

       @commandline{racket -G @nonterm{layer-dir}/etc -l- raco setup}}

]

In either case, initialization creates tethered executables in the
directories @nonterm{tethered-bin-dir} and
@nonterm{tethered-gui-bin-dir}, writing @filepath{.desktop} files
(for Unix) in @nonterm{tethered-apps-dir} (if specified). Thereafter, tethered executables like
@exec{@nonterm{tethered-bin-dir}/racket} and
@exec{@nonterm{tethered-bin-dir}/raco} can be used to work with the
tethered layer.
