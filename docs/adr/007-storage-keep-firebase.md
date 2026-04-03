# ADR-007: 전환 기간 이미지 스토리지는 Firebase Storage 유지

## 상태

확정

## 맥락

프로필 이미지, 그룹 이미지 등의 파일 저장소를 어떻게 할지 결정해야 한다.

현재 흐름:
1. iOS 앱이 Firebase Storage에 이미지 업로드
2. Firebase Functions가 Storage 경로로 다운로드 URL 생성
3. Firestore에 URL 저장

## 비교

| 방법 | 설명 | 구현량 | 위험도 |
|------|------|--------|--------|
| **Firebase Storage 유지** | iOS 업로드 그대로, Rust는 URL/경로만 DB에 저장 | 없음 | 없음 |
| **GCS (Cloud Storage)** | Firebase Storage는 내부적으로 GCS. 직접 접근으로 전환 | 중간 — 서명 URL 생성 로직 | 낮음 |
| **S3 호환 스토리지** | Cloudflare R2, Tigris 등으로 이전 | 높음 — 기존 이미지 마이그레이션 + iOS 업로드 로직 변경 | 중간 |

## 결정

**전환 기간 동안 Firebase Storage를 그대로 사용한다.**

Rust 서버에서의 처리:
- 이미지 업로드: iOS → Firebase Storage (기존 그대로)
- Rust API: iOS가 전달한 Storage 경로/URL을 PostgreSQL에 저장만 함
- 이미지 조회: 클라이언트가 Firebase Storage URL로 직접 다운로드 (기존 그대로)

Rust 서버는 이미지 파일 자체를 다루지 않는다. 메타데이터(경로, URL)만 관리한다.

### 스토리지 이전 시점

Firebase 의존성 완전 제거 단계에서 별도 ADR로 결정한다. Firebase Storage는 내부적으로 GCS이므로, GCP 생태계 내 전환은 비교적 수월하다.

## 결과

- **얻는 것**: 이미지 관련 iOS/서버 변경 제로, 도메인 마이그레이션에 집중 가능
- **잃는 것**: Firebase Storage 의존성 지속 (전환 기간 한정), Storage 비용 별도 발생
- **후속 결정**: Firebase 완전 제거 시 GCS 직접 접근 또는 대체 스토리지 선택
