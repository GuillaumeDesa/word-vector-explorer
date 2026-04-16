## [1.0.1] — 2025

Initial public release.

### Added
- Download manager for fastText Common Crawl `.bin` models (7 languages)
- Automatic path construction from language + folder selection, keeping all UI elements in sync
- Extended download timeout (1 hour) to prevent R's 60-second default from interrupting large transfers
- Fast decompression via `R.utils::gunzip()`, replacing a manual R I/O loop
- Model loading into RAM via `fastTextR::ft_load()`; language inferred from filename
- Language-appropriate word list suggestions, populated automatically on model load
- OOV detection: words returning all-zero vectors are identified, removed, and reported to the user
- t-SNE perplexity cap with floor enforcement (`max(2, min(perp, floor((n−1)/3)))`); user notified when capping occurs
- Live word count display (red below minimum, green at or above)
- Adjustable label font size (slider)
- Adjustable point size (slider)
- Non-overlapping label rendering via `ggrepel::geom_text_repel()` (toggleable)
- PNG export with configurable DPI, width, and height; timestamped filename
- Status bar with informative messages at every stage (ready / downloading / loading / plotting / errors)
- OOV warning banner in main panel
- Numbered sidebar steps (① through ⑤) to make workflow sequence explicit

### Fixed
- Path/language desync: `observe()` on all inputs replaced with `observeEvent` scoped to language and folder only
- Suggestions desync: loaded language stored in reactive value and used consistently, independent of dropdown state
- Silent OOV distortion: zero vectors no longer passed to t-SNE
- t-SNE crash on small word lists: perplexity floor added
- Download failure on slow connections: timeout extended
- Slow decompression: manual R loop replaced with compiled `gunzip()`
- Missing folder validation before download attempt
