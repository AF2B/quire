(defpackage #:quire/tests/markdown
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/markdown
                #:markdown->html)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/markdown)

(def-suite markdown-suite
  :description "Markdown rendering."
  :in quire-suite)

(in-suite markdown-suite)

(defun contains-p (needle haystack)
  "Return true when HAYSTACK contains NEEDLE."
  (and (search needle haystack) t))

(test headings-and-emphasis-render
  (let ((html (markdown->html (format nil "# Title~%~%Some *emphasis* here~%"))))
    (is-true (contains-p "<h1>Title</h1>" html))
    (is-true (contains-p "<em>emphasis</em>" html))))

(test ampersands-are-escaped
  (is-true (contains-p "a &amp; b" (markdown->html "a & b"))))

(test fenced-code-without-language-is-escaped
  (let ((html (markdown->html (format nil "```~%a<b~%```~%"))))
    (is-true (contains-p "<pre><code>a&lt;b</code></pre>" html))))

(test fenced-lisp-code-is-highlighted
  (let ((html (markdown->html (format nil "```lisp~%(defun f (x) x)~%```~%"))))
    (is-true (contains-p "<pre><code>" html))
    (is-true (contains-p "class=\"symbol\"" html))))

(test pipe-tables-render
  (let ((html (markdown->html (format nil "| a | b |~%|---|---|~%| 1 | 2 |~%"))))
    (is-true (contains-p "<table" html))))

(test non-string-input-is-a-type-error
  (signals type-error (markdown->html nil)))
