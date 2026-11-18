# ============================================================
# HIERARCHINIS KLASTERIZAVIMAS
# ============================================================
# Nustatymai
# ------------------------------------------------------------
SEED <- 42
N_IMCIU <- 10
IMTIES_DALIS <- 0.80
K_REIKSMES <- 2:10
KORELIACIJOS_SLENKSTIS <- 0.90
MIN_KLASTERIO_DALIS <- 0.01

DUOMENU_FAILAS <- "aibes/aibe_originali.csv"
ORIGINALIU_DUOMENU_FAILAS <- "aibes/C_originaliais_vienetais_interpretacijai.csv"
PCA_FAILAS <- "aibes/aibe_PCA.csv"
TSNE_FAILAS <- "aibes/aibe_tSNE_2D.csv"

# ------------------------------------------------------------
# Paketų įkėlimas
# ------------------------------------------------------------
R_PAKETU_APLANKAS <- Sys.getenv("R_LIBS_USER")
if (!nzchar(R_PAKETU_APLANKAS)) {
  R_PAKETU_APLANKAS <- file.path(path.expand("~"), "R", "library")
}
if (!dir.exists(R_PAKETU_APLANKAS)) {
  dir.create(R_PAKETU_APLANKAS, recursive = TRUE, showWarnings = FALSE)
}
.libPaths(unique(c(R_PAKETU_APLANKAS, .libPaths())))

for (pkg in c("cluster", "Rtsne")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org",
                     lib = R_PAKETU_APLANKAS)
  }
}

# ------------------------------------------------------------
# Duomenų nuskaitymas
# ------------------------------------------------------------
if (!file.exists(DUOMENU_FAILAS)) {
  stop(paste0("Nerastas failas: ", DUOMENU_FAILAS,
              ". Pirmiausia paleiskite vykdymas.R."))
}

duomenys <- read.csv(DUOMENU_FAILAS, check.names = FALSE)
pozymiu_pavadinimai <- setdiff(names(duomenys), c("id", "class", "klasteris"))
X <- as.matrix(duomenys[pozymiu_pavadinimai])
storage.mode(X) <- "double"
objektu_id <- if ("id" %in% names(duomenys)) duomenys$id else seq_len(nrow(duomenys))

nuskaityti_sumazinta <- function(failas) {
  aibe <- read.csv(failas, check.names = FALSE)
  if ("id" %in% names(aibe) && "id" %in% names(duomenys)) {
    aibe <- aibe[match(objektu_id, aibe$id), , drop = FALSE]
  }
  pozymiai <- setdiff(names(aibe), c("id", "class", "klasteris"))
  mat <- as.matrix(aibe[pozymiai])
  storage.mode(mat) <- "double"
  list(data = aibe, X = mat)
}

pca_aibe <- nuskaityti_sumazinta(PCA_FAILAS)
tsne_aibe <- nuskaityti_sumazinta(TSNE_FAILAS)

# Dinaminiai erdvių pavadinimai (ne hardcodinti)
originalios_erdves_pavadinimas <- paste0("Originali_C_", ncol(X), "D")
pca_erdves_pavadinimas <- paste0("PCA_", ncol(pca_aibe$X), "D")
tsne_erdves_pavadinimas <- paste0("tSNE_", ncol(tsne_aibe$X), "D")

PARUOSIMO_BUDAS <- paste(
  "Paruoštos C, PCA ir t-SNE aibės; id ir class neįtraukti;",
  "stabilumo imtyse požymiai perskaičiuoti pagal medianą ir IQR."
)

# ------------------------------------------------------------
# Originalūs matavimo vienetai interpretacijai
# ------------------------------------------------------------
if (file.exists(ORIGINALIU_DUOMENU_FAILAS)) {
  originalus <- read.csv(ORIGINALIU_DUOMENU_FAILAS, check.names = FALSE)
  if ("id" %in% names(originalus)) {
    originalus <- originalus[match(objektu_id, originalus$id), , drop = FALSE]
  }
  X_originalus <- as.matrix(originalus[pozymiu_pavadinimai])
  storage.mode(X_originalus) <- "double"
} else {
  X_originalus <- X
}

# ------------------------------------------------------------
# Pagalbinės funkcijos
# ------------------------------------------------------------
robust_scale <- function(mat) {
  centrai <- apply(mat, 2, median)
  masteliai <- apply(mat, 2, IQR)
  masteliai[!is.finite(masteliai) | masteliai == 0] <- 1
  sweep(sweep(mat, 2, centrai, "-"), 2, masteliai, "/")
}

