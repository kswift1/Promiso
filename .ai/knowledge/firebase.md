---
updated: 2025-01-29
expires: 2025-02-28
version: 12.7.0
source: https://firebase.google.com/support/release-notes/ios
---

# Firebase iOS SDK 지식 베이스

> 이 파일은 `knowledge-updater` 에이전트가 자동으로 관리합니다.
> 2025년 1월 검색 결과 기반.

## 현재 버전 정보

- **최신 버전**: 12.7.0 (2025년 1월 기준)
- **확인 일자**: 2025-01-29
- **출처**: [Firebase Release Notes](https://firebase.google.com/support/release-notes/ios)

## Promiso 프로젝트 상태

- **사용 중인 모듈**: Auth, Firestore, Storage, Functions, Messaging, Crashlytics
- **Xcode 요구사항**: 16.2+ (macOS 14.5+)

---

## 2025년 주요 변경사항

### Firebase AI Logic (구 Vertex AI in Firebase)

> 2025년 5월부터 **Firebase AI Logic**으로 명칭 변경

**새로운 기능**:
- Gemini Live API 통합 (자연스러운 음성 대화)
- Gemini Developer API (무료 옵션)
- Code Execution Tool (Python 코드 생성/실행)
- Gemini 3 시리즈 thinking levels 설정 지원
- Imagen 3 이미지 생성 (Public Preview)

**플랫폼 지원**:
- Web, Flutter, Unity, Android: 지원
- iOS: 곧 지원 예정 (Gemini Live API)

```swift
// Firebase AI Logic 기본 사용 (iOS)
import FirebaseAI

let model = FirebaseAI.generativeModel(modelName: "gemini-2.5-flash")
let response = try await model.generateContent("Hello, Gemini!")
```

### 보안 업데이트

- **CVE-2025-0838** 내부 워크어라운드 구현
- `__SwiftValue` 관련 iOS 앱 제출 차단 이슈 수정
- Auth/App Check 토큰 가져오기 시 크래시 수정

### SDK 12.x 주요 변경

**12.7.0**:
- Codable 구현 수정 (plist defaults의 array/dictionary 처리)
- 이미지 생성 디코딩 에러 수정 (`gemini-2.5-flash-image-preview` 모델)

**12.1.0**:
- Swift concurrency 전면 지원
- async/await API 안정화

### Deprecated 서비스

> ⚠️ **Firebase Dynamic Links 종료**: 2025년 8월 25일
> 새 프로젝트에서 사용 금지. 대안: App Links, Universal Links, Branch.io

---

## Firestore Swift Codable

### 기본 사용법

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var createdAt: Timestamp

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case createdAt = "created_at"
    }
}

// 읽기
let user = try await db.collection("users")
    .document(uid)
    .getDocument(as: User.self)

// 쓰기
try db.collection("users")
    .document(uid)
    .setData(from: user)

// 쿼리
let users = try await db.collection("users")
    .whereField("email", isEqualTo: email)
    .getDocuments()
    .documents
    .compactMap { try? $0.data(as: User.self) }
```

### FirebaseFirestoreSwift 모듈

> ⚠️ 일부 사용자가 최신 SDK에서 모듈 누락 보고
> 해결: SPM에서 `FirebaseFirestoreSwift` 명시적 추가

```swift
// Package.swift
.package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.0.0")

// dependencies
.product(name: "FirebaseFirestoreSwift", package: "firebase-ios-sdk")
```

### FieldValue 지원

```swift
// FieldValue는 Encodable만 지원 (setData, updateData용)
import FirebaseFirestore

struct UpdateData: Encodable {
    var lastLogin: FieldValue = FieldValue.serverTimestamp()
    var loginCount: FieldValue = FieldValue.increment(Int64(1))
}

try await db.collection("users")
    .document(uid)
    .updateData(from: UpdateData())
```

---

## Auth async/await

### 로그인

```swift
import FirebaseAuth

// 이메일/비밀번호
let result = try await Auth.auth().signIn(
    withEmail: email,
    password: password
)
let user = result.user

// Apple Sign In
let result = try await Auth.auth().signIn(with: appleCredential)

// Google Sign In
let result = try await Auth.auth().signIn(with: googleCredential)

// 익명 로그인
let result = try await Auth.auth().signInAnonymously()
```

### 회원가입

```swift
let result = try await Auth.auth().createUser(
    withEmail: email,
    password: password
)
let user = result.user

