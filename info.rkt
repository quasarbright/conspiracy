#lang info
(define collection "conspiracy")
(define deps '("base"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/conspiracy.scrbl" ())))
(define pkg-desc "workflow orchestrator like temporal.io")
(define version "0.0")
(define pkg-authors '(mdelmonaco))
(define license '(Apache-2.0 OR MIT))
