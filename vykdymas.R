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
# 12. MASTELIO KEITIMAS
#     (kiekvienas metodas kuria atskirą kopiją,
#      `deimantai` lieka nepakeistas)
# =========================================================

numeric_cols <- names(deimantai)[sapply(deimantai, is.numeric)]


# ---------------------------------------------------------
# 12.1. Standardizavimas: (x - vidurkis) / SD
# ---------------------------------------------------------

deimantai_standard <- deimantai

deimantai_standard[numeric_cols] <- lapply(
  deimantai_standard[numeric_cols],
  function(x) (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
)


# ---------------------------------------------------------
# 12.2. Min-Max normalizavimas: (x - min) / (max - min)
# ---------------------------------------------------------

deimantai_minmax <- deimantai

deimantai_minmax[numeric_cols] <- lapply(
  deimantai_minmax[numeric_cols],
  function(x) {
    xmin <- min(x, na.rm = TRUE)
    xmax <- max(x, na.rm = TRUE)
    (x - xmin) / (xmax - xmin)
  }
)


# ---------------------------------------------------------
# 12.3. Robust Scaling: (x - mediana) / IQR
# ---------------------------------------------------------

deimantai_robust <- deimantai

deimantai_robust[numeric_cols] <- lapply(
  deimantai_robust[numeric_cols],
  function(x) {
    (x - median(x, na.rm = TRUE)) / IQR(x, na.rm = TRUE)
  }
)

# =========================================================
# 13. TRYS DUOMENŲ AIBĖS
# =========================================================

# ---------------------------------------------------------
# 13.1. Visa sutvarkyta aibė
# ---------------------------------------------------------

deimantai_pilna <- deimantai


# ---------------------------------------------------------
# 13.2. Be stipriai koreliuojančių požymių
#       (požymiai, atrinkti 1-ame darbe)
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
# 13.3. Be ekstremumų (už 3 × IQR ribų)
#       Eilutė šalinama, jei bent vieno skaitinio požymio
#       reikšmė yra už [Q1 - 3*IQR ; Q3 + 3*IQR]
# ---------------------------------------------------------

ar_ekstremumas <- function(x) {
  q <- quantile(x, c(0.25, 0.75), na.rm = TRUE)
  h <- 3 * IQR(x, na.rm = TRUE)
  !is.na(x) & (x < q[1] - h | x > q[2] + h)
}

skaitiniai <- names(deimantai)[sapply(deimantai, is.numeric)]

ekstremumu_matrica <- sapply(deimantai[skaitiniai], ar_ekstremumas)

eilutes_su_ekstremumais <- rowSums(ekstremumu_matrica) > 0

deimantai_be_ekstremumu <- deimantai[!eilutes_su_ekstremumais, ]

ekstremumu_lentele <- data.frame(
  pozymis = skaitiniai,
  ekstremumu_kiekis = colSums(ekstremumu_matrica),
  procentas = round(colMeans(ekstremumu_matrica) * 100, 2)
)

ekstremumu_lentele <- ekstremumu_lentele[
  order(-ekstremumu_lentele$ekstremumu_kiekis),
]
ekstremumu_lentele

# Bendri skaičiai
nrow(deimantai_pilna)                  # eilučių pilnoje aibėje
sum(eilutes_su_ekstremumais)           # kiek eilučių pašalinta
nrow(deimantai_be_ekstremumu)          # kiek liko
round(mean(eilutes_su_ekstremumais) * 100, 2)  # % pašalintų
