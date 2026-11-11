
# =====================================================
# 3 DARBAS. K-MEANS KLASTERIZAVIMAS
# 1 ETAPAS – OPTIMALAUS KLASTERIU SKAICIAUS PARINKIMAS
# =====================================================

# 1. Reikalingi paketai

paketai <- c("cluster", "ggplot2")

for (pkg in paketai) {
  # Įdiegiame paketą, jeigu jo dar nėra
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}

# 2. Originalios C aibės nuskaitymas

duomenys <- read.csv("aibes/aibe_originali.csv")

# Klasterizavimui naudojame tik skaitinius požymius.
# ID ir class neįtraukiame.
X <- as.matrix(
  duomenys[, !names(duomenys) %in% c("id", "class")]
)

# Patikriname duomenis
stopifnot(nrow(X) == 3928, ncol(X) == 19, !anyNA(X))

# 3. Parametrai

SEED <- 42
K_REIKSMES <- 2:10

# 4. Elbow metodo skaičiavimai

set.seed(SEED)

wss <- sapply(K_REIKSMES, function(k) {
  # nstart = 25 – algoritmas pradedamas iš
  # 25 skirtingų pradinių centrų
  modelis <- kmeans(X, centers = k, nstart = 25)
  
  # Klasterių vidinė kvadratinių nuokrypių suma
  modelis$tot.withinss
})

elbow_lentele <- data.frame(
  k = K_REIKSMES,
  WSS = wss
)

# 5. Elbow grafikas

grafikas_elbow <- ggplot(
  elbow_lentele,
  aes(x = k, y = WSS)
) +
  geom_line() +
  geom_point(size = 2) +
  scale_x_continuous(breaks = K_REIKSMES) +
  labs(
    title = "K-means: Elbow metodas",
    subtitle = "Originali C aibė (19D)",
    x = "Klasterių skaičius (k)",
    y = "WSS"
  ) +
  theme_minimal()

print(grafikas_elbow)

# 6. Silhouette metodo skaičiavimai

# Silhouette skaičiavimui reikalingi objektų atstumai.
atstumai <- dist(X)

set.seed(SEED)

sil_reiksmes <- sapply(K_REIKSMES, function(k) {
  modelis <- kmeans(X, centers = k, nstart = 25)
  
  # Apskaičiuojame kiekvieno objekto siluetą
  sil <- silhouette(modelis$cluster, atstumai)
  
  # Grąžiname vidutinį silueto koeficientą
  mean(sil[, "sil_width"])
})

sil_lentele <- data.frame(
  k = K_REIKSMES,
  silhouette = sil_reiksmes
)

# 7. Silhouette grafikas

grafikas_sil <- ggplot(
  sil_lentele,
  aes(x = k, y = silhouette)
) +
  geom_line() +
  geom_point(size = 2) +
  scale_x_continuous(breaks = K_REIKSMES) +
  labs(
    title = "K-means: Silhouette metodas",
    subtitle = "Originali C aibė (19D)",
    x = "Klasterių skaičius (k)",
    y = "Vidutinis silueto koeficientas"
  ) +
  theme_minimal()

print(grafikas_sil)

# 8. Rezultatų lentelė

rezultatai <- merge(
  elbow_lentele,
  sil_lentele,
  by = "k"
)

print(rezultatai)

cat(
  "\nDidziausias Silhouette, kai k =",
  rezultatai$k[which.max(rezultatai$silhouette)],
  "\n"
)

# 9. Grafikų ir rezultatų išsaugojimas

dir.create("grafikai", showWarnings = FALSE)
dir.create("rezultatai", showWarnings = FALSE)

ggsave(
  "grafikai/kmeans_elbow_originali.png",
  grafikas_elbow,
  width = 8,
  height = 5,
  dpi = 300
)

ggsave(
  "grafikai/kmeans_silhouette_originali.png",
  grafikas_sil,
  width = 8,
  height = 5,
  dpi = 300
)

write.csv(
  rezultatai,
  "rezultatai/kmeans_parametrai_originali.csv",
  row.names = FALSE
)

# =====================================================
# 10. K-MEANS EKSPERIMENTU REGISTRAVIMAS
# Originali C aibe (19D)
# =====================================================

# 10.1. Eksperimentu parametrai
# Tikriname skirtingus k, nstart ir seed derinius

eksperimentai <- data.frame(
  k = c(2, 3, 4, 5, 2, 2),
  nstart = c(25, 25, 25, 25, 10, 25),
  seed = c(42, 42, 42, 42, 42, 123)
)

# 10.2. Funkcija vienam eksperimentui

vykdyti_eksperimenta <- function(k, nstart, seed) {
  
  # Užfiksuojame atsitiktinę sėklą
  set.seed(seed)
  
  # Atliekame K-means klasterizavimą
  modelis <- kmeans(
    X,
    centers = k,
    nstart = nstart
  )
  
  # Apskaičiuojame vidutinį silueto koeficientą
  sil <- silhouette(modelis$cluster, atstumai)
  vid_sil <- mean(sil[, "sil_width"])
  
  # Grąžiname eksperimento rezultatus
  data.frame(
    aibe = "Originali C",
    dimensija = ncol(X),
    k = k,
    nstart = nstart,
    seed = seed,
    WSS = modelis$tot.withinss,
    silhouette = vid_sil,
    klasteriu_dydziai = paste(modelis$size, collapse = ";")
  )
}

# 10.3. Vykdome visus eksperimentus

rez_eksperimentai <- do.call(
  rbind,
  lapply(seq_len(nrow(eksperimentai)), function(i) {
    vykdyti_eksperimenta(
      eksperimentai$k[i],
      eksperimentai$nstart[i],
      eksperimentai$seed[i]
    )
  })
)

# 10.4. Parodome rezultatus

print(rez_eksperimentai)

# 10.5. Išsaugome eksperimentų lentelę

dir.create("rezultatai", showWarnings = FALSE)

write.csv(
  rez_eksperimentai,
  "rezultatai/kmeans_eksperimentai_originali.csv",
  row.names = FALSE
)

cat("\nK-means eksperimentu lentele issaugota!\n")


# =====================================================
# 11. K-MEANS KLASTERIZAVIMAS ORIGINALIOJE C AIBEJE
# =====================================================

# 11.1. Pasirenkame parametrus
K_OPT <- 2
NSTART_OPT <- 25
SEED_OPT <- 42

# 11.2. Atliekame K-means klasterizavima
set.seed(SEED_OPT)

modelis_opt <- kmeans(
  X,
  centers = K_OPT,
  nstart = NSTART_OPT
)

# 11.3. Priskiriame kiekvienam objektui klasteri
klasterizuoti_duomenys <- duomenys
klasterizuoti_duomenys$klasteris <- modelis_opt$cluster

# 11.4. Patikriname klasteriu dydzius
cat("\nKlasteriu dydziai:\n")
print(table(klasterizuoti_duomenys$klasteris))

# 11.5. Palyginame klasterius su tikrosiomis klasemis
# Ideal ir Premium klases nebuvo naudojamos klasterizavimui

klasiu_lentele <- table(
  Klasteris = klasterizuoti_duomenys$klasteris,
  Klase = klasterizuoti_duomenys$class
)

