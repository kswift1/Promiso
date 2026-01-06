# Firestore 데이터베이스 스키마

## 📋 목차

1. [개요](#개요)
2. [전체 구조](#전체-구조)
3. [컬렉션 상세](#컬렉션-상세)
   - [1. users](#1-users-컬렉션)
     - [1-1. auth](#1-1-usersuseridauthmain-서브컬렉션)
     - [1-2. settings](#1-2-usersuseridsettingsmain-서브컬렉션)
     - [1-3. groups](#1-3-usersuseridgroups-서브컬렉션)
   - [2. groups](#2-groups-컬렉션)
   - [3. promises](#3-promises-컬렉션)
   - [4. notifications](#4-notifications-컬렉션)
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
│     ├─ auth/                      # 인증 정보 (서브컬렉션)
│     │  └─ main                    # 고정 문서 ID
│     ├─ settings/                  # 설정 정보 (서브컬렉션)
│     │  └─ main                    # 고정 문서 ID
│     └─ groups/                    # 사용자가 속한 그룹 목록 (서브컬렉션)
│        └─ {groupId}/              # 그룹 참여 정보
│
├─ groups/                          # 그룹 정보
│  └─ {groupId}/                    # 그룹 문서
│     └─ members/                   # 그룹 멤버 목록 (서브컬렉션)
│        └─ {userId}/               # 멤버 정보
│
├─ promises/                        # 약속 정보
│  └─ {promiseId}/                  # 약속 문서
│     └─ attendances/               # 참석자 정보 (서브컬렉션)
│        └─ {userId}/               # 참석자별 응답 상태
│
└─ notifications/                   # 알림 정보
   └─ {notificationId}/             # 알림 문서
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

#### 📝 예시 데이터

```json
{
  "notificationEnabled": true
}
```

#### 💡 설계 의도

- **확장성**: 나중에 theme, language, privacy 등 추가 설정 확장 가능
- **독립성**: 설정 변경 시 메인 문서 updatedAt 영향 없음

---

### 1-3. users/{userId}/groups (서브컬렉션)

사용자가 속한 그룹 목록을 저장합니다. (캐싱 목적)

#### 📍 문서 경로

```
users/{userId}/groups/{groupId}
```

#### 🔑 문서 ID

- 그룹 ID와 동일 (예: `group_friends`)

#### 📊 필드 구조

| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| `groupId` | String | ✅ | 그룹 ID (groups 컬렉션 참조) |
| `groupName` | String | ✅ | 그룹 이름 (캐시) |
| `role` | String | ✅ | 역할 (`admin` \| `member`) |
| `joinedAt` | Timestamp | ✅ | 그룹 가입 시각 |
| `notifications` | Boolean | ✅ | 그룹 알림 수신 여부 |

#### 📝 예시 데이터

```json
{
  "groupId": "group_friends",
  "groupName": "대학 친구들",
  "role": "admin",
  "joinedAt": "2024-01-01T10:00:00+09:00",
  "notifications": true
}
```

#### 💡 설계 의도

- **빠른 조회**: 사용자의 그룹 목록을 빠르게 가져오기 위함
- **캐싱**: groupName을 캐싱하여 groups 컬렉션 조회 횟수 감소
- **권한 관리**: 사용자별 읽기 권한 설정 용이

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
| `emoji` | String | ❌ | null | 그룹 대표 이모지 |
| `themeColor` | String | ❌ | null | 그룹 테마 색상 (HEX) |
| `photoPath` | String | ❌ | null | 그룹 이미지 Storage 경로 |
| `memberIds` | Array<String> | ✅ | [] | 멤버 ID 목록 |
| `memberCount` | Number | ✅ | 1 | 현재 멤버 수 |
| `activePromiseCount` | Number | ✅ | 0 | 활성 약속 수 |
| `maxMembers` | Number | ✅ | - | 최대 인원 (2~10) |
| `requireApproval` | Boolean | ✅ | false | 가입 승인 필요 여부 |
| `defaultMinimumParticipants` | Number | ✅ | 2 | 기본 최소 참가자 수 |
| `inviteCode` | String | ✅ | - | 초대 코드 (6자리 영숫자, 유니크) |
| `createdBy` | String | ✅ | - | 생성자 ID |
| `createdAt` | Timestamp | ✅ | - | 생성 시각 |
| `updatedAt` | Timestamp | ✅ | - | 마지막 수정 시각 |
| `isDeleted` | Boolean | ✅ | false | 삭제 여부 (소프트 삭제) |

#### 📝 예시 데이터

```json
{
  "name": "주말 등산 모임",
  "description": "주말마다 등산하는 모임입니다",
  "emoji": "🏔️",
  "themeColor": "#4CAF50",
  "photo": {
    "type": "storagePath",
    "url": "groups/abc123/photo.jpg"
  },
  "memberIds": [
    "sFeDJwqJbqScbSUp4Jz54MDlnFv1",
    "user2Id",
    "user3Id",
    "user4Id",
    "user5Id"
  ],
  "memberCount": 5,
  "activePromiseCount": 2,
  "maxMembers": 10,
  "requireApproval": false,
  "defaultMinimumParticipants": 3,
  "inviteCode": "AB12CD",
  "createdBy": "sFeDJwqJbqScbSUp4Jz54MDlnFv1",
  "createdAt": "<Timestamp>",
  "updatedAt": "<Timestamp>",
  "isDeleted": false
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
  memberCount: 1,
  // ...
});

// joinGroup
await groupRef.update({
  memberIds: FieldValue.arrayUnion(userId),
  memberCount: FieldValue.increment(1)
});
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
- 예시: `promise_movie_abc123`, `promise_coffee_def456`

#### 📊 필드 구조

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| `emoji` | String | ✅ | - | 약속 대표 이모지 |
| `title` | String | ✅ | - | 약속 제목 |
| `description` | String | ❌ | null | 약속 설명 |
| `minimumParticipants` | Number | ✅ | 2 | 최소 참가자 수 |
| `requiredCount` | Number | ✅ | - | 확정 필요 인원 (= minimumParticipants) |
| `isConfirmed` | Boolean | ✅ | false | 약속 확정 여부 |
| `confirmedAt` | Timestamp | ❌ | null | 확정 시각 |
| `hostId` | String | ✅ | - | 호스트(생성자) ID |
| `hostName` | String | ✅ | - | 호스트 이름 (캐시) |
| `groupId` | String | ✅ | - | 그룹 ID |
| `groupName` | String | ✅ | - | 그룹 이름 (캐시) |
| `counts` | Map | ✅ | - | 참석 상태별 카운트 |
| `counts.total` | Number | ✅ | 0 | 전체 초대 인원 |
| `counts.accepted` | Number | ✅ | 0 | 수락 인원 |
| `counts.declined` | Number | ✅ | 0 | 거절 인원 |
| `counts.pending` | Number | ✅ | 0 | 대기 인원 |
| `counts.tentative` | Number | ✅ | 0 | 미정 인원 |
| `startAt` | Timestamp | ✅ | - | 시작 시각 |
| `endAt` | Timestamp | ✅ | - | 종료 시각 |
| `localYyyymm` | String | ✅ | - | 로컬 년월 (YYYYMM) |
| `localYyyymmdd` | String | ✅ | - | 로컬 년월일 (YYYYMMDD) |
| `localTz` | String | ✅ | "Asia/Seoul" | 타임존 |
| `status` | String | ✅ | "pending" | 약속 상태 (`pending` \| `active` \| `completed` \| `cancelled`) |
| `location` | Map | ❌ | null | 장소 정보 |
| `location.name` | String | ✅ | - | 장소명 |
| `arrivalSharingTime` | Number | ❌ | null | 도착 공유 시작 (분 단위) |
| `titleLower` | String | ✅ | - | 제목 소문자 (검색용) |
| `createdAt` | Timestamp | ✅ | - | 생성 시각 |
| `updatedAt` | Timestamp | ✅ | - | 수정 시각 |
| `isDeleted` | Boolean | ✅ | false | 삭제 여부 (소프트 삭제) |

#### 📝 설계 메모

- `hostName`, `groupName`은 표시용 캐시
- `status` 상태 전이 규칙 정의 필요 (pending -> active -> completed/cancelled)
- `localYyyymm`, `localYyyymmdd`는 월/일 조회용 인덱스

#### 📝 예시 데이터

```json
{
  "emoji": "🍿",
  "title": "영화 관람",
  "description": "마블 신작 보러 가기",
  "minimumParticipants": 2,
  "requiredCount": 2,
  "isConfirmed": true,
  "confirmedAt": "2024-01-14T18:00:00+09:00",
  "hostId": "user_kim123",
  "hostName": "김민수",
  "groupId": "group_friends",
  "groupName": "대학 친구들",
  "counts": {
    "total": 4,
    "accepted": 3,
    "declined": 1,
    "pending": 0,
    "tentative": 0
  },
  "startAt": "2024-01-15T19:00:00+09:00",
  "endAt": "2024-01-15T21:30:00+09:00",
  "localYyyymm": "202401",
  "localYyyymmdd": "20240115",
  "localTz": "Asia/Seoul",
  "status": "active",
  "location": {
    "name": "CGV 강남"
  },
  "arrivalSharingTime": 30,
  "titleLower": "영화 관람",
  "createdAt": "2024-01-14T10:00:00+09:00",
  "updatedAt": "2024-01-14T18:00:00+09:00",
  "isDeleted": false
}
```

---

### 3-1. promises/{promiseId}/attendances (서브컬렉션)

약속 참석자별 응답 상태를 저장합니다.

#### 📍 문서 경로

```
promises/{promiseId}/attendances/{userId}
```

#### 🔑 문서 ID

- 사용자 ID와 동일 (예: `user_kim123`)

#### 📊 필드 구조

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| `userId` | String | ✅ | - | 사용자 ID |
| `userName` | String | ✅ | - | 사용자 이름 (캐시) |
| `profileImageUrl` | String | ❌ | null | 프로필 이미지 (캐시) |
| `status` | String | ✅ | "pending" | 응답 상태 |
| `isHost` | Boolean | ✅ | false | 호스트 여부 |
| `respondedAt` | Timestamp | ❌ | null | 응답 시각 |
| `message` | String | ❌ | null | 코멘트 |
| `notificationSent` | Boolean | ✅ | false | 알림 전송 여부 |
| `lastViewedAt` | Timestamp | ❌ | null | 마지막 조회 시각 |
| `reminderSentAt` | Timestamp | ❌ | null | 리마인더 전송 시각 |
| `invitedAt` | Timestamp | ✅ | - | 초대 시각 |
| `invitedBy` | String | ✅ | - | 초대한 사용자 ID |

#### 📊 status 값 정의

| 값 | 의미 | 설명 |
|----|------|------|
| `pending` | 대기 | 아직 응답하지 않음 |
| `accepted` | 수락 | 참석 확정 |
| `declined` | 거절 | 참석 불가 |
| `tentative` | 미정 | 아직 확실하지 않음 |

#### 📝 예시 데이터

```json
{
  "userId": "user_kim123",
  "userName": "김민수",
  "profileImageUrl": "https://storage.googleapis.com/.../kim123.jpg",
  "status": "accepted",
  "isHost": true,
  "respondedAt": "2024-01-14T10:00:00+09:00",
  "message": "저는 무조건 가요!",
  "notificationSent": true,
  "lastViewedAt": "2024-01-15T18:30:00+09:00",
  "reminderSentAt": "2024-01-15T18:00:00+09:00",
  "invitedAt": "2024-01-14T10:00:00+09:00",
  "invitedBy": "user_kim123"
}
```

---

### 4. notifications (컬렉션)

사용자별 알림 정보를 저장합니다.

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
| `type` | String | ✅ | - | 알림 타입 |
| `promiseId` | String | ❌ | null | 관련 약속 ID |
| `groupId` | String | ❌ | null | 관련 그룹 ID |
| `title` | String | ✅ | - | 알림 제목 |
| `body` | String | ✅ | - | 알림 내용 |
| `imageUrl` | String | ❌ | null | 이미지 URL |
| `actionUrl` | String | ❌ | null | 딥링크 URL |
| `actionType` | String | ❌ | null | 액션 타입 |
| `isRead` | Boolean | ✅ | false | 읽음 여부 |
| `readAt` | Timestamp | ❌ | null | 읽은 시각 |
| `createdAt` | Timestamp | ✅ | - | 생성 시각 |
| `expiresAt` | Timestamp | ❌ | null | 만료 시각 (30일 후) |

#### 📊 type 값 정의

| 값 | 의미 | 설명 |
|----|------|------|
| `promise_confirmed` | 약속 확정 | 약속이 확정됨 |
| `promise_cancelled` | 약속 취소 | 약속이 취소됨 |
| `promise_invited` | 약속 초대 | 새 약속에 초대됨 |
| `promise_updated` | 약속 수정 | 약속 정보가 수정됨 |
| `reminder` | 리마인더 | 약속 시작 전 알림 |
| `response_changed` | 응답 변경 | 다른 멤버의 응답 변경 |
| `group_invited` | 그룹 초대 | 새 그룹에 초대됨 |
| `member_joined` | 멤버 가입 | 새 멤버가 그룹에 가입 |

#### 📝 예시 데이터

```json
{
  "userId": "user_kim123",
  "type": "promise_confirmed",
  "promiseId": "promise_movie_abc123",
  "groupId": "group_friends",
  "title": "약속이 확정되었습니다",
  "body": "영화 관람 약속이 3명 참석으로 확정되었습니다.",
  "imageUrl": null,
  "actionUrl": "/promises/promise_movie_abc123",
  "actionType": "open_promise",
  "isRead": true,
  "readAt": "2024-01-14T18:05:00+09:00",
  "createdAt": "2024-01-14T18:00:00+09:00",
  "expiresAt": "2024-02-14T18:00:00+09:00"
}
```

---

## 쿼리 패턴

### 1. 사용자 관련 쿼리

#### 내가 속한 그룹 목록 조회

```swift
db.collection("users")
  .document(userId)
  .collection("groups")
  .order(by: "joinedAt", descending: true)
  .getDocuments()
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
db.collection("groups")
  .document(groupId)
  .collection("members")
  .order(by: "joinedAt", descending: false)
  .getDocuments()
```

#### 초대 코드로 그룹 찾기

```swift
db.collection("groups")
  .whereField("inviteCode", isEqualTo: inviteCode)
  .whereField("isDeleted", isEqualTo: false)
  .limit(to: 1)
  .getDocuments()
```

---

### 3. 약속 관련 쿼리

#### 특정 그룹의 약속 목록 (날짜순)

```swift
db.collection("promises")
  .whereField("groupId", isEqualTo: groupId)
  .whereField("isDeleted", isEqualTo: false)
  .order(by: "startAt", descending: false)
  .getDocuments()
```

#### 오늘의 약속 조회

```swift
let today = "20240115" // YYYYMMDD
db.collection("promises")
  .whereField("groupId", isEqualTo: groupId)
  .whereField("localYyyymmdd", isEqualTo: today)
  .whereField("isDeleted", isEqualTo: false)
  .order(by: "startAt", descending: false)
  .getDocuments()
```

#### 특정 월의 약속 조회

```swift
let month = "202401" // YYYYMM
db.collection("promises")
  .whereField("groupId", isEqualTo: groupId)
  .whereField("localYyyymm", isEqualTo: month)
  .whereField("isDeleted", isEqualTo: false)
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

      // 사용자가 속한 그룹 목록
      match /groups/{groupId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // ===== 그룹 =====
    match /groups/{groupId} {
      // 멤버만 읽기 가능
      allow read: if request.auth != null &&
                     exists(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid));

      // 관리자만 수정 가능
      allow update: if request.auth != null &&
                       get(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid)).data.role == "admin";

      // 그룹 멤버 목록
      match /members/{userId} {
        // 그룹 멤버만 읽기 가능
        allow read: if request.auth != null &&
                       exists(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid));

        // 관리자만 멤버 추가/삭제 가능
        allow write: if request.auth != null &&
                        get(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid)).data.role == "admin";
      }
    }

    // ===== 약속 =====
    match /promises/{promiseId} {
      // 그룹 멤버만 읽기 가능
      allow read: if request.auth != null &&
                     exists(/databases/$(database)/documents/groups/$(resource.data.groupId)/members/$(request.auth.uid));

      // 호스트만 수정/삭제 가능
      allow update, delete: if request.auth != null &&
                               resource.data.hostId == request.auth.uid;

      // 참석자 정보
      match /attendances/{userId} {
        // 그룹 멤버만 읽기 가능
        allow read: if request.auth != null &&
                       exists(/databases/$(database)/documents/groups/$(get(/databases/$(database)/documents/promises/$(promiseId)).data.groupId)/members/$(request.auth.uid));

        // 본인 응답만 수정 가능
        allow write: if request.auth != null && request.auth.uid == userId;
      }
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
| `promises_by_group_date` | groupId | ASC | 그룹별 날짜 조회 |
|  | isDeleted | ASC |  |
|  | startAt | ASC |  |
| `promises_by_group_month` | groupId | ASC | 월별 조회 |
|  | localYyyymm | ASC |  |
|  | isDeleted | ASC |  |
|  | startAt | ASC |  |
| `promises_by_group_day` | groupId | ASC | 일별 조회 |
|  | localYyyymmdd | ASC |  |
|  | isDeleted | ASC |  |
|  | startAt | ASC |  |

#### 2. notifications 컬렉션

| 인덱스 이름 | 필드 | 순서 | 용도 |
|------------|------|------|------|
| `notifications_unread` | userId | ASC | 안 읽은 알림 |
|  | isRead | ASC |  |
|  | createdAt | DESC |  |
| `notifications_by_user` | userId | ASC | 사용자별 알림 목록 |
|  | createdAt | DESC |  |

#### 3. Collection Group 인덱스

| 컬렉션 그룹 | 필드 | 순서 | 용도 |
|------------|------|------|------|
| `attendances` | userId | ASC | 사용자의 모든 참석 정보 |
| `members` | userId | ASC | 사용자의 모든 그룹 멤버십 |

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

---

## 백로그

### v1.1

- 표시용 이름 조회 방식(캐시/조인/배치 업데이트) 결정
- `status` 상태 정의 및 전이 규칙 문서화
- `location`, `reminders` 필드 도입 시점 및 스키마 확정
