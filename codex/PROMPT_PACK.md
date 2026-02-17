# GitHub Codex — Pack de prompts (LocatifPro)

> Objectif : que Codex fasse évoluer le dépôt **sans intervention manuelle** autre que “lancer Codex” + exécuter les tests.
> Référence fonctionnelle : `docs/requirements/V2_master_spec.md` (+ sources complètes dans `docs/sources/`).

---

## PROMPT 0 — Audit de cohérence (à lancer en premier)
Lis `docs/requirements/V2_master_spec.md`, compare avec le schéma `db/init/001_schema.sql` et le seed `db/init/002_seed.sql`.
- Signale tout champ / table manquant(e) vs V2.
- Signale tout champ “PDF legacy” (locataire_entite_id vs preneur_entite_id, payeur_entite_id vs contrepartie_entite_id, code_bail vs code).
- Propose une migration SQL si besoin (sans casser les données seed).

---

## PROMPT 1 — Séparation par société interne (Directus)
Implémente la séparation par société interne **sans RLS Postgres** au départ :
- Crée un script `scripts/directus_setup_permissions.ts` (Node/TS) qui :
  - crée les rôles Directus : ADMIN, GESTIONNAIRE, COMPTABLE, LECTURE
  - configure les permissions CRUD/R selon la matrice des droits,
  - ajoute un filtre systématique `{ "societe_interne_id": { "_in": "$CURRENT_USER.user_societes.societe_interne_id" } }` sur les collections “métier”.
- Le script doit être idempotent.

---

## PROMPT 2 — Génération échéances (moteur)
Crée une extension Directus `extensions/endpoints/locatifpro/` avec :
- `POST /locatifpro/generate-echeances`
  - body: `{ societe_interne_id, periode_from, periode_to, mode: "PREVISIONNEL"|"FACTURE" }`
  - Pour chaque bail ACTIF de la société :
    - génère les échéances mensuelles (période = AAAA-MM = mois de début),
    - applique les composantes : loyer_base + charges_provision + tf_provision,
    - calcule `date_echeance` à partir de `date_exigibilite_jour` (sinon déclenche alerte MissingExigibilite),
    - n’insère rien si l’échéance existe déjà (anti-doublon).
  - Met à jour le statut selon `mode`.
- Ajoute des tests unitaires (vitest) pour :
  - anti-doublon,
  - date échéance (jour 1, 5, fin de mois),
  - bail clos/non actif exclu.

---

## PROMPT 3 — Rapprochement paiements↔échéances (allocation)
Dans la même extension :
- `POST /locatifpro/reconcile`
  - body: `{ paiement_id, allocations: [{ echeance_id, montant_alloue }], tolerance_eur: 1 }`
  - crée/maj `paiement_allocations` (upsert),
  - calcule le reste dû par échéance,
  - règle : si solde <= tolerance_eur -> statut PAYE, sinon FACTURE.
  - gère trop-perçu : si paiement dépasse, retour JSON avec `surplus_eur` (l’app décidera “avance” vs “remboursement”).
- Tests : N:N, paiement partiel, tolérance.

---

## PROMPT 4 — Bail miroir (réciprocité interne)
- Hook Directus `baux.items.create` :
  - si `interne_reciprocite_requise=true` et `bail_miroir_id` NULL :
    - crée automatiquement le bail miroir (sens opposé, mêmes dates/lot/société, parties inversées),
    - renseigne les `bail_miroir_id` des deux baux,
    - journalise (journal_actions) + alerte si création impossible.
- Hook `baux.items.update` :
  - si changement sur dates/montants (et bail miroir existe) : propose synchronisation (log + alerte).
- Tests : création simple, non-récursif (pas de boucle).

---

## PROMPT 5 — Indexations entrantes (calcul, contrôle, application)
- Endpoint `POST /locatifpro/indexations/calc` : calcule `nouveau_loyer_calcule`, `ecart_eur`, `ecart_pct` à partir des indices (table `indices`) et du loyer de référence.
- Endpoint `POST /locatifpro/indexations/validate` : passe à VALIDEE/CONTESTEE ; contrôle rétroactivité (commercial oui / particulier non) -> alerte RetroactNonAutorisee si violé.
- Endpoint `POST /locatifpro/indexations/apply` : si VALIDEE -> met à jour `baux.loyer_base` + régénère les échéances futures (ou crée une ligne d’ajustement selon stratégie) ; trace dans `journal_actions`.
- Ajoute alerte IndexationEcartFort si `|ecart_pct| > seuil` (paramètre admin).

---

## PROMPT 6 — Provisions indexation (non cumulatives)
- Endpoint `POST /locatifpro/provisions/run` : sur une période ou plage de périodes, calcule la provision si indexation non reçue :
  - enregistre dans `provisions_indexation` (groupé par `run_id`),
  - “non cumulatif” : une période a une seule ligne par bail et run.
- Reporting : vue / endpoint `GET /locatifpro/provisions` filtrable.

---

## PROMPT 7 — Impayés/relances + plans d’apurement
- Job quotidien (ou endpoint) qui :
  - détecte échéances FACTURE non soldées > 10 jours -> propose impayé (ne bascule pas automatiquement) via `impaye_flag` + alerte.
  - génère relances selon J+10/J+20/J+30 (niveau 1/2/MED) sur demande (endpoint).
- Plan d’apurement : CRUD + calcul statut lignes (en retard / payé).

---

## PROMPT 8 — Reporting & Exports
- Exports CSV/Excel : facturé/encaissé, impayés, indexations à venir, CA manquants, provisions indexation.
- Ajoute un endpoint `GET /locatifpro/exports/<report>` renvoyant un fichier.

