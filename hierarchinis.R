# --- Hierarchinis klasterizavimas ---

# --- Nustatymai ---

DUOMENU_FAILAS <- "aibes/aibe_originali.csv"
ORIGINALIU_DUOMENU_FAILAS <- "aibes/C_originaliais_vienetais_interpretacijai.csv"
K_REIKSMES <- 2:10
SEED <- 42
N_IMCIU <- 10
IMTIES_DALIS <- 0.80
KORELIACIJOS_SLENKSTIS <- 0.90
MIN_KLASTERIO_DALIS <- 0.01

R_PAKETU_APLANKAS <- Sys.getenv("R_LIBS_USER")
if (!nzchar(R_PAKETU_APLANKAS)) {
  R_PAKETU_APLANKAS <- file.path(path.expand("~"), "R", "library")
}
if (!dir.exists(R_PAKETU_APLANKAS)) {
  dir.create(R_PAKETU_APLANKAS, recursive = TRUE, showWarnings = FALSE)
}
.libPaths(unique(c(R_PAKETU_APLANKAS, .libPaths())))

if (!requireNamespace("cluster", quietly = TRUE)) {
  install.packages(
    "cluster",
    repos = "https://cloud.r-project.org",
    lib = R_PAKETU_APLANKAS
  )
}
if (!requireNamespace("Rtsne", quietly = TRUE)) {
  install.packages(
    "Rtsne",
    repos = "https://cloud.r-project.org",
    lib = R_PAKETU_APLANKAS
  )
}

if (!file.exists(DUOMENU_FAILAS)) {
  stop(
    paste0(
      "Nerastas failas: ", DUOMENU_FAILAS,
      ". Pirmiausia paruoškite duomenis pagal vykdymas.R."
    )
  )
}

duomenys <- read.csv(DUOMENU_FAILAS, check.names = FALSE)
if (nrow(duomenys) < 3) stop("Duomenų aibėje turi būti bent 3 objektai.")

pozymiu_pavadinimai <- setdiff(
  names(duomenys),
  c("id", "class", "klasteris")
)
if (length(pozymiu_pavadinimai) < 2) {
  stop("Nerasta pakankamai skaitinių požymių klasterizavimui.")
}
if (!all(vapply(duomenys[pozymiu_pavadinimai], is.numeric, logical(1)))) {
  stop("Visi klasterizavimui naudojami požymiai turi būti skaitiniai.")
}

X <- as.matrix(duomenys[pozymiu_pavadinimai])
storage.mode(X) <- "double"
if (anyNA(X) || any(!is.finite(X))) {
  stop("Požymiuose yra trūkstamų arba begalinių reikšmių.")
}
if (any(apply(X, 2, sd) == 0)) {
  stop("Yra pastovios reikšmės požymių. Pašalinkite juos prieš klasterizavimą.")
}
if (max(K_REIKSMES) >= nrow(X)) {
  stop("K_REIKSMES reikšmės turi būti mažesnės už objektų skaičių.")
}

objektu_id <- if ("id" %in% names(duomenys)) duomenys$id else seq_len(nrow(duomenys))
if (anyDuplicated(objektu_id)) stop("Objektų ID turi būti unikalūs.")

nuskaityti_sumazinta_aibe <- function(failas) {
  if (!file.exists(failas)) {
    stop(paste0("Nerastas failas: ", failas, ". Paleiskite vykdymas.R."))
  }
  aibe <- read.csv(failas, check.names = FALSE)
  if ("id" %in% names(aibe) && "id" %in% names(duomenys)) {
    indeksai <- match(objektu_id, aibe$id)
    if (anyNA(indeksai)) stop(paste("Nesutampa objektų ID faile", failas))
    aibe <- aibe[indeksai, , drop = FALSE]
  } else if (nrow(aibe) != nrow(duomenys)) {
    stop(paste("Nesutampa eilučių skaičius faile", failas))
  }
  pozymiai <- setdiff(names(aibe), c("id", "class", "klasteris"))
  if (length(pozymiai) < 2 ||
      !all(vapply(aibe[pozymiai], is.numeric, logical(1)))) {
    stop(paste("Faile nerasta tinkamų skaitinių požymių:", failas))
  }
  mat <- as.matrix(aibe[pozymiai])
  storage.mode(mat) <- "double"
  if (anyNA(mat) || any(!is.finite(mat))) {
    stop(paste("Faile yra trūkstamų arba begalinių reikšmių:", failas))
  }
  list(data = aibe, X = mat)
}

pca_aibe <- nuskaityti_sumazinta_aibe("aibes/aibe_PCA.csv")
tsne_aibe <- nuskaityti_sumazinta_aibe("aibes/aibe_tSNE_2D.csv")
originalios_erdves_pavadinimas <- paste0("Originali C (", ncol(X), "D)")
pca_erdves_pavadinimas <- paste0("PCA ", ncol(pca_aibe$X), "D")
tsne_erdves_pavadinimas <- paste0("t-SNE ", ncol(tsne_aibe$X), "D")
PARUOSIMO_BUDAS <- paste(
  "Naudotos paruoštos C, PCA ir t-SNE aibės; id ir class neįtraukti;",
  "stabilumo imtyse požymiai perskaičiuoti pagal medianą ir IQR."
)

cat("Duomenys:", nrow(X), "objektų ir", ncol(X), "požymių.\n")
cat("ID ir class klasterizavimui nenaudojami.\n")

# --- Paruošimas klasterių interpretacijai ir stabilumui ---

if (file.exists(ORIGINALIU_DUOMENU_FAILAS)) {
  originalus <- read.csv(ORIGINALIU_DUOMENU_FAILAS, check.names = FALSE)
  if ("id" %in% names(originalus) && "id" %in% names(duomenys)) {
    originaliu_indeksai <- match(objektu_id, originalus$id)
    if (anyNA(originaliu_indeksai)) {
      stop("Originalių duomenų faile nerasti visi objektų ID.")
    }
    originalus <- originalus[originaliu_indeksai, , drop = FALSE]
  } else if (nrow(originalus) != nrow(duomenys)) {
    stop("Originalių duomenų ir paruoštų duomenų eilučių skaičius nesutampa.")
  }
  
  if (!all(pozymiu_pavadinimai %in% names(originalus))) {
    stop("Originalių duomenų faile trūksta klasterizuojamų požymių.")
  }
  X_originalus <- as.matrix(originalus[pozymiu_pavadinimai])
  storage.mode(X_originalus) <- "double"
  if (anyNA(X_originalus) || any(!is.finite(X_originalus))) {
    stop("Originalių duomenų požymiuose yra trūkstamų arba begalinių reikšmių.")
  }
  cat("Interpretacijai ir stabilumui naudojami originalūs matavimo vienetai.\n")
} else {
  warning(
    paste0(
      "Nerastas ", ORIGINALIU_DUOMENU_FAILAS,
      ". Klasterių profiliai ir stabilumas bus skaičiuojami iš jau normuotų duomenų."
    ),
    call. = FALSE
  )
  originalus <- duomenys
  X_originalus <- X
}

