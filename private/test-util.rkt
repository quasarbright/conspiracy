#lang racket

(provide (all-defined-out))
(require "clock.rkt")

;; value logging to test order of events and side effects
(define current-logged-values-rev (make-parameter (list)))
(define (log v)
  (current-logged-values-rev (cons v (current-logged-values-rev))))
(define (get-log) (reverse (current-logged-values-rev)))

;; returns (list any (listof any) non-negative-real)
;; gives you the the result, logs (from (log v)), and how much time elapsed (in seconds)
(define-syntax-rule (with-timing-and-logging body ...)
  (parameterize ([current-logged-values-rev (list)])
    (with-mock-clock
      (define result (let () body ...))
      (list result (get-log) (clock-current-seconds)))))

;; inside the body, just use clock operations and they'll basically work without spending real time.
;; clock-current-seconds starts at 0.
;; clock-current-seconds only gets increased from clock-sleep.
;; clock-sleep does not actually sleep, it immediately returns.
;; with-timeout only times out based on clock-sleep time.
;; this does not track real time AT ALL, so a real http request will look like it takes 0 seconds
;; as far as the mock clock is concerned.
(define-syntax-rule (with-mock-clock body ...)
  (parameterize ([current-clock (new mock-clock%)])
    body ...))

;; fake clock that starts at zero and only advances on sleeps
;; so we don't have to do real sleeps in the test
(define mock-clock%
  (class* object% (clock<%>)
    (super-new)
    (define mock-seconds 0)
    (define current-timeout-time (make-parameter #f))
    (define/public (current-seconds) mock-seconds)
    (define/public (sleep secs)
      (set! mock-seconds (+ secs mock-seconds))
      (when (and (current-timeout-time) (> mock-seconds (current-timeout-time)))
        ;; the sleep timed out so we didn't get the whole sleep!
        (set! mock-seconds (current-timeout-time))
        (raise (exn:fail:conspiracy:timeout "mock timeout" (current-continuation-marks)))))
    (define/public (with-timeout timeout thnk)
      (define start-time mock-seconds)
      (parameterize ([current-timeout-time (+ start-time timeout)])
        (thnk)))))