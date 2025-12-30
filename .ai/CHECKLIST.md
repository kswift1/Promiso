# 개발 체크리스트

> 실제 프로젝트 구조와 패턴에 맞춘 실용적인 체크리스트

## 새 Feature 생성 시

### 1. 계획 단계
- [ ] Feature의 목적과 범위 정의
- [ ] 필요한 Client 파악
- [ ] 의존성 그래프 확인 (순환 참조 방지)
- [ ] UI 디자인 확인

### 2. 구조 생성
- [ ] `make feature FEATURE_NAME=YourFeature` 실행
- [ ] Sources/ 폴더 구조 확인
  - [ ] [Feature명]Feature.swift (Reducer)
  - [ ] [Feature명]View.swift (View)
  - [ ] Models/ (필요시)
- [ ] Tests/Sources/ 폴더 확인

### 3. Reducer 작성
- [ ] Namespace 패턴 적용 (`public enum [기능명] {}`)
- [ ] @Reducer 어트리뷰트 추가
- [ ] @ObservableState public struct State: Equatable
- [ ] public enum Action 정의
  - [ ] `case view(ViewAction)`
  - [ ] `case internal(InternalAction)`
  - [ ] `case delegate(DelegateAction)`
  - [ ] `case destination(PresentationAction<Destination.Action>)` (필요시)
- [ ] ViewAction: Sendable 프로토콜
- [ ] InternalAction: Sendable 프로토콜
- [ ] DelegateAction: Equatable 프로토콜
- [ ] @Dependency 선언
- [ ] public var body: some ReducerOf<Self> 구현
  - [ ] Reduce { state, action in } 패턴
  - [ ] 모든 Action case 처리
  - [ ] 에러 핸들링
  - [ ] .cancellable(id:) 적용 (장기 실행 Effect)

### 4. View 작성
- [ ] public struct RootView: View
- [ ] let store: StoreOf<Feature>
- [ ] body 구현
- [ ] @ViewBuilder로 복잡한 View 분리
- [ ] #Preview 추가
  - [ ] 기본 상태
  - [ ] 로딩 상태 (필요시)
  - [ ] 에러 상태 (필요시)

### 5. 테스트 작성 (Swift Testing)
- [ ] @Suite("[Feature명] Tests") 정의
- [ ] @MainActor 적용
- [ ] Happy path 테스트
- [ ] Edge case 테스트
- [ ] Error handling 테스트
- [ ] withDependencies로 Mock 주입
- [ ] confirmation 패턴으로 비동기 검증

### 6. 문서화
- [ ] 복잡한 비즈니스 로직에 주석
- [ ] Public API에 DocC 주석 (필요시)

### 7. 통합
- [ ] 부모 Feature에 통합
- [ ] `make deps`로 의존성 그래프 확인
- [ ] `tuist generate` 성공
- [ ] `tuist build` 성공
- [ ] `tuist test` 통과

---

## Client 생성 시

### 1. 인터페이스 정의
- [ ] @DependencyClient 어트리뷰트
- [ ] public struct [Client명]
- [ ] public 메서드 시그니처
  - [ ] @Sendable 클로저
  - [ ] async throws (필요시)
  - [ ] 명확한 타입 정의

### 2. Live 구현
- [ ] extension [Client]: DependencyKey
- [ ] public static let liveValue 구현
  - [ ] 실제 외부 서비스 호출 (Firebase/URLSession 등)
  - [ ] DomainError로 에러 변환
  - [ ] 적절한 로깅

### 3. Test/Preview 값
- [ ] extension [Client]: TestDependencyKey
- [ ] public static let testValue (XCTFail로 미구현 표시)
- [ ] public static let previewValue (Mock 데이터 즉시 반환)

### 4. DependencyValues 확장
- [ ] extension DependencyValues
- [ ] get/set 구현

### 5. 통합
- [ ] Feature에서 @Dependency(\.client) 주입
- [ ] 테스트에서 Mock 동작 확인

---

## 리팩토링 시

### TCA 패턴 점검
- [ ] Namespace 패턴 사용
- [ ] Action 계층화 (view/internal/delegate)
- [ ] Sendable 프로토콜 적용
- [ ] State에 computed property 활용
- [ ] Delegate 패턴으로 Feature 간 통신
- [ ] Effect cancellation 검토

### 코드 품질
- [ ] 중복 코드 제거
- [ ] 매직 넘버를 상수로
- [ ] 불필요한 주석 제거

