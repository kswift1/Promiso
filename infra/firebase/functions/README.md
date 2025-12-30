# Firebase Functions

Promiso iOS 앱의 백엔드 로직을 담당하는 Firebase Functions입니다.

## 📋 목차

- [설정](#설정)
- [개발](#개발)
- [API 문서](#api-문서)
- [테스트](#테스트)
- [배포](#배포)

## 🔧 설정

### 요구사항

- Node.js 24
- Firebase CLI
- TypeScript

### 설치

```bash
cd infra/firebase/functions
npm install
```

## 💻 개발

### 로컬 실행

```bash
# TypeScript 빌드
npm run build

# Emulator 실행
npm run serve

# 실시간 빌드 (개발 중)
npm run build:watch
```

### 함수 추가

1. `src/index.ts`에 함수 추가
2. `src/types/api.ts`에 타입 정의
3. `.ai/API_SPEC.md` 문서 업데이트
4. `openapi.yaml` 업데이트

## 📚 API 문서

### 빠른 시작 ⭐

```bash
cd infra/firebase/functions

# OpenAPI 스펙 검증
npm run api:validate

# Swagger UI로 미리보기 (자동으로 브라우저 열림)
npm run api:preview

# 정적 HTML 문서 생성
npm run api:docs
```

### 상세 방법

#### 1. Markdown 문서 (추천 - 상세 예시 포함)
```bash
# 프로젝트 루트에서
open .ai/API_SPEC.md
```

#### 2. Swagger UI (추천 - 인터랙티브)
```bash
cd infra/firebase/functions

# 로컬 Swagger UI 실행 (http://localhost:8080)
npm run api:preview
```

#### 3. VS Code 확장
- 확장 설치: `Swagger Viewer` 또는 `OpenAPI (Swagger) Editor`
- `openapi.yaml` 열고 미리보기

#### 4. Online Swagger Editor (공유 시)
```bash
# 1. Swagger Editor 열기
open https://editor.swagger.io/

# 2. openapi.yaml 복사
cd infra/firebase/functions
cat openapi.yaml | pbcopy

# 3. 브라우저에 붙여넣기
```

## 🧪 테스트

### Emulator 테스트

```bash
# Emulator 실행
npm run serve

# 다른 터미널에서 cURL 테스트
curl -X POST http://localhost:5001/[PROJECT_ID]/asia-northeast3/testCallable \
  -H "Content-Type: application/json" \
  -d '{"data": {"name": "Test"}}'
```

### iOS에서 Emulator 연결

```swift
#if DEBUG
// AppDelegate 또는 초기화 시점
Functions.functions().useEmulator(withHost: "localhost", port: 5001)
#endif
```

## 🚀 배포

### 전체 배포

```bash
npm run deploy
```

### 특정 함수만 배포

```bash
firebase deploy --only functions:createGroup
```

### 배포 전 체크리스트

- [ ] TypeScript 빌드 성공 (`npm run build`)
- [ ] Lint 통과 (`npm run lint`)
- [ ] 로컬 테스트 완료 (`npm run serve`)
- [ ] API 문서 업데이트 (`.ai/API_SPEC.md`, `openapi.yaml`)
- [ ] 타입 정의 업데이트 (`src/types/api.ts`)

## 📂 프로젝트 구조

```
functions/
├── src/
│   ├── index.ts           # 함수 정의
│   └── types/
│       └── api.ts         # TypeScript 타입 정의
├── openapi.yaml           # OpenAPI/Swagger 스펙
├── README.md              # 이 파일
├── package.json
└── tsconfig.json
```

## 🔗 관련 문서

- [API 명세서](../../../.ai/API_SPEC.md)
- [프로젝트 아키텍처](../../../.ai/PROJECT_CONTEXT.md)
- [Firebase Functions 공식 문서](https://firebase.google.com/docs/functions)

## 💡 팁

### 함수 로그 보기

```bash
# 실시간 로그
firebase functions:log --only createGroup

# 최근 로그
firebase functions:log --limit 50
```

### 비용 모니터링

- [Firebase Console](https://console.firebase.google.com) → Functions → Usage
- `setGlobalOptions({maxInstances: 10})` 설정으로 비용 제어

### 디버깅

```typescript
// Functions에서 로그 출력
import {logger} from "firebase-functions";

logger.info("Group created", {groupId, inviteCode});
logger.error("Error creating group", error);
```

iOS에서는 Firebase Console의 Functions 로그에서 확인 가능합니다.
