#A02.csv -> aibė C (kaip branch 2_darbas) -> originali, PCA 5D/2D, t-SNE 5D/2D

library(ggplot2)   
library(dplyr)
library(Rtsne)

SEED <- 42
D_VIDUTINE <- 5
TSNE_PERPLEXITY <- 30
TSNE_ITER <- 1000

OUT <- "aibes"
dir.create(OUT, showWarnings = FALSE)


# --- 1. A02 sutvarkymas (gaunama A aibė) ---

deimantai <- read.csv("A02.csv", na.strings = c(""))

deimantai$price <- as.numeric(gsub("[^0-9.]", "", deimantai$price))
deimantai$depth <- suppressWarnings(as.numeric(deimantai$depth))
deimantai$class <- as.factor(deimantai$class)

# --- Originali bazė validavimui (Ideal + Premium) ---
originalas <- ggplot2::diamonds %>%
  mutate(class = as.character(cut)) %>%
  filter(class %in% c("Ideal", "Premium"))

deimantai_su_id <- deimantai %>%
  mutate(a02_id = row_number())

# --- carat ir y atkūrimas pagal originalią bazę ---
carat_match <- deimantai_su_id %>%
  filter(!is.na(carat) & carat <= 0) %>%
  select(a02_id, depth, table, price, x, y, z, class) %>%
  left_join(
    originalas %>%
      select(depth, table, price, x, y, z, class,
             carat_original = carat),
    by = c("depth", "table", "price", "x", "y", "z", "class")
  )

y_match <- deimantai_su_id %>%
  filter(!is.na(y) & y <= 0) %>%
  select(a02_id, carat, depth, table, price, x, z, class) %>%
  left_join(
    originalas %>%
      select(carat, depth, table, price, x, z, class,
             y_original = y),
    by = c("carat", "depth", "table", "price", "x", "z", "class")
  )

y_match_unique <- y_match %>%
  distinct(a02_id, .keep_all = TRUE)

deimantai$carat[carat_match$a02_id] <- carat_match$carat_original
deimantai$y[y_match_unique$a02_id]  <- y_match_unique$y_original

# --- z = 0 atkūrimas pagal depth formulę: z = depth * (x + y) / 200 ---
i_z0 <- which(deimantai$z <= 0)
deimantai$z[i_z0] <- deimantai$depth[i_z0] *
  (deimantai$x[i_z0] + deimantai$y[i_z0]) / 200

# --- Išvestiniai požymiai ---
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

deimantai$dimension_cv <- apply(
  deimantai[, c("x", "y", "z")],
  1,
  function(v) {
    m <- mean(v)
    sqrt(mean((v - m)^2)) / m
  }
)

# --- depth atkūrimas (tik vienareikšmiai atitikmenys) ---
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

deimantai$table_depth_ratio <- deimantai$table / deimantai$depth

# --- price atkūrimas: vienareikšmiai - tiksli reikšmė, kiti - vidurkis ---
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

price_match_unique <- price_match %>%
  filter(!is.na(price_original)) %>%
  group_by(a02_id) %>%
  filter(n_distinct(price_original) == 1) %>%
  slice(1) %>%
  ungroup()

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

deimantai$price_per_carat  <- deimantai$price / deimantai$carat
deimantai$price_per_volume <- deimantai$price / deimantai$volume_xyz
deimantai$price_per_volume[is.infinite(deimantai$price_per_volume)] <- NA

# --- Likusių NA užpildymas mediana ---
carat_mediana <- median(deimantai$carat, na.rm = TRUE)
depth_mediana <- median(deimantai$depth, na.rm = TRUE)
price_mediana <- median(deimantai$price, na.rm = TRUE)

deimantai$carat[is.na(deimantai$carat)] <- carat_mediana
deimantai$depth[is.na(deimantai$depth)] <- depth_mediana
deimantai$price[is.na(deimantai$price)] <- price_mediana

# --- Galutinis išvestinių požymių perskaičiavimas ---
deimantai$price_per_carat   <- deimantai$price / deimantai$carat
deimantai$table_depth_ratio <- deimantai$table / deimantai$depth
deimantai$carat_per_volume  <- deimantai$carat / deimantai$volume_xyz
deimantai$price_per_volume  <- deimantai$price / deimantai$volume_xyz

deimantai$carat_per_volume[is.infinite(deimantai$carat_per_volume)] <- NA
deimantai$price_per_volume[is.infinite(deimantai$price_per_volume)] <- NA

deimantai$id <- seq_len(nrow(deimantai))

pozymiai_visi <- setdiff(
  names(deimantai)[sapply(deimantai, is.numeric)],
  "id"
)


# --- 2. Aibė C: A be ekstremumų ---
# --- Šalinama eilutė, jei bent viename skaitiniame požymyje ---
# --- reikšmė už [Q1 - 3*IQR ; Q3 + 3*IQR] ---

