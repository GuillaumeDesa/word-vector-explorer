library(shiny)
library(fastTextR)
library(Rtsne)
library(ggplot2)
library(dplyr)
library(shinythemes)
library(R.utils)      # for fast gunzip
library(ggrepel)      # for non-overlapping labels (install if needed)

# ---------------------------------------------------------------------------
# Language metadata
# ---------------------------------------------------------------------------
lang_data <- c(
  "English"  = "en", "French"  = "fr", "German"  = "de",
  "Spanish"  = "es", "Italian" = "it", "Chinese" = "zh", "Albanian" = "sq"
)

suggestions <- list(
  en = "king, queen, man, woman, dog, cat, apple, orange, computer, laptop",
  fr = "roi, reine, homme, femme, chien, chat, marron, brun, bleu, rouge",
  de = "König, Königin, Mann, Frau, Hund, Katze, Apfel, Orange, Computer, Laptop",
  es = "rey, reina, hombre, mujer, perro, gato, manzana, naranja, ordenador, portátil",
  it = "re, regina, uomo, donna, cane, gatto, mela, arancia, computer, portatile",
  zh = "国王, 女王, 男人, 女人, 狗, 猫, 苹果, 橙子, 电脑, 笔记本电脑",
  sq = "mbret, mbretëreshë, burrë, grua, qen, mace, mollë, portokall, kompjuter, laptop"
)

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
ui <- fluidPage(
  theme = shinythemes::shinytheme("flatly"),

  titlePanel("fastText Word Vector Explorer"),
  p("Visualise multilingual distributional semantic models (DSMs) from ",
    a("fastText", href = "https://fasttext.cc/docs/en/crawl-vectors.html",
      target = "_blank"), " using t-SNE."),

  sidebarLayout(
    sidebarPanel(width = 4,

      # ── STEP 1: language & download ──────────────────────────────────────
      h4("① Language & Model"),
      selectInput("dl_lang", "Language:", choices = names(lang_data)),
      textInput("dest_folder", "Local folder for model files:", value = getwd()),
      helpText("The .bin file is several GB. Downloads may take 10–30 min."),
      actionButton("download_btn", "Download / Check Model",
                   class = "btn-success btn-block", icon = icon("download")),
      br(),

      # ── STEP 2: load ─────────────────────────────────────────────────────
      h4("② Load Model"),
      textInput("active_model_path", "Path to .bin file:", value = ""),
      helpText("Path is auto-filled when you select a language and folder above."),
      actionButton("load_model_btn", "Load Model into RAM",
                   class = "btn-warning btn-block", icon = icon("database")),
      br(),

      # ── STEP 3: words ────────────────────────────────────────────────────
      h4("③ Words to Plot"),
      textAreaInput("word_list",
                    label = "Word list (comma-separated):",
                    value = "", rows = 5),
      helpText("Minimum 4 words required for t-SNE. OOV words are removed automatically."),
      uiOutput("word_count_ui"),
      br(),

      # ── STEP 4: t-SNE & style controls ───────────────────────────────────
      h4("④ Plot Settings"),
      sliderInput("perp",       "t-SNE Perplexity:",  min = 2,  max = 50, value = 5),
      sliderInput("label_size", "Label font size:",   min = 2,  max = 12, value = 4, step = 0.5),
      sliderInput("point_size", "Point size:",        min = 1,  max = 8,  value = 2, step = 0.5),
      checkboxInput("repel_labels", "Avoid overlapping labels (ggrepel)", value = TRUE),
      br(),
      actionButton("plot_btn", "Generate Visualisation",
                   class = "btn-primary btn-block", icon = icon("chart-scatter")),
      br(),

      # ── STEP 5: export ───────────────────────────────────────────────────
      h4("⑤ Export"),
      sliderInput("export_dpi", "PNG resolution (DPI):", min = 72, max = 300,
                  value = 150, step = 1),
      sliderInput("export_w",   "Width (inches):",  min = 4, max = 20, value = 10, step = 0.5),
      sliderInput("export_h",   "Height (inches):", min = 4, max = 20, value = 7,  step = 0.5),
      downloadButton("dl_png", "Download plot as PNG", class = "btn-info btn-block")
    ),

    mainPanel(width = 8,
      # status bar
      wellPanel(
        style = "background:#f0f4f8; padding:8px 14px; margin-bottom:10px;",
        icon("circle-info"),
        strong(" Status: "),
        textOutput("status_msg", inline = TRUE)
      ),
      # OOV warning (hidden when empty)
      uiOutput("oov_warning_ui"),
      # plot
      plotOutput("tsne_plot", height = "580px")
    )
  )
)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
server <- function(input, output, session) {

  v <- reactiveValues(
    model       = NULL,
    loaded_lang = NULL,   # language code of the currently loaded model
    last_plot   = NULL,   # ggplot object for PNG export
    status      = "Ready. Please select a language and download/load a model."
  )

  # ── Auto-fill model path whenever language OR folder changes ─────────────
  observeEvent(list(input$dl_lang, input$dest_folder), {
    lang_code <- lang_data[[input$dl_lang]]
    updateTextInput(session, "active_model_path",
                    value = file.path(input$dest_folder,
                                      paste0("cc.", lang_code, ".300.bin")))
  }, ignoreNULL = TRUE)

  # ── DOWNLOAD ─────────────────────────────────────────────────────────────
  observeEvent(input$download_btn, {
    old_timeout <- getOption("timeout")
    options(timeout = 3600) # Set to 1 hour
    lang_code <- lang_data[[input$dl_lang]]
    dest_bin  <- file.path(input$dest_folder, paste0("cc.", lang_code, ".300.bin"))
    dest_gz   <- paste0(dest_bin, ".gz")
    url       <- paste0("https://dl.fbaipublicfiles.com/fasttext/vectors-crawl/cc.",
                        lang_code, ".300.bin.gz")

    if (file.exists(dest_bin)) {
      v$status <- paste0("✔ Model already exists: ", dest_bin, ". Ready to load.")
      return()
    }

    if (!dir.exists(input$dest_folder)) {
      v$status <- "✘ Destination folder does not exist. Please create it first."
      return()
    }

    withProgress(message = paste("Downloading", input$dl_lang, "model…"), value = 0.1, {
      tryCatch({
        v$status <- paste("Downloading from", url, "— this may take a while…")
        download.file(url, destfile = dest_gz, mode = "wb", quiet = FALSE)
        incProgress(0.6, message = "Decompressing .gz file…")
        R.utils::gunzip(dest_gz, destname = dest_bin, remove = TRUE, overwrite = TRUE)
        incProgress(0.3, message = "Done.")
        v$status <- paste0("✔ Download complete: ", dest_bin)
      }, error = function(e) {
        v$status <- paste("✘ Download error:", e$message)
      })
    })
  })

  # ── LOAD MODEL ───────────────────────────────────────────────────────────
  observeEvent(input$load_model_btn, {
    path <- trimws(input$active_model_path)
    if (!nzchar(path) || !file.exists(path)) {
      v$status <- "✘ File not found. Check the path and try again."
      return()
    }

    v$status <- "Loading model into RAM… (may take 1–3 min for large .bin files)"
    tryCatch({
      v$model <- NULL
      gc()
      v$model <- ft_load(path)

      # Infer language from filename (cc.XX.300.bin pattern)
      m <- regmatches(basename(path), regexpr("(?<=cc\\.)..(?=\\.300\\.bin)", basename(path), perl = TRUE))
      v$loaded_lang <- if (length(m) == 1) m else lang_data[[input$dl_lang]]

      # Update suggestions to match loaded model's language
      suggestion_text <- suggestions[[v$loaded_lang]]
      if (!is.null(suggestion_text))
        updateTextAreaInput(session, "word_list", value = suggestion_text)

      lang_name <- names(lang_data)[lang_data == v$loaded_lang]
      if (!length(lang_name)) lang_name <- v$loaded_lang
      v$status <- paste0("✔ ", lang_name, " model loaded. Edit the word list and click Generate.")
    }, error = function(e) {
      v$status <- paste("✘ Load error:", e$message)
    })
  })

  # ── WORD COUNT DISPLAY ───────────────────────────────────────────────────
  parsed_words <- reactive({
    w <- trimws(unlist(strsplit(input$word_list, ",")))
    w[nzchar(w)]
  })

  output$word_count_ui <- renderUI({
    n <- length(parsed_words())
    col <- if (n < 4) "color:red;" else "color:#27ae60;"
    tags$small(style = col, paste(n, "words detected"))
  })

  # ── PLOT ─────────────────────────────────────────────────────────────────
  # Reactive value holding the last rendered ggplot (for PNG export)
  plot_data <- eventReactive(input$plot_btn, {
    req(v$model)

    words <- parsed_words()
    if (length(words) < 4) {
      v$status <- "✘ Please enter at least 4 words."
      return(NULL)
    }

    # Get vectors
    vecs <- tryCatch(ft_word_vectors(v$model, words),
                     error = function(e) { v$status <- paste("✘ Vector error:", e$message); NULL })
    req(!is.null(vecs))

    # Detect OOV: fastText returns all-zero rows for unknown words
    zero_rows <- which(rowSums(abs(as.matrix(vecs))) == 0)
    oov_words  <- if (length(zero_rows)) words[zero_rows] else character(0)
    valid_idx  <- setdiff(seq_along(words), zero_rows)
    words      <- words[valid_idx]
    vecs       <- vecs[valid_idx, , drop = FALSE]

    if (length(words) < 4) {
      v$status <- "✘ Too many OOV words; fewer than 4 valid vectors remain."
      return(list(plot = NULL, oov = oov_words))
    }

    # t-SNE
    max_perp <- floor((length(words) - 1) / 3)
    perp_used <- max(2, min(input$perp, max_perp))
    if (perp_used < input$perp)
      v$status <- paste0("⚠ Perplexity capped at ", perp_used,
                         " (max for ", length(words), " words). ", 
                         if (length(oov_words)) paste("OOV removed:", paste(oov_words, collapse=", ")) else "")
    else
      v$status <- paste0("✔ Plot generated",
                         if (length(oov_words)) paste0(" (OOV removed: ", paste(oov_words, collapse=", "), ")") else ".")

    set.seed(42)
    tsne_out <- Rtsne(as.matrix(vecs), perplexity = perp_used,
                      check_duplicates = FALSE, verbose = FALSE)
    df <- data.frame(x = tsne_out$Y[,1], y = tsne_out$Y[,2], label = words)

    # Build plot
    p <- ggplot(df, aes(x, y, label = label)) +
      geom_point(color = "#2c3e50", size = input$point_size) +
      theme_minimal(base_size = 13) +
      theme(
        axis.title = element_blank(),
        axis.text  = element_blank(),
        axis.ticks = element_blank(),
        panel.grid = element_line(color = "#ecf0f1")
      ) +
      labs(title = paste("t-SNE word vector plot —",
                         names(lang_data)[lang_data == (v$loaded_lang %||% "en")]),
           caption = paste("fastText cc model · perplexity =", perp_used,
                           "· seed = 42"))

    if (isTRUE(input$repel_labels)) {
      p <- p + ggrepel::geom_text_repel(size = input$label_size, fontface = "bold",
                                         max.overlaps = 30,
                                         box.padding  = 0.4,
                                         color        = "#2c3e50")
    } else {
      p <- p + geom_text(size = input$label_size, fontface = "bold",
                          vjust = -1.2, color = "#2c3e50")
    }

    list(plot = p, oov = oov_words)
  })

  # Render to screen
  output$tsne_plot <- renderPlot({
    pd <- plot_data()
    req(!is.null(pd), !is.null(pd$plot))
    v$last_plot <- pd$plot
    pd$plot
  })

  # OOV warning banner
  output$oov_warning_ui <- renderUI({
    pd <- plot_data()
    if (is.null(pd) || !length(pd$oov)) return(NULL)
    div(class = "alert alert-warning",
        icon("triangle-exclamation"),
        strong(" Out-of-vocabulary words removed: "),
        paste(pd$oov, collapse = ", "))
  })

  # ── PNG DOWNLOAD ─────────────────────────────────────────────────────────
  output$dl_png <- downloadHandler(
    filename = function() {
      paste0("tsne_vectors_", v$loaded_lang %||% "model", "_",
             format(Sys.time(), "%Y%m%d_%H%M%S"), ".png")
    },
    content = function(file) {
      pd <- plot_data()
      req(!is.null(pd), !is.null(pd$plot))
      ggsave(file, plot = pd$plot,
             device = "png",
             width  = input$export_w,
             height = input$export_h,
             dpi    = input$export_dpi)
    }
  )

  output$status_msg <- renderText({ v$status })
}

# Null-coalescing helper (base R doesn't have %||% by default)
`%||%` <- function(a, b) if (!is.null(a) && nzchar(a)) a else b

shinyApp(ui, server)
