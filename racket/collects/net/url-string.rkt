#lang racket/base

(require racket/contract/base
         racket/list
         racket/string
         "uri-codec.rkt"
         "url-exception.rkt"
         "url-structs.rkt")

;; To do:
;;   Handle HTTP/file errors.
;;   Not throw away MIME headers.
;;     Determine file type.

(define-logger net/url)

;; ----------------------------------------------------------------------

;; Input ports have two statuses:
;;   "impure" = they have text waiting
;;   "pure" = the MIME headers have been read

(define file-url-path-convention-type (make-parameter (system-path-convention-type)))

(define (url-error fmt . args)
  (raise (make-url-exception
          (apply format fmt
                 (map (lambda (arg) (if (url? arg) (url->string arg) arg))
                      args))
          (current-continuation-marks))))

(define (url->string url)
  (let ([scheme (url-scheme url)]
        [user   (url-user url)]
        [host   (url-host url)]
        [port   (url-port url)]
        [path   (url-path url)]
        [query  (url-query url)]
        [fragment (url-fragment url)]
        [sa list]
        [sa* (lambda (l)
               (apply string-append
                      (let loop ([l l])
                        (cond
                          [(null? l) l]
                          [(pair? (car l))
                           (append (loop (car l))
                                   (loop (cdr l)))]
                          [(null? (car l)) (loop (cdr l))]
                          [else (cons (car l) (loop (cdr l)))]))))])
    (when (and (equal? scheme "file")
               (not (url-path-absolute? url)))
      (raise-mismatch-error 'url->string
                            "cannot convert relative file URL to a string: "
                            url))
    (when (and (or user host port)
               (pair? path)
               (not (url-path-absolute? url)))
      (raise-mismatch-error 'url->string
                            "cannot convert relative URL with authority to a string: "
                            url))
    (sa*
     (append
      (if scheme (sa scheme ":") null)
      (if (or user host port)
        (sa "//"
            (if user (sa (uri-userinfo-encode user) "@") null)
            (if host
                (if (regexp-match? rx:ipv6-hex host)
                    (sa "[" host "]")
                    host)
                null)
            (if port (sa ":" (number->string port)) null))
        (if (equal? "file" scheme) ; always need "//" for "file" URLs
          '("//")
          null))
      (combine-path-strings (url-path-absolute? url) path)
      ;; (if query (sa "?" (uri-encode query)) "")
      (if (null? query) null (sa "?" (alist->form-urlencoded query)))
      (if fragment (sa "#" (uri-encode* fragment)) null)))))

