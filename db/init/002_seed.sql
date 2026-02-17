-- LocatifPro (V2) - Seed minimal (données de démonstration)
-- Objectif: permettre de tester immédiatement listes, relations, échéances/paiements/allocations.

-- Entités (internes + externes)
INSERT INTO entites (id, code, nom_affichage, type_entite, perimetre, groupe_interne, sous_groupe_interne, siren, ville, pays, contact_email)
VALUES
('11111111-1111-1111-1111-111111111111','ENT-IMMO','CREO IMMO','SOCIETE','INTERNE','CREO','IMMO','000000000','Paris','FR','immo@creo.local'),
('22222222-2222-2222-2222-222222222222','ENT-BAIL-EXT','Bailleur Externe SARL','SOCIETE','EXTERNE',NULL,NULL,'123456789','Lyon','FR','contact@bailleur-ext.example'),
('33333333-3333-3333-3333-333333333333','ENT-LOC-EXT','Locataire Externe SAS','SOCIETE','EXTERNE',NULL,NULL,'234567890','Marseille','FR','compta@locataire-ext.example'),
('44444444-4444-4444-4444-444444444444','ENT-PREN-INT','CREO Retail','SOCIETE','INTERNE','CREO','RETAIL','345678901','Paris','FR','retail@creo.local')
ON CONFLICT (id) DO NOTHING;

-- Sociétés internes (périmètre)
INSERT INTO societes_internes (id, code, entite_id, groupe_interne, sous_groupe, is_active)
VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','SOC-IMMO-1','11111111-1111-1111-1111-111111111111','CREO','IMMO',true),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','SOC-IMMO-2','11111111-1111-1111-1111-111111111111','CREO','IMMO2',true)
ON CONFLICT (id) DO NOTHING;

