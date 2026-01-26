# AI 도구를 위한 프롬프트 모음

이 문서는 Claude Code, GitHub Copilot 등 AI 도구를 사용할 때 일관된 코드를 생성하기 위한 프롬프트 템플릿 모음입니다.

## 📝 사용 방법

### Claude Code 사용 시
```bash
# 방법 1: 직접 참조
"PROMPTS.md의 [섹션명] 템플릿 사용해서 ..."

# 방법 2: 자연어로 구체적으로 요청
"TCA 사용해서 알림 Feature 만들어줘. 요구사항은..."
```

### 프롬프트 작성 원칙
1. **구체적으로**: "버튼 만들어줘" ❌ → "파란색 배경에 흰색 텍스트, 모서리 12pt 둥근 버튼" ✅
2. **컨텍스트 제공**: 프로젝트 아키텍처, 사용 중인 패턴 명시
3. **예시 포함**: 유사한 기존 코드 참조
4. **제약사항 명확히**: 사용해야 할/하지 말아야 할 패턴
5. **원하는 출력 형식**: 파일 구조, 주석 포함 여부 등

---

## 🎨 Feature 개발

### 새 Feature 생성
```
SwiftUI와 TCA를 사용해서 [기능명]Feature를 만들어줘.

컨텍스트:
- 프로젝트: Promiso (약속 관리 앱)
- 아키텍처: TCA 1.22.2 기반
- iOS 18.0+, SwiftUI

요구사항:
- [구체적 요구사항 1]
- [구체적 요구사항 2]
- [구체적 요구사항 3]

의존성:
- [필요한 Client 1]
- [필요한 Client 2]

제약사항:
- Namespace 패턴 사용 (public enum [기능명] {})
- @ObservableState 사용
- Action 계층화 (view/internal/delegate)
- async/await 기반 비동기 처리
- 에러 핸들링 필수
- Swift Testing 프레임워크로 테스트 작성
- SwiftUI Preview 포함

파일 구조:
Projects/Features/[기능명]Feature/
├── Sources/
│   ├── [기능명]Feature.swift (Reducer)
│   ├── [기능명]View.swift (View)
│   └── Models/ (필요시)
├── Tests/
│   └── Sources/
│       └── [기능명]FeatureTests.swift
└── Project.swift

참고: 비슷한 기능은 [기존 Feature명] 참고해서 일관성 유지
```

### UI 컴포넌트 생성
```
[컴포넌트명] SwiftUI 컴포넌트를 만들어줘.

디자인 요구사항:
- 색상: Color.[컬러명] 사용 (ResourceKit 참고)
- 폰트: Font.[폰트명] 사용
- 레이아웃: [구체적 레이아웃 설명]
- 크기: [width/height 또는 adaptive]

기능:
- [기능1]
- [기능2]
- [인터랙션]

재사용성:
- 위치: Shared/DesignSystem/Components
- public 접근 제어자
- 커스터마이징 가능한 파라미터 제공
- 기본값 설정

Preview:
- 기본 상태
- 다크모드
- 다양한 크기/상태

예시:
[기존 컴포넌트 코드 또는 디자인 설명]
```

### Client 생성
```
[Client명]을 TCA Dependency로 만들어줘.

역할: [Client의 역할 1-2문장 설명]

위치: Projects/Clients/Sources/[Client명]/

인터페이스 (public):
- create[Entity]: ([파라미터 타입]) async throws -> String
- fetch[Entity]: (String) async throws -> [Entity]
- update[Entity]: (String, [Entity]) async throws -> Void
- delete[Entity]: (String) async throws -> Void
- observe[Entity]: (String) -> AsyncStream<[Entity]>

구현 (Live):
- 백엔드: [Firebase/URLSession/기타]
- 에러 핸들링: DomainError로 변환
- 로깅: 적절한 로그 추가

테스트 의존성:
- testValue: XCTFail로 미구현 표시
- previewValue: Mock 데이터 즉시 반환

패턴:
@DependencyClient
public struct [Client명] {
  public var method: @Sendable (Params) async throws -> Result
}

extension [Client명]: DependencyKey {
  public static let liveValue = Self(...)
}

extension [Client명]: TestDependencyKey {
  public static let testValue = Self()
  public static let previewValue = Self(...)
}
```

---

## 🔧 리팩토링

### TCA 베스트 프랙티스 적용
```
다음 코드를 TCA 1.22.2 베스트 프랙티스에 맞게 리팩토링해줘:

[코드 붙여넣기]

개선 포인트:
1. Namespace 패턴 적용
   - public enum [기능명] {}
   - extension으로 Feature, View 분리

2. Action 계층화
   - view(ViewAction): 사용자 인터랙션
   - internal(InternalAction): 비동기 응답, 내부 상태 변경
   - delegate(DelegateAction): 부모 Feature 통신
   - 모든 하위 Action enum에 Sendable 프로토콜

3. State 최적화
   - @ObservableState 사용
   - Equatable 준수 (TestStore 사용 시)
   - 계산 가능한 값은 computed property로

4. Effect 개선
   - .run { send in } 패턴 사용
   - 에러 핸들링 추가
   - 취소 가능하도록 .cancellable(id:) 추가

5. Dependency 주입
   - @Dependency(\.clientName) var clientName
   - 하드코딩된 의존성 제거

6. 테스트 가능성
   - 결정적(deterministic) 동작
   - 의존성 주입으로 mock 가능
```

