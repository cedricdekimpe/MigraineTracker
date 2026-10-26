# Migraine Tracker

Un journal de migraine gratuit qui reprend le calendrier papier des neurologues : trois mois par feuille, une lettre et une
intensité par jour, une marque pour chaque traitement. Fait par une seule personne, pour celles et ceux qui vivent avec des
migraines.

Version hébergée : **https://migraine-tracker.eu** (français et anglais) · [English version](README.md)

> Migraine Tracker est un outil de suivi personnel. Il ne pose pas de diagnostic et ne remplace pas un médecin.

## Ce qu'il fait

- **Noter une crise en deux gestes** (« J'ai mal ») : le type, puis l'intensité, sur un écran sombre pensé pour le moment où
  l'on a mal. Sans compte pour une première crise, et sans réseau (la crise est envoyée au retour du réseau).
- **Le calendrier papier, fidèlement** : mêmes lignes, mêmes lettres (M, T, aura, X, t), trois mois à la fois, sur téléphone
  comme sur grand écran.
- **Un rapport PDF pour la consultation**, qui reprend le calendrier, avec un résumé de l'année.
- **Des repères sur les limites de traitement** (jours par mois selon la classe de médicament, d'après des recommandations
  publiées) et ce que les chiffres veulent dire. Jamais un diagnostic.
- **Un bilan du jour facultatif** (sommeil, stress, repas, caféine) pour voir avec le temps ce qui précède les crises, et
  l'effet de chaque traitement tel que vous le notez.
- Installable comme une application (PWA), thèmes clair et sombre, export et import de toutes vos données, suppression du
  compte.

## Principes

- Ni publicité, ni abonnement, ni revente de données, ni traceur, ni script, police ou image venus d'un autre site.
- Aucune IA dans l'outil lui-même : il fait de simples calculs sur vos propres jours.
- [Pourquoi c'est gratuit](https://migraine-tracker.eu/fr/why-free) · [Un mot sur l'IA](https://migraine-tracker.eu/fr/about-ai)

## Le lancer

Rails 8.1, Ruby 3.4, SQLite, Hotwire, Tailwind, Devise. Tout tourne dans Docker, rien à installer sur votre machine.

```sh
bin/docker-dev bin/rails db:prepare                # prépare la base
bin/docker-dev bin/rails tailwindcss:build         # construit la feuille de style
bin/docker-dev bin/rails server -b 0.0.0.0         # l'appli sur http://localhost:3000
bin/docker-dev bin/rails test                      # tests
TTY_FLAGS=-i bin/docker-dev bash -c "RAILS_ENV=test bin/rails test:system"
```

Contrôles avant chaque version : `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`.

**Auto-hébergement.** L'image de production est un seul conteneur avec un volume SQLite (voir `Dockerfile`), réglé par des
variables d'environnement : `SECRET_KEY_BASE` (obligatoire), `APP_HOST`, et `SMTP_*` / `MAIL_FROM` pour les e-mails de
réinitialisation du mot de passe (facultatif). Un guide pas à pas n'est pas encore écrit ; `docs/BACKUP.md` décrit la
sauvegarde de la version hébergée. Si vous hébergez votre propre copie, vous êtes responsable des données qu'elle contient :
écrivez votre propre politique de confidentialité (les textes de `config/locales` nomment l'exploitant de la version
hébergée).

## Contribuer et sécurité

Voir [CONTRIBUTING.md](CONTRIBUTING.md) et [SECURITY.md](SECURITY.md). Questions : contact@migraine-tracker.eu

## Licence

Copyright (C) 2026 Cédric Dekimpe. Publié sous [licence publique générale Affero GNU v3.0](LICENSE) : vous pouvez lire,
utiliser, modifier et partager le code ; si vous faites tourner une version modifiée comme service, vous devez en offrir le
code source à ses utilisateurs. Le nom « Migraine Tracker » et son logo ne sont pas couverts par la licence : choisissez un
autre nom pour votre propre version.
