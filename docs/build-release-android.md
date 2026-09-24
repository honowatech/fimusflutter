# Build release Android — Fimus (`com.honowa.fimus`)

Procédure de production d'un APK / AAB release, et recette à faire passer
avant toute publication.

> Contexte : ce document est issu du sprint 3 de l'audit, constat **M1** — le
> build release n'activait ni minification ni obfuscation.

---

## 1. Prérequis

| Élément | Attendu | Vérification |
|---|---|---|
| JDK | 17 | `flutter doctor -v` → « Java version 17.x » |
| Flutter | 3.47.x (canal stable) | `flutter --version` |
| Signature | `android/key.properties` + keystore | voir §2 |

### JDK : ne pas coder le chemin en dur

`android/gradle.properties` ne doit **pas** contenir `org.gradle.java.home`.
Un chemin absolu vers un JDK local casse le build sur tout autre poste et sur
la CI. Gradle résout le JDK via `JAVA_HOME`, puis via le JDK configuré pour
Flutter :

```sh
flutter config --jdk-dir="/chemin/vers/jdk-17"
```

La mémoire du démon est fixée à `-Xmx4G` : suffisant pour ce projet, R8
compris, et compatible avec un agent de CI standard.

---

## 2. Signature

La signature release est lue depuis `android/key.properties`, chargé par
`android/app/build.gradle.kts`. Ce fichier **est ignoré par git** et contient
des secrets ; il n'est jamais versionné ni recréé automatiquement.

```properties
storePassword=<…>
keyPassword=<…>
keyAlias=<…>
storeFile=<…>
```

Sans ce fichier, `signingConfigs.release` reçoit des valeurs nulles et
`flutter build apk --release` échoue à l'étape de signature. Sur un poste
neuf, récupérer le keystore et le `key.properties` auprès du responsable de
publication — **ne jamais générer une nouvelle clé** pour une application déjà
publiée : la Play Store refuserait la mise à jour.

---

## 3. Commande de build

### APK (test interne, distribution directe)

```sh
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols
```

### AAB (publication Play Store)

```sh
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols
```

> **Toujours publier en App Bundle.** L'APK universel pèse 90,9 Mo, dont
> 89 % de code natif dupliqué pour trois architectures ; via l'AAB, Play ne
> sert que l'ABI de l'appareil, soit ~36 Mo téléchargés. Mesures, variante
> `--split-per-abi` et réglages Gradle : `docs/livraison-android-taille.md`.

### Pourquoi `--obfuscate --split-debug-info`

Ces deux options se complètent avec R8 mais agissent sur une couche
différente :

| Couche | Outil | Activé par |
|---|---|---|
| Bytecode Java / Kotlin (plugins, `MainActivity`) | **R8** | `isMinifyEnabled` dans `build.gradle.kts` |
| Code Dart compilé en natif (`libapp.so`) | **`--obfuscate`** | option de ligne de commande |

R8 seul ne touche pas au code Dart : sans `--obfuscate`, les noms de classes
et de méthodes Dart restent lisibles dans le binaire natif.

`--split-debug-info=build/symbols` extrait les symboles de débogage hors de
l'APK (gain de taille) et les écrit dans `build/symbols/`.

> **Les symboles sont indispensables.** Sans eux, un rapport de crash Dart
> n'est qu'une suite d'adresses mémoire. Ils doivent être **archivés avec la
> version publiée**.

---

## 4. Artefacts à archiver pour CHAQUE version publiée

Ces fichiers sont générés à chaque build et **écrasés au build suivant**. Les
archiver au moment de la publication, indexés par numéro de version :

| Fichier | Rôle |
|---|---|
| `build/app/outputs/mapping/release/mapping.txt` | Déobfuscation des stack traces **Java** (R8) |
| `build/symbols/` | Déobfuscation des stack traces **Dart** (`--obfuscate`) |
| L'APK / AAB publié lui-même | Rejouer un diagnostic à l'identique |

`mapping.txt` se téléverse aussi sur la Play Console (onglet
« Déobfuscation ») pour que les rapports de plantage y soient lisibles.

Pour relire une trace Dart :

```sh
flutter symbolize -i <trace.txt> -d build/symbols/app.android-arm64.symbols
```

---

## 5. Minification (R8)

Configurée dans `android/app/build.gradle.kts`, buildType `release` :

```kotlin
isMinifyEnabled = true
isShrinkResources = true
proguardFiles(
    getDefaultProguardFile("proguard-android-optimize.txt"),
    "proguard-rules.pro",
)
```

