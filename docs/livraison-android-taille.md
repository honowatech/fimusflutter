# Taille de livraison Android — APK universel, App Bundle, split par ABI

> Sprint 5 — dette d'hygiène. Constat : l'APK release publié pèse **90,9 Mo**,
> ce qui est un frein direct à l'installation sur les réseaux et les appareils
> visés (Afrique centrale, stockage limité, data facturée).

## 1. D'où viennent les 90,9 Mo

Mesure faite sur `build/app/outputs/flutter-apk/app-release.apk`
(build release R8, 23/09) en sommant les tailles compressées par répertoire :

| Contenu | Taille compressée | Part |
|---|---|---|
| `lib/x86_64/` | 30,0 Mio | 33 % |
| `lib/arm64-v8a/` | 27,6 Mio | 30 % |
| `lib/armeabi-v7a/` | 24,0 Mio | 26 % |
| `assets/flutter_assets/` | 1,8 Mio | 2 % |
| Reste (dex, ressources, META-INF) | 7,1 Mio | 8 % |
| **Total** | **90,6 Mio** | |

**89 % de l'APK, ce sont trois copies du même code natif**, une par
architecture. Chaque utilisateur en exécute exactement une. Le reste — code
Dart compilé inclus, qui vit dans ces `.so` — ne pèse que ~9 Mio.

Reproduire la mesure :

```sh
python - <<'PY'
import zipfile, collections
z = zipfile.ZipFile('build/app/outputs/flutter-apk/app-release.apk')
c = collections.Counter()
for i in z.infolist():
    k = i.filename.split('/')[1] if i.filename.startswith('lib/') else 'autres'
    c[k] += i.compress_size
for k, v in c.most_common():
    print(f"{k:16s} {v/1048576:8.2f} Mio")
PY
```

## 2. Publication Play Store : App Bundle (recommandé)

```sh
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols
```

Sortie : `build/app/outputs/bundle/release/app-release.aab`.

L'AAB **n'est pas installé tel quel**. Google Play le découpe et ne sert à
chaque appareil que l'ABI, la densité d'écran et les langues qui le concernent.

| Artefact | Taille | Ce que l'utilisateur télécharge |
|---|---|---|
| APK universel actuel | 90,9 Mo | 90,9 Mo |
| AAB téléversé | ~80 Mo | — (jamais téléchargé) |
| APK servi par Play, arm64-v8a | — | **~36 Mo** |
| APK servi par Play, armeabi-v7a | — | **~33 Mo** |

Ordre de grandeur : ~9 Mio de contenu commun + l'ABI de l'appareil. Soit une
**division par ~2,5 du téléchargement**, sans aucune modification du code.

La taille réelle servie est visible après téléversement dans la Play Console
(Version → Détails → *Taille de téléchargement*) : c'est la seule source
faisant foi.

L'App Bundle est de toute façon **obligatoire** pour toute nouvelle
application sur Google Play.

## 3. Distribution hors Play : `--split-per-abi`

Pour un APK distribué à la main (test interne, APK envoyé par lien), l'AAB ne
sert à rien : il faut produire un APK par architecture.

```sh
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=build/symbols
```

Produit trois fichiers dans `build/app/outputs/flutter-apk/` :

| Fichier | Taille attendue | Cible |
|---|---|---|
| `app-armeabi-v7a-release.apk` | ~33 Mo | Android 32 bits (appareils anciens / bas de gamme) |
| `app-arm64-v8a-release.apk` | ~37 Mo | quasi tout le parc Android actuel |
| `app-x86_64-release.apk` | ~39 Mo | émulateurs, Chromebooks — inutile en distribution réelle |

Attention : un APK par ABI **ne s'installe pas sur une architecture qui ne
correspond pas**. Pour un lien de téléchargement unique sans détection
d'appareil, garder l'APK universel et se contenter d'exclure `x86_64` (§4).

## 4. Réglages Gradle

### 4.1 Splits de langue désactivés (actif)

`android/app/build.gradle.kts` :

```kotlin
bundle {
    language { enableSplit = false }
}
```

Les splits d'ABI et de densité restent actifs (c'est tout le gain de §2) ;
seul celui des langues est désactivé. Raison : l'application gère ses propres
traductions via les fichiers ARB de `lib/l10n/`, qui vivent dans les assets
Flutter et ne sont **pas** des ressources Android. Le split de langue ne
gagnerait donc rien côté application, mais découperait les ressources des
bibliothèques Android embarquées (Play Services, AndroidX, ML Kit) selon la
locale système de l'appareil : un utilisateur qui change de langue dans
l'application obtiendrait des libellés système manquants ou en anglais. Coût
du réglage : quelques centaines de kilo-octets.

### 4.2 Exclusion de `x86_64` (documentée, non activée)

Un bloc `ndk { abiFilters }` prêt à l'emploi et commenté se trouve dans le
`buildTypes { release { … } }` de `build.gradle.kts`. Il retire 30 Mio de
l'APK universel (90,9 → ~61 Mo).

**Ne jamais poser `abiFilters` dans `defaultConfig`** : les émulateurs Android
sont en x86_64 et un `flutter run` deviendrait impossible pour toute l'équipe.
Il ne doit s'appliquer qu'au buildType `release`.

Décision : laissé inactif. La publication passe par l'App Bundle (§2), où
Play ne sert l'ABI x86_64 qu'aux appareils qui en ont besoin — l'exclure ne
ferait qu'abandonner les Chromebooks sans rien gagner pour les autres. Le
réglage n'a d'intérêt que pour un APK universel distribué directement.

## 5. Ce qui reste, après

Les ~9 Mio non attribuables à une ABI, et surtout les ~24-30 Mio de code natif
par ABI, viennent des dépendances : ML Kit (`mobile_scanner`), Firebase, Play
Services. Deux pistes, hors périmètre de ce sprint :

- `mobile_scanner` propose une variante « unbundled » où le modèle ML Kit est
  téléchargé à la demande par Play Services au lieu d'être embarqué : c'est le
  plus gros poste isolable.
- `google_fonts` télécharge les polices à l'exécution ; vérifier qu'aucune
  police n'est en plus embarquée dans les assets.

Mesurer avant d'agir : `flutter build apk --release --analyze-size` produit un
rapport détaillé, ouvrable avec `devtools --appsize-base=…`.

---

Voir aussi `docs/build-release-android.md` : signature, R8, obfuscation Dart,
archivage du `mapping.txt` et recette de publication.
