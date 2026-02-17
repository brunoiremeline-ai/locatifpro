# Extensions Directus 11 - Guide de structure et points de contribution

## Aperçu de la structure

Directus 11 utilise un système d'extensions basé sur **type + source** définis dans `package.json` :

```json
{
  "directus:extension": {
    "type": "endpoint|panel|operation|hook|interface|layout",
    "source": "src/index.ts ou src/index.js",
    "path": "chemin-personnalisé"
  }
}
```

## Points de contribution (Contribution Points) - Directus 11

### 1. **endpoint** - Extension d'API REST

**Signature :**
```typescript
export default function (
  router: Express.Router,
  { database, logger, getSchema, accountability }: DirectusContext
) {
  // Enregistrer des routes
  router.get('/my-endpoint', (req, res) => {
    res.json({ /* ... */ });
  });
}
```

**Fichier source :** `src/index.ts`  
**Routes exposées :** `/my-endpoint` (auto-préfixé)  
**Cas d'usage :**
- Endpoints personnalisés (webhooks, triggers externes)
- Intégrations personnalisées (dashboard refresh, imports/exports)
- Operations métier complexes

**Notre implémentation :** `GET /refresh-dash`

---

### 2. **hook** - Écouteurs d'événements système

**Types d'événements :**
- `items.create`, `items.read`, `items.update`, `items.delete`
- `collections.create`, `collections.update`
- `users.login`, `users.logout`

**Signature :**
```typescript
export default function (register: HookRegister) {
  register('items.create.before', async (meta) => {
    // Middleware : avant la création
    return meta;
  });
  
  register('items.update.after', async (meta) => {
    // Callback : après la mise à jour
  });
}
```

**Cas d'usage :**
- Validation métier (avant créer/modifier)
- Audit logging (après chaque action)
- Synchronisation avec systèmes externes

---

### 3. **operation** - Étape de workflow

**Signature :**
```typescript
export default {
  id: 'operation-id',
  name: 'Operation Name',
  icon: 'extension_icon',
  description: 'Description',
  
  overview: (config) => {
    // Affichage du résumé dans l'interface
    return [{ label: 'Label', text: config.field_name }];
  },
  
  options: [
    {
      field: 'example_field',
      name: 'Example Field',
      type: 'string',
      interface: 'input'
    }
  ],
  
  run: async (data, { services }) => {
    // Logique d'exécution dans le workflow
    return { result: 'value' };
  }
};
```

