# Changelog

Firebase Functions 변경 이력입니다.
AI(Claude)가 서버 코드를 관리하며, iOS 개발자가 히스토리를 추적할 수 있도록 기록합니다.

---

## 2026-01-21

### refactor: 도메인별 파일 분리
- **변경**: 기존 `index.ts` (3400+ lines) → 도메인별 파일 분리
- **이유**: 파일이 너무 커서 AI 컨텍스트 윈도우 초과 문제 발생
- **구조**:
  ```
  src/
  ├── index.ts              # re-export만 (~65 lines)
  ├── config/index.ts       # Firebase, APNs 설정
  ├── functions/
  │   ├── users.ts          # 7개 함수
  │   ├── groups.ts         # 5개 함수
  │   ├── promises.ts       # 3개 함수
  │   ├── notifications.ts  # 4개 함수
  │   ├── liveActivity.ts   # 6개 함수
  │   └── emoji.ts          # 1개 함수
  └── utils/
      ├── helpers.ts        # 공통 헬퍼
      ├── apns.ts           # APNs 유틸리티
      └── firestore.ts      # Firestore 환경 분리
  ```

### feat: generateEmoji 신규 배포
- **기능**: Gemini API로 약속 제목에 맞는 이모지 자동 생성
- **iOS 연동**: `CreatePromiseView`에서 제목 입력 시 호출
- **Fallback**: API 실패 시 기본값 `📅` 반환

### docs: OpenAPI 문서 동기화
- **추가**: `checkNicknameAvailable`, `previewGroup`, `leaveGroup`, `deleteGroup`, `widgetUpdateETA`
- **제거**: `testCallable` (테스트용), `endLiveActivity` (deprecated)
- **이유**: 코드와 문서 불일치 해소

---

## 2026-01-15 (이전 작업 추정)

### feat: iOS 18 Broadcast Push 방식 전환
- **변경**: 개별 APNs 토큰 관리 → channelId 기반 Broadcast
- **이유**:
  - 토큰 관리 복잡성 제거
  - Apple WWDC24 권장 방식
  - 실시간성 향상
- **영향받는 함수**:
  - `startLiveActivity`: Push to Start + 채널 생성
  - `updateETA`: Broadcast로 전체 참가자에게 전송
  - `executeLiveActivityStart`: Cloud Tasks 예약 실행
- **제거**: `endLiveActivity` (APNs `dismissal-date`로 자동 종료)

### feat: widgetUpdateETA HTTP 엔드포인트
- **이유**: Widget Extension은 Firebase SDK 사용 불가
- **URL**: `https://widgetupdateeta-dfaqqrbqgq-du.a.run.app`
- **인증**: `X-User-Id` 헤더 (필수), `X-Auth-Token` (선택)

---

## 변경 기록 작성 가이드

새로운 변경 시 아래 형식으로 추가:

```markdown
## YYYY-MM-DD

### type: 제목
- **변경**: 무엇이 바뀌었는지
- **이유**: 왜 바꿨는지 (중요!)
- **iOS 연동**: 관련 iOS 코드 위치
- **주의사항**: 있다면 기록
```

**type 종류**: feat, fix, refactor, docs, chore
