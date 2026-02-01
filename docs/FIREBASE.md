# Firebase 가이드

Promiso 프로젝트의 Firebase 백엔드 아키텍처 및 개발 가이드입니다.

## 📋 목차

1. [개요](#1-개요)
2. [Firestore](#2-firestore)
3. [Firebase Functions](#3-firebase-functions)
4. [Firebase Storage](#4-firebase-storage)
5. [Firebase Authentication](#5-firebase-authentication)
6. [로컬 개발 가이드](#6-로컬-개발-가이드)
7. [배포](#7-배포)
8. [모니터링 및 최적화](#8-모니터링-및-최적화)

---

## 1. 개요

### 1.1 사용 중인 Firebase 서비스

Promiso는 다음 Firebase 서비스를 사용합니다:

| 서비스 | 용도 | 비고 |
|--------|------|------|
| **Firestore** | NoSQL 데이터베이스 | 사용자, 그룹, 약속 데이터 저장 |
| **Functions** | 서버리스 백엔드 | API, 트리거, 스케줄 작업 |
| **Storage** | 파일 저장소 | 프로필/그룹 이미지 저장 |
| **Authentication** | 인증 | Google, Apple 소셜 로그인 |
| **Cloud Messaging** | 푸시 알림 | 약속 초대, 리마인더 등 |
| **App Check** | 보안 | 앱 무결성 검증 (예정) |

### 1.2 환경별 프로젝트 구성

Promiso는 3개의 독립된 Firebase 프로젝트로 환경을 분리합니다:

```
.firebaserc
{
  "projects": {
    "dev": "promiso-dev",        # 개발 환경
    "stage": "promiso-stage",    # 스테이징 환경
    "prod": "promiso-prod"       # 프로덕션 환경
  }
}
```

#### 환경별 특징

| 환경 | Firebase 프로젝트 | 용도 | Xcode Scheme |
|------|------------------|------|--------------|
| **dev** | `promiso-dev` | 로컬 개발, Emulator | Promiso-Dev |
| **stage** | `promiso-stage` | QA, 내부 테스트 | Promiso-Stage |
| **prod** | `promiso-prod` | 실제 사용자 배포 | Promiso-Prod |

#### 환경 전환

```bash
# 개발 환경으로 전환
firebase use dev

# 스테이징 환경으로 전환
firebase use stage

# 프로덕션 환경으로 전환
firebase use prod

# 현재 환경 확인
firebase use
```

### 1.3 프로젝트 구조

```
Promiso/
├── infra/firebase/                   # Firebase 설정 및 Functions
│   ├── .firebaserc                   # 환경별 프로젝트 설정
│   ├── firebase.json                 # Firebase 서비스 설정
│   ├── firestore.rules               # Firestore 보안 규칙
│   ├── firestore.indexes.json        # Firestore 인덱스
│   ├── storage.rules                 # Storage 보안 규칙
│   └── functions/                    # Firebase Functions
│       ├── src/
│       │   ├── index.ts              # 함수 진입점
│       │   └── functions/            # 도메인별 함수
│       │       ├── users.ts
│       │       ├── groups.ts
│       │       ├── promises.ts
│       │       ├── notifications.ts
│       │       ├── liveActivity.ts
│       │       ├── widget.ts
│       │       └── ...
│       ├── openapi.yaml              # API 명세
│       ├── package.json
│       └── tsconfig.json
```

---

## 2. Firestore

### 2.1 데이터 스키마

Promiso의 Firestore 데이터베이스는 다음 컬렉션으로 구성됩니다:

```
Firestore Root
│
├─ users/                           # 사용자 정보
│  └─ {userId}/
│     ├─ groups (Map)               # 사용자가 속한 그룹 목록
│     ├─ auth/main                  # 인증 정보 (서브컬렉션)
│     ├─ settings/main              # 설정 정보 (서브컬렉션)
│     └─ cache/                     # 캐시 데이터 (서브컬렉션)
│        ├─ widgetSnapshot          # 위젯용 스냅샷
│        └─ homeSnapshot            # 홈화면용 스냅샷
│
├─ groups/                          # 그룹 정보
│  └─ {groupId}/
│
├─ promises/                        # 약속 정보
│  └─ {promiseId}/
│     ├─ votes (Map)                # 투표 상태
│     └─ location (Map)             # 장소 정보
│
├─ notifications/                   # 알림 정보
│  └─ {notificationId}/
│
└─ liveActivities/                  # LiveActivity 상태
   └─ {promiseId}/
```

상세한 스키마는 [.ai/FIRESTORE_SCHEMA.md](../.ai/FIRESTORE_SCHEMA.md)를 참조하세요.

### 2.2 주요 쿼리 패턴

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

#### 특정 그룹의 약속 목록 조회

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

### 2.3 보안 규칙 (Security Rules)

#### 기본 원칙

```javascript
// infra/firebase/firestore.rules

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users - 본인만 읽기/쓰기 허용
    match /users/{userId} {
      allow read, write: if request.auth != null
                        && request.auth.uid == userId;

      // 서브컬렉션도 동일 규칙 적용
      match /{subcollection}/{docId} {
        allow read, write: if request.auth != null
                          && request.auth.uid == userId;
      }
    }

    // Groups - 인증된 사용자만 읽기/쓰기 허용
    match /groups/{groupId} {
      allow read, write: if request.auth != null;
    }

    // Promises - 인증된 사용자만 읽기/쓰기 허용
    match /promises/{promiseId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

#### 보안 규칙 배포

```bash
cd infra/firebase

# 보안 규칙만 배포
firebase deploy --only firestore:rules

# Storage 규칙도 함께 배포
firebase deploy --only firestore:rules,storage
```

#### 규칙 테스트

```bash
# Emulator에서 보안 규칙 테스트
firebase emulators:start --only firestore

# 테스트 스크립트 실행 (별도 작성 필요)
npm run test:rules
```

### 2.4 인덱스 설정

Firestore는 복합 쿼리를 위해 인덱스가 필요합니다.

#### 필수 인덱스

```json
// infra/firebase/firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "promises",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "groupId", "order": "ASCENDING"},
        {"fieldPath": "startAt", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "userId", "order": "ASCENDING"},
        {"fieldPath": "isRead", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    }
  ]
}
```

#### 인덱스 배포

```bash
cd infra/firebase
firebase deploy --only firestore:indexes
```

#### 자동 인덱스 생성

앱에서 쿼리 실행 시 인덱스가 없으면 Firebase Console에서 자동으로 인덱스 생성 링크를 제공합니다.

### 2.5 비용 최적화 팁

#### Map 필드 활용

```swift
// ❌ 서브컬렉션 방식 (10 reads)
users/{userId}/groups/{groupId}  // 각 그룹마다 1 read

// ✅ Map 필드 방식 (1 read)
users/{userId}.groups[groupId]   // 단일 문서에서 모든 그룹 조회
```

#### 캐시 스냅샷 활용

```swift
// ❌ 매번 N+1 쿼리 (10+ reads)
groups.forEach { group in
  promises(groupId: group.id)  // 각 그룹마다 쿼리
}

// ✅ 스냅샷 활용 (1 read)
users/{userId}/cache/homeSnapshot  // 서버에서 미리 분류된 데이터
```

---

## 3. Firebase Functions

### 3.1 Functions 구조

Firebase Functions는 도메인별로 분리되어 있습니다:

```
functions/src/functions/
├── users.ts              # 사용자 관리 (createUser, updateUser 등)
├── groups.ts             # 그룹 관리 (createGroup, joinGroup 등)
├── promises.ts           # 약속 관리 (createPromise, respondPromise 등)
├── notifications.ts      # 푸시 알림 (트리거 기반)
├── liveActivity.ts       # LiveActivity (iOS 18+)
├── widget.ts             # 위젯 스냅샷 API
├── widgetSnapshotTrigger.ts  # 위젯 스냅샷 자동 갱신 (트리거)
└── emoji.ts              # Gemini AI 이모지 생성
```

### 3.2 주요 함수

#### User Functions

| 함수 | 타입 | 설명 |
|------|------|------|
| `createUser` | Callable | 신규 사용자 생성 |
| `getUser` | Callable | 사용자 정보 조회 |
| `updateUser` | Callable | 사용자 정보 수정 |
| `uploadProfileImage` | Callable | 프로필 이미지 업로드 |
| `checkNicknameAvailable` | Callable | 닉네임 중복 확인 |

#### Group Functions

| 함수 | 타입 | 설명 |
|------|------|------|
| `createGroup` | Callable | 그룹 생성 |
| `previewGroup` | Callable | 그룹 미리보기 (초대 코드) |
| `joinGroup` | Callable | 그룹 참여 |
| `leaveGroup` | Callable | 그룹 탈퇴 |
| `updateGroup` | Callable | 그룹 정보 수정 |
| `deleteGroup` | Callable | 그룹 삭제 |
| `onGroupImageUpdated` | Trigger | 그룹 이미지 변경 시 썸네일 생성 |

#### Promise Functions

| 함수 | 타입 | 설명 |
|------|------|------|
| `createPromise` | Callable | 약속 생성 |
| `respondPromise` | Callable | 약속 응답 (참여/거절) |
| `updatePromise` | Callable | 약속 수정 |
| `deletePromise` | Callable | 약속 삭제 |

#### Notification Functions

| 함수 | 타입 | 설명 |
|------|------|------|
| `sendPushNotification` | Callable | 푸시 알림 전송 |
| `onPromiseCreated` | Trigger | 약속 생성 시 알림 |
| `onPromiseVotesUpdated` | Trigger | 투표 변경 시 알림 |
| `onPromiseInfoUpdated` | Trigger | 약속 정보 변경 시 알림 |
| `onGroupMemberJoined` | Trigger | 멤버 참여 시 알림 |

#### Widget Functions

| 함수 | 타입 | 설명 |
|------|------|------|
| `getWidgetSnapshot` | Callable | 위젯용 스냅샷 조회 |
| `onPromiseWriteUpdateSnapshot` | Trigger | 약속 변경 시 스냅샷 자동 갱신 |
| `scheduledSnapshotRefresh` | Scheduled | 매일 00:00 스냅샷 재분류 |

### 3.3 API 명세 (OpenAPI)

Firebase Functions의 API 명세는 OpenAPI 3.0 형식으로 문서화되어 있습니다.

#### API 문서 보기

```bash
cd infra/firebase/functions

# Swagger UI로 미리보기 (http://localhost:8080)
npm run api:preview

# OpenAPI 스펙 검증
npm run api:validate

# 정적 HTML 문서 생성
npm run api:docs
```

#### VS Code에서 보기

1. `42Crunch.vscode-openapi` 확장 설치
2. `infra/firebase/functions/openapi.yaml` 파일 열기
3. 미리보기 실행

### 3.4 iOS에서 Functions 호출

```swift
import FirebaseFunctions

// TCA에서 의존성 주입
@Dependency(\.firebaseFunctions) var functions

// Callable Functions 호출
let result = try await functions.httpsCallable("createGroup").call([
  "name": "대학 친구들",
  "maxMembers": 10
])

// 응답 처리
let data = result.data as? [String: Any]
let groupId = data?["groupId"] as? String
```

---

## 4. Firebase Storage

### 4.1 Storage 구조

```
Firebase Storage
│
├─ profile_images/
│  └─ {userId}/
│     ├─ main.jpg           # 원본 이미지
│     └─ thumb_200x200.jpg  # 썸네일 (자동 생성)
│
└─ group_images/
   └─ {groupId}/
      ├─ main.jpg
      └─ thumb_200x200.jpg
```

### 4.2 파일 업로드/다운로드

#### 프로필 이미지 업로드

```swift
import FirebaseStorage

let storage = Storage.storage()
let storageRef = storage.reference()

// 1. 이미지 데이터 준비
let imageData = image.jpegData(compressionQuality: 0.8)

// 2. 업로드 경로 생성
let profileRef = storageRef.child("profile_images/\(userId)/main.jpg")

// 3. 업로드
let metadata = StorageMetadata()
metadata.contentType = "image/jpeg"

try await profileRef.putDataAsync(imageData, metadata: metadata)

// 4. Download URL 가져오기
let downloadURL = try await profileRef.downloadURL()

// 5. Firestore 업데이트
try await db.collection("users").document(userId).updateData([
  "profile.url": downloadURL.absoluteString,
  "profile.updatedAt": FieldValue.serverTimestamp()
])

// 6. Cloud Functions가 자동으로 썸네일 생성 (onGroupImageUpdated)
```

#### 이미지 다운로드

```swift
// Download URL로 이미지 로드
let url = URL(string: downloadURL)!
let (data, _) = try await URLSession.shared.data(from: url)
let image = UIImage(data: data)
```

### 4.3 Storage 보안 규칙

```javascript
// infra/firebase/storage.rules

rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // 이미지 유효성 검사 함수
    function isValidImage() {
      return request.resource.size < 5 * 1024 * 1024
             && request.resource.contentType.matches('image/.*');
    }

    // 프로필 이미지 - 본인만 업로드, 모든 인증 사용자 읽기
    match /profile_images/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.auth.uid == userId
                   && isValidImage();
    }

    // 그룹 이미지 - 인증 사용자만 업로드/읽기
    match /group_images/{groupId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && isValidImage();
    }
  }
}
```

### 4.4 썸네일 자동 생성

Cloud Functions가 이미지 업로드 시 자동으로 썸네일을 생성합니다:

```typescript
// functions/src/functions/groups.ts

export const onGroupImageUpdated = onObjectFinalized(
  {region: "asia-northeast3"},
  async (event) => {
    const filePath = event.data.name;

    // 이미 썸네일이면 스킵
    if (filePath.includes("thumb_")) return;

    // Sharp로 썸네일 생성 (200x200)
    const thumbBuffer = await sharp(originalBuffer)
      .resize(200, 200, {fit: "cover"})
      .jpeg({quality: 80})
      .toBuffer();

    // Storage에 업로드
    await bucket.file(thumbPath).save(thumbBuffer);

    // Firestore 업데이트
    await db.collection("groups").doc(groupId).update({
      "imageUrl": thumbDownloadURL
    });
  }
);
```

---

## 5. Firebase Authentication

### 5.1 지원 로그인 방식

Promiso는 다음 소셜 로그인을 지원합니다:

| Provider | 플랫폼 | 상태 |
|----------|--------|------|
| Google | iOS | ✅ 지원 |
| Apple | iOS | ✅ 지원 |
| Kakao | iOS | 🔜 예정 |

### 5.2 인증 흐름

#### Google 로그인

```swift
import GoogleSignIn
import FirebaseAuth

// 1. Google Sign-In
let result = try await GIDSignIn.sharedInstance.signIn(
  withPresenting: rootViewController
)

// 2. Firebase 인증
let credential = GoogleAuthProvider.credential(
  withIDToken: result.user.idToken!.tokenString,
  accessToken: result.user.accessToken.tokenString
)
let authResult = try await Auth.auth().signIn(with: credential)

// 3. 사용자 정보 가져오기
let user = authResult.user
let uid = user.uid
let email = user.email
let displayName = user.displayName

// 4. Firestore에 사용자 생성 (Cloud Functions)
try await functions.httpsCallable("createUser").call([
  "uid": uid,
  "email": email,
  "name": displayName,
  "provider": "google"
])
```

#### Apple 로그인

```swift
import AuthenticationServices
import FirebaseAuth

// 1. Apple Sign-In Request
let request = ASAuthorizationAppleIDProvider().createRequest()
request.requestedScopes = [.fullName, .email]

// 2. 인증 결과 처리
func authorizationController(
  controller: ASAuthorizationController,
  didCompleteWithAuthorization authorization: ASAuthorization
) {
  if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
    let nonce = currentNonce
    let idToken = appleIDCredential.identityToken

    // 3. Firebase 인증
    let credential = OAuthProvider.credential(
      withProviderID: "apple.com",
      idToken: String(data: idToken, encoding: .utf8)!,
      rawNonce: nonce
    )
    let authResult = try await Auth.auth().signIn(with: credential)

    // 4. Firestore에 사용자 생성
    try await functions.httpsCallable("createUser").call([
      "uid": authResult.user.uid,
      "email": appleIDCredential.email ?? "",
      "name": appleIDCredential.fullName?.formatted() ?? "",
      "provider": "apple"
    ])
  }
}
```

### 5.3 인증 상태 관리

```swift
import FirebaseAuth

// TCA에서 인증 상태 리스너
Effect.run { send in
  Auth.auth().addStateDidChangeListener { _, user in
    if let user = user {
      send(.authStateChanged(.signedIn(userId: user.uid)))
    } else {
      send(.authStateChanged(.signedOut))
    }
  }
}
```

### 5.4 사용자 데이터 구조

#### Firestore 저장 구조

```
users/{userId}                     # 공개 정보
├── name: String                   # provider에서 받은 이름
├── nickname: String               # 사용자가 설정한 표시명
├── profile: Profile?              # 프로필 이미지
└── metaData: MetaData             # 생성/수정 시각

users/{userId}/auth/main           # 인증 정보 (비공개)
└── provider:
    ├── type: "google" | "apple"
    ├── uid: String
    └── email: String
```

---

## 6. 로컬 개발 가이드

### 6.1 Firebase Emulator Suite 사용

#### Emulator 설치

```bash
# Firebase CLI 설치 (최초 1회)
npm install -g firebase-tools

# 로그인
firebase login

# Emulator 설치
firebase init emulators
```

#### Emulator 실행

```bash
cd infra/firebase

# 모든 Emulator 실행
firebase emulators:start

# 특정 Emulator만 실행
firebase emulators:start --only firestore,functions

# 데이터 지속 (재시작 시 데이터 유지)
firebase emulators:start --import=./emulator-data --export-on-exit
```

#### Emulator UI

Emulator 실행 시 다음 URL에서 UI를 확인할 수 있습니다:

- Emulator UI: http://localhost:4000
- Firestore Emulator: http://localhost:8080
- Functions Emulator: http://localhost:5001

### 6.2 iOS 앱에서 Emulator 연결

```swift
// AppDelegate.swift 또는 App.swift

#if DEBUG
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import FirebaseAuth

func connectToEmulators() {
  let settings = Firestore.firestore().settings
  settings.host = "localhost:8080"
  settings.isSSLEnabled = false
  Firestore.firestore().settings = settings

  Functions.functions().useEmulator(withHost: "localhost", port: 5001)
  Storage.storage().useEmulator(withHost: "localhost", port: 9199)
  Auth.auth().useEmulator(withHost: "localhost", port: 9099)
}

// 앱 시작 시 호출
if ProcessInfo.processInfo.environment["USE_EMULATOR"] == "true" {
  connectToEmulators()
}
#endif
```

#### Xcode Scheme 설정

1. Xcode > Product > Scheme > Edit Scheme
2. Run > Arguments > Environment Variables
3. `USE_EMULATOR = true` 추가

### 6.3 테스트 데이터

#### 샘플 데이터 추가

```bash
# Emulator 데이터 디렉토리 생성
mkdir -p infra/firebase/emulator-data

# 샘플 데이터 스크립트 작성
# scripts/seed-emulator-data.ts

import * as admin from "firebase-admin";

admin.initializeApp({
  projectId: "promiso-dev"
});

const db = admin.firestore();

// 샘플 사용자 생성
await db.collection("users").doc("user1").set({
  name: "김철수",
  nickname: "철수",
  metaData: {
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }
});

// 샘플 그룹 생성
await db.collection("groups").doc("group1").set({
  name: "대학 친구들",
  memberIds: ["user1"],
  maxMembers: 10,
  inviteCode: "ABC123",
  createdBy: "user1",
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp()
});
```

#### 데이터 import/export

```bash
# 데이터 export (Emulator 실행 중)
firebase emulators:export ./emulator-data

# 데이터 import
firebase emulators:start --import=./emulator-data

# 종료 시 자동 export
firebase emulators:start --export-on-exit=./emulator-data
```

### 6.4 Functions 로컬 개발

#### Functions 빌드 및 실행

```bash
cd infra/firebase/functions

# 의존성 설치
npm install

# TypeScript 빌드
npm run build

# 실시간 빌드 (개발 중)
npm run build:watch

# Emulator에서 Functions 실행
cd .. && firebase emulators:start --only functions
```

#### Functions 디버깅

```bash
# 로그 출력
firebase functions:log

# 특정 함수 로그만 보기
firebase functions:log --only createGroup

# 실시간 로그 스트리밍
firebase functions:log --only createGroup --tail
```

### 6.5 cURL로 Functions 테스트

```bash
# Callable Function 호출
curl -X POST http://localhost:5001/promiso-dev/asia-northeast3/createGroup \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "name": "테스트 그룹",
      "maxMembers": 10
    }
  }'