robust_scale <- function(mat) {
  centrai <- apply(mat, 2, median)
  masteliai <- apply(mat, 2, IQR)
  masteliai[!is.finite(masteliai) | masteliai == 0] <- 1
  sweep(sweep(mat, 2, centrai, "-"), 2, masteliai, "/")
}

tuscia_mazu_klasteriu_lentele <- function() {
  data.frame(
    erdve = character(),
    konfiguracija = character(),
    k = integer(),
    klasteris = character(),
    klasterio_dydis = integer(),
    klasterio_dalis = numeric(),
    id = character(),
    stringsAsFactors = FALSE
  )
}

surinkti_mazu_klasteriu_id <- function(
    priskyrimai, ids, erdve, konfiguracija, k) {
  dydziai <- table(priskyrimai)
  mazi <- names(dydziai)[as.numeric(dydziai) / length(priskyrimai) <
                           MIN_KLASTERIO_DALIS]
  indeksai <- which(as.character(priskyrimai) %in% mazi)
  if (length(indeksai) == 0) return(tuscia_mazu_klasteriu_lentele())
  
  klasteriu_pavadinimai <- as.character(priskyrimai[indeksai])
  klasteriu_dydziai <- as.integer(dydziai[klasteriu_pavadinimai])
  data.frame(
    erdve = erdve,
    konfiguracija = konfiguracija,
    k = k,
    klasteris = klasteriu_pavadinimai,
    klasterio_dydis = klasteriu_dydziai,
    klasterio_dalis = klasteriu_dydziai / length(priskyrimai),
    id = as.character(ids[indeksai]),
    stringsAsFactors = FALSE
  )
}

# --- Atstumų ir jungimo metodų palyginimas ---

atstumai <- list(
  euclidean = dist(X, method = "euclidean"),
  manhattan = dist(X, method = "manhattan")
)

konfiguracijos <- data.frame(
  atstumas = c(
    "euclidean", "euclidean", "euclidean", "euclidean",
    "manhattan", "manhattan", "manhattan"
  ),
  jungimas = c(
    "single", "complete", "average", "ward.D2",
    "single", "complete", "average"
  ),
  stringsAsFactors = FALSE
)
konfiguracijos$pavadinimas <- paste(
  konfiguracijos$atstumas,
  konfiguracijos$jungimas,
  sep = "_"
)

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
  
  calinski_harabasz <- if (k > 1 && n > k && vidine_sklaida > 0) {
    ((bendra_sklaida - vidine_sklaida) / (k - 1)) /
      (vidine_sklaida / (n - k))
  } else {
    NA_real_
  }
  
  centro_atstumai <- as.matrix(dist(centrai))
  davies_bouldin <- if (k > 1 && all(centro_atstumai[upper.tri(centro_atstumai)] > 0)) {
    didziausias <- vapply(seq_len(k), function(i) {
      santykiai <- (spinduliai[i] + spinduliai) / centro_atstumai[i, ]
      santykiai[i] <- -Inf
      max(santykiai)
    }, numeric(1))
    mean(didziausias)
  } else {
    NA_real_
  }
  
  c(
    calinski_harabasz = calinski_harabasz,
    davies_bouldin = davies_bouldin
  )
}

medziu_sarasas <- vector("list", nrow(konfiguracijos))
names(medziu_sarasas) <- konfiguracijos$pavadinimas
parametru_rezultatai <- list()
aukstu_suvestine <- list()
mazu_klasteriu_rinkiniai <- list()
rezultatu_indeksas <- 1

for (i in seq_len(nrow(konfiguracijos))) {
  atstumo_pavadinimas <- konfiguracijos$atstumas[i]
  jungimo_metodas <- konfiguracijos$jungimas[i]
  pavadinimas <- konfiguracijos$pavadinimas[i]
  medis <- hclust(
    d = atstumai[[atstumo_pavadinimas]],
    method = jungimo_metodas
  )
  medziu_sarasas[[pavadinimas]] <- medis
  
  for (k in K_REIKSMES) {
    priskyrimai <- cutree(medis, k = k)
    siluetas <- cluster::silhouette(
      priskyrimai,
      atstumai[[atstumo_pavadinimas]]
    )
    vidiniai <- vidiniai_rodikliai(X, priskyrimai)
    maziausias_klasteris <- min(table(priskyrimai))
    mazi_klasteriai <- surinkti_mazu_klasteriu_id(
      priskyrimai,
      objektu_id,
      originalios_erdves_pavadinimas,
      pavadinimas,
      k
    )
    if (nrow(mazi_klasteriai) > 0) {
      mazu_klasteriu_rinkiniai[[length(mazu_klasteriu_rinkiniai) + 1]] <-
        mazi_klasteriai
    }
    
    parametru_rezultatai[[rezultatu_indeksas]] <- data.frame(
      konfiguracija = pavadinimas,
      atstumas = atstumo_pavadinimas,
      jungimas = jungimo_metodas,
      k = k,
      maziausias_klasteris = maziausias_klasteris,
      maziausio_klasterio_dalis = maziausias_klasteris / nrow(X),
      silhouette = mean(siluetas[, "sil_width"]),
      calinski_harabasz = unname(vidiniai["calinski_harabasz"]),
      davies_bouldin = unname(vidiniai["davies_bouldin"])
    )
    rezultatu_indeksas <- rezultatu_indeksas + 1
    
    apjungimo_indeksas <- nrow(X) - k
    aukstu_suvestine[[length(aukstu_suvestine) + 1]] <- data.frame(
      konfiguracija = pavadinimas,
      atstumas = atstumo_pavadinimas,
      jungimas = jungimo_metodas,
      k = k,
      aukscio_skokis = medis$height[apjungimo_indeksas + 1] -
        medis$height[apjungimo_indeksas]
    )
  }
}

parametru_lentele <- do.call(rbind, parametru_rezultatai)
parametru_lentele <- parametru_lentele[
  order(-parametru_lentele$silhouette),
]
aukstu_lentele <- do.call(rbind, aukstu_suvestine)
originalus_mazu_klasteriai <- if (length(mazu_klasteriu_rinkiniai) > 0) {
  do.call(rbind, mazu_klasteriu_rinkiniai)
} else {
  tuscia_mazu_klasteriu_lentele()
}

parametru_lentele$tinkamas_dydis <-
  parametru_lentele$maziausio_klasterio_dalis >= MIN_KLASTERIO_DALIS
