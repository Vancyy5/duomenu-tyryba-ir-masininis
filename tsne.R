# t-SNE dimensijos mažinimo tyrimas
library(Rtsne)
library(ggplot2)

# Nuskaitome grupės paruoštus duomenis
failai <- c("aibe_A.csv", "aibe_B.csv", "aibe_C.csv")

if (!all(file.exists(failai))) {
  stop(
    "Trūksta paruoštų CSV failų. ",
    "Pirmiausia paleiskite vykdymas.R 1–16 skyrius."
  )
}

aibe_A <- read.csv("aibe_A.csv")
aibe_B <- read.csv("aibe_B.csv")
aibe_C <- read.csv("aibe_C.csv")

paruosti_tsne_iejima <- function(df) {
  pozymiai <- setdiff(names(df), c("id", "class"))
  
  stopifnot(all(vapply(df[pozymiai], is.numeric, logical(1))))
  
  X <- as.matrix(df[pozymiai])
  stopifnot(!anyNA(X), all(is.finite(X)))
  X
}

X_A <- paruosti_tsne_iejima(aibe_A)
X_B <- paruosti_tsne_iejima(aibe_B)
X_C <- paruosti_tsne_iejima(aibe_C)

dir.create("grafikai", showWarnings = FALSE)
dir.create("rezultatai", showWarnings = FALSE)

# Pirmoji t-SNE projekcija – A aibė
set.seed(42)

tsne_A <- Rtsne(
  X_A,
  dims = 2,
  perplexity = 30,
  max_iter = 1000,
  pca = FALSE,
  normalize = FALSE,
  verbose = TRUE
)

dim(tsne_A$Y)

# Paruošiame koordinates grafikui
tsne_2d_A <- data.frame(
  TSNE1 = tsne_A$Y[, 1],
  TSNE2 = tsne_A$Y[, 2],
  class = aibe_A$class,
  id = aibe_A$id
)

# Nubraižo projekciją
grafikas_tsne_A <- ggplot(
  tsne_2d_A,
  aes(x = TSNE1, y = TSNE2, color = class)
) +
  geom_point(alpha = 0.5, size = 1) +
  coord_equal() +
  labs(
    title = "t-SNE 2D projekcija – A aibė",
    subtitle = "Perplexity = 30; sėkla = 42",
    x = "t-SNE 1",
    y = "t-SNE 2",
    color = "Deimanto klasė"
  ) +
  theme_minimal()

print(grafikas_tsne_A)

# Sukuriame aplanką, jei jo dar nėra
dir.create("grafikai", showWarnings = FALSE)

# Išsaugome grafiką
ggsave(
  filename = "grafikai/tsne_2d_A_p30_seed42.png",
  plot = grafikas_tsne_A,
  width = 8,
  height = 6,
  units = "in",
  dpi = 300
)

# =========================================================
# A AIBĖ: PERPLEXITY PARAMETRO TYRIMAS
# =========================================================

perplexity_reiksmes <- c(5, 30, 50)

# Išsaugome jau apskaičiuotą p = 30 rezultatą
tsne_A_variantai <- list()
tsne_A_variantai[["30"]] <- tsne_A

# Papildomai apskaičiuojame p = 5 ir p = 50
for (p in c(5, 50)) {
  set.seed(42)
  
  tsne_A_variantai[[as.character(p)]] <- Rtsne(
    X_A,
    dims = 2,
    perplexity = p,
    max_iter = 1000,
    pca = FALSE,
    normalize = FALSE,
    verbose = TRUE
  )
}

# Sujungiame trijų projekcijų koordinates
tsne_parametru_duomenys <- do.call(
  rbind,
  lapply(perplexity_reiksmes, function(p) {
    rezultatas <- tsne_A_variantai[[as.character(p)]]
    
    data.frame(
      TSNE1 = rezultatas$Y[, 1],
      TSNE2 = rezultatas$Y[, 2],
      class = aibe_A$class,
      id = aibe_A$id,
      perplexity = p
    )
  })
)

tsne_parametru_duomenys$perplexity <- factor(
  tsne_parametru_duomenys$perplexity,
  levels = perplexity_reiksmes
)

