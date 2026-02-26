#lang racket

;; starting from the scheduler and building on top of that.
;;; left off about to write some tests and start doing hot workflow/activity (just retries on activities that uses wait-for for delays)

(require racket/control)

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
;; run a bunch in "parallel"

(module+ main
  ;; does not take 10 seconds
  (with-scheduling
      (for ([i (in-range 10)])
        (schedule
         (displayln (format "hello from ~a" i))
         (wait-for 1)
         (displayln (format "goodbye from ~a" i))))))

#|
TODO tests

parallelism happens while tasks are sleeping
  ;; does not take 10 seconds
  (with-scheduling
    (for ([i (in-range 10)])
      (schedule
       (displayln (format "hello from ~a" i))
       (wait-for 1)
       (displayln (format "goodbye from ~a" i))))

queue task A now. queue task B for 1 second from now.
task A takes 2 seconds (using real sleep) and then yields, queueing task C.
task B should run before C since its waiting-until is in the past by 1 second
|#

;; A Task is one of
(struct hot-task [k waiting-until] #:transparent)
;; where
;; k is a continuation to resume the task
;; waiting-until is a timestamp for when to resume

;; TODO cold task once we have a notion of workflow

;; task pool
;; invariant: sorted by waiting-until ascending
(define pending-tasks (list))
;; TODO parameter

;; the body should be a bunch of uses of schedule.
;; runs body, which schedules tasks, then runs those tasks in "parallel".
;; this won't work well with actual parallelism, like having another thread
;; scheduling tasks.
(define-syntax-rule (with-scheduling body ...)
  (with-scheduling/proc (lambda () body ...)))

(define (with-scheduling/proc thnk)
  (reset
   (set! pending-tasks (list))
   (thnk)
   (resume-tasks!)))

;; adds the task to the pool, does not jump to the scheduler
(define-syntax-rule (schedule body ...)
  (schedule/proc (lambda () body ...)))
(define (schedule/proc thnk)
  ;; note: adding anything in the lambda after the prompt might break yield
  (define tsk (hot-task (lambda (_) (prompt (thnk))) (current-seconds)))
  (enqueue-task! tsk))

;; wait for the given duration in seconds
(define (wait-for secs)
  (yield (+ secs (current-seconds))))

;; wait until the given timestamp epoch, in seconds
(define (wait-until secs)
  (yield secs))

;; ends the current task and schedules a new one that will resume it.
;; gives other tasks a chance to run.
(define (yield [waiting-until (current-seconds)])
  ;; this ends the task because control jumps out to the prompt from the schedule,
  ;; and there is nothing after that, so the initially scheduled thunk task ends.
  ;; scheduler will end up calling this k, which will just continue in the schedule body
  ;; like we never left, up to the end of the prompt in schedule.
  ;; This all assumes that nothing happens after the prompt in schedule.
  (control k
           (let ([tsk (hot-task k waiting-until)])
             (enqueue-task! tsk))))

;; insert task into pool maintaining sorting by waiting-until.
;; assumes it's currently sorted
(define (enqueue-task! tsk)
  (set! pending-tasks
        (let loop ([tsks pending-tasks])
          (match tsks
            [(cons tsk^ tsks)
             #:when (< (hot-task-waiting-until tsk) (hot-task-waiting-until tsk^))
             (list* tsk tsk^ tsks)]
            [(cons tsk^ tsks)
             (cons tsk^ (loop tsks))]
            [(list) (list tsk)]))))

;; run the scheduler
(define (resume-tasks!)
  (cond
    [(null? pending-tasks)
     (displayln "done")]
    [else
     (displayln "not done")
     (define tsk (car pending-tasks))
     (set! pending-tasks (cdr pending-tasks))
     (define waiting-until (hot-task-waiting-until tsk))
     (when (< (current-seconds) waiting-until)
       (sleep (- waiting-until (current-seconds))))
     ;; TODO error handling?
     ((hot-task-k tsk) (void))
     (resume-tasks!)]))