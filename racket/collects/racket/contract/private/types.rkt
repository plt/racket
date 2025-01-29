#lang racket/base
(provide types)
(define types
  (hash '(and/c-name racket/contract/private/and)
        '(->* () #:rest Contract Contract)

        '(or/c-name racket/contract/private/orc)
        '(->* () #:rest Contract Contract)))

;; cast : alpha (<alpha,beta> ctc) -> beta