// 프로필 업데이트
let changeRequest = user.createProfileChangeRequest()
changeRequest.displayName = name
try await changeRequest.commitChanges()
```

### 세션 관리

```swift
// 현재 사용자
guard let user = Auth.auth().currentUser else {
    throw AuthError.notLoggedIn
}

// 토큰 가져오기
let token = try await user.getIDToken()

// 강제 토큰 갱신
let token = try await user.getIDToken(forcingRefresh: true)

// 로그아웃
try Auth.auth().signOut()

// 계정 삭제
try await user.delete()
```

### Auth State 리스너

```swift
// Combine 사용
import Combine

let authStatePublisher = Auth.auth().authStateDidChangePublisher()

authStatePublisher
    .sink { user in
        if let user = user {
            print("Logged in: \(user.uid)")
        } else {
            print("Logged out")
        }
    }
    .store(in: &cancellables)

// AsyncSequence (Swift Concurrency)
for await user in Auth.auth().authStateDidChange() {
    // user: User?
}
```

---

## Cloud Functions 호출

```swift
import FirebaseFunctions

let functions = Functions.functions()

// 기본 호출
let result = try await functions.httpsCallable("functionName").call([
    "param1": value1,
    "param2": value2
])

// 결과 파싱
if let data = result.data as? [String: Any] {
    // ...
}

// Codable 사용
struct FunctionRequest: Encodable {
    let userId: String
    let action: String
}

struct FunctionResponse: Decodable {
    let success: Bool
    let message: String
}

let request = FunctionRequest(userId: uid, action: "activate")
let response: FunctionResponse = try await functions.httpsCallable("processUser")
    .call(request, as: FunctionResponse.self)
```

### 에뮬레이터 연결

```swift
#if DEBUG
functions.useEmulator(withHost: "localhost", port: 5001)
#endif
```

---

## Cloud Storage

### 업로드

```swift
import FirebaseStorage

let storage = Storage.storage()
let ref = storage.reference().child("images/\(UUID().uuidString).jpg")

// Data 업로드
let metadata = StorageMetadata()
metadata.contentType = "image/jpeg"

let result = try await ref.putDataAsync(imageData, metadata: metadata)
let downloadURL = try await ref.downloadURL()

// 파일 업로드
let localURL = URL(fileURLWithPath: "/path/to/file")
let result = try await ref.putFileAsync(from: localURL)
```

### 다운로드

```swift
// URL 가져오기
let downloadURL = try await ref.downloadURL()

// 메모리로 다운로드 (최대 크기 제한)
let data = try await ref.data(maxSize: 10 * 1024 * 1024) // 10MB

// 파일로 다운로드
let localURL = FileManager.default.temporaryDirectory.appendingPathComponent("download.jpg")
try await ref.write(toFile: localURL)
```

### 삭제

```swift
try await ref.delete()
```

---

## Cloud Messaging (FCM)

### 토큰 관리

```swift
import FirebaseMessaging

// FCM 토큰 가져오기
let token = try await Messaging.messaging().token()

// 토큰 갱신 리스너
Messaging.messaging().delegate = self

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        // 서버에 토큰 업데이트
    }
}
```

### 토픽 구독

```swift
// 구독
try await Messaging.messaging().subscribe(toTopic: "news")

// 구독 해제
try await Messaging.messaging().unsubscribe(fromTopic: "news")
```

---

## Crashlytics

### 기본 설정

```swift
import FirebaseCrashlytics

// 사용자 ID 설정 (선택)
Crashlytics.crashlytics().setUserID(uid)

// 커스텀 키
Crashlytics.crashlytics().setCustomValue(value, forKey: "key")

// 로그 메시지
Crashlytics.crashlytics().log("User tapped button")
```

### Non-Fatal 에러 기록

```swift
let error = NSError(
    domain: "com.promiso.error",
    code: 1001,
    userInfo: [NSLocalizedDescriptionKey: "Something went wrong"]
)
Crashlytics.crashlytics().record(error: error)
```

### 크래시 수집 제어

```swift
// 사용자 동의 후 활성화
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
```

---

## 비용 최적화 팁

### Firestore

```swift
// ✅ 필요한 필드만 가져오기 (select)
// Firebase iOS SDK는 아직 select() 미지원
// 대안: 별도 컬렉션으로 요약 데이터 분리

