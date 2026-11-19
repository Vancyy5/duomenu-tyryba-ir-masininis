# 1. Originali C aibė (19D): duomenų patikra ir kaimynų atstumai

reikalingi_paketai <- c("dbscan", "ggplot2")

for (paketas in reikalingi_paketai) {
  if (!requireNamespace(paketas, quietly = TRUE)) {
    install.packages(paketas)
  }
}

library(ggplot2)

dir.create("grafikai", showWarnings = FALSE)
dir.create("rezultatai", showWarnings = FALSE)

# Nuskaitome jau normuotą originalią C aibę.
aibe <- read.csv("aibes/aibe_originali.csv")

# Patikriname objektų identifikatorius.
stopifnot(
  all(c("id", "class") %in% names(aibe)),
  !anyNA(aibe$id),
  !anyDuplicated(aibe$id)
)

# ID ir klasės klasterizavimui nenaudojami.
pozymiai <- setdiff(names(aibe), c("id", "class"))

stopifnot(
  length(pozymiai) == 19L,
  all(vapply(
    aibe[, pozymiai, drop = FALSE],
    is.numeric,
    logical(1)
  ))
)

x <- as.matrix(aibe[, pozymiai, drop = FALSE])

stopifnot(all(is.finite(x)))

cat("Objektų:", nrow(x), "\n")
cat("Skaitinių požymių:", ncol(x), "\n")

# Bendras stilius DBSCAN grafikams.
tema_dbscan <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(colour = "black"),
      plot.subtitle = element_text(colour = "black"),
      panel.grid.minor = element_blank(),
      strip.text = element_text(colour = "black"),
      legend.position = "right"
    )
}

# Tiriamos minPts reikšmės.
min_pts_originali <- c(10L, 20L, 38L)

# Apskaičiuojame ir surikiuojame kaimynų atstumus.
# k = minPts − 1, nes minPts įskaičiuoja ir patį objektą.
knn_originali <- do.call(
  rbind,
  lapply(min_pts_originali, function(min_pts) {
    atstumai <- sort(
      dbscan::kNNdist(x, k = min_pts - 1L)
    )
    
    data.frame(
      objekto_eile = seq_along(atstumai),
      atstumas = atstumai,
      minPts = factor(
        paste("minPts =", min_pts),
        levels = paste("minPts =", min_pts_originali)
      )
    )
  })
)

# Nubraižome tris kaimynų atstumų kreives.
grafikas_knn_originali <- ggplot(
  knn_originali,
  aes(x = objekto_eile, y = atstumas)
) +
  geom_line(colour = "black", linewidth = 0.5) +
  facet_wrap(~ minPts, nrow = 1) +
  labs(
    title = "DBSCAN kaimynų atstumai originalioje C aibėje",
    subtitle = "19D erdvė; k = minPts − 1",
    x = "Objektų eilė pagal didėjantį atstumą",
    y = "Atstumas iki k-ojo kaimyno"
  ) +
  tema_dbscan()

# Išsaugome grafiką.
ggsave(
  filename = "grafikai/dbscan_knn_originali.png",
  plot = grafikas_knn_originali,
  width = 12,
  height = 4.5,
  units = "in",
  dpi = 300,
  bg = "white"
)

# Parodome grafiką RStudio lange.
print(grafikas_knn_originali)



# 2. DBSCAN parametrų bandymai originalioje 19D erdvėje

# Bendra funkcija vieno parametrų derinio rezultatams surinkti.
ivertinti_dbscan <- function(duomenys, eps, minPts) {
  
  modelis <- dbscan::dbscan(
    duomenys,
    eps = eps,
    minPts = minPts,
    borderPoints = TRUE
  )
  
  zymes <- modelis$cluster
  dydziai <- table(zymes[zymes > 0])
  
  data.frame(
    eps = eps,
    minPts = minPts,
    klasteriu_sk = length(dydziai),
    triuksmo_sk = sum(zymes == 0),
    triuksmas_proc = 100 * mean(zymes == 0),
    klasteriu_dydziai = paste(
      as.integer(dydziai),
      collapse = "; "
    )
  )
}

# Pradiniai parametrų bandymai.
parametrai <- rbind(
  expand.grid(
    minPts = 10,
    eps = c(0.9, 1.1, 1.3, 1.5, 1.7)
  ),
  expand.grid(
    minPts = 20,
    eps = c(1.1, 1.3, 1.5, 1.7, 1.9)
  ),
  expand.grid(
    minPts = 38,
    eps = c(1.3, 1.5, 1.7, 1.9, 2.1)
  )
)

bandymai <- do.call(
  rbind,
  lapply(seq_len(nrow(parametrai)), function(i) {
    ivertinti_dbscan(
      duomenys = x,
      eps = parametrai$eps[i],
      minPts = parametrai$minPts[i]
    )
  })
)

write.csv(
  bandymai,
  "rezultatai/dbscan_parametrai_originali.csv",
  row.names = FALSE
)

print(bandymai, row.names = FALSE)


# 3. Detalesnis parametrų jautrumo tyrimas originalioje erdvėje

# Visoms minPts reikšmėms tiriamas tas pats eps intervalas.
parametrai <- expand.grid(
  minPts = c(10, 20, 38),
  eps = seq(0.8, 1.6, by = 0.05)
)

bandymai_detaliai <- do.call(
  rbind,
  lapply(seq_len(nrow(parametrai)), function(i) {
    ivertinti_dbscan(
      duomenys = x,
      eps = parametrai$eps[i],
      minPts = parametrai$minPts[i]
    )
  })
)

write.csv(
  bandymai_detaliai,
  "rezultatai/dbscan_parametru_jautrumas_originali.csv",
  row.names = FALSE
)

# Paruošiame duomenis dviem grafiko panelėms.
jautrumas_vaizdui <- rbind(
  data.frame(
    eps = bandymai_detaliai$eps,
    minPts = bandymai_detaliai$minPts,
    rodiklis = "Klasterių skaičius",
    reiksme = bandymai_detaliai$klasteriu_sk
  ),
  data.frame(
    eps = bandymai_detaliai$eps,
    minPts = bandymai_detaliai$minPts,
    rodiklis = "Triukšmas (%)",
    reiksme = bandymai_detaliai$triuksmas_proc
  )
)

jautrumas_vaizdui$minPts <- factor(
  jautrumas_vaizdui$minPts,
  levels = c(10, 20, 38)
)

jautrumas_vaizdui$rodiklis <- factor(
  jautrumas_vaizdui$rodiklis,
  levels = c("Klasterių skaičius", "Triukšmas (%)")
)

grafikas_jautrumas_originali <- ggplot(
  jautrumas_vaizdui,
  aes(
    x = eps,
    y = reiksme,
    colour = minPts,
    group = minPts
  )
) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 1.8) +
  facet_wrap(
    ~ rodiklis,
    nrow = 1,
    scales = "free_y"
  ) +
  scale_colour_manual(
    values = c(
      "10" = "#F8766D",
      "20" = "#00BFC4",
      "38" = "#7CAE00"
    ),
    name = "minPts"
  ) +
  scale_x_continuous(
    breaks = seq(0.8, 1.6, by = 0.1)
  ) +
  scale_y_continuous(
    limits = c(0, NA)
  ) +
  labs(
    title = "DBSCAN parametrų jautrumas originalioje C aibėje",
    subtitle = "19D erdvė; keičiami eps ir minPts",
    x = "Kaimynystės spindulys (eps)",
    y = NULL
  ) +
  tema_dbscan()

ggsave(
  filename = "grafikai/dbscan_parametru_jautrumas_originali.png",
  plot = grafikas_jautrumas_originali,
  width = 12,
  height = 4.5,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_jautrumas_originali)

# Parodome bandymus, kuriuose gauti bent du klasteriai.
print(
  bandymai_detaliai[
    bandymai_detaliai$klasteriu_sk >= 2,
  ],
  row.names = FALSE
)



# 4. Siluetas ir klasterių dydžiai originalioje erdvėje

if (!requireNamespace("cluster", quietly = TRUE)) {
  install.packages("cluster")
}

# Atstumai skaičiuojami originalioje 19D erdvėje.
atstumai_originali <- as.matrix(dist(x))

kokybe_originali <- bandymai_detaliai

kokybe_originali$silhouette <- NA_real_
kokybe_originali$vertinta_proc <- NA_real_
kokybe_originali$didziausio_klasterio_proc <- NA_real_
kokybe_originali$maziausias_klasteris <- NA_integer_

for (i in seq_len(nrow(kokybe_originali))) {
  
  p <- kokybe_originali[i, ]
  
  modelis <- dbscan::dbscan(
    x,
    eps = p$eps,
    minPts = p$minPts,
    borderPoints = TRUE
  )
  
  zymes <- modelis$cluster
  
  # Triukšmas (žymė 0) į silueto skaičiavimą neįtraukiamas.
  priskirti <- which(zymes > 0)
  dydziai <- table(zymes[priskirti])
  
  kokybe_originali$vertinta_proc[i] <-
    100 * length(priskirti) / nrow(x)
  
  if (length(dydziai) > 0) {
    
    # Dalis tarp klasteriams priskirtų objektų.
    kokybe_originali$didziausio_klasterio_proc[i] <-
      100 * max(dydziai) / length(priskirti)
    
    kokybe_originali$maziausias_klasteris[i] <-
      as.integer(min(dydziai))
  }
  
  # Siluetas apibrėžtas, kai yra bent du klasteriai
  # ir objektų daugiau negu klasterių.
  if (length(dydziai) >= 2 &&
      length(priskirti) > length(dydziai)) {
    
    sil <- cluster::silhouette(
      zymes[priskirti],
      as.dist(
        atstumai_originali[
          priskirti,
          priskirti,
          drop = FALSE
        ]
      )
    )
    
    kokybe_originali$silhouette[i] <-
      mean(sil[, "sil_width"])
  }
}

write.csv(
  kokybe_originali,
  "rezultatai/dbscan_kokybe_parametru_originali.csv",
  row.names = FALSE
)

# Palyginimui parodome variantus su bent dviem klasteriais.
rodyti <- kokybe_originali[
  kokybe_originali$klasteriu_sk >= 2,
  c(
    "eps",
    "minPts",
    "klasteriu_sk",
    "triuksmas_proc",
    "vertinta_proc",
    "silhouette",
    "didziausio_klasterio_proc",
    "maziausias_klasteris"
  )
]

# Lentelę surikiuojame pagal mažėjantį siluetą.
rodyti <- rodyti[
  order(rodyti$silhouette, decreasing = TRUE, na.last = TRUE),
]

# Apvaliname tik spausdinamą lentelę.
rodyti$eps <- round(rodyti$eps, 2)
rodyti$triuksmas_proc <- round(rodyti$triuksmas_proc, 2)
rodyti$vertinta_proc <- round(rodyti$vertinta_proc, 2)
rodyti$silhouette <- round(rodyti$silhouette, 4)
rodyti$didziausio_klasterio_proc <-
  round(rodyti$didziausio_klasterio_proc, 2)

print(rodyti, row.names = FALSE)



# 5. Mažųjų klasterių išlikimas keičiant eps
# Tiriame minPts = 10 ir eps intervalą aplink silueto maksimumą.

eps_reiksmes <- seq(0.90, 1.15, by = 0.05)

mazieji_id <- lapply(eps_reiksmes, function(eps) {
  zymes <- dbscan::dbscan(x, eps = eps, minPts = 10)$cluster
  dydziai <- table(zymes[zymes > 0])
  
  # Šiame intervale kiekviename bandyme yra bent du klasteriai.
  didziausio_zyme <- as.integer(names(dydziai)[which.max(dydziai)])
  
  aibe$id[zymes > 0 & zymes != didziausio_zyme]
})

poros <- combn(seq_along(eps_reiksmes), 2)

persidengimas <- lapply(seq_len(ncol(poros)), function(i) {
  a <- poros[1, i]
  b <- poros[2, i]
  
  id_a <- mazieji_id[[a]]
  id_b <- mazieji_id[[b]]
  
  data.frame(
    eps_A = eps_reiksmes[a],
    eps_B = eps_reiksmes[b],
    mazuju_objektu_A = length(id_a),
    mazuju_objektu_B = length(id_b),
    bendru_objektu = length(intersect(id_a, id_b)),
    Jaccard = length(intersect(id_a, id_b)) /
      length(union(id_a, id_b))
  )
})

persidengimas <- do.call(rbind, persidengimas)

write.csv(
  persidengimas,
  "rezultatai/dbscan_mazuju_klasteriu_persidengimas_originali.csv",
  row.names = FALSE
)

print(persidengimas, row.names = FALSE)




# 6. Objektų perėjimai keičiant eps

objektu_busenos <- lapply(eps_reiksmes, function(eps) {
  zymes <- dbscan::dbscan(x, eps = eps, minPts = 10)$cluster
  dydziai <- table(zymes[zymes > 0])
  didziausio_zyme <- as.integer(names(dydziai)[which.max(dydziai)])
  
  busena <- rep("mazieji_klasteriai", length(zymes))
  busena[zymes == 0] <- "triuksmas"
  busena[zymes == didziausio_zyme] <- "didysis_klasteris"
  
  factor(
    busena,
    levels = c("didysis_klasteris", "mazieji_klasteriai", "triuksmas")
  )
})

perejimai <- lapply(seq_len(length(eps_reiksmes) - 1), function(i) {
  lentele <- as.data.frame(table(
    is = objektu_busenos[[i]],
    i = objektu_busenos[[i + 1]]
  ))
  
  lentele$eps_A <- eps_reiksmes[i]
  lentele$eps_B <- eps_reiksmes[i + 1]
  
  lentele[, c("eps_A", "eps_B", "is", "i", "Freq")]
})

perejimai <- do.call(rbind, perejimai)
names(perejimai)[names(perejimai) == "Freq"] <- "objektu_sk"

write.csv(
  perejimai,
  "rezultatai/dbscan_objektu_perejimai_originali.csv",
  row.names = FALSE
)

print(
  perejimai[
    perejimai$is == "mazieji_klasteriai" &
      perejimai$objektu_sk > 0, ],
  row.names = FALSE
)



# 7. Originalių vienetų duomenų patikra klasterių interpretacijai

interpretacijai <- read.csv(
  "aibes/C_originaliais_vienetais_interpretacijai.csv"
)

print(dim(interpretacijai))
print(names(interpretacijai))
print(head(interpretacijai, 2))



# 8. Kandidatų klasterių ir triukšmo charakteristikos

stopifnot(
  !anyDuplicated(aibe$id),
  !anyDuplicated(interpretacijai$id),
  setequal(aibe$id, interpretacijai$id)
)

interpretacijai <- interpretacijai[
  match(aibe$id, interpretacijai$id), ]

stopifnot(
  identical(aibe$id, interpretacijai$id),
  all(aibe$class == interpretacijai$class)
)

kandidatai <- data.frame(
  eps = c(0.80, 0.95, 1.10, 1.15),
  minPts = c(20, 10, 10, 10)
)

pozymiai <- colnames(x)
# Matricos stulpelių pavadinimai gaunami su colnames().
pozymiai <- colnames(x)

statistikos <- list()
klasiu_sudetis <- list()

for (i in seq_len(nrow(kandidatai))) {
  p <- kandidatai[i, ]
  zymes <- dbscan::dbscan(
    x, eps = p$eps, minPts = p$minPts
  )$cluster
  
  varianto_vardas <- paste0(
    "eps_", sprintf("%.2f", p$eps),
    "_minPts_", p$minPts
  )
  
  priskyrimai <- data.frame(
    id = aibe$id,
    class = aibe$class,
    klasteris = zymes
  )
  
  write.csv(
    priskyrimai,
    paste0(
      "rezultatai/dbscan_originali_",
      varianto_vardas, "_priskyrimai.csv"
    ),
    row.names = FALSE
  )
  
  for (grupe in sort(unique(zymes))) {
    duomenys <- interpretacijai[zymes == grupe, ]
    grupes_vardas <- if (grupe == 0) {
      "Triuksmas"
    } else {
      paste0("K", grupe)
    }
    
    statistikos[[length(statistikos) + 1]] <- data.frame(
      eps = p$eps,
      minPts = p$minPts,
      grupe = grupes_vardas,
      n = nrow(duomenys),
      pozymis = pozymiai,
      Q1 = vapply(
        duomenys[, pozymiai, drop = FALSE],
        function(v) unname(quantile(v, 0.25)),
        numeric(1)
      ),
      mediana = vapply(
        duomenys[, pozymiai, drop = FALSE],
        median, numeric(1)
      ),
      Q3 = vapply(
        duomenys[, pozymiai, drop = FALSE],
        function(v) unname(quantile(v, 0.75)),
        numeric(1)
      )
    )
    
    klases <- table(
      factor(duomenys$class, levels = c("Ideal", "Premium"))
    )
    
    klasiu_sudetis[[length(klasiu_sudetis) + 1]] <- data.frame(
      eps = p$eps,
      minPts = p$minPts,
      grupe = grupes_vardas,
      n = nrow(duomenys),
      Ideal = as.integer(klases["Ideal"]),
      Premium = as.integer(klases["Premium"]),
      Ideal_proc = 100 * as.integer(klases["Ideal"]) /
        nrow(duomenys),
      Premium_proc = 100 * as.integer(klases["Premium"]) /
        nrow(duomenys)
    )
  }
}

