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
updated with the uplinks. Defaults to `0 0 * * * *` (hourly).
- **PORT**: The port on which the server will run. Defaults to `3000`.
