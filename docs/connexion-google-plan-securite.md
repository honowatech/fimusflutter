# Connexion Google — plan de sécurisation et état d'avancement

> Origine : `temp_prompt.txt`, un brouillon de plan laissé à la racine du dépôt
> (02/08). Le fichier a été supprimé au sprint 5 ; son contenu est repris ici,
> **réduit à ce qui reste ouvert** et confronté au code actuel.
>
> Aucun identifiant ni secret n'est recopié dans ce document. La liste des
> audiences OAuth acceptées vit dans la variable d'environnement serveur
> `GOOGLE_CLIENT_IDS` (cf. `Backend/config/services.php`) et dans
> `android/app/google-services.json` ; ces valeurs ne doivent pas être
> dupliquées dans la documentation.

## Rappel du flux

`login_screen.dart` appelle `GoogleSignIn.instance.authenticate()`, récupère
l'`idToken` et le poste sur `/auth/google` via `auth_service.dart`. Le backend
(`AuthController::googleAuth`) valide le jeton, retrouve l'utilisateur par
`google_id` puis par e-mail, et renvoie un jeton Sanctum. Si le compte
n'existe pas, il répond 422 avec le code `REGISTRATION_INCOMPLETE`, que le
mobile traduit par un bottom sheet (pays / type / pseudo) avant de rejouer
l'appel.

## Déjà traité (vérifié dans le code au 23/09)

| Point du plan | État |
|---|---|
| Contrôle de l'audience (`aud`) du jeton — faille du « confused deputy » | Fait : `config('services.google.client_ids')` est comparé à l'audience du jeton |
| `email_verified` vérifié avant tout rattachement par e-mail | Fait |
| Pseudo saisi par l'utilisateur validé et persisté | Fait (`min:3|max:15`, unicité) |
| Mass-assignment `company_id` via `forceCreate` | Fait : plus aucun `forceCreate` dans le contrôleur |
| Codes d'erreur machine au lieu du string-matching français | Fait : `REGISTRATION_INCOMPLETE`, `PSEUDO_TAKEN`, `EMAIL_UNVERIFIED`, `INVALID_GOOGLE_TOKEN`, consommés par `auth_service.dart` |
| Limitation de débit par IP unique (`throttle:5,1`) et CGNAT opérateur | Fait : limiteurs nommés `auth_global`, `login`, `googleAuth` |
| Suppression de compte in-app (exigence Google Play) | Fait : `DELETE /api/user` + entrée « Supprimer mon compte » |
| Jetons Sanctum éternels | Fait : `SANCTUM_EXPIRATION` à 30 jours par défaut |

## Reste ouvert

### 1. `forgotPassword` envoie un mot de passe en clair (le plus grave)

`AuthController::forgotPassword` génère un mot de passe aléatoire, l'envoie par
e-mail puis l'applique au compte. Deux conséquences :

- toute personne connaissant une adresse e-mail peut **invalider le mot de
  passe d'un tiers** (déni de service sur le compte) ;
- un mot de passe circule en clair dans une boîte mail, et `WelcomePasswordMail`
  fait la même chose à l'inscription ;
