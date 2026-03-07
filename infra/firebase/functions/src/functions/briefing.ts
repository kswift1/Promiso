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

const BRIEFING_GENERATION_PROMPT = `당신은 사용자의 하루를 친근하게 브리핑해주는 개인 비서입니다.
아래 데이터를 종합해서 자연스러운 아침 브리핑을 작성해주세요.
규칙:
- 3-4문장으로 짧게
- 친근한 한국어 말투
- 날씨가 이동에 영향을 주면 반드시 언급
- 이동 시간 촉박하면 출발 시간 명시
- 그룹 약속은 확정 여부 언급
- 일정 없으면 날씨 중심으로 브리핑
`;

/**
 * 날씨 정보를 프롬프트용 문자열로 변환합니다.
 *
 * @param {GenerateBriefingRequest["weather"]} weather - 날씨 정보
 * @return {string} 프롬프트용 날씨 문자열
 */
function formatWeather(weather: GenerateBriefingRequest["weather"]): string {
  if (!weather) return "정보 없음";
  return `기온 ${weather.temp}°C, 상태 ${weather.condition}, 강수확률 ${weather.rain}%, 최고/최저 ${weather.max}/${weather.min}°C`;
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
 * - API 키 없음 → 기본 브리핑 "좋은 하루 되세요! 오늘도 화이팅 💪"
 * - API 오류 → 기본 브리핑 "좋은 하루 되세요! 오늘도 화이팅 💪"
 *
 * @param request.data.currentDateTime - 현재 날짜/시간 (예: "2026-03-07 금요일 08:30")
 * @param request.data.currentLocation - 현재 위치 (예: "서울 강남구", null이면 알 수 없음)
 * @param request.data.weather - 날씨 정보 (null이면 정보 없음)
 * @param request.data.schedules - 포맷된 일정 텍스트 (없으면 "일정 없음")
 * @returns {briefing: string} - 생성된 브리핑 텍스트
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
    const DEFAULT_BRIEFING = "좋은 하루 되세요! 오늘도 화이팅 💪";

    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const {currentDateTime, currentLocation, weather, schedules} = request.data;

    // 2. API 키 확인 (Secret Manager에서 로드됨)
    const apiKey = GEMINI_API_KEY.value();
    if (!apiKey) {
      console.error("GEMINI_API_KEY is not configured in Secret Manager");
      return {briefing: DEFAULT_BRIEFING};
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
        "브리핑만 작성하고 다른 텍스트는 절대 포함하지 마세요.",
      ].join("\n");

      const result = await model.generateContent(prompt);
      const response = result.response;
      const briefing = response.text().trim();

      if (!briefing) {
        console.warn("Empty briefing response from Gemini");
        return {briefing: DEFAULT_BRIEFING};
      }

      console.log(`✅ Generated briefing (${briefing.length} chars)`);
      return {briefing};
    } catch (error) {
      console.error("Gemini API error:", error);
      // 오류 시 기본 브리핑 반환 (graceful degradation)
      return {briefing: DEFAULT_BRIEFING};
    }
  },
);
