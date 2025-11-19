"""
Workshop API - A sample API for Azure SRE Agent Workshop
Demonstrates: PostgreSQL connectivity, REST endpoints, Application Insights integration
"""

import os
import logging
import time
import random
from typing import Optional, List
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from opencensus.ext.azure.log_exporter import AzureLogHandler

# Import chaos engineering module
from chaos import router as chaos_router, chaos_state, apply_chaos_middleware

# Configuration
PORT = int(os.getenv("PORT", "8000"))
DATABASE_URL = os.getenv("DATABASE_URL", "")
APPLICATIONINSIGHTS_CONNECTION_STRING = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING", "")
SLOW_MODE_DELAY = float(os.getenv("SLOW_MODE_DELAY", "0"))  # Seconds to delay each request (0 = disabled)

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Add Application Insights logging if connection string is provided
if APPLICATIONINSIGHTS_CONNECTION_STRING:
    logger.addHandler(AzureLogHandler(connection_string=APPLICATIONINSIGHTS_CONNECTION_STRING))
    logger.info("Application Insights logging enabled")

# Database connection pool
db_pool = None

def get_db_connection():
    """Get a database connection from the pool"""
    if not DATABASE_URL:
        raise HTTPException(status_code=500, detail="Database connection not configured")
    
    try:
        conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
        
        # Chaos: Connection leak simulation
        if chaos_state["connection_leak"]["enabled"] and random.randint(1, 100) <= chaos_state["connection_leak"]["intensity"]:
            # Silently leak the connection - store it so it's not garbage collected
            chaos_state["connection_leak"]["leaked_connections"].append(conn)
            # Return a new connection instead, leaking the previous one
            conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
        
        return conn
    except Exception as e:
        logger.error(f"Database connection error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")

def apply_slow_mode():
    """Apply artificial delay if SLOW_MODE_DELAY is set"""
    if SLOW_MODE_DELAY > 0:
        # Silently inject delay - appears as slow database or processing
        time.sleep(SLOW_MODE_DELAY)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle management for the FastAPI app"""
    # Startup
    logger.info("Starting Workshop API...")
    logger.info(f"Port: {PORT}")
    logger.info(f"Database configured: {bool(DATABASE_URL)}")
    logger.info(f"Application Insights configured: {bool(APPLICATIONINSIGHTS_CONNECTION_STRING)}")
    
    # Initialize database schema
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Create items table if it doesn't exist
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS items (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                price DECIMAL(10, 2),
                quantity INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Create an index on name for faster lookups
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_items_name ON items(name)
        """)
        
        conn.commit()
        cursor.close()
        conn.close()
        logger.info("Database schema initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization error: {str(e)}")
    
    yield
    
    # Shutdown
    logger.info("Shutting down Workshop API...")

# Create FastAPI app
app = FastAPI(
    title="Workshop API",
    description="Sample API for Azure SRE Agent Workshop",
    version="1.0.0",
    lifespan=lifespan
)

# Include chaos engineering router
app.include_router(chaos_router)

# Note: Application Insights logging is enabled via AzureLogHandler
# For request tracing, consider using OpenTelemetry in production

# Pydantic models
class Item(BaseModel):
    name: str
    description: Optional[str] = None
    price: Optional[float] = None
    quantity: int = 0

class ItemResponse(Item):
    id: int
    created_at: datetime
    updated_at: datetime

