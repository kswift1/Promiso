# Firebase Functions 개발 워크플로우

> OpenAPI YAML 기반 API 개발 및 문서화 가이드

## 🎯 워크플로우 개요

```
1. 타입 정의 → 2. 함수 구현 → 3. OpenAPI 업데이트 → 4. 검증 → 5. 배포
```

---

## 📝 새 API 추가 시

### 1단계: 타입 정의

`src/types/api.ts`에 Request/Response 타입 정의

```typescript
// src/types/api.ts

/**
 * 새 API 요청
 */
export interface NewFeatureRequest {
  /** 설명 */
  param1: string;
  param2: number;
}

/**
 * 새 API 응답
 */
export interface NewFeatureResponse {
  /** 설명 */
  result: string;
}
```

### 2단계: 함수 구현

`src/index.ts`에 타입 안전하게 함수 구현

```typescript
// src/index.ts

/**
 * 새 기능 설명
 *
 * @param request.data - NewFeatureRequest
 * @returns NewFeatureResponse
 * @throws HttpsError
 */
export const newFeature = onCall<NewFeatureRequest>(
  {region: REGION},
  async (request): Promise<NewFeatureResponse> => {
    // 1. 인증 확인 (필요시)
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    // 2. 타입 안전한 데이터 추출
    const data = request.data;

    // 3. 유효성 검사
    validateNewFeatureRequest(data);

    // 4. 비즈니스 로직
    // ...

    // 5. 응답 반환
    return {
      result: "success"
    };
  }
);
```

### 3단계: OpenAPI 업데이트

`openapi.yaml`에 API 명세 추가

```yaml
paths:
  /newFeature:
    post:
      tags:
        - Feature
      summary: 새 기능
      description: 새 기능 설명
      operationId: newFeature
      security:
        - firebaseAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                data:
                  $ref: '#/components/schemas/NewFeatureRequest'
      responses:
        '200':
          description: 성공
          content:
            application/json:
              schema:
                type: object
                properties:
                  result:
                    $ref: '#/components/schemas/NewFeatureResponse'
        '400':
          description: 잘못된 파라미터
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/FunctionsError'

# components/schemas에도 추가
components:
  schemas:
    NewFeatureRequest:
      type: object
      required:
        - param1
        - param2
      properties:
        param1:
          type: string
          description: 파라미터 1
        param2:
          type: integer
          description: 파라미터 2

    NewFeatureResponse:
      type: object
      properties:
        result:
          type: string
          description: 결과
```

### 4단계: 검증

```bash
# TypeScript 빌드 확인
npm run build

# Lint 확인
npm run lint

# OpenAPI 스펙 검증
npm run api:validate

# Swagger UI로 확인
npm run api:preview
```

### 5단계: 배포

```bash
# 로컬 테스트 (Emulator)
npm run serve

# 다른 터미널에서 cURL 테스트
curl -X POST http://localhost:5001/[PROJECT_ID]/asia-northeast3/newFeature \
  -H "Content-Type: application/json" \
  -d '{"data": {"param1": "test", "param2": 123}}'

# 배포
npm run deploy
```

---

## 🔄 기존 API 수정 시

### 1. Breaking Changes 확인

기존 iOS 코드와의 호환성 체크

```bash
# 변경 전후 OpenAPI diff 확인
git diff openapi.yaml
```

**Breaking Changes 예시:**
- 필수 파라미터 추가 ❌
- 파라미터 이름 변경 ❌
- 응답 타입 변경 ❌

**Non-Breaking Changes 예시:**
- 선택적 파라미터 추가 ✅
- 응답 필드 추가 ✅
- 에러 메시지 개선 ✅

### 2. 버전 관리

Breaking Changes가 있다면:

```typescript
// 기존 함수 유지
export const createGroup = onCall<CreateGroupRequest>(...);

// 새 버전 추가
export const createGroupV2 = onCall<CreateGroupV2Request>(...);
```

