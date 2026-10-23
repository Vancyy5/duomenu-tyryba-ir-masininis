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
             n_threads = 1, n_sgd_threads = 1, verbose = FALSE)
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

# A ir B pradinių erdvių palyginimas (tie patys objektai, be projekcijos)
AB_kaimynystes <- data.frame(
  k = k_reiksmes,
  sutapimas = sapply(k_reiksmes, function(k) kaimynysciu_sutapimas(rangai_X_A, rangai_X_B, k))
)
AB_erdves <- vertinti_atstumus(d_X_A, d_X_B)
write.csv(AB_kaimynystes, "rezultatai/AB_pradiniu_kaimynysciu_sutapimas.csv", row.names = FALSE)
write.csv(AB_erdves, "rezultatai/AB_pradiniu_erdviu_atstumai.csv", row.names = FALSE)

# =============================================================================
# PARAMETRŲ TINKLELIAI - A, B, C AIBĖMS
# =============================================================================
tinklelis <- expand.grid(n_neighbors = c(5, 15, 50), min_dist = c(0.01, 0.1, 0.5))

skaiciuoti_tinkleli <- function(X, rangai_X, d_X, klase, aibes_pav) {
  tinklelio_lent <- list()
  tinklelio_Y <- list()
  
  for (i in seq_len(nrow(tinklelis))) {
    n  <- tinklelis$n_neighbors[i]
    md <- tinklelis$min_dist[i]
    vardas <- paste0("n", n, "_md", md)
    
    Y <- paleisti_umap(X, n, md, seed = 42)
    tinklelio_Y[[vardas]] <- Y
    R_Y <- atstumu_rangai(Y)
    tinklelio_lent[[vardas]] <- ivertinti_vienu_zingsniu(
      Y, R_Y, rangai_X, d_X, klase,
      data.frame(n_neighbors = n, min_dist = md, sekla = 42)
    )
  }
  
  rez <- do.call(rbind, tinklelio_lent)
  write.csv(rez, sprintf("rezultatai/umap_%s_parametru_tinklelis.csv", aibes_pav), row.names = FALSE)
  saveRDS(tinklelio_Y, sprintf("rezultatai/umap_%s_tinklelis.rds", aibes_pav))
  
  # Grafikas su visais parametrais (naudojamos jau apskaičiuotos projekcijos)
  tinklelio_duomenys <- do.call(rbind, lapply(seq_len(nrow(tinklelis)), function(i) {
    n <- tinklelis$n_neighbors[i]; md <- tinklelis$min_dist[i]
    Y <- tinklelio_Y[[paste0("n", n, "_md", md)]]
    data.frame(UMAP1 = Y[, 1], UMAP2 = Y[, 2], class = klase,
               n_neighbors = factor(n), min_dist = factor(md))
  }))
  
  g <- ggplot(tinklelio_duomenys, aes(UMAP1, UMAP2, color = class)) +
    geom_point(alpha = 0.6, size = 0.5) +
    facet_grid(min_dist ~ n_neighbors, labeller = label_both) +
    labs(title = sprintf("UMAP parametrų tyrimas – %s aibė", aibes_pav), 
         subtitle = "Sėkla = 42", x = "UMAP 1", y = "UMAP 2", color = "Klasė") + coord_equal() +
    theme_minimal() + theme(legend.position = "bottom")
  
  ggsave(sprintf("grafikai/umap_%s_parametru_tinklelis.png", aibes_pav), 
         g, width = 14, height = 10, dpi = 200)
  
  # Grafikas tik su skirtingais n (fiksuotas min_dist = 0.1)
  n_duomenys <- do.call(rbind, lapply(c(5, 15, 50), function(n) {
    Y <- tinklelio_Y[[paste0("n", n, "_md", 0.1)]]
    data.frame(UMAP1 = Y[, 1], UMAP2 = Y[, 2], class = klase, n_neighbors = factor(n))
  }))
  
  g_n <- ggplot(n_duomenys, aes(UMAP1, UMAP2, color = class)) +
    geom_point(alpha = 0.6, size = 0.8) +
    facet_wrap(~n_neighbors, nrow = 1, labeller = label_both) +
    labs(title = sprintf("n_neighbors poveikis – %s aibė", aibes_pav),
         subtitle = "min_dist = 0.1 (fiksuota)", x = "UMAP 1", y = "UMAP 2", color = "Klasė") + coord_equal() +
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
procesuoti_A_sekla <- function(s) {
  Y <- paleisti_umap(X_A, pasirinktas_n, pasirinktas_md, init = "spectral", seed = s)
  R_Y <- atstumu_rangai(Y)
  metrics <- ivertinti_vienu_zingsniu(Y, R_Y, rangai_X_A, d_X_A, aibe_A$class, 
                                      data.frame(inicializacija = "spectral", sekla = s, 
                                                 n_neighbors = pasirinktas_n, min_dist = pasirinktas_md))
  list(Y = Y, metrics = metrics)
}

rezultatai_A_list <- lapply(seklos, procesuoti_A_sekla)
names(rezultatai_A_list) <- as.character(seklos)
saveRDS(lapply(rezultatai_A_list, function(x) x$Y), "rezultatai/umap_A_seklos.rds")

stab_A_metrics <- do.call(rbind, lapply(rezultatai_A_list, function(x) x$metrics))
write.csv(stab_A_metrics, "rezultatai/umap_A_stabilumas.csv", row.names = FALSE)
write.csv(pridet_zodzius(vidurkis_sd(stab_A_metrics, c("inicializacija", "k"), rodikliai_visi)), 
          "rezultatai/umap_A_stabilumo_suvestine.csv", row.names = FALSE)

sekl_duomenys_A <- do.call(rbind, lapply(seq_along(seklos), function(i) {
  data.frame(UMAP1 = rezultatai_A_list[[i]]$Y[, 1], UMAP2 = rezultatai_A_list[[i]]$Y[, 2], 
             class = aibe_A$class, sekla = factor(seklos[i]))
}))

# =============================================================================
# B AIBĖ
# =============================================================================
procesuoti_B_sekla <- function(s) {
  Y <- paleisti_umap(X_B, pasirinktas_n, pasirinktas_md, seed = s)
  R_Y <- atstumu_rangai(Y)
  metrics <- rbind(
    ivertinti_vienu_zingsniu(Y, R_Y, rangai_X_B, d_X_B, aibe_B$class, data.frame(atskaitos_erdve = "B", sekla = s)),
    ivertinti_vienu_zingsniu(Y, R_Y, rangai_X_A, d_X_A, aibe_B$class, data.frame(atskaitos_erdve = "A", sekla = s))
  )
  list(Y = Y, metrics = metrics)
}

rez_B_list <- lapply(seklos, procesuoti_B_sekla)
names(rez_B_list) <- as.character(seklos)
saveRDS(lapply(rez_B_list, function(x) x$Y), "rezultatai/umap_B_seklos.rds")

rez_B_metrics <- do.call(rbind, lapply(rez_B_list, function(x) x$metrics))
write.csv(rez_B_metrics, "rezultatai/umap_B_kokybe.csv", row.names = FALSE)
write.csv(pridet_zodzius(vidurkis_sd(rez_B_metrics, c("atskaitos_erdve", "k"), rodikliai_visi)), 
          "rezultatai/umap_B_suvestine.csv", row.names = FALSE)

sekl_duomenys_B <- do.call(rbind, lapply(seq_along(seklos), function(i) {
  data.frame(UMAP1 = rez_B_list[[i]]$Y[, 1], UMAP2 = rez_B_list[[i]]$Y[, 2],
             class = aibe_B$class, sekla = factor(seklos[i]))
}))
g_stab_B <- ggplot(sekl_duomenys_B, aes(UMAP1, UMAP2, color = class)) +
  geom_point(alpha = 0.6, size = 0.5) + facet_wrap(~sekla, nrow = 1) + coord_equal() +
  labs(title = "UMAP stabilumas – B aibė", subtitle = "spectral inicializacija",
       x = "UMAP 1", y = "UMAP 2", color = "Klasė") +
  theme_minimal() + theme(legend.position = "bottom")
ggsave("grafikai/umap_B_seklu_palyginimas.png", g_stab_B, width = 16, height = 4, dpi = 200)
# =============================================================================
# C AIBĖ (palyginimas tik su bendrais objektais)
# =============================================================================
indeksai_A <- match(aibe_C$id, aibe_A$id)
X_A_bendri <- X_A[indeksai_A, , drop = FALSE]
rangai_X_A_bendri <- atstumu_rangai(X_A_bendri)
d_X_A_bendri <- as.vector(dist(X_A_bendri))

# A (bendri objektai) ir C pradinių erdvių palyginimas, be projekcijos
AC_erdves_sutapimas <- data.frame(
  k = k_reiksmes,
  sutapimas = sapply(k_reiksmes, function(k) kaimynysciu_sutapimas(rangai_X_A_bendri, rangai_X_C, k))
)
AC_erdves_globalus <- vertinti_atstumus(d_X_A_bendri, d_X_C)
write.csv(AC_erdves_sutapimas, "rezultatai/AC_pradiniu_erdviu_kaimynysciu_sutapimas.csv", row.names = FALSE)
write.csv(AC_erdves_globalus, "rezultatai/AC_pradiniu_erdviu_globalus.csv", row.names = FALSE)

procesuoti_C_sekla <- function(s) {
  Y_C <- paleisti_umap(X_C, pasirinktas_n, pasirinktas_md, seed = s)
  R_Y_C <- atstumu_rangai(Y_C)
  
  # A projekcija (ta pati sėkla), palikti tik bendri objektai
  Y_A_b <- rezultatai_A_list[[as.character(s)]]$Y[indeksai_A, , drop = FALSE]
  R_Y_A_b <- atstumu_rangai(Y_A_b)
  
  # Lokali kokybė (įskaitant C projekciją C erdvės atžvilgiu)
  lokali <- do.call(rbind, list(
    data.frame(palyginimas = "A_proj_A_bendri", sekla = s, lokali_kokybe(rangai_X_A_bendri, R_Y_A_b, aibe_C$class)),
    data.frame(palyginimas = "C_proj_A_bendri", sekla = s, lokali_kokybe(rangai_X_A_bendri, R_Y_C, aibe_C$class)),
    data.frame(palyginimas = "C_proj_C", sekla = s, lokali_kokybe(rangai_X_C, R_Y_C, aibe_C$class))
  ))
  
  # Globali kokybė
  d_Y_A_b <- as.vector(dist(Y_A_b)); d_Y_C <- as.vector(dist(Y_C))
  globali <- rbind(
    data.frame(palyginimas = "A_erdve_vs_A_proj", sekla = s, vertinti_atstumus(d_X_A_bendri, d_Y_A_b)),
    data.frame(palyginimas = "A_erdve_vs_C_proj", sekla = s, vertinti_atstumus(d_X_A_bendri, d_Y_C)),
    data.frame(palyginimas = "C_erdve_vs_C_proj", sekla = s, vertinti_atstumus(d_X_C, d_Y_C)),
    data.frame(palyginimas = "A_proj_vs_C_proj", sekla = s, vertinti_atstumus(d_Y_A_b, d_Y_C))
  )
  
  # Projekcijų sutapimas (A projekcija bendri vs C projekcija)
  projekciju_sutapimas <- data.frame(
    sekla = s,
    k = k_reiksmes,
    projekciju_sutapimas = sapply(k_reiksmes, function(k) 
      kaimynysciu_sutapimas(R_Y_A_b, R_Y_C, k))
  )
  
  list(lokali = lokali, globali = globali, 
       projekciju_sutapimas = projekciju_sutapimas,
       Y_C = Y_C, Y_A_b = Y_A_b)
}

rez_C_list <- lapply(seklos, procesuoti_C_sekla)
names(rez_C_list) <- as.character(seklos)
saveRDS(lapply(rez_C_list, function(x) x$Y_C), "rezultatai/umap_C_seklos.rds")

# Išsaugomi žali duomenys
write.csv(do.call(rbind, lapply(rez_C_list, function(x) x$lokali)), 
          "rezultatai/umap_AC_lokali_kokybe.csv", row.names = FALSE)
write.csv(do.call(rbind, lapply(rez_C_list, function(x) x$globali)), 
          "rezultatai/umap_AC_globalus.csv", row.names = FALSE)
write.csv(do.call(rbind, lapply(rez_C_list, function(x) x$projekciju_sutapimas)), 
          "rezultatai/umap_AC_projekciju_sutapimas.csv", row.names = FALSE)

# Suvestinės (vidurkis ± SD)
C_lokali_suv <- pridet_zodzius(vidurkis_sd(
  do.call(rbind, lapply(rez_C_list, function(x) x$lokali)), 
  c("palyginimas", "k"), 
  c("Trustworthiness", "Continuity", "skirtumas_TC", "kaimynu_issaugojimas", "NH_klase")
))

C_globali_suv <- vidurkis_sd(
  do.call(rbind, lapply(rez_C_list, function(x) x$globali)), 
  "palyginimas", 
  c("Spearman", "Normalizuotas_Stress")
)

C_proj_suv <- vidurkis_sd(
  do.call(rbind, lapply(rez_C_list, function(x) x$projekciju_sutapimas)), 
  "k", 
  "projekciju_sutapimas"
)

write.csv(C_lokali_suv, "rezultatai/umap_AC_lokali_suvestine.csv", row.names = FALSE)
write.csv(C_globali_suv, "rezultatai/umap_AC_globalus_suvestine.csv", row.names = FALSE)
write.csv(C_proj_suv, "rezultatai/umap_AC_projekciju_sutapimas_suvestine.csv", row.names = FALSE)

sekl_duomenys_C <- do.call(rbind, lapply(seq_along(seklos), function(i) {
  data.frame(UMAP1 = rez_C_list[[i]]$Y_C[, 1], UMAP2 = rez_C_list[[i]]$Y_C[, 2],
             class = aibe_C$class, sekla = factor(seklos[i]))
}))
g_stab_C <- ggplot(sekl_duomenys_C, aes(UMAP1, UMAP2, color = class)) +
  geom_point(alpha = 0.6, size = 0.5) + facet_wrap(~sekla, nrow = 1) + coord_equal() +
  labs(title = "UMAP stabilumas – C aibė", subtitle = "spectral inicializacija",
       x = "UMAP 1", y = "UMAP 2", color = "Klasė") +
  theme_minimal() + theme(legend.position = "bottom")
ggsave("grafikai/umap_C_seklu_palyginimas.png", g_stab_C, width = 16, height = 4, dpi = 200)
# =============================================================================
# 3D PROJEKCIJOS: A AIBĖ (5 sėklos, metrikos), B ir C (sėkla 42, grafikams)
# =============================================================================
rez_3D_A <- lapply(seklos, function(s) {
  Y3 <- paleisti_umap(X_A, pasirinktas_n, pasirinktas_md, n_components = 3, seed = s)
  metrics <- ivertinti_vienu_zingsniu(Y3, atstumu_rangai(Y3), rangai_X_A, d_X_A, aibe_A$class,
                                      data.frame(dimensija = 3, sekla = s))
  list(Y = Y3, metrics = metrics)
})
names(rez_3D_A) <- as.character(seklos)
saveRDS(lapply(rez_3D_A, function(x) x$Y), "rezultatai/umap_A_3d_seklos.rds")

Y_B_3d <- paleisti_umap(X_B, pasirinktas_n, pasirinktas_md, n_components = 3, seed = 42)
Y_C_3d <- paleisti_umap(X_C, pasirinktas_n, pasirinktas_md, n_components = 3, seed = 42)

# 2D ir 3D palyginimas (A aibė, tie patys parametrai ir sėklos)
stulpeliai_dim <- c("sekla", "k", rodikliai_visi)
dim_rez <- rbind(
  data.frame(dimensija = 2, stab_A_metrics[, stulpeliai_dim]),
  data.frame(dimensija = 3, do.call(rbind, lapply(rez_3D_A, function(x) x$metrics))[, stulpeliai_dim])
)
write.csv(dim_rez, "rezultatai/umap_A_2d_3d.csv", row.names = FALSE)
write.csv(vidurkis_sd(dim_rez, c("dimensija", "k"), rodikliai_visi),
          "rezultatai/umap_A_2d_3d_suvestine.csv", row.names = FALSE)

# =============================================================================
# 2D GRAFIKAI
# =============================================================================
braizyti_2d <- function(Y, klase, pav, paantr, failas) {
  df <- data.frame(UMAP1 = Y[, 1], UMAP2 = Y[, 2], class = klase)
  
  g <- ggplot(df, aes(UMAP1, UMAP2, color = class)) +
    geom_point(alpha = 0.6, size = 0.8) +
    coord_equal() +
    labs(title = pav, subtitle = paantr, x = "UMAP 1", y = "UMAP 2", color = "Klasė") +  coord_equal() +
    theme_minimal(base_size = 11) + theme(legend.position = "bottom")
  ggsave(failas, g, width = 10, height = 8, dpi = 200)
}

parametrai_tekstas <- paste0("n=", pasirinktas_n, ", md=", pasirinktas_md, ", sėkla=42")

braizyti_2d(rezultatai_A_list[["42"]]$Y, aibe_A$class, "UMAP 2D – A aibė (pagrindinė)", 
            parametrai_tekstas, "grafikai/umap_2d_A_seed42.png")

g_stab <- ggplot(sekl_duomenys_A, aes(UMAP1, UMAP2, color = class)) +
  geom_point(alpha = 0.6, size = 0.5) + facet_wrap(~sekla, nrow = 1) + coord_equal() +
  labs(title = "UMAP stabilumas – A aibė", subtitle = "spectral inicializacija", 
       x = "UMAP 1", y = "UMAP 2", color = "Klasė") +
  theme_minimal() + theme(legend.position = "bottom")
ggsave("grafikai/umap_A_seklu_palyginimas.png", g_stab, width = 16, height = 4, dpi = 200)

braizyti_2d(rez_B_list[["42"]]$Y, aibe_B$class, "UMAP 2D – B aibė (be koreliuotų)", 
            parametrai_tekstas, "grafikai/umap_2d_B_seed42.png")

braizyti_2d(rez_C_list[["42"]]$Y_C, aibe_C$class, "UMAP 2D – C aibė (be išskirčių)", 
            parametrai_tekstas, "grafikai/umap_2d_C_seed42.png")

# =============================================================================
# 3D GRAFIKAI
# =============================================================================
if (!requireNamespace("scatterplot3d", quietly = TRUE)) 
  install.packages("scatterplot3d", repos = "https://cloud.r-project.org")
library(scatterplot3d)

braizyti_3d <- function(Y, klase, pav, failas) {
  # Tos pačios spalvos kaip numatytosios ggplot paletės 2D grafikuose
  lygiai <- sort(unique(as.character(klase)))
  palete <- setNames(scales::hue_pal()(length(lygiai)), lygiai)
  spalvos <- adjustcolor(palete[as.character(klase)], alpha.f = 0.6)
  
  png(failas, width = 1200, height = 900, res = 150)
  s3d <- scatterplot3d(Y[, 1], Y[, 2], Y[, 3], color = spalvos, pch = 16, cex.symbols = 0.6,
                       main = pav, xlab = "UMAP 1", ylab = "UMAP 2", zlab = "UMAP 3", 
                       angle = 55, scale.y = 0.7, grid = TRUE, box = TRUE)
  legend("topright", legend = lygiai, col = palete, pch = 16, cex = 0.8, title = "Klasė")
  dev.off()
}

braizyti_3d(rez_3D_A[["42"]]$Y, aibe_A$class, "UMAP 3D – A aibė", "grafikai/umap_3d_A_seed42.png")
braizyti_3d(Y_B_3d, aibe_B$class, "UMAP 3D – B aibė", "grafikai/umap_3d_B_seed42.png")
braizyti_3d(Y_C_3d, aibe_C$class, "UMAP 3D – C aibė", "grafikai/umap_3d_C_seed42.png")