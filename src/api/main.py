"""
Workshop API - A sample API for Azure SRE Agent Workshop
Demonstrates: PostgreSQL connectivity, REST endpoints, Application Insights integration, Chaos Engineering
"""

import os
import logging
import time
import random
import threading
import gc
from typing import Optional, List, Dict, Any
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.responses import JSONResponse, HTMLResponse
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from opencensus.ext.azure.log_exporter import AzureLogHandler

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

# Chaos Engineering State
chaos_state = {
    "memory_leak": {"enabled": False, "intensity": 5, "leak_data": [], "thread": None},  # intensity = minutes to 95% RAM
    "cpu_spike": {"enabled": False, "intensity": 50, "thread": None},
    "random_errors": {"enabled": False, "intensity": 30},  # 30% error rate
    "slow_responses": {"enabled": False, "intensity": 3.0},  # 3 second delay
    "connection_leak": {"enabled": False, "intensity": 50, "leaked_connections": []},
    "corrupt_data": {"enabled": False, "intensity": 20},  # 20% corruption rate
    "crash_app": {"enabled": False, "intensity": 5},  # intensity = seconds delay before crash
}

def get_db_connection():
    """Get a database connection from the pool"""
    if not DATABASE_URL:
        raise HTTPException(status_code=500, detail="Database connection not configured")
    
    try:
        conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
        
        # Chaos: Connection leak simulation
        if chaos_state["connection_leak"]["enabled"] and random.randint(1, 100) <= chaos_state["connection_leak"]["intensity"]:
            logger.debug("Database connection allocated but not returned to pool")
            chaos_state["connection_leak"]["leaked_connections"].append(conn)
            # Return a new connection instead, leaking the previous one
            conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
        
        return conn
    except Exception as e:
        logger.error(f"Database connection error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")

def cpu_burn_thread():
    """Background thread that burns CPU cycles"""
    logger.debug("Background processing thread started")
    while chaos_state["cpu_spike"]["enabled"]:
        # Burn CPU based on intensity (0-100)
        intensity = chaos_state["cpu_spike"]["intensity"]
        burn_duration = intensity / 1000.0  # Max 100ms of burning
        sleep_duration = (100 - intensity) / 1000.0  # Rest of the time sleeping
        
        start = time.time()
        while time.time() - start < burn_duration:
            _ = sum(i * i for i in range(1000))  # Busy work
        
        if sleep_duration > 0:
            time.sleep(sleep_duration)
    logger.debug("Background processing thread stopped")

