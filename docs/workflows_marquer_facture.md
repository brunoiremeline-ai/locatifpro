But: marquer des échéances PREVISIONNEL en FACTURE sans créer de facture.
Commande: `./scripts/run_marquer_echeances_facturees.sh 2026-03-31`
Commande (bail): `./scripts/run_marquer_echeances_facturees.sh 2026-03-31 <bail_uuid>`
Commande (bail + société): `./scripts/run_marquer_echeances_facturees.sh 2026-03-31 <bail_uuid> <societe_uuid>`
Idempotent: relancer ne modifie rien si déjà FACTURE/PAYE/LITIGE.
