# Feuille de route et suivi d'avancement du projet BAAC (R)

Les tâches cochées sont celles déjà réalisées dans le dépôt. Cocher les autres
au fur et à mesure de l'avancement.

## Phase 0 — Initialisation et architecture du projet

### 0.1 Arborescence du projet

- [x] Créer les dossiers `data/raw/`, `data/processed/`, `R/`,
      `outputs/figures/`, `outputs/tables/` et `report/`
- [x] Initialiser `main.R` et les scripts `R/01_...` à `R/06_...`
- [x] Configurer `.gitignore` pour exclure les fichiers dans `data/raw/` et
      `data/processed/`

### 0.2 Environnement R

- [ ] Charger ou installer les packages : `tidyverse`, `sf`, `spdep`, `mice`,
      `VIM`, `naniar`, `missForest`, `car`, `lmtest`, `sandwich`, `spatialreg`,
      `performance`, `gtsummary`, `gt`, `quarto` et `knitr`

## Phase 1 — Importation, nettoyage et base analytique

Script : `R/01_data_cleaning.R`

### 1.1 Importation et normalisation

- [x] Importer les quatre tables brutes : `caract-2024.csv`, `lieux-2024.csv`,
      `vehicules-2024.csv` et `usagers-2024.csv`
- [x] Normaliser les noms de colonnes en `snake_case` et importer le
      dictionnaire BAAC `data/raw/Attributs_BAAC_v3.xlsx`
- [x] Afficher les dimensions et un aperçu (`glimpse`) de chaque table
      importée pour contrôler leur structure initiale

### 1.2 Contrôle des identifiants et gestion des doublons

- [x] Vérifier l'unicité de `Num_Acc` dans `caracteristiques` et `lieux`
      (relation 1-à-1)
- [x] Vérifier les clés `Num_Acc` + `id_vehicule` (`Num_Veh`) dans
      `vehicules` (relation 1-à-N)
- [x] Vérifier les clés `Num_Acc` + `id_vehicule` + `id_usager` dans `usagers`
      (relation 1-à-N)
- [x] Détecter et quantifier les doublons sur les clés primaires
- [x] Générer l'histogramme d'audit des doublons :
      `outputs/figures/hist_doublons.png`
- [x] Traiter et supprimer les doublons selon une règle documentée
- [x] Sélectionner automatiquement une clé véhicule de remplacement
      (`id_vehicule` ou `num_veh`) lorsque nécessaire
- [x] Normaliser les clés BAAC et exclure les lignes véhicules/usagers dont
      les clés complètes sont absentes
- [x] Vérifier par assertions que les clés nettoyées sont strictement uniques

### 1.3 Fusion relationnelle

- [x] Fusionner `caracteristiques` et `lieux` (1-à-1)
- [x] Joindre ensuite `vehicules`, puis `usagers`
- [x] Générer un tableau de contrôle de la structure après fusion
      (55 attributs attendus)
- [x] Résoudre les doublons de `lieux` en privilégiant la correspondance
      d'adresse puis la ligne comportant le moins de valeurs manquantes
- [x] Garantir une granularité finale au niveau usager et contrôler les
      relations `many-to-one` lors des jointures
- [x] Afficher le nombre de lignes et d'accidents uniques après fusion

### 1.4 Typage, référentiels et valeurs aberrantes

- [x] Définir les variables catégorielles en facteurs et leurs libellés
      (`agg`, `catr`, `catu`, `catv`, `col`, `atm`, `lum`, `surf`, `grav`, etc.)
- [x] Regrouper les codes BAAC selon les libellés et regroupements métier du
      dictionnaire
- [x] Convertir les mesures importées en texte en variables numériques en
      gérant les virgules décimales et les marqueurs de valeurs manquantes
- [x] Arrêter le traitement et signaler les valeurs non numériques invalides
- [x] Vérifier l'année de naissance : `1900 <= An_nais <= an`
- [x] Vérifier la vitesse maximale autorisée : `20 <= vma <= 130` km/h
- [x] Vérifier les coordonnées : `-51 <= lat <= 52` et
      `-179 <= long <= 173`
- [x] Remplacer par `NA` les années, vitesses et coordonnées hors bornes
- [x] Générer des boxplots de contrôle des valeurs aberrantes
- [x] Créer les dossiers de sortie `outputs/figures/` et `data/processed/`
      s'ils n'existent pas