statistikos <- do.call(rbind, statistikos)
klasiu_sudetis <- do.call(rbind, klasiu_sudetis)

write.csv(
  statistikos,
  "rezultatai/dbscan_kandidatu_statistikos_originali.csv",
  row.names = FALSE
)

write.csv(
  klasiu_sudetis,
  "rezultatai/dbscan_kandidatu_klases_originali.csv",
  row.names = FALSE
)

print(klasiu_sudetis, row.names = FALSE, digits = 4)

print(
  statistikos[
    statistikos$pozymis %in%
      c("carat", "price", "depth", "table", "price_per_carat"),
    c("eps", "minPts", "grupe", "n", "pozymis", "mediana")
  ],
  row.names = FALSE,
  digits = 5
)



# 9. Bendros t-SNE projekcijos patikra vizualizacijai

tsne_vaizdui <- read.csv("aibes/aibe_tSNE_2D.csv")

stopifnot(
  all(c("id", "class", "TSNE1", "TSNE2") %in%
        names(tsne_vaizdui)),
  !anyNA(tsne_vaizdui$id),
  !anyDuplicated(tsne_vaizdui$id),
  setequal(aibe$id, tsne_vaizdui$id)
)

# Objektų tvarką suderiname pagal ID.
tsne_vaizdui <- tsne_vaizdui[
  match(aibe$id, tsne_vaizdui$id),
]

stopifnot(
  identical(aibe$id, tsne_vaizdui$id),
  !anyNA(tsne_vaizdui$class),
  all(aibe$class == tsne_vaizdui$class),
  is.numeric(tsne_vaizdui$TSNE1),
  is.numeric(tsne_vaizdui$TSNE2),
  all(is.finite(as.matrix(
    tsne_vaizdui[, c("TSNE1", "TSNE2")]
  )))
)

cat("Vizualizacijai suderinta objektų:",
    nrow(tsne_vaizdui), "\n")


# 10. Originalios erdvės DBSCAN kandidatai bendroje t-SNE projekcijoje

kandidatu_vaizdai <- list()
paneliu_pavadinimai <- character(nrow(kandidatai))

for (i in seq_len(nrow(kandidatai))) {
  
  p <- kandidatai[i, ]
  
  zymes <- dbscan::dbscan(
    x,
    eps = p$eps,
    minPts = p$minPts,
    borderPoints = TRUE
  )$cluster
  
  dydziai <- table(zymes[zymes > 0])
  
  paneles_pavadinimas <- sprintf(
    "eps = %.2f; minPts = %d\n%d klasteriai; triukšmas %.2f %%",
    p$eps,
    p$minPts,
    length(dydziai),
    100 * mean(zymes == 0)
  )
  
  paneliu_pavadinimai[i] <- paneles_pavadinimas
  
  dalis <- data.frame(
    id = aibe$id,
    TSNE1 = tsne_vaizdui$TSNE1,
    TSNE2 = tsne_vaizdui$TSNE2,
    grupe = ifelse(
      zymes == 0,
      "Triukšmas",
      paste0("K", zymes)
    ),
    variantas = paneles_pavadinimas
  )
  
  # Triukšmą braižome pirmą, mažąsias grupes – paskutines.
  dydis_taskui <- rep(Inf, length(zymes))
  priskirti <- zymes > 0
  
  dydis_taskui[priskirti] <- as.numeric(
    dydziai[as.character(zymes[priskirti])]
  )
  
  dalis <- dalis[
    order(dydis_taskui, decreasing = TRUE),
  ]
  
  kandidatu_vaizdai[[i]] <- dalis
}

kandidatu_vaizdai <- do.call(rbind, kandidatu_vaizdai)

kandidatu_vaizdai$variantas <- factor(
  kandidatu_vaizdai$variantas,
  levels = paneliu_pavadinimai
)

kandidatu_vaizdai$grupe <- factor(
  kandidatu_vaizdai$grupe,
  levels = c("Triukšmas", "K1", "K2", "K3", "K4")
)

grafikas_kandidatai_originali <- ggplot(
  kandidatu_vaizdai,
  aes(x = TSNE1, y = TSNE2, colour = grupe)
) +
  geom_point(size = 0.8, alpha = 0.7) +
  facet_wrap(~ variantas, ncol = 2) +
  scale_colour_manual(
    values = c(
      "Triukšmas" = "#BDBDBD",
      "K1" = "#F8766D",
      "K2" = "#00BFC4",
      "K3" = "#7CAE00",
      "K4" = "#C77CFF"
    ),
    name = "Grupė"
  ) +
  coord_fixed() +
  labs(
    title = "DBSCAN kandidatai originalioje C aibėje",
    subtitle = "Klasterizavimas 19D; vizualizacija bendroje t-SNE 2D projekcijoje",
    x = "t-SNE 1",
    y = "t-SNE 2",
    caption = paste(
      "Klasterių numeriai galioja tik atskiram bandymui.",
      "Triukšmas nėra klasteris."
    )
  ) +
  tema_dbscan() +
  guides(
    colour = guide_legend(
      override.aes = list(size = 3, alpha = 1)
    )
  )

ggsave(
  filename = "grafikai/dbscan_kandidatai_originali_tsne.png",
  plot = grafikas_kandidatai_originali,
  width = 12,
  height = 8.5,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_kandidatai_originali)



# 11. Kandidatų Silhouette, CH ir DB originalioje erdvėje

kandidatu_kokybe <- lapply(seq_len(nrow(kandidatai)), function(i) {
  p <- kandidatai[i, ]
  
  zymes <- dbscan::dbscan(
    x, eps = p$eps, minPts = p$minPts
  )$cluster
  
  priskirti <- which(zymes > 0)
  X <- x[priskirti, , drop = FALSE]
  grupes <- zymes[priskirti]
  klasteriai <- sort(unique(grupes))
  
  n <- nrow(X)
  k <- length(klasteriai)
  
  centrai <- t(vapply(
    klasteriai,
    function(g) colMeans(X[grupes == g, , drop = FALSE]),
    numeric(ncol(X))
  ))
  
  dydziai <- vapply(
    klasteriai, function(g) sum(grupes == g), integer(1)
  )
  
  WSS <- sum(vapply(seq_along(klasteriai), function(j) {
    skirtumai <- sweep(
      X[grupes == klasteriai[j], , drop = FALSE],
      2, centrai[j, ], "-"
    )
    sum(skirtumai^2)
  }, numeric(1)))
  
  bendras_centras <- colMeans(X)
  centru_skirtumai <- sweep(centrai, 2, bendras_centras, "-")
  BSS <- sum(dydziai * rowSums(centru_skirtumai^2))
  
  CH <- if (WSS > 0 && n > k && k > 1) {
    (BSS / (k - 1)) / (WSS / (n - k))
  } else {
    NA_real_
  }
  
  sklaida <- vapply(seq_along(klasteriai), function(j) {
    skirtumai <- sweep(
      X[grupes == klasteriai[j], , drop = FALSE],
      2, centrai[j, ], "-"
    )
    mean(sqrt(rowSums(skirtumai^2)))
  }, numeric(1))
  
  centru_atstumai <- as.matrix(dist(centrai))
  
  DB <- if (any(centru_atstumai[upper.tri(centru_atstumai)] == 0)) {
    NA_real_
  } else {
    santykiai <- outer(sklaida, sklaida, "+") / centru_atstumai
    diag(santykiai) <- -Inf
    mean(apply(santykiai, 1, max))
  }
  
  sil <- cluster::silhouette(
    grupes,
    as.dist(atstumai_originali[priskirti, priskirti])
  )
  
  data.frame(
    eps = p$eps,
    minPts = p$minPts,
    klasteriu_sk = k,
    vertinta_n = n,
    vertinta_proc = 100 * n / nrow(x),
    triuksmas_proc = 100 * mean(zymes == 0),
    Silhouette = mean(sil[, "sil_width"]),
    CH = CH,
    DB = DB
  )
})

kandidatu_kokybe <- do.call(rbind, kandidatu_kokybe)

write.csv(
  kandidatu_kokybe,
  "rezultatai/dbscan_kandidatu_kokybe_originali.csv",
  row.names = FALSE
)

print(kandidatu_kokybe, row.names = FALSE, digits = 5)




# 12. Geometrinis kaimynų atstumų kreivės kelio įvertis

kelio_ivertis <- lapply(min_pts_originali, function(min_pts) {
  
  atstumai <- sort(
    dbscan::kNNdist(x, k = min_pts - 1L)
  )
  
  # Abi ašis perkeliame į intervalą [0, 1].
  horizontali <- seq(0, 1, length.out = length(atstumai))
  plotis <- max(atstumai) - min(atstumai)
  
  if (plotis <= 0) {
    stop("Visi kaimynų atstumai vienodi: kelio įvertis nenustatomas.")
  }
  
  vertikali <- (atstumai - min(atstumai)) / plotis
  
  # Didžiausias nuotolis žemiau kreivės galus jungiančios tiesės.
  indeksas <- which.max(horizontali - vertikali)
  eps <- atstumai[indeksas]
  
  zymes <- dbscan::dbscan(
    x,
    eps = eps,
    minPts = min_pts,
    borderPoints = TRUE
  )$cluster
  
  dydziai <- table(zymes[zymes > 0])
  
  data.frame(
    minPts = min_pts,
    eps_kelio = eps,
    objekto_eile = indeksas,
    kreives_proc = 100 * indeksas / length(atstumai),
    klasteriu_sk = length(dydziai),
    triuksmo_sk = sum(zymes == 0),
    triuksmas_proc = 100 * mean(zymes == 0),
    klasteriu_dydziai = paste(
      as.integer(dydziai),
      collapse = "; "
    )
  )
})

kelio_ivertis <- do.call(rbind, kelio_ivertis)

write.csv(
  kelio_ivertis,
  "rezultatai/dbscan_kelio_ivertis_originali.csv",
  row.names = FALSE
)

# Paruošiame kelio taškus grafikui.
keliai_vaizdui <- kelio_ivertis

keliai_vaizdui$minPts <- factor(
  paste("minPts =", keliai_vaizdui$minPts),
  levels = paste("minPts =", min_pts_originali)
)

keliai_vaizdui$uzrasas <- sprintf(
  "eps ≈ %.3f",
  keliai_vaizdui$eps_kelio
)

# Papildome pirmojo bloko grafiką kelio žymomis.
grafikas_keliai_originali <- grafikas_knn_originali +
  geom_hline(
    data = keliai_vaizdui,
    aes(yintercept = eps_kelio),
    inherit.aes = FALSE,
    colour = "#F8766D",
    linetype = "dashed",
    linewidth = 0.6
  ) +
  geom_point(
    data = keliai_vaizdui,
    aes(x = objekto_eile, y = eps_kelio),
    inherit.aes = FALSE,
    colour = "#F8766D",
    size = 2.5
  ) +
  geom_text(
    data = keliai_vaizdui,
    aes(
      x = 0,
      y = eps_kelio,
      label = uzrasas
    ),
    inherit.aes = FALSE,
    hjust = 0,
    vjust = -0.6,
    size = 3.5,
    colour = "#D84A42"
  ) +
  labs(
    title = "DBSCAN eps kelio įverčiai originalioje C aibėje",
    subtitle = "19D erdvė; pažymėti geometriniu būdu nustatyti eps kandidatai"
  )

ggsave(
  filename = "grafikai/dbscan_kelio_ivertis_originali.png",
  plot = grafikas_keliai_originali,
  width = 12,
  height = 4.5,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_keliai_originali)
print(kelio_ivertis, row.names = FALSE, digits = 5)




# 13. Originalios 19D erdvės atskaitos rezultatas

eps_originali <- kelio_ivertis$eps_kelio[
  kelio_ivertis$minPts == 38
]

modelis_originali <- dbscan::dbscan(
  x,
  eps = eps_originali,
  minPts = 38
)

originali_priskyrimai <- data.frame(
  id = aibe$id,
  class = aibe$class,
  klasteris = modelis_originali$cluster
)

write.csv(
  originali_priskyrimai,
  "rezultatai/dbscan_originali_klasteriai.csv",
  row.names = FALSE
)

originali_suvestine <- data.frame(
  erdve = "Originali 19D",
  eps = eps_originali,
  minPts = 38,
  atstumas = "Euklidinis",
  borderPoints = TRUE,
  klasteriu_sk = length(unique(
    modelis_originali$cluster[modelis_originali$cluster > 0]
  )),
  triuksmo_sk = sum(modelis_originali$cluster == 0),
  triuksmas_proc = 100 * mean(modelis_originali$cluster == 0),
  Silhouette = NA_real_,
  CH = NA_real_,
  DB = NA_real_,
  data = as.character(Sys.Date())
)

write.csv(
  originali_suvestine,
  "rezultatai/dbscan_kokybe_originali.csv",
  row.names = FALSE
)

print(originali_suvestine, row.names = FALSE)

# Kito etapo duomenų struktūra
pca_aibe <- read.csv("aibes/aibe_PCA.csv")

print(dim(pca_aibe))
print(names(pca_aibe))



# 14. PCA 5D: duomenų patikra ir eps kelio įvertinimas

stopifnot(
  all(c("id", "class", paste0("PC", 1:5)) %in%
        names(pca_aibe)),
  !anyNA(pca_aibe$id),
  !anyDuplicated(pca_aibe$id),
  setequal(aibe$id, pca_aibe$id)
)

# Suderiname objektų tvarką pagal ID.
pca_aibe <- pca_aibe[match(aibe$id, pca_aibe$id), ]

stopifnot(
  identical(aibe$id, pca_aibe$id),
  !anyNA(pca_aibe$class),
  all(aibe$class == pca_aibe$class),
  all(vapply(
    pca_aibe[, paste0("PC", 1:5), drop = FALSE],
    is.numeric,
    logical(1)
  ))
)

# Naudojame PCA koordinates jų papildomai nenormuodami.
x_pca <- as.matrix(
  pca_aibe[, paste0("PC", 1:5), drop = FALSE]
)

stopifnot(all(is.finite(x_pca)))

# 10 atitinka dvigubą PCA dimensijų skaičių.
# Kitos reikšmės skirtos jautrumui įvertinti.
min_pts_pca <- c(5L, 10L, 20L, 38L)

# Surikiuoti kaimynų atstumai.
knn_pca <- do.call(
  rbind,
  lapply(min_pts_pca, function(min_pts) {
    atstumai <- sort(
      dbscan::kNNdist(x_pca, k = min_pts - 1L)
    )
    
    data.frame(
      minPts = min_pts,
      objekto_eile = seq_along(atstumai),
      atstumas = atstumai
    )
  })
)

# Geometrinis kelio įvertis kiekvienai minPts reikšmei.
keliai_pca <- do.call(
  rbind,
  lapply(min_pts_pca, function(min_pts) {
    
    atstumai <- knn_pca$atstumas[
      knn_pca$minPts == min_pts
    ]
    
    horizontali <- seq(0, 1, length.out = length(atstumai))
    plotis <- max(atstumai) - min(atstumai)
    
    if (plotis <= 0) {
      stop("Visi kaimynų atstumai vienodi: kelio įvertis nenustatomas.")
    }
    
    vertikali <- (atstumai - min(atstumai)) / plotis
    indeksas <- which.max(horizontali - vertikali)
    eps <- atstumai[indeksas]
    
    zymes <- dbscan::dbscan(
      x_pca,
      eps = eps,
      minPts = min_pts,
      borderPoints = TRUE
    )$cluster
    
    dydziai <- table(zymes[zymes > 0])
    
    data.frame(
      minPts = min_pts,
      eps_kelio = eps,
      objekto_eile = indeksas,
      klasteriu_sk = length(dydziai),
      triuksmo_sk = sum(zymes == 0),
      triuksmas_proc = 100 * mean(zymes == 0),
      klasteriu_dydziai = paste(
        as.integer(dydziai),
        collapse = "; "
      )
    )
  })
)

write.csv(
  keliai_pca,
  "rezultatai/dbscan_kelio_ivertis_pca.csv",
  row.names = FALSE
)

# Panelių pavadinimai.
knn_pca$minPts <- factor(
  paste("minPts =", knn_pca$minPts),
  levels = paste("minPts =", min_pts_pca)
)

keliai_pca_vaizdui <- keliai_pca

keliai_pca_vaizdui$minPts <- factor(
  paste("minPts =", keliai_pca_vaizdui$minPts),
  levels = paste("minPts =", min_pts_pca)
)

keliai_pca_vaizdui$uzrasas <- sprintf(
  "eps ≈ %.3f",
  keliai_pca_vaizdui$eps_kelio
)

