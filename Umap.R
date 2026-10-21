library(uwot)
library(ggplot2) 
library(dplyr)
library(cluster)

# =============================================================================
# DUOMENŲ ĮKĖLIMAS
# =============================================================================
failai <- c("aibe_A.csv", "aibe_B.csv", "aibe_C.csv")
if (!all(file.exists(failai))) stop("Nėra csv failų.")

aibe_A <- read.csv("aibe_A.csv")
aibe_B <- read.csv("aibe_B.csv")
aibe_C <- read.csv("aibe_C.csv")

paruosti_iejima <- function(df) {
  pozymiai <- setdiff(names(df), c("id", "class"))
  X <- as.matrix(df[pozymiai])
  stopifnot(!anyNA(X), all(is.finite(X)))
  X
}

X_A <- paruosti_iejima(aibe_A)
X_B <- paruosti_iejima(aibe_B)
X_C <- paruosti_iejima(aibe_C)

dir.create("grafikai", showWarnings = FALSE)
dir.create("rezultatai", showWarnings = FALSE)

k_reiksmes <- c(5, 15, 50)
seklos <- c(42, 123, 2026, 7, 99)
pasirinktas_n <- 15
pasirinktas_md <- 0.1

# =============================================================================
# METRIKŲ FUNKCIJOS
# =============================================================================
atstumu_rangai <- function(X) {
  D <- if (inherits(X, "dist")) as.matrix(X) else as.matrix(dist(X))
  diag(D) <- Inf
  t(apply(D, 1, rank, ties.method = "first"))
}

skaiciuoti_TC <- function(R_X, R_Y, k) {
  N <- nrow(R_X)
  koef <- 2 / (N * k * (2 * N - 3 * k - 1))
  mask_Y <- R_Y <= k; mask_X <- R_X <= k
  bauda_T <- sum((R_X - k) * (mask_Y & !mask_X))
  bauda_C <- sum((R_Y - k) * (mask_X & !mask_Y))
  data.frame(k = k, Trustworthiness = 1 - koef * bauda_T, Continuity = 1 - koef * bauda_C)
}

kaimynysciu_sutapimas <- function(R1, R2, k) mean(rowSums((R1 <= k) & (R2 <= k))) / k

klases_NH <- function(R, klase, k) {
  klase <- as.character(klase)
  mask <- R <= k
  mean(rowSums(outer(klase, klase, "==") & mask) / k)
}

vertinti_atstumus <- function(d_pradiniai, d_lyginami) {
  rho <- cor(d_pradiniai, d_lyginami, method = "spearman")
  mastelis <- sum(d_pradiniai * d_lyginami) / sum(d_lyginami^2)
  stress <- sqrt(sum((d_pradiniai - mastelis * d_lyginami)^2) / sum(d_pradiniai^2))
  data.frame(Spearman = rho, Normalizuotas_Stress = stress)
}

lokali_kokybe <- function(R_X, R_Y, klase) {
  do.call(rbind, lapply(k_reiksmes, function(k) {
    tc <- skaiciuoti_TC(R_X, R_Y, k)
    data.frame(tc, skirtumas_TC = abs(tc$Trustworthiness - tc$Continuity),
               kaimynu_issaugojimas = kaimynysciu_sutapimas(R_X, R_Y, k),
               NH_klase = klases_NH(R_Y, klase, k))
  }))
}

globali_kokybe <- function(d_X, Y, klase) {
  dY_dist <- dist(Y)
  g <- vertinti_atstumus(d_X, as.vector(dY_dist))
  g$Silhouette <- mean(silhouette(as.integer(factor(klase)), dY_dist)[, 3])
  g
}

ivertinti_vienu_zingsniu <- function(Y, R_Y, R_X, d_X, klase, etiketes) {
  data.frame(etiketes, lokali_kokybe(R_X, R_Y, klase), globali_kokybe(d_X, Y, klase), row.names = NULL)
}

vidurkis_sd <- function(df, grupes, rodikliai) {
  df %>% group_by(across(all_of(grupes))) %>%
    summarise(across(all_of(rodikliai), list(vid = mean, sd = sd)), .groups = "drop") %>% as.data.frame()
}

