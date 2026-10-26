# =========================================================
# A02 DEIMANTŲ DUOMENŲ RINKINIO SUTVARKYMAS
# (tik duomenų paruošimas, be vizualizacijų ir patikrinimų)
# =========================================================

library(ggplot2)   # ggplot2::diamonds originaliai bazei
library(dplyr)


# =========================================================
# 1. NUSKAITYMAS
# =========================================================

deimantai <- read.csv("A02.csv", na.strings = c(""))
deimantai_original <- deimantai

# =========================================================
# 2. DUOMENŲ TIPŲ TVARKYMAS
# =========================================================

# price: pašaliname valiutos simbolius ir kitus neskaitinius ženklus
deimantai$price <- as.numeric(gsub("[^0-9.]", "", deimantai$price))

# depth: netinkamos tekstinės reikšmės tampa NA
deimantai$depth <- suppressWarnings(as.numeric(deimantai$depth))

# class: kategorinis požymis
deimantai$class <- as.factor(deimantai$class)


# =========================================================
# 3. ORIGINALI BAZĖ VALIDAVIMUI (Ideal + Premium)
# =========================================================

originalas <- ggplot2::diamonds %>%
  mutate(class = as.character(cut)) %>%
  filter(class %in% c("Ideal", "Premium"))

deimantai_su_id <- deimantai %>%
  mutate(a02_id = row_number())


# =========================================================
# 4. carat IR y ATITIKMENŲ PAIEŠKA ORIGINALIOJE BAZĖJE
#    (abu ieškomi pagal dar neatkurtą A02 būseną)
# =========================================================

# --- carat ---
carat_match <- deimantai_su_id %>%
  filter(!is.na(carat) & carat <= 0) %>%
  select(a02_id, depth, table, price, x, y, z, class) %>%
  left_join(
    originalas %>%
      select(depth, table, price, x, y, z, class,
             carat_original = carat),
    by = c("depth", "table", "price", "x", "y", "z", "class")
  )

# --- y ---
y_match <- deimantai_su_id %>%
  filter(!is.na(y) & y <= 0) %>%
  select(a02_id, carat, depth, table, price, x, z, class) %>%
  left_join(
    originalas %>%
      select(carat, depth, table, price, x, z, class,
             y_original = y),
    by = c("carat", "depth", "table", "price", "x", "z", "class")
  )

# y: po vieną rezultatą kiekvienam a02_id
y_match_unique <- y_match %>%
  distinct(a02_id, .keep_all = TRUE)


# =========================================================
# 5. carat, y ATKŪRIMAS
# =========================================================

deimantai$carat[carat_match$a02_id]   <- carat_match$carat_original
deimantai$y[y_match_unique$a02_id]    <- y_match_unique$y_original


# =========================================================
# 6. z = 0 ATKŪRIMAS PAGAL depth FORMULĘ
#    depth = z / ((x + y) / 2) * 100  =>  z = depth * (x + y) / 200
# =========================================================

i_z0 <- which(deimantai$z <= 0)
deimantai$z[i_z0] <- deimantai$depth[i_z0] *
  (deimantai$x[i_z0] + deimantai$y[i_z0]) / 200


# =========================================================
# 7. IŠVESTINIŲ POŽYMIŲ PERSKAIČIAVIMAS
# =========================================================

deimantai$volume_xyz <- deimantai$x * deimantai$y * deimantai$z

deimantai$area_xy <- deimantai$x * deimantai$y
deimantai$area_xz <- deimantai$x * deimantai$z
deimantai$area_yz <- deimantai$y * deimantai$z

deimantai$price_per_carat <- deimantai$price / deimantai$carat

deimantai$length_width_ratio <- deimantai$x / deimantai$y

deimantai$depth_ratio <-
  deimantai$z / ((deimantai$x + deimantai$y) / 2)

deimantai$table_depth_ratio <- deimantai$table / deimantai$depth

deimantai$carat_per_volume <- deimantai$carat / deimantai$volume_xyz
deimantai$price_per_volume <- deimantai$price / deimantai$volume_xyz

deimantai$mean_dimension <-
  (deimantai$x + deimantai$y + deimantai$z) / 3

# Matmenų variacijos koeficientas (populiacijos SD)
deimantai$dimension_cv <- apply(
  deimantai[, c("x", "y", "z")],
  1,
  function(v) {
    m <- mean(v)
    sqrt(mean((v - m)^2)) / m
  }
)


# =========================================================
# 8. depth ATKŪRIMAS (tik vienareikšmiai atitikmenys)
# =========================================================

depth_min_original <- min(originalas$depth, na.rm = TRUE)
depth_max_original <- max(originalas$depth, na.rm = TRUE)

itartinas_depth <- deimantai %>%
  mutate(a02_id = row_number()) %>%
  filter(!is.na(depth) &
           (depth < depth_min_original | depth > depth_max_original))

depth_match <- itartinas_depth %>%
  select(a02_id, carat, table, price, x, y, z, class) %>%
  left_join(
    originalas %>%
      select(carat, table, price, x, y, z, class,
             depth_original = depth),
    by = c("carat", "table", "price", "x", "y", "z", "class")
  )

depth_match_unique <- depth_match %>%
  filter(!is.na(depth_original)) %>%
  group_by(a02_id) %>%
  filter(n_distinct(depth_original) == 1) %>%
  slice(1) %>%
  ungroup()

deimantai$depth[depth_match_unique$a02_id] <-
  depth_match_unique$depth_original

# Perskaičiuojame nuo depth priklausantį požymį
deimantai$table_depth_ratio <- deimantai$table / deimantai$depth


