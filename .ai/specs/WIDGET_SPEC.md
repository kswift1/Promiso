# Promiso Widget 기술 스펙

## 개요

Promiso 홈 화면 위젯은 사용자가 앱을 열지 않아도 약속 정보를 확인할 수 있게 합니다.

### 지원 위젯

| 위젯 | 크기 | 표시 내용 |
|------|------|----------|
| Small | 2x2 | 다음 약속 1개 |
| Medium | 4x2 | 오늘 약속 2-3개 |
| Large | 4x4 | 오늘 + 다가오는 약속 |

---

## 아키텍처

### 데이터 흐름

```
┌─────────────────────────────────────────────────────────────┐
│                        Main App                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐  │
│  │ HomeFeature │───▶│ PromiseClient│───▶│ Firestore       │  │
│  └─────────────┘    └─────────────┘    └─────────────────┘  │
│         │                                        │           │
│         ▼                                        │           │
│  ┌─────────────────┐                            │           │
│  │ WidgetDataManager│◀── Silent Push ───────────┘           │
│  └─────────────────┘                                        │
│         │                                                    │
└─────────┼────────────────────────────────────────────────────┘
          │
          ▼  (App Group: group.com.promiso.shared)
┌─────────────────────────────────────────────────────────────┐
│                     UserDefaults                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ widget.promises: [WidgetPromiseData] (JSON)            │ │
│  │ widget.userId: String?                                  │ │
│  │ widget.lastUpdated: Date                                │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Widget Extension                          │
│  ┌──────────────────┐    ┌─────────────────┐                │
│  │ TimelineProvider │───▶│ Widget UI       │                │
│  └──────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

### 갱신 전략

#### 1. Silent Push (Primary)
Firestore 변경 시 Cloud Functions가 그룹 멤버들에게 Silent Push 발송

```
Firestore 변경 → Cloud Functions → FCM Silent Push → App 수신
                                                         ↓
                                          WidgetDataManager.savePromises()
                                                         ↓
                                          WidgetCenter.reloadAllTimelines()
```

**트리거 이벤트:**
- 새 약속 제안
- 수락/거절 응답
- 약속 확정
- 시간/장소 변경
- T-30분 도달

#### 2. Timeline Refresh (Fallback)
Silent Push 실패 대비 Timeline 기반 갱신

| 조건 | 갱신 주기 |
|------|----------|
| 1시간 이내 약속 | 15분 |
| 6시간 이내 약속 | 30분 |
| 그 외 | 1시간 |
| 약속 없음 | 2시간 |

**최대 갱신 주기**: 1시간 (시스템 제한 고려)

---

## 데이터 모델

### WidgetPromiseData

Widget에서 사용하는 경량화된 약속 모델

```swift
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
  public let isConfirmed: Bool
  public let participantCount: Int

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

**PromiseModel → WidgetPromiseData 변환:**
```swift
extension WidgetPromiseData {
  public init(from model: PromiseModel) {
    self.id = model.id
    self.title = model.title
    self.emoji = model.displayEmoji
    self.startAt = model.startAt
    self.endAt = model.endAt
    self.location = model.location?.name
    self.groupId = model.groupId
    self.groupName = model.group?.name
    self.isConfirmed = model.isConfirmed
    self.participantCount = model.votes.acceptedCount
    self.cachedAt = Date()
  }
}
```

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

  /// 캐시가 오래됐는지
  var hasStaleData: Bool {
    promises.contains { $0.isStale }
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
| `widget.lastUpdated` | `Date` | 마지막 업데이트 시간 |

### WidgetDataManager API

```swift
public enum WidgetDataManager {
  // MARK: - App에서 호출 (저장)

  /// 약속 목록 저장
  public static func savePromises(_ promises: [WidgetPromiseData])

  /// 사용자 ID 저장 (로그인 시)
  public static func saveUserId(_ userId: String?)

  // MARK: - Widget에서 호출 (읽기)

  /// 약속 목록 로드
  public static func loadPromises() -> [WidgetPromiseData]

  /// 로그인 상태 확인
  public static func isLoggedIn() -> Bool

  /// 마지막 업데이트 시간
  public static func lastUpdated() -> Date?

  // MARK: - 초기화

  /// 모든 데이터 삭제 (로그아웃 시)
  public static func clearAll()
}
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

## Silent Push 페이로드

### FCM 메시지 구조
```json
{
  "message": {
    "token": "<device_token>",
    "data": {
      "type": "widget_refresh"
    },
    "apns": {
      "headers": {
        "apns-priority": "5",
        "apns-push-type": "background"
      },
      "payload": {
        "aps": {
          "content-available": 1
        }
      }
    }
  }
}
```

### App에서 처리
```swift
func application(
  _ application: UIApplication,
  didReceiveRemoteNotification userInfo: [AnyHashable: Any],
  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
  guard userInfo["type"] as? String == "widget_refresh" else {
    completionHandler(.noData)
    return
  }

  Task {
    do {
      let promises = try await promiseClient.getUpcomingPromises(groupIds, 20)
      let widgetData = promises.map { WidgetPromiseData(from: $0) }
      WidgetDataManager.savePromises(widgetData)
      WidgetCenter.shared.reloadAllTimelines()
      completionHandler(.newData)
    } catch {
      completionHandler(.failed)
    }
  }
}
```

---

## 제약사항

### Widget Extension 제한

| 제한 | 대응 방안 |
|------|----------|
| 네트워크 직접 호출 불가 | App Group 캐시 사용 |
| 메모리 제한 (~30MB) | 경량 모델 (WidgetPromiseData) 사용 |
| 갱신 빈도 제한 | Silent Push + Timeline fallback |
| 별도 프로세스 | App Group으로 데이터 공유 |

### iOS 버전 분기

```swift
// Glass Effect (iOS 18+)
.containerBackground(for: .widget) {
  if #available(iOS 18.0, *) {
    Color.clear.glassEffect(.regular)
  } else {
    Color(.systemBackground).opacity(0.9)
  }
}
```

---

## 관련 문서

- [구현 가이드](../guides/WIDGET_IMPLEMENTATION.md)
- [프로젝트 컨텍스트](../PROJECT_CONTEXT.md)