if (!any(parametru_lentele$tinkamas_dydis)) {
  stop("Nė vienas bandymas nesudarė klasterių virš nustatyto minimalaus dydžio.")
}
geriausias_siluetas <- parametru_lentele[1, , drop = FALSE]
geriausias <- parametru_lentele[
  parametru_lentele$tinkamas_dydis,
  ,
  drop = FALSE
][1, , drop = FALSE]
pasirinkta_konfiguracija <- geriausias$konfiguracija
pasirinktas_k <- geriausias$k
pasirinktas_medis <- medziu_sarasas[[pasirinkta_konfiguracija]]
pasirinktas_atstumas <- geriausias$atstumas
pasirinktas_jungimas <- geriausias$jungimas
pasirinkti_klasteriai <- cutree(pasirinktas_medis, k = pasirinktas_k)

cat("\nDidžiausias siluetas (įskaitant labai mažus klasterius):\n")
print(geriausias_siluetas)
cat("\nPasirinktas geriausias siluetas, kai visi klasteriai sudaro bent 1 %:\n")
print(geriausias)
cat(
  "\nMažesni klasteriai nei 1 % paliekami rezultatų lentelėje,",
  "bet nelaikomi pagrindine segmentacija.\n"
)

# --- Rezultatų aplankai ---

dir.create("grafikai", showWarnings = FALSE, recursive = TRUE)
dir.create("rezultatai", showWarnings = FALSE, recursive = TRUE)

koreliaciju_matrica <- cor(X)
koreliuotos_poros <- which(
  abs(koreliaciju_matrica) >= KORELIACIJOS_SLENKSTIS &
    upper.tri(koreliaciju_matrica),
  arr.ind = TRUE
)
koreliuotu_poru_lentele <- if (nrow(koreliuotos_poros) == 0) {
  data.frame(pozymis_1 = character(), pozymis_2 = character(), koreliacija = numeric())
} else {
  data.frame(
    pozymis_1 = rownames(koreliaciju_matrica)[koreliuotos_poros[, 1]],
    pozymis_2 = colnames(koreliaciju_matrica)[koreliuotos_poros[, 2]],
    koreliacija = koreliaciju_matrica[koreliuotos_poros]
  )
}
write.csv(
  koreliuotu_poru_lentele,
  "rezultatai/hierarchinis_stipriai_koreliuoti_pozymiai.csv",
  row.names = FALSE
)
if (nrow(koreliuotos_poros) > 0) {
  warning(
    paste0(
      "Rasta požymių porų, kurių |koreliacija| >= ",
      KORELIACIJOS_SLENKSTIS,
      ". Jos išsaugotos rezultatuose; požymiai nepašalinti, kad liktų ta pati ",
      "aibė kaip K-means palyginime."
    ),
    call. = FALSE
  )
}

write.csv(
  parametru_lentele,
  "rezultatai/hierarchinis_parametru_palyginimas.csv",
  row.names = FALSE
)
write.csv(
  aukstu_lentele,
  "rezultatai/hierarchinis_dendrogramos_suoliai.csv",
  row.names = FALSE
)

# --- Dendrogramos ir klasterių skaičiaus parinkimas ---

pdf("grafikai/hierarchinis_dendrogramos.pdf", width = 12, height = 8)
par(mfrow = c(2, 2), mar = c(3, 3, 3, 1))
for (i in seq_len(nrow(konfiguracijos))) {
  pavadinimas <- konfiguracijos$pavadinimas[i]
  plot(
    medziu_sarasas[[pavadinimas]],
    labels = FALSE,
    hang = -1,
    main = pavadinimas,
    xlab = "Objektai",
    ylab = "Jungimo atstumas"
  )
}
dev.off()

png("grafikai/hierarchinis_dendrograma_pasirinktas.png",
    width = 1800, height = 1000, res = 160)
par(mar = c(4, 4, 4, 1))
plot(
  pasirinktas_medis,
  labels = FALSE,
  hang = -1,
  main = paste0(
    "Pasirinkta dendrograma: ",
    pasirinkta_konfiguracija,
    ", k = ",
    pasirinktas_k
  ),
  xlab = "Objektai",
  ylab = "Jungimo atstumas"
)
n <- nrow(X)
pjovimo_aukstis <- mean(c(
  pasirinktas_medis$height[n - pasirinktas_k],
  pasirinktas_medis$height[n - pasirinktas_k + 1]
))
abline(h = pjovimo_aukstis, col = "red", lty = 2, lwd = 2)
dev.off()

sil_pagal_k <- aggregate(
  silhouette ~ k,
  data = parametru_lentele[
    parametru_lentele$konfiguracija == pasirinkta_konfiguracija,
  ],
  FUN = mean
)
sil_pagal_k <- sil_pagal_k[order(sil_pagal_k$k), ]
png("grafikai/hierarchinis_siluetas.png",
    width = 1400, height = 900, res = 150)
plot(
  sil_pagal_k$k,
  sil_pagal_k$silhouette,
  type = "b",
  pch = 19,
  xlab = "Klasterių skaičius (k)",
  ylab = "Vidutinis silueto koeficientas",
  main = paste0("Vidutinis siluetas: ", pasirinkta_konfiguracija)
)
abline(v = pasirinktas_k, col = "red", lty = 2)
dev.off()

# --- Galutiniai klasteriai ir jų aprašymas ---

galutiniai_duomenys <- duomenys
galutiniai_duomenys$klasteris <- pasirinkti_klasteriai
write.csv(
  galutiniai_duomenys,
  "rezultatai/hierarchinis_klasteriai.csv",
  row.names = FALSE
)

klasteriu_dydziai <- as.data.frame(table(klasteris = pasirinkti_klasteriai))
names(klasteriu_dydziai)[2] <- "objektu_skaicius"
write.csv(
  klasteriu_dydziai,
  "rezultatai/hierarchinis_klasteriu_dydziai.csv",
  row.names = FALSE
)

profilio_duomenys <- as.data.frame(X_originalus)
profilio_duomenys$klasteris <- factor(pasirinkti_klasteriai)
klasteriu_medianos <- aggregate(
  . ~ klasteris,
  data = profilio_duomenys,
  FUN = median
)
write.csv(
  klasteriu_medianos,
  "rezultatai/hierarchinis_klasteriu_medianos.csv",
  row.names = FALSE
)

if ("class" %in% names(duomenys)) {
  klasiu_sudetis <- as.data.frame(
    table(
      klasteris = pasirinkti_klasteriai,
      klase = duomenys$class
    )
  )
  names(klasiu_sudetis)[3] <- "objektu_skaicius"
  klasiu_sudetis$procentai <- ave(
    klasiu_sudetis$objektu_skaicius,
    klasiu_sudetis$klasteris,
    FUN = function(x) 100 * x / sum(x)
  )
  write.csv(
    klasiu_sudetis,
    "rezultatai/hierarchinis_klasiu_sudetis.csv",
    row.names = FALSE
  )
}