# =========================================================
# 9. price ATKŪRIMAS
#    - vienareikšmiai atitikmenys: tiksli originali reikšmė
#    - nevienareikšmiai: unikalių galimų reikšmių vidurkis
# =========================================================

price_min_original <- min(originalas$price, na.rm = TRUE)
price_max_original <- max(originalas$price, na.rm = TRUE)

itartinas_price <- deimantai %>%
  mutate(a02_id = row_number()) %>%
  filter(!is.na(price) &
           (price < price_min_original | price > price_max_original))

price_match <- itartinas_price %>%
  select(a02_id, carat, depth, table, x, y, z, class) %>%
  left_join(
    originalas %>%
      select(carat, depth, table, x, y, z, class,
             price_original = price),
    by = c("carat", "depth", "table", "x", "y", "z", "class")
  )

# vienareikšmiai
price_match_unique <- price_match %>%
  filter(!is.na(price_original)) %>%
  group_by(a02_id) %>%
  filter(n_distinct(price_original) == 1) %>%
  slice(1) %>%
  ungroup()

# nevienareikšmiai -> unikalių originalių kainų vidurkis
price_match_vidurkiai <- price_match %>%
  filter(!is.na(price_original)) %>%
  group_by(a02_id) %>%
  filter(n_distinct(price_original) > 1) %>%
  summarise(
    price_vidurkis = mean(unique(price_original), na.rm = TRUE),
    .groups = "drop"
  )

deimantai$price[price_match_unique$a02_id] <-
  price_match_unique$price_original

deimantai$price[price_match_vidurkiai$a02_id] <-
  price_match_vidurkiai$price_vidurkis

# Perskaičiuojame nuo price priklausančius požymius
deimantai$price_per_carat  <- deimantai$price / deimantai$carat
deimantai$price_per_volume <- deimantai$price / deimantai$volume_xyz
deimantai$price_per_volume[is.infinite(deimantai$price_per_volume)] <- NA


# =========================================================
# 10. LIKUSIŲ NA UŽPILDYMAS MEDIANA (carat, depth, price)
# =========================================================

carat_mediana <- median(deimantai$carat, na.rm = TRUE)
depth_mediana <- median(deimantai$depth, na.rm = TRUE)
price_mediana <- median(deimantai$price, na.rm = TRUE)

deimantai$carat[is.na(deimantai$carat)] <- carat_mediana
deimantai$depth[is.na(deimantai$depth)] <- depth_mediana
deimantai$price[is.na(deimantai$price)] <- price_mediana


# =========================================================
# 11. GALUTINIS IŠVESTINIŲ POŽYMIŲ PERSKAIČIAVIMAS
# =========================================================

deimantai$price_per_carat    <- deimantai$price / deimantai$carat
deimantai$table_depth_ratio  <- deimantai$table / deimantai$depth
deimantai$carat_per_volume   <- deimantai$carat / deimantai$volume_xyz
deimantai$price_per_volume   <- deimantai$price / deimantai$volume_xyz

deimantai$carat_per_volume[is.infinite(deimantai$carat_per_volume)] <- NA
deimantai$price_per_volume[is.infinite(deimantai$price_per_volume)] <- NA

# =========================================================
# 12. EILUČIŲ ID
#     (reikalingas A prieš C palyginimui: bendriems objektams rasti)
# =========================================================

deimantai$id <- seq_len(nrow(deimantai))

pozymiai_visi <- setdiff(
  names(deimantai)[sapply(deimantai, is.numeric)],
  "id"
)


# =========================================================
# 13. TRYS DUOMENŲ AIBĖS (dar be mastelio keitimo)
# =========================================================

# ---------------------------------------------------------
# 13.1. A: pilna sutvarkyta aibė
# ---------------------------------------------------------

deimantai_pilna <- deimantai


# ---------------------------------------------------------
# 13.2. B: be stipriai koreliuojančių požymių
# ---------------------------------------------------------

pasalinti_pozymiai <- c(
  "x", "y", "z",
  "volume_xyz", "area_xy", "area_xz", "area_yz", "mean_dimension",
  "depth_ratio", "dimension_cv",
  "price_per_carat", "price_per_volume",
  "table_depth_ratio"
)

deimantai_be_koreliuotu <- deimantai[
  , !(names(deimantai) %in% pasalinti_pozymiai)
]


# ---------------------------------------------------------
# 13.3. C: be ekstremumų (už [Q1 - 3*IQR ; Q3 + 3*IQR])
#       Eilutė šalinama, jei ekstremumas yra bent viename
#       skaitiniame požymyje.
# ---------------------------------------------------------

ar_ekstremumas <- function(x) {
  q <- quantile(x, c(0.25, 0.75), na.rm = TRUE)
  h <- 3 * IQR(x, na.rm = TRUE)
  !is.na(x) & (x < q[1] - h | x > q[2] + h)
}

ekstremumu_matrica <- sapply(deimantai[pozymiai_visi], ar_ekstremumas)
eilutes_su_ekstremumais <- rowSums(ekstremumu_matrica) > 0

deimantai_be_ekstremumu <- deimantai[!eilutes_su_ekstremumais, ]

# Ekstremumų suvestinė pagal požymį (README lentelei)
ekstremumu_lentele <- data.frame(
  pozymis = pozymiai_visi,
  ekstremumu_kiekis = colSums(ekstremumu_matrica),
  procentas = round(colMeans(ekstremumu_matrica) * 100, 2)
)
ekstremumu_lentele <- ekstremumu_lentele[
  order(-ekstremumu_lentele$ekstremumu_kiekis),
]

dim(deimantai_be_ekstremumu)

# =========================================================
# 14. MASTELIO KEITIMAS: ROBUST SCALING (x - mediana) / IQR
#     Taikomas kiekvienai aibei ATSKIRAI, tik skaitiniams
#     požymiams. `id` ir `class` nekeičiami.
# =========================================================

