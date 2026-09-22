# =========================================================
# A02 DEIMANTŲ DUOMENŲ RINKINIO ANALIZĖ
# Pirminė analizė, duomenų kokybės tikrinimas ir sutvarkymas
# =========================================================

# Paketai --------------------------------------------------

# Paketą reikia įsidiegti tik vieną kartą, todėl šios eilutės
# pagrindiniame vykdymo faile nereikia:
# install.packages("ggplot2")
# install.packages("dplyr")

library(ggplot2)
library(dplyr)


# =========================================================
# 1. DUOMENŲ NUSKAITYMAS IR STRUKTŪROS PATIKRA
# =========================================================

deimantai <- read.csv(
  "A02.csv",
  na.strings = c("")
)

head(deimantai, 3)
str(deimantai)
dim(deimantai)

# Išsaugome visiškai pradinę nuskaitytų duomenų kopiją
deimantai_original <- deimantai


# =========================================================
# 2. DUOMENŲ TIPŲ IR FORMATO TVARKYMAS
# =========================================================

# ---------------------------------------------------------
# price
# ---------------------------------------------------------

# Jei norime pasižiūrėti, kokie neskaitiniai simboliai yra price:
# table(gsub("[0-9.]", "", deimantai$price), useNA = "ifany")

# Pašaliname valiutos simbolius ir kitus neskaitinius ženklus
deimantai$price <- gsub(
  "[^0-9.]",
  "",
  deimantai$price
)

# Paverčiame į skaitinį tipą
deimantai$price <- as.numeric(
  as.character(deimantai$price)
)


# ---------------------------------------------------------
# depth
# ---------------------------------------------------------

# Jei norime patikrinti, kurios depth reikšmės nėra skaitinės:
# isrinkti <- is.na(suppressWarnings(as.numeric(deimantai$depth))) &
#   !is.na(deimantai$depth)
# deimantai$depth[isrinkti]

# Tekstines netinkamas reikšmes paverčiame į NA
deimantai$depth <- suppressWarnings(
  as.numeric(deimantai$depth)
)


# ---------------------------------------------------------
# class
# ---------------------------------------------------------

# Klasė yra kategorinis požymis
deimantai$class <- as.factor(deimantai$class)

str(deimantai$class)


# =========================================================
# 3. PIRMINĖ APRAŠOMOJI STATISTIKA
# =========================================================

# Ši statistika skaičiuojama jau sutvarkius duomenų tipus,
# bet dar prieš taisant nelogiškas reikšmes.

numeric_cols_pries <- names(deimantai)[
  sapply(deimantai, is.numeric)
]

aprasomoji_funkcija <- function(x) {
  
  x_valid <- x[!is.na(x)]
  
  c(
    n = length(x_valid),
    NA_kiekis = sum(is.na(x)),
    vidurkis = mean(x_valid),
    mediana = median(x_valid),
    standartinis_nuokrypis = sd(x_valid),
    minimumas = min(x_valid),
    Q1 = unname(quantile(x_valid, 0.25)),
    Q3 = unname(quantile(x_valid, 0.75)),
    maksimumas = max(x_valid)
  )
}

aprasomoji_pries <- t(
  sapply(
    deimantai[numeric_cols_pries],
    aprasomoji_funkcija
  )
)

aprasomoji_pries <- as.data.frame(aprasomoji_pries)

aprasomoji_pries$pozymis <- rownames(aprasomoji_pries)

aprasomoji_pries <- aprasomoji_pries[
  ,
  c(
    "pozymis",
    "n",
    "NA_kiekis",
    "vidurkis",
    "mediana",
    "standartinis_nuokrypis",
    "minimumas",
    "Q1",
    "Q3",
    "maksimumas"
  )
]

aprasomoji_pries[, -1] <- round(
  aprasomoji_pries[, -1],
  3
)

aprasomoji_pries

# Paprasta R suvestinė papildomai
summary(deimantai)


# =========================================================
# 4. DUOMENŲ KOKYBĖS TIKRINIMAS
# =========================================================

# ---------------------------------------------------------
# 4.1. Trūkstamos reikšmės
# ---------------------------------------------------------

# Trūkstamų reikšmių skaičius kiekviename stulpelyje
na_kiekiai_pries <- colSums(is.na(deimantai))
na_kiekiai_pries

# Trūkstamų reikšmių procentas kiekviename stulpelyje
na_procentai_pries <- round(
  colMeans(is.na(deimantai)) * 100,
  2
)
na_procentai_pries

# Kiek eilučių turi bent vieną trūkstamą reikšmę
eiluciu_su_na_pries <- sum(
  !complete.cases(deimantai)
)
eiluciu_su_na_pries

# Kiek procentų eilučių turi bent vieną trūkstamą reikšmę
eiluciu_su_na_proc_pries <- round(
  mean(!complete.cases(deimantai)) * 100,
  2
)
eiluciu_su_na_proc_pries


