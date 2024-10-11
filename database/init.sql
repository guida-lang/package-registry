CREATE TABLE IF NOT EXISTS uplinks (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  url         TEXT
);

CREATE TABLE IF NOT EXISTS packages (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  author      TEXT,
  project     TEXT,
  summary     TEXT,
  license     TEXT,

  uplink_id   INTEGER,
  FOREIGN KEY(uplink_id) REFERENCES uplinks(id)
);

CREATE TABLE IF NOT EXISTS releases (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  version     TEXT,
  time        UNIXEPOCH NOT NULL,

  package_id  INTEGER NOT NULL,
  FOREIGN KEY(package_id) REFERENCES packages(id),

  UNIQUE(version, package_id)
);

-- INSERT INTO packages VALUES(NULL, "elm", "core", "Elm's standard libraries", "BSD-3-Clause", NULL);
-- INSERT INTO releases VALUES(NULL, "1.0.0", UNIXEPOCH(), 1);
-- INSERT INTO releases VALUES(NULL, "1.0.1", UNIXEPOCH(), 1);
-- INSERT INTO releases VALUES(NULL, "1.0.2", UNIXEPOCH(), 1);