def memory_leak_thread():
    """Background thread that gradually leaks memory over time"""
    try:
        import psutil
        import os
        
        logger.debug("Memory allocation")
        
        # Get target duration in seconds
        target_minutes = chaos_state["memory_leak"]["intensity"]
        target_seconds = target_minutes * 60
        
        # Detect container memory limit from cgroup (for containers) or use system memory
        container_memory_limit = None
        try:
            # Try cgroup v2 first (newer systems)
            if os.path.exists('/sys/fs/cgroup/memory.max'):
                with open('/sys/fs/cgroup/memory.max', 'r') as f:
                    limit_str = f.read().strip()
                    if limit_str != 'max':
                        container_memory_limit = int(limit_str)
            # Try cgroup v1 (older systems)
            elif os.path.exists('/sys/fs/cgroup/memory/memory.limit_in_bytes'):
                with open('/sys/fs/cgroup/memory/memory.limit_in_bytes', 'r') as f:
                    container_memory_limit = int(f.read().strip())
        except Exception as e:
            logger.warning(f"Could not read cgroup memory limit: {e}")
        
        # Determine available memory: use container limit if available, otherwise system memory
        if container_memory_limit and container_memory_limit < (2**63 - 1):  # Check for unrealistic values
            # For containers, use 95% of the container memory limit
            available_memory = container_memory_limit
            logger.info(f"Detected container memory limit: {available_memory / (1024**3):.2f} GB")
        else:
            # For non-containerized environments, use available system memory
            available_memory = psutil.virtual_memory().available
            logger.info(f"Using system available memory: {available_memory / (1024**3):.2f} GB")
        
        # Calculate target (95% of available memory)
        target_memory = int(available_memory * 0.95)
        
        # Calculate chunk size and sleep interval
        # Leak in small increments every second for smooth progression
        chunk_size = max(1024 * 1024, target_memory // target_seconds)  # At least 1MB chunks
        sleep_interval = 1.0  # Leak every second
        
        logger.info(f"Allocating memory buffer: targeting {target_memory / (1024**3):.2f} GB over {target_minutes} minutes")
        
        leaked_bytes = 0
        while chaos_state["memory_leak"]["enabled"] and leaked_bytes < target_memory:
            try:
                # Allocate memory and fill it with data to prevent optimization/deallocation
                data = bytearray(chunk_size)
                # Fill with non-zero data to ensure memory is actually allocated
                for i in range(0, chunk_size, 1024):
                    data[i] = (i % 256)
                chaos_state["memory_leak"]["leak_data"].append(data)
                leaked_bytes += chunk_size
                
                if len(chaos_state["memory_leak"]["leak_data"]) % 100 == 0:  # Log every 100 chunks
                    logger.info(f"Memory allocated: {leaked_bytes / (1024**2):.1f} MB / {target_memory / (1024**2):.1f} MB ({leaked_bytes / target_memory * 100:.1f}%)")
                
                time.sleep(sleep_interval)
            except MemoryError:
                logger.error("Memory allocation failed - container memory limit reached")
                break
        
        # Keep the memory leaked until disabled
        if chaos_state["memory_leak"]["enabled"]:
            logger.warning(f"Memory allocation complete: {leaked_bytes / (1024**3):.2f} GB allocated - monitoring memory usage")
            # Hold the memory by waiting while enabled
            while chaos_state["memory_leak"]["enabled"]:
                time.sleep(1)
            logger.info("Releasing allocated memory buffers")
        else:
            logger.debug("Memory allocation thread stopped")
    except ImportError as e:
        logger.error(f"Failed to import psutil - memory monitoring unavailable: {e}")
    except Exception as e:
        logger.error(f"Memory allocation thread error: {e}")
        import traceback
        logger.error(traceback.format_exc())

def trigger_memory_leak():
    """Allocate memory that won't be freed"""
    # This function is no longer used - memory leak is now background thread based
    pass

def apply_chaos_middleware():
    """Apply chaos engineering faults to the current request"""
    
    # Random errors
    if chaos_state["random_errors"]["enabled"]:
        if random.randint(1, 100) <= chaos_state["random_errors"]["intensity"]:
            error_messages = [
                "Internal server error",
                "Service temporarily unavailable",
                "Database connection timeout",
                "Unexpected error occurred",
                "Resource not available"
            ]
            logger.error(f"Request failed: {random.choice(error_messages)}")
            raise HTTPException(status_code=500, detail=error_messages[-1])
    
    # Slow responses
    if chaos_state["slow_responses"]["enabled"]:
        delay = chaos_state["slow_responses"]["intensity"]
        logger.debug(f"Processing request: {delay}s")
        time.sleep(delay)

def apply_slow_mode():
    """Apply artificial delay if SLOW_MODE_DELAY is set"""
    if SLOW_MODE_DELAY > 0:
        logger.warning(f"S-MODE enabled")
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

class ChaosConfig(BaseModel):
    enabled: bool
    intensity: Optional[int] = None

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
            logger.error("Response serialization error - data integrity issue detected")
            return JSONResponse(
                status_code=200,
                content={"corrupted": True, "error": "Data corruption injected", "random": random.random()}
            )
    
    return response

# =============================================================================
# CHAOS ENGINEERING / ADMIN ENDPOINTS
# =============================================================================

@app.get("/admin/chaos", response_class=HTMLResponse, tags=["Chaos Engineering"])
async def chaos_dashboard():
    """HTML dashboard for chaos engineering controls"""
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Chaos Engineering Dashboard</title>
        <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🔥</text></svg>">
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 1200px;
                margin: 0 auto;
                padding: 20px;
                background-color: #f5f5f5;
            }
            h1 { color: #d32f2f; }
            .fault-card {
                background: white;
                border-radius: 8px;
                padding: 20px;
                margin: 15px 0;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .fault-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 15px;
            }
            .fault-title {
                font-size: 18px;
                font-weight: bold;
                color: #333;
            }
            .status {
                padding: 5px 15px;
                border-radius: 20px;
                font-size: 14px;
                font-weight: bold;
            }
            .status.enabled {
                background-color: #f44336;
                color: white;
            }
            .status.disabled {
                background-color: #4caf50;
                color: white;
            }
            .controls {
                display: flex;
                gap: 10px;
                align-items: center;
                margin-top: 10px;
            }
            button {
                padding: 10px 20px;
                border: none;
                border-radius: 4px;
                cursor: pointer;
                font-size: 14px;
                font-weight: bold;
            }
            .btn-enable {
                background-color: #f44336;
                color: white;
            }
            .btn-disable {
                background-color: #4caf50;
                color: white;
            }
            .btn-enable:hover {
                background-color: #d32f2f;
            }
            .btn-disable:hover {
                background-color: #45a049;
            }
            input[type="range"] {
                flex-grow: 1;
                margin: 0 10px;
            }
            .intensity-label {
                min-width: 60px;
                text-align: right;
                font-weight: bold;
                color: #666;
            }
            .description {
                color: #666;
                font-size: 14px;
                margin-top: 10px;
            }
            .master-controls {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 20px;
                border-radius: 8px;
                margin-bottom: 20px;
                text-align: center;
            }
            .btn-master {
                background-color: white;
                color: #667eea;
                margin: 5px;
            }
            .danger-zone {
                background: linear-gradient(135deg, #ff5252 0%, #d32f2f 100%);
                color: white;
                padding: 20px;
                border-radius: 8px;
                margin-top: 30px;
                text-align: center;
                border: 3px solid #b71c1c;
            }
            .danger-zone h2 {
                margin-top: 0;
                font-size: 24px;
            }
            .btn-danger {
                background-color: #ffebee;
                color: #c62828;
                padding: 15px 30px;
                font-size: 16px;
                font-weight: bold;
                border: 2px solid #fff;
                border-radius: 4px;
                cursor: pointer;
            }
            .btn-danger:hover {
                background-color: #fff;
                color: #b71c1c;
            }
        </style>
    </head>
    <body>
        <h1>🔥 Chaos Engineering Dashboard</h1>
        
        <div class="master-controls">
            <h2>Master Controls</h2>
            <button class="btn-master" onclick="disableAll()">Disable All Faults</button>
            <button class="btn-master" onclick="refreshStatus()">Refresh Status</button>
        </div>

        <div id="faults-container"></div>

        <script>
            const faults = [
                {
                    key: 'memory_leak',
                    title: 'Memory Leak',
                    description: 'Gradually leaks memory in background thread until 95% RAM consumed. Intensity controls duration in minutes.',
                    intensityLabel: 'Minutes',
                    min: 1,
                    max: 30,
                    step: 1
                },
                {
                    key: 'cpu_spike',
                    title: 'CPU Spike',
                    description: 'Spawns background thread burning CPU cycles. Intensity controls CPU utilization (0-100%).',
                    intensityLabel: 'CPU %',
                    min: 0,
                    max: 100,
                    step: 5
                },
                {
                    key: 'random_errors',
                    title: 'Random Errors',
                    description: 'Returns HTTP 500 errors randomly. Intensity controls error rate percentage.',
                    intensityLabel: 'Error rate %',
                    min: 1,
                    max: 100,
                    step: 5
                },
                {
                    key: 'slow_responses',
                    title: 'Slow Responses',
                    description: 'Adds artificial delay to responses. Intensity controls delay in seconds.',
                    intensityLabel: 'Delay (s)',
                    min: 1,
                    max: 30,
                    step: 1
                },
                {
                    key: 'connection_leak',
                    title: 'Connection Leak',
                    description: 'Leaks database connections without closing them. Intensity controls leak probability.',
                    intensityLabel: 'Leak rate %',
                    min: 1,
                    max: 100,
                    step: 5
                },
                {
                    key: 'corrupt_data',
                    title: 'Corrupt Data',
                    description: 'Returns corrupted JSON responses. Intensity controls corruption rate percentage.',
                    intensityLabel: 'Corruption rate %',
                    min: 1,
                    max: 100,
                    step: 5
                },
                {
                    key: 'crash_app',
                    title: '💥 Crash the App',
                    description: 'Terminates the application with a fatal error. Intensity controls delay in seconds before crash.',
                    intensityLabel: 'Delay (s)',
                    min: 1,
                    max: 30,
                    step: 1
                }
            ];

            async function fetchStatus() {
                const response = await fetch('/admin/chaos/status');
                return await response.json();
            }

            async function enableFault(faultKey) {
                const intensity = document.getElementById(`intensity-${faultKey}`).value;
                await fetch(`/admin/chaos/${faultKey}/enable`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({enabled: true, intensity: parseInt(intensity)})
                });
                await refreshStatus();
            }

            async function disableFault(faultKey) {
                await fetch(`/admin/chaos/${faultKey}/disable`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({enabled: false})
                });
                await refreshStatus();
            }

            async function disableAll() {
                for (const fault of faults) {
                    await disableFault(fault.key);
                }
            }

            async function crashApp() {
                if (confirm('⚠️ This will immediately crash the application! Are you sure?')) {
                    await fetch('/admin/chaos/crash_app/enable', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({enabled: true, intensity: 0})
                    });
                }
            }

            async function refreshStatus() {
                const status = await fetchStatus();
                const container = document.getElementById('faults-container');
                
                // Store current slider values to preserve user changes
                const currentValues = {};
                faults.forEach(fault => {
                    const slider = document.getElementById(`intensity-${fault.key}`);
                    if (slider) {
                        currentValues[fault.key] = slider.value;
                    }
                });

                container.innerHTML = '';

                faults.forEach(fault => {
                    const state = status[fault.key];
                    // Use current slider value if exists, otherwise use server state
                    const currentValue = currentValues[fault.key] || state.intensity;
                    const card = document.createElement('div');
                    card.className = 'fault-card';
                    card.innerHTML = `
                        <div class="fault-header">
                            <div class="fault-title">${fault.title}</div>
                            <div class="status ${state.enabled ? 'enabled' : 'disabled'}">
                                ${state.enabled ? 'ACTIVE' : 'INACTIVE'}
                            </div>
                        </div>
                        <div class="description">${fault.description}</div>
                        <div class="controls">
                            <button class="btn-enable" onclick="enableFault('${fault.key}')">Enable</button>
                            <button class="btn-disable" onclick="disableFault('${fault.key}')">Disable</button>
                            <input type="range" id="intensity-${fault.key}" 
                                   min="${fault.min}" max="${fault.max}" step="${fault.step}" value="${currentValue}" 
                                   oninput="document.getElementById('value-${fault.key}').innerText = this.value + ' ${fault.intensityLabel}'">
                            <span class="intensity-label" id="value-${fault.key}">${currentValue} ${fault.intensityLabel}</span>
                        </div>
                    `;
                    container.appendChild(card);
                });
            }

            // Initial load
            refreshStatus();
            
            // Auto-refresh every 5 seconds
            setInterval(refreshStatus, 5000);
        </script>

        <div class="danger-zone">
            <h2>⚠️ Danger Zone!</h2>
            <p>The action below will immediately terminate the application.</p>
            <button class="btn-danger" onclick="crashApp()">💥 Crash App Now</button>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.get("/admin/chaos/status", tags=["Chaos Engineering"])
