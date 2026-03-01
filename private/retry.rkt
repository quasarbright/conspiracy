#lang racket

(provide with-retry exponential-backoff immediate-retry no-retry)
(module+ test (require rackunit "test-util.rkt"))
(require "clock.rkt")

;; example
#;
(with-retry (lambda (retry e attempt)
              (when (exn-not-retryable? e)
                (raise e))
              ;; no more than 2 attempts, including the initial
              ;; (only 1 "retry")
              (when (>= attempt 2)
                (raise e))
              ;; exponential backoff with initial delay of 10
              ;; wait 10, then 20, then 40, etc.
              (clock-sleep (* 10 (expt 2 (sub1 attempt))))
              (retry))
  (with-timeout 60
    (do-something)))

;; A RetryHandler is a ((-> any) exn:fail? natural? any)
;; the first argument is a procedure to retry
;; the second is the failure
;; the third is the number of the attempt that just failed. first attempt is 1
;; see exponential-backoff for an example

(define-syntax-rule (with-retry handler body ...)
  (with-retry/proc handler (lambda () body ...)))

;; RetryHandler (-> any) -> any
(define (with-retry/proc handler thnk)
  (let loop ([attempt 1])
    (with-handlers ([exn:fail? (lambda (e) (let ([retry (lambda () (loop (add1 attempt)))])
                                             (handler retry e attempt)))])
      (thnk))))

;; example retry handlers

;; RetryHandler
;; initial-delay a NonNegativeReal, defaults to 1
;;   how long (in seconds) to wait after the first try before retrying
;; delay-multiplier is a NonNegativeReal, defaults to 2
;;   after each retry, the delay gets multiplied by this value
;; max-attempts is the maximum number of attempts. defaults to 3.
;;   ex: max-attempts=2 means if the initial try and the first retry fail, give up
(define (exponential-backoff #:initial-delay [initial-delay 1] #:delay-multiplier [delay-multiplier 2] #:max-attempts [max-attempts 3] #:exn-retryable? [exn-retryable? (const #t)])
  (lambda (retry e attempt)
    (unless (exn-retryable? e)
      (raise e))
    (when (>= attempt max-attempts)
      (raise e))
    (clock-sleep (* initial-delay (expt delay-multiplier (sub1 attempt))))
    (retry)))

;; RetryHandler
(define (immediate-retry #:max-attempts [max-attempts 3] #:exn-retryable? [exn-retryable? (const #t)])
  (exponential-backoff #:initial-delay 0 #:delay-multiplier 0 #:max-attempts max-attempts #:exn-retryable? exn-retryable?))

;; RetryHandler
(define (no-retry)
  (lambda (_retry e _attempt) (raise e)))

(module+ test
  (test-case
   "order of events for exponential backoff"
   (check-equal?
    (with-timing-and-logging
        (with-handlers ([exn:fail? (lambda (e) (log (list "in exn handler" (clock-current-seconds))))])
          (with-retry (exponential-backoff)
            (log (list "in body" (clock-current-seconds)))
            (error "oops"))))
    (list (void) '(("in body" 0) ("in body" 1) ("in body" 3) ("in exn handler" 3)) 3)))
  (test-case
   "instant success"
   (check-equal?
    (with-timing-and-logging
        (with-retry (exponential-backoff)
          'good))
    (list 'good '() 0)))
  (test-case
   "retry succeeds"
   (check-equal?
    (with-timing-and-logging
        (define tried? #f)
        (with-retry (exponential-backoff)
          (log (list "in body" (clock-current-seconds)))
          (unless tried?
              (set! tried? #t)
              (error "oops"))
          'good))
    (list 'good '(("in body" 0) ("in body" 1)) 1))))