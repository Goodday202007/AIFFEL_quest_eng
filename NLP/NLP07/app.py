import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from dotenv import load_dotenv
from neo4j import GraphDatabase

# Load environment variables
env_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(env_path)

URI = os.environ.get("NEO4J_URI", "neo4j+ssc://ee62ce9b.databases.neo4j.io")
USER = os.environ.get("NEO4J_USERNAME", "ee62ce9b")
PASSWORD = os.environ.get("NEO4J_PASSWORD", "")
DATABASE = os.environ.get("NEO4J_DATABASE", "ee62ce9b")

driver = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global driver
    try:
        driver = GraphDatabase.driver(URI, auth=(USER, PASSWORD))
        driver.verify_connectivity()
        print("Backend connected to Neo4j Database")
    except Exception as e:
        print(f"Failed to connect to Neo4j: {e}")
    yield
    if driver:
        driver.close()

app = FastAPI(lifespan=lifespan, title="LG U+ 5G Plan Consultant API")

# Serve static files from the 'static' directory if it exists, but we'll manually handle the root `/`
static_dir = os.path.join(os.path.dirname(__file__), 'static')
os.makedirs(static_dir, exist_ok=True)
app.mount("/static", StaticFiles(directory=static_dir), name="static")

@app.get("/")
def read_root():
    return FileResponse(os.path.join(static_dir, "index.html"))

@app.get("/api/plans")
def get_all_plans():
    """Fetch all plans with their categories and basic details."""
    if not driver:
        raise HTTPException(status_code=500, detail="Database not connected")
    
    query = """
    MATCH (co:Condition)<-[:REQUIRES]-(p:Plan)-[:BELONGS_TO]->(c:PlanCategory)
    OPTIONAL MATCH (p)-[:OFFERS]->(o:OTTService)
    OPTIONAL MATCH (p)-[:INCLUDES]->(b:Benefit)
    RETURN p.id AS id, p.name AS name, p.price AS price, 
           p.data_limit AS data_limit, p.is_data_unlimited AS is_data_unlimited,
           p.shared_data AS shared_data, c.category_name AS category,
           collect(DISTINCT o.service_name) AS ott_services,
           collect(DISTINCT b.description) AS benefits,
           collect(DISTINCT co.description) AS conditions
    ORDER BY p.price DESC
    """
    
    with driver.session(database=DATABASE) as session:
        result = session.run(query)
        plans = []
        for record in result:
            plans.append({
                "id": record["id"],
                "name": record["name"],
                "price": record["price"],
                "data": "무제한" if record["is_data_unlimited"] else f"{record['data_limit']}GB",
                "shared_data": record["shared_data"],
                "category": record["category"],
                "ott_services": record["ott_services"],
                "benefits": record["benefits"],
                "conditions": record["conditions"]
            })
        return {"status": "success", "data": plans}

@app.get("/api/query/youth")
def get_youth_plans():
    """Find plans with extra youth discount benefits."""
    if not driver:
        raise HTTPException(status_code=500, detail="Database not connected")
        
    query = """
    MATCH (p:Plan)-[:ELIGIBLE_FOR]->(a:AgeDiscount)
    WHERE a.max_age <= 34
    RETURN p.id as id, p.name AS name, p.price AS original_price, 
           p.price * (1 - a.discount_rate) AS discounted_price,
           a.description AS description, a.discount_rate AS discount_rate
    ORDER BY p.price DESC
    """
    
    with driver.session(database=DATABASE) as session:
        result = session.run(query)
        data = []
        for record in result:
            data.append({
                "id": record["id"],
                "name": record["name"],
                "original_price": record["original_price"],
                "discounted_price": int(record["discounted_price"]),
                "description": record["description"],
                "discount_rate": record["discount_rate"]
            })
        return {"status": "success", "data": data}

@app.get("/api/query/family")
def get_family_plans():
    """Find family-related benefits."""
    if not driver:
        raise HTTPException(status_code=500, detail="Database not connected")
        
    query = """
    MATCH (p:Plan)-[:REQUIRES]->(co:Condition {condition_type: 'Family'})-[:PROVIDES]->(b:Benefit)
    RETURN p.id as id, p.name AS name, co.description AS condition, b.description AS benefit
    ORDER BY p.price DESC
    """
    
    with driver.session(database=DATABASE) as session:
        result = session.run(query)
        data = []
        for record in result:
            data.append({
                "id": record["id"],
                "name": record["name"],
                "condition": record["condition"],
                "benefit": record["benefit"]
            })
        return {"status": "success", "data": data}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="127.0.0.1", port=8000, reload=True)