vidiniai_rodikliai <- function(mat, klasteriai) {
  klasteriai <- as.integer(factor(klasteriai))
  k <- length(unique(klasteriai))
  n <- nrow(mat)
  bendras_centras <- colMeans(mat)
  bendra_sklaida <- sum(sweep(mat, 2, bendras_centras, "-")^2)
  vidine_sklaida <- 0
  centrai <- matrix(NA_real_, nrow = k, ncol = ncol(mat))
  spinduliai <- numeric(k)
  for (j in seq_len(k)) {
    grupe <- mat[klasteriai == j, , drop = FALSE]
    centrai[j, ] <- colMeans(grupe)
    skirtumai <- sweep(grupe, 2, centrai[j, ], "-")
    vidine_sklaida <- vidine_sklaida + sum(skirtumai^2)
    spinduliai[j] <- mean(sqrt(rowSums(skirtumai^2)))
  }
  ch <- if (k > 1 && n > k && vidine_sklaida > 0) {
    ((bendra_sklaida - vidine_sklaida) / (k - 1)) / (vidine_sklaida / (n - k))
  } else NA_real_
  centro_atstumai <- as.matrix(dist(centrai))
  db <- if (k > 1 && all(centro_atstumai[upper.tri(centro_atstumai)] > 0)) {
    didz <- vapply(seq_len(k), function(i) {
      s <- (spinduliai[i] + spinduliai) / centro_atstumai[i, ]
      s[i] <- -Inf
      max(s)
    }, numeric(1))
    mean(didz)
  } else NA_real_
  c(calinski_harabasz = ch, davies_bouldin = db)
}

ari_rodiklis <- function(a, b) {
  lentele <- table(a, b)
  poros <- function(x) sum(x * (x - 1) / 2)
  sut <- poros(lentele)
  eil <- poros(rowSums(lentele))
  stulp <- poros(colSums(lentele))
  visu <- choose(sum(lentele), 2)
  tik <- eil * stulp / visu
  didz <- (eil + stulp) / 2
  vard <- didz - tik
  if (abs(vard) < .Machine$double.eps) {
    return(if (abs(sut - didz) < 1e-10) 1 else 0)
  }
  (sut - tik) / vard
}

nmi_rodiklis <- function(a, b) {
  lentele <- table(a, b)
  p <- lentele / sum(lentele)
  p_eil <- rowSums(p)
  p_stulp <- colSums(p)
  bendras <- outer(p_eil, p_stulp)
  aktyvus <- p > 0
  mi <- sum(p[aktyvus] * log(p[aktyvus] / bendras[aktyvus]))
  ent_a <- -sum(p_eil[p_eil > 0] * log(p_eil[p_eil > 0]))
  ent_b <- -sum(p_stulp[p_stulp > 0] * log(p_stulp[p_stulp > 0]))
  vard <- (ent_a + ent_b) / 2
  if (vard == 0) return(1)
  mi / vard
}

jaccard_rodiklis <- function(a, b) {
  lentele <- table(a, b)
  poros <- function(x) sum(x * (x - 1) / 2)
  bendros <- poros(lentele)
  visos_a <- poros(rowSums(lentele))
  visos_b <- poros(colSums(lentele))
  junginys <- visos_a + visos_b - bendros
  if (junginys == 0) return(1)
  bendros / junginys
}

surinkti_mazu_klasteriu_id <- function(priskyrimai, ids, erdve, konfig, k) {
  dydziai <- table(priskyrimai)
  mazi <- names(dydziai)[as.numeric(dydziai) / length(priskyrimai) < MIN_KLASTERIO_DALIS]
  if (length(mazi) == 0) {
    return(data.frame(erdve = character(), konfiguracija = character(),
                      k = integer(), klasteris = character(),
                      klasterio_dydis = integer(),
                      klasterio_dalis = numeric(),
                      id = character(), stringsAsFactors = FALSE))
  }
  indeksai <- which(as.character(priskyrimai) %in% mazi)
  kp <- as.character(priskyrimai[indeksai])
  kd <- as.integer(dydziai[kp])
  data.frame(erdve = erdve, konfiguracija = konfig, k = k,
             klasteris = kp, klasterio_dydis = kd,
             klasterio_dalis = kd / length(priskyrimai),
             id = as.character(ids[indeksai]),
             stringsAsFactors = FALSE)
}

