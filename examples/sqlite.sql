-- ============================================================
-- SQLite examples  (run: .read /examples/sqlite.sql)
-- ============================================================

.headers on
.mode box

-- SQLite does NOT enforce foreign keys unless you turn them on,
-- and the setting is per-connection.
PRAGMA foreign_keys = ON;

-- 1. Sanity check
.tables
PRAGMA table_info(student);
SELECT * FROM student ORDER BY sid;
SELECT * FROM course ORDER BY cid;
SELECT * FROM enrolled ORDER BY sid, cid;

-- 2. Join
SELECT s.name, e.grade
FROM student AS s
     JOIN enrolled AS e ON s.sid = e.sid
WHERE e.cid = '15-445'
ORDER BY s.name;

-- 3. Aggregates
SELECT COUNT(*) AS num_students, AVG(gpa) AS avg_gpa, MAX(age) AS oldest
FROM student;

-- 4. GROUP BY + HAVING
SELECT e.cid, c.name, COUNT(*) AS enrollment
FROM enrolled AS e JOIN course AS c ON c.cid = e.cid
GROUP BY e.cid, c.name
HAVING COUNT(*) > 1
ORDER BY enrollment DESC;

-- 5. Strings
SELECT UPPER(name) || ' <' || login || '>' AS contact
FROM student
WHERE login LIKE '%@cs';

SELECT e.cid, GROUP_CONCAT(s.name, ', ') AS roster
FROM enrolled AS e JOIN student AS s ON s.sid = e.sid
GROUP BY e.cid;

-- 6. Date / time (SQLite has no DATE type - these are string/int functions)
SELECT DATE('now')                AS today,
       DATETIME('now')            AS now_ts,
       STRFTIME('%Y', 'now')      AS yr,
       DATE('now', '-7 days')     AS a_week_ago;

-- 6b. Days since the beginning of the year.
--     STRFTIME('%j') returns a zero-padded STRING ('257'), so cast it.
--     JULIANDAY() converts to a floating-point day count, which subtracts
--     cleanly; 'start of day' strips the time so the result is a whole number.
SELECT DATE('now')                                AS today,
       DATE('now', 'start of year')               AS jan_1,
       CAST(STRFTIME('%j', 'now') AS INT)         AS day_of_year,
       CAST(JULIANDAY('now', 'start of day')
            - JULIANDAY('now', 'start of year') AS INT) AS days_elapsed;

-- 7. ORDER BY + LIMIT
SELECT name, gpa FROM student ORDER BY gpa DESC, name ASC LIMIT 2;

-- 8. Nested queries
SELECT name FROM student
WHERE sid IN (SELECT sid FROM enrolled)
ORDER BY name;

-- SQLite has no ALL/ANY quantifier - use a scalar subquery instead
SELECT name, gpa FROM student
WHERE gpa = (SELECT MAX(gpa) FROM student);

-- 8b. Where a nested query may appear (slide 28).
--     Inner queries can sit almost anywhere: in WHERE, in the SELECT list, in
--     FROM, even in ORDER BY.

--     In the SELECT list, as a CORRELATED scalar subquery: the inner query
--     mentions e.sid from the outer query, so it re-runs for every outer row.
SELECT e.sid,
       (SELECT s.name FROM student AS s WHERE s.sid = e.sid) AS name,
       e.cid, e.grade
FROM enrolled AS e
ORDER BY e.sid, e.cid;

--     In FROM, as a derived table (which needs an alias).
SELECT t.cid, t.enrollment
FROM (SELECT cid, COUNT(*) AS enrollment FROM enrolled GROUP BY cid) AS t
WHERE t.enrollment > 1;

--     Even in ORDER BY. This one sorts by a constant, so it changes nothing -
--     it is here only to show that the position is legal.
SELECT sid, name FROM student ORDER BY (SELECT MAX(sid) FROM student), sid;

-- 8c. IN / EXISTS (slides 29-31, 34).
--       IN     - matches at least one row of the inner result.
--       EXISTS - true if the inner query returns any row at all; the rows
--                themselves are never compared to anything.
--     SQLite has NO ANY / ALL quantifiers - they are a syntax error here.
--     Rewrite "= ANY" as IN, and ">= ALL" as a comparison against MAX().

-- "Get the names of students in 15-445", two equivalent ways.
SELECT name FROM student
 WHERE sid IN (SELECT sid FROM enrolled WHERE cid = '15-445');

SELECT name FROM student AS s
 WHERE EXISTS (SELECT 1 FROM enrolled AS e
                WHERE e.sid = s.sid AND e.cid = '15-445');

-- ">= ALL (SELECT sid FROM enrolled)" becomes:
SELECT sid, name FROM student
 WHERE sid >= (SELECT MAX(sid) FROM enrolled);

-- NOT EXISTS with a correlated inner query (slide 34):
-- "courses that have no students enrolled in them" -> 15-799.
SELECT * FROM course
 WHERE NOT EXISTS (SELECT 1 FROM enrolled
                    WHERE enrolled.cid = course.cid);

