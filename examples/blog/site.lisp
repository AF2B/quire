(in-package #:quire-user)

;;; A blog in several languages, built with every feature of the Borba theme:
;;; series, tables of contents, footnotes, translations and a language switcher.
;;;   quire build --site examples/blog/site.lisp
;;;   quire serve --site examples/blog/site.lisp
;;; The content is placeholder text: replace it with your own.

(setf *site*
      (make-site :title "The Lisp Guy"
                 :description "Macros, the condition system, the MOP and the image underneath. Long posts where every result is evaluated, not guessed."
                 :base-url ""
                 :author "Your Name"
                 :language "en"
                 :languages '((:code "en" :name "English" :flag "gb")
                              (:code "pt-br" :name "Português (Brasil)" :flag "br")
                              (:code "pt-pt" :name "Português (Portugal)" :flag "pt")
                              (:code "es" :name "Español" :flag "es")
                              (:code "ru" :name "Русский" :flag "ru"))
                 :layouts (quire/theme-borba:layouts)
                 :steps (quire/theme-borba:steps)
                 :extra '(:nav ((:posts . "/posts/")
                                (:series . "/series/")
                                (:about . "/about/")
                                (:contact . "/contact/"))
                          :email "hello@example.com"
                          :source-url "https://github.com/example/blog/blob/main/content"
                          :social (("GitHub" . "https://github.com/")
                                   ("GitLab" . "https://gitlab.com/")
                                   ("LinkedIn" . "https://www.linkedin.com/")
                                   ("DEV" . "https://dev.to/")
                                   ("Medium" . "https://medium.com/")))))
