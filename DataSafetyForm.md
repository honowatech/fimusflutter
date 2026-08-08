# Google Play Data Safety Form Guidelines

Pour respecter la politique de sécurité des données de Google Play concernant l'ajout de Firebase Cloud Messaging et des données utilisateurs locales :

## Données collectées
- **Identifiants personnels** : L'ID utilisateur ou le numéro de téléphone (utilisés pour l'authentification).
- **Informations sur l'appareil (Device IDs)** : Les tokens FCM sont collectés pour envoyer des notifications push.

## Pratiques de sécurité
- Les données sont chiffrées en transit (HTTPS).
- Les utilisateurs peuvent demander la suppression de leurs données (le jeton FCM est automatiquement supprimé lors de la déconnexion).
- Les utilisateurs ont un contrôle total sur les préférences de notification.
