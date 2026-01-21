/**
 * Emoji Functions
 *
 * 이모지 생성 관련 Cloud Functions
 *
 * @added 2026-01-21
 * @why 약속 제목에 맞는 이모지 자동 추천으로 UX 향상
 * @ios CreatePromiseView - 제목 입력 시 호출
 */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {GoogleGenerativeAI} from "@google/generative-ai";
import {REGION, GEMINI_API_KEY} from "../config";
import {
  GenerateEmojiRequest,
  GenerateEmojiResponse,
} from "../types/api";

const EMOJI_GENERATION_PROMPT = `당신은 약속 제목을 보고 가장 적절한 이모지를 추천하는 전문가입니다.

규칙:
- 이모지 1개만 출력
- 다른 텍스트 절대 금지
- 제목의 의미와 맥락에 가장 부합하는 이모지 선택
- 대중적인 이모지 우선 (식사🍽️, 커피☕, 운동💪, 회의💼, 술🍺 등)

제목: `;

/**
 * 텍스트에서 첫 번째 이모지를 추출합니다.
 *
 * @param {string} text - 이모지를 추출할 텍스트
 * @return {string | null} 추출된 이모지 또는 null
 */
function extractFirstEmoji(text: string): string | null {
  // 이모지 정규식 패턴 (대부분의 이모지 매칭)
  const emojiRegex = /\p{Emoji_Presentation}|\p{Emoji}\uFE0F/gu;
  const match = text.match(emojiRegex);
  return match ? match[0] : null;
}

/**
 * 이모지 생성 (Gemini API 사용)
 *
 * @why 약속 제목에 맞는 이모지를 자동 추천하여 사용자 경험 향상
 * @ios CreatePromiseView에서 제목 입력 후 debounce로 호출
 * @added 2026-01-21
 *
 * @remarks
 * **인증 필수**
 *
 * Gemini 2.0 Flash 모델을 사용하여 약속 제목에 어울리는 이모지를 생성합니다.
 *
 * **Fallback 전략**:
 * - API 키 없음 → 기본값 📅
 * - API 오류 → 기본값 📅
 * - 이모지 추출 실패 → 기본값 📅
 *
 * @param request.data.title - 약속 제목
 * @returns {emoji: string} - 생성된 이모지
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 제목이 비어있습니다
 */
export const generateEmoji = onCall<GenerateEmojiRequest>(
  {
    region: REGION,
    secrets: [GEMINI_API_KEY], // Secret Manager에서 API 키 로드
  },
  async (request): Promise<GenerateEmojiResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const {title} = request.data;

    // 2. 유효성 검사
    if (!title || title.trim().length === 0) {
      throw new HttpsError("invalid-argument", "제목이 비어있습니다");
    }

    // 3. API 키 확인 (Secret Manager에서 로드됨)
    const apiKey = GEMINI_API_KEY.value();
    if (!apiKey) {
      console.error("GEMINI_API_KEY is not configured in Secret Manager");
      return {emoji: "📅"};
    }

    console.log(`🎨 Generating emoji for: "${title.trim()}"`);

    try {
      // 4. Gemini API 호출
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({model: "gemini-2.0-flash"});

      const prompt = EMOJI_GENERATION_PROMPT + title.trim();
      const result = await model.generateContent(prompt);
      const response = result.response;
      const text = response.text().trim();

      console.log(`🤖 Gemini response: "${text}"`);

      // 5. 이모지 추출
      const emoji = extractFirstEmoji(text);
      if (!emoji) {
        console.warn(`Failed to extract emoji from response: ${text}`);
        return {emoji: "📅"};
      }

      console.log(`✅ Generated emoji: ${emoji}`);
      return {emoji};
    } catch (error) {
      console.error("Gemini API error:", error);
      // 오류 시 기본 이모지 반환 (graceful degradation)
      return {emoji: "📅"};
    }
  },
);
