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

## Requirements

P0
- workflows
- activities
  - retries
  - caching
- can be running multiple workflows at once. scheduler for swapping, maybe proper parallelism
- long-term, non-blocking sleeps
- persist state to file system for crash-safety
- hot and cold replay

P0

P1
- child workflow
- signals
- queries
- updates
- conditions (only makes sense once you have signals)
- describe execution, execution history, stdout

P2
- UI dashboard
- code changes, versioning
- flow chart static view

## Questions

- When should we yield?
  - on sleep/wait
  - while waiting between retries of an activity
  - maybe before an activity actually runs? to give other stuff a chance
  - while waiting for an activity to resolve? would need parallelism, but then you aren't really yielding