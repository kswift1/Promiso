/**
 * Weather Functions
 *
 * 기상청 공공데이터 API 프록시 (단기예보 + 중기예보)
 *
 * @added 2026-02-17
 * @why 기상청 API 키 노출 방지 + 좌표→격자 변환 서버 처리
 * @ios HomeFeature, PromiseDetailFeature - 약속 카드 날씨 표시
 */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";
import {defineSecret} from "firebase-functions/params";
import * as https from "https";

// 기상청 API 키 (Secret Manager에서 관리)
const KMA_API_KEY = defineSecret("KMA_API_KEY");

// MARK: - Server Cache

const CACHE_TTL_MS = 30 * 60 * 1000; // 30분
const CACHE_MAX_ENTRIES = 500;

interface CacheEntry {
  expiresAt: number;
  value: GetWeatherResponse;
}

const weatherCache = new Map<string, CacheEntry>();

/**
 * 캐시 키 생성 (좌표 + 시간 버킷)
 * @param {number} lat - 위도
 * @param {number} lng - 경도
 * @param {string} dateStr - ISO 8601 날짜
 * @return {string} 캐시 키
 */
function buildCacheKey(
  lat: number, lng: number, dateStr: string
): string {
  const date = new Date(dateStr);
  const hourBucket = Math.floor(
    date.getTime() / (60 * 60 * 1000)
  );
  return `${lat.toFixed(2)}_${lng.toFixed(2)}_${hourBucket}`;
}

/**
 * 캐시 조회 (만료 시 자동 삭제)
 * @param {string} key - 캐시 키
 * @param {number} now - 현재 시각 (epoch ms)
 * @return {GetWeatherResponse | null} 캐시된 응답
 */
function readCache(
  key: string, now: number
): GetWeatherResponse | null {
  const entry = weatherCache.get(key);
  if (!entry) return null;
  if (entry.expiresAt <= now) {
    weatherCache.delete(key);
    return null;
  }
  return entry.value;
}

/**
 * 캐시 저장 (초과 시 만료 항목 정리)
 * @param {string} key - 캐시 키
 * @param {GetWeatherResponse} value - 응답 데이터
 * @param {number} now - 현재 시각 (epoch ms)
 */
function writeCache(
  key: string, value: GetWeatherResponse, now: number
): void {
  weatherCache.set(key, {
    value,
    expiresAt: now + CACHE_TTL_MS,
  });
  if (weatherCache.size > CACHE_MAX_ENTRIES) {
    for (const [k, v] of weatherCache.entries()) {
      if (v.expiresAt <= now) weatherCache.delete(k);
    }
  }
}

/**
 * 날씨 조회 요청
 */
export interface GetWeatherRequest {
  latitude: number;
  longitude: number;
  targetDate: string; // ISO 8601
}

/**
 * 일별 예보 (중기예보)
 */
export interface DailyForecastItem {
  date: string;
  minTemperature: number;
  maxTemperature: number;
  amCondition: string;
  pmCondition: string;
  amPrecipitationProbability: number;
  pmPrecipitationProbability: number;
}

/**
 * 날씨 조회 응답
 */
export interface GetWeatherResponse {
  forecasts: Array<{
    dateTime: string;
    temperature: number;
    feelsLikeTemperature: number;
    condition: string;
    precipitationProbability: number;
    humidity: number;
    windSpeed: number;
    precipitationAmount: string;
  }>;
  dailyForecasts?: DailyForecastItem[];
}

/**
 * 기상청 격자 좌표
 */
interface GridCoord {
  nx: number;
  ny: number;
}

/**
 * 기상청 단기예보 API 응답
 */
interface KMAForecastResponse {
  response: {
    header: {
      resultCode: string;
      resultMsg: string;
    };
    body?: {
      items?: {
        item?: Array<{
          baseDate: string;
          baseTime: string;
          category: string;
          fcstDate: string;
          fcstTime: string;
          fcstValue: string;
          nx: number;
          ny: number;
        }>;
      };
    };
  };
}