### 성능
- [ ] 불필요한 View 재생성 제거
- [ ] List에 id 명시
- [ ] 이미지 로딩 최적화
- [ ] 메모리 누수 확인

### 테스트
- [ ] 리팩토링 후 기존 테스트 통과
- [ ] 새로운 로직에 테스트 추가

---

## PR/Commit 전

### 코드 점검
- [ ] 불필요한 print() 제거
- [ ] 불필요한 주석 제거
- [ ] TODO/FIXME 처리 또는 이슈 생성

### 빌드 & 테스트
- [ ] `tuist clean` 후 재빌드
- [ ] `tuist build` 성공
- [ ] `tuist test` 전체 통과
- [ ] Warning 없음
- [ ] 실제 디바이스/시뮬레이터 테스트

### Git
- [ ] 커밋 메시지 작성 (feat:/fix:/refactor: 등)
- [ ] 불필요한 파일 제외 (.gitignore)
- [ ] Feature 브랜치에서 작업
- [ ] main과 충돌 해결

---

## 배포 전

### 기능 검증
- [ ] 주요 시나리오 테스트
- [ ] 에러 케이스 테스트
- [ ] 네트워크 끊김 상황 테스트
- [ ] 다양한 디바이스 크기 확인 (iPhone SE ~ Pro Max)

### 성능
- [ ] 앱 실행 시간 확인
- [ ] 메모리 사용량 확인
- [ ] 네트워크 요청 최적화

### 문서
- [ ] README 업데이트 (필요시)
- [ ] Breaking changes 문서화

---

## 트러블슈팅 체크리스트

### 빌드 실패
- [ ] `tuist clean` 실행
- [ ] `tuist generate` 재실행
- [ ] Xcode 재시작
- [ ] Derived Data 삭제
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData
  ```

### 테스트 실패
- [ ] 단일 테스트 실행으로 격리
- [ ] withDependencies Mock 설정 확인
- [ ] 비동기 타이밍 확인 (Task.sleep 추가)
- [ ] TestStore vs Store 확인
  - TestStore: exhaustive state 검증
  - Store + confirmation: 간단한 동작 검증

### 런타임 크래시
- [ ] Xcode Console 로그 확인
- [ ] Breakpoint 설정
- [ ] Memory Graph 확인
- [ ] Instruments로 프로파일링

### 의존성 문제
- [ ] `make deps`로 그래프 확인
- [ ] 순환 참조 확인
  - App → Features → Clients → Shared (단방향)
  - Parent Feature → Child Feature (허용)
  - Sibling Feature ↔ Sibling Feature (금지)
- [ ] Interface 타겟 분리 검토

### Tuist 문제
- [ ] `tuist install` 재실행
- [ ] Tuist 캐시 삭제
  ```bash
  rm -rf ~/.tuist
  ```
- [ ] Tuist 버전 확인
  ```bash
  tuist version  # 4.65.7
  ```

---

## 일일 개발 루틴

### 시작
- [ ] `git pull origin main`
- [ ] `tuist generate`
- [ ] 오늘 작업할 Task 확인

### 종료
- [ ] 작업 내용 커밋
- [ ] git push
- [ ] 내일 할 일 메모

---

## 자주 사용하는 명령어

### Tuist
```bash
# 프로젝트 생성
tuist generate

# 의존성 설치 + 프로젝트 생성
tuist install && tuist generate

# 빌드
tuist build

# 테스트
tuist test

# 클린
tuist clean
```

### Make
```bash
# 새 Feature 생성
make feature FEATURE_NAME=Notification

# Feature 삭제
make remove-feature FEATURE_NAME=Notification

# 의존성 그래프
make deps

# 컬러 에셋 생성
make color

# 도움말
make help
```

### Git
```bash
# Feature 브랜치 생성
git checkout -b feature/notification

# 커밋
git add .
git commit -m "feat: Add notification feature"

# Push
git push origin feature/notification
```

---

## 체크리스트 사용 팁

- **프린트**: 인쇄해서 책상에 두고 체크
- **노션**: 복사해서 Task 템플릿으로 사용
- **커스터마이징**: 팀/개인 워크플로우에 맞게 수정
- **공유**: 팀원과 공유해서 일관성 유지

---

**마지막 업데이트**: 2024-12-29
**프로젝트**: Promiso
**iOS**: 18.0+
**Tuist**: 4.65.7
**TCA**: 1.22.2
