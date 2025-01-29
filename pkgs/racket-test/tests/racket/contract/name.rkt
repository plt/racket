#lang racket/base
(require "test-util.rkt"
         (for-syntax racket/base))

(define-syntax (test-name stx)
  (syntax-case stx ()
    [(_ name contract)
     (with-syntax ([line (syntax-line stx)])
       #'(do-name-test line 'name 'contract))]))

(define (do-name-test line name contract-exp)
  (contract-eval #:test-case-name (format "name test on line ~a" line)
                 `(,test ,name contract-name ,contract-exp))
  #;(contract-eval #:test-case-name (format "opt/c name test on line ~a" line)
                   `(,test ,name contract-name (opt/c ,contract-exp))))

(parameterize ([current-contract-namespace (make-basic-contract-namespace
                                            'racket/math
                                            'racket/contract
                                            'racket/set
                                            'racket/class)])
  (test-name 'integer? (flat-contract integer?))
  (test-name 'boolean? (flat-contract boolean?))
  (test-name 'char? (flat-contract char?))
  (test-name 'any/c any/c)

  (test-name '(or/c) (or/c))
  (test-name '(or/c) (or/c none/c))
  (test-name '(or/c) (or/c (or/c)))
  (test-name '(or/c) (or/c (first-or/c)))
  (test-name '(or/c integer? gt0?) (or/c integer? (let ([gt0? (lambda (x) (> x 0))]) gt0?)))
  (test-name '(or/c integer? boolean?)
             (or/c (flat-contract integer?)
                   (flat-contract boolean?)))
  (test-name '(or/c (-> (>=/c 5) (>=/c 5)) boolean?)
             (or/c (-> (>=/c 5) (>=/c 5)) boolean?))
  (test-name '(or/c boolean? (-> (>=/c 5) (>=/c 5)))
             (or/c boolean? (-> (>=/c 5) (>=/c 5))))
  (test-name 'boolean? (or/c #f #t))
  (test-name 'boolean? (or/c #t #f))
  #;(test-name 'boolean? (or/c (make-none/c 'none) #t #f)) ; FIXME
  (test-name 'boolean? (or/c (or/c) #t #f))
  (test-name 'boolean? (or/c #t (or/c) #f))
  (test-name 'boolean? (or/c #t #f (or/c)))
  (test-name '(or/c #t #f 'x) (or/c #t #f 'x))
  (test-name '(or/c #t #f 'x) (or/c #t #f (or/c) 'x))
  (test-name '(or/c any/c #f) (or/c any/c #f))
  (test-name '(or/c #f any/c) (or/c #f any/c))

  (test-name '(if/c integer? odd? (-> integer? integer?))
             (if/c integer? odd? (-> integer? integer?)))
  (test-name '(if/c integer? odd? boolean?)
             (if/c integer? odd? boolean?))
  
  (test-name '(first-or/c) (first-or/c))
  (test-name '(first-or/c) (first-or/c none/c))
  (test-name '(first-or/c) (first-or/c (first-or/c)))
  (test-name '(first-or/c) (first-or/c (or/c)))
  (test-name 'pair? (first-or/c pair? pair?))
  (test-name '(first-or/c pair? number?) (first-or/c pair? number? pair?))
  (test-name '(first-or/c integer? gt0?) (first-or/c integer? (let ([gt0? (lambda (x) (> x 0))]) gt0?)))
  (test-name '(first-or/c integer? boolean?)
             (first-or/c (flat-contract integer?)
                    (flat-contract boolean?)))
  (test-name '(first-or/c (-> (>=/c 5) (>=/c 5)) boolean?)
             (first-or/c (-> (>=/c 5) (>=/c 5)) boolean?))
  (test-name '(first-or/c boolean? (-> (>=/c 5) (>=/c 5)))
             (first-or/c boolean? (-> (>=/c 5) (>=/c 5))))
  (test-name '(first-or/c #t #f 'x) (first-or/c #t #f 'x))
  (test-name '(first-or/c #t #f 'x) (first-or/c #t #f (first-or/c) 'x))
  (test-name '(first-or/c any/c #f) (first-or/c any/c #f))
  (test-name '(first-or/c #f any/c) (first-or/c #f any/c))
  
  (test-name 'mumble (let ([frotz/c integer?]
                           [bazzle/c boolean?])
                       (flat-named-contract 'mumble
                                            (and/c frotz/c
                                                   (not/c bazzle/c)))))
  (test-name 'Real (flat-named-contract 'Real real?))
  (test-name 'Natural (flat-named-contract 'Natural exact-nonnegative-integer?))
  (test-name '_Natural (flat-named-contract '_Natural natural?))
  (test-name 'Integer (flat-named-contract 'Integer exact-integer?))
  (test-name 'kalidoscope (flat-named-contract 'kalidoscope exact-positive-integer?))
  (test-name 'brick (flat-named-contract 'brick (integer-in 11 22)))

  (test-name 'brick (flat-contract-with-explanation (let ([brick (λ (x) #t)]) brick)))
  
  (test-name '(-> integer? integer?) (-> integer? integer?))
  (test-name '(-> integer? any) (-> integer? any))
  (test-name '(-> integer? (values boolean? char?)) (-> integer? (values boolean? char?)))
  (test-name '(-> integer? boolean? (values char? any/c))
             (->* (integer? boolean?) () (values char? any/c)))
  (test-name '(-> integer? boolean? any) (->* (integer? boolean?) () any))
  (test-name '(-> integer? boolean? #:x string? any) (-> integer? #:x string? boolean? any))
  (test-name '(-> any/c boolean?) (-> any/c boolean?))
  (test-name 'predicate/c predicate/c)

  (test-name '(-> integer? any/c ... boolean? any) (-> integer? any/c ... boolean? any))

  (test-name '(-> boolean?) (-> boolean?))
  (test-name '(-> void?) (-> void?))
  
  (test-name '(->* (integer?) (string?) #:rest any/c (values char? any/c))
              (->* (integer?) (string?) #:rest any/c (values char? any/c)))
  (test-name '(->* (integer? char?) (boolean?) any) (->* (integer? char?) (boolean?) any))
  (test-name '(->* (integer? char? #:z string?) (integer?) any) 
             (->* (#:z string? integer? char?) (integer?) any))
  (test-name '(->* (integer? char? #:z string?) (boolean? #:i number?) any)
             (->* (#:z string? integer? char?) (boolean? #:i number?) any))
  (test-name '(->* (integer? char? #:z string?) (boolean? #:i number?) #:rest (listof integer?) any)
              (->* (#:z string? integer? char?) (boolean? #:i number?) #:rest (listof integer?) any))
  (test-name '(->* (integer? char? #:z string?) (boolean? #:i number?) 
                   (values number? boolean? symbol?))
              (->* (#:z string? integer? char?) (boolean? #:i number?) 
                   (values number? boolean? symbol?)))
  (test-name '(->* (integer? char? #:z string?) (boolean? #:i number?) #:rest (listof integer?) 
                   (values number? boolean? symbol?))
              (->* (#:z string? integer? char?) (boolean? #:i number?) #:rest (listof integer?) 
                   (values number? boolean? symbol?)))

  (test-name '(->* (integer?) #:pre ... integer?)
			  (->* (integer?) () #:pre (= 1 2) integer?))
  (test-name '(->* (integer?) integer? #:post ...)
			  (->* (integer?) () integer? #:post #f))
  (test-name '(->* (integer?) #:pre ... integer? #:post ...)
			  (->* (integer?) () #:pre (= 1 2) integer? #:post #f))
  (test-name '(->* (integer?) #:pre/desc ... integer?)
			  (->* (integer?) () #:pre/desc (= 1 2) integer?))
  (test-name '(->* (integer?) integer? #:post/desc ...)
			  (->* (integer?) () integer? #:post/desc #f))
  (test-name '(->* (integer?) #:pre/desc ... integer? #:post/desc ...)
			  (->* (integer?) () #:pre/desc (= 1 2) integer? #:post/desc #f))

  (test-name '(->d () () any) (->d () () any))
  (test-name '(->d ([x ...] #:y [y ...]) ([z ...] #:w [w ...]) any)
             (->d ([x integer?] #:y [y integer?]) ([z integer?] #:w [w integer?]) any))
  (test-name '(->d () () (values [x ...] [y ...])) (->d () () (values [x number?] [y number?])))
  (test-name '(->d () () [x ...]) (->d () () [q number?]))
  (test-name '(->d () () #:pre ... [x ...]) (->d () () #:pre #t [q number?]))
  (test-name '(->d () () #:pre ... [x ...] #:post ...) (->d () () #:pre #t [q number?] #:post #t))
  (test-name '(->d () () [x ...] #:post ...) (->d () () [q number?] #:post #t))

  (test-name '(->i () any) (->i () () any))
  (test-name '(->i () any) (->i () any))
  (test-name '(->i () [x () number?])
              (->i () () [x () number?]))
  (test-name '(->i () [q number?])
              (->i () () [q number?]))
  (test-name '(->i () (values [x number?] [y number?]))
              (->i () (values [x number?] [y number?])))
  (test-name '(->i () (values [x (y) number?] [y number?]))
              (->i () (values [x (y) number?] [y number?])))
  (test-name '(->i ([x integer?] #:y [y integer?]) ([z integer?] #:w [w integer?]) any)
              (->i ([x integer?] #:y [y integer?]) ([z integer?] #:w [w integer?]) any))
  (test-name '(->i () #:pre () #t [q number?])
              (->i () #:pre () #t [q number?]))
  (test-name '(->i () #:pre () #t [q () number?] #:post () #t)
              (->i () #:pre () #t [q () number?] #:post () #t))
  (test-name '(->i () #:pre () #t [q () number?] #:post/desc () #t)
              (->i () #:pre () #t [q () number?] #:post/desc () #t))
  (test-name '(->i ([x integer?]) #:pre (x) #t [q (x) number?] #:post (x) #t)
              (->i ([x integer?]) #:pre (x) #t [q (x) number?] #:post (x) #t))
  (test-name '(->i ([x real?]) [_ (x) (>/c x)])
              (->i ([x real?]) [_ (x) (>/c x)]))
  (test-name '(->i ([x any/c]) #:pre/name (x) "pair" (pair? x) #:pre/name (x) "car" (car x) any)
              (->i ([x any/c]) #:pre/name (x) "pair" (pair? x) #:pre/name (x) "car" (car x) any))
  (test-name '(->i ([x any/c]) [y () any/c] #:post/name (y) "pair" (pair? y)
                   #:post/name (y) "car" (car y))
              (->i ([x any/c]) [y () any/c] #:post/name (y) "pair" (pair? y)
                   #:post/name (y) "car" (car y)))
  (test-name '(->i () #:pre/desc () #t [q number?])
              (->i () #:pre/desc () #t [q number?]))
  (test-name '(->i ([p any/c]
                    [q (p) (if (equal? p 10) 'aha any/c)])
                   #:rest [rest (p) (if (equal? p 11) 'aha any/c)]
                   #:pre (q) (if (equal? q 12) 'aha any/c)
                   [res (p) (if (equal? p 13) 'aha any/c)]
                   #:post (q) (if (equal? q 14) 'aha any/c))
             (->i ([p any/c]
                   [q (p) (if (equal? p 10) 'aha any/c)])
                  #:rest [rest (p) (if (equal? p 11) 'aha any/c)]
                  #:pre (q) (if (equal? q 12) 'aha any/c)
                  [res (p) (if (equal? p 13) 'aha any/c)]
                  #:post (q) (if (equal? q 14) 'aha any/c)))
  (test-name '(->i ((p any/c) (q (p) (void (((((...))))) 2 3 ...))) any)
             (->i ([p any/c]
                   [q (p) (void ((((((1)))))) 2 3 4 5 6 7 8 9 10)])
                  any))
  

  (test-name '(case->) (case->))
  (test-name '(case-> (-> integer? any) (-> boolean? boolean? any) (-> char? char? char? any))
             (case-> (-> integer? any) (-> boolean? boolean? any) (-> char? char? char? any)))
  (test-name '(case-> (-> integer? integer?) (-> integer? integer? integer?))
             (case-> (-> integer? integer?) (-> integer? integer? integer?)))
  (test-name '(case-> (-> integer? #:rest any/c any)) (case-> (-> integer? #:rest any/c any)))
  (test-name '(case-> (-> integer? #:rest any/c (values boolean? char? number?)))
             (case-> (-> integer? #:rest any/c (values boolean? char? number?))))
  (test-name '(case-> (-> integer? (values))) (case-> (-> integer? (values))))

  (test-name '(unconstrained-domain-> number?) (unconstrained-domain-> number?))

  (test-name '(or/c) (or/c))
  (test-name 'integer? (or/c integer?))
  (test-name '(or/c integer? gt0?) (or/c integer? (let ([gt0? (lambda (x) (> x 0))]) gt0?)))
  (test-name '(or/c integer? boolean?)
             (or/c (flat-contract integer?)
                   (flat-contract boolean?)))
  (test-name '(or/c integer? boolean?)
             (or/c integer? boolean?))
  (test-name '(or/c (-> (>=/c 5) (>=/c 5)) boolean?)
             (or/c (-> (>=/c 5) (>=/c 5)) boolean?))
  (test-name '(or/c boolean? (-> (>=/c 5) (>=/c 5)))
             (or/c boolean? (-> (>=/c 5) (>=/c 5))))
  (test-name '(or/c (-> (>=/c 5) (>=/c 5))
                    (-> (<=/c 5) (<=/c 5) (<=/c 5)))
             (or/c (-> (>=/c 5) (>=/c 5))
                   (-> (<=/c 5) (<=/c 5) (<=/c 5))))
  (test-name '(or/c boolean?
                    (-> (>=/c 5) (>=/c 5))
                    (-> (<=/c 5) (<=/c 5) (<=/c 5)))
             (or/c boolean?
                   (-> (>=/c 5) (>=/c 5))
                   (-> (<=/c 5) (<=/c 5) (<=/c 5))))

  (test-name '(first-or/c) (first-or/c))
  (test-name 'integer? (first-or/c integer?))
  (test-name '(first-or/c integer? gt0?) (first-or/c integer? (let ([gt0? (lambda (x) (> x 0))]) gt0?)))
  (test-name '(first-or/c integer? boolean?)
             (first-or/c (flat-contract integer?)
                   (flat-contract boolean?)))
  (test-name '(first-or/c integer? boolean?)
             (first-or/c integer? boolean?))
  (test-name '(first-or/c (-> (>=/c 5) (>=/c 5)) boolean?)
             (first-or/c (-> (>=/c 5) (>=/c 5)) boolean?))
  (test-name '(first-or/c boolean? (-> (>=/c 5) (>=/c 5)))
             (first-or/c boolean? (-> (>=/c 5) (>=/c 5))))
  (test-name '(first-or/c (-> (>=/c 5) (>=/c 5))
                     (-> (<=/c 5) (<=/c 5) (<=/c 5)))
             (first-or/c (-> (>=/c 5) (>=/c 5))
                    (-> (<=/c 5) (<=/c 5) (<=/c 5))))
  (test-name '(first-or/c boolean?
                     (-> (>=/c 5) (>=/c 5))
                     (-> (<=/c 5) (<=/c 5) (<=/c 5)))
             (first-or/c boolean?
                    (-> (>=/c 5) (>=/c 5))
                    (-> (<=/c 5) (<=/c 5) (<=/c 5))))

  (test-name 'any/c (and/c))
  (test-name 'any/c (and/c any/c))
  (test-name 'any/c (and/c any/c any/c))
  (test-name 'any/c (and/c (or/c any/c (and/c))))
  (test-name 'pair? (and/c pair? pair?))
  (test-name 'pair? (and/c pair? (and/c)))
  (test-name 'pair? (and/c pair? (or/c any/c (and/c))))
  (test-name '(and/c pair? number?) (and/c pair? number? pair?))
  (test-name '(and/c number? integer?) (and/c number? (and/c) integer?))
  (test-name '(and/c number? integer?) (and/c number? integer?))
  (test-name '(and/c number? integer?) (and/c (flat-contract number?)
                                              (flat-contract integer?)))
  (test-name '(and/c number? (-> integer? integer?)) (and/c number? (-> integer? integer?)))
  (test-name '(and/c (-> boolean? boolean?) (-> integer? integer?))
              (and/c (-> boolean? boolean?) (-> integer? integer?)))

  (test-name '(and/c real? positive?) (and/c real? positive?))
  (test-name '(and/c real? (not/c positive?)) (and/c real? (not/c positive?)))
  (test-name '(and/c real? negative?) (and/c real? negative?))
  (test-name '(and/c real? (not/c negative?)) (and/c real? (not/c negative?)))
  (test-name 'and/c and/c) ;; technically, this tests the `contract-name` of `and/c`
  (test-name '(>/c 0) (>/c 0))
  (test-name '(<=/c 0) (<=/c 0))
  (test-name '(</c 0) (</c 0))
  (test-name '(>=/c 0) (>=/c 0))
  (test-name '(between/c 0 +inf.0) (between/c 0 +inf.0))
  (test-name '(between/c -inf.0 0) (between/c -inf.0 0))
  (test-name '(between/c 1 1) (between/c 1 1))

  (test-name '(not/c integer?) (not/c integer?))
  (test-name '(=/c 5) (=/c 5))
  (test-name '(>=/c 5) (>=/c 5))
  (test-name '(<=/c 5) (<=/c 5))
  (test-name '(</c 5) (</c 5))
  (test-name '(>/c 5) (>/c 5))
  (test-name '(between/c 5 6) (between/c 5 6))
  (test-name '(between/c -inf.0 +inf.0) (between/c -inf.0 +inf.0))
  (test-name '(between/c 5 5) (between/c 5 5))
  (test-name '(integer-in 0 10) (integer-in 0 10))
  (test-name '(integer-in 10 #f) (integer-in 10 #f))
  (test-name '(integer-in #f 10) (integer-in #f 10))
  (test-name 'exact-integer? (integer-in #f #f))
  (test-name 'natural? (integer-in 0 #f))
  (test-name 'exact-positive-integer? (integer-in 1 #f))
  (test-name '(char-in #\a #\z) (char-in #\a #\z))
  (test-name '(and/c 0 exact?) (integer-in 0 0))
  ;; this next one is convenient, using the and/c name would also be okay
  (test-name '(integer-in 0 9) (and/c (</c 10) exact-integer? (>=/c 0)))
  (test-name '(real-in 1 10) (real-in 1 10))
  (test-name '(between/c 1 10) (between/c 1 10))
  (test-name '(string-len/c 3) (string-len/c 3))
  (test-name 'natural-number/c natural-number/c)
  (test-name '(complex/c even? odd?) (complex/c even? odd?))
  (test-name #f false/c)
  (test-name #t #t)
  (test-name #\a #\a)
  (test-name "x" "x")
  (test-name ''x 'x)
  (test-name #rx"x" #rx"x")
  (test-name #rx#"x" #rx#"x")
  (test-name 'printable/c printable/c)
  (test-name '(or/c 'a 'b 'c) (symbols 'a 'b 'c))
  (test-name '(or/c 1 2 3) (one-of/c 1 2 3))
  (test-name '(or/c '() 'x 1 #f #\a void?)
             (one-of/c '() 'x 1 #f #\a (void)))
  
  (test-name '(or/c #f #t #\a "x") (or/c #f #t #\a "x"))
  (test-name '(or/c #f #t #\a "x" #rx"x" #rx#"x") (or/c #f #t #\a "x" #rx"x" #rx#"x"))

  (test-name '(subclass?/c c%)
             (let ([c% (class object% (super-new))]) (subclass?/c c%)))

  (test-name '(implementation?/c i<%>)
             (let ([i<%> (interface ())])
               (implementation?/c i<%>)))

  (test-name '(is-a?/c i<%>)
             (let ([i<%> (interface ())])
               (is-a?/c i<%>)))
  (test-name '(is-a?/c c%)
             (let ([i<%> (interface ())]
                   [c% (class object% (super-new))])
               (is-a?/c c%)))

  (test-name '(listof boolean?) (listof boolean?))
  (test-name '(listof any/c) (listof any/c))
  (test-name '(listof (-> boolean? boolean?)) (listof (-> boolean? boolean?)))

  (test-name '(non-empty-listof boolean?) (non-empty-listof boolean?))
  (test-name '(non-empty-listof any/c) (non-empty-listof any/c))
  (test-name '(non-empty-listof (-> boolean? boolean?)) (non-empty-listof (-> boolean? boolean?)))
  
  (test-name '(list*of boolean?) (list*of boolean?))
  (test-name '(list*of any/c) (list*of any/c))
  (test-name '(list*of (-> boolean? boolean?)) (list*of (-> boolean? boolean?)))
  (test-name '(list*of boolean? char?) (list*of boolean? char?))
  (test-name '(list*of any/c char?) (list*of any/c char?))
  (test-name '(list*of (-> boolean? boolean?) char?) (list*of (-> boolean? boolean?) char?))

  (test-name '(treelist/c integer?) (treelist/c integer?))
  (test-name '(mutable-treelist/c boolean?) (mutable-treelist/c boolean?))

  (test-name '(vectorof boolean?) (vectorof boolean?))
  (test-name '(vectorof any/c) (vectorof any/c))

  (test-name '(vector/c boolean? integer?) (vector/c boolean? integer?))
  (test-name '(vector/c boolean? integer?) (vector/c boolean? (flat-contract integer?)))

  (test-name '(cons/c boolean? integer?) (cons/c boolean? (flat-contract integer?)))
  (test-name '(cons/c boolean? integer?) (cons/c boolean? (flat-contract integer?)))
  (test-name '(list/c boolean? integer?) (list/c boolean? (flat-contract integer?)))
  (test-name '(list/c boolean? integer?) (list/c boolean? (flat-contract integer?)))

  (test-name '(cons/c boolean? integer?) (cons/c boolean? (flat-contract integer?)))
  (test-name '(cons/c boolean? integer?) (cons/c boolean? (flat-contract integer?)))
  (test-name '(cons/c boolean? integer?) (cons/c boolean? (flat-contract integer?)))
  (test-name '(cons/c (-> boolean? boolean?) integer?) (cons/c (-> boolean? boolean?) integer?))

  (test-name '(list/c boolean? integer?)
             (list/c boolean? (flat-contract integer?)))
  (test-name '(list/c boolean? integer?)
             (list/c boolean? (flat-contract integer?)))
  (test-name '(list/c boolean? integer?)
             (list/c boolean? (flat-contract integer?)))
  (test-name '(list/c (-> boolean? boolean?) integer?)
             (list/c (-> boolean? boolean?) integer?))

  (test-name '(parameter/c integer?) (parameter/c integer?))
  (test-name '(parameter/c integer? string?) (parameter/c integer? string?))

  (test-name '(hash/c symbol? boolean?) (hash/c symbol? boolean?))
  (test-name '(hash/c symbol? boolean? #:immutable #t) (hash/c symbol? boolean? #:immutable #t))
  (test-name '(hash/c symbol? boolean? #:immutable #f) (hash/c symbol? boolean? #:immutable #f))
  (test-name '(hash/c symbol? boolean?) (hash/c symbol? boolean? #:immutable 'dont-care))
  (test-name '(hash/dc [k symbol?] [v (k) boolean?]) 
             (hash/dc [k symbol?] [v (k) boolean?]))
  (test-name '(hash/dc [k symbol?] [v (k) boolean?] #:immutable #t #:kind 'flat) 
             (hash/dc [k symbol?] [v (k) boolean?]  #:immutable #t #:kind 'flat))
  
  (test-name '(box/c boolean?) (box/c boolean?))
  (test-name '(box/c boolean?) (box/c (flat-contract boolean?)))
  (test-name 'the-name (flat-rec-contract the-name))
  (test-name 'the-name (flat-murec-contract ([the-name none/c]) the-name))

  (test-name '(object-contract) (object-contract))
  (test-name '(object-contract (field x integer?)) (object-contract (field x integer?)))
  (test-name '(object-contract (m (-> integer? integer?)))
             (object-contract (m (-> integer? integer?))))
  (test-name '(object-contract (m (-> integer? any)))
             (object-contract (m (-> integer? any))))
  (test-name '(object-contract (m (-> integer? (values integer? integer?))))
             (object-contract (m (-> integer? (values integer? integer?)))))
  (test-name '(object-contract (m (case-> (-> integer? integer? integer?)
                                          (-> integer? (values integer? integer?)))))
             (object-contract (m (case->
                                  (-> integer? integer? integer?)
                                  (-> integer? (values integer? integer?))))))
  (test-name
   '(object-contract (m (->* (integer?) (boolean? number?) symbol?)))
   (object-contract (m (->* (integer?) (boolean? number?) symbol?))))

  (test-name '(object-contract (m (->d ((x ...)) () (y ...))))
             (object-contract (m (->d ((x number?)) () [result number?]))))
  (test-name '(object-contract (m (->d ((x ...) (y ...) (z ...)) () [w ...])))
             (object-contract (m (->d ((x number?) (y boolean?) (z pair?)) () [result number?]))))
  (test-name '(object-contract (m (->d ((x ...) (y ...) (z ...)) () #:rest w ... [x0 ...])))
             (object-contract (m (->d ((x number?) (y boolean?) (z pair?)) () 
                                      #:rest rest-x any/c [result number?]))))

  (test-name '(object-contract (m (->i ((x number?)) (result number?))))
             (object-contract (m (->i ((x number?)) () [result number?]))))
  (test-name '(object-contract (m (->i ((x number?) (y boolean?) (z pair?)) [result number?])))
             (object-contract (m (->i ((x number?) (y boolean?) (z pair?)) () [result number?]))))
  (test-name '(object-contract (m (->i ((x number?) (y boolean?) (z pair?)) 
                                       #:rest [rest-x any/c] [result number?])))
             (object-contract (m (->i ((x number?) (y boolean?) (z pair?)) () 
                                      #:rest [rest-x any/c] [result number?]))))

  (test-name '(promise/c any/c) (promise/c any/c))
  (test-name '(syntax/c any/c) (syntax/c any/c))
  (test-name '(struct/c st integer?)
             (let ()
               (define-struct st (a))
               (struct/c st integer?)))

  (test-name '(recursive-contract (box/c boolean?)) (recursive-contract (box/c boolean?)))
  (test-name '(recursive-contract boolean? #:flat) (let ([c (recursive-contract boolean? #:flat)])
                                                     (contract c #f 'pos 'neg)
                                                     c))
  (test-name '(recursive-contract x) (let ([x (box/c boolean?)]) (recursive-contract x)))
  (test-name '(recursive-contract integeeer?) 
             (let ([x (box/c boolean?)]) 
               (let ([c (recursive-contract (flat-named-contract 'integeeer? integer?))])
                 (contract c 1 'pos 'neg)
                 c)))
  (test-name '(recursive-contract (or/c (flat-named-contract 'integeeer? integer?)
                                        (listof c)))
             (letrec ([c (recursive-contract
                          (or/c (flat-named-contract 'integeeer? integer?)
                                (listof c)))])
               c))
  (test-name '(recursive-contract (or/c integeeer? (listof c)))
             (letrec ([c (recursive-contract
                          (or/c (flat-named-contract 'integeeer? integer?)
                                (listof c)))])
               (contract c 1 'pos 'neg)
               c))

  (contract-eval '(define-contract-struct couple (hd tl)))
  (test-name '(couple/c any/c any/c)
             (couple/c any/c any/c))
  (test-name '(couple/c any/c any/c)
             (couple/dc [hd any/c] [tl any/c]))
  (test-name '(couple/dc [hd any/c] [tl ...])
             (couple/dc [hd any/c] [tl (hd) any/c]))

  (test-name '(set/c integer?) (set/c integer?))
  (test-name '(set/c boolean? #:cmp 'equal) (set/c boolean? #:cmp 'equal))
  (test-name '(set/c char? #:cmp 'eq) (set/c char? #:cmp 'eq))
  (test-name '(set/c (set/c char?) #:cmp 'eqv) (set/c (set/c char? #:cmp 'dont-care) #:cmp 'eqv))
  (test-name '(set/c (-> char? char?) #:cmp 'equal) (set/c (-> char? char?) #:cmp 'equal))
  (test-name '(set/c (set/c string?) #:cmp 'equal-always)
             (set/c (set/c string? #:cmp 'dont-care) #:cmp 'equal-always))
  (test-name '(set/c (-> string? string?) #:cmp 'equal-always)
             (set/c (-> string? string?) #:cmp 'equal-always))
  (test-name '(set/c (-> integer? boolean?)) (set/c (-> integer? boolean?)))
  
  (test-name 'α (let ([α (new-∀/c)]) α))
  (test-name 'α (let ([α (new-∀/c #f)]) α))
  (test-name 'β (let ([α (new-∀/c 'β)]) α))
  (test-name '∀∃-unknown ((values new-∀/c)))
  (test-name '∀∃-unknown ((values new-∀/c) #f))
  
  (test-name '(class/c [m (->m integer? integer?)]) (class/c [m (->m integer? integer?)]))
  (test-name '(class/c [m (->*m (integer?) (integer?) integer?)])
              (class/c [m (->*m (integer?) (integer?) integer?)]))
  (test-name '(class/c [m (case->m (-> integer? integer?) (-> integer? integer? integer?))])
              (class/c [m (case->m (-> integer? integer?) (-> integer? integer? integer?))]))
  (test-name '(class/c [m (->dm ((x ...)) () (y ...))])
              (class/c [m (->dm ([d integer?]) () [r integer?])]))
  (test-name 'c%/c (let ([c%/c (class/c [m (->m integer? integer?)])])
                     c%/c))
  (test-name '(class/c (field [f integer?])) (class/c (field [f integer?])))
  (test-name '(class/c (field [f integer?])) (class/c (field [f integer?])))
  (test-name '(class/c (init [f integer?]) (field [f integer?])) (class/c (init-field [f integer?])))
  (test-name '(class/c (inherit-field [f integer?])) (class/c (inherit-field [f integer?])))
  (test-name '(class/c (absent a b c (field d e f))) (class/c (absent a b c (field d e f))))
  (test-name '(class/c (absent a b c)) (class/c (absent a b c)))
  (test-name '(class/c (inherit [f integer?])
                       (super [m (->m (<=/c -1) integer?)])
                       (inner [n (->m (<=/c 1) integer?)])
                       (override [o (->m (<=/c 2) integer?)])
                       (augment [p (->m (<=/c 3) integer?)])
                       (augride [q (->m (<=/c 4) integer?)]))
             (class/c (inherit [f integer?])
                      (super [m (->m (<=/c -1) integer?)])
                      (inner [n (->m (<=/c 1) integer?)])
                      (override [o (->m (<=/c 2) integer?)])
                      (augment [p (->m (<=/c 3) integer?)])
                      (augride [q (->m (<=/c 4) integer?)])))
  (test-name '(class/c (field n)) (class/c (field n)))

  (test-name '(cons/dc [hd integer?] [tl (hd) (if (positive? hd) integer? boolean?)])
             (cons/dc [hd integer?] [tl (hd) (if (positive? hd) integer? boolean?)]))
  
  (test-name '(struct/dc s
                         [a integer?]
                         [b symbol?]
                         [c (a b) ...]
                         [d (a b c) ...])
             (let ()
               (struct s (a b c d))
               (struct/dc s
                          [a integer?]
                          [b symbol?]
                          [c (a b) boolean?]
                          [d (a b c) integer?])))

  (test-name '(struct/dc s
                         [a integer?]
                         [b #:lazy symbol?]
                         [c (a) ...]
                         [d (a c) ...])
             (let ()
               (struct s (a b c d))
               (struct/dc s
                          [a integer?]
                          [b #:lazy symbol?]
                          [c (a) boolean?]
                          [d (a c) integer?])))
  
  (test-name '(struct/dc s
                         [a integer?]
                         [b #:lazy symbol?]
                         [c (a) ...]
                         [d (a c) ...]
                         #:inv (a c) ...)
             (let ()
               (struct s (a b c d))
               (struct/dc s
                          [a integer?]
                          [b #:lazy symbol?]
                          [c (a) boolean?]
                          [d (a c) integer?]
                          #:inv (a c) (if c (even? a) (odd? a)))))

  (contract-eval #:test-case-name "object-name.or/c"
                 `(,test '|(or/c 'ogg 'mp3)| object-name (or/c 'ogg 'mp3)))

  ;; NOT YET RELEASED
  #;
  (test-name '(pr/dc [x integer?]
                     [y integer?]
                     where
                     [x-val ...]
                     [y-val ...]
                     and
                     ...)
             (let ()
               (define-contract-struct pr (x y))
               (pr/dc [x integer?]
                      [y integer?]
                      where
                      [x-val x]
                      [y-val y]
                      and
                      (= x-val y-val)))))
