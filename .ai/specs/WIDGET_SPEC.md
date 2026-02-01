# Promiso Widget 기술 스펙

> **상태**: ✅ 구현 완료 (v2 Snapshot 기반)
> **iOS 지원**: iOS 18.0+
> **마지막 업데이트**: 2025.02.01

## 개요

Promiso 홈 화면 위젯은 사용자가 앱을 열지 않아도 약속 정보를 확인할 수 있게 합니다.

### 지원 위젯

| 위젯 | 크기 | 표시 내용 |
|------|------|----------|
| Small | 2x2 | 다음 약속 1개 (우선순위 기반) |
| Medium | 4x2 | 오늘 약속 최대 5개 |
| Large | 4x4 | 오늘 + 다가오는 약속 최대 7개 |

---

## 아키텍처 (v2 Snapshot 기반)

### 핵심 변경점 (v1 → v2)

| 항목 | v1 (API 호출) | v2 (Snapshot) |
|------|--------------|---------------|
| 데이터 갱신 | Widget에서 API 호출 | Firestore Trigger로 자동 갱신 |
| API 역할 | 매번 계산 | 캐시된 스냅샷 읽기만 |
| Race Condition | 있음 (복잡한 Lock 필요) | 없음 (같은 문서 읽기) |
| 비용 | 높음 (N+1 쿼리) | 낮음 (1 read) |

### 데이터 흐름 (v2)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Firestore Triggers                            │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ onPromiseWrite: 약속 생성/수정/삭제 → 관련 사용자 스냅샷 갱신    │ │
│  │ scheduledRefresh: 매일 자정 (KST) → 전체 사용자 스냅샷 갱신      │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│         │                                                            │
│         ▼                                                            │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ users/{uid}/cache/widgetSnapshot                                 │ │
│  │ ├─ next: WidgetPromise | null     (Small 위젯용)                │ │
│  │ ├─ today: WidgetPromise[]         (Medium 위젯용, 최대 5개)     │ │
│  │ ├─ upcoming: WidgetPromise[]      (Large 위젯용, 최대 7개)      │ │
│  │ └─ meta: { todayCount, upcomingCount, updatedAt, version }      │ │
│  └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
          │
          │  (Firestore Read Only)
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       Widget Extension                               │
│  ┌──────────────────┐    ┌───────────────────────────────────────┐  │
│  │TimelineProvider  │───▶│ getWidgetSnapshotWithToken (Functions)│  │
│  │                  │    │ → 캐시된 스냅샷 읽기만 (계산 없음)    │  │
│  └──────────────────┘    └───────────────────────────────────────┘  │
│         │                                                            │
│         ▼                                                            │
│  ┌─────────────────┐                                                │
│  │   Widget UI     │                                                │
│  └─────────────────┘                                                │
└─────────────────────────────────────────────────────────────────────┘
```

### 우선순위 정렬 (next 필드)

약속은 다음 우선순위로 정렬되어 `next`에 첫 번째 항목이 표시됩니다:

| 순서 | 조건 | 설명 |
|------|------|------|
| 1순위 | `myVoteStatus === "pending"` | 투표 필요한 약속 |
| 2순위 | `isConfirmed === false` | 미확정 약속 |
| 3순위 | `startAt` 오름차순 | 시간순 |

### Firestore Trigger 이벤트

| 트리거 | 이벤트 | 갱신 대상 |
|--------|--------|----------|
| `onPromiseWriteUpdateSnapshot` | 약속 CRUD | 해당 그룹 멤버 전체 |
| `scheduledSnapshotRefresh` | 매일 00:00 KST | 전체 사용자 |

### 인증 전략 (Widget Token)

#### 문제점: Firebase ID Token 1시간 만료

```
Firebase ID Token:
- 유효 기간: 1시간
- 갱신: Firebase SDK 필요 (Widget Extension에서 불가)
- 결과: 앱 종료 후 1시간 경과 시 Widget API 호출 실패
```

#### 해결책: Long-lived Widget Token (30일)

```
Widget Token (JWT):
- 유효 기간: 30일
- 발급: 앱 실행 시 generateWidgetToken 호출
- 저장: App Group UserDefaults
- 갱신: 만료 7일 전 자동 갱신
```

#### 인증 우선순위

```
Widget Timeline Reload 시:

1. Widget Token (30일) 시도
   ├─ 성공 → 데이터 반환
   └─ 실패 (401) → 2단계로

2. ID Token (1시간) 시도 (Fallback)
   ├─ 성공 → 데이터 반환
   └─ 실패 → 3단계로

3. 로컬 캐시 반환
```

### 갱신 전략

#### Timeline Refresh (Primary)

Timeline 기반 주기적 갱신 (서버 직접 호출)

| 조건 | 갱신 주기 |
|------|----------|
| 1시간 이내 약속 | 5분 |
| 6시간 이내 약속 | 30분 |
| 그 외 / 약속 없음 | 1시간 |

**참고**: 이는 시스템에 "요청"하는 주기이며, 실제 갱신은 시스템이 결정 (배터리, 사용 패턴 등 고려)

#### iOS 26 Widget Push (향후 지원)

iOS 26에서 도입된 Widget Push는 앱을 깨우지 않고 위젯 Timeline Reload를 트리거

```
서버 → Widget Push → WidgetKit → Timeline Reload → fetchFromServer()
```

**중요**: Widget Push는 "데이터 푸시"가 아닌 "갱신 트리거"

---

## Widget Token 구조

### JWT Payload

```typescript
interface WidgetTokenPayload {
  sub: string;      // userId
  scope: string;    // "widget:read" (권한 제한)
  deviceId: string; // 기기 바인딩 (탈취 방지)
  version: number;  // revocation용 버전
  iat: number;      // issued at
  exp: number;      // expiry (30일)
}
```

### 보안 설계

| 보안 요소 | 설명 |
|----------|------|
| scope 제한 | `widget:read`만 허용, 쓰기 불가 |
| deviceId 바인딩 | 다른 기기에서 사용 불가 |
| version 필드 | 비밀번호 변경 시 모든 토큰 무효화 |
| 짧은 만료 | 30일 (무한하지 않음) |
| HTTPS 전용 | 네트워크 스니핑 방지 |

### Token Revocation

비밀번호 변경, 보안 이슈 발생 시:

```typescript
// Firestore users/{userId}
{
  widgetTokenVersion: 2  // 버전 증가 → 기존 토큰 무효화
}
```

---

## 데이터 모델

### WidgetPromiseData

Widget에서 사용하는 경량화된 약속 모델

```swift
// 내 투표 상태
public enum MyVoteStatus: String, Codable, Sendable {
  case pending   // 투표 필요
  case voted     // 참여 의사 표시함
  case declined  // 불참 의사 표시함
}

public struct WidgetPromiseData: Codable, Identifiable, Equatable, Sendable {
  // MARK: - 식별자
  public let id: String

  // MARK: - 약속 정보
  public let title: String
  public let emoji: String
  public let startAt: Date
  public let endAt: Date?
  public let location: String?

  // MARK: - 그룹 정보
  public let groupId: String
  public let groupName: String?

  // MARK: - 상태
  public let isConfirmed: Bool      // 약속 확정 여부 (최소 인원 충족)
  public let participantCount: Int
  public let myVoteStatus: MyVoteStatus  // 내 투표 상태 (v2 추가)

  // MARK: - 캐시 메타데이터
  public let cachedAt: Date

  // MARK: - Computed Properties

  /// 캐시 유효성 (2시간 초과 시 stale)
  public var isStale: Bool {
    Date().timeIntervalSince(cachedAt) > 7200
  }

