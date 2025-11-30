# Guida package registry

The source code for Guida's package website.

## Run server

Start by checking if the node version on your machine matches the one found on `.nvmrc`.
We advice the use of [Node Version Manager](https://github.com/nvm-sh/nvm) by running:

```
nvm use
```

Install the project dependencies with the following command:

```
npm ci
```

Compile the Elm code and the required stylesheet by running:

```
npm run build
```

Finally, you can start the server by running:

```
npm start
```

Visit http://localhost:3000.

## Deploy w/ Fly.io

Deploy the application by running `fly deploy`.

## Configuration

### Environment Variables

Below is a list of environment variables required by the application:

- **DATABASE_URL**: The connection string for the database used by the application.
Defaults to `database/development.sqlite3`.
- **ENABLE_CACHE**: Allows for the creation of a local copy of the packages.
Disabled by default.
- **CRON_TIME**: The cron syntax to fire off the background job to keep the registry
- **CRON_DISABLED**: Optional. When set to `true` (case-sensitive), the background cron job that polls uplinks will be disabled. By default the cron job runs; set this variable only when you want to disable polling.
updated with the uplinks. Defaults to `0 0 * * * *` (hourly).
- **PORT**: The port on which the server will run. Defaults to `3000`.
- **UPLINK**: Optional. The URL of an upstream package registry to mirror packages from (for example `https://package.elm-lang.org`).

	- When provided, the server inserts the uplink into the database at startup and the background cron job will poll the uplink for new packages.
	- Note: you only need to set `UPLINK` once. The value is persisted in the database so subsequent restarts do not require re-setting the environment variable.
