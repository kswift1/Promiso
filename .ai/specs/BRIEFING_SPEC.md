# Daily Briefing 스펙

> **마지막 업데이트**: 2026.03.08

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
     language,                        7. promise 상세 조회 (N reads)
     location                         8. location.lat/lng -> 날씨 조회
   }                                  9. location + 일정 좌표 -> 교통 정보 조회
                                         - ODsay: 대중교통 (소요시간, 환승, 요금)
                                         - Kakao Mobility: 자동차 (소요시간, 통행료)
                                         - 도보: 직선거리 기반 자체 계산
                                     10. 분석 (교통 정보, 날씨 매칭 등)
                                     11. 프롬프트 조립
                                     12. Gemini API 호출
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

### 1단계: scheduleSlots (1 read)

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
scheduleSlots는 충돌 감지 전용 스키마이므로 확장하지 않는다.

**포함되는 일정**:
| 케이스 | severity |
|--------|----------|
| 내가 호스트로 생성한 약속 (자동 accepted) | isConfirmed 기반 |
| 제안 받고 수락(accepted)한 약속 | isConfirmed 기반 |
| 내 개인 일정 | 항상 "confirmed" |

**포함되지 않는 일정**:
- 아직 응답 안 한 약속 -> 홈 "응답 필요" 섹션에서 별도 처리
- 거절(declined)한 약속

### 2단계: promise 상세 조회 (N reads)

scheduleSlots에서 `type: "promise"`인 슬롯의 id로 promise 문서를 개별 조회한다.

**추가로 얻는 필드**:
| 필드 | 용도 |
|------|------|
| `location.name` | 장소명 (프롬프트 표시) |
| `location.latitude/longitude` | 이동 거리 계산 |
| `groupId` -> 그룹 문서 or 캐시 | 그룹명 |

scheduleSlots 스키마를 확장하지 않는 이유:
- scheduleSlots는 충돌 감지 전용, 책임 분리
- 스키마 확장 시 트리거 6개 수정 + write 비용 증가
- 추가 쿼리 비용이 write 비용보다 저렴 (read $0.06 vs write $0.18 / 100K)

### 3단계: 날씨 조회

**파일**: `infra/firebase/functions/src/functions/weather.ts`

기상청 공공데이터 API 기반. location 좌표로 조회한다.
location이 null이면 날씨 조회를 건너뛴다.

**활용 데이터**:
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

---

## 서버 분석 로직

scheduleSlots + promise 상세 + 날씨 데이터를 조합하여 프롬프트에 전달할 분석 결과를 생성한다.
임계값 판단은 하지 않고, 사실(수치)만 프롬프트에 전달하여 Gemini가 자연어로 표현한다.

### 이동 거리 계산 (기본)

연속 일정 간 직선 거리를 Haversine 공식으로 계산한다.
교통 API 호출 실패 시 Fallback으로도 사용한다.

```typescript
function haversineKm(
  lat1: number, lng1: number,
  lat2: number, lng2: number
): number {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) *
    Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
```

**계산 대상**:
- 현재 위치 -> 첫 번째 약속 장소
- 약속 장소 -> 다음 약속 장소 (연속 일정)

**계산 조건**: 양쪽 모두 좌표가 있을 때만 계산. 좌표 없는 일정은 건너뛴다.

### 교통 정보 조회 (4단계)

직선 거리 대신 **실제 교통수단별 소요시간**을 프롬프트에 제공한다.
교통수단별 판단은 Gemini에게 위임한다 (사용자마다 이동 수단과 체감이 다르므로).

#### 사용 API

| 교통수단 | API | 엔드포인트 |
|----------|-----|-----------|
| 대중교통 | ODsay Lab | `GET /v1/api/searchPubTransPathT` |
| 자동차 | Kakao Mobility | `GET /v1/directions` |
| 도보 | 자체 계산 | 직선거리 × 1.3 ÷ 4km/h |

#### ODsay Lab — 대중교통 경로

**문서**: https://lab.odsay.com/guide/guide

**요청**:
```
GET https://api.odsay.com/v1/api/searchPubTransPathT
  ?SX={출발 경도}&SY={출발 위도}
  &EX={도착 경도}&EY={도착 위도}
  &apiKey={ODSAY_API_KEY}
```

**응답 핵심 필드** (`result.path[0].info`):
```typescript
{
  totalTime: number;           // 총 소요시간 (분)
  payment: number;             // 요금 (원)
  busTransitCount: number;     // 버스 환승 횟수
  subwayTransitCount: number;  // 지하철 환승 횟수
  totalWalk: number;           // 도보 거리 (미터)
  totalWalkTime: number;       // 도보 시간 (분), -1이면 미제공
  firstStartStation: string;   // 출발 정류장/역
  lastEndStation: string;      // 도착 정류장/역
}
```

