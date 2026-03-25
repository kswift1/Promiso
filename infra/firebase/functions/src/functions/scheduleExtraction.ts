/**
 * Schedule Extraction Functions
 *
 * SMS 문자 텍스트 또는 이미지에서 일정 정보를 LLM으로 추출
 *
 * @added 2026-03-24
 * @why 문자 메시지 복붙 또는 사진으로 개인 일정 자동 입력 UX 향상
 * @ios CreatePersonalEventView - "텍스트에서 가져오기" / "사진에서 가져오기" 기능
 */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {GoogleGenerativeAI} from "@google/generative-ai";
import {REGION, GEMINI_API_KEY} from "../config";
import {
  ExtractScheduleRequest,
  ExtractScheduleResponse,
} from "../types/api";

/* eslint-disable max-len */
const SCHEDULE_EXTRACTION_PROMPT = `당신은 한국어 문자 메시지 또는 이미지에서 일정 정보를 추출하는 전문가입니다.

입력된 텍스트 또는 이미지에서 다음 정보를 JSON 형태로 추출하세요:
- title: 일정 제목 (간결하게 추론, 20자 이내)
- startDate: 시작 날짜시간 (ISO 8601 형식, 예: "2026-03-27T09:00:00+09:00")
- endDate: 종료 날짜시간 (ISO 8601 형식, 없으면 null)
- location: 장소명 (없으면 null)
- address: 상세 주소 (없으면 null)
- description: 부가 정보 메모 - 급여, 준비물, 담당자 등 (없으면 null)

규칙:
- 반드시 JSON만 출력, 다른 텍스트 절대 금지
- 연도가 없으면 현재 연도 기준으로 추론
- "9시~18시" 같은 범위 표현은 startDate/endDate로 분리
- 장소명과 상세 주소를 구분 (장소: "GS25 성남양우프레시점", 주소: "경기 성남시 수정구 논골로 29")
- 급여, 준비물, 담당자 연락처 등 부가 정보는 description에 줄바꿈으로 구분하여 통합
- title은 핵심 내용을 간결하게 (예: "GS25 진열 근무", "고용센터 초기상담")
- 텍스트 또는 이미지(스크린샷, 포스터, 문자 캡처 등)에서 일정 정보를 추출
- 이미지인 경우 텍스트를 먼저 인식한 후 동일한 규칙으로 추출

현재 시각: {currentTime}
`;
/* eslint-enable max-len */

/**
 * Prompt injection 방어
 *
 * @param {string} input - 사용자 입력 텍스트
 * @return {string} 정제된 텍스트
 */
function sanitizeUserData(input: string): string {
  return input
    .replace(/<\/?user-data>/gi, "")
    .replace(/\[\/?(system|assistant|user)\]/gi, "");
}

/**
 * base64 문자열 앞부분에서 MIME 타입 감지
 *
 * @param {string} base64 - base64 인코딩된 이미지 문자열
 * @return {string} MIME 타입 문자열
 */
function detectMimeType(base64: string): string {
  if (base64.startsWith("/9j/")) return "image/jpeg";
  if (base64.startsWith("iVBOR")) return "image/png";
  if (base64.startsWith("R0lGOD")) return "image/gif";
  if (base64.startsWith("UklGR")) return "image/webp";
  return "image/jpeg"; // default
}

/**
 * JSON 응답에서 마크다운 코드블록 제거
 *
 * @param {string} text - Gemini 응답 텍스트
 * @return {string} 순수 JSON 문자열
 */
function extractJSON(text: string): string {
  const jsonBlockMatch = text.match(/```(?:json)?\s*\n?([\s\S]*?)\n?```/);
  if (jsonBlockMatch) {
    return jsonBlockMatch[1].trim();
  }
  return text.trim();
}

/**
 * 일정 추출 (Gemini API 사용)
 *
 * @why 문자 메시지 복붙으로 개인 일정 자동 입력 UX 향상
 * @ios CreatePersonalEventView에서 "텍스트에서 가져오기" 버튼으로 호출
 * @added 2026-03-24
 *
 * @remarks
 * **인증 필수**
 *
 * Gemini 2.0 Flash 모델을 사용하여 SMS 텍스트 또는 이미지에서 일정 정보를 추출합니다.
 *
 * @param request.data.text - SMS/문자 원본 텍스트 (선택적)
 * @param request.data.imageBase64 - 이미지 base64 인코딩 (선택적)
 * @param request.data.timezone - 클라이언트 타임존
 * @returns ExtractScheduleResponse - 추출된 일정 정보
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: text/imageBase64 누락, 텍스트 초과, 이미지 초과
 * - internal: 일정 추출에 실패했습니다
 */
