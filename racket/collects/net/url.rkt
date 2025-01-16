#lang racket/base
(require racket/port
         racket/string
         racket/contract/base
         racket/list
         racket/match
         racket/promise
         racket/tcp
         (prefix-in hc: "http-client.rkt")
         (only-in "url-connect.rkt" current-https-protocol)
         "url-string.rkt"
         (only-in "url-exception.rkt" make-url-exception))

;; To do:
;;   Handle HTTP/file errors.
;;   Not throw away MIME headers.
;;     Determine file type.

(define-logger net/url)

;; ----------------------------------------------------------------------

;; Input ports have two statuses:
;;   "impure" = they have text waiting
;;   "pure" = the MIME headers have been read

(define proxiable-url-schemes '("http"
                                "https"
                                "git"))

;; Like `string->url`, but returns #f for an error, intended for use
;; with pattern matching.
(define (string->url* str)
  (with-handlers ([url-exception? (lambda (exn) #f)])
    (string->url str)))

;; env->c-p-s-entries: (listof (listof string)) -> (listof (list string string num))
;;
;; "http" protocol is proxied by http proxy
;; other ("https" and "git") protocols are proxied by http CONNECT tunneling
;;
;; proxying-scheme is therefore always "http" (no "s") -- although the meaning thereof depends on the
;; proxied-scheme
(define (env->c-p-s-entries . envarses)
  (define (in1 proxied-scheme envvar)
    (match (let ([s (getenv envvar)])
             (and s (string-trim s)))
      [#f #f]
      ["" null]
      [(app string->url*
            (url (and proxying-scheme "http") #f (? string? host) (? integer? port)
                 _ (list) (list) #f))
       (list (list proxied-scheme host port))]
      [(app string->url*
            (url (and proxying-scheme "http") _ (? string? host) (? integer? port)
                 _ _ _ _))
       (log-net/url-warning "~s contains somewhat invalid proxy URL format" envvar)
       (list (list proxied-scheme host port))]
      [inv
       (log-net/url-error "~s contained invalid proxy URL format: ~s" envvar inv)
       null]))
  (define (inr proxied-scheme envars)
    (match envars
      ['() null]
      [(cons envvar more-envars)
       (or (in1 proxied-scheme envvar)
           (in1 proxied-scheme (string-upcase envvar))
           (inr proxied-scheme more-envars))]))
  (define (inrs spec)
    (inr (first spec) (rest spec)))
  (append-map inrs envarses))

(define current-proxy-servers-promise
  (make-parameter
   (delay/sync
    (env->c-p-s-entries
     '("http" "plt_http_proxy" "http_proxy" "all_proxy")
     '("https" "plt_https_proxy" "https_proxy" "all_proxy")
     '("git" "plt_git_proxy" "git_proxy" "all_proxy")))))

(define (proxy-servers-guard v)
  (unless (and (list? v)
               (andmap (lambda (v)
                         (and (list? v)
                              (= 3 (length v))
                              (member (car v) proxiable-url-schemes)
                              (string? (car v))
                              (exact-integer? (caddr v))
                              (<= 1 (caddr v) 65535)))
                       v))
    (raise-type-error
     'current-proxy-servers
     "list of list of scheme, string, and exact integer in [1,65535]"
     v))
  (map (lambda (v)
         (list (string->immutable-string (car v))
               (string->immutable-string (cadr v))
               (caddr v)))
       v))

(define current-proxy-servers
  (make-derived-parameter current-proxy-servers-promise
                          proxy-servers-guard
                          force))

(define (env->n-p-s-entries envars)
  (if (null? envars)
      null
      (match (getenv (car envars))
        [#f (env->n-p-s-entries (cdr envars))]
        ["" null]
        [hostnames (string-split hostnames ",")])))
  
(define current-no-proxy-servers-promise
  (make-parameter (delay/sync (no-proxy-servers-guard
                                (env->n-p-s-entries '("plt_no_proxy" "no_proxy"))))))

(define (no-proxy-servers-guard v)
  (unless (and (list? v)
               (andmap (lambda (v)
                         (or (string? v)
                             (regexp? v)))
                       v))
    (raise-type-error 'current-no-proxy-servers
                      "list of string or regexp"
                      v))
  (map (match-lambda
         [(? regexp? re) re]
         [(regexp "^(\\..*)$" (list _ m))
          (regexp (string-append ".*" (regexp-quote m)))]
         [(? string? s) (regexp (string-append "^"(regexp-quote s)"$"))])
       v))

(define current-no-proxy-servers
  (make-derived-parameter current-no-proxy-servers-promise
                          no-proxy-servers-guard
                          force))

(define (proxy-server-for url-schm (dest-host-name #f))
  (let ((rv (assoc url-schm (current-proxy-servers))))
    (cond [(not dest-host-name) rv]
          [(memf (lambda (np) (regexp-match np dest-host-name)) (current-no-proxy-servers)) #f]
          [else rv])))

;; proxy-tunneled? : url -> boolean
(define (proxy-tunneled? url)
  (not (string=? (url-scheme url) "http")))

(define (url-error fmt . args)
  (raise (make-url-exception
          (apply format fmt
                 (map (lambda (arg) (if (url? arg) (url->string arg) arg))
                      args))
          (current-continuation-marks))))

;; url->default-port : url -> num
(define (url->default-port url)
  (let ([scheme (url-scheme url)])
    (cond [(not scheme) 80]
          [(string=? scheme "http") 80]
          [(string=? scheme "https") 443]
          [(string=? scheme "git") 9418]
          [else (url-error "URL scheme ~s not supported" scheme)])))

;; make-ports : url -> hc
(define (make-ports url proxy)
  (cond
    [(not proxy)
     (let ([target-port-number (or (url-port url) (url->default-port url))]
           [target-host (url-host url)])
       (hc:http-conn-open target-host
                          #:port target-port-number
                          #:ssl? (if (equal? "https" (url-scheme url))
                                   (current-https-protocol)
                                   #f)))]
    [(proxy-tunneled? url)
     (let ([proxy-port-number (caddr proxy)]
           [proxy-host (cadr proxy)])
       (define-values (tnl:ssl? tnl:from-port tnl:to-port tnl:abandon-p)
         (hc:http-conn-CONNECT-tunnel proxy-host
                                      proxy-port-number
                                      (url-host url)
                                      (or (url-port url) (url->default-port url))
                                      #:ssl? (if (equal? "https" (url-scheme url))
                                               (current-https-protocol)
                                               #f)))
       (hc:http-conn-open (url-host url)
                          #:port (or (url-port url) (url->default-port url))
                          #:ssl? (list tnl:ssl? tnl:from-port tnl:to-port tnl:abandon-p)))]
    [else 
      (let ([proxy-port-number (caddr proxy)]
            [proxy-host (cadr proxy)])
        (hc:http-conn-open proxy-host
                           #:port proxy-port-number
                           #:ssl? (if (equal? "https" (url-scheme url))
                                    (current-https-protocol)
                                    #f)))]))

;; http://getpost-impure-port : bool x url x union (str, #f) x list (str)
;;                               -> hc
(define (http://getpost-impure-port get? url post-data strings
                                    make-ports 1.1?)
  (define proxy (proxy-server-for (url-scheme url) (url-host url)))
  (define hc (make-ports url proxy))
  (define access-string
    (ensure-non-empty
     (url->string
      (if (and proxy (not (proxy-tunneled? url)))
          url
          ;; RFCs 1945 and 2616 say:
          ;;   Note that the absolute path cannot be empty; if none is present in
          ;;   the original URI, it must be given as "/" (the server root).
          (let-values ([(abs? path)
                        (if (null? (url-path url))
                            (values #t (list (make-path/param "" '())))
                            (values (url-path-absolute? url) (url-path url)))])
            (make-url #f #f #f #f abs? path (url-query url) (url-fragment url)))))))

  (hc:http-conn-send! hc access-string
                      #:method (if get? #"GET" #"POST")
                      #:headers strings
                      #:content-decode '()
                      #:data post-data)
  hc)

;; file://get-pure-port : url -> in-port
(define (file://get-pure-port url)
  (open-input-file (file://->path url)))

(define (schemeless-url url)
  (url-error "Missing protocol (usually \"http:\") at the beginning of URL: ~a" url))

;; getpost-impure-port : bool x url x list (str) -> in-port
(define (getpost-impure-port get? url post-data strings)
  (let ([scheme (url-scheme url)])
    (cond [(not scheme)
           (schemeless-url url)]
          [(or (string=? scheme "http") (string=? scheme "https"))
           (define hc
             (http://getpost-impure-port get? url post-data strings make-ports #f))
           (http-conn-impure-port hc
                                  #:method (if get? "GET" "POST"))]
          [(string=? scheme "file")
           (url-error "There are no impure file: ports")]
          [else (url-error "Scheme ~a unsupported" scheme)])))

(define (http-conn-impure-port hc
                               #:method [method-bss #"GET"])
  (define-values (in out) (make-pipe 4096))
  (define-values (status headers response-port)
    (hc:http-conn-recv! hc #:method method-bss #:close? #t #:content-decode '()))
  (thread
   (λ ()
     (fprintf out "~a\r\n" status)
     (for ([h (in-list headers)])
       (fprintf out "~a\r\n" h))
     (fprintf out "\r\n")
     (copy-port response-port out)
     (close-output-port out)))
  in)

;; get-impure-port : url [x list (str)] -> in-port
(define (get-impure-port url [strings '()])
  (getpost-impure-port #t url #f strings))

;; post-impure-port : url x bytes [x list (str)] -> in-port
(define (post-impure-port url post-data [strings '()])
  (getpost-impure-port #f url post-data strings))

;; getpost-pure-port : bool x url x list (str) -> in-port
(define (getpost-pure-port get? url post-data strings redirections)
  (let ([scheme (url-scheme url)])
    (cond [(not scheme)
           (schemeless-url url)]
          [(or (string=? scheme "http")
               (string=? scheme "https"))
           (cond
             [(or (not get?)
                  ;; do not follow redirections for POST
                  (zero? redirections))
              (define-values (status headers response-port)
                (hc:http-conn-recv!
                 (http://getpost-impure-port
                  get? url post-data strings
                  make-ports #f)
                 #:method (if get? #"GET" #"POST")
                 #:content-decode '()
                 #:close? #t))
              response-port]
             [else
              (define-values (port header)
                (get-pure-port/headers url strings #:redirections redirections))
              port])]
          [(string=? scheme "file")
           (file://get-pure-port url)]
          [else (url-error "Scheme ~a unsupported" scheme)])))

(define (make-http-connection)
  (hc:http-conn))

(define (http-connection-close hc)
  (hc:http-conn-close! hc))

(define (get-pure-port/headers url [strings '()]
                               #:method [method #"GET"]
                               #:redirections [redirections 0]
                               #:status? [status? #f]
                               #:connection [conn #f])
  (let redirection-loop ([redirections redirections] [url url] [use-conn conn])
    (define hc
      (http://getpost-impure-port #t url #f strings
                                  (if (and use-conn
                                           (hc:http-conn-live? use-conn))
                                    (lambda (url proxy)
                                      (log-net/url-debug "reusing connection")
                                      use-conn)
                                    make-ports)
                                  (and conn #t)))
    (define-values (status headers response-port)
      (hc:http-conn-recv! hc #:method method #:close? (not conn) #:content-decode '()))

    (define new-url
      (ormap (λ (h)
               (match (regexp-match #rx#"^(?i:Location): (.*)$" h)
                 [#f #f]
                 [(list _ m1b)
                  (define m1 (bytes->string/utf-8 m1b))
                  (with-handlers ((exn:fail? (λ (x) #f)))
                    (define next-url (string->url m1))
                    (make-url
                     (or (url-scheme next-url) (url-scheme url))
                     (or (url-user next-url) (url-user url))
                     (or (url-host next-url) (url-host url))
                     (or (url-port next-url) (url-port url))
                     (url-path-absolute? next-url)
                     (url-path next-url)
                     (url-query next-url)
                     (url-fragment next-url)))]))
             headers))
    (define redirection-status-line?
      (regexp-match #rx#"^HTTP/[0-9]+[.][0-9]+ 3[0-9][0-9]" status))
    (cond
      [(and redirection-status-line? new-url (not (zero? redirections)))
       (log-net/url-info "redirection: ~a" (url->string new-url))
       (redirection-loop (- redirections 1) new-url #f)]
      [else
       (values response-port
               (string-append (apply string-append
                                     (map (λ (x) (format "~a\r\n" x))
                                          (if status?
                                              (cons status headers)
                                              headers)))
                              "\r\n"))])))

;; get-pure-port : url [x list (str)] -> in-port
(define (get-pure-port url [strings '()] #:redirections [redirections 0])
  (getpost-pure-port #t url #f strings redirections))

;; post-pure-port : url bytes [x list (str)] -> in-port
(define (post-pure-port url post-data [strings '()])
  (getpost-pure-port #f url post-data strings 0))

;; display-pure-port : in-port -> ()
(define (display-pure-port server->client)
  (copy-port server->client (current-output-port))
  (close-input-port server->client))

;; call/input-url : url x (url -> in-port) x (in-port -> T)
;;                  [x list (str)] -> T
(define call/input-url
  (let ([handle-port
         (lambda (server->client handler)
           (dynamic-wind (lambda () 'do-nothing)
               (lambda () (handler server->client))
               (lambda () (close-input-port server->client))))])
    (case-lambda
      [(url getter handler)
       (handle-port (getter url) handler)]
      [(url getter handler params)
       (handle-port (getter url params) handler)])))

;; purify-port : in-port -> header-string
(define (purify-port port)
  (let ([m (regexp-match-peek-positions
            #rx"^HTTP/.*?(?:\r\n\r\n|\n\n|\r\r)" port)])
    (if m (read-string (cdar m) port) "")))

;; purify-http-port : in-port -> in-port
(define (purify-http-port in-port)
  (purify-port in-port)
  in-port)

;; delete-pure-port : url [x list (str)] -> in-port
(define (delete-pure-port url [strings '()])
  (method-pure-port 'delete url #f strings))

;; delete-impure-port : url [x list (str)] -> in-port
(define (delete-impure-port url [strings '()])
  (method-impure-port 'delete url #f strings))

;; head-pure-port : url [x list (str)] -> in-port
(define (head-pure-port url [strings '()])
  (method-pure-port 'head url #f strings))

;; head-impure-port : url [x list (str)] -> in-port
(define (head-impure-port url [strings '()])
  (method-impure-port 'head url #f strings))

;; put-pure-port : url bytes [x list (str)] -> in-port
(define (put-pure-port url put-data [strings '()])
  (method-pure-port 'put url put-data strings))

;; put-impure-port : url x bytes [x list (str)] -> in-port
(define (put-impure-port url put-data [strings '()])
  (method-impure-port 'put url put-data strings))

;; patch-pure-port : url bytes [x list (str)] -> in-port
(define (patch-pure-port url patch-data [strings '()])
  (method-pure-port 'patch url patch-data strings))

;; patch-impure-port : url x bytes [x list (str)] -> in-port
(define (patch-impure-port url patch-data [strings '()])
  (method-impure-port 'patch url patch-data strings))

;; options-pure-port : url [x list (str)] -> in-port
(define (options-pure-port url [strings '()])
  (method-pure-port 'options url #f strings))

;; options-impure-port : url [x list (str)] -> in-port
(define (options-impure-port url [strings '()])
  (method-impure-port 'options url #f strings))

;; method-impure-port : symbol x url x list (str) -> in-port
(define (method-impure-port method url data strings)
  (let ([scheme (url-scheme url)])
    (cond [(not scheme)
           (schemeless-url url)]
          [(or (string=? scheme "http") (string=? scheme "https"))
           (http://method-impure-port method url data strings)]
          [(string=? scheme "file")
           (url-error "There are no impure file: ports")]
          [else (url-error "Scheme ~a unsupported" scheme)])))

;; method-pure-port : symbol x url x list (str) -> in-port
(define (method-pure-port method url data strings)
  (let ([scheme (url-scheme url)])
    (cond [(not scheme)
           (schemeless-url url)]
          [(or (string=? scheme "http") (string=? scheme "https"))
           (let ([port (http://method-impure-port
                        method url data strings)])
             (purify-http-port port))]
          [(string=? scheme "file")
           (file://get-pure-port url)]
          [else (url-error "Scheme ~a unsupported" scheme)])))

;; http://method-impure-port : symbol x url x union (str, #f) x list (str) -> in-port
(define (http://method-impure-port method url data strings)
  (let* ([method (case method
                   [(get) "GET"] [(post) "POST"] [(head) "HEAD"]
                   [(put) "PUT"] [(patch) "PATCH"] [(delete) "DELETE"]
                   [(options) "OPTIONS"]
                   [else (url-error "unsupported method: ~a" method)])]
         [proxy (proxy-server-for (url-scheme url) (url-host url))]
         [hc (make-ports url proxy)]
         [access-string
          (ensure-non-empty
           (url->string
            (if (and proxy (not (proxy-tunneled? url)))
                url
                (make-url #f #f #f #f
                          (url-path-absolute? url)
                          (url-path url)
                          (url-query url)
                          (url-fragment url)))))])
    (hc:http-conn-send! hc access-string
                        #:method method
                        #:headers strings
                        #:content-decode '()
                        #:data data)
    (http-conn-impure-port hc
                           #:method method)))

(define (ensure-non-empty s)
  (if (string=? "" s)
      "/"
      s))

(provide (all-from-out "url-string.rkt"))

(provide/contract
 (get-pure-port (->* (url?) ((listof string?) #:redirections exact-nonnegative-integer?) input-port?))
 (get-impure-port (->* (url?) ((listof string?)) input-port?))
 (post-pure-port (->* (url? (or/c false/c bytes?)) ((listof string?)) input-port?))
 (post-impure-port (->* (url? bytes?) ((listof string?)) input-port?))
 (head-pure-port (->* (url?) ((listof string?)) input-port?))
 (head-impure-port (->* (url?) ((listof string?)) input-port?))
 (delete-pure-port (->* (url?) ((listof string?)) input-port?))
 (delete-impure-port (->* (url?) ((listof string?)) input-port?))
 (put-pure-port (->* (url? (or/c false/c bytes?)) ((listof string?)) input-port?))
 (put-impure-port (->* (url? bytes?) ((listof string?)) input-port?))
 (patch-pure-port (->* (url? (or/c false/c bytes?)) ((listof string?)) input-port?))
 (patch-impure-port (->* (url? bytes?) ((listof string?)) input-port?))
 (options-pure-port (->* (url?) ((listof string?)) input-port?))
 (options-impure-port (->* (url?) ((listof string?)) input-port?))
 (display-pure-port (input-port? . -> . void?))
 (purify-port (input-port? . -> . string?))
 (get-pure-port/headers (->* (url?)
                             ((listof string?)
                              #:method (or/c #"GET" #"HEAD" #"DELETE" #"OPTIONS")
                              #:redirections exact-nonnegative-integer?
                              #:status? boolean?
                              #:connection (or/c #f hc:http-conn?))
                             (values input-port? string?)))
 (rename hc:http-conn? http-connection? (any/c . -> . boolean?))
 (make-http-connection (-> hc:http-conn?))
 (http-connection-close (hc:http-conn? . -> . void?))
 (call/input-url (case-> (-> url?
                             (-> url? input-port?)
                             (-> input-port? any)
                             any)
                         (-> url?
                             (-> url? (listof string?) input-port?)
                             (-> input-port? any)
                             (listof string?)
                             any)))
 (current-proxy-servers
  (parameter/c (or/c false/c (listof (list/c string? string? number?)))))
 (current-no-proxy-servers
  (parameter/c (or/c false/c (listof (or/c string? regexp?)))))
 (proxy-server-for (->* (string?) ((or/c false/c string?))
                        (or/c false/c (list/c string? string? number?))))
 (proxiable-url-schemes (listof string?)))

(define (http-sendrecv/url u
                           #:method [method-bss #"GET"]
                           #:headers [headers-bs empty]
                           #:data [data #f]
                           #:content-decode [decodes '(gzip deflate)])
  (unless (member (url-scheme u) '(#f "http" "https"))
    (error 'http-sendrecv/url "URL scheme ~e not supported" (url-scheme u)))
  (define ssl?
    (equal? (url-scheme u) "https"))
  (define port
    (or (url-port u)
        (if ssl?
          443
          80)))
  (unless (url-host u)
    (error 'http-sendrecv/url "Host required: ~e" u))
  (hc:http-sendrecv
   (url-host u)
   (ensure-non-empty
    (url->string
     (make-url #f #f #f #f
               (url-path-absolute? u)
               (url-path u)
               (url-query u)
               (url-fragment u))))
   #:ssl?
   (if (equal? "https" (url-scheme u))
     (current-https-protocol)
     #f)
   #:port port
   #:method method-bss
   #:headers headers-bs
   #:data data
   #:content-decode decodes))

(provide
 (contract-out
  [http-sendrecv/url
   (->* (url?)
        (#:method (or/c bytes? string? symbol?)
                  #:headers (listof (or/c bytes? string?))
                  #:data (or/c false/c bytes? string? hc:data-procedure/c)
                  #:content-decode (listof symbol?))
        (values bytes? (listof bytes?) input-port?))]))

;; tcp-or-tunnel-connect : string string number -> (values input-port? output-port?)
(define (tcp-or-tunnel-connect scheme host port)
  (match (proxy-server-for scheme host)
         [(list _ proxy-host proxy-port)
          (define-values (t:ssl-ctx t:from t:to t:abandon-p)
            (hc:http-conn-CONNECT-tunnel proxy-host proxy-port host port #:ssl? #f))
          (values t:from t:to)]
         [_ (tcp-connect host port)]))

(provide
 (contract-out
  [tcp-or-tunnel-connect
   (-> string? string? (between/c 1 65535)
       (values input-port? output-port?))]))