- la validation `exists:users,email` permet en prime **d'énumérer les comptes**
  (réponse différente selon que l'adresse existe ou non).

Correctif : passer au `PasswordBroker` standard de Laravel (lien signé à durée
limitée), supprimer tout envoi de mot de passe en clair, et répondre
systématiquement 200 pour supprimer l'oracle d'énumération.

Un compte créé via Google reste joignable par ce chemin : la sécurisation de la
connexion Google ne vaut que si les flux mot de passe adjacents tiennent.

### 2. `google_id` indexé mais non unique

`add_missing_indexes_to_tables` pose un `index('google_id')`, pas un `unique()`.
Un double-tap ou un retry réseau peut créer deux comptes pour le même compte
Google. Correctif : migration `unique()`, plus `firstOrCreate` dans une
transaction, avec rattrapage sur `QueryException`.

### 3. Pas d'intercepteur 401 global côté mobile

`auth_service.dart` n'a qu'un intercepteur `onRequest`. Si le jeton Sanctum est
révoqué côté serveur, l'application échoue silencieusement sur chaque requête
jusqu'au prochain `checkAuthStatus`. Correctif : `onError` qui purge le jeton
sur un 401 hors endpoints d'authentification et renvoie vers l'écran de
connexion.

### 4. Codes d'erreur Google non mappés

Seul `canceled` est traité ; les autres tombent dans un `catch` générique qui
affiche `e.toString()` — texte technique anglais dans une application bilingue.
À mapper vers les ARB :

| Code | Cas réel | Message attendu |
|---|---|---|
| `interrupted` | appel entrant, app en arrière-plan | « Connexion interrompue, réessayez » |
| `uiUnavailable` | aucun compte Google, ROM sans Play Services | proposer le repli e-mail / mot de passe |
| `clientConfigurationError` | empreinte SHA absente (voir §6) | message générique + trace |
| `providerConfigurationError` | Play Services obsolètes | « Mettez à jour Google Play Services » |
| `userMismatch` | changement de compte | « Réessayez » |

Prévoir un repli visible vers l'inscription e-mail : sur une part non
négligeable du parc (Huawei récents, ROMs sans Play Services), la connexion
Google est structurellement indisponible.

### 5. Ergonomie du flux

- `signOut()` appelé avant chaque `authenticate()` impose le sélecteur de
  compte à chaque tentative : à réserver à un bouton « Changer de compte ».
- Le même `idToken` est rejoué après le bottom sheet ; s'il a expiré, la saisie
  de l'utilisateur est perdue. Sur `INVALID_GOOGLE_TOKEN`, relancer
  `authenticate()` en silence et rejouer la requête avec les champs déjà saisis.
- Un compte sans `country_id` retombe sur « Tous », ce qui fausse les taux et
  les codes USSD : exposer un indicateur `profile_complete` dans `/api/user`.

### 6. Configuration de consoles (sans code, à vérifier avant publication)

- **Empreintes Play App Signing dans Firebase.** Google Play resigne l'AAB avec
  sa propre clé. Si l'empreinte du certificat *App Signing* (et pas seulement
  celle d'*upload*) n'est pas déclarée dans Firebase, la connexion Google
  fonctionne en local et échoue pour tous les téléchargements Play Store
  (`DEVELOPER_ERROR` 10). Seul un test depuis la piste *internal testing* le
  démontre.
- **Écran de consentement OAuth** : doit être *In production*, sinon seuls les
  comptes de test peuvent se connecter.
- **Bouton Google** conforme aux *branding guidelines* (motif de rejet fréquent).
- **Data safety form** : déclarer e-mail, nom, photo, identifiant, données
  financières ; justifier les permissions USSD et contacts.

### 7. Plus tard

- **Nonce anti-rejeu** : dans `google_sign_in` 7.x le nonce est un paramètre
  d'`initialize()`. Le contrôle d'audience apporte déjà l'essentiel du bénéfice.
- **iOS** : `ios/Runner/` n'a ni `GoogleService-Info.plist`, ni `GIDClientID`,
  ni URL scheme `REVERSED_CLIENT_ID`. La connexion Google échouera d'emblée.
  À traiter avant toute soumission App Store, avec ajout du client iOS dans les
  audiences acceptées côté serveur.
- **Firebase App Check / Play Integrity**, en mode *monitoring* d'abord.
- **Observabilité** : journaliser côté serveur chaque échec de `googleAuth` avec
  son motif — jamais le jeton — et instrumenter côté mobile les étapes
  `google_auth_started / _needs_registration / _success / _failed`. Le taux
  d'abandon sur le bottom sheet est la métrique clé.

## Règle transversale

Les versions déjà installées depuis le Play Store continueront d'appeler
l'ancien contrat d'API pendant des mois : **ajouter** des champs `code` sans
retirer les `message` existants, jamais l'inverse.
