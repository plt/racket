#lang scribble/doc
@(require "mz.rkt" (for-label racket/system))

@(define microsoft-argument-doc-src
  @hyperlink["https://github.com/MicrosoftDocs/cpp-docs/blob/e5bdbb71e7b09a58e70ca8758caec68bb9a6cc9c/docs/c-language/parsing-c-command-line-arguments.md"
             "Microsoft's documentation source"])

@title[#:tag "subprocess"]{Processes}

@defproc*[([(subprocess [stdout (or/c (and/c output-port? file-stream-port?) #f)]
                        [stdin (or/c (and/c input-port? file-stream-port?) #f)]
                        [stderr (or/c (and/c output-port? file-stream-port?) #f 'stdout)]
                        [group (or/c #f 'new subprocess) (and (subprocess-group-enabled) 'new)]
                        [command path-string?]
                        [arg (or/c path? string-no-nuls? bytes-no-nuls?)] ...)
            (values subprocess?
                    (or/c (and/c input-port? file-stream-port?) #f)
                    (or/c (and/c output-port? file-stream-port?) #f)
                    (or/c (and/c input-port? file-stream-port?) #f))]
           [(subprocess [stdout (or/c (and/c output-port? file-stream-port?) #f)]
                        [stdin (or/c (and/c input-port? file-stream-port?) #f)]
                        [stderr (or/c (and/c output-port? file-stream-port?) #f)]
                        [group (or/c #f 'new subprocess) (and (subprocess-group-enabled) 'new)]
                        [command path-string?]
                        [exact 'exact]
                        [arg string?])
            (values subprocess?
                    (or/c (and/c input-port? file-stream-port?) #f)
                    (or/c (and/c output-port? file-stream-port?) #f)
                    (or/c (and/c input-port? file-stream-port?) #f))])]{

Creates a new process in the underlying operating system to execute
@racket[command] asynchronously, providing the new process with
environment variables @racket[current-environment-variables]. See also
@racket[system] and @racket[process] from
@racketmodname[racket/system].

@margin-note{On Unix and Mac OS, subprocess creation is separate
from starting the program indicated by @racket[command]. In
particular, if @racket[command] refers to a non-existent or
non-executable file, an error will be reported (via standard error and
a non-0 exit code) in the subprocess, not in the creating
process.}

The @racket[command] argument is a path to a program executable, and
the @racket[arg]s are command-line arguments for the program. See
@racket[find-executable-path] for locating an executable based on
the @envvar{PATH} environment variable. On
Unix and Mac OS, command-line arguments are passed as byte strings,
and string @racket[arg]s are converted using the current locale's
encoding (see @secref["encodings"]). On Windows, command-line
arguments are passed as strings, and byte strings are converted using
UTF-8.

On Windows, a process natively receives a single command-line argument
string, unlike Unix and Mac OS processes that natively receive an
array of arguments. A Windows command-line string is constructed from
@racket[command] and @racket[arg]s following a Windows convention so
that a typical application can parse it back to an array of arguments,
@margin-note*{For information on the Windows command-line conventions,
see @microsoft-argument-doc-src or search for ``command line parsing'' at
@tt{http://msdn.microsoft.com/}.} but beware that an application may
parse the command line in a different way. In particular, @emph{take
special care when supplying a @racket[command] that refers to a
@filepath{.bat} or @filepath{.cmd} file}, because the command-line
string delivered to the process will be parsed as a @exec{cmd.exe}
command, which is effectively a different syntax than the convention
that @racket[subprocess] uses to encode command-line arguments;
supplying unsanitized @racket[arg]s could enable parsing of arguments
as commands. To enable more control over the command-line string that
is delivered to a process, the first @racket[arg] can be replaced with
@indexed-racket['exact], which triggers a Windows-specific behavior:
the sole @racket[arg] is used exactly as the command-line for the
subprocess. If @racket['exact] is provided on a non-Windows platform,
the @exnraise[exn:fail:contract].

When provided as a port, @racket[stdout] is used for the launched
process's standard output, @racket[stdin] is used for the process's
standard input, and @racket[stderr] is used for the process's standard
error.  All provided ports must be file-stream ports. Any of the ports
can be @racket[#f], in which case a system pipe is created and
returned by @racket[subprocess]. The @racket[stderr] argument can be 
@racket['stdout], in which case the same file-stream port or system pipe
that is supplied as standard output is also used for standard error.
For each port or @racket['stdout] that is provided, no
pipe is created and the corresponding returned value is @racket[#f].
If @racket[stdout] or @racket[stderr] is a port for which
@racket[port-waiting-peer?] returns true, then @racket[subprocess]
waits for the port to become ready for writing before proceeding with
the subprocess creation.

If @racket[group] is @racket['new], then the new process is created as
a new OS-level process group. In that case, @racket[subprocess-kill]
attempts to terminate all processes within the group, which may
include additional processes created by the subprocess.
@margin-note*{Beware that creating a group may interfere with the job
control in an interactive shell, since job control is based on process
groups.} See @racket[subprocess-kill] for details. If @racket[group]
is a subprocess, then that subprocess must have been created with
@racket['new], and the new subprocess will be added to the group;
adding to the group will succeed only on Unix and Mac OS, and only in
the same cases that @racket[subprocess-kill] would have an effect
(i.e., the subprocess is not known to have terminated), otherwise it
will fail silently.

The @racket[subprocess] procedure returns four values:

@itemize[

 @item{a @deftech{subprocess} value representing the created process;}

 @item{an input port piped from the process's standard output, or
 @racket[#f] if @racket[stdout] was a port;}

 @item{an output port piped to the process's standard input, or
 @racket[#f] if @racket[stdin] was a port;}

 @item{an input port piped from the process's standard error, or
 @racket[#f] if @racket[stderr] was a port or @racket['stdout].}

]

@bold{Important:} All ports returned from @racket[subprocess] must be
explicitly closed, usually with @racket[close-input-port] or
@racket[close-output-port].

@margin-note{A @tech{file-stream port} for communicating with a
subprocess is normally a pipe with a limited buffer capacity. Beware of
creating deadlock by serializing a write to a subprocess followed by a
read, while the subprocess does the same, so that both processes end
up blocking on a write because the other end must first read to make
room in the pipe. Beware also of waiting for a subprocess to finish
without reading its output, because the subprocess may be blocked attempting
to write output into a full pipe.}

The returned ports are @tech{file-stream ports} (see
@secref["file-ports"]), and they are placed into the management of
the current custodian (see @secref["custodians"]).  The
@exnraise[exn:fail] when a low-level error prevents the spawning of a
process or the creation of operating system pipes for process
communication.

The @racket[current-subprocess-custodian-mode] parameter determines
whether the subprocess itself is registered with the current
@tech{custodian} so that a custodian shutdown calls
@racket[subprocess-kill] for the subprocess.

The @racket[current-subprocess-keep-file-descriptors] parameter
determines how file descriptors and handles in the current process are
shared with the subprocess. File descriptors (on Unix and Mac OS) or
handles (on Windows) represented by @racket[stdin], @racket[stdout],
and @racket[stderr] are always shared with the subprocess. File
descriptors and handles that are replaced by newly created pipes (when
the corresponding @racket[stdin], @racket[stdout], and @racket[stderr]
argument is @racket[#f]) are not shared. Sharing for other file
descriptors and handles depends on the parameter value:
@;
@itemlist[

 @item{@racket['inherited] (the default) --- other handles that are
   inherited on Windows are shared with the subprocess; file
   descriptors that lack the @tt{FD_CLOEXEC} flag on Unix and Mac OS
   variants that support the flag are also shared; and no other file
   descriptors are shared on variants of Unix and Mac OS that do not
   support @tt{FD_CLOEXEC}.}

 @item{@racket['all] --- like @racket['inherited], except on
   variants of Unix and Mac OS that do not support @tt{FD_CLOEXEC}, in
   which case all file descriptors are shared.}

 @item{@racket['()] --- no additional file descriptors are shared, not
   even ones that are inherited on Windows or lacking the
   @tt{FD_CLOEXEC} flag.}

]

A subprocess can be used as a @tech{synchronizable event} (see @secref["sync"]).
A subprocess value is @tech{ready for synchronization} when
@racket[subprocess-wait] would not block; @resultItself{subprocess value}.

Example:

@racketblock[
(define-values (sp out in err)
  (subprocess #f #f #f "/bin/ls" "-l"))
(printf "stdout:\n~a" (port->string out))
(printf "stderr:\n~a" (port->string err))
(close-input-port out)
(close-output-port in)
(close-input-port err)
(subprocess-wait sp)
]

@; PLACEHOLDER: maybe explain here that subprocess-wait should be called
@; after all the I/O to ensure the process is in a position to terminate?

@history[#:changed "6.11.0.1" @elem{Added the @racket[group] argument.}
         #:changed "7.4.0.5" @elem{Added waiting for a fifo without a reader
                                   as @racket[stdout] and/or @racket[stderr].}
         #:changed "8.3.0.4" @elem{Added @racket[current-subprocess-custodian-mode] support.}
         #:changed "8.11.1.6" @elem{Changed the treatment of file-descriptor sharing
                                    on variants of Unix and Mac OS that support
                                    @tt{FD_CLOEXEC}.}]}


@defproc[(subprocess-wait [subproc subprocess?]) void?]{

Blocks until the process represented by @racket[subproc]
terminates. The @racket[subproc] value also can be used with
@racket[sync] and @racket[sync/timeout].}


@defproc[(subprocess-status [subproc subprocess?]) 
         (or/c 'running
               exact-nonnegative-integer?)]{

Returns @indexed-racket['running] if the process represented by
@racket[subproc] is still running, or its exit code otherwise. The
exit code is an exact integer, and @racket[0] typically indicates
success. If the process terminated due to a fault or signal, the exit
code is non-zero.}


@defproc[(subprocess-kill [subproc subprocess?] [force? any/c]) void?]{

Terminates the subprocess represented by @racket[subproc]. The precise
action depends on whether @racket[force?] is true, whether the process
was created in its own group by setting the
@racket[subprocess-group-enabled] parameter to a true value, and the
current platform:

@itemlist[

 @item{@racket[force?] is true, not a group, all platforms: Terminates
       the process if the process still running.}

 @item{@racket[force?] is false, not a group, on Unix or Mac OS:
       Sends the process an interrupt signal instead of a kill
       signal.}

 @item{@racket[force?] is false, not a group, on Windows: No action
       is taken.}

 @item{@racket[force?] is true, a group, on Unix or Mac OS:
       Terminates all processes in the group, but only if
       @racket[subprocess-status] has never produced a
       non-@racket['running] result for the subprocess and only if
       functions like @racket[subprocess-wait] and @racket[sync] have
       not detected the subprocess's completion. Otherwise, no action
       is taken (because the immediate process is known to have
       terminated while the continued existence of the group is
       unknown).}

 @item{@racket[force?] is true, a group, on Windows: Terminates
       the process if the process still running.}

 @item{@racket[force?] is false, a group, on Unix or Mac OS: The
       same as when @racket[force?] is @racket[#t], but when the group
       is sent a signal, it is an interrupt signal instead of a kill
       signal.}

 @item{@racket[force?] is false, a group, on Windows: All processes
       in the group receive a CTRL-BREAK signal (independent of
       whether the immediate subprocess has terminated).}

]

If an error occurs during termination, the @exnraise[exn:fail].}


@defproc[(subprocess-pid [subproc subprocess?]) exact-nonnegative-integer?]{

Returns the operating system's numerical ID (if any) for the process
represented by @racket[subproc]. The result is valid only as long as
the process is running.}


@defproc[(subprocess? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a subprocess value, @racket[#f]
otherwise.}


@defparam[current-subprocess-custodian-mode mode (or/c #f 'kill 'interrupt)]{

A @tech{parameter} that determines whether a subprocess (as created by
@racket[subprocess] or wrappers like @racket[process]) is registered
with the current @tech{custodian}. If the parameter value is
@racket[#f], then the subprocess is not registered with the
custodian---although any created ports are registered. If the
parameter value is @racket['kill] or @racket['interrupt], then the
subprocess is shut down through @racket[subprocess-kill], where
@racket['kill] supplies a @racket[#t] value for the @racket[_force?]
argument and @racket['interrupt] supplies a @racket[#f] value. The
shutdown may occur either before or after ports created for the
subprocess are closed.

Custodian-triggered shutdown is limited by details of process handling
in the host system. For example, @racket[process] and @racket[system]
may create an intermediate shell process to run a program, in which
case custodian-based termination shuts down the shell process and
probably not the process started by the shell. See also
@racket[subprocess-kill]. Process groups (see
@racket[subprocess-group-enabled]) can address some limitations, but
not all of them.}


@defboolparam[subprocess-group-enabled on?]{

A @tech{parameter} that determines whether a subprocess is created as
a new process group by default. See @racket[subprocess] and
@racket[subprocess-kill] for more information.}


@defparam[current-subprocess-keep-file-descriptors keeps (or/c 'inherited 'all '())]{

A @tech{parameter} that determines how file descriptors (on Unix and
Mac OS) and handles (on Windows) are shared in a subprocess as created
by @racket[subprocess] or wrappers like @racket[process]. See
@racket[subprocess] for more information.

@history[#:added "8.3.0.4"]}


@defproc[(shell-execute [verb (or/c string? #f)]
                        [target string?]
                        [parameters string?]
                        [dir path-string?]
                        [show-mode symbol?])
         #f]{

@index['("ShellExecute")]{Performs} the action specified by @racket[verb]
on @racket[target] in Windows. For platforms other than Windows, the
@exnraise[exn:fail:unsupported].

For example,

@racketblock[
(shell-execute #f "http://racket-lang.org" ""
               (current-directory) 'sw_shownormal)
]

Opens the Racket home page in a browser window.

The @racket[verb] can be @racket[#f], in which case the operating
system will use a default verb. Common verbs include @racket["open"],
@racket["edit"], @racket["find"], @racket["explore"], and
@racket["print"].

The @racket[target] is the target for the action, usually a filename
path. The file could be executable, or it could be a file with a
recognized extension that can be handled by an installed application.

The @racket[parameters] argument is passed on to the system to perform
the action. For example, in the case of opening an executable, the
@racket[parameters] is used as the command line (after the executable
name).

The @racket[dir] is used as the current directory when performing the
action.

The @racket[show-mode] sets the display mode for a Window affected by
the action. It must be one of the following symbols; the description
of each symbol's meaning is taken from the Windows API documentation.

@itemize[

 @item{@indexed-racket['sw_hide] or @indexed-racket['SW_HIDE] ---
 Hides the window and activates another window.}

 @item{@indexed-racket['sw_maximize] or @indexed-racket['SW_MAXIMIZE]
 --- Maximizes the window.}

 @item{@indexed-racket['sw_minimize] or @indexed-racket['SW_MINIMIZE]
 --- Minimizes the window and activates the next top-level window in
 the z-order.}

 @item{@indexed-racket['sw_restore] or @indexed-racket['SW_RESTORE]
 --- Activates and displays the window. If the window is minimized or
 maximized, Windows restores it to its original size and position.}

 @item{@indexed-racket['sw_show] or @indexed-racket['SW_SHOW] ---
 Activates the window and displays it in its current size and
 position.}

 @item{@indexed-racket['sw_showdefault] or
 @indexed-racket['SW_SHOWDEFAULT] --- Uses a default.}

 @item{@indexed-racket['sw_showmaximized] or
 @indexed-racket['SW_SHOWMAXIMIZED] --- Activates the window and
 displays it as a maximized window.}

 @item{@indexed-racket['sw_showminimized] or
 @indexed-racket['SW_SHOWMINIMIZED] --- Activates the window and
 displays it as a minimized window.}

 @item{@indexed-racket['sw_showminnoactive] or
 @indexed-racket['SW_SHOWMINNOACTIVE] --- Displays the window as a
 minimized window. The active window remains active.}

 @item{@indexed-racket['sw_showna] or @indexed-racket['SW_SHOWNA] ---
 Displays the window in its current state. The active window remains
 active.}

 @item{@indexed-racket['sw_shownoactivate] or
 @indexed-racket['SW_SHOWNOACTIVATE] --- Displays a window in its most
 recent size and position. The active window remains active.}

 @item{@indexed-racket['sw_shownormal] or
 @indexed-racket['SW_SHOWNORMAL] --- Activates and displays a
 window. If the window is minimized or maximized, Windows restores it
 to its original size and position.}

 ]

If the action fails, the @exnraise[exn:fail]. If the action succeeds,
the result is @racket[#f].

In future versions of Racket, the result may be a subprocess value if
the operating system did returns a process handle (but if a subprocess
value is returned, its process ID will be @racket[0] instead of the
real process ID).}

@; ----------------------------------------------------------------------

@section{Simple Subprocesses}

@note-lib[racket/system]

@defproc[(system [command (or/c string-no-nuls? bytes-no-nuls?)]
                 [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
         boolean?]{

Executes a shell command synchronously (i.e., the call to
@racket[system] does not return until the subprocess has ended). On
Unix and Mac OS, @exec{/bin/sh} is used as the shell, while
@exec{cmd.exe} or @exec{command.com} (if @exec{cmd.exe} is not found)
is used on Windows. The @racket[command] argument is a string or
byte string containing no nul characters. If the command succeeds, the
return value is @racket[#t], @racket[#f] otherwise.

@margin-note{See also @racket[subprocess] for notes about error
handling and the limited buffer capacity of subprocess pipes.}

If @racket[set-pwd?] is true, then the @envvar{PWD} environment
variable is set to the value of @racket[(current-directory)] when
starting the shell process.

See also @racket[current-subprocess-custodian-mode] and
@racket[subprocess-group-enabled], which affect the subprocess used to
implement @racket[system].

The resulting process writes to @racket[(current-output-port)], reads
from @racket[(current-input-port)], and logs errors to
@racket[(current-error-port)]. To gather the process's non-error
output to a string, for example, use @racket[with-output-to-string],
which sets @racket[current-output-port] while calling the given
function:

@racketblock[
(with-output-to-string (lambda () (system "date")))
]}

@; PLACEHOLDER: add something explaining why system* is recommended instead
@; (sorawee)

@defproc*[([(system* [command path-string?]
                     [arg (or/c path? string-no-nuls? bytes-no-nuls?)] ...
                     [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
            boolean?]
           [(system* [command path-string?] [exact 'exact] [arg string?]
                     [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
            boolean?])]{

Like @racket[system], except that @racket[command] is a filename that
is executed directly (instead of through a shell command; see
@racket[find-executable-path] for locating an executable based on
the @envvar{PATH} environment variable), and the
@racket[arg]s are the arguments. The executed file is passed the
specified string arguments (which must contain no nul
characters).

On Windows, the first argument after @racket[command] can be
@racket['exact], and the final @racket[arg] is a complete command
line. See @racket[subprocess] for details and for a specific warning
about using a @racket[command] that refers to a @filepath{.bat} or
@filepath{.cmd} file.}


@defproc[(system/exit-code [command (or/c string-no-nuls? bytes-no-nuls?)]
                           [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
         byte?]{

Like @racket[system], except that the result is the exit code returned
by the subprocess. A @racket[0] result normally indicates success.}


@defproc*[([(system*/exit-code [command path-string?]
                               [arg (or/c path? string-no-nuls? bytes-no-nuls?)] ...
                               [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
            byte?]
           [(system*/exit-code [command path-string?]
                               [exact 'exact] [arg string?]
                               [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
            byte?])]{

Like @racket[system*], but returns the exit code like
@racket[system/exit-code].}


@defproc[(process [command (or/c string-no-nuls? bytes-no-nuls?)]
                  [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
         (list input-port?
               output-port?
               exact-nonnegative-integer?
               input-port?
               ((or/c 'status 'wait 'interrupt 'kill) . -> . any))]{

Executes a shell command asynchronously (using @exec{/bin/sh} on Unix
and Mac OS, @exec{cmd.exe} or @exec{command.com} on Windows). The result is a list of five
values:

@margin-note{See also @racket[subprocess] for notes about error
handling and the limited buffer capacity of subprocess pipes.}

@itemize[

 @item{an input port piped from the subprocess's standard output,}

 @item{an output port piped to the subprocess's standard input,} 

 @item{the system process id of the subprocess,}

 @item{an input port piped from the subprocess's standard
       error, and}

 @item{a procedure of one argument, either @racket['status], @racket['wait],
 @racket['interrupt], @racket['exit-code] or @racket['kill]:

   @itemize[

   @item{@racket['status] returns the status of the subprocess as one
    of @racket['running], @racket['done-ok], or
    @racket['done-error].}

   @item{@racket['exit-code] returns the integer exit code of the
    subprocess or @racket[#f] if it is still running.}

   @item{@racket['wait] blocks execution in the current thread until
    the subprocess has completed.}

   @item{@racket['interrupt] sends the subprocess an interrupt signal
    on @|AllUnix|, and takes no action on Windows. The result is
    @|void-const|.

     @margin-note{On Unix and Mac OS, if @racket[command] runs a
     single program, then @exec{/bin/sh} typically runs the program in
     such a way that it replaces @exec{/bin/sh} in the same process. For
     reliable and precise control over process creation, however, use
     @racket[process*].}}

   @item{@racket['kill] terminates the subprocess and returns
     @|void-const|.  Note that the immediate process created by
     @racket[process] is a shell process that may run another program;
     terminating the shell process may not terminate processes that
     the shell starts, particularly on Windows.}

   ]}

]

@bold{Important:} All three ports returned from @racket[process] must
be explicitly closed with @racket[close-input-port] or
@racket[close-output-port].

If @racket[set-pwd?] is true, then @envvar{PWD} is set in the same way
as @racket[system].

See also @racket[current-subprocess-custodian-mode] and
@racket[subprocess-group-enabled], which affect the subprocess used to
implement @racket[process]. In particular, the @racket['interrupt] and
@racket['kill] process-control messages are implemented via
@racket[subprocess-kill], so they can affect a process group instead
of a single process.}


@defproc*[([(process* [command path-string?]
                      [arg (or/c path? string-no-nuls? bytes-no-nuls?)] ...
                      [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
            list?]
           [(process* [command path-string?] [exact 'exact] [arg string?]
                      [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
            list?])]{

Like @racket[process], except that @racket[command] is a filename that
is executed directly like @racket[system*], and the @racket[arg]s are the arguments.

On Windows, as for @racket[system*], the first @racket[arg] can be
replaced with @racket['exact]. See also @racket[subprocess] for a
specific warning about using a @racket[command] that refers to a
@filepath{.bat} or @filepath{.cmd} file.}


@defproc[(process/ports [out (or/c #f output-port?)]
                        [in (or/c #f input-port?)]
                        [error-out (or/c #f output-port? 'stdout)]
                        [command (or/c path? string-no-nuls? bytes-no-nuls?)]
                        [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
         list?]{

Like @racket[process], except that @racket[out] is used for the
process's standard output, @racket[in] is used for the process's
standard input, and @racket[error-out] is used for the process's
standard error.  Any of the ports can be @racket[#f], in which case a
system pipe is created and returned, as in @racket[process]. If
@racket[error-out] is @racket['stdout], then standard error is
redirected to standard output.  For each port or @racket['stdout] that
is provided, no pipe is created, and the corresponding value in the
returned list is @racket[#f].}

@defproc*[([(process*/ports [out (or/c #f output-port?)]
                            [in (or/c #f input-port?)]
                            [error-out (or/c #f output-port? 'stdout)]
                            [command path-string?]
                            [arg (or/c path? string-no-nuls? bytes-no-nuls?)]
                            ...
                            [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
            list?]
           [(process*/ports [out (or/c #f output-port?)]
                            [in (or/c #f input-port?)]
                            [error-out (or/c #f output-port? 'stdout)]
                            [command path-string?]
                            [exact 'exact]
                            [arg string?]
                            [#:set-pwd? set-pwd? any/c (member (system-type) '(unix macosx))])
            list?])]{

Like @racket[process*], but with the port handling of
@racket[process/ports].}

@; ----------------------------------------------------------------------

@;section{Contract Auxiliaries}

@;note-lib[racket/system]

The contracts of @racket[system] and related functions may signal a
contract error with references to the following functions.

@defproc[(string-no-nuls? [x any/c]) boolean?]{
Ensures that @racket[x] is a string and does not contain @racket["\0"].}

@defproc[(bytes-no-nuls? [x any/c]) boolean?]{
Ensures that @racket[x] is a byte-string and does not contain @racket[#"\0"].}
