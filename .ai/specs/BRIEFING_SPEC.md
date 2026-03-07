# Daily Briefing 스펙

> **마지막 업데이트**: 2026.03.07

## 개요

사용자의 오늘 일정과 날씨를 종합하여 Gemini LLM 기반 하루 브리핑을 생성하는 Pro 기능.
서버에서 데이터 수집 + 프롬프트 조립을 전담하여, 클라이언트는 디바이스 전용 데이터만 전송한다.

---

## 데이터 흐름

```
iOS App                              Firebase Functions (generateBriefing)
-------                              ------------------------------------
1. GPS -> 좌표 획득
2. CLGeocoder -> 위치 텍스트
3. 전송 --------------------------->  4. auth.uid 인증 확인
   {                                  5. timezone 기반 오늘 날짜 계산
     timezone,                        6. scheduleSlots/{오늘} 조회 (1 read)
     language,                        7. location.lat/lng -> 날씨 조회
     location                         8. 프롬프트 조립
   }                                  9. Gemini API 호출
                              <----  { summary, detail }
```

---

## API 명세

### Request

```typescript
interface GenerateBriefingRequest {
  /** 유저 타임존 (서버는 UTC이므로 필수) */
  timezone: string;             // "Asia/Seoul"

  /** 브리핑 언어 (다국어 확장 대비) */
  language: string;             // "ko"

  /** 유저 위치 (위치 권한 거부 시 null) */
  location: {
    latitude: number;
    longitude: number;
    title: string;              // "서울 강남구" (CLGeocoder, 무료)
  } | null;
}
```

클라이언트는 디바이스에서만 얻을 수 있는 데이터만 전송한다:
- GPS 좌표 -> 디바이스 전용
- timezone -> 유저 실제 타임존
- language -> 유저 언어 설정
- location.title -> CLGeocoder (무료, 서버 역지오코딩은 유료 API 필요)

### Response

```typescript
interface GenerateBriefingResponse {
  /** 한 줄 요약 (30자 이내) */
  summary: string;

  /** 상세 브리핑 (3~5문장) */
  detail: string;
}
```

---

## 서버 데이터 조회

### 일정: scheduleSlots

**경로**: `users/{uid}/scheduleSlots/{YYYY-MM-DD}`

```typescript
interface ScheduleSlotDocument {
  slots: ScheduleSlotEntry[];
  updatedAt: Timestamp;
}

interface ScheduleSlotEntry {
  id: string;
  type: "promise" | "personalEvent";
  title: string;
  emoji: string | null;
  startAt: Timestamp;
  endAt: Timestamp | null;
  severity: "confirmed" | "pending";
}
```

Firestore 트리거가 약속/개인일정 생성, 수정, 삭제 시 자동으로 슬롯을 관리한다.

**포함되는 일정**:
| 케이스 | severity |
|--------|----------|
| 내가 호스트로 생성한 약속 (자동 accepted) | isConfirmed 기반 |
| 제안 받고 수락(accepted)한 약속 | isConfirmed 기반 |
| 내 개인 일정 | 항상 "confirmed" |

**포함되지 않는 일정**:
- 아직 응답 안 한 약속 -> 홈 "응답 필요" 섹션에서 별도 처리
- 거절(declined)한 약속

**비용**: 1 read / 요청

**현재 미포함 필드** (스키마 확장 시 추가 가능):
- location (장소)
- groupName (그룹명)
- participantCount (참가자 수)

### 날씨: weather.ts 내부 함수

**파일**: `infra/firebase/functions/src/functions/weather.ts`

기상청 공공데이터 API 기반. location 좌표로 조회한다.

**활용 가능 데이터**:
| 필드 | 설명 |
|------|------|
| temperature | 현재 기온 |
| feelsLikeTemperature | 체감 온도 |
| condition | 날씨 상태 (clear, cloudy, rain 등) |
| precipitationProbability | 강수확률 (%) |
| humidity | 습도 |
| windSpeed | 풍속 |
| dailyForecasts | 최고/최저 기온 |
| forecasts (30분 단위) | 시간대별 예보 |

서버 메모리 캐시 30분 TTL 적용.

location이 null이면 날씨 조회를 건너뛴다.

---

## 프롬프트 설계

### 구조

```
[시스템 역할]
당신은 사용자의 하루를 친근하게 브리핑해주는 개인 비서입니다.

[출력 규칙]
- JSON으로만 응답: {"summary":"...", "detail":"..."}
- summary: 핵심 한 줄 (30자 이내), 날씨 + 주요 일정 키워드
- detail: 3~5문장, 친근한 {language} 말투

[브리핑 가이드]
- 일정 많으면 -> 바쁜 하루 강조, 이동 동선 고려
- 일정 없으면 -> 날씨 중심, 여유로운 톤
- 비/눈 예보 -> 우산 챙기기 언급
- 일교차 크면 -> 겉옷 챙기기 언급
- 미확정 약속 (severity: pending) -> 확정 여부 확인 유도

[데이터]
현재: {timezone 기반 날짜/시간}
위치: {location.title}

날씨:
- 현재 {temp}도 (체감 {feelsLike}도), {condition}, 강수확률 {rain}%
- 오전: {forecasts}
- 오후: {forecasts}
- 최고 {max}도 / 최저 {min}도

오늘 일정:
1. [{startAt}~{endAt}] {title} ({type}, {severity})
2. ...
```

서버에서 프롬프트를 조립하므로, Functions deploy만으로 프롬프트 튜닝이 가능하다.

---

## Fallback

| 상황 | 처리 |
|------|------|
| location null | 날씨 없이 일정 기반 브리핑 |
| scheduleSlots 문서 없음 | 일정 없음으로 처리 |
| Gemini API 키 없음 | 기본값 반환 ("좋은 하루 되세요!") |
| Gemini API 오류 | 기본값 반환 |
| JSON 파싱 실패 | 원문 텍스트를 detail로, 첫 문장을 summary로 사용 |

---

## 비용

| 항목 | 단가 | Pro 100명 기준 (일 1회) |
|------|------|----------------------|
| Firestore read | $0.06 / 100K | ~$0.002/월 |
| 기상청 API | 무료 | - |
| Gemini API (flash) | 기존과 동일 | 기존과 동일 |

---

## 관련 파일

| 파일 | 역할 |
|------|------|
| `infra/firebase/functions/src/functions/briefing.ts` | Cloud Function |
| `infra/firebase/functions/src/functions/weather.ts` | 날씨 조회 |
| `infra/firebase/functions/src/functions/scheduleConflicts.ts` | scheduleSlots 트리거 |
| `infra/firebase/functions/src/types/api.ts` | API 타입 정의 |
| `Projects/Clients/Sources/Clients/BriefingClient.swift` | iOS 클라이언트 |
| `Projects/Features/HomeFeature/Sources/HomeFeature.swift` | HomeFeature Reducer |
