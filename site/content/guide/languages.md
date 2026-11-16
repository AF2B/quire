---
(:title "Languages"
 :description "Write a site in several languages with translation links and a switcher.")
---

A site has one default language and any number of others. Declare them in
`make-site`:

```lisp
(make-site :title "My site"
           :language "en"
           :languages '((:code "en" :name "English" :flag "gb")
                        (:code "pt-br" :name "Português (Brasil)" :flag "br")
                        (:code "es" :name "Español" :flag "es")))
```

The default language comes first and is added when you leave it out. `:flag`
names a flag the theme ships: `gb`, `br`, `pt`, `es` and `ru`. Other flags are
simply not drawn.

## Content

Pages of the default language live where they always did. Pages of any other
language live in a directory named after the code:

```
content/
  about.md                ->  /about/
  posts/restarts.md       ->  /posts/restarts/
  pt-br/
    about.md              ->  /pt-br/about/
    posts/restarts.md     ->  /pt-br/posts/restarts/
```

Sections, layouts and titles are worked out as if the prefix was not there, so
`pt-br/posts/restarts.md` is a post.

## Translations

Pages that have the same path once the prefix is removed are translations of
each other. The step `add-translations` sets `:lang` and `:translations`, a list
of `(CODE . PATH)`, on each page. The theme uses them for the language
switcher in the header and for `hreflang` links in the head. A page without a
translation sends the switcher to the home page of that language.

Everything generated is per language: section listings, tag pages, series and
the RSS and Atom feeds (`/pt-br/feed.xml`).

## Interface strings

The theme translates its own text (navigation, headings, buttons) into English,
Brazilian and European Portuguese, Spanish and Russian. A language it does not
know falls back to English. Override any string under `:strings`:

```lisp
:extra '(:strings (("pt-br" :latest "Novidades")))
```

`quire check` reports a switcher or a link that leads to a page that does not
exist, so a half-translated site shows its gaps.

Next: [REPL workflow](../repl/).
