
(load-relative "loadtest.rktl")

(Section 'foreign)

(require ffi/unsafe
         ffi/unsafe/cvector
         ffi/unsafe/alloc
         ffi/unsafe/define
         ffi/unsafe/define/conventions
         ffi/unsafe/global
         ffi/unsafe/atomic
         ffi/unsafe/os-async-channel
         ffi/vector
         racket/extflonum
         racket/place
         racket/file
         racket/unsafe/ops)

(define test-async? (and (place-enabled?) (not (eq? 'windows (system-type)))))

(test #f malloc 0)
(test #f malloc 0 _int)
(test #f malloc _int 0)

(test 0 ptr-ref (malloc 100 'zeroed-atomic) _int 10)
(test 0 ptr-ref (malloc 100 'zeroed-atomic-interior) _int 10)

(unless (eq? 'cs (system-type 'gc))
  (test 0 bytes-length (make-sized-byte-string #f 0)))

(err/rt-test (malloc 'atomic) exn:fail:contract? #rx"no size given")

;; Check integer-range checking:
(let ()
  (define (try-int-boundary N _int _uint)
    (test (- (expt 2 N)) cast (- (expt 2 N)) _int _int)
    (test (sub1 (expt 2 N)) cast (sub1 (expt 2 N)) _int _int)
    (test (expt 2 N) cast (expt 2 N) _uint _uint)
    (test (sub1 (expt 2 (add1 N))) cast (sub1 (expt 2 (add1 N))) _uint _uint)
    (err/rt-test (cast (expt 2 N) _int _int))
    (err/rt-test (cast (sub1 (- (expt 2 N))) _int _int))
    (err/rt-test (cast -1 _uint _uint))
    (err/rt-test (cast (- (expt 2 N)) _uint _uint)))
  (try-int-boundary 7 _int8 _uint8)
  (try-int-boundary 7 _sbyte _ubyte)
  (test 128 cast -128 _byte _byte)
  (test 239 cast -17 _byte _byte)
  (try-int-boundary 15 _int16 _uint16)
  (try-int-boundary 15 _sword _uword)
  (try-int-boundary 15 _short _ushort)
  (test (expt 2 15) cast (- (expt 2 15)) _word _word)
  (try-int-boundary 31 _int32 _uint32)
  (try-int-boundary 63 _int64 _uint64))

(let ([big/little (if (system-big-endian?) (lambda (x y) x) (lambda (x y) y))]
      [p (malloc _int32)])
  (ptr-set! p _int32 0)
  (test 0 ptr-ref p _int32)
  (ptr-set! p _int32 16909060)
  (test 16909060 ptr-ref p _int32)
  (test 16909060 ptr-ref p _int32 0)
  (test (big/little 1 4) ptr-ref p _int8 0)
  (test (big/little 2 3) ptr-ref p _int8 1)
  (test (big/little 3 2) ptr-ref p _int8 2)
  (test (big/little 4 1) ptr-ref p _int8 3))
(flush-output)

(err/rt-test (_array _byte 1024 1024 1024 1024 1024 1024 1200 2)
             (lambda (exn) (regexp-match? #rx"arithmetic overflow" (exn-message exn))))

(when (eq? 'windows (system-type))
  (define concat string-append)
  (define 64bit? (= 8 (compiler-sizeof '(* void))))
  (define (find-dir what . dirs)
    (or (for/or ([d (in-list dirs)]) (and (directory-exists? d) d))
        (error (format "Could not find a directory: ~a" what))))
  (define progfiles
    (find-dir "Program Files" "C:/Program Files (x86)" "C:/Program Files"))
  (define studio
    (and progfiles (concat progfiles "/Microsoft Visual Studio 10.0")))
  (when (and studio (directory-exists? studio))
    (define (paths-env var . ps)
      (define orig-val (getenv var))
      (define val
        (apply concat (for/list ([p (in-list ps)]
                                 #:when (and p (directory-exists? p)))
                        (concat p ";"))))
      (printf ">>> $~a = ~s\n" var val)
      (putenv var (if orig-val
                      (concat orig-val ";" val)
                      val)))
    (define (vc p)     (concat studio "/VC/" p))
    (define (common p) (concat studio "/Common7/" p))
    (define (winsdk p) (concat progfiles "/Microsoft SDKs/Windows/v7.0A/" p))
    (paths-env "PATH"
               (vc (if 64bit? "BIN/amd64" "BIN"))
               (vc "IDE") (vc "Tools") (vc "Tools/bin")
               (common "Tools") (common "IDE"))
    (paths-env "INCLUDE"
               (vc "INCLUDE") (vc "ATLMFC/INCLUDE") (vc "PlatformSDK/INCLUDE")
               (winsdk "include"))
    (paths-env "LIB"
               (vc (if 64bit? "LIB/amd64" "LIB"))
               (vc (if 64bit? "ATLMFC/LIB/amd64" "ATLMFC/LIB"))
               (vc "PlatformSDK/LIB")
               (winsdk (if 64bit? "Lib/x64" "Lib")))
    (putenv "LIBPATH" (getenv "LIB"))
    (define tmp (getenv "TEMP"))
    (unless (and tmp (directory-exists? tmp))
      (putenv "TEMP" (find-dir "Temporary directory" "C:/Temp" "C:/tmp")))
    (when 64bit? (putenv "Platform" "X64"))))

(require dynext/compile dynext/link racket/runtime-path)
(define-runtime-path here ".")

(define test-tmp-dir
  (make-temporary-file "foreign~a" 'directory))
(copy-file (build-path here "foreign-test.c")
           (build-path test-tmp-dir "foreign-test.c"))
(define delete-test-files
  (parameterize ([current-directory test-tmp-dir])
    (let ([c  (build-path (current-directory) "foreign-test.c")]
          [o  (build-path (current-directory)
                          (if (eq? 'windows (system-type))
                              "foreign-test.obj" "foreign-test.o"))]
          [so (build-path (current-directory)
                          (bytes->path (bytes-append #"foreign-test"
                                                     (system-type 'so-suffix))))])
      (when (file-exists? o) (delete-file o))
      (when (file-exists? so) (delete-file so))
      (parameterize ([current-standard-link-libraries '()]
                     [current-extension-compiler-flags
                      (if test-async?
                          (append '("-pthread" "-DUSE_THREAD_TEST") (current-extension-compiler-flags))
                          (current-extension-compiler-flags))]
                     [current-extension-linker-flags
                      (if test-async?
                          (append '("-pthread") (current-extension-linker-flags))
                          (current-extension-linker-flags))])
        (compile-extension #t c o '())
        (link-extension #t (list o) so))
      (lambda ()
        (with-handlers ([exn:fail:filesystem?
                         (lambda (e)
                           (eprintf "warning: could not delete ~e\n" test-tmp-dir))])
          (delete-directory/files test-tmp-dir))))))

;; Test arrays
(define _c7_list (_array/list _byte 7))
(test 7 ctype-sizeof _c7_list)
(test 1 ctype-alignof _c7_list)

(test 21 ctype-sizeof (_array _byte 3 7))

;; Test enum and bitmask
(let ([t (_enum '(a b c = 4 d))]
      [s (_bitmask '(a b c = 14 d))])
  (define (check t v n)
    (test #t (λ (x) (equal? x n)) (cast v t _int)))
  (check t 'a 0)
  (check t 'b 1)
  (check t 'c 4)
  (check t 'd 5)
  (check s 'a 1)
  (check s 'b 2)
  (check s 'c 14)
  (check s 'd 16))

(let ([_bm _bitmask])
  (let ([s (_bm '(a b c = 14 d))])
    (test 2 values (cast 'b s _int))))

(let ()
  (define _test32_enum (_enum `(TEST32 = 1073741906) _sint32))
  (define _test64_enum (_enum `(TEST64 = 4611686018427387904) _sint64))
  (test 1073741906 cast 'TEST32 _test32_enum _sint32)
  (test 'TEST32 cast 1073741906 _sint32 _test32_enum)
  (test 4611686018427387904 cast  'TEST64 _test64_enum _sint64)
  (test 'TEST64 cast 4611686018427387904 _sint64 _test64_enum))

;; Make sure `_box` at least compiles:
(test #t ctype? (_fun (_box _int) -> _void))
(test #t ctype? (_fun (_box _int #f) -> _void))
(test #t ctype? (_fun (_box _int atomic-interior) -> _void))

;; Check error message on bad _fun form
(syntax-test #'(_fun (b) :: _bool -> _void) #rx"unnamed argument .without an expression. is not allowed")

;; Make sure that _enum works in non first order cases
(test #t ctype? (let ([enum _enum]) (enum '(x y))))
;; Make sure that _enum checks its inputs
(let ([_enum-exn? (lambda (exn)
                    (and (exn:fail:contract? exn)
                         (regexp-match? #rx"_enum" (exn-message exn))))])
  (error-test #'(_enum 1) _enum-exn?)
  (error-test #'(_enum '(1)) _enum-exn?)
  (error-test #'(_enum '(x = y)) _enum-exn?)
  (error-test #'(_enum '(x y) #:unknown (lambda (x y) x)) _enum-exn?))

(test 5 cast 'foo (_enum '(foo = 5)) _int)
(test -5 cast 'bar (_enum '(bar = -5)) _int)

(define-cstruct _ic7i ([i1 _int]
                       [c7 _c7_list]
                       [i2 _int]))

(let ()
  (define-cstruct _posn ([x _int]
                         [y _int]))
  (test #t equal? 'posn posn-tag))

(define _borl (_union _byte _long))
(define _ic7iorl (_union _ic7i _long))
(define _iord (_union _int _double))
(define _dorf (_union _double _float))
(define _dor2f (_union _double (_array _float 2)))

(define test-lib (ffi-lib (build-path test-tmp-dir "foreign-test")))

(for ([n (in-range 5)])
  (define (ffi name type) (get-ffi-obj name test-lib type))
  (define (test* expected name type proc)
    (test expected name (proc (ffi name type))))
  (define (t expected name type . args)
    (test* expected name type (lambda (p) (apply p args))))
  (define (tc expected name type arg1 . args)
    ;; curry first argument
    (test* expected name type (lambda (p) (apply (p arg1) args))))
  (define (sqr x) (when (zero? (random 4)) (collect-garbage)) (* x x))
  (define b (box #f))
  ;; ---
  (t  2 'add1_int_int   (_fun _int  -> _int ) 1)
  (t  2 'add1_byte_int  (_fun _byte -> _int ) 1)
  (t  2 'add1_int_byte  (_fun _int  -> _byte) 1)
  (t  2 'add1_byte_byte (_fun _byte -> _byte) 1)
  (t  -1 'add1_int_int   (_fun _int  -> _int ) -2)
  (t  -1 'add1_int_int   (_fun _int  -> _fixint ) -2)
  (t 2.0 'add1_float_float (_fun _float -> _float) 1.0)
  (t -1.0 'add1_float_float (_fun _float -> _float) -2.0)
  (t 2.0 'add1_double_double (_fun _double -> _double) 1.0)
  (t -1.0 'add1_double_double (_fun _double -> _double) -2.0)
  ;; ---
  (t 12 'decimal_int_int_int    (_fun _int  _int  -> _int ) 1 2)
  (t 12 'decimal_byte_int_int   (_fun _byte _int  -> _int ) 1 2)
  (t 12 'decimal_int_byte_int   (_fun _int  _byte -> _int ) 1 2)
  (t 12 'decimal_byte_byte_int  (_fun _byte _byte -> _int ) 1 2)
  (t 12 'decimal_int_int_byte   (_fun _int  _int  -> _byte) 1 2)
  (t 12 'decimal_byte_int_byte  (_fun _byte _int  -> _byte) 1 2)
  (t 12 'decimal_int_byte_byte  (_fun _int  _byte -> _byte) 1 2)
  (t 12 'decimal_byte_byte_byte (_fun _byte _byte -> _byte) 1 2)
  ;; ---
  (t  9 'callback3_int_int_int     (_fun (_fun _int  -> _int ) -> _int ) sqr)
  (t  79 'callback3_int_int_int    (_fun (_fun _int  -> _int ) -> _int ) #f) ; NULL allowed as function pointer
  (t  9 'callback3_int_int_int     (_fun _pointer -> _int ) (function-ptr sqr (_fun _int  -> _int ))) ; callback allowed as pointer
  (t  9 'callback3_byte_int_int    (_fun (_fun _byte -> _int ) -> _int ) sqr)
  (t  9 'callback3_short_int_int   (_fun (_fun _short -> _int ) -> _int ) sqr)
  (t  9 'callback3_int_byte_int    (_fun (_fun _int  -> _byte) -> _int ) sqr)
  (t  9 'callback3_int_short_int   (_fun (_fun _int  -> _short) -> _int ) sqr)
  (t  9 'callback3_byte_byte_int   (_fun (_fun _byte -> _byte) -> _int ) sqr)
  (t  9 'callback3_short_short_int (_fun (_fun _short -> _short) -> _int ) sqr)
  (t  9 'callback3_int_int_byte    (_fun (_fun _int  -> _int ) -> _byte) sqr)
  (t  9 'callback3_int_int_short   (_fun (_fun _int  -> _int ) -> _short) sqr)
  (t  9 'callback3_byte_int_byte   (_fun (_fun _byte -> _int ) -> _byte) sqr)
  (t  9 'callback3_short_int_short (_fun (_fun _short -> _int ) -> _short) sqr)
  (t  9 'callback3_int_byte_byte   (_fun (_fun _int  -> _byte) -> _byte) sqr)
  (t  9 'callback3_int_short_short (_fun (_fun _int  -> _short) -> _short) sqr)
  (t  9 'callback3_byte_byte_byte  (_fun (_fun _byte -> _byte) -> _byte) sqr)
  (t  9 'callback3_short_short_short (_fun (_fun _short -> _short) -> _short) sqr)
  (t  9.0 'callback3_float_float_float (_fun (_fun _float -> _float) -> _float) sqr)
  (t  9.0 'callback3_double_double_double (_fun (_fun _double -> _double) -> _double) sqr)
  ;; ---
  (tc 3 'curry_int_int_int    (_fun _int  -> (_fun _int  -> _int )) 1 2)
  (tc 3 'curry_byte_int_int   (_fun _byte -> (_fun _int  -> _int )) 1 2)
  (tc 3 'curry_int_byte_int   (_fun _int  -> (_fun _byte -> _int )) 1 2)
  (tc 3 'curry_byte_byte_int  (_fun _byte -> (_fun _byte -> _int )) 1 2)
  (tc 3 'curry_int_int_byte   (_fun _int  -> (_fun _int  -> _byte)) 1 2)
  (tc 3 'curry_byte_int_byte  (_fun _byte -> (_fun _int  -> _byte)) 1 2)
  (tc 3 'curry_int_byte_byte  (_fun _int  -> (_fun _byte -> _byte)) 1 2)
  (tc 3 'curry_byte_byte_byte (_fun _byte -> (_fun _byte -> _byte)) 1 2)
  ;; ---
  (test* 14 'ho (_fun (_fun _int -> _int) _int -> (_fun _int -> _int))
         (lambda (p) ((p add1 3) 10)))
  (test* 14 'ho (_fun (_fun _int -> _int) _int -> (_fun _int -> _int))
         (lambda (p) ((p (ffi 'add1_int_int (_fun _int -> _int)) 3) 10)))
  (test* 14 'ho (_fun (_fun _int -> _int) _int -> (_fun _int -> _int))
         (lambda (p) ((p (ffi 'add1_byte_byte (_fun _byte -> _byte)) 3) 10)))
  ;; ---
  (test* 4 'g2 _int (lambda (p) p))
  ;; ---
  (set-ffi-obj! "g3" test-lib (_fun _int -> _int) add1)
  (t 4 'use_g3 (_fun _int -> _int) 3)
  (test* 4 'g3 _pointer (lambda (p) ((function-ptr p (_fun _int -> _int)) 3)))
  ;; Equivalentlly, 'g3 is a static variable that holds a function pointer. By
  ;; looking it up with _fpointer, we get its address, which then works
  ;; with ptr-ref to extract the function. (This pattern isn't a good idea, but
  ;; it's a useful extra check here.)
  (test* 7 'g3 _fpointer (lambda (p) ((ptr-ref (cast p _fpointer _pointer) (_fun _int -> _int)) 6)))
  ;; ---
  (test ((lambda (x f) ((f (+ x 1)) (- x 1)))
         3 (lambda (x) (lambda (y) (+ y (* x x)))))
        'hoho
        ((ffi 'hoho (_fun _int (_fun _int -> (_fun _int -> _int)) -> _int))
         3 (lambda (x) (lambda (y) (+ y (* x x))))))
  ;; ---
  (let ([qsort (get-ffi-obj 'qsort #f
                            (_fun (l    : (_list io _int len atomic-interior))
                                  (len  : _int = (length l))
                                  (size : _int = (ctype-sizeof _int))
                                  (compare : (_fun _pointer _pointer -> _int))
                                  -> _void -> l))])
    (test '(0 1 2 3 4 5 6 7 8 9)
          'qsort
          (qsort
           '(7 1 2 3 5 6 4 8 0 9)
           (lambda (x y)
             (let ([x (ptr-ref x _int)] [y (ptr-ref y _int)])
               (cond [(< x y) -1] [(> x y) +1] [else 0])))))
    (test '() 'qsort (qsort '() (lambda (x y) (error "bad!")))))
  ;; ---
  ;; test vectors
  (t 55 'grab7th (_fun _pointer -> _int ) #"012345678")
  (t 56 'grab7th (_fun _pointer -> _int ) (ptr-add #"012345678" 1))
  (t 52 'grab7th (_fun _pointer -> _int ) (ptr-add #"012345678" -3))
  (t 10 'vec4    (_fun (_list   i _int) -> _int) '(1 2 3 4))
  (t 10 'vec4    (_fun (_vector i _int) -> _int) '#(1 2 3 4))
  (t 10 'vec4    (_fun _cvector -> _int) (list->cvector '(1 2 3 4) _int))
  (t 10 'vec4    (_fun _pointer -> _int)
                 (cvector-ptr (list->cvector '(1 2 3 4) _int)))
  ;; ---
  ;; test passing and receiving structs
  (let ([_charint (_list-struct _byte _int)])
    (t 1212       'charint_to_int (_fun _charint -> _int)     '(12 1200))
    (t '(123 123) 'int_to_charint (_fun _int -> _charint)     123)
    (t '(255 1)   'charint_swap   (_fun _charint -> _charint) '(1 255)))
  ;; Make sure allocation mode is used for function result
  (let ()
    (define-cstruct _charint ([b _byte]
                              [i _int])
      #:malloc-mode 'atomic-interior)
    (define v ((ffi 'int_to_charint (_fun _int -> _charint)) 77))
    (define addr (cast v _pointer _intptr))
    (test 77 charint-b v)
    (test 77 charint-b v)
    (collect-garbage)
    (test #t eqv? (cast v _pointer _intptr) addr))
  ;; ---
  ;; test sending a callback for C to hold, preventing the callback from GCing
  (let ([with-keeper
         (lambda (k)
           (define (sqr x)
             (when (eq? (system-type 'vm) 'chez-scheme)
               (test #t in-atomic-mode?))
             (* x x))
           (t (void) 'grab_callback
              (_fun (_fun #:keep k _int  -> _int) -> _void) sqr)
           (t 9      'use_grabbed_callback (_fun _int -> _int) 3)
           (collect-garbage) ; make sure it survives a GC
           (t 25     'use_grabbed_callback (_fun _int -> _int) 5)
           (collect-garbage)
           (t 81     'use_grabbed_callback (_fun _int -> _int) 9)
           (void/reference-sink sqr))])
    (with-keeper #t)
    (let ([b (box #f)])
      (with-keeper b)
      (set-box! b #f)))
  ;; ---
  ;; test passing an array of strings
  (test "world"
        (ffi 'second_string (_fun (_list i _string) -> _string))
        (list "hello" "world" "!"))
  ;; check that an io array of strings can have GC_allocated strings get replaced
  ;; by foreign addresses
  (test '("olleh" "dlrow" "?!" #f)
        (ffi 'reverse_strings (_fun (lst : (_list io _string 4)) -> _void -> lst))
        (list "hello" "world" "!?" #f #f))
  
  ;; ---
  ;; test exposing internal mzscheme functionality
  (when (eq? 'racket (system-type 'vm))
    (test '(1 2)
          (get-ffi-obj 'scheme_make_pair #f (_fun _scheme _scheme -> _scheme))
          1 '(2)))
  ;; ---
  ;; test arrays
  (let ([p (malloc _c7_list)]) ;; should allocate the right size
    (for ([i 7]) (ptr-set! p _byte i (+ i 10)))
    (test (for/list ([i 7]) (+ i 10)) cast p _pointer (_list o _byte 7))
    (t (for/list ([i 7]) (+ i 11)) 'increment_c_array (_fun _pointer -> (_list o _byte 7)) p)
    (let ([a (ptr-ref p (_array _byte 7))])
      (test 7 array-length a)
      (test 12 array-ref a 1)
      (ptr-set! p _byte 1 17)
      (test 17 array-ref a 1)
      (test #t array? (cast a (_array _byte 7) (_array _ubyte 7)))
      (test #t array? (cast a (_array _byte 6) (_array _ubyte 6))) ; smaller is ok
      (err/rt-test (cast a (_array _byte 8) (_array _ubyte 8))
                   (lambda (exn) (regexp-match? "array length does not match" (exn-message exn))))))
  (let ([a (ptr-ref (malloc (_array (_array _int 2) 3)) (_array (_array _int 2) 3))])
    (test #t array? (cast a (_array (_array _int 2) 2) (_array (_array _uint 2) 2))) ; smaller outside is ok
    (err/rt-test (cast a (_array (_array _int 1) 3) (_array (_array _uint 1) 3)) ; smaller inside is not ok
                 (lambda (exn) (regexp-match? "array element type is incompatible" (exn-message exn)))))
  ;; Disable these tests on Windows/i386 where they fail (and crash the process
  ;; killing all other tests).  Matthew said: There's no consistent spec for
  ;; functions that return structures in i386 Windows.  Historically, gcc does
  ;; it one way, and MSVC another.  I think libffi expects the gcc protocol.
  ;; Newer versions of gcc may agree with msvc, so this may change in the
  ;; future.
  (unless (and (eq? 'windows (system-type)) (= 4 (compiler-sizeof '(* void))))
    (let ([v (for/list ([i 7]) i)])
      ;; pass array as pointer:
      ;; FIXME: these tests wrap the result pointer as non-GCable,
      ;; but _c7_list allocates the argument array as GCable.
      (t (for/list ([i 7]) (add1 i)) 'increment_c_array (_fun _c7_list -> (_list o _byte 7)) v)
      (t (for/list ([i 7]) (add1 i)) 'increment_c_array (_fun _c7_list -> _c7_list) v)
      (let ([r ((ffi 'increment_c_array (_fun _c7_list -> (_array _byte 7))) v)])
        (test 2 array-ref r 1))
      ;; Array within struct argument and result:
      (let* ([ic7i (make-ic7i 13 v 14)]
             [ic7i-2 ((ffi 'increment_ic7i (_fun _ic7i -> _ic7i)) ic7i)])
        (test v ptr-ref (cast ic7i _ic7i-pointer _pointer) _c7_list 'abs (ctype-sizeof _int))
        (test 13 ic7i-i1 ic7i)
        (test v ic7i-c7 ic7i)
        (test 14 ic7i-i2 ic7i)
        (test 14 ic7i-i1 ic7i-2)
        (test (map add1 v) ic7i-c7 ic7i-2)
        (test 15 ic7i-i2 ic7i-2)
        (let ([ic7i-3 ((ffi 'ic7i_cb (_fun _ic7i (_fun _ic7i -> _ic7i) -> _ic7i))
                       ic7i
                       (lambda (ic7i-4)
                         (collect-garbage 'minor)
                         (test 12 ic7i-i1 ic7i-4)
                         (test (cons 255 (map sub1 (cdr v))) ic7i-c7 ic7i-4)
                         (test 13 ic7i-i2 ic7i-4)
                         (make-ic7i 2 (map (lambda (x) (- 252 x)) v) 9)))])
          (test 3 ic7i-i1 ic7i-3)
          (test (map add1 (map (lambda (x) (- 252 x)) v)) ic7i-c7 ic7i-3)
          (test 10 ic7i-i2 ic7i-3)))))
  ;; Two-dimensional array:
  ;; FIXME: same allocation bug for result as above
  (let ([v (for/list ([j 3]) (for/list ([i 7]) (+ i j)))]
        [v2 (for*/vector ([j 3] [i 7]) (+ i i j j))]
        [v3 (for/vector ([j 3]) (for/vector ([i 7]) (+ i i j j)))])
    (t v2 'increment_2d_array (_fun (_array/list _byte 3 7) -> (_vector o _byte 21)) v)
    (t v2 'increment_2d_array (_fun (_array/list (_array/list _byte 7) 3) -> (_vector o _byte 21)) v)
    (t v3 'increment_2d_array (_fun (_array/list (_array/list _byte 7) 3) -> (_array/vector _byte 3 7)) v))
  (t 0 'with_2d_array_cb (_fun (_fun (_array _byte 3 7) -> _void) -> _int)
     (lambda (a) (for ([i 3]) 
                   (for ([j 7]) 
                     (test (+ i (* 2 j)) array-ref a i j)
                     (array-set! a i j (+ (* 2 i) (* 2 j)))))))
  ;; ---
  ;; test union
  (let ([u (ptr-ref (malloc _borl) _borl)])
    (union-set! u 0 190)
    (test 190 union-ref u 0)
    (let ([u2 ((ffi 'increment_borl (_fun _int _borl -> _borl)) 0 u)])
      (test 191 union-ref u2 0))
    (union-set! u 1 (expt 2 19))
    (test (expt 2 19) union-ref u 1)
    (let ([u2 ((ffi 'increment_borl (_fun _int _borl -> _borl)) 1 u)])
      (test (add1 (expt 2 19)) union-ref u2 1)))
  (let ([u (ptr-ref (malloc _ic7iorl) _ic7iorl)])
    (union-set! u 1 190)
    (test 190 union-ref u 1)
    (let ([u2 ((ffi 'increment_ic7iorl (_fun _int _ic7iorl -> _ic7iorl)) 1 u)])
      (test 191 union-ref u2 1))
    (let ([v (for/list ([i 7]) i)])
      (union-set! u 0 (make-ic7i 3 v 88))
      (test 3 ic7i-i1 (union-ref u 0))
      (set-ic7i-i1! (union-ref u 0) 9)
      (test 9 ic7i-i1 (union-ref u 0))
      (let ([u2 ((ffi 'increment_ic7iorl (_fun _int _ic7iorl -> _ic7iorl)) 0 u)])
        (test 10 ic7i-i1 (union-ref u2 0))
        (test 89 ic7i-i2 (union-ref u2 0))
        (test (map add1 v) ic7i-c7 (union-ref u2 0)))))
  (let ([u (ptr-ref (malloc _iord) _iord)])
    (union-set! u 0 (expt 2 18))
    (test (expt 2 18) union-ref u 0)
    (let ([u2 ((ffi 'increment_iord (_fun _int _iord -> _iord)) 0 u)])
      (test (add1 (expt 2 18)) union-ref u2 0))
    (union-set! u 1 3.145)
    (test 3.145 union-ref u 1)
    (let ([u2 ((ffi 'increment_iord (_fun _int _iord -> _iord)) 1 u)])
      (test 4.145 union-ref u2 1)))
  (let ([u (ptr-ref (malloc _dorf) _dorf)])
    (union-set! u 0 1.075)
    (test 1.075 union-ref u 0)
    (let ([u2 ((ffi 'increment_dorf (_fun _int _dorf -> _dorf)) 0 u)])
      (test 2.075 union-ref u2 0))
    (union-set! u 1 3.5)
    (test 3.5 union-ref u 1)
    (let ([u2 ((ffi 'increment_dorf (_fun _int _dorf -> _dorf)) 1 u)])
      (test 4.5 union-ref u2 1)))
  (let ([u (ptr-ref (malloc _dor2f) _dor2f)])
    (union-set! u 0 3.075)
    (test 3.075 union-ref u 0)
    (let ([u2 ((ffi 'increment_dor2f (_fun _int _dor2f -> _dor2f)) 0 u)])
      (test 4.075 union-ref u2 0))
    (array-set! (union-ref u 1) 0 5.25)
    (array-set! (union-ref u 1) 1 7.25)
    (test 5.25 array-ref (union-ref u 1) 0)
    (test 7.25 array-ref (union-ref u 1) 1)
    (let ([u2 ((ffi 'increment_dor2f (_fun _int _dor2f -> _dor2f)) 1 u)])
      (test 6.25 array-ref (union-ref u2 1) 0)
      (test 8.25 array-ref (union-ref u2 1) 1)))
  ;; ---
  ;; test retries
  (t  78 'add1_int_int
      (_fun #:retry (again [count 0]) _int  -> (v : _int) -> 
            (if (= count 0)
                (again 76)
                (+ count v)))
      1)
  (t  95 'add1_int_int
      (_fun #:retry (again [count 0])
            (a) :: (a : _int = (+ a count))  -> (v : _int) -> 
            (if (= count 0)
                (again 92)
                v))
      2)
  
  )

;; test setting vector elements
(let* ([x #b01010101]
       [l 20]
       [v (make-u8vector l x)])
  (do ([i 0 (add1 i)]) [(= i l)]
    (test x u8vector-ref v i)))

(let ()
  (define-syntax (check stx)
    (syntax-case stx ()
      [(_ vec _type zero e1 e2 e3 has-unsafe?)
       (let ([id (lambda (a b [c ""])
                   (datum->syntax
                    #'vec
                    (string->symbol
                     (format "~a~a~a"
                             (if (syntax? a) (syntax-e a) a)
                             (if (syntax? b) (syntax-e b) b)
                             (if (syntax? c) (syntax-e c) c)))))])
         (with-syntax ([make-vec (id "make-" #'vec)]
                       [vec? (id #'vec "?")]
                       [vec-length (id #'vec "-length")]
                       [vec-ref (id #'vec "-ref")]
                       [vec-set! (id #'vec "-set!")]
                       [unsafe-vec-ref (id "unsafe-" #'vec "-ref")]
                       [unsafe-vec-set! (id "unsafe-" #'vec "-set!")]
                       [list->vec (id "list->" #'vec)]
                       [vec->list (id #'vec "->list")]
                       [vec->cpointer (id #'vec "->cpointer")]
                       [_vec (id "_" #'vec)])
           #`(let ([v1 (make-vec 5 zero)]
                   [v2 (vec e1 e2 e3)]
                   #,@(if (syntax-e #'has-unsafe?)
                          '()
                          (list #`[unsafe-vec-ref vec-ref]
                                #`[unsafe-vec-set! vec-set!])))
               (test #f vec? (make-vector 5))
               (test #t vec? v1)
               (test #t vec? v2)
               (test 5 vec-length v1)
               (test 3 vec-length v2)
               (test zero vec-ref v1 0)
               (test zero vec-ref v1 2)
               (test zero vec-ref v1 4)
               (test e1 vec-ref v2 0)
               (test e2 vec-ref v2 1)
               (test e3 vec-ref v2 2)
               (test e3 vec-ref v2 2)
               (test (void) vec-set! v1 2 e1)
               (test zero vec-ref v1 1)
               (test e1 vec-ref v1 2)
               (test zero vec-ref v1 3)
               (test zero unsafe-vec-ref v1 4)
               (test (void) unsafe-vec-set! v1 4 e2)
               (test e2 unsafe-vec-ref v1 4)
               (test (list zero zero e1 zero e2) vec->list v1)
               (test (list e1 e2 e3) vec->list v2)
               (let ([v3 (cast (vec->cpointer v1) _pointer (_vec o 5))])
                 (test (vec->list v1) vec->list v3))
               (let* ([p (malloc 'raw 4 _type)]
                      [v4 (cast p  _pointer (_vec o 4))])
                 (test (void) vec-set! v4 0 e3)
                 (test (void) vec-set! v4 1 e1)
                 (test (void) vec-set! v4 2 e1)
                 (test (void) vec-set! v4 3 e2)
                 (test e1 vec-ref v4 1)
                 (test e3 vec-ref v4 0))
               (void))))]))
  (check u8vector _ubyte 0 1 127 255 #f)
  (check s8vector _sbyte 0 1 127 -128 #f)
  (check u16vector _ushort 0 1 (expt 2 8) (sub1 (expt 2 16)) #t)
  (check s16vector _sshort 0 1 (sub1 (expt 2 15)) (- (expt 2 15)) #t)
  (check u32vector _uint 0 1 (expt 2 16) (sub1 (expt 2 32)) #f)
  (check s32vector _sint 0 1 (sub1 (expt 2 31)) (- (expt 2 31)) #f)
  (check u64vector _uint64 0 1 (expt 2 32) (sub1 (expt 2 64)) #f)
  (check s64vector _sint64 0 1 (sub1 (expt 2 63)) (- (expt 2 63)) #f)
  (check f32vector _float 0.0 1.0 1e10 -1e10 #f)
  (check f64vector _double 0.0 1.0 1e300 -1e300 #t)
  (void))

;; Test pointer arithmetic and memmove-like operations
(let ([p (malloc 10 _int)])
  (memset p 0 10 _int)
  (test 0 ptr-ref p _int)
  (test 0 ptr-ref (ptr-add p 3 _int) _int)
  (ptr-set! p _int 5)
  (test 5 ptr-ref p _int)
  (test 0 ptr-ref (ptr-add p 3 _int) _int)
  (memcpy p 3 p 0 1 _int)
  (test 5 ptr-ref (ptr-add p 3 _int) _int)

  ;; A Racket `int' is always 4 bytes.
  (memset p 1 17 9 _int)
  (test 5 ptr-ref p _int)
  (test #x11111111 ptr-ref (ptr-add p 4) _int)
  (memset p 2 18 (* 9 (ctype-sizeof _int)))
  (test #x12121212 ptr-ref (ptr-add p 4) _int)
  (test (if (system-big-endian?) #x00001212 #x12120005)
        ptr-ref p _int)

  (ptr-set! (ptr-add p 4 _int) _int 10)
  (ptr-set! (ptr-add p 5 _int) _int 11)
  (ptr-set! (ptr-add p 6 _int) _int 12)
  (memmove p 2 p 4 3 _int)
  (test 10 ptr-ref (ptr-add p 2 _int) _int)
  (test 11 ptr-ref (ptr-add p 3 _int) _int)
  (test 12 ptr-ref (ptr-add p 4 _int) _int)
  (memmove p (* 6 (ctype-sizeof _short)) p 8 12)
  (test 10 ptr-ref (ptr-add p 2 _int) _int)
  (test 10 ptr-ref (ptr-add p 3 _int) _int)
  (test 11 ptr-ref (ptr-add p 4 _int) _int)
  (test 12 ptr-ref (ptr-add p 5 _int) _int)
  (test 12 ptr-ref (ptr-add p 6 _int) _int)
  (memmove p p 8 4)
  (test 10 ptr-ref p _int)

  (test #f ptr-equal? p (ptr-add p 3))
  (test #t ptr-equal? p (ptr-add (ptr-add p 3) -3))
  (test #f ptr-equal? #f (ptr-add #f 8))
  (test #t ptr-equal? #f (ptr-add (ptr-add #f 8) -8))
  )

;; Test cstruct alignment
(let ()
  (define-cstruct _stuff ([a _int16]
                          [b _int32]
                          [c _int16])
    #:alignment 2)
  (define v (make-stuff 1 2 3))
  (test 8 ctype-sizeof _stuff)
  (test 3 stuff-c v)
  (test 1 ptr-ref v _int16 0)
  (test 3 ptr-ref v _int16 3))

;; Test intptr:
(let ([v (malloc _pointer)])
  (ptr-set! v _pointer (ptr-add #f 107))
  (test 107 ptr-ref v _intptr))

;; Test _bytes and _bytes/nul-terminated
(let ([p (malloc 8)])
  (memcpy p #"hi, all\0" 8)
  (test #"hi, all" cast p _pointer _bytes)
  (test #"hi, all" cast p _pointer _bytes/nul-terminated))
(let ([p (malloc 8)])
  (memcpy p #"hi, all!" 8)
  (test #"hi, all!" cast p _pointer (_bytes o 8))
  (test #"hi, all!" cast p _pointer (_bytes/nul-terminated o 8)))
(let* ([strdup (get-ffi-obj (if (eq? 'windows (system-type))
				'_strdup
				'strdup)
			    (if (eq? 'windows (system-type))
				(ffi-lib "msvcrt.dll")
				#f)
			    (_fun _bytes/nul-terminated -> _pointer))]
       [p (strdup #"howdy...")])
  (test #"howdy..." cast p _pointer _bytes)
  (test #"howdy..." cast p _pointer _bytes/nul-terminated)
  (let ([free (if (eq? 'windows (system-type))
		  ;; get `free` consistent with `_strdup`:
		  (get-ffi-obj 'free (ffi-lib "msvcrt.dll") (_fun _pointer -> _void))
		  free)])
    (free p)))

(let ([return_null (get-ffi-obj 'return_null test-lib (_fun -> _bytes/nul-terminated))])
  (test #f return_null))
(let ([return_null (get-ffi-obj 'return_null test-lib (_fun -> (_bytes/nul-terminated o 20)))])
  (test #f return_null))

;; Test equality and hashing of c pointers:
(let ([seventeen1 (cast 17 _intptr _pointer)]
      [seventeen2 (cast 17 _intptr _pointer)]
      [seventeen3 (ptr-add (cast 13 _intptr _pointer) 4)]
      [sixteen (cast 16 _intptr _pointer)])
  (test #t equal? seventeen1 seventeen2)
  (test #t equal? seventeen1 seventeen3)
  (test #f equal? sixteen seventeen1)
  (test #t = (equal-hash-code seventeen1) (equal-hash-code seventeen2))
  (test #t = (equal-hash-code seventeen1) (equal-hash-code seventeen3))
  (let ([ht (make-hash)])
    (hash-set! ht seventeen1 'hello)
    (test 'hello hash-ref ht seventeen2 #f)
    (test 'hello hash-ref ht seventeen3 #f)))

;; Check proper handling of offsets:
(when (eq? 'racket (system-type 'vm))
  (define scheme_make_sized_byte_string 
    (get-ffi-obj 'scheme_make_sized_byte_string #f (_fun _pointer _intptr _int -> _scheme)))
  ;; Non-gcable:
  (let ()
    (define p (cast (ptr-add #f 20) _pointer _pointer))
    (define d (scheme_make_sized_byte_string (ptr-add p 24)
                                             4
                                             0))
    (test 44 values (cast d _pointer _intptr)))
  ;; GCable:
  (let ()
    (define p (cast (ptr-add #f 20) _pointer _gcpointer))
    (define d (scheme_make_sized_byte_string (ptr-add p 24)
                                             4
                                             0))
    (test 44 values (cast d _gcpointer _intptr))))

;; test multi-dimension arrays
(let ([_t (_array _int 20 10 5)])
  (define ar (ptr-ref (malloc _t) _t))
  (define (t n)
    (test (void) array-set! ar 19 9 4 n)
    (test n      array-ref ar 19 9 4))
  (for-each t '(1 2 3)))

;; test casting of GCable and offset pointers:
(let ()
  (define _thing-pointer (_cpointer 'thing))
  (define _stuff-pointer (_cpointer 'stuff))
  
  (define p (cast (ptr-add (malloc 10) 5) _pointer _thing-pointer))
  (test #t cpointer-gcable? p)
  (define q (cast p _thing-pointer _stuff-pointer))
  (test #t ptr-equal? p q)
  (collect-garbage)
  (test #t ptr-equal? p q))

;; For casts where the BC output might share with the input, so
;; an offset pointer needs to be 'atomic-interior
(define (share-protect bstr)
  (if (eq? 'racket (system-type 'vm))
      (let ([new-bstr (malloc 'atomic-interior (add1 (bytes-length bstr)))])
        (memcpy new-bstr bstr (add1 (bytes-length bstr)))
        (make-sized-byte-string new-bstr (bytes-length bstr)))
      bstr))

;; `cast` should auto-upgrade target pointer types using `_gcable` for a GCable argument
(test #t cpointer-gcable? (cast #"x" _pointer _pointer))
(test #t cpointer-gcable? (cast #"x" _gcpointer _pointer))
(test #t cpointer-gcable? (cast #"x" _pointer _gcpointer))
(test #t cpointer-gcable? (cast (malloc 8) _pointer _pointer))
(test #t cpointer-gcable? (cast (malloc 8) _gcpointer _pointer))
(test #t cpointer-gcable? (cast (malloc 8) _pointer _gcpointer))
(test #t cpointer-gcable? (cast (ptr-add (malloc 8) 5) _pointer _pointer))
(test #t cpointer-gcable? (cast #"x" _bytes _pointer))
(test #t cpointer-gcable? (cast #"x" _bytes _gcpointer))
(test #t cpointer-gcable? (cast #"x" _bytes _bytes))
(test "lo" cast #"lo\0" _pointer _string/utf-8)
(test "lo" cast (if (system-big-endian?) #"l\0o\0\0\0" #"l\0o\0\0\0") _pointer _string/utf-16)
(test "lo" cast (if (system-big-endian?) #"\0\0\0l\0\0\0o\0\0\0\0\0\0\0\0" #"l\0\0\0o\0\0\0\0\0\0\0")
      _pointer _string/ucs-4)
(test #t cpointer-gcable? (cast (ptr-add #"xy" 1) _pointer _bytes))
(test #t cpointer-gcable? (cast (ptr-add #"xy" 1) _pointer _pointer))
(test (char->integer #\y) ptr-ref (cast (ptr-add #"xy" 1) _pointer _pointer) _byte)
(test #"lo" cast (ptr-add (share-protect #"hello\0") 3) _pointer _bytes)
(test "lo" cast (ptr-add #"hello\0" 3) _pointer _string/utf-8)
(test "lo" cast (ptr-add (if (system-big-endian?) #"e\0l\0l\0o\0\0\0" #"\0l\0l\0o\0\0\0") 3) _pointer _string/utf-16)
(test "lo" cast (ptr-add (share-protect (if (system-big-endian?) #"\0\0\0l\0\0\0l\0\0\0o\0\0\0\0\0\0\0\0" #"\0\0\0\0l\0\0\0o\0\0\0\0\0\0\0")) 4)
      _pointer _string/ucs-4)
(test #t cpointer-gcable? (cast '(#"apple") (_list i _bytes) _gcpointer))
(test #t
      'many-casts
      (for/and ([i (in-range 1000)])
        (cpointer-gcable? (cast (bytes 1 2 3 4)
                                _bytes
                                _pointer))))

;; test 'interior allocation mode
(let ()
  ;; Example by Ron Garcia
  (define-struct data (a b))
  (define (cbox s)
    (define ptr (malloc _racket 'interior))
    (ptr-set! ptr _racket s)
    ptr)
  (define (cunbox cb)
    (ptr-ref cb _racket 0))
  (define cb1 (cbox (make-data 1 2)))
  (collect-garbage)
  (test 1 data-a (cunbox cb1)))

;; Make sure calling a foreign function retains the function arguments
;; until the foreign function returns, even if it invokes a callback
(let ()
  (define sum_after_callback
    (get-ffi-obj 'sum_after_callback test-lib (_fun _pointer _int (_fun -> _void) -> _int)))
  (define N 1000)
  (test 499500
        'sum-after-callback
        (let ([n (malloc 'atomic-interior _int N)])
          (for ([i (in-range N)])
            (ptr-set! n _int i i))
          (sum_after_callback n N (lambda ()
                                    (collect-garbage)
                                    (collect-garbage)
                                    (collect-garbage)
                                    (for ([i 100])
                                      (let ([m (malloc _int N)])
                                        (for ([i (in-range N)])
                                          (ptr-set! m _int i 0)))))))))

(let ()
  (define-syntax (_varargs stx)
    (syntax-case stx ()
      [(_ arg ...)
       #`(_fun #:varargs-after 2
               _int ; init for result
               (_int = #,(quotient (length (syntax->list #'(arg ...))) 2))
               ;; each argument is an _int in [1, 5] followed by:
               ;;  1 - _int
               ;;  2 - _long
               ;;  3 - _double
               ;;  4 - _int pointer
               ;;  5 - (_fun #:varargs-after 2 _int _long ... -> _int)
               arg ... -> _long)]))
  (test 77
        (get-ffi-obj 'varargs_check test-lib (_varargs))
        77)
  (test 75
        (get-ffi-obj 'varargs_check test-lib (_varargs (_int = 1) _int))
        77 -2)
  (test 277
        (get-ffi-obj 'varargs_check test-lib (_varargs (_int = 2) _long))
        77 200)
  (test 86
        (get-ffi-obj 'varargs_check test-lib (_varargs (_int = 3) _double))
        76 10.2)
  (test 96
        (get-ffi-obj 'varargs_check test-lib (_varargs (_int = 3) _double (_int = 1) _int (_int = 2) _long (_int = 3) _double))
        86 1.0 2 3 4.0)
  (test 67
        (get-ffi-obj 'varargs_check test-lib (_varargs (_int = 4) (_ptr i _int) (_int = 1) _int))
        50 8 9)
  (test 67
        (get-ffi-obj 'varargs_check test-lib (_varargs (_int = 4) (_ptr i _int #f) (_int = 1) _int))
        50 8 9)
  (test 67
        (get-ffi-obj 'varargs_check test-lib (_varargs (_int = 4) (_ptr i _int atomic-interior) (_int = 1) _int))
        50 8 9)
  (test 16
        (get-ffi-obj 'varargs_check test-lib (_varargs (_int = 5) (_fun #:varargs-after 2 _int _long _double -> _int)))
        10 (lambda (a b c) (inexact->exact (+ a b c))))
  (void))

(let ()
  (struct foo (ptr)
    #:property prop:cpointer 0)
  
  (define a-foo (foo (malloc 16 'raw)))
  (free a-foo)
  (struct bar (ptr)
    #:property prop:cpointer (λ (s) (bar-ptr s)))
  
  (define a-bar (bar (malloc 16 'raw)))
  (free a-bar))

;; in Posix, so true for all OSes?
(test 13 lookup-errno 'EACCES)

(unless (eq? (system-type) 'windows)
  ;; saved-errno tests
  (define check-multiple-of-ten
    (get-ffi-obj 'check_multiple_of_ten test-lib (_fun #:save-errno 'posix _int -> _int)))
  (test 0 check-multiple-of-ten 40)
  (test -1 check-multiple-of-ten 42)
  (test 2 saved-errno)
  (saved-errno 5)
  (test 5 saved-errno)
  ;; test saved-errno is thread-local
  (define errno-from-thread #f)
  (sync (thread (lambda () (check-multiple-of-ten 17) (set! errno-from-thread (saved-errno)))))
  (test 5 saved-errno) ;; same as before
  (test 7 (lambda () errno-from-thread)))

(when (eq? (system-type) 'windows)
  ;; Use functions from msvcrt.dll that are documented to affect errno.
  ;; (See note in /racket/src/foreign/foreign.rktc about Windows.)
  (define msvcrt (ffi-lib "msvcrt.dll"))
  (define ENOENT 2)
  (define ERANGE 34)
  (define _getcwd   ;; sets errno = ERANGE if path longer than buffer
    (get-ffi-obj '_getcwd msvcrt (_fun #:save-errno 'posix _bytes/nul-terminated _int -> _void)))
  (define _chdir    ;; sets errno = ENOENT if path doesn't exist
    (get-ffi-obj '_chdir  msvcrt (_fun #:save-errno 'posix _string -> _int)))
  (define (bad/ERANGE) (_getcwd (make-bytes 1) 1))
  (define (bad/ENOENT) (_chdir "no-such-directory"))
  (bad/ERANGE)
  (test ERANGE saved-errno)
  (test -1 bad/ENOENT)
  (test ENOENT saved-errno)
  ;; test saved-errno is thread-local
  (define errno-from-thread #f)
  (sync (thread (lambda () (bad/ERANGE) (set! errno-from-thread (saved-errno)))))
  (test ENOENT saved-errno) ;; same as above
  (test ERANGE (lambda () errno-from-thread)))

(delete-test-files)

(when (eq? 'racket (system-type 'vm))
  (define _values (get-ffi-obj 'scheme_values #f (_fun _int (_list i _racket) -> _racket)))
  (test-values '(1 "b" three) (lambda () (_values 3 (list 1 "b" 'three)))))

(when (extflonum-available?)
  (define m (malloc _longdouble))
  (ptr-set! m _longdouble 13.57t0)
  (test 13.57t0 ptr-ref m _longdouble)

  (define v (extflvector 1.1t0 2.2t0 3.3t0))
  (test 3.3t0 extflvector-ref v 2)
  (test (void) extflvector-set! v 2 4.4t0)
  (test 4.4t0 extflvector-ref v 2)
  (test 2.2t0 ptr-ref (ptr-add (extflvector->cpointer v) (ctype-sizeof _longdouble)) _longdouble))

(when (eq? 'racket (system-type 'vm))
  ;; Check a corner of UTF-16 conversion:
  (test "\U171D3" cast (cast "\U171D3" _string/utf-16 _gcpointer) _gcpointer _string/utf-16))

;; strings can be cast
(test "heλλo" cast (cast "he\u3bb\u3bbo" _string/utf-16 _gcpointer) _gcpointer _string/utf-16)

;; symbols
(test "abc" cast (cast 'abc _symbol _gcpointer) _gcpointer _string/utf-8)
(test "heλλo" cast (cast 'heλλo _symbol _gcpointer) _gcpointer _string/utf-8)
(test (char->integer #\h) (get-ffi-obj 'grab7th test-lib  (_fun _symbol -> _int)) 'abcdefgh)

;; check async:
(when test-async?
  (define (check async like)
    (cond
      [(eq? (system-type 'vm) 'racket)
       (define foreign_thread_callback (get-ffi-obj 'foreign_thread_callback test-lib 
                                                    (_fun #:blocking? #t
                                                          (_fun #:async-apply async
                                                                _intptr -> _intptr)
                                                          _intptr
                                                          (_fun #:async-apply (lambda (f) (f))
                                                                -> _void)
                                                          -> _intptr)))
       (test (like 16) foreign_thread_callback (lambda (v) (add1 v)) 16 sleep)]
      [else
       (define foreign_thread_callback_setup (get-ffi-obj 'foreign_thread_callback_setup test-lib 
                                                          (_fun #:blocking? #t ; doesn't do anything in this case
                                                                (_fun #:async-apply async
                                                                      _intptr -> _intptr)
                                                                _intptr
                                                                -> _pointer)))
       (define foreign_thread_callback_check_done (get-ffi-obj 'foreign_thread_callback_check_done test-lib 
                                                               (_fun _pointer
                                                                     -> _bool)))
       (define foreign_thread_callback_finish (get-ffi-obj 'foreign_thread_callback_finish test-lib 
                                                           (_fun _pointer
                                                                 -> _intptr)))
       (define d (foreign_thread_callback_setup (lambda (v) (add1 v)) 16))
       (let loop ()
         (unless (foreign_thread_callback_check_done d)
           (sleep)
           (loop)))
       (test (like 16) foreign_thread_callback_finish d)]))
  (check (lambda (f) (f)) add1)
  (check (lambda (f) (thread f)) add1)
  (let ()
    ;; using thread mailboxes
    (define runner
      (thread
       (lambda ()
         (let loop ()
           (define p (thread-receive))
           (p)
           (loop)))))
    (check (lambda (f) (thread-send runner f)) add1))
  (when (eq? 'chez-scheme (system-type 'vm))
    (define chan (make-os-async-channel))
    (void
     (thread
      (lambda ()
        (let loop ()
          (define p (sync chan))
          (p)
          (loop)))))
    (check (lambda (f) (os-async-channel-put chan f)) add1))
  (check (box 20) (lambda (x) 20)))

;; check `#:callback-exns?`
(let ([callback_hungry (get-ffi-obj 'callback_hungry test-lib
                                    (_fun #:callback-exns? #t
                                          (_fun #:atomic? #t -> _int) -> _int))])
  (test 17 callback_hungry (lambda () 17))
  (for ([i 1000])
    (with-handlers ([(lambda (x) (eq? x 'out)) void])
      (callback_hungry (lambda () (raise 'out))))
    (sync (system-idle-evt))))
;; Same thing, with a lock
(let ([callback_hungry (get-ffi-obj 'callback_hungry test-lib
                                    (_fun #:callback-exns? #t
                                          #:lock-name "hungry"
                                          (_fun #:atomic? #t -> _int) -> _int))])
  (test 170 callback_hungry (lambda () 170))
  (for ([i 1000])
    (with-handlers ([(lambda (x) (eq? x 'out)) void])
      (callback_hungry (lambda () (raise 'out))))
    (sync (system-idle-evt))))

;; check in-array
(let ()
  (define _t (_array _int 6))
  (define ar (ptr-ref (malloc _t) _t))
  (for ([i (array-length ar)])
    (array-set! ar i (+ 10 i)))

  (test '(10 11 12 13 14 15) values (for/list ([a (in-array ar)]) a))
  (test '(11 12 13 14 15) values (for/list ([a (in-array ar 1)]) a))
  (test '(11 12) values (for/list ([a (in-array ar 1 3)]) a))
  (test '(10 12 14) values (for/list ([a (in-array ar 0 #f 2)]) a))

  (define seq (in-array ar))
  (test '(10 11 12 13 14 15) values (for/list ([a seq]) a))

  (err/rt-test (in-array '(1 2 3)) exn:fail:contract?))

;; check cstruct serialization (define-serialize-cstruct must be at module level, can't use (let () ...))
(module mod-cstruct-serialize racket/base
  (require (for-syntax racket/base)
           racket/serialize
           racket/list
           ffi/unsafe
           ffi/serialize-cstruct)

  ;; malloc helper
  (define current-raw (make-parameter (make-hash)))
  (define-syntax-rule (with-free . body)
    (parameterize ([current-raw (make-hash)])
      (register-finalizer (current-raw) (lambda (h) (for ([(k v) h]) (free k))))
      (begin . body)))

  (define (malloc/register size/type)
    (define sz (if (ctype? size/type)
                   (ctype-sizeof size/type)
                   size/type))
    (define m (malloc sz 'raw))
    (memset m 0 sz)
    (hash-set! (current-raw) m #t)
    m)

  ;; run multiple times to better catching gc related errors
  (define num-runs 5)

  (define-syntax-rule (err/rt-test e p?)
    (with-handlers ([p? void]
                    [exn:fail? (lambda (exn) (error 'test "exn test ~a failed, expected ~a but got ~a" 'e p? exn))])
      e))

  (define-syntax-rule (check-exn exn thunk)
    (if (regexp? exn)
        (err/rt-test (thunk) (lambda (e) (regexp-match? exn (exn-message e))))
        (err/rt-test (thunk) exn)))

  ;; --- syntax errors
  (define-syntax-rule (check-not-exn thunk)
    (with-handlers ([exn:fail? (lambda (exn) (error 'test "no-exn test ~a failed, got exn ~a" 'e exn))])
      (thunk)))

  (define-syntax-rule (check-equal? e v)
    (let ([r e]
          [v* v])
      (unless (equal? e v*)
        (error 'test "check-equal? ~a: expected ~s but got ~s" 'e v* r))))

  (define-syntax-rule (check-exn+rx exn rx thunk)
    (begin
      (err/rt-test (thunk) exn)
      (err/rt-test (thunk) (lambda (e) (regexp-match? rx (exn-message e))))))
  
  (check-exn+rx exn:fail:syntax? #rx"id must start with"
                (lambda () (expand #'(define-serializable-cstruct F1a ([a _int])))))
  (check-exn+rx exn:fail:syntax? #rx"only allowed in module or top-level context"
                (lambda () (expand #'(+ 1 (define-serializable-cstruct _F1b ([a _int]))))))
  (check-exn+rx exn:fail:syntax? #rx"#:property prop:serializable not allowed"
                (lambda () (expand #'(define-serializable-cstruct _F1c ([a _int]) #:property prop:serializable #f))))
  (check-exn+rx exn:fail:syntax? #rx"expected \\[field-id ctype\\]"
                (lambda () (expand #'(define-serializable-cstruct _F1d ()))))


  ;; --- misc creation tests
  (define-values (prop:tmp prop:tmp? prop:tmp-ref)
    (make-struct-type-property 'testprop))

  (define-serializable-cstruct _M1 ([a _int]) #:alignment 8)
  (define-serializable-cstruct _M2 ([a _int]) #:property prop:tmp 'abc)
  (define-serializable-cstruct _M3 ([a _int]) #:malloc-mode 'atomic)
  (define-serializable-cstruct _M4 ([a _int]) #:malloc-mode 'raw)

  (let ()
    (check-not-exn (lambda () (make-M1 123)))
    (check-not-exn (lambda () (make-M2 123)))
    (check-not-exn (lambda () (make-M3/mode 123)))
    (check-not-exn (lambda ()
                     (define s (make-M4/mode 123))
                     (free s))))

  ;; --- test different types
  (define-serializable-cstruct _MISC ([d _double] [ad (_array _double 10)]
                                      [i _int] [ai (_array _int 10)])
    #:malloc-mode malloc/register)
  (define-serializable-cstruct _MISCPTR ([s _string] [as (_array _string 4)]
                                         [b _bytes] [ab (_array _bytes 4)])
    #:malloc-mode 'nonatomic)

  (for ([i num-runs])
    (with-free
     (define m (ptr-ref (malloc/register _MISC) _MISC))
     (set-MISC-d! m 1.234)
     (set-MISC-i! m 456)
     (for ([i 10])
       (array-set! (MISC-ad m) i (exact->inexact (+ i (* i .1))))
       (array-set! (MISC-ai m) i (+ i 5)))

     (check-not-exn (lambda () (deserialize (serialize m))))

     (define d  (deserialize (serialize m)))
     (collect-garbage)

     (check-equal? (MISC-d d) 1.234)
     (check-equal? (MISC-i d) 456)
     (for ([i 10])
       (check-equal? (array-ref (MISC-ad d) i) (exact->inexact (+ i (* i .1))))
       (check-equal? (array-ref (MISC-ai d) i) (+ i 5)))))

  (for ([i num-runs])
    (define m (ptr-ref (malloc _MISCPTR 'nonatomic) _MISCPTR))
    (set-MISCPTR-s! m "str")
    (set-MISCPTR-b! m #"bstr")
    (define s-list (list "abc" "def" "ghi" "jkl"))
    (define b-list (list #"mno" #"pqr" #"stu"))
    (for ([s s-list] [b b-list] [i (in-naturals)])
      (array-set! (MISCPTR-as m) i s)
      (array-set! (MISCPTR-ab m) i b))

    (check-not-exn (lambda () (deserialize (serialize m))))
    (define d  (deserialize (serialize m)))
    (collect-garbage)

    (check-equal? (MISCPTR-s d) "str")
    (check-equal? (MISCPTR-b d) #"bstr")

    (for ([s s-list] [b b-list] [i (in-naturals)])
      (check-equal? (array-ref (MISCPTR-as d) i) s)
      (check-equal? (array-ref (MISCPTR-ab d) i) b)))

  ;; --- simple failing tests
  (define-serializable-cstruct _F4 ([a _int]) #:malloc-mode 'abc)
  (define-serializable-cstruct _F40 ([a _fpointer]))
  (define-cstruct _F4E ([a _int]))
  (define-serializable-cstruct _F41 ([a _F4E]))
  (define-serializable-cstruct _F42 ([a _F4E-pointer]))
  (define-serializable-cstruct _F43 ([a (_array _F4E 3)]))
  (define-serializable-cstruct _F44 ([a (_array _F4E-pointer 3)]))
  (define-serializable-cstruct _F45 ([a _pointer]))
  (define-serializable-cstruct _F46 ([a (_array _pointer 3)]))
  (define-serializable-cstruct _F47 ([a _fpointer]))
  (define-serializable-cstruct _F48 ([a (_array _fpointer 3)]))

  (with-free
   (check-exn exn:fail? (lambda () (make-F4/mode 1)))
   (check-exn exn:fail? (lambda () (deserialize (serialize (make-F4 1)))))

   (define msg #rx"is not serializable")
   (check-exn msg (lambda () (serialize (ptr-ref (malloc _F40) _F40))))
   (check-exn msg (lambda () (serialize (ptr-ref (malloc _F40) _F40)))) ; same: test promise
   (check-exn msg (lambda () (serialize (ptr-ref (malloc _F41) _F41))))
   (check-exn msg (lambda () (serialize (ptr-ref (malloc _F42) _F42))))
   (check-exn msg (lambda () (serialize (ptr-ref (malloc _F43) _F43))))
   (check-exn msg (lambda () (serialize (ptr-ref (malloc _F44) _F44))))
   (check-exn msg (lambda () (serialize (ptr-ref (malloc _F45) _F45))))
   (check-exn msg (lambda () (serialize (ptr-ref (malloc _F46) _F46))))
   (check-exn msg (lambda () (serialize (ptr-ref (malloc _F47) _F47))))
   (check-exn msg (lambda () (serialize (ptr-ref (malloc _F48) _F48)))))

  ;; --- test shared pointers
  (define-serializable-cstruct _B ([a _int]) #:malloc-mode malloc/register)
  (define-serializable-cstruct _C ([b _B-pointer]) #:malloc-mode malloc/register)
  (define-serializable-cstruct _D ([b _B-pointer]) #:malloc-mode malloc/register)
  (define-serializable-cstruct _A ([c _C-pointer] [d _D-pointer]) #:malloc-mode malloc/register)

  (for ([i num-runs])
    (with-free
     (define b (make-B/mode 123))
     (define c (make-C/mode b))
     (define d (make-D/mode b))
     (define a (make-A/mode c d))

     (define s1 (serialize a))
     (define ds1 (deserialize s1))
     (check-equal? (ptr-equal? (C-b (A-c ds1)) (D-b (A-d ds1))) #t)

     (collect-garbage)
     (check-equal? (C-b (A-c a)) (D-b (A-d a)))
     (check-equal? (C-b (A-c ds1)) (D-b (A-d ds1)))
     (check-equal? (B-a (C-b (A-c ds1))) 123)))


  ;; --- test cyclic pointers
  (define _CY1/fwd (_cpointer/null 'CY1 _pointer
                                   values
                                   (lambda (e) (cast e _pointer _CY1-pointer))))

  (define-serializable-cstruct _CY0 ([a _CY1/fwd]) #:malloc-mode malloc/register)
  (define-serializable-cstruct _CY1 ([a _CY0-pointer]) #:malloc-mode malloc/register)

  (for ([i num-runs])
    (with-free
     (define cy0 (make-CY0/mode #f))
     (define cy1 (make-CY1/mode cy0))
     (set-CY0-a! cy0 cy1)

     (define s2 (serialize cy1))
     (define ds2 (deserialize s2))

     (collect-garbage)
     (check-equal? cy1 (CY0-a cy0))
     (check-equal? cy0 (CY1-a (CY0-a cy0)))

     (check-equal? ds2 (CY0-a (CY1-a ds2)))))


  ;; --- self referencing struct
  (define-serializable-cstruct _SELF ([a _SELF-pointer/null]) #:malloc-mode malloc/register)

  (for ([i num-runs])
    (with-free
     (define self (make-SELF/mode #f))
     (set-SELF-a! self self)

     (cast self _pointer _uintptr)
     (cast (SELF-a self) _pointer _uintptr)

     (define s3 (serialize self))
     s3
     (define ds3 (deserialize s3))
     ds3

     (collect-garbage)
     (cast ds3 _pointer _uintptr)
     (cast (SELF-a ds3) _pointer _uintptr)
     (check-equal? ds3 (SELF-a ds3))

     ;; ---

     (define self2 (make-SELF/mode #f))
     (define ds4 (deserialize (serialize self2)))
     (collect-garbage)
     (check-equal? (SELF-a ds4) #f)))


  ;; --- struct pointer array and embedded struct array
  (define-serializable-cstruct _SINT ([a _int]) #:malloc-mode malloc/register)
  (define-serializable-cstruct _PTRAR ([a (_array _SINT-pointer/null 2 5)]) #:malloc-mode malloc/register)
  (define-serializable-cstruct _EMBAR ([a (_array _SINT 2 5)]) #:malloc-mode malloc/register)

  (for ([i num-runs])
    (with-free
     (define par (ptr-ref (malloc/register _PTRAR) _PTRAR))
     (for* ([i 2] [j 5])
       (array-set! (PTRAR-a par) i j (make-SINT/mode (+ 10 j (* i 5)))))

     (define ds (deserialize (serialize par)))
     (collect-garbage)

     (check-equal?
      (for*/and ([i 2] [j 5])
        (= (SINT-a (array-ref (PTRAR-a ds) i j)) (+ 10 j (* i 5))))
      #t)

     ;; --
     (define ear (ptr-ref (malloc/register _EMBAR) _EMBAR))
     (for* ([i 2] [j 5])
       (array-set! (EMBAR-a ear) i j (make-SINT/mode (+ 10 j (* i 5)))))

     (define ds2 (deserialize (serialize ear)))
     (collect-garbage)

     (check-equal?
      (for*/and ([i 2] [j 5])
        (= (SINT-a (array-ref (EMBAR-a ds2) i j)) (+ 10 j (* i 5))))
      #t)))

  ;; --- array with embedded struct with pointer
  (define-serializable-cstruct _TP ([a _int]) #:malloc-mode malloc/register)
  (define-serializable-cstruct _TB ([a _TP-pointer]) #:malloc-mode malloc/register)
  (define-serializable-cstruct _TS ([a (_array _TB 2)]) #:malloc-mode malloc/register)

  (with-free
   (define p (make-TP/mode 65))
   (define s (ptr-ref (malloc/register _TS) _TS))

   (set-TB-a! (array-ref (TS-a s) 0) p)
   (set-TB-a! (array-ref (TS-a s) 1) p)

   (define ds (deserialize (serialize s)))
   (memset p 0 1 _TP)

   (check-equal? (TB-a (array-ref (TS-a ds) 0))
                 (TB-a (array-ref (TS-a ds) 1)))
   (check-equal? 65 (TP-a (TB-a (array-ref (TS-a ds) 0)))))


  ;; --- inplace tests
  (define can-in-place? (not (eq? 'chez-scheme (system-type 'vm))))

  (define-serializable-cstruct _NOIN ([a _int]))

  (define-serializable-cstruct _INS ([a _int]) #:serialize-inplace)

  (define-serializable-cstruct _IND ([a _int]) #:deserialize-inplace)

  (define-serializable-cstruct _INSD ([a _int])
    #:serialize-inplace #:deserialize-inplace
    #:malloc-mode (if can-in-place?
                      (lambda (_) (error "should not get here"))
                      malloc/register))

  ;; non-inplace + modification
  (let ()
    (define noin (make-NOIN/mode 123))
    (define s (serialize noin))
    (set-NOIN-a! noin 0)

    (define ds (deserialize s))
    (check-equal? (NOIN-a ds) 123)

    (for ([e (flatten s)])
      (when (bytes? e)
        (memset e 0 (bytes-length e)  _byte)))
    (check-equal? (NOIN-a ds) 123))

  ;; inplace serialize and test modification
  (let ()
    (define ins (make-INS/mode 123))

    (check-not-exn (lambda () (serialize ins)))
    (define s (serialize ins))
    (check-not-exn (lambda () (deserialize s)))

    ;; unmodified
    (define ds1 (deserialize s))
    (check-equal? 123 (INS-a ds1))

    ;; modified
    (set-INS-a! ins 456)
    (define ds2 (deserialize s))
    (check-equal? (if can-in-place? 456 123) (INS-a ds2)))

  ;; inplace deser
  (let ()
    (define ind (ptr-ref (malloc _IND) _IND))
    (set-IND-a! ind 123)

    (check-not-exn (lambda () (serialize ind)))
    (define s (serialize ind))
    (check-not-exn (lambda () (deserialize s)))

    (define ds (deserialize s))
    (check-equal? 123 (IND-a ds)))

  ;; both inplace, should never malloc
  (let ()
    (define insd (ptr-ref (malloc _INSD) _INSD))
    (set-INSD-a! insd 123)

    (check-not-exn (lambda () (serialize insd)))
    (define s (serialize insd))
    (check-not-exn (lambda () (deserialize s)))
    (define ds (deserialize s))

    (check-equal? 123 (INSD-a ds))))

(require (only-in 'mod-cstruct-serialize))

;; Check that `define-serializable-cstruct' works in a top-level context
(require racket/serialize
         ffi/serialize-cstruct)
(define-serializable-cstruct _serializable-example-1 ([a _int]))
(test 17 serializable-example-1-a (deserialize (serialize (make-serializable-example-1 17))))

;; ----------------------------------------
;; Check that `i`, `o`, and `io` are matched as symbols, not by binding:

(let ([i 'no]
      [o 'no]
      [io 'no])
  (test #t ctype? (_ptr i _int))
  (test #t ctype? (_ptr o _int))
  (test #t ctype? (_ptr io _int))
  (test #t ctype? (_list i _int))
  (test #t ctype? (_list o _int 10))
  (test #t ctype? (_list io _int 10))
  (test #t ctype? (_vector i _int))
  (test #t ctype? (_vector o _int 10))
  (test #t ctype? (_vector io _int 10)))

(test #t ctype? (_ptr i _int atomic))
(test #t ctype? (_ptr i _int zeroed-atomic))
(test #t ctype? (_ptr i _int atomic-interior))
(test #t ctype? (_ptr i _int zeroed-atomic-interior))

(syntax-test #'(_ptr i _int magic))

;; ----------------------------------------

(define-cpointer-type _foo)
(test 'foo? object-name foo?)
(test #t cpointer-predicate-procedure? foo?)
(test #f cpointer-predicate-procedure? (λ (x) (foo? x)))

(define-cpointer-type _also_foo #f #f (lambda (ptr)
                                        (cpointer-push-tag! ptr 'extra)
                                        ptr))
(let ([p (cast (malloc 16) _pointer _also_foo)])
  (test #t also_foo? p)
  (test #t cpointer-has-tag? p 'extra))
(test #t cpointer-predicate-procedure? foo?)

;; ----------------------------------------
;; Test JIT inlining

(define (test-ptr-jit-inline bstr)
  (for/fold ([v 1.0]) ([i (in-range 100)])
    (ptr-set! bstr _float v)
    (ptr-set! bstr _float 1 (+ v 0.5))
    (ptr-set! bstr _float 'abs 8 (+ v 0.25))
    (unless (= v (ptr-ref bstr _float))
      (error 'float "failed"))
    (unless (= (+ v 0.5) (ptr-ref bstr _float 'abs 4))
      (error 'float "failed(2) ~s ~s" (+ v 0.5) (ptr-ref bstr _float 'abs 4)))
    (unless (= (+ v 0.25) (ptr-ref bstr _float 2))
      (error 'float "failed(3)"))
    (+ 1.0 v))

  (for/fold ([v 1.0]) ([i (in-range 100)])
    (ptr-set! bstr _double v)
    (ptr-set! bstr _double 1 (+ v 0.5))
    (ptr-set! bstr _double 'abs 16 (+ v 0.25))
    (ptr-set! (ptr-add bstr 24) _double (+ v 0.125))
    (unless (= v (ptr-ref bstr _double))
      (error 'double "failed"))
    (unless (= (+ v 0.5) (ptr-ref bstr _double 'abs 8))
      (error 'double "failed(2)"))
    (unless (= (+ v 0.25) (ptr-ref bstr _double 2))
      (error 'double "failed(3)"))
    (unless (= (+ v 0.5) (ptr-ref (ptr-add bstr 8) _double))
      (error 'double "failed(4)"))
    (unless (= (+ v 0.125) (ptr-ref (ptr-add bstr 24) _double))
      (error 'double "failed(5)"))
    (+ 1.0 v))

  (for ([i (in-range 256)])
    (ptr-set! bstr _uint8 i)
    (ptr-set! bstr _uint8 1 (- 255 i))
    (unless (= i (ptr-ref bstr _uint8))
      (error 'uint8 "fail ~s vs. ~s" i (ptr-ref bstr _uint8)))
    (unless (= (- 255 i) (ptr-ref bstr _uint8 'abs 1))
      (error 'uint8 "fail(2) ~s vs. ~s" (- 255 i) (ptr-ref bstr _uint8 'abs 1))))

  (for ([i (in-range -128 128)])
    (ptr-set! bstr _int8 i)
    (unless (= i (ptr-ref bstr _int8))
      (error 'int8 "fail ~s vs. ~s" i (ptr-ref bstr _int8))))

  (for ([i (in-range (expt 2 16))])
    (ptr-set! bstr _uint16 i)
    (ptr-set! bstr _uint16 3 (- (sub1 (expt 2 16)) i))
    (unless (= i (ptr-ref bstr _uint16))
      (error 'uint16 "fail ~s vs. ~s" i (ptr-ref bstr _uint16)))
    (unless (= (- (sub1 (expt 2 16)) i) (ptr-ref bstr _uint16 'abs 6))
      (error 'uint16 "fail(2) ~s vs. ~s" (- (sub1 (expt 2 16)) i) (ptr-ref bstr _uint16 'abs 6))))

  (for ([j (in-range 100)])
    (for ([i (in-range (- (expt 2 15)) (sub1 (expt 2 15)))])
      (ptr-set! bstr _int16 i)
      (unless (= i (ptr-ref bstr _int16))
        (error 'int16 "fail ~s vs. ~s" i (ptr-ref bstr _int16)))))

  (let ()
    (define (go lo hi)
      (for ([i (in-range lo hi)])
        (ptr-set! bstr _uint32 i)
        (ptr-set! bstr _uint32 1 (- hi (- i lo) 1))
        (unless (= i (ptr-ref bstr _uint32))
          (error 'uint32 "fail ~s vs. ~s" i (ptr-ref bstr _uint32)))
        (unless (= (- hi (- i lo) 1) (ptr-ref bstr _uint32 'abs 4))
          (error 'uint32 "fail ~s vs. ~s" (- hi (- i lo) 1) (ptr-ref bstr _uint32)))))
    (go 0 256)
    (go (- (expt 2 31) 256) (+ (expt 2 31) 256))
    (go (- (expt 2 32) 256) (expt 2 32)))

  (let ()
    (define (go lo hi)
      (for ([i (in-range lo hi)])
        (ptr-set! bstr _int32 i)
        (unless (= i (ptr-ref bstr _int32))
          (error 'int32 "fail ~s vs. ~s" i (ptr-ref bstr _int32)))))
    (go -256 256)
    (go (- (expt 2 31) 256) (sub1 (expt 2 31)))
    (go (- (expt 2 31)) (- 256 (expt 2 31))))

  (let ()
    (define (go lo hi)
      (for ([i (in-range lo hi)])
        (ptr-set! bstr _uint64 i)
        (ptr-set! bstr _uint64 1 (- hi (- i lo) 1))
        (unless (= i (ptr-ref bstr _uint64))
          (error 'uint64 "fail ~s vs. ~s" i (ptr-ref bstr _uint64)))
        (unless (= (- hi (- i lo) 1) (ptr-ref bstr _uint64 'abs 8))
          (error 'uint32 "fail ~s vs. ~s" (- hi (- i lo) 1) (ptr-ref bstr _uint64)))))
    (go 0 256)
    (go (- (expt 2 63) 256) (+ (expt 2 63) 256))
    (go (- (expt 2 64) 256) (expt 2 64)))

  (let ()
    (define (go lo hi)
      (for ([i (in-range lo hi)])
        (ptr-set! bstr _int64 i)
        (unless (= i (ptr-ref bstr _int64))
          (error 'int64 "fail ~s vs. ~s" i (ptr-ref bstr _int64)))))
    (go -256 256)
    (go (- (expt 2 63) 256) (sub1 (expt 2 63)))
    (go (- (expt 2 63)) (- 256 (expt 2 63))))

  (let ()
    (define p (malloc 10 'atomic-interior))
    (for ([i (in-range 100)])
      (ptr-set! bstr _pointer (ptr-add p i))
      (ptr-set! bstr _pointer 2 p)
      (unless (ptr-equal? p (ptr-add (ptr-ref bstr _pointer) (- i)))
        (error 'pointer "fail ~s vs. ~s"
               (cast p _pointer _intptr)
               (cast (ptr-ref bstr _pointer) _pointer _intptr)))
      (unless (ptr-equal? p (ptr-ref bstr _pointer 'abs (* 2 (ctype-sizeof _pointer))))
        (error 'pointer "fail ~s vs. ~s"
               (cast p _pointer _intptr)
               (cast (ptr-ref bstr _pointer 'abs (ctype-sizeof _pointer)) _pointer _intptr))))))

(let ()
  (test-ptr-jit-inline (make-bytes 64))
  (test-ptr-jit-inline (cast (make-bytes 64) _pointer _pointer))
  (let ([p (malloc 'raw 64)])
    (test-ptr-jit-inline p)
    (free p)))

;; ----------------------------------------

(when (eq? 'racket (system-type 'vm))
  (define scheme_make_type
    (get-ffi-obj 'scheme_make_type #f (_fun _string -> _short)))
  (define scheme_register_type_gc_shape
    (get-ffi-obj 'scheme_register_type_gc_shape #f (_fun _short (_list i _intptr) -> _void)))

  (define SHAPE_STR_TERM       0)
  (define SHAPE_STR_PTR_OFFSET 1)

  (define-cstruct _tagged ([type-tag _short]
                           [obj1 _racket]
                           [non2 _intptr]
                           [obj3 _racket]
                           [non4 _intptr])
    #:define-unsafe
    #:malloc-mode 'tagged)
  (test #t cpointer-predicate-procedure? tagged?)

  (define t (scheme_make_type "new-type"))
  (scheme_register_type_gc_shape t (list SHAPE_STR_PTR_OFFSET tagged-obj1-offset
                                         SHAPE_STR_PTR_OFFSET tagged-obj3-offset
                                         SHAPE_STR_TERM))

  (define obj1 (make-string 10))
  (define obj2 (make-bytes 12))
  (define obj3 (make-bytes 14))
  (define obj4 (make-string 16))

  (define obj2-addr (cast obj2 _racket _intptr))
  (define obj4-addr (cast obj4 _racket _intptr))

  (define o (make-tagged t obj1 obj2-addr obj3 obj4-addr))

  (collect-garbage)

  (eq? (tagged-obj1 o) obj1)
  (eq? (tagged-obj3 o) obj3)
  (= (tagged-non2 o) obj2-addr)
  (= (tagged-non4 o) obj4-addr))

;; ----------------------------------------

(test #t procedure? ((allocator void) void))
(test #f (allocator void) #f)

;; ----------------------------------------

;; Check `void/reference-sink`
(let* ([sym (gensym)]
       [wb (make-weak-box sym)])
  (collect-garbage)
  (void/reference-sink sym)
  (test #f not (weak-box-value wb)))

;; ----------------------------------------

(let ()
  (define-ffi-definer define-test-lib test-lib
    #:make-c-id convention:hyphen->underscore)
  (define-test-lib underscore-variable (_fun -> _void))
  (test (void) underscore-variable))

(let ()
  (define-ffi-definer define-test-lib test-lib
    #:make-c-id convention:hyphen->camelCase)
  (define-test-lib camel-case-variable (_fun -> _void))
  (test (void) camel-case-variable)
  (define-test-lib cAmeL-CAsE-vaRiaBlE (_fun -> _void))
  (test (void) cAmeL-CAsE-vaRiaBlE))

(let ()
  (define-ffi-definer define-test-lib test-lib
    #:make-c-id convention:hyphen->PascalCase)
  (define-test-lib pascal-case-variable (_fun -> _void))
  (test (void) pascal-case-variable)
  (define-test-lib paSCaL-CAsE-vaRiaBlE (_fun -> _void))
  (test (void) paSCaL-CAsE-vaRiaBlE))

(let ()
  (define-ffi-definer define-test-lib test-lib
    #:make-c-id convention:hyphen->camelcase)
  (define-test-lib pascal-case-variable (_fun -> _void))
  (test (void) pascal-case-variable)
  (define-test-lib paSCaL-CAsE-vaRiaBlE (_fun -> _void))
  (test (void) paSCaL-CAsE-vaRiaBlE))

(let ()
  (define-ffi-definer define-test-lib test-lib)

  (define-test-lib g1 _int #:variable)
  (define-test-lib curry_ret_int_int (_fun _int -> _int))

  (g1 12)
  (test 25 curry_ret_int_int 13)
  (test 12 g1)

  (define-test-lib g2 _int #:variable)
  (define-test-lib ho_return (_fun _int -> _int))
  (define update-g2-fun-name 'ho)
  (define-test-lib update-g2 (_fun (_fun _int -> _int) _int -> _void)
    #:c-id ,update-g2-fun-name)
  (g2 20)
  (test (void) update-g2 (lambda (n) (* n 3)) 15)
  (test 45 g2)
  (test 48 ho_return 3)

  (define-test-lib no_such_var _int #:variable #:fail (lambda () #f))
  (test #f values no_such_var))

(let ()
  (define-ffi-definer define-test-lib test-lib
    #:make-c-id convention:hyphen->underscore
    #:default-make-fail (lambda (name) (lambda () #f)))
  (define (valid-cpointer? v) (and (cpointer? v) (not (eq? v #f))))
  (let ()
    (define-test-lib add1-int-int _fpointer)
    (test #t valid-cpointer? add1-int-int))
  (let ()
    ;; Convention should not be applied when explicit #:c-id.
    (define-test-lib add1-by-any-other-name _fpointer #:c-id add1_int_int)
    (test #t valid-cpointer? add1-by-any-other-name))
  (let ()
    ;; Convention should not be applied when explicit #:c-id.
    (define-test-lib add1-int-int _fpointer #:c-id add1-int-int)
    (test #f valid-cpointer? add1-int-int)))

;; ----------------------------------------
;; Make sure `_union` can deal with various things
;; that create a large structure

(let ()
  (define-cpointer-type _FcCharSet)
  (define-cstruct _FcMatrix ([xx _double] [xy _double]
                             [yx _double] [yy _double]))
  (define-cstruct _FcValue ([u (_union _bytes _int _bool _double
                                       _long _long _long _long
                                       _FcMatrix-pointer
                                       _FcCharSet)]))
  (malloc _FcValue))

;; ----------------------------------------

(let* ([bstr (string->bytes/utf-8 (format "~a ~a" (current-inexact-milliseconds) (random)))]
       [orig-bstr (bytes-copy bstr)])
  (err/rt-test (register-process-global 7 8))
  (err/rt-test (register-process-global "7" 8))
  (test #f register-process-global bstr #f)
  (test #f register-process-global bstr #"data\0")
  (test #"data" cast (register-process-global bstr #f) _pointer _bytes)
  (bytes-set! bstr 0 65)
  (test #f register-process-global bstr #f)
  (test #"data" cast (register-process-global orig-bstr #"data\0") _pointer _bytes))

;; ----------------------------------------
;; Make sure `make-ctype` is not confused by a conversion function that
;; could have extra arguments

(let ()
  (define _strnum (make-ctype _int
                              (lambda (s [ignored 'ignore-me])
                                (test 'ignore-me values ignored)
                                (string->number s))
                              (lambda (n [ignored 'ignore-me])
                                (test 'ignore-me values ignored)
                                (number->string n))))
  (test 5 cast "5" _strnum _int)
  (test "5" cast 5 _int _strnum))

;; ----------------------------------------

(let ()
  ;; test _delay with non-gcable types
  (define counter 0)
  (define-cstruct _outer
    ([x (_delay (begin (set! counter (add1 counter)) _inner-pointer))])
    #:malloc-mode 'raw)
  (define-cstruct _inner
    ([y _int])
    #:malloc-mode 'raw)
  (define an-inner (make-inner 42))
  (test 0 values counter)
  (define an-outer (make-outer an-inner))
  (test 1 values counter)
  (test #t inner? (outer-x an-outer))
  (test #t ptr-equal? (outer-x an-outer) an-inner)
  (test 1 values counter)
  (free an-outer)
  (free an-inner))

(let ()
  ;; test _delay again with gcable types
  (define counter 0)
  (define-cstruct _outer
    ([x (_delay (begin (set! counter (add1 counter)) _inner-pointer) _gcpointer)])
    #:malloc-mode 'nonatomic)
  (define-cstruct _inner
    ([y _int])
    #:malloc-mode 'atomic)
  (define an-inner (make-inner 42))
  (test 0 values counter)
  (define an-outer (make-outer an-inner))
  (test 1 values counter)
  (test #t inner? (outer-x an-outer))
  (test #t ptr-equal? (outer-x an-outer) an-inner)
  (test 1 values counter)
  (test #t (lambda ()
             (for/and ([i 10])
               (collect-garbage)
               (equal? 42 (inner-y (outer-x an-outer)))))))

;; ----------------------------------------

(report-errs)

#| --- ignore everything below ---

The following is some random Scheme and C code, with some things that should be
added.

-------------------------------------------------------------------------------
(define foo-struct1
  (get-ffi-obj "foo_struct1" "junk/foo.so" (_fun _foo -> _int)))
(define foo-struct2
  (get-ffi-obj "foo_struct2" "junk/foo.so" (_fun _foo -> _foo)))
(printf ">>> foo-struct1(32,23) = ~s\n" (foo-struct1 '(32 23)))
(printf ">>> foo-struct2(32,23) = ~s\n" (foo-struct2 '(32 23)))
(exit)

(define-cstruct _foo ((b _byte) (i _int)))
(printf ">>> struct-type: ~s\n" _foo)
(printf ">>>        size: ~s\n" (ctype-sizeof _foo))
(printf ">>>   alignment: ~s\n" (ctype-alignof _foo))
(define foo-struct1
  (get-ffi-obj "foo_struct1" "junk/foo.so" (_fun _foo -> _int)))
(define foo-struct2
  (get-ffi-obj "foo_struct2" "junk/foo.so" (_fun _foo -> _foo)))
(define foostruct (make-foo 32 23))
(printf ">>> foostruct = ~s = ~s,~s\n"
        foostruct (foo-b foostruct) (foo-i foostruct))
(set-foo-b! foostruct 34)
(set-foo-i! foostruct 43)
(printf ">>> foostruct = ~s = ~s,~s\n"
        foostruct (foo-b foostruct) (foo-i foostruct))
(printf ">>> foo-struct1(34,43) = ~s\n" (foo-struct1 foostruct))
(printf ">>> foo-struct2(34,43) = ~s\n"
        (let ([x (foo-struct2 foostruct)]) (list (foo-b x) (foo-i x))))
(exit)

(printf ">>> g3 = ~s\n"
        (get-ffi-obj "g3" "junk/foo.so" _string))
(printf ">>> g3 := \"blah\" -> ~s\n"
        (set-ffi-obj! "g3" "junk/foo.so" _string "blah"))
(printf ">>> g3 = ~s\n"
        (get-ffi-obj "g3" "junk/foo.so" _string))
(printf ">>> g3 := add1 -> ~s\n"
        (set-ffi-obj! "g3" "junk/foo.so" _scheme add1))
(printf ">>> g3 = ~s\n"
        (get-ffi-obj "g3" "junk/foo.so" _scheme))
(printf ">>> g3 := s->c[int->int](add1) -> ~s\n"
        (set-ffi-obj! "g3" "junk/foo.so" (_fun _int -> _int) add1))
(printf ">>> (ptr) g3 = ~s\n"
        (get-ffi-obj "g3" "junk/foo.so" _pointer))
(printf ">>> (int->int) g3 = ~s\n"
        (get-ffi-obj "g3" "junk/foo.so" (_fun _int -> _int)))
(printf ">>> use_g3(3) = ~s\n"
        ((get-ffi-obj "use_g3" "junk/foo.so" (_fun _int -> _int)) 3))
(printf ">>> g3(3) = ~s\n"
        ((ptr-ref (get-ffi-obj "g3" "junk/foo.so" _pointer)
                  (_fun _int -> _int))
         3))

(define block (malloc 4 _int))
(ptr-set! block _int 0 2)
(ptr-set! block _int 1 1)
(ptr-set! block _int 2 4)
(ptr-set! block _int 3 3)
(printf ">>> block= ~s\n" (list (ptr-ref block _int 0)
                                (ptr-ref block _int 1)
                                (ptr-ref block _int 2)
                                (ptr-ref block _int 3)))

(printf ">>> foo_none() = ~s\n"
        ((get-ffi-obj "foo_none" "./junk/foo.so" (_fun -> _void))))
(printf ">>> sleep(1) = ~s\n"
        ((get-ffi-obj "sleep" #f (_fun _int -> _void)) 1))
(printf ">>> fprintf(stderr,\"...\",3) = ~s\n"
        ((get-ffi-obj "fprintf" #f (_fun _pointer _string _int -> _void))
         (get-ffi-obj "stderr" #f _pointer)
         "using fprintf on stderr with an argument: %d\n"
         3))

(define (foo-test name args type)
  (define res (apply (get-ffi-obj name "junk/foo.so" type) args))
  (printf ">>> ~a~s -> ~s\n" name args res)
  res)
(foo-test "foo_int"    '(3)     (_fun _int -> _int))
(foo-test "foo_int"    '(3)     (_fun _fixint -> _fixint))
(foo-test "foo_int3"   '(1 2 3) (_fun _int _int _int -> _int))
(foo-test "foo_int3"   '(1 2 3) (_fun _fixint _fixint _fixint -> _fixint))
(foo-test "foo_long3"  '(1 2 3) (_fun _long _long _long -> _long))
(foo-test "foo_long3"  '(1 2 3) (_fun _fixnum _fixnum _fixnum -> _fixnum))
(foo-test "foo_char"   '(3)     (_fun _byte -> _byte))
(foo-test "foo_short"  '(22)    (_fun _word -> _word))
(foo-test "foo_ushort" '(22)    (_fun _ushort -> _ushort))
(foo-test "foo_byte"   '(22)    (_fun _byte -> _byte))
(foo-test "foo_ubyte"  '(22)    (_fun _ubyte -> _ubyte))
(foo-test "foo_byte"   '(156)   (_fun _byte -> _byte))
(foo-test "foo_ubyte"  '(156)   (_fun _ubyte -> _ubyte))
(foo-test "foo_double" '(81.0)  (_fun _double -> _double))
(foo-test "foo_double" '(81.0f0)  (_fun _double -> _double))
(foo-test "foo_float"  '(81.0)  (_fun _float -> _float))
(foo-test "foo_float"  '(81.0f0)  (_fun _float -> _float))

(exit) ;=======================================================================
(newline)
(define x1 "foo")
(define x2 (foo-test "foo_string" (list x1) '(string) 'string))
(printf ">>> now x1 = ~s\n" x1)
(string-set! x2 1 #\X)
(foo-test "foo_string" '(#f) '(string) 'string)

(newline)
(printf ">>> sizeof(int) = ~s\n" (ffi-size-of 'int))
'(let loop ((l '()))
  (eprintf ">>> ~s\n" (length l))
  (when (> (length l) 50)
    (set-cdr! (cddddr l) '())
    (collect-garbage))
  (sleep 1)
  ;; behavior with flags of this: atomic -> much faster, uncollectable -> crash
  (loop (cons (malloc 'byte 1000000) l)))
(define block1 (malloc 'int 4))
(printf ">>> block1 = ~s\n" block1)
(ffi-ptr-set! block1 'ulong 0 67305985)
(printf ">>> first uint of block1 = ~s\n" (ffi-ptr-ref block1 'uint))
(define block2 (malloc block1 'int 4))
(printf ">>> first 4 bytes of block2 = ~s\n"
        (list (ffi-ptr-ref block2 'ubyte 0) (ffi-ptr-ref block2 'ubyte 1)
              (ffi-ptr-ref block2 'ubyte 2) (ffi-ptr-ref block2 'ubyte 3)))
(ffi-ptr-set! block1 'ulong 0 11)
(ffi-ptr-set! block1 'ulong 1 22)
(ffi-ptr-set! block1 'ulong 2 33)
(ffi-ptr-set! block1 'ulong 3 44)
;(ffi-ptr-set! block1 'ulong 'abs 1 22)
(printf ">>> [0] -> ~s\n" (ffi-ptr-ref block1 'ulong 0))
(printf ">>> [1] -> ~s\n" (ffi-ptr-ref block1 'ulong 1))
(printf ">>> [abs 1] -> ~s\n" (ffi-ptr-ref block1 'ulong 'abs 1))
(printf ">>> [abs 4] -> ~s\n" (ffi-ptr-ref block1 'ulong 'abs 4))
(printf ">>> ptr-equal? b1 b2     -> ~s\n" (ffi-equal-ptr? block1 block2))
(printf ">>> ptr-equal? b1 NULL   -> ~s\n" (ffi-equal-ptr? block1 #f))
(printf ">>> ptr-equal? b1 b1     -> ~s\n" (ffi-equal-ptr? block1 block1))
(printf ">>> ptr-equal? NULL NULL -> ~s\n" (ffi-equal-ptr? #f #f))

(newline)
(define (final x) (printf "GC>>> ~s[0]=~s\n" x (ffi-ptr-ref x 'ulong)))
(printf ">>> set finalizer b1 -> ~s\n" (register-finalizer block1 final))
(printf ">>> set finalizer b1 -> ~s\n" (register-finalizer block1 final))
(printf ">>> set finalizer b2 -> ~s\n" (register-finalizer block2 final))
(printf ">>> set finalizer b2 -> ~s\n" (register-finalizer block2 #f))
(printf "Collecting garbage...\n")
(collect-garbage)
(printf "Clearing block1,2 and GCing again...\n")
(set! block1 #f) (set! block2 #f)
(collect-garbage)

(newline)
(define (foo x) (+ x x x))
(define a (malloc 'int 20))
(ffi-ptr-set! a 'scheme foo)
(define b (ffi-ptr-ref a 'pointer))
(ffi-ptr-set! a 'scheme 1 b)
(printf ">>> a[1] as a pointer object = ~s\n" (ffi-ptr-ref a 'scheme 1))
(ffi-ptr-set! a 'pointer 1 b)
(printf ">>> a[1] as the pointer value = ~s\n" (ffi-ptr-ref a 'scheme 1))
(printf ">>> (a[1] 12) -> ~s\n" ((ffi-ptr-ref a 'scheme 1) 12))

(newline)
(define c:int1 (make-ctype c:int sub1 add1))
(define c:foo
  (make-ctype
   c:foo c:int1
   (lambda (x)
     (unless (memq x '(foo1 foo2 bar1 bar2))
       (raise-type-error 'foo->int1 "foo" x))
     (cdr (assq x '((foo1 . 1) (foo2 . 2) (bar1 . 3) (bar2 . 4)))))
   (lambda (x)
     (cdr (or (assq x '((1 . foo1) (2 . foo2) (3 . bar1) (4 . bar2)))
              '(#f . #f))))))

(printf ">>> sizeof(fooo) = ~s\n" (ffi-size-of 'fooo))
(foo-test "foo_foo" (list 'foo1) '(fooo) 'fooo)
(foo-test "foo_foo" (list 'foo2) '(fooo) 'fooo)
(foo-test "foo_foo" (list 'bar1) '(fooo) 'fooo)
(foo-test "foo_foo" (list 'bar2) '(fooo) 'fooo)
(foo-test "foo_foo" (list 'fooo) '(fooo) 'fooo)
-------------------------------------------------------------------------------
void foo_none() {
  fprintf(stderr, "===>>> in foo_none()\n");
}

#define U unsigned

int     foo_int    (int x)     { return x*2; }
int     foo_int3   (int x, int y, int z) { return x*y*z; }
long    foo_long3  (long x, long y, long z) { return x*y*z; }
char    foo_char   (char x)    { return toupper(x); }
short   foo_short  (short x)   { return x + 40000; }
U short foo_ushort (U short x) { return x + 40000; }
char    foo_byte   (char x)    { return x + 200; }
U char  foo_ubyte  (U char x)  { return x + 200; }
double  foo_double (double x)  { return sqrt(x); }
float   foo_float  (float x)   { return sqrt(x); }

char*   foo_string (char* x) {
  if (x==NULL) {
    printf("===>>> Got NULL, HOME=\"%s\"\n", getenv("HOME"));
    return NULL;
  } else {
    x[0] = toupper(x[0]);
    return getenv("HOME");
  }
}

int foo_foo(int x) { return x^1; }

-------------------------------------------------------------------------------
|#
