# Firestore Database 구조 구현

## 📋 개요

약속 관리 iOS 앱을 위한 확장 가능하고 효율적인 Firestore 데이터베이스 구조를 구현했습니다.

## 🏗️ 컬렉션 구조

```
firestore/
├── users/{userId}
│   └── groups/{groupId} (서브컬렉션)
├── groups/{groupId}
│   └── members/{userId} (서브컬렉션)
├── promises/{promiseId}
│   └── attendances/{userId} (서브컬렉션)
└── notifications/{notificationId}
```

## 📊 데이터 모델

### 1. UserDocument
- **기본 정보**: name, email, profileImageUrl
- **설정**: notificationSettings (enabled, defaultReminderMinutes)
- **타임스탬프**: createdAt, updatedAt

### 2. GroupDocument
- **기본 정보**: name, description, emoji, themeColor
- **카운터(캐시)**: memberCount, activePromiseCount
- **설정**: maxMembers, requireApproval, defaultMinimumParticipants
- **메타데이터**: createdBy, createdAt, updatedAt, isDeleted

### 3. PromiseDocument
- **기본 정보**: emoji, title, description
- **확정 조건**: minimumParticipants, requiredCount, isConfirmed, confirmedAt
- **관계**: hostId, hostName(캐시), groupId, groupName(캐시)
- **counts 객체**: total, accepted, declined, tentative
- **시간**: startAt, endAt
- **달력 인덱스**: localYyyymm(202401), localYyyymmdd(20240115), localTz
- **상태**: status (draft/active/cancelled/completed)
- **위치**: location (name, address, latitude, longitude, placeId)
- **검색 최적화**: titleLower (소문자 변환된 제목)

### 4. AttendanceDocument
- **사용자 정보**: userId, userName(캐시), profileImageUrl(캐시)
- **상태**: status (pending/accepted/declined/tentative)
- **응답**: respondedAt, message, isHost
- **알림**: notificationSent, lastViewedAt, reminderSentAt
- **메타데이터**: invitedAt, invitedBy

### 5. NotificationDocument
- **기본 정보**: userId, type, title, body
- **관련 데이터**: promiseId, groupId, relatedUserId
- **상태**: isRead, isDelivered
- **타임스탬프**: createdAt, readAt, deliveredAt
- **추가 데이터**: data

## 🔧 핵심 기능

### Repository 클래스
- **PromiseRepository**: 약속 CRUD 및 쿼리 작업
- **AttendanceRepository**: 참석 상태 관리
- **SearchRepository**: 검색 기능 구현

### Manager 클래스
- **CacheManager**: 캐시 일관성 검증 및 관리
- **BatchOperationManager**: 대량 작업 처리
- **CalendarKeyGenerator**: 날짜 키 생성 유틸리티

### Security
- **infra/firebase/firestore.rules**: 서버 보안 규칙

## 🚀 주요 특징

### 1. 성능 최적화
- **달력 인덱스**: localYyyymmdd 필드로 날짜별 빠른 조회
- **캐시 필드**: 자주 사용되는 데이터 캐싱
- **복합 인덱스**: 효율적인 쿼리를 위한 인덱스 설계

### 2. 확장성
- **모듈화된 구조**: 각 기능별로 분리된 Repository
- **타입 안전성**: Swift의 강타입 시스템 활용
- **에러 처리**: 포괄적인 에러 처리 및 재시도 로직

### 3. 보안
- **세밀한 권한 제어**: 사용자별, 그룹별 접근 권한
- **데이터 검증**: 클라이언트 및 서버 측 데이터 유효성 검사
- **트랜잭션**: 데이터 일관성 보장

## 📝 사용 예시

### 약속 생성
```swift
let promise = PromiseDocument(
  title: "맛집 탐방",
  minimumParticipants: 2,
  requiredCount: 2,
  hostId: currentUserId,
  hostName: "홍길동",
  groupId: groupId,
  groupName: "친구들",
  startAt: Timestamp(date: startDate),
  localYyyymm: "202401",
  localYyyymmdd: "20240115"
)

let promiseId = try await promiseRepository.createPromise(promise, attendances: attendances)
```

### 오늘의 약속 조회
```swift
let todayPromises = try await promiseRepository.getTodayPromises(groupId: groupId)
```

### 참석 상태 업데이트
```swift
try await attendanceRepository.updateAttendance(
  promiseId: promiseId,
  userId: userId,
  status: .accepted,
  message: "참석합니다!"
)
```

### 검색
```swift
let searchResults = try await searchRepository.searchPromises(
  query: "맛집",
  groupId: groupId
)
```

## 🧪 테스트

### 통합 테스트
- 오늘 약속 조회 (localYyyymmdd 활용)
- 참석 상태 변경 시 counts 자동 업데이트
- 2명 이상 참석 시 약속 자동 확정
- 대량(100명) 초대 배치 처리

### 보안 테스트
- 인증되지 않은 사용자 접근 차단
- 권한별 데이터 접근 제어
- 데이터 유효성 검증
- 종합 보안 시나리오

## 🔍 인덱스 요구사항

### 필수 복합 인덱스
1. promises: (groupId, startAt)
2. promises: (localYyyymmdd, status, startAt)
3. attendances(collectionGroup): (userId, status)
4. notifications: (userId, isRead, createdAt DESC)

## ⚠️ 주의사항

### Firestore 한계
- select() 메서드 없음 (전체 문서 다운로드)
- in 쿼리는 최대 10개 값
- 텍스트 검색 한계 (titleLower로 prefix 검색만 가능)

### 성능 고려사항
- 홈 화면은 실시간 리스너 사용
- 페이지네이션: limit(to: 20) + start(afterDocument:)
- 배치 작업: 500개씩 분할 처리

### 문서 크기 관리
- reminders 배열 최대 5개 제한
- titleKeywords 배열 최대 10개 제한
- 대량 멤버는 서브컬렉션으로 관리

## 🚀 Cloud Functions 연동

### 자동 업데이트 트리거
- attendance 변경 시 → counts 자동 계산
- counts.accepted >= requiredCount → isConfirmed = true
- user name 변경 시 → 모든 캐시된 userName 업데이트
- 약속 시작 1시간 전 → 알림 발송

이 구조를 기반으로 확장 가능하고 효율적인 Firestore 구현을 제공합니다.
