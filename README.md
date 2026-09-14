# Four DBMS in One `docker compose` — Postgres, MySQL, DuckDB, SQLite

A sandbox for the lecture's example database (`student` / `course` / `enrolled`), loaded
identically into four engines so the same query can be compared side by side.

Two of these are **client–server** systems (Postgres, MySQL): they run a daemon, listen on a
TCP port, and you talk to them over a socket. The other two are **embedded** libraries
(DuckDB, SQLite): there is no server and no port — the "database" is a single file and the
engine runs inside your own process. The containers for DuckDB and SQLite therefore just
keep a long-lived shell alive around that file so you have somewhere to run the CLI.

| Service    | Type          | Image                                     | Host port | Database                  | User / password |
|------------|---------------|-------------------------------------------|-----------|---------------------------|-----------------|
| `postgres` | client–server | `postgres:16-alpine`                      | `5432`    | `university`              | `student` / `student` |
| `mysql`    | client–server | `mysql:8.4`                               | `3306`    | `university`              | `student` / `student` (root: `root`) |
| `duckdb`   | embedded      | built from `images/duckdb` (DuckDB 1.1.3) | —         | `/data/university.duckdb` | — |
| `sqlite`   | embedded      | built from `images/sqlite` (SQLite 3.40)  | —         | `/data/university.sqlite` | — |

---

## 1. Layout

```
db_demo/
├── docker-compose.yml
├── README.md
├── images/
│   ├── duckdb/{Dockerfile,entrypoint.sh}   # downloads the DuckDB CLI, seeds the .duckdb file
│   └── sqlite/{Dockerfile,entrypoint.sh}   # installs sqlite3, seeds the .sqlite file
├── init/                                   # schema + data, one dialect per engine
│   ├── postgres/{01-schema.sql,02-data.sql}
│   ├── mysql/{01-schema.sql,02-data.sql}
│   ├── duckdb/init.sql
│   └── sqlite/init.sql
└── examples/                               # runnable query scripts, mounted at /examples
    ├── postgres.sql
    ├── mysql.sql
    ├── duckdb.sql
    └── sqlite.sql
```

---

## 2. Install Docker on Ubuntu

Skip if `docker compose version` already works.

```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl
```

```bash
sudo install -m 0755 -d /etc/apt/keyrings && sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && sudo chmod a+r /etc/apt/keyrings/docker.asc
```

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