# ---------------------------------------------------------
# Trūkstamų reikšmių pasiskirstymas pagal klasę
# ---------------------------------------------------------

# Automatiškai randame stulpelius, kuriuose yra bent vienas NA
cols_with_na_pries <- names(
  na_kiekiai_pries[na_kiekiai_pries > 0]
)

# class netraukiame į skaitomą NA palyginimą, jei joje NA nėra
cols_with_na_pries <- setdiff(
  cols_with_na_pries,
  "class"
)

na_by_class_pries <- sapply(
  cols_with_na_pries,
  function(col) {
    tapply(
      is.na(deimantai[[col]]),
      deimantai$class,
      mean
    ) * 100
  }
)

na_by_class_pries <- round(
  t(na_by_class_pries),
  2
)

na_by_class_pries


# ---------------------------------------------------------
# 4.2. Dublikatai
# ---------------------------------------------------------

sum(duplicated(deimantai))

# Jei būtų dublikatų, ši eilutė juos parodytų
deimantai[duplicated(deimantai), ]


# ---------------------------------------------------------
# 4.3. Klasių balansas
# ---------------------------------------------------------

table(deimantai$class)

round(
  prop.table(table(deimantai$class)) * 100,
  2
)


# ---------------------------------------------------------
# 4.4. Nelogiškos reikšmės
# ---------------------------------------------------------

# carat negali būti <= 0
sum(deimantai$carat <= 0, na.rm = TRUE)

# price negali būti <= 0
sum(deimantai$price <= 0, na.rm = TRUE)

# x, y, z matmenys turi būti teigiami
sum(deimantai$x <= 0, na.rm = TRUE)
sum(deimantai$y <= 0, na.rm = TRUE)
sum(deimantai$z <= 0, na.rm = TRUE)

# depth ir table turi būti teigiami
sum(deimantai$depth <= 0, na.rm = TRUE)
sum(deimantai$table <= 0, na.rm = TRUE)


# =========================================================
# 5. PROBLEMINIŲ OBJEKTŲ PERŽIŪRA
# =========================================================

# Probleminės carat reikšmės
problemines_carat <- deimantai[
  deimantai$carat <= 0 &
    !is.na(deimantai$carat),
]

problemines_carat


# Probleminės y reikšmės
problemines_y <- deimantai[
  deimantai$y <= 0 &
    !is.na(deimantai$y),
]

problemines_y


# Probleminės z reikšmės
problemines_z <- deimantai[
  deimantai$z <= 0 &
    !is.na(deimantai$z),
]

problemines_z


# Visos unikalios eilutės, kuriose bent viena
# carat, y arba z reikšmė yra nelogiška.
# Naudojame which(), kad NA loginėje sąlygoje nesukurtų NA eilučių.

problemines <- deimantai[
  which(
    deimantai$carat <= 0 |
      deimantai$y <= 0 |
      deimantai$z <= 0
  ),
]

problemines
nrow(problemines)

# Probleminių objektų procentas
round(
  nrow(problemines) / nrow(deimantai) * 100,
  2
)


# =========================================================
# 6. PROBLEMINIŲ REIKŠMIŲ VALIDAVIMAS PAGAL
#    ORIGINALIĄ ggplot2::diamonds BAZĘ
# =========================================================

# Originalioje diamonds bazėje pjūvio kokybės požymis
# vadinasi cut, o A02 faile - class.

originalas <- ggplot2::diamonds %>%
  mutate(
    class = as.character(cut)
  ) %>%
  filter(
    class %in% c("Ideal", "Premium")
  )


# A02 eilutėms pridedame identifikatorių,
# kad būtų aišku, kuri eilutė buvo tikrinama.

deimantai_su_id <- deimantai %>%
  mutate(
    a02_id = row_number()
  )


# ---------------------------------------------------------
# 6.1. carat validavimas
# ---------------------------------------------------------

blogas_carat <- deimantai_su_id %>%
  filter(
    !is.na(carat) &
      carat <= 0
  )

# Kadangi carat yra sugadintas, jo nenaudojame paieškai.
carat_match <- blogas_carat %>%
  select(
    a02_id,
    depth,
    table,
    price,
    x,
    y,
    z,
    class,
    carat_A02 = carat
  ) %>%
  left_join(
    originalas %>%
      select(
        depth,
        table,
        price,
        x,
        y,
        z,
        class,
        carat_original = carat
      ),
    by = c(
      "depth",
      "table",
      "price",
      "x",
      "y",
      "z",
      "class"
    )
  )

carat_match

# Patikriname, kiek atitikmenų gauta kiekvienai A02 eilutei
carat_match %>%
  count(a02_id) %>%
  arrange(desc(n))


# ---------------------------------------------------------
# 6.2. y validavimas
# ---------------------------------------------------------

blogas_y <- deimantai_su_id %>%
  filter(
    !is.na(y) &
      y <= 0
  )

