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

-- 7c. Paging (slide 22).
--     MySQL has NO FETCH FIRST / OFFSET ... ROWS syntax - it is a syntax error.
--     Use LIMIT count OFFSET skip instead.
SELECT sid, name FROM student
 WHERE login LIKE '%@cs'
 LIMIT 2;

--     Skip the first row, then take two - "rows 2 and 3".
SELECT sid, name FROM student
 ORDER BY gpa DESC
 LIMIT 2 OFFSET 1;

--     There is no WITH TIES either. Emulate it with RANK(), which gives tied
--     rows the same number, then filter. Works on all four engines.
SELECT sid, grade FROM (
    SELECT sid, grade, RANK() OVER (ORDER BY grade) AS rnk
    FROM enrolled
) AS t
 WHERE rnk <= 3
 ORDER BY grade, sid;

-- 8. Nested queries
SELECT name FROM student
WHERE sid IN (SELECT sid FROM enrolled)
ORDER BY name;

SELECT name, gpa FROM student
WHERE gpa >= ALL (SELECT gpa FROM student);

-- 9. Window functions (MySQL 8.0+)
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

-- 10. CTE (MySQL 8.0+)
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

-- 12. MySQL specialities
SHOW CREATE TABLE enrolled\G
SELECT CONSTRAINT_NAME, TABLE_NAME, REFERENCED_TABLE_NAME
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'university';
EXPLAIN ANALYZE SELECT * FROM enrolled WHERE cid = '15-445';

-- 13. Foreign key really is enforced (table-level FOREIGN KEY clause).
--     Uncomment to see error 1452.
-- INSERT INTO enrolled (sid, cid, grade) VALUES (99999, '15-445', 'A');