```bash
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Run docker without `sudo`:

```bash
sudo usermod -aG docker "$USER" && newgrp docker
```

---

## 3. Start the stack

From the `db_demo/` directory:

```bash
docker compose up -d --build
```

First run takes a couple of minutes: it pulls Postgres and MySQL and builds the two small
DuckDB/SQLite images. Watch the services come up:

```bash
docker compose ps
```

```bash
docker compose logs -f
```

Postgres reports `healthy` within seconds; MySQL takes ~20–30 s on first boot because it
initialises its data directory before running the seed scripts.

### Stop, restart, wipe

```bash
docker compose stop
```

```bash
docker compose up -d
```

Delete everything including the data volumes, so the next `up` re-seeds from `init/`:

```bash
docker compose down -v
```

> The seed scripts run only when the data volume is **empty**. If you edit anything under
> `init/`, you must `docker compose down -v` before the change takes effect.

---

## 4. Connect and run queries

### 4.1 PostgreSQL

Interactive shell inside the container (no client install needed):

```bash
docker compose exec -it postgres psql -U student -d university
```

One-off query:

```bash
docker compose exec -T postgres psql -U student -d university -c "SELECT * FROM student ORDER BY sid;"
```

Run the whole example script:

```bash
docker compose exec -T postgres psql -U student -d university -f /examples/postgres.sql
```

From an Ubuntu host client over TCP (`sudo apt-get install -y postgresql-client`):

```bash
PGPASSWORD=student psql -h 127.0.0.1 -p 5432 -U student -d university
```

Useful `psql` meta-commands: `\dt` list tables, `\d student` describe, `\x` expanded output,
`\timing` query time, `\i /examples/postgres.sql` run a file, `\q` quit.

### 4.2 MySQL

```bash
docker compose exec -it mysql mysql -ustudent -pstudent university
```

```bash
docker compose exec -T mysql mysql -ustudent -pstudent university -e "SELECT * FROM student ORDER BY sid;"
```

```bash
docker compose exec -T mysql mysql -ustudent -pstudent university -e "SOURCE /examples/mysql.sql"
```

From an Ubuntu host client (`sudo apt-get install -y mysql-client`):

```bash
mysql -h 127.0.0.1 -P 3306 -ustudent -pstudent university
```

Useful commands: `SHOW TABLES;`, `DESCRIBE student;`, `SHOW CREATE TABLE enrolled\G` (the
`\G` prints one column per line), `SOURCE file.sql;`, `\q` quit. The
`[Warning] Using a password on the command line interface can be insecure` message is
expected — this is a throwaway teaching database.

### 4.3 DuckDB

No server; you open the database **file**. The container is only a place to run the CLI.

```bash
docker compose exec -it duckdb duckdb /data/university.duckdb
```

```bash
docker compose exec -T duckdb duckdb /data/university.duckdb -c "SELECT * FROM student ORDER BY sid;"
```

```bash
docker compose exec -T duckdb duckdb /data/university.duckdb ".read /examples/duckdb.sql"
```

Useful dot-commands: `.tables`, `.schema student`, `.mode box|csv|json|markdown`, `.timer on`,
`.read file.sql`, `.quit`. `DESCRIBE tbl` and `SUMMARIZE tbl` are SQL, not dot-commands.

DuckDB is one static binary, so it also installs straight onto Ubuntu with no daemon:

```bash
curl -fsSL https://install.duckdb.org | sh
```

### 4.4 SQLite

Same idea — one file, no server.

```bash
docker compose exec -it sqlite sqlite3 /data/university.sqlite
```

```bash
docker compose exec -T sqlite sqlite3 /data/university.sqlite "SELECT * FROM student ORDER BY sid;"
```

```bash
docker compose exec -T sqlite sqlite3 /data/university.sqlite ".read /examples/sqlite.sql"
```

Useful dot-commands: `.tables`, `.schema enrolled`, `.headers on`, `.mode box|csv|json`,
`.once out.csv` (send the next result to a file), `.timer on`, `.quit`.

On Ubuntu directly:

```bash
sudo apt-get install -y sqlite3
```

### 4.5 Copy the embedded database files out

```bash
docker compose cp duckdb:/data/university.duckdb ./university.duckdb
```

```bash
docker compose cp sqlite:/data/university.sqlite ./university.sqlite
```

---

## 5. The example database

Identical data in all four engines:

```sql
CREATE TABLE student (
    sid   INT PRIMARY KEY,
    name  VARCHAR(16),
    login VARCHAR(32) UNIQUE,
    age   SMALLINT,
    gpa   FLOAT
);

CREATE TABLE course (
    cid  VARCHAR(32) PRIMARY KEY,
    name VARCHAR(32) NOT NULL
);

CREATE TABLE enrolled (
    sid   INT         REFERENCES student (sid),
    cid   VARCHAR(32) REFERENCES course (cid),
    grade CHAR(1)
);
```

| sid   | name       | login         | age | gpa |
|-------|------------|---------------|-----|-----|
| 53666 | Kanye      | kanye@cs      | 44  | 4.0 |
| 53688 | Bieber     | jbieber@cs    | 27  | 3.9 |
| 53655 | Tupac      | shakur@cs     | 25  | 3.5 |
| 53633 | Kardashian | kardashian@cs | 42  | 3.7 |

`course`: `15-445` Database Systems, `15-721` Advanced Database Systems, `15-826` Data Mining,
`15-799` Special Topics in Databases.

`enrolled`: (53666, 15-445, C), (53688, 15-721, A), (53688, 15-826, B), (53655, 15-445, B),
(53666, 15-721, C), (53633, 15-826, A).

---

## 6. Worked examples

Each file in `examples/` covers the same ground — joins, aggregates, `GROUP BY … HAVING`,
string and date functions, nested queries, window functions, CTEs, recursive CTEs — and then
shows what makes that engine different. Run one end to end, or paste single queries into an
interactive shell.

### 6.1 The query that is the same everywhere

```sql
SELECT e.cid, s.name, s.gpa,
       RANK() OVER (PARTITION BY e.cid ORDER BY s.gpa DESC) AS gpa_rank
FROM enrolled AS e JOIN student AS s ON s.sid = e.sid
ORDER BY e.cid, gpa_rank;
```

```
  cid   |    name    | gpa | gpa_rank
--------+------------+-----+----------
 15-445 | Kanye      |   4 |        1
 15-445 | Tupac      | 3.5 |        2
 15-721 | Kanye      |   4 |        1
 15-721 | Bieber     | 3.9 |        2
 15-826 | Bieber     | 3.9 |        1
 15-826 | Kardashian | 3.7 |        2
