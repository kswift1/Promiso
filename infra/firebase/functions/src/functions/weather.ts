/**
 * Weather Functions
 *
 * 기상청 공공데이터 API 프록시 (단기예보)
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

/**
 * 날씨 조회 (기상청 단기예보 API 프록시)
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

    // 1. 시간 범위 검증 (과거 / 72시간 초과)
    const now = Date.now();
    const targetMs = new Date(targetDate).getTime();
    const MAX_FORECAST_MS = 72 * 60 * 60 * 1000;

    if (targetMs < now) {
      return {forecasts: []};
    }
    if (targetMs > now + MAX_FORECAST_MS) {
      return {forecasts: []};
    }

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

    // 5. 발표 시각 계산
    const target = new Date(targetDate);
    const {baseDate, baseTime} =
      getBaseDateTime(target);

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
        "&numOfRows=300" +
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

      const result = {forecasts};
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
