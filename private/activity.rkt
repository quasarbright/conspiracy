#lang racket

(provide (all-defined-out))

;; An Activity is a
(struct activity [name proc retry-config] #:transparent)