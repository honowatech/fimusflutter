# Plugins vendorisés (`third_party/`)

Trois plugins sont recopiés ici et référencés par chemin dans `pubspec.yaml`
(`path: third_party/<plugin>`) au lieu d'être tirés de pub.dev.

| Paquet | Version vendorisée | Version amont correspondante | Amont |
|---|---|---|---|
| `flutter_native_contact_picker` | 0.0.12 | 0.0.12 (identique) | https://pub.dev/packages/flutter_native_contact_picker |
| `flutter_phone_direct_caller` | 2.2.1 | 2.2.1 (identique) | https://pub.dev/packages/flutter_phone_direct_caller |
| `safe_device` | 1.4.1 | 1.4.1 (identique) | https://pub.dev/packages/safe_device |

Les trois copies partent de la **dernière version publiée** du paquet : aucune
n'est un fork divergent ni une version figée dans le passé.

## Raison du fork

Flutter 3.44+ construit l'application avec le Kotlin intégré d'AGP 9. Un plugin
qui applique lui-même le Kotlin Gradle Plugin (KGP) déclenche l'avertissement
« Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP) » —
avertissement aujourd'hui, échec de build dans une version future de Flutter.
Aucun des trois plugins n'a de version publiée qui abandonne KGP, d'où la copie
locale.

## Modification locale — un seul fichier par paquet

Vérifié par comparaison avec les archives du cache pub
(`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\<paquet>-<version>`) : le **seul**
fichier qui diffère de l'amont est `android/build.gradle`, et la modification
est la même dans les trois cas.

```diff
+// Vendored copy: Kotlin is compiled by AGP 9 built-in Kotlin
+// (android.builtInKotlin=true), so the Kotlin Gradle Plugin is not applied here.
 apply plugin: 'com.android.library'
-apply plugin: 'kotlin-android'
 ...
-    kotlinOptions {
-        jvmTarget = JavaVersion.VERSION_1_8
-    }
```

(`kotlinOptions` n'existe que dans les deux premiers paquets ; `safe_device` n'a
que la ligne `apply plugin`.) Aucun code Dart, Kotlin, Java, Swift ni
Objective-C n'a été touché. Les répertoires `example/`, `test/` et
`analysis_options.yaml` de l'amont n'ont pas été recopiés : ils ne servent pas
à la compilation de l'application.

Reproduire la vérification :

```sh
diff -r third_party/safe_device \
  "$LOCALAPPDATA/Pub/Cache/hosted/pub.dev/safe_device-1.4.1"
```

## Risques

1. **Aucune mise à jour automatique.** `flutter pub outdated` ne voit pas ces
   paquets : une correction de sécurité publiée en amont n'arrivera jamais
   seule. C'est la dette réelle de ce répertoire.
2. **`safe_device` porte une fonction de sécurité.** Le plugin réalise la
   détection de root, de jailbreak, d'émulateur et de fausse position GPS. Ces
   heuristiques se périment vite : Magisk, Zygisk et les modules de
   dissimulation évoluent en permanence, et une détection figée à la version
   1.4.1 perdra en efficacité avec le temps. **Surveiller activement les
   nouvelles versions de ce paquet**, contrairement aux deux autres dont
   l'obsolescence est sans conséquence de sécurité.
3. **Interaction avec R8.** `safe_device` appelle
   `Class.forName("android.os.SystemProperties")` puis `getMethod(...).invoke(...)`.
   La règle `-keep class com.xamdesign.safe_device.**` de
   `android/app/proguard-rules.pro` est **indispensable** : sans elle, la
   détection de root échoue silencieusement sur un build release. Les deux
   autres plugins y sont aussi protégés. Toute resynchronisation avec l'amont
   impose de rejouer le cas 13 de la recette de
   `docs/build-release-android.md`.
4. **Surface de confiance.** Le code de ces trois paquets n'est plus vérifié par
   le hash pub.dev (`sha256` de `pubspec.lock`) : il vit dans le dépôt et
   n'est contrôlé que par la revue de code.

## Resynchroniser avec l'amont

À faire dès qu'une version amont supportant le Kotlin intégré paraît :

1. `flutter pub cache add <paquet> --version <x.y.z>` pour récupérer l'archive.
2. Remplacer le contenu de `third_party/<paquet>/` par celui du cache.
3. Si la nouvelle version n'applique plus KGP, supprimer le répertoire et
   rétablir la contrainte normale `^x.y.z` dans `pubspec.yaml` — c'est la
   sortie souhaitée.
4. Sinon, rejouer la modification `android/build.gradle` ci-dessus et
   consigner la nouvelle version dans le tableau.
5. Dans les deux cas : `flutter build apk --release` puis la recette de
   `docs/build-release-android.md` (cas 10, 11 et 13 au minimum).

## Pour mémoire

Deux plugins **non vendorisés** appliquent encore KGP et produisent le même
avertissement au build : `flutter_timezone` et `mobile_scanner`. Ils ne sont pas
recopiés ici — ils sont suffisamment actifs pour qu'une version corrigée
paraisse d'elle-même. À surveiller avant la montée vers une version de Flutter
qui transformera cet avertissement en erreur.
