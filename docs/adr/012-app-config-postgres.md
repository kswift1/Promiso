# ADR-012: 앱 운영 설정은 PostgreSQL app_config + Public Endpoint로 제공한다

## 상태

확정

## 맥락

현재 앱 운영 설정은 Firebase Remote Config에서 읽는다.

사용 중인 주요 필드:

- `forceUpdateVersion`
- `recommendedVersion`
- `appStoreURL`
- `privacyPolicyURL`
- `termsOfServiceURL`
- `supportEmail`
- `notionFAQDatabaseId`

이번 cutover에서는 legacy backend Firebase에서 `Remote Config`도 제거 대상이다. 동시에 강제 업데이트는 big-bang cutover 안전장치 역할을 하므로, 배포 없이 값을 바꿀 수 있는 운영 경로가 필요하다.

## 평가 기준

| 기준 | 가중치 | 설명 |
|------|--------|------|
| 스케일 비용 | 낮음 | 트래픽이 작아도 불필요한 운영비를 만들지 않는가 |
| 확장성 | 중간 | 설정 키 추가, 다국어/환경별 값 확장 용이성 |
| 안정성 | 높음 | 잘못된 값 배포, 캐시 무효화, 강제 업데이트 즉시 반영 |
| 락인 | 중간 | 특정 서비스 종속 없이 운용 가능한가 |
| 성능 | 중간 | 앱 시작 시 설정 조회 비용 |
| 안전성 | 중간 | 잘못된 수정 권한, 스키마 오염 방지 |

## 비교

| 기준 | ENV 기반 정적 config | PostgreSQL `app_config` + Public GET | CDN/정적 JSON |
|------|------------------------|--------------------------------------|----------------|
| 스케일 비용 | 낮음 | 낮음 | 낮음 |
| 확장성 | 중간 — 키 추가는 쉬우나 운영 변경은 배포 필요 | 높음 — 값 변경, 키 추가, 관리 API 확장 가능 | 중간 — 구조는 단순하지만 스키마 제약이 약함 |
| 안정성 | 중간 — 강제 업데이트 변경마다 배포 필요 | 높음 — 배포 없이 값 변경 가능, DB/서버 캐시로 제어 가능 | 중간 — 캐시 무효화, 배포 타이밍이 애매 |
| 락인 | 낮음 | 낮음 | 중간 — CDN/스토리지 운영 방식 의존 |
| 성능 | 높음 — 프로세스 메모리 값 | 높음 — 단건 조회 + 서버 캐시로 충분 | 높음 — 정적 파일 fetch |
| 안전성 | 높음 — 수정 경로가 좁음 | 높음 — 스키마와 권한으로 제어 가능 | 중간 — 잘못된 JSON 배포 시 검증 약함 |

## 결정

**앱 운영 설정은 PostgreSQL의 `app_config` 테이블을 source of truth로 두고, Rust public endpoint가 이를 제공한다.**

구체 원칙:

- 앱은 `GET /api/v1/app-config` 같은 public endpoint에서 설정을 조회한다.
- 서버는 `app_config` 값을 읽어 `AppConfigModel`과 동일한 형태로 응답한다.
- 강제 업데이트/권장 업데이트 값은 배포 없이 변경 가능해야 한다.
- 서버는 짧은 캐시를 둘 수 있지만, 운영자가 강제 업데이트를 올렸을 때 빠르게 반영되어야 한다.
- 관리 쓰기 경로는 초기에는 SQL/manual update로 시작할 수 있고, 필요 시 admin API를 추가한다.

이 결정을 선택한 이유:

- big-bang cutover 시 강제 업데이트 값은 운영자가 즉시 조정할 수 있어야 한다.
- ENV 방식은 단순하지만 매번 재배포가 필요하다.
- CDN/정적 JSON은 단순하지만 수정 권한, 캐시, 검증 체계가 DB보다 약하다.

## 결과

이 결정으로 인해:

- **얻는 것**:
  - Firebase Remote Config 없이도 강제 업데이트와 운영 설정을 관리할 수 있다
  - 앱 설정을 Rust 경계 안으로 가져와 제품 운영 표면을 일원화할 수 있다
  - 추후 admin API를 붙여도 DB schema를 그대로 재사용할 수 있다
- **잃는 것**:
  - `app_config` 스키마와 public endpoint를 새로 구현해야 한다
  - 운영자가 값을 잘못 수정했을 때 검증/감사 장치를 별도로 마련해야 한다
- **후속 결정**:
  - `app_config`를 단일 row로 둘지 key-value로 둘지
  - 서버 캐시 TTL과 캐시 무효화 방식
  - admin 수정 경로를 API로 열지 수동 SQL로 유지할지
