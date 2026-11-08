const express = require('express');
const mysql = require('mysql2/promise');

const app = express();
app.use(express.json());

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'todo_user',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'todo_db',
  waitForConnections: true,
  connectionLimit: 10,
});

const wrap = fn => (req, res) =>
  fn(req, res).catch(err => {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  });

// READ all
app.get('/api/tasks', wrap(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM tasks ORDER BY id');
  res.json(rows);
}));

// READ one
app.get('/api/tasks/:id', wrap(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM tasks WHERE id = ?', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Not found' });
  res.json(rows[0]);
}));

// CREATE
app.post('/api/tasks', wrap(async (req, res) => {
  const { title } = req.body;
  if (!title) return res.status(400).json({ error: 'title is required' });
  const [result] = await pool.query('INSERT INTO tasks (title) VALUES (?)', [title]);
  res.status(201).json({ id: result.insertId, title, completed: 0 });
}));

// UPDATE
app.put('/api/tasks/:id', wrap(async (req, res) => {
  const { title, completed } = req.body;
  const [result] = await pool.query(
    'UPDATE tasks SET title = COALESCE(?, title), completed = COALESCE(?, completed) WHERE id = ?',
    [title ?? null, completed ?? null, req.params.id]
  );
  if (!result.affectedRows) return res.status(404).json({ error: 'Not found' });
  res.json({ updated: true });
}));

// DELETE
app.delete('/api/tasks/:id', wrap(async (req, res) => {
  const [result] = await pool.query('DELETE FROM tasks WHERE id = ?', [req.params.id]);
  if (!result.affectedRows) return res.status(404).json({ error: 'Not found' });
  res.status(204).end();
}));

const port = process.env.PORT || 3000;
app.listen(port, '0.0.0.0', () => console.log(`API listening on :${port}`));
