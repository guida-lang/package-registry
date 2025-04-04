import express from "express";
import cors from "cors";
import multer from "multer";
import fs from "node:fs";
import sqlite3 from "sqlite3";
import url from "node:url";
import path from "node:path";
import https from "node:https";
import { Octokit } from "@octokit/core";
import crypto from "node:crypto";
import * as cron from "cron";
import { createProxyMiddleware } from "http-proxy-middleware";

const octokit = new Octokit();
const upload = multer();

// https://flaviocopes.com/fix-dirname-not-defined-es-module-scope/
const __filename = url.fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Express Application
const app = express();
app.set("trust proxy", true);

// CORS
app.use(cors());

// Proxy github
app.use("/github/", createProxyMiddleware({
  target: "https://github.com",
  changeOrigin: true,
  followRedirects: true,
  logger: console,
  on: {
    proxyRes: (proxyRes) => {
      proxyRes.headers["access-control-allow-origin"] = "*";
    }
  }
}));

// Static Content
app.use("/assets", express.static("public"));
app.use("/public/fonts", express.static("public/fonts"));
app.use("/artifacts", express.static("artifacts"));

// Fonts
app.get("/assets/fonts.css", async (request, response) => {
  const hints = request.get("User-Agent").includes("Macintosh") ? "off" : "on";
  const content = fs.readFileSync(
    path.join(__dirname, `public/fonts/_hints_${hints}.css`)
  );

  response.set("Content-Type", "text/css");
  response.send(content);
});

// Database
process.env.DATABASE_URL ||= url
  .pathToFileURL("database/development.sqlite3")
  .toString();

sqlite3.verbose();

const db = new sqlite3.Database(new URL(process.env.DATABASE_URL).pathname);

// Caching
const ENABLE_CACHE = (process.env.ENABLE_CACHE === "true");

// Routes
const makeHtml = function (title) {
  return `<!DOCTYPE HTML>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="shortcut icon" size="16x16, 32x32, 48x48, 64x64, 128x128, 256x256" href="/assets/favicon.ico">
  <title>${title}</title>
  <link rel="stylesheet" href="/assets/fonts.css">
  <link rel="stylesheet" href="/assets/style.css">
  <script src="/artifacts/elm.min.js"></script>
  <script src="/assets/highlight/highlight.pack.js"></script>
  <link rel="stylesheet" href="/assets/highlight/styles/default.css">
</head>
<body>
<script>Elm.Main.init({ flags: new Date().getFullYear() })</script>
</body>
</html>`;
};

app.get("/", async (_req, res) => {
  res.send(makeHtml("Guida Packages"));
});

app.get("/packages", async (_req, res) => {
  res.redirect(301, "/");
});

app.get("/packages/:author/:project/releases.json", async (req, res, next) => {
  db.all(
    "SELECT r.version, r.time FROM releases AS r INNER JOIN packages AS p ON p.id = r.package_id WHERE p.author = ? AND p.project = ?",
    [req.params.author, req.params.project],
    (err, rows) => {
      if (err) {
        next(err);
      } else {
        res.send(
          rows
            .sort((a, b) => {
              const [majorA, minorA, patchA] = a.version.split(".");
              const [majorB, minorB, patchB] = b.version.split(".");

              if (majorA === majorB) {
                if (minorA === minorB) {
                  return parseInt(patchA) - parseInt(patchB);
                }

                return parseInt(minorA) - parseInt(minorB);
              }

              return parseInt(majorA) - parseInt(majorB);
            })
            .reduce((acc, row) => {
              acc[row.version] = row.time;
              return acc;
            }, {})
        );
      }
    }
  );
});

app.get("/packages/:author/:project/:version?", async (req, res, next) => {
  db.get(
    "SELECT * FROM packages WHERE author = ? AND project = ?",
    [req.params.author, req.params.project],
    (err, row) => {
      if (row) {
        res.send(makeHtml(`${row.author}/${row.project}`));
      } else {
        next(err);
      }
    }
  );
});

app.get("/packages/:author/:project/:version/about", async (req, res, next) => {
  db.get(
    "SELECT * FROM packages WHERE author = ? AND project = ?",
    [req.params.author, req.params.project],
    (err, row) => {
      if (err) {
        next(err);
      } else {
        res.send(makeHtml(`${row.author}/${row.project}`));
      }
    }
  );
});

