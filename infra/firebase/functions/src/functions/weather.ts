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

// 기상청 API 키 (Secret Manager에서 관리)
const KMA_API_KEY = defineSecret("KMA_API_KEY");

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
 * 위경도 → 기상청 격자 변환 (Lambert Conformal Conic Projection)
 */
function convertToGrid(lat: number, lng: number): GridCoord {
  const RE = 6371.00877; // 지구 반경 (km)
  const GRID = 5.0; // 격자 간격 (km)
  const SLAT1 = 30.0; // 투영 위도1 (degree)
  const SLAT2 = 60.0; // 투영 위도2 (degree)
  const OLON = 126.0; // 기준점 경도 (degree)
  const OLAT = 38.0; // 기준점 위도 (degree)
  const XO = 43; // 기준점 X좌표 (GRID)
  const YO = 136; // 기준점 Y좌표 (GRID)

  const DEGRAD = Math.PI / 180.0;

  const re = RE / GRID;
  const slat1 = SLAT1 * DEGRAD;
  const slat2 = SLAT2 * DEGRAD;
  const olon = OLON * DEGRAD;
  const olat = OLAT * DEGRAD;

  let sn = Math.tan(Math.PI * 0.25 + slat2 * 0.5) /
    Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sn = Math.log(Math.cos(slat1) / Math.cos(slat2)) / Math.log(sn);

  let sf = Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sf = (Math.pow(sf, sn) * Math.cos(slat1)) / sn;

  let ro = Math.tan(Math.PI * 0.25 + olat * 0.5);
  ro = (re * sf) / Math.pow(ro, sn);

  let ra = Math.tan(Math.PI * 0.25 + lat * DEGRAD * 0.5);
  ra = (re * sf) / Math.pow(ra, sn);

  let theta = lng * DEGRAD - olon;
  if (theta > Math.PI) theta -= 2.0 * Math.PI;
  if (theta < -Math.PI) theta += 2.0 * Math.PI;
  theta *= sn;

  const nx = Math.floor(ra * Math.sin(theta) + XO + 0.5);
  const ny = Math.floor(ro - ra * Math.cos(theta) + YO + 0.5);

  return {nx, ny};
}

/**
 * 기상청 API 발표 시각 계산
 * 단기예보: 0200, 0500, 0800, 1100, 1400, 1700, 2000, 2300
 */
