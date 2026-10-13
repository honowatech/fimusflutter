# Fimus — état des lieux et travaux restants

Document de passation, à jour du **24 septembre 2026**, après six sprints d'audit et de correction.
Destiné à quelqu'un (humain ou agent) qui reprend le projet sans connaître l'historique.

---

## 1. Ce qu'il faut savoir avant de toucher au code

**Deux dépôts git distincts.** `C:\Users\DELL\dev\MoniTrack` (app Flutter) et `Backend/` (API Laravel), ce
dernier **ignoré par le dépôt parent** — il a son propre historique. Une modification qui touche les deux
côtés demande deux commits.

**Rien n'est commité.** Les six sprints vivent dans le working tree, sur la branche `master`. Avant de
commiter, prévoir une branche : le diff est large (plus de 100 fichiers).

**Conventions en place**, à respecter pour rester homogène :
- code et commentaires en français, commentaires qui expliquent le *pourquoi* et non le *quoi* ;
- fins de ligne **CRLF** sur la plupart des fichiers (attention aux scripts d'édition qui les convertissent) ;
- toute chaîne destinée à l'utilisateur passe par `lib/l10n/app_fr.arb` + `app_en.arb` puis `flutter gen-l10n`
  (810 clés, parité fr/en complète) ;
- les couleurs passent par `ColorScheme` et l'extension `AppSemanticColors` de `lib/utils/app_theme.dart`
  (`warning`, `info`, `success`, `expense`, `income`, `cardShadow`, `tone(light:, dark:)`) — plus aucun
  littéral `Colors.*` dans les écrans, sauf exceptions commentées (surimpression caméra, dégradés illustratifs).

**Vérification de référence** (état actuel, à ne pas dégrader) :
```
flutter analyze   # 0 erreur, 0 warning (≈120 info préexistants)
flutter test      # 564/564
cd Backend && php artisan test   # 172/172
```

**Architecture des notifications**, refondue en profondeur — lire avant d'y toucher :
`lib/services/notification_service.dart` (façade) + `lib/services/notifications/` (`reminder_scheduler`,
`reminder_plan`, `inbox_repository`, `notification_navigator`, `pending_notification_store`,
`local_notification_settings`, `notification_texts`) + `lib/services/notification_intent_queue.dart`.
Le mapping type → canal Android est un **miroir** de `Backend/config/notifications.php`, vérifié par un test
des deux côtés : toute modification se fait en binôme.

**Les pushs Android sont *data-only*.** Le serveur n'envoie pas de bloc `notification` : c'est le handler
d'arrière-plan de l'app qui affiche, ce qui donne le bon canal et les boutons d'action. Conséquence à
connaître : si l'utilisateur fait « Forcer l'arrêt » ou si le constructeur bride l'app, rien ne s'affiche.
iOS conserve un bloc `apns` avec alerte et badge.

---

## 2. Bloquants avant toute mise en production

Par ordre de risque. **Rien de ce qui suit n'a jamais tourné sur un téléphone** : six sprints de code ont
été validés uniquement par l'analyse statique et les tests unitaires.

### 2.1 Recette R8 / minification sur appareil réel
`android/app/build.gradle.kts` active `isMinifyEnabled` et `isShrinkResources`, avec
`android/app/proguard-rules.pro`. Un `flutter build apk --release` **réussit** (90,6 Mio, ~23 min), ce qui
prouve la compilation, pas l'exécution : R8 casse la réflexion au lancement, pas au build.

À vérifier sur appareil : connexion, ouverture de la base, scan QR (MLKit), biométrie (`local_auth`),
réception d'une notification, détection root (`safe_device` — dépend de la règle
`-keep class com.xamdesign.safe_device.**`, sans laquelle la détection échoue **en silence**).
Si la recette est impossible à court terme, repasser `isMinifyEnabled` à `false` est un choix défendable.

### 2.2 Recette SQLCipher
`lib/services/database_encryption.dart` + `lib/services/database_service.dart`. Chiffrement actif par défaut,
désactivable par `--dart-define=FIMUS_DB_CHIFFREMENT=false` (filet *avant* déploiement : inopérant sur un
appareil déjà migré). **La migration clair → chiffré n'a jamais tourné sur un vrai appareil** — SQLCipher est
absent du moteur de test (`sqflite_common_ffi`), et le chiffrement s'auto-désactive sous `flutter test`.

