# WS2: 브리핑 Free 공개 + Push 비서 톤 + 반복 카피

**브랜치**: `feat/briefing-free-push-tone` (release/v1.2.0에서 분기)
**의존성**: WS1 완료 후 rebase (HomeFeature.swift 브리핑 영역). 2번째 머지.

---

## 2-A. 브리핑 Free 공개

### iOS 클라이언트

수정 파일: `Projects/Features/HomeFeature/Sources/Components/DailyBriefing/DailyBriefingCard.swift`

- isPro 분기 변경: `blur(radius: 6)` 삭제
- summary + detail 모든 유저에게 전체 노출
- 설정칩 중 교통/스타일은 Pro 전용 유지
- 하단에 "출발 시간도 알려드릴까요? → Pro" CTA 추가
- `onProUpgradeTapped` 콜백 유지 (CTA용)

### Firebase Functions

수정 파일: `infra/firebase/functions/src/functions/briefing.ts`

- 라인 1091~1103: `if (isPro)` 교통 API 분기 유지
- 날씨 조회 코드를 isPro 밖으로 이동 (Free에도 포함)
- Free 브리핑 표시 조건: scheduleSlots에 일정 1개 이상 있을 때만 generate. 없으면 미생성.

`briefingScheduler.ts` 변경 없음 — 스케줄 Push는 Pro 전용 유지.

### HomeFeature.swift (브리핑 영역만)

수정 파일: `Projects/Features/HomeFeature/Sources/HomeFeature.swift`

- 브리핑 generate 호출 전 일정 존재 여부 체크 추가
- 일정 0개면 generate 스킵 → 빈 상태 or 미표시
- **주의**: calendar/banner/sheet 영역 (WS1) 및 departure 영역 (WS4) 절대 건드리지 않음

---

## 2-B. Push 알림 비서 톤 전환

수정 파일: `infra/firebase/functions/src/functions/notifications.ts`

| 위치 | AS-IS | TO-BE |
|------|-------|-------|
| 라인 622-623 (약속 생성) 제목 | `"새 약속 도착 📩"` | `"새 약속이 도착했어요"` |
| 라인 622-623 (약속 생성) 본문 | `"${hostName}님이 ${title}을 제안했어요. 확인해주세요!"` | `"${hostName}님이 제안한 ${title}, 확인해볼까요?"` |
| 라인 697-698 (약속 확정) 제목 | `"${title} 약속 확정! 🎉"` | `"Promiso가 약속을 확정했어요"` |
| 라인 697-698 (약속 확정) 본문 | `"${dateTimeString}에 만나요!"` | `"따로 연락 안 해도 돼요. ${dateTimeString}에 만나요!"` |
| 라인 719-720 (약속 무산) 제목 | `"${title} 약속 무산 😢"` | `"아쉽지만 이번엔 어려울 것 같아요"` |
| 라인 719-720 (약속 무산) 본문 | `"참여 인원이 부족해서 확정되지 않았어요"` | `"${title}, 다시 잡아볼까요?"` |
| 라인 847-848 (약속 수정) 제목 | `"${title} 변경 📝"` | `"${title} 정보가 바뀌었어요"` |
| 라인 847-848 (약속 수정) 본문 | `"약속 정보가 수정됐어요. 확인해주세요!"` | `"변경된 내용을 확인해보세요!"` |
| 라인 779-780 (멤버 합류) 제목 | `"새 멤버 합류 👋"` | `"${newMemberName}님이 합류했어요 👋"` |
| 라인 779-780 (멤버 합류) 본문 | `"${newMemberName}님이 ${groupName}에 들어왔어요"` | `"${groupName}에 새 멤버가 들어왔어요"` |

---

## 2-C. 반복 일정 카피

수정 파일: `Projects/Shared/Resources/Localizable.xcstrings`

- 반복 일정 관련 카피를 비서 톤으로 전환
- 예시: "반복 일정 추가" → "한 번만 알려주면 제가 알아서 챙길게요"

---

## 카피 톤 기준 (이 WS가 확립)

이 WS에서 정립된 톤 기준을 WS1(온보딩 배너), WS5(독촉 Push)가 동일하게 따른다.

- 주어: "Promiso" (3인칭 비서)
- 이모지 자제 (제목에 최소한만)
- 존댓말 + 부드러운 톤
- Push 패턴: "~해볼까요?", "~해드릴게요"

---

## 컨벤션

- TCA: `@ObservableState`, Namespace 패턴
- Glass Effect: `#available(iOS 26)` Fallback 분기
- 색상: `Color.pm*` (하드코딩 금지)
- Action 3분할 (View / Internal / Delegate)
- Firebase 직접 호출 금지 — Client 레이어 통과
