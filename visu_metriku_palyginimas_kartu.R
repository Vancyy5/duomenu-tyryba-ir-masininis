# =========================================================
# PILNAS VISŲ LENTELĖS PARAMETRŲ SKAIČIAVIMO SKRIPTAS
# =========================================================

library(cluster)

# 1. Pagalbinės funkcijos
atstumu_rangai <- function(X) {
  D <- as.matrix(dist(X))
  diag(D) <- Inf
  N <- nrow(D)
  R <- matrix(0L, nrow = N, ncol = N)
  for (i in seq_len(N)) {
    R[i, order(D[i, ], seq_len(N))] <- seq_len(N)
  }
  R
}

skaiciuoti_TC <- function(R_X, R_Y, k) {
  N <- nrow(R_X)
  bauda_T <- 0
  bauda_C <- 0
  for (i in seq_len(N)) {
    kaimynai_X <- which(R_X[i, ] <= k)
    kaimynai_Y <- which(R_Y[i, ] <= k)
    netikri <- setdiff(kaimynai_Y, kaimynai_X)
    prarasti <- setdiff(kaimynai_X, kaimynai_Y)
    bauda_T <- bauda_T + sum(R_X[i, netikri] - k)
    bauda_C <- bauda_C + sum(R_Y[i, prarasti] - k)
  }
  koeficientas <- 2 / (N * k * (2 * N - 3 * k - 1))
  data.frame(
    k = k,
    Trustworthiness = 1 - koeficientas * bauda_T,
    Continuity = 1 - koeficientas * bauda_C
  )
}
klases_NH <- function(R_Y, klase, k) {
  klase <- as.character(klase)
  mask <- R_Y <= k
  mean(rowSums(outer(klase, klase, "==") & mask) / k)
}

kaimynysciu_sutapimas <- function(R_X, R_Y, k) {
  mean(vapply(seq_len(nrow(R_X)), function(i) {
    length(intersect(which(R_X[i, ] <= k), which(R_Y[i, ] <= k))) / k
  }, numeric(1)))
}

skaiciuoti_silhouette <- function(Y, klase) {
  mean(silhouette(as.integer(factor(klase)), dist(Y))[, 3])
}

knn_tikslumas <- function(R_Y, klase, k) {
  klase <- as.character(klase)
  N <- length(klase)
  teisingi <- vapply(seq_len(N), function(i) {
    kaim <- which(R_Y[i, ] <= k)
    kaim <- kaim[order(R_Y[i, kaim])]      # nuo artimiausio
    dazniai <- table(klase[kaim])
    kandidatai <- names(dazniai)[dazniai == max(dazniai)]
    # lygiųjų atveju laimi artimiausio kaimyno klasė
    pred <- klase[kaim][klase[kaim] %in% kandidatai][1]
    pred == klase[i]
  }, logical(1))
  mean(teisingi)
}

skaiciuoti_cluster_purity <- function(Y, klase) {
  n_klasiu <- length(unique(klase))
  set.seed(42)
  km <- kmeans(Y, centers = n_klasiu, nstart = 20)
  cluster_labels <- km$cluster
  teisingi <- sum(sapply(unique(cluster_labels), function(cl) {
    dažniai <- table(klase[cluster_labels == cl])
    if (length(dažniai) > 0) max(dažniai) else 0
  }))
  teisingi / length(klase)
}

stress1 <- function(pradiniai_atstumai, projekcija) {
  d <- as.vector(pradiniai_atstumai)
  dhat <- as.vector(dist(projekcija))
  mastelis <- sum(d * dhat) / sum(dhat^2)
  sqrt(sum((d - mastelis * dhat)^2) / sum(d^2))
}

# 2. Pagrindinė skaičiavimo funkcija metoduose
generuoti_metoda <- function(Y, X, klase, metodo_pavadinimas) {
  R_X <- atstumu_rangai(X)
  R_Y <- atstumu_rangai(Y)
  d_X <- as.vector(dist(X))
  
  # Globalūs rodikliai (nesikeičia nuo k)
  rho <- cor(d_X, as.vector(dist(Y)), method = "spearman")
  stresas <- stress1(dist(X), Y)
  sil <- skaiciuoti_silhouette(Y, klase)
  purity <- skaiciuoti_cluster_purity(Y, klase)
  
  k_reiksmes <- c(5, 15, 50)
  
  do.call(rbind, lapply(k_reiksmes, function(k) {
    tc <- skaiciuoti_TC(R_X, R_Y, k)
    ki <- kaimynysciu_sutapimas(R_X, R_Y, k)
    nh <- klases_NH(R_Y, klase, k)
    knn <- knn_tikslumas(R_Y, klase, k)
    
    data.frame(
      Metodas = metodo_pavadinimas,
      k = k,
      T = round(tc$Trustworthiness, 4),
      C = round(tc$Continuity, 4),
      Skirtumas_TC = round(abs(tc$Trustworthiness - tc$Continuity), 4),
      KI = round(ki, 4),
      Spearman_rho = round(rho, 4),
      Stress = round(stresas, 4),
      Silhouette = round(sil, 4),
      Cluster_Purity = round(purity, 4),
      NH = round(nh, 4),
      kNN_tikslumas = round(knn, 4)
    )
  }))
}

# =========================================================
# 3. METODŲ APJUNGIMAS (A aibės pagrindu)
# =========================================================

klase <- aibe_A$class

galutine_suvestine <- rbind(
  generuoti_metoda(pca_A$x[, 1:2], X_A, klase, "PCA"),
  generuoti_metoda(mds_A, X_A, klase, "Klasikinis MDS"),
  generuoti_metoda(mds_smacof_A2$conf, X_A, klase, "MDS SMACOF"),
  generuoti_metoda(tsne_A_variantai[["30"]]$Y, X_A, klase, "t-SNE"),
  generuoti_metoda(rezultatai_A_list[["42"]]$Y, X_A, klase, "UMAP")
)

# Rezultatų išvedimas
print(galutine_suvestine)

# Išsaugome į failą
write.csv(galutine_suvestine, "rezultatai/visi_lenteles_parametrai.csv", row.names = FALSE)
cat("\nFailas sėkmingai išsaugotas: rezultatai/visi_lenteles_parametrai.csv\n")