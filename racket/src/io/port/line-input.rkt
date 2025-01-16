#lang racket/base
(require racket/fixnum
         "../common/check.rkt"
         "input-port.rkt"
         "read-and-peek.rkt"
         "bytes-input.rkt"
         "string-input.rkt"
         "parameter.rkt"
         "flush-output.rkt")

(provide read-bytes-line
         read-line)

(define (ok-mode? v)
  (case v [(linefeed return return-linefeed any any-one) #t] [else #f]))
(define ok-mode-str "(or/c 'linefeed 'return 'return-linefeed 'any 'any-one)")

(define-syntax-rule (define-read-line read-line
                      make-string string-set! 
                      string-copy! substring
                      read-a-char peek-a-char
                      as-char direct-string?)
  (define/who (read-line [orig-in (current-input-port)] [mode 'any])
    (define in (->core-input-port orig-in who))
    (check who ok-mode? #:contract ok-mode-str mode)
    (maybe-flush-stdout orig-in)
    (define cr? (case mode [(return any any-one) #t] [else #f]))
    (define lf? (case mode [(linefeed any any-one) #t] [else #f]))
    (define crlf? (case mode [(return-linefeed any) #t] [else #f]))
    (cond
      [(maybe-read-a-line in cr? lf? crlf? direct-string?)
       => (lambda (r) r)]
      [else
       (define init-len 32)
       (let loop ([str (make-string init-len)] [len init-len] [pos 0])
         (define ch (read-a-char 'read-line in))
         (define (keep-char)
           (if (pos . fx< . len)
               (begin
                 (string-set! str pos ch)
                 (loop str len (fx+ pos 1)))
               (let* ([new-len (fx* len 2)]
                      [new-str (make-string new-len)])
                 (string-copy! new-str 0 str 0)
                 (string-set! new-str pos ch)
                 (loop new-str new-len (fx+ pos 1)))))
         (cond
           [(eof-object? ch)
            (if (fx= pos 0)
                eof
                (substring str 0 pos))]
           [(and (or cr? crlf?)
                 (eqv? ch (as-char #\return)))
            (cond
              [(and crlf?
                    (eqv? (peek-a-char 'read-line in 0) (as-char #\linefeed)))
               (read-a-char 'read-line in)
               (substring str 0 pos)]
              [cr?
               (substring str 0 pos)]
              [else (keep-char)])]
           [(and lf?
                 (eqv? ch (as-char #\newline)))
            (substring str 0 pos)]
           [else (keep-char)]))])))

(define-read-line read-line
  make-string string-set! 
  string-copy! substring
  read-a-char peek-a-char
  values
  #t)

 (define-read-line read-bytes-line
   make-bytes bytes-set! 
   bytes-copy! subbytes
   read-a-byte peek-a-byte
   char->integer
   #f)
