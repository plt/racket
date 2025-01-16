#lang racket/base

(provide bytes-append* bytes-join bytes->number)

(define (check-bytes-list* l name)
  (let loop ((l l))
    (cond ((null? (cdr l))
           (define tail (car l))
           (or (and (list? tail) (andmap bytes? tail))
               (raise-argument-error name "(listof bytes?)" tail))
           tail)
          (else
           (define e (car l))
           (or (bytes? e)
               (raise-argument-error name "bytes?" e))
           (cons e (loop (cdr l)))))))

(define (bytes-append* bstr-list-or-bstr . null-or-bstr-list*)
  (apply bytes-append (check-bytes-list* (cons bstr-list-or-bstr null-or-bstr-list*) 'bytes-append*)))

(require (only-in racket/list add-between)
         (only-in file/sha1 bytes->hex-string))

(define (bytes-join strs sep)
  (cond [(not (and (list? strs) (andmap bytes? strs)))
         (raise-argument-error 'bytes-join "(listof bytes?)" strs)]
        [(not (bytes? sep))
         (raise-argument-error 'bytes-join "bytes?" sep)]
        [(null? strs) (bytes)]
        [(null? (cdr strs)) (bytes-copy (car strs))]
        [else (apply bytes-append (add-between strs sep))]))

(define bytes->number (compose (lambda (s) (string->number s 16)) bytes->hex-string))