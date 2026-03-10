/**
 * Transportation Functions
 *
 * 교통 정보 조회 (ODsay 대중교통 + Kakao Mobility 자동차 + 도보 자체 계산)
 * 브리핑에서 이동 구간별 교통수단 소요시간 제공용
 *
 * @added 2026-03-08
 */

import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION, ODSAY_API_KEY, KAKAO_REST_API_KEY} from "../config";

/** 외부 교통 API 호출을 생략하는 최소 거리 (km) */
const MIN_DISTANCE_FOR_API_KM = 1.0;

// MARK: - Types

/** 대중교통 경로의 구간 정보 */
export interface SubPathInfo {
  /** 교통 수단 타입 (1=지하철, 2=버스, 3=도보) */
  trafficType: number;
  /** 구간 소요시간 (분) */
  sectionTime: number;
  /** 구간 거리 (미터) */
  distance: number;
  /** 승차 정류장/역 이름 */
  startName?: string;
  /** 하차 정류장/역 이름 */
  endName?: string;
  /** 경유 정류장 수 */
  stationCount?: number;
  /** 노선 정보 */
  lanes?: { name?: string; busNo?: string; subwayCode?: number }[];
}

/** 대중교통 경로 정보 */
export interface TransitRouteInfo {
  /** 총 소요시간 (분) */
  totalTime: number;
  /** 요금 (원) */
  payment: number;
  /** 버스 환승 횟수 */
  busTransitCount: number;
  /** 지하철 환승 횟수 */
  subwayTransitCount: number;
  /** 경로 유형 (1=지하철, 2=버스, 3=복합) */
  pathType: number;
  /** 구간별 상세 정보 */
  subPaths: SubPathInfo[];
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
  transitRoutes: TransitRouteInfo[];
  driving: DrivingInfo | null;
  walkingMinutes: number;
}

// MARK: - ODsay (대중교통)

/**
 * ODsay 대중교통 경로 조회 (최대 5개 경로 반환)
 * @param {number} fromLat 출발 위도
 * @param {number} fromLng 출발 경도
 * @param {number} toLat 도착 위도
 * @param {number} toLng 도착 경도
 * @return {Promise<TransitRouteInfo[]>} 대중교통 경로 목록
 */
async function fetchTransitRoute(
  fromLat: number, fromLng: number,
  toLat: number, toLng: number,
): Promise<TransitRouteInfo[]> {
  const apiKey = ODSAY_API_KEY.value();
  if (!apiKey) {
    console.warn("[Transportation] ODSAY_API_KEY not configured");
    return [];
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
      return [];
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const data: any = await response.json();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const paths: any[] = data?.result?.path ?? [];
    if (!Array.isArray(paths) || paths.length === 0) return [];

    return paths.slice(0, 5).map((path) => {
      const info = path.info ?? {};
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const rawSubPaths: any[] =
        Array.isArray(path.subPath) ? path.subPath : [];

      const subPaths: SubPathInfo[] = rawSubPaths.map((sp) => {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const rawLanes: any[] = Array.isArray(sp.lane) ? sp.lane : [];
        const lanes = rawLanes.map((lane) => ({
          name: lane.name as string | undefined,
          busNo: lane.busNo as string | undefined,
          subwayCode: lane.subwayCode as number | undefined,
        }));

        return {
          trafficType: sp.trafficType ?? 3,
          sectionTime: sp.sectionTime ?? 0,
          distance: sp.distance ?? 0,
          startName: sp.startName as string | undefined,
          endName: sp.endName as string | undefined,
          stationCount: sp.stationCount as number | undefined,
          lanes: lanes.length > 0 ? lanes : undefined,
        };
      });

      return {
        totalTime: info.totalTime ?? 0,
        payment: info.payment ?? 0,
        busTransitCount: info.busTransitCount ?? 0,
        subwayTransitCount: info.subwayTransitCount ?? 0,
        pathType: info.pathType ?? 3,
        subPaths,
      };
    });
  } catch (error) {
    console.error("[Transportation] ODsay fetch error:", error);
    return [];
  }
}

// MARK: - Kakao Mobility (자동차)

/**
 * Kakao Mobility 자동차 경로 조회
 * @param {number} fromLat 출발 위도
 * @param {number} fromLng 출발 경도
 * @param {number} toLat 도착 위도
 * @param {number} toLng 도착 경도
 * @return {Promise<DrivingInfo | null>} 자동차 경로 정보
 */
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
      console.error(
        `[Transportation] Kakao Mobility error: ${response.status}`
      );
      return null;
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const data: any = await response.json();
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

/**
 * Haversine 거리 기반 도보 소요시간 추정
 * @param {number} distanceKm 직선거리 (km)
 * @return {number} 도보 소요시간 (분)
 */
function estimateWalkMinutes(distanceKm: number): number {
  const actualDistance = distanceKm * 1.3; // 직선 → 실제 경로 보정
  return Math.round((actualDistance / 4) * 60); // 시속 4km 기준
}

// MARK: - Haversine Distance

/**
 * 두 좌표 간 직선거리 계산 (km)
 * @param {number} lat1 첫 번째 위도
 * @param {number} lng1 첫 번째 경도
 * @param {number} lat2 두 번째 위도
 * @param {number} lng2 두 번째 경도
 * @return {number} 직선거리 (km)
 */
function haversineDistance(
  lat1: number, lng1: number,
  lat2: number, lng2: number,
): number {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
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

  // 단거리는 외부 API 호출 생략
  if (distanceKm < MIN_DISTANCE_FOR_API_KM) {
    return {transitRoutes: [], driving: null, walkingMinutes};
  }

  // 대중교통 + 자동차 병렬 호출
  const [transitRoutes, driving] = await Promise.all([
    fetchTransitRoute(fromLat, fromLng, toLat, toLng),
    fetchDrivingRoute(fromLat, fromLng, toLat, toLng),
  ]);

  return {
    transitRoutes,
    driving,
    walkingMinutes,
  };
}

// MARK: - Callable Function

interface GetTransportationRequest {
  fromLat: number;
  fromLng: number;
  toLat: number;
  toLng: number;
}

/**
 * 두 좌표 간 교통 정보 조회 (대중교통 + 자동차 + 도보)
 *
 * @ios HomeFeature - 출발 알림 설정 시 이동 시간 조회
 * @added 2026-03-10
 *
 * @param fromLat 출발 위도
 * @param fromLng 출발 경도
 * @param toLat 도착 위도
 * @param toLng 도착 경도
 */
export const getTransportation = onCall<GetTransportationRequest>(
  {
    region: REGION,
    secrets: [ODSAY_API_KEY, KAKAO_REST_API_KEY],
  },
  async (request): Promise<TransportationResult> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "인증이 필요합니다");
    }

    const {fromLat, fromLng, toLat, toLng} = request.data;

    if (typeof fromLat !== "number" || typeof fromLng !== "number" ||
        typeof toLat !== "number" || typeof toLng !== "number" ||
        isNaN(fromLat) || isNaN(fromLng) || isNaN(toLat) || isNaN(toLng)) {
      throw new HttpsError(
        "invalid-argument",
        "출발지와 도착지 좌표가 필요합니다"
      );
    }

    const distanceKm = haversineDistance(fromLat, fromLng, toLat, toLng);

    return await fetchTransportation(
      fromLat, fromLng, toLat, toLng, distanceKm
    );
  }
);
