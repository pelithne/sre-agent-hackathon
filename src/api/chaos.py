"""
Chaos Engineering Module
Provides chaos fault injection capabilities for testing system resilience
"""

import os
import logging
import time
import random
import threading
import gc
from typing import Dict, Any, Optional

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse, HTMLResponse
from pydantic import BaseModel

logger = logging.getLogger(__name__)

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

class ChaosConfig(BaseModel):
    enabled: bool
    intensity: Optional[int] = None

# Background thread functions
def cpu_burn_thread():
    """Background thread that burns CPU cycles"""
    logger.info("Worker thread initialized for async task processing")
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
    logger.info("Worker thread terminated")

def memory_leak_thread():
    """Background thread that gradually leaks memory over time"""
    try:
        import psutil
        import os
        
        logger.info("Initializing request cache manager")
        
        # Get target duration in seconds
        target_minutes = chaos_state["memory_leak"]["intensity"]
        target_seconds = target_minutes * 60
        
        # Try to read container memory limit from cgroup
        try:
            with open('/sys/fs/cgroup/memory.max', 'r') as f:
                container_memory_limit = int(f.read().strip())
                if container_memory_limit == -1 or container_memory_limit > 1e15:  # "max" or unreasonably large
                    raise ValueError("No limit set")
        except (FileNotFoundError, ValueError):
            # Fallback to system total memory if cgroup file doesn't exist
            container_memory_limit = psutil.virtual_memory().total
        
        logger.debug(f"Container memory limit detected: {container_memory_limit / (1024**3):.2f} GB")
        
        # Target: 95% of container memory
        target_memory_bytes = int(container_memory_limit * 0.95)
        
        # Calculate allocation size and interval
        allocation_size_mb = 50  # Allocate 50MB at a time
        allocation_size_bytes = allocation_size_mb * 1024 * 1024
        
        # Calculate number of allocations needed
        total_allocations_needed = target_memory_bytes // allocation_size_bytes
        
        # Calculate sleep interval between allocations
        sleep_interval = target_seconds / total_allocations_needed if total_allocations_needed > 0 else 1
        
        logger.debug(f"Cache target size: {target_memory_bytes / (1024**3):.2f} GB")
        
        process = psutil.Process(os.getpid())
        start_time = time.time()
        
        while chaos_state["memory_leak"]["enabled"]:
            current_memory = process.memory_info().rss
            
            if current_memory >= target_memory_bytes:
                # Hold at 95% until disabled
                logger.debug(f"Cache size stable at {current_memory / (1024**3):.2f} GB")
                time.sleep(10)  # Check every 10 seconds
                continue
            
            # Allocate memory chunk
            chunk = bytearray(allocation_size_bytes)
            # Write to the memory to ensure it's actually allocated
            for i in range(0, allocation_size_bytes, 4096):
                chunk[i] = random.randint(0, 255)
            chaos_state["memory_leak"]["leak_data"].append(chunk)
            
            elapsed = time.time() - start_time
            current_memory = process.memory_info().rss
            progress = (current_memory / target_memory_bytes) * 100
            
            logger.debug(f"Cache size: {current_memory / (1024**3):.2f} GB ({progress:.1f}% capacity)")
            
            # Sleep before next allocation
            if chaos_state["memory_leak"]["enabled"]:
                time.sleep(sleep_interval)
        
    except Exception as e:
        logger.error(f"Cache manager error: {str(e)}")

# Middleware helper function
def apply_chaos_middleware():
    """Apply chaos faults - call this from middleware"""
    # Chaos: Random errors
    if chaos_state["random_errors"]["enabled"]:
        if random.randint(1, 100) <= chaos_state["random_errors"]["intensity"]:
            # Simulate realistic production errors
            error_types = [
                ("Database connection pool exhausted - max pool size reached", 503),
                ("Database query timeout after 30s - please retry", 504),
                ("Serialization error: Object of type 'datetime' is not JSON serializable", 500),
                ("psycopg2.OperationalError: server closed the connection unexpectedly", 503),
                ("Connection to database lost - unable to acquire connection from pool", 503),
                ("SSL SYSCALL error: EOF detected", 500),
            ]
            error_msg, status_code = random.choice(error_types)
            logger.error(f"Request failed: {error_msg}")
            raise HTTPException(status_code=status_code, detail=error_msg)
    
    # Chaos: Slow responses
    if chaos_state["slow_responses"]["enabled"]:
        delay = chaos_state["slow_responses"]["intensity"]
        # Silently inject delay - no obvious logging
        time.sleep(delay)

# Create API router
router = APIRouter(prefix="/admin/chaos", tags=["Chaos Engineering"])

