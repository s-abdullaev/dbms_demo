-- ============================================================
-- PostgreSQL examples  (run: \i /examples/postgres.sql)
-- ============================================================

-- 1. Sanity check: what is in the database?
\dt
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

-- 4. GROUP BY + HAVING: courses with more than one student
SELECT e.cid, c.name, COUNT(*) AS enrollment
FROM enrolled AS e JOIN course AS c ON c.cid = e.cid
GROUP BY e.cid, c.name
HAVING COUNT(*) > 1
ORDER BY enrollment DESC;

-- 5. String operations ('||' is the SQL-standard concat operator)
SELECT UPPER(name) || ' <' || login || '>' AS contact
FROM student
WHERE login LIKE '%@cs';

-- 6. Date / time
SELECT CURRENT_DATE                                AS today,
       NOW()                                       AS now_ts,
       EXTRACT(YEAR FROM NOW())                    AS yr,
       NOW() - INTERVAL '7 days'                   AS a_week_ago;

-- 7. ORDER BY + LIMIT: top 2 by GPA
SELECT name, gpa FROM student ORDER BY gpa DESC, name ASC LIMIT 2;

-- 8. Nested queries: students enrolled in at least one course
SELECT name FROM student
WHERE sid IN (SELECT sid FROM enrolled)
ORDER BY name;

-- ... and the one with the highest GPA, via ALL
SELECT name, gpa FROM student
WHERE gpa >= ALL (SELECT gpa FROM student);

-- 9. Window functions: rank students by GPA inside each course
SELECT e.cid, s.name, s.gpa,
       RANK() OVER (PARTITION BY e.cid ORDER BY s.gpa DESC) AS gpa_rank
FROM enrolled AS e JOIN student AS s ON s.sid = e.sid
ORDER BY e.cid, gpa_rank;

-- 10. Common Table Expression
WITH course_load AS (
    SELECT sid, COUNT(*) AS n FROM enrolled GROUP BY sid
)
SELECT s.name, cl.n AS courses
FROM student AS s JOIN course_load AS cl ON cl.sid = s.sid
ORDER BY cl.n DESC, s.name;

-- 11. Recursive CTE: print 1..10
WITH RECURSIVE counter(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM counter WHERE n < 10
)
SELECT * FROM counter;

-- 12. Postgres specialities
SELECT generate_series(1, 5) AS gs;                       -- set-returning function
SELECT json_agg(row_to_json(s)) FROM student AS s;        -- JSON aggregation
EXPLAIN ANALYZE SELECT * FROM enrolled WHERE cid = '15-445';

-- 13. Constraints are real: this must FAIL (no student 99999)
--     Uncomment to see the foreign key error.
-- INSERT INTO enrolled (sid, cid, grade) VALUES (99999, '15-445', 'A');
