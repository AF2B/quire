(defpackage #:quire/front-matter
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/conditions
                #:front-matter-error)
  (:export #:+fence+
           #:split-front-matter))

(in-package #:quire/front-matter)

(define-constant +fence+ "---"
  :test #'string=
  :documentation "Line that opens and closes the metadata block.")

(defconstant +byte-order-mark+ (code-char #xFEFF)
  "Character some editors put at the start of UTF-8 files.")

(defvar *metadata-package*
  (or (find-package "QUIRE-METADATA")
      (make-package "QUIRE-METADATA" :use '("COMMON-LISP")))
  "Package that metadata symbols are read into: T and NIL stay themselves and
any other bare symbol is harmless here.")

(defun normalize-newlines (text)
  "Return TEXT with every CR LF pair replaced by a single LF.

TEXT: the string to normalize."
  (with-output-to-string (out)
    (loop for index from 0 below (length text)
          for character = (char text index)
          unless (and (char= character #\Return)
                      (< (1+ index) (length text))
                      (char= (char text (1+ index)) #\Newline))
            do (write-char character out))))

(defun split-lines (text)
  "Return the lines of TEXT, keeping empty ones, without line terminators.

TEXT: the string to split; \"a~%b~%\" yields (\"a\" \"b\" \"\")."
  (loop with start = 0
        for end = (position #\Newline text :start start)
        collect (subseq text start end)
        while end
        do (setf start (1+ end))))

(defun join-lines (lines)
  "Return LINES joined with LF, the inverse of SPLIT-LINES.

LINES: a list of strings."
  (format nil "~{~A~^~%~}" lines))

(defun fence-line-p (line)
  "Return true when LINE is the metadata fence, ignoring trailing blanks.

LINE: one line of text."
  (string= +fence+ (string-right-trim '(#\Space #\Tab) line)))

(defun valid-plist-p (form)
  "Return true when FORM is a proper list of keyword and value pairs.

FORM: any object."
  (and (listp form)
       (null (cdr (last form)))
       (evenp (length form))
       (loop for (key) on form by #'cddr
             always (keywordp key))))

(defun read-form (stream source end-marker)
  "Read one form from STREAM, or return END-MARKER at end of input.

Reading is safe: no reader evaluation, symbols go to *METADATA-PACKAGE*. Any
reader failure is re-signaled as a FRONT-MATTER-ERROR.

STREAM: the input stream.
SOURCE: origin of the text, for messages.
END-MARKER: object returned when STREAM is exhausted."
  (let ((failure nil))
    (let ((form (handler-case
                    (let ((*read-eval* nil)
                          (*package* *metadata-package*))
                      (read stream nil end-marker))
                  (error (condition)
                    (setf failure (princ-to-string condition))
                    nil))))
      (when failure
        (error 'front-matter-error
               :source source
               :reason :unreadable
               :detail failure))
      form)))

(defun read-metadata (text source)
  "Return the property list written in TEXT, or NIL when TEXT is blank.

Signals FRONT-MATTER-ERROR when TEXT is unreadable, holds more than one form
or is not a property list with keyword keys.

TEXT: the metadata block without its fences.
SOURCE: origin of the text, for messages."
  (with-input-from-string (stream text)
    (let* ((end-marker (make-symbol "END"))
           (form (read-form stream source end-marker)))
      (cond ((eq form end-marker)
             '())
            ((not (eq end-marker (read-form stream source end-marker)))
             (error 'front-matter-error :source source :reason :trailing-forms))
            ((not (valid-plist-p form))
             (error 'front-matter-error :source source :reason :not-a-plist))
            (t form)))))

(defun split-front-matter (text &key source)
  "Split TEXT into its metadata property list and its body.

A file has metadata when its first line is --- ; the metadata is one Lisp
property list, and a second --- line ends it. Line endings are normalized to
LF. Without the opening fence the metadata is NIL and the body is TEXT.
Returns two values: the property list and the body string. Signals
FRONT-MATTER-ERROR when the block is unterminated or unusable.

TEXT: the full contents of a content file.
SOURCE: origin of the text, for messages; defaults to NIL."
  (check-type text string)
  (let* ((start (if (and (plusp (length text))
                         (char= +byte-order-mark+ (char text 0)))
                    1
                    0))
         (lines (split-lines (normalize-newlines (subseq text start)))))
    (if (not (fence-line-p (first lines)))
        (values '() (join-lines lines))
        (let ((closing (position-if #'fence-line-p lines :start 1)))
          (unless closing
            (error 'front-matter-error :source source :reason :unterminated))
          (values (read-metadata (join-lines (subseq lines 1 closing)) source)
                  (join-lines (nthcdr (1+ closing) lines)))))))
