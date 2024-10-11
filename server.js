const express = require("express");
const fs = require("node:fs");
const sqlite3 = require("sqlite3");
const url = require("node:url");
const path = require("node:path");
const zlib = require("node:zlib");

// express application
const app = express();

// static content
app.use("/assets", express.static("public"));
app.use("/artifacts", express.static("artifacts"));

// fonts
app.get("/assets/fonts.css", async (request, response) => {
  const hints = request.get("User-Agent").includes("Macintosh") ? "off" : "on";
  const content = fs.readFileSync(
    path.join(__dirname, `public/fonts/_hints_${hints}.css.gz`)
  );

  response.set("Content-Type", "text/css");
  response.send(zlib.deflateSync(content).toString("base64"));
});

// database
process.env.DATABASE_URL ||= url
  .pathToFileURL("database/production.sqlite3")
  .toString();
const db = new sqlite3.Database(new URL(process.env.DATABASE_URL).pathname);

// pages
const makeHtml = function (title) {
  return `<!DOCTYPE HTML>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="shortcut icon" size="16x16, 32x32, 48x48, 64x64, 128x128, 256x256" href="/assets/favicon.ico">
  <title>${title}</title>
  <link rel="stylesheet" href="/assets/fonts.css">
  <link rel="stylesheet" href="/assets/style.css">
  <script src="/artifacts/elm.js"></script>
  <script src="/assets/highlight/highlight.pack.js"></script>
  <link rel="stylesheet" href="/assets/highlight/styles/default.css">
</head>
<body>
<script>Elm.Main.init()</script>
</body>
</html>`;
};

app.get("/", async (_request, response) => {
  response.send(makeHtml("Elm Packages"));
});

app.get("/packages", async (_request, response) => {
  response.redirect(301, "/");
});

app.get("/packages/:author/:project", async (request, response, next) => {
  await new Promise((resolve, reject) => {
    db.get(
      "SELECT * FROM packages WHERE author = ? AND project = ?",
      [request.params.author, request.params.project],
      (err, row) => {
        if (err) {
          reject(err);
        } else {
          if (row) {
            response.send(makeHtml(`${row.author}/${row.project}`));
          } else {
            next();
          }

          resolve();
        }
      }
    );
  });
});

app.get(
  "/packages/:author/:project/releases.json",
  async (request, response) => {
    await new Promise((resolve, reject) => {
      db.all(
        "SELECT r.version, r.time FROM releases AS r INNER JOIN packages AS p ON p.id = r.package_id WHERE p.author = ? AND p.project = ?",
        [request.params.author, request.params.project],
        (err, rows) => {
          if (err) {
            reject(err);
          } else {
            response.send(
              rows.reduce((acc, row) => {
                acc[row.version] = row.time;
                return acc;
              }, {})
            );
            resolve();
          }
        }
      );
    });
  }
);

app.get("/search.json", async (_request, response) => {
  await new Promise((resolve, reject) => {
    db.all(
      "SELECT CONCAT(p.author, '/', p.project) AS name, p.summary, p.license, r.version FROM packages AS p INNER JOIN releases AS r ON p.id = r.package_id WHERE r.id IN (SELECT MAX(r.id) AS id FROM releases AS r GROUP BY r.package_id)",
      (err, rows) => {
        if (err) {
          reject(err);
        } else {
          response.set("Content-Type", "application/json");
          response.send(rows);
          resolve();
        }
      }
    );
  });
});

app.get("/all-packages", async (_request, response) => {
  await new Promise((resolve, reject) => {
    db.all(
      "SELECT CONCAT(p.author, '/', p.project) AS name, r.version FROM packages AS p INNER JOIN releases AS r ON p.id = r.package_id",
      (err, rows) => {
        if (err) {
          reject(err);
        } else {
          response.set("Content-Type", "application/json");
          response.send(
            rows.reduce((acc, row) => {
              acc[row.name] ||= [];
              acc[row.name].push(row.version);
              return acc;
            }, {})
          );
          resolve();
        }
      }
    );
  });
});

app.get("/all-packages/since/:index", async (request, response) => {
  await new Promise((resolve, reject) => {
    db.all(
      "SELECT CONCAT(p.author, '/', p.project, '@', r.version) AS name FROM packages AS p INNER JOIN releases AS r ON p.id = r.package_id WHERE r.id > ? ORDER BY r.id DESC",
      [request.params.index],
      (err, rows) => {
        if (err) {
          reject(err);
        } else {
          response.set("Content-Type", "application/json");
          response.send(rows.map((row) => row.name));
          resolve();
        }
      }
    );
  });
});

app.get("/register", async (_request, response) => {
  response.send("TODO");
});

app.get("/help/design-guidelines", async (_request, response) => {
  response.send(makeHtml("Design Guidelines"));
});

app.get("/help/documentation-format", async (_request, response) => {
  response.send(makeHtml("Documentation Format"));
});

app.use((_request, response) => {
  response.status(404).send(makeHtml("Not Found"));
});

// database setup
db.exec(fs.readFileSync(path.join(__dirname, "database/init.sql")).toString());

// start web server
app.listen(3000, () => {
  console.log("Server is listening on port 3000");
});
