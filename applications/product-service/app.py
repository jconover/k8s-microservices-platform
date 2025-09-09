import os
import json
import logging
from datetime import datetime
from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import psycopg2
from psycopg2.extras import RealDictCursor
import redis
from prometheus_client import Counter, Histogram, generate_latest
import time

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Rate limiting
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

# Prometheus metrics
request_count = Counter('product_service_requests_total', 
                       'Total requests', ['method', 'endpoint', 'status'])
request_duration = Histogram('product_service_request_duration_seconds',
                            'Request duration', ['method', 'endpoint'])

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'postgresql.database'),
    'port': os.getenv('DB_PORT', 5432),
    'database': os.getenv('DB_NAME', 'microservices'),
    'user': os.getenv('DB_USER', 'admin'),
    'password': os.getenv('DB_PASSWORD', 'SuperSecurePassword123!')
}

# Redis configuration
redis_client = redis.Redis(
    host=os.getenv('REDIS_HOST', 'redis.database'),
    port=int(os.getenv('REDIS_PORT', 6379)),
    decode_responses=True
)

def get_db_connection():
    """Create database connection"""
    return psycopg2.connect(**DB_CONFIG, cursor_factory=RealDictCursor)

def init_database():
    """Initialize database tables"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS products (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                price DECIMAL(10, 2) NOT NULL,
                stock_quantity INTEGER DEFAULT 0,
                category VARCHAR(100),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        conn.commit()
        cur.close()
        conn.close()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")

@app.before_request
def before_request():
    """Track request start time"""
    request.start_time = time.time()

@app.after_request
def after_request(response):
    """Track request metrics"""
    if hasattr(request, 'start_time'):
        duration = time.time() - request.start_time
        request_duration.labels(
            method=request.method,
            endpoint=request.endpoint or 'unknown'
        ).observe(duration)
    
    request_count.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status=response.status_code
    ).inc()
    
    return response

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        # Check database connection
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT 1')
        cur.close()
        conn.close()
        
        # Check Redis connection
        redis_client.ping()
        
        return jsonify({
            'status': 'healthy',
            'service': 'product-service',
            'timestamp': datetime.utcnow().isoformat()
        })
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 503

@app.route('/ready')
def ready():
    """Readiness check endpoint"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT 1')
        cur.close()
        conn.close()
        return jsonify({'status': 'ready'})
    except Exception as e:
        return jsonify({'status': 'not ready', 'error': str(e)}), 503

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

@app.route('/api/products', methods=['GET'])
@limiter.limit("100 per minute")
def get_products():
    """Get all products"""
    try:
        # Try cache first
        cached = redis_client.get('products:all')
        if cached:
            return json.loads(cached)
        
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT * FROM products 
            ORDER BY created_at DESC 
            LIMIT 100
        """)
        products = cur.fetchall()
        cur.close()
        conn.close()
        
        # Convert to regular dict for JSON serialization
        products_list = [dict(p) for p in products]
        for product in products_list:
            if product.get('created_at'):
                product['created_at'] = product['created_at'].isoformat()
            if product.get('updated_at'):
                product['updated_at'] = product['updated_at'].isoformat()
            if product.get('price'):
                product['price'] = float(product['price'])
        
        # Cache for 60 seconds
        redis_client.setex('products:all', 60, json.dumps(products_list))
        
        return jsonify(products_list)
    except Exception as e:
        logger.error(f"Error fetching products: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    """Get single product by ID"""
    try:
        # Try cache first
        cached = redis_client.get(f'product:{product_id}')
        if cached:
            return json.loads(cached)
        
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT * FROM products WHERE id = %s", (product_id,))
        product = cur.fetchone()
        cur.close()
        conn.close()
        
        if not product:
            return jsonify({'error': 'Product not found'}), 404
        
        # Convert to regular dict
        product_dict = dict(product)
        if product_dict.get('created_at'):
            product_dict['created_at'] = product_dict['created_at'].isoformat()
        if product_dict.get('updated_at'):
            product_dict['updated_at'] = product_dict['updated_at'].isoformat()
        if product_dict.get('price'):
            product_dict['price'] = float(product_dict['price'])
        
        # Cache for 5 minutes
        redis_client.setex(f'product:{product_id}', 300, json.dumps(product_dict))
        
        return jsonify(product_dict)
    except Exception as e:
        logger.error(f"Error fetching product: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/products', methods=['POST'])
@limiter.limit("10 per minute")
def create_product():
    """Create new product"""
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data.get('name') or not data.get('price'):
            return jsonify({'error': 'Name and price are required'}), 400
        
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO products (name, description, price, stock_quantity, category)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING *
        """, (
            data['name'],
            data.get('description'),
            data['price'],
            data.get('stock_quantity', 0),
            data.get('category')
        ))
        product = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        
        # Invalidate cache
        redis_client.delete('products:all')
        
        # Convert to regular dict
        product_dict = dict(product)
        if product_dict.get('created_at'):
            product_dict['created_at'] = product_dict['created_at'].isoformat()
        if product_dict.get('updated_at'):
            product_dict['updated_at'] = product_dict['updated_at'].isoformat()
        if product_dict.get('price'):
            product_dict['price'] = float(product_dict['price'])
        
        logger.info(f"Product created: {product_dict['name']}")
        return jsonify(product_dict), 201
    except Exception as e:
        logger.error(f"Error creating product: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/products/<int:product_id>', methods=['PUT'])
def update_product(product_id):
    """Update product"""
    try:
        data = request.get_json()
        
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            UPDATE products
            SET name = COALESCE(%s, name),
                description = COALESCE(%s, description),
                price = COALESCE(%s, price),
                stock_quantity = COALESCE(%s, stock_quantity),
                category = COALESCE(%s, category),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
            RETURNING *
        """, (
            data.get('name'),
            data.get('description'),
            data.get('price'),
            data.get('stock_quantity'),
            data.get('category'),
            product_id
        ))
        product = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        
        if not product:
            return jsonify({'error': 'Product not found'}), 404
        
        # Invalidate cache
        redis_client.delete(f'product:{product_id}')
        redis_client.delete('products:all')
        
        # Convert to regular dict
        product_dict = dict(product)
        if product_dict.get('created_at'):
            product_dict['created_at'] = product_dict['created_at'].isoformat()
        if product_dict.get('updated_at'):
            product_dict['updated_at'] = product_dict['updated_at'].isoformat()
        if product_dict.get('price'):
            product_dict['price'] = float(product_dict['price'])
        
        return jsonify(product_dict)
    except Exception as e:
        logger.error(f"Error updating product: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/products/<int:product_id>', methods=['DELETE'])
def delete_product(product_id):
    """Delete product"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("DELETE FROM products WHERE id = %s RETURNING *", (product_id,))
        product = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        
        if not product:
            return jsonify({'error': 'Product not found'}), 404
        
        # Invalidate cache
        redis_client.delete(f'product:{product_id}')
        redis_client.delete('products:all')
        
        return jsonify({'message': 'Product deleted successfully'})
    except Exception as e:
        logger.error(f"Error deleting product: {e}")
        return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    init_database()
    app.run(host='0.0.0.0', port=5000, debug=False)