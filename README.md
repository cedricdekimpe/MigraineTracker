# MyMigraineManager

MyMigraineManager is a modern Rails 8 application that helps people track migraines, medications, and triggers through monthly and yearly calendars.

## Local Development

- Install prerequisites: Ruby 3.4.11, Bundler, SQLite 3, and Redis-compatible services if you intend to run Solid Queue accessories.
- Bootstrap the app with `bin/setup`, which installs gems, prepares the database, and installs Tailwind binaries.
- Run the development stack with `bin/dev` to start Rails, Tailwind, and any background workers.

## Testing

- Run model and integration tests with `bin/rails test`.
- Run system tests with `bin/rails test:system` (uses Capybara and the configured browser driver).

## Docker Workflow

The repository ships with a production-ready multi-stage `Dockerfile`. It mirrors the local environment by installing the same Ruby version, precompiling assets, and running under Thruster.

1. Build the image, passing the Ruby version from `.ruby-version` so the Docker base image always matches your app:
	```sh
	docker build --build-arg RUBY_VERSION="$(sed 's/ruby-//' .ruby-version)" -t my-migraine-manager .
	```
2. Prepare the database (the image defaults to SQLite inside `/rails/db/production.sqlite3`).
	```sh
	docker run --rm \
	  -e RAILS_MASTER_KEY="$(cat config/master.key 2>/dev/null || echo change-me)" \
	  my-migraine-manager ./bin/rails db:prepare
	```
3. Run the application (the container listens on port 80 because Thruster fronts Puma).
	```sh
	docker run --rm -p 3000:80 \
	  -e RAILS_LOG_TO_STDOUT=1 \
	  -e RAILS_MASTER_KEY="$(cat config/master.key 2>/dev/null || echo change-me)" \
	  --name my-migraine-manager \
	  my-migraine-manager
	```

### Staying in Sync

- The Docker build now fails fast if `ARG RUBY_VERSION` drifts from `.ruby-version`, preventing stale images.
- Re-run the build command after changing gems, Node assets, the Tailwind configuration, or the Ruby version.
- Provide additional environment variables (for example `SECRET_KEY_BASE`, mail credentials, Solid Queue adapters) via `--env` flags or an env file as needed.