@router.get("", response_class=HTMLResponse)
async def chaos_dashboard():
    """Chaos Engineering Dashboard - Visual interface for fault injection"""
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Chaos Engineering Dashboard</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                padding: 20px;
            }
            
            .container {
                max-width: 1200px;
                margin: 0 auto;
            }
            
            h1 {
                color: white;
                text-align: center;
                margin-bottom: 30px;
                font-size: 2.5em;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
            }
            
            .master-controls {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                padding: 20px;
                border-radius: 12px;
                margin-bottom: 30px;
                display: flex;
                gap: 15px;
                justify-content: center;
                box-shadow: 0 8px 32px rgba(0,0,0,0.3);
            }
            
            .master-controls button {
                padding: 12px 24px;
                font-size: 16px;
                font-weight: 600;
                border: 2px solid white;
                border-radius: 8px;
                cursor: pointer;
                transition: all 0.3s ease;
                background: rgba(255,255,255,0.9);
                color: #667eea;
            }
            
            .master-controls button:hover {
                background: white;
                transform: translateY(-2px);
                box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            }
            
            #faults-container {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
                gap: 20px;
                margin-bottom: 30px;
            }
            
            .fault-card {
                background: white;
                border-radius: 12px;
                padding: 25px;
                box-shadow: 0 8px 32px rgba(0,0,0,0.1);
                transition: transform 0.3s ease, box-shadow 0.3s ease;
            }
            
            .fault-card:hover {
                transform: translateY(-5px);
                box-shadow: 0 12px 48px rgba(0,0,0,0.15);
            }
            
            .fault-card.enabled {
                border: 3px solid #4CAF50;
                background: #f0f9f0;
            }
            
            .fault-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 15px;
            }
            
            .fault-name {
                font-size: 1.3em;
                font-weight: 700;
                color: #333;
            }
            
            .fault-status {
                padding: 6px 14px;
                border-radius: 20px;
                font-size: 0.85em;
                font-weight: 600;
            }
            
            .status-enabled {
                background: #4CAF50;
                color: white;
            }
            
            .status-disabled {
                background: #e0e0e0;
                color: #666;
            }
            
            .fault-description {
                color: #666;
                margin-bottom: 20px;
                line-height: 1.5;
            }
            
            .controls {
                display: flex;
                flex-direction: column;
                gap: 15px;
            }
            
            .slider-container {
                display: flex;
                flex-direction: column;
                gap: 8px;
            }
            
            .slider-label {
                display: flex;
                justify-content: space-between;
                font-size: 0.9em;
                color: #666;
            }
            
            input[type="range"] {
                width: 100%;
                height: 8px;
                border-radius: 5px;
                background: #ddd;
                outline: none;
                -webkit-appearance: none;
            }
            
            input[type="range"]::-webkit-slider-thumb {
                -webkit-appearance: none;
                appearance: none;
                width: 20px;
                height: 20px;
                border-radius: 50%;
                background: #667eea;
                cursor: pointer;
                transition: background 0.3s;
            }
            
            input[type="range"]::-webkit-slider-thumb:hover {
                background: #764ba2;
            }
            
            .action-buttons {
                display: flex;
                gap: 10px;
            }
            
            button {
                padding: 10px 20px;
                border: none;
                border-radius: 6px;
                font-weight: 600;
                cursor: pointer;
                transition: all 0.3s ease;
                flex: 1;
            }
            
            .btn-enable {
                background: #4CAF50;
                color: white;
            }
            
            .btn-enable:hover {
                background: #45a049;
                transform: translateY(-2px);
            }
            
            .btn-disable {
                background: #f44336;
                color: white;
            }
            
            .btn-disable:hover {
                background: #da190b;
                transform: translateY(-2px);
            }
            
            .danger-zone {
                background: linear-gradient(135deg, #ff6b6b 0%, #ee5a6f 100%);
                padding: 30px;
                border-radius: 12px;
                text-align: center;
                box-shadow: 0 8px 32px rgba(0,0,0,0.3);
                border: 3px solid #c92a2a;
            }
            
            .danger-zone h2 {
                color: white;
                margin-bottom: 15px;
                font-size: 2em;
            }
            
            .danger-zone p {
                color: white;
                margin-bottom: 20px;
                font-size: 1.1em;
            }
            
            .danger-zone button {
                background: white;
                color: #c92a2a;
                padding: 15px 40px;
                font-size: 1.1em;
                border: 3px solid white;
            }
            
            .danger-zone button:hover {
                background: #ffe0e0;
                transform: scale(1.05);
            }
            
            .hidden {
                display: none;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🔥 Chaos Engineering Dashboard</h1>
            
            <div class="master-controls" id="master-controls">
                <button onclick="disableAll()">🛑 Disable All Faults</button>
                <button onclick="refreshStatus()">🔄 Refresh Status</button>
            </div>
            
            <div id="faults-container"></div>
        </div>

        <script>
            const faults = [
                {
                    id: 'memory_leak',
                    name: '💾 Memory Leak',
                    description: 'Gradually consumes memory until container limit',
                    sliderLabel: 'Time to 95% RAM (minutes)',
                    sliderMin: 1,
                    sliderMax: 30,
                    sliderStep: 1,
                    sliderUnit: 'min'
                },
                {
                    id: 'cpu_spike',
                    name: '⚡ CPU Spike',
                    description: 'Burns CPU cycles in background thread',
                    sliderLabel: 'CPU utilization (%)',
                    sliderMin: 0,
                    sliderMax: 100,
                    sliderStep: 5,
                    sliderUnit: '%'
                },
                {
                    id: 'slow_responses',
                    name: '🐌 Slow Responses',
                    description: 'Adds artificial delay to API responses',
                    sliderLabel: 'Response delay (seconds)',
                    sliderMin: 1,
                    sliderMax: 30,
                    sliderStep: 1,
                    sliderUnit: 's'
                },
                {
                    id: 'random_errors',
                    name: '💥 Random Errors',
                    description: 'Returns HTTP 500 errors randomly',
                    sliderLabel: 'Error rate (%)',
                    sliderMin: 0,
                    sliderMax: 100,
                    sliderStep: 5,
                    sliderUnit: '%'
                },
                {
                    id: 'corrupt_data',
                    name: '🔀 Corrupt Data',
                    description: 'Returns corrupted JSON responses',
                    sliderLabel: 'Corruption rate (%)',
                    sliderMin: 0,
                    sliderMax: 100,
                    sliderStep: 5,
                    sliderUnit: '%'
                },
                {
                    id: 'connection_leak',
                    name: '🔌 Connection Leak',
                    description: 'Leaks database connections',
                    sliderLabel: 'Leak probability (%)',
                    sliderMin: 0,
                    sliderMax: 100,
                    sliderStep: 5,
                    sliderUnit: '%'
                }
            ];

            async function fetchStatus() {
                const response = await fetch('/admin/chaos/status');
                return await response.json();
            }

            async function enableFault(faultId, intensity) {
                await fetch(`/admin/chaos/${faultId}/enable`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({enabled: true, intensity: intensity})
                });
                await refreshStatus();
            }

            async function disableFault(faultId) {
                await fetch(`/admin/chaos/${faultId}/disable`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({enabled: false})
                });
                await refreshStatus();
            }

            async function disableAll() {
                await fetch('/admin/chaos/disable-all', {method: 'POST'});
                await refreshStatus();
            }

            async function crashApp() {
                if (confirm('⚠️ This will immediately crash the application. Are you sure?')) {
                    const delay = parseInt(prompt('Delay before crash (seconds, 0 for immediate):', '0'));
                    await fetch('/admin/chaos/crash_app/enable', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({enabled: true, intensity: delay})
                    });
                }
            }

            async function refreshStatus() {
                const status = await fetchStatus();
                const container = document.getElementById('faults-container');
                container.innerHTML = '';

                faults.forEach(fault => {
                    const state = status[fault.id];
                    const card = document.createElement('div');
                    card.className = `fault-card ${state.enabled ? 'enabled' : ''}`;
                    card.innerHTML = `
                        <div class="fault-header">
                            <div class="fault-name">${fault.name}</div>
                            <div class="fault-status ${state.enabled ? 'status-enabled' : 'status-disabled'}">
                                ${state.enabled ? 'ENABLED' : 'DISABLED'}
                            </div>
                        </div>
                        <div class="fault-description">${fault.description}</div>
                        <div class="controls">
                            <div class="slider-container">
                                <div class="slider-label">
                                    <span>${fault.sliderLabel}</span>
                                    <span id="${fault.id}-value">${state.intensity}${fault.sliderUnit}</span>
                                </div>
                                <input type="range" 
                                    id="${fault.id}-slider"
                                    min="${fault.sliderMin}" 
                                    max="${fault.sliderMax}" 
                                    step="${fault.sliderStep}"
                                    value="${state.intensity}"
                                    oninput="document.getElementById('${fault.id}-value').textContent = this.value + '${fault.sliderUnit}'">
                            </div>
                            <div class="action-buttons">
                                <button class="btn-enable" onclick="enableFault('${fault.id}', document.getElementById('${fault.id}-slider').value)">
                                    ▶️ Enable
                                </button>
                                <button class="btn-disable" onclick="disableFault('${fault.id}')">
                                    ⏹️ Disable
                                </button>
                            </div>
                        </div>
                    `;
                    container.appendChild(card);
                });
                
                // Show danger zone after first load
                document.getElementById('danger-zone').classList.remove('hidden');
            }

            // Initial load
            refreshStatus();
            
            // Auto-refresh every 5 seconds
            setInterval(refreshStatus, 5000);
        </script>

        <div class="danger-zone hidden" id="danger-zone">
            <h2>⚠️ Danger Zone!</h2>
            <p>The action below will immediately terminate the application.</p>
            <button class="btn-danger" onclick="crashApp()">💥 Crash App Now</button>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@router.get("/status")
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

@router.post("/{fault_type}/enable")
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
            logger.critical(f"Application crash triggered - terminating process")
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

@router.post("/{fault_type}/disable")
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

@router.post("/disable-all")
async def disable_all_chaos():
    """Disable all chaos faults at once"""
    for fault_type in chaos_state.keys():
        await disable_chaos_fault(fault_type, ChaosConfig(enabled=False))
    return {"status": "all faults disabled"}