robust_scale <- function(df) {
  cols <- setdiff(names(df)[sapply(df, is.numeric)], "id")
  for (col in cols) {
    iqr <- IQR(df[[col]])
    if (iqr == 0) stop(paste("IQR = 0 požymiui:", col))
    df[[col]] <- (df[[col]] - median(df[[col]])) / iqr
  }
  df
}

aibe_A <- robust_scale(deimantai_pilna)
aibe_B <- robust_scale(deimantai_be_koreliuotu)
aibe_C <- robust_scale(deimantai_be_ekstremumu)


# =========================================================
# 15. ĮĖJIMAI PROJEKCIJOMS
#     Tik skaitiniai požymiai: be `class` ir be `id`.
#     `class` ir `id` laikomi atskirai (spalvoms, kNN tikslumui,
#     bendriems objektams rasti).
# =========================================================

paruosti_iejima <- function(df) {
  X <- as.matrix(df[, setdiff(names(df), c("id", "class"))])
  stopifnot(!anyNA(X), all(is.finite(X)))
  X
}

X_A <- paruosti_iejima(aibe_A)
X_B <- paruosti_iejima(aibe_B)
X_C <- paruosti_iejima(aibe_C)

klase_A <- aibe_A$class
klase_C <- aibe_C$class

id_A <- aibe_A$id
id_C <- aibe_C$id

# Bendri A ir C objektai (C yra A poaibis)
bendri_id <- intersect(id_A, id_C)
length(bendri_id)    

dim(X_A)   
dim(X_B)   
dim(X_C)   


# =========================================================
# 16. IŠSAUGOJIMAS (kad visi trys naudotų tuos pačius įėjimus)
# =========================================================

write.csv(aibe_A, "aibe_A.csv", row.names = FALSE)
write.csv(aibe_B, "aibe_B.csv", row.names = FALSE)
write.csv(aibe_C, "aibe_C.csv", row.names = FALSE)

# =========================================================
# 17. PCA ANALIZĖ – A AIBĖ
# =========================================================

pca_A <- prcomp(X_A, center = TRUE, scale. = FALSE)

summary(pca_A)

# PCA paaiškintos dispersijos grafikas

plot(
  pca_A,
  main = "PCA – A aibės komponenčių dispersija"
)
# Kiekvienos komponentės paaiškinta dispersija (%)
dispersija <- 100 * pca_A$sdev^2 / sum(pca_A$sdev^2)

plot(
  dispersija,
  type = "b",
  pch = 19,
  main = "PCA – paaiškinta dispersija",
  xlab = "Pagrindinė komponentė",
  ylab = "Paaiškinta dispersija (%)"
)

# =========================================================
# 18. PCA KOMPONENČIŲ INTERPRETACIJA
# =========================================================

# Pirmųjų trijų komponenčių požymių svoriai
svoriai <- pca_A$rotation[, 1:3]

# Suapvaliname iki 3 skaičių po kablelio
round(svoriai, 3)

# =========================================================
# 19. PCA 2D PROJEKCIJA – A AIBĖ
# =========================================================

# Pirmųjų dviejų komponenčių koordinatės
pca_2d <- as.data.frame(pca_A$x[, 1:2])

# Pridedame deimantų klases
pca_2d$class <- aibe_A$class

# Braižome grafiką
library(ggplot2)

ggplot(pca_2d, aes(x = PC1, y = PC2, color = class)) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "PCA 2D projekcija – A aibė",
    x = "PC1 (65,30 %)",
    y = "PC2 (18,13 %)",
    color = "Deimanto klasė"
  ) +
  coord_equal() +
  theme_minimal()

# =========================================================
# 20. PCA 3D PROJEKCIJA – A AIBĖ
# =========================================================

# Jei neturi paketo, įdiek vieną kartą:
install.packages("plotly")

library(plotly)

# Pirmųjų trijų komponenčių koordinatės
pca_3d <- as.data.frame(pca_A$x[, 1:3])

# Pridedame klases
pca_3d$class <- aibe_A$class

# Interaktyvus 3D grafikas
plot_ly(
  data = pca_3d,
  x = ~PC1,
  y = ~PC2,
  z = ~PC3,
  color = ~class,
  type = "scatter3d",
  mode = "markers",
  marker = list(size = 2, opacity = 0.5)
) %>%
  layout(
    title = "PCA 3D projekcija – A aibė",
    scene = list(
      xaxis = list(title = "PC1 (65,30 %)"),
      yaxis = list(title = "PC2 (18,13 %)"),
      zaxis = list(title = "PC3 (9,99 %)")
    )
  )

# =========================================================
# 21. PCA ANALIZĖ – B AIBĖ
# =========================================================

# Atliekame PCA
pca_B <- prcomp(X_B, center = TRUE, scale. = FALSE)

# Paaiškinta dispersija
summary(pca_B)

# Kiekvienos komponentės dispersija procentais
dispersija_B <- 100 * pca_B$sdev^2 / sum(pca_B$sdev^2)

# Grafikas
plot(
  dispersija_B,
  type = "b",
  pch = 19,
  main = "PCA – B aibės paaiškinta dispersija",
  xlab = "Pagrindinė komponentė",
  ylab = "Paaiškinta dispersija (%)"
)
# =========================================================
# 22. PCA B AIBĖS KOMPONENČIŲ INTERPRETACIJA
# =========================================================

# Pirmųjų trijų komponenčių svoriai
svoriai_B <- pca_B$rotation[, 1:3]

round(svoriai_B, 3)
# =========================================================
# 23. PCA 2D PROJEKCIJA – B AIBĖ
# =========================================================