rodikliai_visi <- c("Trustworthiness", "Continuity", "skirtumas_TC", "kaimynu_issaugojimas", 
                    "NH_klase", "Spearman", "Normalizuotas_Stress", "Silhouette")

T_zodziu <- function(x) as.character(cut(x, c(-Inf, 0.80, 0.90, 0.95, Inf), right = FALSE, 
                                         labels = c("silpna", "vidutiniška", "gerai", "labai gerai")))
C_zodziu <- function(x) as.character(cut(x, c(-Inf, 0.85, 0.90, 0.95, 0.98, Inf), right = FALSE, 
                                         labels = c("prasta", "vidutinė", "gera", "labai gera", "beveik idealu")))
NH_zodziu <- function(x) as.character(cut(x, c(-Inf, 0.5, 0.6, 0.8, 0.9, Inf), right = FALSE, 
                                          labels = c("beveik atsitiktinė", "silpnas atsiskyrimas", "vidutinė", "gera", "labai gera")))

pridet_zodzius <- function(suvestine) {
  suvestine$T_vertinimas  <- T_zodziu(suvestine$Trustworthiness_vid)
  suvestine$C_vertinimas  <- C_zodziu(suvestine$Continuity_vid)
  suvestine$NH_vertinimas <- NH_zodziu(suvestine$NH_klase_vid)
  suvestine
}

paleisti_umap <- function(X, n_neighbors = 15, min_dist = 0.01, n_components = 2, 
                          init = "spectral", seed = 42) {
  set.seed(seed)
  uwot::umap(X, n_neighbors = n_neighbors, min_dist = min_dist, n_components = n_components,
             metric = "euclidean", init = init, n_epochs = 250, scale = FALSE,
             n_threads = 1, n_sgd_threads = 1, approx = TRUE, verbose = FALSE)
}

# =============================================================================
# PRADINĖ ERDVĖ
# =============================================================================
rangai_X_A <- atstumu_rangai(X_A); d_X_A <- as.vector(dist(X_A))
rangai_X_B <- atstumu_rangai(X_B); d_X_B <- as.vector(dist(X_B))
rangai_X_C <- atstumu_rangai(X_C); d_X_C <- as.vector(dist(X_C))

# NH pradinėje erdvėje
NH_pradine_A <- data.frame(
  k = k_reiksmes,
  NH_klase_pradineje_A = sapply(k_reiksmes, function(k) klases_NH(rangai_X_A, aibe_A$class, k))
)
write.csv(NH_pradine_A, "rezultatai/umap_A_NH_pradine_erdve.csv", row.names = FALSE)

# =============================================================================
# PARAMETRŲ TINKLELIAI - A, B, C AIBĖMS
# =============================================================================
tinklelis <- expand.grid(n_neighbors = c(5, 15, 50), min_dist = c(0.01, 0.1, 0.5))