cat("\nKlasteriu sudetis pagal klases:\n")
print(klasiu_lentele)

# 11.6. Apskaiciuojame klasiu proporcijas klasteriuose
klasiu_procentai <- round(
  prop.table(klasiu_lentele, margin = 1) * 100,
  2
)

cat("\nKlasiu proporcijos (%):\n")
print(klasiu_procentai)

# 11.7. Issaugome klasterizavimo rezultatus
dir.create("rezultatai", showWarnings = FALSE)

write.csv(
  klasterizuoti_duomenys,
  "rezultatai/kmeans_originali_klasteriai.csv",
  row.names = FALSE
)

write.csv(
  as.data.frame.matrix(klasiu_lentele),
  "rezultatai/kmeans_originali_klasiu_sudetis.csv"
)

write.csv(
  as.data.frame.matrix(klasiu_procentai),
  "rezultatai/kmeans_originali_klasiu_procentai.csv"
)

# =====================================================
# 12. KLASTERIU INTERPRETAVIMAS PAGAL ORIGINALIUS POZYMIUS
# =====================================================

# 12.1. Nuskaitome duomenis originaliais matavimo vienetais
originalus <- read.csv(
  "aibes/C_originaliais_vienetais_interpretacijai.csv"
)

# 12.2. Sujungiame originalius duomenis su K-means klasteriais
# Jungimui naudojame ID, kad objektai nesusimaišytų
originalus$klasteris <- klasterizuoti_duomenys$klasteris[
  match(originalus$id, klasterizuoti_duomenys$id)
]

stopifnot(!anyNA(originalus$klasteris))

# 12.3. Palyginame pagrindinių požymių medianas
# Mediana mažiau jautri didelėms reikšmėms nei vidurkis
pozymiai_interpretacijai <- c(
  "carat", "price", "depth", "table",
  "x", "y", "z", "volume_xyz", "price_per_carat"
)

medianu_lentele <- aggregate(
  originalus[, pozymiai_interpretacijai],
  by = list(klasteris = originalus$klasteris),
  FUN = median
)

cat("\nKlasteriu pozymiu medianos:\n")
print(medianu_lentele)

# =====================================================
# 13. K-MEANS KLASTERIZAVIMO KOKYBES VERTINIMAS
# =====================================================

# 13.1. Reikalingas paketas
if (!requireNamespace("clusterCrit", quietly = TRUE)) {
  install.packages("clusterCrit")
}

library(clusterCrit)

# 13.2. Apskaičiuojame kokybės rodiklius
# Naudojame originalią normuotą C aibę (19D)
# ir anksčiau gautus K-means klasterius

kokybe <- intCriteria(
  traj = X,
  part = as.integer(modelis_opt$cluster),
  crit = c("Calinski_Harabasz", "Davies_Bouldin")
)

# 13.3. Išvedame rezultatus
cat("\nK-means klasterizavimo kokybės rodikliai:\n")
cat("Calinski-Harabasz:", kokybe$calinski_harabasz, "\n")
cat("Davies-Bouldin:", kokybe$davies_bouldin, "\n")

# 13.4. Sukuriame rezultatų lentelę
kokybes_lentele <- data.frame(
  aibe = "Originali C",
  dimensija = ncol(X),
  algoritmas = "K-means",
  k = K_OPT,
  nstart = NSTART_OPT,
  seed = SEED_OPT,
  silhouette = mean(
    cluster::silhouette(modelis_opt$cluster, atstumai)[, "sil_width"]
  ),
  calinski_harabasz = kokybe$calinski_harabasz,
  davies_bouldin = kokybe$davies_bouldin
)

print(kokybes_lentele)

# 13.5. Išsaugome rezultatų lentelę
write.csv(
  kokybes_lentele,
  "rezultatai/kmeans_kokybe_originali.csv",
  row.names = FALSE
)

# =====================================================
# 14. K-MEANS KLASTERIU VIZUALIZAVIMAS
# ORIGINALI C AIBE (19D)
# =====================================================

# 14.1. PCA taikome tik vizualizacijai
# Pats K-means jau atliktas originalioje 19D erdveje

pca_viz <- prcomp(
  X,
  center = TRUE,
  scale. = FALSE
)

# 14.2. Paruosiame grafiko duomenis
# PC1 ir PC2 - pirmos dvi pagrindines komponentes
# Klasteriu numeriai paimami is 19D K-means rezultato

grafiko_duomenys <- data.frame(
  PC1 = pca_viz$x[, 1],
  PC2 = pca_viz$x[, 2],
  klasteris = factor(modelis_opt$cluster)
)

# 14.3. Nubraizome klasterius

grafikas_klasteriai <- ggplot(
  grafiko_duomenys,
  aes(x = PC1, y = PC2, color = klasteris)
) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "K-means klasteriai originalioje C aibeje",
    subtitle = "Klasterizavimas 19D, vizualizacija PCA 2D",
    x = "PC1",
    y = "PC2",
    color = "Klasteris"
  ) +
  theme_minimal()

print(grafikas_klasteriai)

# 14.4. Issaugome grafika

dir.create("grafikai", showWarnings = FALSE)

ggsave(
  "grafikai/kmeans_klasteriai_originali.png",
  plot = grafikas_klasteriai,
  width = 8,
  height = 5,
  dpi = 300
)


# =====================================================
# 15. K-MEANS KLASTERIU VIZUALIZAVIMAS t-SNE 2D
# ORIGINALI C AIBE (19D)
# =====================================================

# 15.1. Nuskaitome jau apskaiciuotas t-SNE koordinates
tsne_duomenys <- read.csv("aibes/aibe_tSNE_2D.csv")

# 15.2. Susiejame t-SNE koordinates su originaliais objektais
# Naudojame ID, kad objektai butu teisingai suporuoti
indeksai <- match(duomenys$id, tsne_duomenys$id)

# Patikriname, ar visi objektai rasti
stopifnot(!anyNA(indeksai))

# 15.3. Paruosiame duomenis grafikui
# Klasteriu numeriai paimti is originalios 19D aibes K-means
grafiko_duomenys_tsne <- data.frame(
  TSNE1 = tsne_duomenys$TSNE1[indeksai],
  TSNE2 = tsne_duomenys$TSNE2[indeksai],
  klasteris = factor(modelis_opt$cluster)
)

# 15.4. Braizome t-SNE 2D grafika
grafikas_tsne <- ggplot(
  grafiko_duomenys_tsne,
  aes(x = TSNE1, y = TSNE2, color = klasteris)
) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "K-means klasteriai originalioje C aibeje",
    subtitle = "Klasterizavimas 19D, vizualizacija t-SNE 2D",
    x = "t-SNE 1",
    y = "t-SNE 2",
    color = "Klasteris"
  ) +
  theme_minimal()

print(grafikas_tsne)

# 15.5. Issaugome grafika
dir.create("grafikai", showWarnings = FALSE)

ggsave(
  "grafikai/kmeans_klasteriai_originali_tsne.png",
  plot = grafikas_tsne,
  width = 8,
  height = 5,
  dpi = 300
)

# =====================================================
# 16. K-MEANS KLASTERIU POZYMIU IR KLASIU VIZUALIZAVIMAS
# ORIGINALI C AIBE (19D)
# =====================================================