# Kadangi y yra sugadintas, jo nenaudojame paieškai.
y_match <- blogas_y %>%
  select(
    a02_id,
    carat,
    depth,
    table,
    price,
    x,
    z,
    class,
    y_A02 = y
  ) %>%
  left_join(
    originalas %>%
      select(
        carat,
        depth,
        table,
        price,
        x,
        z,
        class,
        y_original = y
      ),
    by = c(
      "carat",
      "depth",
      "table",
      "price",
      "x",
      "z",
      "class"
    )
  )

y_match

y_match %>%
  count(a02_id) %>%
  arrange(desc(n))


# ---------------------------------------------------------
# 6.3. z validavimas
# ---------------------------------------------------------

blogas_z <- deimantai_su_id %>%
  filter(
    !is.na(z) &
      z <= 0
  )

# Kadangi z yra tikrinamas, jo nenaudojame paieškai.
z_match <- blogas_z %>%
  select(
    a02_id,
    carat,
    depth,
    table,
    price,
    x,
    y,
    class,
    z_A02 = z
  ) %>%
  left_join(
    originalas %>%
      select(
        carat,
        depth,
        table,
        price,
        x,
        y,
        class,
        z_original = z
      ),
    by = c(
      "carat",
      "depth",
      "table",
      "price",
      "x",
      "y",
      "class"
    )
  )

z_match

z_match %>%
  count(a02_id) %>%
  arrange(desc(n))


# ---------------------------------------------------------
# 6.4. Suvestinė
# ---------------------------------------------------------

cat(
  "Probleminių carat reikšmių:",
  nrow(blogas_carat),
  "\n"
)

cat(
  "Probleminių y reikšmių:",
  nrow(blogas_y),
  "\n"
)

cat(
  "Probleminių z reikšmių:",
  nrow(blogas_z),
  "\n"
)


# =========================================================
# 7. PATIKIMAI NUSTATYTŲ REIKŠMIŲ ATKŪRIMAS
# =========================================================

# Išsaugome kopiją prieš atkūrimą
deimantai_pries_atkurima <- deimantai


# ---------------------------------------------------------
# 7.1. Atkuriame carat
# ---------------------------------------------------------

for (i in seq_len(nrow(carat_match))) {
  
  deimantai$carat[
    carat_match$a02_id[i]
  ] <- carat_match$carat_original[i]
}


# ---------------------------------------------------------
# 7.2. Atkuriame y
# ---------------------------------------------------------

# Viena A02 eilutė originale gali turėti kelis identiškus
# atitikmenis, todėl paliekame po vieną rezultatą kiekvienam a02_id.

y_match_unique <- y_match %>%
  distinct(
    a02_id,
    .keep_all = TRUE
  )

for (i in seq_len(nrow(y_match_unique))) {
  
  deimantai$y[
    y_match_unique$a02_id[i]
  ] <- y_match_unique$y_original[i]
}


# =========================================================
# 8. PATIKRINAME, AR BAZINĖS REIKŠMĖS SUTVARKYTOS
# =========================================================

sum(deimantai$carat <= 0, na.rm = TRUE)
sum(deimantai$y <= 0, na.rm = TRUE)
sum(deimantai$z <= 0, na.rm = TRUE)

# Pagal originalią bazę z = 0 atvejai nėra A02 sugadinimas,
# todėl jų reikšmių nekeičiam.


# =========================================================
# 9. PERSKAIČIUOJAME IŠVESTINIUS POŽYMIUS
# =========================================================

# Tūris
deimantai$volume_xyz <-
  deimantai$x *
  deimantai$y *
  deimantai$z

# Ploto požymiai
deimantai$area_xy <-
  deimantai$x *
  deimantai$y

deimantai$area_xz <-
  deimantai$x *
  deimantai$z

deimantai$area_yz <-
  deimantai$y *
  deimantai$z

# Kaina vienam karatui
deimantai$price_per_carat <-
  deimantai$price /
  deimantai$carat

# Ilgio ir pločio santykis
deimantai$length_width_ratio <-
  deimantai$x /
  deimantai$y

# Gylio santykis
deimantai$depth_ratio <-
  deimantai$z /
  ((deimantai$x + deimantai$y) / 2)

# table ir depth santykis
deimantai$table_depth_ratio <-
  deimantai$table /
  deimantai$depth

# Karatų kiekis tūrio vienetui
deimantai$carat_per_volume <-
  deimantai$carat /
  deimantai$volume_xyz

# Kaina tūrio vienetui
deimantai$price_per_volume <-
  deimantai$price /
  deimantai$volume_xyz

# Vidutinis matmuo
deimantai$mean_dimension <-
  (
    deimantai$x +
      deimantai$y +
      deimantai$z
  ) / 3

# Matmenų variacijos koeficientas
# Naudojame populiacijos standartinį nuokrypį,
# kad formulė atitiktų A02 išvestinio požymio skaičiavimą.

