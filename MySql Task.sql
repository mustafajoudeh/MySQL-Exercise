
/* =========================================================
   1. BASIC QUERIES
   ========================================================= */

-- Display all students.
SELECT *
FROM Students;

-- Count the total number of courses.
SELECT COUNT(*) AS total_courses
FROM Courses;


/* =========================================================
   2. FILTERING AND INNER JOIN
   ========================================================= */

-- Find students enrolled in Database Systems.
SELECT
    s.first_name,
    s.last_name
FROM Students AS s
INNER JOIN Enrollments AS e
    ON s.student_id = e.student_id
INNER JOIN Courses AS c
    ON e.course_id = c.course_id
WHERE c.course_name = 'Database Systems';


-- Find instructors in the Computer Science department.
SELECT
    email
FROM Instructors
WHERE department = 'Computer Science';


-- Find students who received grades greater than 90.
SELECT
    s.first_name,
    c.course_name,
    e.grade
FROM Enrollments AS e
INNER JOIN Students AS s
    ON e.student_id = s.student_id
INNER JOIN Courses AS c
    ON e.course_id = c.course_id
WHERE e.grade > 90;


/* =========================================================
   3. COURSE ASSIGNMENTS
   ========================================================= */

-- Display courses and their instructors in Fall 2026.
SELECT
    c.course_name,
    c.course_code,
    i.first_name,
    i.last_name,
    ca.semester,
    ca.year
FROM CourseAssignments AS ca
INNER JOIN Courses AS c
    ON ca.course_id = c.course_id
INNER JOIN Instructors AS i
    ON ca.instructor_id = i.instructor_id
WHERE ca.semester = 'Fall'
  AND ca.year = 2026;


/* =========================================================
   4. AGGREGATE FUNCTIONS
   ========================================================= */

-- Calculate the average grade for course CS301.
SELECT
    c.course_name,
    ROUND(AVG(e.grade), 2) AS average_grade
FROM Courses AS c
INNER JOIN Enrollments AS e
    ON c.course_id = e.course_id
WHERE c.course_code = 'CS301'
GROUP BY
    c.course_id,
    c.course_name;


-- Calculate the average grade for each course department.
-- COUNT(e.grade) counts only enrollments that have a grade.
SELECT
    c.department,
    COUNT(e.enrollment_id) AS total_enrollments,
    COUNT(e.grade) AS graded_enrollments,
    ROUND(AVG(e.grade), 2) AS average_grade,
    MIN(e.grade) AS lowest_grade,
    MAX(e.grade) AS highest_grade
FROM Courses AS c
LEFT JOIN Enrollments AS e
    ON c.course_id = e.course_id
GROUP BY c.department
ORDER BY average_grade DESC;


-- Find the student with the highest average grade.
SELECT
    s.student_id,
    s.first_name,
    s.last_name,
    ROUND(AVG(e.grade), 2) AS average_grade
FROM Students AS s
INNER JOIN Enrollments AS e
    ON s.student_id = e.student_id
GROUP BY
    s.student_id,
    s.first_name,
    s.last_name
HAVING COUNT(e.grade) > 0
ORDER BY average_grade DESC
LIMIT 1;


-- Count distinct courses assigned to instructors in each department
-- during 2026, then return the department with the highest count.
SELECT
    i.department,
    COUNT(DISTINCT ca.course_id) AS total_courses
FROM CourseAssignments AS ca
INNER JOIN Instructors AS i
    ON ca.instructor_id = i.instructor_id
WHERE ca.year = 2026
GROUP BY i.department
ORDER BY total_courses DESC
LIMIT 1;


/* =========================================================
   5. GROUP BY AND HAVING
   ========================================================= */

-- Find students enrolled in more than three distinct courses
-- that have a Fall 2026 assignment.
SELECT
    s.student_id,
    s.first_name,
    s.last_name,
    COUNT(DISTINCT e.course_id) AS total_courses
FROM Students AS s
INNER JOIN Enrollments AS e
    ON s.student_id = e.student_id
INNER JOIN CourseAssignments AS ca
    ON e.course_id = ca.course_id
WHERE ca.semester = 'Fall'
  AND ca.year = 2026
GROUP BY
    s.student_id,
    s.first_name,
    s.last_name
HAVING COUNT(DISTINCT e.course_id) > 3;


/* =========================================================
   6. NULL VALUES AND LEFT JOIN
   ========================================================= */

-- Find enrolled students whose grades have not been assigned yet.
SELECT
    s.student_id,
    s.first_name,
    s.last_name,
    c.course_name,
    e.grade
FROM Students AS s
INNER JOIN Enrollments AS e
    ON s.student_id = e.student_id
INNER JOIN Courses AS c
    ON e.course_id = c.course_id
WHERE e.grade IS NULL;


-- Find courses with no student enrollments.
SELECT
    c.course_id,
    c.course_name,
    c.course_code
FROM Courses AS c
LEFT JOIN Enrollments AS e
    ON c.course_id = e.course_id
WHERE e.enrollment_id IS NULL;


-- Display all instructors and their assigned courses, if any.
-- Instructors without course assignments will still appear.
SELECT
    i.instructor_id,
    i.first_name,
    i.last_name,
    c.course_name,
    ca.semester,
    ca.year
FROM Instructors AS i
LEFT JOIN CourseAssignments AS ca
    ON i.instructor_id = ca.instructor_id
LEFT JOIN Courses AS c
    ON ca.course_id = c.course_id;


/* =========================================================
   7. FUNCTION: CALCULATE AGE
   Create this function separately from ordinary queries.
   ========================================================= */

DROP FUNCTION IF EXISTS CalculateAge;

DELIMITER //