app.get(
  "/packages/:author/:project/:version/elm.json",
  async (req, res, next) => {
    db.get(
      `
      SELECT r.elm_json FROM releases AS r
      INNER JOIN packages AS p ON p.id = r.package_id
      WHERE r.version = ? AND p.author = ? AND p.project = ?`,
      [req.params.version, req.params.author, req.params.project],
      (err, row) => {
        if (row) {
          res.send(row.elm_json);
        } else {
          next(err);
        }
      }
    );
  }
);

app.get(
  "/packages/:author/:project/:version/docs.json",
  async (req, res, next) => {
    db.get(
      `
      SELECT r.docs FROM releases AS r
      INNER JOIN packages AS p ON p.id = r.package_id
      WHERE r.version = ? AND p.author = ? AND p.project = ?`,
      [req.params.version, req.params.author, req.params.project],
      (err, row) => {
        if (row) {
          res.send(row.docs);
        } else {
          next(err);
        }
      }
    );
  }
);

app.get(
  "/packages/:author/:project/:version/README.md",
  async (req, res, next) => {
    db.get(
      `
      SELECT r.readme FROM releases AS r
      INNER JOIN packages AS p ON p.id = r.package_id
      WHERE r.version = ? AND p.author = ? AND p.project = ?`,
      [req.params.version, req.params.author, req.params.project],
      (err, row) => {
        if (row) {
          res.send(row.readme);
        } else {
          next(err);
        }
      }
    );
  }
);

app.get(
  "/packages/:author/:project/:version/endpoint.json",
  async (req, res, next) => {
    db.get(
      `
      SELECT r.hash FROM releases AS r
      INNER JOIN packages AS p ON p.id = r.package_id
      WHERE r.version = ? AND p.author = ? AND p.project = ?`,
      [req.params.version, req.params.author, req.params.project],
      (err, row) => {
        if (err) {
          next(err);
        } else {
          res.send({
            url: url.format({
              protocol: req.protocol,
              host: req.get("host"),
              pathname: `/github/${req.params.author}/${req.params.project}/zipball/${req.params.version}/`
            }),
            hash: row.hash,
          });
        }
      }
    );
  }
);

app.get("/packages/:author/:project/:version/:path*", async (req, res) => {
  res.send(
    makeHtml(
      `${req.params.path.replaceAll("-", ".")} - ${req.params.author}/${req.params.project
      } ${req.params.version}`
    )
  );
});

app.get("/search.json", async (_req, res, next) => {
  db.all(
    `
    SELECT CONCAT(p.author, '/', p.project) AS name, p.summary, p.license, r.version FROM packages AS p
    INNER JOIN releases AS r ON p.id = r.package_id
    WHERE r.id IN (SELECT MAX(r.id) AS id FROM releases AS r GROUP BY r.package_id) AND p.summary IS NOT NULL AND p.license IS NOT NULL`,
    (err, rows) => {
      if (err) {
        next(err);
      } else {
        res.set("Content-Type", "application/json").send(rows);
      }
    }
  );
});

app.post("/all-packages", async (_req, res, next) => {
  db.all(
    "SELECT CONCAT(p.author, '/', p.project) AS name, r.version FROM packages AS p INNER JOIN releases AS r ON p.id = r.package_id",
    (err, rows) => {
      if (err) {
        next(err);
      } else {
        res.set("Content-Type", "application/json").send(
          rows.reduce((acc, row) => {
            acc[row.name] ||= [];
            acc[row.name].push(row.version);
            return acc;
          }, {})
        );
      }
    }
  );
});

app.post("/all-packages/since/:index", async (req, res, next) => {
  db.all(
    "SELECT CONCAT(p.author, '/', p.project, '@', r.version) AS name FROM packages AS p INNER JOIN releases AS r ON p.id = r.package_id WHERE r.id > ? ORDER BY r.id DESC",
    [req.params.index],
    (err, rows) => {
      if (err) {
        next(err);
      } else {
        res
          .set("Content-Type", "application/json")
          .send(rows.map((row) => row.name));
      }
    }
  );
});

const registerUpload = upload.fields([
  { name: "elm.json", maxCount: 1 },
  { name: "docs.json", maxCount: 1 },
  { name: "README.md", maxCount: 1 },
  { name: "github-hash", maxCount: 1 },
]);

