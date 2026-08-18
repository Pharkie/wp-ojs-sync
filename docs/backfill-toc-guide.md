# TOC guide — moved

`toc.json` is the content pipeline's input, and the content pipeline moved to
Harbour on 2026-08-18. The schema, the method for building one from an issue
PDF, and the book-review pitfalls are now at
`membership-platform/docs/journal-toc-guide.md`.

Nothing in this repo reads `toc.json` except the OJS delivery stages
(`pipe6`–`pipe13`), and they only consume what the pipeline already wrote.