pca_2d_B <- as.data.frame(pca_B$x[, 1:2])

pca_2d_B$class <- aibe_B$class

library(ggplot2)

ggplot(pca_2d_B, aes(x = PC1, y = PC2, color = class)) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "PCA 2D projekcija – B aibė",
    x = "PC1 (87,18 %)",
    y = "PC2 (6,00 %)",
    color = "Deimanto klasė"
  ) +
  coord_equal() +
  theme_minimal()

# =========================================================
# 24. PCA 3D PROJEKCIJA – B AIBĖ
# =========================================================

library(plotly)

pca_3d_B <- as.data.frame(pca_B$x[, 1:3])
pca_3d_B$class <- aibe_B$class

plot_ly(
  data = pca_3d_B,
  x = ~PC1,
  y = ~PC2,
  z = ~PC3,
  color = ~class,
  type = "scatter3d",
  mode = "markers",
  marker = list(size = 2, opacity = 0.5)
) %>%
  layout(
    title = "PCA 3D projekcija – B aibė",
    scene = list(
      xaxis = list(title = "PC1 (87,18 %)"),
      yaxis = list(title = "PC2 (6,00 %)"),
      zaxis = list(title = "PC3 (3,67 %)")
    )
  )

# =========================================================
# 25. PCA ANALIZĖ – C AIBĖ
# =========================================================

# Atliekame PCA
pca_C <- prcomp(X_C, center = TRUE, scale. = FALSE)

# Peržiūrime paaiškintą dispersiją
summary(pca_C)

# Kiekvienos komponentės paaiškinta dispersija (%)
dispersija_C <- 100 * pca_C$sdev^2 / sum(pca_C$sdev^2)

# Braižome paaiškintos dispersijos grafiką
plot(
  dispersija_C,
  type = "b",
  pch = 19,
  main = "PCA – C aibės paaiškinta dispersija",
  xlab = "Pagrindinė komponentė",
  ylab = "Paaiškinta dispersija (%)"
)
# =========================================================
# 26. PCA C AIBĖS KOMPONENČIŲ INTERPRETACIJA
# =========================================================

# Pirmųjų trijų komponenčių svoriai
svoriai_C <- pca_C$rotation[, 1:3]

# Peržiūrime rezultatus
round(svoriai_C, 3)
# =========================================================
# 27. PCA 2D PROJEKCIJA – C AIBĖ
# =========================================================

# Pirmųjų dviejų komponenčių koordinatės
pca_2d_C <- as.data.frame(pca_C$x[, 1:2])

# Pridedame deimantų klases
pca_2d_C$class <- aibe_C$class

# Braižome grafiką
library(ggplot2)

ggplot(pca_2d_C, aes(x = PC1, y = PC2, color = class)) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "PCA 2D projekcija – C aibė",
    x = "PC1 (55,77 %)",
    y = "PC2 (24,34 %)",
    color = "Deimanto klasė"
  ) +
  coord_equal() +
  theme_minimal()

# =========================================================
# PCA 3D PROJEKCIJA – C AIBĖ
# =========================================================

library(plotly)

# Pirmųjų trijų komponenčių koordinatės
pca_3d_C <- as.data.frame(pca_C$x[, 1:3])

# Pridedame klases
pca_3d_C$class <- aibe_C$class

# 3D grafikas
plot_ly(
  data = pca_3d_C,
  x = ~PC1,
  y = ~PC2,
  z = ~PC3,
  color = ~class,
  type = "scatter3d",
  mode = "markers",
  marker = list(size = 2, opacity = 0.5)
) %>%
  layout(
    title = "PCA 3D projekcija – C aibė",
    scene = list(
      xaxis = list(title = "PC1 (55,77 %)"),
      yaxis = list(title = "PC2 (24,34 %)"),
      zaxis = list(title = "PC3 (9,46 %)")
    )
  )

# =========================================================
# 28. KLASIKINIS MDS – A AIBĖ (2D)
# =========================================================

# Apskaičiuojame atstumus tarp deimantų
atstumai_A <- dist(X_A, method = "euclidean")

# Sumažiname dimensiją iki 2
mds_A <- cmdscale(atstumai_A, k = 2)

# Patikriname rezultato dydį
dim(mds_A)

# =========================================================
# 29. KLASIKINIO MDS 2D PROJEKCIJA – A AIBĖ
# =========================================================

# Paruošiame MDS koordinates
mds_2d_A <- as.data.frame(mds_A)

# Suteikiame stulpeliams pavadinimus
colnames(mds_2d_A) <- c("MDS1", "MDS2")

# Pridedame deimantų klases
mds_2d_A$class <- aibe_A$class

# Braižome grafiką
library(ggplot2)

ggplot(mds_2d_A, aes(x = MDS1, y = MDS2, color = class)) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "Klasikinio MDS 2D projekcija – A aibė",
    x = "MDS1",
    y = "MDS2",
    color = "Deimanto klasė"
  ) +
  coord_equal() +
  theme_minimal()

#patikrinam kiek panasu i PCA
cor(pca_A$x[, 1:2], mds_A)

# =========================================================
# 30. KLASIKINIS MDS – B AIBĖ
# =========================================================

# Apskaičiuojame atstumus
atstumai_B <- dist(X_B, method = "euclidean")

# Atliekame klasikinį MDS
mds_B <- cmdscale(atstumai_B, k = 2)

# Patikriname rezultatą
dim(mds_B)

mds_2d_B <- as.data.frame(mds_B)
colnames(mds_2d_B) <- c("MDS1", "MDS2")
mds_2d_B$class <- aibe_B$class

ggplot(mds_2d_B, aes(x = MDS1, y = MDS2, color = class)) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "Klasikinio MDS 2D projekcija – B aibė",
    x = "MDS1",
    y = "MDS2",
    color = "Deimanto klasė"
  ) +
  coord_equal() +
  theme_minimal()

