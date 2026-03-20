# LG U+ 5G Plan Graph DB - Conceptual Design

이 문서는 `prototyping.md`의 **입력 방법 1 (간단한 요구사항)** 과 **입력 방법 3 (자연어 요구사항 방침)** 을 바탕으로 작성된 그래프 DB 개념 설계서입니다. 현재 구축된 v0 베이스라인 스키마를 훼손하지 않고 확장하는 구조를 정의합니다.

## 1. 요구사항 분석 (Input 1 매핑)

**엔티티 (Entities):**
- 요금제 (`Plan`): 이름(name), 가격(price), 데이터 제공량(data_limit), 음성 제공량(voice_limit)
- 요금제 카테고리 (`PlanCategory`): 5G 단말기, 5G 프리미어 등
- 혜택 (`Benefit`): OTT 서비스, 데이터 추가 등
- 가입 조건 (`Condition`): 나이 제한, 약정 기간 등

**관계 (Relationships):**
- `Plan` -> `[BELONGS_TO]` -> `PlanCategory`
- `Plan` -> `[INCLUDES]` -> `Benefit`
- `Plan` -> `[REQUIRES]` -> `Condition`

## 2. v0 베이스라인 비교 및 개선 포인트

1. **누락된 핵심 속성 추가**: Input 1에 명시된 `Plan`의 **"음성 제공량(voice_limit)"** 속성이 v0 스키마에 추가되었습니다.
2. **개념적 포괄성 확보**: v0 베이스라인은 `Benefit`, `Condition` 뿐 아니라 `OTTService` 및 정형화된 `AgeDiscount` 등을 구별하여 복잡한 로직을 포괄하도록 설계되었습니다.

## 3. 핵심 아키텍처 원칙 (Conceptual Mapping)

* **유연성 강화**: OTT 팩은 사용자가 선택할 수 있으므로, 단순 `Benefit` 대신 `OTTService` 단위로 독립된 노드를 만들어 연결합니다.
* **약정 기간 등**: 데이터 필터링 성능을 고려하여 `Condition` 노드 외에도 `Plan` 자체의 필수 속성(`contract_period_months`)으로 이중화하는 것을 허용합니다.

## 4. 능동적 관계 설계 (Input 3 매핑 추가)

단순한 엔티티->엔티티(Plan->Benefit)의 단순 형태를 넘어, 특정 요구사항을 처리하기 위해 **조건(Condition)과 카테고리(PlanCategory) 자체**가 **혜택(Benefit)** 을 능동적으로 부여(`PROVIDES`)하는 패턴을 확장합니다.

1. **나이 조건 → 할인 혜택**: 기존 `AgeDiscount` 엔티티 대신 범용적인 처리를 위해 `Condition(나이조건) -[PROVIDES]-> Benefit(할인)` 관계를 추가하여 자연어("만 34세 이하 할인 혜택 구조를 설계해줘")에 완벽히 대응합니다.
2. **가족 결합 → 데이터 보너스**: `Condition(가족결합) -[PROVIDES]-> Benefit(데이터 2배)` 로 명시적 관계를 생성하여, 결합 시 얻는 혜택의 인과결과를 그래프 트리로 순회할 수 있게 합니다.
3. **요금제 등급 → 쉐어링 보조기기 혜택**: 개별 Plan 단위가 아니라, `PlanCategory(시그니처/프리미어) -[PROVIDES_BENEFIT]-> Benefit(스마트기기 2회선)` 로 계층적인 상속 구조를 명시합니다.
4. **OTT 서비스 명확화**: 이미 정의된 `Plan -[OFFERS]-> OTTService` 다대다 연결을 통해 요금제별 OTT 선택 가능 여부를 해결합니다.