deimantai$dimension_cv <- apply(
  deimantai[, c("x", "y", "z")],
  1,
  function(v) {
    
    m <- mean(v)
    
    sd_pop <- sqrt(
      mean((v - m)^2)
    )
    
    sd_pop / m
  }
)


# =========================================================
# 10. Inf REIKŠMIŲ TVARKYMAS
# =========================================================

# Kai z = 0, volume_xyz = 0.
# Dėl dalybos iš nulio carat_per_volume ir price_per_volume
# gali tapti Inf. Tokias reikšmes keičiame į NA.

deimantai$carat_per_volume[
  is.infinite(deimantai$carat_per_volume)
] <- NA

deimantai$price_per_volume[
  is.infinite(deimantai$price_per_volume)
] <- NA

# Patikriname, ar Inf nebeliko
sum(
  is.infinite(
    as.matrix(
      deimantai[
        sapply(deimantai, is.numeric)
      ]
    )
  )
)


# =========================================================
# 11. DUOMENŲ KOKYBĖS PATIKRA PO SUTVARKYMO
# =========================================================

summary(deimantai)

# NA kiekis po perskaičiavimo
na_kiekiai_po <- colSums(
  is.na(deimantai)
)

na_kiekiai_po

# NA procentai po perskaičiavimo
na_procentai_po <- round(
  colMeans(is.na(deimantai)) * 100,
  2
)

na_procentai_po

# Kiek eilučių dabar turi bent vieną NA
sum(
  !complete.cases(deimantai)
)

round(
  mean(!complete.cases(deimantai)) * 100,
  2
)


# =========================================================
# 12. APRAŠOMOJI STATISTIKA PO DUOMENŲ SUTVARKYMO
# =========================================================

numeric_cols_po <- names(deimantai)[
  sapply(deimantai, is.numeric)
]

aprasomoji_po <- t(
  sapply(
    deimantai[numeric_cols_po],
    aprasomoji_funkcija
  )
)

aprasomoji_po <- as.data.frame(
  aprasomoji_po
)

aprasomoji_po$pozymis <-
  rownames(aprasomoji_po)

aprasomoji_po <- aprasomoji_po[
  ,
  c(
    "pozymis",
    "n",
    "NA_kiekis",
    "vidurkis",
    "mediana",
    "standartinis_nuokrypis",
    "minimumas",
    "Q1",
    "Q3",
    "maksimumas"
  )
]

aprasomoji_po[, -1] <- round(
  aprasomoji_po[, -1],
  3
)

aprasomoji_po


# =========================================================
# 13. APRAŠOMOJI STATISTIKA PAGAL KLASĘ
# =========================================================

aprasomoji_klasei <- function(data) {
  
  numeric_cols <- names(data)[
    sapply(data, is.numeric)
  ]
  
  rezultatas <- t(
    sapply(
      data[numeric_cols],
      aprasomoji_funkcija
    )
  )
  
  rezultatas <- as.data.frame(
    rezultatas
  )
  
  rezultatas$pozymis <-
    rownames(rezultatas)
  
  rezultatas <- rezultatas[
    ,
    c(
      "pozymis",
      "n",
      "NA_kiekis",
      "vidurkis",
      "mediana",
      "standartinis_nuokrypis",
      "minimumas",
      "Q1",
      "Q3",
      "maksimumas"
    )
  ]
  
  rezultatas[, -1] <- round(
    rezultatas[, -1],
    3
  )
  
  rezultatas
}


# ---------------------------------------------------------
# 13.1. Ideal klasė
# ---------------------------------------------------------

deimantai_ideal <- deimantai %>%
  filter(class == "Ideal")

aprasomoji_ideal <- aprasomoji_klasei(
  deimantai_ideal
)

aprasomoji_ideal


# ---------------------------------------------------------
# 13.2. Premium klasė
# ---------------------------------------------------------

deimantai_premium <- deimantai %>%
  filter(class == "Premium")

aprasomoji_premium <- aprasomoji_klasei(
  deimantai_premium
)

aprasomoji_premium


# =========================================================
# 14. IDEAL IR PREMIUM KLASIŲ PALYGINIMAS
# =========================================================

klasiu_palyginimas <- deimantai %>%
  group_by(class) %>%
  summarise(
    n = n(),
    
    carat_vidurkis = mean(carat, na.rm = TRUE),
    carat_mediana = median(carat, na.rm = TRUE),
    
    depth_vidurkis = mean(depth, na.rm = TRUE),
    depth_mediana = median(depth, na.rm = TRUE),
    
    table_vidurkis = mean(table, na.rm = TRUE),
    table_mediana = median(table, na.rm = TRUE),
    
    price_vidurkis = mean(price, na.rm = TRUE),
    price_mediana = median(price, na.rm = TRUE),
    
    volume_vidurkis = mean(volume_xyz, na.rm = TRUE),
    volume_mediana = median(volume_xyz, na.rm = TRUE),
    
    price_per_carat_vidurkis =
      mean(price_per_carat, na.rm = TRUE),
    
    price_per_carat_mediana =
      median(price_per_carat, na.rm = TRUE),
    
    .groups = "drop"
  )

