# papildo tsne.R. 
#
# tsne.R neturėjo:
#   1. A aibė, 2D: NH ir Silhouette 
#   2. A aibė, 3D: 5 sėklos vietoj vienos
#   3. B aibė: 5 sėklos, vertinimas B ir A erdvės atžvilgiu
#   4. C aibė: 5 sėklos, A/C palyginimas tik su bendrais objektais

library(Rtsne)
library(cluster)

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

dir.create("rezultatai", showWarnings = FALSE)

k_reiksmes <- c(5, 15, 50)
seklos <- c(42, 123, 2026, 7, 99)
perplexity_pasirinktas <- 30

# ---
# METRIKŲ FUNKCIJOS (tos pačios kaip umap.R)
# ---

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
  rez <- do.call(rbind, lapply(split(df, df[grupes], drop = TRUE), function(d) {
    out <- d[1, grupes, drop = FALSE]
    for (r in rodikliai) {
      out[[paste0(r, "_vid")]] <- mean(d[[r]])
      out[[paste0(r, "_sd")]]  <- sd(d[[r]])
    }
    out
  }))
  rownames(rez) <- NULL
  rez
}

rodikliai_visi <- c("Trustworthiness", "Continuity", "skirtumas_TC", "kaimynu_issaugojimas",
                    "NH_klase", "Spearman", "Normalizuotas_Stress", "Silhouette")

paleisti_tsne <- function(X, dims = 2, perplexity = perplexity_pasirinktas, seed = 42) {
  set.seed(seed)
  Rtsne(X, dims = dims, perplexity = perplexity, max_iter = 1000,
        pca = FALSE, normalize = FALSE, verbose = FALSE)
}

# ---
# PRADINĖS ERDVĖS
# ---

rangai_X_A <- atstumu_rangai(X_A); d_X_A <- as.vector(dist(X_A))
rangai_X_B <- atstumu_rangai(X_B); d_X_B <- as.vector(dist(X_B))
rangai_X_C <- atstumu_rangai(X_C); d_X_C <- as.vector(dist(X_C))

# ---
# A AIBĖ, 2D: 5 sėklos + NH + Silhouette
# ---

tsne_A_Y <- list()
tsne_A_metrics <- list()
for (s in seklos) {
  message("t-SNE A 2D: sėkla ", s, "  ", format(Sys.time(), "%H:%M:%S"))
  t <- paleisti_tsne(X_A, 2, seed = s)
  tsne_A_Y[[as.character(s)]] <- t$Y
  tsne_A_metrics[[as.character(s)]] <- ivertinti_vienu_zingsniu(
    t$Y, atstumu_rangai(t$Y), rangai_X_A, d_X_A, aibe_A$class,
    data.frame(sekla = s, perplexity = perplexity_pasirinktas, KL = tail(t$itercosts, 1)))
}
saveRDS(tsne_A_Y, "rezultatai/tsne_A_5seklos_Y.rds")
stab_A <- do.call(rbind, tsne_A_metrics)
write.csv(stab_A, "rezultatai/tsne_A_stabilumas_pilnas.csv", row.names = FALSE)
write.csv(vidurkis_sd(stab_A, "k", rodikliai_visi),
          "rezultatai/tsne_A_stabilumo_suvestine_pilna.csv", row.names = FALSE)

# ---
# A AIBĖ, 3D: 5 sėklos
# ---

tsne_3D_metrics <- list()
for (s in seklos) {
  message("t-SNE A 3D: sėkla ", s, "  ", format(Sys.time(), "%H:%M:%S"))
  t <- paleisti_tsne(X_A, 3, seed = s)
  tsne_3D_metrics[[as.character(s)]] <- ivertinti_vienu_zingsniu(
    t$Y, atstumu_rangai(t$Y), rangai_X_A, d_X_A, aibe_A$class,
    data.frame(dimensija = 3, sekla = s))
}
stulpeliai_dim <- c("sekla", "k", rodikliai_visi)
dim_rez <- rbind(
  data.frame(dimensija = 2, stab_A[, stulpeliai_dim]),
  data.frame(dimensija = 3, do.call(rbind, tsne_3D_metrics)[, stulpeliai_dim])
)
write.csv(dim_rez, "rezultatai/tsne_A_2d_3d.csv", row.names = FALSE)
write.csv(vidurkis_sd(dim_rez, c("dimensija", "k"), rodikliai_visi),
          "rezultatai/tsne_A_2d_3d_suvestine.csv", row.names = FALSE)

# ---
# B AIBĖ: 5 sėklos, vertinimas B ir A erdvės atžvilgiu
# ---

