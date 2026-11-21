  # ==============================================================================
# DBSCAN klasterizavimas: originali C aibė (19D), PCA 5D ir t-SNE 2D
# ------------------------------------------------------------------------------
#  0. Paketai, duomenys, bendros funkcijos
#  1. Kiekvienai erdvei (ciklas): eps kelio įvertis, jautrumas, kandidatai, atskaita
#  2. Papildomi tyrimai: 19D mažųjų grupių jautrumas, t-SNE 2 ir 3 klasterių variantai
#  3. Atskaitų palyginimas tarp erdvių
#  4. Stabilumas (80 % imtys): atskaitos procedūra, N pakankamumas, vidiniai matai
#  5. Fiksuotų parametrų kandidatų ir panašios aprėpties variantų stabilumas
#  6. Bendra eksperimentų suvestinė
# Darbo aplankas: tas, kuriame yra aibes/, grafikai/ ir rezultatai/.
# ==============================================================================

# ---- 0. Paketai, duomenys, funkcijos ----------------------------------------

for (p in c("dbscan", "ggplot2", "cluster", "Rtsne")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
library(ggplot2)

dir.create("grafikai", showWarnings = FALSE)
dir.create("rezultatai", showWarnings = FALSE)

rasyti <- function(df, failas) {
  write.csv(df, file.path("rezultatai", failas), row.names = FALSE)
}

issaugoti <- function(g, failas, plotis, aukstis) {
  ggsave(file.path("grafikai", failas), g, width = plotis, height = aukstis,
         units = "in", dpi = 300, bg = "white")
  if (interactive()) print(g)
}

# --- Duomenys (visos aibės suderinamos pagal id) ------------------------------

aibe <- read.csv("aibes/aibe_originali.csv")
stopifnot(all(c("id", "class") %in% names(aibe)),
          !anyNA(aibe$id), !anyDuplicated(aibe$id))

pozymiai <- setdiff(names(aibe), c("id", "class"))
stopifnot(length(pozymiai) == 19L,
          all(vapply(aibe[, pozymiai, drop = FALSE], is.numeric, logical(1))))

x <- as.matrix(aibe[, pozymiai, drop = FALSE])
stopifnot(all(is.finite(x)))

skaityti_suderinta <- function(failas, stulpeliai) {
  d <- read.csv(failas)
  stopifnot(all(c("id", "class", stulpeliai) %in% names(d)),
            !anyNA(d$id), !anyDuplicated(d$id), setequal(aibe$id, d$id))
  d <- d[match(aibe$id, d$id), ]
  stopifnot(identical(aibe$id, d$id), all(aibe$class == d$class))
  d
}

pca_aibe   <- skaityti_suderinta("aibes/aibe_PCA.csv", paste0("PC", 1:5))
tsne_aibe  <- skaityti_suderinta("aibes/aibe_tSNE_2D.csv", c("TSNE1", "TSNE2"))
interp     <- skaityti_suderinta(
  "aibes/C_originaliais_vienetais_interpretacijai.csv", pozymiai)

x_pca  <- as.matrix(pca_aibe[, paste0("PC", 1:5), drop = FALSE])
x_tsne <- as.matrix(tsne_aibe[, c("TSNE1", "TSNE2"), drop = FALSE])
stopifnot(all(is.finite(x_pca)), all(is.finite(x_tsne)))

cat("Objektų:", nrow(x), "| požymių:", ncol(x), "\n")

# --- Bendros skaičiavimo funkcijos --------------------------------------------

paleisti <- function(X, eps, minPts) {
  dbscan::dbscan(X, eps = eps, minPts = minPts, borderPoints = TRUE)$cluster
}

# Klasterių skaičius, triukšmas, dydžiai.
santrauka <- function(z, rusiuoti = FALSE) {
  dyd <- table(z[z > 0])
  if (rusiuoti) dyd <- sort(dyd, decreasing = TRUE)
  data.frame(
    klasteriu_sk = length(dyd),
    triuksmo_sk = sum(z == 0),
    triuksmas_proc = 100 * mean(z == 0),
    didziausio_klasterio_proc = if (length(dyd)) 100 * max(dyd) / sum(dyd) else NA_real_,
    maziausias_klasteris = if (length(dyd)) as.integer(min(dyd)) else NA_integer_,
    klasteriu_dydziai = paste(as.integer(dyd), collapse = "; ")
  )
}

# Geometrinis kelio įvertis: didžiausias nuotolis žemiau tiesės, jungiančios
# normuotos kaimynų atstumų kreivės galus. k = minPts − 1 (minPts apima patį tašką).
kelio_indeksas <- function(d) {
  plotis <- max(d) - min(d)
  if (plotis <= 0) stop("Visi kaimynų atstumai vienodi: kelio įvertis nenustatomas.")
  h <- seq(0, 1, length.out = length(d))
  v <- (d - min(d)) / plotis
  which.max(h - v)
}

kelio_eps <- function(X, minPts) {
  d <- sort(dbscan::kNNdist(X, k = minPts - 1L))
  d[kelio_indeksas(d)]
}

kelio_lentele <- function(X, minPts, rusiuoti = FALSE) {
  do.call(rbind, lapply(minPts, function(m) {
    d <- sort(dbscan::kNNdist(X, k = m - 1L))
    i <- kelio_indeksas(d)
    data.frame(minPts = m, eps_kelio = d[i], objekto_eile = i,
               kreives_proc = 100 * i / length(d),
               santrauka(paleisti(X, d[i], m), rusiuoti))
  }))
}

# Silhouette, Calinski–Harabasz ir Davies–Bouldin be triukšmo (žymė 0).
# D (nebūtina) – iš anksto apskaičiuota pilna atstumų matrica.
vidiniai_matai <- function(X, z, D = NULL) {
  prisk <- which(z > 0)
  Xp <- X[prisk, , drop = FALSE]
  g <- as.integer(factor(z[prisk]))
  n <- nrow(Xp)
  k <- length(unique(g))
  rez <- data.frame(klasteriu_sk = k, vertinta_n = n,
                    Silhouette = NA_real_, CH = NA_real_, DB = NA_real_)
  if (k < 2 || n <= k) return(rez)
  
  dalys <- lapply(seq_len(k), function(c) Xp[g == c, , drop = FALSE])
  centrai <- do.call(rbind, lapply(dalys, colMeans))
  dyd <- vapply(dalys, nrow, integer(1))
  d_iki <- lapply(seq_len(k), function(j) {
    sqrt(rowSums(sweep(dalys[[j]], 2, centrai[j, ], "-")^2))
  })
  
  WSS <- sum(vapply(d_iki, function(d) sum(d^2), numeric(1)))
  BSS <- sum(dyd * rowSums(sweep(centrai, 2, colMeans(Xp), "-")^2))
  if (WSS > 0) rez$CH <- (BSS / (k - 1)) / (WSS / (n - k))
  
  dc <- as.matrix(dist(centrai))
  if (all(dc[upper.tri(dc)] > 0)) {
    s <- vapply(d_iki, mean, numeric(1))
    r <- outer(s, s, "+") / dc
    diag(r) <- -Inf
    rez$DB <- mean(apply(r, 1, max))
  }
  
  Dp <- if (is.null(D)) dist(Xp) else as.dist(D[prisk, prisk, drop = FALSE])
  rez$Silhouette <- mean(cluster::silhouette(g, Dp)[, "sil_width"])
  rez
}

# ARI, NMI (aritmetinis entropijų vidurkis) ir objektų porų Jaccard.
# Kai abu suskirstymai trivialūs (vienas klasteris), ARI laikomas lygiu 1.
suskirstymu_matai <- function(a, b) {
  lent <- table(a, b)
  n <- sum(lent)
  stopifnot(n >= 2)
  
  bendros <- sum(choose(lent, 2))
  poros_a <- sum(choose(rowSums(lent), 2))
  poros_b <- sum(choose(colSums(lent), 2))
  tiketinas <- poros_a * poros_b / choose(n, 2)
  vardiklis <- (poros_a + poros_b) / 2 - tiketinas
  ARI <- if (abs(vardiklis) < 1e-12) 1 else (bendros - tiketinas) / vardiklis
  
  p <- lent / n
  pa <- rowSums(p)
  pb <- colSums(p)
  teig <- p > 0
  MI <- sum(p[teig] * log(p[teig] / outer(pa, pb)[teig]))
  Ha <- -sum(pa[pa > 0] * log(pa[pa > 0]))
  Hb <- -sum(pb[pb > 0] * log(pb[pb > 0]))
  NMI <- if (Ha + Hb == 0) 1 else 2 * MI / (Ha + Hb)
  
  sajunga <- poros_a + poros_b - bendros
  Jaccard <- if (sajunga == 0) NA_real_ else bendros / sajunga
  
  c(ARI = ARI, NMI = NMI, Jaccard = Jaccard)
}

# Visų imčių porų palyginimas tik bendriems objektams (pagal id).
# rez – sąrašas elementų su laukais sekla, id, klasteris.
poru_palyginimas <- function(rez) {
  poros <- combn(seq_along(rez), 2)
  do.call(rbind, lapply(seq_len(ncol(poros)), function(i) {
    a <- rez[[poros[1, i]]]
    b <- rez[[poros[2, i]]]
    id <- intersect(a$id, b$id)
    za <- a$klasteris[match(id, a$id)]
    zb <- b$klasteris[match(id, b$id)]
    stopifnot(length(id) >= 2L)
    na <- za == 0
    nb <- zb == 0
    data.frame(sekla_A = a$sekla, sekla_B = b$sekla, bendru_objektu = length(id),
               t(suskirstymu_matai(za, zb)),
               triuksmo_Jaccard = sum(na & nb) / sum(na | nb))
  }))
}

# Parametrų tinklelio tyrimas; silueto skaičiuojama tik kai pateikta D.
jautrumo_tyrimas <- function(X, tinklelis, D = NULL, rusiuoti = FALSE) {
  do.call(rbind, lapply(seq_len(nrow(tinklelis)), function(i) {
    p <- tinklelis[i, ]
    z <- paleisti(X, p$eps, p$minPts)
    sil <- if (is.null(D)) NA_real_ else vidiniai_matai(X, z, D)$Silhouette
    data.frame(eps = p$eps, minPts = p$minPts, santrauka(z, rusiuoti),
               vertinta_proc = 100 - 100 * mean(z == 0), silhouette = sil)
  }))
}

# Grupių profiliai originaliais vienetais ir klasių sudėtis.
# p – viena kandidato eilutė (variantas, eps, minPts).
profiliai <- function(z, p) {
  g <- sort(unique(z))
  vard <- ifelse(g == 0, "Triuksmas", paste0("K", g))
  pagrindas <- function(j, n) {
    data.frame(variantas = p$variantas, eps = p$eps, minPts = p$minPts,
               klasteris = g[j], grupe = vard[j], n = n)
  }
  
  stat <- do.call(rbind, lapply(seq_along(g), function(j) {
    d <- interp[z == g[j], pozymiai, drop = FALSE]
    data.frame(pagrindas(j, nrow(d)), pozymis = pozymiai,
               Q1 = vapply(d, quantile, numeric(1), probs = 0.25, names = FALSE),
               mediana = vapply(d, median, numeric(1)),
               Q3 = vapply(d, quantile, numeric(1), probs = 0.75, names = FALSE),
               row.names = NULL)
  }))
  
  klases <- do.call(rbind, lapply(seq_along(g), function(j) {
    t_ <- table(factor(aibe$class[z == g[j]], levels = c("Ideal", "Premium")))
    n <- sum(t_)
    data.frame(pagrindas(j, n), Ideal = as.integer(t_[["Ideal"]]),
               Premium = as.integer(t_[["Premium"]]),
               Ideal_proc = 100 * t_[["Ideal"]] / n,
               Premium_proc = 100 * t_[["Premium"]] / n)
  }))
  
  list(statistikos = stat, klases = klases)
}

# --- Grafikai -----------------------------------------------------------------

tema_dbscan <- function() {
  theme_minimal(base_size = 12) +
    theme(plot.title = element_text(colour = "black"),
          plot.subtitle = element_text(colour = "black"),
          panel.grid.minor = element_blank(),
          strip.text = element_text(colour = "black"),
          legend.position = "right")
}

PAL_MINPTS <- c("4" = "#619CFF", "5" = "#C77CFF", "10" = "#F8766D",
                "20" = "#00BFC4", "38" = "#7CAE00")
PAL_GRUPES <- c("Triukšmas" = "#BDBDBD", K1 = "#F8766D", K2 = "#00BFC4",
                K3 = "#7CAE00", K4 = "#C77CFF", K5 = "#619CFF", K6 = "#E6AB02")
PAL_ERDVES <- c("Originali 19D" = "#F8766D", "PCA 5D" = "#00BFC4",
                "t-SNE 2D" = "#C77CFF")

# k-atstumų kreivės su pažymėtu geometriniu kelio įverčiu.
knn_grafikas <- function(X, kelias, cfg) {
  lygiai <- paste("minPts =", cfg$minPts)
  kr <- do.call(rbind, lapply(cfg$minPts, function(m) {
    d <- sort(dbscan::kNNdist(X, k = m - 1L))
    data.frame(minPts = factor(paste("minPts =", m), levels = lygiai),
               eile = seq_along(d), atstumas = d)
  }))
  kel <- data.frame(minPts = factor(paste("minPts =", kelias$minPts), levels = lygiai),
                    eile = kelias$objekto_eile, eps = kelias$eps_kelio)
  
  ggplot(kr, aes(x = eile, y = atstumas)) +
    geom_line(colour = "black", linewidth = 0.5) +
    geom_hline(data = kel, aes(yintercept = eps), colour = "#F8766D",
               linetype = "dashed", linewidth = 0.6) +
    geom_point(data = kel, aes(x = eile, y = eps), colour = "#F8766D", size = 2.5) +
    geom_text(data = kel, aes(x = 0, y = eps, label = sprintf("eps ≈ %.3f", eps)),
              hjust = 0, vjust = -0.6, size = 3.5, colour = "#D84A42") +
    facet_wrap(~ minPts, ncol = cfg$knn_stulpeliai) +
    labs(title = paste("DBSCAN eps kelio įverčiai:", cfg$vardas),
         subtitle = "Pažymėti geometriniu būdu nustatyti eps kandidatai",
         x = "Objektų eilė pagal didėjantį atstumą",
         y = "Atstumas iki k-ojo kaimyno") +
    tema_dbscan()
}

jautrumo_grafikas <- function(tab, cfg) {
  v <- rbind(
    data.frame(eps = tab$eps, minPts = factor(tab$minPts),
               rodiklis = "Klasterių skaičius", reiksme = tab$klasteriu_sk),
    data.frame(eps = tab$eps, minPts = factor(tab$minPts),
               rodiklis = "Triukšmas (%)", reiksme = tab$triuksmas_proc))
  v$rodiklis <- factor(v$rodiklis, levels = c("Klasterių skaičius", "Triukšmas (%)"))
  
  ggplot(v, aes(x = eps, y = reiksme, colour = minPts, group = minPts)) +
    geom_line(linewidth = 0.6) +
    geom_point(size = 1.8) +
    facet_wrap(~ rodiklis, nrow = 1, scales = "free_y") +
    scale_colour_manual(values = PAL_MINPTS, name = "minPts") +
    scale_x_continuous(breaks = cfg$eps_zingsniai) +
    scale_y_continuous(limits = c(0, NA)) +
    labs(title = paste("DBSCAN parametrų jautrumas:", cfg$vardas),
         subtitle = "Keičiami eps ir minPts",
         x = "Kaimynystės spindulys (eps)", y = NULL) +
    tema_dbscan()
}

# Kandidatų klasteriai bendroje 2D projekcijoje (koord – dviejų stulpelių matrica).
kandidatu_grafikas <- function(kz, kand, koord, antraste, poantraste, stulpeliai = 2) {
  dalys <- lapply(seq_len(nrow(kand)), function(i) {
    z <- kz[[kand$variantas[i]]]
    dyd <- table(z[z > 0])
    pav <- sprintf("eps = %s; minPts = %d\nKlasterių: %d; triukšmas %.2f %%",
                   format(round(kand$eps[i], 3), nsmall = 2),
                   as.integer(kand$minPts[i]), length(dyd), 100 * mean(z == 0))
    dydis <- rep(Inf, length(z))
    dydis[z > 0] <- as.numeric(dyd[as.character(z[z > 0])])
    d <- data.frame(TSNE1 = koord[, 1], TSNE2 = koord[, 2],
                    grupe = ifelse(z == 0, "Triukšmas", paste0("K", z)),
                    variantas = pav)
    d[order(dydis, decreasing = TRUE), ]   # triukšmas piešiamas pirmas
  })
  d <- do.call(rbind, dalys)
  d$variantas <- factor(d$variantas, levels = unique(d$variantas))
  
  max_k <- max(unlist(lapply(kand$variantas, function(v) kz[[v]])))
  niv <- c("Triukšmas", paste0("K", seq_len(max_k)))
  stopifnot(all(niv %in% names(PAL_GRUPES)))
  d$grupe <- factor(d$grupe, levels = niv)
  
  ggplot(d, aes(x = TSNE1, y = TSNE2, colour = grupe)) +
    geom_point(size = 0.8, alpha = 0.7) +
    facet_wrap(~ variantas, ncol = stulpeliai) +
    scale_colour_manual(values = PAL_GRUPES, breaks = niv, name = "Grupė") +
    coord_fixed() +
    labs(title = antraste, subtitle = poantraste, x = "t-SNE 1", y = "t-SNE 2",
         caption = "Klasterių numeriai galioja tik atskiram bandymui. Triukšmas nėra klasteris.") +
    tema_dbscan() +
    guides(colour = guide_legend(override.aes = list(size = 3, alpha = 1)))
}

# ---- 1. Erdvių konfigūracija --------------------------------------------------
# minPts: pagrindinė reikšmė = 2 × dimensija, kitos – jautrumui.
# Kandidatuose eps = NA reiškia „imti geometrinį kelio įvertį tai minPts".

erdves <- list(
  originali = list(
    kodas = "originali", vardas = "Originali 19D", X = x,
    minPts = c(10, 20, 38), bazinis_minPts = 38,
    eps_tinklelis = seq(0.8, 1.6, by = 0.05), ideti_kelio_eps = FALSE,
    eps_zingsniai = seq(0.8, 1.6, by = 0.1), rusiuoti = FALSE,
    knn_png = "dbscan_kelio_ivertis_originali.png",
    knn_stulpeliai = 3, knn_aukstis = 4.5,
    kandidatu_png = "dbscan_kandidatai_originali_tsne.png",
    kandidatai = data.frame(variantas = NA_character_,
                            eps = c(0.80, 0.95, 1.10, 1.15),
                            minPts = c(20, 10, 10, 10))
  ),
  pca = list(
    kodas = "pca", vardas = "PCA 5D", X = x_pca,
    minPts = c(5, 10, 20, 38), bazinis_minPts = 10,
    eps_tinklelis = seq(0.6, 1.8, by = 0.05), ideti_kelio_eps = TRUE,
    eps_zingsniai = seq(0.6, 1.8, by = 0.2), rusiuoti = FALSE,
    knn_png = "dbscan_knn_pca.png", knn_stulpeliai = 2, knn_aukstis = 8,
    kandidatu_png = "dbscan_kandidatai_pca_tsne.png",
    kandidatai = data.frame(variantas = c(NA, NA, NA, NA, NA, "kelias_10"),
                            eps = c(0.85, 0.90, 0.65, 1.35, 1.00, NA),
                            minPts = c(5, 10, 20, 38, 10, 10))
  ),
  tsne = list(
    kodas = "tsne", vardas = "t-SNE 2D", X = x_tsne,
    minPts = c(4, 5, 10, 20), bazinis_minPts = 4,
    eps_tinklelis = seq(0.8, 4.4, by = 0.15), ideti_kelio_eps = TRUE,
    eps_zingsniai = seq(0.8, 4.4, by = 0.6), rusiuoti = TRUE,
    knn_png = "dbscan_knn_tsne.png", knn_stulpeliai = 2, knn_aukstis = 8,
    kandidatu_png = NULL,   # 114 klasterių nevaizduojami; žr. 2.2 skyrių
    kandidatai = data.frame(variantas = c("kelias_4", "kelias_10",
                                          "trys_klasteriai", "du_klasteriai"),
                            eps = c(NA, NA, 3.05, 3.20),
                            minPts = c(4, 10, 4, 4))
  )
)

ER <- vapply(erdves, function(e) e$vardas, character(1))   # kodas -> pavadinimas

# 19D pradiniai 15 bandymų.
pradiniai <- rbind(
  expand.grid(minPts = 10, eps = c(0.9, 1.1, 1.3, 1.5, 1.7)),
  expand.grid(minPts = 20, eps = c(1.1, 1.3, 1.5, 1.7, 1.9)),
  expand.grid(minPts = 38, eps = c(1.3, 1.5, 1.7, 1.9, 2.1)))
rasyti(jautrumo_tyrimas(x, pradiniai)[, c("eps", "minPts", "klasteriu_sk",
                                          "triuksmo_sk", "triuksmas_proc",
                                          "klasteriu_dydziai")],
       "dbscan_parametrai_originali.csv")

# ---- 1. Pagrindinis ciklas per erdves ------------------------------------------

bazines_z <- list()      # atskaitos priskyrimai
bazines_suv <- list()    # atskaitos kokybės eilutės
kand_visi <- list()      # kandidatų lentelės
kand_z_visi <- list()    # kandidatų priskyrimai

for (cfg in erdves) {
  cat("\n=====", cfg$vardas, "=====\n")
  X <- cfg$X
  D <- as.matrix(dist(X))
  k <- cfg$kodas
  
  # 1.1 eps kelio įvertis
  kelias <- kelio_lentele(X, cfg$minPts, cfg$rusiuoti)
  rasyti(kelias, paste0("dbscan_kelio_ivertis_", k, ".csv"))
  issaugoti(knn_grafikas(X, kelias, cfg), cfg$knn_png, 12, cfg$knn_aukstis)
  print(kelias, row.names = FALSE, digits = 5)
  
  # 1.2 Parametrų jautrumas + siluetas + klasterių balansas
  tinklelis <- expand.grid(minPts = cfg$minPts, eps = cfg$eps_tinklelis)
  if (cfg$ideti_kelio_eps) {
    tinklelis <- unique(rbind(tinklelis,
                              data.frame(minPts = kelias$minPts, eps = kelias$eps_kelio)))
  }
  tinklelis <- tinklelis[order(tinklelis$minPts, tinklelis$eps), ]
  jaut <- jautrumo_tyrimas(X, tinklelis, D, cfg$rusiuoti)
  rasyti(jaut[, c("eps", "minPts", "klasteriu_sk", "triuksmo_sk",
                  "triuksmas_proc", "klasteriu_dydziai")],
         paste0("dbscan_parametru_jautrumas_", k, ".csv"))
  rasyti(jaut, paste0("dbscan_kokybe_parametru_", k, ".csv"))
  issaugoti(jautrumo_grafikas(jaut, cfg),
            paste0("dbscan_parametru_jautrumas_", k, ".png"), 12, 4.5)
  cat("Atlikta bandymų:", nrow(jaut), "\n")
  
  # 1.3 Kandidatai: priskyrimai, profiliai, klasių sudėtis, vidiniai matai
  kand <- cfg$kandidatai
  trukst <- is.na(kand$eps)
  kand$eps[trukst] <- kelias$eps_kelio[match(kand$minPts[trukst], kelias$minPts)]
  kand$variantas <- ifelse(is.na(kand$variantas),
                           sprintf("eps_%.2f_minPts_%d", kand$eps, as.integer(kand$minPts)),
                           kand$variantas)
  
  kz <- setNames(lapply(seq_len(nrow(kand)),
                        function(i) paleisti(X, kand$eps[i], kand$minPts[i])),
                 kand$variantas)
  
  pr <- lapply(seq_len(nrow(kand)), function(i) profiliai(kz[[i]], kand[i, ]))
  rasyti(do.call(rbind, lapply(pr, `[[`, "statistikos")),
         paste0("dbscan_kandidatu_statistikos_", k, ".csv"))
  klases <- do.call(rbind, lapply(pr, `[[`, "klases"))
  rasyti(klases, paste0("dbscan_kandidatu_klases_", k, ".csv"))
  
  for (i in seq_len(nrow(kand))) {
    rasyti(data.frame(id = aibe$id, class = aibe$class, klasteris = kz[[i]]),
           sprintf("dbscan_%s_%s_priskyrimai.csv", k, kand$variantas[i]))
  }
  
  kok <- do.call(rbind, lapply(seq_len(nrow(kand)), function(i) {
    z <- kz[[i]]
    v <- vidiniai_matai(X, z, D)
    data.frame(kand[i, c("variantas", "eps", "minPts")],
               klasteriu_sk = v$klasteriu_sk, vertinta_n = v$vertinta_n,
               vertinta_proc = 100 * v$vertinta_n / nrow(X),
               triuksmas_proc = 100 * mean(z == 0),
               v[, c("Silhouette", "CH", "DB")])
  }))
  rasyti(kok, paste0("dbscan_kandidatu_kokybe_", k, ".csv"))
  print(kok, row.names = FALSE, digits = 5)
  
  if (!is.null(cfg$kandidatu_png)) {
    g <- kandidatu_grafikas(
      kz, kand, x_tsne,
      paste("DBSCAN kandidatai:", cfg$vardas),
      paste0("Klasterizavimas ", cfg$vardas, "; vizualizacija bendroje t-SNE 2D projekcijoje"))
    issaugoti(g, cfg$kandidatu_png, 12, 4.25 * ceiling(nrow(kand) / 2))
  }
  
  # 1.4 Atskaita: bazinis minPts + geometrinis eps
  eps0 <- kelias$eps_kelio[kelias$minPts == cfg$bazinis_minPts]
  z0 <- paleisti(X, eps0, cfg$bazinis_minPts)
  v0 <- vidiniai_matai(X, z0, D)
  suv0 <- data.frame(erdve = cfg$vardas, eps = eps0, minPts = cfg$bazinis_minPts,
                     atstumas = "Euklidinis", borderPoints = TRUE,
                     klasteriu_sk = v0$klasteriu_sk, triuksmo_sk = sum(z0 == 0),
                     triuksmas_proc = 100 * mean(z0 == 0),
                     v0[, c("Silhouette", "CH", "DB")], data = as.character(Sys.Date()))
  rasyti(data.frame(id = aibe$id, class = aibe$class, klasteris = z0),
         paste0("dbscan_", k, "_klasteriai.csv"))
  rasyti(suv0, paste0("dbscan_kokybe_", k, ".csv"))
  
  bazines_z[[k]] <- z0
  bazines_suv[[k]] <- suv0
  kand_visi[[k]] <- kand
  kand_z_visi[[k]] <- kz
  
  rm(D)
  invisible(gc())
}

# ---- 2.1 19D: mažųjų grupių jautrumas eps (minPts = 10) -----------------------

eps_m <- seq(0.90, 1.15, by = 0.05)
BUSENOS <- c("didysis_klasteris", "mazieji_klasteriai", "triuksmas")

busenos <- lapply(eps_m, function(e) {
  z <- paleisti(x, e, 10L)
  didysis <- as.integer(names(which.max(table(z[z > 0]))))
  factor(ifelse(z == 0, "triuksmas",
                ifelse(z == didysis, "didysis_klasteris", "mazieji_klasteriai")),
         levels = BUSENOS)
})
mazieji <- lapply(busenos, function(b) aibe$id[b == "mazieji_klasteriai"])

persidengimas <- do.call(rbind, lapply(seq_len(ncol(combn(length(eps_m), 2))), function(i) {
  p <- combn(length(eps_m), 2)[, i]
  a <- mazieji[[p[1]]]
  b <- mazieji[[p[2]]]
  data.frame(eps_A = eps_m[p[1]], eps_B = eps_m[p[2]],
             mazuju_objektu_A = length(a), mazuju_objektu_B = length(b),
             bendru_objektu = length(intersect(a, b)),
             Jaccard = length(intersect(a, b)) / length(union(a, b)))
}))
rasyti(persidengimas, "dbscan_mazuju_klasteriu_persidengimas_originali.csv")

perejimai_eps <- do.call(rbind, lapply(seq_len(length(eps_m) - 1), function(i) {
  t_ <- as.data.frame(table(busena_A = busenos[[i]], busena_B = busenos[[i + 1]]))
  names(t_)[3] <- "objektu_sk"
  data.frame(eps_A = eps_m[i], eps_B = eps_m[i + 1], t_)
}))
rasyti(perejimai_eps, "dbscan_objektu_perejimai_originali.csv")

# ---- 2.2 t-SNE: du ir trys klasteriai ------------------------------------------

dt <- c("trys_klasteriai", "du_klasteriai")
kz_t <- kand_z_visi$tsne
perej <- table(eps_3_05 = kz_t$trys_klasteriai, eps_3_20 = kz_t$du_klasteriai)
print(perej)
rasyti(as.data.frame(perej), "dbscan_tsne_du_ir_trys_perejimai.csv")

kand_dt <- kand_visi$tsne[match(dt, kand_visi$tsne$variantas), ]
g <- kandidatu_grafikas(kz_t, kand_dt, x_tsne,
                        "DBSCAN trijų ir dviejų klasterių variantai",
                        "Klasterizavimas ir vizualizacija t-SNE 2D erdvėje",
                        stulpeliai = 2)
issaugoti(g, "dbscan_tsne_du_ir_trys_klasteriai.png", 12, 5)

# ---- 3. Atskaitų palyginimas tarp erdvių --------------------------------------

vardai_f <- c(originali = "Originali_19D", pca = "PCA_5D", tsne = "tSNE_2D")
poros_e <- combn(names(vardai_f), 2)

tarp <- lapply(seq_len(ncol(poros_e)), function(i) {
  a <- bazines_z[[poros_e[1, i]]]
  b <- bazines_z[[poros_e[2, i]]]
  va <- vardai_f[[poros_e[1, i]]]
  vb <- vardai_f[[poros_e[2, i]]]
  na <- a == 0
  nb <- b == 0
  
  perej <- as.data.frame(table(klasteris_A = a, klasteris_B = b))
  names(perej)[3] <- "objektu_sk"
  rasyti(perej, sprintf("dbscan_perejimai_%s_%s.csv", va, vb))
  
  list(
    palyginimas = data.frame(erdve_A = va, erdve_B = vb, objektu_sk = length(a),
                             t(suskirstymu_matai(a, b))),   # triukšmas (0) = viena grupė
    triuksmas = data.frame(erdve_A = va, erdve_B = vb,
                           triuksmas_A = sum(na), triuksmas_B = sum(nb),
                           triuksmas_abiejose = sum(na & nb),
                           tik_A_triuksmas = sum(na & !nb),
                           tik_B_triuksmas = sum(!na & nb),
                           klasteriuose_abiejose = sum(!na & !nb),
                           triuksmo_Jaccard = sum(na & nb) / sum(na | nb)))
})
rasyti(do.call(rbind, lapply(tarp, `[[`, "palyginimas")), "dbscan_erdviu_palyginimas.csv")
rasyti(do.call(rbind, lapply(tarp, `[[`, "triuksmas")), "dbscan_triuksmo_palyginimas.csv")
print(do.call(rbind, lapply(tarp, `[[`, "palyginimas")), row.names = FALSE, digits = 5)

# ---- 4. Stabilumas: 80 % imtys -------------------------------------------------
# Imtis imama iš nenormuotų duomenų, normavimas (mediana, IQR) ir dimensijos
# mažinimas kiekvienoje imtyje atliekami iš naujo – duomenų nutekėjimo nėra.

N_MAX <- 20L   # imčių originaliai ir PCA erdvėms
N_PAG <- 10L   # imčių bendram trijų erdvių palyginimui (t-SNE – tik tiek)

X_pradine <- as.matrix(interp[, pozymiai, drop = FALSE])
stopifnot(all(is.finite(X_pradine)))

sudaryti_imti <- function(sekla) {
  set.seed(sekla)
  ind <- sort(sample.int(nrow(X_pradine), size = floor(0.8 * nrow(X_pradine)),
                         replace = FALSE))
  Xi <- X_pradine[ind, , drop = FALSE]
  med <- apply(Xi, 2, median)
  iqr <- apply(Xi, 2, IQR)
  stopifnot(all(is.finite(iqr)), all(iqr > 0))
  list(sekla = sekla, id = aibe$id[ind],
       x = sweep(sweep(Xi, 2, med, "-"), 2, iqr, "/"))
}
imtys <- lapply(0:(N_MAX - 1L), sudaryti_imti)

# t-SNE projekcijos kešuojamos, kad nereikėtų perskaičiuoti.
tsne_imtis <- function(im) {
  failas <- file.path("rezultatai",
                      sprintf("dbscan_stabilumas_tsne_imtis_%d.csv", im$sekla))
  if (file.exists(failas)) {
    d <- read.csv(failas)
    if (nrow(d) == length(im$id) && all(as.character(d$id) == as.character(im$id))) {
      return(as.matrix(d[, c("TSNE1", "TSNE2")]))
    }
  }
  cat("t-SNE imtis:", im$sekla, "| sėkla:", 1000L + im$sekla, "\n")
  set.seed(1000L + im$sekla)
  Y <- Rtsne::Rtsne(im$x, dims = 2, perplexity = 30, max_iter = 1000,
                    pca = FALSE, normalize = FALSE, verbose = FALSE,
                    check_duplicates = FALSE, num_threads = 1)$Y
  stopifnot(all(is.finite(Y)))
  write.csv(data.frame(id = im$id, TSNE1 = Y[, 1], TSNE2 = Y[, 2]),
            failas, row.names = FALSE)
  Y
}

pertvarkos <- list(
  originali = function(im) list(X = im$x, disp5 = NA_real_),
  pca = function(im) {
    m <- prcomp(im$x, center = TRUE, scale. = FALSE)
    list(X = m$x[, 1:5, drop = FALSE], disp5 = sum(m$sdev[1:5]^2) / sum(m$sdev^2))
  },
  tsne = function(im) list(X = tsne_imtis(im), disp5 = NA_real_)
)

# Atskaitos procedūra: eps perskaičiuojamas kiekvienai imčiai.
stabilumo_rez <- function(kodas, imtys, minPts) {
  lapply(imtys, function(im) {
    pert <- pertvarkos[[kodas]](im)
    eps <- kelio_eps(pert$X, minPts)
    list(sekla = im$sekla, eps = eps, id = im$id, X = pert$X, disp5 = pert$disp5,
         klasteriu_eps = eps, klasteris = paleisti(pert$X, eps, minPts))
  })
}

rez_st <- list(
  originali = stabilumo_rez("originali", imtys, 38L),
  pca       = stabilumo_rez("pca", imtys, 10L),
  tsne      = stabilumo_rez("tsne", imtys[seq_len(N_PAG)], 4L)
)
MINPTS_ST <- c(originali = 38L, pca = 10L, tsne = 4L)
pirmos10 <- list(originali = rez_st$originali[seq_len(N_PAG)],
                 pca = rez_st$pca[seq_len(N_PAG)],
                 tsne = rez_st$tsne)

bandymai_lentele <- function(rez, etikete, minPts) {
  do.call(rbind, lapply(rez, function(r) {
    data.frame(erdve = etikete, sekla = r$sekla, eps = r$eps, minPts = minPts,
               objektu_sk = length(r$id), santrauka(r$klasteris),
               paaiskinta_dispersija_proc = 100 * r$disp5)
  }))
}

# 4.1 Porų palyginimas (originali ir PCA – 20 imčių, t-SNE – 10)
poros20 <- list(originali = poru_palyginimas(rez_st$originali),
                pca = poru_palyginimas(rez_st$pca))
poros10 <- list(
  originali = subset(poros20$originali, sekla_A < N_PAG & sekla_B < N_PAG),
  pca = subset(poros20$pca, sekla_A < N_PAG & sekla_B < N_PAG),
  tsne = poru_palyginimas(rez_st$tsne))

for (kodas in names(poros10)) {
  rasyti(bandymai_lentele(pirmos10[[kodas]], ER[[kodas]], MINPTS_ST[[kodas]]),
         paste0("dbscan_stabilumo_bandymai_", kodas, ".csv"))
  rasyti(poros10[[kodas]], paste0("dbscan_stabilumo_poros_", kodas, ".csv"))
}
rasyti(poros20$originali, "dbscan_stabilumo_poros_originali_20.csv")
rasyti(poros20$pca, "dbscan_stabilumo_poros_pca_20.csv")
rasyti(rbind(bandymai_lentele(rez_st$originali, ER[["originali"]], 38L),
             bandymai_lentele(rez_st$pca, ER[["pca"]], 10L)),
       "dbscan_stabilumo_bandymai_20.csv")

# 4.2 Aprašomoji statistika
aprasomoji <- function(v) {
  v <- v[is.finite(v)]
  data.frame(vertinta = length(v),
             vidurkis = if (length(v)) mean(v) else NA_real_,
             SD = if (length(v) > 1) sd(v) else NA_real_,
             minimumas = if (length(v)) min(v) else NA_real_,
             maksimumas = if (length(v)) max(v) else NA_real_)
}
suvesti <- function(df, rodikliai) {
  do.call(rbind, lapply(levels(df$erdve), function(e) {
    do.call(rbind, lapply(rodikliai, function(r) {
      data.frame(erdve = e, rodiklis = r, aprasomoji(df[df$erdve == e, r]))
    }))
  }))
}

poros_visos <- do.call(rbind, lapply(names(poros10), function(kodas) {
  data.frame(erdve = ER[[kodas]], poros10[[kodas]])
}))
poros_visos$erdve <- factor(poros_visos$erdve, levels = ER)

stab_suv <- suvesti(poros_visos, c("ARI", "NMI", "Jaccard", "triuksmo_Jaccard"))
rasyti(poros_visos, "dbscan_stabilumo_poros_visos_erdves.csv")
rasyti(stab_suv, "dbscan_stabilumo_suvestine.csv")
print(stab_suv, row.names = FALSE, digits = 5)

g <- ggplot(poros_visos, aes(x = erdve, y = ARI, fill = erdve)) +
  geom_boxplot(width = 0.5, alpha = 0.65, outlier.shape = NA) +
  geom_point(position = position_jitter(width = 0.09, height = 0, seed = 42),
             size = 1.6, alpha = 0.55) +
  scale_fill_manual(values = PAL_ERDVES) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, by = 0.2)) +
  labs(title = "DBSCAN stabilumas skirtingose erdvėse",
       subtitle = "10 atsitiktinių 80 % imčių; 45 poriniai palyginimai kiekvienai erdvei",
       x = NULL, y = "Adjusted Rand Index (ARI)",
       caption = "Lyginami tik bendri objektai. Triukšmo žymė 0 laikoma viena bendra grupe.") +
  tema_dbscan() + theme(legend.position = "none")
