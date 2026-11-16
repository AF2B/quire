---
(:title "REPL workflow"
 :description "Develop with the dev server running in your Lisp image.")
---

The dev server is a library, so you can start it from the REPL and keep
working in the same image.

```lisp
(asdf:load-system "quire/cli")            ; also loads the server and the theme
(load "examples/demo/site.lisp")

(defparameter *server*
  (quire/server:start-server (lambda () (quire:build-site quire:*site*))
                             :port 4000
                             :watch (quire:site-watched-directories
                                     quire:*site*)))

;; Edit and recompile a layout with C-c C-c, then nudge the open tabs:
(quire/server:reload-browsers *server*)

(quire/server:stop-server *server*)
```

## What happens

- Layouts run on every request, so a redefinition shows up without rebuilding.
- Content changes are noticed by a poller (every 0.5 s) and trigger a rebuild
  and a reload over server-sent events.
- A failed build is shown in the browser until you fix it.

From the command line, `quire serve` does the same without a REPL.

Next: [errors](../errors/).