À vérifier : migration d'une base existante avec données, reprise après interruption (tuer l'app pendant la
migration), multicompte, cas « clé perdue » (le comportement voulu est : base vidée + resynchronisation,
jamais un blocage), et le temps d'ouverture (PBKDF2 à 256 000 itérations). Recette pas-à-pas au §8 de
`docs/chiffrement-base-locale.md`.

### 2.3 Recette notifications
Les points qui ne se valident que sur appareil :
- bouton « Annuler » d'une dépense programmée, app **tuée** puis app en arrière-plan (isolat séparé) ;
- absence de doublon sur iOS au premier plan ;
- `suppress_local` honoré en arrière-plan (évite le doublon rappel local + push de dette) ;
- appui sur notification avec verrou PIN actif : aucune donnée financière ne doit apparaître avant saisie ;
- icône monochrome `ic_stat_fimus` — **le glyphe actuel est une cloche Material générique, placeholder à
  remplacer par le design** ;
- badge iOS qui redescend à zéro ;
- alarme exacte refusée → repli inexact, rappel délivré avec retard acceptable.

### 2.4 Déploiement backend
```
cd Backend
php artisan migrate --force     # ~10 migrations en attente (sprints 2 à 6)
php artisan config:cache        # si le cache de config est actif
```
Redéployer le planificateur : la cadence des rappels de dette est passée à `everyThirtyMinutes()`
(`routes/console.php`), et `digest:send-weekly` a été ajouté.

Trois secrets à fournir avant d'activer Play Integrity (§7 de `Backend/docs/play-integrity.md`) : compte de
service Google, `PLAY_INTEGRITY_PACKAGE`, `PLAY_INTEGRITY_CERT_SHA256`. Sans eux le vérificateur rend
`error` et laisse passer — c'est voulu.

### 2.5 Rupture de compatibilité : mot de passe oublié
`forgotPassword` ne renvoie plus de mot de passe : le flux est désormais **code à 6 chiffres** en trois
appels (`/api/password/forgot`, `/password/verify-code`, `/password/reset`). L'app 1.1 en production appelle
l'ancienne route et affiche « e-mail envoyé » : **l'utilisateur recevra un code sans écran pour le saisir**.
Il faut livrer l'écran mobile (§4.3) avant de retirer l'alias `/api/forgot-password`, idéalement avec une
mise à jour forcée.

---

## 3. Multi-devise : la moitié qui manque

Le sprint 6 a posé la colonne `currency` (palier SQLite 19, migration backend, synchronisation, formatage).
**La partie visible et la partie calcul ne sont pas faites.** Tant que l'utilisateur reste mono-devise, rien
ne casse ; dès qu'une opération dans une devise touche un compte dans une autre, les soldes sont faux.

Rappel du contrat, à ne pas dévier : colonne **nullable**, `NULL` = « devise inconnue, interpréter dans celle
du profil », **jamais réécrite après la création**, fixée à la création (devise du compte imputé, sinon celle
du profil).

### 3.1 Conversion des soldes — priorité haute
Trois sites additionnent aujourd'hui un delta brut, en supposant implicitement une devise unique :
- `lib/providers/account_provider.dart:112` — `updateBalance(accountId, amountDelta)` ;
- `lib/providers/expense_provider.dart:387` — `rawUpdate('UPDATE accounts SET balance = balance + ?…')`
  dans `confirmScheduledExpense` ;
- `lib/providers/expense_provider.dart` — `deleteExpenseAndAdjustBalance` (delta au signe inverse).