# HTTP Function 호출
curl http://localhost:5001/promiso-dev/asia-northeast3/getWidgetSnapshot?userId=user1
```

---

## 7. 배포

### 7.1 환경별 배포

#### 개발 환경 배포

```bash
cd infra/firebase

# 환경 전환
firebase use dev

# 전체 배포
firebase deploy

# Functions만 배포
firebase deploy --only functions

# Firestore Rules만 배포
firebase deploy --only firestore:rules
```

#### 스테이징 환경 배포

```bash
firebase use stage
firebase deploy
```

#### 프로덕션 환경 배포

```bash
firebase use prod
firebase deploy
```

### 7.2 특정 함수만 배포

```bash
# 단일 함수 배포
firebase deploy --only functions:createGroup

# 여러 함수 배포
firebase deploy --only functions:createGroup,functions:joinGroup

# 패턴 매칭 배포 (그룹 관련 함수만)
firebase deploy --only functions:*Group
```

### 7.3 배포 전 체크리스트

Functions 배포 전 다음 사항을 확인하세요:

- [ ] TypeScript 빌드 성공 (`npm run build`)
- [ ] Lint 통과 (`npm run lint`)
- [ ] 로컬 테스트 완료 (Emulator)
- [ ] API 문서 업데이트 (`openapi.yaml`)
- [ ] 환경 변수 설정 확인
- [ ] 보안 규칙 테스트

### 7.4 롤백

```bash
# 배포 이력 확인
firebase deploy:history

