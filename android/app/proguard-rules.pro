# ==========================================================================
# Fimus (com.honowa.fimus) — règles R8 / ProGuard pour le buildType release
# ==========================================================================
# Philosophie : conservatrice. Une application financière ne peut pas se
# permettre un crash visible seulement en production. Chaque règle ci-dessous
# répond à un besoin identifié (réflexion, JNI, instanciation par nom depuis
# le manifest, ou désérialisation Gson). En cas de doute, on garde.
#
# Rappel important : R8 ne touche QUE le bytecode Java/Kotlin. Le code Dart
# est compilé en AOT natif (libapp.so) ; les modèles Dart de lib/models/ ne
# sont donc PAS concernés par ces règles. Leur obfuscation se fait via
# `flutter build apk --release --obfuscate --split-debug-info=build/symbols`
# (voir docs/build-release-android.md).
# ==========================================================================


# --------------------------------------------------------------------------
# 1. Attributs à conserver (traces de crash lisibles + génériques)
# --------------------------------------------------------------------------
# Signature / InnerClasses / EnclosingMethod : indispensables dès qu'un
#   TypeToken Gson ou un type générique est résolu par réflexion.
# *Annotation* : conserve les annotations runtime (Firebase, Gson @SerializedName…).
# SourceFile + LineNumberTable : sans eux, les stack traces Java sont
#   illisibles (pas de numéro de ligne). On les garde et on renomme le
#   SourceFile pour ne pas divulguer l'arborescence source.
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault
-renamesourcefileattribute SourceFile


# --------------------------------------------------------------------------
# 2. Flutter — moteur, embedding et plugins
# --------------------------------------------------------------------------
# io.flutter.** est appelé depuis le natif (JNI) et depuis le manifest
# (FlutterFragmentActivity). Le moteur enregistre aussi les plugins par
# réflexion via GeneratedPluginRegistrant.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Tout ce qui est annoté @Keep (androidx) ne doit jamais être retiré/renommé.
-keep class androidx.annotation.Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <methods>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <fields>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <init>(...);
}

# Toute méthode native (JNI) et la classe qui la porte : le nom est résolu
# côté C/C++ par chaîne de caractères, R8 ne peut pas le savoir.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}


# --------------------------------------------------------------------------
# 3. Code applicatif natif de Fimus
# --------------------------------------------------------------------------
# MainActivity est référencée par nom dans AndroidManifest.xml (AAPT2 génère
# déjà une règle, on la double par sécurité). Le MethodChannel "…/ussd" est
# résolu par chaîne, mais le handler est une lambda interne : garder la
# classe hôte suffit.
-keep class com.honowa.fimus.** { *; }


# --------------------------------------------------------------------------
# 4. Firebase (Core / Analytics / Messaging)
# --------------------------------------------------------------------------
# Firebase s'appuie massivement sur la réflexion : ComponentRegistrar est
# découvert via les métadonnées du manifest, les services (FirebaseMessagingService)
# sont instanciés par nom, et les payloads sont désérialisés.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Registrars de composants Firebase, découverts par réflexion au démarrage.
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keep @com.google.firebase.annotations.PublicApi class * { *; }

# Encodeurs/décodeurs de données Firebase (firebase-encoders), réflexion sur
# les annotations @Encodable.
-keep @interface com.google.firebase.encoders.annotations.**
-keepclassmembers class * {
    @com.google.firebase.encoders.annotations.Encodable$Ignore *;
}

# Plugins Flutter Firebase.
-keep class io.flutter.plugins.firebase.** { *; }
-dontwarn io.flutter.plugins.firebase.**


# --------------------------------------------------------------------------
# 5. flutter_local_notifications + Gson  (RISQUE R8 N°1)
# --------------------------------------------------------------------------
# C'est LA source de crash connue en release sur Flutter. Le plugin sérialise
# les notifications planifiées en JSON (Gson) dans SharedPreferences, puis les
# relit au boot via ScheduledNotificationBootReceiver. Si R8 renomme les
# champs des modèles, la relecture échoue ou produit des objets vides ->
# crash au démarrage, invisible en debug.
# Règle officiellement recommandée par le plugin :
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-dontwarn com.dexterous.**

# Gson : réflexion sur les champs, TypeToken générique, adaptateurs.
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepclassmembers class * implements com.google.gson.TypeAdapterFactory { *; }
-keepclassmembers class * implements com.google.gson.JsonSerializer { *; }
-keepclassmembers class * implements com.google.gson.JsonDeserializer { *; }

# --------------------------------------------------------------------------
# 5 bis. « Modèles sérialisés » — filet de sécurité générique
# --------------------------------------------------------------------------
# Tout POJO Java/Kotlin relu par réflexion doit garder ses champs ET son
# constructeur sans argument. On cible ici les conteneurs de modèles usuels
# des plugins embarqués, pas tout le classpath (sinon la minification
# ne sert plus à rien).
-keepclassmembers class **.models.** {
    <init>(...);
    <fields>;
}
-keepclassmembers class **.model.** {
    <init>(...);
    <fields>;
}
# Les enums sérialisés (Gson les résout par valueOf réflexif).
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
    **[] $VALUES;
    public *;
}
# Parcelable : le CREATOR est lu par réflexion par le framework.
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
# Serializable : signatures imposées par la JVM.
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}


# --------------------------------------------------------------------------
# 6. local_auth (biométrie) + AndroidX Biometric / Fragment
# --------------------------------------------------------------------------
# BiometricPrompt instancie des fragments par nom et s'appuie sur les
# callbacks AndroidX. Supprimer un callback casse le déverrouillage.
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.** { *; }
-keep class androidx.core.app.** { *; }
-dontwarn androidx.biometric.**


