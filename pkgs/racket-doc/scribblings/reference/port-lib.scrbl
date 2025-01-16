#lang scribble/doc
@(require "mz.rkt" (for-label racket/port))

@title[#:tag "port-lib"]{More Port Constructors, Procedures, and Events}

@note-lib[racket/port]

@; ----------------------------------------------------------------------

@section{Port String and List Conversions}
@(define port-eval (make-base-eval))
@examples[#:hidden #:eval port-eval (require racket/port)]

@defproc[(port->list [r (input-port? . -> . any/c) read] [in input-port? (current-input-port)])
         (listof any/c)]{
Returns a list whose elements are produced by calling @racket[r]
on @racket[in] until it produces @racket[eof].

@examples[#:eval port-eval
(define (read-number input-port)
  (define char (read-char input-port))
  (if (eof-object? char)
   char
   (string->number (string char))))
(port->list read-number (open-input-string "12345"))
]}

@defproc[(port->string [in input-port? (current-input-port)]
                       [#:close? close? any/c #f])
         string?]{

Reads all characters from @racket[in] and returns them as a string.
If @racket[close?] is @racket[#t], then the input port is closed,
otherwise, it is left open.

@examples[#:eval port-eval
(port->string (open-input-string "hello world"))
    ]

@history[#:changed "6.8.0.2" @elem{Added the @racket[#:close?] argument.}]}

@defproc[(port->bytes [in input-port? (current-input-port)]
                      [#:close? close? any/c #f])
         bytes?]{

Reads all bytes from @racket[in] and returns them as a @tech{byte string}.
The input port is closed unless @racket[close?] is @racket[#f].

@examples[#:eval port-eval
(port->bytes (open-input-string "hello world"))
]

@history[#:changed "6.8.0.2" @elem{Added the @racket[#:close?] argument.}]}

@defproc[(port->lines [in input-port? (current-input-port)]
                      [#:line-mode line-mode (or/c 'linefeed 'return 'return-linefeed 'any 'any-one) 'any]
                      [#:close? close? any/c #f])
         (listof string?)]{

Read all characters from @racket[in], breaking them into lines. The
@racket[line-mode] argument is the same as the second argument to
@racket[read-line], but the default is @racket['any] instead of
@racket['linefeed].
The input port is closed unless @racket[close?] is @racket[#f].

@examples[#:eval port-eval
(port->lines
 (open-input-string "line 1\nline 2\n  line 3\nline 4"))
]

@history[#:changed "6.8.0.2" @elem{Added the @racket[#:close?] argument.}]}

@defproc[(port->bytes-lines [in input-port? (current-input-port)]
                            [#:line-mode line-mode (or/c 'linefeed 'return 'return-linefeed 'any 'any-one) 'any]
                            [#:close? close? any/c #f])
         (listof bytes?)]{

Like @racket[port->lines], but reading bytes and collecting them into
lines like @racket[read-bytes-line].
The input port is closed unless @racket[close?] is @racket[#f].

@examples[#:eval port-eval
(port->bytes-lines 
 (open-input-string "line 1\nline 2\n  line 3\nline 4"))
]

@history[#:changed "6.8.0.2" @elem{Added the @racket[#:close?] argument.}]}

@defproc[(display-lines [lst list?]
                        [out output-port? (current-output-port)]
                        [#:separator separator any/c #"\n"])
         void?]{

Uses @racket[display] on each element of @racket[lst] to @racket[out], adding
@racket[separator] after each element.}

@defproc[(call-with-output-string [proc (output-port? . -> . any)]) string?]{

Calls @racket[proc] with an output port that accumulates all output
into a string, and returns the string.

The port passed to @racket[proc] is like the one created by
@racket[open-output-string], except that it is wrapped via
@racket[dup-output-port], so that @racket[proc] cannot access the
port's content using @racket[get-output-string]. If control jumps back
into @racket[proc], the port continues to accumulate new data, and
@racket[call-with-output-string] returns both the old data and newly
accumulated data.}

@defproc[(call-with-output-bytes [proc (output-port? . -> . any)]) bytes?]{

Like @racket[call-with-output-string], but returns the accumulated result
in a @tech{byte string} instead of a string. Furthermore, the port's
content is emptied when @racket[call-with-output-bytes] returns, so
that if control jumps back into @racket[proc] and returns a second
time, only the newly accumulated bytes are returned.}

@defproc[(with-output-to-string [proc (-> any)]) string?]{

Equivalent to

@racketblock[(call-with-output-string
              (lambda (p) (parameterize ([current-output-port p])
                            (proc))))]}

@defproc[(with-output-to-bytes [proc (-> any)]) bytes?]{

Equivalent to

@racketblock[(call-with-output-bytes
              (lambda (p) (parameterize ([current-output-port p])
                            (proc))))]}

@defproc[(call-with-input-string [str string?] [proc (input-port? . -> . any)]) any]{

Equivalent to @racket[(proc (open-input-string str))].}

@defproc[(call-with-input-bytes [bstr bytes?] [proc (input-port? . -> . any)]) any]{

Equivalent to @racket[(proc (open-input-bytes bstr))].}

@defproc[(with-input-from-string [str string?] [proc (-> any)]) any]{

Equivalent to

@racketblock[(parameterize ([current-input-port (open-input-string str)])
               (proc))]}

@defproc[(with-input-from-bytes [bstr bytes?] [proc (-> any)]) any]{

Equivalent to

@racketblock[(parameterize ([current-input-port (open-input-bytes str)])
               (proc))]}


@; ----------------------------------------------------------------------

@section{Creating Ports}

@defproc[(input-port-append [close-at-eof? any/c]
                            [in input-port?] ...
                            [#:name name any/c (map object-name in)])
         input-port?]{

Takes any number of input ports and returns an input port. Reading
from the input port draws bytes (and special non-byte values) from the
given input ports in order. If @racket[close-at-eof?] is true, then
each port is closed when an end-of-file is encountered from the port,
or when the result input port is closed. Otherwise, data not read from
the returned input port remains available for reading in its original
input port.

The @racket[name] argument determines the name as reported by
@racket[object-name] for the returned input port.

See also @racket[merge-input], which interleaves data from multiple
input ports as it becomes available.

@history[#:changed "6.90.0.19" @elem{Added the @racket[name] argument.}]}


@defproc[(make-input-port/read-to-peek 
          [name any/c]
          [read-in (bytes? 
                    . -> . (or/c exact-nonnegative-integer?
                                 eof-object?
                                 procedure?
                                 evt?))]
          [fast-peek (or/c #f
                           (bytes? exact-nonnegative-integer?
                            (bytes? exact-nonnegative-integer?
                             . -> . (or/c exact-nonnegative-integer?
                                          eof-object?
                                          procedure?
                                          evt?
                                          #f))
                            . -> . (or/c exact-nonnegative-integer?
                                         eof-object?
                                         procedure?
                                         evt?
                                         #f)))]
          [close (-> any)]
          [get-location (or/c 
                         (->
                          (values
                           (or/c exact-positive-integer? #f)
                           (or/c exact-nonnegative-integer? #f)
                           (or/c exact-positive-integer? #f)))
                         #f)
                        #f]
          [count-lines! (-> any) void]
          [init-position exact-positive-integer? 1]
          [buffer-mode (or/c (case-> ((or/c 'block 'none) . -> . any)
                                     (-> (or/c 'block 'none #f)))
                             #f)
                       #f]
          [buffering? any/c #f]
          [on-consumed (or/c ((or/c exact-nonnegative-integer? eof-object? 
                                    procedure? evt?) 
                              . -> . any)
                             #f)
                       #f])
         input-port?]{

Similar to @racket[make-input-port], but if the given @racket[read-in]
returns an event, the event's value must be @racket[0].  The resulting
port's peek operation is implemented automatically (in terms of
@racket[read-in]) in a way that can handle special non-byte
values. The progress-event and commit operations are also implemented
automatically. The resulting port is thread-safe, but not kill-safe
(i.e., if a thread is terminated or suspended while using the port,
the port may become damaged).

The @racket[read-in], @racket[close], @racket[get-location],
@racket[count-lines!], @racket[init-position], and
@racket[buffer-mode] procedures are the same as for
@racket[make-input-port].

The @racket[fast-peek] argument can be either @racket[#f] or a
procedure of three arguments: a byte string to receive a peek, a skip
count, and a procedure of two arguments. The @racket[fast-peek]
procedure can either implement the requested peek, or it can dispatch
to its third argument to implement the peek. The @racket[fast-peek] is
not used when a peek request has an associated progress event.

The @racket[buffering?] argument determines whether @racket[read-in]
can be called to read more characters than are immediately demanded by
the user of the new port. If @racket[buffer-mode] is not @racket[#f],
then @racket[buffering?] determines the initial buffer mode, and
@racket[buffering?] is enabled after a buffering change only if the
new mode is @racket['block].

If @racket[on-consumed] is not @racket[#f], it is called when data is
read (or committed) from the port, as opposed to merely peeked. The argument to
@racket[on-consumed] is the result value of the port's reading
procedure, so it can be an integer or any result from
@racket[read-in].}


@defproc[(make-limited-input-port [in input-port?]
                                  [limit exact-nonnegative-integer?]
                                  [close-orig? any/c #t])
         input-port?]{

Returns a port whose content is drawn from @racket[in], but where an
end-of-file is reported after @racket[limit] bytes (and non-byte
special values) have been read.  If @racket[close-orig?] is true, then the
original port is closed if the returned port is closed.

Bytes are consumed from @racket[in] only when they are consumed from
the returned port. In particular, peeking into the returned port peeks
into the original port.

If @racket[in] is used directly while the resulting port is also used,
then the @racket[limit] bytes provided by the port need not be
contiguous parts of the original port's stream.}



@defproc[(make-pipe-with-specials [limit exact-nonnegative-integer? #f]
                                  [in-name any/c 'pipe]
                                  [out-name any/c 'pipe]) 
         (values input-port? output-port?)]{

Returns two ports: an input port and an output port. The ports behave
like those returned by @racket[make-pipe], except that the ports
support non-byte values written with procedures such as
@racket[write-special] and read with procedures such as
@racket[get-byte-or-special].

The @racket[limit] argument determines the maximum capacity of the
pipe in bytes, but this limit is disabled if special values are
written to the pipe before @racket[limit] is reached. The limit is
re-enabled after the special value is read from the pipe.

The optional @racket[in-name] and @racket[out-name] arguments
determine the names of the result ports.}


@defproc[(combine-output [a-out output-port?]
                         [b-out output-port?])
         output-port?]{

Accepts two output ports and returns a new output port
combining the original ports. When written to, the combined port
first writes as many bytes as possible to @racket[a-out], and then
tries to write the same number of bytes to @racket[b-out]. If that
doesn't succeed, what is left over is buffered and no further writes
can go through until the ports are evened out. The port is ready (for
the purposes of synchronization) when each port reports being ready.
However, the first port may stop being ready while waiting on
the second port to sync, so it cannot be guaranteed that both
ports are ready at once. Closing the combined port is done
after writing all remaining bytes to @racket[b-out].

@history[#:added "7.7.0.10"]}

@defproc[(merge-input [a-in input-port?]
                      [b-in input-port?]
                      [buffer-limit (or/c exact-nonnegative-integer? #f) 4096])
         input-port?]{

Accepts two input ports and returns a new input port. The new port
merges the data from two original ports, so data can be read from the
new port whenever it is available from either of the two original ports. The data
from the original ports are interleaved. When an end-of-file has been
read from an original port, it no longer contributes characters to the
new port. After an end-of-file has been read from both original ports,
the new port returns end-of-file. Closing the merged port does not
close the original ports.

The optional @racket[buffer-limit] argument limits the number of bytes
to be buffered from @racket[a-in] and @racket[b-in], so that the merge
process does not advance arbitrarily beyond the rate of consumption of
the merged data. A @racket[#f] value disables the limit. As for
@racket[make-pipe-with-specials], @racket[buffer-limit] does not apply
when a special value is produced by one of the input ports before the
limit is reached.

See also @racket[input-port-append], which concatenates input streams
instead of interleaving them.}


@defproc[(open-output-nowhere [name any/c 'nowhere] [special-ok? any/c #t])
         output-port?]{
@index*['("discard-output" "null-output" "null-output-port" "dev-null"
          "/dev/null")
	'("Opening a null output port")]{
	
Creates} and returns an output port that discards all output sent to it
(without blocking). The @racket[name] argument is used as the port's
name. If the @racket[special-ok?]  argument is true, then the
resulting port supports @racket[write-special], otherwise it does not.}


@defproc[(open-input-nowhere [name any/c 'nowhere])
         input-port?]{
@index*['("null-input" "null-input-port" "dev-null"
          "/dev/null")
	'("Opening a null input port")]{

Creates} and returns an input port that always returns @racket[eof]
(without blocking). The @racket[name] argument is used as the port's
name.

@history[#:added "8.15.0.2"]}


@defproc[(peeking-input-port [in input-port?]
                             [name any/c (object-name in)]
                             [skip exact-nonnegative-integer? 0]
                             [#:init-position init-position exact-positive-integer? 1])
         input-port?]{

Returns an input port whose content is determined by peeking into
@racket[in]. In other words, the resulting port contains an internal
skip count, and each read of the port peeks into @racket[in] with the
internal skip count, and then increments the skip count according to
the amount of data successfully peeked.

The optional @racket[name] argument is the name of the resulting
port. The @racket[skip] argument is the port initial skip count, and
it defaults to @racket[0].

The resulting port's initial position (as reported by @racket[file-position])
is @racket[(- init-position 1)], no matter the position of @racket[in].

The resulting port supports buffering, and a @racket['block] buffer
mode allows the port to peek further into @racket[in] than
requested. The resulting port's initial buffer mode is
@racket['block], unless @racket[in] supports buffer mode and its mode
is initially @racket['none] (i.e., the initial buffer mode is taken
from @racket[in] when it supports buffering). If @racket[in] supports
buffering, adjusting the resulting port's buffer mode via
@racket[file-stream-buffer-mode] adjusts @racket[in]'s buffer mode.

For example, when you read from a peeking port, you
see the same answers as when you read from the original port:

@examples[#:eval port-eval
(define an-original-port (open-input-string "123456789"))
(define a-peeking-port (peeking-input-port an-original-port))
(file-stream-buffer-mode a-peeking-port 'none)
(read-string 3 a-peeking-port)
(read-string 3 an-original-port)]

Beware that the read from the original port is invisible to the peeking
port, which keeps its own separate internal counter, and thus
interleaving reads on the two ports can produce confusing results.
Continuing the example before, if we read three more characters from
the peeking port, we end up skipping over the @litchar{456} in the port
(but only because we disabled buffering above):

@examples[#:eval port-eval
(read-string 3 a-peeking-port)
]

If we had left the buffer mode of @racket[a-peeking-port] alone, that
last @racket[read-string] would have likely produced @racket["456"] as
a result of buffering bytes from @racket[an-original-port] earlier.


@history[#:changed "6.1.0.3" @elem{Enabled buffering and buffer-mode
                                   adjustments via @racket[file-stream-buffer-mode],
                                   and set the port's initial buffer mode to that of
                                   @racket[in].}]}



@defproc[(reencode-input-port [in input-port?]
                              [encoding string?]
                              [error-bytes (or/c #f bytes?) #f]
                              [close? any/c #f]
                              [name any/c (object-name in)]
                              [convert-newlines? any/c #f]
                              [enc-error (string? input-port? . -> . any) 
                                         (lambda (msg port) (error ...))])
         input-port?]{

Produces an input port that draws bytes from @racket[in], but converts
the byte stream using @racket[(bytes-open-converter encoding-str
"UTF-8")]. In addition, if @racket[convert-newlines?] is true, then
decoded sequences that correspond to UTF-8 encodings of @racket["\r\n"],
@racket["\r\x85"], @racket["\r"], @racket["\x85"], and @racket["\u2028"]
are all converted to the UTF-8 encoding of @racket["\n"].
 
If @racket[error-bytes] is provided and not @racket[#f], then the
given byte sequence is used in place of bytes from @racket[in] that
trigger conversion errors.  Otherwise, if a conversion is encountered,
@racket[enc-error] is called, which must raise an exception.

If @racket[close?] is true, then closing the result input port also
closes @racket[in]. The @racket[name] argument is used as the name of
the result input port.

In non-buffered mode, the resulting input port attempts to draw bytes
from @racket[in] only as needed to satisfy requests. Toward that end,
the input port assumes that at least @math{n} bytes must be read to
satisfy a request for @math{n} bytes. (This is true even if the port
has already drawn some bytes, as long as those bytes form an
incomplete encoding sequence.)}


@defproc[(reencode-output-port [out output-port?]
                               [encoding string?]
                               [error-bytes (or/c #f bytes?) #f]
                               [close? any/c #f]
                               [name any/c (object-name out)]
                               [newline-bytes (or/c #f bytes?) #f]
                               [enc-error (string? output-port? . -> . any) 
                                          (lambda (msg port) (error ...))])
         output-port?]{

Produces an output port that directs bytes to @racket[out], but
converts its byte stream using @racket[(bytes-open-converter "UTF-8"
encoding-str)]. In addition, if @racket[newline-bytes] is not
@racket[#f], then bytes written to the port that are the UTF-8
encoding of @racket["\n"] are first converted to
@racket[newline-bytes] (before applying the convert from UTF-8 to
@racket[encoding-str]).
 
If @racket[error-bytes] is provided and not @racket[#f], then the
given byte sequence is used in place of bytes that have been sent to the output port
and that trigger conversion errors. Otherwise, @racket[enc-error] is
called, which must raise an exception.

If @racket[close?] is true, then closing the result output port also
closes @racket[out]. The @racket[name] argument is used as the name of
the result output port.

The resulting port supports buffering, and the initial buffer mode is
@racket[(or (file-stream-buffer-mode out) 'block)]. In @racket['block]
mode, the port's buffer is flushed only when it is full or a flush is
requested explicitly. In @racket['line] mode, the buffer is flushed
whenever a newline or carriage-return byte is written to the port. In
@racket['none] mode, the port's buffer is flushed after every write.
Implicit flushes for @racket['line] or @racket['none] leave bytes in
the buffer when they are part of an incomplete encoding sequence.

The resulting output port does not support atomic writes. An explicit
flush or special-write to the output port can hang if the most
recently written bytes form an incomplete encoding sequence.

When the port is buffered, a @tech{flush callback} is registered with
the @tech{current plumber} to flush the buffer.}


@defproc[(dup-input-port [in input-port?]
                         [close? any/c #f])
         input-port?]{

Returns an input port that draws directly from @racket[in]. Closing
the resulting port closes @racket[in] only if @racket[close?] is
@racket[#t].

The new port is initialized with the @tech{port read handler} of
@racket[in], but setting the handler on the result port does not
affect reading directly from @racket[in].}


@defproc[(dup-output-port [out output-port?]
                          [close? any/c #f])
         output-port?]{

Returns an output port that propagates data directly to
@racket[out]. Closing the resulting port closes @racket[out] only if
@racket[close?] is @racket[#t].

The new port is initialized with the @tech{port display handler} and
@tech{port write handler} of @racket[out], but setting the handlers on
the result port does not affect writing directly to @racket[out].}



@defproc[(relocate-input-port [in input-port?]
                              [line (or/c exact-positive-integer? #f)]
                              [column (or/c exact-nonnegative-integer? #f)]
                              [position exact-positive-integer?]
                              [close? any/c #t]
                              [#:name name (object-name in)])
         input-port?]{

Produces an input port that is equivalent to @racket[in] except in how
it reports location information (and possibly its name). The resulting port's content starts
with the remaining content of @racket[in], and it starts at the given
line, column, and position. A @racket[#f] for the line or column means
that the line and column will always be reported as @racket[#f].

The @racket[line] and @racket[column] values are used only if line
counting is enabled for @racket[in] and for the resulting port,
typically through @racket[port-count-lines!]. The @racket[column]
value determines the column for the first line (i.e., the one numbered
@racket[line]), and later lines start at column @racket[0]. The given
@racket[position] is used even if line counting is not enabled.

When line counting is on for the resulting port, reading from
@racket[in] instead of the resulting port increments location reports
from the resulting port. Otherwise, the resulting port's position does
not increment when data is read from @racket[in].

If @racket[close?] is true, then closing the resulting port also
closes @racket[in]. If @racket[close?] is @racket[#f], then closing
the resulting port does not close @racket[in].

The @racket[name] argument is used as the name for the resulting port;
the default value keeps the same name as @racket[in].
}


@defproc[(relocate-output-port [out output-port?]
                               [line (or/c exact-positive-integer? #f)]
                               [column (or/c exact-nonnegative-integer? #f)]
                               [position exact-positive-integer?]
                               [close? any/c #t]
                               [#:name name (object-name out)])
         output-port?]{

Like @racket[relocate-input-port], but for output ports.}


@defproc[(transplant-input-port [in input-port?]
                                [get-location (or/c 
                                               (->
                                                (values
                                                 (or/c exact-positive-integer? #f)
                                                 (or/c exact-nonnegative-integer? #f)
                                                 (or/c exact-positive-integer? #f)))
                                               #f)]
                                [init-pos exact-positive-integer?]
                                [close? any/c #t]
                                [count-lines! (-> any) void]
                                [#:name name (object-name in)])
          input-port?]{

Like @racket[relocate-input-port], except that arbitrary position
information can be produced (when line counting is enabled) via
@racket[get-location], which is used as for @racket[make-input-port]. If
@racket[get-location] is @racket[#f], then the port counts lines in
the usual way starting from @racket[init-pos], independent of
locations reported by @racket[in].

If @racket[count-lines!] is supplied, it is called when line counting
is enabled for the resulting port. The default is @racket[void].}

@defproc[(transplant-output-port [out output-port?]
                                 [get-location (or/c 
                                                (->
                                                 (values
                                                  (or/c exact-positive-integer? #f)
                                                  (or/c exact-nonnegative-integer? #f)
                                                  (or/c exact-positive-integer? #f)))
                                                #f)]
                                 [init-pos exact-positive-integer?]
                                 [close? any/c #t]
                                 [count-lines! (-> any) void]
                                 [#:name name (object-name out)])
          output-port?]{

Like @racket[transplant-input-port], but for output ports.}


@defproc[(filter-read-input-port [in input-port?]
                                 [read-wrap (bytes? (or/c exact-nonnegative-integer?
                                                          eof-object?
                                                          procedure?
                                                          evt?)
                                                    . -> .
                                                    (or/c exact-nonnegative-integer?
                                                          eof-object?
                                                          procedure?
                                                          evt?))]
                                 [peek-wrap (bytes? exact-nonnegative-integer? (or/c evt? #f)
                                                    (or/c exact-nonnegative-integer?
                                                     eof-object?
                                                     procedure?
                                                     evt?
                                                     #f)
                                             . -> . (or/c exact-nonnegative-integer?
                                                     eof-object?
                                                     procedure?
                                                     evt?
                                                     #f))]
                                 [close? any/c #t])
         input-port?]{

Creates a port that draws from @racket[in], but each result from the
port's read and peek procedures (in the sense of @racket[make-input-port]) 
is filtered by @racket[read-wrap] and
@racket[peek-wrap]. The filtering procedures each receive both the
arguments and results of the read and peek procedures on @racket[in]
for each call.

If @racket[close?] is true, then closing the resulting port also
closes @racket[in].}


@defproc[(special-filter-input-port [in input-port?]
                                    [proc (procedure? bytes? . -> . (or/c exact-nonnegative-integer? 
                                                                          eof-object?
                                                                          procedure? 
                                                                          evt?))]
                                    [close? any/c #t])
          input-port?]{

Produces an input port that is equivalent to @racket[in], except
that when @racket[in] produces a procedure to access a special value,
@racket[proc] is applied to the procedure to allow the special value
to be replaced with an alternative. The @racket[proc] is called with
the special-value procedure and the byte string that was given to the
port's read or peek function (see @racket[make-input-port]), and the
result is used as the read or peek function's result.  The
@racket[proc] can modify the byte string to substitute a byte for the
special value, but the byte string is guaranteed only to hold at least
one byte.

If @racket[close?] is true, then closing the resulting input port also
closes @racket[in].}

@; ----------------------------------------------------------------------

@section{Port Events}


@defproc[(eof-evt [in input-port?]) evt?]{

Returns a @tech{synchronizable event} that is ready when
@racket[in] produces an @racket[eof]. If @racket[in] produces a
mid-stream @racket[eof], the @racket[eof] is consumed by the event
only if the event is chosen in a synchronization.

If attempting to read from @racket[in] raises an exception during a
synchronization attempt, then the exception may be reported during the
synchronization attempt, but it will silently discarded if some another
event in the same synchronization is selected or if some other event
raises an exception first.

@history[#:changed "7.5.0.3" @elem{Changed handling of read errors so
                                   they are propagated to a synchronization attempt,
                                   instead of treated as unhandled errors in a
                                   background thread.}]}


@defproc[(read-bytes-evt [k exact-nonnegative-integer?] [in input-port?]) 
         evt?]{

Returns a @tech{synchronizable event} that is ready when @racket[k]
bytes can be read from @racket[in], or when an end-of-file is
encountered in @racket[in]. If @racket[k] is @racket[0], then the
event is ready immediately with @racket[""]. For non-zero @racket[k],
if no bytes are available before an end-of-file, the event's result is
@racket[eof]. Otherwise, the event's result is a byte string of up to
@racket[k] bytes, which contains as many bytes as are available (up to
@racket[k]) before an available end-of-file. (The result is a byte
string of less than @racket[k] bytes only when an end-of-file is
encountered.)

Bytes are read from the port if and only if the event is chosen in a
synchronization, and the returned bytes always represent contiguous
bytes in the port's stream.

The event can be synchronized multiple times---even
concurrently---and each synchronization corresponds to a distinct read
request.

The @racket[in] must support progress events, and it must not produce
a special non-byte value during the read attempt.

Exceptions attempting to read from @racket[in] are handled in the same
way as by @racket[eof-evt].}


@defproc[(read-bytes!-evt [bstr (and/c bytes? (not/c immutable?))]
                          [in input-port?])
         evt?]{

Like @racket[read-bytes-evt], except that the read bytes are placed
into @racket[bstr], and the number of bytes to read corresponds to
@racket[(bytes-length bstr)]. The event's result is either
@racket[eof] or the number of read bytes.

The @racket[bstr] may be mutated any time after the first
synchronization attempt on the event and until either the event is
selected, a non-@racket[#f] @racket[progress-evt] is ready, or the
current @tech{custodian} (at the time of synchronization) is shut
down. Note that there is no time bound otherwise on when @racket[bstr]
might be mutated if the event is not selected by a synchronzation;
nevertheless, multiple synchronization attempts can use the same
result from @racket[read-bytes!-evt] as long as there is no
intervening read on @racket[in] until one of the synchronization
attempts selects the event.

Exceptions attempting to read from @racket[in] are handled in the same
way as by @racket[eof-evt].}


@defproc[(read-bytes-avail!-evt [bstr (and/c bytes? (not/c immutable?))] [in input-port?]) 
         evt?]{

Like @racket[read-bytes!-evt], except that the event reads only as
many bytes as are immediately available, after at least one byte or
one @racket[eof] becomes available.}


@defproc[(read-string-evt [k exact-nonnegative-integer?] [in input-port?]) 
         evt?]{

Like @racket[read-bytes-evt], but for character strings instead of
byte strings.}


@defproc[(read-string!-evt [str (and/c string? (not/c immutable?))]
                           [in input-port?]) 
         evt?]{

Like @racket[read-bytes!-evt], but for a character string instead of
a byte string.}


@defproc[(read-line-evt [in input-port?]
                        [mode (or/c 'linefeed 'return 'return-linefeed 'any 'any-one) 'linefeed])
         evt?]{

Returns a @tech{synchronizable event} that is ready when a line of
characters or end-of-file can be read from @racket[in]. The
meaning of @racket[mode] is the same as for @racket[read-line]. The
event result is the read line of characters (not including the line
separator).

A line is read from the port if and only if the event is chosen in a
synchronization, and the returned line always represents contiguous
bytes in the port's stream.

Exceptions attempting to read from @racket[in] are handled in the same
way as by @racket[eof-evt].}


@defproc[(read-bytes-line-evt [in input-port?]
                              [mode (or/c 'linefeed 'return 'return-linefeed 'any 'any-one) 'linefeed])
         evt?]{
 
Like @racket[read-line-evt], but returns a byte string instead of a
string.}

@defproc*[([(peek-bytes-evt [k exact-nonnegative-integer?] [skip exact-nonnegative-integer?]
                            [progress-evt (or/c progress-evt? #f)] [in input-port?]) evt?]
           [(peek-bytes!-evt [bstr (and/c bytes? (not/c immutable?))] [skip exact-nonnegative-integer?]
                             [progress-evt (or/c progress-evt? #f)] [in input-port?]) evt?]
           [(peek-bytes-avail!-evt [bstr (and/c bytes? (not/c immutable?))] [skip exact-nonnegative-integer?]
                                   [progress-evt (or/c progress-evt? #f)] [in input-port?]) evt?]
           [(peek-string-evt [k exact-nonnegative-integer?] [skip exact-nonnegative-integer?]
                             [progress-evt (or/c progress-evt? #f)] [in input-port?]) evt?]
           [(peek-string!-evt [str (and/c string? (not/c immutable?))] [skip exact-nonnegative-integer?]
                              [progress-evt (or/c progress-evt? #f)] [in input-port?]) evt?])]{

Like the @racket[read-bytes-evt], etc., functions, but for peeking. The
@racket[skip] argument indicates the number of bytes to skip, and
@racket[progress-evt] indicates an event that effectively cancels the peek
(so that the event never becomes ready). The @racket[progress-evt]
argument can be @racket[#f], in which case the event is never
canceled.}


@defproc[(regexp-match-evt [pattern (or/c string? bytes? regexp? byte-regexp?)]
                           [in input-port?]) any]{

Returns a @tech{synchronizable event} that is ready when
@racket[pattern] matches the stream of bytes/characters from
@racket[in]; see also @racket[regexp-match]. The event's value is the
result of the match, in the same form as the result of
@racket[regexp-match].

If @racket[pattern] does not require a start-of-stream match, then
bytes skipped to complete the match are read and discarded when the
event is chosen in a synchronization.

Bytes are read from the port if and only if the event is chosen in a
synchronization, and the returned match always represents contiguous
bytes in the port's stream. If not-yet-available bytes from the port
might contribute to the match, the event is not ready.  Similarly, if
@racket[pattern] begins with a start-of-stream @litchar{^} and the
@racket[pattern] does not initially match, then the event cannot
become ready until bytes have been read from the port.

The event can be synchronized multiple times---even concurrently---and
each synchronization corresponds to a distinct match request.

The @racket[in] port must support progress events. If @racket[in]
returns a special non-byte value during the match attempt, it is
treated like @racket[eof].

Exceptions attempting to read from @racket[in] are handled in the same
way as by @racket[eof-evt].}

@; ----------------------------------------------------------------------

@section{Copying Streams}

@defproc[(convert-stream [from-encoding string?]
                         [in input-port?]
                         [to-encoding string?]
                         [out output-port?])
         void?]{

Reads data from @racket[in], converts it using
@racket[(bytes-open-converter from-encoding
to-encoding)] and writes the converted bytes to
@racket[out]. The @racket[convert-stream] procedure returns after
reaching @racket[eof] in @racket[in].

If opening the converter fails, the @exnraise[exn:fail]. Similarly, if
a conversion error occurs at any point while reading from @racket[in], then
@exnraise[exn:fail].}


@defproc[(copy-port [in input-port?] [out output-port?] ...+) void?]{

Reads data from @racket[in] and writes it back out to @racket[out],
returning when @racket[in] produces @racket[eof].  The copy is
efficient, and it is without significant buffer delays (i.e., a byte
that becomes available on @racket[in] is immediately transferred to
@racket[out], even if future reads on @racket[in] must block). If
@racket[in] produces a special non-byte value, it is transferred to
@racket[out] using @racket[write-special].

This function is often called from a ``background'' thread to
continuously pump data from one stream to another.

If multiple @racket[out]s are provided, data from @racket[in] is
written to every @racket[out]. The different @racket[out]s block
output to each other, because each block of data read from @racket[in]
is written completely to one @racket[out] before moving to the next
@racket[out]. The @racket[out]s are written in the provided order, so
non-blocking ports (e.g., file output ports) should be placed first in the
argument list.}

@close-eval[port-eval]
