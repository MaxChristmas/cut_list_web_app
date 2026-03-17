# Cut List Web App

Application SaaS Rails 8.1 d'optimisation de plans de découpe de matériaux (bois, métal, etc.). Les utilisateurs saisissent les dimensions d'un panneau et les pièces à découper, et l'application calcule la disposition optimale pour minimiser les chutes.

---

## Tech Stack

| Composant | Version / Outil |
|-----------|----------------|
| Langage | Ruby 3.3.6 |
| Framework | Rails 8.1 |
| Base de données | PostgreSQL |
| Asset pipeline | Propshaft + jsbundling (esbuild) + cssbundling |
| CSS | Tailwind CSS v4 (`@import "tailwindcss"`) |
| JS | Hotwire (Turbo + Stimulus) |
| Auth | Devise + Google OAuth2 |
| Paiement | Stripe (abonnements + one-shot) |
| PDF | Prawn + prawn-table + prawn-svg |
| Jobs | Solid Queue (Rails 8 default) |
| Cache | Solid Cache |
| Action Cable | Solid Cable |
| Déploiement | Kamal |
| Tests | RSpec + Capybara + Selenium |
| Linting | RuboCop (rubocop-rails-omakase) |
| Sécurité | Brakeman + bundler-audit |

**Node 25.3.0 avec npm** (pas yarn — Procfile.dev utilise `npm run`).

---

## Architecture

### Modèle de données

```
User -has_many-> Project -has_many-> Optimization
User -has_many-> CouponRedemption -belongs_to-> Coupon
User -has_many-> ReportIssue
AdminUser (panneau admin séparé)
```

### Structure des dossiers clés

```
app/
  models/
    concerns/
      plannable.rb     # Logique d'abonnement (plans, features, limites)
      scorable.rb      # Score d'engagement (0–100)
  controllers/
    admin/             # Panneau d'administration
    users/             # Overrides Devise
  services/
    rust_cutting_service.rb   # Client API Rust (optimisation)
    cut_list_pdf_service.rb   # Génération PDF liste de découpe
    label_pdf_service.rb      # Génération PDF étiquettes Avery
  jobs/
    geocode_sign_in_job.rb    # Géolocalisation async
    ntfy_job.rb               # Notifications ntfy.sh
    ntfy_optimization_job.rb  # Notification 1ère optimisation
  mailers/
    report_issue_mailer.rb    # Réponse aux signalements
```

---

## Modèles

### User
Authentification Devise avec modules : `database_authenticatable, registerable, recoverable, rememberable, validatable, lockable, trackable, omniauthable` (Google OAuth2).

Champs notables :
- `plan` (default: `"free"`) — plan actuel
- `plan_expires_at` — expiration (plans one-shot ou coupons)
- `stripe_customer_id`, `stripe_subscription_id` — Stripe
- `discarded_at` — soft delete GDPR
- `locale` — préférence de langue
- `terms_accepted_at` — acceptation CGU
- `internal` — flag interne/test
- `last_sign_in_city`, `last_sign_in_country`, `last_sign_in_device` — géolocalisation

Includes : `Plannable`, `Scorable`