pasirinktas_vidinis <- vidiniai_rodikliai(X, pasirinkti_klasteriai)
pasirinktas_siluetas <- mean(
  cluster::silhouette(
    pasirinkti_klasteriai,
    atstumai[[pasirinktas_atstumas]]
  )[, "sil_width"]
)
kokybes_lentele <- data.frame(
  atstumas = pasirinktas_atstumas,
  jungimas = pasirinktas_jungimas,
  k = pasirinktas_k,
  silhouette = pasirinktas_siluetas,
  calinski_harabasz = unname(pasirinktas_vidinis["calinski_harabasz"]),
  davies_bouldin = unname(pasirinktas_vidinis["davies_bouldin"])
)
write.csv(
  kokybes_lentele,
  "rezultatai/hierarchinis_kokybes_rodikliai.csv",
  row.names = FALSE
)

pca <- prcomp(X, center = TRUE, scale. = FALSE)
klasteriu_lygis <- factor(pasirinkti_klasteriai)
spalvos <- grDevices::hcl.colors(nlevels(klasteriu_lygis), "Dark 3")
png("grafikai/hierarchinis_klasteriai_PCA.png",
    width = 1400, height = 1000, res = 150)
plot(
  pca$x[, 1],
  pca$x[, 2],
  col = spalvos[as.integer(klasteriu_lygis)],
  pch = 16,
  cex = 0.6,
  xlab = "Pirma pagrindinė komponentė",
  ylab = "Antra pagrindinė komponentė",
  main = "Hierarchiniai klasteriai PCA projekcijoje"
)
legend(
  "topright",
  legend = levels(klasteriu_lygis),
  col = spalvos,
  pch = 16,
  title = "Klasteris"
)
dev.off()

saveRDS(
  list(
    medis = pasirinktas_medis,
    konfiguracija = pasirinkta_konfiguracija,
    k = pasirinktas_k,
    klasteriai = pasirinkti_klasteriai,
    pozymiai = pozymiu_pavadinimai
  ),
  "rezultatai/hierarchinis_modelis.rds"
)

modeliai <- list(
  originali = list(
    X = X,
    klasteriai = pasirinkti_klasteriai,
    atstumas = pasirinktas_atstumas,
    jungimas = pasirinktas_jungimas,
    k = pasirinktas_k,
    konfiguracija = pasirinkta_konfiguracija,
    kokybe = kokybes_lentele,
    mazu_klasteriu_id = originalus_mazu_klasteriai
  )
)