/**
 * 위경도 → 기상청 격자 변환
 * (Lambert Conformal Conic Projection)
 * @param {number} lat - 위도
 * @param {number} lng - 경도
 * @return {GridCoord} 격자 좌표
 */
function convertToGrid(
  lat: number, lng: number
): GridCoord {
  const RE = 6371.00877;
  const GRID = 5.0;
  const SLAT1 = 30.0;
  const SLAT2 = 60.0;
  const OLON = 126.0;
  const OLAT = 38.0;
  const XO = 43;
  const YO = 136;

  const DEGRAD = Math.PI / 180.0;

  const re = RE / GRID;
  const slat1 = SLAT1 * DEGRAD;
  const slat2 = SLAT2 * DEGRAD;
  const olon = OLON * DEGRAD;
  const olat = OLAT * DEGRAD;

  let sn =
    Math.tan(Math.PI * 0.25 + slat2 * 0.5) /
    Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sn = Math.log(
    Math.cos(slat1) / Math.cos(slat2)
  ) / Math.log(sn);

  let sf = Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sf = (Math.pow(sf, sn) * Math.cos(slat1)) / sn;

  let ro = Math.tan(Math.PI * 0.25 + olat * 0.5);
  ro = (re * sf) / Math.pow(ro, sn);

  let ra =
    Math.tan(Math.PI * 0.25 + lat * DEGRAD * 0.5);
  ra = (re * sf) / Math.pow(ra, sn);

  let theta = lng * DEGRAD - olon;
  if (theta > Math.PI) theta -= 2.0 * Math.PI;
  if (theta < -Math.PI) theta += 2.0 * Math.PI;
  theta *= sn;

  const nx = Math.floor(
    ra * Math.sin(theta) + XO + 0.5
  );
  const ny = Math.floor(
    ro - ra * Math.cos(theta) + YO + 0.5
  );

  return {nx, ny};
}

/**
 * 기상청 API 발표 시각 계산
 * 단기예보: 0200,0500,0800,1100,1400,1700,2000,2300
 * @param {Date} targetDate - 대상 날짜
 * @return {object} baseDate, baseTime
 */
function getBaseDateTime(
  targetDate: Date
): { baseDate: string; baseTime: string } {
  const baseTimes = [
    "0200", "0500", "0800", "1100",
    "1400", "1700", "2000", "2300",
  ];
  const kstOffset = 9 * 60; // KST = UTC + 9

  // UTC → KST
  const kstDate = new Date(
    targetDate.getTime() + kstOffset * 60 * 1000
  );
  const currentHour = kstDate.getUTCHours();
  const currentMinute = kstDate.getUTCMinutes();
  const h = String(currentHour).padStart(2, "0");
  const m = String(currentMinute).padStart(2, "0");
  const currentTimeStr = h + m;

  // API 발표 후 약 10분 뒤부터 데이터 사용 가능
  let selectedBaseTime = baseTimes[baseTimes.length - 1];
  let usePreviousDay = true;

  for (const bt of baseTimes) {
    const btHour = bt.substring(0, 2);
    const btWithDelay = btHour + "10";
    if (currentTimeStr >= btWithDelay) {
      selectedBaseTime = bt;
      usePreviousDay = false;
    }
  }

  const baseDate = new Date(kstDate);
  if (usePreviousDay) {
    baseDate.setUTCDate(baseDate.getUTCDate() - 1);
  }

  const year = baseDate.getUTCFullYear();
  const month = String(
    baseDate.getUTCMonth() + 1
  ).padStart(2, "0");
  const day = String(
    baseDate.getUTCDate()
  ).padStart(2, "0");

  return {
    baseDate: `${year}${month}${day}`,
    baseTime: selectedBaseTime,
  };
}

/**
 * 체감온도 계산 (Wind Chill / Heat Index)
 * @param {number} temp - 기온
 * @param {number} windSpeed - 풍속 (m/s)
 * @param {number} humidity - 습도 (%)
 * @return {number} 체감온도
 */
