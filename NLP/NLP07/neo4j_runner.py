import os
import sys
from dotenv import load_dotenv
from neo4j import GraphDatabase

def main():
    env_path = r'd:\python_2025-26\practise\telco-graph-prototype\.env'
    if not os.path.exists(env_path):
        print(f"Error: .env not found at {env_path}")
        sys.exit(1)

    load_dotenv(env_path)
    
    uri = os.environ.get("NEO4J_URI")
    user = os.environ.get("NEO4J_USERNAME")
    password = os.environ.get("NEO4J_PASSWORD")
    database = os.environ.get("NEO4J_DATABASE", "neo4j") # Default to neo4j for Aura

    if not all([uri, user, password]):
        print("Error: Missing Neo4j credentials in .env")
        sys.exit(1)

    print(f"Connecting to {uri} (Database: {database})")
    
    try:
        driver = GraphDatabase.driver(uri, auth=(user, password))
        driver.verify_connectivity()
        print("Successfully connected to Neo4j.")
    except Exception as e:
        print(f"Connection failed: {e}")
        sys.exit(1)

    # 1. Execute schema.cypher
    schema_path = r'd:\python_2025-26\practise\telco-graph-prototype\schema.cypher'
    with open(schema_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split by semicolon. The huge MERGE block has no semicolons, so it runs entirely as one transaction!
    statements = [s.strip() for s in content.split(';') if s.strip()]
    
    with driver.session(database=database) as session:
        print("Executing schema.cypher...")
        for i, stmt in enumerate(statements):
            try:
                # Strip pure comment blocks so we don't send empty queries
                lines = [l for l in stmt.split('\n') if not l.strip().startswith('//') and not l.strip().startswith('/*')]
                clean_stmt = '\n'.join(lines).strip()
                if not clean_stmt:
                    continue
                
                print(f"  Executing block {i+1} ({len(clean_stmt)} chars)...")
                session.run(clean_stmt)
            except Exception as e:
                print(f"Error executing statement block {i+1}:\n{e}")

        print("Schema execution complete.")

        # 2. Run sample queries
        print("Running sample querying...")
        q1 = "MATCH (p:Plan)-[:BELONGS_TO]->(c:PlanCategory {category_name: '5G 프리미어'}) RETURN p.name AS PlanName, p.price AS Price"
        q2 = "MATCH (p:Plan)-[:ELIGIBLE_FOR]->(a:AgeDiscount) WHERE a.max_age <= 34 RETURN p.name AS PlanName, a.description AS DiscountInfo"
        
        result_md = "# Neo4j Aura Test Results\n\n"
        result_md += "## 1. 5G 프리미어 카테고리에 속한 모든 요금제\n"
        result_md += "| PlanName | Price |\n|---|---|\n"
        res1 = session.run(q1)
        for record in res1:
            result_md += f"| {record['PlanName']} | {record['Price']} |\n"
            
        result_md += "\n## 2. 만 34세 이하 할인이 가능한 요금제\n"
        result_md += "| PlanName | DiscountInfo |\n|---|---|\n"
        res2 = session.run(q2)
        for record in res2:
            result_md += f"| {record['PlanName']} | {record['DiscountInfo']} |\n"

    driver.close()
    
    out_file = r'd:\python_2025-26\practise\telco-graph-prototype\neo4j_test_results.md'
    with open(out_file, 'w', encoding='utf-8') as f:
        f.write(result_md)
        
    print(f"Test queries executed successfully. Results saved to {out_file}")

if __name__ == '__main__':
    main()
