-- Example database from lecture (CMU 15-445 / Modern SQL)
-- MySQL dialect

DROP TABLE IF EXISTS enrolled;
DROP TABLE IF EXISTS course;
DROP TABLE IF EXISTS student;

CREATE TABLE student (
    sid   INT PRIMARY KEY,
    name  VARCHAR(16),
    login VARCHAR(32) UNIQUE,
    age   SMALLINT,
    gpa   FLOAT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE course (
    cid  VARCHAR(32) PRIMARY KEY,
    name VARCHAR(32) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- NOTE: InnoDB parses but SILENTLY IGNORES inline column-level REFERENCES.
-- Table-level FOREIGN KEY clauses are required for the constraint to exist.
CREATE TABLE enrolled (
    sid   INT,
    cid   VARCHAR(32),
    grade CHAR(1),
    FOREIGN KEY (sid) REFERENCES student (sid),
    FOREIGN KEY (cid) REFERENCES course (cid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
