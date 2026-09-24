import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.honowa.fimus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.honowa.fimus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Plus de placeholder `usesCleartextTraffic` : la politique réseau est
        // décrite une fois pour toutes dans
        // res/xml/network_security_config.xml (HTTPS partout, HTTP en clair
        // réservé aux hôtes de développement).
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            isDebuggable = false
            signingConfig = signingConfigs.getByName("release")

            // ----------------------------------------------------------------
            // Minification / obfuscation du bytecode Java-Kotlin (R8)
            // ----------------------------------------------------------------
            // Constat d'audit M1 : le build release ne réduisait ni n'obscurcissait
            // le code natif. R8 supprime le code mort, renomme les classes et
            // rend la rétro-ingénierie de l'APK nettement plus coûteuse — un
            // prérequis pour une application financière.
            //
            // Les règles de conservation sont dans `proguard-rules.pro` (à côté
            // de ce fichier). Elles sont délibérément conservatrices : chaque
            // bibliothèque qui utilise la réflexion, le JNI ou la
            // désérialisation Gson y est protégée explicitement.
            //
            // Interrupteur de secours : si un crash suspecté R8 survient en
            // production, passer ces deux valeurs à `false`, republier, puis
            // diagnostiquer à froid avec le mapping (voir ci-dessous).
            isMinifyEnabled = true

            // ----------------------------------------------------------------
            // Filtrage des ABI — documenté, volontairement INACTIF
            // ----------------------------------------------------------------
            // Décommenter retire lib/x86_64/ (30 Mio) de l'APK universel :
            // 90,9 Mo -> ~61 Mo. À ne faire QUE pour un APK distribué
            // directement (hors Play Store) : la publication passe par l'App
            // Bundle, où Play ne sert x86_64 qu'aux appareils concernés —
            // l'exclure n'y ferait qu'abandonner les Chromebooks.
            //
            // Ce bloc doit rester dans `release` et JAMAIS remonter dans
            // `defaultConfig` : les émulateurs Android sont en x86_64, un
            // filtre global rendrait `flutter run` impossible pour l'équipe.
            //
            // ndk {
            //     abiFilters += listOf("armeabi-v7a", "arm64-v8a")
            // }

            // Supprime les ressources (drawables, layouts, strings) qu'aucun
            // code conservé ne référence. Dépend de isMinifyEnabled.
            // `shrinkResources` ne s'applique qu'aux ressources Android : les
            // assets Flutter (déclarés dans pubspec.yaml) ne sont pas touchés.
            isShrinkResources = true

            proguardFiles(
                // Règles de base d'AGP, version « optimisée » : inclut les
                // optimisations R8 en plus du simple shrinking.
                getDefaultProguardFile("proguard-android-optimize.txt"),
                // Nos règles projet.
                "proguard-rules.pro",
            )
        }
    }

    // Rappel : R8 produit `build/app/outputs/mapping/release/mapping.txt`.
    // Sans ce fichier, une stack trace Java venue de la production est
    // illisible, et il doit correspondre EXACTEMENT au build publié.
    // -> archiver mapping.txt à chaque publication et le téléverser sur la
    //    Play Console (onglet « Déobfuscation »).
    // Le pendant côté Dart est `--obfuscate --split-debug-info=build/symbols`
    // (voir docs/build-release-android.md).

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    // ------------------------------------------------------------------
    // App Bundle : découpage servi par Google Play
    // ------------------------------------------------------------------
    // Constat d'audit : l'APK universel pèse 90,9 Mo, dont 89 % de code natif
    // triplé (une copie par ABI). L'App Bundle règle ce point tout seul : Play
    // ne sert à chaque appareil que son ABI et sa densité (~36 Mo en arm64).
    // Voir docs/livraison-android-taille.md pour les mesures.
    //
    // Les splits d'ABI et de densité restent actifs — c'est là qu'est le gain.
    // Seul celui des langues est désactivé : l'application porte ses propres
    // traductions dans les assets Flutter (lib/l10n), donc le split ne gagne
    // rien côté app, mais il découperait les ressources des bibliothèques
    // Android embarquées (Play Services, AndroidX, ML Kit) selon la locale
    // système. Un utilisateur qui bascule FR/EN dans l'application verrait
    // alors des libellés système manquants. Coût : quelques centaines de Ko.
    bundle {
        language {
            enableSplit = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

configurations.all {
    resolutionStrategy {
        force("com.google.android.material:material:1.13.0")
        force("com.google.mlkit:barcode-scanning:17.3.0")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    implementation("com.google.android.material:material:1.13.0")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")

    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.16.0"))
    // Add the dependencies for Firebase products you want to use
    implementation("com.google.firebase:firebase-analytics")
}