grafikas_knn_pca <- ggplot(
  knn_pca,
  aes(x = objekto_eile, y = atstumas)
) +
  geom_line(colour = "black", linewidth = 0.5) +
  geom_hline(
    data = keliai_pca_vaizdui,
    aes(yintercept = eps_kelio),
    inherit.aes = FALSE,
    colour = "#F8766D",
    linetype = "dashed",
    linewidth = 0.6
  ) +
  geom_point(
    data = keliai_pca_vaizdui,
    aes(x = objekto_eile, y = eps_kelio),
    inherit.aes = FALSE,
    colour = "#F8766D",
    size = 2.5
  ) +
  geom_text(
    data = keliai_pca_vaizdui,
    aes(x = 0, y = eps_kelio, label = uzrasas),
    inherit.aes = FALSE,
    hjust = 0,
    vjust = -0.6,
    size = 3.5,
    colour = "#D84A42"
  ) +
  facet_wrap(~ minPts, ncol = 2) +
  labs(
    title = "DBSCAN eps kelio įverčiai PCA 5D erdvėje",
    subtitle = "Pažymėti geometriniu būdu nustatyti eps kandidatai",
    x = "Objektų eilė pagal didėjantį atstumą",
    y = "Atstumas iki k-ojo kaimyno"
  ) +
  tema_dbscan()

ggsave(
  filename = "grafikai/dbscan_knn_pca.png",
  plot = grafikas_knn_pca,
  width = 12,
  height = 8,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_knn_pca)
print(dim(x_pca))
print(keliai_pca, row.names = FALSE, digits = 5)


# 15. PCA 5D parametrų jautrumas

parametrai_pca <- expand.grid(
  minPts = min_pts_pca,
  eps = seq(0.6, 1.8, by = 0.05)
)

# Papildomai įtraukiame tikslius geometrinius kelio įverčius.
parametrai_pca <- unique(rbind(
  parametrai_pca,
  data.frame(
    minPts = keliai_pca$minPts,
    eps = keliai_pca$eps_kelio
  )
))

parametrai_pca <- parametrai_pca[
  order(parametrai_pca$minPts, parametrai_pca$eps),
]

# Naudojame 2 bloke sukurtą funkciją.
bandymai_pca <- do.call(
  rbind,
  lapply(seq_len(nrow(parametrai_pca)), function(i) {
    ivertinti_dbscan(
      duomenys = x_pca,
      eps = parametrai_pca$eps[i],
      minPts = parametrai_pca$minPts[i]
    )
  })
)

write.csv(
  bandymai_pca,
  "rezultatai/dbscan_parametru_jautrumas_pca.csv",
  row.names = FALSE
)

# Paruošiame duomenis dviem grafiko panelėms.
jautrumas_pca_vaizdui <- rbind(
  data.frame(
    eps = bandymai_pca$eps,
    minPts = bandymai_pca$minPts,
    rodiklis = "Klasterių skaičius",
    reiksme = bandymai_pca$klasteriu_sk
  ),
  data.frame(
    eps = bandymai_pca$eps,
    minPts = bandymai_pca$minPts,
    rodiklis = "Triukšmas (%)",
    reiksme = bandymai_pca$triuksmas_proc
  )
)

jautrumas_pca_vaizdui$minPts <- factor(
  jautrumas_pca_vaizdui$minPts,
  levels = min_pts_pca
)

jautrumas_pca_vaizdui$rodiklis <- factor(
  jautrumas_pca_vaizdui$rodiklis,
  levels = c("Klasterių skaičius", "Triukšmas (%)")
)

grafikas_jautrumas_pca <- ggplot(
  jautrumas_pca_vaizdui,
  aes(
    x = eps,
    y = reiksme,
    colour = minPts,
    group = minPts
  )
) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 1.8) +
  facet_wrap(
    ~ rodiklis,
    nrow = 1,
    scales = "free_y"
  ) +
  scale_colour_manual(
    values = c(
      "5" = "#C77CFF",
      "10" = "#F8766D",
      "20" = "#00BFC4",
      "38" = "#7CAE00"
    ),
    name = "minPts"
  ) +
  scale_x_continuous(
    breaks = seq(0.6, 1.8, by = 0.2)
  ) +
  scale_y_continuous(
    limits = c(0, NA)
  ) +
  labs(
    title = "DBSCAN parametrų jautrumas PCA 5D erdvėje",
    subtitle = "Keičiami eps ir minPts; įtraukti geometriniai kelio įverčiai",
    x = "Kaimynystės spindulys (eps)",
    y = NULL
  ) +
  tema_dbscan()

ggsave(
  filename = "grafikai/dbscan_parametru_jautrumas_pca.png",
  plot = grafikas_jautrumas_pca,
  width = 12,
  height = 4.5,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_jautrumas_pca)

cat("Atlikta bandymų:", nrow(bandymai_pca), "\n")

print(
  bandymai_pca[bandymai_pca$klasteriu_sk >= 2, ],
  row.names = FALSE,
  digits = 4
)




# 16. PCA parametrų variantų siluetas ir klasterių balansas

atstumai_pca <- as.matrix(dist(x_pca))
kokybe_pca <- bandymai_pca

kokybe_pca$silhouette <- NA_real_
kokybe_pca$vertinta_proc <- 100 - kokybe_pca$triuksmas_proc
kokybe_pca$didziausio_klasterio_proc <- NA_real_
kokybe_pca$maziausias_klasteris <- NA_integer_

for (i in seq_len(nrow(kokybe_pca))) {
  p <- kokybe_pca[i, ]
  
  zymes <- dbscan::dbscan(
    x_pca, eps = p$eps, minPts = p$minPts
  )$cluster
  
  priskirti <- which(zymes > 0)
  dydziai <- table(zymes[priskirti])
  
  if (length(dydziai) > 0) {
    kokybe_pca$didziausio_klasterio_proc[i] <-
      100 * max(dydziai) / length(priskirti)
    
    kokybe_pca$maziausias_klasteris[i] <- min(dydziai)
  }
  
  if (length(dydziai) >= 2 && length(priskirti) > length(dydziai)) {
    sil <- cluster::silhouette(
      zymes[priskirti],
      as.dist(atstumai_pca[priskirti, priskirti])
    )
    
    kokybe_pca$silhouette[i] <- mean(sil[, "sil_width"])
  }
}

write.csv(
  kokybe_pca,
  "rezultatai/dbscan_kokybe_parametru_pca.csv",
  row.names = FALSE
)

# Geriausias siluetas kiekvienai tirtai minPts reikšmei.
geriausi_pca <- lapply(min_pts_pca, function(m) {
  dalis <- kokybe_pca[
    kokybe_pca$minPts == m &
      is.finite(kokybe_pca$silhouette), ]
  
  if (nrow(dalis) == 0) {
    return(NULL)
  }
  
  dalis[which.max(dalis$silhouette), ]
})

geriausi_pca <- do.call(rbind, geriausi_pca)

print(
  geriausi_pca[, c(
    "eps", "minPts", "klasteriu_sk", "triuksmas_proc",
    "silhouette", "didziausio_klasterio_proc",
    "klasteriu_dydziai"
  )],
  row.names = FALSE,
  digits = 5
)


# 17. PCA kandidatų klasterių ir triukšmo charakteristikos

kandidatai_pca <- data.frame(
  eps = c(0.85, 0.90, 0.65, 1.35, 1.00),
  minPts = c(5, 10, 20, 38, 10)
)

# Originalių vienetų duomenis suderiname su PCA pagal ID.
stopifnot(
  !anyDuplicated(pca_aibe$id),
  !anyDuplicated(interpretacijai$id),
  setequal(pca_aibe$id, interpretacijai$id)
)

interpretacijai_pca <- interpretacijai[
  match(pca_aibe$id, interpretacijai$id), ]

stopifnot(
  identical(pca_aibe$id, interpretacijai_pca$id),
  all(pca_aibe$class == interpretacijai_pca$class),
  nrow(x_pca) == nrow(pca_aibe)
)

# Klasterius aprašome pagal 19 pradinių požymių,
# o ne pagal PCA komponenčių reikšmes.
pozymiai_pca <- colnames(x)

stopifnot(
  all(pozymiai_pca %in% names(interpretacijai_pca))
)

statistikos_pca <- list()
klasiu_sudetis_pca <- list()

for (i in seq_len(nrow(kandidatai_pca))) {
  p <- kandidatai_pca[i, ]
  
  zymes <- dbscan::dbscan(
    x_pca,
    eps = p$eps,
    minPts = p$minPts
  )$cluster
  
  varianto_vardas <- paste0(
    "eps_", sprintf("%.2f", p$eps),
    "_minPts_", p$minPts
  )
  
  priskyrimai <- data.frame(
    id = pca_aibe$id,
    class = pca_aibe$class,
    klasteris = zymes
  )
  
  write.csv(
    priskyrimai,
    paste0(
      "rezultatai/dbscan_pca_",
      varianto_vardas, "_priskyrimai.csv"
    ),
    row.names = FALSE
  )
  
  for (grupe in sort(unique(zymes))) {
    duomenys <- interpretacijai_pca[zymes == grupe, ]
    
    grupes_vardas <- if (grupe == 0) {
      "Triuksmas"
    } else {
      paste0("K", grupe)
    }
    
    statistikos_pca[[length(statistikos_pca) + 1]] <- data.frame(
      eps = p$eps,
      minPts = p$minPts,
      grupe = grupes_vardas,
      n = nrow(duomenys),
      pozymis = pozymiai_pca,
      Q1 = vapply(
        duomenys[, pozymiai_pca, drop = FALSE],
        function(v) unname(quantile(v, 0.25)),
        numeric(1)
      ),
      mediana = vapply(
        duomenys[, pozymiai_pca, drop = FALSE],
        median,
        numeric(1)
      ),
      Q3 = vapply(
        duomenys[, pozymiai_pca, drop = FALSE],
        function(v) unname(quantile(v, 0.75)),
        numeric(1)
      )
    )
    
    klases <- table(
      factor(duomenys$class, levels = c("Ideal", "Premium"))
    )
    
    klasiu_sudetis_pca[[length(klasiu_sudetis_pca) + 1]] <-
      data.frame(
        eps = p$eps,
        minPts = p$minPts,
        grupe = grupes_vardas,
        n = nrow(duomenys),
        Ideal = as.integer(klases["Ideal"]),
        Premium = as.integer(klases["Premium"]),
        Ideal_proc = 100 * as.integer(klases["Ideal"]) /
          nrow(duomenys),
        Premium_proc = 100 * as.integer(klases["Premium"]) /
          nrow(duomenys)
      )
  }
}

statistikos_pca <- do.call(rbind, statistikos_pca)
klasiu_sudetis_pca <- do.call(rbind, klasiu_sudetis_pca)

write.csv(
  statistikos_pca,
  "rezultatai/dbscan_kandidatu_statistikos_pca.csv",
  row.names = FALSE
)

write.csv(
  klasiu_sudetis_pca,
  "rezultatai/dbscan_kandidatu_klases_pca.csv",
  row.names = FALSE
)

print(klasiu_sudetis_pca, row.names = FALSE, digits = 4)

print(
  statistikos_pca[
    statistikos_pca$pozymis %in%
      c("carat", "price", "depth", "table", "price_per_carat"),
    c("eps", "minPts", "grupe", "n", "pozymis", "mediana")
  ],
  row.names = FALSE,
  digits = 5
)




# 18. PCA DBSCAN kandidatų vizualizacija bendroje t-SNE projekcijoje

stopifnot(
  !anyNA(tsne_vaizdui$id),
  !anyDuplicated(tsne_vaizdui$id),
  setequal(pca_aibe$id, tsne_vaizdui$id)
)

tsne_pca_vaizdui <- tsne_vaizdui[
  match(pca_aibe$id, tsne_vaizdui$id),
]

stopifnot(
  identical(pca_aibe$id, tsne_pca_vaizdui$id),
  all(pca_aibe$class == tsne_pca_vaizdui$class),
  all(is.finite(as.matrix(
    tsne_pca_vaizdui[, c("TSNE1", "TSNE2")]
  )))
)

variantai_pca <- rbind(
  kandidatai_pca,
  data.frame(
    eps = keliai_pca$eps_kelio[keliai_pca$minPts == 10],
    minPts = 10
  )
)

pca_kandidatu_vaizdai <- list()
pca_paneliu_pavadinimai <- character(nrow(variantai_pca))

for (i in seq_len(nrow(variantai_pca))) {
  
  p <- variantai_pca[i, ]
  
  zymes <- dbscan::dbscan(
    x_pca,
    eps = p$eps,
    minPts = p$minPts,
    borderPoints = TRUE
  )$cluster
  
  dydziai <- table(zymes[zymes > 0])
  
  paneles_pavadinimas <- sprintf(
    "eps = %.3f; minPts = %d\nKlasterių: %d; triukšmas %.2f %%",
    p$eps,
    p$minPts,
    length(dydziai),
    100 * mean(zymes == 0)
  )
  
  pca_paneliu_pavadinimai[i] <- paneles_pavadinimas
  
  dalis <- data.frame(
    id = pca_aibe$id,
    TSNE1 = tsne_pca_vaizdui$TSNE1,
    TSNE2 = tsne_pca_vaizdui$TSNE2,
    grupe = ifelse(
      zymes == 0,
      "Triukšmas",
      paste0("K", zymes)
    ),
    variantas = paneles_pavadinimas
  )
  
  # Triukšmą braižome pirmą, mažąsias grupes – paskutines.
  dydis_taskui <- rep(Inf, length(zymes))
  priskirti <- zymes > 0
  
  dydis_taskui[priskirti] <- as.numeric(
    dydziai[as.character(zymes[priskirti])]
  )
  
  dalis <- dalis[
    order(dydis_taskui, decreasing = TRUE),
  ]
  
  pca_kandidatu_vaizdai[[i]] <- dalis
}

pca_kandidatu_vaizdai <- do.call(
  rbind,
  pca_kandidatu_vaizdai
)

pca_kandidatu_vaizdai$variantas <- factor(
  pca_kandidatu_vaizdai$variantas,
  levels = pca_paneliu_pavadinimai
)

pca_kandidatu_vaizdai$grupe <- factor(
  pca_kandidatu_vaizdai$grupe,
  levels = c("Triukšmas", "K1", "K2", "K3")
)

grafikas_kandidatai_pca <- ggplot(
  pca_kandidatu_vaizdai,
  aes(x = TSNE1, y = TSNE2, colour = grupe)
) +
  geom_point(size = 0.8, alpha = 0.7) +
  facet_wrap(~ variantas, ncol = 2) +
  scale_colour_manual(
    values = c(
      "Triukšmas" = "#BDBDBD",
      "K1" = "#F8766D",
      "K2" = "#00BFC4",
      "K3" = "#7CAE00"
    ),
    name = "Grupė"
  ) +
  coord_fixed() +
  labs(
    title = "DBSCAN kandidatai PCA 5D erdvėje",
    subtitle = "Klasterizavimas PCA 5D; vizualizacija bendroje t-SNE 2D projekcijoje",
    x = "t-SNE 1",
    y = "t-SNE 2",
    caption = paste(
      "Klasterių numeriai galioja tik atskiram bandymui.",
      "Triukšmas nėra klasteris."
    )
  ) +
  tema_dbscan() +
  guides(
    colour = guide_legend(
      override.aes = list(size = 3, alpha = 1)
    )
  )

ggsave(
  filename = "grafikai/dbscan_kandidatai_pca_tsne.png",
  plot = grafikas_kandidatai_pca,
  width = 12,
  height = 12,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_kandidatai_pca)




# 19. PCA kandidatų Silhouette, CH ir DB

