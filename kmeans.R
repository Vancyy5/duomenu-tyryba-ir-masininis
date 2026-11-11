
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
