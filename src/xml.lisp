(defpackage #:quire/xml
  (:use #:cl)
  (:export #:xml-escape))

(in-package #:quire/xml)

(defconstant +first-printable-code+ 32
  "Character codes below this value are control characters.")

(defun xml-control-character-p (character)
  "Return true for a control character that XML 1.0 cannot carry.

Tab, line feed and carriage return are allowed in XML and are not matched.

CHARACTER: the character to test."
  (and (< (char-code character) +first-printable-code+)
       (not (member character '(#\Tab #\Newline #\Return)))))

(defun xml-escape (text)
  "Return TEXT safe to place in XML text or in a double-quoted attribute.

The five predefined entities are escaped and characters XML cannot carry are
dropped.

TEXT: the string to escape."
  (check-type text string)
  (with-output-to-string (out)
    (loop for character across text
          do (case character
               (#\& (write-string "&amp;" out))
               (#\< (write-string "&lt;" out))
               (#\> (write-string "&gt;" out))
               (#\" (write-string "&quot;" out))
               (#\' (write-string "&apos;" out))
               (t (unless (xml-control-character-p character)
                    (write-char character out)))))))