;; transliteration of code in rfc 3986, section 5.2.2
(define (combine-url/relative Base string)
  (let ([R (string->url string)]
        [T (make-url #f #f #f #f #f '() '() #f)])
    (if (url-scheme R)
      (begin
        (set-url-scheme! T (url-scheme R))
        (set-url-user! T (url-user R))  ;; authority
        (set-url-host! T (url-host R))  ;; authority
        (set-url-port! T (url-port R))  ;; authority
        (set-url-path-absolute?! T (url-path-absolute? R))
        (set-url-path! T (remove-dot-segments (url-path R)))
        (set-url-query! T (url-query R)))
      (begin
        (if (url-host R)  ;; => authority is defined
          (begin
            (set-url-user! T (url-user R))  ;; authority
            (set-url-host! T (url-host R))  ;; authority
            (set-url-port! T (url-port R))  ;; authority
            (set-url-path-absolute?! T (url-path-absolute? R))
            (set-url-path! T (remove-dot-segments (url-path R)))
            (set-url-query! T (url-query R)))
          (begin
            (if (null? (url-path R)) ;; => R has empty path
              (begin
                (set-url-path-absolute?! T (url-path-absolute? Base))
                (set-url-path! T (url-path Base))
                (if (not (null? (url-query R)))
                  (set-url-query! T (url-query R))
                  (set-url-query! T (url-query Base))))
              (begin
                (cond
                  [(url-path-absolute? R)
                   (set-url-path-absolute?! T #t)
                   (set-url-path! T (remove-dot-segments (url-path R)))]
                  [(and (null? (url-path Base))
                        (url-host Base))
                   (set-url-path-absolute?! T #t)
                   (set-url-path! T (remove-dot-segments (url-path R)))]
                  [else
                   (set-url-path-absolute?! T (url-path-absolute? Base))
                   (set-url-path! T (remove-dot-segments
                                     (append (all-but-last (url-path Base))
                                             (url-path R))))])
                (set-url-query! T (url-query R))))
            (set-url-user! T (url-user Base))   ;; authority
            (set-url-host! T (url-host Base))   ;; authority
            (set-url-port! T (url-port Base)))) ;; authority
        (set-url-scheme! T (url-scheme Base))))
    (set-url-fragment! T (url-fragment R))
    T))

(define (all-but-last lst)
  (cond [(null? lst) null]
        [(null? (cdr lst)) null]
        [else (cons (car lst) (all-but-last (cdr lst)))]))

;; cribbed from 5.2.4 in rfc 3986
;; the strange [*] cases implicitly change urls
;; with paths segments "." and ".." at the end
;; into "./" and "../" respectively
(define (remove-dot-segments path)
  (let loop ([path path] [result '()])
    (if (null? path)
      (reverse result)
      (let ([fst (path/param-path (car path))]
            [rst (cdr path)])
        (loop rst
              (cond
                [(and (eq? fst 'same) (null? rst))
                 (cons (make-path/param "" '()) result)] ; [*]
                [(eq? fst 'same)
                 result]
                [(and (eq? fst 'up) (null? rst) (not (null? result)))
                 (cons (make-path/param "" '()) (cdr result))] ; [*]
                [(and (eq? fst 'up) (not (null? result)))
                 (cdr result)]
                [(and (eq? fst 'up) (null? result))
                 ;; when we go up too far, just drop the "up"s.
                 result]
                [else
                 (cons (car path) result)]))))))

;; netscape/string->url : str -> url
(define (netscape/string->url string)
  (let ([url (string->url string)])
    (cond [(url-scheme url) url]
          [(string=? string "")
           (url-error "can't resolve empty string as URL")]
          [else (set-url-scheme! url
                                 (if (char=? (string-ref string 0) #\/) "file" "http"))
                url])))

;; Approximation to IPv6 literal addresses, to be recognized
;; in "[...]" when decoding and put back in "[...]" when encoding;
;; having at least one ":" distinguishes from other address forms:
(define ipv6-hex "[0-9a-fA-F:]*:[0-9a-fA-F:]*")
(define rx:ipv6-hex (regexp (string-append "^" ipv6-hex "$")))

;; URL parsing regexp
;; this is roughly following the regexp in Appendix B of rfc 3986, except for using
;; `*' instead of `+' for the scheme part (it is checked later anyway, and
;; we don't want to parse it as a path element), and the user@host:port is
;; parsed here.
(define url-regexp
  (regexp (string-append
           "^"
           "(?:"              ; / scheme-colon-opt
           "([^:/?#]*)"       ; | #1 = scheme-opt
           ":)?"              ; \
           "(?://"            ; / slash-slash-authority-opt
           "(?:"              ; | / user-at-opt
           "([^/?#@]*)"       ; | | #2 = user-opt
           "@)?"              ; | \
           "(?:"              ;
           "(?:\\["           ; | / #3 = ipv6-host-opt
           "(" ipv6-hex ")"   ; | | hex-addresses
           "\\])|"            ; | \
           "([^/?#:]*)"       ; | #4 = host-opt
           ")?"               ;
           "(?::"             ; | / colon-port-opt
           "([0-9]*)"         ; | | #5 = port-opt
           ")?"               ; | \
           ")?"               ; \
           "([^?#]*)"         ; #6 = path
           "(?:\\?"           ; / question-query-opt
           "([^#]*)"          ; | #7 = query-opt
           ")?"               ; \
           "(?:#"             ; / hash-fragment-opt
           "(.*)"             ; | #8 = fragment-opt
           ")?"               ; \
           "$")))

;; string->url : str -> url
;; Original version by Neil Van Dyke
(define (string->url str)
  (apply
   (lambda (scheme user ipv6host host port path query fragment)
     (when (and scheme (not (regexp-match? #rx"^[a-zA-Z][a-zA-Z0-9+.-]*$"
                                           scheme)))
       (url-error "invalid URL string; bad scheme\n  scheme: ~e\n  in: ~e" scheme str))
     ;; Windows => "file://xxx:/...." specifies a "xxx:/..." path
     (let ([win-file? (and (or (equal? "" port) (not port))
                           (equal? "file" (and scheme (string-downcase scheme)))
                           (eq? 'windows (file-url-path-convention-type))
                           (not (equal? host ""))
                           (or (regexp-match? "^[fF][iI][lL][eE]://[a-zA-Z]:" str)
                               (regexp-match? "^[fF][iI][lL][eE]:\\\\" str)))])
       (when win-file?
         (set! path (cond [(equal? "" port) (string-append host ":" path)]
                          [(and path host) (string-append host "/" path)]
                          [else (or path host)]))
         (set! port #f)
         (set! host ""))
       (define win-file-url (and win-file?
                                 (path->url (bytes->path (string->bytes/utf-8 path) 'windows))))
       (let* ([scheme   (and scheme (string-downcase scheme))]
              [host     (cond  [win-file-url (url-host win-file-url)]
                               [ipv6host (and ipv6host (string-downcase ipv6host))]
                               [else (and host (string-downcase host))])]
              [user     (uri-decode/maybe user)]
              [port     (and port (string->number port))]
              [abs?     (or (equal? "file" scheme)
                            (regexp-match? #rx"^/" path))]
              [use-abs? (or abs?
                            ;; If an authority part is provided, the (empty) path must be
                            ;; absolute, even if it isn't written with a "/":
                            (and (or host user port) #t))]
              [path     (if win-file?
                            (url-path win-file-url)
                            (separate-path-strings path))]
              [query    (if query (form-urlencoded->alist query) '())]
              [fragment (uri-decode/maybe fragment)])
         (when (and (not abs?) (pair? path) host)
           (url-error (string-append "invalid URL string;\n"
                                     " host provided with non-absolute path (i.e., missing a slash)\n"
                                     "  in: ~e")
                      str))
         (make-url scheme user host port use-abs? path query fragment))))
   (cdr (regexp-match url-regexp str))))

(define (uri-decode/maybe f) (friendly-decode/maybe f uri-decode))

(define (friendly-decode/maybe f uri-decode)
  ;; If #f, and leave unmolested any % that is followed by hex digit
  ;; if a % is not followed by a hex digit, replace it with %25
  ;; in an attempt to be "friendly"
  (and f (uri-decode (regexp-replace* #rx"%([^0-9a-fA-F])" f "%25\\1"))))

;; separate-path-strings : string[starting with /] -> (listof path/param)
(define (separate-path-strings str)
  (let ([strs (regexp-split #rx"/" str)])
    (map separate-params (if (string=? "" (car strs)) (cdr strs) strs))))

(define (separate-params s)
  (let ([lst (map path-segment-decode
                  (regexp-split
                   (if (memq (current-alist-separator-mode) '(semi semi-or-amp))
                       #rx";"
                       #rx"&")
                   s))])
    (make-path/param (car lst) (cdr lst))))

(define (path-segment-decode p)
  (cond [(string=? p "..") 'up]
        [(string=? p ".") 'same]
        [else (uri-path-segment-decode p)]))

(define (path-segment-encode p)
  (cond [(eq?    p 'up)   ".."]
        [(eq?    p 'same) "."]
        [(equal? p "..")  "%2e%2e"]
        [(equal? p ".")   "%2e"]
        [else (uri-path-segment-encode* p)]))

(define (combine-path-strings absolute? path/params)
  (cond [(null? path/params) null]
        [else (let ([p (add-between (map join-params path/params) "/")])
                (if (and absolute? (pair? p)) (cons "/" p) p))]))

(define (join-params s)
  (if (null? (path/param-param s))
    (path-segment-encode (path/param-path s))
    (string-join (map path-segment-encode
                      (cons (path/param-path s) (path/param-param s)))
                 ";")))

(define (path->url path)
  (let* ([spath (simplify-path path #f)]
         [dir? (let-values ([(b n dir?) (split-path spath)]) dir?)]
         ;; If original path is a directory the resulting URL
         ;; should have a trailing forward slash
         [url-tail (if dir? (list (make-path/param "" null)) null)]
         [host+url-path
          (let loop ([path spath][accum null])
            (let-values ([(base name dir?) (split-path path)])
              (cond
                [(not base)
                 (if (eq? (path-convention-type path) 'windows)
                   ;; For Windows, massage the root:
                   (append (map
                            (lambda (s)
                              (make-path/param s null))
                            (let ([s (regexp-replace
                                      #rx"[/\\\\]$"
                                      (bytes->string/utf-8 (path->bytes name))
                                      "")])
                              (cond
                                [(regexp-match? #rx"^\\\\\\\\[?]\\\\[a-zA-Z]:" s)
                                 ;; \\?\<drive>: path:
                                 (cons "" (regexp-split #rx"[/\\]+" (substring s 4)))]
                                [(regexp-match? #rx"^\\\\\\\\[?]\\\\UNC" s)
                                 ;; \\?\ UNC path:
                                 (cons "" (regexp-split #rx"[/\\]+" (substring s 7)))]
                                [(regexp-match? #rx"^[/\\]" s)
                                 ;; UNC path:
                                 (cdr (regexp-split #rx"[/\\]+" s))]
                                [else
                                 (list "" s)])))
                           accum)
                   ;; On other platforms, we drop the root:
                   (cons "" accum))]
                [else
                 (let ([accum (cons (make-path/param
                                     (if (symbol? name)
                                       name
                                       (bytes->string/utf-8
                                        (path-element->bytes name)))
                                     null)
                                    accum)])
                   (if (eq? base 'relative)
                     (cons "" accum)
                     (loop base accum)))])))]
         [host (let ([h (car host+url-path)])
                 (if (path/param? h)
                     (path/param-path h)
                     h))]
         [url-path (cdr host+url-path)])
  (make-url "file" #f host #f (absolute-path? path)
              (if (null? url-tail) url-path (append url-path url-tail))
              '() #f)))

(define (file://->path url [kind (system-path-convention-type)])
  (let ([strs (map path/param-path (url-path url))]
        [string->path-element/same
         (lambda (e)
           (if (symbol? e)
             e
             (if (string=? e "")
               'same
               (bytes->path-element (string->bytes/locale e) kind))))]
        [string->path/win (lambda (s)
                            (bytes->path (string->bytes/utf-8 s) 'windows))])
    (if (and (url-path-absolute? url)
             (eq? 'windows kind))
      ;; If initial path is "", then build UNC path.
      ;; Also build a UNC path if the host is non-#f.
      (cond
        [(not (url-path-absolute? url))
         (apply build-path (map string->path-element/same strs))]
        [(and ((length strs) . >= . 3)
              (equal? (car strs) ""))
         (apply build-path
                (string->path/win
                 (string-append "\\\\" (cadr strs) "\\" (caddr strs) "\\"))
                (map string->path-element/same (cdddr strs)))]
        [(and (url-host url)
              (not (equal? (url-host url) ""))
              (pair? strs))
         (if (equal? (car strs) "")
             (error 'file://->path "empty drive element: ~e" url)
             (apply build-path
                    (string->path/win
                     (string-append "\\\\" (url-host url) "\\" (car strs) "\\"))
                    (map string->path-element/same (cdr strs))))]
        [(pair? strs)
         (apply build-path (string->path/win (car strs))
                (map string->path-element/same (cdr strs)))]
        [else (error 'file://->path "no path elements: ~e" url)])
      (let ([elems (map string->path-element/same strs)])
        (if (url-path-absolute? url)
          (apply build-path (bytes->path #"/" 'unix) elems)
          (apply build-path elems))))))

(define (url->path url [kind (system-path-convention-type)])
  (file://->path url kind))

(define (relative-path->relative-url-string path)
  (define s (string-join (for/list ([e (in-list (explode-path path))])
                           (cond
                            [(eq? e 'same) "."]
                            [(eq? e 'up) ".."]
                            [else
                             (uri-encode* (path-element->string e))]))
                         "/"))
  ;; Add "/" to reflect directory-ness:
  (let-values ([(base name dir?) (split-path path)])
    (if dir?
        (string-append s "/")
        s)))

(define current-url-encode-mode (make-parameter 'recommended))

(define (uri-encode* str)
  (case (current-url-encode-mode)
    [(unreserved) (uri-unreserved-encode str)]
    [(recommended) (uri-encode str)]))

(define (uri-path-segment-encode* str)
  (case (current-url-encode-mode)
    [(unreserved) (uri-path-segment-unreserved-encode str)]
    [(recommended) (uri-path-segment-encode str)]))

(provide (struct-out url) (struct-out path/param))

(provide/contract
 (url-regexp regexp?)
 (string->url (-> (and/c string? url-regexp) url?))
 (path->url ((or/c path-string? path-for-some-system?) . -> . url?))
 (relative-path->relative-url-string ((and/c (or/c path-string? path-for-some-system?)
                                             relative-path?)
                                      . -> . string?))
 (url->string (url? . -> . string?))
 (url->path (->* (url?) ((one-of/c 'unix 'windows)) path-for-some-system?))
 (file://->path (->* (url?) ((one-of/c 'unix 'windows)) path-for-some-system?))
 (netscape/string->url (string? . -> . url?))
 (combine-url/relative (url? string? . -> . url?))
 (rename -url-exception? url-exception? (any/c . -> . boolean?))
 (file-url-path-convention-type
  (parameter/c (one-of/c 'unix 'windows)))
 (current-url-encode-mode (parameter/c (one-of/c 'recommended 'unreserved))))
