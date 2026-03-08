/**
 * Transportation Functions
 *
 * 교통 정보 조회 (ODsay 대중교통 + Kakao Mobility 자동차 + 도보 자체 계산)
 * 브리핑에서 이동 구간별 교통수단 소요시간 제공용
 *
 * @added 2026-03-08
 */

import {ODSAY_API_KEY, KAKAO_REST_API_KEY} from "../config";

// MARK: - Types

export interface TransitInfo {
  /** 총 소요시간 (분) */
  totalTime: number;
  /** 요금 (원) */
  payment: number;
  /** 버스 환승 횟수 */
  busTransitCount: number;
  /** 지하철 환승 횟수 */
  subwayTransitCount: number;
}

export interface DrivingInfo {
  /** 총 거리 (미터) */
  distance: number;
  /** 소요시간 (분) */
  duration: number;
  /** 통행료 (원) */
  toll: number;
}

export interface TransportationResult {
  transit: TransitInfo | null;
  driving: DrivingInfo | null;
  walkingMinutes: number;
}

// MARK: - ODsay (대중교통)

async function fetchTransitRoute(
  fromLat: number, fromLng: number,
  toLat: number, toLng: number,
): Promise<TransitInfo | null> {
  const apiKey = ODSAY_API_KEY.value();
  if (!apiKey) {
    console.warn("[Transportation] ODSAY_API_KEY not configured");
    return null;
  }

  try {
    const url = new URL("https://api.odsay.com/v1/api/searchPubTransPathT");
    url.searchParams.append("SX", fromLng.toString());
    url.searchParams.append("SY", fromLat.toString());
    url.searchParams.append("EX", toLng.toString());
    url.searchParams.append("EY", toLat.toString());
    url.searchParams.append("apiKey", apiKey);

    const response = await fetch(url.toString(), {
      method: "GET",
      signal: AbortSignal.timeout(5000),
    });

    if (!response.ok) {
      console.error(`[Transportation] ODsay API error: ${response.status}`);
      return null;
    }

    const data = await response.json() as any;
    const path = data?.result?.path?.[0];
    if (!path?.info) return null;

    const info = path.info;
    return {
      totalTime: info.totalTime ?? 0,
      payment: info.payment ?? 0,
      busTransitCount: info.busTransitCount ?? 0,
      subwayTransitCount: info.subwayTransitCount ?? 0,
    };
  } catch (error) {
    console.error("[Transportation] ODsay fetch error:", error);
    return null;
  }
}

// MARK: - Kakao Mobility (자동차)

async function fetchDrivingRoute(
  fromLat: number, fromLng: number,
  toLat: number, toLng: number,
): Promise<DrivingInfo | null> {
  const apiKey = KAKAO_REST_API_KEY.value();
  if (!apiKey) {
    console.warn("[Transportation] KAKAO_REST_API_KEY not configured");
    return null;
  }

  try {
    const url = new URL("https://apis-navi.kakaomobility.com/v1/directions");
    url.searchParams.append("origin", `${fromLng},${fromLat}`);
    url.searchParams.append("destination", `${toLng},${toLat}`);
    url.searchParams.append("summary", "true");

    const response = await fetch(url.toString(), {
      method: "GET",
      headers: {
        "Authorization": `KakaoAK ${apiKey}`,
      },
      signal: AbortSignal.timeout(5000),
    });

    if (!response.ok) {
      console.error(`[Transportation] Kakao Mobility API error: ${response.status}`);
      return null;
    }

    const data = await response.json() as any;
    const summary = data?.routes?.[0]?.summary;
    if (!summary) return null;

    return {
      distance: summary.distance ?? 0,
      duration: Math.round((summary.duration ?? 0) / 60), // 초 → 분
      toll: summary.fare?.toll ?? 0,
    };
  } catch (error) {
    console.error("[Transportation] Kakao Mobility fetch error:", error);
    return null;
  }
}

// MARK: - 도보 (자체 계산)

function estimateWalkMinutes(distanceKm: number): number {
  const actualDistance = distanceKm * 1.3; // 직선 → 실제 경로 보정
  return Math.round((actualDistance / 4) * 60); // 시속 4km 기준
}

// MARK: - Public API

/**
 * 두 좌표 간 교통 정보 조회 (대중교통 + 자동차 + 도보)
 * ODsay, Kakao 병렬 호출 + 도보 자체 계산
 *
 * @param {number} fromLat 출발 위도
 * @param {number} fromLng 출발 경도
 * @param {number} toLat 도착 위도
 * @param {number} toLng 도착 경도
 * @param {number} distanceKm Haversine 직선거리 (도보 계산용)
 * @return {Promise<TransportationResult>} 교통 정보
 */
export async function fetchTransportation(
  fromLat: number, fromLng: number,
  toLat: number, toLng: number,
  distanceKm: number,
): Promise<TransportationResult> {
  const walkingMinutes = estimateWalkMinutes(distanceKm);

  // 1km 미만 단거리는 외부 API 호출 생략
  if (distanceKm < 1.0) {
    return {transit: null, driving: null, walkingMinutes};
  }

  // 대중교통 + 자동차 병렬 호출
  const [transit, driving] = await Promise.all([
    fetchTransitRoute(fromLat, fromLng, toLat, toLng),
    fetchDrivingRoute(fromLat, fromLng, toLat, toLng),
  ]);

  return {
    transit,
    driving,
    walkingMinutes,
  };
}
