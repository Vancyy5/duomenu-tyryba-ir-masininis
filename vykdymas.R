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




