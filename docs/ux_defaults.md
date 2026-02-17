# UX Defaults - LocatifPro

## Vue d'ensemble

Le script `scripts/ux_defaults.sql` applique automatiquement des paramétrages Directus pour rendre l'interface utilisable sans configuration manuelle champ par champ :

1. **Display templates** pour les collections (affichage lisible dans les listes)
2. **Interfaces relationnelles** pour les FK (dropdown lisibles au lieu d'UUID)

## Display Templates

### Qu'est-ce que c'est ?

Un `display_template` dans Directus est un format de texte pour afficher un enregistrement en tant que label lisible (au lieu de l'ID unique).

Exemple :
- **Sans template** : `a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6` (UUID illisible)
- **Avec template** : `Immeuble République` (affichage de la colonne `nom`)

### Heuristique appliquée

Pour chaque collection, le script **détecte automatiquement** le meilleur champ pour afficher :

**Ordre de préférence :**
```
['nom', 'name', 'libelle', 'label', 'titre', 'title', 'code', 'reference', 'ref', 'numero', 'num', 'slug']
```

**Logique :**
- Si un seul champ trouvé → utilise `{{nom}}`
- Si plusieurs trouvés → combine les 2-3 premiers avec ` - ` (ex: `{{code}} - {{nom}}`)
- Si aucun trouvé → laisser vide (ne rien mettre)

### Exemples résultants

| Collection | Colonnes trouvées | Template appliqué |
|-----------|-------------------|-------------------|
| `entites` | `nom`, `code` | `{{code}} - {{nom}}` |
| `proprietes` | `nom` | `{{nom}}` |
| `societes_internes` | `code` | `{{code}}` |
| `baux` | `code` | `{{code}}` |
| `bien` | `code`, `ref_unite` | `{{code}} - {{ref_unite}}` |
| `indices` | — | (vide, pas de colonne candidate) |

## Interfaces Relationnelles

### Qu'est-ce que c'est ?

Par défaut, Directus affiche les champs FK avec un input texte (UUID). L'interface `select-dropdown-m2o` transforme ça en dropdown lisible avec les templates appliqués.

### Configuration

Le script détecte **tous les champs FK** (via `directus_relations`) et les configure avec :
```
interface = 'select-dropdown-m2o'
```

Résultat : quand vous éditez un enregistrement `baux`, le champ `societe_interne_id` affiche un dropdown avec les noms des sociétés (grâce au template de `societes_internes`).

### Exemple

**Avant :**
```
paiement_allocations.echeance_id = [UUID input]
```

**Après :**
```
paiement_allocations.echeance_id = [Dropdown showing: "BAIL-001 - 2025-01" (from echeances template)]
```

## Idempotence

Le script utilise `WHERE display_template IS NULL` donc :
- ✅ **Exécutable** en boucle sans créer de doublons
- ✅ **Respecte** les templates manually set (ne les écrase pas)
- ✅ **Ajoute** uniquement où il y a du vide

## Exceptions et ajustements manuels

Si tu veux customizer un template :

```sql
UPDATE directus_collections
SET display_template = '{{VOTRE_TEMPLATE}}'
WHERE collection = 'nom_collection';
```

### Exemples de templates avancés

```sql
-- Afficher "code - nom (statut)"
UPDATE directus_collections
SET display_template = '{{code}} - {{nom}} ({{statut}})'
WHERE collection = 'baux';

-- Afficher avec date formatée
UPDATE directus_collections
SET display_template = '{{date_debut|date}}'
WHERE collection = 'plans_apurement';

-- Afficher un champ relationnel imbriqué
UPDATE directus_collections
SET display_template = '{{societe_interne_id.entite_id.nom}}'
WHERE collection = 'baux';
```

## Validation après bootstrap

Après exécution du bootstrap :

```bash
./scripts/reset.sh
./scripts/bootstrap.sh
```

### 1. Vérifier les templates appliqués

```sql
docker compose exec -T db psql -U locatifpro -d locatifpro <<EOF
SELECT collection, display_template
FROM directus_collections
WHERE collection NOT LIKE 'directus_%' AND display_template IS NOT NULL
ORDER BY collection;
EOF
```

### 2. Vérifier les interfaces M2O

```sql
docker compose exec -T db psql -U locatifpro -d locatifpro <<EOF
SELECT collection, field, interface
FROM directus_fields
WHERE collection NOT LIKE 'directus_%' AND interface = 'select-dropdown-m2o'
ORDER BY collection, field;
EOF
```

### 3. Test manual dans Directus UI

1. Ouvrir **Content > baux**
2. Cliquer sur un enregistrement pour l'éditer
3. Vérifier que le champ `societe_interne_id` affiche un dropdown avec des libellés (ex: `SOC-IMMO-1`) au lieu d'UUID
4. Tester **Content > paiement_allocations**
5. Vérifier que `echeance_id` et `paiement_id` affichent des dropdowns lisibles

## Intégration dans bootstrap.sh

Le script s'exécute automatiquement lors du bootstrap :

```bash
# 5) Apply UX defaults (display templates, relation displays)
echo "Applying UX defaults (display templates / relation displays)..."
cat scripts/ux_defaults.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro
```

**Ordre d'exécution :**
1. `reset.sh` → clean slate
2. `bootstrap.sh` up services
3. Populate metadata
4. Patch FK
5. **Apply UX defaults** ← HERE
6. Setup RBAC
7. Done ✅

## Limitations et notes

- **Pas de support Composite** : display_template fonctionne avec des colonnes simples. Si tu as besoin d'afficher un champ calculé à partir de plusieurs FK imbriquées, customizer manuellement.
- **Performance** : les templates Directus sont évalués côté client/serveur, aucun impact perf.
- **Override** : si une collection a déjà un `display_template` non-null, le script ne l'écrase pas.

## Évolution future

- [ ] Script pour détecter templates à plusieurs niveaux (ex: `{{fk.related_table.col}}`)
- [ ] Auto-configuration des filtres et tris par défaut
- [ ] Support des enum et custom types
