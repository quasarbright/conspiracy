#lang racket

;; Activities that yield to the scheduler.
;; Activities can have side effects and can use real sleeps instead of wait-for, like for retries.

(provide define-activity)
(module+ test (require rackunit "test-util.rkt"))
(require (for-syntax syntax/parse syntax/parse/lib/function-header)
         "scheduler.rkt")

;; TODO activities should yield between tries. just use wait-for in handler?

(define (wrap-activity proc)
  ;; TODO this doesn't lend itself to Promise.all for activities
  (make-keyword-procedure
    (lambda (kws kwargs . args)
      (yield)
      (define result (keyword-apply proc kws kwargs args))
      (yield)
      result)))

(define-syntax define-activity
  (syntax-parser
   [(_ f:id body:expr)
    #'(define f (wrap-activity body))]
   [(_ f:function-header body ...)
    #'(define f.name (procedure-rename (wrap-activity (let () (define f body ...) f.name)) 'f.name))]))

(module+ test
  (test-case
   "activity yields on enter and exit"
   (define-activity (inc x)
     (log (list 'start 'inc x))
     (wait-for 1)
     (log (list 'done 'inc x))
     (add1 x))
   
   (check-equal?
    (with-timing-and-logging
      (with-scheduling
        (schedule
          (log "start workflow 1")
          (log (list "workflow 1 received" (inc 1)))
          (log "end workflow 1"))
        (schedule
          (log "start workflow 2")
          (log (list "workflow 2 received" (inc 3)))
          (log "end workflow 2"))))
    (list (void) 
          ;; we jump between the two concurrent workflows as they yield
          '("start workflow 1"
            "start workflow 2"
            (start inc 1)
            (start inc 3)
            (done inc 1)
            (done inc 3)
            ("workflow 1 received" 2)
            "end workflow 1"
            ("workflow 2 received" 4)
            "end workflow 2")
          1))))