issaugoti(g, "dbscan_stabilumo_ari_visos_erdves.png", 10, 5.5)

# 4.3 ARI vidurkio kitimas didinant imčių skaičių (originali ir PCA)
pagal_N <- do.call(rbind, lapply(names(poros20), function(kodas) {
  do.call(rbind, lapply(c(5L, 10L, 15L, 20L), function(N) {
    d <- poros20[[kodas]][poros20[[kodas]]$sekla_A < N & poros20[[kodas]]$sekla_B < N, ]
    stopifnot(nrow(d) == choose(N, 2))
    data.frame(erdve = ER[[kodas]], N = N, poru_sk = nrow(d),
               ARI_vidurkis = mean(d$ARI), ARI_SD = sd(d$ARI))
  }))
}))
rasyti(pagal_N, "dbscan_stabilumas_pagal_N_20.csv")
print(pagal_N, row.names = FALSE, digits = 6)

g <- ggplot(pagal_N, aes(x = N, y = ARI_vidurkis, colour = erdve, group = erdve)) +
  geom_line(linewidth = 0.7) + geom_point(size = 2.5) +
  scale_colour_manual(values = PAL_ERDVES, name = "Erdvė") +
  scale_x_continuous(breaks = c(5, 10, 15, 20)) +
  coord_cartesian(ylim = c(0.75, 0.90)) +
  labs(title = "DBSCAN stabilumo įverčio kitimas",
       subtitle = "Originalios ir PCA erdvių geometrinio kelio atskaitos",
       x = "Imčių skaičius (N)", y = "Porinių ARI vidurkis",
       caption = "Vertikalioji ašis padidinta pokyčiams parodyti. t-SNE stabilumas vertintas su 10 imčių.") +
  tema_dbscan()