function calculateFeelsLike(
  temp: number,
  windSpeed: number,
  humidity: number
): number {
  if (temp <= 10 && windSpeed >= 1.3) {
    // Wind Chill (추울 때)
    const windKmh = windSpeed * 3.6;
    const wc = Math.pow(windKmh, 0.16);
    return 13.12 + 0.6215 * temp -
      11.37 * wc + 0.3965 * temp * wc;
  } else if (temp >= 27) {
    // Heat Index 간소화 (더울 때)
    const e = humidity / 100 * 6.105 *
      Math.exp(17.27 * temp / (237.7 + temp));
    return temp + 0.33 * e - 4.0;
  }
  return temp;
}

/**
 * 기상청 API 카테고리별 값 파싱
 */
interface ForecastSlot {
  fcstDate: string;
  fcstTime: string;
  TMP?: number;
  SKY?: number;
  PTY?: number;
  POP?: number;
  REH?: number;
  WSD?: number;
  PCP?: string;
}

/**
 * SKY + PTY → WeatherCondition 매핑
 * @param {number} sky - 하늘상태 코드
 * @param {number} pty - 강수형태 코드
 * @return {string} WeatherCondition 문자열
 */
function mapToCondition(
  sky: number, pty: number
): string {
  if (pty > 0) {
    switch (pty) {
    case 1: return "rain";
    case 2: return "rainSnow";
    case 3: return "snow";
    case 4: return "shower";
    default: return "rain";
    }
  }
  switch (sky) {
  case 1: return "clear";
  case 3: return "cloudy";
  case 4: return "overcast";
  default: return "cloudy";
  }
}

// MARK: - Mid-Term Forecast (중기예보)

interface MidTermRegion {
  name: string;
  tempRegId: string; // getMidTa
  landRegId: string; // getMidLandFcst
  lat: number;
  lng: number;
}

/* eslint-disable max-len */
const MID_TERM_REGIONS: MidTermRegion[] = [
  // 서울/인천/경기
  {name: "서울", tempRegId: "11B10101", landRegId: "11B00000", lat: 37.567, lng: 126.978},
  {name: "인천", tempRegId: "11B20201", landRegId: "11B00000", lat: 37.456, lng: 126.705},
  {name: "수원", tempRegId: "11B20601", landRegId: "11B00000", lat: 37.264, lng: 127.029},
  {name: "파주", tempRegId: "11B20305", landRegId: "11B00000", lat: 37.760, lng: 126.770},
  // 강원영서
  {name: "춘천", tempRegId: "11D10301", landRegId: "11D10000", lat: 37.881, lng: 127.730},
  {name: "원주", tempRegId: "11D10401", landRegId: "11D10000", lat: 37.342, lng: 127.920},
  // 강원영동
  {name: "강릉", tempRegId: "11D20501", landRegId: "11D20000", lat: 37.752, lng: 128.876},
  // 충북
  {name: "청주", tempRegId: "11C10301", landRegId: "11C10000", lat: 36.642, lng: 127.489},
  // 대전/세종/충남
  {name: "대전", tempRegId: "11C20401", landRegId: "11C20000", lat: 36.350, lng: 127.385},
  {name: "세종", tempRegId: "11C20404", landRegId: "11C20000", lat: 36.480, lng: 127.260},
  // 전북
  {name: "전주", tempRegId: "11F10201", landRegId: "11F10000", lat: 35.824, lng: 127.148},
  // 광주/전남
  {name: "광주", tempRegId: "11F20501", landRegId: "11F20000", lat: 35.160, lng: 126.853},
  {name: "여수", tempRegId: "11F20401", landRegId: "11F20000", lat: 34.760, lng: 127.662},
  {name: "목포", tempRegId: "21F20801", landRegId: "11F20000", lat: 34.812, lng: 126.392},
  // 대구/경북
  {name: "대구", tempRegId: "11H10701", landRegId: "11H10000", lat: 35.871, lng: 128.601},
  {name: "안동", tempRegId: "11H10501", landRegId: "11H10000", lat: 36.568, lng: 128.729},
  // 부산/울산/경남
  {name: "부산", tempRegId: "11H20201", landRegId: "11H20000", lat: 35.180, lng: 129.076},
  {name: "울산", tempRegId: "11H20101", landRegId: "11H20000", lat: 35.538, lng: 129.311},
  {name: "창원", tempRegId: "11H20301", landRegId: "11H20000", lat: 35.228, lng: 128.681},
  // 제주
  {name: "제주", tempRegId: "11G00201", landRegId: "11G00000", lat: 33.510, lng: 126.522},
  {name: "서귀포", tempRegId: "11G00401", landRegId: "11G00000", lat: 33.253, lng: 126.560},
];
/* eslint-enable max-len */

