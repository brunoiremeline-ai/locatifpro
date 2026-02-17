# Modèle de sécurité - LocatifPro

## Vue d'ensemble

LocatifPro implémente un système RBAC (Role-Based Access Control) pour isoler l'accès aux données par **société interne**. Chaque utilisateur n'accède qu'aux enregistrements des sociétés pour lesquelles il est explicitement autorisé.

## Architecture

### Tableau des rôles et permissions

| Entité | Rôle | Politiques | Portée |
|--------|------|-----------|--------|
| **Administrator** | Rôle système Directus | Accès admin_access=true | Accès total à toutes les données et paramètres |
| **Agent** | Rôle personnalisé (nouveau) | Politiques par societe_interne | Accès scoped uniquement aux ses sociétés assignées |

### Flux d'autorisation

```
directus_roles (Agent)
    ↓
directus_access (relie role → policy)
    ↓
directus_policies (Agent policy: app_access=true, admin_access=false)
    ↓
directus_permissions (ACL granulaires par collection et action)
```

## Permissions par collection

### 1. Collections avec `societe_interne_id` directe

Les utilisateurs Agent ne voient/créent/modifient/suppriment que les enregistrements où `societe_interne_id` figure dans leur liste personnelle :

| Collection | Actions | Filtre |
|-----------|----------|--------|
| `baux` | READ, CREATE, UPDATE, DELETE | `societe_interne_id IN (SELECT ... FROM user_societes WHERE directus_user_id = $CURRENT_USER)` |
| `echeances` | READ, CREATE, UPDATE, DELETE | Idem |
| `paiements` | READ, CREATE, UPDATE, DELETE | Idem |
| `paiement_allocations` | READ, CREATE, UPDATE, DELETE | Idem |
| `budgets` | READ, CREATE, UPDATE, DELETE | Idem |
| `charges_refacturables` | READ, CREATE, UPDATE, DELETE | Idem |
| `alertes_conformite` | READ, CREATE, UPDATE, DELETE | Idem |
| `documents` | READ, CREATE, UPDATE, DELETE | Idem |
| `user_societes` | READ, CREATE, UPDATE, DELETE | Idem |
| `relances` | READ, CREATE, UPDATE, DELETE | Idem |
| `plans_apurement` | READ, CREATE, UPDATE, DELETE | Idem |
| `plan_apurement_lignes` | READ, CREATE, UPDATE, DELETE | Idem |
| `indexations_soumises` | READ, CREATE, UPDATE, DELETE | Idem |
| `loyers_variables_ca` | READ, CREATE, UPDATE, DELETE | Idem |
| `provisions_indexation` | READ, CREATE, UPDATE, DELETE | Idem |

### 2. Collections de lecture seule (accès relationnel)

Les utilisateurs Agent peuvent **lire seulement** :

| Collection | Actions | Notes |
|-----------|----------|-------|
| `societes_internes` | READ | Uniquement ses sociétés assignées via `user_societes` |
| `entites` | READ | Lookup relationnel pour bailleur/preneur |
| `proprietes` | READ | Context des propriétés gérées |
| `biens` | READ | Lots/unités des propriétés |
| `config_index` | READ | Config d'indexation des baux |
| `indices` | READ | Données de référence (IRL, ILC, etc.) |
| `propriete_societes` | READ | Attribution des propriétés aux sociétés |
| `journal_actions` | READ | Historique audit des actions |

### 3. Collections système Directus

Accès minimal pour l'usage personnel :

| Collection | Actions | Restrictions |
|-----------|----------|--------------|
| `directus_users` | READ | Uniquement son propre profil (`id = $CURRENT_USER`) |
| `directus_users` | UPDATE | Uniquement email, password, first_name, last_name, avatar |
| `directus_roles` | READ | Lecture seule (pour affichage des rôles) |
| `directus_files` | READ, CREATE | Lecture et upload de fichiers |

## Configuration des utilisateurs

### Créer un utilisateur Agent

1. Accéder à **Admin Panel > Users**
2. Cliquer sur **+ Create User**
3. Remplir les champs obligatoires (email, password, name)
4. **Important** : Assigner le rôle **Agent** (pas Administrator)
5. Cliquer sur **Save & Exit**

### Rattacher un utilisateur à des sociétés

Une fois l'utilisateur créé, lui autoriser l'accès aux sociétés via la table `user_societes` :

```sql
-- Donner accès à l'utilisateur user_123 sur la société SOC-IMMO-1
INSERT INTO user_societes (directus_user_id, societe_interne_id, role, is_active)
VALUES (
  'user-uuid-here',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',  -- SOC-IMMO-1 uuid
  'GESTIONNAIRE',
  true
);
```

