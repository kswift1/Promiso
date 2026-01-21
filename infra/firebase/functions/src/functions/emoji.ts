/**
 * Emoji Functions
 *
 * 이모지 생성 관련 Cloud Functions
 */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {GoogleGenerativeAI} from "@google/generative-ai";
import {REGION} from "../config";
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
 * @remarks
 * **인증 필수**
 *
 * 약속 제목에 어울리는 이모지를 Gemini API를 통해 생성합니다.
 *
 * @param request.data - GenerateEmojiRequest
 * @returns GenerateEmojiResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 제목이 비어있습니다
 * - internal: API 오류
 */
export const generateEmoji = onCall<GenerateEmojiRequest>(
  {region: REGION},
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

    // 3. API 키 확인
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.error("GEMINI_API_KEY is not configured");
      // API 키가 없으면 기본 이모지 반환
      return {emoji: "📅"};
    }

    try {
      // 4. Gemini API 호출
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({model: "gemini-2.0-flash"});

      const prompt = EMOJI_GENERATION_PROMPT + title.trim();
      const result = await model.generateContent(prompt);
      const response = result.response;
      const text = response.text().trim();

      // 5. 이모지 추출
      const emoji = extractFirstEmoji(text);
      if (!emoji) {
        console.warn(`Failed to extract emoji from response: ${text}`);
        return {emoji: "📅"};
      }

      return {emoji};
    } catch (error) {
      console.error("Gemini API error:", error);
      // 오류 시 기본 이모지 반환 (graceful degradation)
      return {emoji: "📅"};
    }
  },
);
