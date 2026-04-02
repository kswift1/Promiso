---
name: rust-learn
description: Firebase → Rust 서버 마이그레이션 기록 (구현 + 블로그 포스팅)
---

# /rust-learn $ARGUMENTS

Firebase 백엔드를 Rust 서버로 마이그레이션하는 과정을 **구현하면서 기록**합니다.
토픽을 받아 **설계 → 기술 결정(ADR) → 구현 → 블로그 포스팅**을 한 사이클로 진행합니다.

## 실행 전 준비

1. `docs/blog/00-roadmap.md`를 읽어 현재 진행 상태 확인
2. `$ARGUMENTS`로 받은 토픽이 로드맵의 어느 Phase/Step에 해당하는지 파악
3. 이전 포스트가 있으면 마지막 포스트를 읽어 연속성 확인

## 실행 흐름

### Step 1 — 설계 & 조사

마이그레이션 대상을 분석합니다:

- **기존 Firebase 코드 확인**: 해당 토픽의 Firebase 구현을 탐색 (Functions, Firestore 규칙, iOS Client)
- **Rust 대체 설계**: 어떻게 바꿀 것인지 설계 (데이터 모델, API 스펙, 인프라)
- **Swift ↔ Rust 대응**: Rust 문법이 처음 등장하면 Swift 비교로 설명 (유저가 Swift 시니어)
- **트레이드오프 논의**: Firebase 방식 vs 직접 구현 방식의 차이, 얻는 것과 잃는 것

유저와 설계를 합의한 후 다음 단계로 진행합니다.

### Step 2 — 기술 결정 (ADR)

해당 토픽에서 기술 선택이 필요하면 `docs/adr/` 에 ADR을 작성합니다.

**ADR이 필요한 경우**: 라이브러리, 서비스, 아키텍처 패턴 등 2개 이상의 선택지가 있을 때
**ADR이 불필요한 경우**: 이전 ADR에서 이미 결정됨, 또는 사실상 선택지가 1개일 때

**ADR 작성 규칙**:
- `docs/adr/000-template.md` 포맷을 따름
- 파일명: `{순번}-{slug}.md` (예: `002-axum-over-actix.md`)
- **반드시 6가지 평가 기준으로 비교** (해당 결정 맥락에서 가중치 조정):
  1. 스케일 비용
  2. 확장성
  3. 안정성
  4. 락인
  5. 성능
  6. 안전성
- 러닝커브, DX, 문서 품질은 평가 기준에서 제외 (AI 활용 전제)
- **유저에게 비교표를 보여주고, 유저가 이해한 후 결정을 확정**한다. Claude가 일방적으로 결정하지 않음.

### Step 3 — 구현

`infra/rust-backend/` 에 실제 코드를 작성합니다:

- Rust 프로젝트가 없으면 `cargo init` 으로 생성
- Firebase의 해당 기능을 Rust로 대체 구현
- **메인 Claude가 직접 작성** (Rust 코드는 implementer 위임 예외)
- 새로 등장하는 Rust 개념은 코드 옆에서 바로 설명
- 작성 후 `cargo check` 또는 `cargo build`로 검증

### Step 4 — 블로그 포스팅

`docs/blog/` 에 Medium 형식 마크다운을 생성합니다:

**파일명 규칙**: `{순번}-{slug}.md` (예: `01-why-leave-firebase.md`)

**Medium 포맷 규칙**:
- 제목: `# Firebase에서 Rust로 — {부제}`
- 시리즈명: "Firebase에서 Rust로: iOS 앱 서버 마이그레이션기"
- 도입부: 이번 편에서 해결할 문제가 뭔지 (Firebase에서 어떻게 했고, 왜 바꾸는지)
- 본문 구조:
  - **Before (Firebase)**: 기존에 어떻게 동작했는지
  - **설계 결정**: 왜 이렇게 바꾸기로 했는지 (ADR 참조)
  - **After (Rust)**: 실제 구현 코드와 설명
  - **비교**: 바꾸고 나서 뭐가 달라졌는지
- 짧은 문단 (2-3문장), 풍부한 코드 예제
- Rust 문법이 처음 나오면 Swift 비교 박스로 설명
- 기술 선택이 있었으면 비교 과정을 독자에게도 공유 (ADR 요약)
- 핵심 인사이트는 인용 블록(`>`)으로 강조
- 마무리: 이번 편 요약 + 다음 편 예고
- 하단: `---` + 시리즈 목차

**톤/스타일**: `docs/blog/STYLE_GUIDE.md`를 따른다.

### Step 5 — 로드맵 업데이트

`docs/blog/00-roadmap.md`에서 완료된 항목을 `[x]`로 체크합니다.

## 참고 자료

- Promiso Firestore 스키마: `.ai/FIRESTORE_SCHEMA.md`
- 현재 Firebase Functions: `infra/firebase/functions/src/`
- iOS Client 레이어: `Projects/Clients/Sources/`
- Rust 프로젝트: `infra/rust-backend/`
- 기술 결정 기록: `docs/adr/`
- ADR 템플릿: `docs/adr/000-template.md`

## 주의사항

- Rust 코드 작성은 `.claude/CLAUDE.md`의 "S 이상 implementer 위임" 규칙의 예외
- iOS 코드 (Projects/) 수정이 필요한 경우는 기존 워크플로우를 따름