issaugoti(g, "dbscan_stabilumas_pagal_N_20.png", 10, 5.5)

# 4.4 Vidiniai matai imtyse (be triukšmo; vienam klasteriui – NA)
vidiniai_st <- do.call(rbind, lapply(names(pirmos10), function(kodas) {
  do.call(rbind, lapply(pirmos10[[kodas]], function(r) {
    data.frame(erdve = ER[[kodas]], sekla = r$sekla, vidiniai_matai(r$X, r$klasteris))
  }))
}))
vidiniai_st$erdve <- factor(vidiniai_st$erdve, levels = ER)
rasyti(vidiniai_st, "dbscan_stabilumo_vidiniai.csv")
vid_suv <- suvesti(vidiniai_st, c("Silhouette", "CH", "DB"))
rasyti(vid_suv, "dbscan_stabilumo_vidiniu_suvestine.csv")
print(vid_suv, row.names = FALSE, digits = 5)

# ---- 5. Fiksuotų parametrų kandidatų stabilumas -------------------------------
# Čia eps ir minPts fiksuoti (neperskaičiuojami), todėl 80 % imtis ir (t-SNE
# atveju) kitas projekcijos mastelis keičia ne tik klasterius, bet ir tankį.

fiksuotas <- function(rez, eps, minPts) {
  lapply(rez, function(r) {
    r$eps <- eps
    r$klasteris <- paleisti(r$X, eps, minPts)
    r
  })
}