skaiciuoti_tinkleli <- function(X, rangai_X, d_X, klase, aibes_pav) {
  tinklelio_lent <- list()
  
  for (i in seq_len(nrow(tinklelis))) {
    n  <- tinklelis$n_neighbors[i]
    md <- tinklelis$min_dist[i]
    
    Y <- paleisti_umap(X, n, md, seed = 42)
    R_Y <- atstumu_rangai(Y)
    tinklelio_lent[[paste0("n", n, "_md", md)]] <- ivertinti_vienu_zingsniu(
      Y, R_Y, rangai_X, d_X, klase,
      data.frame(n_neighbors = n, min_dist = md, sekla = 42)
    )
  }
  
  rez <- do.call(rbind, tinklelio_lent)
  write.csv(rez, sprintf("rezultatai/umap_%s_parametru_tinklelis.csv", aibes_pav), row.names = FALSE)
  
  # Grafikas su visais parametrais
  tinklelio_duomenys <- do.call(rbind, lapply(seq_len(nrow(tinklelis)), function(i) {
    n <- tinklelis$n_neighbors[i]; md <- tinklelis$min_dist[i]
    Y <- paleisti_umap(X, n, md, seed = 42)
    data.frame(UMAP1 = Y[, 1], UMAP2 = Y[, 2], class = klase,
               n_neighbors = factor(n), min_dist = factor(md))
  }))
  
  g <- ggplot(tinklelio_duomenys, aes(UMAP1, UMAP2, color = class)) +
    geom_point(alpha = 0.6, size = 0.5) +
    facet_grid(min_dist ~ n_neighbors, labeller = label_both) +
    labs(title = sprintf("UMAP parametrų tyrimas – %s aibė", aibes_pav), 
         subtitle = "Sėkla = 42", x = "UMAP 1", y = "UMAP 2", color = "Klasė") +
    theme_minimal() + theme(legend.position = "bottom")
  
  ggsave(sprintf("grafikai/umap_%s_parametru_tinklelis.png", aibes_pav), 
         g, width = 14, height = 10, dpi = 200)
  
  # Grafikas tik su skirtingais n (fiksuotas min_dist = 0.1)
  n_duomenys <- do.call(rbind, lapply(c(5, 15, 50), function(n) {
    Y <- paleisti_umap(X, n, 0.1, seed = 42)
    data.frame(UMAP1 = Y[, 1], UMAP2 = Y[, 2], class = klase, n_neighbors = factor(n))
  }))
  
  g_n <- ggplot(n_duomenys, aes(UMAP1, UMAP2, color = class)) +
    geom_point(alpha = 0.6, size = 0.8) +
    facet_wrap(~n_neighbors, nrow = 1, labeller = label_both) +
    labs(title = sprintf("n_neighbors poveikis – %s aibė", aibes_pav),
         subtitle = "min_dist = 0.1 (fiksuota)", x = "UMAP 1", y = "UMAP 2", color = "Klasė") +
    theme_minimal() + theme(legend.position = "bottom")
  
  ggsave(sprintf("grafikai/umap_%s_n_poveikis.png", aibes_pav),
         g_n, width = 16, height = 6, dpi = 200)
  
  rez
}

tinklelis_A <- skaiciuoti_tinkleli(X_A, rangai_X_A, d_X_A, aibe_A$class, "A")
tinklelis_B <- skaiciuoti_tinkleli(X_B, rangai_X_B, d_X_B, aibe_B$class, "B")
tinklelis_C <- skaiciuoti_tinkleli(X_C, rangai_X_C, d_X_C, aibe_C$class, "C")

# =============================================================================
# A AIBĖS STABILUMAS
# =============================================================================
procesuoti_A_sėklą <- function(s) {
  Y <- paleisti_umap(X_A, pasirinktas_n, pasirinktas_md, init = "spectral", seed = s)
  R_Y <- atstumu_rangai(Y)
  metrics <- ivertinti_vienu_zingsniu(Y, R_Y, rangai_X_A, d_X_A, aibe_A$class, 
                                      data.frame(inicializacija = "spectral", sekla = s, 
                                                 n_neighbors = pasirinktas_n, min_dist = pasirinktas_md))
  list(Y = Y, metrics = metrics)
}

rezultatai_A_list <- lapply(seklos, procesuoti_A_sėklą)
stab_A_metrics <- do.call(rbind, lapply(rezultatai_A_list, function(x) x$metrics))
write.csv(stab_A_metrics, "rezultatai/umap_A_stabilumas.csv", row.names = FALSE)
write.csv(pridet_zodzius(vidurkis_sd(stab_A_metrics, c("inicializacija", "k"), rodikliai_visi)), 
          "rezultatai/umap_A_stabilumo_suvestine.csv", row.names = FALSE)

sekl_duomenys_A <- do.call(rbind, lapply(seq_along(seklos), function(i) {
  data.frame(UMAP1 = rezultatai_A_list[[i]]$Y[, 1], UMAP2 = rezultatai_A_list[[i]]$Y[, 2], 
             class = aibe_A$class, sekla = factor(seklos[i]))
}))

