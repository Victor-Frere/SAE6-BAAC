# Import et preparation des donnees BAAC.

# --- 1. Librairies ---
library(tidyverse)
library(janitor)
library(readxl)
library(here)
library(mice)

# --- 1.1 Importation et Normalisation ---

# Importer le dictionnaire pour conserver les définitions initiales des
# variables BAAC.
dict_baac <- readxl::read_excel(
  here::here("data", "raw", "Attributs_BAAC_v3.xlsx")
)

# Les CSV BAAC utilisent le point-virgule comme séparateur. Les noms de
# colonnes sont normalisés immédiatement après chaque import.
caracteristiques_raw <- janitor::clean_names(
  readr::read_csv2(
    here::here("data", "raw", "caract-2024.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    locale = readr::locale(encoding = "UTF-8"),
    show_col_types = FALSE
  )
)

lieux_raw <- janitor::clean_names(
  readr::read_csv2(
    here::here("data", "raw", "lieux-2024.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    locale = readr::locale(encoding = "UTF-8"),
    show_col_types = FALSE
  )
)

vehicules_raw <- janitor::clean_names(
  readr::read_csv2(
    here::here("data", "raw", "vehicules-2024.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    locale = readr::locale(encoding = "UTF-8"),
    show_col_types = FALSE
  )
)

usagers_raw <- janitor::clean_names(
  readr::read_csv2(
    here::here("data", "raw", "usagers-2024.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    locale = readr::locale(encoding = "UTF-8"),
    show_col_types = FALSE
  )
)

# Afficher les dimensions et la structure pour vérifier chaque import.
cat("\ncaracteristiques_raw — dimensions :", paste(dim(caracteristiques_raw), collapse = " x "), "\n")
dplyr::glimpse(caracteristiques_raw)

cat("\nlieux_raw — dimensions :", paste(dim(lieux_raw), collapse = " x "), "\n")
dplyr::glimpse(lieux_raw)

cat("\nvehicules_raw — dimensions :", paste(dim(vehicules_raw), collapse = " x "), "\n")
dplyr::glimpse(vehicules_raw)

cat("\nusagers_raw — dimensions :", paste(dim(usagers_raw), collapse = " x "), "\n")
dplyr::glimpse(usagers_raw)

# %% --- 1.2 Contrôle des Identifiants & Gestion des Doublons ---

# Définir les clés attendues. Pour les tables liées aux véhicules et aux
# usagers, utiliser les identifiants alternatifs si la clé principale manque.
select_available_key <- function(data, alternatives, table_name) {
  available <- Filter(
    function(key_columns) all(key_columns %in% names(data)),
    alternatives
  )

  if (length(available) == 0L) {
    stop(
      "Aucune clé primaire complète n'est disponible pour la table ",
      table_name,
      ". Colonnes présentes : ",
      paste(names(data), collapse = ", "),
      call. = FALSE
    )
  }

  available[[1]]
}

primary_keys <- list(
  caracteristiques_raw = "num_acc",
  lieux_raw = "num_acc",
  vehicules_raw = select_available_key(
    vehicules_raw,
    alternatives = list(
      c("num_acc", "id_vehicule"),
      c("num_acc", "num_veh")
    ),
    table_name = "vehicules_raw"
  ),
  usagers_raw = select_available_key(
    usagers_raw,
    alternatives = list(
      c("num_acc", "id_vehicule", "id_usager"),
      c("num_acc", "num_veh", "id_usager"),
      c("num_veh", "id_usager")
    ),
    table_name = "usagers_raw"
  )
)

raw_tables <- list(
  caracteristiques_raw = caracteristiques_raw,
  lieux_raw = lieux_raw,
  vehicules_raw = vehicules_raw,
  usagers_raw = usagers_raw
)

# Compter les lignes, les clés distinctes et les lignes excédentaires
# partageant une clé avec une autre ligne.
audit_table <- function(data, key_columns, table_name) {
  if (!all(key_columns %in% names(data))) {
    stop("Colonnes de clé absentes dans ", table_name, call. = FALSE)
  }

  unique_key_count <- nrow(
    dplyr::distinct(
      data,
      dplyr::across(dplyr::all_of(key_columns))
    )
  )

  tibble::tibble(
    table = table_name,
    primary_key = paste(key_columns, collapse = " + "),
    total_rows = nrow(data),
    unique_keys = unique_key_count,
    duplicate_rows = nrow(data) - unique_key_count
  )
}

doublons_audit <- purrr::imap_dfr(
  raw_tables,
  function(data, table_name) {
    audit_table(data, primary_keys[[table_name]], table_name)
  }
)

cli::cli_alert_info("Bilan du contrôle des clés primaires :")
print(doublons_audit)

if (any(doublons_audit$duplicate_rows > 0L)) {
  cli::cli_alert_warning(
    paste(
      "Des doublons de clé ont été détectés ; les tables autres que lieux",
      "conserveront la première occurrence, et lieux suivra une règle métier."
    )
  )
} else {
  cli::cli_alert_info("Aucun doublon de clé détecté.")
}

# Le graphique compare, pour chaque table, le nombre de clés uniques au nombre
# de lignes excédentaires correspondant aux doublons détectés.
doublons_plot_data <- doublons_audit |>
  dplyr::select(table, unique_keys, duplicate_rows) |>
  tidyr::pivot_longer(
    cols = c(unique_keys, duplicate_rows),
    names_to = "type_ligne",
    values_to = "nombre"
  ) |>
  dplyr::mutate(
    type_ligne = dplyr::recode(
      type_ligne,
      unique_keys = "Clés uniques",
      duplicate_rows = "Lignes en doublon"
    )
  )

figures_dir <- here::here("outputs", "figures")
if (!dir.exists(figures_dir) &&
    !dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)) {
  stop("Impossible de créer le dossier de sortie : ", figures_dir, call. = FALSE)
}

hist_doublons <- ggplot2::ggplot(
  doublons_plot_data,
  ggplot2::aes(x = table, y = nombre, fill = type_ligne)
) +
  ggplot2::geom_col(position = "stack") +
  ggplot2::labs(
    title = "Audit des identifiants et des doublons par table",
    x = "Table BAAC",
    y = "Nombre de lignes",
    fill = "Type de ligne"
  ) +
  ggplot2::theme_minimal()

ggplot2::ggsave(
  filename = here::here("outputs", "figures", "hist_doublons.png"),
  plot = hist_doublons,
  width = 8,
  height = 5,
  units = "in",
  dpi = 300
)

# Pour les tables autres que lieux, conserver la première occurrence de chaque
# clé primaire dans l'ordre du fichier source.
deduplicate_by_key <- function(data, key_columns) {
  dplyr::distinct(
    data,
    dplyr::across(dplyr::all_of(key_columns)),
    .keep_all = TRUE
  )
}

caracteristiques_clean <- deduplicate_by_key(
  caracteristiques_raw,
  primary_keys$caracteristiques_raw
)

# Enrichir temporairement les lieux avec l'adresse de la table caractéristiques.
# La table caractéristiques est d'abord dédupliquée pour éviter qu'une jointure
# sur num_acc multiplie les lignes de lieux.
if (!all(c("num_acc", "adr") %in% names(caracteristiques_clean))) {
  stop(
    "La table caracteristiques doit contenir les colonnes num_acc et adr.",
    call. = FALSE
  )
}
if (!all(c("num_acc", "voie") %in% names(lieux_raw))) {
  stop("La table lieux doit contenir les colonnes num_acc et voie.", call. = FALSE)
}

lieux_count_initial <- nrow(lieux_raw)
cat("Nombre initial de lignes dans lieux :", lieux_count_initial, "\n")

lieux_enrichi <- lieux_raw |>
  dplyr::left_join(
    caracteristiques_clean |>
      dplyr::select(num_acc, adr),
    by = "num_acc"
  ) |>
  dplyr::mutate(
    match_adr = dplyr::coalesce(
      !is.na(voie) &
        !is.na(adr) &
        stringr::str_squish(stringr::str_to_lower(as.character(voie))) ==
          stringr::str_squish(stringr::str_to_lower(as.character(adr))),
      FALSE
    ),
    nb_na = rowSums(is.na(dplyr::pick(dplyr::everything())))
  )

# Étape 1 : garder, pour chaque accident, les lignes dont l'adresse correspond
# à celle de la table caractéristiques. Les égalités sont conservées pour
# permettre à l'étape suivante de les départager.
lieux_etape_1 <- lieux_enrichi |>
  dplyr::group_by(num_acc) |>
  dplyr::slice_max(order_by = match_adr, n = 1, with_ties = TRUE) |>
  dplyr::ungroup()

cat(
  "Nombre de lignes dans lieux après priorité à la correspondance d'adresse :",
  nrow(lieux_etape_1),
  "\n"
)

# Étape 2 : parmi les égalités, retenir la ligne ayant le moins de valeurs
# manquantes. En cas d'égalité, slice_min(..., with_ties = FALSE) conserve une
# seule ligne et garantit l'unicité stricte de num_acc.
lieux_clean <- lieux_etape_1 |>
  dplyr::group_by(num_acc) |>
  dplyr::slice_min(order_by = nb_na, n = 1, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::select(-adr, -match_adr, -nb_na)

cat("Nombre final de lignes dans lieux après complétion :", nrow(lieux_clean), "\n")
cat(
  "Nombre d'accidents uniques dans lieux_clean :",
  length(unique(lieux_clean$num_acc)),
  "\n"
)

normaliser_cle_baac <- function(x) {
  value <- stringr::str_trim(as.character(x))
  missing_value <- is.na(value) |
    toupper(value) %in% c("", "NA", "N/A", "NULL")
  value[missing_value] <- NA_character_
  value
}

get_vehicle_join_id <- function(data) {
  id_vehicule <- if ("id_vehicule" %in% names(data)) {
    normaliser_cle_baac(data$id_vehicule)
  } else {
    rep(NA_character_, nrow(data))
  }
  num_veh <- if ("num_veh" %in% names(data)) {
    normaliser_cle_baac(data$num_veh)
  } else {
    rep(NA_character_, nrow(data))
  }

  dplyr::coalesce(id_vehicule, num_veh)
}

# Normaliser les identifiants et utiliser num_veh uniquement si id_vehicule
# n'est pas renseigné. Les lignes sans clé complète ne peuvent pas être
# reliées sans ambiguïté ; elles sont retirées explicitement et comptabilisées.
vehicules_clean <- vehicules_raw |>
  dplyr::mutate(
    num_acc = normaliser_cle_baac(num_acc),
    .vehicle_join_id = get_vehicle_join_id(dplyr::pick(dplyr::everything()))
  )
invalid_vehicle_keys <- sum(
  is.na(vehicules_clean$num_acc) | is.na(vehicules_clean$.vehicle_join_id)
)
if (invalid_vehicle_keys > 0L) {
  cli::cli_alert_warning(
    "{invalid_vehicle_keys} lignes véhicules sans clé complète ont été exclues."
  )
}
vehicules_clean <- vehicules_clean |>
  dplyr::filter(!is.na(num_acc), !is.na(.vehicle_join_id)) |>
  dplyr::distinct(num_acc, .vehicle_join_id, .keep_all = TRUE)

usagers_clean <- usagers_raw |>
  dplyr::mutate(
    num_acc = normaliser_cle_baac(num_acc),
    id_usager = normaliser_cle_baac(id_usager),
    .vehicle_join_id = get_vehicle_join_id(dplyr::pick(dplyr::everything()))
  )
invalid_user_keys <- sum(
  is.na(usagers_clean$num_acc) |
    is.na(usagers_clean$.vehicle_join_id) |
    is.na(usagers_clean$id_usager)
)
if (invalid_user_keys > 0L) {
  cli::cli_alert_warning(
    "{invalid_user_keys} lignes usagers sans clé complète ont été exclues."
  )
}
usagers_clean <- usagers_clean |>
  dplyr::filter(
    !is.na(num_acc),
    !is.na(.vehicle_join_id),
    !is.na(id_usager)
  ) |>
  dplyr::distinct(
    num_acc,
    .vehicle_join_id,
    id_usager,
    .keep_all = TRUE
  )

# Vérifier automatiquement que chaque clé est désormais unique.
stopifnot(
  nrow(caracteristiques_clean) ==
    nrow(dplyr::distinct(
      caracteristiques_clean,
      dplyr::across(dplyr::all_of(primary_keys$caracteristiques_raw))
    )),
  nrow(lieux_clean) ==
    nrow(dplyr::distinct(
      lieux_clean,
      dplyr::across(dplyr::all_of(primary_keys$lieux_raw))
    )),
  nrow(vehicules_clean) ==
    nrow(dplyr::distinct(
      vehicules_clean,
      num_acc,
      .vehicle_join_id
    )),
  nrow(usagers_clean) ==
    nrow(dplyr::distinct(
      usagers_clean,
      num_acc,
      .vehicle_join_id,
      id_usager
    ))
)

# %% --- 1.3 Fusion Relationnelle ---

# Construire la table parent des accidents en conservant tous les accidents
# caractéristiques et en vérifiant que lieux ne multiplie pas leurs lignes.
accidents_clean <- dplyr::left_join(
  caracteristiques_clean,
  lieux_clean,
  by = "num_acc",
  relationship = "one-to-one",
  na_matches = "never"
)

stopifnot(
  nrow(accidents_clean) ==
    dplyr::n_distinct(caracteristiques_clean$num_acc)
)

# Les clés d'identification du véhicule sont déjà conservées dans usagers_clean.
# Retirer les copies de ces colonnes du parent véhicules évite les suffixes .x/.y.
vehicules_pour_jointure <- vehicules_clean |>
  dplyr::select(-dplyr::any_of(c("id_vehicule", "num_veh")))

# Construire la table au niveau usager : chaque usager est rattaché à au plus
# un véhicule puis à au plus un accident. Les clés manquantes ne correspondent
# jamais entre elles.
baac_merged <- usagers_clean |>
  dplyr::left_join(
    vehicules_pour_jointure,
    by = c("num_acc", ".vehicle_join_id"),
    relationship = "many-to-one",
    na_matches = "never"
  ) |>
  dplyr::left_join(
    accidents_clean,
    by = "num_acc",
    relationship = "many-to-one",
    na_matches = "never"
  ) |>
  dplyr::select(-.vehicle_join_id)

# Contrôler l'intégrité relationnelle, la granularité usager et le nombre
# d'attributs attendu d'après le dictionnaire BAAC.
stopifnot(
  nrow(baac_merged) == nrow(usagers_clean),
  ncol(baac_merged) == 55L
)

cli::cli_alert_success(
  "Fusion BAAC terminée : {dplyr::n_distinct(baac_merged$num_acc)} accidents uniques."
)
cli::cli_inform(
  "Véhicules uniques : {nrow(vehicules_clean)}"
)
cli::cli_inform(
  "Usagers dans la table finale : {nrow(baac_merged)} lignes."
)

# %% --- 1.4 Typage, Référentiels & Valeurs Aberrantes ---

# Appliquer les libellés BAAC aux codes des variables catégorielles. Les codes
# qui ne sont pas indiqués dans les mappings deviennent NA plutôt que de recevoir
# un libellé incorrect.
appliquer_labels <- function(df, col, codes, labels) {
  if (col %in% names(df)) {
    df[[col]] <- factor(
      as.character(df[[col]]),
      levels = as.character(codes),
      labels = labels
    )
  }
  return(df)
}

codes_secu <- c(0, 1, 2, 3, 4, 5, 6, 7, 9)
labels_secu <- c(
  "Aucun équipement", "Ceinture", "Casque", "Dispositif enfants",
  "Gilet réfléchissant", "Airbag (2RM/3RM)", "Gants (2RM/3RM)",
  "Gants + Airbag (2RM/3RM)", "Autre"
)

modalites_baac <- list(
  lum = list(
    codes = c(1, 2, 3, 4, 5),
    labels = c(
      "Plein jour", "Crépuscule ou aube", "Nuit sans éclairage",
      "Nuit sans éclairage", "Nuit avec éclairage public allumé"
    )
  ),
  agg = list(
    codes = c(1, 2),
    labels = c("Hors agglomération", "En agglomération")
  ),
  int = list(
    codes = 1:9,
    labels = c(
      "Hors intersection", "Intersection 4 branches ou +",
      "Intersection 3 branches", "Intersection 3 branches",
      "Intersection 4 branches ou +", "Giratoire", "Autre intersection",
      "Autre intersection", "Autre intersection"
    )
  ),
  atm = list(
    codes = 1:9,
    labels = c(
      "Normale", "Pluie légère", "Route modifiée", "Route modifiée",
      "Visibilité altérée", "Autre", "Visibilité altérée", "Temps couvert",
      "Autre"
    )
  ),
  col = list(
    codes = 1:7,
    labels = c(
      "Deux véhicules - frontale", "Deux véhicules - par l'arrière",
      "Deux véhicules - par le coté", "Trois véhicules et plus - en chaîne",
      "Trois véhicules et plus - collisions multiples", "Autre collision",
      "Sans collision"
    )
  ),
  catr = list(
    codes = c(1, 2, 3, 4, 5, 6, 7, 9),
    labels = c(
      "Autoroute", "Route nationale", "Route Départementale",
      "Voie Communales", "Autre", "Autre", "Routes de métropole urbaine",
      "Autre"
    )
  ),
  circ = list(
    codes = 1:4,
    labels = c(
      "A sens unique", "Bidirectionnelle", "A chaussées séparées",
      "Avec voies d'affectation variable"
    )
  ),
  vosp = list(
    codes = 0:3,
    labels = c("Sans objet", "Piste cyclable", "Bande cyclable", "Voie réservée")
  ),
  prof = list(
    codes = 1:4,
    labels = c("Plat", "Pente", "Côte", "Côte")
  ),
  plan = list(
    codes = 1:4,
    labels = c(
      "Partie rectiligne", "En courbe à gauche", "En courbe à droite", "En « S »"
    )
  ),
  surf = list(
    codes = 1:9,
    labels = c("Normale", rep("Surface modifiée", 8))
  ),
  infra = list(
    codes = 0:9,
    labels = c(
      "Aucun", "Souterrain - Pont", "Souterrain - Pont", "Autres", "Autres",
      "Carrefour aménagé", "Autres", "Autres", "Chantier", "Autres"
    )
  ),
  situ = list(
    codes = c(0, 1, 2, 3, 4, 5, 6, 8),
    labels = c(
      "Aucun", "Sur chaussée", "Sur accotement", "Sur accotement",
      "Sur trottoir", "Sur piste cyclable", "Sur autre voie spéciale", "Autres"
    )
  ),
  senc = list(
    codes = 1:3,
    labels = c("Sens croissant", "Sens décroissant", "Absence de repère")
  ),
  catv = list(
    codes = c(
      1:21, 30:43, 50, 60, 80, 99
    ),
    labels = c(
      "Vélo", "< 50 cm3", "Autre véhicule", "Scooter immatriculé (inutilisé)",
      "Motocyclette (inutilisé)", "Side-car (inutilisé)", "Véhicule léger seul",
      "VL + caravane (inutilisé)", "VL + remorque (inutilisé)",
      "Véhicule utilitaire", "VU + caravane (inutilisé)",
      "VU + remorque (inutilisé)", "Poids Lourd", "Poids Lourd", "Poids Lourd",
      "Tracteur", "Tracteur", "Transport en commun (inutilisé)",
      "Tramway (inutilisé)", "Autre véhicule", "Tracteur", "< 50 cm3",
      "> 50 cm3 et <= 125 cm3", "> 50 cm3 et <= 125 cm3",
      "> 125 cm3", "> 125 cm3", "< 50 cm3", "> 50 cm3",
      "Transport commun", "Transport commun", "Transport commun",
      "Transport commun", "< 50 cm3", "> 50 cm3 et <= 125 cm3",
      "> 125 cm3", "EDP", "EDP", "Vélo", "Autre véhicule"
    )
  ),
  obs = list(
    codes = 0:17,
    labels = c(
      "Sans obstacle", "Véhicule en stationnement", "Arbre", "Glissière",
      "Glissière", "Glissière", "Bâtiment, mur, pile de pont", "Poteau",
      "Poteau", "Autre obstacle fixe", "Autre obstacle fixe", "Muret",
      "Autre obstacle fixe", "Fossé, talus, paroi rocheuse", "Muret",
      "Autre obstacle fixe", "Sans obstacle", "Muret"
    )
  ),
  obsm = list(
    codes = c(0, 1, 2, 4, 5, 6, 9),
    labels = c("Aucun", "Piéton", "Véhicule", "Véhicule", "Autre", "Autre", "Autre")
  ),
  choc = list(
    codes = 0:9,
    labels = c(
      "Aucun", "Avant", "Avant droit", "Avant gauche", "Arrière",
      "Arrière droit", "Arrière gauche", "Côté droit", "Côté gauche",
      "Chocs multiples (tonneaux)"
    )
  ),
  manv = list(
    codes = 1:26,
    labels = c(
      "Sans changement de direction", "Même sens, même file", "Entre 2 files",
      "En marche arrière", "À contresens", "En franchissant le terre-plein central",
      "Dans le couloir bus, dans le même sens",
      "Dans le couloir bus, dans le sens inverse", "En s'insérant",
      "En faisant demi-tour sur la chaussée", "Changeant de file à gauche",
      "Changeant de file à droite", "Déporté à gauche", "Déporté à droite",
      "Tournant à gauche", "Tournant à droite", "Dépassant à gauche",
      "Dépassant à droite", "Traversant la chaussée",
      "Manœuvre de stationnement", "Manœuvre d'évitement", "Ouverture de porte",
      "Arrêté (hors stationnement)", "En stationnement (avec occupants)",
      "Circulant sur trottoir", "Autres manœuvres"
    )
  ),
  motor = list(
    codes = 1:6,
    labels = c(
      "Hydrocarbures", "Hybride électrique", "Electrique", "Autre", "Humaine",
      "Autre"
    )
  ),
  place = list(
    codes = 1:10,
    labels = c(
      "Place 1 (Conducteur)", paste("Place", 2:9),
      "Piéton (non applicable)"
    )
  ),
  catu = list(
    codes = 1:3,
    labels = c("Conducteur", "Passager", "Piéton")
  ),
  grav = list(
    codes = 1:4,
    labels = c("Indemne", "Tué", "Blessé hospitalisé", "Blessé léger")
  ),
  sexe = list(
    codes = 1:2,
    labels = c("Masculin", "Féminin")
  ),
  trajet = list(
    codes = c(1, 2, 3, 4, 5, 9),
    labels = c(
      "Domicile - travail", "Domicile - école", "Courses - achats",
      "Utilisation professionnelle", "Promenade - loisirs", "Autre"
    )
  ),
  secu1 = list(codes = codes_secu, labels = labels_secu),
  secu2 = list(codes = codes_secu, labels = labels_secu),
  secu3 = list(codes = codes_secu, labels = labels_secu),
  locp = list(
    codes = 0:8,
    labels = c(
      "Sans objet", "A + 50 m du passage piéton",
      "A - 50 m du passage piéton", "Sans signalisation lumineuse",
      "Avec signalisation lumineuse", "Sur trottoir", "Sur accotement",
      "Sur refuge ou BAU", "Sur contre allée"
    )
  ),
  actp = list(
    codes = c("1", "2", "3", "4", "5", "6", "9", "A"),
    labels = c(
      "Sens véhicule heurtant", "Sens inverse du véhicule", "Traversant",
      "Masqué", "Jouant - courant", "Avec animal", "Autre",
      "Monte/descend du véhicule"
    )
  ),
  etatp = list(
    codes = 1:3,
    labels = c("Seul", "Accompagné", "En groupe")
  )
)

for (column_name in names(modalites_baac)) {
  modalite <- modalites_baac[[column_name]]
  baac_merged <- appliquer_labels(
    baac_merged,
    column_name,
    modalite$codes,
    modalite$labels
  )
}

# Toutes les colonnes de cette liste sont converties en facteurs ; les
# mappings ci-dessus fournissent leurs libellés et regroupements de modalités.
categorical_columns <- names(modalites_baac)

# Ces mesures sont importées en texte afin de préserver les valeurs sources.
# La conversion utilise la virgule comme séparateur décimal des fichiers BAAC.
numeric_columns <- c(
  "lat", "long", "larrout", "lartpc", "vma", "an", "an_nais", "jour",
  "mois", "occutc", "nbv", "pr", "pr1"
)

required_typed_columns <- c(categorical_columns, numeric_columns)
missing_typed_columns <- setdiff(required_typed_columns, names(baac_merged))
if (length(missing_typed_columns) > 0L) {
  stop(
    "Colonnes BAAC attendues absentes de baac_merged : ",
    paste(missing_typed_columns, collapse = ", "),
    call. = FALSE
  )
}

parse_baac_numeric <- function(x, column_name) {
  values <- stringr::str_trim(as.character(x))
  missing_values <- is.na(values) |
    toupper(values) %in% c("", "NA", "N/A", "NULL", "#VALEURMULTI")
  values[missing_values] <- NA_character_
  values <- stringr::str_replace_all(values, "[\\s\\u00a0\\u202f]", "")

  parsed <- suppressWarnings(
    readr::parse_number(
      values,
      locale = readr::locale(decimal_mark = ",", grouping_mark = ".")
    )
  )
  invalid_values <- !missing_values & is.na(parsed)

  if (any(invalid_values)) {
    examples <- unique(values[invalid_values])
    stop(
      "Valeurs non numériques dans la colonne ",
      column_name,
      " : ",
      paste(utils::head(examples, 5L), collapse = ", "),
      call. = FALSE
    )
  }

  parsed
}

baac_typed <- baac_merged |>
  dplyr::mutate(
    dplyr::across(
      dplyr::all_of(categorical_columns),
      ~ if (is.factor(.x)) {
        .x
      } else {
        factor(stringr::str_trim(as.character(.x)))
      }
    ),
    dplyr::across(
      dplyr::all_of(numeric_columns),
      ~ parse_baac_numeric(.x, dplyr::cur_column())
    )
  )

# Sauvegarder les distributions avant filtrage afin que les valeurs extrêmes
# puissent être examinées dans les boxplots de contrôle.
outlier_columns <- c("vma", "an_nais", "larrout")
outliers_plot_data <- baac_typed |>
  dplyr::select(dplyr::all_of(outlier_columns)) |>
  tidyr::pivot_longer(
    cols = dplyr::everything(),
    names_to = "variable",
    values_to = "valeur"
  )

outliers_check <- ggplot2::ggplot(
  outliers_plot_data,
  ggplot2::aes(x = variable, y = valeur)
) +
  ggplot2::geom_boxplot(na.rm = TRUE) +
  ggplot2::facet_wrap(~ variable, scales = "free_y") +
  ggplot2::labs(
    title = "Contrôle des valeurs aberrantes avant filtrage",
    x = NULL,
    y = "Valeur"
  ) +
  ggplot2::theme_minimal() +
  ggplot2::theme(axis.text.x = ggplot2::element_blank())

figures_dir <- here::here("outputs", "figures")
processed_dir <- here::here("data", "processed")
for (output_dir in c(figures_dir, processed_dir)) {
  if (!dir.exists(output_dir) &&
      !dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)) {
    stop("Impossible de créer le dossier de sortie : ", output_dir, call. = FALSE)
  }
}

ggplot2::ggsave(
  filename = here::here("outputs", "figures", "outliers_check.png"),
  plot = outliers_check,
  width = 8,
  height = 5,
  units = "in",
  dpi = 300
)

# Remplacer par NA les années de naissance, vitesses et coordonnées hors des
# bornes métier indiquées par le dictionnaire BAAC.
baac_typed <- baac_typed |>
  dplyr::mutate(
    an_nais = dplyr::if_else(
      !is.na(an_nais) & !is.na(an) & dplyr::between(an_nais, 1900, an),
      an_nais,
      NA_real_
    ),
    vma = dplyr::if_else(
      !is.na(vma) & dplyr::between(vma, 20, 130),
      vma,
      NA_real_
    ),
    lat = dplyr::if_else(
      !is.na(lat) & dplyr::between(lat, -51, 52),
      lat,
      NA_real_
    ),
    long = dplyr::if_else(
      !is.na(long) & dplyr::between(long, -179, 173),
      long,
      NA_real_
    )
  )

readr::write_csv2(
  baac_typed,
  here::here("data", "processed", "dataset_pre_traitement.csv")
)
cli::cli_alert_success(
  "Dataset pré-traité sauvegardé dans data/processed/dataset_pre_traitement.csv."
)

# %% --- 1.5 Audit et Imputation des Valeurs Manquantes ---

if (!requireNamespace("naniar", quietly = TRUE)) {
  stop("Le package 'naniar' est requis pour l'audit des valeurs manquantes.",
       call. = FALSE)
}
if (!requireNamespace("VIM", quietly = TRUE)) {
  stop("Le package 'VIM' est requis pour l'imputation KNN des variables qualitatives.",
       call. = FALSE)
}
if (!requireNamespace("lmtest", quietly = TRUE)) {
  stop("Le package 'lmtest' est requis pour les tests des résidus.",
       call. = FALSE)
}
if (!requireNamespace("knitr", quietly = TRUE)) {
  stop("Le package 'knitr' est requis pour afficher le bilan des imputations.",
       call. = FALSE)
}
if (!requireNamespace("gridExtra", quietly = TRUE)) {
  stop("Le package 'gridExtra' est requis pour exporter le bilan des imputations.",
       call. = FALSE)
}

# Produire un audit graphique initial avant l'application des règles métiers.
miss_var_plot <- naniar::gg_miss_var(baac_typed) +
  ggplot2::labs(
    title = "Valeurs manquantes par variable",
    x = "Variable",
    y = "Nombre de valeurs manquantes"
  ) +
  ggplot2::theme_minimal()

ggplot2::ggsave(
  filename = here::here("outputs", "figures", "miss_var.png"),
  plot = miss_var_plot,
  width = 8,
  height = 6,
  units = "in",
  dpi = 300
)

# Variables textuelles et identifiants à conserver en chaînes de caractères.
text_vars_to_skip <- c(
  "num_acc", "id_vehicule", "id_usager", "adr", "voie", "v1", "v2",
  "pr", "pr1", "dep", "com", "hrmn", "lat", "long"
)

# Nettoyer toutes les chaînes puis convertir uniquement les qualitatives
# résiduelles non identifiantes en facteurs.
baac_typed <- baac_typed |>
  dplyr::mutate(
    dplyr::across(where(is.character), stringr::str_trim),
    dplyr::across(
      where(is.character) & !dplyr::any_of(text_vars_to_skip),
      factor
    )
  )

# Ajouter une modalité métier si elle n'existe pas encore dans le facteur.
set_factor_value <- function(data, column, rows, value) {
  if (!column %in% names(data)) {
    return(data)
  }

  if (is.factor(data[[column]])) {
    data[[column]] <- forcats::fct_expand(data[[column]], value)
  }
  data[[column]][rows] <- value
  data
}

na_before_business_rules <- sum(is.na(baac_typed))

# Si au moins un équipement est renseigné, les autres champs de sécurité
# manquants signifient « Aucun équipement ». Trois NA restent inchangés.
if (all(c("secu1", "secu2", "secu3") %in% names(baac_typed))) {
  security_columns <- c("secu1", "secu2", "secu3")
  security_values <- lapply(
    baac_typed[security_columns],
    as.character
  )
  any_security_reported <- Reduce(
    `|`,
    lapply(security_values, function(values) !is.na(values))
  )

  for (column in security_columns) {
    values <- security_values[[column]]
    values[any_security_reported & is.na(values)] <- "Aucun équipement"
    baac_typed[[column]] <- factor(values, levels = labels_secu)
  }
}

# Les variables relatives aux piétons ne s'appliquent pas aux autres usagers.
if ("catu" %in% names(baac_typed)) {
  not_pedestrian <- !is.na(baac_typed$catu) &
    as.character(baac_typed$catu) != "Piéton"

  for (column in c("etatp", "locp", "actp")) {
    if (column %in% names(baac_typed)) {
      baac_typed <- set_factor_value(
        baac_typed,
        column,
        not_pedestrian,
        "Sans objet"
      )
    }
  }
}

# occutc vaut zéro pour les véhicules qui ne sont pas des transports en commun.
if (all(c("catv", "occutc") %in% names(baac_typed))) {
  not_public_transport <- !is.na(baac_typed$catv) &
    as.character(baac_typed$catv) != "Transport commun"
  baac_typed$occutc[
    not_public_transport
  ] <- 0
}

# Contrôler l'effet des règles métiers sur les valeurs manquantes.
na_after_business_rules <- sum(is.na(baac_typed))
na_eliminated_by_business_rules <- na_before_business_rules -
  na_after_business_rules
cli::cli_inform(
  "Nombre total de NA éliminés par les règles métiers : {na_eliminated_by_business_rules}"
)

# lartpc comporte un volume extrême de valeurs manquantes et est exclue
# du jeu analytique avant l'audit post-règles et l'imputation.
if ("lartpc" %in% names(baac_typed)) {
  baac_typed <- dplyr::select(baac_typed, -lartpc)
  cli::cli_inform(
    "Variable lartpc supprimée avant imputation en raison de son volume élevé de valeurs manquantes."
  )
}

miss_var_post_rules_plot <- naniar::gg_miss_var(baac_typed) +
  ggplot2::labs(
    title = "Répartition des valeurs manquantes après règles métiers déterministes",
    x = "Variable",
    y = "Nombre de valeurs manquantes"
  ) +
  ggplot2::theme_minimal()

ggplot2::ggsave(
  filename = here::here(
    "outputs",
    "figures",
    "miss_var_post_rules.png"
  ),
  plot = miss_var_post_rules_plot,
  width = 8,
  height = 6,
  units = "in",
  dpi = 300
)

baac_post_rules <- baac_typed
df_pre_imputation <- baac_post_rules

# Les identifiants et variables textuelles exclues ne sont jamais des cibles Y.
vars_to_impute <- baac_post_rules |>
  dplyr::summarise(
    dplyr::across(everything(), ~ sum(is.na(.x)))
  ) |>
  tidyr::pivot_longer(
    cols = everything(),
    names_to = "var",
    values_to = "n_na"
  ) |>
  dplyr::filter(
    n_na > 0L,
    !var %in% text_vars_to_skip
  ) |>
  dplyr::arrange(n_na) |>
  dplyr::pull(var)

# Alias conservé pour les diagnostics et la boucle d'imputation existants.
variables_to_impute <- vars_to_impute

# Construire un encodage one-hot complet sur les prédicteurs disponibles.
build_predictor_matrix <- function(data, predictors) {
  if (length(predictors) == 0L) {
    return(matrix(numeric(), nrow = nrow(data), ncol = 0L))
  }

  predictor_data <- as.data.frame(data[predictors], check.names = FALSE)
  logical_columns <- names(predictor_data)[
    vapply(predictor_data, is.logical, logical(1))
  ]
  for (column in logical_columns) {
    predictor_data[[column]] <- factor(predictor_data[[column]])
  }
  factor_columns <- names(predictor_data)[
    vapply(predictor_data, is.factor, logical(1))
  ]
  predictor_data[factor_columns] <- lapply(
    predictor_data[factor_columns],
    droplevels
  )

  non_constant <- vapply(
    predictor_data,
    function(values) dplyr::n_distinct(values) > 1L,
    logical(1)
  )
  predictor_data <- predictor_data[, non_constant, drop = FALSE]
  if (ncol(predictor_data) == 0L) {
    return(matrix(numeric(), nrow = nrow(data), ncol = 0L))
  }

  factor_columns <- names(predictor_data)[
    vapply(predictor_data, is.factor, logical(1))
  ]
  full_one_hot_contrasts <- lapply(
    predictor_data[factor_columns],
    stats::contrasts,
    contrasts = FALSE
  )
  predictor_matrix <- stats::model.matrix(
    ~ . - 1,
    data = predictor_data,
    contrasts.arg = full_one_hot_contrasts
  )
  storage.mode(predictor_matrix) <- "double"
  predictor_matrix
}

# KNN utilise les mêmes prédicteurs numériques one-hot que la régression.
impute_factor_knn <- function(values, predictor_matrix, missing_rows) {
  donors <- which(!missing_rows)
  recipients <- which(missing_rows)
  if (length(donors) == 0L) {
    stop("Aucune valeur observée disponible pour l'imputation KNN.", call. = FALSE)
  }
  if (ncol(predictor_matrix) == 0L) {
    cli::cli_alert_danger(
      "Imputation KNN impossible : aucun prédicteur complet et variable n'est disponible."
    )
    return(values)
  }

  max_donors <- 2500L
  set.seed(2026L)
  donor_sample <- if (length(donors) > max_donors) {
    sample(donors, max_donors)
  } else {
    donors
  }
  recipient_batches <- split(
    recipients,
    ceiling(seq_along(recipients) / 500L)
  )
  imputed_values <- values
  predictor_names <- colnames(predictor_matrix)

  for (batch in recipient_batches) {
    work_rows <- c(donor_sample, batch)
    knn_data <- data.frame(
      .target = values[work_rows],
      predictor_matrix[work_rows, , drop = FALSE],
      check.names = FALSE
    )
    knn_result <- VIM::kNN(
      knn_data,
      variable = ".target",
      dist_var = predictor_names,
      k = min(5L, length(donor_sample)),
      imp_var = FALSE
    )
    batch_positions <- length(donor_sample) + seq_along(batch)
    batch_values <- knn_result$.target[batch_positions]
    if (anyNA(batch_values)) {
      stop("KNN n'a pas imputé toutes les valeurs qualitatives.", call. = FALSE)
    }
    imputed_values[batch] <- batch_values
  }

  imputed_values
}

fit_regression_remedy <- function(
    target_values,
    predictor_matrix,
    observed_rows,
    transformation
) {
  response_values <- switch(
    transformation,
    brut = target_values,
    log_plus_1 = log(target_values + 1),
    sqrt = sqrt(target_values)
  )
  train_data <- data.frame(
    .target = response_values[observed_rows],
    predictor_matrix[observed_rows, , drop = FALSE],
    check.names = FALSE
  )
  n_obs <- nrow(train_data)
  p_vars <- ncol(predictor_matrix)
  sample_idx <- if (n_obs > 15000L) {
    set.seed(2026L)
    sample.int(n_obs, 15000L)
  } else {
    seq_len(n_obs)
  }
  sample_data <- train_data[sample_idx, , drop = FALSE]
  sample_model <- tryCatch(
    stats::lm(.target ~ ., data = sample_data),
    error = function(error) NULL
  )
  if (is.null(sample_model)) {
    return(NULL)
  }

  leverage <- stats::hatvalues(sample_model)
  cooks_distance <- stats::cooks.distance(sample_model)
  p <- sample_model$rank
  n <- stats::nobs(sample_model)
  influential_rows <- leverage > 2 * p / n | cooks_distance > 1
  influential_rows[is.na(influential_rows)] <- FALSE
  clean_sample_data <- sample_data[!influential_rows, , drop = FALSE]
  influential_indices <- sample_idx[influential_rows]
  clean_data <- train_data[
    !(seq_len(n_obs) %in% influential_indices),
    ,
    drop = FALSE
  ]
  if (nrow(clean_data) <= ncol(predictor_matrix) + 10L) {
    return(NULL)
  }

  selected_sample_model <- if (p_vars > 50L) {
    sample_model
  } else {
    tryCatch(
      stats::step(
        stats::lm(.target ~ ., data = clean_sample_data),
        scope = list(
          lower = ~1,
          upper = ~.
        ),
        direction = "both",
        trace = 0
      ),
      error = function(error) NULL
    )
  }
  if (is.null(selected_sample_model)) {
    selected_sample_model <- sample_model
  }
  selected_model <- tryCatch(
    stats::lm(
      stats::formula(selected_sample_model),
      data = clean_data
    ),
    error = function(error) NULL
  )
  if (is.null(selected_model)) {
    return(NULL)
  }

  model_summary <- summary(selected_model)
  f_statistic <- model_summary$fstatistic
  global_f_p <- if (is.null(f_statistic)) {
    NA_real_
  } else {
    stats::pf(
      f_statistic[[1]],
      f_statistic[[2]],
      f_statistic[[3]],
      lower.tail = FALSE
    )
  }
  residuals <- stats::rstandard(selected_model)
  n_residuals <- length(residuals)
  normality_test <- tryCatch(
    if (n_residuals <= 50L) {
      stats::shapiro.test(residuals)
    } else {
      suppressWarnings(
        stats::ks.test(
          jitter(residuals),
          "pnorm",
          mean(residuals),
          stats::sd(residuals)
        )
      )
    },
    error = function(error) NULL
  )
  homoscedasticity_test <- tryCatch(
    lmtest::bptest(selected_model),
    error = function(error) NULL
  )
  normality_p <- if (is.null(normality_test)) {
    NA_real_
  } else {
    unname(normality_test$p.value)
  }
  homoscedasticity_p <- if (is.null(homoscedasticity_test)) {
    NA_real_
  } else {
    unname(homoscedasticity_test$p.value)
  }
  adjusted_r_squared <- model_summary$adj.r.squared
  valid <- is.finite(global_f_p) &&
    global_f_p < 0.05 &&
    is.finite(adjusted_r_squared) &&
    adjusted_r_squared >= 0.10 &&
    is.finite(normality_p) &&
    normality_p >= 0.05 &&
    is.finite(homoscedasticity_p) &&
    homoscedasticity_p >= 0.05

  list(
    model = selected_model,
    transformation = transformation,
    valid = valid,
    adjusted_r_squared = adjusted_r_squared,
    influential_count = sum(influential_rows)
  )
}

df_imputed <- df_pre_imputation
bilan_imputation <- list()
# Les mêmes variables brutes sont exclues des prédicteurs X.
excluded_predictors <- text_vars_to_skip

# Libérer explicitement les objets potentiellement volumineux créés pendant
# une itération, y compris lorsque la branche se termine par next().
cleanup_imputation_iteration <- function() {
  iteration_objects <- c(
    "target", "n_na_cnt", "missing_rows", "complete_predictors",
    "predictor_matrix",
    "na_treated", "observed_rows", "transformations", "target_values",
    "candidate_results", "valid_results", "selected_result",
    "missing_data", "predictions", "response_values", "train_data",
    "model", "clean_data", "clean_model", "selected_model",
    "model_summary", "f_statistic", "residuals", "normality_test",
    "homoscedasticity_test", "na_initial", "type_target",
    "methode_retenue", "adjusted_r_squared", "detail_imputation"
  )
  caller_environment <- parent.frame()
  rm(
    list = intersect(iteration_objects, ls(envir = caller_environment)),
    envir = caller_environment
  )
  gc(verbose = FALSE)
}

for (var_target in vars_to_impute) {
  target <- var_target
  missing_rows <- is.na(df_imputed[[target]])
  n_na_cnt <- sum(missing_rows)
  cli::cli_alert_info("Début traitement : {var_target} ({n_na_cnt} NA)...")
  na_initial <- n_na_cnt
  type_target <- if (is.factor(df_imputed[[target]])) {
    "Qualitative"
  } else if (is.numeric(df_imputed[[target]]) ||
             is.integer(df_imputed[[target]])) {
    "Quantitative"
  } else {
    "Non pris en charge"
  }
  methode_retenue <- if (type_target == "Qualitative") {
    "KNN"
  } else {
    "Régression Linéaire"
  }
  adjusted_r_squared <- NA_real_
  detail_imputation <- ""

  if (!any(!missing_rows)) {
    if (is.factor(df_imputed[[target]])) {
      cli::cli_alert_danger(
        "Imputation KNN impossible pour {var_target} : aucune valeur observée."
      )
    } else {
      cli::cli_alert_danger(
        "Régression linéaire impossible pour {var_target}"
      )
    }
    detail_imputation <- "Aucune valeur observée; variable non imputée."
    bilan_imputation[[length(bilan_imputation) + 1L]] <- list(
      var = var_target,
      type = type_target,
      methode = methode_retenue,
      nb_na_traites = 0L,
      r2_ajuste = adjusted_r_squared,
      detail = detail_imputation
    )
    cleanup_imputation_iteration()
    next
  }

  complete_predictors <- names(df_imputed)[
    vapply(df_imputed, function(values) !anyNA(values), logical(1))
  ]
  complete_predictors <- setdiff(
    complete_predictors,
    c(target, excluded_predictors)
  )
  complete_predictors <- complete_predictors[
    vapply(
      df_imputed[complete_predictors],
      function(values) {
        is.numeric(values) || is.integer(values) ||
          (is.factor(values) && nlevels(values) < 50L) ||
          (is.logical(values) && dplyr::n_distinct(values) < 50L)
      },
      logical(1)
    )
  ]
  predictor_matrix <- build_predictor_matrix(
    df_imputed,
    complete_predictors
  )

  if (is.factor(df_imputed[[target]])) {
    df_imputed[[target]] <- impute_factor_knn(
      df_imputed[[target]],
      predictor_matrix,
      missing_rows
    )
    na_treated <- sum(missing_rows & !is.na(df_imputed[[target]]))
    detail_imputation <- if (na_treated == na_initial) {
      "KNN appliqué sur les prédicteurs one-hot complets."
    } else {
      "KNN incomplet; valeurs manquantes restantes conservées."
    }
    bilan_imputation[[length(bilan_imputation) + 1L]] <- list(
      var = var_target,
      type = type_target,
      methode = methode_retenue,
      nb_na_traites = na_treated,
      r2_ajuste = adjusted_r_squared,
      detail = detail_imputation
    )
    cleanup_imputation_iteration()
    next
  }

  if (!is.numeric(df_imputed[[target]]) && !is.integer(df_imputed[[target]])) {
    cli::cli_alert_danger(
      "Type non pris en charge pour l'imputation de {var_target}."
    )
    detail_imputation <- "Type non pris en charge; variable non imputée."
    bilan_imputation[[length(bilan_imputation) + 1L]] <- list(
      var = var_target,
      type = type_target,
      methode = methode_retenue,
      nb_na_traites = 0L,
      r2_ajuste = adjusted_r_squared,
      detail = detail_imputation
    )
    cleanup_imputation_iteration()
    next
  }

  if (ncol(predictor_matrix) == 0L) {
    cli::cli_alert_danger(
      "Régression linéaire impossible pour {var_target}"
    )
    detail_imputation <-
      "Conditions de validité non respectées malgré remèdes; non imputée"
    bilan_imputation[[length(bilan_imputation) + 1L]] <- list(
      var = var_target,
      type = type_target,
      methode = methode_retenue,
      nb_na_traites = 0L,
      r2_ajuste = adjusted_r_squared,
      detail = detail_imputation
    )
    cleanup_imputation_iteration()
    next
  }

  observed_rows <- which(!missing_rows)
  transformations <- "brut"
  target_values <- df_imputed[[target]]
  if (all(target_values[observed_rows] >= 0, na.rm = TRUE)) {
    transformations <- c(transformations, "log_plus_1", "sqrt")
  }
  candidate_results <- lapply(
    transformations,
    function(transformation) {
      fit_regression_remedy(
        target_values,
        predictor_matrix,
        observed_rows,
        transformation
      )
    }
  )
  valid_results <- candidate_results[
    vapply(candidate_results, function(result) {
      !is.null(result) && isTRUE(result$valid)
    }, logical(1))
  ]
  selected_result <- if (length(valid_results) > 0L) {
    valid_results[[1L]]
  } else {
    NULL
  }

  if (is.null(selected_result)) {
    cli::cli_alert_danger(
      "Régression linéaire impossible pour {var_target}"
    )
    detail_imputation <- paste(
      "Conditions de validité non respectées malgré remèdes; non imputée"
    )
    bilan_imputation[[length(bilan_imputation) + 1L]] <- list(
      var = var_target,
      type = type_target,
      methode = methode_retenue,
      nb_na_traites = 0L,
      r2_ajuste = NA_real_,
      detail = detail_imputation
    )
    cleanup_imputation_iteration()
    next
  }

  adjusted_r_squared <- selected_result$adjusted_r_squared
  missing_data <- as.data.frame(
    predictor_matrix[missing_rows, , drop = FALSE],
    check.names = FALSE
  )
  predictions <- tryCatch(
    stats::predict(selected_result$model, newdata = missing_data),
    error = function(error) NULL
  )
  if (is.null(predictions) || anyNA(predictions) ||
      any(!is.finite(predictions))) {
    cli::cli_alert_danger(
      "Régression linéaire impossible pour {var_target}"
    )
    bilan_imputation[[length(bilan_imputation) + 1L]] <- list(
      var = var_target,
      type = type_target,
      methode = methode_retenue,
      nb_na_traites = 0L,
      r2_ajuste = adjusted_r_squared,
      detail = "Conditions de validité non respectées malgré remèdes; non imputée"
    )
    cleanup_imputation_iteration()
    next
  }
  if (selected_result$transformation == "log_plus_1") {
    predictions <- expm1(predictions)
  } else if (selected_result$transformation == "sqrt") {
    predictions <- predictions^2
  }
  if (any(!is.finite(predictions))) {
    cli::cli_alert_danger(
      "Régression linéaire impossible pour {var_target}"
    )
    bilan_imputation[[length(bilan_imputation) + 1L]] <- list(
      var = var_target,
      type = type_target,
      methode = methode_retenue,
      nb_na_traites = 0L,
      r2_ajuste = adjusted_r_squared,
      detail = "Conditions de validité non respectées malgré remèdes; non imputée"
    )
    cleanup_imputation_iteration()
    next
  }

  df_imputed[[target]][missing_rows] <- predictions
  na_treated <- sum(missing_rows & !is.na(df_imputed[[target]]))
  detail_imputation <- paste(
    "Régression validée avec remède :",
    selected_result$transformation
  )
  bilan_imputation[[length(bilan_imputation) + 1L]] <- list(
    var = var_target,
    type = type_target,
    methode = methode_retenue,
    nb_na_traites = na_treated,
    r2_ajuste = adjusted_r_squared,
    detail = detail_imputation
  )
  cli::cli_inform(
    "Variable {var_target} imputée par régression linéaire : R² ajusté = {round(adjusted_r_squared, 3)}, p(F) = {signif(global_f_p, 3)}."
  )
  cleanup_imputation_iteration()
  gc(verbose = FALSE)
}

cli::cli_h2("Bilan récapitulatif des imputations")
if (length(bilan_imputation) > 0L) {
  df_bilan <- dplyr::bind_rows(bilan_imputation) |>
    dplyr::mutate(
      r2_ajuste = dplyr::if_else(
        is.na(r2_ajuste),
        "N/A",
        format(round(as.numeric(r2_ajuste), 3), nsmall = 3)
      )
    ) |>
    dplyr::select(
      var,
      type,
      methode,
      nb_na_traites,
      r2_ajuste,
      detail
    )
  print(
    knitr::kable(
      df_bilan,
      format = "simple",
      col.names = c(
        "Variable",
        "Type",
        "Méthode",
        "NA traités",
        "R² ajusté",
        "Détail"
      ),
      align = "l"
    )
  )
} else {
  cli::cli_inform("Aucune variable ne nécessitait d'imputation.")
}

# Exporter directement le tableau bilan sous forme d'image.
if (exists("df_bilan", inherits = FALSE) &&
    nrow(df_bilan) > 0L) {
  tryCatch(
    {
      bilan_theme <- gridExtra::ttheme_default(
        base_size = 10,
        padding = grid::unit(c(4, 4), "pt"),
        colhead = list(
          fg_params = list(
            col = "#FFFFFF",
            fontface = "bold",
            hjust = 0,
            x = 0.05
          ),
          bg_params = list(fill = "#1F4E78")
        ),
        core = list(
          fg_params = list(
            col = "#1A1A1A",
            hjust = 0,
            x = 0.05
          ),
          bg_params = list(fill = c("#FFFFFF", "#F8F9FA"))
        )
      )
      bilan_grob <- gridExtra::tableGrob(
        df_bilan,
        rows = NULL,
        theme = bilan_theme
      )
      bilan_title <- grid::textGrob(
        "Bilan de l'imputation des données BAAC",
        gp = grid::gpar(
          col = "#1A1A1A",
          fontsize = 14,
          fontface = "bold"
        ),
        hjust = 0,
        x = 0.05
      )
      bilan_plot <- gridExtra::arrangeGrob(
        bilan_title,
        bilan_grob,
        ncol = 1,
        heights = grid::unit.c(
          grid::unit(0.45, "in"),
          grid::unit(1, "null")
        )
      )
      table_width <- max(10, min(20, 0.16 * ncol(df_bilan) * 20))
      table_height <- max(3.5, min(20, 0.35 * nrow(df_bilan) + 2))
      ggplot2::ggsave(
        filename = here::here(
          "outputs",
          "figures",
          "tableau_bilan_imputation.png"
        ),
        plot = bilan_plot,
        width = table_width,
        height = table_height,
        units = "in",
        bg = "white",
        dpi = 300
      )
      cli::cli_alert_success(
        "Tableau bilan sauvegardé dans outputs/figures/tableau_bilan_imputation.png."
      )
    },
    error = function(error) {
      cli::cli_alert_warning(
        "Échec de l'export du tableau bilan : {conditionMessage(error)}. Le script continue."
      )
    }
  )
}

# Comparer les distributions quantitatives avant/après imputation.
numeric_imputed <- intersect(
  variables_to_impute[
    vapply(df_pre_imputation[variables_to_impute], is.numeric, logical(1))
  ],
  names(df_imputed)
)
if (length(numeric_imputed) > 0L) {
  numeric_distribution_check <- purrr::map_dfr(
    numeric_imputed,
    function(variable) {
      tibble::tibble(
        variable = variable,
        mean_before = mean(df_pre_imputation[[variable]], na.rm = TRUE),
        median_before = stats::median(df_pre_imputation[[variable]], na.rm = TRUE),
        mean_after = mean(df_imputed[[variable]], na.rm = TRUE),
        median_after = stats::median(df_imputed[[variable]], na.rm = TRUE)
      )
    }
  )
  cli::cli_inform("Comparaison des distributions quantitatives avant/après :")
  print(numeric_distribution_check)
}

# Comparer les fréquences des modalités qualitatives avant/après imputation.
factor_imputed <- variables_to_impute[
  vapply(df_pre_imputation[variables_to_impute], is.factor, logical(1))
]
if (length(factor_imputed) > 0L) {
  factor_distribution_check <- purrr::map_dfr(
    factor_imputed,
    function(variable) {
      before <- tibble::tibble(
        modalite = as.character(df_pre_imputation[[variable]])
      ) |>
        dplyr::count(modalite, name = "n_before")
      after <- tibble::tibble(
        modalite = as.character(df_imputed[[variable]])
      ) |>
        dplyr::count(modalite, name = "n_after")

      dplyr::full_join(before, after, by = "modalite") |>
        dplyr::mutate(
          variable = variable,
          dplyr::across(c(n_before, n_after), ~ tidyr::replace_na(.x, 0L))
        ) |>
        dplyr::select(variable, modalite, n_before, n_after)
    }
  )
  cli::cli_inform("Comparaison des fréquences qualitatives avant/après :")
  print(factor_distribution_check)
}

remaining_na <- sum(is.na(df_imputed))
if (remaining_na > 0L) {
  columns_with_na <- names(which(colSums(is.na(df_imputed)) > 0L))
  cli::cli_alert_warning(
    "L'imputation séquentielle a laissé {remaining_na} valeurs manquantes dans : {paste(columns_with_na, collapse = ', ')}"
  )
} else {
  cli::cli_alert_success("Aucune valeur manquante ne subsiste après imputation.")
}

baac_imputed <- df_imputed
initial_row_count <- nrow(baac_imputed)
baac_final <- baac_imputed |>
  tidyr::drop_na()
removed_row_count <- initial_row_count - nrow(baac_final)
removed_row_percentage <- if (initial_row_count > 0L) {
  100 * removed_row_count / initial_row_count
} else {
  0
}
cli::cli_alert_warning(
  paste0(
    "Nettoyage final des valeurs manquantes : ",
    initial_row_count,
    " lignes initiales, ",
    removed_row_count,
    " lignes supprimées (",
    format(round(removed_row_percentage, 2), nsmall = 2),
    " %), ",
    nrow(baac_final),
    " lignes finales."
  )
)
stopifnot(sum(is.na(baac_final)) == 0)
readr::write_csv2(
  baac_final,
  here::here("data", "processed", "dataset_imputed.csv")
)
cli::cli_alert_success(
  "Dataset final nettoyé sauvegardé dans data/processed/dataset_imputed.csv."
)

# %% --- 1.6 Construction et export de la base analytique ---

required_calendar_columns <- c("an", "mois", "jour", "hrmn", "an_nais")
missing_calendar_columns <- setdiff(
  required_calendar_columns,
  names(baac_final)
)
if (length(missing_calendar_columns) > 0L) {
  stop(
    "Colonnes nécessaires à la construction de la base analytique absentes : ",
    paste(missing_calendar_columns, collapse = ", "),
    call. = FALSE
  )
}

# Normaliser les années sur quatre chiffres avant de calculer l'âge et la date.
baac_final <- baac_final |>
  dplyr::mutate(
    an = dplyr::if_else(an < 100, an + 2000, an),
    age = an - as.numeric(as.character(an_nais)),
    tranche_age = cut(
      age,
      breaks = c(-Inf, 14, 24, 44, 64, Inf),
      labels = c("0-14", "15-24", "25-44", "45-64", "65+"),
      right = TRUE
    )
  )

if (any(!is.na(baac_final$an) & baac_final$an < 1000) ||
    any(!is.na(baac_final$an) & baac_final$an > 9999)) {
  stop("La variable an contient des années qui ne sont pas sur quatre chiffres.",
       call. = FALSE)
}

parse_hrmn <- function(values) {
  values <- stringr::str_replace_all(as.character(values), "[^0-9]", "")
  digits <- stringr::str_extract(
    stringr::str_pad(as.character(values), width = 4, side = "left", pad = "0"),
    "^[0-9]{4}"
  )
  hour <- suppressWarnings(as.integer(stringr::str_sub(digits, 1L, 2L)))
  minute <- suppressWarnings(as.integer(stringr::str_sub(digits, 3L, 4L)))
  valid <- !is.na(hour) & !is.na(minute) &
    hour <= 23L & minute <= 59L
  list(
    exact = ifelse(
      valid,
      sprintf("%02d:%02d", hour, minute),
      NA_character_
    ),
    hour = hour,
    valid = valid
  )
}

hrmn_parsed <- parse_hrmn(baac_final$hrmn)
baac_final <- baac_final |>
  dplyr::mutate(
    date = lubridate::make_date(
      year = as.integer(an),
      month = as.integer(mois),
      day = as.integer(jour)
    ),
    heure_exacte = hrmn_parsed$exact,
    tranche_horaire = dplyr::case_when(
      !hrmn_parsed$valid ~ NA_character_,
      hrmn_parsed$hour < 6L ~ "00h-06h",
      hrmn_parsed$hour < 12L ~ "06h-12h",
      hrmn_parsed$hour < 18L ~ "12h-18h",
      TRUE ~ "18h-24h"
    ),
    jour_semaine = lubridate::wday(
      date,
      label = FALSE,
      week_start = 1L
    )
  )
baac_final$jour_semaine <- c(
  "lundi", "mardi", "mercredi", "jeudi",
  "vendredi", "samedi", "dimanche"
)[as.integer(baac_final$jour_semaine)]

easter_sunday <- function(year) {
  a <- year %% 19L
  b <- year %/% 100L
  c <- year %% 100L
  d <- b %/% 4L
  e <- b %% 4L
  f <- (b + 8L) %/% 25L
  g <- (b - f + 1L) %/% 3L
  h <- (19L * a + b - d - g + 15L) %% 30L
  i <- c %/% 4L
  k <- c %% 4L
  l <- (32L + 2L * e + 2L * i - h - k) %% 7L
  m <- (a + 11L * h + 22L * l) %/% 451L
  month <- (h + l - 7L * m + 114L) %/% 31L
  day <- (h + l - 7L * m + 114L) %% 31L + 1L
  lubridate::make_date(year, month, day)
}

public_holidays <- function(year) {
  easter <- easter_sunday(year)
  c(
    lubridate::make_date(year, 1L, 1L),
    easter + lubridate::days(1L),
    lubridate::make_date(year, 5L, 1L),
    lubridate::make_date(year, 5L, 8L),
    easter + lubridate::days(39L),
    easter + lubridate::days(50L),
    lubridate::make_date(year, 7L, 14L),
    lubridate::make_date(year, 8L, 15L),
    lubridate::make_date(year, 11L, 1L),
    lubridate::make_date(year, 11L, 11L),
    lubridate::make_date(year, 12L, 25L)
  )
}

school_holidays <- tibble::tribble(
  ~start, ~end,
  as.Date("2024-02-10"), as.Date("2024-03-11"),
  as.Date("2024-04-06"), as.Date("2024-05-13"),
  as.Date("2024-07-06"), as.Date("2024-09-02"),
  as.Date("2024-10-19"), as.Date("2024-11-04"),
  as.Date("2024-12-21"), as.Date("2025-01-06")
)

holiday_dates <- unique(do.call(
  c,
  lapply(unique(lubridate::year(baac_final$date)), public_holidays)
))
baac_final <- baac_final |>
  dplyr::mutate(
    jours_feries = as.integer(date %in% holiday_dates),
    vacances_scolaires = as.integer(
      purrr::map_lgl(
        date,
        ~ any(.x >= school_holidays$start & .x < school_holidays$end)
      )
    ),
    presence_secu = as.integer(
      rowSums(
        !is.na(dplyr::across(dplyr::all_of(c("secu1", "secu2", "secu3")))) &
          dplyr::across(
            dplyr::all_of(c("secu1", "secu2", "secu3")),
            ~ as.character(.x) != "Aucun équipement"
          )
      ) > 0L
    )
  )

readr::write_csv2(
  baac_final,
  here::here("data", "processed", "dataset_analytique_clean.csv")
)
cli::cli_alert_success(
  "Base analytique sauvegardée dans data/processed/dataset_analytique_clean.csv."
)
