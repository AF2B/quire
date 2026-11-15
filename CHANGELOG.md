# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Until 1.0.0 the public API may change between minor versions.

## [Unreleased]

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