# ------------------------------------------------------------
# Aplankų kūrimas
# ------------------------------------------------------------
dir.create("grafikai", showWarnings = FALSE, recursive = TRUE)
dir.create("rezultatai", showWarnings = FALSE, recursive = TRUE)

# ------------------------------------------------------------
# Konfigūracijų palyginimas vienoje erdvėje
# ------------------------------------------------------------
analizuoti_erdve <- function(X_erdves, ids_erdves, erdves_pavadinimas,
                             trumpinys = NULL) {
  # --- 1. Atstumai ir konfigūracijos ---
  atstumai <- list(
    euclidean = dist(X_erdves, method = "euclidean"),
    manhattan = dist(X_erdves, method = "manhattan")
  )
  konfig <- expand.grid(
    atstumas = c("euclidean", "manhattan"),
    jungimas = c("single", "complete", "average", "ward.D2"),
    stringsAsFactors = FALSE
  )
  konfig <- konfig[!(konfig$jungimas == "ward.D2" &
                       konfig$atstumas == "manhattan"), ]
  konfig$pavadinimas <- paste(konfig$atstumas, konfig$jungimas, sep = "_")
  
  # --- 2. Dendrogramos ir šuoliai (be silhouette) ---
  medziai <- vector("list", nrow(konfig))
  names(medziai) <- konfig$pavadinimas
  auksciai <- list()
  
  for (i in seq_len(nrow(konfig))) {
    dist_v <- konfig$atstumas[i]
    jung_v <- konfig$jungimas[i]
    pav <- konfig$pavadinimas[i]
    medis <- hclust(atstumai[[dist_v]], method = jung_v)
    medziai[[pav]] <- medis
    
    for (k in K_REIKSMES) {
      apj <- nrow(X_erdves) - k
      auksciai[[length(auksciai) + 1]] <- data.frame(
        erdve = erdves_pavadinimas, konfiguracija = pav, k = k,
        aukscio_suolis = medis$height[apj + 1] - medis$height[apj],
        stringsAsFactors = FALSE
      )
    }
  }
  
  aukscio_lentele <- do.call(rbind, auksciai)
  
  # --- 3. Optimalus k pagal santykinį dendrogramos šuolį ---
  aukscio_lentele$santykinis_suolis <- NA_real_
  aukscio_lentele$maziausio_klasterio_dalis <- NA_real_
  for (r in seq_len(nrow(aukscio_lentele))) {
    m <- medziai[[aukscio_lentele$konfiguracija[r]]]
    kl <- cutree(m, k = aukscio_lentele$k[r])
    aukscio_lentele$santykinis_suolis[r] <-
      aukscio_lentele$aukscio_suolis[r] / max(m$height)
    aukscio_lentele$maziausio_klasterio_dalis[r] <-
      min(table(kl)) / length(kl)
  }
  tinkami <- aukscio_lentele[
    aukscio_lentele$maziausio_klasterio_dalis >= MIN_KLASTERIO_DALIS, ]
  if (nrow(tinkami) == 0) stop("Nėra k su pakankamai dideliais klasteriais.")
  geriausias <- tinkami[which.max(tinkami$santykinis_suolis), ]
  
  geriausia_konfig <- geriausias$konfiguracija
  pasirinktas_k <- geriausias$k
  geriausia_idx <- which(konfig$pavadinimas == geriausia_konfig)
  pasirinktas_medis <- medziai[[geriausia_konfig]]
  pasirinkti_klasteriai <- cutree(pasirinktas_medis, k = pasirinktas_k)
  pasirinktas_atstumas <- konfig$atstumas[geriausia_idx]
  pasirinktas_jungimas <- konfig$jungimas[geriausia_idx]
  
  
  vidiniai <- vidiniai_rodikliai(X_erdves, pasirinkti_klasteriai)
  
  # --- 4. Palyginimo lentelė (pagal konfigūraciją) ---
  
  panasumo_lentele <- do.call(rbind, lapply(seq_len(nrow(konfig)), function(i) {
    pav <- konfig$pavadinimas[i]
    sub <- tinkami[tinkami$konfiguracija == pav, ]
    if (nrow(sub) == 0) return(NULL)
    k_d <- sub$k[which.max(sub$santykinis_suolis)]
    kl <- cutree(medziai[[pav]], k = k_d)
    data.frame(
      konfiguracija = pav,
      k = k_d,
      silhouette = mean(cluster::silhouette(
        kl, atstumai[[konfig$atstumas[i]]])[, "sil_width"]),
      stringsAsFactors = FALSE
    )
  }))
  
  # --- 5. Silhouette TIK pasirinktam k ---
  silhouette_pasirinktam <- panasumo_lentele$silhouette[
    panasumo_lentele$konfiguracija == geriausia_konfig]
  
  suffix <- if (is.null(trumpinys)) "" else paste0("_", trumpinys)
  write.csv(panasumo_lentele,
            paste0("rezultatai/hierarchinis_panasumo_matu_palyginimas", suffix, ".csv"),
            row.names = FALSE)
  
  # --- 6. Grafikai ---
  pdf(paste0("grafikai/hierarchinis_dendrogramos", suffix, ".pdf"),
      width = 12, height = 8)
  par(mfrow = c(2, 2), mar = c(3, 3, 3, 1))
  for (pav in names(medziai)) {
    plot(medziai[[pav]], labels = FALSE, hang = -1, main = pav,
         xlab = "Objektai", ylab = "Jungimo atstumas")
  }
  dev.off()
  
  n_erdve <- nrow(X_erdves)
  pjovimo_aukstis <- mean(c(
    pasirinktas_medis$height[n_erdve - pasirinktas_k],
    pasirinktas_medis$height[n_erdve - pasirinktas_k + 1]
  ))
  png(paste0("grafikai/hierarchinis_dendrograma_pasirinktas", suffix, ".png"),
      width = 1800, height = 1000, res = 160)
  plot(pasirinktas_medis, labels = FALSE, hang = -1,
       main = paste0(erdves_pavadinimas, ": ", geriausia_konfig,
                     ", k = ", pasirinktas_k),
       xlab = "Objektai", ylab = "Jungimo atstumas")
  abline(h = pjovimo_aukstis, col = "red", lty = 2, lwd = 2)
  dev.off()
  
  # --- 7. Kokybė ---
  kokybe <- data.frame(
    erdve = erdves_pavadinimas,
    atstumas = pasirinktas_atstumas, jungimas = pasirinktas_jungimas,
    k = pasirinktas_k, silhouette = silhouette_pasirinktam,
    calinski_harabasz = unname(vidiniai["calinski_harabasz"]),
    davies_bouldin = unname(vidiniai["davies_bouldin"]),
    stringsAsFactors = FALSE
  )
  
  # --- 8. Grąžinimas ---
  list(
    X = X_erdves, klasteriai = pasirinkti_klasteriai,
    atstumas = pasirinktas_atstumas, jungimas = pasirinktas_jungimas,
    k = pasirinktas_k, konfiguracija = geriausia_konfig,
    medis = pasirinktas_medis, pjovimo_aukstis = pjovimo_aukstis,
    kokybe = kokybe,
    aukscio_lentele = aukscio_lentele,
    panasumo_lentele = panasumo_lentele,
    mazu_klasteriu_id = surinkti_mazu_klasteriu_id(
      pasirinkti_klasteriai, ids_erdves, erdves_pavadinimas,
      geriausia_konfig, pasirinktas_k)
  )
}

