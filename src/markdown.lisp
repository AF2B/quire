(defpackage #:quire/markdown
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/front-matter
                #:join-lines
                #:split-lines)
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

(define-constant +code-fence+ "```"
  :test #'string=
  :documentation "Line prefix that opens and closes a fenced code block.")

(define-constant +container-fence+ ":::"
  :test #'string=
  :documentation "Prefix of the lines that open and close a container.")

(define-constant +details-kind+ "details"
  :test #'string=
  :documentation "Container kind rendered as a collapsed details element.")

(define-constant +details-open-kind+ "details-open"
  :test #'string=
  :documentation "Container kind rendered as an expanded details element.")

(define-constant +footnote-marker+ "[^"
  :test #'string=
  :documentation "Start of a footnote reference or definition.")

(define-constant +footnote-back-link+ "↩"
  :test #'string=
  :documentation "Text of the link from a footnote back to its reference.")

(defun markdown->html (markdown)
  "Return the HTML fragment that MARKDOWN renders to.

Tables, fenced code blocks, containers and footnotes are enabled; fenced Lisp
code is highlighted with CSS classes by the code-blocks extension. Inside
CALL-WITH-RENDER-CACHE the result of an unchanged source is reused.

MARKDOWN: the Markdown source string."
  (check-type markdown string)
  (if *render-cache*
      (cached-render *render-cache* markdown)
      (render-markdown markdown)))

(defun render-plain (markdown)
  "Render MARKDOWN with 3bmd alone, without containers or footnotes.

MARKDOWN: the Markdown source string."
  (with-output-to-string (out)
    ;; The highlighter (colorize) prints progress chatter ("Scan was called N
    ;; times", a missing HyperSpec map) on *TRACE-OUTPUT*, which is the terminal
    ;; and would pollute the output of the command line.
    (let ((3bmd-tables:*tables* t)
          (3bmd-code-blocks:*code-blocks* t)
          (*trace-output* (make-broadcast-stream)))
      (3bmd:parse-string-and-print-to-stream markdown out))))

(defun escape-html (text)
  "Return TEXT with the characters that HTML reserves written as references.

TEXT: the string to escape."
  (with-output-to-string (out)
    (loop for character across text
          do (case character
               (#\& (write-string "&amp;" out))
               (#\< (write-string "&lt;" out))
               (#\> (write-string "&gt;" out))
               (#\" (write-string "&quot;" out))
               (t (write-char character out))))))

(defun starts-with-p (prefix text)
  "Return true when TEXT begins with PREFIX.

PREFIX: the string to look for.
TEXT: the string to inspect."
  (and (>= (length text) (length prefix))
       (string= prefix text :end2 (length prefix))))

(defun code-fence-line-p (line)
  "Return true when LINE opens or closes a fenced code block.

LINE: one line of Markdown."
  (starts-with-p +code-fence+ (string-left-trim " " line)))

;;; Containers: ::: kind title ... :::

(defun container-kind-p (kind)
  "Return true when KIND is a word of letters, digits and hyphens.

KIND: the string after the opening fence of a container."
  (and (plusp (length kind))
       (every (lambda (character)
                (or (alphanumericp character) (char= character #\-)))
              kind)))

(defun container-opening (line)
  "Return the kind and the title of the container that LINE opens, or NIL.

A container opens with ::: , a kind and an optional title.

LINE: one line of Markdown."
  (let ((prefix (concatenate 'string +container-fence+ " ")))
    (when (starts-with-p prefix line)
      (let* ((rest (string-trim " " (subseq line (length prefix))))
             (space (position #\Space rest))
             (kind (subseq rest 0 space))
             (title (if space (string-trim " " (subseq rest space)) "")))
        (when (container-kind-p kind)
          (values kind title))))))

(defun container-closing-p (line)
  "Return true when LINE closes a container.

LINE: one line of Markdown."
  (string= +container-fence+ (string-trim " " line)))

(defun split-containers (markdown)
  "Split MARKDOWN into segments, outside fenced code.

A segment is (:MARKDOWN TEXT) or (:CONTAINER KIND TITLE TEXT). A container left
open at the end of the text is closed there.

MARKDOWN: the Markdown source string."
  (let ((segments '())
        (buffer '())
        (open nil)
        (inside-code nil))
    (flet ((flush ()
             (let ((text (join-lines (reverse buffer))))
               (cond (open
                      (push (list :container (car open) (cdr open) text)
                            segments))
                     ((plusp (length (string-trim '(#\Space #\Newline) text)))
                      (push (list :markdown text) segments))))
             (setf buffer '())))
      (dolist (line (split-lines markdown))
        (cond ((code-fence-line-p line)
               (setf inside-code (not inside-code))
               (push line buffer))
              (inside-code
               (push line buffer))
              ((and (null open) (container-opening line))
               (flush)
               (multiple-value-bind (kind title) (container-opening line)
                 (setf open (cons kind title))))
              ((and open (container-closing-p line))
               (flush)
               (setf open nil))
              (t (push line buffer))))
      (flush))
    (nreverse segments)))

(defun render-container (kind title text)
  "Return the HTML of a container.

The kinds details and details-open make a details element whose summary is
TITLE; any other kind makes a div with that class.

KIND: the container kind.
TITLE: the text after the kind on the opening line.
TEXT: the Markdown inside the container."
  (let ((inner (render-plain text)))
    (cond ((or (string= kind +details-kind+)
               (string= kind +details-open-kind+))
           (format nil "<details class=\"exp\"~A><summary>~A</summary>~%~A</details>~%"
                   (if (string= kind +details-open-kind+) " open" "")
                   (escape-html title)
                   inner))
          (t (format nil "<div class=\"~A\">~%~A</div>~%" kind inner)))))

(defun render-segments (markdown)
  "Return the HTML of MARKDOWN with its containers rendered.

MARKDOWN: the Markdown source string."
  (with-output-to-string (out)
    (dolist (segment (split-containers markdown))
      (write-string (if (eq :markdown (first segment))
                        (render-plain (second segment))
                        (render-container (second segment)
                                          (third segment)
                                          (fourth segment)))
                    out))))

;;; Footnotes: [^id] and [^id]: text

(defun footnote-definition (line)
  "Return the id and the text of the footnote that LINE defines, or NIL.

LINE: one line of Markdown, such as \"[^1]: The source.\"."
  (when (starts-with-p +footnote-marker+ line)
    (let ((close (search "]:" line)))
      (when (and close (> close (length +footnote-marker+)))
        (let ((id (subseq line (length +footnote-marker+) close)))
          (unless (find #\Space id)
            (values id (string-trim " " (subseq line (+ close 2))))))))))

(defun inside-code-span-p (line position)
  "Return true when POSITION in LINE falls between two backticks.

LINE: one line of Markdown.
POSITION: an index into LINE."
  (oddp (count #\` line :end position)))

(defun footnote-reference-html (number first-p)
  "Return the superscript link to footnote NUMBER.

NUMBER: the footnote number.
FIRST-P: true for the first reference, which carries the id that the footnote
  links back to."
  (format nil "<sup class=\"fnref\"><a ~Ahref=\"#fn-~D\">~D</a></sup>"
          (if first-p (format nil "id=\"fnref-~D\" " number) "")
          number
          number))

(defun replace-footnote-references (line definitions numbers)
  "Return LINE with each [^id] that has a definition turned into a link.

LINE: one line of Markdown.
DEFINITIONS: hash table of footnote id to text.
NUMBERS: hash table of footnote id to number, filled as ids are first seen."
  (with-output-to-string (out)
    (loop with position = 0
          for start = (search +footnote-marker+ line :start2 position)
          for close = (and start (position #\] line :start start))
          for id = (and close
                        (subseq line (+ start (length +footnote-marker+)) close))
          do (write-string line out :start position :end start)
          while start
          do (cond ((and id
                         (gethash id definitions)
                         (not (inside-code-span-p line start)))
                    (let ((known (gethash id numbers)))
                      (if known
                          (write-string (footnote-reference-html known nil)
                                        out)
                          (let ((number (1+ (hash-table-count numbers))))
                            (setf (gethash id numbers) number)
                            (write-string (footnote-reference-html number t)
                                          out))))
                    (setf position (1+ close)))
                   (t (write-string +footnote-marker+ out)
                      (setf position (+ start (length +footnote-marker+))))))))

(defun inline-html (markdown)
  "Return MARKDOWN rendered without the paragraph that wraps a single line.

MARKDOWN: a Markdown fragment of one paragraph."
  (let ((html (string-trim '(#\Newline #\Space) (render-plain markdown))))
    (if (and (starts-with-p "<p>" html)
             (>= (length html) 7)
             (string= "</p>" html :start2 (- (length html) 4)))
        (subseq html 3 (- (length html) 4))
        html)))

(defun footnotes-html (definitions numbers)
  "Return the ordered list of the footnotes that were referenced.

DEFINITIONS: hash table of footnote id to text.
NUMBERS: hash table of footnote id to number."
  (let ((entries '()))
    (maphash (lambda (id number) (push (cons number id) entries)) numbers)
    (with-output-to-string (out)
      (format out "<ol class=\"footnotes\">~%")
      (dolist (entry (sort entries #'< :key #'car))
        (format out "<li id=\"fn-~D\">~A <a class=\"fnback\" href=\"#fnref-~D\" ~
                     aria-label=\"Back to the text\">~A</a></li>~%"
                (car entry)
                (inline-html (gethash (cdr entry) definitions))
                (car entry)
                +footnote-back-link+))
      (format out "</ol>~%"))))

(defun extract-footnotes (markdown)
  "Return MARKDOWN without footnote definitions, and the footnote list.

Returns two values: the Markdown, whose references are already links, and the
HTML of the list of footnotes, or NIL when the text references none. Lines
inside fenced code are left alone.

MARKDOWN: the Markdown source string."
  (let ((definitions (make-hash-table :test 'equal))
        (numbers (make-hash-table :test 'equal))
        (kept '())
        (inside-code nil))
    (dolist (line (split-lines markdown))
      (when (code-fence-line-p line)
        (setf inside-code (not inside-code)))
      (multiple-value-bind (id text) (and (not inside-code)
                                          (footnote-definition line))
        (if id
            (setf (gethash id definitions) text)
            (push line kept))))
    (if (zerop (hash-table-count definitions))
        (values markdown nil)
        (let ((inside-code nil)
              (lines '()))
          (dolist (line (nreverse kept))
            (when (code-fence-line-p line)
              (setf inside-code (not inside-code)))
            (push (if inside-code
                      line
                      (replace-footnote-references line definitions numbers))
                  lines))
          (values (join-lines (nreverse lines))
                  (when (plusp (hash-table-count numbers))
                    (footnotes-html definitions numbers)))))))

(defun render-markdown (markdown)
  "Render MARKDOWN to an HTML string, without any cache.

Containers (::: kind title ... :::) become details elements or divs, and
footnotes ([^id] and [^id]: text) become numbered links plus a list at the end.

MARKDOWN: the Markdown source string."
  (multiple-value-bind (text footnotes) (extract-footnotes markdown)
    (concatenate 'string
                 (render-segments text)
                 (or footnotes ""))))
