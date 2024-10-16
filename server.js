import express from "express";
import multer from "multer";
import fs from "node:fs";
import sqlite3 from "sqlite3";
import url from "node:url";
import path from "node:path";
import zlib from "node:zlib";
import https from "node:https";
import { Octokit } from "@octokit/core";
import StreamZip from "node-stream-zip";
import crypto from "node:crypto";

const upload = multer({ dest: "packages/" });

const octokit = new Octokit({ auth: process.env.GITHUB_ACCESS_TOKEN });

// https://flaviocopes.com/fix-dirname-not-defined-es-module-scope/
const __filename = url.fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

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

sqlite3.verbose();

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
              rows
                .sort((a, b) => {
                  const [majorA, minorA, patchA] = a.version.split(".");
                  const [majorB, minorB, patchB] = b.version.split(".");

                  if (majorA === majorB) {
                    if (minorA === minorB) {
                      return patchA - patchB;
                    }

                    return minorA - minorB;
                  }

                  return majorA - majorB;
                })
                .reduce((acc, row) => {
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

app.get(
  "/packages/:author/:project/:version?",
  async (request, response, next) => {
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
  }
);

app.get(
  "/packages/:author/:project/:version/about",
  async (request, response, next) => {
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
  }
);

const foo = (filepath) => {
  return async (request, response) => {
    const { author, project, version } = request.params;
    const zipballPath = `./packages/${author}/${project}-${version}.zip`;

    if (!fs.existsSync(zipballPath)) {
      const tags = await octokit.request(
        "GET /repos/{owner}/{repo}/git/refs/tags/{version}",
        { owner: author, repo: project, version }
      );

      const zipball = await octokit.request(
        "GET /repos/{owner}/{repo}/zipball/refs/tags/{version}",
        { owner: author, repo: project, version }
      );

      if (!fs.existsSync(`./packages/${author}`)) {
        fs.mkdirSync(`./packages/${author}`, true);
      }
      fs.appendFileSync(zipballPath, Buffer.from(zipball.data));
    }

    const zip = new StreamZip({
      file: zipballPath,
      storeEntries: true,
    });

    zip.on("ready", () => {
      let topLevelDirectory = "";

      for (const entry of Object.values(zip.entries())) {
        const desc = entry.isDirectory ? "directory" : `${entry.size} bytes`;

        if (
          entry.isDirectory &&
          new RegExp(`^${author}-${project}-[0-9a-f]{5,40}\/$`, "i").test(
            entry.name
          )
        ) {
          topLevelDirectory = entry.name;
        }
      }

      let content = zip
        .entryDataSync(`${topLevelDirectory}${filepath}`)
        .toString("utf8");

      response.send(content);

      // Do not forget to close the file once you're done
      zip.close();
    });
  };
};

app.get("/packages/:author/:project/:version/elm.json", foo("elm.json"));

app.get(
  "/packages/:author/:project/:version/docs.json",
  async (request, _response, next) => {
    console.log("docs.json", request.params);
    next();
  }
);

app.get("/packages/:author/:project/:version/README.md", foo("README.md"));

app.get(
  "/packages/:author/:project/:version/endpoint.json",
  async (request, response) => {
    const { author, project, version } = request.params;

    // ...
    const filename = `./packages/${author}/${project}-${version}.zip`;
    const hash = crypto.createHash("sha1");

    const input = fs.createReadStream(filename);
    input.on("readable", () => {
      // Only one element is going to be produced by the
      // hash stream.
      const data = input.read();

      if (data) {
        hash.update(data);
      } else {
        response.send({
          url: `https://github.com/${author}/${project}/zipball/${version}/`,
          hash: hash.digest("hex"),
        });
      }
    });
  }
);

app.get(
  "/packages/:author/:project/:version/:path*",
  async (request, response, next) => {
    console.log(request.params);
    next();
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

app.post("/all-packages", async (_request, response) => {
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

app.post("/all-packages/since/:index", async (request, response) => {
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

const registerUpload = upload.fields([
  { name: "elm.json", maxCount: 1 },
  { name: "docs.json", maxCount: 1 },
  { name: "README.md", maxCount: 1 },
  { name: "github-hash", maxCount: 1 },
]);

app.post("/register", registerUpload, async (request, response) => {
  response.send(request.files);
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

  const zipball = await octokit.request(
    "GET /repos/{owner}/{repo}/zipball/refs/tags/{version}",
    { owner: author, repo: project, version }
  );

  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }

  fs.appendFileSync(zipballPath, Buffer.from(zipball.data));

  return new Promise((resolve, reject) => {
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
        const elmJsonRegExp = new RegExp(
          `^${author}-${project}-[0-9a-f]{5,40}\/elm(-package)?\.json$`,
          "i"
        );

        const zip = new StreamZip({
          file: zipballPath,
          storeEntries: true,
        });

        zip.on("ready", () => {
          let elmJsonEntry;

          for (const entry of Object.values(zip.entries())) {
            if (!entry.isDirectory && elmJsonRegExp.test(entry.name)) {
              elmJsonEntry = entry.name;
            }
          }

          let elmJson = {};

          if (elmJsonEntry) {
            const content = zip.entryDataSync(elmJsonEntry).toString("utf8");
            elmJson = JSON.parse(content);
          }

          // Do not forget to close the file once you're done
          zip.close();

          resolve(elmJson);
        });
      }),
    ]).then(([releases, docs, elmJson]) => {
      db.serialize(function () {
        db.run("BEGIN");

        db.run(
          "INSERT INTO packages VALUES (NULL, ?, ?, ?, ?, ?) ON CONFLICT(author, project, uplink_id) DO UPDATE SET summary=excluded.summary, license=excluded.license",
          [author, project, elmJson.summary, elmJson.license, uplink.id]
        );

        db.run(
          "INSERT INTO releases VALUES (NULL, ?, ?, ?, (SELECT id FROM packages WHERE author = ? AND project = ?))",
          [version, releases[version], JSON.stringify(docs), author, project]
        );

        db.run("UPDATE uplinks SET lastIndex = lastIndex + 1 WHERE id = ?", [
          uplink.id,
        ]);

        db.run("COMMIT", (err) => {
          if (err) {
            reject(err);
          } else {
            resolve();
          }
        });
      });
    });
  });
};

const handleAllPackages = async (uplink, allPackages) => {
  for (const pkg of allPackages) {
    await handlePackage(uplink, pkg);
  }
};

// Database Setup
db.exec(fs.readFileSync(path.join(__dirname, "database/init.sql")).toString());

db.each(
  "SELECT * FROM uplinks",
  handleError((uplink) => {
    https
      .get(`${uplink.url}/all-packages/since/${uplink.lastIndex}`, (res) => {
        let allPackagesRawData = "";

        res.on("data", (chunk) => {
          allPackagesRawData += chunk;
        });

        res.on("end", () => {
          try {
            const allPackages = JSON.parse(allPackagesRawData);

            if (allPackages.length > 0) {
              handleAllPackages(uplink, allPackages.reverse());
            }
          } catch (e) {
            console.error(e);
          }
        });
      })
      .on("error", (e) => {
        console.error(e);
      });
  })
);

// start web server
process.env.PORT ||= 3000;

app.listen(process.env.PORT, () => {
  console.log(`Server is listening on http://localhost:${process.env.PORT}...`);
});
