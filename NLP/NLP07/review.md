# Schema 리뷰 결과 (Checklist)

이 문서는 `prototyping.md` 내부의 **예상 출력 (Expected Output)** 스펙을 기준으로, 작성된 3개의 파일(`schema.cypher`, `schema_spanner.ddl`, `README.md`)의 정합성을 점검한 리뷰 리포트입니다.

## 1. 노드(엔티티) 및 속성 점검

원문 요구 스펙: `Plan`, `PlanCategory`, `Benefit`, `Condition`, `OTTService`, `AgeDiscount` 총 6개 노드.

- [x] **`schema_spanner.ddl` 및 `schema.cypher`**: 6개의 노드와 속성(id, name, price, 등)이 모두 완벽히 스펙에 부합하게 구현되어 있음. (Input 2,4 요구사항을 대응하며 일부 추가 확장 컬럼이 삽입된 것은 정상적인 확장임)
- [x] **`README.md` (Mermaid 다이어그램 시각화 한정)**: DDL이나 Cypher에는 존재하는 속성들이 다이어그램 표현 간소화로 인해 일부 누락되어 불일치함 발견. (수정 완료)
  - `AgeDiscount`: `min_age`, `max_age` 표기 추가 완료
  - `Benefit`: `description`, `value` 표기 추가 완료
  - `Condition`: `description`, `value` 표기 추가 완료
  - `PlanCategory`: `description` 표기 추가 완료
  - `OTTService`: `provider` 표기 추가 완료

## 2. 엣지(관계) 및 방향 점검

원문 요구 스펙: 5개의 핵심 Edge (`BELONGS_TO`, `INCLUDES`, `REQUIRES`, `OFFERS`, `ELIGIBLE_FOR`)

- [x] **관계 명칭(Label) 일치**: 요구된 명칭이 모든 파일에서 100% 동일하게 사용됨.
- [x] **방향(Direction) 일치**: `Plan`을 시작점(Source)으로 각 외부 정책 엔티티(Destination)를 향하는 단방향 화살표가 `schema.cypher`(`p-[]->t`)와 `schema_spanner.ddl`(`SOURCE KEY / DESTINATION KEY`)에서 완벽히 일치하게 적용됨.
- [x] **추가 확장 관계 정상 동작**: Input 3을 위해 추가한 `Condition -[PROVIDES]-> Benefit` 및 `PlanCategory -[PROVIDES_BENEFIT]-> Benefit`가 기존 스키마를 망가뜨리지 않고 성공적으로 병합되어 있음.

## 3. 기타 스키마 타입 및 DDL 제약 점검

- [x] **ID 규칙**: 6개 노드 모두 `STRING(36)` 또는 UUID로 적합하게 설계/강제화됨.
- [x] **제약 조건**: Neo4j의 5.x `CREATE CONSTRAINT` 문법과 Spanner의 `FOREIGN KEY` 결합이 스펙 문서의 의도를 초과 달성함.

---
### 💡 수정 권고사항 (Action Items)
- `schema.cypher` 및 `schema_spanner.ddl`은 스펙 누락이나 관계 오류 없이 매우 우수합니다. (수정 불필요)
- 단, **`README.md`의 Mermaid ER 다이어그램 속성** 부분만 `schema_spanner.ddl`의 전체 스펙과 1:1로 일치할 수 있도록 보강 업데이트를 진행해 주면 프로토타입의 문서 정합성이 100%가 됩니다.