export const extractSchedule = onCall<ExtractScheduleRequest>(
  {
    region: REGION,
    secrets: [GEMINI_API_KEY],
  },
  async (request): Promise<ExtractScheduleResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const {text, imageBase64, timezone} = request.data;

    // 2. 유효성 검사
    if (!text && !imageBase64) {
      throw new HttpsError(
        "invalid-argument",
        "text 또는 imageBase64 중 하나 이상 필요"
      );
    }

    if (text && text.length > 2000) {
      throw new HttpsError(
        "invalid-argument",
        "텍스트가 너무 깁니다 (최대 2000자)"
      );
    }

    if (imageBase64 && imageBase64.length > 5_300_000) {
      throw new HttpsError(
        "invalid-argument",
        "이미지 크기가 너무 큽니다 (최대 4MB)"
      );
    }

    // 3. API 키 확인
    const apiKey = GEMINI_API_KEY.value();
    if (!apiKey) {
      console.error("GEMINI_API_KEY is not configured in Secret Manager");
      throw new HttpsError("internal", "서버 설정 오류");
    }

    // 4. 현재 시각 계산 (클라이언트 timezone 기반)
    let safeTimezone = "Asia/Seoul";
    try {
      new Intl.DateTimeFormat(undefined, {
        timeZone: timezone,
      });
      safeTimezone = timezone;
    } catch {
      console.warn(
        `Invalid timezone: ${timezone}, ` +
        "falling back to Asia/Seoul"
      );
    }

    const currentTime = new Date().toLocaleString("ko-KR", {
      timeZone: safeTimezone,
      year: "numeric",
      month: "long",
      day: "numeric",
      weekday: "long",
      hour: "2-digit",
      minute: "2-digit",
    });

    const sanitizedText = text ? sanitizeUserData(text.trim()) : null;
    if (imageBase64) {
      console.log(
        `📷 Extracting schedule from image (${imageBase64.length} chars)`
      );
    } else {
      console.log(
        `📋 Extracting schedule from text (${sanitizedText?.length ?? 0} chars)`
      );
    }

    try {
      // 5. Gemini API 호출
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({model: "gemini-2.0-flash"});

      const promptWithTime = SCHEDULE_EXTRACTION_PROMPT
        .replace("{currentTime}", currentTime);

      const parts: object[] = [];

      // 프롬프트
      parts.push({text: promptWithTime});

      // 이미지가 있으면 inlineData 추가
      if (imageBase64) {
        parts.push({
          inlineData: {
            mimeType: detectMimeType(imageBase64),
            data: imageBase64,
          },
        });
      }

      // 텍스트가 있으면 user-data로 추가
      if (sanitizedText) {
        parts.push({text: `<user-data>${sanitizedText}</user-data>`});
      }

      const result = await model.generateContent({
        contents: [{role: "user", parts}],
      });
      const response = result.response;
      const responseText = response.text().trim();

      console.log(
        `🤖 Gemini response: ${responseText.substring(0, 200)}`
      );

      // 6. JSON 파싱
      const jsonText = extractJSON(responseText);
      let parsed: Record<string, unknown>;
      try {
        parsed = JSON.parse(jsonText);
      } catch {
        console.error(`Failed to parse JSON: ${jsonText}`);
        throw new HttpsError("internal", "일정 추출에 실패했습니다");
      }

      // 7. 응답 구성
      const extractedResponse: ExtractScheduleResponse = {
        title: typeof parsed.title === "string" ? parsed.title : null,
        startDate: typeof parsed.startDate === "string" ?
          parsed.startDate : null,
        endDate: typeof parsed.endDate === "string" ? parsed.endDate : null,
        location: typeof parsed.location === "string" ?
          parsed.location : null,
        address: typeof parsed.address === "string" ? parsed.address : null,
        description: typeof parsed.description === "string" ?
          parsed.description : null,
      };

      console.log(
        `✅ Extracted schedule: title="${extractedResponse.title}", ` +
        `start=${extractedResponse.startDate}`
      );
      return extractedResponse;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Gemini API error:", error);
      throw new HttpsError("internal", "일정 추출에 실패했습니다");
    }
  },
);