klasiu_palyginimas


# =========================================================
# 15. KLASIŲ PALYGINIMAS BOXPLOT DIAGRAMOMIS
# =========================================================

boxplot(
  carat ~ class,
  data = deimantai,
  main = "Carat pagal klasę",
  xlab = "Klasė",
  ylab = "Carat"
)

boxplot(
  price ~ class,
  data = deimantai,
  main = "Price pagal klasę",
  xlab = "Klasė",
  ylab = "Price"
)

boxplot(
  depth ~ class,
  data = deimantai,
  main = "Depth pagal klasę",
  xlab = "Klasė",
  ylab = "Depth"
)

boxplot(
  table ~ class,
  data = deimantai,
  main = "Table pagal klasę",
  xlab = "Klasė",
  ylab = "Table"
)

boxplot(
  volume_xyz ~ class,
  data = deimantai,
  main = "Volume pagal klasę",
  xlab = "Klasė",
  ylab = "Volume"
)


# =========================================================
# 16. HISTOGRAMOS PAGAL KLASĘ
# =========================================================

# Pagrindiniams požymiams pažiūrime atskirus
# Ideal ir Premium pasiskirstymus.

pagrindiniai_pozymiai <- c(
  "carat",
  "depth",
  "table",
  "price",
  "volume_xyz",
  "price_per_carat"
)

for (col in pagrindiniai_pozymiai) {
  
  hist(
    deimantai_ideal[[col]],
    main = paste("Ideal klasė -", col),
    xlab = col,
    col = "lightblue",
    border = "white"
  )
  
  hist(
    deimantai_premium[[col]],
    main = paste("Premium klasė -", col),
    xlab = col,
    col = "lightblue",
    border = "white"
  )
}


# =========================================================
# 17. BENDRA POŽYMIŲ PASISKIRSTYMO ANALIZĖ
# =========================================================

numeric_cols <- names(deimantai)[
  sapply(deimantai, is.numeric)
]

for (col in numeric_cols) {
  
  hist(
    deimantai[[col]],
    main = col,
    xlab = col,
    col = "lightblue",
    border = "white"
  )
}


# =========================================================
# 18. BOXPLOT DIAGRAMOS VISAI AIBEI
# =========================================================

for (col in numeric_cols) {
  
  boxplot(
    deimantai[[col]],
    main = col,
    ylab = col,
    col = "lightgreen"
  )
}


# =========================================================
# 19. IŠSKIRČIŲ ANALIZĖ PAGAL 1.5 × IQR
# =========================================================

count_outliers <- function(x) {
  
  qnt <- quantile(
    x,
    probs = c(0.25, 0.75),
    na.rm = TRUE
  )
  
  H <- 1.5 * IQR(
    x,
    na.rm = TRUE
  )
  
  apacia <- qnt[1] - H
  virsus <- qnt[2] + H
  
  sum(
    x < apacia |
      x > virsus,
    na.rm = TRUE
  )
}

outlier_counts <- sapply(
  deimantai[numeric_cols],
  count_outliers
)

valid_counts <- sapply(
  deimantai[numeric_cols],
  function(x) {
    sum(!is.na(x))
  }
)

outlier_percent <- round(
  outlier_counts /
    valid_counts *
    100,
  2
)

rezultatai_isskirtys <- data.frame(
  pozymis = names(outlier_counts),
  iskirciu_kiekis = outlier_counts,
  procentas = outlier_percent
)

rezultatai_isskirtys <-
  rezultatai_isskirtys[
    order(
      -rezultatai_isskirtys$iskirciu_kiekis
    ),
  ]

rezultatai_isskirtys

# =========================================================
# PAPILDOMAS BAZINIŲ POŽYMIŲ VALIDAVIMAS
# Tikrinami depth ir price požymiai pagal originalią
# ggplot2::diamonds bazę
# =========================================================

# Ši kodo dalis skirta vykdyti PO to, kai:
# 1) jau paruoštas objektas originalas;
# 2) carat ir y reikšmės jau atkurtos;
# 3) išvestiniai požymiai jau perskaičiuoti.
#
# Tikslas:
# - rasti depth ir price reikšmes, kurios išeina už originalios
#   Ideal + Premium bazės ribų;
# - surasti atitinkamus objektus originalioje bazėje;
# - depth reikšmes atkurti tik tada, kai originalus atitikmuo
#   yra vienareikšmis;
# - price kol kas tik validuoti, bet nekeisti automatiškai.


# =========================================================
# 1. ORIGINALIOS BAZĖS RIBOS
# =========================================================

depth_min_original <- min(originalas$depth, na.rm = TRUE)
depth_max_original <- max(originalas$depth, na.rm = TRUE)

