---
(:title "Pages are functions"
 :date "2026-11-10"
 :tags ("design" "lisp")
 :description "A page body can be a function, resolved only when needed.")
---

A page body is a string, a vector of bytes, or a **function of the page**.
Layouts are wrapped in functions, so a build only reads content and wires pages
together. The HTML is produced when the page is written or served.

```lisp
(make-page :path "/hello/"
           :body (lambda (page)
                   (format nil "<h1>~A</h1>" (page-path page))))
;; => #<PAGE "/hello/">
```

That is why redefining a layout at the REPL takes effect on the next request:
the function is looked up again every time it runs.
