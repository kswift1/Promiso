---
name: verify-changes
description: 변경사항의 크로스 레이어 정합성 검증 (클라이언트-서버 인터페이스, 레이어 관통, 리소스 충돌)
---

# /verify-changes $ARGUMENTS

코드 변경 후 **크로스 레이어 정합성**을 검증합니다.
기존 `/review-pr`이 단일 파일 코드 품질을 보는 반면, 이 스킬은 **파일 간/레이어 간 불일치**를 잡습니다.

## 인자

- `$ARGUMENTS`: 생략 시 현재 브랜치 전체 diff 대상
  - `--base <branch>`: 비교 기준 브랜치 (기본: 최신 release/ 브랜치. `git branch -r | grep 'release/v' | sort -V | tail -1`로 결정)
  - `--files <path>`: 특정 파일/디렉토리만 검증

## 검증 영역 (7개)

### 1. 클라이언트-서버 인터페이스 일치

변경된 파일에 Firebase Functions 호출이 있으면:

```
Swift 호출 파라미터 키 ←→ TypeScript data.키 읽기
```

- `httpsCallable` 호출의 딕셔너리 키 vs 서버 `data.xxx` 파라미터 매칭
- `onRequest` 엔드포인트의 request body 키 vs 서버 `req.body.xxx` 매칭
- 응답 구조체 필드 vs 서버 response 필드 매칭

**검사 방법**:
1. Grep으로 변경된 Swift 파일에서 `httpsCallable`, `FirebaseFunctionNames` 추출
2. 해당 함수명으로 서버 TS 파일에서 `data.xxx` 패턴 추출
3. 키 목록 교차 비교

### 2. APNs Payload 정합성

ActivityKit 관련 변경이 있으면:

```
서버 attributes-type 문자열 ←→ Swift ActivityAttributes 타입명
서버 content-state 필드 ←→ Swift ContentState 프로퍼티
서버 attributes 필드 ←→ Swift Attributes 프로퍼티
```

**검사 방법**:
1. `*.ts` 파일에서 `"attributes-type"` 값 추출
2. Swift `ActivityAttributes` 구현체의 struct 이름과 비교
3. payload의 `attributes` / `content-state` JSON 키와 Swift `CodingKeys` 비교

### 3. 수직 레이어 관통 검증

Protocol → DataSource → Client → Feature 각 레이어에 빠진 구현이 없는지:

```
Protocol에 선언됨 → DataSource에 구현됨 → Client에 프로퍼티 있음 → liveValue 연결됨
```

**검사 방법**:
1. 변경된 Protocol 파일에서 새 메서드 추출
2. 대응하는 DataSource 구현체에서 해당 메서드 존재 확인
3. Client의 struct 프로퍼티 + liveValue/testValue/previewValue 존재 확인
4. 누락 시 Critical 보고

### 4. Firestore 필드 충돌

같은 Firestore 문서/컬렉션의 같은 필드에 여러 기능이 쓰기를 시도하는지:

```
기능 A가 users/{uid}.devices.{deviceId}.liveActivityPushToStartToken에 저장
기능 B도 같은 필드에 다른 값을 저장 → 충돌
```

**검사 방법**:
1. 변경된 서버 코드에서 Firestore `update()`, `set()` 호출의 필드 경로 추출
2. 기존 코드에서 같은 필드를 쓰는 다른 함수가 있는지 Grep
3. 충돌 시 Warning 보고

### 5. 리소스 파일 완전성

Localizable.xcstrings, Assets 등 리소스 파일의 키 누락:

```
LocalizedStrings.swift에서 참조하는 키 ←→ Localizable.xcstrings에 존재
```

**검사 방법**:
1. 변경된 Swift 파일에서 `LocalizedStrings.xxx.yyy` 사용 추출
2. `LocalizedStrings.swift`에서 해당 프로퍼티의 `String(localized:)` 키 추출
3. `Localizable.xcstrings`에 해당 키 존재 확인 (JSON 파싱)
4. 누락 시 Critical 보고

### 6. 리네임 전파 검증

Swift 타입/프로퍼티 리네임 시 모든 참조가 업데이트되었는지:

```
Swift struct 이름 변경 → 서버 문자열 리터럴도 변경?
모델 프로퍼티 이름 변경 → DTO, View, Feature 모두 반영?
```

**검사 방법**:
1. diff에서 `-struct OldName` / `+struct NewName` 패턴으로 리네임 추정
   ```bash
   git diff {base}...HEAD | grep '^-' | grep -oE '(struct|class|enum|protocol) [A-Z][a-zA-Z]+' | awk '{print $2}'
   ```
