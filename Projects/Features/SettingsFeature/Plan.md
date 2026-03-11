# ProfileFeature Plan

## Overview
ProfileFeature는 사용자 프로필 관리를 담당하는 Feature입니다. 프로필 조회, 편집, 설정 관리, 로그아웃 등의 기능을 제공합니다.

---

## 1. 현재 구현 상태

### 완료된 기능

| 기능 | 상태 | 설명 |
|------|------|------|
| 프로필 표시 | ✅ 완료 | 아바타, 닉네임, 계정 정보 표시 |
| 프로필 편집 | ✅ 완료 | 닉네임 변경, 프로필 이미지 변경 |
| 닉네임 유효성 검사 | ✅ 완료 | 길이 검사, 중복 검사 (debounce 500ms) |
| 로그아웃 | ✅ 완료 | 확인 알러트, 로딩 상태, delegate 패턴 |
| 햅틱 피드백 | ✅ 완료 | 주요 액션에 햅틱 적용 |

### 미완료 기능 (TODO)

| 기능 | 우선순위 | 설명 |
|------|----------|------|
| 알림 설정 | 중 | 푸시 알림 on/off 설정 화면 |
| 개인정보처리방침 | 중 | 웹뷰/시트로 표시 |
| 이용약관 | 중 | 웹뷰/시트로 표시 |
| 앱 정보 | 낮음 | 버전, 라이선스 정보 표시 |

---

## 2. 파일 구조

```
ProfileFeature/
├── Sources/
│   ├── ExportedImports.swift      # 의존성 re-export
│   ├── ProfileFeature.swift       # Reducer, State, Action
│   ├── ProfileView.swift          # 메인 프로필 화면
│   └── ProfileEditView.swift      # 프로필 편집 시트
├── Tests/
│   └── Sources/ProfileFeatureTests.swift
└── Example/
    └── Sources/ExampleApp.swift
```

---

## 3. 추가 고려 기능

### 3.1 계정 관리

| 기능 | 우선순위 | 설명 |
|------|----------|------|
| 계정 삭제 (회원탈퇴) | 높음 | GDPR/개인정보보호법 준수 필수 |
| 계정 연동 관리 | 낮음 | Apple/Google 연동 상태 관리 |

### 3.2 프로필 확장

| 기능 | 우선순위 | 설명 |
|------|----------|------|
| 프로필 이미지 삭제 | 중 | 기본 이미지로 초기화 |
| 프로필 이미지 크롭 | 낮음 | 업로드 전 이미지 편집 |
| 상태 메시지 | 낮음 | 짧은 자기소개 문구 |

### 3.3 알림 설정 세분화

| 기능 | 우선순위 | 설명 |
|------|----------|------|
| 일정 알림 | 중 | 새 일정 초대, 일정 변경 |
| 그룹 알림 | 중 | 그룹 초대, 멤버 변경 |
| 리마인더 알림 | 중 | 일정 시간 전 알림 |

### 3.4 앱 설정

| 기능 | 우선순위 | 설명 |
|------|----------|------|
| 다크모드 설정 | 낮음 | 시스템/라이트/다크 선택 |
| 언어 설정 | 낮음 | 앱 내 언어 변경 |
| 캐시 삭제 | 낮음 | 로컬 캐시 정리 |

### 3.5 지원 및 피드백

| 기능 | 우선순위 | 설명 |
|------|----------|------|
| 문의하기 | 중 | 이메일/인앱 문의 |
| 버그 신고 | 중 | 스크린샷 포함 신고 |
| 앱 평가하기 | 낮음 | App Store 리뷰 유도 |
| 버전 업데이트 확인 | 낮음 | 최신 버전 체크 |

---

## 4. 데이터 모델

### 현재 사용 중

```swift
// UserPrivateModel
- userId: String
- name: String
- nickname: String
- profile: ProfileImage?
- metadata: Metadata (createdAt, updatedAt)
- email: String
- provider: String
- groups: [UserGroupInfo]

// NicknameValidation
- idle, checking, available, unavailable, invalid(String), error(String)
```

### 확장 필요 시

```swift
// UserSettings (알림 설정 세분화 시)
- scheduleNotification: Bool
- groupNotification: Bool
- reminderNotification: Bool
- reminderMinutesBefore: Int

// AppPreferences (앱 설정 추가 시)
- theme: Theme (system, light, dark)
- language: String
```

---

## 5. 우선순위 제안

### Phase 1 (필수)
1. ✅ 프로필 조회/편집 - 완료
2. ✅ 로그아웃 - 완료
3. 개인정보처리방침/이용약관 - 법적 필수
4. 계정 삭제 (회원탈퇴) - 법적 필수

### Phase 2 (중요)
1. 알림 설정 화면
2. 프로필 이미지 삭제
3. 문의하기

### Phase 3 (개선)
1. 앱 정보 화면
2. 프로필 이미지 크롭
3. 다크모드 설정
4. 앱 평가하기

---

## 6. 기술적 고려사항

### 웹뷰 구현 방식
- **Option A**: SafariViewController - 간편, 외부 브라우저 느낌
- **Option B**: WKWebView - 커스텀 UI 가능, 구현 복잡
- **권장**: SafariViewController (빠른 구현)

### 계정 삭제 구현
- Firebase Auth 계정 삭제 + Firestore 데이터 삭제
- 재인증 필요 (민감한 작업)
- 삭제 확인 절차 강화 (텍스트 입력 등)

### 알림 설정
- UserDefaults vs Firestore 저장
- 권장: Firestore (다기기 동기화)

---

## 변경 이력

| 날짜 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-01-15 | 1.0 | 초기 Plan 작성 |