# Trijų variantų palyginimas viename paveiksle
grafikas_tsne_parametrai <- ggplot(
  tsne_parametru_duomenys,
  aes(TSNE1, TSNE2, color = class)
) +
  geom_point(alpha = 0.5, size = 0.6) +
  facet_wrap(
    ~perplexity,
    nrow = 1,
    labeller = label_both
  ) +
  coord_equal() +
  labs(
    title = "t-SNE parametrų tyrimas – A aibė",
    subtitle = "Sėkla = 42; 1000 iteracijų",
    x = "t-SNE 1",
    y = "t-SNE 2",
    color = "Deimanto klasė"
  ) +
  theme_minimal()

print(grafikas_tsne_parametrai)

dir.create("grafikai", showWarnings = FALSE)
dir.create("rezultatai", showWarnings = FALSE)

ggsave(
  "grafikai/tsne_A_perplexity_palyginimas.png",
  plot = grafikas_tsne_parametrai,
  width = 15,
  height = 5,
  dpi = 300
)

# Galutinė algoritmo optimizuojama KL paklaida
tsne_parametru_suvestine <- data.frame(
  perplexity = perplexity_reiksmes,
  sekla = 42,
  iteracijos = 1000,
  KL_paklaida = sapply(perplexity_reiksmes, function(p) {
    tail(
      tsne_A_variantai[[as.character(p)]]$itercosts,
      1
    )
  })
)

print(tsne_parametru_suvestine, row.names = FALSE)

write.csv(
  tsne_parametru_suvestine,
  "rezultatai/tsne_A_perplexity_suvestine.csv",
  row.names = FALSE
)

# Išsaugome rezultatus, kad nereikėtų skaičiuoti iš naujo
saveRDS(
  tsne_A_variantai,
  "rezultatai/tsne_A_perplexity_variantai.rds"
)

# =========================================================
# KAIMYNŲ IŠSAUGOJIMAS – A AIBĖ
# =========================================================

# Kiekvienoje eilutėje grąžina artimiausių kaimynų indeksus
rasti_kaimynus <- function(X, max_k = 50) {
  D <- as.matrix(dist(X))
  
  # Objektas negali būti savo paties kaimynas
  diag(D) <- Inf
  
  t(vapply(
    seq_len(nrow(D)),
    function(i) {
      order(D[i, ], seq_along(D[i, ]))[seq_len(max_k)]
    },
    integer(max_k)
  ))
}

# Pradinės 19 požymių erdvės kaimynus skaičiuojame vieną kartą
kaimynai_X_A <- rasti_kaimynus(X_A)

k_reiksmes <- c(5, 15, 50)

kaimynu_rezultatai <- do.call(
  rbind,
  lapply(perplexity_reiksmes, function(p) {
    
    Y <- tsne_A_variantai[[as.character(p)]]$Y
    kaimynai_Y <- rasti_kaimynus(Y)
    
    do.call(
      rbind,
      lapply(k_reiksmes, function(k) {
        
        sutapimas <- vapply(
          seq_len(nrow(X_A)),
          function(i) {
            length(intersect(
              kaimynai_X_A[i, seq_len(k)],
              kaimynai_Y[i, seq_len(k)]
            )) / k
          },
          numeric(1)
        )
        
        data.frame(
          perplexity = p,
          k = k,
          kaimynu_issaugojimas = mean(sutapimas)
        )
      })
    )
  })
)

print(kaimynu_rezultatai, row.names = FALSE)

write.csv(
  kaimynu_rezultatai,
  "rezultatai/tsne_A_kaimynu_issaugojimas.csv",
  row.names = FALSE
)

# =========================================================
# TRUSTWORTHINESS IR CONTINUITY – A AIBĖ
# =========================================================

# Atstumų rangai: artimiausias kitas objektas turi rangą 1.
# Vienodi atstumai rikiuojami pagal eilutės indeksą,
# kaip ankstesniame kaimynų išsaugojimo skaičiavime.
atstumu_rangai <- function(X) {
  D <- as.matrix(dist(X))
  diag(D) <- Inf
  
  N <- nrow(D)
  R <- matrix(0L, nrow = N, ncol = N)
  
  for (i in seq_len(N)) {
    tvarka <- order(D[i, ], seq_len(N))
    R[i, tvarka] <- seq_len(N)
  }
  
  R
}