fix_orig <- fiksuotas(pirmos10$originali, 1.15, 10L)
fix_pca  <- fiksuotas(pirmos10$pca, 1.00, 10L)
fix_t3   <- fiksuotas(pirmos10$tsne, 3.05, 4L)
fix_t2   <- fiksuotas(pirmos10$tsne, 3.20, 4L)
fix_tapr <- fiksuotas(pirmos10$tsne, 2.30, 20L)   # panašios aprėpties t-SNE variantas

rasyti(bandymai_lentele(fix_orig, "Originali 19D", 10L),
       "dbscan_kandidato_stabilumo_bandymai_originali.csv")
rasyti(poru_palyginimas(fix_orig), "dbscan_kandidato_stabilumo_poros_originali.csv")
rasyti(bandymai_lentele(fix_pca, "PCA 5D", 10L),
       "dbscan_kandidato_stabilumo_bandymai_pca.csv")
rasyti(poru_palyginimas(fix_pca), "dbscan_kandidato_stabilumo_poros_pca.csv")

rasyti(rbind(data.frame(variantas = "trys_klasteriai", bandymai_lentele(fix_t3, "t-SNE 2D", 4L)),
             data.frame(variantas = "du_klasteriai", bandymai_lentele(fix_t2, "t-SNE 2D", 4L))),
       "dbscan_kandidatu_stabilumo_bandymai_tsne.csv")
