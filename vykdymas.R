
# ============================================================
# 3 DARBAS. DIMENSIJOS MAZINIMAS KLASTERIZAVIME
# Originalios C aibes paruosimas IDENTISKAS 2 darbui
# ============================================================


# 1. REIKALINGI PAKETAI ---------------------------------------

paketai <- c("ggplot2", "dplyr", "Rtsne")

for (pkg in paketai) {
  # Trukstamus paketus idiegiame
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}


# 2. PAGRINDINIAI PARAMETRAI ----------------------------------

SEED <- 42
PCA_SLENKSTIS <- 0.95
TSNE_PERPLEXITY <- 30
TSNE_ITER <- 1000

OUT <- "aibes"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)


# 3. ORIGINALUS 2 DARBO DUOMENU PARUOSIMAS ---------------------

# Nuskaitome ankstesnio darbo vykdymas.R is Git.
# Taip panaudojame tiksliai ta pati duomenu paruosimo koda.

senas_kodas <- system2(
  "git",
  c("show", "origin/2_darbas:vykdymas.R"),
  stdout = TRUE,
  stderr = TRUE
)

if (!is.null(attr(senas_kodas, "status"))) {
  stop(
    paste(
      "Nepavyko nuskaityti 2 darbo kodo:",
      paste(senas_kodas, collapse = "\n")
    )
  )
}

# Randame eilute, kurioje 2 darbe galutinai parengta C aibe.
riba <- grep(
  "aibe_C <- robust_scale(deimantai_be_ekstremumu)",
  senas_kodas,
  fixed = TRUE
)

if (length(riba) != 1) {
  stop("Nepavyko rasti originalios C aibes paruosimo dalies")
}

# Vykdome originalu koda iki C aibes sudarymo.
# Neperrasome ir nekeiciame jokiu 2 darbo valymo taisykliu.

eval(
  parse(
    text = paste(senas_kodas[seq_len(riba)], collapse = "\n")
  ),
  envir = .GlobalEnv
)


# 4. ORIGINALIOS C AIBES PATIKRINIMAS --------------------------

# Originali C aibe jau yra paruosta ir normuota.
# I dimensijos mazinimo algoritmus neitraukiame ID ir klases.

pozymiai <- setdiff(names(aibe_C), c("id", "class"))

X <- as.matrix(aibe_C[, pozymiai, drop = FALSE])

id <- aibe_C$id
klase <- aibe_C$class

stopifnot(
  !anyNA(X),
  all(is.finite(X)),
  ncol(X) == 19,
  nrow(X) == 3928
)

cat("\nOriginali C aibe is 2 darbo:\n")
cat("Objektu:", nrow(X), "\n")
cat("Pozymiu:", ncol(X), "\n")
cat("Pasalinta ekstremaliu objektu:",
    sum(eilutes_su_ekstremumais), "\n")


# 5. PCA DIMENSIJOS MAZINIMAS ---------------------------------

# PCA atliekame originaliai normuotai C aibei.

pca <- prcomp(
  X,
  center = TRUE,
  scale. = FALSE
)

# Apskaiciuojame paaiskinta dispersija.
dispersija <- pca$sdev^2 / sum(pca$sdev^2)

disp_lent <- data.frame(
  komponente = seq_along(dispersija),
  dispersija = dispersija,
  kaupiamoji = cumsum(dispersija)
)

# Parenkame maziausia komponenčiu skaiciu,
# kuriam sukaupta dispersija siekia bent 95 %.
k_pca <- which(
  disp_lent$kaupiamoji >= PCA_SLENKSTIS
)[1]

X_pca <- pca$x[
  , seq_len(k_pca), drop = FALSE
]

colnames(X_pca) <- paste0("PC", seq_len(k_pca))

cat("\nPCA rezultatai:\n")
cat("Komponenciu skaicius:", k_pca, "\n")
cat(
  "Paaiskinta dispersija:",
  round(disp_lent$kaupiamoji[k_pca] * 100, 2),
  "%\n"
)


# 6. t-SNE DIMENSIJOS MAZINIMAS -------------------------------

# t-SNE taikome tai paciai originaliai C aibei.
# Rezultatas - 2 dimensijos.

set.seed(SEED)

X_tsne <- Rtsne(
  X,
  dims = 2,
  perplexity = TSNE_PERPLEXITY,
  max_iter = TSNE_ITER,
  pca = FALSE,
  normalize = FALSE,
  verbose = TRUE,
  check_duplicates = FALSE
)$Y

colnames(X_tsne) <- c("TSNE1", "TSNE2")


# 7. TRIJU DUOMENU AIBIU ISSAUGOJIMAS --------------------------

issaugoti <- function(M, vardas) {
  
  rezultatas <- data.frame(
    id = id,
    class = klase,
    as.data.frame(M),
    check.names = FALSE
  )
  
  write.csv(
    rezultatas,
    file.path(OUT, vardas),
    row.names = FALSE
  )
}

# Originali C aibe
issaugoti(X, "aibe_originali.csv")

# PCA sumazintos dimensijos aibe
issaugoti(X_pca, "aibe_PCA.csv")

# t-SNE 2D aibe
issaugoti(X_tsne, "aibe_tSNE_2D.csv")


# 8. PAPILDOMI FAILAI -----------------------------------------

# Originalus mastelis reikalingas klasteriu interpretacijai.
write.csv(
  deimantai_be_ekstremumu,
  file.path(OUT, "C_originaliais_vienetais_interpretacijai.csv"),
  row.names = FALSE
)

# PCA dispersijos lentele
write.csv(
  disp_lent,
  file.path(OUT, "pca_dispersija.csv"),
  row.names = FALSE
)

# PCA komponenčiu apkrovos
apkrovos <- data.frame(
  pozymis = rownames(pca$rotation),
  pca$rotation[, seq_len(k_pca), drop = FALSE],
  check.names = FALSE
)

write.csv(
  apkrovos,
  file.path(OUT, "pca_apkrovos.csv"),
  row.names = FALSE
)


# 9. GALUTINE PATIKRA -----------------------------------------

stopifnot(
  nrow(X) == nrow(X_pca),
  nrow(X) == nrow(X_tsne)
)

cat("\n====================================\n")
cat("BAIGTA: SUKURTOS 3 DUOMENU AIBES\n")
cat("====================================\n")

cat("1. Originali:",
    nrow(X), "objektu,",
    ncol(X), "pozymiu\n")

cat("2. PCA:",
    nrow(X_pca), "objektu,",
    ncol(X_pca), "komponenciu\n")

cat("3. t-SNE:",
    nrow(X_tsne), "objektu,",
    ncol(X_tsne), "dimensijos\n")

cat("\nFailai issaugoti aplanke:", OUT, "\n")