cor(pca_B$x[, 1:2], mds_B)

# =========================================================
# 31. KLASIKINIS MDS – C AIBĖ
# =========================================================

# Apskaičiuojame atstumus
atstumai_C <- dist(X_C, method = "euclidean")

# Atliekame klasikinį MDS
mds_C <- cmdscale(atstumai_C, k = 2)

# Patikriname rezultatą
dim(mds_C)

mds_2d_C <- as.data.frame(mds_C)
colnames(mds_2d_C) <- c("MDS1", "MDS2")
mds_2d_C$class <- aibe_C$class

ggplot(mds_2d_C, aes(x = MDS1, y = MDS2, color = class)) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "Klasikinio MDS 2D projekcija – C aibė",
    x = "MDS1",
    y = "MDS2",
    color = "Deimanto klasė"
  ) +
  coord_equal() +
  theme_minimal()

cor(pca_C$x[, 1:2], mds_C)

# =========================================================
# 32. METRINIS MDS (SMACOF) – A AIBĖ
# =========================================================

library(smacof)

# Naudojame jau apskaičiuotus A aibės atstumus
# ir klasikinio MDS koordinates kaip pradinį išdėstymą

mds_smacof_A <- smacofSym(
  delta = atstumai_A,
  ndim = 2,
  init = mds_A,
  type = "ratio",
  itmax = 100
)

# Peržiūrime rezultatą
mds_smacof_A$stress

# Tęsiame SMACOF nuo ankstesnio rezultato
mds_smacof_A2 <- smacofSym(
  delta = atstumai_A,
  ndim = 2,
  init = mds_smacof_A$conf,
  type = "ratio",
  itmax = 200
)

# Palyginame Stress reikšmes
c(
  po_100_iteraciju = mds_smacof_A$stress,
  po_papildomu_iteraciju = mds_smacof_A2$stress
)

# =========================================================
# 33. SMACOF MDS 2D PROJEKCIJA – A AIBĖ
# =========================================================

# Imame galutinę SMACOF konfigūraciją
mds_smacof_2d_A <- as.data.frame(mds_smacof_A2$conf)
colnames(mds_smacof_2d_A) <- c("MDS1", "MDS2")

# Pridedame klases
mds_smacof_2d_A$class <- aibe_A$class

# Braižome grafiką
library(ggplot2)

ggplot(mds_smacof_2d_A, aes(x = MDS1, y = MDS2, color = class)) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "Metrinio MDS (SMACOF) 2D projekcija – A aibė",
    x = "MDS1",
    y = "MDS2",
    color = "Deimanto klasė"
  ) +
  coord_equal() +
  theme_minimal()

# Stress-1 apskaičiavimas pagal pradinius Euklido atstumus

stress1 <- function(pradiniai_atstumai, projekcija) {
  d <- as.vector(pradiniai_atstumai)
  dhat <- as.vector(dist(projekcija))
  
  # Optimaliai pritaikome bendrą projekcijos mastelį
  mastelis <- sum(d * dhat) / sum(dhat^2)
  
  sqrt(sum((d - mastelis * dhat)^2) / sum(d^2))
}

c(
  klasikinis_MDS = stress1(atstumai_A, mds_A),
  SMACOF = stress1(atstumai_A, mds_smacof_A2$conf)
)

# =========================================================
# 34. METRINIS MDS (SMACOF) – B AIBĖ
# =========================================================

library(smacof)

mds_smacof_B <- smacofSym(
  delta = atstumai_B,
  ndim = 2,
  init = mds_B,
  type = "ratio",
  itmax = 100
)

mds_smacof_B$stress

# Papildomas B aibės SMACOF optimizavimas

mds_smacof_B2 <- smacofSym(
  delta = atstumai_B,
  ndim = 2,
  init = mds_smacof_B$conf,
  type = "ratio",
  itmax = 200
)mds_smacof_B2$stress

mds_smacof_B2$stress

# =========================================================
# 35. SMACOF 2D PROJEKCIJA – B AIBĖ
# =========================================================

# Paimame SMACOF koordinates
mds_smacof_2d_B <- as.data.frame(mds_smacof_B2$conf)

colnames(mds_smacof_2d_B) <- c("MDS1", "MDS2")

# Pridedame deimantų klases
mds_smacof_2d_B$class <- aibe_B$class

# Braižome grafiką
library(ggplot2)

ggplot(mds_smacof_2d_B, aes(x = MDS1, y = MDS2, color = class)) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "Metrinio MDS (SMACOF) 2D projekcija – B aibė",
    x = "MDS1",
    y = "MDS2",
    color = "Deimanto klasė"
  ) +
  coord_equal() +
  theme_minimal()

c(
  klasikinis_MDS = stress1(atstumai_B, mds_B),
  SMACOF = stress1(atstumai_B, mds_smacof_B2$conf)
)

# =========================================================
# 36. METRINIS MDS (SMACOF) – C AIBĖ
# =========================================================

mds_smacof_C <- smacofSym(
  delta = atstumai_C,
  ndim = 2,
  init = mds_C,
  type = "ratio",
  itmax = 100
)

mds_smacof_C$stress

# =========================================================
# 37. SMACOF C AIBĖ – PAPILDOMOS ITERACIJOS
# =========================================================

mds_smacof_C2 <- smacofSym(
  delta = atstumai_C,
  ndim = 2,
  init = mds_smacof_C$conf,
  type = "ratio",
  itmax = 200
)

# Palyginame Stress reikšmes
c(
  po_100_iteraciju = mds_smacof_C$stress,
  po_papildomu_iteraciju = mds_smacof_C2$stress
)