rasyti(rbind(data.frame(variantas = "trys_klasteriai", poru_palyginimas(fix_t3)),
             data.frame(variantas = "du_klasteriai", poru_palyginimas(fix_t2))),
       "dbscan_kandidatu_stabilumo_poros_tsne.csv")

poros_tapr <- poru_palyginimas(fix_tapr)
rasyti(bandymai_lentele(fix_tapr, "t-SNE 2D", 20L), "dbscan_aprepties_tsne_stabilumo_bandymai.csv")
rasyti(poros_tapr, "dbscan_aprepties_tsne_stabilumo_poros.csv")

# ---- 5.1 Panašios aprėpties variantai (pilna aibė) ----------------------------

apr <- data.frame(kodas = c("originali", "pca", "tsne"),
                  erdve = unname(ER),
                  eps = c(1.15, 1.00, 2.30),
                  minPts = c(10L, 10L, 20L))
matr <- list(originali = x, pca = x_pca, tsne = x_tsne)
apr_z <- lapply(seq_len(nrow(apr)),
                function(i) paleisti(matr[[apr$kodas[i]]], apr$eps[i], apr$minPts[i]))

apr_kok <- do.call(rbind, lapply(seq_len(nrow(apr)), function(i) {
  data.frame(apr[i, c("erdve", "eps", "minPts")],
             triuksmas_proc = 100 * mean(apr_z[[i]] == 0),
             vidiniai_matai(matr[[apr$kodas[i]]], apr_z[[i]]))
}))