# 이전 버전으로 롤백
firebase rollback functions:createGroup
```

---

## 8. 모니터링 및 최적화

### 8.1 Firebase Console 모니터링

#### Functions 모니터링

- **Usage**: https://console.firebase.google.com → Functions → Usage
  - 호출 횟수
  - 실행 시간
  - 메모리 사용량
  - 비용 추정

#### Firestore 모니터링

- **Usage**: https://console.firebase.google.com → Firestore → Usage
  - 문서 읽기/쓰기/삭제 횟수
  - 저장 용량
  - 비용 추정

### 8.2 비용 최적화

#### Firestore 최적화

```swift
// ❌ 비효율적 (N+1 쿼리)
for group in groups {
  let promises = try await db.collection("promises")
    .whereField("groupId", isEqualTo: group.id)
    .getDocuments()  // 10 groups = 10 reads
}

// ✅ 효율적 (캐시 스냅샷 활용)
let snapshot = try await db.collection("users")
  .document(userId)
  .collection("cache")
  .document("homeSnapshot")
  .getDocument()  // 1 read
```

#### Functions 최적화

```typescript
// ❌ 비효율적 (각 요청마다 초기화)
export const myFunction = onRequest(async (req, res) => {
  const db = admin.firestore();  // 매번 초기화
  // ...
});