analizuoti_sumazinta_aibe <- function(aibe, trumpinys, pavadinimas) {
  X_erdves <- aibe$X
  ids_erdves <- if ("id" %in% names(aibe$data)) {
    aibe$data$id
  } else {
    seq_len(nrow(X_erdves))
  }
  atstumai_erdveje <- list(
    euclidean = dist(X_erdves, method = "euclidean"),
    manhattan = dist(X_erdves, method = "manhattan")
  )
  medziai <- vector("list", nrow(konfiguracijos))
  names(medziai) <- konfiguracijos$pavadinimas
  rez <- list()
  auksciai <- list()
  mazu_klasteriu_rinkiniai <- list()
  ix <- 1
  
  for (i in seq_len(nrow(konfiguracijos))) {
    dist_vardas <- konfiguracijos$atstumas[i]
    jungimo_vardas <- konfiguracijos$jungimas[i]
    config_vardas <- konfiguracijos$pavadinimas[i]
    medis <- hclust(
      atstumai_erdveje[[dist_vardas]],
      method = jungimo_vardas
    )
    medziai[[config_vardas]] <- medis
    
    for (k in K_REIKSMES) {
      klasteriai <- cutree(medis, k = k)
      sil <- cluster::silhouette(klasteriai, atstumai_erdveje[[dist_vardas]])
      vidiniai <- vidiniai_rodikliai(X_erdves, klasteriai)
      maziausias_klasteris <- min(table(klasteriai))
      mazi_klasteriai <- surinkti_mazu_klasteriu_id(
        klasteriai,
        ids_erdves,
        pavadinimas,
        config_vardas,
        k
      )
      if (nrow(mazi_klasteriai) > 0) {
        mazu_klasteriu_rinkiniai[[length(mazu_klasteriu_rinkiniai) + 1]] <-
          mazi_klasteriai
      }
      rez[[ix]] <- data.frame(
        erdve = pavadinimas,
        konfiguracija = config_vardas,
        atstumas = dist_vardas,
        jungimas = jungimo_vardas,
        k = k,
        maziausias_klasteris = maziausias_klasteris,
        maziausio_klasterio_dalis = maziausias_klasteris / nrow(X_erdves),
        silhouette = mean(sil[, "sil_width"]),
        calinski_harabasz = unname(vidiniai["calinski_harabasz"]),
        davies_bouldin = unname(vidiniai["davies_bouldin"])
      )
      ix <- ix + 1
      apjungimo_indeksas <- nrow(X_erdves) - k
      auksciai[[length(auksciai) + 1]] <- data.frame(
        konfiguracija = config_vardas,
        atstumas = dist_vardas,
        jungimas = jungimo_vardas,
        k = k,
        aukscio_skokis = medis$height[apjungimo_indeksas + 1] -
          medis$height[apjungimo_indeksas]
      )
    }
  }
  
  parametrai <- do.call(rbind, rez)
  parametrai <- parametrai[order(-parametrai$silhouette), ]
  parametrai$tinkamas_dydis <-
    parametrai$maziausio_klasterio_dalis >= MIN_KLASTERIO_DALIS
  if (!any(parametrai$tinkamas_dydis)) {
    stop(paste("Nė vienas", pavadinimas, "bandymas nesudarė pakankamai didelių klasterių."))
  }
  aukscio_suvestine <- do.call(rbind, auksciai)
  geriausias_siluetas <- parametrai[1, , drop = FALSE]
  geriausias <- parametrai[parametrai$tinkamas_dydis, , drop = FALSE][1, , drop = FALSE]
  pasirinktas_konfig <- geriausias$konfiguracija
  pasirinktas_tree <- medziai[[pasirinktas_konfig]]
  klasteriai <- cutree(pasirinktas_tree, k = geriausias$k)
  suffix <- paste0("_", trumpinys)
  
  write.csv(
    parametrai,
    paste0("rezultatai/hierarchinis_parametru_palyginimas", suffix, ".csv"),
    row.names = FALSE
  )
  write.csv(
    aukscio_suvestine,
    paste0("rezultatai/hierarchinis_dendrogramos_suoliai", suffix, ".csv"),
    row.names = FALSE
  )
  
  pdf(
    paste0("grafikai/hierarchinis_dendrogramos", suffix, ".pdf"),
    width = 12,
    height = 8
  )
  par(mfrow = c(2, 2), mar = c(3, 3, 3, 1))
  for (config_vardas in names(medziai)) {
    plot(
      medziai[[config_vardas]],
      labels = FALSE,
      hang = -1,
      main = paste(pavadinimas, config_vardas),
      xlab = "Objektai",
      ylab = "Jungimo atstumas"
    )
  }
  dev.off()
  
  n_erdve <- nrow(X_erdves)
  pjovimo_aukstis_erdves <- mean(c(
    pasirinktas_tree$height[n_erdve - geriausias$k],
    pasirinktas_tree$height[n_erdve - geriausias$k + 1]
  ))
  png(
    paste0("grafikai/hierarchinis_dendrograma_pasirinktas", suffix, ".png"),
    width = 1800,
    height = 1000,
    res = 160
  )
  plot(
    pasirinktas_tree,
    labels = FALSE,
    hang = -1,
    main = paste0(pavadinimas, ": ", pasirinktas_konfig, ", k = ", geriausias$k),
    xlab = "Objektai",
    ylab = "Jungimo atstumas"
  )
  abline(h = pjovimo_aukstis_erdves, col = "red", lty = 2, lwd = 2)
  dev.off()
  
  sil_pagal_k_erdve <- aggregate(
    silhouette ~ k,
    data = parametrai[parametrai$konfiguracija == pasirinktas_konfig, ],
    FUN = mean
  )
  sil_pagal_k_erdve <- sil_pagal_k_erdve[order(sil_pagal_k_erdve$k), ]
  png(
    paste0("grafikai/hierarchinis_siluetas", suffix, ".png"),
    width = 1400,
    height = 900,
    res = 150
  )
  plot(
    sil_pagal_k_erdve$k,
    sil_pagal_k_erdve$silhouette,
    type = "b",
    pch = 19,
    xlab = "Klasterių skaičius (k)",
    ylab = "Vidutinis silueto koeficientas",
    main = paste("Vidutinis siluetas:", pavadinimas, pasirinktas_konfig)
  )
  abline(v = geriausias$k, col = "red", lty = 2)
  dev.off()
  
  galutiniai <- aibe$data
  galutiniai$klasteris <- klasteriai
  write.csv(
    galutiniai,
    paste0("rezultatai/hierarchinis_klasteriai", suffix, ".csv"),
    row.names = FALSE
  )
  dydziai <- as.data.frame(table(klasteris = klasteriai))
  names(dydziai)[2] <- "objektu_skaicius"
  write.csv(
    dydziai,
    paste0("rezultatai/hierarchinis_klasteriu_dydziai", suffix, ".csv"),
    row.names = FALSE
  )
  
  profilio_duomenys_erdves <- as.data.frame(X_originalus)
  profilio_duomenys_erdves$klasteris <- factor(klasteriai)
  medianos_erdves <- aggregate(
    . ~ klasteris,
    data = profilio_duomenys_erdves,
    FUN = median
  )
  write.csv(
    medianos_erdves,
    paste0("rezultatai/hierarchinis_klasteriu_medianos", suffix, ".csv"),
    row.names = FALSE
  )
  
  if ("class" %in% names(galutiniai)) {
    klasiu_sudetis_erdves <- as.data.frame(
      table(klasteris = klasteriai, klase = galutiniai$class)
    )
    names(klasiu_sudetis_erdves)[3] <- "objektu_skaicius"
    klasiu_sudetis_erdves$procentai <- ave(
      klasiu_sudetis_erdves$objektu_skaicius,
      klasiu_sudetis_erdves$klasteris,
      FUN = function(x) 100 * x / sum(x)
    )
    write.csv(
      klasiu_sudetis_erdves,
      paste0("rezultatai/hierarchinis_klasiu_sudetis", suffix, ".csv"),
      row.names = FALSE
    )
  }
  
  vidiniai <- vidiniai_rodikliai(X_erdves, klasteriai)
  siluetas <- mean(
    cluster::silhouette(
      klasteriai,
      atstumai_erdveje[[geriausias$atstumas]]
    )[, "sil_width"]
  )
  kokybe <- data.frame(
    erdve = pavadinimas,
    atstumas = geriausias$atstumas,
    jungimas = geriausias$jungimas,
    k = geriausias$k,
    silhouette = siluetas,
    calinski_harabasz = unname(vidiniai["calinski_harabasz"]),
    davies_bouldin = unname(vidiniai["davies_bouldin"])
  )
  write.csv(
    kokybe,
    paste0("rezultatai/hierarchinis_kokybes_rodikliai", suffix, ".csv"),
    row.names = FALSE
  )
  
  klasteriu_lygis_erdves <- factor(klasteriai)
  spalvos_erdves <- grDevices::hcl.colors(
    nlevels(klasteriu_lygis_erdves),
    "Dark 3"
  )
  png(
    paste0("grafikai/hierarchinis_klasteriai", suffix, ".png"),
    width = 1400,
    height = 1000,
    res = 150
  )
  plot(
    X_erdves[, 1],
    X_erdves[, 2],
    col = spalvos_erdves[as.integer(klasteriu_lygis_erdves)],
    pch = 16,
    cex = 0.6,
    xlab = colnames(X_erdves)[1],
    ylab = colnames(X_erdves)[2],
    main = paste("Hierarchiniai klasteriai:", pavadinimas)
  )
  legend(
    "topright",
    legend = levels(klasteriu_lygis_erdves),
    col = spalvos_erdves,
    pch = 16,
    title = "Klasteris"
  )
  dev.off()
  
  saveRDS(
    list(
      medis = pasirinktas_tree,
      konfiguracija = pasirinktas_konfig,
      k = geriausias$k,
      klasteriai = klasteriai,
      atstumas = geriausias$atstumas,
      jungimas = geriausias$jungimas
    ),
    paste0("rezultatai/hierarchinis_modelis", suffix, ".rds")
  )
  
  list(
    X = X_erdves,
    klasteriai = klasteriai,
    atstumas = geriausias$atstumas,
    jungimas = geriausias$jungimas,
    k = geriausias$k,
    konfiguracija = pasirinktas_konfig,
    kokybe = kokybe,
    siluetas_be_dydzio_ribos = geriausias_siluetas,
    mazu_klasteriu_id = if (length(mazu_klasteriu_rinkiniai) > 0) {
      do.call(rbind, mazu_klasteriu_rinkiniai)
    } else {
      tuscia_mazu_klasteriu_lentele()
    }
  )
}

modeliai$pca <- analizuoti_sumazinta_aibe(
  pca_aibe,
  "pca",
  pca_erdves_pavadinimas
)
modeliai$tsne <- analizuoti_sumazinta_aibe(
  tsne_aibe,
  "tsne",
  tsne_erdves_pavadinimas
)

# --- Stabilumo vertinimas 80 % imtimis ---

stabilumo_imtys <- vector("list", N_IMCIU)
vidiniu_rodikliu_imtys <- vector("list", N_IMCIU)