Les règles de conservation vivent dans `android/app/proguard-rules.pro`. Elles
sont **volontairement conservatrices** : chaque bibliothèque qui recourt à la
réflexion, au JNI ou à la désérialisation Gson y est protégée explicitement.
Points sensibles couverts :

- **`flutter_local_notifications`** (`com.dexterous.**`) — risque n°1. Le
  plugin sérialise les notifications planifiées en JSON (Gson) dans les
  `SharedPreferences` et les relit au démarrage. Des champs renommés par R8
  produisent un crash au boot, invisible en debug.
- **`package:jni`** (`com.github.dart_lang.jni.**`) — résout classes et
  signatures Java *par chaîne de caractères* depuis Dart.
- **`safe_device`** (`com.xamdesign.safe_device.**`) — fait
  `Class.forName("android.os.SystemProperties")` puis `getMethod(...).invoke(...)`
  pour les détections de root et d'émulateur.
- **ML Kit / `mobile_scanner`** — détecteurs chargés dynamiquement par nom.
- **Firebase** — `ComponentRegistrar` découvert par réflexion au démarrage.
- **`local_auth` / AndroidX Biometric** — fragments instanciés par nom.
- Les deux autres plugins de `third_party/`
  (`flutter_native_contact_picker`, `flutter_phone_direct_caller`).

Les attributs `Signature`, `*Annotation*`, `SourceFile` et `LineNumberTable`
sont conservés : sans eux, les traces Java n'ont plus de numéro de ligne.

### Interrupteur de secours

Si un crash suspecté R8 survient en production : passer `isMinifyEnabled` et
`isShrinkResources` à `false`, republier, **puis** diagnostiquer à froid avec
`mapping.txt`. Ne pas ajouter de règle `-keep` au hasard sans avoir relu la
trace déobfusquée.

---

## 6. Recette avant publication

R8 casse en production ce qui passait en debug. Cette recette est le minimum
à faire passer **sur un APK release signé et minifié**, pas en `flutter run`.

```sh
flutter build apk --release --obfuscate --split-debug-info=build/symbols
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb logcat -c && adb logcat | grep -iE "AndroidRuntime|ClassNotFound|NoSuchMethod|fimus"
```

Garder `logcat` ouvert pendant toute la recette : une `ClassNotFoundException`
ou une `NoSuchMethodError` y apparaît même si l'écran ne montre rien.

| # | Cas à vérifier | Ce que ça valide |
|---|---|---|
| 1 | L'application démarre, l'onboarding puis l'écran de connexion s'affichent | Flutter embedding, `MainActivity` |
| 2 | Connexion par e-mail / mot de passe | Dio, `flutter_secure_storage`, Keystore |
| 3 | Connexion Google | `google_sign_in`, Play Services |
| 4 | Lecture et écriture en base : créer une dépense, fermer puis rouvrir l'app | `sqflite` |
| 5 | Notification locale immédiate | `flutter_local_notifications` |
| 6 | Notification **planifiée**, puis redémarrage de l'appareil | Gson + `ScheduledNotificationBootReceiver` — **le cas qui casse le plus souvent** |
| 7 | Notification push reçue | Firebase Messaging |
| 8 | Déverrouillage biométrique (écran de verrouillage) | `local_auth`, AndroidX Biometric |
| 9 | Scan d'un code-barres / QR | `mobile_scanner`, ML Kit |
| 10 | Sélection d'un contact | `flutter_native_contact_picker` |
| 11 | Appel direct d'un code USSD | `MethodChannel` `com.honowa.fimus/ussd` |
| 12 | Ajout d'une photo (galerie et appareil photo) | `image_picker`, `FileProvider` |
| 13 | Détection root / émulateur (`safe_device`) | réflexion `SystemProperties` |
| 14 | Graphiques de l'écran d'accueil | `fl_chart` (Dart pur, valide `--obfuscate`) |
| 15 | Bascule français / anglais | ressources l10n vs `shrinkResources` |

Les cas **6, 9 et 13** sont ceux dont la probabilité de régression sous R8 est
la plus élevée : ne pas les sauter.

---

## 7. Vérifier que l'obfuscation a bien eu lieu

```sh
# Le mapping doit être volumineux (plusieurs milliers de lignes).
wc -l build/app/outputs/mapping/release/mapping.txt

# Les symboles Dart doivent exister.
ls -la build/symbols/

# Aucun nom de classe Dart de l'app ne doit apparaître en clair.
unzip -p build/app/outputs/flutter-apk/app-release.apk lib/arm64-v8a/libapp.so \
  | strings | grep -c "ExpenseProvider"   # attendu : 0
```