# =========================================================
# 38. SMACOF 2D PROJEKCIJA – C AIBĖ
# =========================================================

# Paimame SMACOF koordinates
mds_smacof_2d_C <- as.data.frame(mds_smacof_C2$conf)

colnames(mds_smacof_2d_C) <- c("MDS1", "MDS2")

# Pridedame deimantų klases
mds_smacof_2d_C$class <- aibe_C$class

# Braižome grafiką
library(ggplot2)

ggplot(mds_smacof_2d_C, aes(x = MDS1, y = MDS2, color = class)) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "Metrinio MDS (SMACOF) 2D projekcija – C aibė",
    x = "MDS1",
    y = "MDS2",
    color = "Deimanto klasė"
  ) +
  coord_equal() +
  theme_minimal()

c(
  klasikinis_MDS = stress1(atstumai_C, mds_C),
  SMACOF = stress1(atstumai_C, mds_smacof_C2$conf)
)

# =========================================================
# 39. DIMENSIJOS MAZINIMO KOKYBES VERTINIMO FUNKCIJOS
# =========================================================

# Vertinsime tris kaimynysciu dydzius
k_reiksmes <- c(5, 15, 50)


# 1. APSKAICIUOJAME ATSTUMU RANGUS

atstumu_rangai <- function(X) {
  
  D <- as.matrix(dist(X))
  diag(D) <- Inf
  
  N <- nrow(D)
  R <- matrix(0L, nrow = N, ncol = N)
  
  for (i in seq_len(N)) {
    tvarka <- order(D[i, ], seq_len(N))
    R[i, tvarka] <- seq_len(N)
  }
  
  return(R)
}


# 2. TRUSTWORTHINESS IR CONTINUITY

