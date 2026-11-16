(defpackage #:quire/theme-borba/i18n
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/languages
                #:language-prefix
                #:page-language)
  (:import-from #:quire/page
                #:page-metadata)
  (:import-from #:quire/site
                #:site-extra
                #:site-language
                #:site-languages
                #:site-link)
  (:export #:flag-sprite-html
           #:language-switcher-html
           #:localized-path
           #:multilingual-p
           #:page-lang
           #:ui))

(in-package #:quire/theme-borba/i18n)

(define-constant +fallback-language+ "en"
  :test #'string=
  :documentation "Language whose strings fill any gap in another language.")

(define-constant +ui-strings+
    '(("en"
       :home "Home" :posts "Posts" :series "Series" :about "About"
       :contact "Contact" :latest "Latest" :start-here "Start here"
       :start-here-note "Read these first" :all-posts "All posts"
       :min "min" :min-read "min read" :on-this-page "On this page"
       :part "Part" :of "of" :published "published" :parts "parts"
       :elsewhere "Elsewhere" :this-site "This site"
       :built-with "Built with quire" :subscribe "Subscribe via RSS"
       :view-source "View source" :download-cv "Download CV (PDF)"
       :email-me "Email me" :email "Email" :language "Language"
       :tags "Tags" :tag "Tag" :previous "Previous" :next "Next"
       :skip "Skip to content" :primary "Primary" :photo "Photo")
      ("pt-br"
       :home "Início" :posts "Posts" :series "Séries" :about "Sobre"
       :contact "Contato" :latest "Recentes" :start-here "Comece por aqui"
       :start-here-note "Leia estes primeiro" :all-posts "Todos os posts"
       :min "min" :min-read "min de leitura" :on-this-page "Nesta página"
       :part "Parte" :of "de" :published "publicados" :parts "partes"
       :elsewhere "Em outros lugares" :this-site "Este site"
       :built-with "Feito com quire" :subscribe "Assinar via RSS"
       :view-source "Ver fonte" :download-cv "Baixar currículo (PDF)"
       :email-me "Enviar e-mail" :email "E-mail" :language "Idioma"
       :tags "Tags" :tag "Tag" :previous "Anterior" :next "Próximo"
       :skip "Pular para o conteúdo" :primary "Principal" :photo "Foto")
      ("pt-pt"
       :home "Início" :posts "Artigos" :series "Séries" :about "Sobre"
       :contact "Contacto" :latest "Recentes" :start-here "Começar aqui"
       :start-here-note "Leia estes primeiro" :all-posts "Todos os artigos"
       :min "min" :min-read "min de leitura" :on-this-page "Nesta página"
       :part "Parte" :of "de" :published "publicadas" :parts "partes"
       :elsewhere "Noutros sítios" :this-site "Este sítio"
       :built-with "Feito com quire" :subscribe "Subscrever via RSS"
       :view-source "Ver código-fonte" :download-cv "Descarregar CV (PDF)"
       :email-me "Enviar e-mail" :email "E-mail" :language "Língua"
       :tags "Etiquetas" :tag "Etiqueta" :previous "Anterior" :next "Seguinte"
       :skip "Saltar para o conteúdo" :primary "Principal" :photo "Fotografia")
      ("es"
       :home "Inicio" :posts "Entradas" :series "Series" :about "Acerca de"
       :contact "Contacto" :latest "Recientes" :start-here "Empieza aquí"
       :start-here-note "Lee esto primero" :all-posts "Todas las entradas"
       :min "min" :min-read "min de lectura" :on-this-page "En esta página"
       :part "Parte" :of "de" :published "publicadas" :parts "partes"
       :elsewhere "En otros sitios" :this-site "Este sitio"
       :built-with "Hecho con quire" :subscribe "Suscribirse por RSS"
       :view-source "Ver fuente" :download-cv "Descargar CV (PDF)"
       :email-me "Enviar correo" :email "Correo" :language "Idioma"
       :tags "Etiquetas" :tag "Etiqueta" :previous "Anterior" :next "Siguiente"
       :skip "Saltar al contenido" :primary "Principal" :photo "Foto")
      ("ru"
       :home "Главная" :posts "Записи" :series "Серии" :about "Обо мне"
       :contact "Контакты" :latest "Новое" :start-here "Начните здесь"
       :start-here-note "Сначала прочитайте" :all-posts "Все записи"
       :min "мин" :min-read "мин чтения" :on-this-page "На этой странице"
       :part "Часть" :of "из" :published "опубликовано" :parts "частей"
       :elsewhere "В других местах" :this-site "Об этом сайте"
       :built-with "Сделано на quire" :subscribe "Подписаться по RSS"
       :view-source "Исходник" :download-cv "Скачать резюме (PDF)"
       :email-me "Написать письмо" :email "Почта" :language "Язык"
       :tags "Теги" :tag "Тег" :previous "Назад" :next "Вперёд"
       :skip "Перейти к содержимому" :primary "Основное" :photo "Фото"))
  :test #'equal
  :documentation "Built-in interface strings: (LANGUAGE-CODE . PLIST).")

(define-constant +flag-sprite+
    (concatenate
     'string
     "<svg width=\"0\" height=\"0\" style=\"position:absolute\" "
     "aria-hidden=\"true\" focusable=\"false\"><defs>"
     "<symbol id=\"f-gb\" viewBox=\"0 0 20 14\">"
     "<rect width=\"20\" height=\"14\" fill=\"#012169\"/>"
     "<path d=\"M0 0L20 14M20 0L0 14\" stroke=\"#fff\" stroke-width=\"2.6\"/>"
     "<path d=\"M0 0L20 14M20 0L0 14\" stroke=\"#C8102E\" stroke-width=\"1\"/>"
     "<rect x=\"8\" width=\"4\" height=\"14\" fill=\"#fff\"/>"
     "<rect y=\"5\" width=\"20\" height=\"4\" fill=\"#fff\"/>"
     "<rect x=\"8.8\" width=\"2.4\" height=\"14\" fill=\"#C8102E\"/>"
     "<rect y=\"5.8\" width=\"20\" height=\"2.4\" fill=\"#C8102E\"/></symbol>"
     "<symbol id=\"f-br\" viewBox=\"0 0 20 14\">"
     "<rect width=\"20\" height=\"14\" fill=\"#009C3B\"/>"
     "<path d=\"M10 1.4L18.2 7L10 12.6L1.8 7Z\" fill=\"#FFDF00\"/>"
     "<circle cx=\"10\" cy=\"7\" r=\"3.2\" fill=\"#002776\"/></symbol>"
     "<symbol id=\"f-pt\" viewBox=\"0 0 20 14\">"
     "<rect width=\"20\" height=\"14\" fill=\"#FF0000\"/>"
     "<rect width=\"8\" height=\"14\" fill=\"#006600\"/>"
     "<circle cx=\"8\" cy=\"7\" r=\"2.6\" fill=\"#FFE000\"/>"
     "<circle cx=\"8\" cy=\"7\" r=\"1.3\" fill=\"#FF0000\"/></symbol>"
     "<symbol id=\"f-es\" viewBox=\"0 0 20 14\">"
     "<rect width=\"20\" height=\"14\" fill=\"#AA151B\"/>"
     "<rect y=\"3.5\" width=\"20\" height=\"7\" fill=\"#F1BF00\"/></symbol>"
     "<symbol id=\"f-ru\" viewBox=\"0 0 20 14\">"
     "<rect width=\"20\" height=\"14\" fill=\"#fff\"/>"
     "<rect y=\"4.67\" width=\"20\" height=\"4.67\" fill=\"#0039A6\"/>"
     "<rect y=\"9.33\" width=\"20\" height=\"4.67\" fill=\"#D52B1E\"/></symbol>"
     "</defs></svg>")
  :test #'string=
  :documentation "SVG sprite with the flags a language entry can name with :FLAG.")

(defun page-lang (site page)
  "Return the language code written in the lang attribute of PAGE.

The :LANG of the front matter wins; otherwise the language comes from the path.

SITE: the site being built.
PAGE: the page being rendered."
  (or (getf (page-metadata page) :lang)
      (page-language site page)))

(defun ui (site page key)
  "Return the interface string KEY in the language of PAGE.

The site can override any string with :STRINGS in its extra options, as
((\"pt-br\" :latest \"Novidades\")). A string missing in the language falls back
to English.

SITE: the site being built.
PAGE: the page being rendered.
KEY: a keyword such as :LATEST."
  (let ((language (string-downcase (page-lang site page))))
    (flet ((lookup (table)
             (getf (cdr (assoc language table :test #'string-equal)) key)))
      (or (lookup (getf (site-extra site) :strings))
          (lookup +ui-strings+)
          (getf (cdr (assoc +fallback-language+ +ui-strings+
                            :test #'string=))
                key)
          (error "Unknown interface string ~S" key)))))

(defun localized-path (site page path)
  "Return PATH below the language prefix of PAGE.

Addresses that are not site paths, such as full URLs, are returned unchanged.

SITE: the site being built.
PAGE: the page being rendered.
PATH: a site path such as \"/about/\", or an absolute address."
  (if (and (plusp (length path)) (char= #\/ (char path 0)))
      (concatenate 'string
                   (language-prefix site (page-language site page))
                   path)
      path))

(defun multilingual-p (site)
  "Return true when SITE has more than one language.

SITE: the site being built."
  (rest (site-languages site)))

(defun flag-sprite-html (site)
  "Return the SVG sprite of the flags, or an empty string for a one-language site.

SITE: the site being built."
  (if (multilingual-p site) +flag-sprite+ ""))

(defun flag-html (entry)
  "Return the small flag image of the language ENTRY, or an empty string.

ENTRY: a language plist; its :FLAG names a symbol of the sprite.

Only letters and digits are accepted in the flag name."
  (let ((flag (getf entry :flag)))
    (if (and (stringp flag) (plusp (length flag)) (every #'alphanumericp flag))
        (format nil "<svg class=\"flag\" aria-hidden=\"true\"><use href=\"#f-~A\"/></svg>"
                flag)
        "")))

(defun language-target (site page code)
  "Return the site path that the language CODE should link to from PAGE.

It is the translation of PAGE when there is one, otherwise the home page of that
language.

SITE: the site being built.
PAGE: the page being rendered.
CODE: a language code of the site."
  (or (cdr (assoc code (getf (page-metadata page) :translations)
                  :test #'string=))
      (concatenate 'string (language-prefix site code) "/")))

(defun language-switcher-html (site page)
  "Return the language dropdown of the header, or an empty string.

It is a details element, so it works without JavaScript. Each entry links to the
translation of the current page, or to the home page of the language.

SITE: the site being built.
PAGE: the page being rendered."
  (if (not (multilingual-p site))
      ""
      (let* ((current (page-language site page))
             (entries (site-languages site))
             (current-entry (or (find current entries
                                      :key (lambda (entry) (getf entry :code))
                                      :test #'string=)
                                (first entries)))
             (label (ui site page :language)))
        (spinneret:with-html-string
          (:details :class "lang"
           (:summary :aria-label label
            (:raw (flag-html current-entry))
            (:span (string-upcase (getf current-entry :code))))
           (:ul
            (dolist (entry entries)
              (let ((code (getf entry :code)))
                (:li
                 (:a :href (site-link site (language-target site page code))
                     :lang code
                     :hreflang code
                     :aria-current (when (string= code current) "true")
                     (:raw (flag-html entry))
                     (:span :class "name" (or (getf entry :name) code))
                     (:span :class "code" (string-upcase code)))))))))))
  )
