const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');
const prometheus = require('prom-client');
const winston = require('winston');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api/', limiter);

// Logging
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Prometheus metrics
const register = new prometheus.Registry();
prometheus.collectDefaultMetrics({ register });

const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});
register.registerMetric(httpRequestDuration);

// Database connection
const pgPool = new Pool({
  host: process.env.DB_HOST || 'postgresql.database',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'microservices',
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASSWORD || 'SuperSecurePassword123!',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Redis connection
const redisClient = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST || 'redis.database',
    port: process.env.REDIS_PORT || 6379
  }
});

redisClient.on('error', err => logger.error('Redis Client Error', err));
redisClient.connect().catch(console.error);

// Middleware to track request duration
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .observe(duration);
  });
  next();
});

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    await pgPool.query('SELECT 1');
    await redisClient.ping();
    res.json({ 
      status: 'healthy',
      service: 'user-service',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(503).json({ 
      status: 'unhealthy',
      error: error.message 
    });
  }
});

// Ready check endpoint
app.get('/ready', async (req, res) => {
  try {
    await pgPool.query('SELECT 1');
    res.json({ status: 'ready' });
  } catch (error) {
    res.status(503).json({ status: 'not ready' });
  }
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  const metrics = await register.metrics();
  res.end(metrics);
});

// Initialize database
async function initDatabase() {
  try {
    await pgPool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(100) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        full_name VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    logger.info('Database initialized');
  } catch (error) {
    logger.error('Database initialization failed:', error);
  }
}

// User endpoints
app.get('/api/users', async (req, res) => {
  try {
    // Try to get from cache first
    const cached = await redisClient.get('users:all');
    if (cached) {
      return res.json(JSON.parse(cached));
    }
    
    const result = await pgPool.query('SELECT * FROM users ORDER BY created_at DESC LIMIT 100');
    
    // Cache for 60 seconds
    await redisClient.setEx('users:all', 60, JSON.stringify(result.rows));
    
    res.json(result.rows);
  } catch (error) {
    logger.error('Error fetching users:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/api/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Try cache first
    const cached = await redisClient.get(`user:${id}`);
    if (cached) {
      return res.json(JSON.parse(cached));
    }
    
    const result = await pgPool.query('SELECT * FROM users WHERE id = $1', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Cache for 5 minutes
    await redisClient.setEx(`user:${id}`, 300, JSON.stringify(result.rows[0]));
    
    res.json(result.rows[0]);
  } catch (error) {
    logger.error('Error fetching user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/users', async (req, res) => {
  try {
    const { username, email, full_name } = req.body;
    
    if (!username || !email) {
      return res.status(400).json({ error: 'Username and email are required' });
    }
    
    const result = await pgPool.query(
      'INSERT INTO users (username, email, full_name) VALUES ($1, $2, $3) RETURNING *',
      [username, email, full_name]
    );
    
    // Invalidate cache
    await redisClient.del('users:all');
    
    logger.info(`User created: ${username}`);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    logger.error('Error creating user:', error);
    if (error.code === '23505') { // Unique violation
      return res.status(409).json({ error: 'Username or email already exists' });
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.put('/api/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { username, email, full_name } = req.body;
    
    const result = await pgPool.query(
      `UPDATE users 
       SET username = COALESCE($1, username),
           email = COALESCE($2, email),
           full_name = COALESCE($3, full_name),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $4
       RETURNING *`,
      [username, email, full_name, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Invalidate cache
    await redisClient.del(`user:${id}`);
    await redisClient.del('users:all');
    
    res.json(result.rows[0]);
  } catch (error) {
    logger.error('Error updating user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/api/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await pgPool.query('DELETE FROM users WHERE id = $1 RETURNING *', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Invalidate cache
    await redisClient.del(`user:${id}`);
    await redisClient.del('users:all');
    
    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    logger.error('Error deleting user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Start server
async function start() {
  await initDatabase();
  
  app.listen(PORT, () => {
    logger.info(`User service running on port ${PORT}`);
  });
}

start().catch(error => {
  logger.error('Failed to start service:', error);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  await pgPool.end();
  await redisClient.quit();
  process.exit(0);
});