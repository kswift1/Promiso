/**
 * Widget Token Functions 테스트
 */
import { describe, it, expect, jest, beforeEach, afterEach } from '@jest/globals';
import * as admin from 'firebase-admin';
import * as jwt from 'jsonwebtoken';

describe('generateWidgetToken', () => {
  let generateWidgetToken: any;
  let mockFirestore: any;

  beforeEach(async () => {
    // Firestore mock
    mockFirestore = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({ widgetTokenVersion: 1 }),
          }),
        }),
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    // Functions 모듈 import
    const functions = await import('../src/functions/widgetToken');
    generateWidgetToken = functions.generateWidgetToken;
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  // NOTE: Firestore/Secret 모두 mock 처리하므로 정상 플로우를 유닛 테스트로 검증 가능
  describe('정상 케이스', () => {
    it('유효한 Widget Token을 생성한다', async () => {
      // Given
      const request = {
        data: {
          deviceId: 'test-device-id',
        },
        auth: {
          uid: 'test-user-id',
        },
      };

      // When
      const handler = (generateWidgetToken as any).run;
      const result = await handler(request);

      // Then
      expect(result).toBeDefined();
      expect(result.widgetToken).toBeDefined();
      expect(result.expiresAt).toBeGreaterThan(Date.now() / 1000);

      // JWT 검증
      const decoded = jwt.verify(result.widgetToken, 'test-secret-value') as any;
      expect(decoded.sub).toBe('test-user-id');
      expect(decoded.scope).toBe('widget:read');
      expect(decoded.deviceId).toBe('test-device-id');
    });
  });

  describe('에러 케이스', () => {
    it('인증 없이 호출 시 에러를 발생시킨다', async () => {
      // Given
      const request = {
        data: {
          deviceId: 'test-device-id',
        },
        auth: undefined,
      };

      // When & Then
      await expect(generateWidgetToken(request)).rejects.toThrow();
    });

    it('deviceId가 없으면 에러를 발생시킨다', async () => {
      // Given
      const request = {
        data: {},
        auth: {
          uid: 'test-user-id',
        },
      };

      // When & Then
      await expect(generateWidgetToken(request)).rejects.toThrow();
    });
  });
});

describe('verifyWidgetToken', () => {
  let verifyWidgetToken: any;

  beforeEach(async () => {
    const functions = await import('../src/functions/widgetToken');
    verifyWidgetToken = functions.verifyWidgetToken;
  });

  it('유효한 토큰을 검증한다', () => {
    // Given
    const payload = {
      sub: 'test-user-id',
      scope: 'widget:read',
      deviceId: 'test-device-id',
      version: 1,
    };
    const secret = 'test-secret-key';
    const token = jwt.sign(payload, secret, { expiresIn: '30d' });

    // When
    const result = verifyWidgetToken(token, secret);

    // Then
    expect(result.sub).toBe('test-user-id');
    expect(result.scope).toBe('widget:read');
  });

  it('잘못된 scope는 에러를 발생시킨다', () => {
    // Given
    const payload = {
      sub: 'test-user-id',
      scope: 'invalid-scope',
      deviceId: 'test-device-id',
      version: 1,
    };
    const secret = 'test-secret-key';
    const token = jwt.sign(payload, secret);

    // When & Then
    expect(() => verifyWidgetToken(token, secret)).toThrow();
  });

  it('만료된 토큰은 에러를 발생시킨다', () => {
    // Given
    const payload = {
      sub: 'test-user-id',
      scope: 'widget:read',
      deviceId: 'test-device-id',
      version: 1,
    };
    const secret = 'test-secret-key';
    const token = jwt.sign(payload, secret, { expiresIn: '-1s' }); // 이미 만료

    // When & Then
    expect(() => verifyWidgetToken(token, secret)).toThrow();
  });
});
