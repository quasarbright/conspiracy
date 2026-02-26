#lang racket

(provide (all-defined-out))

;; An Activity is a
(struct activity [name proc retry-config] #:transparent)

;; A RetryConfig is one of
(struct exponential-backoff [initial-delay-ms multiplier max-retries timeout-ms exn-retryable?] #:transparent)
;; where
;; initial-delay-ms a Natural
;;   how long (in milliseconds) to wait after the first try before retrying
;; multiplier is a NonNegativeReal
;;   after each retry, the delay gets multiplied by this value
;; max-retries is a Natural
;;   how many retries before giving up. e.g. for max-retries=1, it will try once,
;;   and then retry once, and then give up if that fails.
;; timeout-ms is a (Or #f Natural)
;;   if the operation takes longer than this amount (in milliseconds), consider it a failure.
;;   #f means no timeout.
;; exn-retryable? is a (Any -> Any)
;;   if the operation raises an exception, this procedure is used to determine
;;   whether to retry or give up. If (exn-retryable? e) returns #f, we don't retry anymore.