# ------------------------------------------------------------
# Originali erdvė
# ------------------------------------------------------------
modelis_originali <- analizuoti_erdve(
  X_erdves = X,
  ids_erdves = objektu_id,
  erdves_pavadinimas = originalios_erdves_pavadinimas
)

# PCA erdvė
modelis_pca <- analizuoti_erdve(
  X_erdves = pca_aibe$X,
  ids_erdves = if ("id" %in% names(pca_aibe$data)) pca_aibe$data$id else seq_len(nrow(pca_aibe$X)),
  erdves_pavadinimas = pca_erdves_pavadinimas,
  trumpinys = "pca"
)

# t-SNE erdvė
modelis_tsne <- analizuoti_erdve(
  X_erdves = tsne_aibe$X,
  ids_erdves = if ("id" %in% names(tsne_aibe$data)) tsne_aibe$data$id else seq_len(nrow(tsne_aibe$X)),
  erdves_pavadinimas = tsne_erdves_pavadinimas,
  trumpinys = "tsne"
)

modeliai <- list(
  originali = modelis_originali,
  pca = modelis_pca,
  tsne = modelis_tsne
)

# Klasteriai PCA projekcijoje (originaliai erdvei)
pca_viz <- prcomp(X, center = TRUE, scale. = FALSE)
kl_lygis <- factor(modelis_originali$klasteriai)
spalvos <- grDevices::hcl.colors(nlevels(kl_lygis), "Dark 3")
png("grafikai/hierarchinis_klasteriai_PCA.png",
    width = 1400, height = 1000, res = 150)