function getBaseDateTime(targetDate: Date): { baseDate: string; baseTime: string } {
  const baseTimes = ["0200", "0500", "0800", "1100", "1400", "1700", "2000", "2300"];
  const kstOffset = 9 * 60; // KST = UTC + 9

  // UTC → KST
  const kstDate = new Date(targetDate.getTime() + kstOffset * 60 * 1000);
  const currentHour = kstDate.getUTCHours();
  const currentMinute = kstDate.getUTCMinutes();
  const currentTimeStr = String(currentHour).padStart(2, "0") +
    String(currentMinute).padStart(2, "0");

  // API 발표 후 약 10분 뒤부터 데이터 사용 가능
  let selectedBaseTime = baseTimes[baseTimes.length - 1]; // 기본: 전날 2300
  let usePreviousDay = true;

  for (const bt of baseTimes) {
    const btWithDelay = String(parseInt(bt.substring(0, 2))).padStart(2, "0") + "10";
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
  const month = String(baseDate.getUTCMonth() + 1).padStart(2, "0");
  const day = String(baseDate.getUTCDate()).padStart(2, "0");

  return {
    baseDate: `${year}${month}${day}`,
    baseTime: selectedBaseTime,
  };
}

/**
 * 체감온도 계산 (Wind Chill / Heat Index)
 */
function calculateFeelsLike(temp: number, windSpeed: number, humidity: number): number {
  if (temp <= 10 && windSpeed >= 1.3) {
    // Wind Chill (추울 때)
    const windKmh = windSpeed * 3.6;
    return 13.12 + 0.6215 * temp - 11.37 * Math.pow(windKmh, 0.16) +
      0.3965 * temp * Math.pow(windKmh, 0.16);
  } else if (temp >= 27) {
    // Heat Index 간소화 (더울 때)
    return temp + 0.33 * (humidity / 100 * 6.105 * Math.exp(17.27 * temp / (237.7 + temp))) - 4.0;
  }
  return temp;
}

/**
 * Mock 날씨 데이터 생성 (API 키 미설정 시)
 */
function generateMockWeather(
  latitude: number,
  longitude: number,
  targetDateStr: string
): GetWeatherResponse {
  const targetDate = new Date(targetDateStr);
  const seed = Math.floor(latitude * 100 + longitude * 100 + targetDate.getDate());

  const conditions = ["clear", "cloudy", "overcast", "rain", "clear", "cloudy", "clear", "shower"];

  const forecasts = [];
  for (let i = 0; i < 12; i++) {
    const forecastDate = new Date(targetDate.getTime() + i * 3600 * 1000);
    const hour = forecastDate.getHours();

    // 결정론적 데이터 (좌표+날짜 기반)
    const conditionIndex = (seed + i) % conditions.length;
    const baseTemp = 15 + Math.sin((hour - 6) * Math.PI / 12) * 8;
    const temp = Math.round((baseTemp + (seed % 5) - 2) * 10) / 10;
    const humidity = 50 + ((seed + i * 7) % 30);
    const windSpeed = Math.round((2 + ((seed + i * 3) % 8)) * 10) / 10;
    const feelsLike = Math.round(calculateFeelsLike(temp, windSpeed, humidity) * 10) / 10;
    const condition = conditions[conditionIndex];
    const precipProb = condition === "rain" || condition === "shower" ?
      50 + ((seed + i) % 40) : (seed + i) % 30;

    forecasts.push({
      dateTime: forecastDate.toISOString(),
      temperature: temp,
      feelsLikeTemperature: feelsLike,
      condition: condition,
      precipitationProbability: precipProb,
      humidity: humidity,
      windSpeed: windSpeed,
      precipitationAmount: condition === "rain" ? "1mm" : "",
    });
  }

  return {forecasts};
}

/**
 * 기상청 API 카테고리별 값 파싱
 */
interface ForecastSlot {
  fcstDate: string;
  fcstTime: string;
  TMP?: number; // 기온
  SKY?: number; // 하늘상태 (1: 맑음, 3: 구름많음, 4: 흐림)
  PTY?: number; // 강수형태 (0: 없음, 1: 비, 2: 비/눈, 3: 눈, 4: 소나기)
  POP?: number; // 강수확률
  REH?: number; // 습도
  WSD?: number; // 풍속
  PCP?: string; // 1시간 강수량
}

/**
 * SKY + PTY → WeatherCondition 매핑
 */
function mapToCondition(sky: number, pty: number): string {
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
 * @why 기상청 API 키를 클라이언트에 노출하지 않기 위해 서버에서 프록시
 * @ios HomeFeature, PromiseDetailFeature의 날씨 표시에서 호출
 * @added 2026-02-17
 *
 * @remarks
 * **Mock 모드**
 * - KMA_API_KEY가 설정되지 않으면 결정론적 Mock 데이터 반환
 * - 개발/테스트 환경에서 API 키 없이도 동작
 *
 * @param request.data.latitude - 위도
 * @param request.data.longitude - 경도
 * @param request.data.targetDate - 대상 날짜 (ISO 8601)
 * @returns {forecasts: ForecastItem[]} - 시간대별 예보 목록
 */
export const getWeather = onCall<GetWeatherRequest>(
  {
    region: REGION,
    secrets: [KMA_API_KEY],
    invoker: "public",
  },
  async (request): Promise<GetWeatherResponse> => {
    const {latitude, longitude, targetDate} = request.data;

    if (!latitude || !longitude || !targetDate) {
      throw new HttpsError("invalid-argument", "latitude, longitude, targetDate가 필요합니다");
    }

    // 1. API 키 확인 → 없으면 Mock 데이터 반환
    const apiKey = KMA_API_KEY.value();
    if (!apiKey) {
      console.log("🌤️ KMA_API_KEY not set, returning mock weather data");
      return generateMockWeather(latitude, longitude, targetDate);
    }

    // 2. 좌표 → 기상청 격자 변환
    const {nx, ny} = convertToGrid(latitude, longitude);

    // 3. 발표 시각 계산
    const target = new Date(targetDate);
    const {baseDate, baseTime} = getBaseDateTime(target);

    console.log(`🌤️ Weather: lat=${latitude}, lng=${longitude} → nx=${nx}, ny=${ny}, ` +
      `base=${baseDate}/${baseTime}`);

    try {
      // 4. 기상청 단기예보 API 호출
      const url = new URL("http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst");
      url.searchParams.append("serviceKey", apiKey);
      url.searchParams.append("numOfRows", "300");
      url.searchParams.append("pageNo", "1");
      url.searchParams.append("dataType", "JSON");
      url.searchParams.append("base_date", baseDate);
      url.searchParams.append("base_time", baseTime);
      url.searchParams.append("nx", nx.toString());
      url.searchParams.append("ny", ny.toString());

      const response = await fetch(url.toString());

      if (!response.ok) {
        console.error(`KMA API error: ${response.status}`);
        // API 실패 시 Mock fallback
        return generateMockWeather(latitude, longitude, targetDate);
      }

      const data: KMAForecastResponse = await response.json() as KMAForecastResponse;

      if (data.response.header.resultCode !== "00") {
        console.error(`KMA API result error: ${data.response.header.resultMsg}`);
        return generateMockWeather(latitude, longitude, targetDate);
      }

      const items = data.response.body?.items?.item ?? [];

      // 5. 시간대별 그룹핑
      const slots: Record<string, ForecastSlot> = {};
      for (const item of items) {
        const key = `${item.fcstDate}_${item.fcstTime}`;
        if (!slots[key]) {
          slots[key] = {fcstDate: item.fcstDate, fcstTime: item.fcstTime};
        }
        const value = parseFloat(item.fcstValue);
        switch (item.category) {
        case "TMP": slots[key].TMP = value; break;
        case "SKY": slots[key].SKY = value; break;
        case "PTY": slots[key].PTY = value; break;
        case "POP": slots[key].POP = value; break;
        case "REH": slots[key].REH = value; break;
        case "WSD": slots[key].WSD = value; break;
        case "PCP": slots[key].PCP = item.fcstValue; break;
        }
      }

      // 6. 변환
      const forecasts = Object.values(slots)
        .filter((slot) => slot.TMP !== undefined)
        .map((slot) => {
          const year = parseInt(slot.fcstDate.substring(0, 4));
          const month = parseInt(slot.fcstDate.substring(4, 6)) - 1;
          const day = parseInt(slot.fcstDate.substring(6, 8));
          const hour = parseInt(slot.fcstTime.substring(0, 2));
          // KST → UTC
          const dateTime = new Date(Date.UTC(year, month, day, hour - 9, 0, 0));

          const temp = slot.TMP ?? 0;
          const windSpeed = slot.WSD ?? 0;
          const humidity = slot.REH ?? 50;
          const feelsLike = calculateFeelsLike(temp, windSpeed, humidity);
          const condition = mapToCondition(slot.SKY ?? 1, slot.PTY ?? 0);
          const precipAmount = slot.PCP === "강수없음" ? "" : (slot.PCP ?? "");

          return {
            dateTime: dateTime.toISOString(),
            temperature: Math.round(temp * 10) / 10,
            feelsLikeTemperature: Math.round(feelsLike * 10) / 10,
            condition,
            precipitationProbability: slot.POP ?? 0,
            humidity,
            windSpeed: Math.round(windSpeed * 10) / 10,
            precipitationAmount: precipAmount,
          };
        })
        .sort((a, b) => new Date(a.dateTime).getTime() - new Date(b.dateTime).getTime());

      console.log(`✅ Weather: ${forecasts.length} forecast slots`);

      return {forecasts};
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("Weather API error:", error);
      // 에러 시 Mock fallback
      return generateMockWeather(latitude, longitude, targetDate);
    }
  }
);
