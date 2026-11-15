---
(:title "Conditions and restarts"
 :date "2026-11-12"
 :tags ("lisp" "errors")
 :description "Two pages at one path are a conflict you can resolve, not a crash.")
---

When two pages want the same output file, quire signals `path-conflict`. The
handler can pick a restart:

```lisp
(handler-bind ((path-conflict
                 (lambda (condition)
                   (declare (ignore condition))
                   (invoke-restart 'keep-existing))))
  (merge-page-maps first second))
```

`skip-page`, `keep-existing` and `replace-existing` leave the decision to the
caller, with the stack still alive. This is the condition system doing a job
that most languages answer with an exception.
