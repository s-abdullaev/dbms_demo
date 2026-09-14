-- ============================================================
-- MySQL examples  (run: SOURCE /examples/mysql.sql;)
-- ============================================================

-- 1. Sanity check
SHOW TABLES;
DESCRIBE student;
SELECT * FROM student ORDER BY sid;
SELECT * FROM course ORDER BY cid;
SELECT * FROM enrolled ORDER BY sid, cid;

-- 2. Join: who is enrolled in 15-445?
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

-- 5. Strings. NOTE: in MySQL '||' means OR by default, so use CONCAT().
SELECT CONCAT(UPPER(name), ' <', login, '>') AS contact
FROM student
WHERE login LIKE '%@cs';

-- GROUP_CONCAT is a MySQL speciality
SELECT e.cid, GROUP_CONCAT(s.name ORDER BY s.name SEPARATOR ', ') AS roster
FROM enrolled AS e JOIN student AS s ON s.sid = e.sid
GROUP BY e.cid;

-- 6. Date / time
SELECT CURDATE()                          AS today,
       NOW()                              AS now_ts,
       YEAR(NOW())                        AS yr,
       DATE_SUB(NOW(), INTERVAL 7 DAY)    AS a_week_ago;

-- 6b. Days since the beginning of the year.
--     DAYOFYEAR() is the 1-based day NUMBER; DATEDIFF() from Jan 1 gives the
--     number of days ELAPSED, which is always one less.
--     MAKEDATE(year, 1) is MySQL's way of spelling "January 1st of that year".
SELECT CURDATE()                                           AS today,
       MAKEDATE(YEAR(CURDATE()), 1)                        AS jan_1,
       DAYOFYEAR(CURDATE())                                AS day_of_year,
       DATEDIFF(CURDATE(), MAKEDATE(YEAR(CURDATE()), 1))   AS days_elapsed;

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
--     MySQL 8 REJECTS it under the default sql_mode:
--       ERROR 1140 (42000): In aggregated query without GROUP BY, expression
--       #2 of SELECT list contains nonaggregated column 'university.s.name';
--       this is incompatible with sql_mode=only_full_group_by
--     Dropping ONLY_FULL_GROUP_BY from sql_mode makes it "work" and return an
--     arbitrary name - which is exactly why that mode is on by default.
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

-- 9. Window functions (MySQL 8.0+)
SELECT e.cid, s.name, s.gpa,
       RANK() OVER (PARTITION BY e.cid ORDER BY s.gpa DESC) AS gpa_rank
FROM enrolled AS e JOIN student AS s ON s.sid = e.sid
ORDER BY e.cid, gpa_rank;

-- 10. CTE (MySQL 8.0+)
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

--      MySQL is the strictest of the four about duplicate names in the alias
--      list - it rejects the DEFINITION, before anything references it:
--        ERROR 1060 (42S21): Duplicate column name 'colXXX'
--      (Postgres accepts the definition and errors on the reference, SQLite
--      silently resolves to the first column, DuckDB renames to colXXX_1.)
-- WITH cteName (colXXX, colXXX) AS (SELECT 1, 2) SELECT * FROM cteName;

-- 11. Recursive CTE: print 1..10
WITH RECURSIVE counter(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM counter WHERE n < 10
)
SELECT * FROM counter;

-- 12. MySQL specialities
SHOW CREATE TABLE enrolled\G
SELECT CONSTRAINT_NAME, TABLE_NAME, REFERENCED_TABLE_NAME
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'university';
EXPLAIN ANALYZE SELECT * FROM enrolled WHERE cid = '15-445';

-- 13. Foreign key really is enforced (table-level FOREIGN KEY clause).
--     Uncomment to see error 1452.
-- INSERT INTO enrolled (sid, cid, grade) VALUES (99999, '15-445', 'A');
