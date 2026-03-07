/**
 * Briefing Functions
 *
 * 하루 브리핑 생성 관련 Cloud Functions
 *
 * @added 2026-03-07
 * @why 사용자의 날씨, 일정을 종합해 아침 브리핑 제공으로 UX 향상
 * @ios BriefingView - 홈 화면 브리핑 카드에서 호출
 */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {GoogleGenerativeAI} from "@google/generative-ai";
import {REGION, GEMINI_API_KEY} from "../config";
import {GenerateBriefingRequest, GenerateBriefingResponse} from "../types/api";

const BRIEFING_GENERATION_PROMPT =
  `당신은 사용자의 하루를 친근하게 브리핑해주는 개인 비서입니다.\n` +
  `아래 데이터를 종합해서 브리핑을 작성해주세요.\n\n` +
  `반드시 아래 JSON 형식으로만 응답하세요:\n` +
  `{"summary":"한 줄 요약 (30자 이내)","detail":"상세 브리핑 (3-4문장)"}\n\n` +
  `summary 규칙:\n` +
  `- 핵심만 담은 한 줄 (30자 이내)\n` +
  `- 날씨 + 주요 일정 키워드만\n\n` +
  `detail 규칙:\n` +
  `- 3-4문장으로 짧게\n` +
  `- 친근한 한국어 말투\n` +
  `- 날씨가 이동에 영향을 주면 반드시 언급\n` +
  `- 이동 시간 촉박하면 출발 시간 명시\n` +
  `- 그룹 약속은 확정 여부 언급\n` +
  `- 일정 없으면 날씨 중심으로 브리핑\n\n` +
  `JSON 외 다른 텍스트는 절대 포함하지 마세요.\n`;

/**
 * 날씨 정보를 프롬프트용 문자열로 변환
 * @param {object | null | undefined} weather 날씨 정보
 * @return {string} 프롬프트용 날씨 문자열
 */
function formatWeather(
  weather: GenerateBriefingRequest["weather"]
): string {
  if (!weather) return "정보 없음";
  const {temp, condition, rain, max, min} = weather;
  return `기온 ${temp}°C, 상태 ${condition}, ` +
    `강수확률 ${rain}%, 최고/최저 ${max}/${min}°C`;
}

/**
 * 하루 브리핑 생성 (Gemini API 사용)
 *
 * @why 날씨 및 일정 데이터를 종합해 사용자 맞춤 아침 브리핑 제공
 * @ios BriefingView에서 앱 실행 시 호출
 * @added 2026-03-07
 *
 * @remarks
 * **인증 필수**
 *
 * Gemini 2.0 Flash 모델을 사용하여 날씨와 일정을 종합한 브리핑을 생성합니다.
 *
 * **Fallback 전략**:
 * - API 키 없음 → 기본값 반환
 * - API 오류 → 기본값 반환
 * - JSON 파싱 실패 → 원문 텍스트를 detail로, 첫 문장을 summary로 사용
 *
 * @param request.data.currentDateTime - 현재 날짜/시간 (예: "2026-03-07 금요일 08:30")
 * @param request.data.currentLocation - 현재 위치 (예: "서울 강남구", null이면 알 수 없음)
 * @param request.data.weather - 날씨 정보 (null이면 정보 없음)
 * @param request.data.schedules - 포맷된 일정 텍스트 (없으면 "일정 없음")
 * @returns {{summary: string, detail: string}} - 생성된 브리핑
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 */
export const generateBriefing = onCall<GenerateBriefingRequest>(
  {
    region: REGION,
    secrets: [GEMINI_API_KEY], // Secret Manager에서 API 키 로드
  },
  async (request): Promise<GenerateBriefingResponse> => {
    const DEFAULT_SUMMARY = "좋은 하루 되세요!";
    const DEFAULT_DETAIL = "오늘도 화이팅 💪";

    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const {
      currentDateTime,
      currentLocation,
      weather,
      schedules,
    } = request.data;

    // 2. API 키 확인 (Secret Manager에서 로드됨)
    const apiKey = GEMINI_API_KEY.value();
    if (!apiKey) {
      console.error("GEMINI_API_KEY is not configured in Secret Manager");
      return {summary: DEFAULT_SUMMARY, detail: DEFAULT_DETAIL};
    }

    console.log(`📋 Generating briefing for: ${currentDateTime}`);

    try {
      // 3. Gemini API 호출
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({model: "gemini-2.0-flash"});

      const prompt = [
        BRIEFING_GENERATION_PROMPT,
        `[현재 날짜/시간]: ${currentDateTime}`,
        `[현재 위치]: ${currentLocation ?? "알 수 없음"}`,
        `[날씨]: ${formatWeather(weather)}`,
        `[오늘 일정]: ${schedules}`,
      ].join("\n");

      const result = await model.generateContent(prompt);
      const response = result.response;
      const text = response.text().trim();

      if (!text) {
        console.warn("Empty briefing response from Gemini");
        return {summary: DEFAULT_SUMMARY, detail: DEFAULT_DETAIL};
      }

      // JSON 파싱 시도
      try {
        // 마크다운 코드블록 제거
        const jsonStr = text
          .replace(/^```json\s*/i, "")
          .replace(/```\s*$/, "")
          .trim();
        const parsed = JSON.parse(jsonStr);
        if (parsed.summary && parsed.detail) {
          console.log(`✅ Generated briefing (JSON)`);
          return {
            summary: parsed.summary,
            detail: parsed.detail,
          };
        }
      } catch {
        // JSON 파싱 실패 시 전체 텍스트를 detail로
        console.warn("JSON parse failed, using raw text");
      }

      // fallback: 전체 텍스트를 detail로, 첫 문장을 summary로
      const firstSentence = text.split(/[.!?。]/)[0];
      return {
        summary: firstSentence.substring(0, 30),
        detail: text,
      };
    } catch (error) {
      console.error("Gemini API error:", error);
      // 오류 시 기본값 반환 (graceful degradation)
      return {summary: DEFAULT_SUMMARY, detail: DEFAULT_DETAIL};
    }
  },
);
