## Example

```racket
(begin
  (module+ main
    ;; server 
    (define worker (create-worker (list process-application)))
    (serve-worker worker))

  (define/workflow (process-application application)
    ;; invoke child workflow
    (define data (fetch-data application))

    ;; pure deterministic logic
    (define result
      (if (or (is-fraud? data)
              (bad-history? data))
          "reject"
          "approve") )
    
    ;; invoke child workflow
    (process-result result))

  (define/workflow (fetch-data application)
    ;; invoke activities
    (define fraud-data (fetch-fraud-data application))
    (define historical-data (fetch-historical-data application))
    ;; pure deterministic logic
    (hash 'fraud-data fraud-data
          'historical data historical-data))
  ...

  (define/activity (fetch-fraud-data application)
    #:retry-behavior (...)
    ;; effectful code
    (http-get ...))

  ;; this would be in the library, included for explanatory purposes
  (define (serve-worker worker)
    (let loop ()
      (define-values (workflow-name workflow-args) (receive-workflow-request worker))
      (start-workflow worker workflow-args workflow-args)
      (loop))))
```

## Rules

- workflow code must be pure and deterministic
  - if we re-run a workflow using cached activity results, the exact same sequence of activity calls must occur. this guarantees the validity of activity-cached replays
  - local variable mutation is allowed in workflow code, but not global mutable variables. bc local variable mutation gets replayed fine on a replay
  - activities and child workflows must not mutate parent workflow variables/values since this mutation wouldn't happen when using a cached result for the activity
- activities' inputs and outputs must be serializable and comparable with equal? in a way that respects serialize->deserialize round trip. so `(equal? v (deserialize (serialize v)))` must hold. this is necessary for caching
- workflow code should be lightweight bc it may run on lower-resource hardware: low memory, slow CPU.
  - don't use racket sleep in workflow code since it'll block. use yielding sleep instead. it's ok in activities though.
  - activities would run on high-resource hardware. for intense computation, use activities

## Requirements

P0
- workflows
- activities
  - retries
  - caching for cold replay
- can be running multiple workflows at once. scheduler for swapping
- long-term, non-blocking sleeps
- persist state to file system for crash-safety
- "parallel" activity execution like promise.all
  - just schedules a bunch of activities at once
- hot and cold replay

P1
- child workflow
- signals
  - in the hot case, a signal cannot be handled while the pure workflow code is running bc both may mutate the same local variables.
  - for an execution, workflow code should have a lock. it should be impossible for multiple threads/places to be running workflow code on the same execution bc of this local mutable variable race condition
  - but it's fine to handle a signal while an activity is running(?)
- queries
- updates
- conditions (only makes sense once you have signals)
- describe execution, execution history, stdout
- proper parallelism. at least threads, maybe places. continuations can't move between places, so have to use cold path when resuming in another place

P2
- UI dashboard
- code changes, versioning
- flow chart static view

## Questions

- When should we yield?
  - on sleep/wait
  - while waiting between retries of an activity
  - before an activity runs
  - when an activity finishes. need to make sure continuations and scheduling are set up so the result of the activity makes its way back into the workflow