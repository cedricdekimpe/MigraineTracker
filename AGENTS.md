# Guide pour les agents IA - Problèmes CSS Tailwind en production

## Problème initial : Classes Tailwind manquantes en production

### Symptômes
- Les styles fonctionnent parfaitement en développement local
- En production, certaines classes CSS (comme `text-red-900`) sont absentes du fichier CSS compilé
- L'application s'affiche sans styles ou avec des styles partiels

### Cause racine
Tailwind CSS fonctionne différemment en développement vs production :

1. **En développement** : Tailwind génère toutes les classes à la volée (mode JIT complet). Toutes les classes sont disponibles même si elles ne sont pas explicitement utilisées dans le code.

2. **En production** : Tailwind purge agressivement les classes non utilisées pour réduire la taille du CSS. Il ne garde que les classes qu'il détecte dans les fichiers scannés par la configuration `content`.

3. **Pourquoi `text-red-900` était manquante** :
   - La classe n'était pas présente littéralement dans les fichiers ERB/HTML
   - Elle était peut-être générée dynamiquement dans un helper Ruby
   - Elle était peut-être dans un fichier non scanné par la config `content`
   - Tailwind ne pouvait pas la détecter et l'a donc supprimée lors de la purge

### Solution appliquée

#### 1. Ajout de patterns regex au safelist dans `config/tailwind.config.js`

Le `safelist` indique à Tailwind de toujours inclure certaines classes, même si elles ne sont pas détectées dans le code :

```javascript
safelist: [
  // ... classes existantes ...
  // Patterns pour les couleurs rouge (text-red-*, bg-red-*, border-red-*)
  { pattern: /^(text|bg|border)-red-(50|100|200|300|400|500|600|700|800|900)$/ },
  // Patterns pour hover states avec rouge
  { pattern: /^hover:(text|bg|border)-red-(50|100|200|300|400|500|600|700|800|900)$/ }
]
```

**Important** : Utiliser des patterns regex dans le safelist pour couvrir toutes les variantes d'une classe plutôt que de lister chaque classe individuellement.

#### 2. Compilation explicite de Tailwind dans le Dockerfile

Ajout d'une étape explicite pour compiler Tailwind avant la précompilation des assets :

```dockerfile
RUN --mount=type=secret,id=RAILS_MASTER_KEY \
  export RAILS_MASTER_KEY="$(cat /run/secrets/RAILS_MASTER_KEY)" && \
  ./bin/rails tailwindcss:build

RUN --mount=type=secret,id=RAILS_MASTER_KEY \
  export RAILS_MASTER_KEY="$(cat /run/secrets/RAILS_MASTER_KEY)" && \
  ./bin/rails assets:precompile
```

**Pourquoi** : S'assurer que Tailwind est compilé avec toutes les classes du safelist avant que Sprockets ne précompile les assets.

---

## Problème secondaire : 404 sur les fichiers CSS après déploiement

### Symptômes
- Après le déploiement avec Kamal, les fichiers CSS retournent une erreur 404
- L'application charge mais sans aucun style
- Les URLs des assets CSS sont générées mais les fichiers ne sont pas accessibles

### Cause racine
La configuration `public_file_server.enabled` dans `config/environments/production.rb` était conditionnelle et dépendait de variables d'environnement non définies :

```ruby
# ❌ MAUVAIS - Ne s'active pas car les variables ne sont pas définies
config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present? || ENV["RACK_ENV"] == "production"
```

**Pourquoi ça ne fonctionnait pas** :
- `RAILS_SERVE_STATIC_FILES` n'était pas défini dans l'environnement
- `RACK_ENV` n'était probablement pas défini non plus (Rails utilise `RAILS_ENV`)
- La condition évaluait à `false`, donc Rails ne servait pas les assets statiques
- Kamal s'attend à ce que Rails serve les assets depuis `/rails/public/assets` (comme configuré dans `deploy.yml` avec `asset_path: /rails/public/assets`)

### Solution appliquée

```ruby
# ✅ BON - Active directement le service des fichiers statiques
config.public_file_server.enabled = true
```

**Pourquoi ça fonctionne** :
- Avec Kamal, les assets sont précompilés dans `/rails/public/assets` pendant le build Docker
- Kamal configure le reverse proxy pour servir ces assets
- Rails doit être configuré pour servir les fichiers statiques depuis `public/`
- En activant directement `public_file_server.enabled = true`, Rails sert les assets correctement

---

## Leçons apprises

### 1. Tailwind CSS en production
- **Toujours** vérifier que les classes dynamiques ou générées sont dans le `safelist`
- Utiliser des patterns regex dans le safelist pour couvrir toutes les variantes
- Vérifier la configuration `content` pour s'assurer que tous les fichiers pertinents sont scannés
- Compiler Tailwind explicitement avant `assets:precompile` dans le Dockerfile

### 2. Configuration des assets avec Kamal
- **Toujours** activer `public_file_server.enabled = true` en production avec Kamal
- Ne pas dépendre de variables d'environnement non définies pour cette configuration critique
- Kamal s'attend à ce que Rails serve les assets depuis `public/assets`
- La configuration `asset_path: /rails/public/assets` dans `deploy.yml` doit correspondre à la configuration Rails

### 3. Ordre des opérations dans le Dockerfile
1. Installer les dépendances
2. Copier le code
3. Compiler Tailwind (`tailwindcss:build`)
4. Précompiler les assets (`assets:precompile`)
5. Copier les artefacts dans l'image finale

### 4. Debugging
Si les assets ne se chargent pas en production :
1. Vérifier que `public_file_server.enabled = true` dans `production.rb`
2. Vérifier que les assets sont bien précompilés : `ls -la /rails/public/assets` dans le conteneur
3. Vérifier que le safelist Tailwind contient les classes nécessaires
4. Vérifier les logs Rails pour voir si les requêtes d'assets arrivent

---

## Checklist pour éviter ces problèmes

### Avant de déployer en production
- [ ] Vérifier que toutes les classes Tailwind utilisées sont soit :
  - Présentes littéralement dans les fichiers scannés par `content`
  - Ajoutées au `safelist` avec des patterns appropriés
- [ ] Vérifier que `public_file_server.enabled = true` dans `production.rb`
- [ ] Vérifier que Tailwind est compilé avant `assets:precompile` dans le Dockerfile
- [ ] Tester la compilation locale en mode production : `RAILS_ENV=production bin/rails assets:precompile`
- [ ] Vérifier que le fichier `app/assets/builds/tailwind.css` est généré et contient les classes attendues

### Si des classes manquent après déploiement
1. Vérifier le safelist dans `tailwind.config.js`
2. Ajouter des patterns regex pour les classes manquantes
3. Rebuild et redéployer

### Si les assets retournent 404
1. Vérifier `public_file_server.enabled = true` dans `production.rb`
2. Vérifier que les assets sont précompilés dans le conteneur
3. Vérifier la configuration `asset_path` dans `deploy.yml`
4. Vérifier les logs du reverse proxy Kamal