price_min_original <- min(originalas$price, na.rm = TRUE)
price_max_original <- max(originalas$price, na.rm = TRUE)

cat(
  "Originalios bazės depth ribos:",
  depth_min_original,
  "-",
  depth_max_original,
  "\n"
)

cat(
  "Originalios bazės price ribos:",
  price_min_original,
  "-",
  price_max_original,
  "\n"
)


# =========================================================
# 2. ĮTARTINŲ depth REIKŠMIŲ PAIEŠKA
# =========================================================

itartinas_depth <- deimantai %>%
  mutate(a02_id = row_number()) %>%
  filter(
    !is.na(depth) &
      (
        depth < depth_min_original |
          depth > depth_max_original
      )
  )

cat(
  "Įtartinų depth reikšmių skaičius:",
  nrow(itartinas_depth),
  "\n"
)

itartinas_depth


# =========================================================
# 3. depth PALYGINIMAS SU ORIGINALIA BAZE
# =========================================================

depth_match <- itartinas_depth %>%
  select(
    a02_id,
    carat,
    table,
    price,
    x,
    y,
    z,
    class,
    depth_A02 = depth
  ) %>%
  left_join(
    originalas %>%
      select(
        carat,
        table,
        price,
        x,
        y,
        z,
        class,
        depth_original = depth
      ),
    by = c(
      "carat",
      "table",
      "price",
      "x",
      "y",
      "z",
      "class"
    )
  )

depth_match


# =========================================================
# 4. depth ATITIKMENŲ PATIKRA
# =========================================================

depth_match_suvestine <- depth_match %>%
  group_by(a02_id) %>%
  summarise(
    depth_A02 = first(depth_A02),
    kiek_atitikmenu = n(),
    kiek_skirtingu_depth = n_distinct(depth_original),
    originalios_reiksmes = paste(
      unique(depth_original),
      collapse = ", "
    ),
    .groups = "drop"
  )

depth_match_suvestine


# =========================================================
# 5. VIENAREIKŠMIŲ depth REIKŠMIŲ ATKŪRIMAS
# =========================================================

depth_match_unique <- depth_match %>%
  filter(!is.na(depth_original)) %>%
  group_by(a02_id) %>%
  filter(n_distinct(depth_original) == 1) %>%
  slice(1) %>%
  ungroup()

cat(
  "Vienareikšmiškai atkuriamų depth reikšmių skaičius:",
  nrow(depth_match_unique),
  "\n"
)

depth_match_unique

deimantai_pries_depth_atkurima <- deimantai

for (i in seq_len(nrow(depth_match_unique))) {
  deimantai$depth[
    depth_match_unique$a02_id[i]
  ] <- depth_match_unique$depth_original[i]
}


# =========================================================
# 6. depth PATIKRA PO ATKŪRIMO
# =========================================================

summary(deimantai$depth)

range(
  deimantai$depth,
  na.rm = TRUE
)

depth_liko_itartinu <- deimantai %>%
  mutate(a02_id = row_number()) %>%
  filter(
    !is.na(depth) &
      (
        depth < depth_min_original |
          depth > depth_max_original
      )
  )

cat(
  "Po atkūrimo likusių įtartinų depth reikšmių skaičius:",
  nrow(depth_liko_itartinu),
  "\n"
)

depth_liko_itartinu


# =========================================================
# 7. PO depth ATKŪRIMO PERSKAIČIUOJAME
#    NUO depth PRIKLAUSANTĮ IŠVESTINĮ POŽYMĮ
# =========================================================

deimantai$table_depth_ratio <-
  deimantai$table /
  deimantai$depth


# =========================================================
# 8. ĮTARTINŲ price REIKŠMIŲ PAIEŠKA
# =========================================================

itartinas_price <- deimantai %>%
  mutate(a02_id = row_number()) %>%
  filter(
    !is.na(price) &
      (
        price < price_min_original |
          price > price_max_original
      )
  )

cat(
  "Įtartinų price reikšmių skaičius:",
  nrow(itartinas_price),
  "\n"
)

itartinas_price


# =========================================================
# 9. price PALYGINIMAS SU ORIGINALIA BAZE
# =========================================================

price_match <- itartinas_price %>%
  select(
    a02_id,
    carat,
    depth,
    table,
    x,
    y,
    z,
    class,
    price_A02 = price
  ) %>%
  left_join(
    originalas %>%
      select(
        carat,
        depth,
        table,
        x,
        y,
        z,
        class,
        price_original = price
      ),
    by = c(
      "carat",
      "depth",
      "table",
      "x",
      "y",
      "z",
      "class"
    )
  )

price_match


# =========================================================
# 10. price ATITIKMENŲ PATIKRA
# =========================================================