/**
 * 유클리드 거리 기반 최근접 도시 반환
 * @param {number} lat - 위도
 * @param {number} lng - 경도
 * @return {MidTermRegion} 최근접 도시
 */
function findNearestRegion(
  lat: number, lng: number
): MidTermRegion {
  let nearest = MID_TERM_REGIONS[0];
  let minDist = Infinity;
  for (const region of MID_TERM_REGIONS) {
    const d = Math.pow(lat - region.lat, 2) +
      Math.pow(lng - region.lng, 2);
    if (d < minDist) {
      minDist = d;
      nearest = region;
    }
  }
  return nearest;
}

/**
 * 중기예보 발표 시각 계산 (06시/18시 KST)
 * @param {Date} now - 현재 시각
 * @return {string} tmFc (yyyyMMddHHmm 형식)
 */
function getMidTermBaseTime(now: Date): string {
  const kstOffset = 9 * 60;
  const kst = new Date(
    now.getTime() + kstOffset * 60 * 1000
  );
  const h = kst.getUTCHours();

  const baseDate = new Date(kst);
  let baseHour: string;

  if (h >= 18) {
    baseHour = "1800";
  } else if (h >= 6) {
    baseHour = "0600";
  } else {
    // 06시 이전 → 전날 18시 기준
    baseDate.setUTCDate(baseDate.getUTCDate() - 1);
    baseHour = "1800";
  }

  const y = baseDate.getUTCFullYear();
  const m = String(baseDate.getUTCMonth() + 1)
    .padStart(2, "0");
  const d = String(baseDate.getUTCDate())
    .padStart(2, "0");

  return `${y}${m}${d}${baseHour}`;
}

/**
 * 기상청 중기기온예보 API 응답
 */
interface KMAMidTaResponse {
  response: {
    header: { resultCode: string; resultMsg: string };
    body?: {
      items?: {
        item?: Array<{
          regId: string;
          taMin3: number; taMax3: number;
          taMin4: number; taMax4: number;
          taMin5: number; taMax5: number;
          taMin6: number; taMax6: number;
          taMin7: number; taMax7: number;
          taMin8: number; taMax8: number;
          taMin9: number; taMax9: number;
          taMin10: number; taMax10: number;
        }>;
      };
    };
  };
}

/**
 * 기상청 중기육상예보 API 응답
 */
interface KMAMidLandResponse {
  response: {
    header: { resultCode: string; resultMsg: string };
    body?: {
      items?: {
        item?: Array<{
          regId: string;
          wf3Am: string; wf3Pm: string;
          wf4Am: string; wf4Pm: string;
          wf5Am: string; wf5Pm: string;
          wf6Am: string; wf6Pm: string;
          wf7Am: string; wf7Pm: string;
          wf8: string;
          wf9: string;
          wf10: string;
          rnSt3Am: number; rnSt3Pm: number;
          rnSt4Am: number; rnSt4Pm: number;
          rnSt5Am: number; rnSt5Pm: number;
          rnSt6Am: number; rnSt6Pm: number;
          rnSt7Am: number; rnSt7Pm: number;
          rnSt8: number;
          rnSt9: number;
          rnSt10: number;
        }>;
      };
    };
  };
}

