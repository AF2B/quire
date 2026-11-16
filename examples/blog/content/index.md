---
(:layout :home
 :title "Home"
 :eyebrow "Common Lisp / TODO"
 :headline "Lisp, from the"
 :accent "inside."
 :cta ("Start here" . "/posts/restarts/"))
---

```
CL-USER> (macroexpand-1 '(when ready (launch)))
(IF READY (PROGN (LAUNCH)))
T
CL-USER> (mapcar #'1+ '(1 2 3))
(2 3 4)
```