tsne_B_Y <- list(); tsne_B_metrics <- list()
for (s in seklos) {
  message("t-SNE B: sėkla ", s, "  ", format(Sys.time(), "%H:%M:%S"))
  t <- paleisti_tsne(X_B, 2, seed = s)
  R_Y <- atstumu_rangai(t$Y)
  tsne_B_Y[[as.character(s)]] <- t$Y
  tsne_B_metrics[[as.character(s)]] <- rbind(
    ivertinti_vienu_zingsniu(t$Y, R_Y, rangai_X_B, d_X_B, aibe_B$class, data.frame(atskaitos_erdve = "B", sekla = s)),
    ivertinti_vienu_zingsniu(t$Y, R_Y, rangai_X_A, d_X_A, aibe_B$class, data.frame(atskaitos_erdve = "A", sekla = s))
  )
}
saveRDS(tsne_B_Y, "rezultatai/tsne_B_5seklos_Y.rds")
rez_B <- do.call(rbind, tsne_B_metrics)
write.csv(rez_B, "rezultatai/tsne_B_kokybe_5seklos.csv", row.names = FALSE)
write.csv(vidurkis_sd(rez_B, c("atskaitos_erdve", "k"), rodikliai_visi),
          "rezultatai/tsne_B_suvestine.csv", row.names = FALSE)

# ---
# C AIBĖ: 5 sėklos, A/C palyginimas tik su bendrais objektais
# ---

indeksai_A <- match(aibe_C$id, aibe_A$id)
stopifnot(!anyNA(indeksai_A), identical(aibe_A$id[indeksai_A], aibe_C$id))
X_A_bendri <- X_A[indeksai_A, , drop = FALSE]
rangai_X_A_bendri <- atstumu_rangai(X_A_bendri)
d_X_A_bendri <- as.vector(dist(X_A_bendri))

tsne_C_Y <- list(); lok_C <- list(); glob_C <- list(); proj_C <- list()
for (s in seklos) {
  message("t-SNE C: sėkla ", s, "  ", format(Sys.time(), "%H:%M:%S"))
  Y_C <- paleisti_tsne(X_C, 2, seed = s)$Y
  tsne_C_Y[[as.character(s)]] <- Y_C
  R_Y_C <- atstumu_rangai(Y_C)
  Y_A_b <- tsne_A_Y[[as.character(s)]][indeksai_A, , drop = FALSE]
  R_Y_A_b <- atstumu_rangai(Y_A_b)
  
  lok_C[[as.character(s)]] <- rbind(
    data.frame(palyginimas = "A_proj_A_bendri", sekla = s, lokali_kokybe(rangai_X_A_bendri, R_Y_A_b, aibe_C$class)),
    data.frame(palyginimas = "C_proj_A_bendri", sekla = s, lokali_kokybe(rangai_X_A_bendri, R_Y_C, aibe_C$class)),
    data.frame(palyginimas = "C_proj_C", sekla = s, lokali_kokybe(rangai_X_C, R_Y_C, aibe_C$class))
  )
  d_Y_A_b <- as.vector(dist(Y_A_b)); d_Y_C <- as.vector(dist(Y_C))
  glob_C[[as.character(s)]] <- rbind(
    data.frame(palyginimas = "A_erdve_vs_A_proj", sekla = s, vertinti_atstumus(d_X_A_bendri, d_Y_A_b)),
    data.frame(palyginimas = "A_erdve_vs_C_proj", sekla = s, vertinti_atstumus(d_X_A_bendri, d_Y_C)),
    data.frame(palyginimas = "C_erdve_vs_C_proj", sekla = s, vertinti_atstumus(d_X_C, d_Y_C)),
    data.frame(palyginimas = "A_proj_vs_C_proj", sekla = s, vertinti_atstumus(d_Y_A_b, d_Y_C))
  )
  proj_C[[as.character(s)]] <- data.frame(
    sekla = s, k = k_reiksmes,
    projekciju_sutapimas = sapply(k_reiksmes, function(k) kaimynysciu_sutapimas(R_Y_A_b, R_Y_C, k)))
}
saveRDS(tsne_C_Y, "rezultatai/tsne_C_5seklos_Y.rds")
lok_C <- do.call(rbind, lok_C); glob_C <- do.call(rbind, glob_C); proj_C <- do.call(rbind, proj_C)
write.csv(lok_C, "rezultatai/tsne_AC_lokali_kokybe_5seklos.csv", row.names = FALSE)
write.csv(glob_C, "rezultatai/tsne_AC_globalus_5seklos.csv", row.names = FALSE)
write.csv(proj_C, "rezultatai/tsne_AC_projekciju_sutapimas_5seklos.csv", row.names = FALSE)

write.csv(vidurkis_sd(lok_C, c("palyginimas", "k"),
                      c("Trustworthiness", "Continuity", "skirtumas_TC", "kaimynu_issaugojimas", "NH_klase")),
          "rezultatai/tsne_AC_lokali_suvestine.csv", row.names = FALSE)
write.csv(vidurkis_sd(glob_C, "palyginimas", c("Spearman", "Normalizuotas_Stress")),
          "rezultatai/tsne_AC_globalus_suvestine.csv", row.names = FALSE)
write.csv(vidurkis_sd(proj_C, "k", "projekciju_sutapimas"),
          "rezultatai/tsne_AC_projekciju_sutapimas_suvestine.csv", row.names = FALSE)
