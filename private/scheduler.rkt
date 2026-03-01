#lang racket

(module+ test (require rackunit "test-util.rkt"))
(provide (all-defined-out))
(require racket/control "clock.rkt")

(module+ main
  ;; only takes one second
  (with-scheduling
      (for ([i (in-range 10)])
        (schedule
         (displayln (format "hello from ~a" i))
         (wait-for 1)
         (displayln (format "goodbye from ~a" i))))))

;; A Task is one of
(struct hot-task [k waiting-until] #:transparent)
;; where
;; k is a continuation to resume the task
;; waiting-until is a timestamp for when to resume

;; TODO cold task once we have a notion of workflow

;; task pool
;; invariant: sorted by waiting-until ascending
(define current-pending-tasks (make-parameter (list)))

;; the body should be a bunch of uses of schedule.
;; runs body, which schedules tasks, then runs those tasks in "parallel".
;; this won't work well with actual parallelism, like having another thread
;; scheduling tasks.
(define-syntax-rule (with-scheduling body ...)
  (with-scheduling/proc (lambda () body ...)))

(define (with-scheduling/proc thnk)
  (reset
   (parameterize ([current-pending-tasks (list)])
     (begin0
       (thnk)
       (resume-tasks!)))))

;; adds the task to the pool, does not jump to the scheduler
(define-syntax-rule (schedule body ...)
  (schedule/proc (lambda () body ...)))
(define (schedule/proc thnk)
  ;; note: adding anything in the lambda after the prompt might break yield
  (define tsk (hot-task (lambda (_) (prompt (thnk))) (clock-current-seconds)))
  (enqueue-task! tsk))

;; wait for the given duration in seconds
(define (wait-for secs)
  (yield (+ secs (clock-current-seconds))))

;; wait until the given timestamp epoch, in seconds
(define (wait-until secs)
  (yield secs))

;; ends the current task and schedules a new one that will resume it.
;; gives other tasks a chance to run.
(define (yield [waiting-until (clock-current-seconds)])
  ;; this ends the task because control jumps out to the prompt from the schedule,
  ;; and there is nothing after that, so the initially scheduled thunk task ends.
  ;; scheduler will end up calling this k, which will just continue in the schedule body
  ;; like we never left, up to the end of the prompt in schedule.
  ;; This all assumes that nothing happens after the prompt in schedule.
  (shift k
         (let ([tsk (hot-task k waiting-until)])
           (enqueue-task! tsk))))

;; insert task into pool maintaining sorting by waiting-until.
;; assumes it's currently sorted
(define (enqueue-task! tsk)
  (current-pending-tasks
   (let loop ([tsks (current-pending-tasks)])
     (match tsks
       [(cons tsk^ tsks)
        #:when (< (hot-task-waiting-until tsk) (hot-task-waiting-until tsk^))
        (list* tsk tsk^ tsks)]
       [(cons tsk^ tsks)
        (cons tsk^ (loop tsks))]
       [(list) (list tsk)]))))

;; run the scheduler
(define (resume-tasks!)
  (unless (null? (current-pending-tasks))
    (define tsk (car (current-pending-tasks)))
    (current-pending-tasks (cdr (current-pending-tasks)))
    (define waiting-until (hot-task-waiting-until tsk))
    (when (< (clock-current-seconds) waiting-until)
      (clock-sleep (- waiting-until (clock-current-seconds))))
    ;; TODO error handling?
    ((hot-task-k tsk) (void))
    (resume-tasks!)))

(module+ test
  (test-case
   "wait in parallel"
  (check-equal?
    (with-timing-and-logging
      (with-scheduling
        (for ([i (in-range 3)])
          (schedule
           (log (list 'in i))
           (wait-for 1)
           (log (list 'out i))))))
    (list (void)
          '((in 0) (in 1) (in 2) (out 0) (out 1) (out 2))
          ;; only 1 second passes, not 3
          1)))
  (test-case 
   "longest-waiting task is first in line"
   (check-equal?
    (with-timing-and-logging
        (with-scheduling
          (schedule 
           ;; simulate slow task
           (clock-sleep 1)
           (log 'a)
           (yield) 
           (log 'c))
          (schedule (log 'b))))
    ;; b should happen before c since it's been waiting
    (list (void) '(a b c) 1)))
  (test-case 
   "multiple yields in a schedule"
   (check-equal?
    (with-timing-and-logging
      (with-scheduling
        (schedule
          (yield)
          (yield)
          (log 'ok))))
    (list (void)
          '(ok)
          0)))
  (test-case 
   "scheduling happens before any tasks run"
   (check-equal?
    (with-timing-and-logging
      (with-scheduling
        (log "before schedule")
        (schedule (log "in schedule"))
        (log "after schedule")))
    (list (void)
          '("before schedule" "after schedule" "in schedule")
          0)))
  (test-case
   "schedule returns void even if body has result"
   (check-equal?
    (with-timing-and-logging
      (with-scheduling
        (log (schedule 42))))
    (list (void)
          (list (void))
          0)))
  (test-case
   "operations do not work outside of with-scheduling"
   (check-exn
    #rx"scheduler not active"
    (lambda ()
      (prompt (yield))))
   (check-exn
    #rx"scheduler not active"
    (lambda ()
      (prompt (schedule 42))))))