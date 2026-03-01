#lang racket

(provide (all-defined-out))
(module+ test (require rackunit "test-util.rkt"))
(require (for-syntax syntax/parse syntax/parse/lib/function-header)
         "scheduler.rkt")

;; TODO more dynamic scheduling
#|
to support new tasks coming in dynamically,
the scheduler is going to have to be more flexible and "live".
right now, we schedule all the tasks and then run the scheduler loop until they're done.
going to need multi threading

when someone wants to schedule a task:
  if there are no tasks, then enqueue and try to run.
  if it's running a task, then just enqueue and it'll get to it later.
  if there are tasks, but they aren't ready, then check if the new thing is ready and work on it if it is.
    need to interrupt the sleep, or fundamentally redesign how waiting works. will break mock clock tests lol.
    idea: in sleep state, have a known thread for the sleep that can be killed if something new comes in.
    it might end up being re-created if the new thing isn't ready, and that's fine

this may affect the workflow wrapper
|#

(define worker%
  (class object%
    (super-new)
    ))