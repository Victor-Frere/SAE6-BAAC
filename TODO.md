# Feuille de route et suivi d'avancement du projet BAAC (R)

Les tâches cochées sont celles déjà réalisées dans le dépôt. Cocher les autres
au fur et à mesure de l'avancement.

## Phase 0 — Initialisation et architecture du projet

### 0.1 Arborescence du projet

- [x] Créer les dossiers `data/raw/`, `data/processed/`, `R/`, `outputs/`
      structurés par script et `report/`
- [x] Initialiser `main.R` et les scripts `R/01_...` à `R/05_...`
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
      `outputs/01_data_cleaning/figures/hist_doublons.png`
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
- [x] Créer les dossiers de sortie `outputs/01_data_cleaning/figures/`,
      `outputs/01_data_cleaning/tables/` et `data/processed/`
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

## Phase 2 — Statistique descriptive univariée et bivariée (selon les 3 Axes)

Script : `R/02_eda_univariate.R`

### 2.1 Règles communes de l'analyse univariée (Partie 1)

- [ ] Identifier le type de chaque variable (quantitative discrète/continue ou qualitative nominale/ordinale) et contrôler les valeurs aberrantes, les effectifs et l'absence de `NA`.
- [ ] Pour chaque variable quantitative, décrire la forme de la distribution avec un histogramme, une densité, un boxplot, l'asymétrie (`skewness`) et l'aplatissement (`kurtosis`).
- [ ] Choisir les paramètres de position et de dispersion selon la symétrie :
  - [ ] Distribution approximativement symétrique : moyenne, écart-type et variance.
  - [ ] Distribution asymétrique ou présence d'extrêmes : médiane, quartiles et écart interquartile (`IQR`).
- [ ] Calculer systématiquement l'étendue (`max - min`), le mode (`collapse::fmode()` ou modalité issue de `table()`), les quantiles (au minimum `Q1`, médiane et `Q3`) et les indicateurs retenus ci-dessus.
- [ ] Pour chaque variable qualitative, calculer les effectifs, fréquences relatives et modalités dominantes ; représenter les résultats par barplot.

### 2.2 Axe 1 : Infrastructures & Typologie des Voies

- [x] Calculer les statistiques descriptives de `vma` (moyenne, médiane, IQR, skewness) selon les types de routes.
- [x] Croiser la gravité (`grav`) avec la catégorie de route (`catr`) et le type d'infrastructure (`infra`, `plan`, `prof`).
- [x] Produire les histogrammes, boxplots croisés et barplots de l'Axe 1 dans `outputs/02_eda_univariate/figures/axe1_infra/`.
- [ ] Appliquer le choix symétrique/asymétrique des indicateurs à `vma` selon `catr` : moyennes/écarts-types/variances si la distribution est symétrique, médianes/quartiles/`IQR` sinon.

### 2.3 Axe 2 : Vulnérabilité des Usagers & Équipements de Sécurité

- [x] Analyser la distribution de l'âge (`age`) et des tranches d'âge (`tranche_age`) par niveau de sévérité (`grav`).
- [x] Mesurer l'effet bivarié de la présence d'équipements de sécurité (`presence_secu`) sur la sévérité des blessures.
- [x] Générer les tables de contingence, profils lignes/colonnes et graphiques associés dans `outputs/02_eda_univariate/figures/axe2_usagers/`.
- [ ] Comparer `age` et `grav` avec les statistiques conditionnelles adaptées : moyennes/écarts-types en cas symétrique, médianes/`IQR` en cas asymétrique.

### 2.4 Axe 3 : Temporalité, Calendrier & Facteurs Exogènes

- [x] Évaluer la survenance et la gravité selon le calendrier (`jours_feries`, `vacances_scolaires`, `jour_semaine`).
- [x] Analyser la distribution horaire (`heure_exacte`) des accidents et la sévérité par tranche horaire.
- [x] Exporter les représentations graphiques temporelles dans `outputs/02_eda_univariate/figures/axe3_temp/`.

### 2.5 Bivarié qualitatif × qualitatif : effectifs, profils et indépendance

- [ ] Pour chaque croisement (`grav` × `catr`, `infra`, `plan`, `prof`, `presence_secu`,
      `jours_feries`, `vacances_scolaires` et `jour_semaine`), construire la table des
      effectifs joints `n_ij`.
- [ ] Calculer les fréquences jointes `f_ij = n_ij / n`, les fréquences marginales
      `f_i.` et `f_.j`, puis les fréquences conditionnelles par lignes
      `f_{j|i}` et par colonnes `f_{i|j}` ; exporter ces tables dans le dossier
      `tables` de l'axe concerné.
- [ ] Représenter chaque liaison par barplots empilés (`position = "fill"`), barplots
      groupés et graphique en mosaïque avec `ggmosaic::geom_mosaic()`, en affichant
      les proportions plutôt que les effectifs bruts lorsque la gravité est comparée.
