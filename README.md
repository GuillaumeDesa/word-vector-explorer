# word-vector-explorer

A Shiny application for the interactive visualisation of fastText distributional semantic models (DSMs). Words are projected from their native 300-dimensional vector space into two dimensions using t-SNE, allowing users to explore semantic proximity and clustering across seven languages.

Companion to the blog series on distributional semantics at [Corpus Linguistics & Statistics with R](https://corpling.hypotheses.org).

---

## What it does

- Downloads pre-trained fastText Common Crawl models directly from [fasttext.cc](https://fasttext.cc/docs/en/crawl-vectors.html) into a user-specified local folder
- Loads a `.bin` model into memory and retrieves vectors for a user-supplied word list
- Projects the vectors into 2D with t-SNE and renders an interactive plot
- Exports the plot as a PNG with configurable resolution and dimensions

Supported languages: **English, French, German, Spanish, Italian, Chinese, Albanian**

---

## Screenshot

*(Add a screenshot here once the app is running: `docs/screenshot.png`)*

---

## Requirements

### R version

R ≥ 4.1.0 is recommended.

### R packages

Install all dependencies in one call:

```r
install.packages(c(
  "shiny",
  "shinythemes",
  "fastTextR",
  "Rtsne",
  "ggplot2",
  "dplyr",
  "R.utils",
  "ggrepel"
))
```

| Package | Purpose |
|---|---|
| `shiny` | Web application framework |
| `shinythemes` | Flatly UI theme |
| `fastTextR` | R interface to fastText; loads `.bin` models and retrieves word vectors |
| `Rtsne` | t-SNE dimensionality reduction |
| `ggplot2` | Plot rendering |
| `dplyr` | Data manipulation |
| `R.utils` | Fast `.gz` decompression via `gunzip()` |
| `ggrepel` | Non-overlapping text labels |

> **Note on `fastTextR`**: this package links against the fastText C++ library. On some systems (particularly Windows) compilation from source may be required. See the [fastTextR documentation](https://github.com/pommedeterresautee/fastrtext) for platform-specific instructions.

### Disk space

Each fastText model requires approximately 7–8 GB of disk space once decompressed. Ensure the destination folder has sufficient space before downloading.

---

## Installation

```r
# Clone the repository or download the script directly
# Then, from R or RStudio:
library(shiny)
runApp("path/to/word-vector-explorer/app.R")
```

The app opens in your default browser.

---

## Workflow

The sidebar follows a numbered five-step sequence. Steps depend on each other: complete them in order.

### ① Language & Model

Select a language from the dropdown. The app sets the download URL and the expected local file path automatically. Enter or confirm the destination folder, then click **Download / Check Model**.

- If the `.bin` file already exists in the folder, the app reports this and skips the download.
- If the folder does not exist, the app reports an error. Create the folder first.
- Downloads are large (several GB). On a typical academic network connection, expect 10–30 minutes. The app sets a one-hour timeout to prevent R's default 60-second limit from interrupting the transfer.
- Decompression is handled automatically after download using `R.utils::gunzip()`.

### ② Load Model

The path to the `.bin` file is auto-filled from the language and folder selection above. Click **Load Model into RAM**.

- Loading takes 1–3 minutes depending on available RAM and disk speed.
- The model stays in memory for the session. You do not need to reload it between plots.
- The word list (Step ③) is automatically populated with language-appropriate suggestions once the model is loaded.

### ③ Words to Plot

Enter a comma-separated word list. The app shows a live count of detected words; the count is displayed in red if fewer than 4 words are present (the minimum required for t-SNE).

Out-of-vocabulary (OOV) words — i.e. words for which fastText returns an all-zero vector — are detected automatically, removed before plotting, and reported in a warning banner.

### ④ Plot Settings

| Control | Effect |
|---|---|
| t-SNE Perplexity | Controls the balance between local and global structure. For small word lists (< 20 words), keep this low (2–5). The app caps perplexity automatically at `floor((n−1)/3)` and reports when capping occurs. |
| Label font size | Size of word labels in the plot (ggplot size units). |
| Point size | Size of the plotted points. |
| Avoid overlapping labels | Toggles `ggrepel::geom_text_repel()`. Recommended for lists of more than ~15 words. |

Click **Generate Visualisation** to render the plot. The plot only updates when this button is clicked, not on every slider change.

### ⑤ Export

Set resolution (DPI), width, and height, then click **Download plot as PNG**. The filename is generated automatically and includes the language code and a timestamp.

Recommended settings:
- Presentation slide: 150 dpi, 10 × 7 in
- Print / paper appendix: 300 dpi, 10 × 7 in
- Web / quick preview: 72 dpi, 10 × 7 in

---

## Technical notes

### Why fastText and not word2vec or BERT?

fastText Common Crawl vectors (Grave et al. 2018) are type-based representations: each word form receives a single 300-dimensional vector aggregated over all its training contexts. This is a known limitation — polysemous and homonymous words receive a single blended representation — but it has practical compensating advantages. fastText incorporates subword information (character n-grams of length 3–6), which means morphologically related forms share vector components and out-of-vocabulary items can receive reasonable representations. The models are pre-trained on Wikipedia and Common Crawl (up to 630 billion words for English), are freely available, and are interpretable in the sense that the training objective and hyperparameters are fully documented. For lexical-level exploratory work and pedagogical purposes, they remain a well-motivated choice.

Token-based models such as BERT produce context-sensitive representations and handle polysemy more gracefully, but they require substantially greater computational resources, offer less transparency about what individual layers represent, and — in their standard pre-trained forms — are biased towards contemporary standard written English in ways that matter for historical or register-specific work.

### t-SNE interpretation

t-SNE projections preserve local neighbourhood structure but not global distances. Words that appear close in the plot are genuinely close in the original high-dimensional space; words that appear far apart may or may not be far apart. Do not draw conclusions from absolute distances in the 2D projection. For quantitative similarity measurement, use cosine similarity on the original vectors.

The `set.seed(42)` call in the plotting code ensures reproducibility: the same word list and perplexity setting will always produce the same layout.

### Memory management

Loading a fastText `.bin` model occupies approximately 7–8 GB of RAM. The app calls `gc()` before loading to release any previously held model. On machines with less than 16 GB of RAM, running other memory-intensive applications alongside the app is not recommended.

---

## File structure

```
word-vector-explorer/
├── app.R           # Main application (UI + server)
├── README.md       # This file
├── CHANGELOG.md    # Version history
├── CITATION.cff    # Citation metadata
├── LICENSE         # CC BY-NC 4.0
└── .gitignore      # Excludes model files and R session artefacts
```

Model files (`.bin`, `.gz`) are excluded from version control via `.gitignore`. They must be downloaded separately through the app or directly from [fasttext.cc](https://fasttext.cc/docs/en/crawl-vectors.html).

---

## Limitations

- **Type-based representations only.** The app visualises fastText Common Crawl vectors, which are static (one vector per word form). Context-sensitive variation within a word's usage is not captured.
- **Training corpus bias.** The models reflect the distributional patterns of Wikipedia and Common Crawl. Results may not generalise to historical corpora, specialist registers, or non-standard varieties.
- **Small word lists.** t-SNE requires at least 4 data points and becomes most informative with 15–100 words. Very large lists produce cluttered plots; hierarchical clustering or MCA is more appropriate in that regime.
- **Local execution only.** The app is designed to run locally. It is not configured for deployment to shinyapps.io or a server, primarily because the model files cannot be bundled and the RAM requirements exceed standard cloud tiers.

---

## References

Grave, E., Bojanowski, P., Gupta, P., Joulin, A., & Mikolov, T. (2018). Learning word vectors for 157 languages. *Proceedings of LREC 2018*. arXiv:1802.06893.

Mikolov, T., Grave, E., Bojanowski, P., Puhrsch, C., & Joulin, A. (2017). Advances in pre-training distributed word representations. arXiv:1712.09405.

van der Maaten, L., & Hinton, G. (2008). Visualizing data using t-SNE. *Journal of Machine Learning Research*, 9, 2579–2605.

---

## Related publications

Desagulier, G. (2019). Can word vectors help corpus linguists? *Studia Neophilologica*, 91(2), 219–240. https://doi.org/10.1080/00393274.2019.1616220

Desagulier, G. (2022). Changes in the midst of a construction network: a diachronic construction grammar approach to complex prepositions denoting internal location. *Cognitive Linguistics*, 33(2), 339–386. https://doi.org/10.1515/cog-2021-0128

---

## License

[CC BY-NC 4.0](LICENSE). You are free to use, adapt, and redistribute this software for non-commercial purposes, provided you credit the source.