skaiciuoti_TC <- function(R_X, R_Y, k) {
  
  N <- nrow(R_X)
  
  bauda_T <- 0
  bauda_C <- 0
  
  for (i in seq_len(N)) {
    
    kaimynai_X <- which(R_X[i, ] <= k)
    kaimynai_Y <- which(R_Y[i, ] <= k)
    
    # Nauji kaimynai projekcijoje
    netikri <- setdiff(kaimynai_Y, kaimynai_X)
    
    # Prarasti pradiniai kaimynai
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


# 3. KAIMYNU ISSAUGOJIMAS

kaimynysciu_sutapimas <- function(R_X, R_Y, k) {
  
  mean(vapply(
    seq_len(nrow(R_X)),
    function(i) {
      
      kaimynai_X <- which(R_X[i, ] <= k)
      kaimynai_Y <- which(R_Y[i, ] <= k)
      
      length(intersect(kaimynai_X, kaimynai_Y)) / k
    },
    numeric(1)
  ))
}


# 4. BENDRAS LOKALIOS KOKYBES VERTINIMAS

vertinti_lokalia_kokybe <- function(X, Y) {
  
  R_X <- atstumu_rangai(X)
  R_Y <- atstumu_rangai(Y)
  
  rezultatai <- do.call(
    rbind,
    lapply(k_reiksmes, function(k) {
      
      tc <- skaiciuoti_TC(R_X, R_Y, k)
      
      tc$kaimynu_issaugojimas <- kaimynysciu_sutapimas(
        R_X, R_Y, k
      )
      
      tc
    })
  )
  
  return(rezultatai)
}

# =========================================================
# 40. PCA A AIBES LOKALIOS KOKYBES VERTINIMAS
# =========================================================

# PCA 2D projekcijos koordinates
Y_pca_A <- pca_A$x[, 1:2]

# Apskaiciuojame T, C ir kaimynu issaugojima
pca_A_lokali_kokybe <- vertinti_lokalia_kokybe(
  X_A,
  Y_pca_A
)

# Rezultatai
print(pca_A_lokali_kokybe, digits = 6)

# =========================================================
# 41. PCA A AIBES GLOBALIOS KOKYBES VERTINIMAS
# =========================================================

# Pradiniai atstumai
d_X_A <- as.vector(dist(X_A))

# PCA 2D projekcijos atstumai
d_Y_pca_A <- as.vector(dist(Y_pca_A))

# Spearman koreliacija
spearman_pca_A <- cor(
  d_X_A,
  d_Y_pca_A,
  method = "spearman"
)

# Normalizuotas Stress
stress_pca_A <- stress1(
  dist(X_A),
  Y_pca_A
)

# Rezultatai
c(
  Spearman = spearman_pca_A,
  Normalizuotas_Stress = stress_pca_A
)

# =========================================================
# 42. PCA B AIBES KOKYBES VERTINIMAS
# =========================================================

# PCA B aibes 2D koordinates
Y_pca_B <- pca_B$x[, 1:2]

# Lokali kokybe: T, C ir kaimynu issaugojimas
pca_B_lokali_kokybe <- vertinti_lokalia_kokybe(
  X_B,
  Y_pca_B
)

print(pca_B_lokali_kokybe, digits = 6)


# Globali kokybe: Spearman ir Stress
spearman_pca_B <- cor(
  as.vector(dist(X_B)),
  as.vector(dist(Y_pca_B)),
  method = "spearman"
)

stress_pca_B <- stress1(
  dist(X_B),
  Y_pca_B
)

c(
  Spearman = spearman_pca_B,
  Normalizuotas_Stress = stress_pca_B
)

# =========================================================
# 43. PCA C AIBES KOKYBES VERTINIMAS
# =========================================================

# PCA C aibes 2D koordinates
Y_pca_C <- pca_C$x[, 1:2]

# Lokali kokybe: T, C ir kaimynu issaugojimas
pca_C_lokali_kokybe <- vertinti_lokalia_kokybe(
  X_C,
  Y_pca_C
)

print(pca_C_lokali_kokybe, digits = 6)


# Globali kokybe: Spearman ir Stress
spearman_pca_C <- cor(
  as.vector(dist(X_C)),
  as.vector(dist(Y_pca_C)),
  method = "spearman"
)

stress_pca_C <- stress1(
  dist(X_C),
  Y_pca_C
)

c(
  Spearman = spearman_pca_C,
  Normalizuotas_Stress = stress_pca_C
)

# =========================================================
# 44. PCA A IR B PALYGINIMAS BENDROJE A ERDVEJE
# =========================================================

# Patikriname, kad objektai vienodi ir ta pacia tvarka
stopifnot(identical(aibe_A$id, aibe_B$id))

# A projekcija vertinama A erdves atzvilgiu
pca_A_palyginimas <- vertinti_lokalia_kokybe(
  X_A,
  Y_pca_A
)

# B projekcija taip pat vertinama A erdves atzvilgiu
pca_B_palyginimas <- vertinti_lokalia_kokybe(
  X_A,
  Y_pca_B
)

# Sujungiame rezultatus
pca_AB_lokali_kokybe <- rbind(
  data.frame(projekcija = "PCA A", pca_A_palyginimas),
  data.frame(projekcija = "PCA B", pca_B_palyginimas)
)

print(pca_AB_lokali_kokybe, digits = 6)


# Globali kokybe bendroje A erdveje

pca_AB_globali_kokybe <- data.frame(
  projekcija = c("PCA A", "PCA B"),
  
  Spearman = c(
    cor(as.vector(dist(X_A)),
        as.vector(dist(Y_pca_A)),
        method = "spearman"),
    
    cor(as.vector(dist(X_A)),
        as.vector(dist(Y_pca_B)),
        method = "spearman")
  ),
  
  Stress = c(
    stress1(dist(X_A), Y_pca_A),
    stress1(dist(X_A), Y_pca_B)
  )
)

print(pca_AB_globali_kokybe, digits = 6)

# =========================================================
# 45. PCA A IR C PALYGINIMAS SU BENDRAIS OBJEKTAIS
# =========================================================

# Randame C objektu vietas A aibeje pagal id
indeksai_A <- match(aibe_C$id, aibe_A$id)

# Patikriname, ar visi objektai rasti
stopifnot(!anyNA(indeksai_A))

# Pradine A erdve, paliekant tik C objektus
X_A_bendri <- X_A[indeksai_A, , drop = FALSE]

# PCA A projekcija, paliekant tuos pacius objektus
Y_pca_A_bendri <- Y_pca_A[indeksai_A, , drop = FALSE]

# PCA C projekcija
Y_pca_C <- pca_C$x[, 1:2]


# =========================================================
# LOKALI KOKYBE BENDROJE A ERDVEJE
# =========================================================

pca_A_bendri_kokybe <- vertinti_lokalia_kokybe(
  X_A_bendri,
  Y_pca_A_bendri
)

pca_C_bendri_kokybe <- vertinti_lokalia_kokybe(
  X_A_bendri,
  Y_pca_C
)

pca_AC_lokali_kokybe <- rbind(
  data.frame(
    projekcija = "PCA A (bendri)",
    pca_A_bendri_kokybe
  ),
  data.frame(
    projekcija = "PCA C",
    pca_C_bendri_kokybe
  )
)

print(pca_AC_lokali_kokybe, digits = 6)


# =========================================================
# GLOBALI KOKYBE BENDROJE A ERDVEJE
# =========================================================

d_A_bendri <- as.vector(dist(X_A_bendri))

pca_AC_globali_kokybe <- data.frame(
  projekcija = c("PCA A (bendri)", "PCA C"),
  
  Spearman = c(
    cor(
      d_A_bendri,
      as.vector(dist(Y_pca_A_bendri)),
      method = "spearman"
    ),
    cor(
      d_A_bendri,
      as.vector(dist(Y_pca_C)),
      method = "spearman"
    )
  ),
  
  Stress = c(
    stress1(dist(X_A_bendri), Y_pca_A_bendri),
    stress1(dist(X_A_bendri), Y_pca_C)
  )
)

print(pca_AC_globali_kokybe, digits = 6)

# =========================================================
# 46. KLASIKINIO MDS IR SMACOF KOKYBES VERTINIMAS – A AIBE
# =========================================================

# Abieju MDS variantu 2D koordinates
Y_mds_A <- mds_A
Y_smacof_A <- mds_smacof_A2$conf


# =========================================================
# 1. LOKALI KOKYBE: T, C IR KAIMYNU ISSAUGOJIMAS
# =========================================================

# Klasikinis MDS
mds_A_lokali_kokybe <- vertinti_lokalia_kokybe(
  X_A,
  Y_mds_A
)

# MDS su SMACOF
smacof_A_lokali_kokybe <- vertinti_lokalia_kokybe(
  X_A,
  Y_smacof_A
)

# Sujungiame rezultatus
mds_A_lokali_palyginimas <- rbind(
  data.frame(
    metodas = "Klasikinis MDS",
    mds_A_lokali_kokybe
  ),
  data.frame(
    metodas = "MDS SMACOF",
    smacof_A_lokali_kokybe
  )
)

print(mds_A_lokali_palyginimas, digits = 6)


# =========================================================
# 2. GLOBALI KOKYBE: SPEARMAN IR NORMALIZUOTAS STRESS
# =========================================================

mds_A_globali_palyginimas <- data.frame(
  metodas = c("Klasikinis MDS", "MDS SMACOF"),
  
  Spearman = c(
    cor(
      as.vector(dist(X_A)),
      as.vector(dist(Y_mds_A)),
      method = "spearman"
    ),
    cor(
      as.vector(dist(X_A)),
      as.vector(dist(Y_smacof_A)),
      method = "spearman"
    )
  ),
  
  Stress = c(
    stress1(dist(X_A), Y_mds_A),
    stress1(dist(X_A), Y_smacof_A)
  )
)

print(mds_A_globali_palyginimas, digits = 6)

# =========================================================
# 47. KLASIKINIO MDS IR SMACOF KOKYBES VERTINIMAS – B AIBE
# =========================================================

# Abieju MDS variantu 2D koordinates
Y_mds_B <- mds_B
Y_smacof_B <- mds_smacof_B2$conf


# =========================================================
# 1. LOKALI KOKYBE
# =========================================================

# Klasikinis MDS
mds_B_lokali_kokybe <- vertinti_lokalia_kokybe(
  X_B,
  Y_mds_B
)

# MDS su SMACOF
smacof_B_lokali_kokybe <- vertinti_lokalia_kokybe(
  X_B,
  Y_smacof_B
)

# Sujungiame rezultatus
mds_B_lokali_palyginimas <- rbind(
  data.frame(
    metodas = "Klasikinis MDS",
    mds_B_lokali_kokybe
  ),
  data.frame(
    metodas = "MDS SMACOF",
    smacof_B_lokali_kokybe
  )
)

print(mds_B_lokali_palyginimas, digits = 6)


# =========================================================
# 2. GLOBALI KOKYBE
# =========================================================

mds_B_globali_palyginimas <- data.frame(
  metodas = c("Klasikinis MDS", "MDS SMACOF"),
  
  Spearman = c(
    cor(
      as.vector(dist(X_B)),
      as.vector(dist(Y_mds_B)),
      method = "spearman"
    ),
    cor(
      as.vector(dist(X_B)),
      as.vector(dist(Y_smacof_B)),
      method = "spearman"
    )
  ),
  
  Stress = c(
    stress1(dist(X_B), Y_mds_B),
    stress1(dist(X_B), Y_smacof_B)
  )
)

print(mds_B_globali_palyginimas, digits = 6)

# =========================================================
# 48. KLASIKINIO MDS IR SMACOF KOKYBES VERTINIMAS – C AIBE
# =========================================================

# Abieju MDS variantu 2D koordinates
Y_mds_C <- mds_C
Y_smacof_C <- mds_smacof_C2$conf


# 1. LOKALI KOKYBE

mds_C_lokali_kokybe <- vertinti_lokalia_kokybe(
  X_C,
  Y_mds_C
)

smacof_C_lokali_kokybe <- vertinti_lokalia_kokybe(
  X_C,
  Y_smacof_C
)

mds_C_lokali_palyginimas <- rbind(
  data.frame(
    metodas = "Klasikinis MDS",
    mds_C_lokali_kokybe
  ),
  data.frame(
    metodas = "MDS SMACOF",
    smacof_C_lokali_kokybe
  )
)

print(mds_C_lokali_palyginimas, digits = 6)


# 2. GLOBALI KOKYBE

mds_C_globali_palyginimas <- data.frame(
  metodas = c("Klasikinis MDS", "MDS SMACOF"),
  
  Spearman = c(
    cor(
      as.vector(dist(X_C)),
      as.vector(dist(Y_mds_C)),
      method = "spearman"
    ),
    cor(
      as.vector(dist(X_C)),
      as.vector(dist(Y_smacof_C)),
      method = "spearman"
    )
  ),
  
  Stress = c(
    stress1(dist(X_C), Y_mds_C),
    stress1(dist(X_C), Y_smacof_C)
  )
)

print(mds_C_globali_palyginimas, digits = 6)

# =========================================================
# 50. MDS A IR C PALYGINIMAS SU BENDRAIS OBJEKTAIS
# =========================================================

# Randame bendrus objektus pagal ID
indeksai_A <- match(aibe_C$id, aibe_A$id)

stopifnot(
  !anyNA(indeksai_A),
  identical(aibe_A$id[indeksai_A], aibe_C$id)
)

# Pradine A erdve, tik 3928 bendri objektai
X_A_bendri <- X_A[indeksai_A, , drop = FALSE]

# Paruosiame keturias MDS projekcijas
mds_AC_projekcijos <- list(
  "Klasikinis MDS A" = mds_A[indeksai_A, , drop = FALSE],
  "SMACOF A" = mds_smacof_A2$conf[indeksai_A, , drop = FALSE],
  "Klasikinis MDS C" = mds_C,
  "SMACOF C" = mds_smacof_C2$conf
)


# =========================================================
# 1. LOKALI KOKYBE BENDROJE A ERDVEJE
# =========================================================

mds_AC_lokali <- do.call(
  rbind,
  lapply(names(mds_AC_projekcijos), function(pav) {
    
    Y <- mds_AC_projekcijos[[pav]]
    
    data.frame(
      projekcija = pav,
      vertinti_lokalia_kokybe(X_A_bendri, Y)
    )
  })
)

print(mds_AC_lokali, digits = 6)


# =========================================================
# 2. GLOBALI KOKYBE BENDROJE A ERDVEJE
# =========================================================

d_A_bendri <- as.vector(dist(X_A_bendri))

mds_AC_globali <- do.call(
  rbind,
  lapply(names(mds_AC_projekcijos), function(pav) {
    
    Y <- mds_AC_projekcijos[[pav]]
    
    data.frame(
      projekcija = pav,
      
      Spearman = cor(
        d_A_bendri,
        as.vector(dist(Y)),
        method = "spearman"
      ),
      
      Stress = stress1(
        dist(X_A_bendri),
        Y
      )
    )
  })
)

print(mds_AC_globali, digits = 6)
