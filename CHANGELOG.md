# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Until 1.0.0 the public API may change between minor versions.

## [Unreleased]

### Added

- `quire check`: reports internal links that lead nowhere, honoring the base
  URL path, and exits with 1 when there are any.
- Canonical link and Open Graph and Twitter card tags in the default theme,
  with `:image` in the front matter or the site options.
- Atom 1.0 feed at `/atom.xml`, built by the new default step `add-atom-feed`.
- `:lang` front matter key to set the language of one page.
- `CNAME`, `LICENSE`, `.nojekyll` and `.well-known/` are copied as site files.
- The dev server reuses the rendered Markdown of unchanged files.
- Guide page on writing build steps.
- Release workflow: pushing a `v*` tag builds the executable and attaches it,
  with its checksum, to the GitHub release.
- The test suite passes on ECL and Clozure CL; CI runs both as experimental
  jobs.
- Product site and guide in `site/`, built entirely with quire and published
  to GitHub Pages by a workflow.
- The default theme shows the BORBA wordmark as the header logo.
- Languages: `:languages` on the site, content in `content/<code>/`, the step
  `add-translations`, `hreflang` links, a language dropdown with flags in the
  theme, and section listings, tags, series and feeds per language.
- Series: the `:series`, `:part` and `:series-total` front matter keys and the
  step `add-series`, with navigation between parts and a page per series.
- `h2` and `h3` get ids and a `:toc`, and every page gets `:reading-minutes`.
- Markdown containers (`::: details Title`) and footnotes (`[^id]`).
- `page-source-name`, so a theme can link to the Markdown source of a page.
- Theme layouts `:about`, `:contact`, `:series` and `:series-index`, an
  editorial `:home`, a footer with social links, interface strings in five
  languages, and a table of contents in posts.
- `examples/blog`, a multilingual blog that uses all of the above.

### Changed

- Section listings and tag pages in the theme are rows with tags and reading
  time instead of plain entries. Navigation labels may be keywords that the
  theme translates. `tag-url-path` takes an optional language prefix.

### Fixed

- `export-site` could report a wrong file count on implementations whose `sort`
  reuses the conses of the list it sorts.

## [0.1.0] - 2026-11-15

First public preview.

### Added

- Page model: validated URL paths, pages whose body is text, bytes or a
  function, and a page map that always iterates in path order.
- Typed conditions with restarts for invalid paths, path conflicts, unknown
  layouts, bad front matter and unsafe output directories.
- Markdown content with a Lisp property-list front matter, read with
  `*read-eval*` disabled. Tables and highlighted fenced code are supported.
- ISO 8601 dates, always in UTC, with RFC 822 output for feeds.
- Build steps for section listings, tag pages, an RSS 2.0 feed and a sitemap.
- Lazy layouts: a layout runs when a page is written or served, so redefining
  it at the REPL takes effect on the next request.
- Deterministic export; `--clean` only empties directories that quire created.
- Development server with live reload over server-sent events and a file
  watcher; build failures are shown in the browser.
- `quire` command with `build`, `serve`, `version` and `help`, and a standalone
  executable built with `make binary`.
- Default theme following the Borba Design System, with a demo site in
  `examples/demo/`.

### Known limitations

- SBCL only.
- Raw HTML inside Markdown passes through unchanged.
- The Markdown parser is not strict CommonMark; fenced code needs backticks.
- No incremental builds, i18n, image pipeline or plugin system.
- The file watcher polls instead of using inotify.

[Unreleased]: https://github.com/AF2B/quire/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/AF2B/quire/releases/tag/v0.1.0
