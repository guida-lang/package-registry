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