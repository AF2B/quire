(defpackage #:quire/paths
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/conditions
                #:invalid-path)
  (:export #:+path-separator+
           #:+index-file-name+
           #:parse-path
           #:path-directory-p
           #:path->output-path))

(in-package #:quire/paths)

(defconstant +path-separator+ #\/
  "Separator between the segments of a URL path.")

(defconstant +extension-separator+ #\.
  "Separator between a file name and its extension.")

(define-constant +index-file-name+ "index.html"
  :test #'string=
  :documentation "File written for a directory path.")

(define-constant +extensionless-file-names+ '("CNAME" "LICENSE")
  :test #'equal
  :documentation "Well-known file names that are valid file paths without an
extension. Any other name without an extension is ambiguous with a directory
and is rejected.")

(define-constant +current-segment+ "."
  :test #'string=
  :documentation "Path segment that means the current directory.")

(define-constant +parent-segment+ ".."
  :test #'string=
  :documentation "Path segment that means the parent directory.")

(define-constant +forbidden-characters+ "?#\\"
  :test #'string=
  :documentation "Printable characters that never appear in a site path.")

(defconstant +first-printable-code+ 32
  "Character codes below this value are control characters.")

(defconstant +delete-code+ 127
  "Character code of DEL, a control character above the printable range.")

(defun illegal-character-p (character)
  "Return true when CHARACTER may not appear in a site path.

CHARACTER: the character to test."
  (let ((code (char-code character)))
    (or (< code +first-printable-code+)
        (= code +delete-code+)
        (find character +forbidden-characters+))))

(defun split-segments (path)
  "Return the substrings of PATH between separators, keeping empty ones.

PATH: a string; \"/a/b/\" yields (\"\" \"a\" \"b\" \"\")."
  (loop with start = 0
        for end = (position +path-separator+ path :start start)
        collect (subseq path start end)
        while end
        do (setf start (1+ end))))

(defun path-directory-p (path)
  "Return true when PATH names a directory, that is, ends with a separator.

PATH: a string."
  (let ((length (length path)))
    (and (plusp length)
         (char= +path-separator+ (char path (1- length))))))

(defun has-extension-p (file-name)
  "Return true when FILE-NAME has a non-empty extension after its last dot.

FILE-NAME: a path segment; \".nojekyll\" counts, \"a.\" and \"a\" do not."
  (let ((dot (position +extension-separator+ file-name :from-end t)))
    (and dot
         (< dot (1- (length file-name))))))

(defun directory-segments (path)
  "Return the segments of PATH after the leading separator.

A trailing separator does not produce a final empty segment.

PATH: a string that starts with a separator."
  (let ((segments (rest (split-segments path))))
    (if (path-directory-p path)
        (butlast segments)
        segments)))

(defun bad-segment-p (segment)
  "Return true when SEGMENT is empty, \".\" or \"..\".

SEGMENT: one path segment."
  (or (zerop (length segment))
      (string= segment +current-segment+)
      (string= segment +parent-segment+)))

(defun path-violation (path)
  "Return the keyword naming the first rule PATH breaks, or NIL when valid.

PATH: a string."
  (cond ((zerop (length path))
         :empty)
        ((char/= +path-separator+ (char path 0))
         :not-absolute)
        ((find-if #'illegal-character-p path)
         :illegal-character)
        (t
         (let ((segments (directory-segments path)))
           (cond ((some #'bad-segment-p segments)
                  :bad-segment)
                 ((and (not (path-directory-p path))
                       (not (has-extension-p (first (last segments))))
                       (not (member (first (last segments))
                                    +extensionless-file-names+
                                    :test #'string=)))
                  :missing-extension))))))

(defun parse-path (path)
  "Return PATH when it is a valid site URL path, else signal INVALID-PATH.

A valid path starts with a slash, has no empty, \".\" or \"..\" segments and no
control character, ?, # or backslash. It either ends with a slash (a directory)
or ends with a file name that has an extension, or with one of the well-known
names in +EXTENSIONLESS-FILE-NAMES+ (CNAME, LICENSE).

Restart USE-VALUE takes a replacement string, which is validated in turn.

PATH: the string to validate; a non-string signals TYPE-ERROR."
  (check-type path string)
  (restart-case
      (let ((reason (path-violation path)))
        (when reason
          (error 'invalid-path :path path :reason reason))
        path)
    (use-value (replacement)
      :report "Use a different path."
      :interactive (lambda ()
                     (format *query-io* "Replacement path: ")
                     (finish-output *query-io*)
                     (list (read-line *query-io*)))
      (parse-path replacement))))

(defun path->output-path (path)
  "Return the relative file name, as a string, that PATH is written to.

A directory path maps to the index file inside it: \"/\" becomes
\"index.html\" and \"/blog/\" becomes \"blog/index.html\". A file path only
loses its leading slash. Signals INVALID-PATH when PATH is invalid.

PATH: the URL path to map."
  (let ((relative (subseq (parse-path path) 1)))
    (if (path-directory-p path)
        (concatenate 'string relative +index-file-name+)
        relative)))