- [ ] Formuler le test du Chi-2 d'indépendance (`H_0` : les deux variables sont
      indépendantes ; `H_1` : elles sont associées) et conserver la statistique,
      les degrés de liberté, la p-value et la décision au seuil `alpha = 5 %`.
- [ ] Contrôler la condition de validité avec `test$expected` : vérifier les
      effectifs théoriques `>= 5` (et documenter toute cellule insuffisante).
- [ ] Si la condition du Chi-2 n'est pas respectée, basculer explicitement vers
      `fisher.test()` (notamment pour les tables 2 × 2 ou de faible effectif) et
      rapporter la p-value et la décision correspondantes.

### 2.6 Bivarié quantitatif × qualitatif : comparaison de groupes

- [ ] Pour `vma` × `catr` et `age` × `grav`, produire les statistiques
      conditionnelles adaptées : moyenne/écart-type (cas symétrique) ou
      médiane/`IQR` (cas asymétrique), avec effectif de chaque groupe.
- [ ] Suivre l'arbre décisionnel d'inférence de C. Frévent :
  - [ ] Étape 1 — Normalité : examiner les Q-Q plots (`qqnorm`, `qqline`) et appliquer
        Shapiro-Wilk (`shapiro.test`) si `n <= 50`, ou Kolmogorov-Smirnov
        (`ks.test`) si `n > 50`.
  - [ ] Étape 2 — Homoscédasticité : pour deux groupes, appliquer le test de Fisher
        (`var.test`) ; pour plus de deux groupes, appliquer le test de Bartlett
        (`bartlett.test`), en tenant compte de l'hypothèse de normalité.
  - [ ] Étape 3 — Test d'hypothèses : utiliser Student
        (`t.test(..., var.equal = TRUE)`) si les variances sont homogènes, Welch
        (`t.test(..., var.equal = FALSE)` ou `oneway.test`) sinon ; utiliser
        Wilcoxon (`wilcox.test`) si la normalité n'est pas acceptable ; pour plus
        de deux groupes, choisir ANOVA (`aov`) ou Kruskal-Wallis (`kruskal.test`).
- [ ] Formuler `H_0` (égalité des moyennes ou des distributions selon le test) et
      `H_1` (différence), conserver statistique, degrés de liberté, p-value,
      décision à `alpha = 5 %` et, si pertinent, une mesure d'effet.

### 2.7 Bivarié quantitatif × quantitatif : association et corrélation

- [ ] Étudier `age` × `vma`, `age` × `heure_exacte` et les autres couples
      quantitatifs par nuages de points (`scatterplots`), avec droite de tendance
      ou courbe LOESS lorsque cela est pertinent.
- [ ] Calculer la corrélation de Pearson `R` pour mesurer un lien linéaire (données
      quantitatives compatibles avec les hypothèses paramétriques) et la corrélation
      de Spearman `R_S` pour mesurer un lien monotone, plus robuste aux valeurs
      extrêmes et à la non-normalité.
- [ ] Tester la nullité de chaque coefficient avec
      `cor.test(..., method = "pearson")` ou
      `cor.test(..., method = "spearman")`.
- [ ] Formuler `H_0 : rho = 0` (absence de corrélation dans la population) contre
      `H_1 : rho != 0`, rapporter le coefficient, l'intervalle de confiance si
      disponible, la p-value et la décision au seuil `alpha = 5 %`.

## Phase 3 — Analyse spatiale et dépendance spatiale (Focus Axe 1)

Script : `R/03_spatial_analysis.R`

### 3.1 Conversion cartographique & Sémiologie (Partie 5)

- [ ] **Préparation & Exportation des données spatiales**
  - [ ] Filtrer les coordonnées valides (`lat`, `long`) et convertir le dataframe en objet `sf`
  - [ ] Reprojeter en Lambert-93 (`EPSG:2154`) pour la métropole
  - [ ] Agréger par entité géographique (Communes / Départements)
  - [ ] Exporter la couche spatiale sous `data/processed/accidents_spatial.gpkg`
- [ ] **Représentation des Volumes (Sémiologie - Effectifs)**
  - [ ] Cartographier le volume d'accidents par cercles proportionnels (`stat_sf_coordinates(aes(size = ...))`)
  - [ ] Ajuster la taille des cercles pour garantir la lisibilité (`scale_size_continuous(limits = ...)`)
- [ ] **Représentation des Taux & Densités (Sémiologie - Choroplèthe)**
  - [ ] Cartographier le taux de sévérité / gravité par aplats de couleurs (`geom_sf(aes(fill = ...))`)
  - [ ] Appliquer une palette adaptée (`scale_fill_viridis_c(option = "magma", direction = -1)`)
- [ ] **Discrétisation de la variable quantitative**
  - [ ] Déterminer le nombre de classes (règle de Sturges `1 + log2(N)` ou classes métier)
  - [ ] Appliquer la méthode de discrétisation optimale (Quantiles, Jenks ou K-means)
