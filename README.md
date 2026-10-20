# Analyse statistique et spatiale des donnees BAAC

Ce projet fournit une trame reproductible pour importer, nettoyer, explorer et
analyser statistiquement et spatialement les donnees BAAC, puis evaluer des
modeles de regression lineaire.

## Etat actuel du pipeline

Le script `R/01_data_cleaning.R` execute les etapes suivantes :

1. Import des quatre tables BAAC et du dictionnaire des attributs.
2. Normalisation des noms de colonnes, controle des cles et suppression des
   doublons selon les regles de jointure BAAC.
3. Fusion au niveau usager avec controle de l'integrite relationnelle.
4. Typage des variables, application des libelles BAAC et conversion robuste
   des variables numeriques.
5. Controle des valeurs aberrantes et remplacement des valeurs hors bornes par
   `NA`.
6. Audit des valeurs manquantes, regles metier deterministes, imputation KNN
   des variables qualitatives et imputation par regression des variables
   quantitatives.
7. Suppression finale des lignes contenant encore des valeurs manquantes.
8. Construction de la base analytique : age, tranches d'age, date, heure,
   jour de la semaine, jours feries, vacances scolaires et `presence_secu`.

## Problématiques de recherche et axes d'analyse

### Problématique 1 : Inégalités Territoriales et Typologie des Infrastructures

**Axe Spatial & Infrastructure**

- **Question :** « Dans quelle mesure la gravité d'un accident de la route
  est-elle conditionnée par la typologie de l'infrastructure (`catr`, `vma`,
  `infra`) et sa localisation spatiale (milieu urbain vs rattaché aux grands
  axes routiers) ? »
- **Intérêt académique :** régression logistique ordonnée (prédiction du niveau
  de gravité) et analyse de dépendance spatiale (autocorrélation spatiale I de
  Moran sur les clusters d'accidents graves).

### Problématique 2 : Profils de Vulnérabilité des Usagers et Équipements de Sécurité

**Axe Usagers & PR**

- **Question :** « L'efficacité protectrice des équipements de sécurité
  (`presence_secu`) varie-t-elle de manière significative selon la tranche
  d'âge de l'usager et le mode de déplacement (piéton, deux-roues,
  automobiliste) ? »
- **Intérêt académique :** modèles d'interaction (effets modérateurs) et tests
  de Chi-2 / V de Cramér avancés (réduction du risque relatif de blessure grave
  ou décès).

### Problématique 3 : Temporalité, Calendrier et Facteurs Exogènes

**Axe Temporel & Calendrier**

- **Question :** « Quel est l'effet propre des périodes à haut risque (vacances
  scolaires, jours fériés, conditions nocturnes) sur la survenance et la
  sévérité des accidents à caractéristiques d'usagers constantes ? »
- **Intérêt académique :** modèles de comptage (régression de Poisson /
  binomiale négative par commune/jour) et découpage temporel issu des
  référentiels calendaires.

## Structure

- `data/raw/` : fichiers sources, conserves hors du depot.
- `data/processed/` : donnees nettoyees et intermediaires, conservees hors du depot.
- `R/` : scripts d'analyse, executes dans l'ordre numerique.
- `outputs/<nom_script>/figures/` : figures generees par chaque script.
- `outputs/<nom_script>/tables/` : tableaux et resultats tabulaires de chaque
  script.
- `report/` : rapports et supports de restitution.
- `main.R` : script maitre d'orchestration.

## Fichiers produits par le nettoyage

Le script `R/01_data_cleaning.R` genere notamment :

- `data/processed/dataset_pre_traitement.csv` : donnees apres fusion, typage
  et controle des valeurs aberrantes.
- `data/processed/dataset_imputed.csv` : donnees apres imputation et
  suppression des lignes restant incompletes.
- `data/processed/dataset_analytique_clean.csv` : base finale enrichie avec
  les variables analytiques de la section 1.6.
- `outputs/01_data_cleaning/figures/hist_doublons.png` : audit des doublons.
- `outputs/01_data_cleaning/figures/outliers_check.png` : controle graphique des valeurs
  aberrantes.
- `outputs/01_data_cleaning/figures/miss_var.png` et
  `outputs/01_data_cleaning/figures/miss_var_post_rules.png` : audit des
  valeurs manquantes avant et apres les regles metier.
- `outputs/01_data_cleaning/figures/tableau_bilan_imputation.png` : bilan
  graphique de l'imputation.

## Prerequis et lancement

Installer R, puis les packages utilises par les scripts :

```r
install.packages(c(
  "tidyverse", "janitor", "readxl", "here", "mice", "VIM", "naniar",
  "lmtest", "knitr", "gridExtra", "lubridate"
))
```

Les fichiers sources attendus dans `data/raw/` sont :

- `caract-2024.csv`
- `lieux-2024.csv`
- `vehicules-2024.csv`
- `usagers-2024.csv`
- `Attributs_BAAC_v3.xlsx`

Depuis la racine du projet, lancer :

```r
source("main.R")
```

La base finale peut ensuite etre chargee par les scripts d'analyse avec :

```r
base_analytique <- readr::read_csv2(
  here::here("data", "processed", "dataset_analytique_clean.csv")
)
```

Les etapes d'analyse exploratoire, spatiale, de tests statistiques et de
modelisation sont suivies dans [TODO.md](TODO.md).
