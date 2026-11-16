---
(:title "Restarts: the half of error handling nobody teaches"
 :date "2026-11-09"
 :tags ("common-lisp" "conditions")
 :series "The condition system, end to end"
 :part 2
 :series-total 4
 :featured t
 :kicker "Condition system"
 :description "Most languages give you one tool for failure: unwind until someone catches. Common Lisp lets the code that knows how to recover stay apart from the code that knows which recovery to pick.")
---

## Two halves of a failure

An exception answers one question: who catches this? The condition system asks
two. Who decides what to do, and who knows how to do it? Those are rarely the
same piece of code, and the stack stays intact while they talk.

quire meets this when two files map to the same URL. The build signals
`path-conflict` and offers two ways out. Nothing unwinds until a caller picks
one.[^1]

## A restart you can invoke

```lisp
(define-condition path-conflict (error)
  ((path :initarg :path :reader conflict-path)))

(handler-bind ((path-conflict
                 (lambda (c)
                   (declare (ignore c))
                   (invoke-restart 'use-last))))
  (restart-case (error 'path-conflict :path "/about/")
    (use-first () :first)
    (use-last  () :last)))
;; => :LAST
```

The handler runs before the stack unwinds, so the `restart-case` frame is still
alive and `invoke-restart` can reach it. That is the whole trick.

## Reading the expansion

::: details-open macroexpand-1 / with-use-last
```lisp
(defmacro with-use-last (&body body)
  `(handler-bind ((path-conflict
                    (lambda (c)
                      (declare (ignore c))
                      (invoke-restart 'use-last))))
     ,@body))

(macroexpand-1 '(with-use-last (build)))
;; => (HANDLER-BIND ((PATH-CONFLICT
;;                    (LAMBDA (C)
;;                      (DECLARE (IGNORE C))
;;                      (INVOKE-RESTART 'USE-LAST))))
;;      (BUILD))
```
:::

If you cannot read the expansion, you do not own the macro yet.

## Sources

1. [Common Lisp HyperSpec, 9.1 Condition System Concepts](http://www.lispworks.com/documentation/HyperSpec/Body/09_a.htm)
2. Peter Seibel, [Practical Common Lisp, ch. 19](https://gigamonkeys.com/book/beyond-exception-handling-conditions-and-restarts.html)
3. Kent Pitman, [Condition Handling in the Lisp Language Family](http://www.nhplace.com/kent/Papers/Condition-Handling-2001.html) (2001)

[^1]: See `path-conflict` and its restarts in the quire source.