/**
 * wf 문자열 → WeatherCondition 매핑
 * @param {string} wf - 날씨 예보 문자열 (예: "맑음", "구름많고 비")
 * @return {string} WeatherCondition
 */
function mapWfToCondition(wf: string): string {
  if (!wf) return "unknown";
  if (wf.includes("비/눈") || wf.includes("눈/비")) {
    return "rainSnow";
  }
  if (wf.includes("눈")) return "snow";
  if (wf.includes("소나기")) return "shower";
  if (wf.includes("비")) return "rain";
  if (wf.includes("흐림")) return "overcast";
  if (wf.includes("구름많")) return "cloudy";
  if (wf.includes("맑")) return "clear";
  return "cloudy";
}

/**
 * HTTPS GET 요청 유틸리티
 * @param {string} path - 요청 경로
 * @return {Promise<T>} JSON 파싱된 응답
 */
function kmaGet<T>(path: string): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const req = https.get(
      {
        hostname: "apis.data.go.kr",
        path: path,
        headers: {"Accept": "application/json"},
      },
      (res) => {
        let body = "";
        res.on("data", (c) => {
          body += c;
        });
        res.on("end", () => {
          if (res.statusCode !== 200) {
            reject(new Error(
              "KMA " + res.statusCode
            ));
            return;
          }
          try {
            resolve(JSON.parse(body));
          } catch (e) {
            reject(e);
          }
        });
      }
    );
    req.on("error", reject);
    req.end();
  });
}

/**
 * 중기기온예보 호출
 * @param {string} regId - 기온 예보 지역코드
 * @param {string} tmFc - 발표 시각 (yyyyMMddHHmm)
 * @param {string} apiKey - 기상청 API 키
 * @return {object} 일별 최저/최고 기온 (3~10일)
 */
async function fetchMidTemp(
  regId: string, tmFc: string, apiKey: string
): Promise<Record<number, { min: number; max: number }>> {
  const encodedKey = encodeURIComponent(apiKey);
  const path =
    "/1360000/MidFcstInfoService/getMidTa" +
    "?serviceKey=" + encodedKey +
    "&numOfRows=10&pageNo=1" +
    "&dataType=JSON" +
    "&regId=" + regId +
    "&tmFc=" + tmFc;

  const data = await kmaGet<KMAMidTaResponse>(path);
  if (data.response.header.resultCode !== "00") {
    console.error(
      "MidTa error:", data.response.header.resultMsg
    );
    return {};
  }

  const item = data.response.body?.items?.item?.[0];
  if (!item) return {};

  const result: Record<number, {min: number; max: number}> = {};
  for (let d = 3; d <= 10; d++) {
    const minKey = `taMin${d}` as keyof typeof item;
    const maxKey = `taMax${d}` as keyof typeof item;
    const minVal = item[minKey];
    const maxVal = item[maxKey];
    if (minVal == null || maxVal == null) continue;
    result[d] = {
      min: minVal as number,
      max: maxVal as number,
    };
  }
  return result;
}

/**
 * 중기육상예보 호출
 * @param {string} regId - 육상 예보 지역코드
 * @param {string} tmFc - 발표 시각 (yyyyMMddHHmm)
 * @param {string} apiKey - 기상청 API 키
 * @return {object} 일별 날씨/강수확률 (3~10일)
 */
