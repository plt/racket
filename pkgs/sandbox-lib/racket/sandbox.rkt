#lang racket/base

(require racket/port
         racket/path
         racket/list
         racket/string
         racket/file
         syntax/moddep
         racket/gui/dynamic
         planet/config
         setup/dirs
         setup/link)

(provide gui?
         sandbox-gui-available
         sandbox-gui-yield?
         sandbox-init-hook
         sandbox-reader
         sandbox-input
         sandbox-output
         sandbox-error-output
         sandbox-propagate-breaks
         sandbox-coverage-enabled
         sandbox-namespace-specs
         sandbox-override-collection-paths
         sandbox-path-permissions
         sandbox-security-guard
         sandbox-network-guard
         sandbox-exit-handler
         sandbox-make-namespace
         sandbox-make-inspector
         sandbox-make-code-inspector
         sandbox-make-logger
         sandbox-make-plumber
         sandbox-make-environment-variables
         sandbox-memory-limit
         sandbox-eval-limits
         sandbox-eval-handlers
         sandbox-propagate-exceptions
         sandbox-run-submodules
         call-with-trusted-sandbox-configuration
         evaluator-alive?
         kill-evaluator
         break-evaluator
         get-user-custodian
         set-eval-limits
         set-eval-handler
         put-input
         get-output
         get-error-output
         get-uncovered-expressions
         call-in-sandbox-context
         make-evaluator
         make-module-evaluator
         call-in-nested-thread*
         call-with-limits
         with-limits
         call-with-deep-time-limit
         with-deep-time-limit
         call-with-custodian-shutdown
         call-with-killing-threads
         exn:fail:sandbox-terminated?
         exn:fail:sandbox-terminated-reason
         exn:fail:resource?
         exn:fail:resource-resource
         default-language-readers)

; for backward compatibility; maybe it should be removed:
(define gui? (gui-available?))

