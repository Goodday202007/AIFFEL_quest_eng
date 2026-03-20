// LG U+ 5G Plan Graph Schema Prototype - Neo4j 5.x
// Extended by Input 1 and Input 2 (Detailed Plan Data)

// -----------------------------------------------------------------------------
// 0. Database cleanup (Optional)
// MATCH (n) DETACH DELETE n;
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// 1. Node Constraints (Neo4j 5.x Syntax)
// -----------------------------------------------------------------------------
CREATE CONSTRAINT plan_id IF NOT EXISTS FOR (p:Plan) REQUIRE p.id IS UNIQUE;
CREATE CONSTRAINT category_id IF NOT EXISTS FOR (c:PlanCategory) REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT benefit_id IF NOT EXISTS FOR (b:Benefit) REQUIRE b.id IS UNIQUE;
CREATE CONSTRAINT condition_id IF NOT EXISTS FOR (c:Condition) REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT ott_id IF NOT EXISTS FOR (o:OTTService) REQUIRE o.id IS UNIQUE;
CREATE CONSTRAINT age_discount_id IF NOT EXISTS FOR (a:AgeDiscount) REQUIRE a.id IS UNIQUE;

// -----------------------------------------------------------------------------
// 2. Indexes
// -----------------------------------------------------------------------------
CREATE INDEX plan_name IF NOT EXISTS FOR (p:Plan) ON (p.name);
CREATE INDEX category_name IF NOT EXISTS FOR (c:PlanCategory) ON (c.category_name);

// -----------------------------------------------------------------------------
// 3. Input 2: Detailed Plan Sample Data Injection
// -----------------------------------------------------------------------------

// --- Categories ---
MERGE (c1:PlanCategory {id: 'cat_5g_device', category_name: '5G 단말기', description: '일반 5G 단말기 라인업'})
MERGE (c2:PlanCategory {id: 'cat_5g_premier', category_name: '5G 프리미어', description: '프리미엄 혜택이 포함된 5G 라인업'})

// --- Conditions (조건) ---
MERGE (cond_family:Condition {id: 'cond_family_2', condition_type: 'FAMILY_BOND', value: '2', description: '2회선 이상 가족 결합 (데이터 2배)'})
MERGE (cond_contract:Condition {id: 'cond_contract_25', condition_type: 'CONTRACT', value: '24', description: '선택약정 25% 할인 (24개월)'})
MERGE (cond_share:Condition {id: 'cond_data_share', condition_type: 'DATA_SHARE', value: '2', description: '보조기기 2회선 무료'})
MERGE (cond_age_34:Condition {id: 'cond_age_34', condition_type: 'AGE', value: '34', description: '만 34세 이하'})

// --- Age Discount (조건형 혜택) ---
MERGE (age_34:AgeDiscount {id: 'age_34_under', min_age: 0, max_age: 34, discount_rate: 0.0, description: '만 34세 이하 특정 혜택제공'})

// --- Benefits (혜택) ---
MERGE (b_ott_2:Benefit {id: 'ben_ott_2', benefit_type: 'OTT', description: 'OTT 팩 2개 선택 가능', value: '2'})
MERGE (b_ott_1:Benefit {id: 'ben_ott_1', benefit_type: 'OTT', description: 'OTT 팩 1개 선택 가능', value: '1'})
MERGE (b_smart_2:Benefit {id: 'ben_smart_2', benefit_type: 'DEVICE', description: '스마트기기 2회선 무료', value: '2'})
MERGE (b_data_double:Benefit {id: 'ben_data_double', benefit_type: 'DATA', description: '가족 결합 시 데이터 2배 제공', value: 'x2'})
MERGE (ben_age_discount:Benefit {id: 'ben_age_discount', benefit_type: 'DISCOUNT', description: '나이 할인 혜택', value: 'custom'})

// --- OTT Services ---
MERGE (ott_net:OTTService {id: 'ott_netflix', service_name: 'Netflix', provider: 'Netflix'})
MERGE (ott_dis:OTTService {id: 'ott_disney', service_name: 'Disney+', provider: 'Disney'})
MERGE (ott_wav:OTTService {id: 'ott_wavve', service_name: 'Wavve', provider: 'Wavve'})

