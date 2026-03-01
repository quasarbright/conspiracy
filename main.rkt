#lang racket

(module+ test (require rackunit))
(require "private/scheduler.rkt")

;; example of the sort of thing we're building towards
#;
(begin
  (define/workflow (process-data data)
    (notify-subscribers)
    ;; special operation that yields
    (wait-until (+ now 1000))
    "success")
  (define/activity (notify-subscribers)
    #:retry "wait 1 second, 2 tries"
    ;; regular racket sleep to simulate network
    (sleep/racket 1000)
    (displayln "notified")))