# Middleware to apply chaos engineering faults
@app.middleware("http")
async def chaos_middleware(request: Request, call_next):
    """Apply chaos faults to requests going to /api/* endpoints"""
    # Only apply chaos to business API endpoints, not admin endpoints
    if request.url.path.startswith("/api/"):
        try:
            apply_chaos_middleware()
        except HTTPException:
            raise
    
    response = await call_next(request)
    
    # Chaos: Corrupt response data
    if chaos_state["corrupt_data"]["enabled"] and request.url.path.startswith("/api/"):
        if random.randint(1, 100) <= chaos_state["corrupt_data"]["intensity"]:
            # Simulate realistic data corruption scenarios
            corruption_types = [
                {"error": "TypeError", "message": "Object of type 'Decimal' is not JSON serializable", "traceback": "File /app/main.py, line 234"},
                {"items": [{"id": None, "name": None, "price": "NaN", "quantity": -1}], "error": "partial_data"},
                {"database_error": "relation \"items\" does not exist", "hint": "Perhaps you meant to reference the table \"public.items\"?"},
            ]
            corrupted_response = random.choice(corruption_types)
            logger.error(f"Data integrity error: {corrupted_response}")
            return JSONResponse(
                status_code=500 if "error" in corrupted_response else 200,
                content=corrupted_response
            )
    
    return response

# Health check endpoints
@app.get("/health", tags=["Health"])
async def health_check():
    """Basic health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.get("/health/ready", tags=["Health"])
async def readiness_check():
    """Readiness check - verifies database connectivity"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        return {
            "status": "ready",
            "database": "connected",
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Readiness check failed: {str(e)}")
        raise HTTPException(status_code=503, detail=f"Service not ready: {str(e)}")

@app.get("/health/live", tags=["Health"])
async def liveness_check():
    """Liveness check - basic application health"""
    return {"status": "alive", "timestamp": datetime.utcnow().isoformat()}

# Item CRUD endpoints
@app.get("/", tags=["Root"])
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Welcome to Workshop API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "items": "/api/items",
            "docs": "/docs",
            "chaos_dashboard": "/admin/chaos"
        }
    }

@app.get("/api/items", response_model=List[ItemResponse], tags=["Items"])
async def list_items(skip: int = 0, limit: int = 100):
    """List all items with pagination"""
    apply_slow_mode()  # Apply artificial delay if SLOW_MODE is enabled
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            "SELECT * FROM items ORDER BY created_at DESC LIMIT %s OFFSET %s",
            (limit, skip)
        )
        items = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        logger.info(f"Retrieved {len(items)} items")
        return items
    except Exception as e:
        logger.error(f"Error listing items: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/items/{item_id}", response_model=ItemResponse, tags=["Items"])
async def get_item(item_id: int):
    """Get a specific item by ID"""
    apply_slow_mode()  # Apply artificial delay if SLOW_MODE is enabled
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM items WHERE id = %s", (item_id,))
        item = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if not item:
            raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
        
        logger.info(f"Retrieved item {item_id}")
        return item
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting item {item_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/items", response_model=ItemResponse, status_code=201, tags=["Items"])
async def create_item(item: Item):
    """Create a new item"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            """
            INSERT INTO items (name, description, price, quantity)
            VALUES (%s, %s, %s, %s)
            RETURNING *
            """,
            (item.name, item.description, item.price, item.quantity)
        )
        new_item = cursor.fetchone()
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Created item: {new_item['id']}")
        return new_item
    except Exception as e:
        logger.error(f"Error creating item: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/items/{item_id}", response_model=ItemResponse, tags=["Items"])
async def update_item(item_id: int, item: Item):
    """Update an existing item"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            """
            UPDATE items
            SET name = %s, description = %s, price = %s, quantity = %s,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
            RETURNING *
            """,
            (item.name, item.description, item.price, item.quantity, item_id)
        )
        updated_item = cursor.fetchone()
        
        if not updated_item:
            conn.close()
            raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Updated item: {item_id}")
        return updated_item
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating item {item_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/items/{item_id}", status_code=204, tags=["Items"])
async def delete_item(item_id: int):
    """Delete an item"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM items WHERE id = %s RETURNING id", (item_id,))
        deleted = cursor.fetchone()
        
        if not deleted:
            conn.close()
            raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Deleted item: {item_id}")
        return None
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting item {item_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Run the application
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT)
