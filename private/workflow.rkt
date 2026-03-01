#lang racket

(provide (all-defined-out))
(module+ test (require rackunit "test-util.rkt"))
(require (for-syntax syntax/parse syntax/parse/lib/function-header)
         "scheduler.rkt")

(define (wrap-workflow proc)
  (make-keyword-procedure
    (lambda (kws kwargs . args)
      (schedule
        (keyword-apply proc kws kwargs args)))))

(define-syntax define-workflow
  (syntax-parser
   [(_ f:id body:expr)
    #'(define f (wrap-workflow body))]
   [(_ f:function-header body ...)
    #'(define f.name (procedure-rename (wrap-workflow (let () (define f body ...) f.name)) 'f.name))]))