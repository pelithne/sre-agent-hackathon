# Workshop API

A sample REST API built with FastAPI for the Azure SRE Agent Workshop. This API demonstrates:
- PostgreSQL database connectivity
- CRUD operations on items
- Application Insights integration
- Health check endpoints
- Containerization with Docker

## Features

### Endpoints

#### Health Checks
- `GET /health` - Basic health check
- `GET /health/ready` - Readiness check (includes database connectivity)
- `GET /health/live` - Liveness check

#### Items API
- `GET /` - Root endpoint with API information
- `GET /items` - List all items (with pagination)
- `GET /items/{id}` - Get a specific item
- `POST /items` - Create a new item
- `PUT /items/{id}` - Update an item
- `DELETE /items/{id}` - Delete an item

### Interactive Documentation
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Configuration

The API is configured using environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Port to listen on | `8000` |
| `DATABASE_URL` | PostgreSQL connection string | Required |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Application Insights connection string | Optional |

### Database Connection String Format
```
postgresql://username:password@hostname:5432/database?sslmode=require
```

## Local Development

### Prerequisites
- Python 3.11+
- PostgreSQL 14+

### Setup

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set environment variables:
```bash
export DATABASE_URL="postgresql://user:pass@localhost:5432/workshopdb"
export PORT=8000
```

4. Run the application:
```bash
python main.py
```

5. Access the API:
- API: http://localhost:8000
- Swagger docs: http://localhost:8000/docs

## Docker

### Build the image
```bash
docker build -t workshop-api:latest .
```

### Run the container
```bash
docker run -d \
  -p 8000:8000 \
  -e DATABASE_URL="postgresql://user:pass@host:5432/db" \
  -e APPLICATIONINSIGHTS_CONNECTION_STRING="your-connection-string" \
  --name workshop-api \
  workshop-api:latest
```

### Check logs
```bash
docker logs workshop-api
```

### Test health endpoint
```bash
curl http://localhost:8000/health
```

## Azure Container Registry

### Build and push to ACR
```bash
# Login to ACR
az acr login --name <your-acr-name>

# Build and push
docker build -t <your-acr-name>.azurecr.io/workshop-api:1.0.0 .
docker push <your-acr-name>.azurecr.io/workshop-api:1.0.0
```

## API Usage Examples

### Create an item
```bash
curl -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sample Item",
    "description": "A test item",
    "price": 29.99,
    "quantity": 10
  }'
```

### List items
```bash
curl http://localhost:8000/items
```

### Get a specific item
```bash
curl http://localhost:8000/items/1
```

### Update an item
```bash
curl -X PUT http://localhost:8000/items/1 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Item",
    "description": "Updated description",
    "price": 39.99,
    "quantity": 5
  }'
```

### Delete an item
```bash
curl -X DELETE http://localhost:8000/items/1
```

## Database Schema

The API creates the following table automatically on startup:

```sql
CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2),
    quantity INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_items_name ON items(name);
```

## Application Insights Integration

When `APPLICATIONINSIGHTS_CONNECTION_STRING` is provided, the API automatically:
- Sends logs to Application Insights
- Tracks HTTP requests and dependencies
- Reports exceptions and errors
- Enables distributed tracing

## Troubleshooting

### Database Connection Issues
If you see database connection errors, verify:
1. PostgreSQL is running and accessible
2. Connection string is correct
3. Firewall rules allow connections
4. SSL mode is configured correctly

### Application Insights Not Working
1. Verify the connection string is correct
2. Check that the Application Insights resource exists
3. Review logs for authentication errors

### Container Not Starting
1. Check logs: `docker logs workshop-api`
2. Verify environment variables are set
3. Ensure port 8000 is not already in use

## Architecture

```
┌─────────────────┐
│  Azure APIM     │
│  (Gateway)      │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Container App  │
│  (FastAPI)      │
└────┬──────────┬─┘
     │          │
     ↓          ↓
┌─────────┐  ┌──────────────────┐
│ PostgreSQL│  │ App Insights     │
│ Database  │  │ (Monitoring)     │
└───────────┘  └──────────────────┘
```

## License

MIT License - See LICENSE file for details