# Visi trys suskirstymai vertinami originalioje 19D erdvėje tiems patiems objektams.
bendri <- Reduce("&", lapply(apr_z, function(z) z > 0))
bendra_19D <- do.call(rbind, lapply(seq_len(nrow(apr)), function(i) {
  data.frame(suskirstymo_erdve = apr$erdve[i], vertinimo_erdve = "Originali 19D",
             vidiniai_matai(x[bendri, , drop = FALSE],
                            as.integer(factor(apr_z[[i]][bendri]))))
}))

rasyti(apr_kok, "dbscan_panasios_aprepties_kokybe.csv")
rasyti(bendra_19D, "dbscan_panasios_aprepties_kokybe_bendra_19D.csv")
rasyti(data.frame(id = aibe$id, originali = apr_z[[1]], pca = apr_z[[2]],
                  tsne = apr_z[[3]], bendras_vertinimo_poaibis = bendri),
       "dbscan_panasios_aprepties_priskyrimai.csv")
print(apr_kok, row.names = FALSE, digits = 5)
print(bendra_19D, row.names = FALSE, digits = 5)

# ---- 6. Bendra eksperimentų suvestinė -----------------------------------------
# ARI*/NMI*/Jaccard* lyginami su tos pačios grupės originalios 19D suskirstymu.