kokybe_kandidatu_pca <- lapply(
  seq_len(nrow(variantai_pca)),
  function(i) {
    p <- variantai_pca[i, ]
    
    zymes <- dbscan::dbscan(
      x_pca, eps = p$eps, minPts = p$minPts
    )$cluster
    
    priskirti <- which(zymes > 0)
    X <- x_pca[priskirti, , drop = FALSE]
    grupes <- zymes[priskirti]
    klasteriai <- sort(unique(grupes))
    
    n <- nrow(X)
    k <- length(klasteriai)
    
    siluetas <- NA_real_
    CH <- NA_real_
    DB <- NA_real_
    
    if (k >= 2 && n > k) {
      centrai <- t(vapply(
        klasteriai,
        function(g) colMeans(X[grupes == g, , drop = FALSE]),
        numeric(ncol(X))
      ))
      
      dydziai <- vapply(
        klasteriai,
        function(g) sum(grupes == g),
        integer(1)
      )
      
      WSS <- sum(vapply(seq_along(klasteriai), function(j) {
        skirtumai <- sweep(
          X[grupes == klasteriai[j], , drop = FALSE],
          2, centrai[j, ], "-"
        )
        sum(skirtumai^2)
      }, numeric(1)))
      
      centru_skirtumai <- sweep(
        centrai, 2, colMeans(X), "-"
      )
      BSS <- sum(dydziai * rowSums(centru_skirtumai^2))
      
      if (WSS > 0) {
        CH <- (BSS / (k - 1)) / (WSS / (n - k))
      }
      
      sklaida <- vapply(seq_along(klasteriai), function(j) {
        skirtumai <- sweep(
          X[grupes == klasteriai[j], , drop = FALSE],
          2, centrai[j, ], "-"
        )
        mean(sqrt(rowSums(skirtumai^2)))
      }, numeric(1))
      
      centru_atstumai <- as.matrix(dist(centrai))
      
      if (all(
        centru_atstumai[upper.tri(centru_atstumai)] > 0
      )) {
        santykiai <- outer(sklaida, sklaida, "+")
        diag(centru_atstumai) <- Inf
        santykiai <- santykiai / centru_atstumai
        diag(santykiai) <- -Inf
        DB <- mean(apply(santykiai, 1, max))
      }
      
      sil <- cluster::silhouette(
        grupes,
        as.dist(atstumai_pca[priskirti, priskirti])
      )
      siluetas <- mean(sil[, "sil_width"])
    }
    
    data.frame(
      eps = p$eps,
      minPts = p$minPts,
      klasteriu_sk = k,
      vertinta_n = n,
      vertinta_proc = 100 * n / nrow(x_pca),
      triuksmas_proc = 100 * mean(zymes == 0),
      Silhouette = siluetas,
      CH = CH,
      DB = DB
    )
  }
)

kokybe_kandidatu_pca <- do.call(rbind, kokybe_kandidatu_pca)

write.csv(
  kokybe_kandidatu_pca,
  "rezultatai/dbscan_kandidatu_kokybe_pca.csv",
  row.names = FALSE
)

print(kokybe_kandidatu_pca, row.names = FALSE, digits = 5)



# 20. PCA atskaitos išsaugojimas

eps_pca <- keliai_pca$eps_kelio[
  keliai_pca$minPts == 10
]

stopifnot(
  length(eps_pca) == 1L,
  is.finite(eps_pca),
  eps_pca > 0
)

modelis_pca <- dbscan::dbscan(
  x_pca,
  eps = eps_pca,
  minPts = 10,
  borderPoints = TRUE
)

pca_priskyrimai <- data.frame(
  id = pca_aibe$id,
  class = pca_aibe$class,
  klasteris = modelis_pca$cluster
)

# Atitinkamą kokybės eilutę parenkame pagal parametrus.
atitinka <- which(
  kokybe_kandidatu_pca$minPts == 10 &
    abs(kokybe_kandidatu_pca$eps - eps_pca) < 1e-10
)

stopifnot(length(atitinka) == 1L)

pca_suvestine <- data.frame(
  erdve = "PCA 5D",
  eps = eps_pca,
  minPts = 10,
  atstumas = "Euklidinis",
  borderPoints = TRUE,
  klasteriu_sk = length(unique(
    modelis_pca$cluster[modelis_pca$cluster > 0]
  )),
  triuksmo_sk = sum(modelis_pca$cluster == 0),
  triuksmas_proc = 100 * mean(modelis_pca$cluster == 0),
  Silhouette = kokybe_kandidatu_pca$Silhouette[atitinka],
  CH = kokybe_kandidatu_pca$CH[atitinka],
  DB = kokybe_kandidatu_pca$DB[atitinka],
  data = as.character(Sys.Date())
)

write.csv(
  pca_priskyrimai,
  "rezultatai/dbscan_pca_klasteriai.csv",
  row.names = FALSE
)

write.csv(
  pca_suvestine,
  "rezultatai/dbscan_kokybe_pca.csv",
  row.names = FALSE
)

print(pca_suvestine, row.names = FALSE)

# 20.1. t-SNE 2D duomenys ir kelio įverčiai

# Naudojame jau paruoštas t-SNE koordinates.
# Čia DBSCAN taikomas tiesiogiai t-SNE 2D erdvėje.
stopifnot(
  identical(pca_aibe$id, tsne_pca_vaizdui$id),
  all(vapply(
    tsne_pca_vaizdui[, c("TSNE1", "TSNE2"), drop = FALSE],
    is.numeric,
    logical(1)
  ))
)

x_tsne <- as.matrix(
  tsne_pca_vaizdui[, c("TSNE1", "TSNE2"), drop = FALSE]
)

stopifnot(all(is.finite(x_tsne)))

# 4 atitinka dvigubą dimensijų skaičių.
# Kitos reikšmės skirtos jautrumui įvertinti.
min_pts_tsne <- c(4L, 5L, 10L, 20L)

knn_tsne <- do.call(
  rbind,
  lapply(min_pts_tsne, function(m) {
    atstumai <- sort(
      dbscan::kNNdist(x_tsne, k = m - 1L)
    )
    
    data.frame(
      minPts = m,
      objekto_eile = seq_along(atstumai),
      atstumas = atstumai
    )
  })
)

keliai_tsne <- do.call(
  rbind,
  lapply(min_pts_tsne, function(m) {
    
    atstumai <- knn_tsne$atstumas[
      knn_tsne$minPts == m
    ]
    
    horizontali <- seq(0, 1, length.out = length(atstumai))
    plotis <- max(atstumai) - min(atstumai)
    
    if (plotis <= 0) {
      stop("Visi kaimynų atstumai vienodi: kelio įvertis nenustatomas.")
    }
    
    vertikali <- (atstumai - min(atstumai)) / plotis
    indeksas <- which.max(horizontali - vertikali)
    eps <- atstumai[indeksas]
    
    zymes <- dbscan::dbscan(
      x_tsne,
      eps = eps,
      minPts = m,
      borderPoints = TRUE
    )$cluster
    
    dydziai <- sort(
      table(zymes[zymes > 0]),
      decreasing = TRUE
    )
    
    data.frame(
      minPts = m,
      eps_kelio = eps,
      objekto_eile = indeksas,
      klasteriu_sk = length(dydziai),
      triuksmo_sk = sum(zymes == 0),
      triuksmas_proc = 100 * mean(zymes == 0),
      klasteriu_dydziai = paste(
        as.integer(dydziai),
        collapse = "; "
      )
    )
  })
)

write.csv(
  keliai_tsne,
  "rezultatai/dbscan_kelio_ivertis_tsne.csv",
  row.names = FALSE
)

# Panelių pavadinimai.
knn_tsne$minPts <- factor(
  paste("minPts =", knn_tsne$minPts),
  levels = paste("minPts =", min_pts_tsne)
)

keliai_tsne_vaizdui <- keliai_tsne

keliai_tsne_vaizdui$minPts <- factor(
  paste("minPts =", keliai_tsne_vaizdui$minPts),
  levels = paste("minPts =", min_pts_tsne)
)

keliai_tsne_vaizdui$uzrasas <- sprintf(
  "eps ≈ %.3f",
  keliai_tsne_vaizdui$eps_kelio
)

grafikas_knn_tsne <- ggplot(
  knn_tsne,
  aes(x = objekto_eile, y = atstumas)
) +
  geom_line(colour = "black", linewidth = 0.5) +
  geom_hline(
    data = keliai_tsne_vaizdui,
    aes(yintercept = eps_kelio),
    inherit.aes = FALSE,
    colour = "#F8766D",
    linetype = "dashed",
    linewidth = 0.6
  ) +
  geom_point(
    data = keliai_tsne_vaizdui,
    aes(x = objekto_eile, y = eps_kelio),
    inherit.aes = FALSE,
    colour = "#F8766D",
    size = 2.5
  ) +
  geom_text(
    data = keliai_tsne_vaizdui,
    aes(x = 0, y = eps_kelio, label = uzrasas),
    inherit.aes = FALSE,
    hjust = 0,
    vjust = -0.6,
    size = 3.5,
    colour = "#D84A42"
  ) +
  facet_wrap(~ minPts, ncol = 2) +
  labs(
    title = "DBSCAN eps kelio įverčiai t-SNE 2D erdvėje",
    subtitle = "Pažymėti geometriniu būdu nustatyti eps kandidatai",
    x = "Objektų eilė pagal didėjantį atstumą",
    y = "Atstumas iki k-ojo kaimyno"
  ) +
  tema_dbscan()

ggsave(
  filename = "grafikai/dbscan_knn_tsne.png",
  plot = grafikas_knn_tsne,
  width = 12,
  height = 8,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_knn_tsne)
print(keliai_tsne, row.names = FALSE, digits = 5)



# 21. t-SNE 2D parametrų jautrumas

parametrai_tsne <- unique(rbind(
  expand.grid(
    minPts = min_pts_tsne,
    eps = seq(0.8, 4.4, by = 0.15)
  ),
  data.frame(
    minPts = keliai_tsne$minPts,
    eps = keliai_tsne$eps_kelio
  )
))

parametrai_tsne <- parametrai_tsne[
  order(parametrai_tsne$minPts, parametrai_tsne$eps),
]

bandymai_tsne <- do.call(
  rbind,
  lapply(seq_len(nrow(parametrai_tsne)), function(i) {
    
    p <- parametrai_tsne[i, ]
    
    zymes <- dbscan::dbscan(
      x_tsne,
      eps = p$eps,
      minPts = p$minPts,
      borderPoints = TRUE
    )$cluster
    
    dydziai <- sort(
      table(zymes[zymes > 0]),
      decreasing = TRUE
    )
    
    data.frame(
      eps = p$eps,
      minPts = p$minPts,
      klasteriu_sk = length(dydziai),
      triuksmo_sk = sum(zymes == 0),
      triuksmas_proc = 100 * mean(zymes == 0),
      didziausias_klasteris = if (length(dydziai) > 0) {
        as.integer(max(dydziai))
      } else {
        0L
      },
      didziausio_klasterio_proc = if (length(dydziai) > 0) {
        100 * max(dydziai) / sum(dydziai)
      } else {
        NA_real_
      },
      klasteriu_dydziai = paste(
        as.integer(dydziai),
        collapse = "; "
      )
    )
  })
)

write.csv(
  bandymai_tsne,
  "rezultatai/dbscan_parametru_jautrumas_tsne.csv",
  row.names = FALSE
)

# Paruošiame duomenis dviem grafiko panelėms.
jautrumas_tsne_vaizdui <- rbind(
  data.frame(
    eps = bandymai_tsne$eps,
    minPts = bandymai_tsne$minPts,
    rodiklis = "Klasterių skaičius",
    reiksme = bandymai_tsne$klasteriu_sk
  ),
  data.frame(
    eps = bandymai_tsne$eps,
    minPts = bandymai_tsne$minPts,
    rodiklis = "Triukšmas (%)",
    reiksme = bandymai_tsne$triuksmas_proc
  )
)

jautrumas_tsne_vaizdui$minPts <- factor(
  jautrumas_tsne_vaizdui$minPts,
  levels = min_pts_tsne
)

jautrumas_tsne_vaizdui$rodiklis <- factor(
  jautrumas_tsne_vaizdui$rodiklis,
  levels = c("Klasterių skaičius", "Triukšmas (%)")
)

grafikas_jautrumas_tsne <- ggplot(
  jautrumas_tsne_vaizdui,
  aes(
    x = eps,
    y = reiksme,
    colour = minPts,
    group = minPts
  )
) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 1.8) +
  facet_wrap(
    ~ rodiklis,
    nrow = 1,
    scales = "free_y"
  ) +
  scale_colour_manual(
    values = c(
      "4" = "#619CFF",
      "5" = "#C77CFF",
      "10" = "#F8766D",
      "20" = "#00BFC4"
    ),
    name = "minPts"
  ) +
  scale_x_continuous(
    breaks = seq(0.8, 4.4, by = 0.6)
  ) +
  scale_y_continuous(
    limits = c(0, NA)
  ) +
  labs(
    title = "DBSCAN parametrų jautrumas t-SNE 2D erdvėje",
    subtitle = "Keičiami eps ir minPts; įtraukti geometriniai kelio įverčiai",
    x = "Kaimynystės spindulys (eps)",
    y = NULL
  ) +
  tema_dbscan()

ggsave(
  filename = "grafikai/dbscan_parametru_jautrumas_tsne.png",
  plot = grafikas_jautrumas_tsne,
  width = 12,
  height = 4.5,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_jautrumas_tsne)

cat("Atlikta bandymų:", nrow(bandymai_tsne), "\n")





# 22. t-SNE 2D kandidatų kokybė ir klasių sudėtis

kandidatai_tsne <- data.frame(
  variantas = c(
    "kelias_4",
    "kelias_10",
    "trys_klasteriai",
    "du_klasteriai"
  ),
  eps = c(
    keliai_tsne$eps_kelio[keliai_tsne$minPts == 4],
    keliai_tsne$eps_kelio[keliai_tsne$minPts == 10],
    3.05,
    3.20
  ),
  minPts = c(4L, 10L, 4L, 4L)
)

stopifnot(
  identical(pca_aibe$id, tsne_pca_vaizdui$id),
  nrow(x_tsne) == nrow(tsne_pca_vaizdui),
  !anyNA(tsne_pca_vaizdui$class),
  all(tsne_pca_vaizdui$class %in% c("Ideal", "Premium"))
)

atstumai_tsne <- as.matrix(dist(x_tsne))

kokybe_kandidatu_tsne <- list()
klases_kandidatu_tsne <- list()

for (i in seq_len(nrow(kandidatai_tsne))) {
  
  p <- kandidatai_tsne[i, ]
  
  zymes <- dbscan::dbscan(
    x_tsne,
    eps = p$eps,
    minPts = p$minPts,
    borderPoints = TRUE
  )$cluster
  
  # Vidiniai rodikliai skaičiuojami be triukšmo.
  priskirti <- which(zymes > 0)
  X <- x_tsne[priskirti, , drop = FALSE]
  grupes <- zymes[priskirti]
  klasteriai <- sort(unique(grupes))
  
  n <- nrow(X)
  k <- length(klasteriai)
  
  siluetas <- CH <- DB <- NA_real_
  
  if (k >= 2 && n > k) {
    
    dalys <- lapply(
      klasteriai,
      function(g) X[grupes == g, , drop = FALSE]
    )
    
    centrai <- do.call(rbind, lapply(dalys, colMeans))
    dydziai <- vapply(dalys, nrow, integer(1))
    
    atstumai_iki_centru <- lapply(
      seq_along(dalys),
      function(j) {
        skirtumai <- sweep(
          dalys[[j]], 2, centrai[j, ], "-"
        )
        sqrt(rowSums(skirtumai^2))
      }
    )
    
    WSS <- sum(vapply(
      atstumai_iki_centru,
      function(d) sum(d^2),
      numeric(1)
    ))
    
    centru_skirtumai <- sweep(
      centrai, 2, colMeans(X), "-"
    )
    
    BSS <- sum(
      dydziai * rowSums(centru_skirtumai^2)
    )
    
    if (WSS > 0) {
      CH <- (BSS / (k - 1)) / (WSS / (n - k))
    }
    
    centru_atstumai <- as.matrix(dist(centrai))
    
    if (all(
      centru_atstumai[upper.tri(centru_atstumai)] > 0
    )) {
      
      sklaida <- vapply(
        atstumai_iki_centru,
        mean,
        numeric(1)
      )
      
      diag(centru_atstumai) <- Inf
      
      santykiai <- outer(sklaida, sklaida, "+") /
        centru_atstumai
      
      diag(santykiai) <- -Inf
      
      DB <- mean(apply(santykiai, 1, max))
    }
    
    sil <- cluster::silhouette(
      grupes,
      as.dist(
        atstumai_tsne[
          priskirti, priskirti, drop = FALSE
        ]
      )
    )
    
    siluetas <- mean(sil[, "sil_width"])
  }
  
  kokybe_kandidatu_tsne[[i]] <- data.frame(
    variantas = p$variantas,
    eps = p$eps,
    minPts = p$minPts,
    klasteriu_sk = k,
    vertinta_n = n,
    vertinta_proc = 100 * n / nrow(x_tsne),
    triuksmas_proc = 100 * mean(zymes == 0),
    Silhouette = siluetas,
    CH = CH,
    DB = DB
  )
  
  # Klasių sudėtį pateikiame ir triukšmui (žymė 0).
  sudetis <- table(
    klasteris = zymes,
    klase = factor(
      tsne_pca_vaizdui$class,
      levels = c("Ideal", "Premium")
    )
  )
  
  grupiu_n <- as.integer(rowSums(sudetis))
  
  klases_kandidatu_tsne[[i]] <- data.frame(
    variantas = p$variantas,
    klasteris = as.integer(rownames(sudetis)),
    n = grupiu_n,
    Ideal = as.integer(sudetis[, "Ideal"]),
    Premium = as.integer(sudetis[, "Premium"]),
    Ideal_proc = 100 *
      as.integer(sudetis[, "Ideal"]) / grupiu_n,
    Premium_proc = 100 *
      as.integer(sudetis[, "Premium"]) / grupiu_n
  )
  
  write.csv(
    data.frame(
      id = tsne_pca_vaizdui$id,
      class = tsne_pca_vaizdui$class,
      klasteris = zymes
    ),
    paste0(
      "rezultatai/dbscan_tsne_",
      p$variantas,
      "_priskyrimai.csv"
    ),
    row.names = FALSE
  )
}

