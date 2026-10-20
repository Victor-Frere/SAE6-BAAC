# Projet d'analyse statistique et spatiale des donnees BAAC
# Script maitre : lance les etapes d'analyse dans leur ordre d'execution.

# --- 1. Configuration ---
options(stringsAsFactors = FALSE)

# --- 2. Orchestration ---
source("R/01_data_cleaning.R")
source("R/02_eda_univariate.R")
source("R/03_spatial_analysis.R")
source("R/04_modeling_lm.R")
source("R/05_model_eval.R")
