**Workflow Échéances**
Ce workflow génère les échéances à partir des baux actifs de manière idempotente. Il est 100% scripté et ne nécessite aucun clic UI. `./scripts/dev_apply.sh` n’est pas requis ici.

**Commandes**
- Génération avec dates par défaut (mois courant -> +12 mois)
```
./scripts/run_generate_echeances.sh
```
- Génération avec fenêtre explicite
```
./scripts/run_generate_echeances.sh 2026-01-01 2026-12-31
```

**Validation Rapide**
1. Reset + bootstrap (si nécessaire)
```
./scripts/dev_reset.sh
./scripts/bootstrap.sh
```
2. Générer 3 mois d’échéances
```
./scripts/run_generate_echeances.sh 2026-01-01 2026-03-31
```
3. Afficher le nombre d’échéances par bail
```
docker compose exec -T db psql -U locatifpro -d locatifpro -c "SELECT bail_id, count(*) FROM echeances GROUP BY bail_id ORDER BY count(*) DESC;"
```