kokybe_kandidatu_tsne <- do.call(
  rbind, kokybe_kandidatu_tsne
)

klases_kandidatu_tsne <- do.call(
  rbind, klases_kandidatu_tsne
)

write.csv(
  kokybe_kandidatu_tsne,
  "rezultatai/dbscan_kandidatu_kokybe_tsne.csv",
  row.names = FALSE
)

write.csv(
  klases_kandidatu_tsne,
  "rezultatai/dbscan_kandidatu_klases_tsne.csv",
  row.names = FALSE
)

print(
  kokybe_kandidatu_tsne,
  row.names = FALSE,
  digits = 5
)

print(
  subset(
    klases_kandidatu_tsne,
    variantas %in% c("du_klasteriai", "trys_klasteriai")
  ),
  row.names = FALSE,
  digits = 5
)


# 23. Dviejų ir trijų DBSCAN klasterių variantų palyginimas

variantu_vardai <- c("trys_klasteriai", "du_klasteriai")

priskyrimai_tsne <- lapply(
  variantu_vardai,
  function(variantas) {
    
    duomenys <- read.csv(paste0(
      "rezultatai/dbscan_tsne_",
      variantas,
      "_priskyrimai.csv"
    ))
    
    stopifnot(
      !anyNA(duomenys$id),
      !anyDuplicated(duomenys$id),
      setequal(duomenys$id, tsne_pca_vaizdui$id)
    )
    
    duomenys <- duomenys[
      match(tsne_pca_vaizdui$id, duomenys$id),
    ]
    
    stopifnot(
      identical(duomenys$id, tsne_pca_vaizdui$id),
      !anyNA(duomenys$klasteris),
      all(duomenys$class == tsne_pca_vaizdui$class)
    )
    
    duomenys$klasteris
  }
)

# Perėjimai skaičiuojami tų pačių objektų tvarka.
perejimai_tsne <- table(
  eps_3_05 = priskyrimai_tsne[[1]],
  eps_3_20 = priskyrimai_tsne[[2]]
)

print(perejimai_tsne)

write.csv(
  as.data.frame(perejimai_tsne),
  "rezultatai/dbscan_tsne_du_ir_trys_perejimai.csv",
  row.names = FALSE
)

# Grafiko duomenys.
eps_vaizdui <- c(3.05, 3.20)
paneliu_vardai <- c(
  "Trys klasteriai: eps = 3,05; minPts = 4",
  "Du klasteriai: eps = 3,20; minPts = 4"
)

vaizdai_tsne <- do.call(
  rbind,
  lapply(seq_along(priskyrimai_tsne), function(i) {
    data.frame(
      TSNE1 = x_tsne[, 1],
      TSNE2 = x_tsne[, 2],
      grupe = paste0("K", priskyrimai_tsne[[i]]),
      variantas = paneliu_vardai[i]
    )
  })
)

vaizdai_tsne$variantas <- factor(
  vaizdai_tsne$variantas,
  levels = paneliu_vardai
)

vaizdai_tsne$grupe <- factor(
  vaizdai_tsne$grupe,
  levels = c("K1", "K2", "K3")
)

grafikas_du_trys <- ggplot(
  vaizdai_tsne,
  aes(x = TSNE1, y = TSNE2, colour = grupe)
) +
  geom_point(size = 0.8, alpha = 0.7) +
  facet_wrap(~ variantas, nrow = 1) +
  scale_colour_manual(
    values = c(
      "K1" = "#F8766D",
      "K2" = "#00BFC4",
      "K3" = "#7CAE00"
    ),
    name = "Klasteris"
  ) +
  coord_fixed() +
  labs(
    title = "DBSCAN trijų ir dviejų klasterių variantai",
    subtitle = "Klasterizavimas ir vizualizacija t-SNE 2D erdvėje",
    x = "t-SNE 1",
    y = "t-SNE 2",
    caption = paste(
      "Abiem atvejais visi 3928 objektai priskirti klasteriams.",
      "Klasterių numeriai galioja tik atskiram bandymui."
    )
  ) +
  tema_dbscan() +
  guides(
    colour = guide_legend(
      override.aes = list(size = 3, alpha = 1)
    )
  )

ggsave(
  filename = "grafikai/dbscan_tsne_du_ir_trys_klasteriai.png",
  plot = grafikas_du_trys,
  width = 12,
  height = 5,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_du_trys)



# 23.1. t-SNE 2D atskaitos išsaugojimas

eps_tsne <- keliai_tsne$eps_kelio[
  keliai_tsne$minPts == 4
]

stopifnot(
  length(eps_tsne) == 1L,
  is.finite(eps_tsne),
  eps_tsne > 0
)

modelis_tsne <- dbscan::dbscan(
  x_tsne,
  eps = eps_tsne,
  minPts = 4,
  borderPoints = TRUE
)

tsne_priskyrimai <- data.frame(
  id = tsne_pca_vaizdui$id,
  class = tsne_pca_vaizdui$class,
  klasteris = modelis_tsne$cluster
)

# Kokybės rodiklius paimame iš atitinkamo kandidato.
atitinka_tsne <- which(
  kokybe_kandidatu_tsne$variantas == "kelias_4" &
    kokybe_kandidatu_tsne$minPts == 4 &
    abs(kokybe_kandidatu_tsne$eps - eps_tsne) < 1e-10
)

stopifnot(length(atitinka_tsne) == 1L)

tsne_suvestine <- data.frame(
  erdve = "t-SNE 2D",
  eps = eps_tsne,
  minPts = 4,
  atstumas = "Euklidinis",
  borderPoints = TRUE,
  klasteriu_sk = length(unique(
    modelis_tsne$cluster[modelis_tsne$cluster > 0]
  )),
  triuksmo_sk = sum(modelis_tsne$cluster == 0),
  triuksmas_proc = 100 * mean(modelis_tsne$cluster == 0),
  Silhouette = kokybe_kandidatu_tsne$Silhouette[atitinka_tsne],
  CH = kokybe_kandidatu_tsne$CH[atitinka_tsne],
  DB = kokybe_kandidatu_tsne$DB[atitinka_tsne],
  data = as.character(Sys.Date())
)

write.csv(
  tsne_priskyrimai,
  "rezultatai/dbscan_tsne_klasteriai.csv",
  row.names = FALSE
)

write.csv(
  tsne_suvestine,
  "rezultatai/dbscan_kokybe_tsne.csv",
  row.names = FALSE
)

print(tsne_suvestine, row.names = FALSE)




# 23.2. DBSCAN suskirstymų palyginimas tarp erdvių

# Atskaitų priskyrimus nuskaitome iš išsaugotų failų.
failai <- c(
  Originali_19D = "rezultatai/dbscan_originali_klasteriai.csv",
  PCA_5D = "rezultatai/dbscan_pca_klasteriai.csv",
  tSNE_2D = "rezultatai/dbscan_tsne_klasteriai.csv"
)

priskyrimai_erdvese <- lapply(failai, read.csv)

# Visus priskyrimus suderiname pagal originalios aibės ID.
priskyrimai_erdvese <- lapply(
  priskyrimai_erdvese,
  function(d) {
    
    stopifnot(
      all(c("id", "class", "klasteris") %in% names(d)),
      !anyNA(d$id),
      !anyDuplicated(d$id),
      setequal(aibe$id, d$id)
    )
    
    d <- d[match(aibe$id, d$id), ]
    
    stopifnot(
      identical(aibe$id, d$id),
      !anyNA(d$klasteris),
      !anyNA(d$class),
      all(aibe$class == d$class)
    )
    
    d
  }
)

# Dviejų suskirstymų panašumo rodikliai.
suskirstymu_matai <- function(a, b) {
  
  lentele <- table(a, b)
  n <- sum(lentele)
  
  stopifnot(n >= 2)
  
  bendros_poros <- sum(choose(lentele, 2))
  poros_a <- sum(choose(rowSums(lentele), 2))
  poros_b <- sum(choose(colSums(lentele), 2))
  
  tiketinas <- poros_a * poros_b / choose(n, 2)
  ari_vardiklis <- (poros_a + poros_b) / 2 - tiketinas
  
  # Sutampantiems vieno klasterio ar vienetinių grupių
  # suskirstymams priskiriame ARI = 1.
  ARI <- if (abs(ari_vardiklis) < 1e-12) {
    1
  } else {
    (bendros_poros - tiketinas) / ari_vardiklis
  }
  
  p <- lentele / n
  p_a <- rowSums(p)
  p_b <- colSums(p)
  nepriklausomi <- outer(p_a, p_b)
  teigiami <- p > 0
  
  MI <- sum(
    p[teigiami] *
      log(p[teigiami] / nepriklausomi[teigiami])
  )
  
  H_a <- -sum(p_a[p_a > 0] * log(p_a[p_a > 0]))
  H_b <- -sum(p_b[p_b > 0] * log(p_b[p_b > 0]))
  
  # NMI normalizuojame aritmetiniu entropijų vidurkiu.
  NMI <- if (H_a + H_b == 0) {
    1
  } else {
    2 * MI / (H_a + H_b)
  }
  
  poru_sajunga <- poros_a + poros_b - bendros_poros
  
  Jaccard <- if (poru_sajunga == 0) {
    NA_real_
  } else {
    bendros_poros / poru_sajunga
  }
  
  c(ARI = ARI, NMI = NMI, Jaccard = Jaccard)
}

erdviu_poros <- combn(names(priskyrimai_erdvese), 2)

palyginimai_erdviu <- list()
triuksmo_palyginimai <- list()

for (i in seq_len(ncol(erdviu_poros))) {
  
  vardas_a <- erdviu_poros[1, i]
  vardas_b <- erdviu_poros[2, i]
  
  a <- priskyrimai_erdvese[[vardas_a]]
  b <- priskyrimai_erdvese[[vardas_b]]
  
  # Pagrindiniame palyginime 0 laikoma bendra triukšmo žyme.
  matai <- suskirstymu_matai(a$klasteris, b$klasteris)
  
  palyginimai_erdviu[[i]] <- data.frame(
    erdve_A = vardas_a,
    erdve_B = vardas_b,
    objektu_sk = nrow(a),
    ARI = unname(matai["ARI"]),
    NMI = unname(matai["NMI"]),
    Jaccard = unname(matai["Jaccard"])
  )
  
  # Atskirai lyginame triukšmo objektų rinkinius.
  triuksmas_a <- a$klasteris == 0
  triuksmas_b <- b$klasteris == 0
  
  bendras_triuksmas <- sum(triuksmas_a & triuksmas_b)
  triuksmo_sajunga <- sum(triuksmas_a | triuksmas_b)
  
  triuksmo_palyginimai[[i]] <- data.frame(
    erdve_A = vardas_a,
    erdve_B = vardas_b,
    triuksmas_A = sum(triuksmas_a),
    triuksmas_B = sum(triuksmas_b),
    triuksmas_abiejose = bendras_triuksmas,
    tik_A_triuksmas = sum(triuksmas_a & !triuksmas_b),
    tik_B_triuksmas = sum(!triuksmas_a & triuksmas_b),
    klasteriuose_abiejose = sum(!triuksmas_a & !triuksmas_b),
    triuksmo_Jaccard = if (triuksmo_sajunga > 0) {
      bendras_triuksmas / triuksmo_sajunga
    } else {
      NA_real_
    }
  )
  
  # Išsaugome pilną klasterių perėjimų lentelę.
  perejimai <- as.data.frame(table(
    klasteris_A = a$klasteris,
    klasteris_B = b$klasteris
  ))
  
  names(perejimai)[3] <- "objektu_sk"
  
  write.csv(
    perejimai,
    paste0(
      "rezultatai/dbscan_perejimai_",
      vardas_a, "_", vardas_b, ".csv"
    ),
    row.names = FALSE
  )
}

palyginimai_erdviu <- do.call(rbind, palyginimai_erdviu)
triuksmo_palyginimai <- do.call(rbind, triuksmo_palyginimai)

write.csv(
  palyginimai_erdviu,
  "rezultatai/dbscan_erdviu_palyginimas.csv",
  row.names = FALSE
)

write.csv(
  triuksmo_palyginimai,
  "rezultatai/dbscan_triuksmo_palyginimas.csv",
  row.names = FALSE
)

print(palyginimai_erdviu, row.names = FALSE, digits = 5)
print(triuksmo_palyginimai, row.names = FALSE, digits = 5)




# 23.3. t-SNE klasterių charakteristikos originaliais vienetais

stopifnot(
  !anyNA(interpretacijai$id),
  !anyDuplicated(interpretacijai$id),
  setequal(tsne_pca_vaizdui$id, interpretacijai$id)
)

interpretacijai_tsne <- interpretacijai[
  match(tsne_pca_vaizdui$id, interpretacijai$id),
]

pozymiai_tsne <- colnames(x)

stopifnot(
  identical(tsne_pca_vaizdui$id, interpretacijai_tsne$id),
  all(tsne_pca_vaizdui$class == interpretacijai_tsne$class),
  all(pozymiai_tsne %in% names(interpretacijai_tsne)),
  all(vapply(
    interpretacijai_tsne[, pozymiai_tsne, drop = FALSE],
    is.numeric,
    logical(1)
  )),
  all(is.finite(as.matrix(
    interpretacijai_tsne[, pozymiai_tsne, drop = FALSE]
  )))
)

statistikos_tsne <- list()

for (i in seq_len(nrow(kandidatai_tsne))) {
  
  p <- kandidatai_tsne[i, ]
  
  priskyrimai <- read.csv(paste0(
    "rezultatai/dbscan_tsne_",
    p$variantas,
    "_priskyrimai.csv"
  ))
  
  stopifnot(
    !anyNA(priskyrimai$id),
    !anyDuplicated(priskyrimai$id),
    setequal(tsne_pca_vaizdui$id, priskyrimai$id)
  )
  
  priskyrimai <- priskyrimai[
    match(tsne_pca_vaizdui$id, priskyrimai$id),
  ]
  
  stopifnot(
    identical(tsne_pca_vaizdui$id, priskyrimai$id),
    !anyNA(priskyrimai$klasteris)
  )
  
  for (grupe in sort(unique(priskyrimai$klasteris))) {
    
    duomenys <- interpretacijai_tsne[
      priskyrimai$klasteris == grupe,
    ]
    
    statistikos_tsne[[length(statistikos_tsne) + 1L]] <-
      data.frame(
        variantas = p$variantas,
        eps = p$eps,
        minPts = p$minPts,
        klasteris = grupe,
        grupe = if (grupe == 0) {
          "Triuksmas"
        } else {
          paste0("K", grupe)
        },
        n = nrow(duomenys),
        pozymis = pozymiai_tsne,
        Q1 = vapply(
          duomenys[, pozymiai_tsne, drop = FALSE],
          function(v) unname(quantile(v, 0.25)),
          numeric(1)
        ),
        mediana = vapply(
          duomenys[, pozymiai_tsne, drop = FALSE],
          median,
          numeric(1)
        ),
        Q3 = vapply(
          duomenys[, pozymiai_tsne, drop = FALSE],
          function(v) unname(quantile(v, 0.75)),
          numeric(1)
        )
      )
  }
}

statistikos_tsne <- do.call(rbind, statistikos_tsne)

write.csv(
  statistikos_tsne,
  "rezultatai/dbscan_kandidatu_statistikos_tsne.csv",
  row.names = FALSE
)

# Konsolėje rodome tik dviejų ir trijų klasterių
# variantų svarbiausių požymių medianas.
print(
  subset(
    statistikos_tsne,
    variantas %in% c("du_klasteriai", "trys_klasteriai") &
      pozymis %in% c(
        "carat", "price", "depth", "table", "price_per_carat"
      ),
    select = c(
      variantas, grupe, n, pozymis, mediana
    )
  ),
  row.names = FALSE,
  digits = 5
)


# 24. Stabilumo tyrimas: 80 % imčių paruošimas

# Naudojame C aibę originaliais matavimo vienetais.
# Anksčiau pašalintų objektų negrąžiname.
stabilumo_duomenys <- interpretacijai[
  match(aibe$id, interpretacijai$id),
]

stabilumo_pozymiai <- colnames(x)

stopifnot(
  identical(stabilumo_duomenys$id, aibe$id),
  !anyDuplicated(stabilumo_duomenys$id),
  all(stabilumo_pozymiai %in% names(stabilumo_duomenys))
)

X_pradine <- as.matrix(
  stabilumo_duomenys[, stabilumo_pozymiai, drop = FALSE]
)

stopifnot(
  is.numeric(X_pradine),
  all(is.finite(X_pradine))
)