**무료 한도**: Basic 플랜 일 1,000건 (6개월 무료, 이후 유료 전환 필요).

#### Kakao Mobility — 자동차 경로

**문서**: https://developers.kakaomobility.com/docs/navi-api/directions/

**요청**:
```
GET https://apis-navi.kakaomobility.com/v1/directions
  ?origin={출발 경도},{출발 위도}
  &destination={도착 경도},{도착 위도}
  &summary=true
Headers: Authorization: KakaoAK {REST_API_KEY}
```

**응답 핵심 필드** (`routes[0].summary`):
```typescript
{
  distance: number;    // 총 거리 (미터)
  duration: number;    // 소요시간 (초)
  fare: {
    taxi: number;      // 택시 요금 추정 (원)
    toll: number;      // 통행료 (원)
  };
}
```

**무료 한도**: 일 10,000건 (월 3,000,000건).

**미래 시간대 경로**: `/v1/future/directions` 엔드포인트로 약속 시간 기준 예측 소요시간 조회 가능 (향후 적용 고려).

#### 도보 — 자체 계산

독립 도보 API가 없으므로 (Kakao 도보 API는 파트너십 필요) 자체 계산한다.

```typescript
function estimateWalkMinutes(distanceKm: number): number {
  const actualDistance = distanceKm * 1.3;  // 직선 → 실제 경로 보정
  return Math.round(actualDistance / 4 * 60); // 시속 4km 기준
}
```

#### 호출 전략

- **서버 사이드 전용**: API Key 노출 방지를 위해 Firebase Functions에서만 호출
- **병렬 호출**: 구간별로 ODsay + Kakao를 동시 호출하여 지연 최소화
- **캐싱 연동**: 브리핑 캐시에 교통 정보 포함. 브리핑이 캐시 히트되면 교통 API 호출 없음
- **교통 정보 캐시**: 동일 출발-도착 좌표 조합은 서버 메모리 캐시 1시간 TTL 적용
- **API Key 관리**: `ODSAY_API_KEY`, `KAKAO_REST_API_KEY`를 Firebase Functions 환경변수로 관리

#### 프롬프트 반영 형태

```
이동 정보:
- 현재 위치(강남구) -> 카페A (홍대):
  자동차 약 25분 (통행료 0원) | 대중교통 약 35분 (환승 1회, 1,450원) | 도보 약 52분
- 카페A (홍대) -> 레스토랑B (이태원):
  자동차 약 15분 | 대중교통 약 22분 (환승 0회, 1,450원) | 도보 약 30분
```

### 날씨 x 일정 매칭

시간대별 예보(30분 단위)를 일정 startAt과 매칭하여, 각 약속 시간대의 날씨를 프롬프트에 포함한다.

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
- 일정 많으면 -> 바쁜 하루 강조
- 일정 없으면 -> 날씨 중심, 여유로운 톤
- 비/눈 예보 -> 우산 챙기기 언급
- 일교차 크면 -> 겉옷 챙기기 언급
- 미확정 약속 (severity: pending) -> 확정 여부 확인 유도
- 교통 정보가 있으면 -> 교통수단별 소요시간 비교하여 이동 안내 자연스럽게 언급

[데이터]
현재: {timezone 기반 날짜/시간}
위치: {location.title}

날씨:
- 현재 {temp}도 (체감 {feelsLike}도), {condition}, 강수확률 {rain}%
- 오전: {forecasts}
- 오후: {forecasts}
- 최고 {max}도 / 최저 {min}도

오늘 일정:
1. [{startAt}~{endAt}] {title} @ {location} | {groupName} | {severity}
   날씨: {해당 시간대 예보}
2. ...

이동 정보:
- 현재 위치({title}) -> {약속1 장소}:
  자동차 약 {N}분 (통행료 {N}원) | 대중교통 약 {N}분 (환승 {N}회, {N}원) | 도보 약 {N}분
- {약속1 장소} -> {약속2 장소}:
  자동차 약 {N}분 | 대중교통 약 {N}분 (환승 {N}회, {N}원) | 도보 약 {N}분