// ✅ 효율적 (전역 초기화)
const db = admin.firestore();  // 한 번만 초기화

export const myFunction = onRequest(async (req, res) => {
  // db 재사용
});
```

#### 비용 제한 설정

```typescript
// functions/src/index.ts

import {setGlobalOptions} from "firebase-functions/v2";

// 최대 인스턴스 제한 (비용 제어)
setGlobalOptions({
  maxInstances: 10,
  region: "asia-northeast3"
});
```

### 8.3 성능 모니터링

#### 로그 확인

```bash
# 최근 50개 로그 확인
firebase functions:log --limit 50

# 실시간 로그 스트리밍
firebase functions:log --only createGroup --tail

# 에러 로그만 필터링
firebase functions:log | grep ERROR
```

#### 커스텀 로그

```typescript
import {logger} from "firebase-functions";

export const createGroup = onCall(async (request) => {
  const startTime = Date.now();

  // 함수 실행
  const groupId = await createGroupInFirestore(data);

  // 성능 로그
  logger.info("Group created", {
    groupId,
    duration: Date.now() - startTime,
    userId: request.auth?.uid
  });

  return {groupId};
});
```

### 8.4 알림 설정

Firebase Console에서 예산 알림을 설정하여 비용 초과를 방지할 수 있습니다:

1. Firebase Console → Settings → Usage and billing
2. Set budget alerts
3. 이메일 알림 설정

---

## 9. 참고 자료

### 공식 문서

- [Firebase 공식 문서](https://firebase.google.com/docs)
- [Firestore 가이드](https://firebase.google.com/docs/firestore)
- [Firebase Functions 가이드](https://firebase.google.com/docs/functions)
- [Firebase Storage 가이드](https://firebase.google.com/docs/storage)

### 프로젝트 문서

- [Firestore 스키마](../.ai/FIRESTORE_SCHEMA.md)
- [프로젝트 아키텍처](../.ai/PROJECT_CONTEXT.md)
- [Functions API 명세](../../infra/firebase/functions/openapi.yaml)
- [배포 가이드](DEPLOYMENT.md)

### 트러블슈팅

#### Emulator 연결 실패

```bash
# 포트 충돌 확인
lsof -i :8080
lsof -i :5001

# 프로세스 종료
kill -9 <PID>

# Emulator 재시작
firebase emulators:start
```

#### Functions 배포 실패

```bash
# 빌드 에러 확인
cd infra/firebase/functions
npm run build

# 권한 확인
firebase login
firebase projects:list

# 환경 확인
firebase use
```

#### Firestore 쿼리 느림

- Firebase Console에서 인덱스 생성 확인
- 쿼리 조건 최적화 (limit, orderBy)
- 캐시 스냅샷 활용

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 1.0 | 2026-02-01 | 초안 작성 | Claude Sonnet 4.5 |