# 16.1. Paruosiame originalius duomenis grafikams
# Naudojame originalius matavimo vienetus,
# o klasteriu numerius imame is K-means 19D rezultato.

originalus <- read.csv(
  "aibes/C_originaliais_vienetais_interpretacijai.csv"
)

# Susiejame objektus pagal ID
indeksai <- match(
  originalus$id,
  klasterizuoti_duomenys$id
)

stopifnot(!anyNA(indeksai))

originalus$klasteris <- factor(
  klasterizuoti_duomenys$klasteris[indeksai]
)


# 16.2. Boxplot - deimantu svoris (carat)

grafikas_carat <- ggplot(
  originalus,
  aes(x = klasteris, y = carat, fill = klasteris)
) +
  geom_boxplot(
    alpha = 0.7,
    outlier.alpha = 0.3
  ) +
  labs(
    title = "Deimantu svorio pasiskirstymas pagal klasterius",
    subtitle = "K-means originalioje C aibeje (19D)",
    x = "Klasteris",
    y = "Svoris (karatai)"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

print(grafikas_carat)


# 16.3. Boxplot - deimantu kaina (price)

grafikas_price <- ggplot(
  originalus,
  aes(x = klasteris, y = price, fill = klasteris)
) +
  geom_boxplot(
    alpha = 0.7,
    outlier.alpha = 0.3
  ) +
  labs(
    title = "Deimantu kainos pasiskirstymas pagal klasterius",
    subtitle = "K-means originalioje C aibeje (19D)",
    x = "Klasteris",
    y = "Kaina"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

print(grafikas_price)


# 16.4. Klasiu proporciju apskaiciavimas
# Kiekviename klasteryje suskaiciuojame,
# kokia dali sudaro Ideal ir Premium deimantai.

klasiu_duomenys <- as.data.frame(
  table(
    klasteris = originalus$klasteris,
    klase = originalus$class
  )
)

# Apskaiciuojame proporcijas kiekviename klasteryje
klasiu_duomenys <- klasiu_duomenys |>
  dplyr::group_by(klasteris) |>
  dplyr::mutate(
    procentai = Freq / sum(Freq) * 100
  ) |>
  dplyr::ungroup()


# 16.5. Klasiu proporciju grafikas

grafikas_klases <- ggplot(
  klasiu_duomenys,
  aes(
    x = klasteris,
    y = procentai,
    fill = klase
  )
) +
  geom_col(width = 0.6) +
  geom_text(
    aes(label = paste0(round(procentai, 1), "%")),
    position = position_stack(vjust = 0.5),
    size = 4
  ) +
  scale_y_continuous(
    limits = c(0, 100),
    expand = c(0, 0)
  ) +
  labs(
    title = "Ideal ir Premium klasiu proporcijos",
    subtitle = "K-means originalioje C aibeje (19D)",
    x = "Klasteris",
    y = "Procentai (%)",
    fill = "Klase"
  ) +
  theme_minimal()

print(grafikas_klases)


# 16.6. Issaugome visus tris grafikus

dir.create("grafikai", showWarnings = FALSE)

ggsave(
  "grafikai/kmeans_boxplot_carat.png",
  grafikas_carat,
  width = 7,
  height = 5,
  dpi = 300
)

ggsave(
  "grafikai/kmeans_boxplot_price.png",
  grafikas_price,
  width = 7,
  height = 5,
  dpi = 300
)

ggsave(
  "grafikai/kmeans_klasiu_proporcijos.png",
  grafikas_klases,
  width = 7,
  height = 5,
  dpi = 300
)

cat("\n16 skyrius baigtas: issaugoti 3 grafikai.\n")

# =====================================================
# 17. K-MEANS PARAMETRU PARINKIMAS PCA 5D AIBEJE
# =====================================================

# 17.1. Nuskaitome PCA aibe
pca_duomenys <- read.csv("aibes/aibe_PCA.csv")

# Patikriname, ar objektu ID sutampa
indeksai_pca <- match(duomenys$id, pca_duomenys$id)
stopifnot(!anyNA(indeksai_pca))

# Pasirenkame tik PCA komponentes
X_pca <- as.matrix(
  pca_duomenys[
    indeksai_pca,
    !names(pca_duomenys) %in% c("id", "class")
  ]
)

cat("PCA aibes matmenys:", dim(X_pca), "\n")

# 17.2. Apskaiciuojame Elbow rodikli
k_reiksmes_pca <- 2:10

set.seed(42)

wss_pca <- sapply(k_reiksmes_pca, function(k) {
  modelis <- kmeans(X_pca, centers = k, nstart = 25)
  modelis$tot.withinss
})

# 17.3. Apskaiciuojame vidutini Silhouette
atstumai_pca <- dist(X_pca)

set.seed(42)

sil_pca <- sapply(k_reiksmes_pca, function(k) {
  modelis <- kmeans(X_pca, centers = k, nstart = 25)
  sil <- cluster::silhouette(modelis$cluster, atstumai_pca)
  mean(sil[, "sil_width"])
})

# 17.4. Sukuriame rezultatu lentele
rezultatai_pca <- data.frame(
  k = k_reiksmes_pca,
  WSS = wss_pca,
  silhouette = sil_pca
)

print(rezultatai_pca)

cat(
  "Didziausias PCA Silhouette, kai k =",
  rezultatai_pca$k[which.max(rezultatai_pca$silhouette)],
  "\n"
)

# 17.5. Elbow grafikas
grafikas_elbow_pca <- ggplot(
  rezultatai_pca,
  aes(x = k, y = WSS)
) +
  geom_line() +
  geom_point(size = 2) +
  scale_x_continuous(breaks = k_reiksmes_pca) +
  labs(
    title = "K-means: Elbow metodas",
    subtitle = "PCA 5D aibe",
    x = "Klasteriu skaicius (k)",
    y = "WSS"
  ) +
  theme_minimal()

print(grafikas_elbow_pca)

# 17.6. Silhouette grafikas
grafikas_sil_pca <- ggplot(
  rezultatai_pca,
  aes(x = k, y = silhouette)
) +
  geom_line() +
  geom_point(size = 2) +
  scale_x_continuous(breaks = k_reiksmes_pca) +
  labs(
    title = "K-means: Silhouette metodas",
    subtitle = "PCA 5D aibe",
    x = "Klasteriu skaicius (k)",
    y = "Vidutinis silueto koeficientas"
  ) +
  theme_minimal()

print(grafikas_sil_pca)

# 17.7. Issaugome rezultatus
ggsave(
  "grafikai/kmeans_elbow_pca.png",
  grafikas_elbow_pca,
  width = 8,
  height = 5,
  dpi = 300
)

ggsave(
  "grafikai/kmeans_silhouette_pca.png",
  grafikas_sil_pca,
  width = 8,
  height = 5,
  dpi = 300
)

write.csv(
  rezultatai_pca,
  "rezultatai/kmeans_parametrai_pca.csv",
  row.names = FALSE
)

# =====================================================
# 18. K-MEANS EKSPERIMENTAI PCA 5D AIBEJE
# =====================================================

# 18.1. Parenkame parametrų derinius
eksperimentai_pca <- data.frame(
  k = c(2, 3, 4, 5, 2, 2),
  nstart = c(25, 25, 25, 25, 10, 25),
  seed = c(42, 42, 42, 42, 42, 123)
)

# 18.2. Funkcija vienam PCA eksperimentui
vykdyti_pca_eksperimenta <- function(k, nstart, seed) {
  
  # Užfiksuojame atsitiktinę sėklą
  set.seed(seed)
  
  # K-means taikome PCA 5D aibei
  modelis <- kmeans(
    X_pca,
    centers = k,
    nstart = nstart
  )
  
  # Apskaičiuojame vidutinį Silhouette
  sil <- cluster::silhouette(
    modelis$cluster,
    atstumai_pca
  )
  
  # Grąžiname eksperimento rezultatus
  data.frame(
    aibe = "PCA 5D",
    dimensija = ncol(X_pca),
    k = k,
    nstart = nstart,
    seed = seed,
    WSS = modelis$tot.withinss,
    silhouette = mean(sil[, "sil_width"]),
    klasteriu_dydziai = paste(modelis$size, collapse = ";")
  )
}

# 18.3. Vykdome visus bandymus
rez_eksperimentai_pca <- do.call(
  rbind,
  lapply(seq_len(nrow(eksperimentai_pca)), function(i) {
    vykdyti_pca_eksperimenta(
      eksperimentai_pca$k[i],
      eksperimentai_pca$nstart[i],
      eksperimentai_pca$seed[i]
    )
  })
)

# 18.4. Parodome rezultatus
print(rez_eksperimentai_pca)

# 18.5. Išsaugome eksperimentų lentelę
dir.create("rezultatai", showWarnings = FALSE)

write.csv(
  rez_eksperimentai_pca,
  "rezultatai/kmeans_eksperimentai_pca.csv",
  row.names = FALSE
)

# =====================================================
# 19. K-MEANS KLASTERIZAVIMAS PCA 5D AIBEJE
# =====================================================

# 19.1. Pasirenkame parametrus
K_PCA <- 2
NSTART_PCA <- 25
SEED_PCA <- 42

# 19.2. Atliekame K-means PCA 5D erdveje
set.seed(SEED_PCA)

modelis_pca <- kmeans(
  X_pca,
  centers = K_PCA,
  nstart = NSTART_PCA
)

# 19.3. Priskiriame kiekvienam objektui klasteri
# X_pca eilutes jau suderintos su originalios C aibes ID
klasterizuoti_pca <- pca_duomenys[indeksai_pca, ]

klasterizuoti_pca$klasteris <- modelis_pca$cluster

# 19.4. Patikriname klasteriu dydzius
cat("\nPCA 5D klasteriu dydziai:\n")
print(table(klasterizuoti_pca$klasteris))

# 19.5. Klasteriu sudetis pagal Ideal ir Premium
klasiu_lentele_pca <- table(
  Klasteris = klasterizuoti_pca$klasteris,
  Klase = klasterizuoti_pca$class
)

cat("\nPCA 5D klasteriu sudetis pagal klases:\n")
print(klasiu_lentele_pca)

# 19.6. Apskaiciuojame klasiu proporcijas
klasiu_procentai_pca <- round(
  prop.table(klasiu_lentele_pca, margin = 1) * 100,
  2
)

cat("\nPCA 5D klasiu proporcijos (%):\n")
print(klasiu_procentai_pca)

# 19.7. Issaugome klasterizavimo rezultatus
dir.create("rezultatai", showWarnings = FALSE)

write.csv(
  klasterizuoti_pca,
  "rezultatai/kmeans_pca_klasteriai.csv",
  row.names = FALSE
)

# =====================================================
# 20. K-MEANS KLASTERIZAVIMO KOKYBE PCA 5D AIBEJE
# =====================================================

# 20.1. Apskaiciuojame tris vidinius kokybes rodiklius
# Naudojame PCA 5D koordinates, nes sioje erdveje
# buvo atliktas klasterizavimas.

kokybe_pca <- clusterCrit::intCriteria(
  traj = X_pca,
  part = as.integer(modelis_pca$cluster),
  crit = c("Calinski_Harabasz", "Davies_Bouldin")
)

# 20.2. Apskaiciuojame vidutini silueto koeficienta
silhouette_pca <- mean(
  cluster::silhouette(
    modelis_pca$cluster,
    atstumai_pca
  )[, "sil_width"]
)

# 20.3. Sudarome rezultatu lentele
kokybes_lentele_pca <- data.frame(
  aibe = "PCA 5D",
  dimensija = ncol(X_pca),
  algoritmas = "K-means",
  k = K_PCA,
  nstart = NSTART_PCA,
  seed = SEED_PCA,
  silhouette = silhouette_pca,
  calinski_harabasz = kokybe_pca$calinski_harabasz,
  davies_bouldin = kokybe_pca$davies_bouldin
)

# 20.4. Parodome rezultatus
cat("\nPCA 5D klasterizavimo kokybes rodikliai:\n")
print(kokybes_lentele_pca)

# 20.5. Issaugome rezultatus
write.csv(
  kokybes_lentele_pca,
  "rezultatai/kmeans_kokybe_pca.csv",
  row.names = FALSE
)

# =====================================================
# 21. K-MEANS KLASTERIU VIZUALIZACIJA PCA 5D AIBEJE
# =====================================================

# 21.1. Paruosiame duomenis grafikui
# Klasteriai gauti PCA 5D erdveje, o vaizduojami PC1 ir PC2.

grafiko_duomenys_pca <- data.frame(
  PC1 = X_pca[, 1],
  PC2 = X_pca[, 2],
  klasteris = factor(modelis_pca$cluster)
)

# 21.2. Nubraizome grafika
grafikas_klasteriai_pca <- ggplot(
  grafiko_duomenys_pca,
  aes(x = PC1, y = PC2, color = klasteris)
) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "K-means klasteriai PCA 5D aibeje",
    subtitle = "Klasterizavimas PCA 5D, vizualizacija PCA 2D",
    x = "PC1",
    y = "PC2",
    color = "Klasteris"
  ) +
  theme_minimal()

print(grafikas_klasteriai_pca)

# 21.3. Issaugome grafika
dir.create("grafikai", showWarnings = FALSE)

ggsave(
  "grafikai/kmeans_klasteriai_pca.png",
  plot = grafikas_klasteriai_pca,
  width = 8,
  height = 5,
  dpi = 300
)

# =====================================================
# 22. PCA 5D K-MEANS KLASTERIU VIZUALIZAVIMAS t-SNE 2D
# =====================================================

# 22.1. Nuskaitome t-SNE 2D koordinates
tsne_duomenys <- read.csv("aibes/aibe_tSNE_2D.csv")

# 22.2. Suderiname objektus pagal ID
indeksai_tsne_pca <- match(
  klasterizuoti_pca$id,
  tsne_duomenys$id
)

stopifnot(!anyNA(indeksai_tsne_pca))

# 22.3. Paruosiame duomenis grafikui
# Klasteriu numeriai gauti PCA 5D erdveje,
# t-SNE naudojame tik vaizdavimui.

grafiko_duomenys_pca_tsne <- data.frame(
  TSNE1 = tsne_duomenys$TSNE1[indeksai_tsne_pca],
  TSNE2 = tsne_duomenys$TSNE2[indeksai_tsne_pca],
  klasteris = factor(klasterizuoti_pca$klasteris)
)

# 22.4. Braizome grafika
grafikas_pca_tsne <- ggplot(
  grafiko_duomenys_pca_tsne,
  aes(x = TSNE1, y = TSNE2, color = klasteris)
) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "K-means klasteriai PCA 5D aibeje",
    subtitle = "Klasterizavimas PCA 5D, vizualizacija t-SNE 2D",
    x = "t-SNE 1",
    y = "t-SNE 2",
    color = "Klasteris"
  ) +
  theme_minimal()

