CREATE TABLE IF NOT EXISTS uplinks (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  url         TEXT UNIQUE,
  last_index  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS packages (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  author      TEXT NOT NULL,
  project     TEXT NOT NULL,
  summary     TEXT,
  license     TEXT,

  uplink_id   INTEGER,
  FOREIGN KEY(uplink_id) REFERENCES uplinks(id),

  UNIQUE(author, project, uplink_id)
);

CREATE TABLE IF NOT EXISTS releases (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  version     TEXT,
  time        UNIXEPOCH NOT NULL,
  is_guida    BOOLEAN NOT NULL DEFAULT FALSE,
  json        TEXT,
  readme      TEXT,
  docs        TEXT,
  hash        TEXT,

  package_id  INTEGER NOT NULL,
  FOREIGN KEY(package_id) REFERENCES packages(id),

  UNIQUE(version, package_id)
);

INSERT INTO uplinks VALUES(NULL, "https://package.elm-lang.org", 0) ON CONFLICT(url) DO NOTHING;