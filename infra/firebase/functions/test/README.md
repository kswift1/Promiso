# Firebase Functions 테스트 가이드

> 자동 배포 테스트: Stage 환경에 자동 배포됩니다.

## 📁 구조

```
test/
├── setup.ts                  # Jest 초기 설정
├── emoji.test.ts            # ✅ 완료 (템플릿)
├── widgetToken.test.ts      # ✅ 완료 (템플릿)
├── kakaoMap.test.ts         # ✅ 완료 (템플릿)
├── notifications.test.ts    # TODO
├── promises.test.ts         # TODO
├── users.test.ts            # TODO
├── widget.test.ts           # TODO
├── faq.test.ts              # TODO
├── promiseBadges.test.ts    # TODO
├── groups.test.ts           # TODO (복잡도 높음 - Opus 권장)
└── liveActivity.test.ts     # TODO (복잡도 높음 - Opus 권장)
```

---

## 🎯 테스트 패턴

### 1️⃣ 기본 구조

```typescript
import { describe, it, expect, jest, beforeEach } from '@jest/globals';

describe('functionName', () => {
  let functionName: any;

  beforeEach(async () => {
    // Functions 모듈 import
    const functions = await import('../src/functions/fileName');
    functionName = functions.functionName;
  });

  describe('정상 케이스', () => {
    it('올바른 입력으로 성공 응답을 반환한다', async () => {
      // Given
      const request = {
        data: { /* 테스트 데이터 */ },
        auth: { uid: 'test-user-id' },
      };

      // When
      const result = await functionName(request);

      // Then
      expect(result).toBeDefined();
    });
  });

  describe('에러 케이스', () => {
    it('인증 없이 호출 시 에러를 발생시킨다', async () => {
      const request = { data: {}, auth: undefined };
      await expect(functionName(request)).rejects.toThrow();
    });

    it('필수 파라미터 누락 시 에러를 발생시킨다', async () => {
      const request = { data: {}, auth: { uid: 'test-user-id' } };
      await expect(functionName(request)).rejects.toThrow();
    });
  });
});
```

---

### 2️⃣ Mock 패턴

#### Firestore Mock

```typescript
import * as admin from 'firebase-admin';

beforeEach(() => {
  const mockFirestore = {
    collection: jest.fn().mockReturnValue({
      doc: jest.fn().mockReturnValue({
        get: jest.fn().mockResolvedValue({
          exists: true,
          data: () => ({ field: 'value' }),
        }),
        set: jest.fn().mockResolvedValue(undefined),
        update: jest.fn().mockResolvedValue(undefined),
      }),
    }),
  };

  jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);
});

afterEach(() => {
  jest.restoreAllMocks();
});
```

#### 외부 API Mock (fetch)

```typescript
global.fetch = jest.fn() as any;

beforeEach(() => {
  (global.fetch as jest.Mock).mockResolvedValue({
    ok: true,
    json: async () => ({ data: 'response' }),
  });
});
```

#### Secret Mock (Firebase Secret Manager)

```typescript
jest.mock('firebase-functions/params', () => ({
  defineSecret: jest.fn((name: string) => ({
    value: () => 'test-secret-value',
  })),
}));
```

#### Gemini AI Mock

```typescript
jest.mock('@google/generative-ai', () => ({
  GoogleGenerativeAI: jest.fn().mockImplementation(() => ({
    getGenerativeModel: jest.fn().mockReturnValue({
      generateContent: jest.fn().mockResolvedValue({
        response: {
          text: jest.fn().mockReturnValue('AI 응답'),
        },
      }),
    }),
  })),
}));
```

---

### 3️⃣ 테스트 케이스 체크리스트

각 함수당 최소한 다음 테스트를 포함:

- [ ] **정상 케이스**: 올바른 입력 → 성공 응답
- [ ] **인증 에러**: `auth: undefined` → HttpsError (unauthenticated)
- [ ] **유효성 에러**: 필수 파라미터 누락 → HttpsError (invalid-argument)
- [ ] **권한 에러**: 권한 없는 사용자 → HttpsError (permission-denied)
- [ ] **외부 API 에러**: 외부 API 실패 → 적절한 에러 처리

---

## 🚀 실행 방법

```bash
# 전체 테스트 실행
npm test

# 특정 파일만 실행
npm test emoji.test.ts

# Watch 모드
npm run test:watch

# 커버리지 확인
npm test -- --coverage
```

---

## 📊 커버리지 목표

| 파일 | 복잡도 | 목표 커버리지 |
|------|--------|---------------|
| emoji.ts | 🟢 낮음 | 80%+ |
| widgetToken.ts | 🟢 낮음 | 80%+ |
| kakaoMap.ts | 🟢 낮음 | 80%+ |
| faq.ts | 🟢 낮음 | 80%+ |
| promiseBadges.ts | 🟢 낮음 | 70%+ |
| widget.ts | 🟡 중간 | 70%+ |
| users.ts | 🟡 중간 | 70%+ |
| promises.ts | 🟡 중간 | 70%+ |
| notifications.ts | 🟡 중간 | 60%+ |
| groups.ts | 🔴 높음 | 60%+ |
| liveActivity.ts | 🔴 높음 | 50%+ |

**전체 목표**: 60% 이상

---

## ⚠️ 주의사항

### 실제 API 호출 금지

테스트에서 실제 외부 API를 호출하면 안 됩니다:
- ❌ Kakao Map API
- ❌ Notion API
- ❌ Gemini AI API
- ❌ FCM (Firebase Cloud Messaging)
- ❌ APNs (Apple Push Notification)

모두 **mock**으로 처리해야 합니다.

### Firestore 에뮬레이터 사용

`setup.ts`에 에뮬레이터 설정이 되어 있습니다:
```typescript
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
```

실제 Firestore 대신 에뮬레이터를 사용합니다.

### 비동기 테스트 타임아웃

복잡한 함수는 시간이 오래 걸릴 수 있습니다:
```typescript
jest.setTimeout(10000); // 10초
```

---

## 📚 참고 자료

- [Jest 공식 문서](https://jestjs.io/docs/getting-started)
- [firebase-functions-test](https://firebase.google.com/docs/functions/unit-testing)
- [프로젝트 컨벤션](.claude/CLAUDE.md)

---

## 🔄 점진적 추가 가이드

새 Functions 추가 시:

1. **Functions 파일 작성** (`src/functions/newFunction.ts`)
2. **테스트 파일 작성** (`test/newFunction.test.ts`)
3. **테스트 실행 및 검증** (`npm test newFunction.test.ts`)
4. **커버리지 확인** (목표 달성 여부)
5. **커밋** (`feat: newFunction 추가 및 테스트 작성`)

---

**작성일**: 2026-02-06
**작성자**: Claude Sonnet 4.5 (with Human)