// ✅ 실시간 리스너 범위 최소화
db.collection("groups")
    .whereField("memberIds", arrayContains: uid)
    .limit(to: 20)  // 항상 limit 사용
    .addSnapshotListener { ... }

// ✅ 캐시 우선 (오프라인 지원)
db.collection("users").document(uid)
    .getDocument(source: .cache)  // 캐시 우선

// ✅ 배치 쓰기
let batch = db.batch()
for item in items {
    let ref = db.collection("items").document()
    try batch.setData(from: item, forDocument: ref)
}
try await batch.commit()  // 1회 쓰기로 처리
```

### Storage

```swift
// ✅ 썸네일 사용
// 원본 대신 리사이즈된 썸네일 URL 사용

// ✅ 캐시 컨트롤
let metadata = StorageMetadata()
metadata.cacheControl = "public, max-age=31536000"  // 1년 캐시

// ✅ 이미지 압축
let compressedData = image.jpegData(compressionQuality: 0.7)
```

### Functions

```swift
// ✅ Cold Start 최소화
// 자주 사용하는 함수는 min instances 설정 (Functions 측)

// ✅ 배치 처리
// 여러 작업을 하나의 함수 호출로 묶기
```

---

## Security Rules 참고

### Firestore Rules

```javascript
// infra/firebase/firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // 사용자 문서
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }

    // 그룹 문서
    match /groups/{groupId} {
      allow read: if request.auth.uid in resource.data.memberIds;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.ownerId;
    }

    // 약속 문서
    match /promises/{promiseId} {
      allow read: if request.auth.uid in resource.data.participantIds;
      allow create: if request.auth != null;
      allow update: if request.auth.uid in resource.data.participantIds;
      allow delete: if request.auth.uid == resource.data.creatorId;
    }
  }
}
```

### Storage Rules

```javascript
// infra/firebase/storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // 프로필 이미지
    match /users/{userId}/profile/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024  // 5MB
                   && request.resource.contentType.matches('image/.*');
    }

    // 그룹 이미지
    match /groups/{groupId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 10 * 1024 * 1024;  // 10MB
    }
  }
}
```

---

## visionOS 지원

```swift
// Firestore는 visionOS에서 SPM source distribution 필요
// 환경 변수 설정 후 프로젝트 열기:
// FIREBASE_SOURCE_FIRESTORE=1 xed .
```

---

## 자주 묻는 질문

### Q: FirebaseFirestoreSwift 모듈을 찾을 수 없어요
A: SPM에서 명시적으로 `FirebaseFirestoreSwift` product 추가 필요.

### Q: async/await API가 없어요
A: Firebase SDK 10.0+ 필요. Package.swift에서 버전 확인.

### Q: 에뮬레이터 연결이 안 돼요
A:
```swift
// DEBUG 플래그 확인
#if DEBUG
let settings = Firestore.firestore().settings
settings.host = "localhost:8080"
settings.cacheSettings = MemoryCacheSettings()
settings.isSSLEnabled = false
Firestore.firestore().settings = settings
#endif
```

### Q: Dynamic Links 대안은?
A: Firebase Dynamic Links가 2025년 8월 종료.
- iOS: Universal Links
- Android: App Links
- 서드파티: Branch.io, Adjust

### Q: Xcode 버전 요구사항은?
A: Firebase iOS SDK 12.x는 Xcode 16.2+ 필요 (macOS 14.5+).

---

## 참고 자료

### 공식 자료
- [Firebase iOS SDK GitHub](https://github.com/firebase/firebase-ios-sdk)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Firebase Release Notes](https://firebase.google.com/support/release-notes/ios)
- [Firebase AI Logic Updates (2025년 9월)](https://firebase.blog/posts/2025/09/firebase-ai-logic-updates/)
- [Cloud Next 2025 Announcements](https://firebase.blog/posts/2025/04/cloud-next-announcements)

### Promiso 프로젝트 참조
- `Projects/Clients/FirestoreClient/`
- `Projects/Clients/AuthClient/`
- `Projects/Clients/StorageClient/`
- `infra/firebase/firestore.rules`
- `infra/firebase/storage.rules`

---

*마지막 업데이트: 2025-01-29 (웹 검색 기반)*