- [x] Exporter le jeu intermédiaire vers
      `data/processed/dataset_pre_traitement.csv` avec `readr::write_csv2()`

### 1.5 Audit et imputation des valeurs manquantes

- [x] Générer l'histogramme des valeurs manquantes avec
      `naniar::gg_miss_var()`
- [x] Appliquer les règles métiers déterministes avant toute imputation
  - [x] Équipements de sécurité : si `secu1` est connu et `secu2` manquant,
        renseigner `secu2` comme « Aucun »
  - [x] Équipements de sécurité : si `secu2` est renseigné et `secu3` manquant,
        renseigner `secu3` comme « Aucun »
  - [x] Piétons : si `catu != 3`, renseigner `etatp`, `locp` et `actp` comme
        « Non concerné / Aucun »
  - [x] Transports en commun : si `catv` n'est pas un transport en commun,
        renseigner `occutc` comme `0` / « Aucun »
- [x] Exclure `lartpc` avant l'imputation en raison de son volume élevé de
        valeurs manquantes
- [ ] Analyser la structure des valeurs manquantes restantes et leur matrice de
        corrélation
- [x] Limiter les prédicteurs aux variables complètes, non identifiantes et
        catégorielles de moins de 50 modalités
- [x] Encoder les prédicteurs catégoriels en variables indicatrices pour les
        modèles d'imputation
- [x] Imputer les variables qualitatives par KNN avec traitement par lots et
        échantillonnage des donneurs
- [x] Imputer les variables quantitatives par régression avec transformations
        candidates (`brut`, `log_plus_1`, `sqrt`)
- [x] Contrôler les modèles quantitatifs par diagnostics des résidus,
        influence, R² ajusté, test global et homoscédasticité
- [x] Accélérer l'évaluation des régressions volumineuses par sous-échantillon
        et désactiver `step()` lorsque le nombre de prédicteurs est supérieur à 50
- [x] Imputer les valeurs manquantes restantes (régression, MICE, KNN ou
        `missForest`)
- [x] Comparer les distributions avant et après imputation
- [x] Afficher un bilan récapitulatif des imputations et l'exporter en image
- [x] Supprimer les lignes contenant encore des valeurs manquantes après
        l'imputation et vérifier qu'aucun `NA` ne subsiste
- [x] Exporter le jeu imputé vers `data/processed/dataset_imputed.csv` avec
        `readr::write_csv2()`

### 1.6 Construction de la base analytique

- [x] Normaliser `an` sur quatre chiffres et calculer l'âge :
      `Âge = an - An_nais`
- [x] Créer les tranches d'âge : 0–14, 15–24, 25–44, 45–64 et 65+
- [x] Reconstituer la date, l'heure exacte (`hrmn`), la tranche horaire et le
      jour de la semaine en français
- [x] Synthétiser la variable `presence_secu`
- [x] Calculer les jours fériés métropolitains de manière déterministe
- [x] Apparier les périodes nationales de vacances scolaires pour créer
      `vacances_scolaires` (0/1)
- [x] Exporter la base analytique vers
      `data/processed/dataset_analytique_clean.csv` avec `readr::write_csv2()`

Les scripts d'analyse suivants devront importer la base finale avec
`readr::read_csv2(here::here("data", "processed", "dataset_analytique_clean.csv"))`.

## Phase 2 — Statistique descriptive univariée et bivariée

Script : `R/02_eda_univariate.R`

### 2.1 Analyse univariée

- [ ] Variables quantitatives : calculer moyenne, médiane, écart-type, IQR,
      asymétrie et kurtosis
- [ ] Variables qualitatives : calculer effectifs et fréquences relatives
- [ ] Produire histogrammes, densités, boxplots et barplots

### 2.2 Analyse bivariée

- [ ] Quantitatif vs quantitatif : matrice de corrélation Pearson/Spearman et
      nuages de points avec courbes LOESS
- [ ] Qualitatif vs quantitatif : boxplots croisés et moyennes conditionnelles
- [ ] Qualitatif vs qualitatif : tables de contingence et profils lignes/colonnes

## Phase 3 — Analyse spatiale

Script : `R/03_spatial_analysis.R`

### 3.1 Visualisation cartographique

- [ ] Cartographier la variable réponse `Y` avec `sf`, `tmap` ou `ggplot2`
- [ ] Cartographier les principales variables explicatives `X_k`

### 3.2 Tests de dépendance spatiale

