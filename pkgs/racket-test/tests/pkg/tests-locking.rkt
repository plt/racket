#lang racket/base
(require web-server/http
         web-server/servlet-env
         "basic-index.rkt"
         "shelly.rkt"
         "util.rkt")

(this-test-is-run-by-the-main-test)

(pkg-tests
 (with-fake-root
  (shelly-case
   "A lock is used to guarantee serial access to the package database"

   ;; Step 1: Start a special server that waits for our signal to respond
   (initialize-catalogs)

   (define succeed-catalog (make-channel))
   (define fail-catalog (make-channel))

   (thread
    (λ ()
      (serve/servlet (pkg-index/basic
                      (λ (pkg-name)
                        (channel-put fail-catalog 'go)
                        (sync fail-catalog) ;; => 'continue
                        (define r (hash-ref *index-ht-1* pkg-name #f))
                        r)
                      (λ () *index-ht-1*))
                     #:command-line? #t
                     #:servlet-regexp #rx""
                     #:port 9967)))

   ;; Step 2: Assign it as our server
   $ "raco pkg config --set catalogs http://localhost:9967"

   $ "raco pkg show pkg-test1"

   ;; Step 3: Start an installation request in the background
   (thread
    (λ ()
      (shelly-begin
       $ "raco pkg install pkg-test1"
       $ "raco pkg show pkg-test1")
      (channel-put succeed-catalog 'done)))
   (sync fail-catalog) ;; => 'go

   ;; Step 4: Start the installation request that will fail
   $ "raco pkg install pkg-test1" =exit> 1

   ;; Step 5: Free the other one
   (channel-put fail-catalog 'continue)
   (sync succeed-catalog) ;; => 'done
   )))
