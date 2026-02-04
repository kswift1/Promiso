/**
 * Kakao Map Functions
 *
 * Kakao REST API 프록시 Functions (장소 검색)
 *
 * @added 2026-02-04
 * @why Kakao REST API 키 노출 방지 - 클라이언트에서 직접 호출하지 않고 Functions를 통해 프록시
 * @ios LocationPickerFeature - 약속 생성 시 장소 검색에서 호출
 */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";
import {defineSecret} from "firebase-functions/params";

// Kakao REST API 키 (Secret Manager에서 관리)
const KAKAO_REST_API_KEY = defineSecret("KAKAO_REST_API_KEY");

/**
 * 장소 검색 요청
 */
export interface SearchPlacesRequest {
  query: string;
  size?: number;
}

/**
 * 장소 검색 응답
 */
export interface SearchPlacesResponse {
  places: Array<{
    id: string;
    name: string;
    latitude: number;
    longitude: number;
    address: string;
    roadAddress: string;
    category: string;
    phone: string;
  }>;
}

/**
 * Kakao API 응답 타입
 */
interface KakaoSearchResponse {
  meta: {
    total_count: number;
    pageable_count: number;
    is_end: boolean;
  };
  documents: Array<{
    id: string;
    place_name: string;
    category_name: string;
    category_group_code: string;
    category_group_name: string;
    phone: string;
    address_name: string;
    road_address_name: string;
    x: string; // longitude
    y: string; // latitude
    place_url: string;
    distance: string;
  }>;
}

/**
 * 장소 검색 (Kakao REST API 프록시)
 *
 * @why Kakao REST API 키를 클라이언트에 노출하지 않기 위해 서버에서 프록시
 * @ios LocationPickerFeature의 장소 검색에서 호출
 * @added 2026-02-04
 *
 * @remarks
 * **인증 선택**
 * - 인증 없이도 호출 가능 (장소 검색은 공개 기능)
 * - 필요시 `if (!request.auth)` 체크 추가 가능
 *
 * **환경 변수**:
 * - KAKAO_REST_API_KEY: Kakao REST API 키 (Secret Manager)
 *
 * @param request.data.query - 검색어 (필수)
 * @param request.data.size - 검색 결과 개수 (기본 15, 최대 45)
 * @returns {places: PlaceItem[]} - 장소 목록
 *
 * @throws HttpsError
 * - invalid-argument: query가 없거나 비어있음
 * - unavailable: Kakao API 호출 실패
 */
export const searchPlaces = onCall<SearchPlacesRequest>(
  {
    region: REGION,
    secrets: [KAKAO_REST_API_KEY], // Secret Manager에서 API 키 로드
  },
  async (request): Promise<SearchPlacesResponse> => {
    // 1. 검색어 확인
    const {query, size = 15} = request.data;

    if (!query || query.trim().length === 0) {
      throw new HttpsError("invalid-argument", "검색어가 필요합니다");
    }

    // 2. API 키 확인 (Secret Manager에서 로드됨)
    const apiKey = KAKAO_REST_API_KEY.value();
    if (!apiKey) {
      console.error("KAKAO_REST_API_KEY is not configured in Secret Manager");
      throw new HttpsError(
        "internal",
        "서버 설정 오류: KAKAO_REST_API_KEY가 설정되지 않았습니다"
      );
    }

    console.log(`🗺️ Searching places: query="${query}", size=${size}`);

    try {
      // 3. Kakao REST API 호출
      const url = new URL("https://dapi.kakao.com/v2/local/search/keyword.json");
      url.searchParams.append("query", query);
      url.searchParams.append("size", Math.min(size, 45).toString()); // 최대 45개

      const response = await fetch(url.toString(), {
        method: "GET",
        headers: {
          "Authorization": `KakaoAK ${apiKey}`,
        },
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`Kakao API error: ${response.status} - ${errorText}`);
        throw new HttpsError(
          "unavailable",
          `Kakao API 호출 실패: ${response.status}`
        );
      }

      const data: KakaoSearchResponse =
        await response.json() as KakaoSearchResponse;

      // 4. 데이터 변환
      const places = data.documents.map((doc) => ({
        id: doc.id,
        name: doc.place_name,
        latitude: parseFloat(doc.y),
        longitude: parseFloat(doc.x),
        address: doc.address_name,
        roadAddress: doc.road_address_name || "",
        category: doc.category_name || "",
        phone: doc.phone || "",
      }));

      console.log(`✅ Found ${places.length} places`);

      return {places};
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("Unexpected error searching places:", error);
      throw new HttpsError(
        "internal",
        "장소 검색 중 오류가 발생했습니다"
      );
    }
  }
);