### 3. 문서 업데이트

- `openapi.yaml` 업데이트
- iOS 코드 수정 필요 여부 기록

---

## 📋 체크리스트

### 개발 전

- [ ] 타입 정의 완료 (`src/types/api.ts`)
- [ ] 비즈니스 로직 설계 완료
- [ ] iOS와 파라미터 협의 완료

### 개발 중

- [ ] 함수 구현 (`src/index.ts`)
- [ ] 유효성 검사 추가
- [ ] 에러 핸들링 추가
- [ ] JSDoc 주석 추가

### 문서화

- [ ] `openapi.yaml` 업데이트 (예시 코드 포함)
- [ ] `npm run api:validate` 통과

### 테스트

- [ ] TypeScript 빌드 성공 (`npm run build`)
- [ ] Lint 통과 (`npm run lint`)
- [ ] Emulator 테스트 (`npm run serve`)
- [ ] cURL로 수동 테스트
- [ ] iOS에서 실제 호출 테스트

### 배포

- [ ] Breaking Changes 확인
- [ ] 버전 기록 (필요시)
- [ ] 배포 (`npm run deploy`)
- [ ] 프로덕션 테스트
- [ ] iOS 팀에 배포 알림

---

## 🛠️ 유용한 명령어

### 개발

```bash
# TypeScript 실시간 빌드
npm run build:watch

# Emulator 실행
npm run serve

# 함수 로그 확인
npm run logs
```

### 문서

```bash
# OpenAPI 검증
npm run api:validate

# Swagger UI 미리보기
npm run api:preview

# 정적 HTML 생성
npm run api:docs
```

### 배포

```bash
# 전체 배포
npm run deploy

# 특정 함수만 배포
firebase deploy --only functions:createGroup
```

---

## 🐛 트러블슈팅

### OpenAPI 검증 실패

```bash
npm run api:validate

# 에러 메시지 확인 후 수정
# 주로: 필수 필드 누락, 타입 불일치, 참조 오류
```

### TypeScript 빌드 실패

```bash
# 타입 정의 확인
vi src/types/api.ts

# tsconfig.json 확인
cat tsconfig.json
```

### iOS와 파라미터 불일치

1. `openapi.yaml` 확인
2. iOS `FirebaseGroupCreationGateway.swift` 확인
3. 파라미터 매핑 검증

```swift
// iOS
var data: [String: Any] = [
  "name": name,  // ✅ openapi.yaml의 "name"과 일치
  "maxMembers": maxMembers  // ✅ 일치
]
```

---

## 📚 참고 문서

- [API 명세서 (OpenAPI)](./openapi.yaml)
- [OpenAPI Specification](https://swagger.io/specification/)
- [Firebase Functions Docs](https://firebase.google.com/docs/functions)
- [TypeScript 타입 정의](./src/types/api.ts)

---

## 💡 팁

### 1. 타입 먼저, 구현은 나중에

TypeScript 타입을 먼저 정의하면:
- IDE 자동완성 활용 ✅
- 타입 안정성 보장 ✅
- iOS와 계약 명확화 ✅

### 2. OpenAPI as Single Source of Truth

OpenAPI YAML을 진실의 원천으로:
- iOS 개발자와 공유
- Postman/Insomnia로 테스트 가능
- 자동 클라이언트 생성 가능 (필요시)

### 3. 문서는 코드와 함께 업데이트

```bash
# 커밋 전 체크
git diff src/index.ts
git diff openapi.yaml  # 함께 수정되었는지 확인
```

### 4. Breaking Changes 최소화

새 필드 추가 시:
```typescript
// ❌ 기존 필수 필드 변경
interface Request {
  oldField: string;  // 삭제 -> Breaking!
}

// ✅ 새 선택적 필드 추가
interface Request {
  oldField: string;
  newField?: string;  // 선택적 -> Non-breaking!
}
```

---

**마지막 업데이트**: 2024-12-29
