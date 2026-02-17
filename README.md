# LocatifPro (bootstrap Codex)

Ce dépôt contient le **socle exécutable** (Postgres + Directus) du projet LocatifPro, basé sur les documents de besoin V2.

## Démarrage (1 commande)
```bash
./scripts/bootstrap.sh
```

- Directus : http://localhost:8055
- Admin : **auto** (prend ton email Git si disponible) / `Admin123!ChangeMe`  
  (sinon fallback `admin@example.com`)

## Docs
- Spéc consolidée agent : `docs/requirements/V2_master_spec.md`
- Sources : `docs/sources/`

## DB
- Schéma : `db/init/001_schema.sql`
- Seed minimal : `db/init/002_seed.sql`

## Configuration (optionnel)
- Duplique `.env.example` en `.env` pour fixer ADMIN_EMAIL/ADMIN_PASSWORD/PUBLIC_URL.
