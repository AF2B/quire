---
(:title "The Borba theme"
 :description "Layouts, series, tables of contents and the options the theme reads.")
---

The default theme follows the Borba Design System: a midnight page, white text,
1px rules, square corners, Inter, JetBrains Mono and Playfair Display for post
titles. It needs no JavaScript.

## Layouts

| Layout | Used for | Reads from the front matter |
|--------|----------|-----------------------------|
| `:page` | Any page | `:hide-title` |
| `:post` | Pages under `posts/` | `:description` (the lead), `:tags`, series keys |
| `:home` | The home page | `:eyebrow`, `:headline`, `:accent`, `:cta` |
| `:index` | Section listings, generated | |
| `:tag`, `:tags` | Tag pages, generated | |
| `:series`, `:series-index` | Series pages, generated | |
| `:about` | An about page | `:photo`, `:facts`, `:cv`, `:kicker` |
| `:contact` | A contact page | `:email`, `:cv`, `:cv-preview` |

A post shows a table of contents beside the text when it has two or more
headings, the reading time, its tags, a link to its Markdown source and, in a
series, a breadcrumb and links to the neighbouring parts.

## The home page

With `:headline` the home page is editorial: `:eyebrow` is the small label,
`:headline` and `:accent` make the title with a blue ending, `:cta` is a pair
`("Start here" . "/posts/first/")` for the button, and the Markdown body fills
the panel on the right, usually a REPL session in a code block. Posts with
`:featured t` become the Start here cards, then come the latest posts and the
series. Without `:headline` the hero shows the site title and the body goes
below it.

## Series

Give each part of a series the same `:series` name and its own `:part`:

```markdown
---
(:title "Restarts"
 :date "2026-11-09"
 :series "The condition system"
 :part 2
 :series-total 4)
---
```

`:series-total` announces parts that do not exist yet, so the progress bar shows
published blocks filled and planned ones empty. The step `add-series` writes
`:series-path`, `:series-previous`, `:series-next` and the counts into each
part, and adds a page per series and the listing at `/series/`. A series stays
within one language.

## Options

Set these under `:extra` in `make-site`:

| Key | Meaning |
|-----|---------|
| `:nav` | Entries `(LABEL . PATH)`. A keyword label, such as `:posts`, is translated. An entry whose page does not exist in the current language falls back to the default language, or is left out |
| `:social` | Pairs `("GitHub" . "https://github.com/you")` for the Elsewhere column of the footer |
| `:email` | Address shown by the contact layout |
| `:source-url` | Base address of your Markdown files; posts link to it |
| `:image` | Default share image |
| `:strings` | Overrides for interface strings, per language |

The footer always credits quire. The header logo is a constant of the theme, so
changing it is a one-line edit.

Next: [languages](../languages/).