app.post("/register", registerUpload, async (req, res, next) => {
  let commitHash, pkg, vsn;

  if (req.query["commit-hash"]) {
    commitHash = req.query["commit-hash"];
  } else {
    return res.status(400).send(`I need a \`commit-hash\` query parameter.`);
  }

  if (req.query["name"]) {
    pkg = req.query["name"];
    // TODO verifyName
  } else {
    return res.status(400).send(`I need a \`name\` query parameter.`);
  }

  if (req.query["version"]) {
    vsn = req.query["version"];
    // TODO verifyVersion token memory pkg commitHash
  } else {
    return res.status(400).send(`I need a \`version\` query parameter.`);
  }

  const [author, project] = pkg.split("/");

  const dirPath = `./packages/0/${author}`;
  const zipballPath = `${dirPath}/${project}-${vsn}.zip`;

  let zipball;

  try {
    zipball = await octokit.request(
      "GET /repos/{owner}/{repo}/zipball/refs/tags/{vsn}",
      { owner: author, repo: project, vsn }
    );
  } catch (error) {
    if (error.status === 404) {
      console.log(`The ${author}/${project}@${vsn} tag was not found...`);
    } else {
      console.error(
        `An error occurred while checking for ${author}/${project}@${vsn} tag: ${error?.response?.data?.message}`
      );
    }
  }

  let hash;

  if (zipball) {
    const buffer = Buffer.from(zipball.data);

    if (ENABLE_CACHE) {
      if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
      }

      fs.appendFileSync(zipballPath, buffer);
    }

    hash = crypto.createHash("sha1").update(buffer).digest("hex");
  }

  // TODO compare hash with commitHash

  const elmJson = JSON.parse(req.files["elm.json"][0].buffer.toString());
  const docs = JSON.parse(req.files["docs.json"][0].buffer.toString());
  const readme = req.files["README.md"][0].buffer.toString();

  const time = Math.floor(new Date().getTime() / 1000);

  db.serialize(function () {
    db.run("BEGIN");

    db.run("INSERT INTO packages VALUES (NULL, ?, ?, ?, ?, NULL)", [
      author,
      project,
      elmJson.summary,
      elmJson.license,
    ]);

    db.run(
      "INSERT INTO releases VALUES (NULL, ?, ?, ?, ?, ?, ?, (SELECT id FROM packages WHERE author = ? AND project = ?))",
      [
        vsn,
        time,
        JSON.stringify(elmJson),
        readme,
        JSON.stringify(docs),
        hash,
        author,
        project,
      ]
    );

    db.run("COMMIT", (err) => {
      if (err) {
        // TODO revert pkg vsn
        res.status(400).send(err);
      } else {
        res.end();
      }
    });
  });
});

app.get("/help/design-guidelines", async (_req, res) => {
  res.send(makeHtml("Design Guidelines"));
});

app.get("/help/documentation-format", async (_req, res) => {
  res.send(makeHtml("Documentation Format"));
});

app.use((_req, res) => {
  res.status(404).send(makeHtml("Not Found"));
});

// Helpers
const handleError = (callback) => {
  return (err, row) => {
    if (err) {
      console.error(err);
    } else {
      callback(row);
    }
  };
};

