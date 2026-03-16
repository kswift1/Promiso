// firebase-functions/params 전역 mock (Jest 환경에서 defineSecret/defineString 미지원)
jest.mock('firebase-functions/params', () => ({
  defineSecret: jest.fn((name: string) => ({
    value: () => 'test-secret-value',
  })),
  defineString: jest.fn((name: string, options?: {default?: string}) => ({
    value: () => options?.default ?? '',
  })),
}));

/**
 * Jest 테스트 환경 설정
 */
import * as admin from 'firebase-admin';

// Firebase Admin 초기화 (테스트 모드)
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'promiso-test',
    storageBucket: 'promiso-test.firebasestorage.app',
  });
}

// 타임아웃 설정 (Functions는 시간이 오래 걸릴 수 있음)
jest.setTimeout(10000);

// 환경 변수 설정
process.env.GCLOUD_PROJECT = 'promiso-test';
process.env.GOOGLE_CLOUD_PROJECT = 'promiso-test';
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
process.env.FIREBASE_STORAGE_EMULATOR_HOST = 'localhost:9199';