  /// 딥링크 URL
  public var deeplinkURL: URL? {
    URL(string: "promiso://promise?id=\(id)&groupId=\(groupId)")
  }
}
```

### MyVoteStatus 표시 가이드

| 상태 | UI 표시 | 색상 |
|------|---------|------|
| `pending` | "투표 필요" 배지 | Orange |
| `voted` | 체크 아이콘 | Green |
| `declined` | - (표시 안함) | - |

### WidgetPromiseEntry

WidgetKit TimelineEntry 구현

```swift
struct WidgetPromiseEntry: TimelineEntry {
  let date: Date
  let promises: [WidgetPromiseData]
  let state: WidgetState

  enum WidgetState: Equatable {
    case loaded
    case empty
    case notLoggedIn
  }

  // MARK: - Computed Properties

  /// 다음 약속 (현재 시간 이후 첫 번째)
  var nextPromise: WidgetPromiseData? {
    promises.first { $0.startAt > Date() }
  }

  /// 오늘 약속
  var todayPromises: [WidgetPromiseData] {
    promises.filter { Calendar.current.isDateInToday($0.startAt) }
  }

  /// 다가오는 약속 (오늘 제외)
  var upcomingPromises: [WidgetPromiseData] {
    promises.filter {
      !Calendar.current.isDateInToday($0.startAt) && $0.startAt > Date()
    }
  }
}
```

---

## App Group 데이터 공유

### Suite Name
```
group.com.promiso.shared
```

### 저장 키

| 키 | 타입 | 설명 |
|----|------|------|
| `widget.promises` | `Data` (JSON) | 약속 목록 |
| `widget.userId` | `String?` | 로그인 사용자 ID |
| `widget.auth.token` | `String?` | Widget Token (JWT, 30일) |
| `widget.auth.tokenExpiry` | `TimeInterval?` | Widget Token 만료 시간 |
| `widget.auth.idToken` | `String?` | Firebase ID Token (1시간, Fallback) |
| `widget.lastUpdated` | `Date` | 마지막 업데이트 시간 |
| `widget.firestore.env` | `String?` | Firestore 환경 (stage/prod) |

### WidgetDataManager API

```swift
public enum WidgetDataManager {
  // MARK: - App에서 호출 (저장)

  /// 약속 목록 저장
  public static func savePromises(_ promises: [WidgetPromiseData])

  /// 사용자 ID 저장 (로그인 시)
  public static func saveUserId(_ userId: String?)

  // MARK: - Widget에서 호출 (읽기)

  /// 약속 목록 로드 (캐시)
  public static func loadPromises() -> [WidgetPromiseData]

  /// 로그인 상태 확인
  public static func isLoggedIn() -> Bool

  /// 마지막 업데이트 시간
  public static func lastUpdated() -> Date?

  // MARK: - 서버 연동 (Widget Token 사용)

  /// 서버에서 위젯 스냅샷 조회 (Widget Token → ID Token → Cache)
  public static func fetchFromServer() async -> [WidgetPromiseData]

  /// Widget Token 로드
  public static func loadWidgetToken() -> String?

  /// ID Token 로드 (Fallback)
  public static func loadIdToken() -> String?

  // MARK: - 초기화