```

Window functions need Postgres 8.4+, MySQL 8.0+, SQLite 3.25+, any DuckDB — all four images
qualify. Same for `WITH RECURSIVE`.

### 6.2 Days since the beginning of the year

Section `6b` of every script. A good small exercise in how differently the four engines model
dates, and in a distinction worth being precise about: the **day number** within the year is
1-based (Jan 1 is day 1), while **days elapsed** since Jan 1 is one less.

```sql
-- PostgreSQL
SELECT EXTRACT(DOY FROM CURRENT_DATE)::int                   AS day_of_year,
       CURRENT_DATE - DATE_TRUNC('year', CURRENT_DATE)::date AS days_elapsed;

-- MySQL  (MAKEDATE(year, 1) spells "January 1st of that year")
SELECT DAYOFYEAR(CURDATE())                              AS day_of_year,
       DATEDIFF(CURDATE(), MAKEDATE(YEAR(CURDATE()), 1)) AS days_elapsed;

-- SQLite  (STRFTIME returns a zero-padded string, so cast it)
SELECT CAST(STRFTIME('%j', 'now') AS INT) AS day_of_year,
       CAST(JULIANDAY('now', 'start of day')
            - JULIANDAY('now', 'start of year') AS INT) AS days_elapsed;

-- DuckDB
SELECT DAYOFYEAR(CURRENT_DATE)                                        AS day_of_year,
       DATE_DIFF('day', DATE_TRUNC('year', CURRENT_DATE), CURRENT_DATE) AS days_elapsed;
```

All four give the same answer — on 2026-09-13, `day_of_year = 256` and `days_elapsed = 255`.
Leap years need no special handling in any of them; the arithmetic is calendar-aware.

### 6.3 Nested queries, LATERAL joins and CTEs (slides 28–39)

Sections `8b`–`8e` and `10b` of every script — the three ways the lecture builds a query out
of other queries.

**Where a nested query may go** (slide 28) — almost anywhere: `WHERE`, the `SELECT` list, `FROM`,
even `ORDER BY`. A subquery that mentions a column from the outer query is *correlated*, and
re-runs once per outer row:

```sql
SELECT e.sid,
       (SELECT s.name FROM student AS s WHERE s.sid = e.sid) AS name,
       e.cid, e.grade
FROM enrolled AS e;
```

**`IN` / `ANY` / `ALL` / `EXISTS`** (slides 29–31, 34). `IN` is exactly `= ANY`; `ALL` requires
the comparison to hold for every inner row; `EXISTS` only asks whether the inner query returned
anything at all, and never compares its rows to the outer query. `NOT EXISTS` answers the
lecture's "courses with nobody enrolled" — `15-799`:

```sql
SELECT * FROM course
 WHERE NOT EXISTS (SELECT 1 FROM enrolled WHERE enrolled.cid = course.cid);
```

SQLite has no `ANY`/`ALL` at all, so its script rewrites `= ANY` as `IN` and `>= ALL` as a
comparison against `MAX()`.

**The SQL-92 trap** (slide 32). Mixing a bare column with an aggregate is rejected by three of
the four — verified messages, not paraphrases:

| | `SELECT MAX(e.sid), s.name FROM enrolled e, student s WHERE e.sid = s.sid` |
|---|---|
| Postgres | `ERROR: column "s.name" must appear in the GROUP BY clause…` |
| MySQL | `ERROR 1140 … incompatible with sql_mode=only_full_group_by` |
| DuckDB | `Binder Error: column "name" must appear in the GROUP BY clause…` |
| SQLite | **runs**, returns `53688 / Bieber` |

SQLite is not being sloppy by accident: with a *bare* `MIN()` or `MAX()` it documents that the
other columns come from the row that produced the extreme value. That guarantee covers no other
aggregate, so the portable form is the scalar subquery from slide 33:

```sql
SELECT sid, name FROM student WHERE sid = (SELECT MAX(sid) FROM enrolled);
```

**`LATERAL`** (slides 35–36) lets a `FROM` subquery reference entries listed before it — a
for-loop over the outer table. Postgres, MySQL and DuckDB support it; SQLite has no such
keyword and its script uses correlated scalar subqueries instead.

```sql
SELECT * FROM course AS c,
    LATERAL (SELECT COUNT(*) AS cnt FROM enrolled WHERE enrolled.cid = c.cid) AS t1,
    LATERAL (SELECT AVG(s.gpa) AS avg FROM student AS s
               JOIN enrolled AS e ON s.sid = e.sid WHERE e.cid = c.cid) AS t2
