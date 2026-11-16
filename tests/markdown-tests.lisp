(defpackage #:quire/tests/markdown
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/markdown
                #:*render-cache*
                #:call-with-render-cache
                #:make-render-cache
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

(test raw-html5-elements-pass-through
  (let ((html (markdown->html
               (format nil "<details><summary>More</summary>text</details>~%~%~
                            <picture><source srcset=\"a.webp\"><img src=\"a.png\"></picture>~%"))))
    (is-true (contains-p "<details>" html))
    (is-true (contains-p "<summary>More</summary>" html))
    (is-true (contains-p "<picture>" html))))

(test non-string-input-is-a-type-error
  (signals type-error (markdown->html nil)))

(defun render-in-build (cache markdown)
  "Render MARKDOWN as one whole build that uses CACHE."
  (call-with-render-cache cache (lambda () (markdown->html markdown))))

(test unchanged-sources-are-reused-between-builds
  (let* ((cache (make-render-cache))
         (first-html (render-in-build cache "# One"))
         (second-html (render-in-build cache "# One")))
    (is (eq first-html second-html))
    (is (string= "<h1>One</h1>" (string-trim '(#\Newline) second-html)))))

(test without-a-cache-every-call-renders-again
  (is-false (eq (markdown->html "# One") (markdown->html "# One"))))

(test sources-no-longer-used-are-dropped-after-a-build
  (let* ((cache (make-render-cache))
         (original (render-in-build cache "# Old")))
    (render-in-build cache "# Other")
    (render-in-build cache "# Other")
    (let ((after-gap (render-in-build cache "# Old")))
      (is (string= original after-gap))
      (is-false (eq original after-gap)))))

(test a-failed-build-keeps-the-last-good-entries
  (let* ((cache (make-render-cache))
         (original (render-in-build cache "# Keep")))
    (ignore-errors
     (call-with-render-cache cache (lambda () (error "boom"))))
    (is (eq original (render-in-build cache "# Keep")))))

(test the-cache-is-off-outside-a-build
  (is (null *render-cache*)))

(test details-containers-wrap-rendered-markdown
  (let ((html (markdown->html (format nil "::: details Expansion~%some **bold**~%:::~%"))))
    (is-true (contains-p "<details class=\"exp\"><summary>Expansion</summary>"
                         html))
    (is-true (contains-p "<strong>bold</strong>" html))
    (is-true (contains-p "</details>" html))))

(test details-open-containers-start-expanded
  (is-true (contains-p "<details class=\"exp\" open>"
                       (markdown->html
                        (format nil "::: details-open T~%x~%:::~%")))))

(test other-containers-become-divs-with-their-kind-as-class
  (is-true (contains-p "<div class=\"note\">"
                       (markdown->html (format nil "::: note~%x~%:::~%")))))

(test container-titles-are-escaped
  (is-true (contains-p "<summary>a &lt;b&gt;</summary>"
                       (markdown->html
                        (format nil "::: details a <b>~%x~%:::~%")))))

(test container-fences-inside-code-blocks-stay-literal
  (let ((html (markdown->html
               (format nil "```~%::: details Hidden~%```~%"))))
    (is-false (contains-p "<details" html))
    (is-true (contains-p "Hidden" html))))

(test an-unclosed-container-ends-with-the-document
  (is-true (contains-p "</details>"
                       (markdown->html (format nil "::: details T~%body~%")))))

(test footnotes-become-numbered-links-and-a-list
  (let ((html (markdown->html
               (format nil "One[^a] two[^b] again[^a].~%~%[^a]: First.~%[^b]: Second *note*.~%"))))
    (is-true (contains-p "<sup class=\"fnref\"><a id=\"fnref-1\" href=\"#fn-1\">1</a></sup>"
                         html))
    (is-true (contains-p "<sup class=\"fnref\"><a id=\"fnref-2\" href=\"#fn-2\">2</a></sup>"
                         html))
    (is-true (contains-p "<sup class=\"fnref\"><a href=\"#fn-1\">1</a></sup>"
                         html))
    (is-true (contains-p "<ol class=\"footnotes\">" html))
    (is-true (contains-p "<li id=\"fn-2\">Second <em>note</em>." html))
    (is-false (contains-p "[^a]:" html))))

(test footnote-markers-in-code-and-without-definition-are-left-alone
  (let ((html (markdown->html
               (format nil "Code `[^a]` and [^missing] and real[^a].~%~%[^a]: Note.~%"))))
    (is-true (contains-p "<code>[^a]</code>" html))
    (is-true (contains-p "[^missing]" html))
    (is-true (contains-p "<li id=\"fn-1\">Note." html))))

(test a-definition-nobody-references-draws-no-list
  (is-false (contains-p "footnotes"
                        (markdown->html (format nil "Text.~%~%[^a]: Unused.~%")))))
