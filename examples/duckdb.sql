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