price_match_suvestine <- price_match %>%
  group_by(a02_id) %>%
  summarise(
    price_A02 = first(price_A02),
    kiek_atitikmenu = n(),
    kiek_skirtingu_price = n_distinct(price_original),
    originalios_reiksmes = paste(
      unique(price_original),
      collapse = ", "
    ),
    .groups = "drop"
  )

price_match_suvestine


# =========================================================
# 11. SVARBU: price KOL KAS AUTOMATIŠKAI NEKEIČIAME
# =========================================================

# Price reikšmes pirmiausia įvertiname pagal price_match
# ir price_match_suvestine rezultatus.
#
# Jei bus patvirtinta, kad atitikmenys vienareikšmiai,
# tik tada jas bus galima saugiai atkurti.


# =========================================================
# 12. GALUTINĖ ŠIOS DALIES SUVESTINĖ
# =========================================================

cat("\n")
cat("===== VALIDAVIMO SUVESTINĖ =====\n")

cat(
  "Originalios depth ribos:",
  depth_min_original,
  "-",
  depth_max_original,
  "\n"
)

cat(
  "Pradžioje įtartinų depth:",
  nrow(itartinas_depth),
  "\n"
)

cat(
  "Vienareikšmiškai atkurtų depth:",
  nrow(depth_match_unique),
  "\n"
)

cat(
  "Po atkūrimo likusių įtartinų depth:",
  nrow(depth_liko_itartinu),
  "\n"
)

cat(
  "Originalios price ribos:",
  price_min_original,
  "-",
  price_max_original,
  "\n"
)

cat(
  "Įtartinų price reikšmių:",
  nrow(itartinas_price),
  "\n"
)

cat("===============================\n")

# =========================================================
# PRICE REIKŠMIŲ ATKŪRIMAS
# Atkuriamos tik vienareikšmės price reikšmės
# =========================================================

# kai jau turimi objektai:
# - price_match
# - price_match_suvestine
# - deimantai
#
# Tikslas:
# 1. atkurti tik tas price reikšmes, kurioms rastas vienas
#    vienintelis originalus atitikmuo;
# 2. atskirai išskirti dviprasmes eilutes;
# 3. perskaičiuoti nuo price priklausančius išvestinius požymius;
# 4. patikrinti rezultatą.


# =========================================================
# 1. VIENAREIKŠMIŲ price ATITIKMENŲ ATRINKIMAS
# =========================================================

price_match_unique <- price_match %>%
  filter(
    !is.na(price_original)
  ) %>%
  group_by(a02_id) %>%
  filter(
    n_distinct(price_original) == 1
  ) %>%
  slice(1) %>%
  ungroup()

cat(
  "Vienareikšmiškai atkuriamų price reikšmių skaičius:",
  nrow(price_match_unique),
  "\n"
)

price_match_unique


# =========================================================
# 2. DVIPRASMIŲ price ATITIKMENŲ ATRINKIMAS
# =========================================================

price_match_nevienareiksmiai <- price_match %>%
  group_by(a02_id) %>%
  filter(
    n_distinct(price_original) > 1
  ) %>%
  ungroup()

price_match_nevienareiksmiai_suvestine <-
  price_match_nevienareiksmiai %>%
  group_by(a02_id) %>%
  summarise(
    price_A02 = first(price_A02),
    kiek_atitikmenu = n(),
    kiek_skirtingu_price = n_distinct(price_original),
    galimos_originalios_reiksmes = paste(
      sort(unique(price_original)),
      collapse = ", "
    ),
    .groups = "drop"
  )

cat(
  "Dviprasmių price eilučių skaičius:",
  nrow(price_match_nevienareiksmiai_suvestine),
  "\n"
)

price_match_nevienareiksmiai_suvestine


# =========================================================
# 3. PRICE REIKŠMIŲ ATKŪRIMAS
# =========================================================

# Išsaugome kopiją prieš atkūrimą
deimantai_pries_price_atkurima <- deimantai

for (i in seq_len(nrow(price_match_unique))) {
  
  deimantai$price[
    price_match_unique$a02_id[i]
  ] <- price_match_unique$price_original[i]
}


# =========================================================
# 4. PATIKRINAME PRICE RIBAS PO ATKŪRIMO
# =========================================================

summary(deimantai$price)

range(
  deimantai$price,
  na.rm = TRUE
)

# Randame, kurios price reikšmės vis dar išeina už
# originalios Ideal + Premium bazės ribų.

price_liko_itartinu <- deimantai %>%
  mutate(
    a02_id = row_number()
  ) %>%
  filter(
    !is.na(price) &
      (
        price < price_min_original |
          price > price_max_original
      )
  )

cat(
  "Po vienareikšmių reikšmių atkūrimo likusių įtartinų price:",
  nrow(price_liko_itartinu),
  "\n"
)

price_liko_itartinu


# =========================================================
# 5. DVIPRASMIŲ PRICE REIKŠMIŲ PAŽYMĖJIMAS
# =========================================================

# Dviprasmių price reikšmių automatiškai nekeičiam.
# Jos paliekamos atskiram sprendimui.

