-- Example database from lecture (CMU 15-445 / Modern SQL)
-- PostgreSQL dialect

DROP TABLE IF EXISTS enrolled;
DROP TABLE IF EXISTS course;
DROP TABLE IF EXISTS student;

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
