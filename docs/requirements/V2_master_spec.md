# LocatifPro — Master Spec (V2)

> Ce fichier est le **point d’ancrage** pour GitHub Codex / l’agent de dev : il résume les décisions & règles, et pointe vers les documents sources complets.
> Sources conservées telles quelles dans `docs/sources/` :
> - `Cahier_Consolide_LocatifPro_V2.docx`
> - `Cahier des besoins.odt`
> - `Gestion locative - Accès Dataverse M365.pdf`

## 0) Contexte & objectif
- Objectif : piloter baux, quittancement, encaissements/rapprochement, impayés/relances, indexations, charges/régularisations, loyers variables (CA), budgets & provisions, documents, alertes conformité.
- Ordres de grandeur : ~120 baux, ~10 utilisateurs, multi-sociétés (~70–80 entités groupe, ~15 sociétés immo gérées). Confidentialité élevée.

## 1) Périmètre V1 (prioritaire)
- Portefeuille : Sociétés internes, Entités (bailleurs/preneurs), Propriétés, Biens.
- Baux : création, suivi, contrôles (chevauchement, réciprocité interne).
- Quittancement : échéances (mensuel / trimestriel / annuel), statuts (prévisionnel/facturé/payé), avoirs autorisés (montants négatifs -> alerte).
- Paiements : saisie + import ; rapprochement paiements↔échéances (N:N) avec tolérance 1€.
- Impayés / relances : impayé proposé à J+10 (pas automatique), relance 1 (J+10), relance 2 (J+20), mise en demeure (J+30) ; plans d’apurement.
- Indexation : IRL/ILC/ICC/ILAT/IRL Outremer ; rétroactivité (commercial oui / particulier non), validation admin ou permission dédiée.
- Loyers variables (CA) : avec/sans plancher & plafond.
- Charges & régularisation.
- Documents (baux, quittances, relances, EDLE, avenants, factures de charges…).
- Reporting & exports (CSV/Excel ; analytique option).

## 2) Navigation (menus)
1. Accueil / Dashboard
2. Portefeuille
   - Sociétés internes
   - Entités
   - Propriétés
   - Biens
3. Baux
4. Quittancement (Échéances)
5. Paiements & Rapprochement
6. Indexation
   - Config indexation
   - Indexations entrantes (bailleurs)
   - Indices (IRL/ILC/ICC/ILAT/IRL Outremer)
7. Impayés & Relances
8. Charges & Régularisations
9. Loyers variables (CA)
10. Budgets & Provisions
11. Documents
12. Conformité (alertes)
13. Reporting & Exports
14. Administration

## 3) Écrans (extraits structurants)
> Le détail complet est dans le PDF. Ici on garde le contrat fonctionnel minimal par écran.

### 3.1 Dashboard
KPIs : échéances du mois (total/payé/restant), impayés (nb+montant), indexations à valider, baux à renouveler (J+30/J+60), CA manquants, alertes ouvertes. Filtres : société interne obligatoire, période AAAA-MM, type bail option.

### 3.2 Portefeuille
- Sociétés internes : liste (code, nom entité liée, groupe/sous-groupe, actif) + détail (onglets propriétés, baux, documents).
- Entités : liste (code, nom, type, périmètre, ville, email) + détail.
- Propriétés : liste + détail (onglets lots, sociétés rattachées, docs).
- Biens : liste (code, ref_unite, propriété, type, surface, étage, actif) + détail.

### 3.3 Baux
Liste : code, statut, sens, type bail, lot, société interne, bailleur, preneur, date effet, loyer base.
Détail (onglets) : résumé, indexation, échéances, paiements, documents, alertes.
Contrôles : pas de chevauchement de baux **ACTIF** sur un lot ; si bail interne -> réciprocité via bail miroir.

### 3.4 Échéances (Quittancement)
Liste : période AAAA-MM, date échéance, bail, société, montant total, statut, impayé, indexation appliquée.
Détail : composants loyer/charges/TF ; journal allocations ; bascule statut selon droits.

### 3.5 Paiements & rapprochement
Liste paiements + écran rapprochement : bloc échéances ouvertes triées par ancienneté ; allocation ; tolérance 1€ ; gestion trop-perçu “au choix”.

### 3.6 Indexation
- Config par bail : indice, fréquence, date révision (mode), cap/floor/min/max, actif. UX : si clause prévue = non, config masquée/désactivée.
- Indexations entrantes (bailleurs) : saisie/import, contrôle, validation/contestation, application auto.