### Feature 분리
```
[Feature명]이 너무 커져서 분리하려고 해.

현재 구조:
- 파일 수: [개수]
- 주요 화면: [화면 목록]
- 문제점: [너무 크다/책임이 많다/등]

분리 전략:
1. 메인 Feature: [MainFeature명]
   - 역할: [Coordinator/네비게이션 관리]

2. 하위 Feature들:
   - [SubFeature1명]: [역할]
   - [SubFeature2명]: [역할]
   - [SubFeature3명]: [역할]

Feature 간 통신:
- Delegate 패턴 사용
- 공통 데이터: [SharedModel] 사용
- 네비게이션: @Presents, PresentationAction

타겟 구조:
- Interface 타겟 필요 여부: [Yes/No]
- 이유: [다른 Feature가 참조할 경우 Yes]

생성할 파일 목록과 각 파일의 역할, 의존성 관계를 정리해줘.
```

---

## 🐛 디버깅

### 버그 수정
```
다음 버그를 수정해줘:

증상:
[구체적인 버그 설명]

재현 방법:
1. [단계1]
2. [단계2]
3. [단계3]
4. 결과: [실제 발생하는 현상]

예상 동작:
[원하는 정상 동작]

환경:
- iOS 버전: [버전]
- 디바이스: [Simulator/실제 기기]
- 빌드 설정: [Debug/Release]

관련 코드:
[버그가 발생하는 코드 또는 Feature 이름]

의심 가는 부분:
[어디가 문제인지 추측]

에러 로그 (있는 경우):
[에러 메시지 또는 스택 트레이스]
```

### 성능 최적화
```
[Feature/View명]의 성능을 최적화해줘.

현재 문제:
- [렌더링이 느림/메모리 사용량 높음/등]
- 발생 시점: [앱 시작/스크롤/특정 액션]

측정 결과:
- [FPS: 30fps → 60fps로 개선 필요]
- [메모리: 500MB → 줄여야 함]
- [로딩 시간: 3초 → 1초 이하로]

코드:
[관련 코드 붙여넣기]

최적화 방향:
1. 불필요한 렌더링 제거
   - @ObservableState 속성 분석
   - View 분리

2. 비동기 처리 개선
   - debounce/throttle 적용
   - 취소 로직 추가

3. 메모리 사용량 감소
   - 큰 데이터 lazy loading
   - 이미지 캐싱

4. [기타 구체적 개선 사항]
```

---

## 🧪 테스트

### 테스트 케이스 작성 (Swift Testing)
```
[Feature명]의 테스트 케이스를 Swift Testing 프레임워크로 작성해줘.

Feature 코드:
[Reducer 코드 또는 파일 경로]

테스트할 시나리오:

1. Happy Path (정상 동작):
   - [시나리오 1: onAppear → 데이터 로드 성공]
   - [시나리오 2: 버튼 탭 → delegate 전달]

2. Edge Cases:
   - [빈 데이터 처리]
   - [중복 요청 처리]
   - [취소 동작]

3. Error Handling:
   - [네트워크 에러]
   - [인증 실패]
   - [데이터 파싱 실패]

Mock 설정:
- [Client명].fetchData: [성공/실패 케이스]
- [Client명].update: [성공 케이스]

패턴:
- @Suite, @Test 사용
- @MainActor 적용
- confirmation 패턴으로 비동기 검증
- #expect로 검증

파일 위치:
Projects/Features/[Feature명]/Tests/Sources/[Feature명]Tests.swift
```

### Integration 테스트
```
[ParentFeature]와 [ChildFeature] 간 통합 테스트를 작성해줘.

통합 시나리오:
1. 부모가 자식 Feature 생성 (.destination에 할당)
2. 자식에서 액션 발생 (예: 버튼 탭)
3. 자식이 delegate로 부모에게 이벤트 전달
4. 부모가 상태 업데이트 및 자식 dismiss

검증할 것:
- 상태 전파 (.destination State 변경)
- Action 통신 (delegate Action 수신)
- Side Effect 순서 (Effect가 올바른 순서로 실행)
- 최종 상태 (부모 State가 예상대로 변경)

패턴:
- TestStore 사용
- await store.send(), await store.receive() 패턴
- exhaustivity = .off 필요시 사용
```

---

## 📚 문서화