plot(pca_viz$x[, 1], pca_viz$x[, 2],
     col = spalvos[as.integer(kl_lygis)], pch = 16, cex = 0.6,
     xlab = "PC1", ylab = "PC2",
     main = "Hierarchiniai klasteriai PCA projekcijoje")
legend("topright", legend = levels(kl_lygis), col = spalvos,
       pch = 16, title = "Klasteris")
dev.off()

# Galutiniai klasterių failai ir profiliai (originali erdvė)

galutiniai <- duomenys
galutiniai$klasteris <- modelis_originali$klasteriai
write.csv(galutiniai, "rezultatai/hierarchinis_klasteriai.csv", row.names = FALSE)

klasteriu_dydziai <- as.data.frame(table(klasteris = modelis_originali$klasteriai))
names(klasteriu_dydziai)[2] <- "objektu_skaicius"
write.csv(klasteriu_dydziai, "rezultatai/hierarchinis_klasteriu_dydziai.csv", row.names = FALSE)

profilio_duomenys <- as.data.frame(X_originalus)
profilio_duomenys$klasteris <- factor(modelis_originali$klasteriai)
klasteriu_medianos <- aggregate(. ~ klasteris, data = profilio_duomenys, FUN = median)
write.csv(klasteriu_medianos, "rezultatai/hierarchinis_klasteriu_medianos.csv", row.names = FALSE)

if ("class" %in% names(duomenys)) {
  klasiu_sudetis <- as.data.frame(table(
    klasteris = modelis_originali$klasteriai,
    klase = duomenys$class
  ))
  names(klasiu_sudetis)[3] <- "objektu_skaicius"
  klasiu_sudetis$procentai <- ave(
    klasiu_sudetis$objektu_skaicius,
    klasiu_sudetis$klasteris,
    FUN = function(x) 100 * x / sum(x)
  )
  write.csv(klasiu_sudetis, "rezultatai/hierarchinis_klasiu_sudetis.csv", row.names = FALSE)
}

# Parametrų palyginimas ir dendrogramos šuoliai
visu_parametru <- do.call(rbind, lapply(modeliai, function(m) {
  cbind(erdve = m$kokybe$erdve, m$panasumo_lentele)
}))
write.csv(visu_parametru, "rezultatai/hierarchinis_parametru_palyginimas.csv", row.names = FALSE)
visu_auksciu <- do.call(rbind, lapply(modeliai, function(m) m$aukscio_lentele))
write.csv(visu_auksciu, "rezultatai/hierarchinis_dendrogramos_suoliai.csv", row.names = FALSE)

# Koreliuotų požymių lentelė
korel_mat <- cor(X)
korel_poros <- which(abs(korel_mat) >= KORELIACIJOS_SLENKSTIS & upper.tri(korel_mat), arr.ind = TRUE)
korel_lentele <- if (nrow(korel_poros) == 0) {
  data.frame(pozymis_1 = character(), pozymis_2 = character(), koreliacija = numeric())
} else {
  data.frame(
    pozymis_1 = rownames(korel_mat)[korel_poros[, 1]],
    pozymis_2 = colnames(korel_mat)[korel_poros[, 2]],
    koreliacija = korel_mat[korel_poros]
  )
}
write.csv(korel_lentele, "rezultatai/hierarchinis_stipriai_koreliuoti_pozymiai.csv", row.names = FALSE)


# Stabilumas 80% imtimis