for (i in seq_len(N_IMCIU)) {
  set.seed(SEED + i - 1)
  eilutes <- sort(sample(
    seq_len(nrow(X_originalus)),
    size = floor(nrow(X_originalus) * IMTIES_DALIS),
    replace = FALSE
  ))
  X_imtis <- robust_scale(X_originalus[eilutes, , drop = FALSE])
  atstumas_imties <- dist(X_imtis, method = pasirinktas_atstumas)
  medis_imties <- hclust(atstumas_imties, method = pasirinktas_jungimas)
  klasteriai_imties <- cutree(medis_imties, k = pasirinktas_k)
  
  vidiniai_imties <- vidiniai_rodikliai(X_imtis, klasteriai_imties)
  siluetas_imties <- mean(
    cluster::silhouette(klasteriai_imties, atstumas_imties)[, "sil_width"]
  )
  
  stabilumo_imtys[[i]] <- list(
    eilutes = eilutes,
    klasteriai = klasteriai_imties
  )
  vidiniu_rodikliu_imtys[[i]] <- data.frame(
    imtis = i,
    objektu_skaicius = length(eilutes),
    silhouette = siluetas_imties,
    calinski_harabasz = unname(vidiniai_imties["calinski_harabasz"]),
    davies_bouldin = unname(vidiniai_imties["davies_bouldin"])
  )
}

vidiniu_rodikliu_imciu_lentele <- do.call(rbind, vidiniu_rodikliu_imtys)
write.csv(
  vidiniu_rodikliu_imciu_lentele,
  "rezultatai/hierarchinis_stabilumo_vidiniai.csv",
  row.names = FALSE
)
vidiniu_rodikliu_suvestine <- data.frame(
  rodiklis = c("Silhouette", "Calinski-Harabasz", "Davies-Bouldin"),
  vidurkis = c(
    mean(vidiniu_rodikliu_imciu_lentele$silhouette),
    mean(vidiniu_rodikliu_imciu_lentele$calinski_harabasz),
    mean(vidiniu_rodikliu_imciu_lentele$davies_bouldin)
  ),
  standartinis_nuokrypis = c(
    sd(vidiniu_rodikliu_imciu_lentele$silhouette),
    sd(vidiniu_rodikliu_imciu_lentele$calinski_harabasz),
    sd(vidiniu_rodikliu_imciu_lentele$davies_bouldin)
  )
)
write.csv(
  vidiniu_rodikliu_suvestine,
  "rezultatai/hierarchinis_stabilumo_vidiniu_suvestine.csv",
  row.names = FALSE
)

ari_rodiklis <- function(a, b) {
  lentele <- table(a, b)
  poros <- function(x) sum(x * (x - 1) / 2)
  sutampancios_por <- poros(lentele)
  eiluciu_por <- poros(rowSums(lentele))
  stulpeliu_por <- poros(colSums(lentele))
  visu_poru <- choose(sum(lentele), 2)
  tiketina <- eiluciu_por * stulpeliu_por / visu_poru
  didziausia <- (eiluciu_por + stulpeliu_por) / 2
  vardiklis <- didziausia - tiketina
  if (abs(vardiklis) < .Machine$double.eps) {
    return(if (abs(sutampancios_por - didziausia) < 1e-10) 1 else 0)
  }
  (sutampancios_por - tiketina) / vardiklis
}

