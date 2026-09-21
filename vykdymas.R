install.packages("ggplot2")
library(ggplot2)

deimantai <- read.csv("A02.csv", na.strings=c(""))
head(deimantai,3)
str(deimantai)
dim(deimantai)

deimantai_original <- deimantai

#tvarkomi stulpeliai
#apacioje patikrinimas, kokie simboliai yra neiskaitant skaiciu ir tasko
#table(gsub("[0-9.]", "", deimantai$price), useNA = "ifany")
deimantai$price <- gsub("[^0-9.]", "", deimantai$price)
deimantai$price <- as.numeric(as.character(deimantai$price))
summary(deimantai)

#tas pats su depth stulpeliu
#table(gsub("[0-9.]", "", deimantai$depth), useNA = "ifany")
#isrinkti <- is.na(suppressWarnings(as.numeric(deimantai$depth))) & !is.na(deimantai$depth)
#deimantai$depth[isrinkti] 
deimantai$depth <- suppressWarnings(as.numeric(deimantai$depth))
summary(deimantai)

# klasė - kategorinė žymė
deimantai$class <- as.factor(deimantai$class)
str(deimantai$class)

# -----------------------------
# DUOMENŲ KOKYBĖS TIKRINIMAS
# -----------------------------

# 1. Trūkstamos reikšmės kiekviename stulpelyje
colSums(is.na(deimantai))

# Trūkstamų reikšmių procentas
round(colMeans(is.na(deimantai)) * 100, 2)

# Kiek eilučių turi bent vieną trūkstamą reikšmę
sum(!complete.cases(deimantai))

# Kiek procentų eilučių turi bent vieną trūkstamą reikšmę
round(mean(!complete.cases(deimantai)) * 100, 2)


#Trūkstamų reikšmių pasiskirtymas pagal klasę vienoje lentelėje

# Požymiai, kuriuose yra trūkstamų reikšmių (pagal jūsų jau gautą lentelę)
cols_with_na <- c("carat", "depth", "price", "volume_xyz",
                  "carat_per_volume", "price_per_volume")

# Kiekvienam požymiui apskaičiuojame trūkstamų reikšmių procentą pagal klasę
na_by_class <- sapply(cols_with_na, function(col) {
  tapply(is.na(deimantai[[col]]), deimantai$class, mean) * 100
})

# Sutvarkome, kad požymiai būtų eilutėse, klasės - stulpeliuose
na_by_class <- round(t(na_by_class), 2)
na_by_class

# 2. Dublikatai
sum(duplicated(deimantai))

# Jei yra dublikatų - parodyti
deimantai[duplicated(deimantai), ]


# 3. Klasių balansas
table(deimantai$class)

# Procentais
round(prop.table(table(deimantai$class)) * 100, 2)


# 4. Nelogiškos reikšmės

# carat negali būti neigiamas arba 0
sum(deimantai$carat <= 0, na.rm = TRUE)

# price negali būti neigiama arba 0
sum(deimantai$price <= 0, na.rm = TRUE)

# x, y, z matmenys turi būti teigiami
sum(deimantai$x <= 0, na.rm = TRUE)
sum(deimantai$y <= 0, na.rm = TRUE)
sum(deimantai$z <= 0, na.rm = TRUE)

# depth ir table taip pat turi būti teigiami
sum(deimantai$depth <= 0, na.rm = TRUE)
sum(deimantai$table <= 0, na.rm = TRUE)

----------------------------------------
  # Probleminės carat reikšmės
  deimantai[
    deimantai$carat <= 0 & !is.na(deimantai$carat),
  ]

# Probleminės y reikšmės
deimantai[
  deimantai$y <= 0 & !is.na(deimantai$y),
]

# Probleminės z reikšmės
deimantai[
  deimantai$z <= 0 & !is.na(deimantai$z),
]

# Visos eilutės, kur bent viena iš šių reikšmių nelogiška
problemines <- deimantai[
  (deimantai$carat <= 0 |
     deimantai$y <= 0 |
     deimantai$z <= 0),
]

problemines
nrow(problemines)

----------------------------
  problemines <- deimantai[
    which(
      deimantai$carat <= 0 |
        deimantai$y <= 0 |
        deimantai$z <= 0
    ),
  ]

nrow(problemines)



