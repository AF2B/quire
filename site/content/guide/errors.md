---
(:title "Errors"
 :description "The conditions quire signals and their restarts.")
---

quire signals typed conditions, all under `quire-error`, and offers restarts
where a decision is possible. The stack stays alive while you decide.

| Condition | Restarts |
|-----------|----------|
| `invalid-path` | `use-value` |
| `path-conflict` | `skip-page`; `keep-existing`, `replace-existing` for two pages at one path |
| `unknown-layout` | `use-value` |
| `front-matter-error`, `invalid-date` | none; the message names the file |
| `unsafe-output-directory` | none; `--clean` never deletes a directory quire did not create |

## Example

When two pages want the same output file, pick one:

```lisp
(handler-bind ((path-conflict
                 (lambda (condition)
                   (declare (ignore condition))
                   (invoke-restart 'keep-existing))))
  (merge-page-maps first second))
```

In the dev server, an unhandled error is shown in the browser. On the command
line it prints a message and exits with status 1.

Next: [command line](../cli/).
