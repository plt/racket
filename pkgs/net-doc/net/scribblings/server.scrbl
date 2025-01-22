#lang scribble/doc

@(require "common.rkt"
          racket/runtime-path
          scribble/example
          (for-label net/server
                     #;racket/unix-socket ; don't add to the racket-doc dependency cycle
                     openssl
                     racket/base
                     racket/contract
                     racket/tcp
                     racket/list))

@title[#:tag "server"]{General-Purpose Servers}
@defmodule[net/server]

The @racketmodname[net/server] library provides
support for running general-purpose networked servers.

@(define reference '(lib "scribblings/reference/reference.scrbl"))
@(define unix-sockets-link @seclink["Echo_Server_over_Unix_Domain_Sockets"]{Unix domain sockets})
@(define ports-link @seclink["Echo_Server_over_Ports"]{plain Racket ports})

@defproc[(start-server [listen-evt (evt/c @#,tech{listener})]
                       [handle (-> input-port? output-port? any)]
                       [#:max-concurrent max-concurrent
                        (or/c +inf.0 natural-number/c)
                        +inf.0]
                       [#:timeout-evt-proc make-timeout-evt
                        (-> thread? input-port? output-port? boolean? evt?)
                        (λ (thd in out break-sent?) never-evt)]
                       [#:accept-proc accept
                        (-> @#,tech{listener} (values input-port? output-port?))
                        tcp-accept]
                       [#:close-proc close
                        (-> listen-evt any)
                        tcp-close]) (-> void?)]{
  Creates a server that accepts connections when @racket[listen-evt] is
  ready for synchronization. For every new connection, @racket[handle]
  is called with two arguments: an input port to read from the
  client, and an output port to write to the client. The result
  of @racket[start-server] is a procedure that, when called,
  stops accepting new connections and calls @racket[close] on
  @racket[listen-evt], but does not terminate active connections.

  The server spawns a background thread to accept new connections. Each
  client connection is managed by a fresh custodian, and each call to
  @racket[handle] occurs in a new thread managed by that custodian. Each
  handling thread has an associated supervising thread that shuts down
  the connection's custodian when the handling thread terminates or when
  the result of @racket[make-timeout-evt] is ready for synchronization.
  Breaks are enabled in handling threads if breaks are enabled when
  @racket[start-server] is called. Handling threads need not close the
  input and output ports they receive.

  To facilitate capturing a continuation in one connection
  thread and invoking it in another, the parameterization of the
  @racket[start-server] call is used for every call to @racket[handle].
  In this parameterization and for the connection's thread, the
  @racket[current-custodian] is parameterized to the connection's
  custodian.

  For each connection, @racket[make-timeout-evt] is called with the
  connection-handling thread, the input port and the output port of
  the connection, and a boolean to signal if the handling thread has
  already been sent a break (which will initially be @racket[#f]). When
  the event it returns is ready for synchronization, if the handling
  thread is still running, the handling thread is sent a break and
  @racket[make-timeout-evt] is called again (this time with @racket[#t]
  for the last argument) to produce an event that, when ready for
  synchronization, will cause the connection's custodian to be shut down
  and, consequently, the handling thread to be killed if it is still
  running by that time. The default @racket[make-timeout-evt] does not
  impose a timeout.

  The server keeps track of the number of active connections
  and pauses accepting new connections once that number reaches
  @racket[max-concurrent], resuming once the number goes down again. By
  default, @racket[max-concurrent] is @racket[+inf.0], which does not
  impose a limit on the number of active connections.

  The @racket[listen-evt], @racket[accept] and @racket[close]
  arguments together determine the protocol that is used. The
  procedures must all work on the same kinds of values. The
  default @racket[accept] and @racket[close] procedures expect
  @racket[listen-evt] to be a @tech[#:doc reference]{TCP listener}
  as created by @racket[tcp-listen]. The examples illustrate using
  these arguments to serve instead over @unix-sockets-link or over
  @|ports-link|. In the general case, @racket[listen-evt] must be a
  @tech[#:doc reference]{synchronizable event} that is @tech[#:doc
  reference]{ready for synchronization} when @racket[accept] would not
  block, and its @tech[#:doc reference]{synchronization result} must be
  some kind of @deftech{listener} value (perhaps @racket[listen-evt]
  itself) that can be passed to @racket[accept]. Additionally,
  @racket[listen-evt] itself must be suitable as an argument to
  @racket[close].

  @history[#:added "1.3"]
}

@defproc[(run-server [listen-evt (evt/c @#,tech{listener})]
                     [handle (-> input-port? output-port? any)]
                     [#:max-concurrent max-concurrent
                      (or/c +inf.0 natural-number/c)
                      +inf.0]
                     [#:timeout-evt-proc make-timeout-evt
                      (-> thread? input-port? output-port? boolean? evt?)
                      (λ (thd in out break-sent?) never-evt)]
                     [#:accept-proc accept
                      (-> @#,tech{listener} (values input-port? output-port?))
                      tcp-accept]
                     [#:close-proc close
                      (-> listen-evt any)
                      tcp-close]) (-> void?)]{

  Spawns a server using @racket[start-server] and blocks the current
  thread until a break is received.  Before returning, it stops the
  spawned server.  The server is run with breaks disabled.

  @history[#:added "1.3"]
}

@section{Examples}

@; Run `raco setup` with the environment variable RECORD_NET_SERVER_EVAL
@; set to any value to update the recorded example output. Note that one
@; of the examples expects unix-socket-lib to be installed.
@(define-runtime-path server-log.rktd "server-log.rktd")
@(define ev (make-log-based-eval server-log.rktd (if (getenv "RECORD_NET_SERVER_EVAL") 'record 'replay)))
@(ev '(require net/server racket/tcp))

@subsection{TCP Echo Server}

Here is an implementation of a TCP echo server using
@racket[start-server]:

@examples[
  #:label #f
  #:eval ev
  (define (echo in out)
    (define buf (make-bytes 4096))
    (let loop ()
      (define n-read (read-bytes-avail! buf in))
      (unless (eof-object? n-read)
        (write-bytes buf out 0 n-read)
        (flush-output out)
        (loop))))
  (code:line)

  (define listener
    (tcp-listen 9000 512 #t "127.0.0.1"))
  (code:line)

  (define stop
    (start-server listener echo))
  (code:line)

  (define-values (in out)
    (tcp-connect "127.0.0.1" 9000))
  (displayln "hello" out)
  (flush-output out)
  (read-line in)
  (close-output-port out)
  (close-input-port in)
  (stop)
]

@subsection{TCP Echo Server with TLS Support}

Here is how you might wrap the previous echo server implementation to
add TLS support:

@margin-note{
  For brevity, we use an insecure client context here.  See
  @other-doc['(lib "openssl/openssl.scrbl")] for details.
}

@examples[
  #:label #f
  #:eval ev
  (require openssl)
  (code:line)

  (define ((make-tls-echo ctx) in out)
    (define-values (ssl-in ssl-out)
      (ports->ssl-ports
       #:context ctx
       #:mode 'accept
       in out))
    (echo ssl-in ssl-out))
  (code:line)

  (define server-ctx
    (ssl-make-server-context))
  (ssl-load-certificate-chain! server-ctx (collection-file-path "test.pem" "openssl"))
  (ssl-load-private-key! server-ctx (collection-file-path "test.pem" "openssl"))
  (ssl-seal-context! server-ctx)
  (code:line)

  (define stop
    (start-server
     (tcp-listen 9000 512 #t "127.0.0.1")
     (make-tls-echo server-ctx)))

  (code:line)
  (define-values (in out)
    (ssl-connect "127.0.0.1" 9000))
  (displayln "hello" out)
  (flush-output out)
  (read-line in)
  (close-output-port out)
  (close-input-port in)
  (stop)
]

@subsection{Echo Server over Unix Domain Sockets}

This example builds upon the previous one to run an echo server with TLS over
@tech[#:indirect? #t #:doc '(lib "scribblings/socket/unix-socket.scrbl")]{Unix domain sockets}.
The Unix socket listener is wrapped in
a custom struct to keep track of the socket path so it can be deleted
on server shutdown.

@margin-note{See the @other-doc['(lib
"scribblings/socket/unix-socket.scrbl") #:indirect "Unix Domain
Sockets"] for details on the procedures used here.}

@examples[
  #:label #f
  #:eval ev
  (require racket/unix-socket)
  (code:line)

  (struct listener (path the-wrapped-listener)
    #:property prop:evt (struct-field-index the-wrapped-listener))
  (code:line)

  (define path "/tmp/server.sock")
  (define stop
    (start-server
     #:accept-proc unix-socket-accept
     #:close-proc (λ (l) (delete-file (listener-path l)))
     (listener path (unix-socket-listen path 512))
     (make-tls-echo server-ctx)))
  (code:line)

  (define-values (in out)
    (let-values ([(in out) (unix-socket-connect path)])
      (ports->ssl-ports in out)))
  (displayln "hello" out)
  (flush-output out)
  (read-line in)
  (close-output-port out)
  (close-input-port in)
  (stop)
]

@subsection{Echo Server over Ports}

Finally, here is an echo server that operates entirely within a Racket
process and does not rely on any networking machinery:

@examples[
  #:label #f
  #:eval ev
  (define ch (make-channel))
  (define stop
    (start-server
     #:accept-proc (λ (ports) (apply values ports))
     #:close-proc void
     ch
     echo))
  (code:line)

  (define-values (client-in server-out) (make-pipe))
  (define-values (server-in client-out) (make-pipe))
  (channel-put ch (list server-in server-out))
  (displayln "hello" client-out)
  (read-line client-in)
  (stop)
]