# =============================================================================
# B IR C AIBIU ANALIZĖ
# =============================================================================
procesuoti_B_sėklą <- function(s) {
  Y <- paleisti_umap(X_B, pasirinktas_n, pasirinktas_md, seed = s)
  R_Y <- atstumu_rangai(Y)
  rbind(
    ivertinti_vienu_zingsniu(Y, R_Y, rangai_X_B, d_X_B, aibe_B$class, data.frame(atskaitos_erdve = "B", sekla = s)),
    ivertinti_vienu_zingsniu(Y, R_Y, rangai_X_A, d_X_A, aibe_B$class, data.frame(atskaitos_erdve = "A", sekla = s))
  )
}
rez_B_metrics <- do.call(rbind, lapply(seklos, procesuoti_B_sėklą))
write.csv(rez_B_metrics, "rezultatai/umap_B_kokybe.csv", row.names = FALSE)
write.csv(vidurkis_sd(rez_B_metrics, c("atskaitos_erdve", "k"), rodikliai_visi), 
          "rezultatai/umap_B_suvestine.csv", row.names = FALSE)

indeksai_A <- match(aibe_C$id, aibe_A$id)
X_A_bendri <- X_A[indeksai_A, , drop = FALSE]
rangai_X_A_bendri <- atstumu_rangai(X_A_bendri)
d_X_A_bendri <- as.vector(dist(X_A_bendri))

procesuoti_C_sėklą <- function(s) {
  Y_C <- paleisti_umap(X_C, pasirinktas_n, pasirinktas_md, seed = s)
  R_Y_C <- atstumu_rangai(Y_C)
  
  Y_A_b <- paleisti_umap(X_A, pasirinktas_n, pasirinktas_md, init = "spectral", seed = s)[indeksai_A, , drop = FALSE]
  R_Y_A_b <- atstumu_rangai(Y_A_b)
  
  lokali <- do.call(rbind, list(
    data.frame(palyginimas = "A_proj_A_bendri", sekla = s, lokali_kokybe(rangai_X_A_bendri, R_Y_A_b, aibe_C$class)),
    data.frame(palyginimas = "C_proj_A_bendri", sekla = s, lokali_kokybe(rangai_X_A_bendri, R_Y_C, aibe_C$class)),
    data.frame(palyginimas = "C_proj_C", sekla = s, lokali_kokybe(rangai_X_C, R_Y_C, aibe_C$class))
  ))
  
  d_Y_A_b <- as.vector(dist(Y_A_b)); d_Y_C <- as.vector(dist(Y_C))
  globali <- rbind(
    data.frame(palyginimas = "A_erdve_vs_A_proj", sekla = s, vertinti_atstumus(d_X_A_bendri, d_Y_A_b)),
    data.frame(palyginimas = "A_erdve_vs_C_proj", sekla = s, vertinti_atstumus(d_X_A_bendri, d_Y_C)),
    data.frame(palyginimas = "C_erdve_vs_C_proj", sekla = s, vertinti_atstumus(d_X_C, d_Y_C)),
    data.frame(palyginimas = "A_proj_vs_C_proj", sekla = s, vertinti_atstumus(d_Y_A_b, d_Y_C))
  )
  
  list(lokali = lokali, globali = globali, Y_C = Y_C, Y_A_b = Y_A_b)
}

rez_C_list <- lapply(seklos, procesuoti_C_sėklą)
write.csv(do.call(rbind, lapply(rez_C_list, function(x) x$lokali)), "rezultatai/umap_AC_lokali_kokybe.csv", row.names = FALSE)
write.csv(do.call(rbind, lapply(rez_C_list, function(x) x$globali)), "rezultatai/umap_AC_globalus.csv", row.names = FALSE)