N_stabilumas <- 10L
imties_dydis <- floor(0.8 * nrow(X_pradine))
seklos_stabilumui <- 0:(N_stabilumas - 1L)

stabilumo_imtys <- lapply(seklos_stabilumui, function(sekla) {
  
  set.seed(sekla)
  
  indeksai <- sort(sample.int(
    nrow(X_pradine),
    size = imties_dydis,
    replace = FALSE
  ))
  
  X_imtis <- X_pradine[indeksai, , drop = FALSE]
  
  # Normavimo parametrai nustatomi tik iš šios imties.
  medianos <- apply(X_imtis, 2, median)
  iqr <- apply(X_imtis, 2, IQR)
  
  if (any(!is.finite(iqr) | iqr <= 0)) {
    stop("Imtyje rastas požymis su nuliniu arba netinkamu IQR.")
  }
  
  X_normuota <- sweep(X_imtis, 2, medianos, "-")
  X_normuota <- sweep(X_normuota, 2, iqr, "/")
  
  stopifnot(all(is.finite(X_normuota)))
  
  list(
    sekla = sekla,
    id = stabilumo_duomenys$id[indeksai],
    x = X_normuota
  )
})

imciu_suvestine <- do.call(
  rbind,
  lapply(stabilumo_imtys, function(imtis) {
    data.frame(
      sekla = imtis$sekla,
      objektu_sk = nrow(imtis$x),
      pozymiu_sk = ncol(imtis$x)
    )
  })
)

print(imciu_suvestine, row.names = FALSE)



# 25. DBSCAN stabilumas originalioje 19D erdvėje

stabilumas_originali <- lapply(
  stabilumo_imtys,
  function(imtis) {
    
    X <- imtis$x
    min_pts <- 38L
    
    atstumai <- sort(
      dbscan::kNNdist(X, k = min_pts - 1L)
    )
    
    plotis <- max(atstumai) - min(atstumai)
    stopifnot(plotis > 0)
    
    horizontali <- seq(0, 1, length.out = length(atstumai))
    vertikali <- (atstumai - min(atstumai)) / plotis
    
    eps <- atstumai[
      which.max(horizontali - vertikali)
    ]
    
    zymes <- dbscan::dbscan(
      X,
      eps = eps,
      minPts = min_pts,
      borderPoints = TRUE
    )$cluster
    
    list(
      sekla = imtis$sekla,
      eps = eps,
      id = imtis$id,
      klasteris = zymes
    )
  }
)

# Kiekvienos imties rezultato suvestinė.
stabilumo_originali_bandymai <- do.call(
  rbind,
  lapply(stabilumas_originali, function(rez) {
    data.frame(
      sekla = rez$sekla,
      eps = rez$eps,
      minPts = 38L,
      objektu_sk = length(rez$id),
      klasteriu_sk = length(unique(
        rez$klasteris[rez$klasteris > 0]
      )),
      triuksmo_sk = sum(rez$klasteris == 0),
      triuksmas_proc = 100 * mean(rez$klasteris == 0)
    )
  })
)

# Visos 10 imčių poros: 10 × 9 / 2 = 45.
imciu_poros <- combn(seq_along(stabilumas_originali), 2)

stabilumo_originali_poros <- do.call(
  rbind,
  lapply(seq_len(ncol(imciu_poros)), function(i) {
    
    a <- stabilumas_originali[[imciu_poros[1, i]]]
    b <- stabilumas_originali[[imciu_poros[2, i]]]
    
    bendri_id <- intersect(a$id, b$id)
    
    zymes_a <- a$klasteris[match(bendri_id, a$id)]
    zymes_b <- b$klasteris[match(bendri_id, b$id)]
    
    stopifnot(
      length(bendri_id) >= 2L,
      !anyNA(zymes_a),
      !anyNA(zymes_b)
    )
    
    # Naudojame 23.2 bloke sukurtą funkciją.
    # Žymė 0 laikoma viena bendra triukšmo grupe.
    matai <- suskirstymu_matai(zymes_a, zymes_b)
    
    triuksmas_a <- zymes_a == 0
    triuksmas_b <- zymes_b == 0
    sajunga <- sum(triuksmas_a | triuksmas_b)
    
    data.frame(
      sekla_A = a$sekla,
      sekla_B = b$sekla,
      bendru_objektu = length(bendri_id),
      ARI = unname(matai["ARI"]),
      NMI = unname(matai["NMI"]),
      Jaccard = unname(matai["Jaccard"]),
      triuksmo_Jaccard = if (sajunga > 0) {
        sum(triuksmas_a & triuksmas_b) / sajunga
      } else {
        NA_real_
      }
    )
  })
)

write.csv(
  stabilumo_originali_bandymai,
  "rezultatai/dbscan_stabilumo_bandymai_originali.csv",
  row.names = FALSE
)

write.csv(
  stabilumo_originali_poros,
  "rezultatai/dbscan_stabilumo_poros_originali.csv",
  row.names = FALSE
)

print(
  stabilumo_originali_bandymai,
  row.names = FALSE,
  digits = 5
)

cat("Palyginta imčių porų:",
    nrow(stabilumo_originali_poros), "\n")





# 26. DBSCAN stabilumas PCA 5D erdvėje

stabilumas_pca <- lapply(
  stabilumo_imtys,
  function(imtis) {
    
    # Imtis jau atskirai normuota 24 bloke.
    # PCA kiekvienai imčiai apskaičiuojama iš naujo.
    pca_modelis <- prcomp(
      imtis$x,
      center = TRUE,
      scale. = FALSE
    )
    
    X <- pca_modelis$x[, 1:5, drop = FALSE]
    
    # Užregistruojame, kiek dispersijos išlaiko 5 komponentės.
    dispersijos <- pca_modelis$sdev^2
    dispersija_5 <- sum(dispersijos[1:5]) /
      sum(dispersijos)
    
    min_pts <- 10L
    
    atstumai <- sort(
      dbscan::kNNdist(X, k = min_pts - 1L)
    )
    
    plotis <- max(atstumai) - min(atstumai)
    stopifnot(plotis > 0)
    
    horizontali <- seq(0, 1, length.out = length(atstumai))
    vertikali <- (atstumai - min(atstumai)) / plotis
    
    eps <- atstumai[
      which.max(horizontali - vertikali)
    ]
    
    zymes <- dbscan::dbscan(
      X,
      eps = eps,
      minPts = min_pts,
      borderPoints = TRUE
    )$cluster
    
    list(
      sekla = imtis$sekla,
      eps = eps,
      dispersija_5 = dispersija_5,
      id = imtis$id,
      klasteris = zymes
    )
  }
)

stabilumo_pca_bandymai <- do.call(
  rbind,
  lapply(stabilumas_pca, function(rez) {
    data.frame(
      sekla = rez$sekla,
      eps = rez$eps,
      minPts = 10L,
      objektu_sk = length(rez$id),
      PCA_dimensijos = 5L,
      paaiskinta_dispersija_proc = 100 * rez$dispersija_5,
      klasteriu_sk = length(unique(
        rez$klasteris[rez$klasteris > 0]
      )),
      triuksmo_sk = sum(rez$klasteris == 0),
      triuksmas_proc = 100 * mean(rez$klasteris == 0)
    )
  })
)

imciu_poros_pca <- combn(
  seq_along(stabilumas_pca), 2
)

stabilumo_pca_poros <- do.call(
  rbind,
  lapply(seq_len(ncol(imciu_poros_pca)), function(i) {
    
    a <- stabilumas_pca[[imciu_poros_pca[1, i]]]
    b <- stabilumas_pca[[imciu_poros_pca[2, i]]]
    
    bendri_id <- intersect(a$id, b$id)
    
    zymes_a <- a$klasteris[match(bendri_id, a$id)]
    zymes_b <- b$klasteris[match(bendri_id, b$id)]
    
    stopifnot(
      length(bendri_id) >= 2L,
      !anyNA(zymes_a),
      !anyNA(zymes_b)
    )
    
    matai <- suskirstymu_matai(zymes_a, zymes_b)
    
    triuksmas_a <- zymes_a == 0
    triuksmas_b <- zymes_b == 0
    sajunga <- sum(triuksmas_a | triuksmas_b)
    
    data.frame(
      sekla_A = a$sekla,
      sekla_B = b$sekla,
      bendru_objektu = length(bendri_id),
      ARI = unname(matai["ARI"]),
      NMI = unname(matai["NMI"]),
      Jaccard = unname(matai["Jaccard"]),
      triuksmo_Jaccard = if (sajunga > 0) {
        sum(triuksmas_a & triuksmas_b) / sajunga
      } else {
        NA_real_
      }
    )
  })
)

write.csv(
  stabilumo_pca_bandymai,
  "rezultatai/dbscan_stabilumo_bandymai_pca.csv",
  row.names = FALSE
)

write.csv(
  stabilumo_pca_poros,
  "rezultatai/dbscan_stabilumo_poros_pca.csv",
  row.names = FALSE
)

print(
  stabilumo_pca_bandymai,
  row.names = FALSE,
  digits = 5
)

cat(
  "Palyginta imčių porų:",
  nrow(stabilumo_pca_poros),
  "\n"
)





# 27. DBSCAN stabilumas t-SNE 2D erdvėje

if (!requireNamespace("Rtsne", quietly = TRUE)) {
  install.packages("Rtsne")
}

stabilumas_tsne <- lapply(
  stabilumo_imtys,
  function(imtis) {
    
    tsne_sekla <- 1000L + imtis$sekla
    
    cat(
      "t-SNE imtis:", imtis$sekla,
      "| t-SNE sėkla:", tsne_sekla, "\n"
    )
    
    set.seed(tsne_sekla)
    
    X <- Rtsne::Rtsne(
      imtis$x,
      dims = 2,
      perplexity = 30,
      max_iter = 1000,
      pca = FALSE,
      normalize = FALSE,
      verbose = FALSE,
      check_duplicates = FALSE,
      num_threads = 1
    )$Y
    
    stopifnot(all(is.finite(X)))
    
    min_pts <- 4L
    
    atstumai <- sort(
      dbscan::kNNdist(X, k = min_pts - 1L)
    )
    
    plotis <- max(atstumai) - min(atstumai)
    stopifnot(plotis > 0)
    
    horizontali <- seq(0, 1, length.out = length(atstumai))
    vertikali <- (atstumai - min(atstumai)) / plotis
    
    eps <- atstumai[
      which.max(horizontali - vertikali)
    ]
    
    zymes <- dbscan::dbscan(
      X,
      eps = eps,
      minPts = min_pts,
      borderPoints = TRUE
    )$cluster
    
    # Išsaugome koordinates ir priskyrimus.
    write.csv(
      data.frame(
        id = imtis$id,
        TSNE1 = X[, 1],
        TSNE2 = X[, 2],
        klasteris = zymes
      ),
      paste0(
        "rezultatai/dbscan_stabilumas_tsne_imtis_",
        imtis$sekla,
        ".csv"
      ),
      row.names = FALSE
    )
    
    list(
      sekla = imtis$sekla,
      tsne_sekla = tsne_sekla,
      eps = eps,
      id = imtis$id,
      x = X,
      klasteris = zymes
    )
  }
)

stabilumo_tsne_bandymai <- do.call(
  rbind,
  lapply(stabilumas_tsne, function(rez) {
    data.frame(
      sekla = rez$sekla,
      tsne_sekla = rez$tsne_sekla,
      eps = rez$eps,
      minPts = 4L,
      objektu_sk = length(rez$id),
      klasteriu_sk = length(unique(
        rez$klasteris[rez$klasteris > 0]
      )),
      triuksmo_sk = sum(rez$klasteris == 0),
      triuksmas_proc = 100 * mean(rez$klasteris == 0)
    )
  })
)

imciu_poros_tsne <- combn(
  seq_along(stabilumas_tsne), 2
)

stabilumo_tsne_poros <- do.call(
  rbind,
  lapply(seq_len(ncol(imciu_poros_tsne)), function(i) {
    
    a <- stabilumas_tsne[[imciu_poros_tsne[1, i]]]
    b <- stabilumas_tsne[[imciu_poros_tsne[2, i]]]
    
    bendri_id <- intersect(a$id, b$id)
    
    zymes_a <- a$klasteris[match(bendri_id, a$id)]
    zymes_b <- b$klasteris[match(bendri_id, b$id)]
    
    stopifnot(
      length(bendri_id) >= 2L,
      !anyNA(zymes_a),
      !anyNA(zymes_b)
    )
    
    matai <- suskirstymu_matai(zymes_a, zymes_b)
    
    triuksmas_a <- zymes_a == 0
    triuksmas_b <- zymes_b == 0
    sajunga <- sum(triuksmas_a | triuksmas_b)
    
    data.frame(
      sekla_A = a$sekla,
      sekla_B = b$sekla,
      bendru_objektu = length(bendri_id),
      ARI = unname(matai["ARI"]),
      NMI = unname(matai["NMI"]),
      Jaccard = unname(matai["Jaccard"]),
      triuksmo_Jaccard = if (sajunga > 0) {
        sum(triuksmas_a & triuksmas_b) / sajunga
      } else {
        NA_real_
      }
    )
  })
)

write.csv(
  stabilumo_tsne_bandymai,
  "rezultatai/dbscan_stabilumo_bandymai_tsne.csv",
  row.names = FALSE
)

write.csv(
  stabilumo_tsne_poros,
  "rezultatai/dbscan_stabilumo_poros_tsne.csv",
  row.names = FALSE
)

print(
  stabilumo_tsne_bandymai,
  row.names = FALSE,
  digits = 5
)

cat(
  "Palyginta imčių porų:",
  nrow(stabilumo_tsne_poros),
  "\n"
)








# 28. Stabilumo palyginimas tarp trijų erdvių

stabilumo_poros_visos <- rbind(
  data.frame(
    erdve = "Originali 19D",
    stabilumo_originali_poros
  ),
  data.frame(
    erdve = "PCA 5D",
    stabilumo_pca_poros
  ),
  data.frame(
    erdve = "t-SNE 2D",
    stabilumo_tsne_poros
  )
)

stabilumo_poros_visos$erdve <- factor(
  stabilumo_poros_visos$erdve,
  levels = c("Originali 19D", "PCA 5D", "t-SNE 2D")
)

rodikliai_stabilumui <- c(
  "ARI", "NMI", "Jaccard", "triuksmo_Jaccard"
)

stabilumo_suvestine <- do.call(
  rbind,
  lapply(levels(stabilumo_poros_visos$erdve), function(e) {
    
    dalis <- stabilumo_poros_visos[
      stabilumo_poros_visos$erdve == e,
    ]
    
    do.call(
      rbind,
      lapply(rodikliai_stabilumui, function(rodiklis) {
        
        reiksmes <- dalis[[rodiklis]]
        reiksmes <- reiksmes[is.finite(reiksmes)]
        
        data.frame(
          erdve = e,
          rodiklis = rodiklis,
          vertintu_poru = length(reiksmes),
          vidurkis = if (length(reiksmes) > 0) {
            mean(reiksmes)
          } else {
            NA_real_
          },
          SD = if (length(reiksmes) > 1) {
            sd(reiksmes)
          } else {
            NA_real_
          },
          minimumas = if (length(reiksmes) > 0) {
            min(reiksmes)
          } else {
            NA_real_
          },
          maksimumas = if (length(reiksmes) > 0) {
            max(reiksmes)
          } else {
            NA_real_
          }
        )
      })
    )
  })
)

write.csv(
  stabilumo_poros_visos,
  "rezultatai/dbscan_stabilumo_poros_visos_erdves.csv",
  row.names = FALSE
)

write.csv(
  stabilumo_suvestine,
  "rezultatai/dbscan_stabilumo_suvestine.csv",
  row.names = FALSE
)

grafikas_stabilumas <- ggplot(
  stabilumo_poros_visos,
  aes(x = erdve, y = ARI, fill = erdve)
) +
  geom_boxplot(
    width = 0.5,
    alpha = 0.65,
    outlier.shape = NA
  ) +
  geom_point(
    position = position_jitter(
      width = 0.09,
      height = 0,
      seed = 42
    ),
    size = 1.6,
    alpha = 0.55
  ) +
  scale_fill_manual(
    values = c(
      "Originali 19D" = "#F8766D",
      "PCA 5D" = "#00BFC4",
      "t-SNE 2D" = "#C77CFF"
    )
  ) +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.2)
  ) +
  labs(
    title = "DBSCAN stabilumas skirtingose erdvėse",
    subtitle = "10 atsitiktinių 80 % imčių; 45 poriniai palyginimai kiekvienai erdvei",
    x = NULL,
    y = "Adjusted Rand Index (ARI)",
    caption = paste(
      "Lyginami tik bendri objektai.",
      "Triukšmo žymė 0 laikoma viena bendra grupe."
    )
  ) +
  tema_dbscan() +
  theme(legend.position = "none")