nmi_rodiklis <- function(a, b) {
  lentele <- table(a, b)
  p <- lentele / sum(lentele)
  p_eil <- rowSums(p)
  p_stulp <- colSums(p)
  bendras <- outer(p_eil, p_stulp)
  aktyvus <- p > 0
  tarpusavio_informacija <- sum(p[aktyvus] * log(p[aktyvus] / bendras[aktyvus]))
  entropija_a <- -sum(p_eil[p_eil > 0] * log(p_eil[p_eil > 0]))
  entropija_b <- -sum(p_stulp[p_stulp > 0] * log(p_stulp[p_stulp > 0]))
  vardiklis <- (entropija_a + entropija_b) / 2
  if (vardiklis == 0) return(1)
  tarpusavio_informacija / vardiklis
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

stabiluma_sumazintoje_aibeje <- function(vardas, modelis, komponentu_skaicius) {
  imtys <- vector("list", N_IMCIU)
  vidiniai <- vector("list", N_IMCIU)
  
  for (i in seq_len(N_IMCIU)) {
    set.seed(SEED + i - 1)
    eilutes <- sort(sample(
      seq_len(nrow(X_originalus)),
      size = floor(nrow(X_originalus) * IMTIES_DALIS),
      replace = FALSE
    ))
    X_imtis <- robust_scale(X_originalus[eilutes, , drop = FALSE])
    
    if (vardas == "pca") {
      projekcija <- prcomp(X_imtis, center = TRUE, scale. = FALSE)$x
      X_imtis <- projekcija[, seq_len(komponentu_skaicius), drop = FALSE]
    } else {
      perplexity <- min(30, floor((nrow(X_imtis) - 1) / 3) - 1)
      X_imtis <- Rtsne::Rtsne(
        X_imtis,
        dims = komponentu_skaicius,
        perplexity = perplexity,
        max_iter = 1000,
        pca = FALSE,
        normalize = FALSE,
        verbose = FALSE,
        check_duplicates = FALSE
      )$Y
    }
    
    atstumas_imties <- dist(X_imtis, method = modelis$atstumas)
    medis_imties <- hclust(atstumas_imties, method = modelis$jungimas)
    klasteriai_imties <- cutree(medis_imties, k = modelis$k)
    rodikliai <- vidiniai_rodikliai(X_imtis, klasteriai_imties)
    sil <- mean(
      cluster::silhouette(klasteriai_imties, atstumas_imties)[, "sil_width"]
    )
    
    imtys[[i]] <- list(eilutes = eilutes, klasteriai = klasteriai_imties)
    vidiniai[[i]] <- data.frame(
      imtis = i,
      objektu_skaicius = length(eilutes),
      silhouette = sil,
      calinski_harabasz = unname(rodikliai["calinski_harabasz"]),
      davies_bouldin = unname(rodikliai["davies_bouldin"])
    )
  }
  
  vidiniu_rezultatai <- do.call(rbind, vidiniai)
  vidiniu_suvestine <- data.frame(
    rodiklis = c("Silhouette", "Calinski-Harabasz", "Davies-Bouldin"),
    vidurkis = c(
      mean(vidiniu_rezultatai$silhouette),
      mean(vidiniu_rezultatai$calinski_harabasz),
      mean(vidiniu_rezultatai$davies_bouldin)
    ),
    standartinis_nuokrypis = c(
      sd(vidiniu_rezultatai$silhouette),
      sd(vidiniu_rezultatai$calinski_harabasz),
      sd(vidiniu_rezultatai$davies_bouldin)
    )
  )
  
  poros <- list()
  ix <- 1
  for (i in seq_len(N_IMCIU - 1)) {
    for (j in (i + 1):N_IMCIU) {
      bendros <- intersect(imtys[[i]]$eilutes, imtys[[j]]$eilutes)
      a <- imtys[[i]]$klasteriai[match(bendros, imtys[[i]]$eilutes)]
      b <- imtys[[j]]$klasteriai[match(bendros, imtys[[j]]$eilutes)]
      poros[[ix]] <- data.frame(
        imtis_1 = i,
        imtis_2 = j,
        bendru_objektu = length(bendros),
        ARI = ari_rodiklis(a, b),
        NMI = nmi_rodiklis(a, b),
        Jaccard = jaccard_rodiklis(a, b)
      )
      ix <- ix + 1
    }
  }
  poru_lentele <- do.call(rbind, poros)
  isoriniai_suvestine <- data.frame(
    rodiklis = c("ARI", "NMI", "Jaccard"),
    vidurkis = c(
      mean(poru_lentele$ARI),
      mean(poru_lentele$NMI),
      mean(poru_lentele$Jaccard)
    ),
    standartinis_nuokrypis = c(
      sd(poru_lentele$ARI),
      sd(poru_lentele$NMI),
      sd(poru_lentele$Jaccard)
    )
  )
  
  write.csv(
    vidiniu_rezultatai,
    paste0("rezultatai/hierarchinis_stabilumo_vidiniai_", vardas, ".csv"),
    row.names = FALSE
  )
  write.csv(
    vidiniu_suvestine,
    paste0("rezultatai/hierarchinis_stabilumo_vidiniu_suvestine_", vardas, ".csv"),
    row.names = FALSE
  )
  write.csv(
    poru_lentele,
    paste0("rezultatai/hierarchinis_stabilumo_porinis_palyginimas_", vardas, ".csv"),
    row.names = FALSE
  )
  write.csv(
    isoriniai_suvestine,
    paste0("rezultatai/hierarchinis_stabilumo_suvestine_", vardas, ".csv"),
    row.names = FALSE
  )
  
  png(
    paste0("grafikai/hierarchinis_stabilumo_ARI_", vardas, ".png"),
    width = 1200,
    height = 850,
    res = 150
  )
  boxplot(
    poru_lentele$ARI,
    ylab = "ARI",
    main = paste0("Hierarchinio klasterizavimo stabilumas: ", vardas),
    col = "lightblue"
  )
  dev.off()
  
  list(
    vidiniai = vidiniu_suvestine,
    isoriniai = isoriniai_suvestine
  )
}

stabilumas_pca <- stabiluma_sumazintoje_aibeje(
  "pca",
  modeliai$pca,
  ncol(pca_aibe$X)
)
stabilumas_tsne <- stabiluma_sumazintoje_aibeje(
  "tsne",
  modeliai$tsne,
  ncol(tsne_aibe$X)
)

poru_rezultatai <- list()
poros_indeksas <- 1
for (i in seq_len(N_IMCIU - 1)) {
  for (j in (i + 1):N_IMCIU) {
    bendros_eilutes <- intersect(
      stabilumo_imtys[[i]]$eilutes,
      stabilumo_imtys[[j]]$eilutes
    )
    klasteriai_i <- stabilumo_imtys[[i]]$klasteriai[
      match(bendros_eilutes, stabilumo_imtys[[i]]$eilutes)
    ]
    klasteriai_j <- stabilumo_imtys[[j]]$klasteriai[
      match(bendros_eilutes, stabilumo_imtys[[j]]$eilutes)
    ]
    poru_rezultatai[[poros_indeksas]] <- data.frame(
      imtis_1 = i,
      imtis_2 = j,
      bendru_objektu = length(bendros_eilutes),
      ARI = ari_rodiklis(klasteriai_i, klasteriai_j),
      NMI = nmi_rodiklis(klasteriai_i, klasteriai_j),
      Jaccard = jaccard_rodiklis(klasteriai_i, klasteriai_j)
    )
    poros_indeksas <- poros_indeksas + 1
  }
}

poru_lentele <- do.call(rbind, poru_rezultatai)
write.csv(
  poru_lentele,
  "rezultatai/hierarchinis_stabilumo_porinis_palyginimas.csv",
  row.names = FALSE
)

stabilumo_suvestine <- data.frame(
  rodiklis = c("ARI", "NMI", "Jaccard"),
  vidurkis = c(
    mean(poru_lentele$ARI),
    mean(poru_lentele$NMI),
    mean(poru_lentele$Jaccard)
  ),
  standartinis_nuokrypis = c(
    sd(poru_lentele$ARI),
    sd(poru_lentele$NMI),
    sd(poru_lentele$Jaccard)
  )
)
write.csv(
  stabilumo_suvestine,
  "rezultatai/hierarchinis_stabilumo_suvestine.csv",
  row.names = FALSE
)

png("grafikai/hierarchinis_stabilumo_ARI.png",
    width = 1200, height = 850, res = 150)
boxplot(
  poru_lentele$ARI,
  ylab = "ARI",
  main = paste0("Hierarchinio klasterizavimo stabilumas (", N_IMCIU, " imčių)"),
  col = "lightblue"
)
dev.off()

isoriniu_erdviu_palyginimas <- data.frame(
  palyginimas = c(
    paste(originalios_erdves_pavadinimas, "ir", pca_erdves_pavadinimas),
    paste(originalios_erdves_pavadinimas, "ir", tsne_erdves_pavadinimas),
    paste(pca_erdves_pavadinimas, "ir", tsne_erdves_pavadinimas)
  ),
  ARI = c(
    ari_rodiklis(modeliai$originali$klasteriai, modeliai$pca$klasteriai),
    ari_rodiklis(modeliai$originali$klasteriai, modeliai$tsne$klasteriai),
    ari_rodiklis(modeliai$pca$klasteriai, modeliai$tsne$klasteriai)
  ),
  NMI = c(
    nmi_rodiklis(modeliai$originali$klasteriai, modeliai$pca$klasteriai),
    nmi_rodiklis(modeliai$originali$klasteriai, modeliai$tsne$klasteriai),
    nmi_rodiklis(modeliai$pca$klasteriai, modeliai$tsne$klasteriai)
  ),
  Jaccard = c(
    jaccard_rodiklis(modeliai$originali$klasteriai, modeliai$pca$klasteriai),
    jaccard_rodiklis(modeliai$originali$klasteriai, modeliai$tsne$klasteriai),
    jaccard_rodiklis(modeliai$pca$klasteriai, modeliai$tsne$klasteriai)
  )
)
write.csv(
  isoriniu_erdviu_palyginimas,
  "rezultatai/hierarchinis_erdviu_isoriniai_rodikliai.csv",
  row.names = FALSE
)

sutapimas_originali_pca <- as.data.frame(table(
  originali_klasteris = modeliai$originali$klasteriai,
  pca_klasteris = modeliai$pca$klasteriai
))
names(sutapimas_originali_pca)[3] <- "tasku_skaicius"
write.csv(
  sutapimas_originali_pca,
  "rezultatai/hierarchinis_sutampantys_taskai_originali_pca.csv",
  row.names = FALSE
)

sutapimas_originali_tsne <- as.data.frame(table(
  originali_klasteris = modeliai$originali$klasteriai,
  tsne_klasteris = modeliai$tsne$klasteriai
))
names(sutapimas_originali_tsne)[3] <- "tasku_skaicius"
write.csv(
  sutapimas_originali_tsne,
  "rezultatai/hierarchinis_sutampantys_taskai_originali_tsne.csv",
  row.names = FALSE
)

mazu_klasteriu_lenteles <- Filter(
  function(lentele) nrow(lentele) > 0,
  list(
    modeliai$originali$mazu_klasteriu_id,
    modeliai$pca$mazu_klasteriu_id,
    modeliai$tsne$mazu_klasteriu_id
  )
)
mazu_klasteriai_visose_erdvese <- if (length(mazu_klasteriu_lenteles) > 0) {
  do.call(rbind, mazu_klasteriu_lenteles)
} else {
  tuscia_mazu_klasteriu_lentele()
}
write.csv(
  mazu_klasteriai_visose_erdvese,
  "rezultatai/hierarchinis_mazu_klasteriu_id.csv",
  row.names = FALSE
)

kokybes_visose_erdvese <- do.call(
  rbind,
  lapply(names(modeliai), function(vardas) {
    lentele <- modeliai[[vardas]]$kokybe
    if (!"erdve" %in% names(lentele)) {
      lentele$erdve <- originalios_erdves_pavadinimas
    }
    lentele
  })
)
kokybes_visose_erdvese <- kokybes_visose_erdvese[
  , c(
    "erdve", "atstumas", "jungimas", "k",
    "silhouette", "calinski_harabasz", "davies_bouldin"
  )
]
write.csv(
  kokybes_visose_erdvese,
  "rezultatai/hierarchinis_erdviu_kokybes_palyginimas.csv",
  row.names = FALSE
)

stabilumas_visose_erdvese <- rbind(
  transform(stabilumo_suvestine, erdve = originalios_erdves_pavadinimas),
  transform(stabilumas_pca$isoriniai, erdve = pca_erdves_pavadinimas),
  transform(stabilumas_tsne$isoriniai, erdve = tsne_erdves_pavadinimas)
)
write.csv(
  stabilumas_visose_erdvese,
  "rezultatai/hierarchinis_stabilumo_visose_erdvese.csv",
  row.names = FALSE
)

vidiniai_visose_erdvese <- rbind(
  transform(vidiniu_rodikliu_suvestine, erdve = originalios_erdves_pavadinimas),
  transform(stabilumas_pca$vidiniai, erdve = pca_erdves_pavadinimas),
  transform(stabilumas_tsne$vidiniai, erdve = tsne_erdves_pavadinimas)
)
write.csv(
  vidiniai_visose_erdvese,
  "rezultatai/hierarchinis_stabilumo_vidiniai_visose_erdvese.csv",
  row.names = FALSE
)

stabilumo_ari_etikete <- function(suvestine) {
  ari <- suvestine[suvestine$rodiklis == "ARI", , drop = FALSE]
  paste0(
    formatC(ari$vidurkis, format = "f", digits = 3),
    " ± ",
    formatC(ari$standartinis_nuokrypis, format = "f", digits = 3)
  )
}

eksperimentu_suvestine <- data.frame(
  erdve = kokybes_visose_erdvese$erdve,
  algoritmas = rep(
    "Hierarchinis klasterizavimas",
    nrow(kokybes_visose_erdvese)
  ),
  parametrai = paste0(
    "atstumas=", kokybes_visose_erdvese$atstumas,
    "; jungimas=", kokybes_visose_erdvese$jungimas
  ),
  k = kokybes_visose_erdvese$k,
  Silhouette = kokybes_visose_erdvese$silhouette,
  CH = kokybes_visose_erdvese$calinski_harabasz,
  DB = kokybes_visose_erdvese$davies_bouldin,
  ARI_su_originalia_C = c(
    1,
    ari_rodiklis(modeliai$originali$klasteriai, modeliai$pca$klasteriai),
    ari_rodiklis(modeliai$originali$klasteriai, modeliai$tsne$klasteriai)
  ),
  NMI_su_originalia_C = c(
    1,
    nmi_rodiklis(modeliai$originali$klasteriai, modeliai$pca$klasteriai),
    nmi_rodiklis(modeliai$originali$klasteriai, modeliai$tsne$klasteriai)
  ),
  `Stabilumas (ARI vidurkis ± SN)` = c(
    stabilumo_ari_etikete(stabilumo_suvestine),
    stabilumo_ari_etikete(stabilumas_pca$isoriniai),
    stabilumo_ari_etikete(stabilumas_tsne$isoriniai)
  ),
  SEED = rep(SEED, nrow(kokybes_visose_erdvese)),
  N_IMCIU = rep(N_IMCIU, nrow(kokybes_visose_erdvese)),
  Paruosimas = rep(PARUOSIMO_BUDAS, nrow(kokybes_visose_erdvese)),
  Bandymo_data = rep(
    format(Sys.Date(), "%Y-%m-%d"),
    nrow(kokybes_visose_erdvese)
  ),
  check.names = FALSE,
  stringsAsFactors = FALSE
)
write.csv(
  eksperimentu_suvestine,
  "rezultatai/hierarchinis_eksperimentu_suvestine.csv",
  row.names = FALSE
)

cat("\nPasirinkta konfigūracija:", pasirinkta_konfiguracija, "\n")
cat("Pasirinktas klasterių skaičius:", pasirinktas_k, "\n")
cat("Vidutinis siluetas:", round(pasirinktas_siluetas, 4), "\n")
cat("\nKlasterių skaičius erdvėse:\n")
cat("Originali C:", modeliai$originali$k, "\n")
cat("PCA 5D:", modeliai$pca$k, "\n")
cat("t-SNE 2D:", modeliai$tsne$k, "\n")
cat("\nStabilumo išorinių rodiklių suvestinė, originali C:\n")
print(stabilumo_suvestine)
cat("\nStabilumo vidinių rodiklių suvestinė, originali C:\n")
print(vidiniu_rodikliu_suvestine)
cat("\nKlasterių panašumas tarp dimensijų:\n")
print(isoriniu_erdviu_palyginimas)
cat("\nRezultatai išsaugoti aplankuose grafikai/ ir rezultatai/.\n")