async function fetchMidLand(
  regId: string, tmFc: string, apiKey: string
): Promise<Record<number, {
  wfAm: string; wfPm: string;
  rnStAm: number; rnStPm: number;
}>> {
  const encodedKey = encodeURIComponent(apiKey);
  const path =
    "/1360000/MidFcstInfoService/getMidLandFcst" +
    "?serviceKey=" + encodedKey +
    "&numOfRows=10&pageNo=1" +
    "&dataType=JSON" +
    "&regId=" + regId +
    "&tmFc=" + tmFc;

  const data = await kmaGet<KMAMidLandResponse>(path);
  if (data.response.header.resultCode !== "00") {
    console.error(
      "MidLand error:", data.response.header.resultMsg
    );
    return {};
  }

  const item = data.response.body?.items?.item?.[0];
  if (!item) return {};

  const result: Record<number, {
    wfAm: string; wfPm: string;
    rnStAm: number; rnStPm: number;
  }> = {};

  // Day 3~7: 오전/오후 분리
  for (let d = 3; d <= 7; d++) {
    const wfAmKey = `wf${d}Am` as keyof typeof item;
    const wfPmKey = `wf${d}Pm` as keyof typeof item;
    const rnAmKey = `rnSt${d}Am` as keyof typeof item;
    const rnPmKey = `rnSt${d}Pm` as keyof typeof item;
    result[d] = {
      wfAm: item[wfAmKey] as string,
      wfPm: item[wfPmKey] as string,
      rnStAm: item[rnAmKey] as number,
      rnStPm: item[rnPmKey] as number,
    };
  }

  // Day 8~10: 오전/오후 통합
  for (let d = 8; d <= 10; d++) {
    const wfKey = `wf${d}` as keyof typeof item;
    const rnKey = `rnSt${d}` as keyof typeof item;
    const wf = item[wfKey] as string;
    const rn = item[rnKey] as number;
    result[d] = {
      wfAm: wf, wfPm: wf,
      rnStAm: rn, rnStPm: rn,
    };
  }

  return result;
}

/**
 * 중기예보 병합 → DailyForecastItem 배열 생성
 * @param {Date} baseKstDate - 발표일 기준 KST 날짜
 * @param {Record} temps - 기온 데이터
 * @param {Record} lands - 날씨/강수확률 데이터
 * @return {DailyForecastItem[]} 일별 예보 배열
 */
function mergeMidForecasts(
  baseKstDate: Date,
  temps: Record<number, { min: number; max: number }>,
  lands: Record<number, {
    wfAm: string; wfPm: string;
    rnStAm: number; rnStPm: number;
  }>
): DailyForecastItem[] {
  const results: DailyForecastItem[] = [];

  for (let d = 3; d <= 10; d++) {
    const temp = temps[d];
    const land = lands[d];
    if (!temp || !land) continue;

    const forecastDate = new Date(baseKstDate);
    forecastDate.setUTCDate(
      forecastDate.getUTCDate() + d
    );
    const y = forecastDate.getUTCFullYear();
    const m = String(forecastDate.getUTCMonth() + 1)
      .padStart(2, "0");
    const dy = String(forecastDate.getUTCDate())
      .padStart(2, "0");

    results.push({
      date: `${y}-${m}-${dy}`,
      minTemperature: temp.min,
      maxTemperature: temp.max,
      amCondition: mapWfToCondition(land.wfAm),
      pmCondition: mapWfToCondition(land.wfPm),
      amPrecipitationProbability: land.rnStAm,
      pmPrecipitationProbability: land.rnStPm,
    });
  }

  return results;
}

/**
 * 날씨 조회 (기상청 단기예보 + 중기예보 API 프록시)
 *
 * @why 기상청 API 키를 클라이언트에 노출하지 않기 위함
 * @ios HomeFeature, PromiseDetailFeature에서 호출
 * @added 2026-02-17
 */
