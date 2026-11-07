CREATE DATABASE IF NOT EXISTS jlweek2;
USE jlweek2;
CREATE TABLE IF NOT EXISTS counter (
    id TINYINT PRIMARY KEY,
    visits BIGINT UNSIGNED NOT NULL
) ENGINE=InnoDB;
INSERT IGNORE INTO counter (id, visits) VALUES (1, 0);
CREATE USER IF NOT EXISTS 'jlweek2'@'localhost' IDENTIFIED VIA unix_socket;
GRANT SELECT, UPDATE ON jlweek2.counter TO 'jlweek2'@'localhost';