```

서버에서 프롬프트를 조립하므로, Functions deploy만으로 프롬프트 튜닝이 가능하다.

---

## Fallback

| 상황 | 처리 |
|------|------|
| location null | 날씨/교통 정보 없이 일정 기반 브리핑 |
| scheduleSlots 문서 없음 | 일정 없음으로 처리 |
| promise 상세 조회 실패 | scheduleSlots 데이터만으로 브리핑 (장소/그룹 없이) |
| ODsay API 오류/타임아웃 | 대중교통 정보 없이 자동차 + 도보만 표시 |
| Kakao API 오류/타임아웃 | 자동차 정보 없이 대중교통 + 도보만 표시 |
| 교통 API 모두 실패 | Haversine 직선거리 Fallback ("약 {N}km") |
| Gemini API 키 없음 | 기본값 반환 ("좋은 하루 되세요!") |
| Gemini API 오류 | 기본값 반환 |
| JSON 파싱 실패 | 원문 텍스트를 detail로, 첫 문장을 summary로 사용 |

---

## 캐싱 전략

온디맨드 생성 + 당일 캐시.

```
유저가 홈 열 때:
1. 캐시 확인 (메모리 또는 Firestore)
2. 캐시 있고 + 일정 변경 없음 -> 캐시 반환 (Gemini 호출 0)
3. 캐시 없거나 일정 변경됨 -> 생성 후 캐시 저장
```

Cron 사전 생성은 하지 않는다:
- 브리핑을 안 보는 유저도 생성하게 되어 Gemini 호출 낭비
- 생성 후 일정 변경되면 stale 브리핑 문제
- 동시 실행 폭발 위험

---

## 비용 (Pro 10,000명 기준, 일 1회)

| 항목 | 계산 | 월 비용 |
|------|------|--------|
| scheduleSlots read | 10K x 1 read x 30일 = 300K | $0.18 |
| promise 상세 read | 10K x 3 reads x 30일 = 900K | $0.54 |
| 기상청 API | 무료 (30분 캐시) | $0 |
| ODsay (대중교통) | 10K x 3구간 x 30일 = 900K | 무료 (Basic) → 유료 전환 시 협의 |
| Kakao Mobility (자동차) | 10K x 3구간 x 30일 = 900K | 무료 (일 10K 한도 내) |
| Gemini Flash | 10K x 30일 = 300K 호출 | $15~45 |
| Cloud Functions | 300K 실행 | $5~10 |
| **합계** | | **~$21~56/월** (교통 API 무료 기준) |

비용의 80% 이상이 Gemini API. 캐싱으로 실제 호출 수를 줄이면 비용 절감 가능.

**교통 API 한도 주의**:
- ODsay Basic은 일 1,000건 → Pro 유저 약 330명(약속 평균 3구간)에서 한도 도달. 스케일 시 Standard 플랜 전환 필요.
- Kakao Mobility는 일 10,000건 → Pro 유저 3,300명에서 한도 도달.
- 브리핑 캐시 히트 시 교통 API 호출 없으므로, 실 호출 수는 이론치보다 낮음.

---

## 관련 파일

| 파일 | 역할 |
|------|------|
| `infra/firebase/functions/src/functions/briefing.ts` | Cloud Function |
| `infra/firebase/functions/src/functions/weather.ts` | 날씨 조회 |
| `infra/firebase/functions/src/functions/transportation.ts` | 교통 정보 조회 (ODsay + Kakao) — 신규 |
| `infra/firebase/functions/src/functions/scheduleConflicts.ts` | scheduleSlots 트리거 |
| `infra/firebase/functions/src/types/api.ts` | API 타입 정의 |
| `Projects/Clients/Sources/Clients/BriefingClient.swift` | iOS 클라이언트 |
| `Projects/Features/HomeFeature/Sources/HomeFeature.swift` | HomeFeature Reducer |

---

## TODO (향후)

### 브리핑 카드 CTA (UI 액션)

Response에 action 필드 추가. 상황에 따라 1개만 노출.
action 결정은 Gemini가 아닌 서버 로직(규칙 기반)으로 처리 (hallucination 방지).

```typescript
action: {
  type: "open_promise" | "send_nudge" | "create_promise";
  promiseId?: string;
  label: string;  // "약속 보기", "확인 요청 보내기", "약속 만들기"
} | null;
```

| 상황 | CTA | type |
|------|-----|------|
| 미확정 + 미응답 멤버 있음 | "확인 요청 보내기" | send_nudge |
| 오늘 약속 있음 | "약속 보기" | open_promise |
| 오늘 일정 없음 | "약속 만들기" | create_promise |

우선순위: send_nudge > open_promise > create_promise

### 서버 개입 (푸시 알림)

- 미확정 약속 투표 유도 푸시: 내가 수락했지만 최소 인원 미충족인 약속에 대해, 미응답 멤버에게 remote push로 투표 유도 ("OO님이 일정을 확인해달래요")
  - cooldown 정책 필요 (최근 N시간 내 발송 시 skip)
- 날씨 알림 푸시: 오늘 약속에 특이 날씨 예보(폭우, 폭설, 한파 등)가 있으면 해당 약속 수락자 전원에게 remote push ("오늘 OO 모임 시간에 비 예보가 있어요, 우산 챙기세요")
- 출발 리마인드: 약속 30~60분 전, 이동 거리 고려하여 출발 권장 푸시
- 재조율 제안: 다수 거절 or 장기 미응답 시 호스트에게 시간 재조율 제안 (자동 실행 아닌 추천만)