skaiciuoti_TC <- function(R_X, R_Y, k) {
  N <- nrow(R_X)
  
  stopifnot(
    identical(dim(R_X), dim(R_Y)),
    k > 0,
    k < N / 2
  )
  
  bauda_T <- 0
  bauda_C <- 0
  
  for (i in seq_len(N)) {
    kaimynai_X <- which(R_X[i, ] <= k)
    kaimynai_Y <- which(R_Y[i, ] <= k)
    
    # Projekcijoje atsiradę nauji kaimynai
    netikri <- setdiff(kaimynai_Y, kaimynai_X)
    
    # Projekcijoje prarasti pradiniai kaimynai
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

# Pradinės erdvės rangus apskaičiuojame vieną kartą
rangai_X_A <- atstumu_rangai(X_A)

# Paprasta patikra: lyginant erdvę su ja pačia,
# abu rodikliai turi būti lygūs 1.
patikra_TC <- skaiciuoti_TC(rangai_X_A, rangai_X_A, k = 5)

stopifnot(
  abs(patikra_TC$Trustworthiness - 1) < 1e-12,
  abs(patikra_TC$Continuity - 1) < 1e-12
)

# Įvertiname tris perplexity variantus
TC_rezultatai <- do.call(
  rbind,
  lapply(perplexity_reiksmes, function(p) {
    message("Skaičiuojama: perplexity = ", p)
    
    Y <- tsne_A_variantai[[as.character(p)]]$Y
    rangai_Y <- atstumu_rangai(Y)
    
    lentele <- do.call(
      rbind,
      lapply(k_reiksmes, function(k) {
        skaiciuoti_TC(rangai_X_A, rangai_Y, k)
      })
    )
    
    data.frame(perplexity = p, lentele)
  })
)

print(TC_rezultatai, row.names = FALSE, digits = 6)

write.csv(
  TC_rezultatai,
  "rezultatai/tsne_A_trustworthiness_continuity.csv",
  row.names = FALSE
)

# =========================================================
# STABILUMAS: 5 SĖKLOS, A AIBĖ, PERPLEXITY = 30
# =========================================================

seklos <- c(42, 123, 2026, 7, 99)
k_reiksmes <- c(5, 15, 50)

# Pirmą rezultatą jau turime
tsne_A_seklos <- list()
tsne_A_seklos[["42"]] <- tsne_A_variantai[["30"]]

# Apskaičiuojame likusius keturis paleidimus
for (s in seklos[seklos != 42]) {
  message("t-SNE paleidimas: sėkla = ", s)
  
  set.seed(s)
  
  tsne_A_seklos[[as.character(s)]] <- Rtsne(
    X_A,
    dims = 2,
    perplexity = 30,
    max_iter = 1000,
    pca = FALSE,
    normalize = FALSE,
    verbose = FALSE
  )
  
  # Po kiekvieno paleidimo išsaugome progresą
  saveRDS(
    tsne_A_seklos,
    "rezultatai/tsne_A_p30_seklos.rds"
  )
}

# Kokybės rodikliai kiekvienai sėklai
stabilumo_rezultatai <- do.call(
  rbind,
  lapply(seklos, function(s) {
    message("Vertinamos metrikos: sėkla = ", s)
    
    rezultatas <- tsne_A_seklos[[as.character(s)]]
    
    # Sėklos 42 metrikas jau apskaičiavome
    if (s == 42) {
      tc <- TC_rezultatai[
        TC_rezultatai$perplexity == 30,
        c("k", "Trustworthiness", "Continuity")
      ]
      
      nh <- kaimynu_rezultatai[
        kaimynu_rezultatai$perplexity == 30,
        c("k", "kaimynu_issaugojimas")
      ]
      
      lentele <- merge(tc, nh, by = "k")
      
    } else {
      rangai_Y <- atstumu_rangai(rezultatas$Y)
      
      lentele <- do.call(
        rbind,
        lapply(k_reiksmes, function(k) {
          tc <- skaiciuoti_TC(rangai_X_A, rangai_Y, k)
          
          sutapimas <- vapply(
            seq_len(nrow(X_A)),
            function(i) {
              pradine_kaimynyste <- which(rangai_X_A[i, ] <= k)
              projekcijos_kaimynyste <- which(rangai_Y[i, ] <= k)
              
              length(intersect(
                pradine_kaimynyste,
                projekcijos_kaimynyste
              )) / k
            },
            numeric(1)
          )
          
          tc$kaimynu_issaugojimas <- mean(sutapimas)
          tc
        })
      )
    }
    
    data.frame(
      sekla = s,
      perplexity = 30,
      lentele,
      KL_paklaida = tail(rezultatas$itercosts, 1)
    )
  })
)

write.csv(
  stabilumo_rezultatai,
  "rezultatai/tsne_A_p30_stabilumas.csv",
  row.names = FALSE
)

# Vidurkiai ir standartiniai nuokrypiai per 5 sėklas
stabilumo_suvestine <- do.call(
  rbind,
  lapply(k_reiksmes, function(k) {
    d <- stabilumo_rezultatai[
      stabilumo_rezultatai$k == k,
    ]
    
    data.frame(
      k = k,
      T_vidurkis = mean(d$Trustworthiness),
      T_SD = sd(d$Trustworthiness),
      C_vidurkis = mean(d$Continuity),
      C_SD = sd(d$Continuity),
      kaimynu_vidurkis = mean(d$kaimynu_issaugojimas),
      kaimynu_SD = sd(d$kaimynu_issaugojimas)
    )
  })
)

print(stabilumo_suvestine, row.names = FALSE, digits = 6)

write.csv(
  stabilumo_suvestine,
  "rezultatai/tsne_A_p30_stabilumo_suvestine.csv",
  row.names = FALSE
)

# =========================================================
# GLOBALI STRUKTŪRA – A AIBĖ, PERPLEXITY = 30
# =========================================================

# Visi pradiniai poriniai Euklido atstumai
pradiniai_atstumai_A <- as.vector(dist(X_A))

# Rangus apskaičiuojame vieną kartą.
# Vienodiems atstumams suteikiami vidutiniai rangai.
pradiniai_rangai_A <- rank(
  pradiniai_atstumai_A,
  ties.method = "average"
)

globalus_rezultatai <- do.call(
  rbind,
  lapply(seklos, function(s) {
    message("Globalūs rodikliai: sėkla = ", s)
    
    Y <- tsne_A_seklos[[as.character(s)]]$Y
    projekcijos_atstumai <- as.vector(dist(Y))
    
    # Spearman = Pearson koreliacija tarp atstumų rangų
    projekcijos_rangai <- rank(
      projekcijos_atstumai,
      ties.method = "average"
    )
    
    rho <- cor(pradiniai_rangai_A, projekcijos_rangai)
    
    # Optimalus bendras projekcijos mastelio koeficientas
    mastelis <- sum(
      pradiniai_atstumai_A * projekcijos_atstumai
    ) / sum(projekcijos_atstumai^2)
    
    # Ta pati normalizuoto Stress formulė kaip Miglės kode
    stress <- sqrt(
      sum(
        (pradiniai_atstumai_A -
           mastelis * projekcijos_atstumai)^2
      ) / sum(pradiniai_atstumai_A^2)
    )
    
    data.frame(
      sekla = s,
      perplexity = 30,
      Spearman = rho,
      Normalizuotas_Stress = stress
    )
  })
)

print(globalus_rezultatai, row.names = FALSE, digits = 6)

write.csv(
  globalus_rezultatai,
  "rezultatai/tsne_A_p30_globalus_rodikliai.csv",
  row.names = FALSE
)

globali_suvestine <- data.frame(
  Spearman_vidurkis = mean(globalus_rezultatai$Spearman),
  Spearman_SD = sd(globalus_rezultatai$Spearman),
  Stress_vidurkis = mean(globalus_rezultatai$Normalizuotas_Stress),
  Stress_SD = sd(globalus_rezultatai$Normalizuotas_Stress)
)

print(globali_suvestine, row.names = FALSE, digits = 6)

write.csv(
  globali_suvestine,
  "rezultatai/tsne_A_p30_globali_suvestine.csv",
  row.names = FALSE
)

# =========================================================
# t-SNE – B AIBĖ
# =========================================================

# Patikriname dydį ir objektų eiliškumą
stopifnot(
  nrow(X_B) == 4000,
  ncol(X_B) == 6,
  identical(aibe_A$id, aibe_B$id)
)

set.seed(42)

tsne_B <- Rtsne(
  X_B,
  dims = 2,
  perplexity = 30,
  max_iter = 1000,
  pca = FALSE,
  normalize = FALSE,
  verbose = TRUE
)

# Išsaugome rezultatą
saveRDS(
  tsne_B,
  "rezultatai/tsne_B_p30_seed42.rds"
)

# Paruošiame grafiką
tsne_2d_B <- data.frame(
  TSNE1 = tsne_B$Y[, 1],
  TSNE2 = tsne_B$Y[, 2],
  class = aibe_B$class,
  id = aibe_B$id
)

grafikas_tsne_B <- ggplot(
  tsne_2d_B,
  aes(TSNE1, TSNE2, color = class)
) +
  geom_point(alpha = 0.5, size = 1) +
  coord_equal() +
  labs(
    title = "t-SNE 2D projekcija – B aibė",
    subtitle = "6 požymiai; perplexity = 30; sėkla = 42",
    x = "t-SNE 1",
    y = "t-SNE 2",
    color = "Deimanto klasė"
  ) +
  theme_minimal()

print(grafikas_tsne_B)

ggsave(
  "grafikai/tsne_2d_B_p30_seed42.png",
  plot = grafikas_tsne_B,
  width = 8,
  height = 6,
  dpi = 300
)

# Patikriname rezultatą
dim(tsne_B$Y)
tail(tsne_B$itercosts, 1)

# =========================================================
# B PROJEKCIJOS LOKALI KOKYBĖ IR A/B STRUKTŪROS POKYTIS
# =========================================================

rangai_X_B <- atstumu_rangai(X_B)
rangai_tsne_B <- atstumu_rangai(tsne_B$Y)

# Bendra funkcija kaimynysčių sutapimui
kaimynysciu_sutapimas <- function(R1, R2, k) {
  stopifnot(identical(dim(R1), dim(R2)))
  
  mean(vapply(
    seq_len(nrow(R1)),
    function(i) {
      length(intersect(
        which(R1[i, ] <= k),
        which(R2[i, ] <= k)
      )) / k
    },
    numeric(1)
  ))
}

# B projekcija savo B ir originalios A erdvės atžvilgiu
B_lokali_kokybe <- do.call(
  rbind,
  lapply(c("B", "A"), function(atskaita) {
    R <- if (atskaita == "B") rangai_X_B else rangai_X_A
    
    do.call(
      rbind,
      lapply(k_reiksmes, function(k) {
        tc <- skaiciuoti_TC(R, rangai_tsne_B, k)
        
        data.frame(
          atskaitos_erdve = atskaita,
          tc,
          kaimynu_issaugojimas = kaimynysciu_sutapimas(
            R, rangai_tsne_B, k
          )
        )
      })
    )
  })
)

# Ar pati požymių atranka pakeitė pradines kaimynystes?
AB_kaimynystes <- data.frame(
  k = k_reiksmes,
  sutapimas = sapply(k_reiksmes, function(k) {
    kaimynysciu_sutapimas(rangai_X_A, rangai_X_B, k)
  })
)

print(B_lokali_kokybe, row.names = FALSE, digits = 6)
print(AB_kaimynystes, row.names = FALSE, digits = 6)

write.csv(
  B_lokali_kokybe,
  "rezultatai/tsne_B_lokali_kokybe.csv",
  row.names = FALSE
)

write.csv(
  AB_kaimynystes,
  "rezultatai/AB_pradiniu_kaimynysciu_sutapimas.csv",
  row.names = FALSE
)

# =========================================================
# GLOBALUS A/B PALYGINIMAS
# =========================================================

# Funkcija palygina dviejų erdvių porinius atstumus
vertinti_atstumus <- function(d_pradiniai, d_lyginami) {
  stopifnot(
    length(d_pradiniai) == length(d_lyginami),
    all(is.finite(d_pradiniai)),
    all(is.finite(d_lyginami)),
    sum(d_pradiniai^2) > 0,
    sum(d_lyginami^2) > 0
  )
  
  # Spearman koreliacija tarp atstumų
  rho <- cor(
    rank(d_pradiniai, ties.method = "average"),
    rank(d_lyginami, ties.method = "average")
  )
  
  # Suderiname bendrą lyginamų atstumų mastelį
  mastelis <- sum(d_pradiniai * d_lyginami) /
    sum(d_lyginami^2)
  
  stress <- sqrt(
    sum((d_pradiniai - mastelis * d_lyginami)^2) /
      sum(d_pradiniai^2)
  )
  
  data.frame(
    Spearman = rho,
    Normalizuotas_Stress = stress
  )
}

atstumai_X_B <- as.vector(dist(X_B))
atstumai_tsne_B <- as.vector(dist(tsne_B$Y))

AB_globalus_rezultatai <- rbind(
  data.frame(
    palyginimas = "A erdvė vs B erdvė",
    vertinti_atstumus(
      pradiniai_atstumai_A,
      atstumai_X_B
    )
  ),
  data.frame(
    palyginimas = "B erdvė vs B projekcija",
    vertinti_atstumus(
      atstumai_X_B,
      atstumai_tsne_B
    )
  ),
  data.frame(
    palyginimas = "A erdvė vs B projekcija",
    vertinti_atstumus(
      pradiniai_atstumai_A,
      atstumai_tsne_B
    )
  )
)

print(AB_globalus_rezultatai, row.names = FALSE, digits = 6)

write.csv(
  AB_globalus_rezultatai,
  "rezultatai/tsne_AB_globalus_palyginimas.csv",
  row.names = FALSE
)

# =========================================================
# t-SNE – C AIBĖ
# =========================================================

stopifnot(
  nrow(X_C) == 3928,
  ncol(X_C) == 19,
  !anyDuplicated(aibe_C$id),
  all(aibe_C$id %in% aibe_A$id)
)

set.seed(42)

tsne_C <- Rtsne(
  X_C,
  dims = 2,
  perplexity = 30,
  max_iter = 1000,
  pca = FALSE,
  normalize = FALSE,
  verbose = TRUE
)

saveRDS(
  tsne_C,
  "rezultatai/tsne_C_p30_seed42.rds"
)

# Projekcijos grafikas
tsne_2d_C <- data.frame(
  TSNE1 = tsne_C$Y[, 1],
  TSNE2 = tsne_C$Y[, 2],
  class = aibe_C$class,
  id = aibe_C$id
)

grafikas_tsne_C <- ggplot(
  tsne_2d_C,
  aes(TSNE1, TSNE2, color = class)
) +
  geom_point(alpha = 0.5, size = 1) +
  coord_equal() +
  labs(
    title = "t-SNE 2D projekcija – C aibė",
    subtitle = "Be 72 ekstremalių objektų; perplexity = 30; sėkla = 42",
    x = "t-SNE 1",
    y = "t-SNE 2",
    color = "Deimanto klasė"
  ) +
  theme_minimal()

print(grafikas_tsne_C)

ggsave(
  "grafikai/tsne_2d_C_p30_seed42.png",
  plot = grafikas_tsne_C,
  width = 8,
  height = 6,
  dpi = 300
)

dim(tsne_C$Y)
tail(tsne_C$itercosts, 1)

# =========================================================
# A/C PALYGINIMAS – TIK BENDRI OBJEKTAI
# =========================================================

# A eilutes surikiuojame tiksliai pagal C objektų tvarką
indeksai_A <- match(aibe_C$id, aibe_A$id)

stopifnot(
  !anyNA(indeksai_A),
  identical(aibe_A$id[indeksai_A], aibe_C$id),
  identical(colnames(X_A), colnames(X_C))
)

# Pradinė A erdvė ir A projekcija, palikus tik C objektus
X_A_bendri <- X_A[indeksai_A, , drop = FALSE]
Y_A_bendri <- tsne_A_seklos[["42"]]$Y[
  indeksai_A, , drop = FALSE
]

# Nauja C projekcija
Y_C <- tsne_C$Y

# Perskaičiuojame rangus tik bendrų objektų imtyje
rangai_X_A_bendri <- atstumu_rangai(X_A_bendri)
rangai_X_C <- atstumu_rangai(X_C)
rangai_Y_A_bendri <- atstumu_rangai(Y_A_bendri)
rangai_Y_C <- atstumu_rangai(Y_C)

# Trys vertinimo atvejai
AC_atvejai <- list(
  list(
    pavadinimas = "A projekcija / A bendrų objektų erdvė",
    R_X = rangai_X_A_bendri,
    R_Y = rangai_Y_A_bendri
  ),
  list(
    pavadinimas = "C projekcija / A bendrų objektų erdvė",
    R_X = rangai_X_A_bendri,
    R_Y = rangai_Y_C
  ),
  list(
    pavadinimas = "C projekcija / C erdvė",
    R_X = rangai_X_C,
    R_Y = rangai_Y_C
  )
)

AC_lokali_kokybe <- do.call(
  rbind,
  lapply(AC_atvejai, function(atvejis) {
    do.call(
      rbind,
      lapply(k_reiksmes, function(k) {
        tc <- skaiciuoti_TC(
          atvejis$R_X, atvejis$R_Y, k
        )
        
        data.frame(
          palyginimas = atvejis$pavadinimas,
          tc,
          kaimynu_issaugojimas = kaimynysciu_sutapimas(
            atvejis$R_X, atvejis$R_Y, k
          )
        )
      })
    )
  })
)

# Pradinių erdvių ir pačių projekcijų kaimynysčių sutapimas
AC_sutapimas <- data.frame(
  k = k_reiksmes,
  pradines_erdves = sapply(k_reiksmes, function(k) {
    kaimynysciu_sutapimas(
      rangai_X_A_bendri, rangai_X_C, k
    )
  }),
  projekcijos = sapply(k_reiksmes, function(k) {
    kaimynysciu_sutapimas(
      rangai_Y_A_bendri, rangai_Y_C, k
    )
  })
)

print(AC_lokali_kokybe, row.names = FALSE, digits = 6)
print(AC_sutapimas, row.names = FALSE, digits = 6)

write.csv(
  AC_lokali_kokybe,
  "rezultatai/tsne_AC_lokali_kokybe.csv",
  row.names = FALSE
)

write.csv(
  AC_sutapimas,
  "rezultatai/tsne_AC_kaimynysciu_sutapimas.csv",
  row.names = FALSE
)

# =========================================================
# GLOBALUS A/C PALYGINIMAS – BENDRI OBJEKTAI
# =========================================================

# Visuose variantuose objektų tvarka vienoda
d_A_bendri <- as.vector(dist(X_A_bendri))
d_C <- as.vector(dist(X_C))
d_Y_A_bendri <- as.vector(dist(Y_A_bendri))
d_Y_C <- as.vector(dist(Y_C))

AC_globalus_rezultatai <- rbind(
  data.frame(
    palyginimas = "A bendrų objektų erdvė vs C erdvė",
    vertinti_atstumus(d_A_bendri, d_C)
  ),
  data.frame(
    palyginimas = "A erdvė vs A projekcija (bendri)",
    vertinti_atstumus(d_A_bendri, d_Y_A_bendri)
  ),
  data.frame(
    palyginimas = "A erdvė vs C projekcija (bendri)",
    vertinti_atstumus(d_A_bendri, d_Y_C)
  ),
  data.frame(
    palyginimas = "C erdvė vs C projekcija",
    vertinti_atstumus(d_C, d_Y_C)
  ),
  data.frame(
    palyginimas = "A projekcija vs C projekcija (bendri)",
    vertinti_atstumus(d_Y_A_bendri, d_Y_C)
  )
)

print(
  AC_globalus_rezultatai,
  row.names = FALSE,
  digits = 6
)

write.csv(
  AC_globalus_rezultatai,
  "rezultatai/tsne_AC_globalus_palyginimas.csv",
  row.names = FALSE
)

# Programinė aplinka ir paketo citavimas
R.version.string
packageVersion("Rtsne")
packageVersion("ggplot2")

writeLines(
  capture.output(sessionInfo()),
  "rezultatai/sessionInfo.txt"
)

citation("Rtsne")

# =========================================================
# PAPILDOMAS TYRIMAS: A AIBĖS 3D t-SNE
# =========================================================

set.seed(42)

tsne_A_3d <- Rtsne(
  X_A,
  dims = 3,
  perplexity = 30,
  max_iter = 1000,
  pca = FALSE,
  normalize = FALSE,
  verbose = TRUE
)

saveRDS(
  tsne_A_3d,
  "rezultatai/tsne_A_3d_p30_seed42.rds"
)

# Koordinatės su objektų identifikatoriais ir klasėmis
tsne_3d_A <- data.frame(
  TSNE1 = tsne_A_3d$Y[, 1],
  TSNE2 = tsne_A_3d$Y[, 2],
  TSNE3 = tsne_A_3d$Y[, 3],
  class = aibe_A$class,
  id = aibe_A$id
)

write.csv(
  tsne_3d_A,
  "rezultatai/tsne_A_3d_koordinates.csv",
  row.names = FALSE
)

dim(tsne_A_3d$Y)
tail(tsne_A_3d$itercosts, 1)

# =========================================================
# A AIBĖ: 2D IR 3D KOKYBĖS PALYGINIMAS
# =========================================================

rangai_Y_3d <- atstumu_rangai(tsne_A_3d$Y)

# 3D lokalios kokybės rodikliai
kokybe_3d <- do.call(
  rbind,
  lapply(k_reiksmes, function(k) {
    tc <- skaiciuoti_TC(rangai_X_A, rangai_Y_3d, k)
    
    data.frame(
      dimensija = 3,
      tc,
      kaimynu_issaugojimas = kaimynysciu_sutapimas(
        rangai_X_A, rangai_Y_3d, k
      )
    )
  })
)

# Anksčiau apskaičiuoti 2D rodikliai su sėkla 42
kokybe_2d <- stabilumo_rezultatai[
  stabilumo_rezultatai$sekla == 42,
  c("k", "Trustworthiness", "Continuity",
    "kaimynu_issaugojimas")
]

kokybe_2d <- data.frame(dimensija = 2, kokybe_2d)

dimensiju_lokali_kokybe <- rbind(kokybe_2d, kokybe_3d)

# Globalūs rodikliai
globali_3d <- vertinti_atstumus(
  pradiniai_atstumai_A,
  as.vector(dist(tsne_A_3d$Y))
)

globali_2d <- globalus_rezultatai[
  globalus_rezultatai$sekla == 42,
  c("Spearman", "Normalizuotas_Stress")
]

dimensiju_globali_kokybe <- rbind(
  data.frame(dimensija = 2, globali_2d),
  data.frame(dimensija = 3, globali_3d)
)

print(dimensiju_lokali_kokybe, row.names = FALSE, digits = 6)
print(dimensiju_globali_kokybe, row.names = FALSE, digits = 6)

write.csv(
  dimensiju_lokali_kokybe,
  "rezultatai/tsne_A_2d_3d_lokali_kokybe.csv",
  row.names = FALSE
)

write.csv(
  dimensiju_globali_kokybe,
  "rezultatai/tsne_A_2d_3d_globali_kokybe.csv",
  row.names = FALSE
)

# Jei paketai dar neįdiegti, vieną kartą paleisk:
# install.packages(c("plotly", "htmlwidgets"))

grafikas_3d <- plotly::plot_ly(
  data = tsne_3d_A,
  x = ~TSNE1,
  y = ~TSNE2,
  z = ~TSNE3,
  color = ~class,
  type = "scatter3d",
  mode = "markers",
  marker = list(size = 2, opacity = 0.65)
)

grafikas_3d <- plotly::layout(
  grafikas_3d,
  title = "A aibės 3D t-SNE: perplexity = 30, sėkla = 42",
  scene = list(
    xaxis = list(title = "t-SNE 1"),
    yaxis = list(title = "t-SNE 2"),
    zaxis = list(title = "t-SNE 3")
  )
)

grafikas_3d

dir.create("grafikai", showWarnings = FALSE)

htmlwidgets::saveWidget(
  grafikas_3d,
  "grafikai/tsne_A_3d.html",
  selfcontained = TRUE
)