  /// 모든 데이터 삭제 (로그아웃 시)
  public static func clearAll()
}
```

---

## Firebase Functions API

### generateWidgetToken

Widget Token 발급 (앱에서 호출)

```typescript
// Callable Function
export const generateWidgetToken = onCall<{
  deviceId: string;
  env?: string;
}>({
  region: "asia-northeast3",
  secrets: [WIDGET_JWT_SECRET],
}, async (request) => {
  // 1. Firebase ID Token 인증 확인
  // 2. deviceId 유효성 검사
  // 3. 토큰 버전 조회 (revocation용)
  // 4. JWT 생성 (30일 유효)
  return {
    widgetToken: string,
    expiresAt: number  // Unix timestamp
  };
});
```

### getWidgetSnapshotWithToken

위젯 스냅샷 조회 (Widget에서 호출)

```typescript
// HTTP Request (POST)
// Authorization: Bearer <widget_token>
export const getWidgetSnapshotWithToken = onRequest({
  region: "asia-northeast3",
  secrets: [WIDGET_JWT_SECRET],
}, async (req, res) => {
  // 1. Widget Token 검증
  // 2. 토큰 버전 확인 (revocation 체크)
  // 3. 스냅샷 데이터 조회
  res.json({
    result: {
      next: WidgetPromise | null,
      today: WidgetPromise[],
      upcoming: WidgetPromise[],
      updatedAt: string  // ISO 8601
    }
  });
});
```

### getWidgetSnapshot

위젯 스냅샷 조회 (앱에서 호출, Fallback)

```typescript
// Callable Function (Firebase ID Token 인증)
export const getWidgetSnapshot = onCall({
  region: "asia-northeast3",
}, async (request) => {
  // Firebase ID Token 인증
  return {
    next: WidgetPromise | null,
    today: WidgetPromise[],
    upcoming: WidgetPromise[],
    updatedAt: string
  };
});
```

---

## 딥링크

### URL 스킴
```
promiso://
```

### 라우팅 테이블

| URL | 파라미터 | 동작 |
|-----|---------|------|
| `promiso://home` | - | 홈 화면으로 이동 |
| `promiso://promise` | `id`, `groupId` | 약속 상세 화면으로 이동 |
| `promiso://group` | `id` | 그룹 화면으로 이동 |

### 예시
```
promiso://promise?id=abc123&groupId=group456
```

### Widget에서 딥링크 설정
```swift
// 단일 약속 위젯
.widgetURL(promise.deeplinkURL)

// 다중 약속 위젯
Link(destination: promise.deeplinkURL!) {
  PromiseRowView(promise: promise)
}
```

---

## 제약사항

### Widget Extension 제한

| 제한 | 대응 방안 |
|------|----------|
| Firebase SDK 사용 불가 | Widget Token + URLSession 직접 호출 |
| 메모리 제한 (~30MB) | 경량 모델 (WidgetPromiseData) 사용 |
| 갱신 빈도 제한 | Timeline 정책 + 캐시 |
| 별도 프로세스 | App Group으로 데이터 공유 |

### iOS 버전 분기

```swift
// Glass Effect (iOS 26+)
.containerBackground(for: .widget) {
  if #available(iOS 26.0, *) {
    Color.clear.glassEffect(.regular)
  } else {
    Color(.systemBackground).opacity(0.9)
  }
}
```

---

## iOS 26 Widget Push (향후 지원)

### 개요

iOS 26에서 도입된 Widget Push는 앱을 깨우지 않고 위젯 Timeline Reload를 트리거하는 기능입니다.

### 현재 vs iOS 26

| 항목 | 현재 (Timeline) | iOS 26 (Widget Push) |
|------|----------------|---------------------|
| 갱신 방식 | Timeline 주기적 | 서버 트리거 |
| 앱 깨움 | 불필요 | 불필요 |
| APNs topic | - | `com.promiso.push-type.widgets` |
| 실시간성 | 낮음 | 높음 |

**중요**: Widget Push는 "Reload 트리거"일 뿐, 여전히 서버 API 호출이 필요 → Widget Token 유지

### 구현 방향 (예정)

**Cloud Functions**:
```typescript
// Widget Push 전용 topic 사용
"apns-topic": "com.promiso.push-type.widgets"
```

**WidgetBundle**:
```swift
@main
struct PromiseWidgetBundle: WidgetBundle {
  var body: some Widget {
    SmallPromiseWidget()
      .onWidgetPush { payload in
        // Timeline Reload 트리거됨
        // → fetchFromServer() 자동 호출
      }
  }
}
```

### 마이그레이션 전략

1. iOS 26+ 점유율 확인
2. 기존 Timeline 방식과 병행 운영
3. iOS 26 미만 → Timeline 기반 (현재)
4. iOS 26 이상 → Widget Push 추가

---

## 관련 문서

- [구현 가이드](../guides/WIDGET_IMPLEMENTATION.md)
- [프로젝트 컨텍스트](../PROJECT_CONTEXT.md)
- [Push Notification 가이드](../PUSH_NOTIFICATION_GUIDE.md)
