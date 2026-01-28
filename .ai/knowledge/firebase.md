---
updated:
expires:
version:
source: https://firebase.google.com/support/release-notes/ios
---

# Firebase iOS SDK 지식 베이스

> 이 파일은 `knowledge-updater` 에이전트가 자동으로 관리합니다.

## 현재 버전 정보

- **최신 버전**: (검색 필요)
- **확인 일자**: -
- **출처**: [Firebase Release Notes](https://firebase.google.com/support/release-notes/ios)

## Promiso 프로젝트 상태

- **사용 중인 버전**: (Package.swift 확인 필요)
- **사용 모듈**: Auth, Firestore, Storage, Functions, Messaging, Crashlytics

## SDK 버전별 주요 변경 (AI 지식 기준)

### 10.x (2024)
- Swift concurrency 지원 강화
- async/await API 추가
- Combine 지원

### 11.x (2025)
- async/await 전면 지원
- 기존 completion handler deprecated
- Swift 6 호환성

## 자주 묻는 질문

### Q: Firestore async/await 사용법?
A:
```swift
// 읽기
let document = try await db.collection("users").document(uid).getDocument()

// 쓰기
try await db.collection("users").document(uid).setData(data)

// 쿼리
let snapshot = try await db.collection("groups")
    .whereField("memberIds", arrayContains: uid)
    .getDocuments()
```

### Q: Auth async/await 사용법?
A:
```swift
// 로그인
let result = try await Auth.auth().signIn(withEmail: email, password: password)

// 현재 사용자
guard let user = Auth.auth().currentUser else { return }

// 로그아웃
try Auth.auth().signOut()
```

### Q: Functions 호출 방법?
A:
```swift
let functions = Functions.functions()
let result = try await functions.httpsCallable("functionName").call(["param": value])
```

## Security Rules 참고

- Firestore: `infra/firebase/firestore.rules`
- Storage: `infra/firebase/storage.rules`

## 비용 최적화 팁

- 실시간 리스너 범위 최소화
- 캐시 우선 조회 (`.getDocument()` 기본값)
- 배치 쓰기 활용
- 썸네일 URL 사용

## 참고 자료

- [Firebase iOS SDK GitHub](https://github.com/firebase/firebase-ios-sdk)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Firebase Release Notes](https://firebase.google.com/support/release-notes/ios)

---

*마지막 검색: 아직 검색되지 않음*
