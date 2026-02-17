# API Directus 11 - Explication des APIs utilisées dans refresh-dash

## 1️⃣ Signature d'extension endpoint

```typescript
// Signature TypeScript (Directus 11)
export default function registerEndpoint(
  router: Router,
  { database, logger }: { database: Database; logger: Logger }
) {
  // router = Express Router instance
  // database = Knex query builder (avec sécurité Directus)
  // logger = Pino logger (async, structuré)
}
```

### Qu'est-ce que Directus fournit ?

| Paramètre | Type | Fournisseur | Utilisé pour |
|-----------|------|-------------|--------------|
| `router` | Express.Router | Directus | Définir routes HTTP |
| `database` | Knex + Directus | Directus | Accéder à la DB |
| `logger` | Pino | Directus | Logger les opérations |

---

## 2️⃣ API `router` (Express Router)

### Définir une route GET

```typescript
router.get('/path', async (req, res) => {
  // req.query   = Paramètres URL (?key=value)
  // req.params  = Paramètres de route (/user/:id)
  // req.body    = Corps de la requête (JSON)
  // req.headers = En-têtes HTTP
  
  res.json({ data: 'success' });       // Réponse 200 JSON
  res.status(404).json({ error: '...' }); // Réponse 404
});
```

### Autres méthodes HTTP

```typescript
router.post('/endpoint', async (req, res) => { /* */ });
router.put('/endpoint/:id', async (req, res) => { /* */ });
router.patch('/endpoint/:id', async (req, res) => { /* */ });
router.delete('/endpoint/:id', async (req, res) => { /* */ });
```

### Paramètres de route

```typescript
router.get('/item/:id', async (req, res) => {
  const itemId = req.params.id;  // ID depuis l'URL
  res.json({ id: itemId });
});

// Appel : GET /item/123
// req.params.id = "123"
```

---

## 3️⃣ API `database` (Knex + Directus)

### Requête SQL brute

```typescript
const result = await database.raw(`
  SELECT id, name FROM users WHERE status = $1
`, ['active']);

// result = { rows: [ { id, name }, ... ], rowCount, ... }
// ou directement array selon le driver
```

### Query builder Knex (préféré)

```typescript
const users = await database('users')
  .select('id', 'name')
  .where('status', 'active')
  .orderBy('name');

// Sans SQL brut = sûr des injections SQL
```

### Opérations CRUD

```typescript
// CREATE
const newUser = await database('users').insert({
  email: 'user@example.com',
  name: 'John'
});

// READ
const user = await database('users').where('id', userId).first();

// UPDATE
await database('users').where('id', userId).update({
  name: 'Jane'
});

// DELETE
await database('users').where('id', userId).delete();
```

### Transactions (atomique)

```typescript
await database.transaction(async (trx) => {
  // Toutes les opérations dans cette fonction
  // sont dans la même transaction
  
  const account = await trx('accounts').where('id', 123).first();
  await trx('transactions').insert({
    account_id: 123,
    amount: 100
  });
  
  // Si erreur → rollback automatique
  // Si succès → commit atomique
});
```

### Paramètres positionnels (sécurité SQL injection)

```typescript
// ✅ BON - Paramètre $1 safe
await database.raw(
  'SELECT * FROM users WHERE id = $1',
  [userId]
);

// ❌ MAUVAIS - Concaténation risquée
await database.raw(
  `SELECT * FROM users WHERE id = ${userId}` // SQL injection!
);
```

### Gestion des résultats

```typescript
const result = await database.raw(`
  SELECT COUNT(*) as cnt FROM articles
`);

// Résultats selon le dialecte DB :
// PostgreSQL:
//   result.rows[0].cnt = 42

// MySQL:
//   result[0].cnt = 42

// Directus normalize souvent en .rows
const count = result.rows 
  ? result.rows[0].cnt 
  : result[0].cnt;
```

---

## 4️⃣ API `logger` (Pino)

### Niveaux de log

```typescript
logger.debug('Diagnostic info');      // Niveau DEBUG (développement)
logger.info('Operation successful');  // Niveau INFO (normal)
logger.warn('System low memory');     // Niveau WARN (attention)
logger.error('Database error', error); // Niveau ERROR (critique)
logger.fatal('System crash');         // Niveau FATAL (arrêt du service)
```

### Objet structuré

```typescript
logger.info('User created', {
  user_id: '123',
  email: 'test@example.com',
  timestamp: new Date()
});

// Log output (JSON structuré)
// {"level": 30, "time": "...", "msg": "User created", "user_id": "123", ...}
```

### Gestion d'erreurs

```typescript
try {
  // ...
} catch (error) {
  // Logguer l'erreur avec contexte
  logger.error('Operation failed', {
    error: error.message,
    code: error.code,
    stack: error.stack
  });
}
```

---

## 5️⃣ Exemple complet : Endpoint avec tous les APIs