ORDER BY cnt DESC;
```

```
  cid   |            name             | cnt | avg
--------+-----------------------------+-----+------
 15-445 | Database Systems            |   2 | 3.75
 15-721 | Advanced Database Systems   |   2 | 3.95
 15-826 | Data Mining                 |   2 |  3.8
 15-799 | Special Topics in Databases |   0 |
```

`15-799` survives with `cnt = 0` and `avg = NULL` — the LATERAL blocks still run for it, and an
aggregate over no rows is `0` for `COUNT` and `NULL` for `AVG`. An inner join to `enrolled`
would have dropped the course entirely.

**CTEs** (slides 37–39) name a temporary result for the duration of one statement, with an
optional column alias list:

```sql
WITH cteSource (maxId) AS (
    SELECT MAX(sid) FROM enrolled
)
SELECT name FROM student, cteSource WHERE student.sid = cteSource.maxId;
```

Duplicate names in that alias list behave differently in all four engines, which is worth
demonstrating rather than asserting — SQLite is the one to watch, since it silently answers
`2` instead of raising anything:

| | `WITH cteName (colXXX, colXXX) AS (SELECT 1, 2)` |
|---|---|
| Postgres | definition is fine; referencing it → `column reference "colxxx" is ambiguous` |
| MySQL | definition rejected → `ERROR 1060: Duplicate column name 'colXXX'` |
| SQLite | accepted; `colXXX + colXXX` silently resolves to the first column → `2` |
| DuckDB | accepted; second column renamed to `colXXX_1` |

### 6.4 PostgreSQL — `examples/postgres.sql`

```bash
docker compose exec -T postgres psql -U student -d university -f /examples/postgres.sql
```

Beyond the shared core it shows set-returning functions, JSON aggregation, and the real
execution plan:

```sql
SELECT generate_series(1, 5) AS gs;
SELECT json_agg(row_to_json(s)) FROM student AS s;
EXPLAIN ANALYZE SELECT * FROM enrolled WHERE cid = '15-445';
```

Standard `||` concatenation, `EXTRACT(YEAR FROM NOW())`, `NOW() - INTERVAL '7 days'`, and
`>= ALL (subquery)` all work as written in the standard.

### 6.5 MySQL — `examples/mysql.sql`

```bash
docker compose exec -T mysql mysql -ustudent -pstudent university -e "SOURCE /examples/mysql.sql"
```

Two dialect traps worth knowing:

- **`||` means `OR`, not concatenation** (unless `sql_mode` includes `PIPES_AS_CONCAT`). Use
  `CONCAT(a, b, c)`.
- **InnoDB silently ignores column-level `REFERENCES`.** The schema in `init/mysql/` uses
  table-level `FOREIGN KEY (sid) REFERENCES student (sid)` clauses instead — otherwise the
  constraint would parse fine and enforce nothing. Verify with:

```bash
docker compose exec -T mysql mysql -ustudent -pstudent university -e "SHOW CREATE TABLE enrolled\G"
```

MySQL's own flavour: `GROUP_CONCAT(... ORDER BY ... SEPARATOR ', ')`,
`DATE_SUB(NOW(), INTERVAL 7 DAY)`, and `information_schema.REFERENTIAL_CONSTRAINTS`.

### 6.6 DuckDB — `examples/duckdb.sql`

```bash
docker compose exec -T duckdb duckdb /data/university.duckdb ".read /examples/duckdb.sql"
```

DuckDB is the columnar/OLAP one, and its dialect adds real conveniences:

```sql
SUMMARIZE student;                                   -- profile every column at once
SELECT * EXCLUDE (login) FROM student;               -- select-star minus a column
SELECT * REPLACE (gpa * 25 AS gpa) FROM student;     -- select-star with one column rewritten
SELECT cid, grade, COUNT(*) FROM enrolled GROUP BY ALL ORDER BY ALL;
SELECT cid, list(sid ORDER BY sid) AS students FROM enrolled GROUP BY cid;
```

It also queries files as if they were tables, with no load step:

```sql
COPY (SELECT s.name, e.cid, e.grade FROM student s JOIN enrolled e ON e.sid = s.sid)
     TO '/data/roster.parquet' (FORMAT PARQUET);