ar_ekstremumas <- function(x) {
  q <- quantile(x, c(0.25, 0.75), na.rm = TRUE)
  h <- 3 * IQR(x, na.rm = TRUE)
  !is.na(x) & (x < q[1] - h | x > q[2] + h)
}

ekstremumu_matrica <- sapply(deimantai[pozymiai_visi], ar_ekstremumas)
eilutes_su_ekstremumais <- rowSums(ekstremumu_matrica) > 0

deimantai_be_ekstremumu <- deimantai[!eilutes_su_ekstremumais, ]

# --- Robust scaling (x - mediana) / IQR, id ir class nekeičiami ---
robust_scale <- function(df) {
  cols <- setdiff(names(df)[sapply(df, is.numeric)], "id")
  for (col in cols) {
    iqr <- IQR(df[[col]])
    if (iqr == 0) stop(paste("IQR = 0 požymiui:", col))
    df[[col]] <- (df[[col]] - median(df[[col]])) / iqr
  }
  df
}

aibe_C <- robust_scale(deimantai_be_ekstremumu)

pozymiai <- setdiff(names(aibe_C), c("id", "class"))
X <- as.matrix(aibe_C[, pozymiai])
stopifnot(!anyNA(X), all(is.finite(X)))

id <- aibe_C$id
klase <- as.character(aibe_C$class)

# --- Patikra pagal 2 darbo skaidres: C turi būti 3928 objektai ir 19 požymių ---
stopifnot(nrow(X) == 3928, ncol(X) == 19)
cat("Aibė C:", nrow(X), "objektų,", ncol(X), "požymių\n")


# --- 3. PCA ---

pca <- prcomp(X, center = TRUE, scale. = FALSE)
dispersija <- pca$sdev^2 / sum(pca$sdev^2)
disp_lent <- data.frame(komponente = seq_along(dispersija),
                        dispersija = dispersija,
                        kaupiamoji = cumsum(dispersija))
cat(sprintf("PCA: 2 komp. paaiškina %.2f %%, %d komp. - %.2f %%\n",
            100 * disp_lent$kaupiamoji[2], D_VIDUTINE,
            100 * disp_lent$kaupiamoji[D_VIDUTINE]))

pca5 <- pca$x[, 1:D_VIDUTINE, drop = FALSE]
pca2 <- pca$x[, 1:2, drop = FALSE]
colnames(pca5) <- paste0("PC", 1:D_VIDUTINE)
colnames(pca2) <- paste0("PC", 1:2)


# --- 4. t-SNE ---

tsne_paleisti <- function(dims) {
  set.seed(SEED)
  Y <- Rtsne(X, dims = dims, perplexity = TSNE_PERPLEXITY, max_iter = TSNE_ITER,
             pca = FALSE, normalize = FALSE, verbose = TRUE)$Y
  colnames(Y) <- paste0("TSNE", seq_len(dims))
  Y
}
tsne5 <- tsne_paleisti(D_VIDUTINE)  
tsne2 <- tsne_paleisti(2)


# --- 5. Išsaugojimas ---

issaugoti <- function(M, vardas) {
  out <- data.frame(id = id, class = klase, as.data.frame(M))
  write.csv(out, file.path(OUT, paste0(vardas, ".csv")), row.names = FALSE)
}

issaugoti(X,     "aibe_orig")
issaugoti(pca5,  "aibe_pca5")
issaugoti(pca2,  "aibe_pca2")
issaugoti(tsne5, "aibe_tsne5")
issaugoti(tsne2, "aibe_tsne2")

write.csv(disp_lent, file.path(OUT, "pca_dispersija.csv"), row.names = FALSE)
apkrovos <- data.frame(pozymis = rownames(pca$rotation),
                       pca$rotation[, 1:D_VIDUTINE])
write.csv(apkrovos, file.path(OUT, "pca_apkrovos.csv"), row.names = FALSE)

zurnalas <- data.frame(
  parametras = c("aibe", "failas", "objektu", "pozymiu", "ekstremumu_pasalinta",
                 "random_state", "pca_komp_vidutine", "pca_dispersija_2",
                 "pca_dispersija_vidutine", "tsne_perplexity", "tsne_max_iter", "data"),
  reiksme = c("C", "A02.csv", nrow(X), ncol(X), sum(eilutes_su_ekstremumais),
              SEED, D_VIDUTINE, round(disp_lent$kaupiamoji[2], 4),
              round(disp_lent$kaupiamoji[D_VIDUTINE], 4),
              TSNE_PERPLEXITY, TSNE_ITER, as.character(Sys.Date())))
write.csv(zurnalas, file.path(OUT, "paruosimo_zurnalas.csv"), row.names = FALSE)

cat("Paruošta. Failai aplanke:", OUT, "\n")
