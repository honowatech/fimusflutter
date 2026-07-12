# MoniTrack — Conception du Backoffice & Backend

> Document de conception — à valider avant toute implémentation.
> Date : 2026-06-18
> Statut : **Brouillon / Proposition**

---

## 1. Analyse de l'existant (frontend Flutter)

### 1.1 Ce qu'est MoniTrack aujourd'hui

MoniTrack est une **application mobile Flutter** destinée au marché africain francophone,
centrée sur la gestion de l'argent mobile (Mobile Money) et le suivi des dépenses personnelles.

### 1.2 Fonctionnalités actuelles (côté application)

| Module | Description | Modèle de données |
|---|---|---|
| **Opérateurs télécoms** | Orange Money, MTN MoMo (extensible), avec le numéro de l'utilisateur | `TelecomOperator` |
| **Codes USSD** | Opérations configurables (transfert, solde, crédit, etc.) avec templates personnalisables | `UssdOperation` |
| **Exécution USSD** | Lancement direct d'appels USSD via `flutter_phone_direct_caller` | — (service) |
| **Historique USSD** | Journal des opérations exécutées | `UssdHistory` |
| **Dépenses** | Suivi des dépenses avec catégories et filtres temporels | `Expense` |
| **Catégories** | Deux jeux distincts : catégories USSD et catégories de dépenses | `List<String>` |
| **Profil utilisateur** | Prénom, nom, photo de profil (chemin local) | `UserProfile` |

### 1.3 Limites critiques de l'architecture actuelle

```
┌──────────────────────────────────────────────┐
│  Application Flutter                         │
│  ┌────────────────────────────────────────┐  │
│  │  Providers (ChangeNotifier)            │  │
│  │  └─ Lecture/écriture → SharedPreferences│  │  ◀── STOCKAGE 100% LOCAL
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

| Problème | Impact |
|---|---|
| **Stockage uniquement local** (`SharedPreferences`) | Perte totale des données si désinstallation / changement d'appareil / reset |
| **Aucune authentification** | Pas d'identité utilisateur, pas de compte |
| **Aucune synchronisation cloud** | Pas de multi-appareil, pas de sauvegarde |
| **Photo de profil stockée en chemin local** | Perdue à la désinstallation |
| **Pas de partage / restauration** | Aucune portabilité des données |
| **Données non chiffrées en clair** dans SharedPreferences | Risque de confidentialité |

### 1.4 Conclusion de l'analyse

> La valeur produit de MoniTrack repose fortement sur l'historique financier de l'utilisateur.
> La **perte de données = perte de valeur**. Un backend de persistance est donc **un besoin produit majeur**,
> pas seulement une optimisation technique.

---

## 2. Objectifs du backoffice/backend à concevoir

### 2.1 Objectifs fonctionnels

1. **Sauvegarde durable** des données de chaque utilisateur (profil, opérateurs, opérations USSD, historique, dépenses, catégories).
2. **Authentification** des utilisateurs (création de compte, connexion, récupération de mot de passe).
3. **Synchronisation multi-appareil** : un utilisateur peut utiliser MoniTrack sur plusieurs téléphones.
4. **Restauration** : un nouvel appareil récupère automatiquement ses données après connexion.
5. **Backoffice d'administration** : pilotage de la plateforme (utilisateurs, opérateurs de référence, codes USSD par défaut, statistiques).

### 2.2 Objectifs non-fonctionnels

- **Confidentialité** : données financières → chiffrement au repos et en transit (HTTPS/TLS).
- **Disponibilité** : API stateless, scalable horizontalement.
- **Performance** : temps de réponse API < 300 ms (p95) pour les opérations de lecture/sync.
- **Évolutivité** : API versionnée, schéma de base migrable.
- **Coût maîtrisé** : pile adaptée à un projet en démarrage (faible coût initial, scalabilité progressive).

---

## 3. Architecture cible proposée

```
                         ┌───────────────────────────┐
                         │   Application Flutter      │
                         │  (HTTP client + DTO local) │
                         └─────────────┬─────────────┘
                                       │  HTTPS / JSON (REST)
                                       ▼
                         ┌───────────────────────────┐
                         │      API Backend (REST)    │
                         │  Auth · Sync · CRUD · Biz  │
                         └─────────────┬─────────────┘
                                       │
                ┌──────────────────────┼──────────────────────┐
                ▼                      ▼                      ▼
      ┌─────────────────┐   ┌──────────────────┐   ┌────────────────────┐
      │  Base de données │   │  Stockage fichiers│   │  Backoffice admin  │
      │  (relationnelle) │   │  (photos profil)  │   │  (interface web)   │
      └─────────────────┘   └──────────────────┘   └────────────────────┘
