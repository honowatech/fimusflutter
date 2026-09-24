# Chiffrement de la base SQLite locale — Fimus

Étude, décision et procédure. Sprint 5 de l'audit, constat **E3** : la base
SQLite locale n'était pas chiffrée.

> Date : 2026-09-23
> Statut : **implémenté derrière un drapeau**, en attente de recette sur
> appareil réel (voir §8).

---

## 1. Ce qui est exposé aujourd'hui

`monitrack.db` (et, en multicompte, `monitrack_<userId>.db`) contient :

| Table | Données sensibles |
|---|---|
| `expenses` | montants, `debtorName`, `debtorPhoneNumber`, échéances, statut de dette |
| `staff_members` | noms, téléphones, e-mails et **salaires** du personnel |
| `accounts` | soldes par compte, propriétaire d'un compte partagé |
| `ussd_history` | historique complet des opérations Mobile Money, réponses opérateur incluses |
| `telecom_operators` | numéro de téléphone de l'utilisateur |

Un fichier SQLite en clair se lit intégralement avec n'importe quel visualiseur.
Il est accessible :

* sur un appareil **rooté** ou déverrouillé (`adb shell run-as`, explorateurs
  de fichiers privilégiés) ;
* dans une **sauvegarde** Android (`android:allowBackup`, sauvegarde ADB,
  Google Drive) ou iOS (iTunes / iCloud non chiffré) ;
* par toute analyse **post-mortem** d'un appareil perdu ou revendu, la
  partition `/data` d'un appareil sans code d'écran n'étant pas protégée par le
  chiffrement au repos.

Le verrouillage par code PIN de l'application (`SecurityProvider`) ne protège
que l'interface : il ne touche pas au fichier.

---

## 2. Options évaluées

### 2.1 `sqflite_sqlcipher` — **retenue**

Fork de `sqflite` (David Martos, `^3.4.1`) qui remplace la bibliothèque SQLite
native par **SQLCipher 4.10** (`net.zetetic:sqlcipher-android` sur Android,
pods `SQLCipher` + `FMDB/SQLCipher` sur iOS/macOS).

| Critère | Verdict |
|---|---|
| **API** | Identique à `sqflite`, avec un `password` supplémentaire à l'ouverture. |
| **Types** | Le paquet dépend de `sqflite_common ^2.5.0`, comme `sqflite 2.4.3` : `Database`, `Transaction`, `OnDatabaseCreateFn`… sont **exactement les mêmes classes**. Aucune adaptation dans les providers ni dans `SyncService`. |
| **Résolution** | `flutter pub get` n'a déplacé aucune autre version (`Changed 1 dependency!`). |
| **Plateformes** | Android, iOS, macOS. **Pas de web**, pas de Windows/Linux — comme `sqflite` lui-même. |
| **Tests** | Voir §3. |
| **Poids** | Mesuré sur un APK de débogage : `libsqlcipher.so` pèse 5,2 Mo en arm64-v8a, 3,6 Mo en armeabi-v7a (non compressée, les bibliothèques natives étant stockées telles quelles). Le build release, symboles retirés, sera nettement en deçà — **à mesurer**. Un AAB ne livre qu'une ABI par appareil. |
| **Maintenance** | Paquet tiers, mais actif (3.4.1 publié pour Flutter ≥ 3.35) et aligné sur SQLCipher 4.10. Dépendance à un seul mainteneur : risque à surveiller. |

### 2.2 `sqlcipher_flutter_libs` + `sqflite_common_ffi` (ou Drift)

On garderait l'API `DatabaseFactory` utilisée par les tests et on chargerait
`libsqlcipher.so` à la place de `libsqlite3.so`, la clé étant posée par
`PRAGMA key`.

Avantages : un seul moteur pour l'application **et** pour les tests, support
desktop. Inconvénients : cela remplace le plugin `sqflite` par le moteur FFI
dans toute l'application (gestion des isolats, des transactions, des chemins de
fichiers, comportement en arrière-plan), avec sur iOS la difficulté classique
d'empêcher l'éditeur de liens de résoudre les symboles vers le SQLite du
système. **Trop de surface pour un sprint de sécurisation** ; c'est le repli
naturel si `sqflite_sqlcipher` devait être abandonné.

### 2.3 Chiffrement applicatif colonne par colonne