CREATE FUNCTION CalculateAge(
    birth_date DATE
)
RETURNS INT
DETERMINISTIC
NO SQL
RETURN TIMESTAMPDIFF(YEAR, birth_date, CURDATE())//

DELIMITER ;


-- Use the function to calculate each student's age.
SELECT
    first_name,
    last_name,
    date_of_birth,
    CalculateAge(date_of_birth) AS age
FROM Students;


/* =========================================================
   8. STORED PROCEDURE: ENROLL A STUDENT
   This procedure inserts an enrollment without a grade.
   ========================================================= */

DROP PROCEDURE IF EXISTS EnrollStudent;

DELIMITER //

CREATE PROCEDURE EnrollStudent(
    IN p_student_id INT,
    IN p_course_id INT
)
BEGIN
    INSERT INTO Enrollments
        (student_id, course_id, grade)
    VALUES
        (p_student_id, p_course_id, NULL);
END //

DELIMITER ;


-- Run this call only when you intentionally want to enroll
-- student 1 in course 3.
-- Do not repeat it if that enrollment already exists.
-- CALL EnrollStudent(1, 3);


/* =========================================================
   9. DATA INTEGRITY: UNIQUE STUDENT EMAILS
   ========================================================= */

-- Inspect existing indexes before adding a UNIQUE constraint.
SHOW INDEX FROM Students;

-- Run only if email is not already UNIQUE and there are no duplicates.
-- ALTER TABLE Students
-- ADD CONSTRAINT uq_students_email UNIQUE (email);


/* =========================================================
   10. COURSE CAPACITY
   Add the capacity column only if it does not already exist.
   ========================================================= */

-- ALTER TABLE Courses
-- ADD COLUMN capacity INT UNSIGNED NOT NULL DEFAULT 30;


/* =========================================================
   11. PROCEDURE WITH TRANSACTION AND CAPACITY CHECK
   Requires the Courses.capacity column above.
   ========================================================= */

DROP PROCEDURE IF EXISTS EnrollStudentWithCapacity;

DELIMITER //

CREATE PROCEDURE EnrollStudentWithCapacity(
    IN p_student_id INT,
    IN p_course_id INT
)
BEGIN
    DECLARE v_capacity INT DEFAULT NULL;
    DECLARE v_enrolled INT DEFAULT 0;

    -- Roll back the transaction if any SQL error occurs.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Lock the selected course row while checking its capacity.
    SELECT capacity
    INTO v_capacity
    FROM Courses
    WHERE course_id = p_course_id
    FOR UPDATE;

    -- Reject the request if the course does not exist.
    IF v_capacity IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Course not found';
    END IF;

    -- Count current enrollments in the selected course.
    SELECT COUNT(*)
    INTO v_enrolled
    FROM Enrollments
    WHERE course_id = p_course_id;

    -- Do not enroll another student if the course is full.
    IF v_enrolled >= v_capacity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Course capacity exceeded';
    END IF;

    -- Insert the enrollment only when capacity is available.
    INSERT INTO Enrollments
        (student_id, course_id, grade)
    VALUES
        (p_student_id, p_course_id, NULL);

    COMMIT;
END //

DELIMITER ;


-- Call only when you want to perform a capacity-checked enrollment.
-- CALL EnrollStudentWithCapacity(1, 3);


/* =========================================================
   12. INDEXING
   ========================================================= */

-- Inspect existing indexes on the Courses table.
SHOW INDEX FROM Courses;

-- course_code may already have an index if it is UNIQUE.
-- Add a separate index only if one does not already serve this purpose.
-- CREATE INDEX idx_courses_course_code
-- ON Courses (course_code);


/* =========================================================
   13. EXPLAIN: QUERY EXECUTION PLAN
   ========================================================= */

-- Examine how MariaDB retrieves students enrolled in course 1.
EXPLAIN
SELECT
    s.student_id,
    s.first_name,
    s.last_name,
    s.email
FROM Enrollments AS e
INNER JOIN Students AS s
    ON e.student_id = s.student_id
WHERE e.course_id = 1;


/* =========================================================
   14. UNION ALL
   Combine student and instructor names into one result set.
   ========================================================= */

SELECT
    'Student' AS person_type,
    student_id AS person_id,
    first_name,
    last_name,
    email
FROM Students

UNION ALL

SELECT
    'Instructor' AS person_type,
    instructor_id AS person_id,
    first_name,
    last_name,
    email
FROM Instructors;


/* =========================================================
   15. FINAL STUDENT REPORT
   Includes student details, courses, instructors, grades,
   credits, and total enrolled credits per student.
   ========================================================= */

SELECT
    s.student_id,
    CONCAT(s.first_name, ' ', s.last_name) AS student_name,
    s.email,
    s.major,
    c.course_name,
    c.course_code,
    CONCAT(i.first_name, ' ', i.last_name) AS instructor_name,
    ca.semester,
    ca.year,
    e.grade,
    c.credits,

    -- Calculate the student's total credits independently
    -- to avoid inflating the sum when a course has assignments
    -- for multiple instructors or semesters.
    (
        SELECT COALESCE(SUM(c2.credits), 0)
        FROM Enrollments AS e2
        INNER JOIN Courses AS c2
            ON e2.course_id = c2.course_id
        WHERE e2.student_id = s.student_id
    ) AS total_credits

FROM Students AS s
LEFT JOIN Enrollments AS e
    ON s.student_id = e.student_id
LEFT JOIN Courses AS c
    ON e.course_id = c.course_id
LEFT JOIN CourseAssignments AS ca
    ON c.course_id = ca.course_id
LEFT JOIN Instructors AS i
    ON ca.instructor_id = i.instructor_id
ORDER BY
    s.student_id,
    c.course_name;