;; When this parameter is #t, it is adjusted when creating a sandbox:
(define sandbox-gui-available (make-parameter #t (lambda (v) (and v #t))))

(define-syntax mz/mr ; use a value for plain racket, or pull a gui binding
  (syntax-rules ()
    [(mz/mr mzval mrsym)
     (if (sandbox-gui-available) (gui-dynamic-require 'mrsym) mzval)]))

;; When this parameter is #t, the evaluator thread (an eventspace handler
;; thread) handles events while waiting for things to evaluate.
(define sandbox-gui-yield? (make-parameter #f (lambda (v) (and v #t))))

;; Configuration ------------------------------------------------------------

(define sandbox-init-hook    (make-parameter void))
(define sandbox-input        (make-parameter #f))
(define sandbox-output       (make-parameter #f))
(define sandbox-error-output
  (make-parameter (lambda () (dup-output-port (current-error-port)))))
(define sandbox-memory-limit (make-parameter 30))       ; 30mb total
(define sandbox-eval-limits  (make-parameter '(30 20))) ; 30sec, 20mb
(define sandbox-propagate-breaks (make-parameter #t))
(define sandbox-coverage-enabled (make-parameter #f))
(define sandbox-propagate-exceptions (make-parameter #t))
(define sandbox-run-submodules (make-parameter null))

(define (call-with-trusted-sandbox-configuration thunk)
  (parameterize ([sandbox-propagate-breaks    #t]
                 [sandbox-override-collection-paths '()]
                 [sandbox-security-guard      current-security-guard]
                 [sandbox-exit-handler        (exit-handler)]
                 [sandbox-make-inspector      current-inspector]
                 [sandbox-make-code-inspector current-code-inspector]
                 [sandbox-make-logger         current-logger]
                 [sandbox-make-plumber        (lambda () (current-plumber))]
                 [sandbox-make-environment-variables current-environment-variables]
                 [sandbox-memory-limit        #f]
                 [sandbox-eval-limits         #f]
                 [sandbox-eval-handlers       '(#f #f)])
    (thunk)))

(define (sandbox-make-namespace)
  ((mz/mr make-base-namespace make-gui-namespace)))

(define sandbox-namespace-specs
  (make-parameter `(,sandbox-make-namespace
                    #| no modules here by default |#)))

(define (default-sandbox-reader source)
  (for/list ([x (in-producer read-syntax eof source)]) x))

(define sandbox-reader (make-parameter default-sandbox-reader))

(define sandbox-override-collection-paths (make-parameter '()))

(define teaching-langs
  '(beginner beginner-abbr intermediate intermediate-lambda advanced))

;; Security Guard -----------------------------------------------------------

(define sep (bytes-ref (path->bytes (simplify-path "/")) 0)) ; '\' on windows

(define (simplify-path* path)
  (cond
   [(symbol? path) #f]
   [(and (pair? path) (eq? 'submod (car path)))
    (simplify-path* (cadr path))]
   [else
    (simple-form-path (cond [(bytes? path) (bytes->path path)]
                            [(string? path) (string->path path)]
                            [else path]))]))

;; 'read-bytecode is special, it's higher than 'read, but not lower than
;; 'delete.
(define permission-order '(execute write delete read-bytecode read exists))
(define (perm<=? p1 p2)
  (or (eq? p1 p2)
      (and (not (eq? 'read-bytecode p1))
           (memq p1 (memq p2 permission-order))
           #t)))

;; gets a path (can be bytes/string), returns a regexp for that path that
;; matches also subdirs (if it's a directory)
(define path->bregexp
  (let* ([sep-re    (regexp-quote (bytes sep))]
         [last-sep  (byte-regexp (bytes-append sep-re #"?$"))]
         [suffix-re (bytes-append #"(?:$|" sep-re #")")])
    (lambda (path)
      (if (byte-regexp? path)
        path
        (let* ([path (path->bytes (simplify-path* path))]
               [path (regexp-quote (regexp-replace last-sep path #""))])
          (byte-regexp (bytes-append #"^" path suffix-re)))))))

(define sandbox-path-permissions
  (make-parameter '()
    (lambda (new)
      (map (lambda (perm)
             (if (and (pair? perm) (symbol? (car perm))
                      (pair? (cdr perm)) (null? (cddr perm)))
               (list (car perm) (path->bregexp (cadr perm)))
               (error 'sandbox-path-permissions
                      "bad permission spec: ~e" perm)))
           new))))

;; compresses the (sandbox-path-permissions) value to a "compressed" list of
;; (permission regexp ...) where each permission appears exactly once (so it's
;; quicker to test it later, no need to scan the whole permission list).
(define compressed-path-permissions
  (let ([t (make-weak-hasheq)])
    (define (compress-permissions ps)
      (map (lambda (perm)
             (let* ([ps (filter (lambda (p) (perm<=? perm (car p))) ps)]
                    [ps (remove-duplicates (map cadr ps))])
               (cons perm ps)))
           permission-order))
    (lambda ()
      (define ps (sandbox-path-permissions))
      (or (hash-ref t ps #f)
          (let ([c (compress-permissions ps)]) (hash-set! t ps c) c)))))

;; similar to the security guard, only with a single mode for simplification;
;; assumes valid mode and simplified path
(define (check-sandbox-path-permissions path needed)
  (define bpath (path->bytes path))
  (define perms (compressed-path-permissions))
  (ormap (lambda (rx) (regexp-match? rx bpath)) (cdr (assq needed perms))))

(define (call-and-accumulate-captured-filesystem-accesses saw-accesses thunk)
  ;; Capture any filesystem accesses needed during the evaluation of `thunk`,
  ;; so that the same evaluation can work in a nested sandbox.
  (parameterize ([current-security-guard (make-security-guard
                                          (current-security-guard)
                                          (lambda (who path perms)
                                            (define old-perm (hash-ref saw-accesses path #f))
                                            (define new-perm
                                              (for/fold ([perm old-perm]) ([a-perm (in-list perms)])
                                                (cond
                                                 [(not perm) a-perm]
                                                 [(perm<=? a-perm perm) perm]
                                                 [else a-perm])))
                                            (unless (eq? old-perm new-perm)
                                              (hash-set! saw-accesses path new-perm)))
                                          void)])
    (thunk)))

(define sandbox-network-guard
  (make-parameter (lambda (what . xs)
                    (error what "network access denied: ~e" xs))))

(define (make-default-sandbox-guard)
  (define orig-security (current-security-guard))
  (make-security-guard
   orig-security
   (lambda (what path modes)
     (when path
       (define spath (parameterize ([current-security-guard orig-security])
                       (simplify-path* path)))
       (define maxperm
         ;; assumes that the modes are valid (ie, in the above list)
         (cond [(null? modes) (error 'default-sandbox-guard
                                     "got empty mode list for ~e and ~e"
                                     what path)]
               [(null? (cdr modes)) (car modes)] ; common case
               [else (foldl (lambda (x max) (if (perm<=? max x) x max))
                            (car modes) (cdr modes))]))
       (unless (check-sandbox-path-permissions spath maxperm)
         (error what "`~a' access denied for ~a"
                (string-append* (add-between (map symbol->string modes) "+"))
                path))))
   (lambda args (apply (sandbox-network-guard) args))))

(define sandbox-security-guard
  (make-parameter make-default-sandbox-guard
    (lambda (x)
      (if (or (security-guard? x)
              (and (procedure? x) (procedure-arity-includes? x 0)))
        x
        (raise-argument-error
         'sandbox-security-guard
         "(or/c security-guard? (-> security-guard?))" x)))))

;; this is never really used (see where it's used in the evaluator)
(define (default-sandbox-exit-handler _) (error 'exit "sandbox exits"))

(define sandbox-exit-handler (make-parameter default-sandbox-exit-handler))

(define sandbox-make-inspector
  (make-parameter (lambda () (make-inspector (current-inspector)))))

(define sandbox-make-code-inspector
  (make-parameter (lambda () (make-inspector (current-code-inspector)))))

(define sandbox-make-logger (make-parameter current-logger))

(define sandbox-make-plumber (make-parameter 'propagate))

(define sandbox-make-environment-variables (make-parameter
                                            (lambda ()
                                              (environment-variables-copy
                                               (current-environment-variables)))))

(define (compute-permissions for-require for-load)
  ;; `for-require' is a list of module paths and paths that will be `reqiure'd,
  ;; while `for-load' is a list of path (strings) that will be `load'ed.
  (define cpaths (map path->complete-path for-load))
  (append (map (lambda (p) `(read ,(path->bytes p))) cpaths)
          ;; when loading a module from "/foo/bar/baz.rkt" racket will try to see
          ;; if "/foo/bar" exists, so allow these paths too; it might be needed
          ;; to allow 'exists on any parent path, but I'm not sure that this is
          ;; safe in terms of security, so put just the immediate parent dir in
          (filter-map (lambda (p)
                        (let ([p (and (file-exists? p) (path-only p))])
                          (and p `(exists ,(path->bytes p)))))
                      cpaths)
          (module-specs->path-permissions for-require)))

;; computes permissions that are needed for require specs (`read-bytecode' for
;; all files and "compiled" subdirs, `exists' for the base-dir)
(define (module-specs->path-permissions mods)
  (define paths (module-specs->non-lib-paths mods))
  (define bases
    (let loop ([paths paths] [bases '()])
      (if (null? paths)
          (reverse bases)
          (let-values ([(base* name dir?) (split-path (car paths))])
            (define base (simplify-path* base*))
            (loop (cdr paths)
                  (if (member base bases) bases (cons base bases)))))))
  (add-compiled-file-roots
   (append (map (lambda (p) `(read-bytecode ,p)) paths)
           (map (lambda (b) `(read-bytecode ,(build-path b "compiled"))) bases)
           (map (lambda (b) `(exists ,b)) bases))))

;; For each 'read-bytecode entry in lm for each root in
;; `(current-compiled-file-roots)`, add the rerooted path
(define (add-compiled-file-roots l)
  (append
   l
   (for/list ([e (in-list l)]
              #:when (eq? 'read-bytecode (car e))
              ;; For every absolute root, add this directory
              ;; under that root:
              [root (in-list (current-compiled-file-roots))]
              #:when (and (path? root)
                          (absolute-path? root)))
     `(read-bytecode ,(reroot-path (cadr e) root)))))

;; takes a module-spec list and returns all module paths that are needed
;; ==> ignores (lib ...) modules
(define (module-specs->non-lib-paths mods)
  (define (lib? x)
    (if (module-path-index? x)
      (let-values ([(m base) (module-path-index-split x)]) (lib? m))
      (or (symbol? x) (and (pair? x) (eq? 'lib (car x))))))
  ;; turns a module spec to a simple one (except for lib specs)
  (define (simple-modspec mod)
    (cond [(and (pair? mod) (eq? 'lib (car mod))) #f]
          [(module-path? mod)
           (simplify-path* (resolve-module-path mod #f))]
          [(path? mod)
           (simplify-path* mod)]
          [(not (and (pair? mod) (pair? (cdr mod))))
           ;; don't know what this is, leave as is
           #f]
          [(eq? 'only (car mod))
           (simple-modspec (cadr mod))]
          [(eq? 'rename (car mod))
           (simple-modspec (cadr mod))]
          [(and (eq? 'prefix (car mod)) (pair? (cddr mod)))
           (simple-modspec (caddr mod))]
          [else #f]))
  (let loop ([todo (filter-map simple-modspec mods)]
             [r '()])
    (cond
      [(null? todo) r]
      [(member (car todo) r) (loop (cdr todo) r)]
      [else
       (define path (car todo))
       (loop (append (cdr todo)
                     (filter-map
                      (lambda (i)
                        (simplify-path* (resolve-module-path-index i path)))
                      (filter (lambda (i)
                                (and (module-path-index? i) (not (lib? i))))
                              (append-map cdr (let ([m (get-module-code
                                                        path
                                                        #:extension-handler
                                                        (lambda (path loader?) #f))])
                                                (if m
                                                  (module-compiled-imports m)
                                                  null))))))
             (let ([l (cons path r)])
               ;; If we need an .rkt path, also allow access to .ss path
               (if (regexp-match? #rx#"[.]rkt$" (path->bytes path))
                 (cons (path-replace-suffix path #".ss") l)
                 l)))])))

;; Resources ----------------------------------------------------------------

(define-struct (exn:fail:resource exn:fail) (resource))

(define memory-accounting? (custodian-memory-accounting-available?))

;; similar to `call-in-nested-thread', but propagates killing the thread,
;; shutting down the custodian or setting parameters and thread cells;
;; optionally with thunks to call for kill/shutdown instead.
(define (call-in-nested-thread*
         thunk
         [kill     (lambda () (kill-thread (current-thread)))]
         [shutdown (lambda () (custodian-shutdown-all (current-custodian)))])
  (define p #f)
  (define c (make-custodian (current-custodian)))
  (define b (make-custodian-box c #t))
  (define break? (break-enabled))
  (parameterize-break #f
    (with-handlers ([(lambda (_) (not p))
                     ;; if the after thunk was not called, then this error is
                     ;; about the thread dying unnaturally, so propagate
                     ;; whatever it did
                     (lambda (_)
                       ((if (custodian-box-value b) kill shutdown)))])
      (dynamic-wind void
        (lambda ()
          (parameterize ([current-custodian c])
            (call-in-nested-thread
             (lambda ()
               (break-enabled break?)
               (dynamic-wind void thunk
                 ;; this should always be called unless the thread is killed
                 ;; or the custodian is shutdown, distinguish the two cases
                 ;; through the above box
                 (lambda ()
                   (set! p (current-preserved-thread-cell-values))))))))
        (lambda () (when p (current-preserved-thread-cell-values p)))))))

;; useful wrapper around the above: run thunk, return one of:
;; - (list values val ...)
;; - (list raise exn)
;; - 'kill or 'shut
(define (nested thunk)
  (call-in-nested-thread*
   (lambda ()
     (with-handlers ([void (lambda (e) (list raise e))])
       (call-with-values thunk (lambda vs (list* values vs)))))
   (lambda () 'kill) (lambda () 'shut)))

(define (call-with-limits sec mb thunk)
  ;; note that when the thread is killed after using too much memory or time,
  ;; then all thread-local changes (parameters and thread cells) are discarded
  (define-values [cust cust-box]
    (if (and mb memory-accounting?)
      ;; memory limit, set on a new custodian so if there's an out-of-memory
      ;; error, the user's custodian is still alive
      (let ([c (make-custodian (current-custodian))])
        (custodian-limit-memory c (inexact->exact (round (* mb 1024 1024))) c)
        (values c (make-custodian-box c #t)))
      (values (current-custodian) #f)))
  (define timeout? #f)
  (define r
    (parameterize ([current-custodian cust])
      (if sec
        (nested
         (lambda ()
           ;; time limit
           (when sec
             (define t (current-thread))
             (thread (lambda ()
                       (unless (sync/timeout sec t) (set! timeout? #t))
                       (kill-thread t))))
           (thunk)))
        (nested thunk))))
  (cond [timeout? (set! r 'time)]
        [(and cust-box (not (custodian-box-value cust-box)))
         (if (memq r '(kill shut)) ; should always be 'shut
           (set! r 'memory)
           (format "cust died with: ~a" r))]) ; throw internal error below
  (case r
    [(kill) (kill-thread (current-thread))]
    [(shut) (custodian-shutdown-all (current-custodian))]
    [(memory time)
     (raise (make-exn:fail:resource (format "with-limit: out of ~a" r)
                                    (current-continuation-marks)
                                    r))]
    [else (if (pair? r)
            (apply (car r) (cdr r))
            (error 'call-with-limits "internal error in nested: ~e" r))]))

(define-syntax with-limits
  (syntax-rules ()
    [(with-limits sec mb body ...)
     (call-with-limits sec mb (lambda () body ...))]))

(define (custodian-managed-list* cust super)
  (define ms (custodian-managed-list cust super))
  (append-map
   (λ (v)
     (if (custodian? v)
       (custodian-managed-list* v cust)
       (list v)))
   ms))

(define (call-with-deep-time-limit secs thunk)
  (define me
    (current-custodian))
  (define cust
    (make-custodian me))
  (define timeout-evt
    (handle-evt
     (alarm-evt (+ (current-inexact-monotonic-milliseconds)
                   (* 1000 secs))
                #t)
     (λ (a) #f)))

  (define results null)
  (parameterize ([current-custodian cust]
                 [current-subprocess-custodian-mode 'kill])
    (thread (lambda () (set! results (call-with-values thunk list)))))

  (define r
    (let loop ()
      (define ms (custodian-managed-list* cust me))
      (define (thread-or-subprocess? x)
        (or (thread? x)
            (subprocess? x)))
      (define ts (filter thread-or-subprocess? ms))
      (sync
       (if (empty? ts)
         always-evt
         (handle-evt
          (apply choice-evt ts)
          (λ (_)
            (loop))))
       timeout-evt)))
  (custodian-shutdown-all cust)
  (unless r
    (raise (make-exn:fail:resource "call-with-deep-time-limit: out of time"
                                   (current-continuation-marks)
                                   'deep-time)))
  (apply values results))

(define-syntax-rule (with-deep-time-limit sec body ...)
  (call-with-deep-time-limit sec (λ () body ...)))

;; other resource utilities

(define (call-with-custodian-shutdown thunk)
  (define cust (make-custodian (current-custodian)))
  (define r (parameterize ([current-custodian cust]) (nested thunk)))
  (case r
    [(kill) (kill-thread (current-thread))]
    [(shut) (custodian-shutdown-all (current-custodian))]
    [else (apply (car r) (cdr r))]))

(define (call-with-killing-threads thunk)
  (define cur (current-custodian))
  (define sub (make-custodian cur))
  (define r (parameterize ([current-custodian sub]) (nested thunk)))
  (let kill-all ([x sub])
    (cond [(custodian? x) (for-each kill-all (custodian-managed-list x cur))]
          [(thread? x) (kill-thread x)]))
  (case r
    [(kill) (kill-thread (current-thread))]
    [(shut) (custodian-shutdown-all (current-custodian))]
    [else (apply (car r) (cdr r))]))

(define sandbox-eval-handlers
  (make-parameter (list #f call-with-custodian-shutdown)))

;; Execution ----------------------------------------------------------------

(define (literal-identifier=? x y)
  (or (free-identifier=? x y) (eq? (syntax-e x) (syntax-e y))))

(define-namespace-anchor anchor)

(define (make-evaluation-namespace)
  (define specs   (sandbox-namespace-specs))
  (define new-ns  ((car specs)))
  (define orig-ns (namespace-anchor->empty-namespace anchor))
  (define mods    (cdr specs))
  (namespace-call-with-registry-lock
   orig-ns
   (lambda ()
     (parameterize ([current-namespace orig-ns])
       (for ([mod (in-list mods)]) (dynamic-require mod #f)))))
  (parameterize ([current-namespace new-ns])
    (for ([mod (in-list mods)]) (namespace-attach-module orig-ns mod)))
  new-ns)

(define (extract-required language requires)
  (cond
    [(string? language) (cons language requires)]
    [(not (pair? language)) requires]
    [(memq (car language) '(lib file planet quote)) (cons language requires)]
    [(eq? (car language) 'begin) requires]
    [else (error 'extract-required "bad language spec: ~e" language)]))

(define (input->port inp)
  ;; returns #f when it can't create a port
  (cond [(input-port? inp) inp]
        [(string? inp) (open-input-string inp #f)]
        [(bytes?  inp) (open-input-bytes inp #f)]
        [(path?   inp) (open-input-file inp)]
        [else #f]))

;; Gets an input spec returns a list of syntaxes and a default source to filter
;; uncovered expressions with.  The input can be a list of sexprs/syntaxes, or
;; a list with a single input port spec (path/string/bytes) value.  Note that
;; the source can be a filtering function.
(define (input->code inps source-in n accept-lang? #:readers [reqreaders #f])
  (if (null? inps)
    (values '() source-in)
    (let ([p (input->port (car inps))])
      (cond [(and p (null? (cdr inps)))
             (port-count-lines! p)
             (define source
               (or (object-name p)
                   ;; just in case someone uses a function as the source...
                   (if (procedure? source-in)
                     (lambda (x) (eq? x source-in))
                     source-in)))
             (define code
               (parameterize ([current-input-port p])
                 (if accept-lang?
                   (parameterize ([read-accept-reader #t] ; needed for #lang too
                                  [read-accept-lang #t]
                                  [current-reader-guard (lambda (v)
                                                          (when reqreaders
                                                            (unless (member v reqreaders)
                                                              (error 'make-evaluator "disallowed reader module path: ~.s" v)))
                                                          v)])
                     ((sandbox-reader) source))
                   ((sandbox-reader) source))))
             ;; close a port if we opened it
             (unless (eq? p (car inps)) (close-input-port p))
             (values code source)]
            [p (error 'input->code "ambiguous inputs: ~e" inps)]
            [(andmap syntax? inps)
             (values inps
                     (let ([srcs (remove-duplicates (map syntax-source inps)
                                                    equal?)])
                       (if (null? (cdr srcs))
                         (car srcs)
                         (lambda (x) (memq x srcs)))))]
            [else (let loop ([inps inps] [n n] [r '()])
                    (if (null? inps)
                      (values (reverse r) source-in)
                      (loop (cdr inps) (and n (add1 n))
                            ;; 1st at line#1, pos#1, 2nd at line#2, pos#2 etc
                            ;; (starting from the `n' argument)
                            (cons (add-location (car inps)
                                                (list source-in n (and n 0) n (and n 1)))
                                  r))))]))))

(define orig-stx (read-syntax 'src (open-input-string "0"))) ; for "is original?" property
(define (make-orig x loc) (datum->syntax #f x loc orig-stx))

(define (add-location x loc)
  (cond [(null? x) null]
        [(list? x)
         ;; For a list, generate a syntax-object wrapper consistent with 
         ;; an absence of `.'s in the reader's input:
         (make-orig (for/list ([i (in-list x)])
                      (add-location i loc))
                    loc)]
        [(pair? x) (make-orig (cons (add-location (car x) loc) 
                                    (add-location (cdr x) loc))
                              loc)]
        [(vector? x) (make-orig (for/vector ([i (in-vector x)])
                                  (add-location i loc))
                                loc)]
        [else (make-orig x loc)]))

(define ((init-hook-for-language language))
  (cond [(not (and (pair? language) (eq? 'special (car language))))
         (void)]
        [(eq? (cadr language) 'r5rs)
         (read-case-sensitive #f)
         (read-square-bracket-as-paren #f)
         (read-curly-brace-as-paren #f)
         (read-accept-infix-dot #f)]
        [(memq (cadr language) teaching-langs)
         (read-case-sensitive #t)
         (read-decimal-as-inexact #f)
         ;; needed to make the test-engine work
         (define orig-ns (namespace-anchor->empty-namespace anchor))
         (namespace-call-with-registry-lock
          orig-ns
          (lambda ()
            (parameterize ([current-namespace orig-ns])
              (dynamic-require 'racket/class #f))))
         (namespace-attach-module orig-ns 'racket/class)]))

;; Returns a single (module ...) or (begin ...) expression (a `begin' list will
;; be evaluated one by one -- the language might not have a `begin'), and a
;; default source to filter uncovered expressions with.
;;
;; FIXME: inserting `#%require's here is bad if the language has a
;; `#%module-begin' that processes top-level forms specially.
;; A more general solution would be to create a new module that exports
;; the given language plus all of the given extra requires.
;;
;; We use `#%require' because, unlike the `require' of racket/base,
;; it comes from `#%kernel', so it's always present through
;; transitive requires.
(define (build-program language requires input-program)
  (define-values [prog-stxs source] (input->code input-program 'program 1 #f))
  (define (intro stx)
    ;; HACK: Using `namespace-syntax-introduce` injects a fallback layer
    ;; to avoid "ambiguous binding" errors when a host module includes
    ;; a `#%require` binding:
    (parameterize ([current-namespace (make-base-empty-namespace)])
      (namespace-syntax-introduce stx)))
  (define body (append (if (and (pair? requires) (eq? 'begin (car requires)))
                         (cdr requires)
                         (map (lambda (r) (list (intro #'#%require) r)) requires))
                       prog-stxs))
  (define (use-lang lang) `(module program ,lang . ,body))
  (values (cond [(decode-language language) => use-lang]
                [(module-path? language) (use-lang language)]
                [(and (list? language) (eq? 'begin (car language)))
                 (append language body)]
                [else (error 'make-evaluator "bad language spec: ~e" language)])
          source))

(define (decode-language language)
  (cond [(and (list? language)
              (= 2 (length language))
              (eq? (car language) 'special)
              (memq (cadr language) teaching-langs))
         `(lib ,(format "htdp-~a.rkt" (cadr language)) "lang")]
        [(equal? language '(special r5rs))
         `(lib "lang.rkt" "r5rs")]
        [else #f]))

;; Like a toplevel (eval `(begin ,@exprs)), but the language that is used may
;; not have a begin.
(define (eval* exprs)
  (call-with-continuation-prompt
   (lambda ()
     (if (null? exprs)
       (void)
       (let ([deftag (default-continuation-prompt-tag)])
         (let loop ([expr (car exprs)] [exprs (cdr exprs)])
           (if (null? exprs)
             (eval expr)
             (begin (call-with-continuation-prompt
                     (lambda () (eval expr))
                     deftag
                     (lambda (x) (abort-current-continuation deftag x)))
                    (loop (car exprs) (cdr exprs))))))))))

;; We need a powerful enough code inspector to invoke the errortrace library
;; (indirectly through private/sandbox-coverage).  But there is a small problem
;; here -- errortrace/stacktrace.rkt will grab the declaration-time code inspector.
;; So we grab it here too, and use it to wrap the code that invokes errortrace. 
(define orig-code-inspector (variable-reference->module-declaration-inspector
                             (#%variable-reference)))

(define (evaluate-program program limit-thunk submod-names uncovered! allow-syntactic-requires)
  (define get-uncovered-expressions
    (cond
      [uncovered!
       (parameterize ([current-code-inspector orig-code-inspector])
         (current-compile
          ((dynamic-require 'racket/private/sandbox-coverage 'make-errortrace-compile-handler)))
         (dynamic-require 'racket/private/sandbox-coverage 'get-uncovered-expressions))]
      [else void]))
  (define ns
    (syntax-case* program (module) literal-identifier=?
      [(module mod . body)
       (identifier? #'mod)
       (let ([mod #'mod])
         (lambda ()
           (eval `(,#'require (quote ,mod)))
           (for ([submod-name (in-list submod-names)])
             (eval `(when (module-declared? '(submod (quote ,mod) ,submod-name) #f)
                      (dynamic-require '(submod (quote ,mod) ,submod-name) #f))))
           (module->namespace `(quote ,(syntax-e mod)))))]
      [_else #f]))
  ;; the actual evaluation happens under the specified limits
  (parameterize ([current-load-relative-directory
                  (let* ([d (and (syntax? program) (syntax-source program))]
                         [d (and (path-string? d) (path-only d))])
                    (if (and d (directory-exists? d))
                      d
                      (current-load-relative-directory)))])
    ((limit-thunk (lambda ()
                    (cond
                      [(and (pair? program) (eq? 'begin (car program)))
                       (eval* (cdr program))]
                      [allow-syntactic-requires
                       (define c (parameterize ([current-module-name-resolver
                                                 (let ([mnr (current-module-name-resolver)])
                                                   (case-lambda
                                                     [(resolved-mod ns) (mnr resolved-mod ns)]
                                                     [(mod-path wrt-resolved-mod src-stx load?)
                                                      ;; The intent is that a non-#f `src-stx` indicates
                                                      ;; a `require` that appears in `program` --- as opposed
                                                      ;; to, say, a `dynamic-require` that implements a
                                                      ;; `lazy-require` in a macro implementation
                                                      (when src-stx
                                                        (unless (or (member mod-path allow-syntactic-requires)
                                                                    ;; always allow relative submodule paths:
                                                                    (and (list? mod-path)
                                                                         (= 3 (length mod-path))
                                                                         (eq? (car mod-path) 'submod)
                                                                         (or (equal? (cadr mod-path) ".")
                                                                             (equal? (cadr mod-path) ".."))))
                                                          (error 'module "disallowed `require` module path: ~.s"
                                                                 mod-path)))
                                                      (mnr mod-path wrt-resolved-mod src-stx load?)]))])
                                   (compile program)))
                       (eval c)]
                      [else
                       (eval program)])
                    (when ns (set! ns (ns)))))))
  (when uncovered!
    (uncovered! (list (get-uncovered-expressions) get-uncovered-expressions)))
  (when (namespace? ns) (current-namespace ns)))

(define null-input         (open-input-bytes #""))

;; special message values for the evaluator procedure, also inside the user
;; context they're used for function applications.
(define-struct evaluator-message (msg args))
(define-syntax define-evaluator-messenger
  (syntax-rules ()
    ;; with extra args
    [(define-evaluator-messenger (name arg ...) msg)
     (define (name evaluator arg ...)
       (evaluator (make-evaluator-message msg (list arg ...))))]
    [(define-evaluator-messenger (name . args) msg)
     (define (name evaluator . args)
       (evaluator (make-evaluator-message msg (list* args))))]
    ;; without
    [(define-evaluator-messenger name msg)
     (define name
       (let ([evmsg (make-evaluator-message msg '())])
         (lambda (evaluator) (evaluator evmsg))))]))

(define-evaluator-messenger evaluator-alive? 'alive?)
(define-evaluator-messenger kill-evaluator 'kill)
(define-evaluator-messenger break-evaluator 'break)
(define-evaluator-messenger get-user-custodian 'user-cust)
(define-evaluator-messenger (set-eval-limits secs mb) 'limits)
(define-evaluator-messenger (set-eval-handler handler) 'handler)
(define-evaluator-messenger (put-input . xs) 'input)
(define-evaluator-messenger get-output 'output)
(define-evaluator-messenger get-error-output 'error-output)
(define-evaluator-messenger (get-uncovered-expressions . xs) 'uncovered)
(define (call-in-sandbox-context evaluator thunk [unrestricted? #f])
  (evaluator (make-evaluator-message (if unrestricted? 'thunk* 'thunk)
                                     (list thunk))))

(define-struct (exn:fail:sandbox-terminated exn:fail) (reason) #:transparent)
(define (make-terminated reason)
  (make-exn:fail:sandbox-terminated
   (format "evaluator: terminated (~a)" reason)
   (current-continuation-marks)
   reason))

(define (make-evaluator* who init-hook allow-for-require allow-for-load allow-syntactic-requires program-maker)
  (define orig-code-inspector (current-code-inspector))
  (define orig-security-guard (current-security-guard))
  (define orig-cust     (current-custodian))
  (define memory-cust   (make-custodian orig-cust))
  (define memory-cust-box (make-custodian-box memory-cust #t))
  (define user-cust     (make-custodian memory-cust))
  (define user-cust-box (make-custodian-box user-cust #t))
  (define coverage?     (sandbox-coverage-enabled))
  (define propagate-exceptions? (sandbox-propagate-exceptions))
  (define uncovered     #f)
  (define default-coverage-source-filter #f)
  (define input-ch      (make-channel))
  (define result-ch     (make-channel))
  (define busy-sema     (make-semaphore 1))
  (define input         #f)
  (define output        #f)
  (define error-output  #f)
  (define limits        (sandbox-eval-limits))
  (define eval-handler  (car (sandbox-eval-handlers))) ; 1st handler on startup
  (define user-thread   #t) ; set later to the thread
  (define user-done-evt #t) ; set in the same place
  (define terminated?   #f) ; set to an exception value when the sandbox dies
  (define breaks-originally-enabled? (break-enabled))
  (define submod-names (sandbox-run-submodules))
  (define (limit-thunk thunk)
    (define sec (and limits (car limits)))
    (define mb  (and limits (cadr limits)))
    (let* ([thunk (if (or sec mb)
                    (lambda () (call-with-limits sec mb thunk))
                    thunk)]
           [thunk (if eval-handler (lambda () (eval-handler thunk)) thunk)])
      thunk))
  (define (terminated! reason)
    (unless terminated?
      (set! terminated?
            (make-terminated
             (cond
               ;; #f is used as an indication of an internal error, when we
               ;; don't know why the sandbox is killed
               [(not reason) "internal error: no termination reason"]
               ;; explicit reason given
               [(not (eq? reason #t)) reason]
               ;; reason = #t => guess the reason
               [(not (custodian-box-value memory-cust-box)) 'out-of-memory]
               [(not (custodian-box-value user-cust-box)) 'custodian-shutdown]
               [(thread-dead? user-thread) 'thread-killed]
               [else "internal error: cannot guess termination reason"])))))
  (define (user-kill)
    (when user-thread
      (define t user-thread)
      (set! user-thread #f)
      (terminated! #f)
      (custodian-shutdown-all user-cust)
      (kill-thread t)) ; just in case
    (void))
  (define (terminate+kill! reason raise?)
    (terminated! reason)
    (user-kill)
    (when raise? (raise terminated?)))
  (define (user-break)
    (when user-thread (break-thread user-thread)))
  (define (user-process sync/yield)
    (define break-paramz (current-break-parameterization))
    (parameterize-break
     #f ;; disable breaks during administrative work
     (with-handlers ([void (lambda (exn) (channel-put result-ch exn))])
       (call-with-break-parameterization
        break-paramz
        (lambda ()
          ;; enable breaks, maybe
          (when breaks-originally-enabled? (break-enabled #t))
          ;; first set up the environment
          (init-hook)
          ((sandbox-init-hook))
          ;; now read and evaluate the input program (in the user context)
          (evaluate-program
           (let-values ([(prog src) (program-maker)])
             (when coverage? (set! default-coverage-source-filter src))
             prog)
           limit-thunk
           submod-names
           (and coverage? (lambda (es+get) (set! uncovered es+get)))
           allow-syntactic-requires)))
       (channel-put result-ch 'ok))
     (set! eval-handler (cadr (sandbox-eval-handlers))) ; interactions handler
     ;; finally wait for interaction expressions
     (define n 0)
     (let loop ()
       (define expr (sync/yield input-ch))
       (when (eof-object? expr)
         (terminated! 'eof) (channel-put result-ch expr) (user-kill))
       (with-handlers ([void (lambda (exn)
                               (if propagate-exceptions?
                                   (channel-put result-ch (cons 'exn exn))
                                   (begin
                                     (call-with-continuation-prompt
                                      (lambda ()
                                        (raise exn)))
                                     (channel-put result-ch (cons 'vals (list (void)))))))])
         (define run
           (if (evaluator-message? expr)
             (case (evaluator-message-msg expr)
               [(thunk) (limit-thunk (car (evaluator-message-args expr)))]
               [(thunk*) (car (evaluator-message-args expr))]
               [else (error 'sandbox "internal error (bad message)")])
             (limit-thunk
              (lambda ()
                (set! n (add1 n))
                (define exprs
                  (let-values ([(code _)
                                (input->code (list expr) 'eval n #f)])
                    code))
                (eval* (map (lambda (expr) (cons '#%top-interaction expr))
                            exprs))))))
         (channel-put result-ch
                      (cons 'vals
                            (call-with-break-parameterization
                             break-paramz
                             (lambda () (call-with-values run list))))))
       (loop))))
  (define (get-user-result)
    (if (and (sandbox-propagate-breaks)
             ;; The following test is weird. We reliably catch breaks if breaks
             ;; are enabled, except that a break just before or after isn't
             ;; reliably propagated. A `get-result/enable-breaks' function
             ;; would make more sense.
             (break-enabled))
        ;; The following loop ensures that breaks are disabled while trying
        ;; to handle a break, which ensures that we don't fail to
        ;; propagate a break.
        (parameterize-break
         #f
         (let loop ()
           (with-handlers* ([exn:break? (lambda (e) (user-break) (loop))])
             (sync/enable-break user-done-evt result-ch))))
        ;; The simple case doesn't have to deal with breaks:
        (sync user-done-evt result-ch)))
  (define (user-eval expr)
    ;; the thread will usually be running, but it might be killed outside of
    ;; the sandboxed environment, for example, if you do something like
    ;; (kill-thread (ev '(current-thread))) when there are no per-expression
    ;; limits (since then you get a different thread, which is already dead).
    (when (and user-thread (thread-dead? user-thread))
      (terminate+kill! #t #t))
    (cond [terminated? => raise]
          [(not user-thread)
           (error 'sandbox "internal error (user-thread is #f)")]
          ;; use a semaphore to know when we're currently in an evaluation, to
          ;; prevent the evaluator from calling itself (it will deadlock, and
          ;; there is no simple way to avoid it -- will require making a stream
          ;; of inputs sent to the user context, queueing them as they come in,
          ;; and for each one register a channel for a reply -- and this will
          ;; consume resources outside the user context)
          [(not (sync/timeout 0 busy-sema))
           (error 'evaluator "nested evaluator call with: ~e" expr)]
          [else (channel-put input-ch expr)
                (define r (get-user-result))
                (semaphore-post busy-sema)
                (cond [(eof-object? r) (terminate+kill! #t #t)]
                      [(eq? (car r) 'exn) (raise (cdr r))]
                      [else (apply values (cdr r))])]))
  (define (get-uncovered [prog? #t] [src default-coverage-source-filter])
    (unless uncovered
      (error 'get-uncovered-expressions "no coverage information"))
    (define uncovered-exprs (if prog? (car uncovered) ((cadr uncovered))))
    (if src
      ;; when given a list of syntaxes, the src is actually a function that
      ;; checks the input source value (which does a union of the sources)
      (filter (if (procedure? src)
                (lambda (x) (src (syntax-source x)))
                (lambda (x) (equal? src (syntax-source x))))
              uncovered-exprs)
      uncovered-exprs))
  (define (output-getter p)
    (if (procedure? p) (user-eval (make-evaluator-message 'thunk (list p))) p))
  (define (input-putter [arg input])
    (cond [(not input)
           (error 'put-input "evaluator input is not 'pipe")]
          [(or (string? arg) (bytes? arg))
           (display arg input) (flush-output input)]
          [(eof-object? arg) (close-output-port input)]
          [else (error 'put-input "bad argument: ~e" arg)]))
  (define (evaluator expr)
    (if (evaluator-message? expr)
      (let ([msg (evaluator-message-msg expr)])
        (case msg
          [(alive?)  (and user-thread (not (thread-dead? user-thread)))]
          [(kill)    (terminate+kill! 'evaluator-killed #f)]
          [(break)   (user-break)]
          [(user-cust) user-cust]
          [(limits)  (set! limits (evaluator-message-args expr))]
          [(handler) (set! eval-handler (car (evaluator-message-args expr)))]
          [(input)   (apply input-putter (evaluator-message-args expr))]
          [(output)  (output-getter output)]
          [(error-output) (output-getter error-output)]
          [(uncovered) (apply get-uncovered (evaluator-message-args expr))]
          [(thunk thunk*) (user-eval expr)]
          [else (error 'evaluator "internal error, bad message: ~e" msg)]))
      (user-eval expr)))
  (define (make-output what out set-out!)
    (cond [(not out) (open-output-nowhere)]
          [(and (procedure? out) (procedure-arity-includes? out 0)) (out)]
          [(output-port? out) out]
          [(eq? out 'pipe) (let-values ([(i o) (make-pipe)]) (set-out! i) o)]
          [(memq out '(bytes string))
           (define bytes? (eq? out 'bytes))
           ;; create the port under the user's custodian
           (define outp
             (parameterize ([current-custodian user-cust])
               (call-in-nested-thread
                ;; this doesn't really matter: they're the same anyway
                (if bytes? open-output-bytes open-output-string))))
           (set-out! (lambda ()
                       ;; this will run in the user context
                       (define buf (get-output-bytes outp #t))
                       (if bytes? buf (bytes->string/utf-8 buf #\?))))
           outp]
          [else (error who "bad sandox-~a spec: ~e" what out)]))
  ;; Call path functions to make sure the underying path computations
  ;; have been forced, so that the sandbox filesystem guards will not
  ;; be relevant:
  (find-config-dir)
  (find-collects-dir)
  (get-lib-search-dirs)
  ;; set global memory limit
  (when (and memory-accounting? (sandbox-memory-limit))
    (custodian-limit-memory
     memory-cust
     (inexact->exact (round (* (sandbox-memory-limit) 1024 1024)))
     memory-cust))
  (define saw-accesses (make-hash))
  (parameterize* ; the order in these matters
   (;; create a sandbox context first
    [sandbox-gui-available (and (sandbox-gui-available)
                                (gui-available?))]
    [current-custodian user-cust]
    [current-thread-group (make-thread-group)]
    ;; paths
    [current-environment-variables ((sandbox-make-environment-variables))]
    [current-library-collection-paths
     (filter directory-exists?
             (append (sandbox-override-collection-paths)
                     (current-library-collection-paths)))]
    [sandbox-path-permissions
     `(,@(add-compiled-file-roots
          (map (lambda (p) `(read-bytecode ,p))
               (apply
                append
                (for/list ([l (current-library-collection-links)])
                  (cond
                    [(not l)
                     (current-library-collection-paths)]
                    [(hash? l)
                     (hash-values l)]
                    [else
                     (if (file-exists? l)
                         (call-and-accumulate-captured-filesystem-accesses
                          saw-accesses
                          (lambda ()
                            (append
                             (links #:root? #t #:file l)
                             (map cdr (links #:file l #:with-path? #t)))))
                         null)])))))
       ,@(for/list ([l (current-library-collection-links)]
                    #:when (path? l))
           `(read ,l))
       ,@(for/list ([(k v) (in-hash saw-accesses)])
           `(,v ,k))
       ,@(let ([pkg-dirs (append (get-pkgs-search-dirs)
                                 (list (find-user-pkgs-dir)))])
           (append (for/list ([l (in-list pkg-dirs)])
                     `(exists ,l))
                   (for*/list ([l (in-list pkg-dirs)]
                               [f (in-list (list "pkgs.rktd" (make-lock-file-name "pkgs.rktd")))])
                     `(read ,(build-path l f)))))
       ,@(add-compiled-file-roots
          (list `(read-bytecode ,(PLANET-BASE-DIR))))
       (exists ,(find-system-path 'addon-dir))
       ,@(for/list ([dir (get-lib-search-dirs)])
           `(read ,dir))
       ,@(let ([d (find-config-dir)])
           (if d
               `((read ,(build-path d "config.rktd")))
               null))
       ,@(compute-permissions allow-for-require allow-for-load)
       ,@(sandbox-path-permissions))]
    ;; restrict the sandbox context from this point
    [current-security-guard
     (let ([g (sandbox-security-guard)]) (if (security-guard? g) g (g)))]
    [current-logger ((sandbox-make-logger))]
    [current-plumber
     (let ([maker (sandbox-make-plumber)])
       (if (eq? maker 'propagate)
           ;; Create a new plumber, but cause flushes to the original
           ;; plumber schedule a flush in the sandbox:
           (let ([p (make-plumber)])
             (define fh (plumber-add-flush! (current-plumber)
                                            (lambda (fh)
                                              (unless (or terminated?
                                                          ;; The evaluator thread may have terminated
                                                          ;; asynchronously, such as through an enclosing
                                                          ;; custodian's shutdown
                                                          (and user-thread
                                                               (thread-dead? user-thread)))
                                                (call-in-sandbox-context
                                                 evaluator
                                                 (lambda ()
                                                   (plumber-flush-all p)))))
                                            ;; weak:
                                            #t))
             ;; Retain flush propagation as long as the new plumber is
             ;; reachable:
             (plumber-add-flush! p (lambda (_) fh))
             p)
           (maker)))]
    [current-inspector ((sandbox-make-inspector))]
    [current-code-inspector ((sandbox-make-code-inspector))]
    ;; The code inspector serves two purposes -- making sure that only trusted
    ;; byte-code is loaded, and avoiding using protected module bindings, like
    ;; the foreign library's `unsafe!'.  We control the first through the path
    ;; permissions -- using the 'read-bytecode permissionn level, so this
    ;; handler just checks for that permission then goes on to load the file
    ;; using the original inspector.
    [current-load/use-compiled
     (let ([handler (current-load/use-compiled)])
       (lambda (path modname)
         (if (check-sandbox-path-permissions
              (parameterize ([current-security-guard orig-security-guard])
                (simplify-path* path))
              'read-bytecode)
           (parameterize ([current-code-inspector orig-code-inspector])
             (handler path modname))
           ;; otherwise, just let the old handler throw a proper error
           (handler path modname))))]
    ;; prevent a potential value here from messing up creating the sandboxed
    ;; module
    [current-module-declare-name #f]
    ;; set up the IO context
    [current-input-port
     (let ([inp (sandbox-input)])
       (cond [(not inp) null-input]
             [(input->port inp) => values]
             [(and (procedure? inp) (procedure-arity-includes? inp 0)) (inp)]
             [(eq? 'pipe inp)
              (let-values ([(i o) (make-pipe)]) (set! input o) i)]
             [else (error who "bad sandbox-input: ~e" inp)]))]
    [current-output-port (make-output 'output (sandbox-output)
                                      (lambda (o) (set! output o)))]
    [current-error-port (make-output 'error-output (sandbox-error-output)
                                     (lambda (o) (set! error-output o)))]
    ;; no exiting
    [exit-handler
     (let ([h (sandbox-exit-handler)])
       (if (eq? h default-sandbox-exit-handler)
           (let ([p (current-plumber)])
             (lambda _
               (plumber-flush-all p)
               (terminate+kill! 'exited #f)))
           h))]
    ;; general info
    [current-command-line-arguments '#()]
    ;; Finally, create the namespace in the restricted environment (in
    ;; particular, it must be created under the new code inspector)
    [current-namespace (make-evaluation-namespace)])
   (define current-eventspace (mz/mr (make-parameter #f) current-eventspace))
   (parameterize*
    ;; Note the above definition of `current-eventspace': in Racket, it
    ;; is an unused parameter.  Also note that creating an eventspace
    ;; starts a thread that will eventually run the callback code (which
    ;; evaluates the program in `run-in-bg') -- so this parameterization
    ;; must be nested in the above (which is what paramaterize* does), or
    ;; it will not use the new namespace.
    ([current-eventspace (parameterize-break #f ((mz/mr void make-eventspace)))])
    (define run-in-bg (mz/mr thread queue-callback))
    (define bg-run->thread (if (sandbox-gui-available)
                               (lambda (ignored)
                                 ((mz/mr void eventspace-handler-thread) (current-eventspace)))
                                values))
    (define sync/yield (if (sandbox-gui-yield?) (mz/mr sync yield) sync))
    (define t (bg-run->thread (run-in-bg (lambda () (user-process sync/yield)))))
    (set! user-done-evt (handle-evt t (lambda (_) (terminate+kill! #t #t))))
    (set! user-thread t)))
  (define r (get-user-result))
  (if (eq? r 'ok)
    ;; initial program executed ok, so return an evaluator
    evaluator
    ;; program didn't execute
    (raise r)))

(define (check-and-combine-allows who allow allow-for-require allow-for-load)
  (define (check-arg-list arg what ok?)
    (unless (and (list? arg) (andmap ok? arg))
      (error who "bad ~a: ~e" what arg)))
  (check-arg-list allow "allows"
                  (lambda (x) (or (path? x) (module-path? x) (path-string? x))))
  (check-arg-list allow-for-require "allow-for-requires"
                  (lambda (x) (or (path? x) (module-path? x))))
  (check-arg-list allow-for-load "allow-for-loads" path-string?)
  ;; This split of `allow' is ugly but backward-compatible:
  (define-values (more-allow-for-load more-allow-for-require)
    (partition (lambda (p) (or (path? p) 
                               ;; strings that can be treated as paths:
                               (not (module-path? p)))) 
               allow))
  (values (append allow-for-require
                  more-allow-for-require)
          (append allow-for-load
                  more-allow-for-load)))

(define (make-evaluator lang
                        #:requires [requires null] 
                        #:allow-read [allow null]
                        #:allow-for-require [allow-for-require null]
                        #:allow-for-load [allow-for-load null]
                        #:allow-syntactic-requires [allow-syntactic-requires #f]
                        . input-program)
  ;; `input-program' is either a single argument specifying a file/string, or
  ;;  multiple arguments for a sequence of expressions
  (define all-requires
    (extract-required (or (decode-language lang) lang) 
                      requires))
  (unless (and (list? requires) 
               (andmap (lambda (x) (or (path-string? x) 
                                       (module-path? x)
                                       (and (list? x)
                                            (pair? x)
                                            (eq? (car x) 'for-syntax)
                                            (andmap module-path? (cdr x)))))
                       requires))
    (error 'make-evaluator "bad requires: ~e" requires))
  (define-values (all-for-require all-for-load)
    (check-and-combine-allows 'make-evaluator allow allow-for-require allow-for-load))
  (define (normalize-require-for-syntax r)
    (if (or (path? r) (and (string? r) 
                           (not (module-path? r))))
        `(file ,(path->string (simplify-path* r)))
        r))
  (define (normalize-require-for-allow r)
    (cond
     [(and (string? r) (not (module-path? r))) (list (string->path r))]
     [(and (pair? r) (eq? (car r) 'for-syntax))
      (cdr r)]
     [else (list r)]))
  (make-evaluator* 'make-evaluator
                   (init-hook-for-language lang)
                   (append (apply append
                                  (map normalize-require-for-allow all-requires))
                           all-for-require)
                   (append (if (and (= 1 (length input-program))
                                    (path? (car input-program)))
                               (list (car input-program))
                               '())
                           all-for-load)
                   allow-syntactic-requires
                   (lambda () (build-program lang 
                                             (map normalize-require-for-syntax requires)
                                             input-program))))

(define (make-module-evaluator input-program 
                               #:allow-read [allow null] 
                               #:allow-for-require [allow-for-require null]
                               #:allow-for-load [allow-for-load null]
                               #:allow-syntactic-requires [allow-syntactic-requires #f]
                               #:language [reqlang #f]
                               #:readers [reqreaders (and reqlang
                                                          (module-path? reqlang)
                                                          (default-language-readers reqlang))])
  ;; this is for a complete module input program
  (define (make-program)
    (define-values [prog source]
      (input->code (list input-program) 'program #f #t #:readers reqreaders))
    (unless (= 1 (length prog))
      (error 'make-module-evaluator "expecting a single `module' program; ~a"
             (if (zero? (length prog))
               "no program expressions given"
               "got more than a single expression")))
    (syntax-case* (car prog) (module) literal-identifier=?
      [(module modname lang body ...)
       (if (or (not reqlang) (equal? reqlang (syntax->datum #'lang)))
         (values (car prog) source)
         (error 'make-module-evaluator
                "module code used `~.s' for a language, expecting `~.s'"
                (syntax->datum #'lang) reqlang))]
      [_else (error 'make-module-evaluator
                    "expecting a `module' program; got ~.s"
                    (syntax->datum (car prog)))]))
  (define-values (all-for-require all-for-load)
    (check-and-combine-allows 'make-module-evaluator allow allow-for-require allow-for-load))
  (make-evaluator* 'make-module-evaluator
                   void
                   all-for-require
                   (if (path? input-program) (cons input-program all-for-load) all-for-load)
                   allow-syntactic-requires
                   make-program))

(define (default-language-readers reqlang)
  (unless (module-path? reqlang)
    (raise-argument-error 'default-language-readers "module-path?" reqlang))
  (list
   `(submod ,reqlang reader)
   (cond
     [(symbol? reqlang)
      (string->symbol (format "~a/lang/reader" reqlang))]
     [else
      (collapse-module-path "lang/reader.rkt" reqlang)])
   '(submod at-exp reader)
   'at-exp/lang/reader))