# =============================================================================
# 2D GRAFIKAI
# =============================================================================
braizyti_2d <- function(Y, klase, pav, paantr, failas) {
  df <- data.frame(UMAP1 = Y[, 1], UMAP2 = Y[, 2], class = factor(klase, levels = unique(klase)))
  
  g <- ggplot(df, aes(UMAP1, UMAP2, color = class)) +
    geom_point(alpha = 0.6, size = 0.8) +
    scale_color_manual(values = c("ideal" = "blue", "premium" = "red", "good" = "green", 
                                  "fair" = "orange", "poor" = "purple")[levels(df$class)]) +
    coord_equal() +
    labs(title = pav, subtitle = paantr, x = "UMAP 1", y = "UMAP 2", color = "Klasė") +
    theme_minimal(base_size = 11) + theme(legend.position = "bottom")
  ggsave(failas, g, width = 10, height = 8, dpi = 200)
}

braizyti_2d(rezultatai_A_list[[1]]$Y, aibe_A$class, "UMAP 2D – A aibė (pagrindinė)", 
            "n=15, md=0.1, sėkla=42", "grafikai/umap_2d_A_seed42.png")

g_stab <- ggplot(sekl_duomenys_A, aes(UMAP1, UMAP2, color = class)) +
  geom_point(alpha = 0.6, size = 0.5) + facet_wrap(~sekla, nrow = 1) +
  labs(title = "UMAP stabilumas – A aibė", subtitle = "spectral inicializacija", 
       x = "UMAP 1", y = "UMAP 2", color = "Klasė") +
  theme_minimal() + theme(legend.position = "bottom")
ggsave("grafikai/umap_A_seklu_palyginimas.png", g_stab, width = 16, height = 4, dpi = 200)

Y_B_42 <- paleisti_umap(X_B, pasirinktas_n, pasirinktas_md, seed = 42)
braizyti_2d(Y_B_42, aibe_B$class, "UMAP 2D – B aibė (be koreliuotų)", 
            "n=15, md=0.1, sėkla=42", "grafikai/umap_2d_B_seed42.png")

braizyti_2d(rez_C_list[[1]]$Y_C, aibe_C$class, "UMAP 2D – C aibė (be išskirčių)", 
            "n=15, md=0.1, sėkla=42", "grafikai/umap_2d_C_seed42.png")

# =============================================================================
# 3D GRAFIKAI
# =============================================================================
if (!requireNamespace("scatterplot3d", quietly = TRUE)) 
  install.packages("scatterplot3d", repos = "https://cloud.r-project.org")
library(scatterplot3d)

braizyti_3d <- function(Y, klase, pav, failas) {
  df <- data.frame(UMAP1 = Y[, 1], UMAP2 = Y[, 2], UMAP3 = Y[, 3], 
                   class = factor(klase, levels = unique(klase)))
  
  spalvu_zemėlapis <- c("ideal" = "blue", "premium" = "red", "good" = "green", 
                        "fair" = "orange", "poor" = "purple")
  spalvos <- spalvu_zemėlapis[as.character(df$class)]
  
  png(failas, width = 1200, height = 900, res = 150)
  s3d <- scatterplot3d(df$UMAP1, df$UMAP2, df$UMAP3, color = spalvos, pch = 16, cex.symbols = 0.6,
                       main = pav, xlab = "UMAP 1", ylab = "UMAP 2", zlab = "UMAP 3", 
                       angle = 55, scale.y = 0.7, grid = TRUE, box = TRUE)
  legend("topright", legend = levels(df$class), 
         col = spalvu_zemėlapis[levels(df$class)], pch = 16, cex = 0.8)
  dev.off()
}

braizyti_3d(paleisti_umap(X_A, pasirinktas_n, pasirinktas_md, n_components = 3, seed = 42), 
            aibe_A$class, "UMAP 3D – A aibė", "grafikai/umap_3d_A_seed42.png")
braizyti_3d(paleisti_umap(X_B, pasirinktas_n, pasirinktas_md, n_components = 3, seed = 42), 
            aibe_B$class, "UMAP 3D – B aibė", "grafikai/umap_3d_B_seed42.png")
braizyti_3d(paleisti_umap(X_C, pasirinktas_n, pasirinktas_md, n_components = 3, seed = 42), 
            aibe_C$class, "UMAP 3D – C aibė", "grafikai/umap_3d_C_seed42.png")