**Cas d'usage :**
- Étapes de workflow personnalisées
- Automation métier (génération d'échéances, paiements, etc.)

---

### 4. **interface** - Interface personnalisée pour un champ

**Signature :**
```typescript
export { default } from './interface.vue';

export const details = {
  id: 'custom-interface',
  name: 'Custom Interface',
  description: 'Description',
  icon: 'extension',
  component: InterfaceComponent,
  types: ['string', 'text'],  // Types de champs acceptés
  options: [ /* configurable options */ ]
};
```

**Cas d'usage :**
- Inputs personnalisés (rich text, code editor, draggable list)
- Affichage customisé (preview image, map, timeline)

---

### 5. **panel** - Component pour Dashboard

**Signature :**
```typescript
export { default } from './panel.vue';

export const details = {
  id: 'custom-panel',
  name: 'Custom Panel',
  description: 'Description',
  icon: 'dashboard_customize',
  component: PanelComponent,
  options: [ /* configurable options */ ]
};
```

**Cas d'usage :**
- Panneaux de dashboard personnalisés
- KPI réels (graphiques, statistiques)
- Embedded apps (cartes, workflows visuels)

---

### 6. **layout** - Affichage personnalisé des collections

**Signature :**
```typescript
export { default } from './layout.vue';

export const details = {
  id: 'custom-layout',
  name: 'Custom Layout',
  icon: 'dashboard',
  component: LayoutComponent,
  tabular: false,
  options: [ /* configurable options */ ]
};
```

**Cas d'usage :**
- Galerie d'images
- Timeline (événements dans le temps)
- Kanban (colonnes draggables)
- Carte géographique

---

## Comparaison des types d'extension

| Type | Accès DB | Côté | Async | Cas d'usage |
|------|----------|------|-------|-----------|
| **endpoint** | ✅ | Backend | ✅ | API REST custom, webhooks |
| **hook** | ✅ | Backend | ✅ | Événements, validation, audit |
| **operation** | ✅ | Backend | ✅ | Étapes workflow |
| **interface** | ❌ | Frontend | ❌ | Input/affichage champs |
| **panel** | ✅ (API) | Frontend | ✅ | Dashboard custom |
| **layout** | ✅ (API) | Frontend | ✅ | Affichage collection |

---

## Architecture - Contexte Directus (DirectusContext)

```typescript
{
  database: Database,              // Knex + sécurité Directus (RLS, permissions)
  logger: Logger,                  // Pino logger
  getSchema: () => Schema,         // Schéma des collections/fields
  accountability?: {               // Info sur l'utilisateur/rôle courant
    user?: string,
    role?: string,
    admin?: boolean
  },
  services,                        // Services système (UsersService, etc.)
  env                              // Variables d'environnement
}
```

---

## Structure physique du projet

```
directus/
├── extensions/
│   └── directus-extension-endpoint-refresh-dash/
│       ├── src/
│       │   └── index.ts                    # Point d'entrée TypeScript
│       ├── dist/
│       │   ├── index.js                    # JavaScript compilé
│       │   ├── index.d.ts                  # Type definitions
│       │   └── index.js.map                # Source map
│       ├── package.json                    # Métadonnées + directus:extension
│       ├── tsconfig.json                   # Config TypeScript
│       ├── README.md                       # Documentation
│       └── .gitignore
├── snapshot.yaml                           # Snapshot Directus
└── ...
```

---

## Processus de compilation - Directus 11

1. **Startup** : Docker lance le container Directus avec volume `./directus/extensions`
2. **Discovery** : Directus scanne `/directus/extensions/` pour `package.json` avec `directus:extension`
3. **Compilation** : Chaque extension `.ts` est compilée via `tsc` en `.js`
4. **Registration** : Routes/hooks/panels sont enregistrés
5. **Runtime** : Extensions disponibles immédiatement (WebSocket sync)

### Force-reload d'une extension

```bash
# Redémarrer le service Directus
docker compose restart directus

# Ou attendre ~5s et refresh du browser (WebSocket notify)
```

---

## Bonnes pratiques - Directus 11

### ✅ DO

- **UserSpace** : Accepter l'`accountability` de l'utilisateur courant
- **Transactions** : Wrapper opérations multi-tables dans `database.transaction()`
- **Logging** : Utiliser `logger.*` pour tous les messages
- **Types** : Importer types depuis `directus` package
- **Source TypeScript** : Toujours fournir `src/index.ts` (Directus compile)
- **Validations** : Checker permissions et données avant opérations
- **Error handling** : Capturer et logger erreurs plutôt que crasher

### ❌ DON'T

- **Accès direct Knex** : Éviter `require('knex')` → utiliser `database` du contexte
- **SQL brut non sécurisé** : Ne jamais concaténer user input dans SQL
- **Hardcoder secrets** : Utiliser variables d'environnement
- **Async sans await** : Toujours attendre les promesses de DB/réseau
- **Ignorer accountability** : Respecter RLS et permissions système

---

## Exemple complet - Endpoint avec validations

```typescript
import type { Router } from 'express';
import type { Database, Logger } from 'directus';

export default function registerEndpoint(
  router: Router,
  { database, logger, accountability }: { database: Database; logger: Logger; accountability }
) {
  router.post('/custom-operation', async (req, res) => {
    try {
      // 1. Valider l'utilisateur
      if (!accountability?.user) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      // 2. Valider les données d'entrée
      const { collection, values } = req.body;
      if (!collection || !values) {
        return res.status(400).json({ error: 'Missing required fields' });
      }

      // 3. Opération en transaction
      const result = await database.transaction(async (trx) => {
        const itemService = new ItemsService(collection, { knex: trx, accountability });
        return await itemService.createOne(values);
      });

      // 4. Log succès
      logger.info('Custom operation completed', { user: accountability.user, collection, result });

      // 5. Retourner réponse
      res.json({ ok: true, data: result });
    } catch (error) {
      logger.error('Custom operation failed', { error: error.message });
      res.status(500).json({ error: error.message });
    }
  });
}
```

---

## Ressources

- **Documentation officielle** : https://docs.directus.io/extensions/
- **SDK TypeScript** : https://docs.directus.io/extensions/sdk.html
- **Exemples** : https://github.com/directus/directus/tree/main/packages/extensions-sdk

---

## Résumé - Choisir le bon type

| Vous voulez... | Utilisez |
|---|---|
| Exposer une API REST | **endpoint** |
| Valider/modifier avant sauvegarde | **hook** |
| Créer une étape de workflow | **operation** |
| Custom input pour un champ | **interface** |
| Dashboard avec données métier | **panel** |
| Affichage alternatif des collections | **layout** |