### README 생성
```
[모듈명]의 README.md를 작성해줘.

포함 내용:
1. 모듈 목적 (1-2문장)
2. 주요 타입/함수 목록
3. 의존성
4. 사용 예시 (코드 포함)
5. 주의사항 또는 알려진 제한사항

톤: 간결하고 실용적
형식: Markdown

예시 구조:
# [모듈명]

[모듈 설명]

## 주요 타입
- `Type1`: 설명
- `Type2`: 설명

## 의존성
- Module1
- Module2

## 사용 예시
```swift
// 코드 예시
```

## 주의사항
- [주의사항]
```

### API 문서
```
[Client명]의 API 문서를 생성해줘.

각 함수마다:
- 목적 (한 줄 설명)
- 파라미터 설명
- 리턴값 설명
- throws: 발생 가능한 에러 케이스
- 사용 예시 (코드)

형식: Swift DocC 스타일 주석

예시:
/// [함수 목적]
///
/// [상세 설명]
///
/// - Parameters:
///   - param1: 설명
///   - param2: 설명
/// - Returns: 설명
/// - Throws: `ErrorType` if ...
///
/// # Example
/// ```swift
/// let result = try await client.method(param)
/// ```
```

---

## 🔄 마이그레이션

### 레거시 코드 → TCA 변환
```
다음 레거시 코드를 TCA 1.22.2로 변환해줘:

기존 코드 (MVVM/MVC):
[코드 붙여넣기]

변환 규칙:
1. ViewModel → Reducer
   - @Published 프로퍼티 → State
   - 메서드 → Action (view/internal/delegate로 분류)

2. Combine → TCA Effect
   - Publisher → .run { send in }
   - sink → await send(.internal(...))

3. 의존성 주입
   - Protocol 주입 → @Dependency
   - Singleton → DependencyKey

4. 비동기 처리
   - Completion handler → async/await
   - DispatchQueue → Task

5. 테스트
   - XCTest → Swift Testing
   - Mock 객체 → withDependencies

추가 개선:
- 에러 핸들링 개선
- Namespace 패턴 적용
- Preview 코드 추가
```

---

## 💡 프롬프트 작성 팁

### 좋은 프롬프트 체크리스트
- [ ] 구체적인 요구사항이 명시되어 있는가?
- [ ] 프로젝트 컨텍스트가 포함되어 있는가?
- [ ] 유사한 기존 코드 예시가 있는가?
- [ ] 제약사항이 명확한가?
- [ ] 원하는 출력 형식이 명시되어 있는가?
- [ ] 검증 가능한 기준이 있는가?

### 나쁜 프롬프트의 예
❌ "로그인 화면 만들어줘"
- 어떤 UI? 어떤 인증 방식? 에러 처리는?

❌ "버튼 추가해줘"
- 어디에? 무슨 색? 어떤 동작?

❌ "최적화해줘"
- 무엇을? 어떤 기준으로?

### 좋은 프롬프트의 예
✅ "Apple/Google 소셜 로그인을 지원하는 AuthFeature를 만들어줘. AuthClient 의존성 사용, 에러 핸들링 포함, @ObservableState 사용"

✅ "파란색 배경(Color.primary), 흰색 텍스트, 모서리 12pt 둥근 버튼 컴포넌트를 Shared/DesignSystem/Components에 만들어줘. 크기와 텍스트를 파라미터로 받도록"

✅ "HomeFeature의 스크롤 성능을 개선해줘. 현재 FPS 30fps → 60fps 목표. LazyVStack 사용 및 이미지 lazy loading 적용"

### 반복 개선 전략
```
1차 요청: 기본 구조 생성
↓
2차 요청: "에러 핸들링 추가해줘"
↓
3차 요청: "테스트 코드 작성해줘"
↓
4차 요청: "문서화 및 Preview 추가해줘"
```

---

## 📌 자주 사용하는 프롬프트 패턴

### 빠른 프로토타이핑
```
"[기능] Feature의 기본 골격만 빠르게 만들어줘.
State, Action, body만 있으면 돼.
나중에 구체적인 로직은 내가 추가할게."
```

### 기존 코드 개선
```
"이 코드를 PROJECT_CONTEXT.md의 베스트 프랙티스에 맞게 개선해줘:
[코드]

특히 다음 부분 집중:
- Action 계층화
- Sendable 프로토콜
- 에러 핸들링"
```

### 일관성 유지
```
"[기존Feature]와 동일한 패턴으로 [새Feature]를 만들어줘.
파일 구조, 네이밍, 스타일 모두 동일하게."
```

---

**사용 팁**:
- 이 템플릿들을 상황에 맞게 커스터마이징하세요
- 전체 파일보다는 핵심 부분만 붙여넣으세요
- AI의 첫 응답이 부족하면 구체적으로 재요청하세요
- 좋은 프롬프트를 발견하면 이 문서에 추가하세요

**Claude Code 활용**:
```bash
# 템플릿 사용 예시
"PROMPTS.md의 '새 Feature 생성' 템플릿으로 NotificationFeature 만들어줘"

# 또는 직접 구체적으로
"알림 목록 Feature 만들어줘. TCA 사용, @ObservableState, async/await, 테스트 포함"
```