# --------------------------------------------------------------------------
# 7. sqflite / SQLite
# --------------------------------------------------------------------------
# Le plugin passe par MethodChannel (pas de réflexion), mais la bibliothèque
# SQLite sous-jacente et les requery/androidx.sqlite exposent du JNI.
-keep class com.tekartik.sqflite.** { *; }
-keep class androidx.sqlite.** { *; }
-keep class org.sqlite.** { *; }
-dontwarn com.tekartik.sqflite.**
-dontwarn org.sqlite.**


# --------------------------------------------------------------------------
# 8. mobile_scanner + ML Kit (barcode scanning)
# --------------------------------------------------------------------------
# ML Kit charge ses détecteurs dynamiquement (modules optionnels résolus par
# nom de classe) et passe par du JNI. Les règles ci-dessous sont celles
# publiées par Google ; sans elles, le scanner lève une
# ClassNotFoundException à la première ouverture de la caméra.
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**

-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# Composants ML Kit chargés dynamiquement par le runtime.
-keep class com.google.mlkit.common.sdkinternal.** { *; }
-keep class com.google.mlkit.vision.barcode.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keep class * implements com.google.mlkit.common.sdkinternal.OptionalModuleUtils { *; }
-keep class com.google.android.gms.vision.** { *; }

# CameraX, utilisé par mobile_scanner pour le flux vidéo.
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**


# --------------------------------------------------------------------------
# 9. google_sign_in
# --------------------------------------------------------------------------
# GoogleSignInApi repose sur Google Play Services (déjà couvert en §4), mais
# on garde explicitement le plugin et les modèles de compte.
-keep class io.flutter.plugins.googlesignin.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.auth.**


# --------------------------------------------------------------------------
# 10. image_picker
# --------------------------------------------------------------------------
# Utilise un FileProvider déclaré au manifest et EXIF via androidx.exifinterface.
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class androidx.exifinterface.** { *; }
-keep class androidx.core.content.FileProvider { *; }
-dontwarn io.flutter.plugins.imagepicker.**


# --------------------------------------------------------------------------
# 11. Plugins forkés de third_party/
# --------------------------------------------------------------------------
# safe_device : RISQUE RÉFLEXION AVÉRÉ.
#   SystemProperties.java et Rooted/RootedCheck.java font
#     Class.forName("android.os.SystemProperties")
#     .getMethod("get"|"getBoolean"|"getInt"|"getLong", …).invoke(...)
#   La classe cible est une classe *plateforme* (pas dans l'APK), donc R8 ne
#   peut pas la casser ; en revanche les classes appelantes, leurs champs
#   statiques (SP) et l'API publique du plugin doivent rester intacts, et les
#   détections de root/émulateur comparent des noms de classes/paquets en dur.
-keep class com.xamdesign.safe_device.** { *; }
-keepclassmembers class com.xamdesign.safe_device.** { *; }
-dontwarn com.xamdesign.safe_device.**

# flutter_native_contact_picker : MethodChannel + ActivityResult sur le
# ContactsContract du système.
-keep class com.jayesh.flutter_native_contact_picker.** { *; }
-dontwarn com.jayesh.flutter_native_contact_picker.**

# flutter_phone_direct_caller : MethodChannel + Intent ACTION_CALL.
-keep class com.yanisalfian.flutterphonedirectcaller.** { *; }
-dontwarn com.yanisalfian.flutterphonedirectcaller.**


# --------------------------------------------------------------------------
# 12. Autres plugins embarqués (defensif, coût faible)
# --------------------------------------------------------------------------
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-keep class net.wolverinebeach.flutter_timezone.** { *; }
-dontwarn com.baseflow.permissionhandler.**
-dontwarn com.it_nomads.fluttersecurestorage.**

# flutter_secure_storage s'appuie sur le Keystore Android et sur Tink.
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# package:jni — présent dans GeneratedPluginRegistrant via
#   com.github.dart_lang.jni.JniPlugin / jni_flutter.JniFlutterPlugin
# C'est le pont JNI de Dart : il résout les classes et les signatures de
# méthodes Java *par chaîne de caractères* depuis le code Dart. Toute
# obfuscation de ces classes provoque une NoSuchMethodError au runtime.
# Règle volontairement large : le gain de taille serait dérisoire face au risque.
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
-dontwarn com.github.dart_lang.jni.**


# --------------------------------------------------------------------------
# 13. Kotlin / coroutines / desugaring
# --------------------------------------------------------------------------
-keep class kotlin.Metadata { *; }
-keepclassmembers class **$WhenMappings { <fields>; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
-dontwarn kotlin.**
-dontwarn java.lang.invoke.**
-dontwarn **$$serializer

# Avertissements connus et sans conséquence du desugaring / d'OkHttp / Conscrypt.
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**


# --------------------------------------------------------------------------
# 14. Hygiène
# --------------------------------------------------------------------------
# On ne supprime PAS les logs : en cas d'incident en production, une trace
# logcat est la seule piste exploitable. (Décommenter seulement après une
# revue montrant qu'aucune donnée sensible n'est journalisée.)
# -assumenosideeffects class android.util.Log { public static *** d(...); public static *** v(...); }

# Note : inutile d'ajouter `-printconfiguration` ici. AGP écrit déjà la
# configuration R8 complète (toutes règles fusionnées) dans
# build/app/outputs/mapping/release/configuration.txt, aux côtés de
# seeds.txt (ce qui a été conservé) et usage.txt (ce qui a été supprimé).
# Ces trois fichiers sont les premiers à consulter pour diagnostiquer un
# crash suspecté R8.