stabilumo_eksperimentas <- function(erdves_pavadinimas, modelis,
                                    X_orig, trumpinys = NULL) {
  imtys <- vector("list", N_IMCIU)
  vidiniai <- vector("list", N_IMCIU)
  
  for (i in seq_len(N_IMCIU)) {
    set.seed(SEED + i - 1)
    eil <- sort(sample(seq_len(nrow(X_orig)),
                       size = floor(nrow(X_orig) * IMTIES_DALIS),
                       replace = FALSE))
    X_imtis <- robust_scale(X_orig[eil, , drop = FALSE])
    
    # Dimensijos mažinimas imtyje
    if (erdves_pavadinimas == originalios_erdves_pavadinimas) {
      X_proj <- X_imtis
    } else if (erdves_pavadinimas == pca_erdves_pavadinimas) {
      p <- prcomp(X_imtis, center = TRUE, scale. = FALSE)
      X_proj <- p$x[, seq_len(ncol(modelis$X)), drop = FALSE]
    } else {
      perp <- min(30, floor((nrow(X_imtis) - 1) / 3) - 1)
      X_proj <- Rtsne::Rtsne(
        X_imtis, dims = ncol(modelis$X),
        perplexity = perp, max_iter = 1000,
        pca = FALSE, normalize = FALSE,
        verbose = FALSE, check_duplicates = FALSE
      )$Y
    }
    
    atstumas_imt <- dist(X_proj, method = modelis$atstumas)
    medis_imt <- hclust(atstumas_imt, method = modelis$jungimas)
    kl_imt <- cutree(medis_imt, k = modelis$k)
    vid <- vidiniai_rodikliai(X_proj, kl_imt)
    sil <- mean(cluster::silhouette(kl_imt, atstumas_imt)[, "sil_width"])
    
    imtys[[i]] <- list(eilutes = eil, klasteriai = kl_imt)
    vidiniai[[i]] <- data.frame(
      imtis = i, n = length(eil),
      silhouette = sil,
      calinski_harabasz = unname(vid["calinski_harabasz"]),
      davies_bouldin = unname(vid["davies_bouldin"])
    )
  }
  
  vid_lentele <- do.call(rbind, vidiniai)
  vid_suvestine <- data.frame(
    rodiklis = c("Silhouette", "Calinski-Harabasz", "Davies-Bouldin"),
    vidurkis = c(mean(vid_lentele$silhouette),
                 mean(vid_lentele$calinski_harabasz),
                 mean(vid_lentele$davies_bouldin)),
    standartinis_nuokrypis = c(sd(vid_lentele$silhouette),
                               sd(vid_lentele$calinski_harabasz),
                               sd(vid_lentele$davies_bouldin)),
    stringsAsFactors = FALSE
  )
  
  # Porinis palyginimas
  poros <- list()
  ix <- 1
  for (i in seq_len(N_IMCIU - 1)) {
    for (j in (i + 1):N_IMCIU) {
      bendros <- intersect(imtys[[i]]$eilutes, imtys[[j]]$eilutes)
      a <- imtys[[i]]$klasteriai[match(bendros, imtys[[i]]$eilutes)]
      b <- imtys[[j]]$klasteriai[match(bendros, imtys[[j]]$eilutes)]
      poros[[ix]] <- data.frame(
        imtis_1 = i, imtis_2 = j,
        bendru_objektu = length(bendros),
        ARI = ari_rodiklis(a, b),
        NMI = nmi_rodiklis(a, b),
        Jaccard = jaccard_rodiklis(a, b),
        stringsAsFactors = FALSE
      )
      ix <- ix + 1
    }
  }
  poru_lentele <- do.call(rbind, poros)
  isor_suvestine <- data.frame(
    rodiklis = c("ARI", "NMI", "Jaccard"),
    vidurkis = c(mean(poru_lentele$ARI),
                 mean(poru_lentele$NMI),
                 mean(poru_lentele$Jaccard)),
    standartinis_nuokrypis = c(sd(poru_lentele$ARI),
                               sd(poru_lentele$NMI),
                               sd(poru_lentele$Jaccard)),
    stringsAsFactors = FALSE
  )
  
  suffix <- if (is.null(trumpinys)) "" else paste0("_", trumpinys)
  write.csv(vid_lentele,
            paste0("rezultatai/hierarchinis_stabilumo_vidiniai", suffix, ".csv"),
            row.names = FALSE)
  write.csv(vid_suvestine,
            paste0("rezultatai/hierarchinis_stabilumo_vidiniu_suvestine", suffix, ".csv"),
            row.names = FALSE)
  write.csv(poru_lentele,
            paste0("rezultatai/hierarchinis_stabilumo_porinis_palyginimas", suffix, ".csv"),
            row.names = FALSE)
  write.csv(isor_suvestine,
            paste0("rezultatai/hierarchinis_stabilumo_suvestine", suffix, ".csv"),
            row.names = FALSE)
  
  png(paste0("grafikai/hierarchinis_stabilumo_ARI", suffix, ".png"),
      width = 1200, height = 850, res = 150)
  boxplot(poru_lentele$ARI, ylab = "ARI",
          main = paste("Stabilumas:", erdves_pavadinimas),
          col = "lightblue")
  dev.off()
  
  list(vidiniai = vid_suvestine, isoriniai = isor_suvestine)
}

