import os
import json
import logging
import threading
from flask import Flask, jsonify
import pika
import redis
from prometheus_client import Counter, generate_latest

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Metrics
notifications_sent = Counter('notifications_sent_total', 'Total notifications sent', ['type'])

# Redis configuration
redis_client = redis.Redis(
    host=os.getenv('REDIS_HOST', 'redis.database'),
    port=int(os.getenv('REDIS_PORT', 6379)),
    decode_responses=True
)

# RabbitMQ configuration
RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'rabbitmq.database')
RABBITMQ_USER = os.getenv('RABBITMQ_USER', 'admin')
RABBITMQ_PASS = os.getenv('RABBITMQ_PASS', 'admin123')

def process_notification(ch, method, properties, body):
    """Process incoming notifications from RabbitMQ"""
    try:
        message = json.loads(body)
        logger.info(f"Processing notification: {message}")
        
        # Simulate sending notification
        notification_type = message.get('type', 'email')
        notifications_sent.labels(type=notification_type).inc()
        
        # Store in Redis for tracking
        redis_client.lpush('notifications:sent', json.dumps(message))
        redis_client.ltrim('notifications:sent', 0, 999)  # Keep last 1000
        
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        logger.error(f"Error processing notification: {e}")
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

def consume_messages():
    """Connect to RabbitMQ and consume messages"""
    try:
        credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASS)
        connection = pika.BlockingConnection(
            pika.ConnectionParameters(host=RABBITMQ_HOST, credentials=credentials)
        )
        channel = connection.channel()
        
        # Declare queue
        channel.queue_declare(queue='notifications', durable=True)
        
        # Set up consumer
        channel.basic_qos(prefetch_count=1)
        channel.basic_consume(queue='notifications', on_message_callback=process_notification)
        
        logger.info("Started consuming messages from RabbitMQ")
        channel.start_consuming()
    except Exception as e:
        logger.error(f"Error connecting to RabbitMQ: {e}")

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'notification-service'
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

@app.route('/api/notifications/recent')
def recent_notifications():
    """Get recent notifications"""
    try:
        notifications = redis_client.lrange('notifications:sent', 0, 99)
        return jsonify([json.loads(n) for n in notifications])
    except Exception as e:
        logger.error(f"Error fetching notifications: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Start RabbitMQ consumer in background thread
    consumer_thread = threading.Thread(target=consume_messages)
    consumer_thread.daemon = True
    consumer_thread.start()
    
    # Start Flask app
    app.run(host='0.0.0.0', port=5001, debug=False)