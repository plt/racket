#lang racket/base
(require racket/tcp
         racket/format
         racket/file
         racket/port
         racket/string
         file/gunzip
         file/private/check-path
         openssl/sha1
         net/base64
         net/url
         net/head
         net/http-client
         (only-in net/url-connect current-https-protocol))

;; Stefan Saasen's "Reimplementing 'git clone' in Haskell from the bottom up"
;;  http://stefan.saasen.me/articles/git-clone-in-haskell-from-the-bottom-up/
;; provided many helpful hints for this implementation.

(provide git-checkout
         current-git-username
         current-git-password
         (struct-out exn:fail:git))

(define-logger git-checkout)

(define current-git-username (make-parameter #f))
(define current-git-password (make-parameter #f))

(struct exn:fail:git exn:fail () #:transparent)

(define (raise-git-error name fmt . vals)
  (raise (exn:fail:git (apply format (string-append "~s: " fmt) name vals)
                       (current-continuation-marks))))

;; Like `git clone`, but producing just the checkout
(define (git-checkout host
                      repo
                      #:dest-dir dest-dir ; #f => only find checkout
                      #:transport [transport 'git]
                      #:ref [ref/head 'head]
                      #:initial-search-ref [initial-search-ref "master"]
                      #:depth [given-depth 1]
                      #:status-printf [status-printf (lambda args
                                                       (apply printf args)
                                                       (flush-output))]
                      #:initial-error [initial-error #f]
                      #:tmp-dir [given-tmp-dir #f]
                      #:clean-tmp-dir? [clean-tmp-dir? (not given-tmp-dir)]
                      #:verify-server? [verify? #t]
                      #:port [given-port #f]
                      #:strict-links? [strict-links? #f]
                      #:username [username (current-git-username)]
                      #:password [password (current-git-password)])
  (let retry-loop ([given-depth given-depth] [try-limit-depth (and given-depth 8)] [try-search-only-ref initial-search-ref])
    (define tmp-dir (or given-tmp-dir
                        (make-temporary-file "git~a" 'directory)))
    (define port (or given-port (case transport
                                  [(git) 9418]
                                  [(http) 80]
                                  [(https) 443])))
    
    (define (status fmt . args)
      (define msg (apply format fmt args))
      (status-printf "~a\n" msg)
      (log-git-checkout-info msg))
    
    (status "Contacting ~a" host)
    (define-values (i o dumb-protocol?)
      (initial-connect transport host verify? port repo status username password))
    ((let/ec esc
       (dynamic-wind
        void
        (lambda ()
          (status "Getting refs~a" (if dumb-protocol? " [dumb protocol]" ""))
          (write-pkt o
                     "git-upload-pack " "/" repo "\0"
                     "host=" host "\0")
          (define pkts (if dumb-protocol?
                           ;; dumb protocol provides plain lines:
                           (for/list ([l (in-lines i)]) (string-append l "\n"))
                           ;; smart protocol provides packets:
                           (read-pkts i)))
          (unless (pair? pkts)
            (raise-git-error 'git-checkout "no initial pkts from the server"))

          ;; Parse server's initial reply
          (define server-capabilities (parse-server-capabilities (car pkts)))
          (define refs ; (list (list <name> <ID>) ...)
            (parse-initial-refs pkts initial-error))

          (define ref (head->ref ref/head
                                 server-capabilities dumb-protocol?
                                 transport host verify? port repo username password
                                 status))

          ;; Find the commits needed for `ref`:
          (define-values (ref-commit    ; #f or an ID string
                          want-commits) ; list of ID string
            (select-commits ref refs server-capabilities status try-search-only-ref repo))

          (unless dest-dir
            (write-pkt o) ; clean termination
            ((esc (lambda ()
                    ;; If we get this far and `ref-commit` is #f,
                    ;; then `ref` looks like a commit
                    (or ref-commit ref)))))

          (define depth (and given-depth
                             (or ref-commit (and try-limit-depth
                                                 (eq? given-depth 1)))
                             (cond
                               [(member "shallow" server-capabilities)
                                (if ref-commit
                                    given-depth
                                    try-limit-depth)]
                               [else
                                (status "Server does not support `shallow`")
                                #f])))

          (unless dumb-protocol?
            ;; Tell the server which commits we need
            (set!-values (i o) (want-step transport host port repo i o))
            (for ([want-commit (in-list want-commits)]
                  [pos (in-naturals)])
              (write-pkt o "want " want-commit (if (zero? pos) " " "") "\n"))
            (when depth
              (write-pkt o "deepen " depth "\n"))
            (write-pkt o)

            ;; Tell the server that we're ready for the objects
            (write-pkt o "done\n")
            (set!-values (i o) (done-step transport host verify? port repo username password i o))

            (when depth
              ;; If we wrote `deepen`, then the server replies with `shallow`s.
              ;; Note that these were available before writing `done` in the
              ;; case of the 'git transport, but it works here for all transports.
              (let loop ()
                (define r (read-pkt i))
                (cond
                 [(eof-object? r)
                  (void)]
                 [(regexp-match? #rx"^shallow " r)
                  (loop)]
                 [else
                  (raise-git-error 'git-checkout "expected shallow, got ~s" r)])))

            ;; Tell the server that we're ready for the objects
            (define nak (read-pkt i))
            (unless (or (eof-object? nak) ; happens when `want-commits` is empty
                        (equal? #"NAK\n" nak))
              (raise-git-error 'git-checkout "expected NAK, got ~s" nak)))

          (make-directory* tmp-dir)
          (define tmp (make-tmp-info tmp-dir #:fresh? #t))
          
          (define (maybe-save-objects objs fn)
            (unless clean-tmp-dir?
              (call-with-output-file*
               (build-path tmp-dir fn)
               #:exists 'truncate
               (lambda (o) (write objs o) (newline o)))))
          
          (dynamic-wind
           void
           (lambda ()
             (define obj-ids
               (cond
                [dumb-protocol?
                 (read-dumb-objects want-commits tmp
                                    transport host verify? port repo
                                    status maybe-save-objects)]
                [else
                 ;; Read packfile pbjects, which are written into
                 ;; `tmp-dir`. If `depth` gives the server trouble,
                 ;; we might get an EOF, in which case we'll try again:
                 (define objs
                   (read-packfile i tmp status
                                  (and depth
                                       (lambda ()
                                         (esc (lambda ()
                                                (status "Unexpected EOF; retrying without depth")
                                                (retry-loop #f #f #f)))))))
                 (maybe-save-objects objs "objs")

                 ;; Convert deltas into full objects within `tmp`:
                 (rewrite-deltas objs tmp status)]))
             
             (maybe-save-objects obj-ids "all-objs")
             
             (define commit
               (or ref-commit
                   (find-commit-as-reference ref obj-ids
                                             (and (or try-search-only-ref
                                                      (and try-limit-depth
                                                           (eqv? depth try-limit-depth)))
                                                  (lambda ()
                                                    (esc (lambda ()
                                                           (cond
                                                             [(and depth (eqv? depth try-limit-depth)
                                                                   (try-limit-depth . < . 32))
                                                              (status "no matching commit found; trying deeper search")
                                                              (retry-loop given-depth (* try-limit-depth 2) try-search-only-ref)]
                                                             [else
                                                              (status "no matching commit found; trying broader search")
                                                              (retry-loop given-depth #f #f)]))))))))

             ;; Extract the tree from the packfile objects:
             (status "Extracting tree to ~a" dest-dir)
             (extract-commit-tree (hex-string->bytes commit)
                                  obj-ids tmp dest-dir
                                  strict-links?)
             
             ;; Done; return checkout id
             (lambda () commit))
           (lambda ()
             (status "Cleaning up")
             (close-tmp-info tmp)
             (when clean-tmp-dir?
               (delete-directory/files tmp-dir)))))
        (lambda ()
          (close-input-port i)
          (close-output-port o)))))))

;; ----------------------------------------
;; Transports: git, http, and https

(define (http-request-headers username password)
  ;; bitbucket.org seems to require a "git" value for "User-Agent",
  ;; otherwise it returns a "broken link" web page
  (define base-headers '("User-Agent: git/1.9"))
  ;; include an Authorization header if credentials are provided
  (if (and username password)
      (cons (~a "Authorization: Basic " (base64-encode (string->bytes/utf-8 (~a username ":" password)) #""))
            base-headers)
      base-headers))

;; initial-connect: transport-sym string bool natural string status-proc string string
;;                  -> (values input-port output-port boolean)
;;  Contacts the server and returns an output port for writing
;;  the request (ignored if not needed for the the transport)
;;  and an input port from reading the available references. The
;;  boolean result indicates whether the protocol is "dumb".
(define (initial-connect transport host verify? port repo status username password)
  (case transport
    [(git)
     (define-values (i o) (tcp-or-tunnel-connect "git" host port))
     (values i o #f)]
    [(http https)
     (define url-str
       (~a transport "://" host ":" port "/" repo
           "/info/refs?service=git-upload-pack"))
     (define-values (i headers)
       (parameterize ([current-https-protocol (ssl-context verify?)])
         (get-pure-port/headers (string->url url-str)
                                (http-request-headers username password)
                                #:redirections 5)))
     (define ok? #f)
     (dynamic-wind
      void
      (lambda ()
        (define dumb?
          (cond
           [(equal? (extract-field "Content-Type" headers)
                    "application/x-git-upload-pack-advertisement")
            ;; "smart" protocol
            (unless (regexp-match-peek #px#"^[0-9a-f]{4}#" i)
              (raise-git-error 'git-checkout (~a "error reading repository content;\n"
                                                 " response is not consistent with the Git protocol\n"
                                                 "  initial portion: ~s")
                               (read-bytes 640 i)))
            (define pkt (read-pkt i))
            (define term-pkt (read-pkt i))
            (unless (eof-object? term-pkt)
              (raise-git-error 'git-checkout (~a "expected a null packet, received something else\n"
                                                 "  packet: ~s")
                               term-pkt))
            #f]
           [else
            ;; "dumb" protocol
            #t]))
        (set! ok? #t)
        (values i (open-output-nowhere) dumb?))
      (lambda ()
        (unless ok? (close-input-port i))))]
    [else
     (raise-git-error 'git-checkout "unrecognized transport\n  given: ~e" transport)]))

;; want-step: transport-sym string natural string input-port output-port
;;            -> (values input-port output-port)
;;  Replaces the connection, if appropriate to the transport, for
;;  writing the wanted references.
(define (want-step transport host port repo i o)
  (case transport
    [(git) (values i o)]
    [(http https)
     (close-input-port i)
     (values (open-input-bytes #"") (open-output-bytes))]))

;; done-step: transport-sym string bool natural string string string input-port output-port
;;            -> (values input-port output-port)
;;  Replaces the connection, if appropriate to the transport, after
;;  writing the wanted references and before reading the server's
;;  response.
(define (done-step transport host verify? port repo username password i o)
  (case transport
    [(git) (values i o)]
    [(http https)
     (define s (get-output-bytes o))
     (define i
       (parameterize ([current-https-protocol (ssl-context verify?)])
         (post-pure-port
          (string->url
           (~a transport "://" host ":" port "/" repo
               "/git-upload-pack"))
          s
          (append
           (http-request-headers username password)
           (list "Content-Type: application/x-git-upload-pack-request")))))
     (values i (open-output-nowhere))]))

;; converts 'head to a branch/tag/commit ref
(define (head->ref ref/head
                   server-capabilities dumb-protocol?
                   transport host verify? port repo username password
                   status)
  (cond
    [(eq? ref/head 'head)
     (or
      ;; Git 1.8.5 and later (smart protocol) maps HEAD in capabilities
      (for/or ([cap (in-list server-capabilities)])
        (define m (regexp-match #rx"^symref=HEAD:(.*)$" cap))
        (and m (refspec->ref (cadr m))))
      ;; dumb protocol: fetch the "HEAD" reference
      (case (and dumb-protocol? transport)
        [(http https)
         (status "Getting HEAD")
         (define i
           (parameterize ([current-https-protocol (ssl-context verify?)])
             (get-pure-port
              (string->url
               (~a transport "://" host ":" port "/" repo
                   "/HEAD"))
              (append
               (http-request-headers username password)
               (list "Content-Type: application/x-git-upload-pack-request")))))
         (define s (port->string i))
         (define m (regexp-match #rx"(?m:^ref: (.*)$)" s))
         (and m (refspec->ref (cadr m)))]
        [else #f])
      ;; If all else fails, keep 'head and try to match "HEAD" in refs
      'head)]
    [else ref/head]))

(define (ssl-context verify?)
  (cond
   [(or (not verify?)
        (getenv "GIT_SSL_NO_VERIFY"))
    (current-https-protocol)]
   [else
    'secure]))

(define (refspec->ref refspec)
  (cond
    [(regexp-match #rx"^refs/(?:heads|tags)/(.*)$" refspec)
     => (lambda (m) (cadr m))]
    [else refspec]))

;; ----------------------------------------

;; parse-server-capabilities : bytes -> (listof string)
(define (parse-server-capabilities first-pkt)
  (let ([m (regexp-match #rx#"\0(.*)\n$" first-pkt)])
    (cond
     [m (string-split (bytes->string/utf-8 (cadr m)))]
     [else null])))

;; parse-initial-refs : (listof bytes) -> (listof (list bytes string))
;;  In each element of the returned list, first item is
;;  the branch or tag name, second is the ID
(define (parse-initial-refs pkts initial-error)
  (filter
   values
   (for/list ([pkt (in-list pkts)])
     (define m (regexp-match #px#"^([0-9a-fA-F]{40})[ \t]([^\0\n]+)[\0\n]" pkt))
     (unless m 
       (when initial-error (initial-error))
       (raise-git-error 'git-checkout "could not parse ref pkt\n  pkt: ~s" pkt))
     (define name (caddr m))
     (define id (bytes->string/utf-8 (cadr m)))
     (cond
      [(regexp-match? #rx#"\\^{}$" name)
       ;; drop parent references
       #f]
      [else (list name id)]))))

;; select-commits : (or/c string 'head) (listof (list bytes string)) ....
;;                  -> (values string-or-#f (listof string))
;;  Convert the user's request `ref`, which is a branch or tag or ID,
;;  into a specific ID --- if we can determine it from the server's
;;  initial response. If we can, the list of requested IDs will be
;;  just that one. Otherwise, we'll have to return a list of all
;;  IDs, and then we'll look for the reference later.
(define (select-commits ref refs server-capabilities status try-search-only-ref repo)
  (define ref-looks-like-id? (and (string? ref)
                                  (regexp-match? #rx"^[0-9a-f]+$" ref)))
  (define ref-rx (cond
                   [(eq? ref 'head)
                    ;; some servers report "HEAD" early, and we can
                    ;; expect it early in the list; if that fails,
                    ;; fall back to trying a "master" branch:
                    #"^HEAD|refs/heads/master$"]
                   [else (branch-or-tag->regexp ref)]))

  (define ref-commit
    (or
     ;; Search list of branch and tag names:
     (for/or ([ref (in-list refs)])
       (and (regexp-match? ref-rx (car ref))
            (cadr ref)))
     ;; Try matching the references as a commit/tag ID of a branch or tag:
     (and (string? ref)
          (let ([rx (id-ref->regexp ref)])
            (for/or ([a-ref (in-list refs)])
              (and (regexp-match? rx (cadr a-ref))
                   (begin
                     (status "Commit id ~s matches ~a" ref (car a-ref))
                     (cadr a-ref))))))))
  (define want-commits
    (cond
     [ref-commit (list ref-commit)]
     [ref-looks-like-id?
      (cond
        [try-search-only-ref
         (status "Requested reference looks like commit id; try within ~a" try-search-only-ref)
         (define master-rx (branch-or-tag->regexp try-search-only-ref))
         (cond
           [(for/or ([ref (in-list refs)])
              (regexp-match? master-rx (car ref)))
            (define-values (master-ref-commit want-commits)
              (select-commits try-search-only-ref refs '() status #f repo))
            want-commits]
           [else
            (status "There does not appear to be a ~a branch or tag, however" try-search-only-ref)
            ;; the branch to try appears not to exist
            null])]
        [else
         (status "Requested reference looks like commit id; getting all commits")
         (for/list ([ref (in-list refs)])
           (cadr ref))])]
     [else
      (raise-git-error 'git "could not find requested reference\n  reference: ~a\n  repo: ~a" ref repo)]))
  
  (values ref-commit want-commits))

(define (branch-or-tag->regexp ref)
  (byte-regexp (bytes-append
                #"^refs/(?:heads|tags)/"
                (regexp-quote (string->bytes/utf-8 ref))
                #"$")))

;; ----------------------------------------
;; A "pkt" is the basic unit of communication in many parts
;; of the git protocol. The first four bytes specify the
;; length of the package (including those bytes).

;; write-pkt : output-port any ... -> void
;;  `display`s each argument to create a package
(define (write-pkt o . args)
  (define s (open-output-bytes))
  (for ([arg (in-list args)])
    (display arg s))
  (define msg (get-output-bytes s))
  (define len (bytes-length msg))
  (define full-msg
    (cond
     [(zero? len) #"0000"]
     [else
      (define len-bstr (string->bytes/utf-8 (format "~x" (+ 4 len))))
      (bytes-append (make-bytes (- 4 (bytes-length len-bstr))
                                (char->integer #\0))
                    len-bstr
                    msg)]))
  (write-bytes full-msg o)
  (flush-output o))

;; read-pkt : input-port -> bstr-or-eof
;;  Reads one pkt, returning eof of the special "null" pkt
(define (read-pkt i)
  (define len-bstr (read-bytes 4 i))
  (cond
   [(eof-object? len-bstr) eof]
   [else
    (unless (and (bytes? len-bstr)
                 (= 4 (bytes-length len-bstr)))
      (raise-git-error 'git-checkout "error getting pkt length"))
    (define len (string->number (bytes->string/utf-8 len-bstr #\?) 16))
    (unless len
      (raise-git-error 'git-checkout "error getting pkt length\n  length string: ~e" len-bstr))
    (cond
     [(= len 0) eof] ; flush pkt
     [else
      (define payload-len (- len 4))
      (unless (payload-len . >= . 0)
        (raise-git-error 'git-checkout "pkt length makes no sense\n  length: ~a" len))
      (read-bytes-exactly 'payload payload-len i)])]))

;; read a list of pkts until an empty packet is found
(define (read-pkts i)
  (define pkt (read-pkt i))
  (if (or (eof-object? pkt)
          (equal? #"" pkt))
      null
      (cons pkt (read-pkts i))))

;; ----------------------------------------
;; Packfile objects

(struct object (location  ; filename within tmp or position in small-object file
                type      ; 'blob, 'commit, etc.; see `type-num->sym`
                [type-info #:mutable] ; #f, id, or object
                id        ; sha1 as bytes
                [undelta #:mutable])
  #:prefab)

;; read-packfile : input-port tmp-info status-proc (or/c #f (-> any)) -> (listof object)
;;  The `initial-eof-handler` argument should escape, if it's not #f
(define (read-packfile i tmp status initial-eof-handler)
  (define pack-bstr (read-bytes 4 i))
  (unless (equal? pack-bstr #"PACK")
    (when (and (eof-object? pack-bstr)
               initial-eof-handler)
      (initial-eof-handler))
    (raise-git-error 'git-checkout "header error\n  bytes: ~s" pack-bstr))
  (define vers (read-bytes 4 i))
  (unless (equal? vers #"\0\0\0\2")
    (raise-git-error 'git-checkout "only version 2 supported"))
  (define count-bstr (read-bytes-exactly 'count 4 i))
  (define count (integer-bytes->integer count-bstr #t #t))
  (define obj-stream-poses (make-hash)) ; for OBJ_OFS_DELTA references
  (status "Getting ~a objects" count)
  (for/list ([pos (in-range count)])
    (read-object i tmp obj-stream-poses)))

(define OBJ_COMMIT 1)
(define OBJ_TREE 2)
(define OBJ_BLOB 3)
(define OBJ_TAG 4)
(define OBJ_OFS_DELTA 6)
(define OBJ_REF_DELTA 7)

(define type-num->sym (hash OBJ_COMMIT 'commit
                            OBJ_TREE 'tree
                            OBJ_BLOB 'blob
                            OBJ_TAG 'tag
                            OBJ_OFS_DELTA 'ofs-delta
                            OBJ_REF_DELTA 'ref-delta))
(define valid-types (for/list ([v (in-hash-values type-num->sym)]) v))

;; read-object : input-port tmp-info (hash-of integer obj) -> object
(define (read-object i tmp obj-stream-poses)
  (define obj-stream-pos (file-position i))
  (define c (read-byte-only 'type-and-size i))
  (define type (bitwise-and (arithmetic-shift c -4) #x7))
  (when (zero? type) (raise-git-error 'git-checkout "bad packfile type"))
  (define init-len (bitwise-and c #xF))
  (define len
    (if (msb-set? c)
        (+ init-len (arithmetic-shift (read-integer i) 4))
        init-len))
  (define type-sym (hash-ref type-num->sym type))
  (define type-info
    (case type-sym
     [(ref-delta)
      (read-bytes-exactly 'referenced-id 20 i)]
     [(ofs-delta)
      (define delta (read-offset-integer i))
      (hash-ref obj-stream-poses (- obj-stream-pos delta)
                (lambda () (raise-git-error 'git-checkout "OBJ_OFS_DELTA object not found")))]
     [else #f]))
  (define obj
    (save-object (lambda (o) (zlib-inflate i o)) len type-sym type-info tmp))
  (hash-set! obj-stream-poses obj-stream-pos obj)
  obj)

;; save-object : (output-port ->) integer symbol any tmp-info -> object
(define (save-object write-data len type-sym type-info tmp)
  (define filename (~a (case type-sym
                        [(ref-delta ofs-delta) "delta"]
                        [else "obj"])
                       (increment-object-count! tmp)))
  (define location
    (call-with-output-object
     tmp
     filename
     len
     write-data))
  (construct-object location type-sym type-info len tmp))

;; To build an `object`, we need to construct a SHA-1 from the object
;; content, which is in a file in `tmp`
(define (construct-object filename type-sym type-info size tmp)
  (object filename type-sym type-info
          (call-with-input-object
           tmp
           filename
           (lambda (i)
             (define prefix (~a type-sym " " size "\0"))
             (sha1-bytes (input-port-append #f
                                            (open-input-string prefix)
                                            i))))
          #f))

;; rewrite-deltas : (listof object) tmp status -> (hashof bytes object)
;; Given a mapping from ids to objects, combine each "delta" file with
;; a referenced object to create a new object file. The deltas,
;; referenced objects, and generated objects all are in `tmp`. The
;; result is an id-to-object mapping that includes all the given
;; objects plus the generated ones.
(define (rewrite-deltas objs tmp status)
  (status "Applying deltas")
  (define ids (hash-copy
               (for/hash ([obj (in-list objs)])
                 (values (object-id obj) obj))))
  (for ([obj (in-list objs)])
    (case (object-type obj)
      [(ref-delta ofs-delta)
       (define base-obj-id (if (eq? (object-type obj) 'ref-delta)
                               ;; Base object is referenced directly:
                               (object-type-info obj)
                               ;; We have to find the object generated by another
                               ;; "object", where the "object" may be a delta:
                               (let ([v (object-type-info obj)])
                                 (set-object-type-info! obj (object-id v))
                                 (case (object-type v)
                                   [(ref-delta ofs-delta) (object-undelta v)]
                                   [else (object-id v)]))))
       (define base-obj (hash-ref ids base-obj-id))
       (define new-filename (~a "obj" (increment-object-count! tmp)))
       (call-with-input-object
        tmp
        ;; the delta file:
        (object-location obj)
        (lambda (i)
          (call-with-input-object
           tmp
           ;; apply delta to this base object:
           (object-location base-obj)
           (lambda (src-in)
             (define src-len (read-integer i))
             (define dest-len (read-integer i))
             (define location
               (call-with-output-object
                tmp
                ;; write to this new object:
                new-filename
                dest-len
                (lambda (o)
                  ;; Each delta command is either "copy" or "insert"
                  (let loop ()
                    (define c (read-byte i))
                    (cond
                     [(eof-object? c)
                      (void)]
                     [(msb-set? c)
                      ;; Copy
                      (define src-offset (read-number-by-bits i (bitwise-and c #xF)))
                      (define raw-src-len (read-number-by-bits i (bitwise-and (arithmetic-shift c -4)
                                                                              #x7)))
                      (define src-len (if (zero? raw-src-len) #x10000 raw-src-len))
                      (file-position src-in src-offset)
                      (copy-port-n src-in o src-len)
                      (loop)]
                     [else
                      ;; Insert
                      (copy-port-n i o c)
                      (loop)])))))
             ;; Add the generated object to our table:
             (define new-obj (construct-object location (object-type base-obj) #f
                                               dest-len tmp))
             (hash-set! ids (object-id new-obj) new-obj)
             ;; Record undelta id:
             (set-object-undelta! obj (object-id new-obj))))))]))
  ids)

;; ----------------------------------------
;; Finding a commit id

(define (find-commit-as-reference ref obj-ids fail-not-found)
  (define rx (id-ref->regexp ref))
  (define matches
    (for/list ([(id obj) (in-hash obj-ids)]
               #:when (eq? 'commit (object-type obj))
               #:when (regexp-match? rx (bytes->hex-string id)))
      (bytes->hex-string id)))
  (cond
   [(= 1 (length matches)) (car matches)]
   [(null? matches)
    (if fail-not-found
        (fail-not-found)
        (raise-git-error 'git-checkout "no commit found matching id: ~a" ref))]
   [else
    (raise-git-error 'git-checkout "found multiple commits matching id: ~a" ref)]))

(define (id-ref->regexp ref)
  (regexp (~a "^" (regexp-quote (string-downcase ref)))))

;; ----------------------------------------
;; Extract a checkout tree

;; extract-commit-tree : bytes (hash/c bytes object) tmp-info path -> void
;;  Extract the designated commit to `dest-dir`, using objects from `tmp`
(define (extract-commit-tree obj-id obj-ids tmp dest-dir strict-links?)
  (define obj (hash-ref obj-ids obj-id))
  (case (object-type obj)
    [(commit)
     (define-values (tree-id-str parent-id-strs)
       (call-with-input-object
        tmp
        (object-location obj)
        (lambda (i)
          (extract-commit-info i obj-id))))
     (define tree-id (hex-string->bytes tree-id-str))
     (extract-tree tree-id obj-ids tmp dest-dir strict-links?)]
    [(tag)
     (define commit-id-bstr
       (call-with-input-object
        tmp
        (object-location obj)
        (lambda (i)
          (define m (regexp-try-match #px"^object ([0-9a-fA-F]{40})" i))
          (unless m
            (raise-git-error 'git-checkout "cannot extract commit from tag file for ~s"
                             (bytes->hex-string obj-id)))
          (cadr m))))
     (define commit-id (hex-string->bytes (bytes->string/utf-8 commit-id-bstr)))
     (extract-commit-tree commit-id obj-ids tmp dest-dir strict-links?)]
    [(tree)
     (extract-tree obj-id obj-ids tmp dest-dir strict-links?)]
    [else
     (raise-git-error 'git-checkout "cannot extract tree from ~a: ~s"
                      (object-type obj)
                      (bytes->hex-string obj-id))]))

;; extract-commit-info: input-port bytes -> string (listof string)
;;  Returns the commit's tree and parent ids.
;;  The `obj-id` argument is used for error reporting, only.
(define (extract-commit-info i obj-id)
  (define m (regexp-try-match #px"^tree ([0-9a-fA-F]{40})" i))
  (unless m
    (raise-git-error 'git-checkout
                     (~a "cannot extract tree from commit file for ~s\n"
                         "  content starts: ~s")
                     (bytes->hex-string obj-id)
                     (peek-bytes 64 0 i)))
  (values
   ;; tree id string:
   (bytes->string/utf-8 (cadr m))
   ;; Loop for parent ids strings:
   (let loop ()
     (define m (regexp-try-match #px"^\nparent ([0-9a-fA-F]{40})" i))
     (if m
         (cons (bytes->string/utf-8 (cadr m))
               (loop))
         null))))

;; extract-tree : bytes (hash/c bytes object) tmp-info path -> void
;;  Extract the designated tree to `dest-dir`, using objects from `tmp`
(define (extract-tree tree-id obj-ids tmp dest-dir strict-links?)
  (make-directory* dest-dir)
  (define tree-obj (hash-ref obj-ids tree-id))
  (call-with-input-object
   tmp
   (object-location tree-obj)
   (lambda (i)
     (let loop ()
       (define-values (id mode fn) (extract-tree-entry i))
       (when id
         (define (this-object-location)
           (object-location (hash-ref obj-ids id)))
         (define (copy-this-object perms)
           (copy-object tmp
                        (this-object-location)
                        perms
                        (build-path dest-dir fn)))
         (case (datum-intern-literal mode)
          [(#"100755") #"755"
           (copy-this-object #o755)]
          [(#"100644" #"644")
           (copy-this-object #o644)]
          [(#"40000" #"040000")
           (extract-tree id obj-ids tmp (build-path dest-dir fn) strict-links?)]
          [(#"120000")
           (define target (bytes->path (object->bytes tmp (this-object-location))))
           (when strict-links?
             (check-unpack-path 'git-checkout target #:kind "link"))
           (make-file-or-directory-link target (build-path dest-dir fn))]
          [(#"160000")
           ;; submodule; just make a directory placeholder
           (make-directory* (build-path dest-dir fn))]
          [else
           (raise-git-error 'extract-tree "unknown mode: ~s" mode)])
         (loop))))))

;; extract-tree-entry: input-port -> bytes-or-#f bytes-or-#f path-or-#f
(define (extract-tree-entry i)
  (define m (regexp-try-match #px"^([0-7]{3,6}) ([^\0]+)\0" i))
  (cond
   [m
    (define id (read-bytes-exactly 'id 20 i))
    (define mode (cadr m))
    (define fn (bytes->path-element (caddr m)))
    (values id mode fn)]
   [else
    (values #f #f #f)]))

;; ----------------------------------------
;; ``Dumb'' HTTP(S) server support

;; read-dumb-objects : (listof string) (hash-of string object)
;;                     symbol string boolean integer string
;;                     status maybe-save-objects
;;                     -> (hash-of string object)
;;  Read the package files available on the server, then round up
;;  any additional loose objects that we'll need.
(define (read-dumb-objects id-strs tmp
                           transport host verify? port repo
                           status maybe-save-objects)
  (define conn (http-conn))
  (http-conn-open! conn
                   host
                   #:ssl? (if (eq? transport 'https)
                              (ssl-context verify?)
                              #f)
                   #:port port
                   #:auto-reconnect? #t)
  
  (define packfiles
    (get-packfile-list conn repo))
  
  (define packed-objects
    (for/fold ([objects (hash)]) ([packfile (in-list packfiles)])
      (read-dumb-packfile packfile objects tmp conn repo status)))
  
  (maybe-save-objects packed-objects "packed-objs")

  (status "Downloading loose objects")
  (define objects
    (read-dumb-loose-objects id-strs packed-objects (make-hash)
                             tmp conn repo status))
  
  (http-conn-close! conn)
  
  (for/hash ([obj (in-hash-values objects)])
    (values (object-id obj) obj)))

;; get-packfile-list : conn string -> (listof string)
;;  Get a list of packfiles available from the server
(define (get-packfile-list conn repo)
  (define-values (status-line headers i)
    (http-conn-sendrecv! conn
                         (~a "/" repo "/objects/info/packs")))
  (check-status status-line "error getting packfile list")
  
  (for/list ([l (in-lines i)]
             #:unless (equal? l ""))
    (define m (regexp-match #rx"^P (.*)" l))
    (unless m (raise-git-error 'git-checkout "error parsing packfile list line\n  line: ~e" l))
    (cadr m)))

;; read-dumb-packfile : string (hashof string object) tmp conn strung status
;;   -> (hashof string object)
;; Read a packfile and apply its deltas, producing an updated mapping of objects
;; that we have unpacked so far.
(define (read-dumb-packfile packfile objects tmp conn repo status)
  (define-values (status-line headers i)
    (http-conn-sendrecv! conn
                         (~a "/" repo "/objects/pack/" packfile)))
  (check-status status-line (~a "error getting packfile " packfile))
  
  (define obj-list (read-packfile i tmp status #f))
  (define obj-ids (rewrite-deltas obj-list tmp status))

  ;; Add new objects to hash table:
  (for/fold ([objects objects]) ([obj (in-hash-values obj-ids)])
    (hash-set objects (bytes->hex-string (object-id obj)) obj)))
  
;; read-dumb-loose-objects : (listof string) (hash-of string object)
;;                           (mutable-hash-of string #t)
;;                           conn string status
;;                           -> (hash-of string object)
;;  Traverse the tree, looking for extra objects (not supplied by a packfile)
;;  that we need to download
(define (read-dumb-loose-objects id-strs objects seen tmp conn repo status)
  (for/fold ([objects objects]) ([id-str (in-list id-strs)])
    (cond
     [(hash-ref seen id-str #f) objects]
     [else
      (define obj
        (cond
         [(hash-ref objects id-str #f)
          => (lambda (obj) obj)]
         [else
          (define-values (status-line headers compressed-i)
            (http-conn-sendrecv! conn
                                 (~a "/" repo
                                     "/objects/" (substring id-str 0 2)
                                     "/" (substring id-str 2))))
          (check-status status-line (format "error getting object ~a" id-str))
          
          ;; Set up decompression of stream:
          (define-values (i decompressed-o) (make-pipe 4096))
          (define exn #f)
          (define inflate-thread
            (thread (lambda ()
                      (dynamic-wind
                       void
                       (lambda ()
                         (with-handlers ([values (lambda (x) (set! exn x))])
                           (zlib-inflate compressed-i decompressed-o)))
                       (lambda ()
                         (close-output-port decompressed-o)
                         (close-input-port compressed-i))))))

          ;; Parse the object description:
          (define header-m (regexp-try-match #rx#"^[^\0]*\0" i))
          (unless header-m
            (raise-git-error 'git-checkout "bad initial line for object content"))
          (define header (car header-m))
          (define header-len (bytes-length header))
          (define type-sym (string->symbol
                            (bytes->string/utf-8 (car (regexp-match #rx"^[^ ]*" header)))))
          (define data-len (string->number
                            (bytes->string/utf-8 (cadr (or (regexp-match #rx"[^ ]* ([0-9]+)" header)
                                                           '(#"" #""))))))        
          (unless (memq type-sym valid-types)
            (raise-git-error 'git-checkout "bad type: ~e" type-sym))
          
          (define obj
            (save-object (lambda (o) (copy-port i o))
                         data-len type-sym #f tmp))
          
          ;; Just in case:
          (kill-thread inflate-thread)
          (close-input-port compressed-i)
          (when exn (raise exn))
          
          obj]))
      
      ;; Add the (potentially) new object to out table:
      (define new-objects (hash-set objects id-str obj))
      (hash-set! seen id-str #t)
      
      ;; Inspect the new object, looking for additional objects to download:
      (define id (object-id obj))
      (define (call-with-content proc)
        (call-with-input-object
         tmp
         (object-location obj)
         proc))
      (define more-id-strs
        (case (object-type obj)
          [(commit)
           (define-values (tree parents)
             (call-with-content (lambda (i) (extract-commit-info i id))))
           (cons tree parents)]
          [(tree)
           (call-with-content
            (lambda (i)
              (let loop ()
                (define-values (content-id mode fn) (extract-tree-entry i))
                (cond
                 [(not content-id) null]
                 [(equal? mode #"160000")
                  ;; don't try to get a submodule commit
                  (loop)]
                 [else
                  (cons (bytes->hex-string content-id)
                        (loop))]))))]
          [else
           null]))
      
      (read-dumb-loose-objects more-id-strs new-objects seen
                               tmp conn repo status)])))

;; check-status : string string -> any
;;  Check an HTTP status result and complain if there's a problem
(define (check-status status-line msg)      
  (define status (let ([m (regexp-match #rx"^[^ ]* ([0-9]+)" status-line)])
                   (and m (string->number (bytes->string/utf-8 (cadr m))))))
  (unless (memv status '(200))
    (raise-git-error 'git-checkout "~a\n  server respone: ~a"
                     msg
                     status-line)))

;; ----------------------------------------
;; Temporary directory & database

(struct tmp-info (dir small-i small-o [pos #:mutable] [flush? #:mutable] [obj-counter #:mutable]))

;; make-tmp-info : path -> tmp-info
(define (make-tmp-info tmp-dir #:fresh? [fresh? #f])
  (define-values (i o) (open-input-output-file
                        (build-path tmp-dir "objs-small")
                        #:exists (if fresh? 'truncate 'update)))
  (file-stream-buffer-mode i 'none)
  (tmp-info tmp-dir i o 0 #f 0))

;; close-tmp-info : tmp-info -> void
(define (close-tmp-info tmp)
  (close-input-port (tmp-info-small-i tmp))
  (close-output-port (tmp-info-small-o tmp)))

;; increment-object-count! : tmp-info -> integer
(define (increment-object-count! tmp)
  (define n (add1 (tmp-info-obj-counter tmp)))
  (set-tmp-info-obj-counter! tmp n)
  n)

;; call-with-output-object : tmp-info string natural (output-port -> any) -> location
(define (call-with-output-object tmp filename len proc)
  (define (check-len got-len)
    (unless (= len got-len)
      (raise-git-error 'git-checkout "size mismatch\n  expected: ~a\n  received: ~a"
                       len
                       got-len)))
  (cond
   [(len . < . 256)
    (define location (tmp-info-pos tmp))
    (define s (open-output-bytes))
    (proc s)
    (let ([bstr (get-output-bytes s)])
      (check-len (bytes-length bstr))
      (define o (tmp-info-small-o tmp))
      (file-position o location)
      (write-bytes bstr o)
      (set-tmp-info-pos! tmp (+ len (tmp-info-pos tmp)))
      (set-tmp-info-flush?! tmp #t))
    (cons location len)]
   [else
    (define path (build-path (tmp-info-dir tmp) filename))
    (call-with-output-file* path proc #:exists 'truncate)
    (check-len (file-size path))
    filename]))

;; call-with-input-object : tmp-info location (input-port -> X) -> X
(define (call-with-input-object tmp location proc)
  (cond
   [(pair? location)
    (define bstr (object->bytes tmp location))
    (proc (open-input-bytes bstr))]
   [else
    (call-with-input-file* (build-path (tmp-info-dir tmp) location) proc)]))

;; copy-object : tmp-info location integer path -> void
(define (copy-object tmp location perms dest-file)
  (cond
   [(pair? location)
    (define bstr (object->bytes tmp location))
    (call-with-output-file*
     dest-file
     #:exists 'truncate
     (lambda (o) (write-bytes bstr o)))]
   [else
    (copy-file (build-path (tmp-info-dir tmp) location)
               dest-file
               #t)])
  (if (equal? 'windows (system-type 'os))
      (file-or-directory-permissions dest-file #o777)
      (file-or-directory-permissions dest-file perms)))

;; object->bytes : tmp-info location -> bytes
(define (object->bytes tmp location)
  (cond
   [(pair? location)
    (when (tmp-info-flush? tmp)
      (flush-output (tmp-info-small-o tmp))
      (set-tmp-info-flush?! tmp #f))
    (define i (tmp-info-small-i tmp))
    (file-position i (car location))
    (read-bytes (cdr location) i)]
   [else
    (file->bytes (build-path (tmp-info-dir tmp) location))]))

;; ----------------------------------------
;; Utils

(define (read-bytes-exactly what len i)
  (define bstr (read-bytes len i))
  (unless (and (bytes? bstr)
               (= (bytes-length bstr) len))
    (raise-git-error 'git-checkout (~a "error getting bytes for ~a\n"
                                       "  expected length: ~a\n"
                                       "  got length: ~a")
                     what
                     len
                     (if (eof-object? bstr)
                         eof
                         (bytes-length bstr))))
  bstr)

(define (read-byte-only what i)
  (define c (read-byte i))
  (unless (byte? c)
    (raise-git-error 'git-checkout "expected to get a byte for ~a, got enf-of-file" what))
  c)

;; copy-port-n : input-port output-port natural -> void
(define (copy-port-n i o n)
  (cond
   [(n . <= . 4096)
    (define bstr (read-bytes n i))
    (unless (and (bytes? bstr)
                 (= (bytes-length bstr) n))
      (raise-git-error 'git-checkout "not enough bytes during copy"))
    (write-bytes bstr o)]
   [else
    (copy-port-n i o 4096)
    (copy-port-n i o (- n 4096))]))

(define (msb-set? c)
  (bitwise-bit-set? c 7))

;; A common integer encoding is a sequence of 7-bit
;; piecs of the number, where the most-significant bit
;; indicates whether the number continues
(define (read-integer i)
  (let loop ([amt 0] [shift 0])
    (define c (read-byte i))
    (cond
     [(eof-object? c) amt]
     [else
      (define new-amt (+ amt
                         (arithmetic-shift (bitwise-and c #x7F) shift)))
      (if (msb-set? c)
          (loop new-amt (+ shift 7))
          new-amt)])))

;; Similar to read-integer, but for (negative) offsets
(define (read-offset-integer i)
  (define c (read-byte i))
  (cond
   [(eof-object? c) 0]
   [else
    (define delta (bitwise-and c #x7F))
    (cond
     [(not (msb-set? c)) delta]
     [else
      (let loop ([delta delta])
        (define c (read-byte i))
        (cond
         [(eof-object? c) delta]
         [else
          (let ([delta (+ (arithmetic-shift (+ delta 1) 7)
                          (bitwise-and c #x7F))])
            (if (msb-set? c)
                (loop delta)
                delta))]))])]))

;; Another number format, where a bitmap `n` indicates
;; when to read a byte
(define (read-number-by-bits i n)
  (cond
   [(zero? n) 0]
   [else
    (+ (if (bitwise-bit-set? n 0)
           (read-byte i)
           0)
       (arithmetic-shift (read-number-by-bits i (arithmetic-shift n -1))
                         8))]))

;; ADLER32 implementation
;; https://www.ietf.org/rfc/rfc1950.txt
(define (adler32-through-ports in out)
  (define ADLER 65521)
  (define bstr (make-bytes 4096))
  (let loop ([s1 1] [s2 0])
    (define n (read-bytes! bstr in))
    (cond
      [(eof-object? n)
       (bitwise-ior (arithmetic-shift s2 16) s1)]
      [else
       (write-bytes bstr out 0 n)
       (define-values (new-s1 new-s2)
         (for/fold ([s1 s1]
                    [s2 s2])
                   ([bits (in-bytes bstr 0 n)])
           (define a (modulo (+ s1 bits) ADLER))
           (define b (modulo (+ s2 a) ADLER))
           (values a b)))
       (loop new-s1 new-s2)])))

;; zlib-inflate : input-port output-port
;;  Reads compressed data from `i`, writes uncompressed to `o`
(define (zlib-inflate i o)
  (define cmf (read-byte-only 'zlib-cmf i))
  (define flg (read-byte-only 'zlib-flag i))
  (unless (= 8 (bitwise-and cmf #xF))
    (raise-git-error 'git-checkout "compression is not `deflate`"))
  (when (bitwise-bit-set? flg 5)
    ;; read dictid
    (read-bytes-exactly 'dictid 4 i))
  ;; Include adler32 checksum in the pipeline, writing to `o`:
  (define-values (checksum-in checksum-out) (make-pipe 4096))
  (define uncompressed-adler #f)
  (define checksum-thread
    (thread
     (lambda () (set! uncompressed-adler (adler32-through-ports checksum-in o)))))
  ;; Inflate, sending output to checksum (and then to `o`):
  (inflate i checksum-out)
  (close-output-port checksum-out)
  (sync checksum-thread)
  ;; Verify checksum
  (define adler (read-bytes-exactly 'adler-checksum 4 i))
  (unless (= (integer-bytes->integer adler #f #t)
             uncompressed-adler)
    (raise-git-error 'git-checkout "adler32 checksum failed"))
  (void))

;; ----------------------------------------

(module+ main
  (require racket/cmdline)

  (define depth 1)
  (define ref "master")
  (define tmp-dir #f)
  (define transport 'git)
  (define status-printf
    (lambda args
      (apply printf args)
      (flush-output)))

  (define-values (host repo dest)
    (command-line
     #:once-any
     [("--git") "Use the Git transport (the default)"
      (set! transport 'git)]
     [("--http") "Use the \"smart\" HTTP transport"
      (set! transport 'http)]
     [("--https") "Use the \"smart\" HTTPS transport"
      (set! transport 'https)]
     #:once-each
     [("--depth") d "Commit depth of <d> (default is 1, 0 means \"all\")"
      (set! depth (string->number d))
      (unless (exact-nonnegative-integer? depth)
        (raise-user-error 'git-checkout "bad depth: ~a" d))]
     [("--ref") branch/tag/commit "Checkout specified commit"
      (set! ref branch/tag/commit)]
     [("--tmp") dir "Write temporary files to <dir>"
      (set! tmp-dir dir)]
     [("-u" "--username") username "Username used to authenticate over HTTP(S)"
      (current-git-username username)]
     [("-p" "--password") password "Password used to authenticate over HTTP(S)"
      (current-git-password password)]
     [("--quiet") "Suppress status printouts"
      (set! status-printf void)]
     #:args (host repo dest)
     (values host repo dest)))

  (git-checkout host repo
                #:transport transport
                #:dest-dir dest
                #:tmp-dir tmp-dir
                #:ref ref
                #:depth (if (eq? 0 depth) #f depth)
                #:status-printf status-printf))
