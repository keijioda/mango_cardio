
# Load packages
pacs <- c("tidyverse", "janitor", "readxl")
sapply(pacs, require, character.only = TRUE)

# Read data; n.obs = 231
bm_long <- read_excel("./data/MANCAR_InBody_lab_10132026.xlsx") %>% 
  clean_names()

# Variables
names(bm_long)

# 31 distinct subjects 
n_distinct(bm_long$part_id)

# 3 participants dropped out
# MANCAR17, MANCAR24, MANCAR27
bm_long %>% filter(status == "Dropped") 

# Baseline
bm_long %>% filter(visit == 0) %>% print(n = Inf)