SELECT * FROM '/data/roster.parquet';
SELECT * FROM read_csv('/data/student.csv');
```

Note `INTERVAL 7 DAY` (unquoted) rather than Postgres's `INTERVAL '7 days'`.

### 6.7 SQLite — `examples/sqlite.sql`

```bash
docker compose exec -T sqlite sqlite3 /data/university.sqlite ".read /examples/sqlite.sql"
```

Three things to notice:

- **Foreign keys are off by default, and the setting is per-connection.**
  `PRAGMA foreign_keys = ON;` must be issued in *every* session that should enforce them.
  Without it, `INSERT INTO enrolled VALUES (99999, '15-445', 'A')` succeeds against a student
  who does not exist.
- **Dynamic typing.** Column types are "affinities", not constraints; `typeof()` tells you what
  a value actually is.
- **No `ALL` / `ANY` quantifiers.** Use a scalar subquery:
  `WHERE gpa = (SELECT MAX(gpa) FROM student)`.

Dates are functions over text/integers, not a native type:

```sql
SELECT DATE('now'), DATETIME('now'), STRFTIME('%Y','now'), DATE('now','-7 days');
```

Export straight from the shell:

```sql
.mode csv
.once /data/roster.csv
SELECT s.name, e.cid, e.grade FROM student s JOIN enrolled e ON e.sid = s.sid;
```

---

## 7. Dialect cheat sheet

| Task | PostgreSQL | MySQL | SQLite | DuckDB |
|---|---|---|---|---|
| Concatenate strings | `a \|\| b` | `CONCAT(a,b)` | `a \|\| b` | `a \|\| b` |
| Current timestamp | `NOW()` | `NOW()` | `DATETIME('now')` | `NOW()` |
| Extract year | `EXTRACT(YEAR FROM ts)` | `YEAR(ts)` | `STRFTIME('%Y', ts)` | `EXTRACT(YEAR FROM ts)` |
| 7 days ago | `NOW() - INTERVAL '7 days'` | `DATE_SUB(NOW(), INTERVAL 7 DAY)` | `DATE('now','-7 days')` | `NOW() - INTERVAL 7 DAY` |
| Day of year (1-based) | `EXTRACT(DOY FROM d)` | `DAYOFYEAR(d)` | `CAST(STRFTIME('%j', d) AS INT)` | `DAYOFYEAR(d)` |
| Days elapsed since Jan 1 | `d - DATE_TRUNC('year', d)::date` | `DATEDIFF(d, MAKEDATE(YEAR(d),1))` | `JULIANDAY(d) - JULIANDAY(d,'start of year')` | `DATE_DIFF('day', DATE_TRUNC('year', d), d)` |
| String aggregate | `string_agg(x, ', ')` | `GROUP_CONCAT(x SEPARATOR ', ')` | `GROUP_CONCAT(x, ', ')` | `string_agg(x, ', ')` |
| List tables | `\dt` | `SHOW TABLES;` | `.tables` | `SHOW TABLES;` |
| Describe table | `\d student` | `DESCRIBE student;` | `PRAGMA table_info(student);` | `DESCRIBE student;` |
| Query plan | `EXPLAIN ANALYZE` | `EXPLAIN ANALYZE` | `EXPLAIN QUERY PLAN` | `EXPLAIN ANALYZE` |
| FK enforced by default | yes | yes (table-level clause required) | **no** — needs `PRAGMA foreign_keys=ON` | yes |
| Quantified subquery `ALL`/`ANY` | yes | yes | no | yes |
| `LATERAL` join | yes | yes (8.0.14+) | **no** — use correlated scalar subqueries | yes |
| Duplicate CTE column alias | errors on *reference* | rejects the *definition* | silently uses the first | renames to `colXXX_1` |

---

## 8. Troubleshooting

**Port already in use** — something on the host already owns 5432 or 3306:

```bash
sudo ss -lptn 'sport = :5432'
```

Either stop that service (`sudo systemctl stop postgresql`) or change the left-hand side of the
port mapping in `docker-compose.yml`, e.g. `"55432:5432"`.

**Edited `init/` but nothing changed** — the seed scripts run only on an empty data volume:

```bash
docker compose down -v && docker compose up -d --build
```

**MySQL refuses connections right after `up`** — it is still initialising. Wait for the
healthcheck to flip:

```bash
docker compose ps mysql
```

**`permission denied` on the docker socket** — you are not in the `docker` group yet; see
section 2, then log out and back in.

**Inspect what got seeded:**

```bash
docker compose exec -T duckdb ls -la /data
```

**Full reset, including the locally built images:**

```bash
docker compose down -v --rmi local
```