### Project
- `name` — optionnel
- `sheet_length`, `sheet_width` — dimensions du panneau (mm)
- `grain_direction` (enum: `none`, `along_length`, `along_width`) — sens du grain
- `token` — token public unique 20 caractères (utilisé dans les URLs à la place de l'ID)
- `archived_at` — soft delete
- `template` — projet modèle read-only visible par tous
- `bonus_optimizations`, `optimizations_count` (counter cache)
- `belongs_to :user, optional: true` — supporte les projets invités (user_id NULL)

### Optimization
- `result` (JSONB) — résultat complet de l'API Rust
- `edited_result` (JSONB) — layout modifié manuellement par l'utilisateur
- `status` — statut (ex: `"completed"`)
- `cut_direction` (enum: `auto`, `along_length`, `along_width`)
- `sheets_count` — nombre de panneaux nécessaires
- `efficiency` (decimal) — taux d'utilisation matière (%)
- `belongs_to :project, counter_cache: true`

### Coupon
- `code` — 6 caractères alphanumériques majuscules, unique
- `plan` — plan accordé (`worker` ou `enterprise`)
- `duration_days` — durée de validité du plan
- `max_uses` — nombre max de rédemptions (NULL = illimité)
- `uses_count` — rédemptions actuelles
- `expires_at` — expiration du coupon (NULL = pas d'expiration)

Méthodes clés : `redeemable?`, `expired?`, `redeem!(user)` (atomique)

### CouponRedemption
Contrainte unique : un utilisateur ne peut pas utiliser le même coupon deux fois.

### AdminUser
Devise séparé (`database_authenticatable, rememberable, validatable`). Panel admin protégé.

### ReportIssue
- `body`, `page_url` — signalement utilisateur
- `reply_body`, `replied_at`, `replied_by_id` — réponse admin

---

## Système de plans (Plannable)

```ruby
{
  "free"       => { max_active_projects: 1000, max_pieces_per_project: 25,      features: [:pdf_export, :label_pieces, :cut_direction, :blade_kerf] },
  "worker"     => { max_active_projects: ∞,    max_pieces_per_project: ∞,       features: [..., :import_csv, :print_labels, :move_pieces], prices: { monthly: 10€, yearly: 100€, one_shot: 5€ } },
  "enterprise" => { max_active_projects: ∞,    max_pieces_per_project: ∞,       features: [tous les 8], prices: { monthly: 20€, yearly: 200€, one_shot: 8€ } }
}
```

Méthodes clés (disponibles partout via ApplicationController) :
- `effective_plan` — plan effectif (prend en compte l'expiration)
- `plan_expired?` — vérifie `plan_expires_at < now`
- `can_create_project?`, `can_optimize_pieces?(pieces)`
- `has_feature?(feature)` — vérifie si la feature est dans le plan
- `usage_projects` — `{ used:, max: }` pour l'affichage de la progression

**Types de paiement :**
- Abonnement mensuel / annuel (Stripe Subscription)
- One-shot 3 jours (Stripe Checkout non-récurrent)
- Coupon (accordé par admin, durée configurable)

---

## Service d'optimisation

Microservice Rust open-source : [github.com/MaxChristmas/cut_optimizer](https://github.com/MaxChristmas/cut_optimizer/blob/main/README.md)

**RustCuttingService** appelle ce service à `ENV["OPTIMIZER_URL"]` (default: `http://localhost:3001/optimize`).

Input :
```json
{
  "stock": { "length": 2400, "width": 1200, "grain": "none" },
  "cuts": [
    { "rect": { "length": 300, "width": 200 }, "qty": 4, "grain": "auto" }
  ],
  "kerf": 3.5,
  "cut_direction": "auto"
}
```

Output : JSON avec `sheets` (placements x/y, rotations), `sheet_count`, `waste_percent`, `efficiency`.

---

## Routes principales

```
GET  /                         # Dashboard projets
GET  /projects/:token          # Détail projet + dernière optimisation
POST /projects                 # Créer projet + optimiser
PATCH /projects/:token         # Modifier projet + re-optimiser
GET  /projects/:token/export_pdf
GET  /projects/:token/export_labels
PATCH /projects/:token/archive
PATCH /projects/:token/unarchive
PATCH /projects/:token/save_layout    # Sauver layout édité manuellement
PATCH /projects/:token/reset_layout   # Restaurer layout original

GET  /plans                    # Page pricing
POST /plans/checkout           # Créer session Stripe
GET  /plans/success            # Vérification paiement
POST /plans/portal             # Portail facturation Stripe

POST /stripe/webhooks          # Webhooks Stripe

GET  /admin                    # Dashboard admin
     /admin/users              # Gestion utilisateurs
     /admin/projects           # Gestion projets
     /admin/coupons            # Gestion coupons
     /admin/report_issues      # Signalements

PATCH /locale                  # Changer la langue
GET  /faq, /privacy-policy, /legal-notices, /cookies-policy
```

---

## Commandes de développement

```bash
bin/setup              # Installer deps, préparer DB, démarrer
bin/dev                # Démarrer le serveur de dev

bundle exec rspec spec/                            # Tous les tests
bundle exec rspec spec/models/project_spec.rb      # Un fichier
bundle exec rspec spec/models/project_spec.rb:10   # Une ligne

bin/rubocop            # Lint Ruby
bin/brakeman --quiet --no-pager  # Analyse sécurité
bin/bundler-audit      # Audit vulnérabilités gems
bin/ci                 # Pipeline CI complet

bin/rails db:prepare   # Créer + migrer la DB
bin/rails db:migrate   # Appliquer migrations
bin/rails db:reset     # Réinitialiser la DB

bin/rails stimulus:manifest:update  # Mettre à jour le manifest Stimulus
```

Bases de données : `cut_list_web_app_development` / `cut_list_web_app_test`.

---

## Variables d'environnement

| Variable | Usage |
|----------|-------|
| `OPTIMIZER_URL` | URL du microservice Rust (default: `http://localhost:3001/optimize`) |
| `STRIPE_*_PRICE_ID` | IDs des prix Stripe (monthly/yearly/one_shot par plan) |
| `NTFY_TOPIC` | Topic ntfy.sh pour les notifications |
| `DATABASE_URL` | URL PostgreSQL (production) |

---

## Fonctionnalités notables

- **Mode invité** : les utilisateurs non connectés peuvent créer 1 projet (limites plan free). Lors de l'inscription, leurs projets sont automatiquement associés à leur compte.
- **Projets templates** : projets read-only visibles par tous les invités.
- **Édition manuelle du layout** : après optimisation, l'utilisateur peut réorganiser les pièces manuellement. Le résultat édité est sauvegardé séparément dans `edited_result`.
- **Sens du grain** : gestion du fil du bois (none, along_length, along_width) — pris en compte par l'algorithme.
- **Kerf (trait de scie)** : perte de matière liée à la découpe, configurable par l'utilisateur.
- **Export PDF** : liste de découpe avec visualisation colorée des placements.
- **Export étiquettes** : planches d'étiquettes Avery (formats 8 à 65 par page), multi-projets.
- **Score d'engagement** : formule pondérée (plan + connexions + projets + optimisations) pour la segmentation admin.
- **RGPD** : soft delete avec anonymisation (email, données auth, géolocalisation).
- **Géolocalisation** : IP lookup async à chaque connexion (ville, pays, device).
- **Notifications ntfy.sh** : alertes admin sur coupons, changements de plan, 1ère optimisation.
- **Rate limiting** : MemoryStore sur les actions critiques (create project: 3/s, register: 5/h, login: 10/15min, coupons: 5/h).
- **i18n** : préférence utilisateur + fallback Accept-Language. Dates admin en Europe/Paris.
