require('dotenv').config();

const express = require('express');
const mysql = require('mysql2/promise');

const app = express();
const PORT = Number(process.env.PORT || 3000);

app.use(express.json());

const db = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 5
});

// Health Check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'success',
    message: 'AWS 3-Tier Backend API is running',
    server: 'Private EC2'
  });
});

// Get Students from AWS RDS
app.get('/api/students', async (req, res) => {
  try {
    const [students] = await db.query(
      'SELECT id, name, course FROM students ORDER BY id'
    );

    res.json({
      success: true,
      count: students.length,
      data: students
    });
  } catch (error) {
    console.error('Database query failed:', error.code);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve students'
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend API running on port ${PORT}`);
});