Rôles disponibles dans `user_societes.role` : `ADMIN`, `GESTIONNAIRE`, `COMPTABLE`, `LECTURE`

**Note** : Ces rôles sont pour la logique métier applicative, les permissions Directus sont gérées par le rôle du user, pas par ce champ.

## Validation des permissions

### Test : Vérifier l'isolation des données

```bash
# 1. Créer 2 utilisateurs test avec rôle Agent

# 2. Assigner User A à SOC-IMMO-1, User B à SOC-IMMO-2

# 3. Login comme User A (Directus UI ou API)
# - Doit voir uniquement les baux/écheances/paiements de SOC-IMMO-1
# - Ne doit PAS voir les données de SOC-IMMO-2

# 4. Login comme User B
# - Doit voir uniquement les données de SOC-IMMO-2
# - Ne doit PAS voir les données de SOC-IMMO-1

# 5. API test (avec token User A) :
curl -H "Authorization: Bearer USER_A_TOKEN" \
  http://localhost:8055/graphql \
  -d '{"query": "{ baux { id societe_interne_id } }"}'
# → Retourne uniquement les baux avec societe_interne_id IN (SOC-IMMO-1)
```

### Test : Tentative d'accès privilégié

```bash
# Essayer de créer directement un record d'une autre société :
curl -X POST http://localhost:8055/items/baux \
  -H "Authorization: Bearer USER_A_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"societe_interne_id": "SOC-IMMO-2-UUID", ...}'
# → ❌ FORBIDDEN (action interdite par la politique)
```

## Cas d'usage

### Admin (Administrator role)
- Accès complet à toutes les données
- Gestion des utilisateurs et rôles
- Paramétrage des métadonnées Directus

### Agent rattaché à SOC-IMMO-1
- **Peut** : Consulter/créer/éditer ses baux, écheances, paiements
- **Ne peut pas** : Consulter les données de SOC-IMMO-2 ou d'autres sociétés
- **Peut** : Consulter les entités (bailleurs/locataires) et propriétés pour contexte
- **Ne peut pas** : Modifier les entités ou propriétés (lecture seule)

### Agent rattaché à plusieurs sociétés
Si `user_societes` contient 2 enregistrements (une même personne dans 2 sociétés) :
- La requête `SELECT societe_interne_id FROM user_societes WHERE directus_user_id = $CURRENT_USER` retourne 2 IDs
- Les filtres de permission appliquent `_in` sur ces 2 IDs
- L'utilisateur voit/crée des enregistrements pour TOUTES ses sociétés

## Sécurité et limites

### ✅ Protections en place
- **Isolation des données par société** : Les requêtes sont filtrées au niveau base de données
- **Immuabilité des permissions** : Créées/gérées via SQL, non modifiables via UI (sauf admin)
- **Audit trail** : `journal_actions` enregistre toutes les actions

### ⚠️ Points à surveiller
1. **Extension du modèle** : Si vous ajoutez des collections avec `societe_interne_id`, mettre à jour `setup_rbac.sql`
2. **Relations indirectes** : Les collections liées (via FK) ne sont pas filtrées automatiquement → inclure dans read-only
3. **Cascade deletes** : Vérifier que la suppression d'un utilisateur ne casse pas intégrité des permissions

### 🔓 Accès root (base de données)
- Les utilisateurs avec accès PostgreSQL direct contournent les permissions Directus
- Limiter l'accès à la BD aux administrateurs système uniquement

## Maintenance

### Ajouter une nouvelle collection au filtrage

1. Déterminer si elle a `societe_interne_id` directement
2. Ajouter le nom de collection à l'array `collections_to_filter` dans `setup_rbac.sql`
3. Exécuter le script (idempotent, ne crée pas de doublons)
4. Tester via Directus UI qu'un Agent ne voit que ses données

### Supprimer une permission existante

```sql
DELETE FROM directus_permissions
WHERE policy = (SELECT id FROM directus_policies WHERE name = 'Agent')
  AND collection = 'nom_collection'
  AND action = 'read';
```

### Vérifier l'état actuel des permissions Agent

```sql
SELECT COUNT(*) FROM directus_permissions
WHERE policy IN (SELECT id FROM directus_policies WHERE name = 'Agent');

SELECT collection, action, COUNT(*)
FROM directus_permissions
WHERE policy IN (SELECT id FROM directus_policies WHERE name = 'Agent')
GROUP BY collection, action
ORDER BY collection;
```

## Évolution future

- [ ] Implémentation d'un frontend pour gérer `user_societes` visuellement
- [ ] Audit trail détaillé des accès (qui a consulté quoi et quand)
- [ ] Support des départements/filiales futures avec clustering multi-niveau
- [ ] Webhooks pour sync des permissions avec systèmes externes (LDAP, SSO)
