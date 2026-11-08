CREATE DATABASE IF NOT EXISTS todo_db;
USE todo_db;

CREATE TABLE IF NOT EXISTS tasks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  completed TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO tasks (title, completed) VALUES
  ('Set up MySQL database', 1),
  ('Deploy Node.js API', 0),
  ('Configure Nginx reverse proxy', 0),
  ('Test CRUD from the browser', 0);