stab_originali <- stabilumo_eksperimentas(
  originalios_erdves_pavadinimas, modelis_originali, X_originalus
)
stab_pca <- stabilumo_eksperimentas(
  pca_erdves_pavadinimas, modelis_pca, X_originalus, "pca"
)
stab_tsne <- stabilumo_eksperimentas(
  tsne_erdves_pavadinimas, modelis_tsne, X_originalus, "tsne"
)

# ------------------------------------------------------------
# Sutapimų lentelės tarp erdvių
# ------------------------------------------------------------
sutapimas_orig_pca <- as.data.frame(table(
  originali = modelis_originali$klasteriai,
  pca = modelis_pca$klasteriai
))
names(sutapimas_orig_pca)[3] <- "tasku_skaicius"
write.csv(sutapimas_orig_pca,
          "rezultatai/hierarchinis_sutampantys_taskai_originali_pca.csv",
          row.names = FALSE)

sutapimas_orig_tsne <- as.data.frame(table(
  originali = modelis_originali$klasteriai,
  tsne = modelis_tsne$klasteriai
))
names(sutapimas_orig_tsne)[3] <- "tasku_skaicius"
write.csv(sutapimas_orig_tsne,
          "rezultatai/hierarchinis_sutampantys_taskai_originali_tsne.csv",
          row.names = FALSE)

sutapimas_pca_tsne <- as.data.frame(table(
  pca = modelis_pca$klasteriai,
  tsne = modelis_tsne$klasteriai
))
names(sutapimas_pca_tsne)[3] <- "tasku_skaicius"
write.csv(sutapimas_pca_tsne,
          "rezultatai/hierarchinis_sutampantys_taskai_pca_tsne.csv",
          row.names = FALSE)

# Išoriniai rodikliai tarp erdvių
isoriniu_erdviu <- data.frame(
  palyginimas = c(
    paste(originalios_erdves_pavadinimas, "vs", pca_erdves_pavadinimas),
    paste(originalios_erdves_pavadinimas, "vs", tsne_erdves_pavadinimas),
    paste(pca_erdves_pavadinimas, "vs", tsne_erdves_pavadinimas)
  ),
  ARI = c(
    ari_rodiklis(modelis_originali$klasteriai, modelis_pca$klasteriai),
    ari_rodiklis(modelis_originali$klasteriai, modelis_tsne$klasteriai),
    ari_rodiklis(modelis_pca$klasteriai, modelis_tsne$klasteriai)
  ),
  NMI = c(
    nmi_rodiklis(modelis_originali$klasteriai, modelis_pca$klasteriai),
    nmi_rodiklis(modelis_originali$klasteriai, modelis_tsne$klasteriai),
    nmi_rodiklis(modelis_pca$klasteriai, modelis_tsne$klasteriai)
  ),
  Jaccard = c(
    jaccard_rodiklis(modelis_originali$klasteriai, modelis_pca$klasteriai),
    jaccard_rodiklis(modelis_originali$klasteriai, modelis_tsne$klasteriai),
    jaccard_rodiklis(modelis_pca$klasteriai, modelis_tsne$klasteriai)
  ),
  stringsAsFactors = FALSE
)
write.csv(isoriniu_erdviu,
          "rezultatai/hierarchinis_erdviu_isoriniai_rodikliai.csv",
          row.names = FALSE)


# Mažų klasterių (atsiskyrėlių) ID visose erdvėse

mazu_visur <- do.call(rbind, lapply(modeliai, function(m) m$mazu_klasteriu_id))
if (is.null(mazu_visur) || nrow(mazu_visur) == 0) {
  mazu_visur <- data.frame(erdve = character(), konfiguracija = character(),
                           k = integer(), klasteris = character(),
                           klasterio_dydis = integer(),
                           klasterio_dalis = numeric(),
                           id = character(), stringsAsFactors = FALSE)
}
write.csv(mazu_visur,
          "rezultatai/hierarchinis_mazu_klasteriu_id.csv",
          row.names = FALSE)


