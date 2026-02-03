# Firestore 데이터베이스 스키마

## 📋 목차

1. [개요](#개요)
2. [전체 구조](#전체-구조)
3. [컬렉션 상세](#컬렉션-상세)
   - [1. users](#1-users-컬렉션)
     - [1-1. auth](#1-1-usersuseridauthmain-서브컬렉션)
     - [1-2. settings](#1-2-usersuseridsettingsmain-서브컬렉션)
     - [1-3. cache/widgetSnapshot](#1-3-usersuseridcachewidgetsnapshot-서브컬렉션)
     - [1-4. cache/homeSnapshot](#1-4-usersuseridcachehomesnapshot-서브컬렉션)
     - [1-5. groups (Map)](#1-5-usersuseridgroups-map)
   - [2. groups](#2-groups-컬렉션)
   - [3. promises](#3-promises-컬렉션)
     - [3-1. votes (Map)](#3-1-promisespromiseidvotes-map)
     - [3-2. location (Map)](#3-2-promisespromiseidlocation-map)
   - [4. notifications](#4-notifications-컬렉션)
   - [5. liveActivities](#5-liveactivities-컬렉션)
4. [쿼리 패턴](#쿼리-패턴)
5. [보안 규칙](#보안-규칙)
6. [인덱스 설정](#인덱스-설정)

---

## 개요

### 목적

Promiso 약속 관리 앱의 Firebase Firestore 데이터베이스 구조를 정의합니다.

### 설계 원칙

- **비정규화**: 읽기 성능 최적화를 위해 일부 데이터 중복 허용
- **확장성**: 사용자 및 그룹 증가에 대응 가능한 구조
- **실시간성**: 약속 상태 변경 시 즉각 반영 가능한 구조
- **쿼리 효율성**: 자주 사용하는 조회 패턴에 최적화

---

## 전체 구조

```
Firestore Root
│
├─ users/                           # 사용자 정보
│  └─ {userId}/                     # 사용자 문서
│     ├─ groups (Map)               # 사용자가 속한 그룹 목록 (Map 필드)
│     │                             # { [groupId]: { groupName, role, joinedAt, notifications } }
│     ├─ auth/                      # 인증 정보 (서브컬렉션)
│     │  └─ main                    # 고정 문서 ID
│     ├─ settings/                  # 설정 정보 (서브컬렉션)
│     │  └─ main                    # 고정 문서 ID
│     └─ cache/                     # 캐시 데이터 (서브컬렉션)
│        └─ widgetSnapshot          # 위젯용 스냅샷 (Trigger 자동 갱신)
│
├─ groups/                          # 그룹 정보
│  └─ {groupId}/                    # 그룹 문서
│
├─ promises/                        # 약속 정보
│  └─ {promiseId}/                  # 약속 문서
│     ├─ votes (Map)                # 투표 상태별 userId 배열
│     │                             # { accepted: [...], declined: [...] }
│     └─ location (Map)             # 장소 정보 (선택)
│                                   # { name: "..." }
│
├─ notifications/                   # 알림 정보
│  └─ {notificationId}/             # 알림 문서
│
└─ liveActivities/                  # LiveActivity 상태 정보
   └─ {promiseId}/                  # 약속별 LiveActivity 상태
      └─ participants (Array)       # 참가자별 ETA 상태
```

---

## 컬렉션 상세

### 1. users (컬렉션)

사용자 기본 정보를 저장합니다.

#### 🔑 문서 위치 (Document Path)

- 컬렉션: `users`
- 문서 ID: `{uid}` (Firebase Auth UID 그대로 사용)
  - 예시: `users/sFeDJwqJbqScbSUp4Jz54MDlnFv1`

> ⚠️ `user_{uid}` 형태가 아닌 **UID 그대로를 문서 ID로 사용**

#### 📊 필드 구조

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `name` | String | ✅ | provider에서 받은 이름 또는 닉네임 (생성 시 없으면 nickname 사용) |
| `nickname` | String | ✅ | 사용자가 설정한 표시명 |
| `profile` | Profile | ❌ | 프로필 이미지 정보 (하단 참조) |
| `groups` | Map<String, UserGroupInfo> | ❌ | 사용자가 속한 그룹 목록 (Map 필드, 하단 참조) |
| `devices` | Map<String, DeviceInfo> | ❌ | FCM 토큰 및 디바이스 정보 (하단 참조) |
| `metaData` | MetaData | ✅ | 메타데이터 (하단 참조) |

> ⚠️ **이메일은 보안을 위해 `users/{userId}/auth/main` 서브컬렉션에만 저장됩니다.**

#### 📦 Profile

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `url` | String | ✅ | 원본 이미지 (Firebase Storage downloadURL) |
| `thumbUrl` | String | ❌ | 썸네일 (Cloud Functions 자동 생성, 생성 전에는 없을 수 있음) |
| `updatedAt` | Timestamp | ✅ | 프로필 이미지 업데이트 시각 |

#### 📦 MetaData

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `createdAt` | Timestamp | ✅ | 계정 생성 시각 |
| `updatedAt` | Timestamp | ✅ | 마지막 수정 시각 |

#### 📦 DeviceInfo (devices Map의 Value)

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `fcmToken` | String | ✅ | Firebase Cloud Messaging 토큰 |
| `platform` | String | ✅ | 플랫폼 (`ios` \| `android`) |
| `lastActiveAt` | Timestamp | ✅ | 마지막 활성 시각 |
| `createdAt` | Timestamp | ✅ | 토큰 등록 시각 |
| `liveActivityPushToStartToken` | String | ❌ | LiveActivity Push to Start 토큰 (iOS 17.2+) |
| `liveActivityPushToken` | String | ❌ | LiveActivity Push 토큰 (개별 Activity용) |

> 💡 **Key**: 디바이스 고유 ID (UUID, 앱 설치 시 생성)

#### 📝 Functions 사용 필드

- `name`, `nickname`, `profile.thumbUrl`을 그룹/약속 캐시 값으로 사용

#### 🖼️ 프로필 이미지 플로우

**업로드 → 썸네일 자동 생성**
```
1. 사용자가 이미지 업로드 → Firebase Storage
2. profile.url 업데이트 (원본 downloadURL)
3. Cloud Function 트리거 → 썸네일 생성
4. profile.thumbUrl 자동 업데이트 (Cloud Functions)
```

**1️⃣ 이미지 없음**
```json
// profile 필드를 아예 저장하지 않음
```

**2️⃣ 이미지 업로드 직후 (썸네일 생성 전)**
```json
"profile": {
  "url": "https://storage.googleapis.com/.../original.jpg",
  "updatedAt": "2025-01-05T10:00:00Z"
}
// thumbUrl은 아직 없음 (Cloud Functions 생성 대기 중)
```

**3️⃣ 썸네일 생성 완료**
```json
"profile": {
  "url": "https://storage.googleapis.com/.../original.jpg",
  "thumbUrl": "https://storage.googleapis.com/.../thumb_200x200.jpg",
  "updatedAt": "2025-01-05T10:00:00Z"
}
// Cloud Functions가 thumbUrl 추가 (updatedAt은 변경 안 함)
```

#### 📝 예시 도큐먼트

```json
{
  "name": "김성원",
  "nickname": "성원",
  "profile": {
    "url": "https://storage.googleapis.com/promiso-dev.appspot.com/profile_images/sFeDJwqJbqScbSUp4Jz54MDlnFv1.jpg",
    "thumbUrl": "https://storage.googleapis.com/promiso-dev.appspot.com/profile_images/thumb_sFeDJwqJbqScbSUp4Jz54MDlnFv1.jpg",
    "updatedAt": "2025-01-05T10:00:00Z"
  },
  "metaData": {
    "createdAt": "2024-12-19T10:00:00Z",
    "updatedAt": "2025-01-05T10:00:00Z"
  }
}
```

---

### 1-1. users/{userId}/auth/main (서브컬렉션)

사용자의 인증 정보를 저장합니다. (보안 목적으로 분리)

#### 📍 문서 경로

```
users/{userId}/auth/main
```

#### 🔑 문서 ID

- 고정값: `main`

#### 📊 필드 구조

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `provider` | Provider | ✅ | 인증 제공자 정보 (하단 참조) |

#### 📦 Provider 구조

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `type` | String | ✅ | 인증 제공자 타입 (`google`, `apple` 등) |
| `uid` | String | ✅ | 제공자 기준 사용자 고유 ID |
| `email` | String | ✅ | 제공자에서 받은 이메일 |

#### 📝 예시 데이터

```json
{
  "provider": {
    "type": "google",
    "uid": "100163668057674322269",
    "email": "kswen0203@gmail.com"
  }
}
```

#### 💡 설계 의도

- **보안**: Firestore Security Rules로 owner만 읽기 가능하도록 제어
- **분리**: 민감한 인증 정보를 메인 문서와 분리

---

### 1-2. users/{userId}/settings/main (서브컬렉션)

사용자의 설정 정보를 저장합니다.

#### 📍 문서 경로

```
users/{userId}/settings/main
```

#### 🔑 문서 ID

- 고정값: `main`

#### 📊 필드 구조

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| `notificationEnabled` | Boolean | ✅ | true | 푸시 알림 활성화 여부 |
| `plan` | String | ❌ | "free" | 사용자 플랜 (`free` \| `pro`) |
| `groupSortOption` | Map | ❌ | `{type: "joinedRecent"}` | 그룹 정렬 설정 |
| `groupSortOption.type` | String | ✅ | "joinedRecent" | 정렬 타입 (`joinedRecent` \| `joinedOldest` \| `nameAscending` \| `nameDescending` \| `custom`) |
| `groupSortOption.order` | Array<String> | ❌ | - | 커스텀 정렬 시 그룹 ID 순서 (type이 `custom`일 때만) |

#### 📝 예시 데이터

```json
{
  "notificationEnabled": true,
  "plan": "free",
  "groupSortOption": {
    "type": "joinedRecent"
  }
}
```

#### 💡 설계 의도

- **확장성**: 나중에 theme, language, privacy 등 추가 설정 확장 가능
- **독립성**: 설정 변경 시 메인 문서 updatedAt 영향 없음

---

### 1-3. users/{userId}/cache/widgetSnapshot (서브컬렉션)

> ⚠️ **Deprecated**: 위젯은 이제 직접 쿼리 방식으로 변경됨 (2026-02)
> 이 캐시 문서는 더 이상 사용되지 않습니다.

위젯 데이터는 Cloud Functions API (`getWidgetSnapshot`, `getWidgetSnapshotWithToken`)에서
Firestore를 직접 쿼리하여 반환합니다.

#### 📊 위젯 API 응답 구조

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `next` | WidgetPromise \| null | ✅ | Small 위젯용 다음 약속 |
| `today` | Array<WidgetPromise> | ✅ | Medium 위젯용 오늘 약속 (최대 3개) |
| `upcoming` | Array<WidgetPromise> | ✅ | Large 위젯용 다가오는 약속 (최대 4개) |
| `meta` | SnapshotMeta | ✅ | 메타데이터 |

#### 📦 WidgetPromise 구조 (SnapshotPromise 공용)

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `id` | String | ✅ | 약속 ID |
| `title` | String | ✅ | 약속 제목 |
| `emoji` | String | ✅ | 대표 이모지 (기본: "📅") |
| `startAt` | String | ✅ | 시작 시간 (ISO 8601) |
| `endAt` | String \| null | ❌ | 종료 시간 (ISO 8601) |
| `location` | String \| null | ❌ | 장소명 |
| `groupId` | String | ✅ | 그룹 ID |
| `groupName` | String \| null | ❌ | 그룹 이름 |
| `groupImageUrl` | String \| null | ❌ | 그룹 이미지 URL |
| `isConfirmed` | Boolean | ✅ | 약속 확정 여부 |
| `minimumParticipants` | Number | ✅ | 최소 확정 인원 |
| `participantCount` | Number | ✅ | 참여 확정 인원 |
| `myVoteStatus` | String | ✅ | 내 투표 상태 (`pending` \| `voted` \| `declined`) |
| `votingDeadline` | String \| null | ❌ | 투표 마감 시간 (ISO 8601) |

> 💡 Widget과 Home에서 동일한 SnapshotPromise 타입을 공유합니다.

#### 📦 SnapshotMeta 구조

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `todayCount` | Number | ✅ | 오늘 약속 개수 |
| `upcomingCount` | Number | ✅ | 다가오는 약속 개수 |
| `updatedAt` | String | ✅ | 마지막 갱신 시간 (ISO 8601) |
| `version` | Number | ✅ | 스키마 버전 (현재 1) |

#### 📊 우선순위 정렬

약속은 다음 우선순위로 정렬됩니다:

| 순서 | 조건 | 설명 |
|------|------|------|
| 1순위 | `myVoteStatus === "pending"` | 투표 필요한 약속 |
| 2순위 | `isConfirmed === false` | 미확정 약속 |
| 3순위 | `startAt` 오름차순 | 시간순 |

#### 📝 예시 데이터

```json
{
  "next": {
    "id": "promise123",
    "title": "점심 약속",
    "emoji": "🍜",
    "startAt": "2025-02-01T12:00:00+09:00",
    "endAt": null,
    "location": "강남역 2번 출구",
    "groupId": "group456",
    "groupName": "대학 동기",
    "isConfirmed": false,
    "participantCount": 2,
    "myVoteStatus": "pending"
  },
  "today": [
    { "id": "promise123", ... },
    { "id": "promise456", ... }
  ],
  "upcoming": [
    { "id": "promise789", ... }
  ],
  "meta": {
    "todayCount": 2,
    "upcomingCount": 1,
    "updatedAt": "2025-02-01T10:30:00+09:00",
    "version": 1
  }
}
```

#### 🔄 데이터 갱신 방식 (Direct Query)

| 시점 | 설명 |
|------|------|
| 위젯 타임라인 갱신 | WidgetKit이 결정한 시점에 API 호출 |
| 사용자 수동 갱신 | 위젯 새로고침 버튼 탭 시 |

#### 📊 쿼리 조건

```typescript
.where("groupId", "in", userGroupIds)
.where("isConfirmed", "==", true)  // 확정된 약속만
.where("startAt", ">=", now)
.orderBy("startAt", "asc")
.limit(7)
```

#### 💡 설계 의도

- **비용 효율**: 위젯 사용자만 API 호출 (스냅샷 방식 대비 효율적)
- **최신 데이터**: API 호출 시점에 항상 최신 데이터 반환
- **단순화**: Trigger 없이 단순한 쿼리로 구현

---

### 1-4. users/{userId}/cache/homeSnapshot (서브컬렉션)

> ⚠️ **Deprecated**: 홈화면은 이제 직접 쿼리 방식으로 변경됨 (2026-02)
> 이 캐시 문서는 더 이상 사용되지 않습니다.

홈화면 데이터는 iOS 앱에서 Firestore를 직접 쿼리하여 가져옵니다.

#### 📊 홈화면 쿼리 방식

| 시점 | 설명 |
|------|------|
| `onAppear` | 홈화면 진입 시 |
| `background → foreground` | 앱이 다시 활성화될 때 |

#### 📊 쿼리 조건

```swift
// getHomePromises (PromiseClient)
.whereField("groupId", in: groupIds)  // 10개씩 청크
.whereField("startAt", isGreaterThanOrEqualTo: now)
.order(by: "startAt")
.limit(to: 10)
```

#### 📊 클라이언트 분류 (HomeFeature)

| 분류 | 조건 |
|------|------|
| `todayPromises` | 오늘 날짜 + 확정된 약속 (최대 5개) |
| `pendingPromises` | 미응답 상태 + 마감 임박순 (최대 5개) |
| `upcomingPromises` | 내일 이후 + 확정된 약속 (최대 10개) |

#### ~~기존 필드 구조 (Deprecated)~~

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `todayPromises` | Array<SnapshotPromise> | ✅ | 오늘 확정된 약속 (최대 5개) |
| `pendingPromises` | Array<SnapshotPromise> | ✅ | 응답 필요 약속 (최대 5개, 마감 임박순) |
| `upcomingPromises` | Array<SnapshotPromise> | ✅ | 다가오는 확정 약속 (최대 10개) |
| `groups` | Array<HomeSnapshotGroup> | ✅ | 그룹별 요약 정보 |
| `meta` | HomeSnapshotMeta | ✅ | 메타데이터 |

#### 📦 SnapshotPromise 구조 (Widget/Home 공용)

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `id` | String | ✅ | 약속 ID |
| `title` | String | ✅ | 약속 제목 |
| `emoji` | String | ✅ | 대표 이모지 (기본: "📅") |
| `startAt` | String | ✅ | 시작 시간 (ISO 8601) |
| `endAt` | String \| null | ❌ | 종료 시간 (ISO 8601) |
| `location` | String \| null | ❌ | 장소명 |
| `groupId` | String | ✅ | 그룹 ID |
| `groupName` | String \| null | ❌ | 그룹 이름 |
| `groupImageUrl` | String \| null | ❌ | 그룹 이미지 URL |
| `isConfirmed` | Boolean | ✅ | 약속 확정 여부 |
| `minimumParticipants` | Number | ✅ | 최소 확정 인원 |
| `participantCount` | Number | ✅ | 참여 확정 인원 |
| `myVoteStatus` | String | ✅ | 내 투표 상태 (`pending` \| `voted` \| `declined`) |
| `votingDeadline` | String \| null | ❌ | 투표 마감 시간 (ISO 8601) |

#### 📦 HomeSnapshotGroup 구조

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `id` | String | ✅ | 그룹 ID |
| `name` | String | ✅ | 그룹 이름 |
| `emoji` | String \| null | ❌ | 그룹 이모지 |
| `imageUrl` | String \| null | ❌ | 그룹 이미지 URL |
| `nextPromise` | SnapshotPromise \| null | ❌ | 다음 약속 |

#### 📦 HomeSnapshotMeta 구조

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `todayCount` | Number | ✅ | 오늘 약속 개수 |
| `pendingCount` | Number | ✅ | 응답 필요 약속 개수 |
| `upcomingCount` | Number | ✅ | 다가오는 약속 개수 |
| `updatedAt` | String | ✅ | 마지막 갱신 시간 (ISO 8601) |
| `version` | Number | ✅ | 스키마 버전 (현재 1) |

#### 📝 예시 데이터

```json
{
  "todayPromises": [
    {
      "id": "promise123",
      "title": "점심 약속",
      "emoji": "🍜",
      "startAt": "2026-02-01T12:00:00+09:00",
      "endAt": null,
      "location": "강남역 2번 출구",
      "groupId": "group456",
      "groupName": "대학 동기",
      "groupImageUrl": null,
      "isConfirmed": true,
      "minimumParticipants": 2,
      "participantCount": 3,
      "myVoteStatus": "voted",
      "votingDeadline": "2026-02-01T10:00:00+09:00"
    }
  ],
  "pendingPromises": [
    {
      "id": "promise789",
      "title": "주말 모임",
      "emoji": "🎉",
      "startAt": "2026-02-03T18:00:00+09:00",
      "groupId": "group456",
      "groupName": "대학 동기",
      "isConfirmed": false,
      "minimumParticipants": 3,
      "participantCount": 1,
      "myVoteStatus": "pending",
      "votingDeadline": "2026-02-02T18:00:00+09:00"
    }
  ],
  "upcomingPromises": [],
  "groups": [
    {
      "id": "group456",
      "name": "대학 동기",
      "emoji": null,
      "imageUrl": null,
      "nextPromise": { ... }
    }
  ],
  "meta": {
    "todayCount": 1,
    "pendingCount": 1,
    "upcomingCount": 0,
    "updatedAt": "2026-02-01T10:30:00+09:00",
    "version": 1
  }
}
```

#### 💡 설계 의도

- **실시간성**: 화면 진입 시 항상 최신 데이터
- **단순화**: Trigger 없이 직접 쿼리
- **클라이언트 분류**: 서버 부하 감소, 유연한 UI 대응

---

### 1-5. users/{userId}.groups (Map)

사용자가 속한 그룹 목록을 저장합니다. (캐싱 목적)

#### 📍 필드 경로

```
users/{userId}.groups
```

#### 🗂️ Map 구조

- **Key**: `{groupId}` (그룹 ID, 예: `0ec6e63d-8d80-4a76-9e1b-7f226c1c6b55`)
- **Value**: `UserGroupInfo` 객체 (하단 참조)

#### 📊 UserGroupInfo 구조

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `groupName` | String | ✅ | 그룹 이름 (캐시) |
| `role` | String | ✅ | 역할 (`admin` \| `member`) |
| `joinedAt` | Timestamp | ✅ | 그룹 가입 시각 |
| `notifications` | Map | ✅ | 그룹 알림 설정 (enabled/promise/group) |
| `hasNewActivity` | Boolean | ✅ | 새 활동 여부 (약속 생성/변경 시 true → 확인 시 false) |
| `imageUrl` | String | ❌ | 그룹 이미지 URL |

#### 📝 예시 데이터

```json
{
  "groups": {
    "0ec6e63d-8d80-4a76-9e1b-7f226c1c6b55": {
      "groupName": "대학 친구들",
      "role": "admin",
      "joinedAt": "2024-01-01T10:00:00+09:00",
      "notifications": {
        "enabled": true,
        "promise": {
          "invitation": true,
          "reminder": true,
          "confirmed": true,
          "cancelled": true,
          "updated": true,
          "attendanceResponse": true
        },
        "group": {
          "update": true
        }
      },
      "hasNewActivity": false,
      "imageUrl": null
    },
    "abc123def456": {
      "groupName": "회사 동료",
      "role": "member",
      "joinedAt": "2024-02-15T10:00:00+09:00",
      "notifications": {
        "enabled": true,
        "promise": {
          "invitation": false,
          "reminder": true,
          "confirmed": true,
          "cancelled": true,
          "updated": true,
          "attendanceResponse": true
        },
        "group": {
          "update": true
        }
      },
      "hasNewActivity": true,
      "imageUrl": "https://firebasestorage.googleapis.com/..."
    }
  }
}
```

#### 💡 설계 의도

- **읽기 비용 절감**: 서브컬렉션 방식(N회 읽기) → Map 방식(1회 읽기)
  - 10개 그룹 기준: 10 reads → 1 read (90% 절감)
- **빠른 조회**: 단일 문서 읽기로 모든 그룹 정보 조회
- **캐싱**: groupName을 캐싱하여 groups 컬렉션 조회 횟수 감소
- **정렬**: iOS에서 joinedAt 기준 정렬

---

### 2. groups (컬렉션)

그룹 정보를 저장합니다.

#### 📍 문서 경로

```
groups/{groupId}
```

#### 🔑 문서 ID

- Firestore 자동 생성 ID 사용
- 예시: `xYz9Abc123Def456`

#### 📊 필드 구조

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| `name` | String | ✅ | - | 그룹 이름 |
| `description` | String | ❌ | null | 그룹 설명 |
| `imageUrl` | String | ❌ | null | 그룹 이미지 downloadURL (Firebase Storage) |
| `memberIds` | Array<String> | ✅ | [] | 멤버 ID 목록 |
| `maxMembers` | Number | ✅ | - | 최대 인원 (2~10) |
| `inviteCode` | String | ✅ | - | 초대 코드 (6자리 영숫자, 유니크) |
| `createdBy` | String | ✅ | - | 생성자 ID |
| `createdAt` | Timestamp | ✅ | - | 생성 시각 |
| `updatedAt` | Timestamp | ✅ | - | 마지막 수정 시각 |

#### 📝 예시 데이터

```json
{
  "name": "주말 등산 모임",
  "description": "주말마다 등산하는 모임입니다",
  "imageUrl": "https://firebasestorage.googleapis.com/v0/b/promiso-20274.firebasestorage.app/o/group_images%2F0ec6e63d-8d80-4a76-9e1b-7f226c1c6b55%2Fmain.jpg?alt=media",
  "memberIds": [
    "sFeDJwqJbqScbSUp4Jz54MDlnFv1",
    "user2Id",
    "user3Id",
    "user4Id",
    "user5Id"
  ],
  "maxMembers": 10,
  "inviteCode": "AB12CD",
  "createdBy": "sFeDJwqJbqScbSUp4Jz54MDlnFv1",
  "createdAt": "<Timestamp>",
  "updatedAt": "<Timestamp>"
}
```

#### 💡 설계 의도

- **단순성**: 멤버 정보는 users 컬렉션에서 직접 조회 (캐시 동기화 불필요)
- **데이터 일관성**: 항상 최신 사용자 정보 보장 (프로필 변경 즉시 반영)
- **확장성**: memberIds 배열로 멤버 관리
- **복잡도 감소**: Cloud Functions Trigger 불필요

#### 🔄 멤버 조회 방식

**1. 그룹 생성/참여**
```typescript
// createGroup
await groupRef.set({
  memberIds: [creatorId],
  // ...
});

await usersCollection.doc(creatorId).set({
  groups: {
    [groupId]: {
      groupName: name,
      role: "admin",
      joinedAt: now,
      notifications: true
    }
  }
}, { merge: true });

// joinGroup
await groupRef.update({
  memberIds: FieldValue.arrayUnion(userId)
});

await usersCollection.doc(userId).set({
  groups: {
    [groupId]: {
      groupName: groupName,
      role: "member",
      joinedAt: now,
      notifications: true
    }
  }
}, { merge: true });
```

**2. 멤버 리스트 조회 (previewGroup 등)**
```typescript
// 1. groups/{groupId} 조회 → memberIds 가져오기 (1 read)
const groupDoc = await groupRef.get();
const memberIds = groupDoc.data().memberIds;

// 2. 각 userId로 users/{userId} 조회 (병렬) (N reads)
const userPromises = memberIds.map(userId =>
  usersCollection.doc(userId).get()
);
const userDocs = await Promise.all(userPromises);

// 3. 사용자 정보 직접 사용 (항상 최신)
const members = userDocs.map(doc => ({
  userId: doc.id,
  name: doc.data().nickname,
  profileImage: doc.data().profile
}));
```

#### ⚡ 성능 및 비용 효과

| 항목 | memberIds 방식 | 비고 |
|------|---------------|------|
| 그룹 조회 reads | 1회 (groups 문서) | |
| 멤버 정보 reads | N회 (users 컬렉션, 병렬) | 10명 = 10 reads |
| **총 reads** | **11회** | 10명 기준 |
| 프로필 변경 writes | 0회 | 동기화 불필요 |
| 응답 속도 | 빠름 (병렬 조회) | |
| 데이터 일관성 | **항상 최신** | ✅ |
| 복잡도 | **낮음** | Trigger 불필요 |

---

### 3. promises (컬렉션)

약속(일정) 정보를 저장합니다.

#### 📍 문서 경로

```
promises/{promiseId}
```

#### 🔑 문서 ID

- Firestore 자동 생성 ID 사용
- 예시: `xYz9Abc123Def456`

#### 📊 필드 구조

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| `title` | String | ✅ | - | 약속 제목 |
| `emoji` | String | ❌ | null | 약속 대표 이모지 |
| `description` | String | ❌ | null | 약속 설명 |
| `hostId` | String | ✅ | - | 호스트(생성자) ID |
| `groupId` | String | ✅ | - | 그룹 ID |
| `minimumParticipants` | Number | ✅ | 2 | 최소 참가자 수 (확정 기준) |
| `isConfirmed` | Boolean | ✅ | false | 약속 확정 여부 (비정규화, 투표 시 자동 갱신) |
| `votes` | Votes | ✅ | - | 투표 정보 (하단 참조) |
| `startAt` | Timestamp | ✅ | - | 시작 시각 |
| `endAt` | Timestamp | ❌ | null | 종료 시각 |
| `location` | Location | ❌ | null | 장소 정보 (하단 참조) |
| `trackingStartMinutesBefore` | Number | ❌ | null | LiveActivity 시작 시간 (약속 N분 전) |
| `liveActivityScheduled` | Boolean | ❌ | false | LiveActivity 예약 완료 여부 |
| `liveActivityScheduledAt` | Timestamp | ❌ | null | LiveActivity 예약 시각 |
| `createdAt` | Timestamp | ✅ | - | 생성 시각 |
| `updatedAt` | Timestamp | ✅ | - | 수정 시각 |

#### 📝 예시 데이터

```json
{
  "title": "영화 관람",
  "emoji": "🍿",
  "description": "마블 신작 보러 가기",
  "hostId": "user_kim123",
  "groupId": "group_friends",
  "minimumParticipants": 2,
  "isConfirmed": true,
  "votes": {
    "accepted": ["user_kim123", "user_lee456", "user_park789"],
    "declined": ["user_choi012"],
    "until": "2024-01-15T19:00:00+09:00"
  },
  "startAt": "2024-01-15T19:00:00+09:00",
  "endAt": "2024-01-15T21:30:00+09:00",
  "location": {
    "name": "CGV 강남",
    "address": "서울 강남구 강남대로 438",
    "latitude": 37.501087,
    "longitude": 127.026632
  },
  "createdAt": "2024-01-14T10:00:00+09:00",
  "updatedAt": "2024-01-14T18:00:00+09:00"
}
```

#### 💡 설계 의도

- **읽기 비용 절감**: 1 promise + N attendances → 1 promise (90% 절감)
- **단순화**: 서브컬렉션 관리 불필요, 트랜잭션 단순화
- **실시간 업데이트**: 단일 문서 리스너로 모든 투표 상태 감지
- **문서 크기**: userId 28자 × 10명 × 2상태 ≈ 1KB (그룹 최대 10명)
- **isConfirmed 비정규화**: 쿼리 효율성을 위해 확정 여부를 별도 필드로 저장 (투표 시 자동 갱신)

---

### 3-1. promises/{promiseId}.votes (Map)

투표 상태별 userId 배열을 저장합니다.

#### 📍 필드 경로

```
promises/{promiseId}.votes
```

#### 📦 Votes 구조

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| `accepted` | Array<String> | ✅ | [] | 참여 확정한 userId 목록 |
| `declined` | Array<String> | ✅ | [] | 참여 불가한 userId 목록 |
| `until` | Timestamp | ✅ | startAt | 투표 마감 시각 (기본값: startAt)

#### 📊 투표 상태 (VoteStatus)

| 상태 | 저장 방식 | 설명 |
|------|----------|------|
| `pending` | 계산 | groups/{groupId}.memberIds - votes.accepted - votes.declined |
| `accepted` | votes.accepted 배열 | 참여 확정 |
| `declined` | votes.declined 배열 | 참여 불가 |

#### 🔧 Set-like 동작

Firestore에는 Set 타입이 없지만, `arrayUnion`/`arrayRemove`로 Set처럼 사용:

```typescript
// 추가 (중복 자동 방지)
await promiseRef.update({
  "votes.accepted": FieldValue.arrayUnion(userId)
});

// 제거
await promiseRef.update({
  "votes.accepted": FieldValue.arrayRemove(userId)
});

// 포함 여부 확인 (쿼리)
.where("votes.accepted", "array-contains", userId)
```

#### 📝 계산 로직

```swift
// pending 멤버 계산
func pendingMembers(memberIds: [String]) -> [String] {
  memberIds.filter { !votes.accepted.contains($0) && !votes.declined.contains($0) }
}

// 확정 여부
var isConfirmed: Bool {
  votes.accepted.count >= minimumParticipants
}

// 내 투표 상태
func myVoteStatus(userId: String) -> VoteStatus {
  if votes.accepted.contains(userId) { return .accepted }
  if votes.declined.contains(userId) { return .declined }
  return .pending
}
```

#### 📝 예시 데이터

```json
{
  "votes": {
    "accepted": ["user_kim123", "user_lee456", "user_park789"],
    "declined": ["user_choi012"],
    "until": "2024-01-15T19:00:00+09:00"
  }
}
```

#### 💡 설계 의도

- **attendances 서브컬렉션 제거**: votes Map으로 대체하여 읽기 비용 90% 절감
- **counts 필드 제거**: votes 배열에서 실시간 계산
- **pending 상태**: memberIds에서 계산 (저장하지 않음)
- **until**: 생성 시 startAt으로 설정, 추후 투표 기간 커스텀 가능
- **확정 여부**: `votes.accepted.count >= minimumParticipants`로 계산 (isConfirmed)
- **과거 여부**: `endAt < now` 또는 `startAt < now`로 계산 (isPast) - 클라이언트에서 처리

---

### 3-2. promises/{promiseId}.location (Map)

약속 장소 정보를 저장합니다.

#### 📍 필드 경로

```
promises/{promiseId}.location
```

#### 📦 Location 구조

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `name` | String | ✅ | 장소명 |
| `address` | String | ❌ | 주소 |
| `latitude` | Number | ❌ | 위도 |
| `longitude` | Number | ❌ | 경도 |

#### 📝 예시 데이터

```json
{
  "location": {
    "name": "스타벅스 강남역점",
    "address": "서울 강남구 강남대로 390",
    "latitude": 37.498095,
    "longitude": 127.027610
  }
}
```

#### 💡 설계 의도

- **지도 연동**: Kakao Maps SDK 연동으로 좌표 및 주소 저장
- **역지오코딩 가능**: 저장된 좌표로 지도 표시 및 길찾기 기능 연동 가능

---

### 4. notifications (컬렉션)

사용자별 알림 정보를 저장합니다. Firebase Functions에서 푸시 알림 전송 시 자동 생성됩니다.

#### 📍 문서 경로

```
notifications/{notificationId}
```

#### 🔑 문서 ID

- Firestore 자동 생성 ID 사용
- 예시: `notif_auto_id_001`

#### 📊 필드 구조

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| `userId` | String | ✅ | - | 수신자 ID |
| `type` | String | ✅ | - | 알림 타입 (하단 참조) |
| `title` | String | ✅ | - | 알림 제목 |
| `body` | String | ✅ | - | 알림 내용 |
| `promiseId` | String | ❌ | null | 관련 약속 ID |
| `groupId` | String | ❌ | null | 관련 그룹 ID |
| `relatedUserId` | String | ❌ | null | 관련 사용자 ID (예: 약속 생성자) |
| `isRead` | Boolean | ✅ | false | 읽음 여부 |
| `isDelivered` | Boolean | ✅ | false | FCM 전송 성공 여부 |
| `createdAt` | Timestamp | ✅ | - | 생성 시각 |
| `readAt` | Timestamp | ❌ | null | 읽은 시각 |
| `deliveredAt` | Timestamp | ❌ | null | FCM 전송 시각 |
| `data` | Map<String, String> | ❌ | null | 추가 데이터 |

#### 📊 type 값 정의 (NotificationType)

| 값 | 의미 | 설명 |
|----|------|------|
| `promise_invitation` | 약속 초대 | 새 약속에 초대됨 |
| `promise_reminder` | 리마인더 | 약속 시작 전 알림 |
| `promise_confirmed` | 약속 확정 | 최소 인원 충족으로 약속 확정 |
| `promise_cancelled` | 약속 무산 | 참여 인원 부족으로 약속 미확정 |
| `promise_updated` | 약속 수정 | 약속 정보 변경 |
| `group_invitation` | 그룹 초대 | 새 그룹에 초대됨 |
| `group_update` | 그룹 업데이트 | 그룹 정보 변경 (새 멤버 참여 등) |
| `attendance_response` | 응답 변경 | 다른 멤버의 참석 응답 |
| `system` | 시스템 | 시스템 알림 |

#### 📝 예시 데이터

```json
{
  "userId": "user_kim123",
  "type": "promise_invitation",
  "title": "대학 친구들에 새 약속",
  "body": "성원님이 \"영화 관람\" 약속을 만들었어요",
  "promiseId": "promise_movie_abc123",
  "groupId": "group_friends",
  "relatedUserId": "user_sungwon",
  "isRead": false,
  "isDelivered": true,
  "createdAt": "2024-01-14T18:00:00+09:00",
  "readAt": null,
  "deliveredAt": "2024-01-14T18:00:01+09:00",
  "data": null
}
```

---

### 5. liveActivities (컬렉션)

LiveActivity 실시간 상태 정보를 저장합니다. Firebase Functions에서 ETA 업데이트 시 생성/수정됩니다.

#### 📍 문서 경로

```
liveActivities/{promiseId}
```

#### 🔑 문서 ID

- 약속 ID 사용 (promises 컬렉션과 1:1 매핑)
- 예시: `xYz9Abc123Def456`

#### 📊 필드 구조

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `promiseId` | String | ✅ | 약속 ID |
| `participants` | Array<ParticipantState> | ✅ | 참가자별 ETA 상태 |
| `trackingDurationMinutes` | Number | ✅ | 추적 시간 (기본 30분) |
| `createdAt` | Timestamp | ✅ | 생성 시각 |
| `updatedAt` | Timestamp | ✅ | 마지막 업데이트 시각 |

#### 📦 ParticipantState

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `id` | String | ✅ | 참가자 userId |
| `name` | String | ✅ | 참가자 표시 이름 |
| `estimatedArrivalMinutes` | Number \| null | ✅ | ETA (null=대기, 0=도착, N=N분 후) |

#### 📝 예시 데이터

```json
{
  "promiseId": "xYz9Abc123Def456",
  "participants": [
    {"id": "user_kim123", "name": "김민수", "estimatedArrivalMinutes": 0},
    {"id": "user_lee456", "name": "이지현", "estimatedArrivalMinutes": 5},
    {"id": "user_park789", "name": "박서연", "estimatedArrivalMinutes": null}
  ],
  "trackingDurationMinutes": 30,
  "createdAt": "2024-01-15T18:00:00+09:00",
  "updatedAt": "2024-01-15T18:30:00+09:00"
}
```

#### 💡 설계 의도

- **임시 데이터**: LiveActivity가 종료되면 문서 삭제
- **APNs 동기화**: updateETA 호출 시 이 문서를 업데이트하고 APNs로 브로드캐스트
- **단일 문서**: 약속당 하나의 문서로 모든 참가자 상태 관리

---

## 쿼리 패턴

### 1. 사용자 관련 쿼리

#### 내가 속한 그룹 목록 조회

```swift
// 1. users/{userId} 문서 조회 (1 read)
let userDoc = try await db.collection("users")
  .document(userId)
  .getDocument()

// 2. groups Map에서 그룹 정보 추출
let groupsMap = userDoc.data()?["groups"] as? [String: [String: Any]] ?? [:]

// 3. iOS에서 joinedAt으로 정렬
let groupSummaries = groupsMap.compactMap { (groupId, groupData) in
  GroupSummary(id: groupId, data: groupData)
}.sorted { $0.joinedAt ?? Date() > $1.joinedAt ?? Date() }
```

#### 사용자 설정 조회

```swift
db.collection("users")
  .document(userId)
  .collection("settings")
  .document("main")
  .getDocument()
```

#### 사용자 인증 정보 조회 (서버 전용)

```swift
db.collection("users")
  .document(userId)
  .collection("auth")
  .document("main")
  .getDocument()
```

---

### 2. 그룹 관련 쿼리

#### 그룹 멤버 목록 조회

```swift
// 1. groups/{groupId} 조회 → memberIds 가져오기 (1 read)
let groupDoc = try await db.collection("groups")
  .document(groupId)
  .getDocument()

let memberIds = groupDoc.data()?["memberIds"] as? [String] ?? []

// 2. 각 userId로 users/{userId} 조회 (병렬, N reads)
let userDocs = try await withThrowingTaskGroup(of: DocumentSnapshot.self) { group in
  for userId in memberIds {
    group.addTask {
      try await db.collection("users").document(userId).getDocument()
    }
  }
  return try await group.reduce(into: []) { $0.append($1) }
}

// 3. 사용자 정보 직접 사용 (항상 최신)
let members = userDocs.compactMap { doc -> UserPublic? in
  let data = doc.data()
  return UserPublic(
    userId: doc.documentID,
    name: data?["name"] as? String ?? "",
    nickname: data?["nickname"] as? String ?? "",
    profile: parseProfile(data?["profile"])
  )
}
```

#### 초대 코드로 그룹 찾기

```swift
db.collection("groups")
  .whereField("inviteCode", isEqualTo: inviteCode)
  .limit(to: 1)
  .getDocuments()
```

---

### 3. 약속 관련 쿼리

#### 특정 그룹의 약속 목록 (날짜순)

```swift
db.collection("promises")
  .whereField("groupId", isEqualTo: groupId)
  .order(by: "startAt", descending: false)
  .getDocuments()
```

#### 오늘의 약속 조회

```swift
let startOfDay = Calendar.current.startOfDay(for: Date())
let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
db.collection("promises")
  .whereField("groupId", isEqualTo: groupId)
  .whereField("startAt", isGreaterThanOrEqualTo: startOfDay)
  .whereField("startAt", isLessThan: endOfDay)
  .order(by: "startAt", descending: false)
  .getDocuments()
```

#### 특정 월의 약속 조회

```swift
let startOfMonth = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!
let endOfMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)!
db.collection("promises")
  .whereField("groupId", isEqualTo: groupId)
  .whereField("startAt", isGreaterThanOrEqualTo: startOfMonth)
  .whereField("startAt", isLessThan: endOfMonth)
  .order(by: "startAt", descending: false)
  .getDocuments()
```

---

### 4. 알림 관련 쿼리

#### 안 읽은 알림 조회

```swift
db.collection("notifications")
  .whereField("userId", isEqualTo: userId)
  .whereField("isRead", isEqualTo: false)
  .order(by: "createdAt", descending: true)
  .getDocuments()
```

---

## 보안 규칙

### Firestore Security Rules 예시

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ===== 사용자 =====
    match /users/{userId} {
      // 본인만 읽기/쓰기 가능
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // 인증 정보 (본인만 읽기 가능)
      match /auth/{docId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if false; // 인증 정보는 서버에서만 쓰기
      }

      // 설정 정보 (본인만 읽기/쓰기 가능)
      match /settings/{docId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      // groups Map 필드는 users/{userId} 문서의 일부로 관리됨
    }

    // ===== 그룹 =====
    match /groups/{groupId} {
      // 멤버만 읽기 가능 (memberIds 배열에 포함된 경우)
      allow read: if request.auth != null &&
                     resource.data.memberIds.hasAny([request.auth.uid]);

      // 관리자만 수정 가능 (users/{userId}.groups[groupId].role이 admin인 경우)
      allow update: if request.auth != null &&
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.groups[groupId].role == "admin";
    }

    // ===== 약속 =====
    match /promises/{promiseId} {
      // 그룹 멤버만 읽기 가능 (groups/{groupId}.memberIds 배열에 포함된 경우)
      allow read: if request.auth != null &&
                     get(/databases/$(database)/documents/groups/$(resource.data.groupId)).data.memberIds.hasAny([request.auth.uid]);

      // 호스트만 수정/삭제 가능
      allow update, delete: if request.auth != null &&
                               resource.data.hostId == request.auth.uid;

      // votes 필드 업데이트는 그룹 멤버만 가능 (Cloud Functions 통해 처리 권장)
    }

    // ===== 알림 =====
    match /notifications/{notificationId} {
      // 본인 알림만 읽기 가능
      allow read: if request.auth != null &&
                     resource.data.userId == request.auth.uid;

      // 읽음 처리만 가능
      allow update: if request.auth != null &&
                       resource.data.userId == request.auth.uid &&
                       request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isRead', 'readAt']);
    }
  }
}
```

---

## 인덱스 설정

### 필수 복합 인덱스

#### 1. promises 컬렉션

| 인덱스 이름 | 필드 | 순서 | 용도 |
|------------|------|------|------|
| `promises_by_group_startAt` | groupId | ASC | 그룹별 약속 조회 |
|  | startAt | ASC |  |
| `promises_by_group_startAt_desc` | groupId | ASC | 과거 약속 조회 |
|  | startAt | DESC |  |

#### 2. notifications 컬렉션

| 인덱스 이름 | 필드 | 순서 | 용도 |
|------------|------|------|------|
| `notifications_unread` | userId | ASC | 안 읽은 알림 |
|  | isRead | ASC |  |
|  | createdAt | DESC |  |
| `notifications_by_user` | userId | ASC | 사용자별 알림 목록 |
|  | createdAt | DESC |  |

#### 3. 추가 인덱스 (votes 쿼리용)

| 인덱스 이름 | 필드 | 순서 | 용도 |
|------------|------|------|------|
| `promises_by_accepted_user` | votes.accepted | array-contains | 내가 참여 확정한 약속 |
| `promises_by_declined_user` | votes.declined | array-contains | 내가 거절한 약속 |

#### 4. 위젯/홈 쿼리용 인덱스

| 인덱스 이름 | 필드 | 순서 | 용도 |
|------------|------|------|------|
| `promises_confirmed_by_group` | groupId | ASC | 확정된 미래 약속 조회 (위젯/홈) |
|  | isConfirmed | ASC |  |
|  | startAt | ASC |  |

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 1.0 | 2024-12-30 | 초안 작성 (groups 컬렉션 추가) | Claude |
| 1.1 | 2025-01-05 | Functions 기준 User/Group/Promise 스키마 정리 | Codex |
| 1.2 | 2025-01-05 | User 스키마 재설계 | Claude |
|  |  | - name: provider에서 받은 이름 (변경 불가) |  |
|  |  | - nickname: 사용자가 설정한 표시명 |  |
|  |  | - profile.thumbUrl 추가 (Cloud Functions 자동 생성) |  |
|  |  | - auth 서브컬렉션 분리 (보안) |  |
|  |  | - settings 서브컬렉션 분리 (확장성) |  |
|  |  | - pinnedGroupId 제거 |  |
|  |  | - profileType 제거 |  |
| 1.3 | 2025-01-06 | Group 스키마 최적화 | Claude |
|  |  | - users/{userId}/groups 서브컬렉션 → users/{userId}.groups Map으로 변경 (읽기 비용 90% 절감) |  |
|  |  | - GroupDocument: emoji, themeColor, photo, memberCount, requireApproval, defaultMinimumParticipants 제거 |  |
|  |  | - GroupDocument.imageUrl: storagePath → downloadURL로 변경 |  |
|  |  | - groups/{groupId}/members 서브컬렉션 제거 (memberIds 배열로 대체) |  |
| 1.4 | 2025-01-07 | Promise 스키마 재설계 | Claude |
|  |  | - attendances 서브컬렉션 제거 → votes Map으로 대체 (읽기 비용 90% 절감) |  |
|  |  | - counts 필드 제거 → votes 배열에서 계산 |  |
|  |  | - requiredCount → minimumParticipants로 이름 변경 |  |
|  |  | - hostName, groupName 캐시 필드 제거 |  |
|  |  | - tentative 상태 제거 (accepted/declined만 저장, pending은 계산) |  |
|  |  | - votesUntil 필드 추가 (투표 마감 시각) |  |
|  |  | - votes Map: Set-like 동작 (arrayUnion/arrayRemove) 문서화 |  |
|  |  | - location Map 별도 섹션으로 분리 |  |
| 1.5 | 2025-01-24 | Settings 스키마 확장 | Claude |
|  |  | - users/{userId}/settings/main에 groupSortOption 필드 추가 |  |
|  |  | - groupSortOption: 그룹 정렬 방식 (joinedRecent \| joinedOldest \| nameAscending) |  |
| 1.6 | 2025-01-25 | Location 스키마 확장 | Claude |
|  |  | - promises/{promiseId}.location에 address, latitude, longitude 필드 추가 |  |
|  |  | - Kakao Maps SDK 연동으로 좌표 및 주소 저장 지원 |  |
| 1.7 | 2025-02-01 | Widget Snapshot 스키마 추가 | Claude |
|  |  | - users/{userId}/cache/widgetSnapshot 서브컬렉션 추가 |  |
|  |  | - Firestore Trigger 기반 자동 갱신 아키텍처 |  |
|  |  | - myVoteStatus 필드 추가 (pending/voted/declined) |  |
|  |  | - 우선순위 정렬: pending → unconfirmed → time |  |
| 1.8 | 2026-02-01 | Home Snapshot 스키마 추가 | Claude |
|  |  | - users/{userId}/cache/homeSnapshot 서브컬렉션 추가 |  |
|  |  | - todayPromises, pendingPromises, upcomingPromises 분류 |  |
|  |  | - SnapshotPromise에 minimumParticipants, groupImageUrl, votingDeadline 추가 |  |
|  |  | - HomeSnapshotGroup 구조 추가 (그룹별 다음 약속) |  |
|  |  | - Widget/Home 공용 SnapshotPromise 타입 통합 |  |
| 1.9 | 2026-02-03 | 홈/위젯 스냅샷 → 직접 쿼리 전환 | Claude |
|  |  | - promises 컬렉션에 `isConfirmed` 필드 추가 (비정규화) |  |
|  |  | - widgetSnapshot 캐시 Deprecated (직접 쿼리로 변경) |  |
|  |  | - homeSnapshot 캐시 Deprecated (직접 쿼리로 변경) |  |
|  |  | - Firestore Trigger 제거 (onPromiseWriteUpdateSnapshot 등) |  |
|  |  | - 복합 인덱스 추가: groupId + isConfirmed + startAt |  |

---

## 백로그

### v1.6

- `reminders` 기능 도입 시 스키마 확정
- 실시간 위치 공유 (arrivalSharing) 스키마 설계
- `location.placeId` 필드 추가 (Kakao Place ID)