```

### 3.1 Trois blocs distincts

1. **Le Backend** (API) — cœur logique, auth, règles métier, accès données.
2. **La Base de données** — persistance fiable des données utilisateurs.
3. **Le Backoffice** — interface d'administration pour piloter la plateforme.

---

## 4. Stack technologique recommandée

### 4.1 Recommandation principale (justifiée)

| Couche | Technologie | Pourquoi |
|---|---|---|
| **API Backend** | **Node.js + NestJS** (TypeScript) | Structure modulaire, typage fort, excellent écosystème, courbe douce, idéal pour REST + auth |
| **Base de données** | **PostgreSQL** | Relationnel robuste, parfait pour données structurées (utilisateurs, transactions, historiques), gratuit et éprouvé |
| **ORM** | **Prisma** | Typé, migrations versionnées, DX excellente avec TypeScript |
| **Authentification** | **JWT (access + refresh tokens)** + hashing bcrypt | Standard, stateless, scalable ; alternative : Supabase Auth / Firebase Auth |
| **Stockage fichiers** | **S3-compatible** (AWS S3, Cloudflare R2, MinIO local) | Stockage d'objets pour photos de profil |
| **Backoffice admin** | **React + TypeScript + shadcn/ui** ou **Refine** | Interface rapide à construire, Refine apporte CRUD admin clé en main |
| **Hébergement** | Backend : Railway / Render / Fly.io ; DB : Neon / Supabase / Railway ; Fichiers : Cloudflare R2 | Faible coût initial, scalabilité progressive |
| **Conteneurisation** | **Docker + docker-compose** | Reproductibilité entre dev / prod |

### 4.2 Alternative « all-in-one » (si priorité = vélocité)

> **Supabase** (PostgreSQL managé + Auth + Storage + API auto-générée + Realtime)
>
> Avantage : backend quasi-clé en main, on code surtout le schéma SQL.
> Inconvénient : moins de contrôle, lock-in partiel, coût à grande échelle.

**Recommandation** : pour un MVP rapide → **Supabase**. Pour un produit pérenne avec logique métier riche → **NestJS + PostgreSQL**.

---

## 5. Modèle de données (schéma relationnel)

### 5.1 Entités principales

```
users (1) ──< (N) operators
users (1) ──< (N) ussd_operations
users (1) ──< (N) ussd_history
users (1) ──< (N) expenses
users (1) ──< (N) categories  (type: 'ussd' | 'expense')