suv_eilutes <- function(grupe, kokybe, zymes, poros) {
  ref <- zymes[[1]]
  do.call(rbind, lapply(seq_len(nrow(kokybe)), function(i) {
    m <- suskirstymu_matai(ref, zymes[[i]])
    data.frame(variantu_grupe = grupe, erdve = kokybe$erdve[i], algoritmas = "DBSCAN",
               eps = kokybe$eps[i], minPts = kokybe$minPts[i], k = kokybe$klasteriu_sk[i],
               triuksmas_proc = kokybe$triuksmas_proc[i],
               Silhouette = kokybe$Silhouette[i], CH = kokybe$CH[i], DB = kokybe$DB[i],
               ARI_originali = m[["ARI"]], NMI_originali = m[["NMI"]],
               Jaccard_originali = m[["Jaccard"]], stabilumo_N = N_PAG,
               stabilumo_ARI_vidurkis = mean(poros[[i]]$ARI),
               stabilumo_ARI_SD = sd(poros[[i]]$ARI))
  }))
}

eksperimentu_suvestine <- rbind(
  suv_eilutes("Kelio atskaita", do.call(rbind, bazines_suv), bazines_z,
              list(poros10$originali, poros10$pca, poros10$tsne)),
  suv_eilutes("Panaši aprėptis", apr_kok, apr_z,
              list(poru_palyginimas(fix_orig), poru_palyginimas(fix_pca), poros_tapr))
)

rasyti(eksperimentu_suvestine, "dbscan_eksperimentu_suvestine.csv")
print(eksperimentu_suvestine, row.names = FALSE, digits = 5)
