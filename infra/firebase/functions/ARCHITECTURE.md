# Firebase Functions 아키텍처

> 이 문서는 iOS 개발자가 서버 코드를 이해하기 위한 가이드입니다.
> AI(Claude)가 서버 코드를 관리하며, 주요 의사결정과 구조를 기록합니다.

---

## 파일 구조

```
infra/firebase/functions/
├── src/
│   ├── index.ts              # 진입점 (re-export만, 수정 거의 없음)
│   ├── config/
│   │   └── index.ts          # Firebase Admin, APNs secrets, 상수
│   ├── functions/
│   │   ├── users.ts          # 사용자 관련 (7개)
│   │   ├── groups.ts         # 그룹 관련 (5개)
│   │   ├── promises.ts       # 약속 관련 (3개)
│   │   ├── notifications.ts  # FCM 푸시 (4개)
│   │   ├── liveActivity.ts   # LiveActivity (6개)
│   │   └── emoji.ts          # 이모지 생성 (1개)
│   ├── utils/
│   │   ├── helpers.ts        # 검증, 초대코드 생성 등
│   │   ├── apns.ts           # APNs JWT, Push, Broadcast
│   │   └── firestore.ts      # 환경별 컬렉션 경로
│   └── types/
│       └── api.ts            # Request/Response 타입 정의
├── openapi.yaml              # API 명세서 (iOS 참고용)
├── CHANGELOG.md              # 변경 이력
└── ARCHITECTURE.md           # 이 문서
```

---

## iOS Feature ↔ Functions 매핑

| iOS Feature | Functions | 설명 |
|-------------|-----------|------|
| `SignUpView` | `createUser` | 회원가입 |
| `ProfileEditView` | `updateUser`, `uploadProfileImage`, `checkNicknameAvailable` | 프로필 수정 |
| `SettingsView` | `getUserSettings`, `updateUserSettings` | 설정 관리 |
| `CreateGroupView` | `createGroup` | 그룹 생성 |
| `JoinGroupView` | `previewGroup`, `joinGroup` | 그룹 참여 |
| `GroupSettingsView` | `leaveGroup`, `deleteGroup` | 그룹 관리 |
| `CreatePromiseView` | `createPromise`, `generateEmoji` | 약속 생성 |
| `PromiseDetailView` | `respondPromise`, `updatePromise` | 약속 응답/수정 |
| `LiveActivityManager` | `registerPushToStartToken`, `startLiveActivity`, `updateETA` | 실시간 공유 |
| `PromiseWidgetExtension` | `widgetUpdateETA` | 위젯 ETA 업데이트 |

---

## 환경 분리 (Environment)

Firestore 경로가 환경별로 분리됩니다:

| 환경 | Firestore 경로 | 용도 |
|------|---------------|------|
| dev | `dev/root/groups/{id}` | 로컬 에뮬레이터 |
| stage | `stage/root/groups/{id}` | 테스트/QA |
| prod | `prod/root/groups/{id}` | 프로덕션 |

**iOS에서 설정**:
```swift
// AppEnvironment.swift
FirestoreEnvironmentManager.shared.setEnvironment(.stage)
```

**Functions에서 처리**:
```typescript
// 요청의 env 파라미터로 분기
const collection = getEnvironmentCollection("groups", db, request.data.env);
```

---

## 주요 의사결정 기록 (ADR)

### ADR-001: LiveActivity - iOS 18 Broadcast 방식 채택

**날짜**: 2026-01-15
**상태**: 적용됨

**컨텍스트**:
- 기존: 각 사용자별 APNs 토큰을 Firestore에 저장하고 개별 전송
- 문제: 토큰 관리 복잡, 실시간성 저하, 토큰 만료 처리 어려움

**결정**:
- iOS 18 Broadcast Push 사용 (channelId 기반)
- Apple이 채널 생성/관리, 서버는 채널에 Broadcast만 전송

**구현**:
```
1. startLiveActivity 호출
2. createAPNsChannel()로 채널 생성 → channelId 획득
3. Push to Start로 각 디바이스에 channelId 전달
4. iOS가 Activity 시작 시 자동으로 채널 구독
5. updateETA에서 channelId로 Broadcast → 모든 구독자 수신
6. dismissal-date로 자동 종료 (endLiveActivity 불필요)
```

**결과**:
- 토큰 관리 로직 제거
- 실시간성 향상
- endLiveActivity 함수 deprecated

---

### ADR-002: Widget Extension - HTTP 엔드포인트 분리

**날짜**: 2026-01-15
**상태**: 적용됨

**컨텍스트**:
- Widget Extension은 별도 프로세스로 실행
- Firebase SDK 초기화/인증 불가능
- `onCall` 함수 호출 불가

**결정**:
- `widgetUpdateETA`를 `onRequest` (HTTP)로 구현
- 인증은 헤더로 처리: `X-User-Id`, `X-Auth-Token`

**Endpoint**:
```
POST https://widgetupdateeta-dfaqqrbqgq-du.a.run.app
Headers:
  X-User-Id: {userId}
  X-Auth-Token: {optional Firebase ID Token}
Body:
  { channelId, participants, trackingDurationMinutes, env }
```

---

### ADR-003: 이모지 생성 - Gemini API 사용

**날짜**: 2026-01-21
**상태**: 적용됨

**컨텍스트**:
- 약속 제목에 맞는 이모지를 자동 추천하고 싶음
- 단순 키워드 매칭은 한계가 있음

**결정**:
- Gemini 2.0 Flash 모델 사용
- 프롬프트로 이모지 1개만 출력하도록 제한

**Fallback**:
- API 키 없음 → 기본값 `📅`
- API 오류 → 기본값 `📅`
- 이모지 추출 실패 → 기본값 `📅`

---

## API 문서

상세한 API 명세는 `openapi.yaml` 참고.

**주요 확인 포인트**:
- Request/Response 스키마
- 에러 코드 및 메시지
- 인증 요구사항

---

## 트러블슈팅

### Q: Functions 배포 후 iOS에서 호출 안됨
1. Firebase Console에서 함수 배포 상태 확인
2. iOS의 `env` 파라미터가 올바른지 확인 (stage/prod)
3. 인증 토큰이 유효한지 확인

### Q: LiveActivity가 시작되지 않음
1. Push to Start 토큰이 등록되었는지 확인 (`registerPushToStartToken`)
2. APNs 인증서/키가 유효한지 확인
3. Bundle ID가 `com.promiso`인지 확인

### Q: Widget에서 ETA 업데이트 안됨
1. `X-User-Id` 헤더가 포함되었는지 확인
2. `channelId`가 유효한지 확인
3. CloudFlare/방화벽에서 차단되지 않았는지 확인

---

## 연락처

서버 관련 문의: AI(Claude)에게 이 문서와 함께 컨텍스트 제공