print(grafikas_pca_tsne)

# 22.5. Issaugome grafika
ggsave(
  "grafikai/kmeans_klasteriai_pca_tsne.png",
  plot = grafikas_pca_tsne,
  width = 8,
  height = 5,
  dpi = 300
)


# =====================================================
# 23. PCA 5D K-MEANS KLASTERIU POZYMIU IR KLASIU VIZUALIZAVIMAS
# =====================================================

# 23.1. Paruosiame originalius duomenis
# Naudojame originalius deimantu pozymius, o klasteriu
# numerius paimame is PCA 5D K-means rezultatu.

originalus_pca <- read.csv(
  "aibes/C_originaliais_vienetais_interpretacijai.csv"
)

# Suderiname objektus pagal ID, kad nesusimaisytu eilutes
indeksai_originalus_pca <- match(
  originalus_pca$id,
  klasterizuoti_pca$id
)

# Patikriname, ar visi objektai rasti
stopifnot(!anyNA(indeksai_originalus_pca))

# Priskiriame PCA 5D klasteriu numerius
originalus_pca$klasteris <- factor(
  klasterizuoti_pca$klasteris[indeksai_originalus_pca],
  levels = c(1, 2)
)


# 23.2. Deimantu svorio (carat) boxplot

grafikas_carat_pca <- ggplot(
  originalus_pca,
  aes(x = klasteris, y = carat, fill = klasteris)
) +
  geom_boxplot(
    alpha = 0.7,
    outlier.alpha = 0.3
  ) +
  labs(
    title = "Deimantu svorio pasiskirstymas pagal klasterius",
    subtitle = "K-means PCA 5D aibeje",
    x = "Klasteris",
    y = "Svoris (karatai)"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

print(grafikas_carat_pca)


# 23.3. Deimantu kainos (price) boxplot

grafikas_price_pca <- ggplot(
  originalus_pca,
  aes(x = klasteris, y = price, fill = klasteris)
) +
  geom_boxplot(
    alpha = 0.7,
    outlier.alpha = 0.3
  ) +
  labs(
    title = "Deimantu kainos pasiskirstymas pagal klasterius",
    subtitle = "K-means PCA 5D aibeje",
    x = "Klasteris",
    y = "Kaina"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

print(grafikas_price_pca)


# 23.4. Ideal ir Premium klasiu proporciju skaiciavimas

# Suskaiciuojame klasiu objektus kiekviename klasteryje
klasiu_duomenys_pca <- as.data.frame(
  table(
    klasteris = originalus_pca$klasteris,
    klase = originalus_pca$class
  )
)

# Apskaiciuojame procentines klasiu dalis klasteriuose
klasiu_duomenys_pca <- klasiu_duomenys_pca |>
  dplyr::group_by(klasteris) |>
  dplyr::mutate(
    procentai = Freq / sum(Freq) * 100
  ) |>
  dplyr::ungroup()

cat("\nPCA 5D klasiu proporcijos:\n")
print(klasiu_duomenys_pca)


# 23.5. Klasiu proporciju grafikas

grafikas_klases_pca <- ggplot(
  klasiu_duomenys_pca,
  aes(
    x = klasteris,
    y = procentai,
    fill = klase
  )
) +
  geom_col(width = 0.6) +
  geom_text(
    aes(label = paste0(round(procentai, 1), "%")),
    position = position_stack(vjust = 0.5),
    size = 4
  ) +
  scale_y_continuous(
    limits = c(0, 100),
    expand = c(0, 0)
  ) +
  labs(
    title = "Ideal ir Premium klasiu proporcijos",
    subtitle = "K-means PCA 5D aibeje",
    x = "Klasteris",
    y = "Procentai (%)",
    fill = "Klase"
  ) +
  theme_minimal()

print(grafikas_klases_pca)


# 23.6. Issaugome visus tris grafikus

dir.create("grafikai", showWarnings = FALSE)

ggsave(
  "grafikai/kmeans_boxplot_carat_pca.png",
  plot = grafikas_carat_pca,
  width = 7,
  height = 5,
  dpi = 300
)

ggsave(
  "grafikai/kmeans_boxplot_price_pca.png",
  plot = grafikas_price_pca,
  width = 7,
  height = 5,
  dpi = 300
)

ggsave(
  "grafikai/kmeans_klasiu_proporcijos_pca.png",
  plot = grafikas_klases_pca,
  width = 7,
  height = 5,
  dpi = 300
)


# 23.7. Apskaiciuojame klasteriu pozymiu medianas

# Palyginame tipinius deimantu svorius ir kainas
medianu_lentele_pca <- aggregate(
  originalus_pca[, c(
    "carat",
    "price",
    "volume_xyz",
    "price_per_carat"
  )],
  by = list(klasteris = originalus_pca$klasteris),
  FUN = median
)

cat("\nPCA 5D klasteriu pozymiu medianos:\n")
print(medianu_lentele_pca)

# Issaugome medianu lentele
dir.create("rezultatai", showWarnings = FALSE)

write.csv(
  medianu_lentele_pca,
  "rezultatai/kmeans_pca_klasteriu_medianos.csv",
  row.names = FALSE
)

cat("\n23 skyrius baigtas: sukurti 3 grafikai ir medianu lentele.\n")


# =====================================================
# 24. K-MEANS PARAMETRU PARINKIMAS t-SNE 2D AIBEJE
# =====================================================

# 24.1. Nuskaitome t-SNE 2D aibe
tsne_duomenys <- read.csv("aibes/aibe_tSNE_2D.csv")

# 24.2. Suderiname objektus pagal originalios aibes ID
indeksai_tsne <- match(duomenys$id, tsne_duomenys$id)

# Patikriname, ar visi objektai rasti
stopifnot(!anyNA(indeksai_tsne))

# 24.3. Pasirenkame tik t-SNE koordinates
# ID ir class nenaudojami klasterizavimui
X_tsne <- as.matrix(
  tsne_duomenys[indeksai_tsne, c("TSNE1", "TSNE2")]
)

cat("t-SNE aibes matmenys:", dim(X_tsne), "\n")

# 24.4. Nustatome tikrinamu k reiksmiu intervala
k_reiksmes_tsne <- 2:10

# 24.5. Apskaiciuojame Elbow WSS
wss_tsne <- sapply(k_reiksmes_tsne, function(k) {
  set.seed(42)
  modelis <- kmeans(
    X_tsne,
    centers = k,
    nstart = 25
  )
  modelis$tot.withinss
})

# 24.6. Apskaiciuojame vidutini Silhouette
atstumai_tsne <- dist(X_tsne)

sil_tsne <- sapply(k_reiksmes_tsne, function(k) {
  set.seed(42)
  modelis <- kmeans(
    X_tsne,
    centers = k,
    nstart = 25
  )
  
  sil <- cluster::silhouette(
    modelis$cluster,
    atstumai_tsne
  )
  
  mean(sil[, "sil_width"])
})

# 24.7. Sukuriame rezultatu lentele
rezultatai_tsne <- data.frame(
  k = k_reiksmes_tsne,
  WSS = wss_tsne,
  silhouette = sil_tsne
)

print(rezultatai_tsne)

cat(
  "\nDidziausias t-SNE Silhouette, kai k =",
  rezultatai_tsne$k[which.max(rezultatai_tsne$silhouette)],
  "\n"
)

# 24.8. Elbow grafikas
grafikas_elbow_tsne <- ggplot(
  rezultatai_tsne,
  aes(x = k, y = WSS)
) +
  geom_line() +
  geom_point(size = 2) +
  scale_x_continuous(breaks = k_reiksmes_tsne) +
  labs(
    title = "K-means: Elbow metodas",
    subtitle = "t-SNE 2D aibe",
    x = "Klasteriu skaicius (k)",
    y = "WSS"
  ) +
  theme_minimal()

print(grafikas_elbow_tsne)

# 24.9. Silhouette grafikas
grafikas_sil_tsne <- ggplot(
  rezultatai_tsne,
  aes(x = k, y = silhouette)
) +
  geom_line() +
  geom_point(size = 2) +
  scale_x_continuous(breaks = k_reiksmes_tsne) +
  labs(
    title = "K-means: Silhouette metodas",
    subtitle = "t-SNE 2D aibe",
    x = "Klasteriu skaicius (k)",
    y = "Vidutinis silueto koeficientas"
  ) +
  theme_minimal()

print(grafikas_sil_tsne)

# 24.10. Issaugome grafikus ir rezultatus
dir.create("grafikai", showWarnings = FALSE)
dir.create("rezultatai", showWarnings = FALSE)

ggsave(
  "grafikai/kmeans_elbow_tsne.png",
  plot = grafikas_elbow_tsne,
  width = 8,
  height = 5,
  dpi = 300
)

ggsave(
  "grafikai/kmeans_silhouette_tsne.png",
  plot = grafikas_sil_tsne,
  width = 8,
  height = 5,
  dpi = 300
)

write.csv(
  rezultatai_tsne,
  "rezultatai/kmeans_parametrai_tsne.csv",
  row.names = FALSE
)

# =====================================================
# 25. K-MEANS EKSPERIMENTAI t-SNE 2D AIBEJE
# =====================================================

# 25.1. Parenkame parametrų derinius
eksperimentai_tsne <- data.frame(
  k = c(2, 3, 4, 5, 2, 2),
  nstart = c(25, 25, 25, 25, 10, 25),
  seed = c(42, 42, 42, 42, 42, 123)
)

# 25.2. Funkcija vienam eksperimentui
vykdyti_tsne_eksperimenta <- function(k, nstart, seed) {
  
  # Užfiksuojame atsitiktinę sėklą
  set.seed(seed)
  
  # K-means atliekame t-SNE 2D erdvėje
  modelis <- kmeans(
    X_tsne,
    centers = k,
    nstart = nstart
  )
  
  # Apskaičiuojame vidutinį Silhouette
  sil <- cluster::silhouette(
    modelis$cluster,
    atstumai_tsne
  )
  
  # Grąžiname eksperimento rezultatus
  data.frame(
    aibe = "t-SNE 2D",
    dimensija = ncol(X_tsne),
    k = k,
    nstart = nstart,
    seed = seed,
    WSS = modelis$tot.withinss,
    silhouette = mean(sil[, "sil_width"]),
    klasteriu_dydziai = paste(modelis$size, collapse = ";")
  )
}

# 25.3. Vykdome visus eksperimentus
rez_eksperimentai_tsne <- do.call(
  rbind,
  lapply(seq_len(nrow(eksperimentai_tsne)), function(i) {
    vykdyti_tsne_eksperimenta(
      eksperimentai_tsne$k[i],
      eksperimentai_tsne$nstart[i],
      eksperimentai_tsne$seed[i]
    )
  })
)

# 25.4. Parodome eksperimentų lentelę
print(rez_eksperimentai_tsne)

# 25.5. Išsaugome rezultatus
dir.create("rezultatai", showWarnings = FALSE)

write.csv(
  rez_eksperimentai_tsne,
  "rezultatai/kmeans_eksperimentai_tsne.csv",
  row.names = FALSE
)

# =====================================================
# 26. K-MEANS KLASTERIZAVIMAS t-SNE 2D AIBEJE
# =====================================================

# 26.1. Pasirenkame parametrus
K_TSNE <- 2
NSTART_TSNE <- 25
SEED_TSNE <- 42

# 26.2. Atliekame K-means t-SNE 2D erdveje
set.seed(SEED_TSNE)

modelis_tsne <- kmeans(
  X_tsne,
  centers = K_TSNE,
  nstart = NSTART_TSNE
)

# 26.3. Priskiriame kiekvienam objektui klasteri
# t-SNE eilutes jau suderintos su originalios C aibes ID
klasterizuoti_tsne <- tsne_duomenys[indeksai_tsne, ]

klasterizuoti_tsne$klasteris <- modelis_tsne$cluster

# 26.4. Patikriname klasteriu dydzius
cat("\nt-SNE 2D klasteriu dydziai:\n")
print(table(klasterizuoti_tsne$klasteris))

# 26.5. Klasteriu sudetis pagal Ideal ir Premium
klasiu_lentele_tsne <- table(
  Klasteris = klasterizuoti_tsne$klasteris,
  Klase = klasterizuoti_tsne$class
)

cat("\nt-SNE 2D klasteriu sudetis pagal klases:\n")
print(klasiu_lentele_tsne)

# 26.6. Apskaiciuojame klasiu proporcijas
klasiu_procentai_tsne <- round(
  prop.table(klasiu_lentele_tsne, margin = 1) * 100,
  2
)

cat("\nt-SNE 2D klasiu proporcijos (%):\n")
print(klasiu_procentai_tsne)

# 26.7. Issaugome klasterizavimo rezultatus
dir.create("rezultatai", showWarnings = FALSE)

write.csv(
  klasterizuoti_tsne,
  "rezultatai/kmeans_tsne_klasteriai.csv",
  row.names = FALSE
)


# =====================================================
# 27. K-MEANS KLASTERIZAVIMO KOKYBE t-SNE 2D AIBEJE
# =====================================================

# 27.1. Apskaiciuojame Calinski-Harabasz ir Davies-Bouldin
# Naudojame t-SNE 2D koordinates, nes jose atliktas K-means

kokybe_tsne <- clusterCrit::intCriteria(
  traj = X_tsne,
  part = as.integer(modelis_tsne$cluster),
  crit = c("Calinski_Harabasz", "Davies_Bouldin")
)

# 27.2. Apskaiciuojame vidutini Silhouette
silhouette_tsne <- mean(
  cluster::silhouette(
    modelis_tsne$cluster,
    atstumai_tsne
  )[, "sil_width"]
)

# 27.3. Sudarome rezultatu lentele
kokybes_lentele_tsne <- data.frame(
  aibe = "t-SNE 2D",
  dimensija = ncol(X_tsne),
  algoritmas = "K-means",
  k = K_TSNE,
  nstart = NSTART_TSNE,
  seed = SEED_TSNE,
  silhouette = silhouette_tsne,
  calinski_harabasz = kokybe_tsne$calinski_harabasz,
  davies_bouldin = kokybe_tsne$davies_bouldin
)

# 27.4. Parodome rezultatus
cat("\nt-SNE 2D klasterizavimo kokybes rodikliai:\n")
print(kokybes_lentele_tsne)

# 27.5. Issaugome rezultatus
write.csv(
  kokybes_lentele_tsne,
  "rezultatai/kmeans_kokybe_tsne.csv",
  row.names = FALSE
)

# =====================================================
# 28. K-MEANS KLASTERIU VIZUALIZACIJA t-SNE 2D AIBEJE
# =====================================================

# 28.1. Paruosiame duomenis grafikui
# Naudojame t-SNE 2D koordinates ir toje pacioje
# erdveje gautus K-means klasteriu numerius.

grafiko_duomenys_tsne_kmeans <- data.frame(
  TSNE1 = X_tsne[, 1],
  TSNE2 = X_tsne[, 2],
  klasteris = factor(modelis_tsne$cluster)
)

# 28.2. Nubraizome K-means klasterius t-SNE erdveje

grafikas_klasteriai_tsne <- ggplot(
  grafiko_duomenys_tsne_kmeans,
  aes(x = TSNE1, y = TSNE2, color = klasteris)
) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "K-means klasteriai t-SNE 2D aibeje",
    subtitle = "Klasterizavimas ir vizualizacija t-SNE 2D",
    x = "t-SNE 1",
    y = "t-SNE 2",
    color = "Klasteris"
  ) +
  theme_minimal()

print(grafikas_klasteriai_tsne)

# 28.3. Issaugome grafika
dir.create("grafikai", showWarnings = FALSE)

ggsave(
  "grafikai/kmeans_klasteriai_tsne.png",
  plot = grafikas_klasteriai_tsne,
  width = 8,
  height = 5,
  dpi = 300
)

# =====================================================
# 29. t-SNE 2D K-MEANS KLASTERIU VIZUALIZACIJA PCA 2D
# =====================================================

# 29.1. Apskaiciuojame PCA 2D koordinates
# PCA taikome originaliai normuotai C aibei (19D).
# Klasterizavimo nekartojame - naudojame t-SNE 2D
# erdveje gautus K-means klasteriu priskyrimus.

pca_viz_tsne <- prcomp(
  X,
  center = TRUE,
  scale. = FALSE
)

# 29.2. Suderiname objektus pagal ID
# X eiluciu tvarka atitinka duomenys$id.

indeksai_pca_tsne <- match(
  duomenys$id,
  klasterizuoti_tsne$id
)

stopifnot(!anyNA(indeksai_pca_tsne))

# 29.3. Paruosiame grafiko duomenis
grafiko_duomenys_tsne_pca <- data.frame(
  PC1 = pca_viz_tsne$x[, 1],
  PC2 = pca_viz_tsne$x[, 2],
  klasteris = factor(
    klasterizuoti_tsne$klasteris[indeksai_pca_tsne]
  )
)

# 29.4. Nubraizome grafika
grafikas_tsne_pca <- ggplot(
  grafiko_duomenys_tsne_pca,
  aes(x = PC1, y = PC2, color = klasteris)
) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "K-means klasteriai t-SNE 2D aibeje",
    subtitle = "Klasterizavimas t-SNE 2D, vizualizacija PCA 2D",
    x = "PC1",
    y = "PC2",
    color = "Klasteris"
  ) +
  theme_minimal()