# Bendra kokybės lentelė visose erdvėse

kokybes_visur <- do.call(rbind, lapply(modeliai, function(m) m$kokybe))
write.csv(kokybes_visur,
          "rezultatai/hierarchinis_erdviu_kokybes_palyginimas.csv",
          row.names = FALSE)

# Eksperimentų suvestinė (viena lentelė pagal skaidrę)
ari_etikete <- function(s) {
  a <- s[s$rodiklis == "ARI", , drop = FALSE]
  paste0(formatC(a$vidurkis, format = "f", digits = 3),
         " ± ", formatC(a$standartinis_nuokrypis, format = "f", digits = 3))
}

eksperimentu_suvestine <- data.frame(
  erdve = kokybes_visur$erdve,
  algoritmas = "Hierarchinis",
  parametrai = paste0("atstumas=", kokybes_visur$atstumas,
                      "; jungimas=", kokybes_visur$jungimas),
  k = kokybes_visur$k,
  Silhouette = round(kokybes_visur$silhouette, 4),
  CH = round(kokybes_visur$calinski_harabasz, 4),
  DB = round(kokybes_visur$davies_bouldin, 4),
  ARI_su_originalia = c(
    1,
    ari_rodiklis(modelis_originali$klasteriai, modelis_pca$klasteriai),
    ari_rodiklis(modelis_originali$klasteriai, modelis_tsne$klasteriai)
  ),
  NMI_su_originalia = c(
    1,
    nmi_rodiklis(modelis_originali$klasteriai, modelis_pca$klasteriai),
    nmi_rodiklis(modelis_originali$klasteriai, modelis_tsne$klasteriai)
  ),
  `Stabilumas (ARI vid. ± SN)` = c(
    ari_etikete(stab_originali$isoriniai),
    ari_etikete(stab_pca$isoriniai),
    ari_etikete(stab_tsne$isoriniai)
  ),
  SEED = SEED,
  N_IMCIU = N_IMCIU,
  Paruosimas = PARUOSIMO_BUDAS,
  Bandymo_data = format(Sys.Date(), "%Y-%m-%d"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)
write.csv(eksperimentu_suvestine,
          "rezultatai/hierarchinis_eksperimentu_suvestine.csv",
          row.names = FALSE)

# Stabilumo ir vidinių rodiklių suvestinės visose erdvėse
stab_visur <- rbind(
  transform(stab_originali$isoriniai, erdve = originalios_erdves_pavadinimas),
  transform(stab_pca$isoriniai, erdve = pca_erdves_pavadinimas),
  transform(stab_tsne$isoriniai, erdve = tsne_erdves_pavadinimas)
)
write.csv(stab_visur,
          "rezultatai/hierarchinis_stabilumo_suvestine_visose_erdvese.csv",
          row.names = FALSE)

vid_visur <- rbind(
  transform(stab_originali$vidiniai, erdve = originalios_erdves_pavadinimas),
  transform(stab_pca$vidiniai, erdve = pca_erdves_pavadinimas),
  transform(stab_tsne$vidiniai, erdve = tsne_erdves_pavadinimas)
)
write.csv(vid_visur,
          "rezultatai/hierarchinis_stabilumo_vidiniai_visose_erdvese.csv",
          row.names = FALSE)

# Modelio išsaugojimas
saveRDS(modeliai, "rezultatai/hierarchinis_modelis.rds")


# Minimali terminalo išvestis
cat("\n=== HIERARCHINIO KLASTERIZAVIMO REZULTATAI ===\n")
cat("Erdvė       | k | Konfigūracija          | Siluetas\n")
cat("------------|---|------------------------|---------\n")
for (m in modeliai) {
  cat(sprintf("%-12s| %d | %-22s| %.4f\n",
              m$kokybe$erdve, m$k, m$konfiguracija, m$kokybe$silhouette))
}
cat("\nStabilumas (ARI vid. ± SN):\n")
for (e in unique(stab_visur$erdve)) {
  s <- stab_visur[stab_visur$erdve == e, , drop = FALSE]
  a <- s[s$rodiklis == "ARI", , drop = FALSE]
  cat(sprintf("  %s: %.3f ± %.3f\n", e, a$vidurkis, a$standartinis_nuokrypis))
}
