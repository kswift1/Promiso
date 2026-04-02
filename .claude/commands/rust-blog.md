---
name: rust-blog
description: Firebase → Rust 마이그레이션 블로그 포스트 작성
---

# /rust-blog $ARGUMENTS

마이그레이션 과정을 블로그 포스트로 작성합니다.
`$ARGUMENTS`에 포스트 번호(예: "#1") 또는 주제를 받습니다.

## 실행 전 준비

1. `docs/blog/00-roadmap.md`를 읽어 현재 진행 상태 확인
2. `docs/blog/STYLE_GUIDE.md`를 읽어 톤/스타일 확인
3. 이전 포스트가 있으면 마지막 포스트를 읽어 연속성 확인
4. 해당 주제의 ADR이 있으면 `docs/adr/` 에서 읽기

## 실행 흐름

### Step 1 — 소재 수집

해당 포스트에서 다룰 내용을 정리한다:

- 관련 ADR (기술 선택 비교표, 결정 근거)
- 실제 구현된 코드 (`infra/rust-backend/`)
- 기존 Firebase 코드 (비교용)
- 마이그레이션 중 발생한 이슈/삽질

### Step 2 — 초안 작성 (한글, velog용)

`docs/blog/` 에 마크다운 파일을 생성한다:

**파일명 규칙**: `{순번}-{slug}.md` (예: `01-why-leave-firebase.md`)

**구조**:
- 제목: `# Firebase에서 Rust로 — {부제}`
- 시리즈명: "Firebase에서 Rust로: iOS 앱 서버 마이그레이션기"
- 도입부: 훅으로 시작 (구체적인 경험/사건/문제)
- 본문:
  - **Before (Firebase)**: 기존에 어떻게 동작했는지
  - **설계 결정**: 왜 이렇게 바꾸기로 했는지 (ADR 요약)
  - **After (Rust)**: 실제 구현 코드와 설명
  - **비교**: 바꾸고 나서 뭐가 달라졌는지
- Rust 문법이 처음 나오면 Swift 비교 박스로 설명
- 하단: 이전/다음 글 링크 (시리즈 목차는 넣지 않음)
- 이미지 필요한 위치에 `[IMAGE: 설명]` 플레이스홀더 삽입

**톤/스타일**: `docs/blog/STYLE_GUIDE.md`를 반드시 따른다.

### Step 3 — 이미지

글에 삽입할 이미지를 준비한다:

- **비교표**: Medium은 마크다운 표를 지원하지 않으므로, 비교표는 Mermaid 코드 또는 이미지로 제공
- **아키텍처 다이어그램**: Mermaid 코드로 작성 → 유저가 렌더링
- **썸네일/삽화**: 설명을 작성 → 유저가 Canva 또는 AI 이미지 도구로 생성
- 이미지 파일은 `docs/blog/images/{순번}/` 에 저장

### Step 4 — 유저 리뷰

한글 초안 + 이미지를 유저에게 보여주고 피드백을 받는다.
피드백 반영 후 한글 최종본 확정.

### Step 5 — 영어 번역 (Medium용)

한글 최종본을 영어로 번역한다:

- 파일: `{순번}-{slug}.en.md` (예: `01-why-leave-firebase.en.md`)
- `docs/blog/STYLE_GUIDE.md`의 **영어 버전** 섹션을 따른다
- 시리즈명: "From Firebase to Rust: An iOS App Server Migration"
- 직역이 아닌 영어권 독자에 맞게 자연스럽게 번역
- 한국 특화 맥락 (서울 리전 등)은 유지하되 보편적으로 이해 가능하게
- 코드 블록은 동일, 주석만 영어로
- **Medium은 마크다운 표를 지원하지 않으므로**, 비교표는 이미지로 대체하거나 코드 블록으로 포맷

### Step 6 — 로드맵 업데이트

`docs/blog/00-roadmap.md`에서 완료된 항목을 `[x]`로 체크한다.

## 참고 자료

- 블로그 로드맵: `docs/blog/00-roadmap.md`
- 스타일 가이드: `docs/blog/STYLE_GUIDE.md`
- ADR 기록: `docs/adr/`
- Rust 프로젝트: `infra/rust-backend/`
- Firebase Functions: `infra/firebase/functions/src/`
