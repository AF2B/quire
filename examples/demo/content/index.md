---
(:title "Home"
 :layout :home
 :description "A static site generator in Common Lisp.")
---

quire turns a folder of Markdown into a site. Content is **data**, pages are
**functions**, and the REPL is the dev server: redefine a layout and the
browser reloads.

```lisp
(defun post-layout (page site pages)
  (shell-html page site pages (render-post page)))
```

Read the [posts](/posts/) to see how it works.