Chiffrer seulement `amount`, `debtorPhoneNumber`, `salary`… en AES-GCM côté
Dart. **Écartée** : les colonnes chiffrées ne sont plus ni filtrables ni
triables ni sommables en SQL, ce qui imposerait de réécrire les requêtes de
tous les providers et de `SyncService` (hors périmètre), pour une protection
partielle — les index, le journal WAL et les noms restant en clair.

### 2.4 Ne rien chiffrer et durcir la sauvegarde

Interdire la sauvegarde Android (`allowBackup=false`) réduit une voie d'accès
sur trois et relève du dossier `android/`. **Complémentaire, pas substituable.**

---

## 3. Compatibilité avec les tests existants

Les suites (`test/database_migration_test.dart`, `test/database_close_test.dart`,
`test/sync_*.dart`) tournent sur `sqflite_common_ffi`, qui embarque un SQLite
**sans** SQLCipher, et dans une VM Dart **sans** plugins : ni le canal
`sqflite_sqlcipher`, ni `flutter_secure_storage` n'y répondent.

Le chiffrement s'y désactive donc tout seul, sans qu'aucun test ait à le
savoir (ils ne sont pas modifiables) :

```dart
static final bool sousTest =
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

static bool get actif => drapeauActif && !kIsWeb && !sousTest;
```

`FLUTTER_TEST` est posé par `flutter test` dans l'environnement du processus de
test. Conséquences assumées :

* un test d'intégration sur appareil (`integration_test`) verrait lui aussi le
  chiffrement désactivé ; la recette du §8 se fait donc en lançant
  l'application, pas via `integration_test` ;
* le journal du chiffrement est **séparé** de `DatabaseService.schemaIssues`
  (`DatabaseService.encryptionIssues`), sans quoi l'assertion
  « une migration nominale ne doit journaliser aucun écart » deviendrait
  fausse.

L'import de `package:sqflite_sqlcipher/sqflite.dart` dans
`database_service.dart` ne gêne pas les tests : la bibliothèque Dart se compile
partout, seul l'appel au canal natif échouerait — et il n'a jamais lieu sous
test.

---

## 4. Compatibilité avec la branche web

`DatabaseService` ouvre la base par `sqflite_common_ffi_web` (SQLite compilé en
WebAssembly, stocké dans IndexedDB) lorsque `kIsWeb` est vrai. **SQLCipher
n'existe pas dans cette chaîne** : le web reste donc en clair, et la condition
`!kIsWeb` du §3 le garantit explicitement.

Vérifié : `flutter build web` réussit avec la dépendance ajoutée. Le SDK web de
Flutter tolère l'import de `dart:io` (déjà présent dans six bibliothèques de
`lib/`, dont `database_service.dart`), tant qu'il n'est pas exercé à
l'exécution ; `sqflite_sqlcipher` n'importe rien d'autre que `dart:io`,
`flutter/services` et `sqflite_common`.