L'API est prête : `CurrencyConverter.amountForAccount({amount, operationCurrency, accountCurrency,
profileCurrency, activeRates})` rend un `ConvertedAmount` dont le montant est **nullable** — il n'existe aucun
chemin par lequel un appelant récupère silencieusement un montant non converti. Règle à appliquer :
`if (!r.isUsable)` → renoncer à l'écriture **et** remonter l'échec ; un solde faux est pire qu'une opération
refusée. `r.approximate` signale un taux issu de la table statique de repli : exploitable, à journaliser.

Ne jamais utiliser `CurrencyConverter.getRate` pour un solde : il rend `1.0` sur devise inconnue. Utiliser
`strictRate`, qui rend `null`.

**Décision produit ouverte** : XOF et XAF n'ont pas de décimales — faut-il arrondir à l'unité après
conversion ?

### 3.2 Affichage
Une vingtaine d'appels à `formatAmountDouble()` suivis de la devise du profil, répartis sur 5 écrans
(`account_detail_screen`, `debt_screen`, `debt_detail_screen`, `expense_detail_screen`,
`add_debt_operation_screen`), et ~67 endroits qui interpolent `profile.currency`. À remplacer par :
- `MoneyFormatter.format(montant, rowCurrency: e.currency, profileCurrency: currency)` pour une opération ;
- `MoneyFormatter.formatConverted(..., activeRates:)` pour les **agrégats** (totaux, soldes, graphiques qui
  mêlent des devises) ;
- `MoneyFormatter.isForeign(...)` pour n'ajouter une mention visuelle que si la devise est connue **et**
  différente de celle du profil.

C'est ce qui corrige l'affichage d'une dette partagée entre deux pays côté app — le côté notifications est
déjà corrigé (priorité : devise de l'opération → pays du propriétaire → pays du destinataire → défaut).

### 3.3 Ce qui est déjà fait, à ne pas refaire
- Palier 19 des deux côtés, sans backfill (rien n'est deviné).
- `changeCountryAndConvert` (`lib/providers/profile_provider.dart`) **ne réécrit plus l'historique**. Il
  multipliait tous les montants par un taux de change : une dépense de 10 000 XOF devenait « 15,24 EUR » en
  base. Désormais les lignes sans devise sont **estampillées à l'ancienne devise du profil** au moment du
  changement — ce qu'elles valaient jusque-là — et les montants ne bougent pas.
- Devise posée à la création dans `ExpenseProvider.addExpense` et `AccountProvider.addAccount`.

---

## 4. Contrats backend livrés, côté app à câbler

Le serveur est prêt et testé pour les trois points suivants ; l'app ne les consomme pas encore.

### 4.1 Préférences de notification — 14 clés
`GET`/`POST /users/notification-preferences` expose désormais, dans cet ordre :
`notify_debts`, `notify_contacts`, `notify_joint_accounts`, `notify_scheduled_expenses`,
`notify_announcements`, `notify_weekly_digest`, `notify_budget_threshold`, `notify_low_balance`,
`notify_unsynced_data`, `unsynced_threshold_hours` (entier, défaut 48, borné [1,720]), `reminder_hour`,
`quiet_hours_enabled`, `quiet_hours_start`, `quiet_hours_end`.

Côté app : `lib/models/notification_preferences.dart` en couvre 10. Ajouter les 4 dernières et **cesser de
stocker** les trois interrupteurs d'alerte et le délai dans `lib/services/alerts/alert_settings.dart`
(SharedPreferences) — ou n'en garder qu'un cache. L'état anti-spam, lui, reste **local à l'appareil** et ne
doit jamais être synchronisé.

### 4.2 Portabilité des réglages d'alerte
Table serveur `alert_settings`, exposée dans les sections existantes `sync/push` et `sync/pull` sous la clé
`alert_settings` — seule section **sans `id`** (`kind` ∈ `budget|low_balance`, `target` = catégorie
normalisée ou uuid de compte, `amount`, `enabled`, `sync_action`). Un budget à ≤ 0 vaut suppression ; un seuil
de solde bas à 0 est une valeur valide à conserver.

Côté app : pousser et lire la section, hydrater `AlertSettings` au premier lancement sur un appareil neuf, et
prévoir une **migration one-shot SharedPreferences → push**, sans laquelle les seuils déjà réglés ne
remonteront jamais.

### 4.3 Écran de réinitialisation par code
Trois appels, réponses volontairement indistinctes selon que l'adresse existe ou non :
1. `POST /api/password/forgot` `{email}` → 200 toujours, `{message, expires_in: 900, code_length: 6}` ;
2. `POST /api/password/verify-code` `{email, code}` → 200 `{reset_token, expires_in: 600}`, ou 422
   `INVALID_RESET_CODE` (identique pour code faux, périmé, consommé, quota épuisé, adresse inconnue) ;
3. `POST /api/password/reset` `{reset_token, password, password_confirmation}` → 200, révoque toutes les
   sessions.

429 avec en-tête `Retry-After` en cas d'abus. Complexité du mot de passe identique à l'inscription.

### 4.4 Play Integrity — moitié mobile
Ajouter `com.google.android.play:integrity`, demander le nonce au serveur
(`POST /api/security/integrity/nonce`), obtenir le jeton via `IntegrityManager.requestIntegrityToken()`, le
poster **tel quel** sans l'interpréter (`POST /api/security/integrity`). Sur `API_NOT_AVAILABLE` /
`PLAY_STORE_NOT_FOUND`, poster `{"unsupported": true, "device_id": …}`. Appeler **après connexion**, pas à
chaque requête (quotas). Tout échec est un non-événement : la politique serveur est `observe` — on journalise,
on ne bloque pas.

### 4.5 Modèle d'appareil
`lib/services/auth_service.dart` remonte `Platform.operatingSystemVersion` (« Android 13 (SDK 33) ») faute de
dépendance : l'alerte de nouvelle connexion annonce donc une version d'OS, pas « Pixel 7 ». Ajouter
`device_info_plus` au `pubspec.yaml` et remplir le getter `deviceModel`, isolé exprès pour ça.

---

## 5. Dette technique restante

### 5.1 Logique métier encore dans les widgets
Même patron que celui migré au sprint 6 (`deleteExpenseAndAdjustBalance`, `syncAndReloadAll`) :
- `lib/screens/expense_detail_screen.dart:164` — duplication **exacte** de `deleteExpenseAndAdjustBalance`,
  remplacement en une ligne ;
- `lib/screens/debt_detail_screen.dart:49` — suppression d'un tag de dette + remboursements
  (cible : `ExpenseProvider.deleteDebtTagAndAdjustBalances`) ;
- `lib/screens/add_expense_screen.dart:77` et `:127`, `lib/screens/add_debt_operation_screen.dart:243`,
  `lib/screens/operation_screen.dart:331`, `lib/screens/account_detail_screen.dart:657` — transactions SQLite
  ouvertes depuis l'UI ;
- `lib/screens/add_debt_operation_screen.dart:309` et `lib/widgets/add_account_bottom_sheet.dart:297` —
  `SyncService().push()` direct ;
- `lib/screens/debt_screen.dart:325` et `:456` — deux `SyncService().fullSync()` depuis des
  `RefreshIndicator`, qui **échappent au verrou** de `syncAndReloadAll`.

Pour obtenir `onRefresh: provider.syncAndReloadAll` sans paramètre, passer `ExpenseProvider` en
`ChangeNotifierProxyProvider<AccountProvider, ExpenseProvider>` dans `lib/main.dart` (aujourd'hui les deux
providers sont indépendants, d'où le paramètre explicite).

### 5.2 Support web cassé — décision produit
`lib/services/database_service.dart` importe `dart:io` en première ligne : la branche `kIsWeb` est donc du
code mort sur mobile et inopérante sur web. Deux issues cohérentes : réparer (import conditionnel
`if (dart.library.js_interop)`, recette décrite dans le rapport d'hygiène) ou **assumer l'abandon du web** et
supprimer branche + dépendance `sqflite_common_ffi_web`, qui est aujourd'hui embarquée dans l'APK pour rien.
Ne pas laisser l'état actuel, qui est le pire des deux.

### 5.3 Livraison Android
APK unique de 90,6 Mio, dont 89 % de code natif triplé pour trois architectures. Publier en **App Bundle**
(`flutter build appbundle`) ramène à ~36 Mo servis en arm64. Détails et mesures dans
`docs/livraison-android-taille.md`. Enjeu réel pour des utilisateurs en zone à connexion limitée.

### 5.4 Lints
`analysis_options.yaml` active 33 règles (coût mesuré : +8 avertissements). Deux paliers documentés en bas du
fichier et laissés en attente : la famille `const` + `prefer_final_locals` (91 occurrences, **100 %
auto-corrigeables** par `dart fix --apply`), puis `unawaited_futures` (80 occurrences, correction manuelle,
vrai signal).

### 5.5 Index git
- Les fichiers parasites (`test.dart`, `test2.dart`, `test3.dart`, `test_types.dart`, `temp_prompt.txt`, logs
  Gradle) ont été **supprimés du disque** mais restent suivis : un `git rm --cached` ou un `git add -A` au
  moment du commit suffit.
- `android/app/google-services.json` est suivi **malgré** le `.gitignore`. L'untracker ne suffit pas : il est
  déjà dans l'historique. La vraie mesure est de **restreindre la clé Firebase par empreinte SHA et nom de
  package** dans la console.

### 5.6 Tests manquants
Suite actuelle : 564 tests (109 au départ). Trous connus :
- devise : migration v18→v19 et v17→v19, `normalizeCode`, `amountForAccount` (taux manquant, approximatif,
  identité), `strictRate` vs `getRate`, aller-retour des modèles, non-régression du changement de pays ;
- `syncAndReloadAll` : deux appels concurrents ⇒ un seul `fullSync`, reprise après échec ;
- `deleteExpenseAndAdjustBalance` : solde réajusté, `accountId == null`, atomicité ;
- `NotificationsScreen` (~520 lignes modifiées, jamais testé — demanderait le même travail d'isolation que le
  provider) ;
- `alert_settings_store`, `local_alerts_service`, `alert_texts` (demandent des doubles de SharedPreferences et
  du plugin de notifications).

---

## 6. Décisions ouvertes (produit, pas technique)

1. **Backfill de la devise** : aujourd'hui le serveur refuse `NULL` → valeur sur une ligne existante. Un
   remplissage sûr supposerait d'historiser le pays de l'utilisateur à la date de création, ce qui n'existe
   pas. Autoriser un remplissage « une seule fois si `NULL` » si l'app sait prouver la devise réelle ?
2. **Fuseau horaire** : déduit du pays du profil faute de colonne `users.timezone`. Décalage pour un
   expatrié, sur les heures calmes et l'heure des rappels. Une colonne alimentée par l'app réglerait les deux.
3. **Bilan hebdomadaire à cheval sur deux devises** : les montants sont additionnés puis libellés dans la
   devise du profil. Alternatives : conversion indicative, ou bilan par devise (plus honnête).
4. **Canal Android de `new_login`** : `fimus_general_v3` faute de mieux. Un canal « Sécurité » dédié, non
   coupable, serait plus juste — décision conjointe app + serveur.
5. **Importance des canaux sur le parc installé** : Android fige l'importance à la création du canal. Les
   utilisateurs déjà installés gardent `max` partout ; seule une installation neuve obtient la hiérarchie
   posée au sprint 3. L'appliquer à tous demanderait de passer en v4 des deux côtés.
6. **Campagnes de masse et heures calmes** : une campagne envoyée à 23 h est reportée en bloc à la fin de
   plage de chaque utilisateur, ce qui concentre les envois. Exempter via `quiet_hours.urgent_types` si le
   back-office doit garder la main.
7. **`alert_settings` en dernier écrivain gagnant**, sans arbitrage d'horodatage (conforme au reste du
   protocole) : deux téléphones réglant le même budget hors ligne, le dernier push l'emporte.
8. **Vocabulaire anglais** à valider avec le produit : `receivable` (créance) est comptable ; `kiosk` ne porte
   pas hors contexte le sens ouest-africain de point Mobile Money ; « pôle de dépense » n'a pas d'équivalent
   évident ; `Staff` a été traduit « Équipe » / *Team*.

---

## 7. Points de sécurité encore ouverts

- **`WelcomePasswordMail`** (`Backend/app/Http/Controllers/AuthController.php:112`) envoie encore le mot de
  passe **en clair** à l'inscription. Moins grave que l'ancien `forgotPassword` — l'utilisateur vient de le
  choisir — mais c'est la même mauvaise pratique.
- **`google_id`** est indexé mais pas `unique()`.
- **Pas d'intercepteur 401 global** côté `lib/services/auth_service.dart`.
- **Empreintes Play App Signing** et écran de consentement OAuth à vérifier ; **iOS non configuré** pour
  Google Sign-In.
- **`safe_device` est un fork local** (`third_party/`), non suivi par `pub outdated`, et ses heuristiques de
  détection root se périment face à Magisk/Zygisk. C'est la raison d'être de Play Integrity côté serveur.
- Détail à vérifier : `Backend/tests/Feature/GoogleAuthTest.php` échouait de façon **préexistante** (test
  périmé, pas un bug serveur) ; il semble avoir été corrigé par une session parallèle — confirmer.

---

## 8. Ordre de travail conseillé

1. **Recette appareil** (§2.1 à 2.3) avant d'empiler quoi que ce soit. Six sprints n'ont jamais tourné sur un
   téléphone, et les deux couches les plus risquées ne se cassent qu'à l'exécution.
2. **Déploiement backend** (§2.4) — il est prêt et testé, il débloque le reste.
3. **Conversion des soldes** (§3.1) — c'est le seul point où un bug produit des chiffres faux sans rien
   signaler.
4. **Écran de code de réinitialisation** (§4.3) — sans lui, le parc installé a une fonction cassée.
5. Affichage multi-devise (§3.2), puis les câblages §4.1, §4.2, §4.5.
6. Dette technique (§5) et décisions produit (§6), au fil de l'eau.
