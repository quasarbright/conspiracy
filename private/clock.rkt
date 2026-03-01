#lang racket

;; mockable time operations

(provide clock-current-seconds
         clock-sleep
         with-timeout
         (struct-out exn:fail:conspiracy:timeout)
         current-clock
         clock<%>)
(require racket/sandbox)

(define (clock-current-seconds)
  (send (current-clock) current-seconds))

(define (clock-sleep secs)
  (send (current-clock) sleep secs))

(struct exn:fail:conspiracy:timeout exn:fail [])
(define-syntax-rule (with-timeout timeout body ...)
  (send (current-clock) with-timeout timeout (lambda () body ...)))

;; we define an interface so we can create a mock clock for testing
(define clock<%>
  (interface ()
    current-seconds
    sleep
    ;; NonNegativeReal (-> any) -> any
    ;; timeout in seconds
    ;; raises exn:fail:resource?
    with-timeout))

(define real-current-seconds current-seconds)
(define real-sleep sleep)
(define real-clock%
  (class* object% (clock<%>)
    (super-new)
    (define/public (current-seconds) (real-current-seconds))
    (define/public (sleep secs) (real-sleep secs))
    (define/public (with-timeout timeout thnk)
      (with-handlers ([exn:fail:resource? (lambda (e) (raise (exn:fail:conspiracy:timeout (format "timed out after ~a seconds" timeout) (exn-continuation-marks e))))])
        (with-limits timeout #f (lambda () (thnk)))))))

(define current-clock (make-parameter (new real-clock%)))