print(grafikas_tsne_pca)

# 29.5. Issaugome grafika
dir.create("grafikai", showWarnings = FALSE)

ggsave(
  "grafikai/kmeans_klasteriai_tsne_pca.png",
  plot = grafikas_tsne_pca,
  width = 8,
  height = 5,
  dpi = 300
)

# =====================================================
# 30. t-SNE 2D K-MEANS KLASTERIU POZYMIU IR KLASIU ANALIZE
# =====================================================

# 30.1. Nuskaitome originalius deimantu duomenis
# Originalius pozymius naudojame klasteriu interpretacijai,
# nes t-SNE koordinates neturi tiesiogines fizines reiksmes.

originalus_tsne <- read.csv(
  "aibes/C_originaliais_vienetais_interpretacijai.csv"
)

# Suderiname objektus pagal ID
indeksai_originalus_tsne <- match(
  originalus_tsne$id,
  klasterizuoti_tsne$id
)

stopifnot(!anyNA(indeksai_originalus_tsne))

# Priskiriame t-SNE 2D erdveje gautus K-means klasterius
originalus_tsne$klasteris <- factor(
  klasterizuoti_tsne$klasteris[indeksai_originalus_tsne]
)


# 30.2. Deimantu svorio (carat) boxplot

grafikas_carat_tsne <- ggplot(
  originalus_tsne,
  aes(x = klasteris, y = carat, fill = klasteris)
) +
  geom_boxplot(
    alpha = 0.7,
    outlier.alpha = 0.3
  ) +
  labs(
    title = "Deimantu svorio pasiskirstymas pagal klasterius",
    subtitle = "K-means t-SNE 2D aibeje",
    x = "Klasteris",
    y = "Svoris (karatai)"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

print(grafikas_carat_tsne)


# 30.3. Deimantu kainos (price) boxplot

grafikas_price_tsne <- ggplot(
  originalus_tsne,
  aes(x = klasteris, y = price, fill = klasteris)
) +
  geom_boxplot(
    alpha = 0.7,
    outlier.alpha = 0.3
  ) +
  labs(
    title = "Deimantu kainos pasiskirstymas pagal klasterius",
    subtitle = "K-means t-SNE 2D aibeje",
    x = "Klasteris",
    y = "Kaina"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

print(grafikas_price_tsne)


# 30.4. Ideal ir Premium klasiu proporcijos

# Suskaiciuojame kiekvienos klases objektu skaiciu
klasiu_duomenys_tsne <- as.data.frame(
  table(
    klasteris = originalus_tsne$klasteris,
    klase = originalus_tsne$class
  )
)

# Apskaiciuojame procentus kiekviename klasteryje
klasiu_duomenys_tsne <- klasiu_duomenys_tsne |>
  dplyr::group_by(klasteris) |>
  dplyr::mutate(
    procentai = Freq / sum(Freq) * 100
  ) |>
  dplyr::ungroup()


# 30.5. Klasiu proporciju grafikas

grafikas_klases_tsne <- ggplot(
  klasiu_duomenys_tsne,
  aes(
    x = klasteris,
    y = procentai,
    fill = klase
  )
) +
  geom_col(width = 0.6) +
  geom_text(
    aes(label = paste0(round(procentai, 1), "%")),
    position = position_stack(vjust = 0.5),
    size = 4
  ) +
  scale_y_continuous(
    limits = c(0, 100),
    expand = c(0, 0)
  ) +
  labs(
    title = "Ideal ir Premium klasiu proporcijos",
    subtitle = "K-means t-SNE 2D aibeje",
    x = "Klasteris",
    y = "Procentai (%)",
    fill = "Klase"
  ) +
  theme_minimal()

print(grafikas_klases_tsne)


# 30.6. Apskaiciuojame klasteriu pozymiu medianas

medianu_lentele_tsne <- aggregate(
  originalus_tsne[, c(
    "carat",
    "price",
    "volume_xyz",
    "price_per_carat"
  )],
  by = list(klasteris = originalus_tsne$klasteris),
  FUN = median
)

cat("\nt-SNE 2D klasteriu pozymiu medianos:\n")
print(medianu_lentele_tsne)


# 30.7. Issaugome grafikus ir medianu lentele

dir.create("grafikai", showWarnings = FALSE)
dir.create("rezultatai", showWarnings = FALSE)

ggsave(
  "grafikai/kmeans_boxplot_carat_tsne.png",
  plot = grafikas_carat_tsne,
  width = 7,
  height = 5,
  dpi = 300
)

ggsave(
  "grafikai/kmeans_boxplot_price_tsne.png",
  plot = grafikas_price_tsne,
  width = 7,
  height = 5,
  dpi = 300
)

ggsave(
  "grafikai/kmeans_klasiu_proporcijos_tsne.png",
  plot = grafikas_klases_tsne,
  width = 7,
  height = 5,
  dpi = 300
)

write.csv(
  medianu_lentele_tsne,
  "rezultatai/kmeans_tsne_klasteriu_medianos.csv",
  row.names = FALSE
)

cat("\n30 skyrius baigtas: sukurti 3 grafikai ir medianu lentele.\n")


# =====================================================
# 31. K-MEANS ISORINIAI RODIKLIAI: ARI, NMI IR JACCARD
# =====================================================

# 31.1. Suderiname visu triju aibiu objektus pagal ID
# Taip uztikriname, kad lyginami tie patys deimantai.

id_bendri <- duomenys$id

indeksai_orig <- match(
  id_bendri,
  klasterizuoti_duomenys$id
)

indeksai_pca <- match(
  id_bendri,
  klasterizuoti_pca$id
)

indeksai_tsne <- match(
  id_bendri,
  klasterizuoti_tsne$id
)

# Patikriname, ar visi ID rasti
stopifnot(
  !anyNA(indeksai_orig),
  !anyNA(indeksai_pca),
  !anyNA(indeksai_tsne),
  !anyDuplicated(id_bendri)
)

# 31.2. Paimame kiekvienos aibes klasteriu numerius
# Visu vektoriu objektu tvarka dabar vienoda.

kl_orig <- klasterizuoti_duomenys$klasteris[indeksai_orig]
kl_pca <- klasterizuoti_pca$klasteris[indeksai_pca]
kl_tsne <- klasterizuoti_tsne$klasteris[indeksai_tsne]


# 31.3. Funkcija ARI, NMI ir Jaccard rodikliams
# Rodikliai skaiciuojami pagal dvieju suskirstymu
# kontingencijos lentele.
# Klasteriu numeriu sutapimas nera butinas.

skaiciuoti_isorinius <- function(grupe1, grupe2) {
  
  # Sukuriame dvieju suskirstymu kontingencijos lentele
  T <- table(grupe1, grupe2)
  
  n <- sum(T)
  
  # Pagalbine funkcija objektu poru skaiciui
  poros <- function(x) {
    x * (x - 1) / 2
  }
  
  # Bendros poros, priklausancios tam paciam
  # klasteriui abiejuose suskirstymuose
  TP <- sum(poros(T))
  
  # Poros tame paciame pirmojo suskirstymo klasteryje
  A <- sum(poros(rowSums(T)))
  
  # Poros tame paciame antrojo suskirstymo klasteryje
  B <- sum(poros(colSums(T)))
  
  # Skirtingi priskyrimai
  FP <- A - TP
  FN <- B - TP
  
  # 31.3.1. Jaccard indeksas (objektu poroms)
  jaccard <- if ((TP + FP + FN) == 0) {
    1
  } else {
    TP / (TP + FP + FN)
  }
  
  # 31.3.2. Adjusted Rand Index (ARI)
  visos_poros <- poros(n)
  tiketinas <- A * B / visos_poros
  maksimumas <- (A + B) / 2
  
  ari <- if (abs(maksimumas - tiketinas) < 1e-12) {
    if (A == B && TP == A) 1 else 0
  } else {
    (TP - tiketinas) / (maksimumas - tiketinas)
  }
  
  # 31.3.3. Normalized Mutual Information (NMI)
  # Naudojame aritmetini entropiju vidurki.
  
  P <- T / n
  p1 <- rowSums(P)
  p2 <- colSums(P)
  
  entropija <- function(p) {
    p <- p[p > 0]
    -sum(p * log(p))
  }
  
  H1 <- entropija(p1)
  H2 <- entropija(p2)
  
  # Bendros informacijos (MI) skaiciavimas
  MI <- 0
  
  for (i in seq_len(nrow(P))) {
    for (j in seq_len(ncol(P))) {
      if (P[i, j] > 0) {
        MI <- MI + P[i, j] *
          log(P[i, j] / (p1[i] * p2[j]))
      }
    }
  }
  
  nmi <- if ((H1 + H2) == 0) {
    1
  } else {
    2 * MI / (H1 + H2)
  }
  
  # Graziname visu triju rodikliu reiksmes
  data.frame(
    ARI = ari,
    NMI = nmi,
    Jaccard = jaccard
  )
}


# 31.4. Atliekame tris palyginimus

palyginimas_orig_pca <- skaiciuoti_isorinius(
  kl_orig, kl_pca
)

palyginimas_orig_tsne <- skaiciuoti_isorinius(
  kl_orig, kl_tsne
)

palyginimas_pca_tsne <- skaiciuoti_isorinius(
  kl_pca, kl_tsne
)


# 31.5. Sudarome bendra rezultatu lentele

isoriniu_lentele <- rbind(
  data.frame(
    palyginimas = "Originali 19D vs PCA 5D",
    palyginimas_orig_pca
  ),
  data.frame(
    palyginimas = "Originali 19D vs t-SNE 2D",
    palyginimas_orig_tsne
  ),
  data.frame(
    palyginimas = "PCA 5D vs t-SNE 2D",
    palyginimas_pca_tsne
  )
)

cat("\nK-means isoriniu rodikliu palyginimas:\n")

print(
  isoriniu_lentele,
  row.names = FALSE
)


# 31.6. Papildomai parodome klasteriu sutapimo lenteles
# Eilutes - pirmos aibes klasteriai
# Stulpeliai - antros aibes klasteriai

cat("\nOriginali 19D vs PCA 5D:\n")
print(table(kl_orig, kl_pca))

cat("\nOriginali 19D vs t-SNE 2D:\n")
print(table(kl_orig, kl_tsne))


# 31.7. Issaugome rezultatus

dir.create("rezultatai", showWarnings = FALSE)

write.csv(
  isoriniu_lentele,
  "rezultatai/kmeans_isoriniai_rodikliai.csv",
  row.names = FALSE
)

cat("\n31 skyrius baigtas. Isoriniai rodikliai issaugoti.\n")