### 3.7 Impayés & relances
Tableau impayés (échéance, bail, locataire, période, dû, jours retard, niveau relance, plan apurement).
Plan d’apurement : lignes (période, attendu, réglé, statut).

### 3.8 Charges / régularisations
Liste charges refacturables + génération pièces.

### 3.9 Loyers variables (CA)
Import CA manquants + calcul + application.

### 3.10 Budgets & provisions
Budgets : édition (société, lot, période, nature flux, montant) + génération auto.
Provision indexation : pilotage (écart provision, statut estimé/validé).

### 3.11 Documents
Liste + upload/liaison (bail, échéance, relance, etc.).

### 3.12 Conformité (alertes)
Liste + détail (message/reco/lien) ; actions : accepter/justifier, résoudre.

### 3.13 Reporting & exports
Rapports : facturé/encaissé, impayés, indexations à venir, entrantes en attente, CA manquants, provisions indexation. Exports : CSV/Excel.

### 3.14 Administration
Utilisateurs + rôle + sociétés autorisées ; paramètres (tolérance rapprochement=1€, seuil écart indexation fort, modèles PDF, etc.).

## 4) Rôles & séparation par société interne
Règle transversale : chaque objet “métier” porte `societe_interne_id` et l’accès est filtré par `user_societes`.
Rôles : ADMIN, GESTIONNAIRE, COMPTABLE, LECTURE.
Recommandations pro :
- Validation indexation : Admin ou permission assignable.
- Corrections période passée : autorisées (gestionnaire) mais déclenchent alerte + journal.

## 5) Workflows clés (résumé)
- **Création bail** : saisie parties, lot, dates, financier, indexation ; si interne et réciprocité requise -> créer/assurer bail miroir (sens opposé).
- **Génération échéances** : selon périodicité ; anti-doublon (unique bail+periode) ; statuts ; possibilité avoirs.
- **Rapprochement** : N:N via `paiement_allocations`, tolérance 1€ ; trop-perçu au choix (avance / remboursement).
- **Indexations entrantes** : réception -> contrôle (indices) -> statut -> application auto (échéances, loyer).
- **Provisions indexation** : non-cumulatives ; calcul sur période choisie si indexation non reçue.
- **Impayés/relances** : impayé proposé J+10 ; relances J+10/J+20/J+30 ; plan d’apurement.
- **Charges/régularisations** : charges refacturables + justificatifs ; création régularisation.
- **CA** : import CA -> calcul loyer variable -> application.

## 6) Catalogue alertes conformité (V1 — avertissement uniquement)
- MissingExigibilite : jour d’exigibilité manquant.
- NegativeRent : échéance loyer négative.
- IndexationClauseNoConfig : clause prévue mais config inexistante/inactive.
- ChevauchementBailActif : chevauchement de baux actifs sur un lot.
- IndexationEcartFort : écart fort entre demandé et calcul.
- RetroactNonAutorisee : rétroactivité sur bail particulier.
- ModifPeriodePassee : modification d’une période passée.
- SocieteInterneMismatch : incohérence société interne vs bail/échéance/paiement.
- BailInterneSansMiroir : bail interne sans bail miroir.

## 7) Données & modèle (tables)
Le schéma DB est implémenté dans `db/init/001_schema.sql` + seed dans `db/init/002_seed.sql`.
Tables principales :
- Référentiels : entites, societes_internes, proprietes, propriete_societes, biens
- Exploitation : baux, config_index, indices, echeances, paiements, paiement_allocations
- Gestion avancée : indexations_soumises, loyers_variables_ca, charges_refacturables, relances, plans_apurement, plan_apurement_lignes
- Pilotage/audit : budgets, provisions_indexation, documents, alertes_conformite, journal_actions
- Sécurité : user_societes

## 8) Convention période
- Champ `periode` = mois au format `AAAA-MM` représentant **le mois de début** de la période couverte.

## 9) Bail miroir (réciprocité interne)
- Si bail interne (bailleur interne & preneur interne) et `interne_reciprocite_requise = true` :
  - création automatique d’un bail miroir (sens opposé) lié par `bail_miroir_id` des deux côtés,
  - mêmes dates/lot, montants miroir si nécessaire (à préciser dans la logique métier),
  - alertes si manquant.

## 10) Codex / agent — définition de “fait”
- DB Postgres avec contraintes de cohérence (anti-chevauchement baux actifs, anti-doublons échéances, etc.).
- Directus prêt : collections visibles, relations OK, champs *_id en dropdown lisible.
- Séparation par société interne implémentée (au minimum via filtres Directus + table user_societes).
- Seed minimal disponible.