2. 추출한 이전 이름을 프로젝트 전체에서 Grep (Swift, TS, JSON, entitlements 포함)
3. 문자열 리터럴, 서버 코드, 테스트 코드에 남아있으면 Critical

### 7. 빌드 타겟 포함 검증

새 파일이 올바른 빌드 타겟에 포함되는지:

```
새 Swift 파일 → Tuist sources 경로에 포함?
Widget Extension 파일 → Widget 타겟 sources/**에 포함?
```

**검사 방법**:
1. 새로 추가된 파일 경로 추출
2. `Project.swift`에서 해당 경로가 sources glob(`Sources/**` 등)에 매칭되는지 문자열 비교로 확인
3. 확신할 수 없으면 `tuist generate --no-open` 후 빌드 에러로 확인
4. 미포함 시 Critical 보고

## 실행 순서

### Step 1. 변경사항 수집 (메인 Claude 직접 실행)

메인 Claude가 직접 실행 후 결과를 아래 에이전트들에 전달한다.

```bash
git diff --name-only --diff-filter=ACMR {base}...HEAD
```

변경 파일을 카테고리별로 분류:
- Swift 클라이언트 파일
- TypeScript 서버 파일
- 리소스 파일 (xcstrings, xcassets)
- 설정 파일 (Project.swift, entitlements)

### Step 2. 검증 실행 (메인 Claude가 reviewer 에이전트 병렬 호출)

7개 영역을 **병렬 에이전트**로 실행:
- 에이전트 A: 검증 1, 2 (클라이언트-서버)
- 에이전트 B: 검증 3 (레이어)
- 에이전트 C: 검증 5, 6 (리소스 + 리네임)
- 에이전트 D: 검증 4, 7 (Firestore 충돌 + 빌드 타겟)

각 에이전트는 `reviewer` 타입으로 실행 (읽기 전용). Step 1에서 수집된 파일 목록을 컨텍스트로 전달한다.

### Step 3. 결과 종합

## 출력 형식

### 1. 사람용 요약

```markdown
## 정합성 검증 결과

### Critical (배포 차단)
- [검증 1] ScheduleRemoteDataSource.swift:568 → "promiseId" 키가 서버의 "scheduleId"와 불일치
- [검증 3] ScheduleClient.swift:331 → finalizeVote liveValue 미구현 (TODO throw)

### Warning (확인 필요)
- [검증 4] liveActivity.ts:95 → votePushToStartToken 필드가 startLiveActivity에서도 읽힘 (의도된 것인지 확인)

### Passed
- [검증 2] APNs attributes-type 일치 ✅
- [검증 5] Localizable 키 완전성 ✅
- [검증 6] 리네임 전파 완료 ✅
- [검증 7] 빌드 타겟 포함 ✅

### 요약
- Critical: N건 (배포 전 수정 필수)
- Warning: N건
- 검증 통과: N/7개 영역
```

### 2. 구조화 피드백 (Critical/Warning이 있을 때만 출력)

implementer가 이 블록을 받아 바로 수정에 착수할 수 있도록 구체적인 수정 지시를 포함한다.

```json
{
  "fixes": [
    {
      "severity": "critical",
      "file": "파일 경로",
      "start_line": 42,
      "end_line": 45,
      "issue": "문제 설명",
      "suggestion": "대체할 코드 스니펫"
    }
  ]
}
```

## 사용 예시

```bash
# 현재 브랜치 전체 검증
/verify-changes

# 특정 base 브랜치 기준
/verify-changes --base release/v1.3.0

# 특정 파일만 검증
/verify-changes --files Projects/Clients/
```

## 사용 시점

- **워크플로우 Step 4(검증) 자동 실행**: M/L 규모 작업에서 멀티 레이어 변경이 포함된 경우 메인 Claude가 자동 호출
- 커밋 전 (특히 멀티 레이어 변경 시)
- PR 생성 전 (`/review-pr`과 함께 실행 권장)
- 머지 충돌 해결 후 (리소스 파일 완전성 확인)
- 타입/프로퍼티 리네임 후

### 자동 트리거 조건 (메인 Claude가 판단)

아래 중 하나라도 해당되면 자동 호출:
- Swift + TypeScript 파일이 동시에 변경됨
- `*ActivityAttributes.swift` 파일이 추가/수정됨
- `Protocol*.swift` 또는 `*Client.swift` 파일이 변경됨
- `Localizable.xcstrings` 또는 `LocalizedStrings.swift`가 변경됨
- 새 파일(`??`)이 추가됨 (빌드 타겟 누락 위험)
