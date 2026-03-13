# 제품 전략 가이드

Promiso의 제품 정체성, 포지셔닝, 주요 메시지 기준을 정의하는 문서입니다.

## 문서 메타

- 목적: 온보딩, 마케팅, Paywall, 핵심 UX 카피의 기준 제공
- 대상 독자: 프로덕트 디자이너, iOS 개발자, 카피 작성자, 마케팅 작업자
- 최종 수정일: 2026-03-14
- 관련 문서: [README.md](README.md) · [ARCHITECTURE.md](ARCHITECTURE.md)

## 한 줄 정의

- 카테고리: 일정 관리 앱
- 핵심 가치: 개인 일정과 그룹 약속을 한 곳에서 관리하는 내 전체 일정 허브
- 차별점: 약속을 잡는 과정부터 당일까지 이어지는 그룹 약속 lifecycle
- Pro 가치: 일정을 대신 챙겨주는 자동화/비서 경험

## 포지셔닝

### Short

개인 일정과 그룹 약속을 함께 관리하는 약속 중심 일정 앱

### Medium

개인 일정과 그룹 약속을 한 곳에서 관리하고, 약속을 잡는 과정부터 당일까지 이어서 경험하는 일정 앱

### Long

약속을 만들고, 응답을 모으고, 자동으로 확정하고, 당일까지 이어서 관리하는 약속 중심 일정 관리 앱

## 제품 구조

### Free

- 개인 일정
- 그룹 약속
- 홈 통합 관리
- 캘린더 통합 보기
- N명 수락 시 자동 확정
- Live Activity 기반 당일 상태 공유

### Pro

- 일정 충돌 감지
- 약속 날씨 안내
- 출발 시간 추천 및 알림
- 하루 일정 브리핑

## 사용자 가치

### Step 1. 약속 잡기

- 초대
- 수락/거절 응답
- 최소 인원 충족 시 자동 확정

유저가 얻는 가치:
약속을 잡는 과정이 단순해진다.

### Step 2. 일정 관리

- 개인 일정
- 그룹 약속
- 홈 통합 뷰
- 캘린더 통합 뷰

유저가 얻는 가치:
오늘과 앞으로의 일정을 한 눈에 본다.

### Step 3. 약속 당일

- Live Activity 상태 공유
- 도착까지 남은 시간 공유
- Pro 기준 출발 판단/브리핑 자동화

유저가 얻는 가치:
당일 커뮤니케이션 비용이 줄고, 준비 판단이 쉬워진다.

## 메시지 원칙

### 반드시 강조할 것

- Promiso는 단순한 그룹 일정 앱이 아니라 개인 일정까지 함께 관리하는 허브다.
- Promiso의 차별점은 그룹 약속 lifecycle이다.
- Free에서도 그룹 약속 생성, 자동 확정, Live Activity 경험은 핵심 가치다.
- Pro는 보관 기능보다 자동화와 판단 보조를 판다.

### 과장하지 말 것

- Promiso를 메신저나 메모 대체 앱처럼 설명하지 않는다.
- Pro를 반복 일정 자동화로 설명하지 않는다. 현재 제품 기준 Pro 핵심은 충돌, 날씨, 출발, 브리핑이다.
- 이미 제공 중인 Pro 기능을 `출시 예정`처럼 설명하지 않는다.

## 권장 온보딩 구조

### 1. Hook

- 흩어진 약속 관리 경험을 Promiso가 한 곳으로 정리한다는 첫 인식 제공

### 2. Problem Empathy

- 약속 하나에 여러 앱을 오가야 하는 현재의 불편함을 짧게 공감시킨다

### 3. Benefit 1: 약속 잡기

- 초대
- 응답
- 자동 확정

### 4. Benefit 2: 일정 허브

- 개인 일정과 그룹 약속이 홈/캘린더에서 함께 보인다는 점을 보여준다

### 5. Benefit 3: 당일 경험

- Live Activity 상태 공유로 `지금 어디야?`를 줄인다는 점을 보여준다

### 6. Pro Preview

- Pro는 자동화와 보조 판단이라는 방향으로만 보여준다

### 7. Sign In

- 가치를 충분히 전달한 뒤 진입시킨다

개인화 질문은 선택 항목이다.
실제 후속 카피, 설정 기본값, 추천 시나리오를 바꾸지 않는다면 핵심 온보딩 단계로 넣지 않는다.

## 현재 코드 정합도

| 영역 | 정합도 | 근거 |
|------|--------|------|
| 개인 + 그룹 일정 허브 | 높음 | [../Projects/Features/RootTabFeature/Sources/RootTabFeature.swift](../Projects/Features/RootTabFeature/Sources/RootTabFeature.swift), [../Projects/Features/HomeFeature/Sources/HomeFeature+StateComputed.swift](../Projects/Features/HomeFeature/Sources/HomeFeature+StateComputed.swift), [../Projects/Features/CalendarFeature/Sources/Feature/CalendarFeature.swift](../Projects/Features/CalendarFeature/Sources/Feature/CalendarFeature.swift) |
| 그룹 약속 lifecycle | 높음 | [../Projects/Clients/Sources/Domain/Models/ScheduleModel.swift](../Projects/Clients/Sources/Domain/Models/ScheduleModel.swift), [../Projects/Features/GroupFeature/Sources/GroupMain/GroupMainFeature.swift](../Projects/Features/GroupFeature/Sources/GroupMain/GroupMainFeature.swift), [../Projects/Features/CreateScheduleFeature/Sources/Views/Step3/ArrivalSharingSection.swift](../Projects/Features/CreateScheduleFeature/Sources/Views/Step3/ArrivalSharingSection.swift) |
| Free / Pro 가치 구분 | 높음 | [../Projects/Features/HomeFeature/Sources/HomeFeature.swift](../Projects/Features/HomeFeature/Sources/HomeFeature.swift), [../Projects/Features/PersonalFeature/Sources/PersonalFeature.swift](../Projects/Features/PersonalFeature/Sources/PersonalFeature.swift), [../Projects/Features/ProPlanFeature/Sources/PaywallView.swift](../Projects/Features/ProPlanFeature/Sources/PaywallView.swift) |
| 온보딩 구조 | 부분 정합 | 현재 구현은 Problem Empathy 중심이며 Personalization 단계는 없음. [../Projects/Features/AppEntryFeature/Sources/Onboarding/OnboardingIntroFeature.swift](../Projects/Features/AppEntryFeature/Sources/Onboarding/OnboardingIntroFeature.swift), [../Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/ProblemEmpathyView.swift](../Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/ProblemEmpathyView.swift) |
| ProPreview 카피 | 수정 필요 | 현재 `고정 약속 자동 생성`, `업데이트를 기대해주세요` 문구는 본 문서의 Pro 정의와 다름. [../Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/ProPreviewView.swift](../Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/ProPreviewView.swift) |

## 다음 정렬 대상

이 문서를 기준으로 아래 항목을 순서대로 맞춥니다.

1. 온보딩 화면 순서와 카피
2. Pro Preview 메시지
3. Paywall/온보딩/홈 브리핑의 톤 일관성
4. 마케팅 문구와 앱 소개문
