-- ============================================================
-- DuckDB examples  (run: .read /examples/duckdb.sql)
-- ============================================================

-- 1. Sanity check
SHOW TABLES;
DESCRIBE student;
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

SELECT e.cid, string_agg(s.name, ', ' ORDER BY s.name) AS roster
FROM enrolled AS e JOIN student AS s ON s.sid = e.sid
GROUP BY e.cid;

-- 6. Date / time
SELECT CURRENT_DATE                       AS today,
       NOW()                              AS now_ts,
       EXTRACT(YEAR FROM NOW())           AS yr,
       NOW() - INTERVAL 7 DAY             AS a_week_ago;

-- 6b. Days since the beginning of the year.
--     DAYOFYEAR() is the 1-based day NUMBER; DATE_DIFF() from Jan 1 gives the
--     number of days ELAPSED, which is always one less.
SELECT CURRENT_DATE                                    AS today,
       DATE_TRUNC('year', CURRENT_DATE)                AS jan_1,
       DAYOFYEAR(CURRENT_DATE)                         AS day_of_year,
       DATE_DIFF('day', DATE_TRUNC('year', CURRENT_DATE), CURRENT_DATE) AS days_elapsed;

-- 7. ORDER BY + LIMIT
SELECT name, gpa FROM student ORDER BY gpa DESC, name ASC LIMIT 2;

-- 8. Nested queries
SELECT name FROM student
WHERE sid IN (SELECT sid FROM enrolled)
ORDER BY name;

SELECT name, gpa FROM student
WHERE gpa >= ALL (SELECT gpa FROM student);

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

-- 8c. IN / ANY / ALL / EXISTS (slides 29-31, 34).
--       IN     - matches at least one row of the inner result. Same as = ANY.
--       ANY    - the comparison must hold for AT LEAST ONE inner row.
--       ALL    - the comparison must hold for EVERY inner row.
--       EXISTS - true if the inner query returns any row at all; the rows
--                themselves are never compared to anything.

-- "Get the names of students in 15-445", three equivalent ways.
SELECT name FROM student
 WHERE sid IN (SELECT sid FROM enrolled WHERE cid = '15-445');

SELECT name FROM student
 WHERE sid = ANY (SELECT sid FROM enrolled WHERE cid = '15-445');

SELECT name FROM student AS s
 WHERE EXISTS (SELECT 1 FROM enrolled AS e
                WHERE e.sid = s.sid AND e.cid = '15-445');

-- ALL: nobody enrolled has a higher sid than this one.
SELECT sid, name FROM student
 WHERE sid >= ALL (SELECT sid FROM enrolled);

-- NOT EXISTS with a correlated inner query (slide 34):
-- "courses that have no students enrolled in them" -> 15-799.
SELECT * FROM course
 WHERE NOT EXISTS (SELECT 1 FROM enrolled
                    WHERE enrolled.cid = course.cid);

-- 8d. The SQL-92 trap (slide 32).
--     "Find the student record with the highest id that is enrolled in at
--     least one course." The tempting version mixes MAX() with a bare column:
--
--         SELECT MAX(e.sid), s.name FROM enrolled AS e, student AS s
--          WHERE e.sid = s.sid;
--
--     DuckDB REJECTS it:
--       Binder Error: column "name" must appear in the GROUP BY clause or must
--       be part of an aggregate function. Either add it to the GROUP BY list,
--       or use "ANY_VALUE(name)" if the exact value is not important.
--     Uncomment to see the error:
-- SELECT MAX(e.sid), s.name FROM enrolled AS e, student AS s WHERE e.sid = s.sid;

--     The correct form: a scalar subquery (slide 33's "is the").
SELECT sid, name FROM student
 WHERE sid = (SELECT MAX(sid) FROM enrolled);

-- 8e. LATERAL joins (slides 35-36).
--     A normal subquery in FROM cannot see the other entries in the same FROM.
--     LATERAL lifts that restriction: the subquery may reference tables listed
--     BEFORE it, so it runs once per outer row - a for-loop over the table.
SELECT * FROM
    (SELECT 1 AS x) AS t1,
    LATERAL (SELECT t1.x + 1 AS y) AS t2;

--     "Number of students enrolled in each course and their average GPA,
--     sorted by enrollment count." One LATERAL block per computed value.
SELECT * FROM course AS c,
    LATERAL (SELECT COUNT(*) AS cnt
               FROM enrolled
              WHERE enrolled.cid = c.cid) AS t1,
    LATERAL (SELECT AVG(s.gpa) AS avg
               FROM student AS s
               JOIN enrolled AS e ON s.sid = e.sid
              WHERE e.cid = c.cid) AS t2
ORDER BY cnt DESC;
--     15-799 comes back with cnt = 0 and avg = NULL: the LATERAL subqueries
--     still run for it, and an aggregate over no rows is 0 for COUNT and NULL
--     for AVG. An inner join to enrolled would have dropped that course.

-- 9. Window functions
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

--      Duplicate names in the alias list are deduplicated rather than
--      rejected: DuckDB renames the second column to colXXX_1.
WITH cteName (colXXX, colXXX) AS (
    SELECT 1, 2
)
SELECT * FROM cteName;
--      (Postgres errors on an ambiguous reference, MySQL rejects the
--      definition, SQLite silently resolves to the first column.)

-- 11. Recursive CTE
WITH RECURSIVE counter(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM counter WHERE n < 10
)
SELECT * FROM counter;

-- 12. DuckDB specialities (analytics / OLAP flavour)

-- Column-profile of a whole table in one command
SUMMARIZE student;

-- Friendly SELECT extensions
SELECT * EXCLUDE (login) FROM student ORDER BY sid;
SELECT * REPLACE (gpa * 25 AS gpa) FROM student ORDER BY sid;

-- GROUP BY ALL / ORDER BY ALL - no need to repeat the column list
SELECT cid, grade, COUNT(*) AS n FROM enrolled GROUP BY ALL ORDER BY ALL;

-- List / struct types
SELECT cid, list(sid ORDER BY sid) AS students FROM enrolled GROUP BY cid;

-- Query files directly, no load step: write Parquet + CSV, then read them back
COPY (SELECT s.name, e.cid, e.grade
      FROM student s JOIN enrolled e ON e.sid = s.sid)
     TO '/data/roster.parquet' (FORMAT PARQUET);
COPY student TO '/data/student.csv' (HEADER, DELIMITER ',');

SELECT * FROM '/data/roster.parquet';
SELECT * FROM read_csv('/data/student.csv');
DESCRIBE SELECT * FROM '/data/roster.parquet';

EXPLAIN ANALYZE SELECT cid, COUNT(*) FROM enrolled GROUP BY cid;
