#lang scribble/doc
@(require "common.rkt" scribble/bnf
          (for-label net/url net/url-unit net/url-sig 
                     racket/list
                     racket/tcp
                     net/head net/uri-codec net/tcp-sig
                     net/http-client
                     (only-in net/url-connect current-https-protocol)
                     openssl))

@title[#:tag "url"]{URLs and HTTP}

@defmodule[net/url]{The @racketmodname[net/url] library provides
utilities to parse and manipulate URIs, as specified in RFC 2396
@cite["RFC2396"], and to use the HTTP protocol.}

To access the text of a document from the web, first obtain its URL as
a string. Convert the address into a @racket[url] structure using
@racket[string->url]. Then, open the document using
@racket[get-pure-port] or @racket[get-impure-port], depending on
whether or not you wish to examine its MIME headers.  At this point,
you have a regular input port with which to process the document, as with
any other file.

Currently the only supported protocols are @racket["http"],
@racket["https"], and sometimes @racket["file"].

The @racketmodname[net/url] logs information and background-thread
errors to a logger named @racket['net/url].

@section{URL Structure}

@declare-exporting[net/url-structs net/url-string net/url]

@defmodule*/no-declare[(net/url-structs)]{The URL structure types are
provided by the @racketmodname[net/url-structs] library, and
re-exported by @racketmodname[net/url] and @racketmodname[net/url-string].}

@; ----------------------------------------


@defstruct[url ([scheme (or/c #f string?)]
                [user (or/c #f string?)]
                [host (or/c #f string?)]
                [port (or/c #f exact-nonnegative-integer?)]
                [path-absolute? boolean?]
                [path (listof path/param?)]
                [query (listof (cons/c symbol? (or/c #f string?)))]
                [fragment (or/c #f string?)])]{

The basic structure for all URLs, which is explained in RFC 3986
@cite["RFC3986"]. The following diagram illustrates the parts:

@verbatim[#:indent 2]|{
  http://sky@www:801/cgi-bin/finger;xyz?name=shriram;host=nw#top
  {-1}   {2} {3} {4}{---5---------} {6} {----7-------------} {8}

  1 = scheme, 2 = user, 3 = host, 4 = port,
  5 = path (two elements),  6 = param (of second path element),
  7 = query, 8 = fragment
}|

The strings inside the @racket[user], @racket[path], @racket[query],
and @racket[fragment] fields are represented directly as Racket
strings, without URL-syntax-specific quoting. The procedures
@racket[string->url] and @racket[url->string] translate encodings such
as @litchar{%20} into spaces and back again.

By default, query associations are parsed with either @litchar{;} or
@litchar{&} as a separator, and they are generated with @litchar{&} as
a separator. The @racket[current-alist-separator-mode] parameter
adjusts the behavior.

An empty string at the end of the @racket[path] list corresponds to a
URL that ends in a slash. For example, the result of
@racket[(string->url "http://racket-lang.org/a/")] has a
@racket[path] field with strings @racket["a"] and @racket[""], while
the result of @racket[(string->url "http://racket-lang.org/a")] has a
@racket[path] field with only the string @racket["a"].

When a @racket["file"] URL is represented by a @racket[url] structure,
the @racket[path] field is mostly a list of path elements. For Unix
paths, the root directory is not included in @racket[path]; its
presence or absence is implicit in the @racket[path-absolute?] flag.
For Windows paths, the first element typically represents a drive, but
a UNC path is represented by a first element that is @racket[""] and
then successive elements complete the drive components that are
separated by @litchar{/} or @litchar{\}.}

@defstruct[path/param ([path (or/c string? (or/c 'up 'same))]
                       [param (listof string?)])]{

A pair that joins a path segment with its params in a URL.}

@; ----------------------------------------

@section{URL Parsing Functions}

@defmodule*/no-declare[(net/url-string)]{The functions used to convert strings and
paths to from URL structure types and back again are provided by the
 @racketmodname[net/url-string] library, and re-exported by @racketmodname[net/url].}

@defthing[url-regexp regexp?]{
A @tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{regexp value} 
that can be useful for matching URL strings. Mostly follows 
RFC 3986 @cite["RFC3986"], Appendix B, except for using @tt{*} instead of 
@tt{+} for the scheme part (see @racket[url]).
@history[#:added "6.4.0.7"]}

@defproc[(string->url [str url-regexp]) url?]{

Parses the URL specified by @racket[str] into a @racket[url]
struct. The @racket[string->url] procedure uses
@racket[form-urlencoded->alist] when parsing the query, so it is
sensitive to the @racket[current-alist-separator-mode] parameter for
determining the association separator.

The contract on @racket[str] insists that, if the URL has a scheme,
then the scheme begins with a letter and consists only of letters,
numbers, @litchar{+}, @litchar{-}, and @litchar{.} characters.

If @racket[str] starts with @litchar{file:} (case-insensitively) and
the value of the @racket[file-url-path-convention-type] parameter is
@racket['windows], then special parsing rules apply to accommodate
ill-formed but widely-recognized path encodings:

@itemize[

 @item{If @litchar{file:} is followed by @litchar{//}, a letter, and
       @litchar{:}, then the @litchar{//} is stripped and the
       remainder parsed as a Windows path.}

 @item{If @litchar{file:} is followed by @litchar{\\}, then the
       @litchar{\\} is stripped and the remainder parsed as a Windows
       path.}

]

In both of these cases, the host is @racket[""], the port is
@racket[#f], and path-element decoding (which extract parameters or
replaces @litchar{%20} with a space, for example) is not applied to
the path.

@history[#:changed "6.3.0.1" @elem{Changed handling of @litchar{file:}
                                   URLs when the value of
                                   @racket[file-url-path-convention-type]
                                   is @racket['windows].}
         #:changed "6.4.0.7" @elem{Use more specific regexp for 
                                   input contract.}
         #:changed "6.5.0.3" @elem{Support a host as an IPv6 literal address
                                   as written in @litchar{[}...@litchar{]}.}]}


@defproc[(combine-url/relative [base url?] [relative string?]) url?]{

Given a base URL and a relative path, combines the two and returns a
new URL as per the URL combination specification.  They are combined
according to the rules in RFC 3986 @cite["RFC3986"].

This function does not raise any exceptions.}


@defproc[(netscape/string->url [str string?]) url?]{

Turns a string into a URL, applying (what appear to be) Netscape's
conventions on automatically specifying the scheme: a string starting
with a slash gets the scheme @racket["file"], while all others get the
scheme @racket["http"].}


@defproc[(url->string [URL url?]) string?]{

Generates a string corresponding to the contents of a @racket[url]
struct.  For a @racket["file:"] URL, the URL must not be relative, and
the result always starts @litchar{file://}. For a URL with a host,
user, or port, its path must be either absolute or empty.

The @racket[url->string] procedure uses
@racket[alist->form-urlencoded] when formatting the query, so it is
sensitive to the @racket[current-alist-separator-mode] parameter for
determining the association separator. The default is to separate
associations with a @litchar{&}.

The encoding of path segments and fragment is sensitive to the
@racket[current-url-encode-mode] parameter.

@history[#:changed "6.5.0.3" @elem{Support a host as an IPv6 literals addresses
                                   by writing the address in @litchar{[}...@litchar{]}.}]}


@defproc[(path->url [path (or/c path-string? path-for-some-system?)])
         url?]{

Converts a path to a @racket[url].

With the @racket['unix] path convention, the host in the resulting URL
is always @racket[""], and the path is absolute from the root.

With the @racket['windows] path convention and a UNC path, the machine
part of the UNC root is used as the URL's host, and the drive part of
the root is the first element of the URL's path.

@history[#:changed "6.3.0.1" @elem{Changed @racket['windows] encoding
                                   of UNC paths.}]}



@defproc[(url->path [URL url?]
                    [kind (or/c 'unix 'windows) (system-path-convention-type)])
         path-for-some-system?]{

Converts @racket[URL], which is assumed to be a @racket["file"] URL,
to a path.

For the @racket['unix] path convention, the URL's host is ignored, and
the URL's path is formed relative to the root.

For the @racket['windows] path convention:

@itemlist[

 @item{A non-@racket[""] value for the URL's host field creates a UNC
       path, where the host is the UNC root's machine name, the URL's
       path must be non-empty, and the first element of the URL's path
       is used as the drive part of the UNC root.}

 @item{For legacy reasons, if the URL's host is @racket[""], the URL's
       path contains at least three elements, and and the first
       element of the URL's path is also @racket[""], then a UNC path
       is created by using the second and third elements of the path
       as the UNC root's machine and drive, respectively.}

 @item{Otherwise, the URL's path is converted to a Windows path. The
       result is an absolute path if the URL's first path element
       corresponds to a drive, otherwise the result is a relative path
       (even though URLs are not intended to represent relative paths).}

]

@history[#:changed "6.3.0.1" @elem{Changed @racket['windows] treatment
                                   of a non-@racket[""] host.}]}



@defproc[(relative-path->relative-url-string [path (and/c (or/c path-string? path-for-some-system?)
                                                          relative-path?)])
         string?]{

Converts @racket[path] to a string that parses as a relative URL (with
forward slashes). Each element of @racket[path] is an element of the
resulting URL path, and the string form of each element is encoded as
needed. If @racket[path] is syntactically a directory, then the resulting
URL ends with @litchar{/}.}


@defparam[file-url-path-convention-type kind (or/c 'unix 'windows)]{

Determines the default conversion from strings for
@racket["file"] URLs; see @racket[string->url].}


@defparam[current-url-encode-mode mode (or/c 'recommended 'unreserved)]{

Determines how @racket[url->string] encodes @litchar{!}, @litchar{*}, @litchar{'}, @litchar{(},
and @litchar{)} in path segments and fragments:
@racket['recommended] leave them as-is, while @racket['unreserved]
encodes them using @litchar{%}. The @racket['recommended] mode corresponds
to the recommendations of RFC 2396 @cite["RFC2396"], but @racket['unreserved]
avoids characters that are in some contexts mistaken for delimiters around
URLs.

Internally, @racket['recommended] mode uses
@racket[uri-path-segment-encode] and @racket[uri-encode], while
@racket['unreserved] mode uses
@racket[uri-path-segment-unreserved-encode] and
@racket[uri-unreserved-encode].}

@; ----------------------------------------

@section{URL Functions}

An HTTP connection is created as a @deftech{pure port} or a
@deftech{impure port}.  A pure port is one from which the MIME headers
have been removed, so that what remains is purely the first content
fragment. An impure port is one that still has its MIME headers.

@deftogether[(
@defproc[(get-pure-port [URL url?]
                        [header (listof string?) null]
                        [#:redirections redirections exact-nonnegative-integer? 0])
         input-port?]
@defproc[(head-pure-port [URL url?]
                         [header (listof string?) null])
         input-port?]
@defproc[(delete-pure-port [URL url?]
                           [header (listof string?) null])
         input-port?]
@defproc[(options-pure-port [URL url?]
                            [header (listof string?) null])
         input-port?]
)]{

Initiates a GET/HEAD/DELETE/OPTIONS request for @racket[URL] and returns a
@tech{pure port} corresponding to the body of the response. The
optional list of strings can be used to send header lines to the
server.

The GET method is used to retrieve whatever information is identified
by @racket[URL]. If @racket[redirections] is not @racket[0], then 
@racket[get-pure-port] will follow redirections from the server, 
up to the limit given by @racket[redirections].

The HEAD method is identical to GET, except the server must not return
a message body. The meta-information returned in a response to a HEAD
request should be identical to the information in a response to a GET
request.

The DELETE method is used to delete the entity identified by
@racket[URL].

@bold{Beware:} By default, @racket["https"] scheme handling does not
verify a server's certificate (i.e., it's equivalent of clicking
through a browser's warnings), so communication is safe, but the
identity of the server is not verified. To validate the server's
certificate, set @racket[current-https-protocol] to @racket['secure]
or a context created with @racket[ssl-secure-client-context].

The @racket["file"] scheme for URLs is handled only by
@racket[get-pure-port], which uses @racket[open-input-file], does not
handle exceptions, and ignores the optional strings.

@history[#:changed "6.1.1.8" @elem{Added @racket[options-pure-port].}]}

@deftogether[(
@defproc[(get-impure-port [URL url?]
                          [header (listof string?) null])
         input-port?]
@defproc[(head-impure-port [URL url?]
                           [header (listof string?) null])
         input-port?]
@defproc[(delete-impure-port [URL url?]
                             [header (listof string?) null])
         input-port?]
@defproc[(options-impure-port [URL url?]
                              [header (listof string?) null])
         input-port?]
)]{

Like @racket[get-pure-port], etc., but the resulting @tech{impure
port} contains both the returned headers and the body. The
@racket["file"] URL scheme is not handled by these functions.

@history[#:changed "6.1.1.8" @elem{Added @racket[options-impure-port].}]}

@deftogether[(
@defproc[(post-pure-port [URL url?]
                         [post bytes?]
                         [header (listof string?) null])
         input-port?]
@defproc[(put-pure-port [URL url?]
                        [post bytes?]
                        [header (listof string?) null])
         input-port?]
@defproc[(patch-pure-port [URL url?]
                          [post bytes?]
                          [header (listof string?) null])
         input-port?]
)]{

Initiates a POST/PUT/PATCH request for @racket[URL] and sends the
@racket[post] byte string.  The result is a @tech{pure port}, which
contains the body of the response is returned.  The optional list of
strings can be used to send header lines to the server.

@bold{Beware:} See @racket[get-pure-port] for warnings about
@racket["https"] certificate validation.}


@deftogether[(
@defproc[(post-impure-port [URL url?]
                           [post bytes?]
                           [header (listof string?) null])
         input-port?]
@defproc[(put-impure-port [URL url?]
                          [post bytes?]
                          [header (listof string?) null])
         input-port?]
@defproc[(patch-impure-port [URL url?]
                            [post bytes?]
                            [header (listof string?) null])
         input-port?]
)]{

Like @racket[post-pure-port] and @racket[put-pure-port], but the
resulting @tech{impure port} contains both the returned headers and
body.}


@defproc[(display-pure-port [in input-port?]) void?]{

Writes the output of a pure port, which is useful for debugging purposes.}


@defproc[(purify-port [in input-port?]) string?]{

Purifies a port, returning the MIME headers, plus a leading line for
the form @litchar{HTTP/}@nonterm{vers}@litchar{
}@nonterm{code}@litchar{ }@nonterm{message}, where @nonterm{vers} is
something like @litchar{1.0} or @litchar{1.1}, @nonterm{code} is an
exact integer for the response code, and @nonterm{message} is
arbitrary text without a return or newline.

The @racketmodname[net/head] library provides procedures, such as
@racket[extract-field] for manipulating the header.

Since web servers sometimes return mis-formatted replies,
@racket[purify-port] is liberal in what it accepts as a header. as a
result, the result string may be ill formed, but it will either be the
empty string, or it will be a string matching the following regexp:

@racketblock[
#rx"^HTTP/.*?(\r\n\r\n|\n\n|\r\r)"
]}

@defproc[(get-pure-port/headers
          [url url?]
          [headers (listof string?) '()]
          [#:method method (or/c #"GET" #"HEAD" #"DELETE" #"OPTIONS") #"GET"]
          [#:redirections redirections exact-nonnegative-integer? 0]
          [#:status? status? boolean? #f]
          [#:connection connection (or/c #f http-connection?)])
         (values input-port? string?)]{
  This function is an alternative to calling @racket[get-impure-port]
  (or @racket[head-impure-port], @racket[delete-impure-port], or @racket[options-impure-port])
  and @racket[purify-port] when needing to follow redirections. It also
  supports HTTP/1.1 connections, which are used when the @racket[connection]
  argument is not @racket[#f].
  
  The @racket[get-pure-port/headers] function performs a request specified by
  @racket[method] (GET by default) on @racket[url], follows up to @racket[redirections] redirections,
  and returns a port containing the data as well as the headers for
  the final connection. If @racket[status?] is true, then the status
  line is included in the result string.

  A given @racket[connection] should be used for communication
  with a particular HTTP/1.1 server, unless @racket[connection] is closed
  (via @racket[http-connection-close]) between uses for different servers.
  If @racket[connection] is provided, read all data from the result port
  before making a new request with the same @racket[connection]. (Reusing
  a @racket[connection] without reading all data may or may not work.)

@history[#:changed "7.7.0.1" @elem{Added the @racket[#:method] argument.}]}

@deftogether[(
@defproc[(http-connection? [v any/c]) boolean?]
@defproc[(make-http-connection) http-connection?]
@defproc[(http-connection-close [connection http-connection?]) void?]
)]{

A HTTP connection value represents a potentially persistent connection
with a HTTP/1.1 server for use with @racket[get-pure-port/headers].

The @racket[make-http-connection] creates a ``connection'' that is
initially unconnected. Each call to @racket[get-pure-port/headers]
leaves a connection either connected or unconnected, depending on
whether the server allows the connection to continue. The
@racket[http-connection-close] function unconnects, but it does not
prevent further use of the connection value.}


@defproc*[([(call/input-url [URL url?]
                            [connect (url? . -> . input-port?)]
                            [handle (input-port? . -> . any)])
            any]
           [(call/input-url [URL url?]
                            [connect (url? (listof string?) . -> . input-port?)]
                            [handle (input-port? . -> . any)]
                            [header (listof string?)])
            any])]{

Given a URL and a @racket[connect] procedure like
@racket[get-pure-port] to convert the URL to an input port (either a
@tech{pure port} or @tech{impure port}), calls the @racket[handle]
procedure on the port and closes the port on return. The result of the
@racket[handle] procedure is the result of @racket[call/input-url].

When a @racket[header] argument is supplied, it is passed along to the
@racket[connect] procedure.

The connection is made in such a way that the port is closed before
@racket[call/input-url] returns, no matter how it returns. In
particular, it is closed if @racket[handle] raises an exception, or if
the connection process is interrupted by an asynchronous break
exception.}

@deftogether[(
@defparam[current-proxy-servers mapping (listof (list/c string? string? (integer-in 0 65535)))]
@defthing[proxiable-url-schemes (listof string?) #:value '("http" "https" "git")]
 )]{

The @racket[current-proxy-servers] parameter determines a mapping of proxy servers used for
connections. Each mapping is a list of three elements:

@itemize[

 @item{the URL scheme, such as @racket["http"], where @racket[proxiable-url-schemes] lists the URL schemes
  that can be proxied}

 @item{the proxy server address; and}

 @item{the proxy server port number.}

]

The initial value of @racket[current-proxy-servers] is configured on
demand from environment variables. Proxies for each URL scheme are
configured from the following variables:

@itemize[

 @item{@indexed-envvar{plt_http_proxy},
@indexed-envvar{PLT_HTTP_PROXY}, @indexed-envvar{http_proxy},
@indexed-envvar{HTTP_PROXY}, @indexed-envvar{all_proxy},
and @indexed-envvar{ALL_PROXY}, configure the HTTP proxy, where the former
takes precedence over the latter. HTTP requests will be proxied using
an HTTP proxy server connection}

 @item{@indexed-envvar{plt_https_proxy},
@indexed-envvar{PLT_HTTPS_PROXY}, @indexed-envvar{https_proxy},
@indexed-envvar{HTTPS_PROXY}, @indexed-envvar{all_proxy},
@indexed-envvar{ALL_PROXY}, configure the HTTPS proxy, where the
former takes precedence over the latter. HTTPS connections are proxied
using an HTTP ``CONNECT'' tunnel}

 @item{@indexed-envvar{plt_git_proxy}, @indexed-envvar{PLT_GIT_PROXY},
@indexed-envvar{git_proxy}, @indexed-envvar{GIT_PROXY},
@indexed-envvar{all_proxy}, @indexed-envvar{ALL_PROXY}, configure the
GIT proxy, where the former takes precedence over the latter. GIT
connections are proxied using an HTTP ``CONNECT'' tunnel}

]

Each environment variable contains a single URL of the form
@litchar{http://}@nonterm{hostname}@litchar{:}@nonterm{portno}.
If any other components of the URL are provided, a warning will be logged to a @racket[net/url]
logger.

The default mapping is the empty list (i.e., no proxies).}

@defparam[current-no-proxy-servers dest-hosts-list (listof (or/c string? regexp?))]{

A parameter that determines which servers will be accessed directly,
i.e., without resort to @racket[current-proxy-servers]. It is a list of

@itemize[
         
  @item{strings that match host names exactly; and}
   
  @item{regexps that match host by pattern.}
  
]

If a proxy server is defined for a URL scheme, then the destination
host name is checked against @racket[current-no-proxy-servers]. The proxy
is used if and only if the host name does not match (by the definition
above) any in the list.

The initial value of @racket[current-no-proxy-servers] is configured on demand from the
environment variables @indexed-envvar{plt_no_proxy} and @indexed-envvar{no_proxy},
where the former takes precedence over the latter.
Each environment variable's value is parsed as a comma-separated list of ``patterns,''
where a pattern is one of:
    @margin-note{This parsing is consistent with the @litchar["no_proxy"] environment
      variable used by other software, albeit not consistent with the regexps
        stored in @racket[current-no-proxy-servers].}

@itemize[
         
  @item{a string beginning with a @litchar{.} (period): converted to a
    regexp that performs a suffix match on a destination host name;
    e.g., @litchar[".racket-lang.org"] matches destinations of
    @litchar["doc.racket-lang.org"], @litchar["pkgs.racket-lang.org"], but
    neither @litchar["doc.bracket-lang.org"] nor
    @litchar["pkgs.racket-lang.org.uk"];
  }
   
  @item{any other string: converted to a regexp that matches the string exactly.}
  
]}


@defproc[(proxy-server-for
          [url-schm string?]
          [dest-host-name (or/c #f string?) #f])
         (or/c (list/c string? string? (integer-in 0 65535)) #f)]{

Returns the proxy server entry for the combination of @racket[url-schm]
and @racket[host], or @racket[#f] if no proxy is to be used.}


@defproc[(url-exception? [x any/c])
         boolean?]{
 Identifies an error thrown by URL functions.         
}

@defproc[(http-sendrecv/url [u url?]
                            [#:method method (or/c bytes? string? symbol?) #"GET"]
                            [#:headers headers (listof (or/c bytes? string?)) empty]
                            [#:data data (or/c #f bytes? string? data-procedure/c) #f]
                            [#:content-decode decodes (listof symbol?) '(gzip deflate)])
         (values bytes? (listof bytes?) input-port?)]{

Calls @racket[http-sendrecv] using @racket[u] to populate the host, URI, port, and SSL parameters.

This function does not support proxies.
                                                      
@history[#:changed "7.6.0.9" @elem{Added support for @racket['deflate] decoding.}]}

@defproc[(tcp-or-tunnel-connect [scheme string?]
                                [host string?]
                                [port (between/c 1 65535)])
         (values input-port? output-port?)]{
 If @racket[(proxy-server-for scheme host)], then the proxy is used to
 @racket[http-conn-CONNECT-tunnel] to @racket[host] (on port @racket[port]).
 
 Otherwise the call is equivalent to @racket[(tcp-connect host port)].}

@section{URL HTTPS mode}

@defmodule[net/url-connect]

These bindings are provided by the @racketmodname[net/url-connect] library, and
used by @racketmodname[net/url].

@defparam[current-https-protocol protocol (or/c ssl-client-context? symbol?)]{

A parameter that determines the connection mode for @racket["https"]
connections; the parameter value is passed as the third argument to
@racket[ssl-connect] when creating an @racket["https"] connection.
Set this parameter to validate a server's certificates, for example,
as described with @racket[get-pure-port].}

@; ----------------------------------------

@section{URL Unit}

@margin-note{@racket[url@], @racket[url^], and @racket[url+scheme^] are deprecated.
They exist for backward-compatibility and will likely be removed in
the future. New code should use the @racketmodname[net/url] module.}

@defmodule[net/url-unit]

@defthing[url@ unit?]{

Imports @racket[tcp^], exports @racket[url+scheme^].

The @racket[url+scheme^] signature contains
@racket[current-connect-scheme], which @racket[url@] binds to a
parameter.  The parameter is set to the scheme of a URL when
@racket[tcp-connect] is called to create a connection.  A
@racket[tcp-connect] variant linked to @racket[url@] can check this
parameter to choose the connection mode; in particular, @racket[net/url]
supplies a @racket[tcp-connect] that actually uses @racket[ssl-connect]
when @racket[(current-connect-scheme)] produces @racket["https"].

Note that @racket[net/url] does not provide the
@racket[current-connect-scheme] parameter.}

@; ----------------------------------------

@section{URL Signature}

@defmodule[net/url-sig]

@defsignature[url^ ()]{

Includes everything exported by the @racketmodname[net/url] module
except @racket[current-https-protocol] and @racket[current-url-encode-mode].
Note that the exports of
@racketmodname[net/url] and the @racket[url^] signature do not include
@racket[current-connect-scheme].}

@defsignature[url+scheme^ (url^)]{

Adds @racket[current-connect-scheme] to @racket[url^].}
