(defpackage #:quire/dates
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/conditions
                #:invalid-date)
  (:export #:format-iso-date
           #:format-iso-datetime
           #:format-rfc-822
           #:parse-date))

(in-package #:quire/dates)

(define-constant +day-names+ #("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun")
  :test #'equalp
  :documentation "English day abbreviations, Monday first like CL day numbers.")

(define-constant +month-names+
  #("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
  :test #'equalp
  :documentation "English month abbreviations, January first.")

(define-constant +days-per-month+ #(31 28 31 30 31 30 31 31 30 31 30 31)
  :test #'equalp
  :documentation "Days of each month in a common year.")

(defconstant +utc-offset+ 0
  "Time zone, in hours west of Greenwich, used by every date quire handles.")

(defconstant +earliest-year+ 1900
  "ENCODE-UNIVERSAL-TIME cannot represent earlier years.")

(defconstant +february+ 2
  "Month number of February.")

(defconstant +date-length+ 10
  "Length of YYYY-MM-DD.")

(defconstant +datetime-length+ 19
  "Length of YYYY-MM-DDTHH:MM:SS.")

(defconstant +max-minute-or-second+ 59
  "Largest valid minute or second.")

(defconstant +max-hour+ 23
  "Largest valid hour.")

(defconstant +utc-suffix+ #\Z
  "Optional last character of a datetime, meaning UTC.")

(defun leap-year-p (year)
  "Return true when YEAR is a leap year in the Gregorian calendar.

YEAR: an integer year."
  (and (zerop (mod year 4))
       (or (plusp (mod year 100))
           (zerop (mod year 400)))))

(defun days-in-month (year month)
  "Return how many days MONTH of YEAR has.

YEAR: an integer year.
MONTH: an integer from 1 to 12."
  (+ (svref +days-per-month+ (1- month))
     (if (and (= month +february+) (leap-year-p year)) 1 0)))

(defun digits (text start end)
  "Return the integer written by the decimal digits of TEXT, or NIL.

NIL is returned when the range is out of bounds or holds a non-digit.

TEXT: the string to read.
START: index of the first digit.
END: index just after the last digit."
  (when (and (<= end (length text))
             (loop for index from start below end
                   always (digit-char-p (char text index))))
    (parse-integer text :start start :end end)))

(defun separator-p (text index character)
  "Return true when TEXT has CHARACTER at INDEX.

TEXT: the string to inspect.
INDEX: position to look at.
CHARACTER: the expected character."
  (and (< index (length text))
       (char= character (char text index))))

(defun parse-date (text)
  "Return the universal time, in UTC, that TEXT denotes.

TEXT is YYYY-MM-DD, meaning midnight, or YYYY-MM-DDTHH:MM:SS with an optional
trailing Z. Signals INVALID-DATE for any other shape or an impossible date.

TEXT: the date string."
  (check-type text string)
  (let* ((datetime-p (>= (length text) +datetime-length+))
         (year (digits text 0 4))
         (month (digits text 5 7))
         (day (digits text 8 10))
         (hour (if datetime-p (digits text 11 13) 0))
         (minute (if datetime-p (digits text 14 16) 0))
         (second (if datetime-p (digits text 17 19) 0))
         (expected-length (if datetime-p
                              (if (separator-p text +datetime-length+
                                               +utc-suffix+)
                                  (1+ +datetime-length+)
                                  +datetime-length+)
                              +date-length+)))
    (unless (and year month day hour minute second
                 (= (length text) expected-length)
                 (separator-p text 4 #\-)
                 (separator-p text 7 #\-)
                 (or (not datetime-p)
                     (and (separator-p text 10 #\T)
                          (separator-p text 13 #\:)
                          (separator-p text 16 #\:)))
                 (>= year +earliest-year+)
                 (<= 1 month 12)
                 (<= 1 day (days-in-month year month))
                 (<= hour +max-hour+)
                 (<= minute +max-minute-or-second+)
                 (<= second +max-minute-or-second+))
      (error 'invalid-date :text text))
    (encode-universal-time second minute hour day month year +utc-offset+)))

(defun format-iso-date (universal-time)
  "Return UNIVERSAL-TIME as YYYY-MM-DD in UTC.

UNIVERSAL-TIME: an integer universal time."
  (multiple-value-bind (second minute hour day month year)
      (decode-universal-time universal-time +utc-offset+)
    (declare (ignore second minute hour))
    (format nil "~4,'0D-~2,'0D-~2,'0D" year month day)))

(defun format-iso-datetime (universal-time)
  "Return UNIVERSAL-TIME as YYYY-MM-DDTHH:MM:SSZ in UTC.

UNIVERSAL-TIME: an integer universal time."
  (multiple-value-bind (second minute hour day month year)
      (decode-universal-time universal-time +utc-offset+)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ"
            year month day hour minute second)))

(defun format-rfc-822 (universal-time)
  "Return UNIVERSAL-TIME in RFC 822 form, such as Sat, 14 Nov 2026 00:00:00 +0000.

UNIVERSAL-TIME: an integer universal time."
  (multiple-value-bind (second minute hour day month year day-of-week)
      (decode-universal-time universal-time +utc-offset+)
    (format nil "~A, ~2,'0D ~A ~4,'0D ~2,'0D:~2,'0D:~2,'0D +0000"
            (svref +day-names+ day-of-week)
            day
            (svref +month-names+ (1- month))
            year hour minute second)))