operators (1) ──< (N) ussd_operations
```

### 5.2 Schéma SQL détaillé

```sql
-- ============================================================
-- UTILISATEURS
-- ============================================================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    phone           VARCHAR(20)  UNIQUE,         -- optionnel, utile pour Mobile Money
    password_hash   VARCHAR(255) NOT NULL,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    profile_picture_url VARCHAR(500),
    role            VARCHAR(20)  NOT NULL DEFAULT 'user',  -- 'user' | 'admin'
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ============================================================
-- OPÉRATEURS TÉLÉCOMS (par utilisateur)
-- ============================================================
CREATE TABLE operators (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name               VARCHAR(100) NOT NULL,
    user_phone_number  VARCHAR(20),
    is_default         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_operators_user ON operators(user_id);

-- ============================================================
-- OPÉRATIONS USSD (configurées par utilisateur)
-- ============================================================
CREATE TABLE ussd_operations (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id)     ON DELETE CASCADE,
    operator_id       UUID NOT NULL REFERENCES operators(id)  ON DELETE CASCADE,
    name              VARCHAR(150) NOT NULL,
    provider          VARCHAR(100) NOT NULL,   -- ex: 'Orange Money'
    category          VARCHAR(100) NOT NULL DEFAULT 'Autre',
    default_template  VARCHAR(255) NOT NULL,
    custom_template   VARCHAR(255),
    required_fields   JSONB NOT NULL DEFAULT '[]'::jsonb,   -- ['contact','amount']
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ussd_ops_user   ON ussd_operations(user_id);
CREATE INDEX idx_ussd_ops_oper   ON ussd_operations(operator_id);

-- ============================================================
-- HISTORIQUE DES OPÉRATIONS USSD EXÉCUTÉES
-- ============================================================
CREATE TABLE ussd_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    operation_name  VARCHAR(150) NOT NULL,
    provider_name   VARCHAR(100) NOT NULL,
    ussd_code       VARCHAR(255) NOT NULL,
    executed_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_history_user      ON ussd_history(user_id);
CREATE INDEX idx_history_executed  ON ussd_history(executed_at DESC);

-- ============================================================
-- DÉPENSES
-- ============================================================
CREATE TABLE expenses (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       VARCHAR(200) NOT NULL,
    amount      NUMERIC(12,2) NOT NULL,    -- CFA = entier, mais NUMERIC pour évolutivité
    category    VARCHAR(100) NOT NULL,
    note        TEXT,
    spent_at    TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_expenses_user   ON expenses(user_id);
CREATE INDEX idx_expenses_spent  ON expenses(spent_at DESC);

-- ============================================================
-- CATÉGORIES (USSD et Dépenses, distinguées par type)
-- ============================================================
CREATE TABLE categories (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        VARCHAR(20)  NOT NULL,   -- 'ussd' | 'expense'
    name        VARCHAR(100) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, type, name)
);

-- ============================================================
-- SYNCHRONISATION (audit et résolution de conflits)
-- ============================================================
CREATE TABLE sync_log (
    id           BIGSERIAL PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_type  VARCHAR(50) NOT NULL,
    entity_id    UUID NOT NULL,
    action       VARCHAR(10) NOT NULL,   -- 'create' | 'update' | 'delete'
    payload      JSONB,
    client_ts    TIMESTAMPTZ NOT NULL,
    server_ts    TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 5.3 Tables de référence (gérées via le backoffice)

```sql
-- Opérateurs et codes USSD "officiels" proposés par défaut aux nouveaux utilisateurs
CREATE TABLE ref_operators (
    id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name  VARCHAR(100) UNIQUE NOT NULL,    -- 'Orange Money', 'MTN MoMo'
    logo_url VARCHAR(500),
    country VARCHAR(50)
);

CREATE TABLE ref_ussd_templates (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operator_id      UUID NOT NULL REFERENCES ref_operators(id) ON DELETE CASCADE,
    name             VARCHAR(150) NOT NULL,
    category         VARCHAR(100) NOT NULL,
    default_template VARCHAR(255) NOT NULL,
    required_fields  JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE
);
```

---

## 6. API REST — Endpoints proposés

Convention : `POST/GET/PUT/DELETE`, base `/api/v1`, réponses JSON, authentification via `Authorization: Bearer <token>`.

### 6.1 Authentification

| Méthode | Route | Description |
|---|---|---|
| POST | `/auth/register` | Création de compte (email, password, prénom, nom) |
| POST | `/auth/login` | Connexion → retourne `access_token` + `refresh_token` |
| POST | `/auth/refresh` | Renouvellement du token d'accès |
| POST | `/auth/logout` | Invalidation du refresh token |
| POST | `/auth/forgot-password` | Envoi d'un email de réinitialisation |
| POST | `/auth/reset-password` | Réinitialisation effective |

### 6.2 Profil utilisateur

| Méthode | Route | Description |
|---|---|---|
| GET | `/me` | Récupère le profil courant |
| PUT | `/me` | Met à jour prénom / nom |
| POST | `/me/profile-picture` | Upload photo (multipart) → retourne URL |
| DELETE | `/me` | Suppression du compte (RGPD) |

### 6.3 Données métier (CRUD par entité)

| Ressource | Endpoints |
|---|---|
| Operators | `GET/POST/PUT/DELETE /operators` |
| USSD Operations | `GET/POST/PUT/DELETE /ussd-operations` |
| USSD History | `GET /ussd-history`, `DELETE /ussd-history/:id`, `DELETE /ussd-history` |
| Expenses | `GET/POST/PUT/DELETE /expenses` (+ filtres `?from=&to=&category=`) |
| Categories | `GET/POST/DELETE /categories?type=ussd|expense` |

### 6.4 Synchronisation (point clé)

| Méthode | Route | Description |
|---|---|---|
| GET | `/sync?since=<ISO8601>` | Récupère toutes les modifications serveur depuis une date |
| POST | `/sync` | Pousse les modifications locales (batch de creates/updates/deletes) |

> Stratégie : **sync incrémentale basée sur `updated_at`**.
> Chaque enregistrement porte `updated_at` côté serveur ; le client garde la dernière date de sync.
> Les conflits sont résolus en **« dernier auteur gagne »** (last-write-wins), suffisante pour un MVP mono-utilisateur.

---

## 7. Backoffice d'administration

### 7.1 Rôle du backoffice

Le backoffice est une **interface web interne** (pas exposée aux utilisateurs finaux) servant à :

1. **Gérer les utilisateurs** : lister, rechercher, suspendre, supprimer, voir statistiques.
2. **Gérer les données de référence** : opérateurs officiels (Orange, MTN, etc.), codes USSD par défaut proposés aux nouveaux inscrits.
3. **Supervision** : métriques d'usage (nombre d'utilisateurs actifs, opérations USSD exécutées, volume dépenses).
4. **Modération / support** : consultation d'un compte utilisateur pour aider au support (avec journalisation des accès).

### 7.2 Pages prévues

| Page | Contenu |
|---|---|
| **Dashboard** | KPIs : utilisateurs totaux, actifs (30j), nouvelles inscriptions, opérations USSD/jour |
| **Utilisateurs** | Tableau paginé, filtres, actions (suspendre, voir détail, supprimer) |
| **Détail utilisateur** | Profil, opérateurs, opérations, dépenses, historique USSD |
| **Opérateurs de référence** | CRUD sur `ref_operators` |
| **Templates USSD de référence** | CRUD sur `ref_ussd_templates` |
| **Logs / Audit** | Journal des actions admin, accès aux comptes |
| **Paramètres** | Gestion des administrateurs, configuration globale |

### 7.3 Sécurité du backoffice

- Authentification séparée (comptes `role = 'admin'`).
- **2FA obligatoire** pour les comptes admin.
- RBAC (Role-Based Access Control) : rôles `super-admin`, `admin`, `support` (lecture seule).
- Journalisation de toute action sensible.
- Hébergement sur un domaine séparé / sous-réseau protégé (IP allowlist si possible).

---

## 8. Sécurité & conformité

| Domaine | Mesure |
|---|---|
| **Mots de passe** | Hash bcrypt (cost ≥ 12), jamais stockés en clair |
| **Tokens** | Access token JWT court (15 min) + refresh token (7 j) rotatif, stocké httpOnly cookie ou secure storage côté Flutter |
| **Transport** | HTTPS obligatoire (TLS 1.2+), HSTS |
| **Données au repos** | Chiffrement DB au niveau disque (managed PG), fichiers S3 chiffrés (SSE-S3) |
| **Rate limiting** | Sur `/auth/*` (anti brute-force) et globalement sur l'API |
| **Validation** | Validation stricte des entrées (class-validator / zod) côté serveur |
| **RGPD / confidentialité** | Droit à l'effacement (`DELETE /me`), export des données, minimisation des données collectées |
| **Secrets** | Variables d'environnement, jamais commités, rotation périodique |

---

## 9. Plan d'exécution étape par étape

> Chaque étape est **autonome et livrable**. Ne pas passer à la suivante tant que la précédente n'est pas validée.

### Phase 0 — Cadrage (1 à 2 jours)

- [ ] Valider ce document.
- [ ] Choisir entre **NestJS + PostgreSQL** (péprenne) et **Supabase** (MVP rapide).
- [ ] Définir l'environnement : repo backend, conventions de commit, CI minimale.
- [ ] Choisir l'hébergeur cible et créer les comptes.

### Phase 1 — Fondations backend (3 à 5 jours)

- [ ] Initialiser le projet NestJS (ou Supabase project).
- [ ] Configurer Prisma + PostgreSQL (ou schéma SQL Supabase).
- [ ] Définir le schéma de données (cf. §5) + première migration.
- [ ] Mettre en place Docker + docker-compose (DB locale + backend).
- [ ] Configurer ESLint, Prettier, tests unitaires (Jest).

### Phase 2 — Authentification (3 à 4 jours)

- [ ] Endpoints `register` / `login` / `refresh` / `logout`.
- [ ] Hashing bcrypt, génération JWT (access + refresh).
- [ ] Guards d'authentification (middleware de vérification du token).
- [ ] Rate limiting sur `/auth/*`.
- [ ] Tests d'intégration du parcours d'auth.
- [ ] Service email (réinitialisation mot de passe) — ex. Resend, SendGrid.

### Phase 3 — CRUD métier (4 à 6 jours)

- [ ] Module **Operators** (CRUD).
- [ ] Module **USSD Operations** (CRUD).
- [ ] Module **USSD History** (lecture + suppression).
- [ ] Module **Expenses** (CRUD + filtres temporels).
- [ ] Module **Categories** (USSD + Expense).
- [ ] Module **Profile** + upload photo de profil (S3/R2).
- [ ] Seed des données de référence (`ref_operators`, `ref_ussd_templates`).
- [ ] Tests d'intégration de chaque module.

### Phase 4 — Synchronisation (3 à 5 jours)

- [ ] Endpoint `GET /sync?since=` et `POST /sync`.
- [ ] Logique de last-write-wins.
- [ ] Table `sync_log` pour audit.
- [ ] Tests de scénarios (sync multi-appareils, hors-ligne → reconnexion).

### Phase 5 — Intégration Flutter (3 à 5 jours)

- [ ] Ajouter dépendances : `dio` (HTTP), `flutter_secure_storage` (tokens), `flutter_riverpod` ou conserver `provider`.
- [ ] Couche `ApiClient` centralisée (intercepteurs : injection token, refresh automatique, gestion erreurs).
- [ ] Repository pattern : `ExpenseRepository`, `UssdRepository`, etc., qui remplacent les accès `SharedPreferences`.
- [ ] Écrans : ajout de l'**écran de login / register**.
- [ ] **Mode hybride** transitoire : lecture locale + sync后台 (offline-first progressif).
- [ ] Gestion des conflits UI minimale.

### Phase 6 — Backoffice admin (5 à 8 jours)

- [ ] Initialiser le projet front admin (React + Refine ou shadcn/ui).
- [ ] Authentification admin + 2FA.
- [ ] Pages : Dashboard, Utilisateurs, Détail utilisateur.
- [ ] Pages : Opérateurs de référence, Templates USSD de référence.
- [ ] Page Audit / Logs.
- [ ] RBAC.

### Phase 7 — Sécurité, observabilité, prod (3 à 5 jours)

- [ ] Audit de sécurité (passcode, dependencies vulnérables via `npm audit`).
- [ ] Logging structuré (Pino / Winston) + centralisation (ex. Logtail).
- [ ] Monitoring uptime + métriques (Prometheus / Grafana ou service managé).
- [ ] Backups automatiques de la DB (quotidien + PITR).
- [ ] Déploiement production (CI/CD via GitHub Actions).
- [ ] Tests de charge minimaux sur `/sync`.

### Phase 8 — Évolutions futures (post-MVP)

- Mode **offline-first** complet (file d'attente locale + sync différé).
- Notifications push (rappels de dépenses, opérations).
- Export PDF/Excel des dépenses.
- Multi-devises (si extension hors zone CFA).
- Analytics avancées (catégorisation auto, budgets).

---

## 10. Estimation globale

| Phase | Durée estimée |
|---|---|
| Phase 0 — Cadrage | 1–2 j |
| Phase 1 — Fondations | 3–5 j |
| Phase 2 — Auth | 3–4 j |
| Phase 3 — CRUD métier | 4–6 j |
| Phase 4 — Sync | 3–5 j |
| Phase 5 — Intégration Flutter | 3–5 j |
| Phase 6 — Backoffice | 5–8 j |
| Phase 7 — Sécurité & prod | 3–5 j |
| **Total MVP backend** | **~25–40 jours-homme** |

> Optimisable avec Supabase (gain ~30–40% sur les phases 1–4).

---

## 11. Décisions à valider avant de démarrer

| # | Décision | Options |
|---|---|---|
| D1 | Stack backend | (A) NestJS + PostgreSQL **(recommandé)** / (B) Supabase |
| D2 | Hébergement | Railway / Render / Fly.io / VPS auto-hebergé |
| D3 | Auth | JWT maison / Supabase Auth / Firebase Auth / Auth0 |
| D4 | Stockage fichiers | Cloudflare R2 / AWS S3 / Supabase Storage |
| D5 | Backoffice | Refine (CRUD rapide) / shadcn+React (sur-mesure) |
| D6 | Stratégie offline | Sync manuel / offline-first complet dès le départ |
| D7 | Multi-pays dès le départ | Oui (table `ref_operators.country`) / non (mono-pays) |

---

## 12. Résumé exécutif

- MoniTrack est aujourd'hui une application **100% locale** : aucune persistance serveur, aucun compte utilisateur.
- Le risque majeur est la **perte des données financières** de l'utilisateur.
- Le backend à concevoir comporte **trois blocs** : une **API REST** (NestJS), une **base PostgreSQL**, et un **backoffice admin** (React).
- L'approche recommandée : **NestJS + Prisma + PostgreSQL + JWT**, avec un backoffice **Refine**, le tout conteneurisé via Docker.
- Une alternative **Supabase** permet un démarrage beaucoup plus rapide pour un MVP.
- Le plan d'exécution se déroule en **8 phases** (~25–40 jours-homme) : fondations → auth → CRUD → sync → intégration Flutter → backoffice → sécurité/prod → évolutions.

**Prochaine action recommandée** : valider les décisions D1–D7 (§11), puis lancer la Phase 0.
