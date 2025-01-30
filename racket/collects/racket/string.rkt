#lang racket/base

(provide string-append*
         string-join
         string-trim
         string-normalize-spaces
         string-split
         string-replace
         non-empty-string?
         string-prefix?
         string-suffix?
         string-contains?
         string-find)

(module+ private
  (provide build-kmp-table))


;; TODO: What are the semantics if the strings themselves are changed during the execution?
(define (string-append*-one-arg strs)
  ;; TODO How to format error message? Do we need to do it up a level when we have more info?
  (unless (and (list? strs) (andmap string? strs))
    (raise-argument-error 'string-append* "(listof string?)" strs))

  (define len (for/sum ([str (in-list strs)]) (string-length str)))
  (define acc (make-string len))
  (for/fold ([offset 0]) ([str (in-list strs)])
    (string-copy! acc offset str)
    (+ offset (string-length str)))
  acc)

(define string-append*
  (case-lambda 
    [(strs) (string-append*-one-arg strs)] ; optimize common cases
    [(s1 strs) (string-append*-one-arg (list* s1 strs))]
    [(s1 s2 strs) (string-append*-one-arg (list* s1 s2 strs))]
    [(s1 s2 s3 strs) (string-append*-one-arg (list* s1 s2 s3 strs))]
    [(s1 s2 s3 s4 strs) (string-append*-one-arg (list* s1 s2 s3 s4 strs))]
    [(str . strss) (string-append*-one-arg (apply list* str strss))]))

(require (only-in racket/list add-between)
         (only-in racket/unsafe/undefined [unsafe-undefined none]))

(define (string-join strs [sep " "]
                     #:before-first [before-first none]
                     #:before-last  [before-last sep]
                     #:after-last   [after-last none])
  (unless (and (list? strs) (andmap string? strs))
    (raise-argument-error 'string-join "(listof string?)" strs))
  (unless (or (string? before-first) (eq? before-first none))
    (raise-argument-error 'string-join "string?" before-first))
  (unless (string? sep)
    (raise-argument-error 'string-join "string?" sep))
  (unless (or (string? after-last) (eq? after-last none))
    (raise-argument-error 'string-join "string?" after-last))

  (let* ([r (cond
              [(or (null? strs) (null? (cdr strs))) strs]
              ;; below here, strs definitely has at least two elements
              [(equal? sep "")
               (cond
                 [(equal? before-last "") strs]
                 [else
                  (define rev-strs (reverse strs))
                  (define rev-assembled
                    (cons (car rev-strs)
                          (cons before-last
                                (cdr rev-strs))))
                  (reverse rev-assembled)])]
              [else (add-between strs sep #:before-last before-last)])]
         [r (if (eq? after-last   none) r (append r (list after-last)))]
         [r (if (eq? before-first none) r (cons before-first r))])
    (apply string-append r)))

;; Cache for string-replace and string-split and similar functions:
;; A mutable string weakly holds a immutable copy until it is collected
;; or modified (and used as a argument of string-replace, string-split, ...).
;; The immutable copy weakly holds the regexp that is used in string-replace.
;; Using string->immutable-string directly in string-replace is not a useful
;; because the immutable copy could be immediately collected.
 
(define immutable-cache (make-weak-hasheq))
(define (string->immutable-string/cache str)
  (if (immutable? str)
    str
    (let ([old (hash-ref immutable-cache str #f)])
      (if (and old (string=? str old))
        old
        (let ([new (string->immutable-string str)])
          (hash-set! immutable-cache str new)
          new)))))    

;; Utility for the functions below: get a string or a regexp and return a list
;; of the regexp (strings are converted using `regexp-quote'), and versions
;; that match at the beginning/end.
(define get-rxs
  (let ([t (make-weak-hasheq)] [t+ (make-weak-hasheq)])
    (let ([spaces '(#px"\\s+" #px"^\\s+" #px"\\s+$")])
      (hash-set! t none spaces)
      (hash-set! t+ none spaces))
    (λ (who rx +?)
      (define rx* (if (string? rx)
                     (string->immutable-string/cache rx)
                     rx))
      (hash-ref! (if +? t+ t) rx*
        (λ () (let* ([s (cond [(string? rx) (regexp-quote rx*)]
                              [(regexp? rx) (string-append
                                             "(?:" (object-name rx) ")")]
                              [else (raise-argument-error
                                     who "(or/c string? regexp?)" rx)])]
                     [s (if +? (string-append "(?:" s ")+") s)]
                     [^s (string-append "^" s)]
                     [s$ (string-append s "$")])
                (if (pregexp? rx)
                  (list (pregexp s) (pregexp ^s) (pregexp s$))
                  (list (regexp  s) (regexp  ^s) (regexp  s$)))))))))

;; returns start+end positions, #f when no trimming should happen
(define (internal-trim who str sep l? r? rxs)
  (unless (string? str) (raise-argument-error who "string?" str))
  (define l
    (and l? (let ([p (regexp-match-positions (car rxs) str)])
              (and p (let ([p (cdar p)]) (and (> p 0) p))))))
  (define r
    (and r? (let ([p (regexp-match-positions (cadr rxs) str)])
              (and p (let ([p (caar p)])
                       (and (< p (string-length str))
                            (if (and l (> l p)) l p)))))))
  (values l r))

;; See http://en.wikipedia.org/wiki/Trimming_(computer_programming) for a nice
;; overview of popular names etc for these functions;
;; http://blog.stevenlevithan.com/archives/faster-trim-javascript for some ways
;; to implement trimming.
(define (string-trim str [sep none]
                     #:left? [l? #t] #:right? [r? #t] #:repeat? [+? #f])
  (define rxs (get-rxs 'string-trim sep +?))
  (define-values [l r] (internal-trim 'string-trim str sep l? r? (cdr rxs)))
  (cond [(and l r) (substring str l r)]
        [l         (substring str l)]
        [r         (substring str 0 r)]
        [else      str]))

(define (internal-split who str sep trim? +?)
  (define rxs (get-rxs who sep +?))
  (define-values [l r]
    (if trim? (internal-trim who str sep #t #t (cdr rxs)) (values #f #f)))
  (define strs (regexp-split (car rxs) str (or l 0) r))
  ;; Seems to make more sense for these functions (eg, this corresponds to
  ;; simple uses where `string-split' in Emacs uses t for `omit-nulls' (but we
  ;; don't do that for all nulls).)
  (if (equal? strs '("")) '() strs))

;; A faster split implementation when splitting on whitespace. The
;; string will also be trimmed.
(define (internal-split-whitespace str)
  (define (is-whitespace? c)
    (or (eq? c #\space)
        (eq? c #\tab)
        (eq? c #\newline)
        (eq? c #\return)
        (eq? c #\page)))
  (define len (string-length str))
  (let loop ([beg 0] [end 0])
    (cond [(= end len)
           (if (= beg end)
               '()
               (list (substring str beg end)))]
          [(is-whitespace? (string-ref str end))
           (let ([pos (add1 end)])
             (if (= beg end)
                 (loop pos pos)
                 (cons (substring str beg end)
                       (loop pos pos))))]
          [else (loop beg (add1 end))])))

(define (string-split str [sep none] #:trim? [trim? #t] #:repeat? [+? #f])
  (if (and (string? str)
           (or (eq? sep none) (eq? sep #px"\\s+"))
           trim?)
      (internal-split-whitespace str)
      (internal-split 'string-split str sep trim? +?)))

(define (string-normalize-spaces str [sep none] [space " "]
                                 #:trim? [trim? #t] #:repeat? [+? #f])
  (string-join (internal-split 'string-normalize-spaces str sep trim? +?)
               space))

(define replace-cache (make-weak-hasheq))
(define (string-replace str from to #:all? [all? #t])
  (unless (string? str) (raise-argument-error 'string-replace "string?" str))
  (unless (string? to)  (raise-argument-error 'string-replace "string?" to))
  (unless (or (string? from) (regexp? from))
    (raise-argument-error 'string-replace "(or/c string? regexp?)" from))
  (define from*
    (if (regexp? from)
      from
      (hash-ref! replace-cache (string->immutable-string/cache from)
        (λ() (regexp (regexp-quote from))))))
  (define to* (regexp-replace-quote to))
  (if all?
    (regexp-replace* from* str to*)
    (regexp-replace  from* str to*)))

(define (non-empty-string? x)
  (and (string? x) (not (zero? (string-length x)))))

(define (string-prefix? str prefix)
  (unless (string? str)
    (raise-argument-error 'string-prefix? "string?" str))
  (unless (string? prefix)
    (raise-argument-error 'string-prefix? "string?" prefix))
  (define l1 (string-length str))
  (define l2 (string-length prefix))
  (let loop ([i 0])
    (cond
     [(= l2 i)  #t] ;; Finished reading all chars in prefix
     [(= l1 i)  #f] ;; Prefix is longer than string
     [else      (and (char=? (string-ref str i) (string-ref prefix i))
                     (loop (add1 i)))])))

(define (string-suffix? str suffix)
  (unless (string? str)
    (raise-argument-error 'string-suffix? "string?" str))
  (unless (string? suffix)
    (raise-argument-error 'string-suffix? "string?" suffix))
  (define l2 (string-length suffix))
  (define offset (- (string-length str) l2))
  (and (not (negative? offset)) ;; Suffix isn't longer than string
       (let loop ([i+o offset] [i 0])
         (or (= i l2)
             (and (char=? (string-ref str i+o) (string-ref suffix i))
                  (loop (add1 i+o) (add1 i)))))))

;; string-contains? uses a variant of the Knuth-Morris-Pratt string search
;; algorithm. It start with a direct search without the KMP table, until
;; it finds a partial match that long enough (currently 4 characters).
;; The table is also skipped when there are only a few characters left
;; to test (currently 4 characters).
;; The first time a partial match is found, it buils a small partial table
;; and if it is necesay it builds the complete table.
;; The KMP table has one more element as usual, that is unused for now.
;; The last coefficient can be used to continue the search in case a 
;; match is found and we want to get all the matches or count them. 
(define (build-kmp-table sub)
  (define L (string-length sub))
  (if (> L 0)
     (build-kmp-table/partial sub L #f)
     (make-vector 1 #f)))

(define (build-kmp-table/partial/first sub pos)
  (define L (string-length sub))
  (if (> L 0)
     (build-kmp-table/partial sub (min L (* 2 pos)) #f)
     (make-vector 1 #f)))

(define (build-kmp-table/partial/next sub pos prev)
  (define L (string-length sub))
  (if (> L 0)
    (build-kmp-table/partial sub L prev)
    (make-vector 1 #f)))

(define (build-kmp-table/partial sub vL prev)
  (define L (string-length sub))
  (define pos (if prev
                 (sub1 (vector-length prev))
                 1))
  (define cnd (if prev
                 (unbox (vector-ref prev (sub1 (vector-length prev))))
                 0))
  (define t (make-vector (add1 vL) #f))
  (when prev
    (vector-copy! t 0 prev))
  
  (let loop ([pos pos] [cnd cnd])
    (cond
      [(= pos L)
       (vector-set! t pos cnd)
       t]
      [(= pos vL)
       (vector-set! t pos (box cnd))
       t]
      [(char=? (string-ref sub pos)
               (string-ref sub cnd))
       (vector-set! t pos (vector-ref t cnd))
       (loop (add1 pos) (add1 cnd))]
      [else
       (vector-set! t pos cnd)
       (let loop2 ([pos pos]
                   [cnd (vector-ref t cnd)])
         (cond
           [(not cnd)
            (loop (add1 pos) 0)]
           [(char=? (string-ref sub pos)
                    (string-ref sub cnd))
            (loop (add1 pos) (add1 cnd))]
           [else
            (loop2 pos (vector-ref t cnd))]))])))

(define (string-find str sub)
  (do-string-find 'string-find str sub))

(define (string-contains? str sub)
  (and (do-string-find 'string-contains? str sub) #t))

(define (do-string-find who str sub)
  (unless (string? str)
    (raise-argument-error who "string?" str))
  (unless (string? sub)
    (raise-argument-error who "string?" sub))
  (define L1 (string-length str))
  (define L2 (string-length sub))
  (define d (- L1 L2))
  (define d-4 (- d 4))

  (cond
    [(= L2 0) 0]
    [else
     (let loop ([start 0]
                [offset 0])
       (define start+offset (+ start offset))
       (and (<= start d)
            (cond
              [(= offset L2)
               start]
              [else
               (cond
                 [(char=? (string-ref sub offset)
                          (string-ref str start+offset))
                  (loop start (add1 offset))]
                 [(or (<= offset 4) (>= start d-4))
                  (loop (add1 start) 0)]
                 [else
                  (define t (build-kmp-table/partial/first sub offset))
                  (define skip (vector-ref t offset))
                  (cond
                    [skip
                     (string-find/table str sub (- start+offset skip) skip t)]
                    [else
                     (string-find/table str sub (add1 start+offset) 0 t)])])])))]))

(define (string-find/table str sub start offset t)
  (define L1 (string-length str))
  (define L2 (string-length sub))
  (define d (- L1 L2))

  (cond
    [(= L2 0)
     start]
    [else
     (let loop ([start start]
                [offset offset]
                [t t]
                [tL (sub1 (vector-length t))])
       (define start+offset (+ start offset))
       (and (<= start d)
            (cond
              [(= offset L2)
               start]
              [else
               (cond
                 [(char=? (string-ref sub offset)
                          (string-ref str start+offset))
                  (loop start (add1 offset) t tL)]
                 [(< offset tL)
                  (define skip (vector-ref t offset))
                  (cond
                    [skip
                     (loop (- start+offset skip) skip t tL)]
                    [else
                     (loop (add1 start+offset) 0 t tL)])]
                 [else
                  (let* ([t (build-kmp-table/partial/next sub offset t)]
                         [tL (sub1 (vector-length t))]
                         [skip (vector-ref t offset)])
                    (cond
                      [skip
                       (loop (- start+offset skip) skip t tL)]
                      [else
                       (loop (add1 start+offset) 0 t tL)]))])])))]))