async def get_chaos_status():
    """Get current status of all chaos faults"""
    # Return a serializable version without thread objects
    status = {}
    for fault_type, state in chaos_state.items():
        status[fault_type] = {
            "enabled": state["enabled"],
            "intensity": state["intensity"]
        }
    return status

@app.post("/admin/chaos/{fault_type}/enable", tags=["Chaos Engineering"])
async def enable_chaos_fault(fault_type: str, config: ChaosConfig):
    """Enable a specific chaos fault"""
    if fault_type not in chaos_state:
        raise HTTPException(status_code=404, detail=f"Fault type '{fault_type}' not found")
    
    chaos_state[fault_type]["enabled"] = True
    if config.intensity is not None:
        chaos_state[fault_type]["intensity"] = config.intensity
    
    # Special handling for CPU spike - start background thread
    if fault_type == "cpu_spike":
        current_thread = chaos_state["cpu_spike"]["thread"]
        # Start new thread if none exists or if the existing one is not alive
        if current_thread is None or not current_thread.is_alive():
            thread = threading.Thread(target=cpu_burn_thread, daemon=True)
            thread.start()
            chaos_state["cpu_spike"]["thread"] = thread
    
    # Special handling for memory leak - start background thread
    elif fault_type == "memory_leak":
        current_thread = chaos_state["memory_leak"]["thread"]
        # Start new thread if none exists or if the existing one is not alive
        if current_thread is None or not current_thread.is_alive():
            thread = threading.Thread(target=memory_leak_thread, daemon=True)
            thread.start()
            chaos_state["memory_leak"]["thread"] = thread
    
    # Special handling for crash - trigger immediate or delayed crash
    elif fault_type == "crash_app":
        delay = chaos_state["crash_app"]["intensity"]
        def crash_with_delay():
            if delay > 0:
                time.sleep(delay)
            # Trigger a fatal error
            os._exit(1)
        
        thread = threading.Thread(target=crash_with_delay, daemon=False)
        thread.start()
    
    return {
        "status": "enabled",
        "fault": fault_type,
        "config": {
            "enabled": chaos_state[fault_type]["enabled"],
            "intensity": chaos_state[fault_type]["intensity"]
        }
    }

