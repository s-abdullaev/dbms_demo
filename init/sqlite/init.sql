-- SQLite dialect
PRAGMA foreign_keys = ON;


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

INSERT INTO student (sid, name, login, age, gpa) VALUES
    (53666, 'Kanye',  'kanye@cs',  44, 4.0),
    (53688, 'Bieber', 'jbieber@cs', 27, 3.9),
    (53655, 'Tupac',  'shakur@cs', 25, 3.5),
    (53633, 'Kardashian', 'kardashian@cs', 42, 3.7);

INSERT INTO course (cid, name) VALUES
    ('15-445', 'Database Systems'),
    ('15-721', 'Advanced Database Systems'),
    ('15-826', 'Data Mining'),
    ('15-799', 'Special Topics in Databases');

INSERT INTO enrolled (sid, cid, grade) VALUES
    (53666, '15-445', 'C'),
    (53688, '15-721', 'A'),
    (53688, '15-826', 'B'),
    (53655, '15-445', 'B'),
    (53666, '15-721', 'C'),
    (53633, '15-826', 'A');
