---
(:title "HTML output"
 :description "What the pages look like and how to write HTML in layouts.")
---

The pages quire writes are plain, modern HTML5:

- `<!doctype html>`, a `lang` attribute, a viewport meta tag and a UTF-8
  charset
- Semantic landmarks (`header`, `nav`, `main`, `article`, `footer`), a skip
  link, `aria-current` on the active navigation entry and `<time datetime>`
  for dates
- RSS and Atom alternate links when the site has dated pages
- A canonical link and Open Graph and Twitter card tags, so shared links show a
  title, a description and an image; set `:image` in the front matter or in the
  site's `:extra` to choose the image
- Text and attributes escaped by default

## Writing HTML in layouts

Layouts use [Spinneret](https://github.com/ruricolist/spinneret), so HTML is
S-expressions and any HTML5 element is available:

```lisp
(spinneret:with-html-string
  (:article
   (:header (:h1 "Title")
            (:time :datetime "2026-11-14" "14 Nov 2026"))
   (:figure (:picture (:source :srcset "a.webp" :type "image/webp")
                      (:img :src "a.png" :alt "A diagram"))
            (:figcaption "A diagram"))
   (:details (:summary "More") (:p "Hidden until opened."))
   (:dialog :open t (:p "Hello"))))
```

The test suite renders more than thirty elements, among them `article`,
`aside`, `audio`, `details`, `dialog`, `figure`, `hgroup`, `mark`, `meter`,
`nav`, `picture`, `progress`, `ruby`, `section`, `summary`, `template`, `time`
and `video`. Spinneret has no `<search>` or `<slot>` element; write those with
`(:raw "<search>...</search>")`.

In Markdown content, raw HTML passes through unchanged, so `<details>`,
`<picture>`, `<video>` and the rest work there too.

## The default theme

`quire/theme-borba` follows the Borba Design System: midnight background,
Electric Blue accents, Inter, JetBrains Mono and Playfair Display, square
corners and 1 px borders. The generator itself does not depend on the theme;
write your own layouts and the theme is not loaded.

Next: [the Borba theme](../theme/).