```typescript
// src/index.ts
import type { Router } from 'express';
import type { Database } from 'directus';
import type { Logger } from 'pino';

export default function registerEndpoint(
  router: Router,
  { database, logger }: { database: Database; logger: Logger }
) {
  // GET /balance/:userId - Récupérer le solde d'un utilisateur
  router.get('/balance/:userId', async (req, res) => {
    try {
      const userId = req.params.userId;
      
      // Validation
      if (!userId) {
        return res.status(400).json({
          error: 'userId required'
        });
      }

      logger.debug('Fetching balance for user', { userId });

      // Requête DB sûre
      const result = await database.raw(
        'SELECT id, email, balance FROM users WHERE id = $1',
        [userId]
      );

      const user = result.rows ? result.rows[0] : result[0];

      if (!user) {
        logger.info('User not found', { userId });
        return res.status(404).json({
          error: 'User not found'
        });
      }

      logger.info('Balance fetched', {
        userId,
        balance: user.balance
      });

      // Réponse structurée
      res.json({
        ok: true,
        data: {
          user_id: user.id,
          email: user.email,
          balance: parseFloat(user.balance)
        },
        at: new Date().toISOString()
      });

    } catch (error) {
      logger.error('Endpoint error', {
        error: error instanceof Error ? error.message : String(error),
        userId: req.params.userId
      });

      res.status(500).json({
        ok: false,
        error: 'Internal server error',
        at: new Date().toISOString()
      });
    }
  });

  // POST /transfer - Transférer de l'argent (atomique)
  router.post('/transfer', async (req, res) => {
    try {
      const { from_id, to_id, amount } = req.body;

      // Validations
      if (!from_id || !to_id || !amount || amount <= 0) {
        return res.status(400).json({
          error: 'Invalid parameters'
        });
      }

      logger.info('Transfer requested', { from_id, to_id, amount });

      // Transaction atomique
      const result = await database.transaction(async (trx) => {
        // 1. Vérifier solde suffisant
        const fromUser = await trx('users')
          .where('id', from_id)
          .first();

        if (!fromUser || fromUser.balance < amount) {
          throw new Error('Insufficient balance');
        }

        // 2. Débiter compte source
        await trx('users')
          .where('id', from_id)
          .decrement('balance', amount);

        // 3. Créditer compte destination
        await trx('users')
          .where('id', to_id)
          .increment('balance', amount);

        // 4. Enregistrer la transaction
        await trx('transactions').insert({
          from_user_id: from_id,
          to_user_id: to_id,
          amount,
          status: 'COMPLETED',
          created_at: new Date()
        });

        return { success: true };
      });

      logger.info('Transfer completed', {
        from_id,
        to_id,
        amount
      });

      res.json({
        ok: true,
        message: 'Transfer completed',
        at: new Date().toISOString()
      });

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      
      logger.error('Transfer failed', {
        error: errorMsg,
        from_id: req.body.from_id,
        to_id: req.body.to_id
      });

      res.status(400).json({
        ok: false,
        error: errorMsg,
        at: new Date().toISOString()
      });
    }
  });
}
```

### Appels API

```bash
# GET: Récupérer solde
curl http://localhost:8055/balance/user-123

# Réponse 200
{
  "ok": true,
  "data": {
    "user_id": "user-123",
    "email": "john@example.com",
    "balance": 1000.00
  },
  "at": "2025-02-14T10:45:23.456Z"
}

# POST: Transférer
curl -X POST http://localhost:8055/transfer \
  -H "Content-Type: application/json" \
  -d '{"from_id": "user-123", "to_id": "user-456", "amount": 100}'

# Réponse 200
{
  "ok": true,
  "message": "Transfer completed",
  "at": "2025-02-14T10:45:23.456Z"
}
```

---

## 6️⃣ API Directus avancée - DirectusContext

### Contexte complet reçu par l'extension

```typescript
export default function registerEndpoint(
  router: Router,
  {
    database,              // Knex + sécurité Directus
    logger,                // Pino
    getSchema,             // async () => Schema
    accountability,        // Utilisateur courant
    services,              // Services système
    env                    // Variables d'environnement
  }: DirectusContext
) { }
```

### Utilisation avancée

```typescript
// Récupérer le schéma des collections
const schema = await getSchema();
const collectionFields = schema.collections['users'].fields;

// Vérifier les permissions de l'utilisateur
if (!accountability?.admin) {
  return res.status(403).json({ error: 'Admin required' });
}

// Services Directus (pour opérations système)
const { ItemsService, UsersService } = services;

// Accéder à variables d'env
const secretKey = env['SECRET_API_KEY'];
```

---

## 7️⃣ Sécurité - Bonnes pratiques Directus

### Valider accountability

```typescript
router.post('/admin-action', async (req, res) => {
  // Vérifier que c'est un admin
  if (!accountability?.admin) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  
  // Opération admin sûre
  // ...
});
```

### Respecter les permissions Directus

```typescript
// ✅ BON - Utiliser le context accountability
const { ItemsService } = services;
const itemsService = new ItemsService('articles', {
  knex: database,
  accountability    // Respecte permissions RLS automatiquement
});

// ❌ MAUVAIS - Ignorer accountability
await database('articles').select(); // Pas de vérification permissions!
```

### Éviter les requêtes SQL directes sensibles

```typescript
// ✅ BON - Builder Knex avec sécurité
await database('users')
  .where('id', userId)
  .select('email', 'name');

// ❌ MAUVAIS - SQL brut sans paramètres
await database.raw(`
  SELECT * FROM users WHERE id = ${userId}`  // SQL injection!
);
```

---

## 📖 Résumé - Hiérarchie des APIs

```
┌─────────────────────────────────────────────────────────┐
│ Directus Extension Entry Point                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Router (Express)                                       │
│  ├── .get(path, handler)                               │
│  ├── .post(path, handler)                              │
│  ├── .put(path, handler)                               │
│  ├── .patch(path, handler)                             │
│  └── .delete(path, handler)                            │
│                                                         │
│  Database (Knex + Directus)                            │
│  ├── .raw(sql, [params])     → Requêtes SQL brutes    │
│  ├── (table).select(...)     → Query builder          │
│  ├── .transaction(fn)         → Opération atomique    │
│  └── Applique RLS/permissions autom.                  │
│                                                         │
│  Logger (Pino)                                          │
│  ├── .debug(msg)                                       │
│  ├── .info(msg)                                        │
│  ├── .warn(msg)                                        │
│  ├── .error(msg, { context })                         │
│  └── Output: logs Directus                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