// --- Plans (요금제 4종) ---
// 1. 5G 시그니처
MERGE (p_sig:Plan {
  id: 'plan_5g_sig', name: '5G 시그니처', price: 130000, 
  data_limit: -1, is_data_unlimited: true, voice_limit: '-1',
  shared_data: '60GB+60GB', tethering_limit_gb: 0, roaming_discount_rate: 0.5
})
// 2. 5G 프리미어 슈퍼
MERGE (p_pre_super:Plan {
  id: 'plan_5g_pre_super', name: '5G 프리미어 슈퍼', price: 115000, 
  data_limit: -1, is_data_unlimited: true, voice_limit: '-1',
  shared_data: '50GB+50GB', tethering_limit_gb: 0, roaming_discount_rate: 0.0
})
// 3. 5G 프리미어 에센셜
MERGE (p_pre_ess:Plan {
  id: 'plan_5g_pre_ess', name: '5G 프리미어 에센셜', price: 95000, 
  data_limit: 40, is_data_unlimited: false, voice_limit: '-1',
  shared_data: '', tethering_limit_gb: 10, roaming_discount_rate: 0.0
})
// 4. 5G 스탠다드
MERGE (p_std:Plan {
  id: 'plan_5g_std', name: '5G 스탠다드', price: 75000, 
  data_limit: 30, is_data_unlimited: false, voice_limit: '-1',
  shared_data: '', tethering_limit_gb: 5, roaming_discount_rate: 0.0
})

// -----------------------------------------------------------------------------
// 4. Edges (Relationships)
// -----------------------------------------------------------------------------
// [시그니처]
MERGE (p_sig)-[:BELONGS_TO]->(c1)
MERGE (p_sig)-[:INCLUDES]->(b_ott_2)
MERGE (p_sig)-[:INCLUDES]->(b_smart_2)
MERGE (p_sig)-[:REQUIRES]->(cond_contract)
MERGE (p_sig)-[:REQUIRES]->(cond_family)
MERGE (p_sig)-[:REQUIRES]->(cond_share)
MERGE (p_sig)-[:OFFERS]->(ott_net)
MERGE (p_sig)-[:OFFERS]->(ott_dis)
MERGE (p_sig)-[:OFFERS]->(ott_wav)
MERGE (p_sig)-[:ELIGIBLE_FOR]->(age_34)

// [프리미어 슈퍼]
MERGE (p_pre_super)-[:BELONGS_TO]->(c2)
MERGE (p_pre_super)-[:INCLUDES]->(b_ott_1)
MERGE (p_pre_super)-[:REQUIRES]->(cond_contract)
MERGE (p_pre_super)-[:REQUIRES]->(cond_family)
MERGE (p_pre_super)-[:REQUIRES]->(cond_share)
MERGE (p_pre_super)-[:OFFERS]->(ott_net)
MERGE (p_pre_super)-[:OFFERS]->(ott_dis)
MERGE (p_pre_super)-[:OFFERS]->(ott_wav)
MERGE (p_pre_super)-[:ELIGIBLE_FOR]->(age_34)

// [프리미어 에센셜]
MERGE (p_pre_ess)-[:BELONGS_TO]->(c2)
MERGE (p_pre_ess)-[:REQUIRES]->(cond_contract)
MERGE (p_pre_ess)-[:REQUIRES]->(cond_family)
MERGE (p_pre_ess)-[:ELIGIBLE_FOR]->(age_34)

// [스탠다드]
MERGE (p_std)-[:BELONGS_TO]->(c2)
MERGE (p_std)-[:REQUIRES]->(cond_contract)
MERGE (p_std)-[:REQUIRES]->(cond_family)
MERGE (p_std)-[:ELIGIBLE_FOR]->(age_34)

// -----------------------------------------------------------------------------
// 5. Input 3: Natural Language Advanced Relationships
// -----------------------------------------------------------------------------
// 1. 나이 조건과 할인 혜택 간의 관계 추가
MERGE (cond_age_34)-[:PROVIDES]->(ben_age_discount)

// 2. 가족 결합 조건과 데이터 보너스 관계 추가
MERGE (cond_family)-[:PROVIDES]->(b_data_double)

// 3. 요금제 등급(카테고리)과 쉐어링 혜택 간의 계층 구조 연결
MERGE (c1)-[:PROVIDES_BENEFIT]->(b_smart_2)
MERGE (c2)-[:PROVIDES_BENEFIT]->(b_smart_2)

// -----------------------------------------------------------------------------
// 6. Input 4: Structured Data (Table) Population
// -----------------------------------------------------------------------------
// 표 형식의 데이터를 입력받았을 때, 일괄 데이터 생성을 위한 명시적 CREATE 구문 예제입니다.
// CSV 로드 등 배치 작업 시 아래와 같이 속성 매핑을 구성합니다.
/*
CREATE (p1:Plan {id: 'csv_p1', name: '5G 시그니처', price: 130000, data_limit: -1, is_data_unlimited: true, shared_data: '60GB+60GB'});
CREATE (p2:Plan {id: 'csv_p2', name: '5G 프리미어 슈퍼', price: 115000, data_limit: -1, is_data_unlimited: true, shared_data: '50GB+50GB'});
CREATE (p3:Plan {id: 'csv_p3', name: '5G 프리미어 에센셜', price: 95000, data_limit: 40, is_data_unlimited: false, shared_data: ''});
CREATE (p4:Plan {id: 'csv_p4', name: '5G 스탠다드', price: 75000, data_limit: 30, is_data_unlimited: false, shared_data: ''});
*/

