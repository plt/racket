#lang racket/base

(provide mangle-id mangle-id-for-maker
         build-struct-names
         lookup-struct-info
         nums-up-to
         add-name-prop
         all-but-last
         known-good-contract?
         known-good-contracts
         update-loc
         gen-id)

(require setup/main-collects
         racket/struct-info
         (rename-in syntax/private/boundmap
                    ;; the private version of the library
                    ;; (the one without contracts)
                    ;; has these old, wrong names in it.
                    [make-module-identifier-mapping make-free-identifier-mapping]
                    [module-identifier-mapping-get free-identifier-mapping-get]
                    [module-identifier-mapping-put! free-identifier-mapping-put!])
         (for-template racket/base
                       (only-in racket/private/list-predicates
                                empty? cons?)))

(define (update-loc stx loc)
  (datum->syntax stx (syntax-e stx) loc))

;; lookup-struct-info : syntax -> struct-info?
(define (lookup-struct-info stx struct-name-remappings provide-stx)
  (define id-in-syntax
    (syntax-case stx ()
      [(a b) (syntax a)]
      [_ stx]))
  (define id (free-identifier-mapping-get struct-name-remappings
                                          id-in-syntax
                                          (λ () id-in-syntax)))
  (define v (syntax-local-value id (λ () #f)))
  (define error-name
    (syntax-case provide-stx ()
      [(x . y)
       (identifier? #'x)
       (syntax-e #'x)]
      [_ 'provide/contract]))
  (if (struct-info? v)
      v
      (raise-syntax-error error-name
                          "expected a struct name"
                          provide-stx
                          id)))


(define (add-name-prop name stx)
  (cond
    [(identifier? name)
     (syntax-property stx 'inferred-name (syntax-e name))]
    [(symbol? name)
     (syntax-property stx 'inferred-name name)]
    [else stx]))

;; mangle-id : string syntax ... -> syntax
;; constructs a mangled name of an identifier from an identifier
;; the name isn't fresh, so `id' combined with `ids' must already be unique.
(define (mangle-id prefix id . ids)
  (datum->syntax
   #f
   (string->symbol
    (string-append
     prefix
     (format 
      "-~a~a"
      (syntax->datum id)
      (apply 
       string-append 
       (map 
        (lambda (id)
          (format "-~a" (syntax->datum id)))
        ids)))))))

(define (mangle-id-for-maker prefix id . ids)
  (let ([id-w/out-make (regexp-replace #rx"^make-" (format "~a" (syntax->datum id)) "")])
    (datum->syntax
     #f
     (string->symbol
      (string-append
       "make-"
       prefix
       (format 
        "-~a~a"
        id-w/out-make
        (apply 
         string-append 
         (map 
          (lambda (id)
            (format "-~a" (syntax->datum id)))
          ids))))))))

;; (cons X (listof X)) -> (listof X)
;; returns the elements of `l', minus the last element
;; special case: if l is an improper list, it leaves off
;; the contents of the last cdr (ie, making a proper list
;; out of the input), so (all-but-last '(1 2 . 3)) = '(1 2)
(define (all-but-last l)
  (cond
    [(null? l) (error 'all-but-last "bad input")]
    [(not (pair? l)) '()]
    [(null? (cdr l)) null]
    [(pair? (cdr l)) (cons (car l) (all-but-last (cdr l)))]
    [else (list (car l))]))

;; helper for build-src-loc-string
(define (source->name src)
  (let* ([bs (cond [(bytes? src)  src]
                   [(path? src)   (path->bytes src)]
                   [(string? src) (string->bytes/locale src)]
                   [else #f])]
         [r (and bs (path->main-collects-relative bs))])
    (and bs
         (bytes->string/locale (if (and (pair? r) (eq? 'collects (car r)))
                                   (apply bytes-append 
                                          #"<collects>" 
                                          (map (lambda (s)
                                                 (bytes-append #"/" s))
                                               (cdr r)))
                                   bs)))))

;; build-src-loc-string : (or/c srcloc syntax) -> (union #f string)
(define (build-src-loc-string stx)
  (let-values ([(source line col pos)
                (if (syntax? stx)
                    (values (source->name (syntax-source stx))
                            (syntax-line stx)
                            (syntax-column stx)
                            (syntax-position stx))
                    (if (syntax? (srcloc-source stx))
                      (values (source->name 
                               (resolved-module-path-name 
                                (module-path-index-resolve 
                                 (syntax-source-module
                                  (srcloc-source stx)))))
                              (srcloc-line stx)
                              (srcloc-column stx)
                              (srcloc-position stx))
                      (error 'contract
                             "malformed srcloc has non-syntax source: ~e"
                             stx)))])
    (let ([location (cond [(and line col) (format "~a:~a" line col)]
                          [pos (format "~a" pos)]
                          [else #f])])
      (if (and source location)
          (string-append source ":" location)
          (or location source)))))

(define build-struct-names
  (lambda (name-stx fields omit-sel? omit-set? srcloc-stx)
    (let ([name (symbol->string (syntax-e name-stx))]
          [fields (map symbol->string (map syntax-e fields))]
          [+ string-append])
      (map (lambda (s)
             (datum->syntax name-stx (string->symbol s) srcloc-stx))
           (append
            (list 
             (+ "struct:" name)
             (+ "make-" name)
             (+ name "?"))
            (let loop ([l fields])
              (if (null? l)
                  null
                  (append
                   (if omit-sel?
                       null
                       (list (+ name "-" (car l))))
                   (if omit-set?
                       null
                       (list (+ "set-" name "-" (car l) "!")))
                   (loop (cdr l))))))))))

(define (nums-up-to n)
  (let loop ([i 0])
    (cond
      [(= i n) '()]
      [else (cons i (loop (+ i 1)))])))

#|

;; the code below builds the known-good-syms-ht
;; it should contain only predicates or else 
;; opt/c will misbehave

(define cm
  (parameterize ([read-accept-compiled #t])
    (call-with-input-file
        "C:\\Users\\robby\\git\\plt\\collects\\racket\\compiled\\base_rkt.zo" read)))

(define ns (make-base-namespace))
(parameterize ([current-namespace ns])
  (namespace-require 'racket/base))

(define-values (vars stx) (module-compiled-exports cm))
(define known-good-syms 
  (filter (λ (x) (and (regexp-match #rx"[?]$" (symbol->string x))
                      (procedure-arity-includes? (eval x ns) 1)))
          (map car (cdr (assoc 0 vars)))))
(define table-to-be-turned-into-a-literal-hash
  (map (λ (x) (cons x #t))
       (sort known-good-syms
             string<=?
             #:key symbol->string)))

-- also add not, <, <=, =, >, >=, empty? and cons? to the above

|#

(define known-good-syms-ht 
  '#hash((absolute-path? . #t)
         (arity-at-least? . #t)
         (boolean? . #t)
         (box? . #t)
         (break-parameterization? . #t)
         (byte-pregexp? . #t)
         (byte-ready? . #t)
         (byte-regexp? . #t)
         (byte? . #t)
         (bytes-converter? . #t)
         (bytes-environment-variable-name? . #t)
         (bytes<? . #t)
         (bytes=? . #t)
         (bytes>? . #t)
         (bytes? . #t)
         (channel-put-evt? . #t)
         (channel? . #t)
         (chaperone? . #t)
         (char-alphabetic? . #t)
         (char-blank? . #t)
         (char-ci<=? . #t)
         (char-ci<? . #t)
         (char-ci=? . #t)
         (char-ci>=? . #t)
         (char-ci>? . #t)
         (char-extended-pictographic? . #t)
         (char-graphic? . #t)
         (char-iso-control? . #t)
         (char-lower-case? . #t)
         (char-numeric? . #t)
         (char-punctuation? . #t)
         (char-ready? . #t)
         (char-symbolic? . #t)
         (char-title-case? . #t)
         (char-upper-case? . #t)
         (char-whitespace? . #t)
         (char<=? . #t)
         (char<? . #t)
         (char=? . #t)
         (char>=? . #t)
         (char>? . #t)
         (char? . #t)
         (compile-target-machine? . #t)
         (compiled-expression? . #t)
         (compiled-module-expression? . #t)
         (complete-path? . #t)
         (complex? . #t)
         (continuation-mark-key? . #t)
         (continuation-mark-set? . #t)
         (continuation-prompt-available? . #t)
         (continuation-prompt-tag? . #t)
         (continuation? . #t)
         (custodian-box? . #t)
         (custodian-shut-down? . #t)
         (custodian? . #t)
         (custom-print-quotable? . #t)
         (custom-write? . #t)
         (date*? . #t)
         (date-dst? . #t)
         (date? . #t)
         (directory-exists? . #t)
         (double-flonum? . #t)
         (environment-variables? . #t)
         (eof-object? . #t)
         (ephemeron? . #t)
         (even? . #t)
         (evt? . #t)
         (exact-integer? . #t)
         (exact-nonnegative-integer? . #t)
         (exact-positive-integer? . #t)
         (exact? . #t)
         (exn:break:hang-up? . #t)
         (exn:break:terminate? . #t)
         (exn:break? . #t)
         (exn:fail:contract:arity? . #t)
         (exn:fail:contract:continuation? . #t)
         (exn:fail:contract:divide-by-zero? . #t)
         (exn:fail:contract:non-fixnum-result? . #t)
         (exn:fail:contract:variable? . #t)
         (exn:fail:contract? . #t)
         (exn:fail:filesystem:errno? . #t)
         (exn:fail:filesystem:exists? . #t)
         (exn:fail:filesystem:missing-module? . #t)
         (exn:fail:filesystem:version? . #t)
         (exn:fail:filesystem? . #t)
         (exn:fail:network:errno? . #t)
         (exn:fail:network? . #t)
         (exn:fail:out-of-memory? . #t)
         (exn:fail:read:eof? . #t)
         (exn:fail:read:non-char? . #t)
         (exn:fail:read? . #t)
         (exn:fail:syntax:missing-module? . #t)
         (exn:fail:syntax:unbound? . #t)
         (exn:fail:syntax? . #t)
         (exn:fail:unsupported? . #t)
         (exn:fail:user? . #t)
         (exn:fail? . #t)
         (exn:missing-module? . #t)
         (exn:srclocs? . #t)
         (exn? . #t)
         (file-exists? . #t)
         (file-stream-port? . #t)
         (filesystem-change-evt? . #t)
         (fixnum? . #t)
         (flonum? . #t)
         (handle-evt? . #t)
         (hash-empty? . #t)
         (hash-ephemeron? . #t)
         (hash-eq? . #t)
         (hash-equal-always? . #t)
         (hash-equal? . #t)
         (hash-eqv? . #t)
         (hash-placeholder? . #t)
         (hash-strong? . #t)
         (hash-weak? . #t)
         (hash? . #t)
         (identifier? . #t)
         (immutable? . #t)
         (impersonator-property-accessor-procedure? . #t)
         (impersonator-property? . #t)
         (impersonator? . #t)
         (inexact-real? . #t)
         (inexact? . #t)
         (input-port? . #t)
         (inspector? . #t)
         (integer? . #t)
         (internal-definition-context? . #t)
         (keyword<? . #t)
         (keyword? . #t)
         (liberal-define-context? . #t)
         (link-exists? . #t)
         (list? . #t)
         (log-receiver? . #t)
         (logger? . #t)
         (module-compiled-cross-phase-persistent? . #t)
         (module-declared? . #t)
         (module-path-index? . #t)
         (module-path? . #t)
         (module-predefined? . #t)
         (mpair? . #t)
         (namespace-anchor? . #t)
         (namespace? . #t)
         (negative? . #t)
         (null? . #t)
         (number? . #t)
         (odd? . #t)
         (output-port? . #t)
         (pair? . #t)
         (parameter? . #t)
         (parameterization? . #t)
         (path-for-some-system? . #t)
         (path-string? . #t)
         (path<? . #t)
         (path? . #t)
         (phantom-bytes? . #t)
         (placeholder? . #t)
         (plumber-flush-handle? . #t)
         (plumber? . #t)
         (port-closed? . #t)
         (port-counts-lines? . #t)
         (port-provides-progress-evts? . #t)
         (port-waiting-peer? . #t)
         (port-writes-atomic? . #t)
         (port-writes-special? . #t)
         (port? . #t)
         (portal-syntax? . #t)
         (positive? . #t)
         (prefab-key? . #t)
         (pregexp? . #t)
         (primitive-closure? . #t)
         (primitive? . #t)
         (procedure-arity? . #t)
         (procedure-impersonator*? . #t)
         (procedure-struct-type? . #t)
         (procedure? . #t)
         (progress-evt? . #t)
         (pseudo-random-generator-vector? . #t)
         (pseudo-random-generator? . #t)
         (rational? . #t)
         (readtable? . #t)
         (real? . #t)
         (regexp? . #t)
         (relative-path? . #t)
         (rename-transformer? . #t)
         (resolved-module-path? . #t)
         (security-guard? . #t)
         (semaphore-peek-evt? . #t)
         (semaphore-try-wait? . #t)
         (semaphore? . #t)
         (sequence? . #t)
         (set!-transformer? . #t)
         (single-flonum? . #t)
         (special-comment? . #t)
         (srcloc? . #t)
         (stencil-vector? . #t)
         (string-ci<=? . #t)
         (string-ci<? . #t)
         (string-ci=? . #t)
         (string-ci>=? . #t)
         (string-ci>? . #t)
         (string-environment-variable-name? . #t)
         (string-locale-ci<? . #t)
         (string-locale-ci=? . #t)
         (string-locale-ci>? . #t)
         (string-locale<? . #t)
         (string-locale=? . #t)
         (string-locale>? . #t)
         (string-port? . #t)
         (string<=? . #t)
         (string<? . #t)
         (string=? . #t)
         (string>=? . #t)
         (string>? . #t)
         (string? . #t)
         (struct-accessor-procedure? . #t)
         (struct-constructor-procedure? . #t)
         (struct-mutator-procedure? . #t)
         (struct-predicate-procedure? . #t)
         (struct-type-authentic? . #t)
         (struct-type-property-accessor-procedure? . #t)
         (struct-type-property-predicate-procedure? . #t)
         (struct-type-property? . #t)
         (struct-type-sealed? . #t)
         (struct-type? . #t)
         (struct? . #t)
         (subprocess? . #t)
         (symbol-interned? . #t)
         (symbol-unreadable? . #t)
         (symbol<? . #t)
         (symbol? . #t)
         (syntax-binding-set? . #t)
         (syntax-original? . #t)
         (syntax-tainted? . #t)
         (syntax? . #t)
         (terminal-port? . #t)
         (thread-cell-values? . #t)
         (thread-cell? . #t)
         (thread-dead? . #t)
         (thread-group? . #t)
         (thread-running? . #t)
         (thread? . #t)
         (unquoted-printing-string? . #t)
         (variable-reference-constant? . #t)
         (variable-reference-from-unsafe? . #t)
         (variable-reference? . #t)
         (vector? . #t)
         (void? . #t)
         (weak-box? . #t)
         (will-executor? . #t)
         (zero? . #t)
         ;; special cases
         (not . #t)
         (< . #t)
         (<= . #t)
         (= . #t)
         (> . #t)
         (>= . #t)
         ;; from racket/private/list-predicates
         (empty? . #t)
         (cons? . #t)))

(define (known-good-contract? id)
  (define r-id (syntax-e id))
  (and (symbol? r-id)
       (hash-ref known-good-syms-ht r-id #f)
       (free-identifier=? id (datum->syntax #'here r-id))))

(define (known-good-contracts)
  (for/list ([k (in-list (sort (hash-keys known-good-syms-ht) symbol<?))])
    (datum->syntax #'here k)))

(define (gen-id sym)
  (car (generate-temporaries (list sym))))