Cela reste un **angle mort** : si le web devait servir à autre chose qu'une
vitrine, il faudrait y traiter le sujet séparément (IndexedDB est isolé par
origine, mais lisible depuis la machine de l'utilisateur).

---

## 5. Gestion de la clé

| Point | Décision |
|---|---|
| Nature | 256 bits tirés de `Random.secure()`, encodés en base64 (44 caractères). |
| Stockage | `FlutterSecureStorage`, entrée `fimus_cle_base_locale_v1` — Keystore Android / Keychain iOS, comme les jetons d'authentification. |
| Interdits | Jamais dans les `SharedPreferences`, jamais en dur dans le code, jamais dérivée du **code PIN** (trop court, et un changement de PIN rendrait la base illisible). |
| Portée | **Une seule clé par appareil**, partagée par toutes les bases de comptes (`monitrack_<userId>.db`). Une clé par compte n'apporterait rien : c'est la même application, sur le même appareil, qui les déverrouille toutes. |
| Validation | Une entrée qui ne décode pas en exactement 32 octets est traitée comme absente (écriture interrompue, entrée corrompue). |
| Dérivation | SQLCipher applique PBKDF2-HMAC-SHA512, 256 000 itérations, sur la phrase secrète. C'est ce qui coûte à l'ouverture (§7). |

### Cas « clé perdue »

Restauration d'un appareil vers un autre, réinitialisation du Keystore
(changement de verrouillage d'écran sur certains OEM), désinstallation partielle,
sauvegarde applicative restaurée sans le Keychain : **le fichier devient
définitivement illisible.** Il n'existe aucune récupération — c'est le prix du
chiffrement.

Comportement retenu, dans l'ordre de gravité :

1. **Coffre lisible, clé absente, base chiffrée** → la base est supprimée, une
   clé neuve est tirée, une base vide est créée.
   `DatabaseService.resyncRequiseApresPerteCle` passe à vrai ; `SyncService.pull()`
   étant un rechargement **complet** (aucun paramètre `since`), tout ce qui
   avait été synchronisé revient du serveur.
   Ce qui n'avait jamais été poussé (`is_synced = 0` au moment de l'incident)
   est perdu.
2. **Clé présente mais qui n'ouvre pas le fichier** (base venue d'une autre
   installation) → même traitement, **et seulement dans ce cas** : la
   destruction n'est déclenchée que par une erreur d'authentification
   (`SQLITE_NOTADB`, « file is not a database » — SQLCipher ne déchiffre pas
   l'en-tête avec une mauvaise clé). Toute autre panne à l'ouverture (disque
   plein, palier de schéma en échec, plugin absent) remonte telle quelle, sans
   rien supprimer (`ChiffrementBase.estErreurDeCle`).
3. **Coffre inaccessible** (exception du stockage sécurisé, Keystore
   temporairement verrouillé) → **rien n'est détruit**. `CoffreIndisponible` est
   levée : mieux vaut un démarrage en erreur, réessayable, qu'une destruction
   irréversible sur un incident passager. Si la base n'est pas encore chiffrée,
   on se replie simplement sur une ouverture en clair et l'incident est
   journalisé.

Le choix « repartir d'une base vide » plutôt que « bloquer l'utilisateur »
suppose que le serveur est la source de vérité. C'est le cas pour les comptes,
dépenses, dettes, opérations et historiques (tous poussés par `SyncService`).

---

## 6. Migration d'une base existante en clair

C'est le point délicat : les utilisateurs déjà installés ont une base en clair
qui doit devenir chiffrée **sans perte**, y compris si l'application est tuée en
plein milieu.

### 6.1 Détection

Aucun marqueur applicatif (les `SharedPreferences` peuvent être effacées, une
base peut être restaurée par-dessus). L'état est lu **dans le fichier** : les
16 premiers octets d'une base SQLite en clair valent `SQLite format 3\0` ;
SQLCipher chiffre aussi l'en-tête. D'où trois états : `absent`, `clair`,
`chiffre` (`ChiffrementBase.etatDepuisEntete`, fonction pure).

### 6.2 Déroulé

Trois chemins : la base `X`, la copie `X.chiffre-tmp`, la sauvegarde
`X.clair-sauvegarde`.

1. ouverture de `X` **sans mot de passe et sans `version`** (aucun palier de
   schéma ne doit tourner ici) ;
2. relevé de `PRAGMA user_version` et du nombre de lignes de chaque table ;
3. `ATTACH DATABASE 'X.chiffre-tmp' AS chiffree KEY ?` puis
   `SELECT sqlcipher_export('chiffree')` ;
4. `PRAGMA chiffree.user_version = <n>` — `sqlcipher_export` **ne recopie pas**
   la version de schéma ; sans cette ligne, la base migrée passerait pour neuve
   et tous les paliers seraient rejoués ;
5. `DETACH`, fermeture ;
6. **vérification** : la copie s'ouvre avec la clé, sa `user_version` et son
   inventaire (tables → nombre de lignes) sont identiques à l'original ;
7. `X` → `X.clair-sauvegarde` (renommage), suppression des `-wal`, `-shm` et
   `-journal` de l'ancienne base — un `-wal` orphelin laissé à côté du nouveau
   fichier serait interprété comme lui appartenant et le corromprait ;
8. `X.chiffre-tmp` → `X` (renommage) ;
9. suppression de la sauvegarde.

La base en clair n'est supprimée qu'à l'étape 9, après une copie **vérifiée**.
Un échec à l'étape 6 jette la copie et conserve la base en clair.

**Échec de la migration, quelle qu'en soit la cause** : la base en clair étant
intacte, l'application s'ouvre dessus (comportement historique) plutôt que de
refuser de démarrer ; l'incident part dans `DatabaseService.encryptionIssues`
et la migration est retentée au lancement suivant. C'est un compromis assumé :
une base qui reste en clair est visible dans le journal, une application qui ne
démarre plus ne l'est pas.

### 6.3 Reprise après interruption

L'invariant — *la sauvegarde n'est créée qu'après vérification de la copie* —
permet de décider de la reprise à partir de la seule présence des fichiers
(`ChiffrementBase.decider`, fonction pure) :

| `X` | `.chiffre-tmp` | `.clair-sauvegarde` | Action |
|:-:|:-:|:-:|---|
| ✓ | — | — | aucune |
| ✓ | ✓ | — | jeter la copie (export interrompu avant vérification) |
| ✓ | — ou ✓ | ✓ | effacer la sauvegarde (la bascule avait abouti) |
| — | ✓ | ✓ | terminer la bascule (la copie est vérifiée) |
| — | — | ✓ | restaurer la sauvegarde |

La reprise tourne **avant** toute ouverture, à chaque démarrage : l'opération
est idempotente.

### 6.4 Multicompte

`switchToUserDatabase` ouvre un fichier par utilisateur ; chaque base est donc
migrée indépendamment, à sa première ouverture chiffrée. La copie
`_copyLegacyDbFileIfNeeded` (base partagée pré-multicompte → base du compte)
reste valable : elle copie des octets, que la source soit claire (elle sera
migrée ensuite) ou déjà chiffrée (la clé est celle de l'appareil, pas celle du
compte).

---

## 7. Coût

| Poste | Ordre de grandeur |
|---|---|
| Ouverture | **PBKDF2, 256 000 itérations HMAC-SHA512** à chaque `openDatabase` : typiquement 50 à 200 ms sur un mobile d'entrée / milieu de gamme. Payé une fois par session, la poignée étant conservée par `DatabaseService._database`, et une fois de plus à chaque `switchToUserDatabase`. |
| Lecture / écriture | Surcoût AES-256-CBC + HMAC-SHA512 par page : de l'ordre de 5 à 15 % sur des volumes de cette taille. Non perceptible aux volumes de Fimus (quelques milliers de lignes). |
| Migration | Une réécriture complète du fichier, une fois. Quelques centaines de millisecondes pour une base de cette taille ; la durée réelle est journalisée. |
| Binaire | `libsqlcipher.so` : 5,2 Mo (arm64-v8a) / 3,6 Mo (armeabi-v7a) dans un APK **de débogage**, une seule ABI étant livrée par appareil via l'AAB. |

Seule la taille du binaire a été mesurée (APK de débogage). Les autres valeurs
sont des ordres de grandeur issus de la documentation SQLCipher :
**rien n'a été exécuté sur appareil** (cf. §8).

---

## 8. Activation, recette et retour arrière

### Drapeau

```dart
static const bool drapeauActif =
    bool.fromEnvironment('FIMUS_DB_CHIFFREMENT', defaultValue: true);
```

Le chiffrement est **actif par défaut** (hors web et hors `flutter test`). Le
retour arrière se fait au build, sans modification de code :

```
flutter build appbundle --release --dart-define=FIMUS_DB_CHIFFREMENT=false
```

> **Attention** : une version « drapeau à faux » ouvre les bases **en clair**.
> Sur un appareil dont la base a déjà été migrée, elle échouera à l'ouverture
> (fichier illisible comme SQLite). Le retour arrière n'est donc sûr que
> **avant** le déploiement de la version chiffrée, ou accompagné d'une
> procédure de remise à zéro locale. Pour un incident survenant après
> déploiement, préférer un correctif ciblé à la bascule du drapeau.

### Recette avant publication (sur appareil réel)

1. installer la version **précédente**, créer des comptes, dépenses, dettes,
   membres du personnel, exécuter une opération USSD ;
2. installer par-dessus la version chiffrée, vérifier que **toutes** les
   données sont là et que `DatabaseService.encryptionIssues` annonce la
   migration ;
3. vérifier avec `adb shell run-as com.honowa.fimus` que
   `databases/monitrack*.db` ne commence plus par `SQLite format 3` et
   qu'aucun `.chiffre-tmp` ni `.clair-sauvegarde` ne subsiste ;
4. tuer l'application pendant la migration (base volumineuse, `adb shell am
   force-stop`) et vérifier la reprise au démarrage suivant ;
5. basculer entre deux comptes et vérifier que chaque base s'ouvre ;
6. effacer les données de l'application depuis les réglages Android (le
   Keystore est vidé) et vérifier que l'application redémarre sur une base vide
   puis se resynchronise ;
7. relever le temps entre le lancement et le premier écran (impact PBKDF2).

---

## 9. Cas à couvrir par des tests

Le module est écrit pour être testable sans appareil : le moteur d'ouverture
est injecté (`OuvertureBase`), le coffre est une interface (`CoffreCle`), et les
décisions sont des fonctions pures.

| Cas | Point d'entrée |
|---|---|
| en-tête → état (`SQLite format 3`, octets aléatoires, fichier vide, fichier tronqué) | `ChiffrementBase.etatDepuisEntete` (pur) |
| table de reprise, les 8 combinaisons de présence de fichiers | `ChiffrementBase.decider` (pur) |
| clé : 256 bits, base64, aléa injecté, rejet d'une entrée tronquée ou non base64 | `genererCle`, `cleValide` (purs) |
| migration clair → chiffré : données et `user_version` préservées, `.chiffre-tmp` et `.clair-sauvegarde` disparus | `ouvrir` + moteur double |
| migration : échec de vérification → base en clair **conservée**, copie jetée | moteur double qui rend un inventaire divergent |
| reprise après interruption à chacune des étapes 6 à 9 | fichiers posés à la main + `ouvrir` |
| base déjà chiffrée : ouverture directe, aucune migration, aucun incident journalisé | coffre pré-rempli |
| clé absente + base chiffrée : base recréée vide, `resynchronisationRequise` vrai | coffre vide |
| clé présente mais refusée (`not a database`) : base recréée | moteur double qui lève cette erreur |
| **autre** panne à l'ouverture d'une base chiffrée : l'erreur remonte, **le fichier survit** | `estErreurDeCle` (pur) + moteur double qui lève autre chose |
| coffre qui lève + base chiffrée : `CoffreIndisponible`, **fichier intact** | coffre double qui lève |
| coffre qui lève + base absente : repli en clair | idem |
| multicompte : deux bases migrées indépendamment avec la même clé | deux chemins |
| `-wal`/`-shm` orphelins supprimés après bascule | vérification de l'arborescence |

Ces tests appartiennent à `test/`, hors périmètre du sprint 5 : ils restent à
écrire. La liste n'est pas théorique — elle a été **exécutée** sur un banc
jetable hors dépôt (paquet temporaire dépendant de `monitrack` par chemin,
moteur `sqflite_common_ffi` injecté en guise de double), 12 cas au vert :
fonctions pures, clé tirée une seule fois, perte de clé (base recréée,
`resynchronisationRequise` vrai), coffre indisponible (fichier intact), échec
de migration (données conservées, ouverture en clair) et les trois reprises
après interruption. Le seul cas non reproductible sans SQLCipher est la
migration nominale, `sqlcipher_export` n'existant pas dans le SQLite de
`sqflite_common_ffi` — d'où la recette sur appareil du §8.

---

## 10. Risques résiduels

1. **Aucune exécution sur appareil réel** à ce stade : la chaîne Android/iOS
   n'a été validée que par la compilation (§8, recette à faire).
2. **Le web reste en clair** (IndexedDB).
3. **La clé vit dans le Keystore**, donc accessible à l'application elle-même :
   un appareil rooté sur lequel l'application tourne reste attaquable. Le
   chiffrement protège le fichier **au repos**, pas un appareil compromis en
   cours d'usage.
4. **Sauvegardes** : une sauvegarde Android qui emporterait le fichier sans le
   Keystore produira une base illisible — comportement correct (§5), mais qui
   se solde par une resynchronisation. Interdire la sauvegarde du dossier
   `databases/` reste souhaitable (dossier `android/`, hors périmètre).
5. **Dépendance à un paquet tiers** maintenu par une seule personne ; repli
   documenté en §2.2.
6. **Les données jamais synchronisées sont perdues** en cas de perte de clé.
