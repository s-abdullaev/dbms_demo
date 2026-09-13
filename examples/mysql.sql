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