- [ ] **Habillage cartographique réglementaire (`ggspatial`)**
  - [ ] Ajouter la flèche d'orientation (Nord) et l'échelle graphique
  - [ ] Ajouter les repères des grandes villes pour faciliter la localisation

### 3.2 Construction des voisinages et matrices de pondération `W` (Partie 6)

- [ ] **Définition de la structure de voisinage**
  - [ ] Voisinage par contiguïté : construire le graphe contigu Queen / Rook (`spdep::poly2nb(..., queen = TRUE)`)
  - [ ] Voisinage par `k`-plus proches voisins : générer les voisins `k`-NN (`spdep::knearneigh(..., k = 8)` + `knn2nb()`)
  - [ ] Voisinage par distance : fixer un seuil kilométrique (`spdep::dnearneigh(..., d1 = 0, d2 = threshold)`)
- [ ] **Matrice de poids spatiaux `W`**
  - [ ] Standardiser la matrice de voisinage par ligne (`style = "W"`, chaque ligne somme à 1) via `spdep::nb2mat()` et `spdep::nb2listw()`

### 3.3 Tests de dépendance spatiale (Partie 6)

- [ ] **Formulation des hypothèses statistiques**
  - [ ] Poser `H_0` (absence d'autocorrélation spatiale) vs `H_1` (présence d'autocorrélation spatiale)
- [ ] **Test de l'indice `I` de Moran**
  - [ ] Calculer l'indice `I` de Moran global via `spdep::moran.test(x, listw = ..., alternative = "two.sided")`
  - [ ] Interpréter le signe de `I` (`I > 0` : autocorrélation positive/clusters ; `I < 0` : répulsion)
- [ ] **Test du `C` de Geary**
  - [ ] Calculer l'indice `C` de Geary via `spdep::geary.test(x, listw = ..., alternative = "two.sided")`
  - [ ] Interpréter la valeur de `C` (`C < 1` : autocorrélation positive/clusters ; `C > 1` : répulsion)
- [ ] **Décision statistique**
  - [ ] Comparer les p-valeurs obtenues au seuil `alpha = 5 %` et conclure sur la présence de dépendance spatiale

## Phase 4 — Modélisation de la Sévérité & Économétrie

Script : `R/04_modeling_lm.R`

### 5.1 Formulation mathématique & Partitionnement

- [ ] Écrire la formulation théorique explicative de la sévérité (`grave_bin` ou `grav`) en intégrant les covariables des 3 axes
- [ ] Séparer les données en jeu d'entraînement (80 %) et jeu de test (20 %)

### 5.2 Sélection de variables & Inférence

- [ ] Appliquer une procédure stepwise (AIC/BIC) ou Lasso (`glmnet`) sur les prédicteurs des 3 axes
- [ ] Estimer le modèle (Régression Logistique / Ordonnée) et calculer les Odds Ratios associés
- [ ] Quantifier l'effet propre du port d'équipement (Axe 2), de la vitesse/route (Axe 1) et du calendrier (Axe 3)

### 5.3 Diagnostics et réajustements

- [ ] Vérifier l'absence de multicolinéarité (`VIF < 5`)
- [ ] Analyser l'autocorrélation spatiale des résidus du modèle (Test de Moran)
- [ ] Si nécessaire, appliquer un modèle avec erreurs-types robustes ou un modèle Spatial Lag / Spatial Error (`spatialreg`)

## Phase 5 — Évaluation et comparaison des modèles

Script : `R/05_model_eval.R`

### 6.1 Évaluation sur le jeu de test

- [ ] Calculer les métriques de performance sur le jeu de test (Accuracy, AUC, Matrice de confusion, RMSE/MAE si linéaire)

### 6.2 Comparaison avec les modèles de Machine Learning

- [ ] Comparer le modèle économétrique (OLS / Logistique) aux modèles ML (Random Forest, XGBoost)
- [ ] Mesurer l'importance relative des variables explicatives pour identifier quel axe (Infra, Usagers ou Temporalité) explique le mieux la sévérité

## Phase 7 — Rapport et support de soutenance

Dossier : `report/`

Consignes : ne pas utiliser de captures d'écran ; produire des tableaux propres
(HTML, LaTeX ou Markdown avec `gt` / `knitr::kable`), rédiger les équations en
LaTeX et expliciter les hypothèses.

### 7.1 Rapport (`report/report.qmd`)

- [ ] Introduction et problématique générale déclinée selon les 3 axes
- [ ] Restitution synthétique de l'analyse exploratoire et spatiale (Figures 300 dpi, fond blanc)
- [ ] Inférence statistique et résultats des modèles économétriques (Odds Ratios, VIF, diagnostics)
- [ ] Discussion comparative (Économétrie vs Machine Learning) et recommandations de sécurité routière

### 7.2 Support de soutenance (`report/slides.qmd`)

- [ ] Élaborer des diapositives synthétiques et visuelles pour la présentation orale (1 section dédiée à chaque axe d'analyse)
