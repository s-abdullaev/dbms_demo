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

-- 6b. Days since the beginning of the year.
--     EXTRACT(DOY ...) is the 1-based day NUMBER; subtracting Jan 1 gives the
--     number of days ELAPSED, which is always one less.
SELECT CURRENT_DATE                                            AS today,
       DATE_TRUNC('year', CURRENT_DATE)::date                  AS jan_1,
       EXTRACT(DOY FROM CURRENT_DATE)::int                     AS day_of_year,
       CURRENT_DATE - DATE_TRUNC('year', CURRENT_DATE)::date   AS days_elapsed;

-- 7. ORDER BY + LIMIT: top 2 by GPA
SELECT name, gpa FROM student ORDER BY gpa DESC, name ASC LIMIT 2;

-- 7b. ORDER BY details (slide 21).
--     A sort key can be a column POSITION in the SELECT list: "2" means grade.
SELECT sid, grade FROM enrolled
 WHERE cid = '15-721'
 ORDER BY 2;

--     Several keys, each with its own direction. Ties on the first key are
--     broken by the second.
SELECT sid, grade FROM enrolled
 WHERE cid = '15-445'
 ORDER BY grade DESC, sid ASC;

-- 7c. OFFSET / FETCH (slide 22) - the SQL-standard way to page through output.
--     Postgres supports the standard spelling in full, including WITH TIES.
SELECT sid, name FROM student
 WHERE login LIKE '%@cs'
 FETCH FIRST 2 ROWS ONLY;

--     Skip the first row, then take two - "rows 2 and 3".
SELECT sid, name FROM student
 ORDER BY gpa DESC
 OFFSET 1 ROWS
 FETCH NEXT 2 ROWS ONLY;

--     WITH TIES keeps every row that ties with the last one, so this can return
--     MORE than 2 rows. Requires an ORDER BY; Postgres 13+.
SELECT sid, grade FROM enrolled
 ORDER BY grade
 OFFSET 1 ROWS
 FETCH NEXT 2 ROWS WITH TIES;

--     LIMIT/OFFSET is the older Postgres spelling of the same thing.
SELECT sid, name FROM student ORDER BY gpa DESC LIMIT 2 OFFSET 1;

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

-- 9b. ROW_NUMBER() / RANK() / DENSE_RANK() (slides 23-24).
--     An empty OVER () treats the whole result as ONE window and numbers every
--     row. With no ORDER BY inside OVER, the numbering follows whatever order
--     the engine produces - fine for a row counter, not for ranking.
SELECT sid, cid, grade, ROW_NUMBER() OVER () AS row_num
FROM enrolled;

--     The three functions differ only in how they treat TIES:
--       ROW_NUMBER  - always distinct: 1,2,3,4,5,6
--       RANK        - ties share a number, then it SKIPS: 1,1,3,3,5,5
--       DENSE_RANK  - ties share a number, no gaps:      1,1,2,2,3,3
SELECT sid, grade,
       ROW_NUMBER() OVER (ORDER BY grade, sid) AS rn,
       RANK()       OVER (ORDER BY grade)      AS rnk,
       DENSE_RANK() OVER (ORDER BY grade)      AS drnk
FROM enrolled
ORDER BY 3;

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