ggsave(
  filename = "grafikai/dbscan_stabilumo_ari_visos_erdves.png",
  plot = grafikas_stabilumas,
  width = 10,
  height = 5.5,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_stabilumas)

print(
  stabilumo_suvestine,
  row.names = FALSE,
  digits = 5
)









# 29. Vidiniai kokybės rodikliai stabilumo imtyse

vidiniai_matai <- function(X, zymes) {
  
  priskirti <- which(zymes > 0)
  X <- X[priskirti, , drop = FALSE]
  grupes <- zymes[priskirti]
  
  klasteriai <- sort(unique(grupes))
  n <- nrow(X)
  k <- length(klasteriai)
  
  siluetas <- CH <- DB <- NA_real_
  
  if (k >= 2 && n > k) {
    
    dalys <- lapply(
      klasteriai,
      function(g) X[grupes == g, , drop = FALSE]
    )
    
    centrai <- do.call(rbind, lapply(dalys, colMeans))
    dydziai <- vapply(dalys, nrow, integer(1))
    
    atstumai_iki_centru <- lapply(
      seq_along(dalys),
      function(j) {
        skirtumai <- sweep(
          dalys[[j]], 2, centrai[j, ], "-"
        )
        sqrt(rowSums(skirtumai^2))
      }
    )
    
    WSS <- sum(vapply(
      atstumai_iki_centru,
      function(d) sum(d^2),
      numeric(1)
    ))
    
    centru_skirtumai <- sweep(
      centrai, 2, colMeans(X), "-"
    )
    
    BSS <- sum(
      dydziai * rowSums(centru_skirtumai^2)
    )
    
    if (WSS > 0) {
      CH <- (BSS / (k - 1)) / (WSS / (n - k))
    }
    
    centru_atstumai <- as.matrix(dist(centrai))
    
    if (all(
      centru_atstumai[upper.tri(centru_atstumai)] > 0
    )) {
      
      sklaida <- vapply(
        atstumai_iki_centru,
        mean,
        numeric(1)
      )
      
      diag(centru_atstumai) <- Inf
      
      santykiai <- outer(sklaida, sklaida, "+") /
        centru_atstumai
      
      diag(santykiai) <- -Inf
      DB <- mean(apply(santykiai, 1, max))
    }
    
    sil <- cluster::silhouette(
      grupes,
      dist(X)
    )
    
    siluetas <- mean(sil[, "sil_width"])
  }
  
  data.frame(
    klasteriu_sk = k,
    vertinta_n = n,
    Silhouette = siluetas,
    CH = CH,
    DB = DB
  )
}

# Originalios erdvės imtys.
vidiniai_originali <- do.call(
  rbind,
  lapply(seq_along(stabilumas_originali), function(i) {
    
    rez <- stabilumas_originali[[i]]
    imtis <- stabilumo_imtys[[i]]
    
    stopifnot(identical(rez$id, imtis$id))
    
    data.frame(
      erdve = "Originali 19D",
      sekla = rez$sekla,
      vidiniai_matai(imtis$x, rez$klasteris)
    )
  })
)

# PCA imtyse jau patikrinta, kad liko vienas klasteris.
stopifnot(
  all(stabilumo_pca_bandymai$klasteriu_sk == 1L)
)

vidiniai_pca <- data.frame(
  erdve = "PCA 5D",
  sekla = stabilumo_pca_bandymai$sekla,
  klasteriu_sk = stabilumo_pca_bandymai$klasteriu_sk,
  vertinta_n = stabilumo_pca_bandymai$objektu_sk -
    stabilumo_pca_bandymai$triuksmo_sk,
  Silhouette = NA_real_,
  CH = NA_real_,
  DB = NA_real_
)

# t-SNE imčių koordinatės išsaugotos 27 bloke.
vidiniai_tsne <- do.call(
  rbind,
  lapply(stabilumas_tsne, function(rez) {
    data.frame(
      erdve = "t-SNE 2D",
      sekla = rez$sekla,
      vidiniai_matai(rez$x, rez$klasteris)
    )
  })
)

stabilumo_vidiniai <- rbind(
  vidiniai_originali,
  vidiniai_pca,
  vidiniai_tsne
)

vidiniu_suvestine <- do.call(
  rbind,
  lapply(unique(stabilumo_vidiniai$erdve), function(e) {
    
    dalis <- stabilumo_vidiniai[
      stabilumo_vidiniai$erdve == e,
    ]
    
    do.call(
      rbind,
      lapply(c("Silhouette", "CH", "DB"), function(m) {
        
        reiksmes <- dalis[[m]]
        reiksmes <- reiksmes[is.finite(reiksmes)]
        
        data.frame(
          erdve = e,
          rodiklis = m,
          vertintu_imciu = length(reiksmes),
          vidurkis = if (length(reiksmes) > 0) {
            mean(reiksmes)
          } else {
            NA_real_
          },
          SD = if (length(reiksmes) > 1) {
            sd(reiksmes)
          } else {
            NA_real_
          }
        )
      })
    )
  })
)

write.csv(
  stabilumo_vidiniai,
  "rezultatai/dbscan_stabilumo_vidiniai.csv",
  row.names = FALSE
)

write.csv(
  vidiniu_suvestine,
  "rezultatai/dbscan_stabilumo_vidiniu_suvestine.csv",
  row.names = FALSE
)

print(vidiniu_suvestine, row.names = FALSE, digits = 5)









# 30. Papildomo 19D kandidato stabilumas
# Fiksuoti parametrai: eps = 1.15, minPts = 10.

stabilumas_originali_kandidatas <- lapply(
  stabilumo_imtys,
  function(imtis) {
    
    zymes <- dbscan::dbscan(
      imtis$x,
      eps = 1.15,
      minPts = 10,
      borderPoints = TRUE
    )$cluster
    
    list(
      sekla = imtis$sekla,
      id = imtis$id,
      klasteris = zymes
    )
  }
)

kandidato_originali_bandymai <- do.call(
  rbind,
  lapply(stabilumas_originali_kandidatas, function(rez) {
    
    dydziai <- sort(
      table(rez$klasteris[rez$klasteris > 0]),
      decreasing = TRUE
    )
    
    data.frame(
      sekla = rez$sekla,
      eps = 1.15,
      minPts = 10,
      objektu_sk = length(rez$id),
      klasteriu_sk = length(dydziai),
      triuksmas_proc = 100 * mean(rez$klasteris == 0),
      klasteriu_dydziai = paste(
        as.integer(dydziai),
        collapse = "; "
      )
    )
  })
)

kandidato_poros <- combn(
  seq_along(stabilumas_originali_kandidatas), 2
)

kandidato_originali_poros <- do.call(
  rbind,
  lapply(seq_len(ncol(kandidato_poros)), function(i) {
    
    a <- stabilumas_originali_kandidatas[[
      kandidato_poros[1, i]
    ]]
    b <- stabilumas_originali_kandidatas[[
      kandidato_poros[2, i]
    ]]
    
    bendri_id <- intersect(a$id, b$id)
    
    zymes_a <- a$klasteris[match(bendri_id, a$id)]
    zymes_b <- b$klasteris[match(bendri_id, b$id)]
    
    stopifnot(
      length(bendri_id) >= 2L,
      !anyNA(zymes_a),
      !anyNA(zymes_b)
    )
    
    matai <- suskirstymu_matai(zymes_a, zymes_b)
    
    triuksmas_a <- zymes_a == 0
    triuksmas_b <- zymes_b == 0
    sajunga <- sum(triuksmas_a | triuksmas_b)
    
    data.frame(
      sekla_A = a$sekla,
      sekla_B = b$sekla,
      bendru_objektu = length(bendri_id),
      ARI = unname(matai["ARI"]),
      NMI = unname(matai["NMI"]),
      Jaccard = unname(matai["Jaccard"]),
      triuksmo_Jaccard = if (sajunga > 0) {
        sum(triuksmas_a & triuksmas_b) / sajunga
      } else {
        NA_real_
      }
    )
  })
)

write.csv(
  kandidato_originali_bandymai,
  "rezultatai/dbscan_kandidato_stabilumo_bandymai_originali.csv",
  row.names = FALSE
)

write.csv(
  kandidato_originali_poros,
  "rezultatai/dbscan_kandidato_stabilumo_poros_originali.csv",
  row.names = FALSE
)

print(
  kandidato_originali_bandymai,
  row.names = FALSE,
  digits = 5
)






# 31. Papildomo PCA 5D kandidato stabilumas
# Fiksuoti parametrai: eps = 1.00, minPts = 10.

stabilumas_pca_kandidatas <- lapply(
  stabilumo_imtys,
  function(imtis) {
    
    pca_modelis <- prcomp(
      imtis$x,
      center = TRUE,
      scale. = FALSE
    )
    
    X <- pca_modelis$x[, 1:5, drop = FALSE]
    
    zymes <- dbscan::dbscan(
      X,
      eps = 1.00,
      minPts = 10,
      borderPoints = TRUE
    )$cluster
    
    list(
      sekla = imtis$sekla,
      id = imtis$id,
      x = X,
      klasteris = zymes
    )
  }
)

kandidato_pca_bandymai <- do.call(
  rbind,
  lapply(stabilumas_pca_kandidatas, function(rez) {
    
    dydziai <- sort(
      table(rez$klasteris[rez$klasteris > 0]),
      decreasing = TRUE
    )
    
    data.frame(
      sekla = rez$sekla,
      eps = 1.00,
      minPts = 10,
      objektu_sk = length(rez$id),
      klasteriu_sk = length(dydziai),
      triuksmas_proc = 100 * mean(rez$klasteris == 0),
      klasteriu_dydziai = paste(
        as.integer(dydziai),
        collapse = "; "
      )
    )
  })
)

kandidato_poros_pca <- combn(
  seq_along(stabilumas_pca_kandidatas), 2
)

kandidato_pca_poros <- do.call(
  rbind,
  lapply(seq_len(ncol(kandidato_poros_pca)), function(i) {
    
    a <- stabilumas_pca_kandidatas[[
      kandidato_poros_pca[1, i]
    ]]
    b <- stabilumas_pca_kandidatas[[
      kandidato_poros_pca[2, i]
    ]]
    
    bendri_id <- intersect(a$id, b$id)
    
    zymes_a <- a$klasteris[match(bendri_id, a$id)]
    zymes_b <- b$klasteris[match(bendri_id, b$id)]
    
    stopifnot(
      length(bendri_id) >= 2L,
      !anyNA(zymes_a),
      !anyNA(zymes_b)
    )
    
    matai <- suskirstymu_matai(zymes_a, zymes_b)
    
    triuksmas_a <- zymes_a == 0
    triuksmas_b <- zymes_b == 0
    sajunga <- sum(triuksmas_a | triuksmas_b)
    
    data.frame(
      sekla_A = a$sekla,
      sekla_B = b$sekla,
      bendru_objektu = length(bendri_id),
      ARI = unname(matai["ARI"]),
      NMI = unname(matai["NMI"]),
      Jaccard = unname(matai["Jaccard"]),
      triuksmo_Jaccard = if (sajunga > 0) {
        sum(triuksmas_a & triuksmas_b) / sajunga
      } else {
        NA_real_
      }
    )
  })
)

write.csv(
  kandidato_pca_bandymai,
  "rezultatai/dbscan_kandidato_stabilumo_bandymai_pca.csv",
  row.names = FALSE
)

write.csv(
  kandidato_pca_poros,
  "rezultatai/dbscan_kandidato_stabilumo_poros_pca.csv",
  row.names = FALSE
)

print(
  kandidato_pca_bandymai,
  row.names = FALSE,
  digits = 5
)







# 32. Papildomų t-SNE kandidatų stabilumas

papildomi_tsne <- data.frame(
  variantas = c("trys_klasteriai", "du_klasteriai"),
  eps = c(3.05, 3.20),
  minPts = c(4L, 4L)
)

kandidatu_tsne_bandymai <- list()
kandidatu_tsne_poros <- list()

for (v in seq_len(nrow(papildomi_tsne))) {
  
  p <- papildomi_tsne[v, ]
  
  # Taikome DBSCAN jau turimoms imčių projekcijoms.
  rezultatai <- lapply(stabilumas_tsne, function(imtis) {
    
    zymes <- dbscan::dbscan(
      imtis$x,
      eps = p$eps,
      minPts = p$minPts,
      borderPoints = TRUE
    )$cluster
    
    list(
      sekla = imtis$sekla,
      id = imtis$id,
      klasteris = zymes
    )
  })
  
  kandidatu_tsne_bandymai[[v]] <- do.call(
    rbind,
    lapply(rezultatai, function(rez) {
      
      dydziai <- sort(
        table(rez$klasteris[rez$klasteris > 0]),
        decreasing = TRUE
      )
      
      # Išsaugome priskyrimus vėlesnei patikrai.
      write.csv(
        data.frame(
          id = rez$id,
          klasteris = rez$klasteris
        ),
        paste0(
          "rezultatai/dbscan_stabilumas_tsne_",
          p$variantas,
          "_imtis_", rez$sekla, ".csv"
        ),
        row.names = FALSE
      )
      
      data.frame(
        variantas = p$variantas,
        sekla = rez$sekla,
        eps = p$eps,
        minPts = p$minPts,
        objektu_sk = length(rez$id),
        klasteriu_sk = length(dydziai),
        triuksmas_proc = 100 * mean(rez$klasteris == 0),
        klasteriu_dydziai = paste(
          as.integer(dydziai),
          collapse = "; "
        )
      )
    })
  )
  
  poros <- combn(seq_along(rezultatai), 2)
  
  kandidatu_tsne_poros[[v]] <- do.call(
    rbind,
    lapply(seq_len(ncol(poros)), function(i) {
      
      a <- rezultatai[[poros[1, i]]]
      b <- rezultatai[[poros[2, i]]]
      
      bendri_id <- intersect(a$id, b$id)
      
      zymes_a <- a$klasteris[match(bendri_id, a$id)]
      zymes_b <- b$klasteris[match(bendri_id, b$id)]
      
      stopifnot(
        length(bendri_id) >= 2L,
        !anyNA(zymes_a),
        !anyNA(zymes_b)
      )
      
      matai <- suskirstymu_matai(zymes_a, zymes_b)
      
      triuksmas_a <- zymes_a == 0
      triuksmas_b <- zymes_b == 0
      sajunga <- sum(triuksmas_a | triuksmas_b)
      
      data.frame(
        variantas = p$variantas,
        sekla_A = a$sekla,
        sekla_B = b$sekla,
        bendru_objektu = length(bendri_id),
        ARI = unname(matai["ARI"]),
        NMI = unname(matai["NMI"]),
        Jaccard = unname(matai["Jaccard"]),
        triuksmo_Jaccard = if (sajunga > 0) {
          sum(triuksmas_a & triuksmas_b) / sajunga
        } else {
          NA_real_
        }
      )
    })
  )
}

kandidatu_tsne_bandymai <- do.call(
  rbind, kandidatu_tsne_bandymai
)

kandidatu_tsne_poros <- do.call(
  rbind, kandidatu_tsne_poros
)

write.csv(
  kandidatu_tsne_bandymai,
  "rezultatai/dbscan_kandidatu_stabilumo_bandymai_tsne.csv",
  row.names = FALSE
)

write.csv(
  kandidatu_tsne_poros,
  "rezultatai/dbscan_kandidatu_stabilumo_poros_tsne.csv",
  row.names = FALSE
)

print(
  kandidatu_tsne_bandymai,
  row.names = FALSE,
  digits = 5
)







# 33. Stabilumo ARI vidurkio kitimas didinant imčių skaičių

poros_pagal_erdve <- list(
  "Originali 19D" = stabilumo_originali_poros,
  "PCA 5D" = stabilumo_pca_poros,
  "t-SNE 2D" = stabilumo_tsne_poros
)

stabilumas_pagal_N <- do.call(
  rbind,
  lapply(names(poros_pagal_erdve), function(e) {
    
    poros <- poros_pagal_erdve[[e]]
    
    do.call(
      rbind,
      lapply(5:10, function(N) {
        
        # Naudojame pirmas N imčių: sėklos 0,...,N−1.
        dalis <- poros[
          poros$sekla_A %in% 0:(N - 1L) &
            poros$sekla_B %in% 0:(N - 1L),
        ]
        
        stopifnot(nrow(dalis) == choose(N, 2))
        
        data.frame(
          erdve = e,
          N = N,
          poru_sk = nrow(dalis),
          ARI_vidurkis = mean(dalis$ARI),
          ARI_SD = sd(dalis$ARI)
        )
      })
    )
  })
)

stabilumas_pagal_N$erdve <- factor(
  stabilumas_pagal_N$erdve,
  levels = c("Originali 19D", "PCA 5D", "t-SNE 2D")
)

write.csv(
  stabilumas_pagal_N,
  "rezultatai/dbscan_stabilumas_pagal_N.csv",
  row.names = FALSE
)