- [ ] Construire la matrice de pondération spatiale `W`, normée en ligne
- [ ] Calculer l'indice de Moran global sur la variable réponse `Y`
- [ ] Exécuter le test LISA (Local Indicators of Spatial Association)
- [ ] Cartographier les clusters High-High, Low-Low, High-Low et Low-High

## Phase 4 — Inférence statistique et tests d'hypothèses

Script : `R/04_stat_testing.R`

Pour chaque test, formuler explicitement `H_0` et `H_1`, préciser le nom du
test, sa statistique, sa p-valeur et la décision au seuil `alpha = 5 %`.

### 4.1 Tests entre variables explicatives (`X_i` vs `X_j`)

- [ ] Quantitatif vs quantitatif : test de corrélation de Pearson ou Spearman
- [ ] Qualitatif vs qualitatif : test du chi carré d'indépendance ou test exact
      de Fisher
- [ ] Qualitatif vs quantitatif : test t de Student, ANOVA ou
      Kruskal-Wallis selon les conditions d'application

### 4.2 Tests entre variables explicatives et réponse (`X_k` vs `Y`)

- [ ] Réaliser les tests de liaison bivariée pour présélectionner les variables
      explicatives potentiellement significatives

## Phase 5 — Modélisation par régression linéaire

Script : `R/05_modeling_lm.R`

### 5.1 Formulation mathématique

- [ ] Écrire la formulation théorique :
      `Y_i = beta_0 + sum(beta_j * X_ij) + epsilon_i`, avec
      `epsilon_i iid ~ N(0, sigma^2)`

### 5.2 Partitionnement des données

- [ ] Séparer les données en jeu d'entraînement (80 %) et jeu de test (20 %)

### 5.3 Sélection de variables

- [ ] Appliquer une procédure stepwise (AIC/BIC) ou Lasso (`glmnet`)
- [ ] Filtrer les variables selon les p-valeurs (`p < 0.05`)

### 5.4 Diagnostic des conditions de validité

- [ ] Normalité des résidus : test de Shapiro-Wilk et Q-Q plot
- [ ] Homoscédasticité : test de Breusch-Pagan et graphique résidus vs fitted
- [ ] Absence d'autocorrélation des résidus : test de Durbin-Watson
- [ ] Absence de multicolinéarité : calculer le VIF et vérifier `VIF < 5`
- [ ] Autocorrélation spatiale des résidus : test de Moran sur les résidus

### 5.5 Corrections et réajustements

- [ ] Si nécessaire, appliquer une transformation de Box-Cox ou logarithmique
- [ ] Si nécessaire, utiliser une régression pondérée (WLS) ou des
      erreurs-types robustes HC3 (`sandwich`)
- [ ] Si nécessaire, ajuster un modèle Spatial Lag ou Spatial Error avec
      `spatialreg`

### 5.6 Interprétation du modèle final

- [ ] Interpréter les coefficients `beta_j`, leurs intervalles de confiance et
      leur portée métier

## Phase 6 — Évaluation et comparaison des modèles

Script : `R/06_model_eval.R`

### 6.1 Évaluation sur le jeu de test

- [ ] Calculer RMSE, MAE et R² ajusté

### 6.2 Comparaison avec les modèles de la partie 3

- [ ] Comparer OLS et modèles de machine learning (Random Forest, XGBoost) sur
      le même jeu de test
- [ ] Expliquer les différences de performance : non-linéarités, interactions,
      dépendance spatiale et compromis interprétabilité/prédiction

## Phase 7 — Rapport et support de soutenance

Dossier : `report/`

Consignes : ne pas utiliser de captures d'écran ; produire des tableaux propres
(HTML, LaTeX ou Markdown avec `gt` / `knitr::kable`), rédiger les équations en
LaTeX et expliciter les hypothèses.

### 7.1 Rapport (`report/report.qmd`)

- [ ] Introduction et contexte
- [ ] Analyse exploratoire et prétraitement (graphiques et tableaux propres)
- [ ] Analyse spatiale (cartes et tests de Moran/LISA)
- [ ] Inférence statistique (tableaux récapitulatifs des tests)
- [ ] Modélisation par régression linéaire (formulation, diagnostics,
      corrections et interprétation)
- [ ] Évaluation comparative et discussion (tableau OLS vs ML)
- [ ] Conclusion et perspectives

### 7.2 Support de soutenance (`report/slides.qmd`)

- [ ] Élaborer des diapositives synthétiques et visuelles pour la présentation
      orale
