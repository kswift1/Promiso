/**
 * FAQ Functions
 *
 * Notion FAQ 데이터베이스 프록시 Functions
 *
 * @added 2026-02-04
 * @why Notion API 키 노출 방지 - 클라이언트에서 직접 호출하지 않고 Functions를 통해 프록시
 * @ios SettingsFeature - FAQ/도움말 화면에서 호출
 */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";
import {defineSecret} from "firebase-functions/params";

// Notion API 키 (Secret Manager에서 관리)
const NOTION_FAQ_API_KEY = defineSecret("NOTION_FAQ_API_KEY");

/**
 * FAQ 아이템 타입
 */
export interface FAQItem {
  id: string;
  question: string;
  answer: string;
  category: string;
  order: number;
  createdAt: string;
  updatedAt: string;
}

/**
 * FAQ 목록 조회 요청
 */
export type GetFAQsRequest = Record<string, never>;

/**
 * FAQ 목록 조회 응답
 */
export interface GetFAQsResponse {
  faqs: FAQItem[];
}

/**
 * Notion API 응답 타입
 */
interface NotionQueryResponse {
  results: NotionPage[];
}

interface NotionPage {
  id: string;
  created_time: string;
  last_edited_time: string;
  properties: {
    Question?: {
      title: Array<{
        plain_text: string;
      }>;
    };
    Answer?: {
      rich_text: Array<{
        plain_text: string;
      }>;
    };
    Category?: {
      select?: {
        name: string;
      };
    };
    Order?: {
      number: number;
    };
    Active?: {
      checkbox: boolean;
    };
  };
}

/**
 * FAQ 목록 조회 (Notion 프록시)
 *
 * @why Notion API 키를 클라이언트에 노출하지 않기 위해 서버에서 프록시
 * @ios SettingsFeature의 FAQ/도움말 화면에서 호출
 * @added 2026-02-04
 *
 * @remarks
 * **인증 선택**
 * - 인증 없이도 호출 가능 (FAQ는 공개 데이터)
 * - 필요시 `if (!request.auth)` 체크 추가 가능
 *
 * **Notion Database 구조**:
 * - Question (title): 질문 텍스트
 * - Answer (rich_text): 답변 텍스트
 * - Category (select): 카테고리
 * - Order (number): 정렬 순서
 * - Active (checkbox): 활성화 여부
 *
 * **환경 변수**:
 * - NOTION_FAQ_API_KEY: Notion Integration API 키 (Secret Manager)
 * - NOTION_FAQ_DATABASE_ID: FAQ 데이터베이스 ID (Remote Config)
 *
 * @param request.data.databaseId - Notion FAQ 데이터베이스 ID (Remote Config에서 전달)
 * @returns {faqs: FAQItem[]} - FAQ 목록 (Order 순으로 정렬, Active=true만)
 *
 * @throws HttpsError
 * - invalid-argument: databaseId가 없습니다
 * - unavailable: Notion API 호출 실패
 */
export const getFAQs = onCall<GetFAQsRequest & {databaseId: string}>(
  {
    region: REGION,
    secrets: [NOTION_FAQ_API_KEY], // Secret Manager에서 API 키 로드
    invoker: "public", // 인증 없이 호출 가능
  },
  async (request): Promise<GetFAQsResponse> => {
    // 1. databaseId 확인 (Remote Config에서 전달받음)
    const {databaseId} = request.data;

    if (!databaseId || databaseId.trim().length === 0) {
      throw new HttpsError("invalid-argument", "databaseId가 필요합니다");
    }

    // 2. API 키 확인 (Secret Manager에서 로드됨)
    const apiKey = NOTION_FAQ_API_KEY.value();
    if (!apiKey) {
      console.error("NOTION_FAQ_API_KEY is not configured in Secret Manager");
      throw new HttpsError(
        "internal",
        "서버 설정 오류: NOTION_FAQ_API_KEY가 설정되지 않았습니다"
      );
    }

    console.log(`📚 Fetching FAQs from Notion database: ${databaseId}`);

    try {
      // 3. Notion API 호출
      const url = `https://api.notion.com/v1/databases/${databaseId}/query`;
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Notion-Version": "2022-06-28",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          filter: {
            property: "Active",
            checkbox: {
              equals: true,
            },
          },
          sorts: [
            {
              property: "Order",
              direction: "ascending",
            },
          ],
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`Notion API error: ${response.status} - ${errorText}`);
        throw new HttpsError(
          "unavailable",
          `Notion API 호출 실패: ${response.status}`
        );
      }

      const data: NotionQueryResponse =
        await response.json() as NotionQueryResponse;

      // 4. 데이터 변환
      const faqs: FAQItem[] = data.results
        .map((page: NotionPage) => {
          const question = page.properties.Question?.title[0]?.plain_text || "";
          const answer = page.properties.Answer?.rich_text[0]?.plain_text || "";
          const category = page.properties.Category?.select?.name || "기타";
          const order = page.properties.Order?.number || 999;

          // Question과 Answer가 모두 있는 것만 포함
          if (!question || !answer) {
            return null;
          }

          return {
            id: page.id,
            question,
            answer,
            category,
            order,
            createdAt: page.created_time,
            updatedAt: page.last_edited_time,
          };
        })
        .filter((faq): faq is FAQItem => faq !== null);

      console.log(`✅ Fetched ${faqs.length} FAQs`);

      return {faqs};
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("Unexpected error fetching FAQs:", error);
      throw new HttpsError(
        "internal",
        "FAQ 조회 중 오류가 발생했습니다"
      );
    }
  }
);