const handlePackage = async (uplink, pkg) => {
  const [author, project, version] = pkg.split(/[\/@]/);

  const dirPath = `./packages/${uplink.id}/${author}`;
  const zipballPath = `${dirPath}/${project}-${version}.zip`;

  let zipball;

  try {
    zipball = await octokit.request(
      "GET /repos/{owner}/{repo}/zipball/refs/tags/{version}",
      { owner: author, repo: project, version }
    );
  } catch (error) {
    if (error.status === 404) {
      console.log(`The ${author}/${project}@${version} tag was not found...`);
    } else {
      console.error(
        `An error occurred while checking for ${author}/${project}@${version} tag: ${error?.response?.data?.message}`
      );
    }
  }

  let hash;

  if (zipball) {
    const buffer = Buffer.from(zipball.data);

    if (ENABLE_CACHE) {
      if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
      }

      fs.appendFileSync(zipballPath, buffer);
    }

    hash = crypto.createHash("sha1").update(buffer).digest("hex");
  }

  return new Promise((resolveAll, rejectAll) => {
    Promise.all([
      new Promise((resolve) => {
        let releasesRawData = "";

        https.get(
          `${uplink.url}/packages/${author}/${project}/releases.json`,
          (res) => {
            res.on("data", (chunk) => {
              releasesRawData += chunk;
            });

            res.on("end", () => {
              resolve(JSON.parse(releasesRawData));
            });
          }
        );
      }),
      new Promise((resolve) => {
        let docsRawData = "";

        https.get(
          `${uplink.url}/packages/${author}/${project}/${version}/docs.json`,
          (res) => {
            res.on("data", (chunk) => {
              docsRawData += chunk;
            });

            res.on("end", () => {
              resolve(JSON.parse(docsRawData));
            });
          }
        );
      }),
      new Promise((resolve) => {
        let elmRawData = "";

        https.get(
          `${uplink.url}/packages/${author}/${project}/${version}/elm.json`,
          (res) => {
            res.on("data", (chunk) => {
              elmRawData += chunk;
            });

            res.on("end", () => {
              resolve(JSON.parse(elmRawData));
            });
          }
        );
      }),
      new Promise((resolve) => {
        let readmeRawData = "";

        https.get(
          `${uplink.url}/packages/${author}/${project}/${version}/README.md`,
          (res) => {
            res.on("data", (chunk) => {
              readmeRawData += chunk;
            });

            res.on("end", () => {
              resolve(readmeRawData);
            });
          }
        );
      }),
    ]).then(([releases, docs, elmJson, readme]) => {
      db.serialize(function () {
        db.run("BEGIN");

        db.run(
          "INSERT INTO packages VALUES (NULL, ?, ?, ?, ?, ?) ON CONFLICT(author, project, uplink_id) DO UPDATE SET summary=excluded.summary, license=excluded.license",
          [author, project, elmJson?.summary, elmJson?.license, uplink.id]
        );

        db.run(
          "INSERT INTO releases VALUES (NULL, ?, ?, ?, ?, ?, ?, (SELECT id FROM packages WHERE author = ? AND project = ?))",
          [
            version,
            releases[version],
            elmJson && JSON.stringify(elmJson),
            readme,
            JSON.stringify(docs),
            hash,
            author,
            project,
          ]
        );

        db.run("UPDATE uplinks SET last_index = last_index + 1 WHERE id = ?", [
          uplink.id,
        ]);

        db.run("COMMIT", (err) => {
          if (err) {
            console.error(`Failed to add ${author}/${project}@${version}`, err);
            rejectAll(err);
          } else {
            console.log(`Successfully added ${author}/${project}@${version}`);
            resolveAll();
          }
        });
      });
    })
  });
};

const handleAllPackages = async (uplink, allPackages) => {
  for (const pkg of allPackages) {
    await handlePackage(uplink, pkg);
  }

  console.log(`Finished processing ${allPackages.length} for ${uplink.url}...`);
};

// Database Setup
db.exec(fs.readFileSync(path.join(__dirname, "database/init.sql")).toString());

// Cron job
let cronTime = "0 0 * * * *";

if (process.env.CRON_TIME) {
  const cronValidation = cron.validateCronExpression(process.env.CRON_TIME);
  if (cronValidation.valid) {
    cronTime = process.env.CRON_TIME;
  }
}

console.log(`CronJob time: "${cronTime}"`);

cron.CronJob.from({
  cronTime,
  onTick: async () => {
    return new Promise((resolveAll, rejectAll) => {
      db.all(
        "SELECT * FROM uplinks",
        handleError((uplinks) => {
          Promise.all(uplinks.map((uplink) => {
            return new Promise((resolve, reject) => {
              https.get(`${uplink.url}/all-packages/since/${uplink.last_index}`, (res) => {
                let allPackagesRawData = "";

                res.on("data", (chunk) => {
                  allPackagesRawData += chunk;
                });

                res.on("end", async () => {
                  try {
                    const allPackages = JSON.parse(allPackagesRawData);

                    if (allPackages.length > 0) {
                      await handleAllPackages(uplink, allPackages.reverse());

                    } else {
                      console.log(`No more packages found for ${uplink.url}...`);
                    }

                    resolve();
                  } catch (e) {
                    reject(e);
                  }
                });
              }).on("error", (e) => {
                reject(e);
              });
            });
          })).then(() => {
            resolveAll();
          }).catch((error) => {
            rejectAll(error);
          });
        })
      );
    });
  },
  start: true,
  runOnInit: true,
  waitForCompletion: true
});

// Start Web Server
process.env.PORT ||= 3000;

app.listen(process.env.PORT, () => {
  console.log(`Serving at http://localhost:${process.env.PORT}`);
});
