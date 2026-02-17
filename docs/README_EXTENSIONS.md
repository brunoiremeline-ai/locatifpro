# Index - Extension Directus 11 `refresh-dash`

## Objectif

Cette extension expose `GET /refresh-dash` pour rafraichir les tables `dash_*` depuis les vues `v_*`.

## Fichiers réels (implémentation)

| Fichier | Rôle |
|---|---|
| [`../directus/extensions/directus-extension-endpoint-refresh-dash/index.js`](../directus/extensions/directus-extension-endpoint-refresh-dash/index.js) | Handler endpoint (`id: refresh-dash`) |
| [`../directus/extensions/directus-extension-endpoint-refresh-dash/package.json`](../directus/extensions/directus-extension-endpoint-refresh-dash/package.json) | Manifeste Directus v11 (`directus:extension`) |

## Documentation projet

| Fichier | Contenu |
|---|---|
| [`./DIRECTUS_11_EXTENSIONS_GUIDE.md`](./DIRECTUS_11_EXTENSIONS_GUIDE.md) | Concepts/extensions Directus 11 |
| [`./DIRECTUS_11_API_REFERENCE.md`](./DIRECTUS_11_API_REFERENCE.md) | Référence API utilisée par l'endpoint |
| [`../EXTENSION_REFRESH_DASH_SUMMARY.md`](../EXTENSION_REFRESH_DASH_SUMMARY.md) | Résumé du livrable |
| [`../EXTENSION_WORK_COMPLETE.md`](../EXTENSION_WORK_COMPLETE.md) | Historique détaillé du chantier |

## Vérification rapide

1. Démarrer la stack:
   - `./scripts/bootstrap.sh`
2. Vérifier la santé Directus:
   - `curl http://localhost:8055/server/health`
3. Tester l'endpoint:
   - sans token: `GET /refresh-dash` -> `401`
   - avec token: `GET /refresh-dash` -> `200` + `ok: true`
4. Test automatisé:
   - `pytest -q test_refresh_dash.py`

## Notes

- Le runtime actuel utilise uniquement `index.js` (pas de `dist/`).
- Le manifeste est aligné Directus v11 (`host`, `path`, `source`).
