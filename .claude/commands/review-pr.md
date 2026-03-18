---
name: review-pr
description: PR 또는 현재 변경사항 코드 리뷰
---

# /review-pr $ARGUMENTS

현재 브랜치의 변경사항 또는 특정 PR을 리뷰합니다.

> 먼저 `.ai/AI_WORKFLOW.md`를 읽고 따른다. 이 파일은 작업별 규칙만 정의한다.

## 실행 순서

1. 변경된 파일 목록 확인
2. **reviewer** 에이전트로 각 파일 검토 (코드 품질 + Firebase 비용 + 보안 통합)
3. 리뷰 결과 종합 보고

## 사용 예시

```bash
# 현재 브랜치 변경사항 리뷰
/review-pr

# 특정 PR 리뷰
/review-pr 123

# 특정 파일만 리뷰
/review-pr --file Projects/Features/HomeFeature/Sources/HomeView.swift
```

## 리뷰 기준

### TCA 패턴
- State/Action 구조
- Effect 처리
- Dependency 주입

### Swift 컨벤션
- 강제 언래핑 금지
- async/await 사용
- 메모리 관리

### UI/UX
- iOS 26 Glass Effect
- Fallback 구현
- 접근성

### 보안
- 민감 정보 노출
- 적절한 권한 검사

### Firebase 비용 (해당 시)
- N+1 쿼리 패턴
- 불필요한 실시간 리스너
- 캐시 미활용
- Storage 썸네일 미사용

## Firebase 비용 분석 트리거

다음 경로의 파일이 변경되면 **firebase-cost-advisor** 실행:
- `Projects/Clients/Sources/Data/DataSources/*`
- `Projects/Features/*/Sources/*` (Firestore/Storage 사용 시)
- `infra/firebase/functions/src/*`

## 출력 형식

```markdown
## PR 리뷰 결과

### 변경 파일 수: N개

### 파일별 리뷰
#### 1. {파일명}
- 🔴 Critical: N건
- 🟡 Warning: N건
- 🟢 Suggestion: N건

### Firebase 비용 분석 (해당 시)
- 🔴 비용 Critical: N건
- 🟡 비용 Warning: N건
- 예상 절감 효과: {내용}

### 전체 요약
- 승인 가능 여부: ✅ / ❌
- 필수 수정 사항: {내용}
```