export const getWeather = onCall<GetWeatherRequest>(
  {
    region: REGION,
    secrets: [KMA_API_KEY],
  },
  async (request): Promise<GetWeatherResponse> => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요합니다"
      );
    }

    const {latitude, longitude, targetDate} =
      request.data;

    if (!latitude || !longitude || !targetDate) {
      throw new HttpsError(
        "invalid-argument",
        "latitude, longitude, targetDate가 필요합니다"
      );
    }

    // 1. 시간 범위 검증 (과거 / 10일 초과)
    const now = Date.now();
    const targetMs = new Date(targetDate).getTime();
    const MAX_FORECAST_MS = 10 * 24 * 60 * 60 * 1000;
    const SHORT_TERM_MS = 5 * 24 * 60 * 60 * 1000;

    if (targetMs < now) {
      return {forecasts: []};
    }
    if (targetMs > now + MAX_FORECAST_MS) {
      return {forecasts: []};
    }

    const diffMs = targetMs - now;
    const needMidTerm = diffMs > SHORT_TERM_MS;

    // 2. 캐시 확인
    const cacheKey = buildCacheKey(
      latitude, longitude, targetDate
    );
    const cached = readCache(cacheKey, now);
    if (cached) {
      console.log(`Weather: cache hit ${cacheKey}`);
      return cached;
    }

    // 3. API 키 확인
    const apiKey = KMA_API_KEY.value().trim();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "KMA_API_KEY가 설정되지 않았습니다"
      );
    }

    // 4. 좌표 → 기상청 격자 변환
    const {nx, ny} = convertToGrid(
      latitude, longitude
    );

    // 5. 발표 시각 계산 (현재 시각 기준 최신 발표)
    const {baseDate, baseTime} =
      getBaseDateTime(new Date(now));

    console.log(
      `Weather: (${latitude},${longitude})` +
      ` nx=${nx},ny=${ny}` +
      ` base=${baseDate}/${baseTime}`
    );

    try {
      // 4. 기상청 단기예보 API 호출
      // Node.js fetch가 URL을 재인코딩하는 문제 회피
      // → https 모듈 직접 사용
      const encodedKey =
        encodeURIComponent(apiKey);
      const path =
        "/1360000" +
        "/VilageFcstInfoService_2.0" +
        "/getVilageFcst" +
        "?serviceKey=" + encodedKey +
        "&numOfRows=1000" +
        "&pageNo=1" +
        "&dataType=JSON" +
        "&base_date=" + baseDate +
        "&base_time=" + baseTime +
        "&nx=" + nx +
        "&ny=" + ny;

      console.log(
        "KMA request: base=" + baseDate +
        "/" + baseTime +
        " nx=" + nx + " ny=" + ny +
        " keyLen=" + apiKey.length
      );

      const data = await new Promise<
        KMAForecastResponse
      >((resolve, reject) => {
        const req = https.get(
          {
            hostname: "apis.data.go.kr",
            path: path,
            headers: {
              "Accept": "application/json",
            },
          },
          (res) => {
            let body = "";
            res.on("data", (c) => {
              body += c;
            });
            res.on("end", () => {
              if (res.statusCode !== 200) {
                console.error(
                  "KMA API error:",
                  res.statusCode,
                  body.substring(0, 500)
                );
                reject(new Error(
                  "KMA " + res.statusCode
                ));
                return;
              }
              try {
                resolve(JSON.parse(body));
              } catch (e) {
                reject(e);
              }
            });
          }
        );
        req.on("error", reject);
        req.end();
      });

      const resultCode =
        data.response.header.resultCode;
      if (resultCode !== "00") {
        const msg =
          data.response.header.resultMsg;
        console.error(
          `KMA API result error: ${msg}`
        );
        return {forecasts: []};
      }

      const items =
        data.response.body?.items?.item ?? [];

      // 5. 시간대별 그룹핑
      const slots: Record<string, ForecastSlot> =
        {};
      for (const item of items) {
        const key =
          `${item.fcstDate}_${item.fcstTime}`;
        if (!slots[key]) {
          slots[key] = {
            fcstDate: item.fcstDate,
            fcstTime: item.fcstTime,
          };
        }
        const value = parseFloat(item.fcstValue);
        switch (item.category) {
        case "TMP":
          slots[key].TMP = value; break;
        case "SKY":
          slots[key].SKY = value; break;
        case "PTY":
          slots[key].PTY = value; break;
        case "POP":
          slots[key].POP = value; break;
        case "REH":
          slots[key].REH = value; break;
        case "WSD":
          slots[key].WSD = value; break;
        case "PCP":
          slots[key].PCP = item.fcstValue; break;
        }
      }

      // 6. 변환
      const forecasts = Object.values(slots)
        .filter((slot) => slot.TMP !== undefined)
        .map((slot) => {
          const yr = parseInt(
            slot.fcstDate.substring(0, 4)
          );
          const mo = parseInt(
            slot.fcstDate.substring(4, 6)
          ) - 1;
          const dy = parseInt(
            slot.fcstDate.substring(6, 8)
          );
          const hr = parseInt(
            slot.fcstTime.substring(0, 2)
          );
          // KST → UTC
          const dateTime = new Date(
            Date.UTC(yr, mo, dy, hr - 9, 0, 0)
          );

          const tmp = slot.TMP ?? 0;
          const ws = slot.WSD ?? 0;
          const hum = slot.REH ?? 50;
          const fl = calculateFeelsLike(
            tmp, ws, hum
          );
          const cond = mapToCondition(
            slot.SKY ?? 1, slot.PTY ?? 0
          );
          const pcp = slot.PCP === "강수없음" ?
            "" : (slot.PCP ?? "");

          return {
            dateTime: dateTime.toISOString(),
            temperature:
              Math.round(tmp * 10) / 10,
            feelsLikeTemperature:
              Math.round(fl * 10) / 10,
            condition: cond,
            precipitationProbability:
              slot.POP ?? 0,
            humidity: hum,
            windSpeed:
              Math.round(ws * 10) / 10,
            precipitationAmount: pcp,
          };
        })
        .sort((a, b) =>
          new Date(a.dateTime).getTime() -
          new Date(b.dateTime).getTime()
        );

      console.log(
        `Weather: ${forecasts.length} slots`
      );

      // 7. 중기예보 (3일 초과 시)
      let dailyForecasts: DailyForecastItem[] | undefined;
      if (needMidTerm) {
        try {
          const region = findNearestRegion(
            latitude, longitude
          );
          const tmFc = getMidTermBaseTime(new Date(now));
          console.log(
            `MidTerm: region=${region.name}` +
            ` temp=${region.tempRegId}` +
            ` land=${region.landRegId}` +
            ` tmFc=${tmFc}`
          );

          // 캐시 확인
          const midCacheKey =
            `mid_${region.tempRegId}_${tmFc}`;
          const midCached = readCache(midCacheKey, now);
          if (midCached && midCached.dailyForecasts) {
            dailyForecasts = midCached.dailyForecasts;
          } else {
            const [temps, lands] = await Promise.all([
              fetchMidTemp(
                region.tempRegId, tmFc, apiKey
              ),
              fetchMidLand(
                region.landRegId, tmFc, apiKey
              ),
            ]);

            // 발표일 기준 KST 날짜 계산
            const kstOffset = 9 * 60;
            const baseKst = new Date(
              now + kstOffset * 60 * 1000
            );
            // 발표 시각의 날짜 (00:00 UTC 기준)
            baseKst.setUTCHours(0, 0, 0, 0);

            dailyForecasts = mergeMidForecasts(
              baseKst, temps, lands
            );

            console.log(
              `MidTerm: ${dailyForecasts.length} days`
            );

            // 중기예보 캐시 저장
            if (dailyForecasts.length > 0) {
              writeCache(midCacheKey, {
                forecasts: [],
                dailyForecasts,
              }, now);
            }
          }
        } catch (midError) {
          console.error(
            "MidTerm API error:", midError
          );
          // 중기 실패해도 단기만 반환
        }
      }

      const hasDailyForecasts =
        dailyForecasts && dailyForecasts.length > 0;
      const result: GetWeatherResponse = {
        forecasts,
        ...(hasDailyForecasts ?
          {dailyForecasts} : {}),
      };
      writeCache(cacheKey, result, now);
      return result;
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("Weather API error:", error);
      return {forecasts: []};
    }
  }
);