grafikas_stabilumas_N <- ggplot(
  stabilumas_pagal_N,
  aes(
    x = N,
    y = ARI_vidurkis,
    colour = erdve,
    group = erdve
  )
) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 2.5) +
  scale_colour_manual(
    values = c(
      "Originali 19D" = "#F8766D",
      "PCA 5D" = "#00BFC4",
      "t-SNE 2D" = "#C77CFF"
    ),
    name = "Erdvė"
  ) +
  scale_x_continuous(breaks = 5:10) +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.2)
  ) +
  labs(
    title = "DBSCAN stabilumo įverčio kitimas",
    subtitle = "Geometrinio kelio atskaitos; naudojamos pirmos N imčių",
    x = "Imčių skaičius (N)",
    y = "Porinių ARI vidurkis",
    caption = "Kiekvienam N lyginamos visos pasirinktų imčių poros."
  ) +
  tema_dbscan()

ggsave(
  filename = "grafikai/dbscan_stabilumas_pagal_N.png",
  plot = grafikas_stabilumas_N,
  width = 10,
  height = 5.5,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_stabilumas_N)
print(stabilumas_pagal_N, row.names = FALSE, digits = 5)



# 34. Originalios ir PCA atskaitų stabilumas iki 20 imčių

# Papildomos 80 % imtys: sėklos 10–19.
papildomos_imtys <- lapply(10:19, function(sekla) {
  
  set.seed(sekla)
  
  indeksai <- sort(sample.int(
    nrow(X_pradine),
    size = imties_dydis,
    replace = FALSE
  ))
  
  X_imtis <- X_pradine[indeksai, , drop = FALSE]
  
  medianos <- apply(X_imtis, 2, median)
  iqr <- apply(X_imtis, 2, IQR)
  
  stopifnot(all(is.finite(iqr)), all(iqr > 0))
  
  X_normuota <- sweep(X_imtis, 2, medianos, "-")
  X_normuota <- sweep(X_normuota, 2, iqr, "/")
  
  stopifnot(all(is.finite(X_normuota)))
  
  list(
    sekla = sekla,
    id = stabilumo_duomenys$id[indeksai],
    x = X_normuota
  )
})

# Ta pati atskaitos procedūra kaip ankstesniuose blokuose.
skaiciuoti_atskaita <- function(imtis, naudoti_pca = FALSE) {
  
  if (naudoti_pca) {
    
    modelis <- prcomp(
      imtis$x,
      center = TRUE,
      scale. = FALSE
    )
    
    X <- modelis$x[, 1:5, drop = FALSE]
    min_pts <- 10L
    
    dispersija_5 <- sum(modelis$sdev[1:5]^2) /
      sum(modelis$sdev^2)
    
  } else {
    
    X <- imtis$x
    min_pts <- 38L
    dispersija_5 <- NA_real_
  }
  
  atstumai <- sort(
    dbscan::kNNdist(X, k = min_pts - 1L)
  )
  
  plotis <- max(atstumai) - min(atstumai)
  stopifnot(plotis > 0)
  
  horizontali <- seq(0, 1, length.out = length(atstumai))
  vertikali <- (atstumai - min(atstumai)) / plotis
  
  eps <- atstumai[
    which.max(horizontali - vertikali)
  ]
  
  zymes <- dbscan::dbscan(
    X,
    eps = eps,
    minPts = min_pts,
    borderPoints = TRUE
  )$cluster
  
  list(
    sekla = imtis$sekla,
    eps = eps,
    dispersija_5 = dispersija_5,
    id = imtis$id,
    klasteris = zymes
  )
}

papildomi_originali <- lapply(
  papildomos_imtys,
  skaiciuoti_atskaita,
  naudoti_pca = FALSE
)

papildomi_pca <- lapply(
  papildomos_imtys,
  skaiciuoti_atskaita,
  naudoti_pca = TRUE
)

# Pirmųjų 10 rezultatus paliekame nepakeistus.
stabilumas_originali_20 <- c(
  stabilumas_originali,
  papildomi_originali
)

stabilumas_pca_20 <- c(
  stabilumas_pca,
  papildomi_pca
)

# Poriniai palyginimai bendriems objektams.
lyginti_imciu_poras <- function(rezultatai) {
  
  poros <- combn(seq_along(rezultatai), 2)
  
  do.call(
    rbind,
    lapply(seq_len(ncol(poros)), function(i) {
      
      a <- rezultatai[[poros[1, i]]]
      b <- rezultatai[[poros[2, i]]]
      
      bendri_id <- intersect(a$id, b$id)
      
      zymes_a <- a$klasteris[match(bendri_id, a$id)]
      zymes_b <- b$klasteris[match(bendri_id, b$id)]
      
      stopifnot(
        length(bendri_id) >= 2L,
        !anyNA(zymes_a),
        !anyNA(zymes_b)
      )
      
      matai <- suskirstymu_matai(zymes_a, zymes_b)
      
      triuksmas_a <- zymes_a == 0
      triuksmas_b <- zymes_b == 0
      sajunga <- sum(triuksmas_a | triuksmas_b)
      
      data.frame(
        sekla_A = a$sekla,
        sekla_B = b$sekla,
        bendru_objektu = length(bendri_id),
        ARI = unname(matai["ARI"]),
        NMI = unname(matai["NMI"]),
        Jaccard = unname(matai["Jaccard"]),
        triuksmo_Jaccard = if (sajunga > 0) {
          sum(triuksmas_a & triuksmas_b) / sajunga
        } else {
          NA_real_
        }
      )
    })
  )
}

stabilumo_originali_poros_20 <- lyginti_imciu_poras(
  stabilumas_originali_20
)

stabilumo_pca_poros_20 <- lyginti_imciu_poras(
  stabilumas_pca_20
)

# Išsaugome visų 20 bandymų charakteristikas.
bandymu_suvestine_20 <- function(rezultatai, erdve, min_pts) {
  
  do.call(
    rbind,
    lapply(rezultatai, function(rez) {
      data.frame(
        erdve = erdve,
        sekla = rez$sekla,
        eps = rez$eps,
        minPts = min_pts,
        objektu_sk = length(rez$id),
        klasteriu_sk = length(unique(
          rez$klasteris[rez$klasteris > 0]
        )),
        triuksmo_sk = sum(rez$klasteris == 0),
        triuksmas_proc = 100 * mean(rez$klasteris == 0)
      )
    })
  )
}

bandymai_20 <- rbind(
  bandymu_suvestine_20(
    stabilumas_originali_20, "Originali 19D", 38L
  ),
  bandymu_suvestine_20(
    stabilumas_pca_20, "PCA 5D", 10L
  )
)

# ARI kitimas ties N = 5, 10, 15, 20.
poros_20 <- list(
  "Originali 19D" = stabilumo_originali_poros_20,
  "PCA 5D" = stabilumo_pca_poros_20
)

stabilumas_N_20 <- do.call(
  rbind,
  lapply(names(poros_20), function(e) {
    
    do.call(
      rbind,
      lapply(c(5L, 10L, 15L, 20L), function(N) {
        
        p <- poros_20[[e]]
        
        dalis <- p[
          p$sekla_A %in% 0:(N - 1L) &
            p$sekla_B %in% 0:(N - 1L),
        ]
        
        stopifnot(nrow(dalis) == choose(N, 2))
        
        data.frame(
          erdve = e,
          N = N,
          poru_sk = nrow(dalis),
          ARI_vidurkis = mean(dalis$ARI),
          ARI_SD = sd(dalis$ARI)
        )
      })
    )
  })
)

write.csv(
  stabilumo_originali_poros_20,
  "rezultatai/dbscan_stabilumo_poros_originali_20.csv",
  row.names = FALSE
)

write.csv(
  stabilumo_pca_poros_20,
  "rezultatai/dbscan_stabilumo_poros_pca_20.csv",
  row.names = FALSE
)

write.csv(
  bandymai_20,
  "rezultatai/dbscan_stabilumo_bandymai_20.csv",
  row.names = FALSE
)

write.csv(
  stabilumas_N_20,
  "rezultatai/dbscan_stabilumas_pagal_N_20.csv",
  row.names = FALSE
)

print(stabilumas_N_20, row.names = FALSE, digits = 6)



# 35. Atnaujintas stabilumo įverčio kitimo grafikas

grafiko_duomenys_N <- stabilumas_N_20

grafiko_duomenys_N$erdve <- factor(
  grafiko_duomenys_N$erdve,
  levels = c("Originali 19D", "PCA 5D")
)

grafikas_stabilumas_N_20 <- ggplot(
  grafiko_duomenys_N,
  aes(
    x = N,
    y = ARI_vidurkis,
    colour = erdve,
    group = erdve
  )
) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 2.5) +
  scale_colour_manual(
    values = c(
      "Originali 19D" = "#F8766D",
      "PCA 5D" = "#00BFC4"
    ),
    name = "Erdvė"
  ) +
  scale_x_continuous(
    breaks = c(5, 10, 15, 20)
  ) +
  scale_y_continuous(
    breaks = seq(0.75, 0.90, by = 0.025)
  ) +
  coord_cartesian(ylim = c(0.75, 0.90)) +
  labs(
    title = "DBSCAN stabilumo įverčio kitimas",
    subtitle = "Originalios ir PCA erdvių geometrinio kelio atskaitos",
    x = "Imčių skaičius (N)",
    y = "Porinių ARI vidurkis",
    caption = paste(
      "Vertikalioji ašis padidinta pokyčiams parodyti.",
      "t-SNE stabilumas vertintas su 10 imčių."
    )
  ) +
  tema_dbscan()

ggsave(
  filename = "grafikai/dbscan_stabilumas_pagal_N_20.png",
  plot = grafikas_stabilumas_N_20,
  width = 10,
  height = 5.5,
  units = "in",
  dpi = 300,
  bg = "white"
)

print(grafikas_stabilumas_N_20)



# 36. Panašios aprėpties kelių klasterių variantai

variantai_apreptis <- data.frame(
  erdve = c("Originali 19D", "PCA 5D", "t-SNE 2D"),
  eps = c(1.15, 1.00, 2.30),
  minPts = c(10L, 10L, 20L)
)

erdviu_matricos <- list(x, x_pca, x_tsne)

# Patikriname, kad matricų eilutės atitinka tuos pačius ID.
stopifnot(
  identical(aibe$id, pca_aibe$id),
  identical(aibe$id, tsne_pca_vaizdui$id)
)

aprepties_zymes <- lapply(
  seq_len(nrow(variantai_apreptis)),
  function(i) {
    dbscan::dbscan(
      erdviu_matricos[[i]],
      eps = variantai_apreptis$eps[i],
      minPts = variantai_apreptis$minPts[i],
      borderPoints = TRUE
    )$cluster
  }
)

# Vidiniai rodikliai kiekvieno varianto savo erdvėje.
aprepties_kokybe <- do.call(
  rbind,
  lapply(seq_len(nrow(variantai_apreptis)), function(i) {
    
    zymes <- aprepties_zymes[[i]]
    
    data.frame(
      variantai_apreptis[i, ],
      triuksmas_proc = 100 * mean(zymes == 0),
      vidiniai_matai(erdviu_matricos[[i]], zymes)
    )
  })
)

# Tie patys objektai, priskirti klasteriams visuose variantuose.
bendri_priskirti <- Reduce(
  "&",
  lapply(aprepties_zymes, function(z) z > 0)
)

# Visus suskirstymus vertiname pagal originalius 19D atstumus.
bendra_19D_kokybe <- do.call(
  rbind,
  lapply(seq_len(nrow(variantai_apreptis)), function(i) {
    
    # Perkoduojame išlikusias klasterių žymes į 1,...,k.
    zymes <- as.integer(factor(
      aprepties_zymes[[i]][bendri_priskirti]
    ))
    
    data.frame(
      suskirstymo_erdve = variantai_apreptis$erdve[i],
      vertinimo_erdve = "Originali 19D",
      vidiniai_matai(
        x[bendri_priskirti, , drop = FALSE],
        zymes
      )
    )
  })
)

write.csv(
  aprepties_kokybe,
  "rezultatai/dbscan_panasios_aprepties_kokybe.csv",
  row.names = FALSE
)

write.csv(
  bendra_19D_kokybe,
  "rezultatai/dbscan_panasios_aprepties_kokybe_bendra_19D.csv",
  row.names = FALSE
)

write.csv(
  data.frame(
    id = aibe$id,
    originali = aprepties_zymes[[1]],
    pca = aprepties_zymes[[2]],
    tsne = aprepties_zymes[[3]],
    bendras_vertinimo_poaibis = bendri_priskirti
  ),
  "rezultatai/dbscan_panasios_aprepties_priskyrimai.csv",
  row.names = FALSE
)

print(aprepties_kokybe, row.names = FALSE, digits = 5)
print(bendra_19D_kokybe, row.names = FALSE, digits = 5)



# 37. Bendra DBSCAN eksperimentų suvestinė

# Panašios aprėpties t-SNE kandidato stabilumas.
stabilumas_tsne_apreptis <- lapply(
  stabilumas_tsne,
  function(imtis) {
    
    zymes <- dbscan::dbscan(
      imtis$x,
      eps = 2.30,
      minPts = 20,
      borderPoints = TRUE
    )$cluster
    
    list(
      sekla = imtis$sekla,
      id = imtis$id,
      klasteris = zymes
    )
  }
)

# Naudojame 34 bloke sukurtą porų palyginimo funkciją.
tsne_aprepties_poros <- lyginti_imciu_poras(
  stabilumas_tsne_apreptis
)

tsne_aprepties_bandymai <- do.call(
  rbind,
  lapply(stabilumas_tsne_apreptis, function(rez) {
    
    dydziai <- sort(
      table(rez$klasteris[rez$klasteris > 0]),
      decreasing = TRUE
    )
    
    data.frame(
      sekla = rez$sekla,
      eps = 2.30,
      minPts = 20,
      klasteriu_sk = length(dydziai),
      triuksmas_proc = 100 * mean(rez$klasteris == 0),
      klasteriu_dydziai = paste(
        as.integer(dydziai),
        collapse = "; "
      )
    )
  })
)

write.csv(
  tsne_aprepties_poros,
  "rezultatai/dbscan_aprepties_tsne_stabilumo_poros.csv",
  row.names = FALSE
)

write.csv(
  tsne_aprepties_bandymai,
  "rezultatai/dbscan_aprepties_tsne_stabilumo_bandymai.csv",
  row.names = FALSE
)

# Dvi atskiros palyginimo grupės.
atskaitu_kokybe <- rbind(
  originali_suvestine,
  pca_suvestine,
  tsne_suvestine
)

atskaitu_zymes <- lapply(
  priskyrimai_erdvese,
  function(d) d$klasteris
)

atskaitu_stabilumas <- list(
  stabilumo_originali_poros,
  stabilumo_pca_poros,
  stabilumo_tsne_poros
)

aprepties_stabilumas <- list(
  kandidato_originali_poros,
  kandidato_pca_poros,
  tsne_aprepties_poros
)

suvestines_dalys <- list()

for (tipas in c("Kelio atskaita", "Panaši aprėptis")) {
  
  if (tipas == "Kelio atskaita") {
    kokybe <- atskaitu_kokybe
    zymes <- atskaitu_zymes
    stabilumas <- atskaitu_stabilumas
  } else {
    kokybe <- aprepties_kokybe
    zymes <- aprepties_zymes
    stabilumas <- aprepties_stabilumas
  }
  
  # Kiekvienos grupės referencija – jos originalios 19D
  # erdvės suskirstymas.
  referencija <- zymes[[1]]
  
  for (i in seq_len(nrow(kokybe))) {
    
    matai <- suskirstymu_matai(
      referencija,
      zymes[[i]]
    )
    
    suvestines_dalys[[length(suvestines_dalys) + 1L]] <-
      data.frame(
        variantu_grupe = tipas,
        erdve = kokybe$erdve[i],
        algoritmas = "DBSCAN",
        eps = kokybe$eps[i],
        minPts = kokybe$minPts[i],
        k = kokybe$klasteriu_sk[i],
        triuksmas_proc = kokybe$triuksmas_proc[i],
        Silhouette = kokybe$Silhouette[i],
        CH = kokybe$CH[i],
        DB = kokybe$DB[i],
        ARI_originali = unname(matai["ARI"]),
        NMI_originali = unname(matai["NMI"]),
        Jaccard_originali = unname(matai["Jaccard"]),
        stabilumo_N = 10L,
        stabilumo_ARI_vidurkis = mean(stabilumas[[i]]$ARI),
        stabilumo_ARI_SD = sd(stabilumas[[i]]$ARI)
      )
  }
}

eksperimentu_suvestine <- do.call(
  rbind,
  suvestines_dalys
)

write.csv(
  eksperimentu_suvestine,
  "rezultatai/dbscan_eksperimentu_suvestine.csv",
  row.names = FALSE
)

print(
  eksperimentu_suvestine,
  row.names = FALSE,
  digits = 5
)

print(
  tsne_aprepties_bandymai,
  row.names = FALSE,
  digits = 5
)