@app.post("/admin/chaos/{fault_type}/disable", tags=["Chaos Engineering"])
async def disable_chaos_fault(fault_type: str, config: ChaosConfig):
    """Disable a specific chaos fault"""
    if fault_type not in chaos_state:
        raise HTTPException(status_code=404, detail=f"Fault type '{fault_type}' not found")
    
    chaos_state[fault_type]["enabled"] = False
    
    # Special handling for different fault types
    if fault_type == "memory_leak":
        # Clear leaked memory
        chaos_state["memory_leak"]["leak_data"].clear()
        chaos_state["memory_leak"]["thread"] = None
        gc.collect()
        logger.info("Memory buffers released and garbage collection completed")
    
    elif fault_type == "cpu_spike":
        # Clear thread reference so it can be restarted
        chaos_state["cpu_spike"]["thread"] = None
        logger.debug("Background processing thread stopped")
    
    elif fault_type == "connection_leak":
        # Close all leaked connections
        for conn in chaos_state["connection_leak"]["leaked_connections"]:
            try:
                conn.close()
            except:
                pass
        chaos_state["connection_leak"]["leaked_connections"].clear()
        logger.info("Database connection cleanup completed")
    
    return {"status": "disabled", "fault": fault_type}

@app.post("/admin/chaos/disable-all", tags=["Chaos Engineering"])
async def disable_all_chaos():
    """Disable all chaos faults at once"""
    for fault_type in chaos_state.keys():
        await disable_chaos_fault(fault_type, ChaosConfig(enabled=False))
    return {"status": "all faults disabled"}

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