-- Propriété + rattachement société
INSERT INTO proprietes (id, code, nom, nature, type_propriete, adresse_ligne1, code_postal, ville, pays, surface_totale, commentaire, is_active)
VALUES
('c0c0c0c0-c0c0-c0c0-c0c0-c0c0c0c0c0c0','PRO-001','Immeuble République','Urbain','Immeuble','10 Rue de la République','75001','Paris','FR',1200,'Immeuble test',true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO propriete_societes (id, propriete_id, societe_interne_id, quote_part_pct, date_debut, date_fin, par_defaut, is_active)
VALUES
('d0d0d0d0-d0d0-d0d0-d0d0-d0d0d0d0d0d0','c0c0c0c0-c0c0-c0c0-c0c0-c0c0c0c0c0c0','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',100,'2020-01-01',NULL,true,true)
ON CONFLICT (id) DO NOTHING;

-- Lots
INSERT INTO biens (id, code, ref_unite, propriete_id, type_bien, surface, etage, commentaire, is_active)
VALUES
('e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0','LOT-A12','A12','c0c0c0c0-c0c0-c0c0-c0c0-c0c0c0c0c0c0','Lot',85,'RDC','Boutique',true),
('f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0','LOT-A13','A13','c0c0c0c0-c0c0-c0c0-c0c0-c0c0c0c0c0c0','Lot',92,'R+1','Bureau',true)
ON CONFLICT (id) DO NOTHING;

-- Baux (1 sortant + 1 entrant)
INSERT INTO baux (
  id, code, statut, sens, relation, bien_id, societe_interne_id,
  bailleur_entite_id, preneur_entite_id, type_bail, date_effet, date_fin_contractuelle,
  reconduction, periodicite, date_exigibilite_jour,
  loyer_base, charges_mode, charges_provision, tf_refacturable, tf_provision,
  indexation_clause_prevue, indexation_active, loyer_variable_pct_ca,
  loyer_variable_plancher_mode, loyer_variable_plancher_valeur_base,
  loyer_variable_plafond_mode, loyer_variable_plafond_valeur_base,
  interne_reciprocite_requise, bail_miroir_id
) VALUES
('01010101-0101-0101-0101-010101010101','B-SOCIMMO1-LOCEXT-A12-01','ACTIF','SORTANT','DIRECT','e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
 '11111111-1111-1111-1111-111111111111','33333333-3333-3333-3333-333333333333','COMMERCIAL','2025-01-01',NULL,
 'TACITE','MENSUEL',5,
 2500,'PROVISIONS',200,true,0,
 true,true,NULL,
 NULL,NULL,NULL,NULL,
 false,NULL),
('02020202-0202-0202-0202-020202020202','B-SOCIMMO1-BAILEXT-A13-01','ACTIF','ENTRANT','DIRECT','f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
 '22222222-2222-2222-2222-222222222222','44444444-4444-4444-4444-444444444444','COMMERCIAL','2024-06-01',NULL,
 'TACITE','MENSUEL',1,
 1800,'FORFAIT',0,false,0,
 true,true,3.0,
 'FIXE',1500,'FIXE',4000,
 false,NULL)
ON CONFLICT (id) DO NOTHING;

-- Config indexation (par bail)
INSERT INTO config_index (
  id, bail_id, indice, frequence, date_revision_mode, date_revision_fixe,
  cap_pct, floor_pct, cap_eur, floor_eur, min_loyer, max_loyer, actif
) VALUES
('03030303-0303-0303-0303-030303030303','01010101-0101-0101-0101-010101010101','ILC','ANNUELLE','ANNIVERSAIRE',NULL, 10, NULL, NULL, NULL, NULL, NULL, true),
('04040404-0404-0404-0404-040404040404','02020202-0202-0202-0202-020202020202','ILC','ANNUELLE','ANNIVERSAIRE',NULL, 10, NULL, NULL, NULL, 1500, 4000, true)
ON CONFLICT (id) DO NOTHING;

-- Indices (exemples)
INSERT INTO indices (id, type_indice, periode, annee, valeur_indice, date_publication, source)
VALUES
('05050505-0505-0505-0505-050505050505','ILC','2024-T2',2024,130.00,'2024-09-15','INSEE'),
('06060606-0606-0606-0606-060606060606','ILC','2025-T2',2025,135.00,'2025-09-15','INSEE')
ON CONFLICT (id) DO NOTHING;

-- Échéances (mois courant)
INSERT INTO echeances (
  id, bail_id, societe_interne_id, periode, date_debut_periode, date_fin_periode, date_echeance,
  montant_loyer, montant_charges, montant_taxe_fonciere_refacturee,
  statut, indexation_appliquee, impaye_flag
) VALUES
('07070707-0707-0707-0707-070707070707','01010101-0101-0101-0101-010101010101','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','2026-01','2026-01-01','2026-01-31','2026-01-05',2500,200,0,'FACTURE',false,false),
('08080808-0808-0808-0808-080808080808','01010101-0101-0101-0101-010101010101','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','2026-02','2026-02-01','2026-02-28','2026-02-05',2500,200,0,'FACTURE',false,false)
ON CONFLICT (id) DO NOTHING;

-- Paiement + allocation partielle sur une échéance
INSERT INTO paiements (id, reference_paiement, date_paiement, montant, societe_interne_id, contrepartie_entite_id, mode_paiement, source_import, commentaire)
VALUES
('09090909-0909-0909-0909-090909090909','VIR-2026-02-001','2026-02-06',1500,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','33333333-3333-3333-3333-333333333333','VIREMENT','seed','Paiement partiel')
ON CONFLICT (id) DO NOTHING;

INSERT INTO paiement_allocations (id, paiement_id, echeance_id, montant_alloue, created_by)
VALUES
('0a0a0a0a-0a0a-0a0a-0a0a-0a0a0a0a0a0a','09090909-0909-0909-0909-090909090909','08080808-0808-0808-0808-080808080808',1500,'seed')
ON CONFLICT (id) DO NOTHING;

-- Journal actions (exemple)
INSERT INTO journal_actions (id, action, utilisateur, bail_id, periode, details)
VALUES
('0b0b0b0b-0b0b-0b0b-0b0b-0b0b0b0b0b0b','SeedInit','system','01010101-0101-0101-0101-010101010101','2026-02','{\"note\":\"seed minimal\"}')
ON CONFLICT (id) DO NOTHING;
