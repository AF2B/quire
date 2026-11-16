(defpackage #:quire/markdown
  (:use #:cl)
  (:export #:*render-cache*
           #:call-with-render-cache
           #:make-render-cache
           #:markdown->html))

(in-package #:quire/markdown)

(defvar *render-cache* nil
  "When non-NIL, a RENDER-CACHE that MARKDOWN->HTML reads and fills.")

(defstruct (render-cache (:constructor make-render-cache ()))
  "Rendered Markdown remembered between builds, keyed by its source text.

Two generations: a build looks in both and stores into the current one, and
the generations rotate when the build ends, so a source that is no longer used
disappears after one more build."
  (previous (make-hash-table :test 'equal) :type hash-table)
  (current (make-hash-table :test 'equal) :type hash-table))

(defun cached-render (cache markdown)
  "Return the cached HTML of MARKDOWN in CACHE, rendering it on a miss.

CACHE: a RENDER-CACHE.
MARKDOWN: the Markdown source string."
  (let ((html (or (gethash markdown (render-cache-current cache))
                  (gethash markdown (render-cache-previous cache))
                  (render-markdown markdown))))
    (setf (gethash markdown (render-cache-current cache)) html)))

(defun rotate-render-cache (cache)
  "Drop the entries CACHE did not use since the last rotation.

CACHE: a RENDER-CACHE."
  (setf (render-cache-previous cache) (render-cache-current cache)
        (render-cache-current cache) (make-hash-table :test 'equal)))

(defun call-with-render-cache (cache function)
  "Call FUNCTION with *RENDER-CACHE* bound to CACHE, then rotate CACHE.

Rotation happens only when FUNCTION returns normally, so a failed build keeps
the entries of the last good one. Returns the values of FUNCTION.

CACHE: a RENDER-CACHE.
FUNCTION: a function of no arguments, usually one build."
  (let ((*render-cache* cache))
    (multiple-value-prog1 (funcall function)
      (rotate-render-cache cache))))

(defun markdown->html (markdown)
  "Return the HTML fragment that MARKDOWN renders to.

Tables and fenced code blocks are enabled; fenced Lisp code is highlighted
with CSS classes by the code-blocks extension. Inside CALL-WITH-RENDER-CACHE the
result of an unchanged source is reused.

MARKDOWN: the Markdown source string."
  (check-type markdown string)
  (if *render-cache*
      (cached-render *render-cache* markdown)
      (render-markdown markdown)))

(defun render-markdown (markdown)
  "Render MARKDOWN to an HTML string, without any cache.

MARKDOWN: the Markdown source string."
  (with-output-to-string (out)
    ;; The highlighter (colorize) prints progress chatter ("Scan was called N
    ;; times", a missing HyperSpec map) on *TRACE-OUTPUT*, which is the terminal
    ;; and would pollute the output of the command line.
    (let ((3bmd-tables:*tables* t)
          (3bmd-code-blocks:*code-blocks* t)
          (*trace-output* (make-broadcast-stream)))
      (3bmd:parse-string-and-print-to-stream markdown out))))
