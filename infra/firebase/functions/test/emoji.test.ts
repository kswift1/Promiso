/**
 * Emoji Functions 테스트
 */
import { describe, it, expect, jest, beforeEach } from '@jest/globals';

// Gemini AI mock
jest.mock('@google/generative-ai', () => ({
  GoogleGenerativeAI: jest.fn().mockImplementation(() => ({
    getGenerativeModel: jest.fn().mockReturnValue({
      generateContent: jest.fn().mockResolvedValue({
        response: {
          text: jest.fn().mockReturnValue('🎉'),
        },
      }),
    }),
  })),
}));

// Secret mock
jest.mock('firebase-functions/params', () => ({
  defineSecret: jest.fn(() => ({
    value: () => 'test-gemini-key',
  })),
}));

describe('generateEmoji', () => {
  let generateEmoji: any;

  beforeEach(async () => {
    // Functions 모듈 import (mock 후)
    const functions = await import('../src/functions/emoji');
    generateEmoji = functions.generateEmoji;
  });

  // NOTE: Gemini SDK는 mock 처리하므로 정상 플로우를 유닛 테스트로 검증 가능
  describe('정상 케이스', () => {
    it('그룹 이름으로 이모지를 생성한다', async () => {
      // Given
      const request = {
        data: {
          title: '친구들 모임',
        },
        auth: {
          uid: 'test-user-id',
        },
      };

      // When
      const handler = (generateEmoji as any).run;
      const result = await handler(request);

      // Then
      expect(result).toBeDefined();
      expect(result.emoji).toBe('🎉');
    });
  });

  describe('에러 케이스', () => {
    it('인증 없이 호출 시 에러를 발생시킨다', async () => {
      // Given
      const request = {
        data: {
          groupName: '친구들',
        },
        auth: undefined,
      };

      // When & Then
      await expect(generateEmoji(request)).rejects.toThrow();
    });

    it('그룹 이름이 없으면 에러를 발생시킨다', async () => {
      // Given
      const request = {
        data: {},
        auth: {
          uid: 'test-user-id',
        },
      };

      // When & Then
      await expect(generateEmoji(request)).rejects.toThrow();
    });
  });
});