-- 8d. The SQL-92 trap (slide 32).
--     "Find the student record with the highest id that is enrolled in at
--     least one course." The tempting version mixes MAX() with a bare column.
--     SQLite ACCEPTS this, where Postgres, MySQL and DuckDB all reject it:
SELECT MAX(e.sid), s.name
FROM enrolled AS e, student AS s
WHERE e.sid = s.sid;

--     It even gives the right answer, because SQLite has a documented special
--     case: with a bare MIN() or MAX(), the other columns come from the row
--     that produced the extreme value. That guarantee does NOT extend to any
--     other aggregate - swap MAX for COUNT and the name is arbitrary. Do not
--     rely on this pattern in portable SQL.

--     The correct form, and the one that runs everywhere (slide 33's "is the").
SELECT sid, name FROM student
 WHERE sid = (SELECT MAX(sid) FROM enrolled);

-- 8e. LATERAL joins (slides 35-36) - NOT AVAILABLE in SQLite.
--     LATERAL lets a subquery in FROM reference entries listed before it, so
--     it runs once per outer row. SQLite has no LATERAL keyword:
--       Error: in prepare, near "SELECT": syntax error
--
--         SELECT * FROM (SELECT 1 AS x) AS t1,
--                       LATERAL (SELECT t1.x + 1 AS y) AS t2;
--
--     Correlated scalar subqueries in the SELECT list do the same job whenever
--     each block returns exactly one value, which covers the lecture example:
--     "number of students enrolled in each course and their average GPA".
SELECT c.cid,
       c.name,
       (SELECT COUNT(*) FROM enrolled AS e WHERE e.cid = c.cid) AS cnt,
       (SELECT AVG(s.gpa) FROM student AS s
          JOIN enrolled AS e ON s.sid = e.sid
         WHERE e.cid = c.cid) AS avg
FROM course AS c
ORDER BY cnt DESC;
--     15-799 comes back with cnt = 0 and avg = NULL: the subqueries still run
--     for it, and an aggregate over no rows is 0 for COUNT and NULL for AVG.

-- 9. Window functions (SQLite 3.25+)
SELECT e.cid, s.name, s.gpa,
       RANK() OVER (PARTITION BY e.cid ORDER BY s.gpa DESC) AS gpa_rank
FROM enrolled AS e JOIN student AS s ON s.sid = e.sid
ORDER BY e.cid, gpa_rank;

-- 10. CTE
WITH course_load AS (
    SELECT sid, COUNT(*) AS n FROM enrolled GROUP BY sid
)
SELECT s.name, cl.n AS courses
FROM student AS s JOIN course_load AS cl ON cl.sid = s.sid
ORDER BY cl.n DESC, s.name;

-- 10b. CTE details (slides 37-39).
--      A CTE is a named temporary result set that exists only for this one
--      statement - a readable alternative to a nested subquery.
WITH cteName AS (
    SELECT 1
)
SELECT * FROM cteName;

--      Output columns can be renamed in an alias list placed before AS.
WITH cteName (col1, col2) AS (
    SELECT 1, 2
)
SELECT col1 + col2 FROM cteName;

--      Slide 39's query: "student record with the highest id that is enrolled
--      in at least one course", written as a CTE instead of a subquery.
WITH cteSource (maxId) AS (
    SELECT MAX(sid) FROM enrolled
)
SELECT name FROM student, cteSource
 WHERE student.sid = cteSource.maxId;

--      Duplicate names in the alias list are the dangerous case here. SQLite
--      accepts them AND resolves the reference silently to the FIRST column,
--      so this returns 2 (1+1), not 3. No error, no warning.
WITH cteName (colXXX, colXXX) AS (
    SELECT 1, 2
)
SELECT colXXX + colXXX FROM cteName;
--      Postgres errors on the ambiguous reference, MySQL rejects the
--      definition, DuckDB renames the second column to colXXX_1.

-- 11. Recursive CTE
WITH RECURSIVE counter(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM counter WHERE n < 10
)
SELECT * FROM counter;

-- 12. SQLite specialities
.schema enrolled
SELECT type, name, sql FROM sqlite_master;
EXPLAIN QUERY PLAN SELECT * FROM enrolled WHERE cid = '15-445';

-- Dynamic typing: SQLite lets you store text in an INT column ("type affinity")
SELECT typeof(sid), typeof(name), typeof(gpa) FROM student LIMIT 1;

-- Export the roster to CSV inside the container
.mode csv
.once /data/roster.csv
SELECT s.name, e.cid, e.grade FROM student s JOIN enrolled e ON e.sid = s.sid;
.mode box

-- 13. With PRAGMA foreign_keys=ON this fails; without it, it succeeds.
--     Uncomment to try.
-- INSERT INTO enrolled (sid, cid, grade) VALUES (99999, '15-445', 'A');
