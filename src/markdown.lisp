(defpackage #:quire/markdown
  (:use #:cl)
  (:export #:markdown->html))

(in-package #:quire/markdown)

(defun markdown->html (markdown)
  "Return the HTML fragment that MARKDOWN renders to.

Tables and fenced code blocks are enabled; fenced Lisp code is highlighted
with CSS classes by the code-blocks extension.

MARKDOWN: the Markdown source string."
  (check-type markdown string)
  (with-output-to-string (out)
    ;; The highlighter (colorize) prints progress chatter ("Scan was called N
    ;; times", a missing HyperSpec map) on *TRACE-OUTPUT*, which is the terminal
    ;; and would pollute the output of the command line.
    (let ((3bmd-tables:*tables* t)
          (3bmd-code-blocks:*code-blocks* t)
          (*trace-output* (make-broadcast-stream)))
      (3bmd:parse-string-and-print-to-stream markdown out))))