if (nrow(price_match_nevienareiksmiai_suvestine) > 0) {
  
  cat("\nDviprasmės price eilutės:\n")
  
  print(
    price_match_nevienareiksmiai_suvestine,
    n = Inf
  )
}


# =========================================================
# 6. PERSKAIČIUOJAME NUO price PRIKLAUSANČIUS
#    IŠVESTINIUS POŽYMIUS
# =========================================================

deimantai$price_per_carat <-
  deimantai$price /
  deimantai$carat

deimantai$price_per_volume <-
  deimantai$price /
  deimantai$volume_xyz


# Jei volume_xyz = 0, price_per_volume tampa Inf.
# Tokias reikšmes keičiame į NA.

deimantai$price_per_volume[
  is.infinite(deimantai$price_per_volume)
] <- NA


# =========================================================
# 7. PATIKRINAME Inf IR NA PO PERSKAIČIAVIMO
# =========================================================

cat(
  "Inf skaičius po perskaičiavimo:",
  sum(
    is.infinite(
      as.matrix(
        deimantai[
          sapply(deimantai, is.numeric)
        ]
      )
    )
  ),
  "\n"
)

na_kiekiai_po_price <- colSums(
  is.na(deimantai)
)

na_kiekiai_po_price


# =========================================================
# 8. APRAŠOMOJI STATISTIKA PO price ATKŪRIMO
# =========================================================

numeric_cols_po_price <- names(deimantai)[
  sapply(deimantai, is.numeric)
]

aprasomoji_po_price <- t(
  sapply(
    deimantai[numeric_cols_po_price],
    aprasomoji_funkcija
  )
)

aprasomoji_po_price <- as.data.frame(
  aprasomoji_po_price
)

aprasomoji_po_price$pozymis <-
  rownames(aprasomoji_po_price)

aprasomoji_po_price <- aprasomoji_po_price[
  ,
  c(
    "pozymis",
    "n",
    "NA_kiekis",
    "vidurkis",
    "mediana",
    "standartinis_nuokrypis",
    "minimumas",
    "Q1",
    "Q3",
    "maksimumas"
  )
]

aprasomoji_po_price[, -1] <- round(
  aprasomoji_po_price[, -1],
  3
)

aprasomoji_po_price


# =========================================================
# 9. IŠSKIRČIŲ ANALIZĖ PO price ATKŪRIMO
# =========================================================

numeric_cols <- names(deimantai)[
  sapply(deimantai, is.numeric)
]

outlier_counts_po_price <- sapply(
  deimantai[numeric_cols],
  count_outliers
)

valid_counts_po_price <- sapply(
  deimantai[numeric_cols],
  function(x) {
    sum(!is.na(x))
  }
)

outlier_percent_po_price <- round(
  outlier_counts_po_price /
    valid_counts_po_price *
    100,
  2
)

rezultatai_isskirtys_po_price <- data.frame(
  pozymis = names(outlier_counts_po_price),
  iskirciu_kiekis = outlier_counts_po_price,
  procentas = outlier_percent_po_price
)

rezultatai_isskirtys_po_price <-
  rezultatai_isskirtys_po_price[
    order(
      -rezultatai_isskirtys_po_price$iskirciu_kiekis
    ),
  ]

rezultatai_isskirtys_po_price


# =========================================================
# 10. GALUTINĖ SUVESTINĖ
# =========================================================

cat("\n")
cat("===== PRICE ATKŪRIMO SUVESTINĖ =====\n")

cat(
  "Pradžioje įtartinų price:",
  nrow(itartinas_price),
  "\n"
)

cat(
  "Vienareikšmiškai atkurtų price:",
  nrow(price_match_unique),
  "\n"
)

cat(
  "Dviprasmių price eilučių:",
  nrow(price_match_nevienareiksmiai_suvestine),
  "\n"
)

cat(
  "Po atkūrimo likusių price už originalios ribos:",
  nrow(price_liko_itartinu),
  "\n"
)

cat(
  "Dabartinės price ribos:",
  min(deimantai$price, na.rm = TRUE),
  "-",
  max(deimantai$price, na.rm = TRUE),
  "\n"
)

cat("====================================\n")

# =========================================================
# TOLIMESNI ŽINGSNIAI
# =========================================================

# Toliau:
# 1. ištirti likusias labai įtartinas bazines reikšmes
#    (pvz., depth = 239.06);
# 2. pasirinkti trūkstamų reikšmių apdorojimo metodą;
# 3. nuspręsti, kaip elgtis su statistinėmis išskirtimis;
# 4. atlikti normavimo / standartizavimo palyginimą;
# 5. atlikti koreliacijų analizę;
# 6. tirti carat ir price ryšį;
# 7. tirti volume_xyz ir price ryšį;
# 8. tirti carat ir volume_xyz ryšį;
# 9. įvertinti duomenų tinkamumą tolimesnei analizei.
