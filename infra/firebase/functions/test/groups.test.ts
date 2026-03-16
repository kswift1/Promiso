// @ts-nocheck
/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Groups Functions 테스트
 *
 * 복잡도가 높은 함수에 대한 철저한 유닛 테스트
 * - 권한 로직 (호스트/멤버/초대)
 * - Firestore 트랜잭션
 * - Storage 관리
 * - 초대 코드 생성
 * - 그룹 멤버 관리
 */
import {
  describe,
  it,
  expect,
  jest,
  beforeEach,
  afterEach,
} from '@jest/globals';
import * as admin from 'firebase-admin';

// ============================================================================
// Mock 설정
// ============================================================================

// Notifications mock
jest.mock('../src/functions/notifications', () => ({
  sendPushNotificationInternal: jest.fn(() => Promise.resolve({
    success: true,
    successCount: 1,
    failureCount: 0,
  })),
}));

// ============================================================================
// 테스트 유틸리티
// ============================================================================

// Jest mock 타입 정의
type MockFn = jest.Mock<any, any>;

/**
 * Promise를 반환하는 mock 함수 생성
 */
function mockResolved<T>(value: T): MockFn {
  return jest.fn(() => Promise.resolve(value)) as MockFn;
}

function mockRejected(error: Error): MockFn {
  return jest.fn(() => Promise.reject(error)) as MockFn;
}

/**
 * Firestore 문서 mock 생성
 */
function createMockDocument(exists: boolean, data?: Record<string, unknown>): any {
  return {
    exists,
    id: 'mock-doc-id',
    data: () => data,
    ref: {
      id: 'mock-doc-id',
      update: mockResolved(undefined),
    },
  };
}

/**
 * Firestore 쿼리 스냅샷 mock 생성
 */
function createMockQuerySnapshot(docs: Array<{id: string; data: Record<string, unknown>}>): any {
  return {
    empty: docs.length === 0,
    size: docs.length,
    docs: docs.map((doc) => ({
      id: doc.id,
      data: () => doc.data,
      ref: {
        id: doc.id,
        update: mockResolved(undefined),
        delete: mockResolved(undefined),
      },
    })),
  };
}

// ============================================================================
// createGroup 테스트
// ============================================================================

describe('createGroup', () => {
  let createGroup: any;
  let mockFirestore: any;
  let mockGroupRef: any;
  let mockUserRef: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    // Mock refs
    mockGroupRef = {
      id: 'test-group-id',
      get: mockResolved(createMockDocument(false)),
      set: mockResolved(undefined),
    };

    mockUserRef = {
      id: 'test-user-id',
      set: mockResolved(undefined),
    };

    // Firestore mock
    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === 'groups') {
          return {
            doc: jest.fn().mockReturnValue(mockGroupRef),
            where: jest.fn().mockReturnValue({
              limit: jest.fn().mockReturnValue({
                get: mockResolved(createMockQuerySnapshot([])),
              }),
            }),
          };
        }
        if (name === 'users') {
          return {
            doc: jest.fn().mockReturnValue(mockUserRef),
          };
        }
        return {};
      }),
    };

    const {admin: configAdmin} = await import('../src/config');
    jest.spyOn(configAdmin, 'firestore').mockReturnValue(mockFirestore as any);

    const functions = await import('../src/functions/groups');
    createGroup = functions.createGroup;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: Firestore를 mock 처리한 정상 플로우 유닛 테스트
  describe('정상 케이스', () => {
    it('유효한 요청으로 그룹을 생성한다', async () => {
      // Given
      const request = {
        data: {
          groupId: 'test-group-id',
          name: '테스트 그룹',
          maxMembers: 10,
          description: '테스트 설명',
          imageUrl: 'https://example.com/image.jpg',
        },
        auth: {
          uid: 'creator-user-id',
        },
      };

      // When
      const handler = (createGroup as any).run;
      const result = await handler(request);

      // Then
      expect(result).toBeDefined();
      expect(result.id).toBe('test-group-id');
      expect(result.name).toBe('테스트 그룹');
      expect(result.inviteCode).toBeDefined();
      expect(result.inviteCode.length).toBe(6);
      expect(mockGroupRef.set).toHaveBeenCalled();
    });

    it('description과 imageUrl 없이도 그룹을 생성한다', async () => {
      // Given
      const request = {
        data: {
          groupId: 'minimal-group-id',
          name: '최소 그룹',
          maxMembers: 5,
        },
        auth: {
          uid: 'creator-user-id',
        },
      };

      // When
      const handler = (createGroup as any).run;
      const result = await handler(request);

      // Then
      expect(result).toBeDefined();
      expect(result.id).toBe('test-group-id');
    });
  });

  describe('인증 에러', () => {
    it('인증 없이 호출 시 unauthenticated 에러를 발생시킨다', async () => {
      // Given
      const request = {
        data: {
          groupId: 'test-group-id',
          name: '테스트 그룹',
          maxMembers: 10,
        },
        auth: undefined,
      };

      // When & Then
      await expect(createGroup(request)).rejects.toThrow();
    });
  });

  describe('유효성 검사 에러', () => {
    it('빈 groupId는 에러를 발생시킨다', async () => {
      const request = {
        data: {
          groupId: '   ',
          name: '테스트 그룹',
          maxMembers: 10,
        },
        auth: { uid: 'user-id' },
      };

      await expect(createGroup(request)).rejects.toThrow();
    });

    it('groupId에 슬래시(/)가 포함되면 에러를 발생시킨다', async () => {
      const request = {
        data: {
          groupId: 'invalid/group/id',
          name: '테스트 그룹',
          maxMembers: 10,
        },
        auth: { uid: 'user-id' },
      };

      await expect(createGroup(request)).rejects.toThrow();
    });

    it('그룹 이름이 2글자 미만이면 에러를 발생시킨다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          name: '가',
          maxMembers: 10,
        },
        auth: { uid: 'user-id' },
      };

      await expect(createGroup(request)).rejects.toThrow();
    });

    it('그룹 이름이 12글자 초과면 에러를 발생시킨다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          name: '가나다라마바사아자차카타파',
          maxMembers: 10,
        },
        auth: { uid: 'user-id' },
      };

      await expect(createGroup(request)).rejects.toThrow();
    });

    it('description이 50글자 초과면 에러를 발생시킨다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          name: '테스트 그룹',
          maxMembers: 10,
          description: 'a'.repeat(51),
        },
        auth: { uid: 'user-id' },
      };

      await expect(createGroup(request)).rejects.toThrow();
    });

    it('maxMembers가 정수가 아니면 에러를 발생시킨다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          name: '테스트 그룹',
          maxMembers: 5.5,
        },
        auth: { uid: 'user-id' },
      };

      await expect(createGroup(request)).rejects.toThrow();
    });

    it('maxMembers가 2 미만이면 에러를 발생시킨다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          name: '테스트 그룹',
          maxMembers: 1,
        },
        auth: { uid: 'user-id' },
      };

      await expect(createGroup(request)).rejects.toThrow();
    });
  });

  describe('중복 그룹 에러', () => {
    it('이미 존재하는 그룹 ID면 already-exists 에러를 발생시킨다', async () => {
      // Mock existing group
      mockGroupRef.get.mockResolvedValue(createMockDocument(true, { name: '기존 그룹' }) as any);

      const request = {
        data: {
          groupId: 'existing-group-id',
          name: '테스트 그룹',
          maxMembers: 10,
        },
        auth: { uid: 'user-id' },
      };

      await expect(createGroup(request)).rejects.toThrow();
    });
  });
});

// ============================================================================
// previewGroup 테스트
// ============================================================================

describe('previewGroup', () => {
  let previewGroup: any;
  let mockFirestore: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    const mockGroupData = {
      name: '테스트 그룹',
      description: '그룹 설명',
      imageUrl: 'https://example.com/group.jpg',
      maxMembers: 10,
      memberIds: ['user1', 'user2', 'user3'],
      inviteCode: 'ABC123',
    };

    const mockUserData = (userId: string) => ({
      nickname: `유저 ${userId}`,
      profile: { url: `https://example.com/${userId}.jpg` },
    });

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === 'groups') {
          return {
            where: jest.fn().mockReturnValue({
              limit: jest.fn().mockReturnValue({
                get: jest.fn().mockResolvedValue({
                  empty: false,
                  docs: [{
                    id: 'group-id',
                    data: () => mockGroupData,
                  }],
                } as any),
              }),
            }),
          };
        }
        if (name === 'users') {
          return {
            doc: jest.fn((userId: string) => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(true, mockUserData(userId)) as any
              ),
            })),
          };
        }
        return {};
      }),
    };

    const {admin: configAdmin} = await import('../src/config');
    jest.spyOn(configAdmin, 'firestore').mockReturnValue(mockFirestore as any);

    const functions = await import('../src/functions/groups');
    previewGroup = functions.previewGroup;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: Firestore를 mock 처리한 정상 플로우 유닛 테스트
  describe('정상 케이스', () => {
    it('유효한 초대 코드로 그룹 정보를 반환한다', async () => {
      const request = {
        data: { inviteCode: 'ABC123' },
        auth: undefined, // 인증 불필요
      };

      const handler = (previewGroup as any).run;
      const result = await handler(request);

      expect(result).toBeDefined();
      expect(result.groupId).toBe('group-id');
      expect(result.groupName).toBe('테스트 그룹');
      expect(result.description).toBe('그룹 설명');
      expect(result.memberCount).toBe(3);
      expect(result.members.length).toBe(3);
    });

    it('소문자 초대 코드도 대문자로 변환하여 처리한다', async () => {
      const request = {
        data: { inviteCode: 'abc123' },
        auth: undefined,
      };

      const handler = (previewGroup as any).run;
      const result = await handler(request);

      expect(result).toBeDefined();
      expect(result.groupName).toBe('테스트 그룹');
    });

    it('인증 없이도 호출 가능하다', async () => {
      const request = {
        data: { inviteCode: 'ABC123' },
        auth: undefined,
      };

      const handler = (previewGroup as any).run;
      await expect(handler(request)).resolves.toBeDefined();
    });
  });

  describe('유효성 검사 에러', () => {
    it('초대 코드가 6자리가 아니면 에러를 발생시킨다', async () => {
      const request = {
        data: { inviteCode: 'ABC12' }, // 5자리
        auth: undefined,
      };

      await expect(previewGroup(request)).rejects.toThrow();
    });

    it('빈 초대 코드는 에러를 발생시킨다', async () => {
      const request = {
        data: { inviteCode: '' },
        auth: undefined,
      };

      await expect(previewGroup(request)).rejects.toThrow();
    });

    it('초대 코드가 없으면 에러를 발생시킨다', async () => {
      const request = {
        data: {},
        auth: undefined,
      };

      await expect(previewGroup(request)).rejects.toThrow();
    });
  });

  describe('not-found 에러', () => {
    it('존재하지 않는 초대 코드는 에러를 발생시킨다', async () => {
      // Empty query result
      mockFirestore.collection = jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            get: jest.fn().mockResolvedValue({ empty: true, docs: [] } as any),
          }),
        }),
      });

      const request = {
        data: { inviteCode: 'ZZZZZZ' },
        auth: undefined,
      };

      await expect(previewGroup(request)).rejects.toThrow();
    });
  });
});

// ============================================================================
// joinGroup 테스트
// ============================================================================

describe('joinGroup', () => {
  let joinGroup: any;
  let mockFirestore: any;
  let mockTransaction: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    const mockGroupData = {
      name: '테스트 그룹',
      imageUrl: 'https://example.com/group.jpg',
      maxMembers: 10,
      memberIds: ['user1', 'user2'],
      inviteCode: 'ABC123',
    };

    mockTransaction = {
      update: jest.fn(),
      set: jest.fn(),
    };

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === 'groups') {
          return {
            where: jest.fn().mockReturnValue({
              limit: jest.fn().mockReturnValue({
                get: jest.fn().mockResolvedValue({
                  empty: false,
                  docs: [{
                    id: 'group-id',
                    data: () => mockGroupData,
                    ref: { id: 'group-id' },
                  }],
                } as any),
              }),
            }),
          };
        }
        if (name === 'users') {
          return {
            doc: jest.fn().mockReturnValue({ id: 'user-id' }),
          };
        }
        return {};
      }),
      runTransaction: jest.fn(async (callback: any) => {
        await callback(mockTransaction);
      }),
    };

    const {admin: configAdmin} = await import('../src/config');
    jest.spyOn(configAdmin, 'firestore').mockReturnValue(mockFirestore as any);

    const functions = await import('../src/functions/groups');
    joinGroup = functions.joinGroup;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: Firestore 트랜잭션을 mock 처리한 정상 플로우 유닛 테스트
  describe('정상 케이스', () => {
    it('유효한 초대 코드로 그룹에 참여한다', async () => {
      const request = {
        data: { inviteCode: 'ABC123' },
        auth: { uid: 'new-user-id' },
      };

      const handler = (joinGroup as any).run;
      const result = await handler(request);

      expect(result).toBeDefined();
      expect(result.groupId).toBe('group-id');
      expect(result.groupName).toBe('테스트 그룹');
      expect(mockTransaction.update).toHaveBeenCalled();
      expect(mockTransaction.set).toHaveBeenCalled();
    });
  });

  describe('인증 에러', () => {
    it('인증 없이 호출 시 에러를 발생시킨다', async () => {
      const request = {
        data: { inviteCode: 'ABC123' },
        auth: undefined,
      };

      await expect(joinGroup(request)).rejects.toThrow();
    });
  });

  describe('유효성 검사 에러', () => {
    it('초대 코드가 6자리가 아니면 에러를 발생시킨다', async () => {
      const request = {
        data: { inviteCode: 'ABC' },
        auth: { uid: 'user-id' },
      };

      await expect(joinGroup(request)).rejects.toThrow();
    });
  });

  describe('이미 참여한 멤버', () => {
    it('이미 참여한 그룹이면 already-exists 에러를 발생시킨다', async () => {
      // user1 is already a member
      const request = {
        data: { inviteCode: 'ABC123' },
        auth: { uid: 'user1' },
      };

      await expect(joinGroup(request)).rejects.toThrow();
    });
  });

  describe('정원 초과', () => {
    it('그룹 정원이 초과되면 resource-exhausted 에러를 발생시킨다', async () => {
      // Mock full group
      const fullGroupData = {
        name: '가득 찬 그룹',
        maxMembers: 2,
        memberIds: ['user1', 'user2'], // Already at max
        inviteCode: 'FULL00',
      };

      mockFirestore.collection = jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            get: jest.fn().mockResolvedValue({
              empty: false,
              docs: [{
                id: 'full-group-id',
                data: () => fullGroupData,
                ref: { id: 'full-group-id' },
              }],
            } as any),
          }),
        }),
      });

      const request = {
        data: { inviteCode: 'FULL00' },
        auth: { uid: 'new-user' },
      };

      await expect(joinGroup(request)).rejects.toThrow();
    });
  });
});

// ============================================================================
// leaveGroup 테스트
// ============================================================================

describe('leaveGroup', () => {
  let leaveGroup: any;
  let mockFirestore: any;
  let mockTransaction: any;
  let mockGroupRef: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    const mockGroupData = {
      name: '테스트 그룹',
      createdBy: 'host-user-id',
      memberIds: ['host-user-id', 'member-user-id', 'another-member'],
    };

    mockGroupRef = {
      id: 'test-group-id',
      get: jest.fn().mockResolvedValue(createMockDocument(true, mockGroupData) as any),
    };

    mockTransaction = {
      update: jest.fn(),
    };

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === 'groups') {
          return {
            doc: jest.fn().mockReturnValue(mockGroupRef),
          };
        }
        if (name === 'users') {
          return {
            doc: jest.fn().mockReturnValue({ id: 'user-id' }),
          };
        }
        return {};
      }),
      runTransaction: jest.fn(async (callback: any) => {
        await callback(mockTransaction);
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    const functions = await import('../src/functions/groups');
    leaveGroup = functions.leaveGroup;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: 정상 케이스는 실제 Firestore 트랜잭션이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('정상 케이스', () => {
    it('일반 멤버가 그룹을 나간다', async () => {
      const request = {
        data: { groupId: 'test-group-id' },
        auth: { uid: 'member-user-id' },
      };

      const result = await leaveGroup(request);

      expect(result).toBeDefined();
      expect(result.success).toBe(true);
      expect(mockTransaction.update).toHaveBeenCalled();
    });
  });

  describe('인증 에러', () => {
    it('인증 없이 호출 시 에러를 발생시킨다', async () => {
      const request = {
        data: { groupId: 'test-group-id' },
        auth: undefined,
      };

      await expect(leaveGroup(request)).rejects.toThrow();
    });
  });

  describe('유효성 검사 에러', () => {
    it('groupId가 없으면 에러를 발생시킨다', async () => {
      const request = {
        data: {},
        auth: { uid: 'user-id' },
      };

      await expect(leaveGroup(request)).rejects.toThrow();
    });

    it('빈 groupId는 에러를 발생시킨다', async () => {
      const request = {
        data: { groupId: '   ' },
        auth: { uid: 'user-id' },
      };

      await expect(leaveGroup(request)).rejects.toThrow();
    });
  });

  describe('not-found 에러', () => {
    it('존재하지 않는 그룹은 에러를 발생시킨다', async () => {
      mockGroupRef.get.mockResolvedValue(createMockDocument(false) as any);

      const request = {
        data: { groupId: 'nonexistent-group' },
        auth: { uid: 'user-id' },
      };

      await expect(leaveGroup(request)).rejects.toThrow();
    });
  });

  describe('권한 에러', () => {
    it('멤버가 아닌 사용자는 나갈 수 없다', async () => {
      const request = {
        data: { groupId: 'test-group-id' },
        auth: { uid: 'non-member-user-id' },
      };

      await expect(leaveGroup(request)).rejects.toThrow();
    });

    it('호스트는 그룹을 나갈 수 없다', async () => {
      const request = {
        data: { groupId: 'test-group-id' },
        auth: { uid: 'host-user-id' },
      };

      await expect(leaveGroup(request)).rejects.toThrow();
    });
  });
});

// ============================================================================
// updateGroup 테스트
// ============================================================================

describe('updateGroup', () => {
  let updateGroup: any;
  let mockFirestore: any;
  let mockGroupRef: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    const mockGroupData = {
      name: '테스트 그룹',
      description: '기존 설명',
      imageUrl: 'https://example.com/old.jpg',
      maxMembers: 10,
      createdBy: 'host-user-id',
      memberIds: ['host-user-id', 'member1', 'member2'],
    };

    mockGroupRef = {
      id: 'test-group-id',
      get: jest.fn().mockResolvedValue(createMockDocument(true, mockGroupData) as any),
      update: jest.fn().mockResolvedValue(undefined as any),
    };

    mockFirestore = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue(mockGroupRef),
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    const functions = await import('../src/functions/groups');
    updateGroup = functions.updateGroup;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: 정상 케이스는 실제 Firestore 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('정상 케이스', () => {
    it('호스트가 그룹 설명을 수정한다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          description: '새로운 설명',
        },
        auth: { uid: 'host-user-id' },
      };

      const result = await updateGroup(request);

      expect(result).toBeDefined();
      expect(result.success).toBe(true);
      expect(mockGroupRef.update).toHaveBeenCalled();
    });

    it('호스트가 그룹 이미지를 수정한다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          imageUrl: 'https://example.com/new.jpg',
        },
        auth: { uid: 'host-user-id' },
      };

      const result = await updateGroup(request);

      expect(result.success).toBe(true);
    });

    it('호스트가 최대 인원을 수정한다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          maxMembers: 20,
        },
        auth: { uid: 'host-user-id' },
      };

      const result = await updateGroup(request);

      expect(result.success).toBe(true);
    });
  });

  describe('인증 에러', () => {
    it('인증 없이 호출 시 에러를 발생시킨다', async () => {
      const request = {
        data: { groupId: 'test-group-id', description: '새 설명' },
        auth: undefined,
      };

      await expect(updateGroup(request)).rejects.toThrow();
    });
  });

  describe('권한 에러', () => {
    it('호스트가 아닌 멤버는 수정할 수 없다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          description: '새 설명',
        },
        auth: { uid: 'member1' },
      };

      await expect(updateGroup(request)).rejects.toThrow();
    });
  });

  describe('유효성 검사 에러', () => {
    it('현재 인원보다 작은 maxMembers는 에러를 발생시킨다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          maxMembers: 2, // 현재 멤버 3명보다 작음
        },
        auth: { uid: 'host-user-id' },
      };

      await expect(updateGroup(request)).rejects.toThrow();
    });
  });
});

// ============================================================================
// deleteGroup 테스트
// ============================================================================

describe('deleteGroup', () => {
  let deleteGroup: any;
  let mockFirestore: any;
  let mockStorage: any;
  let mockGroupRef: any;
  let mockTransaction: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    const mockGroupData = {
      name: '테스트 그룹',
      createdBy: 'host-user-id',
      memberIds: ['host-user-id', 'member1', 'member2'],
      imageUrl: 'https://firebasestorage.googleapis.com/v0/b/bucket/o/groups%2Ftest%2Fimage.jpg?alt=media',
    };

    mockGroupRef = {
      id: 'test-group-id',
      get: jest.fn().mockResolvedValue(createMockDocument(true, mockGroupData) as any),
    };

    mockTransaction = {
      delete: jest.fn(),
      update: jest.fn(),
    };

    const mockBatch = {
      delete: jest.fn(),
      commit: jest.fn().mockResolvedValue(undefined as any),
    };

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === 'groups') {
          return {
            doc: jest.fn().mockReturnValue(mockGroupRef),
          };
        }
        if (name === 'users') {
          return {
            doc: jest.fn().mockReturnValue({ id: 'user-id' }),
          };
        }
        if (name === 'promises') {
          return {
            where: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue(createMockQuerySnapshot([
                { id: 'promise1', data: {} },
                { id: 'promise2', data: {} },
              ]) as any),
            }),
          };
        }
        return {};
      }),
      runTransaction: jest.fn(async (callback: any) => {
        await callback(mockTransaction);
      }),
      batch: jest.fn().mockReturnValue(mockBatch),
    };

    mockStorage = {
      bucket: jest.fn().mockReturnValue({
        file: jest.fn().mockReturnValue({
          delete: jest.fn().mockResolvedValue(undefined as any),
        }),
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);
    jest.spyOn(admin, 'storage').mockReturnValue(mockStorage as any);

    const functions = await import('../src/functions/groups');
    deleteGroup = functions.deleteGroup;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: 정상 케이스는 실제 Firestore/Storage 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('정상 케이스', () => {
    it('호스트가 그룹을 삭제한다', async () => {
      const request = {
        data: { groupId: 'test-group-id' },
        auth: { uid: 'host-user-id' },
      };

      const result = await deleteGroup(request);

      expect(result).toBeDefined();
      expect(result.success).toBe(true);
      expect(mockTransaction.delete).toHaveBeenCalled();
    });

    it('그룹 삭제 시 Storage 이미지도 삭제된다', async () => {
      const request = {
        data: { groupId: 'test-group-id' },
        auth: { uid: 'host-user-id' },
      };

      await deleteGroup(request);

      expect(mockStorage.bucket).toHaveBeenCalled();
    });

    it('그룹 삭제 시 관련 약속도 삭제된다', async () => {
      const request = {
        data: { groupId: 'test-group-id' },
        auth: { uid: 'host-user-id' },
      };

      await deleteGroup(request);

      expect(mockFirestore.batch).toHaveBeenCalled();
    });
  });

  describe('인증 에러', () => {
    it('인증 없이 호출 시 에러를 발생시킨다', async () => {
      const request = {
        data: { groupId: 'test-group-id' },
        auth: undefined,
      };

      await expect(deleteGroup(request)).rejects.toThrow();
    });
  });

  describe('권한 에러', () => {
    it('호스트가 아닌 멤버는 삭제할 수 없다', async () => {
      const request = {
        data: { groupId: 'test-group-id' },
        auth: { uid: 'member1' },
      };

      await expect(deleteGroup(request)).rejects.toThrow();
    });
  });

  describe('not-found 에러', () => {
    it('존재하지 않는 그룹은 에러를 발생시킨다', async () => {
      mockGroupRef.get.mockResolvedValue(createMockDocument(false) as any);

      const request = {
        data: { groupId: 'nonexistent-group' },
        auth: { uid: 'host-user-id' },
      };

      await expect(deleteGroup(request)).rejects.toThrow();
    });
  });

  // NOTE: Storage mock이 Firebase Functions v2 내부에서 제대로 작동하지 않아 skip
  describe.skip('Storage 오류 복구', () => {
    it('이미지 삭제 실패해도 그룹 삭제는 계속 진행된다', async () => {
      mockStorage.bucket = jest.fn().mockReturnValue({
        file: jest.fn().mockReturnValue({
          delete: jest.fn().mockRejectedValue(new Error('Storage error') as any),
        }),
      });

      const request = {
        data: { groupId: 'test-group-id' },
        auth: { uid: 'host-user-id' },
      };

      // 에러가 발생하지 않고 성공해야 함
      const result = await deleteGroup(request);
      expect(result.success).toBe(true);
    });
  });
});

// ============================================================================
// transferGroupHost 테스트
// ============================================================================

describe('transferGroupHost', () => {
  let transferGroupHost: any;
  let mockFirestore: any;
  let mockTransaction: any;
  let mockGroupRef: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    const mockGroupData = {
      name: '테스트 그룹',
      createdBy: 'current-host-id',
      memberIds: ['current-host-id', 'new-host-id', 'member3'],
    };

    mockGroupRef = {
      id: 'test-group-id',
    };

    const mockGroupDoc = createMockDocument(true, mockGroupData);

    mockTransaction = {
      get: jest.fn().mockResolvedValue(mockGroupDoc as any),
      update: jest.fn(),
    };

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === 'groups') {
          return {
            doc: jest.fn().mockReturnValue(mockGroupRef),
          };
        }
        if (name === 'users') {
          return {
            doc: jest.fn().mockReturnValue({ id: 'user-id' }),
          };
        }
        return {};
      }),
      runTransaction: jest.fn(async (callback: any) => {
        return await callback(mockTransaction);
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    const functions = await import('../src/functions/groups');
    transferGroupHost = functions.transferGroupHost;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: 정상 케이스는 실제 Firestore 트랜잭션이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('정상 케이스', () => {
    it('현재 호스트가 다른 멤버에게 호스트를 양도한다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          newHostId: 'new-host-id',
        },
        auth: { uid: 'current-host-id' },
      };

      const result = await transferGroupHost(request);

      expect(result).toBeDefined();
      expect(result.success).toBe(true);
      expect(mockTransaction.update).toHaveBeenCalledTimes(3); // group, old host, new host
    });
  });

  describe('인증 에러', () => {
    it('인증 없이 호출 시 에러를 발생시킨다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          newHostId: 'new-host-id',
        },
        auth: undefined,
      };

      await expect(transferGroupHost(request)).rejects.toThrow();
    });
  });

  describe('유효성 검사 에러', () => {
    it('groupId가 없으면 에러를 발생시킨다', async () => {
      const request = {
        data: { newHostId: 'new-host-id' },
        auth: { uid: 'current-host-id' },
      };

      await expect(transferGroupHost(request)).rejects.toThrow();
    });

    it('newHostId가 없으면 에러를 발생시킨다', async () => {
      const request = {
        data: { groupId: 'test-group-id' },
        auth: { uid: 'current-host-id' },
      };

      await expect(transferGroupHost(request)).rejects.toThrow();
    });

    it('자기 자신에게 양도할 수 없다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          newHostId: 'current-host-id',
        },
        auth: { uid: 'current-host-id' },
      };

      await expect(transferGroupHost(request)).rejects.toThrow();
    });

    it('groupId에 dot(.)이 포함되면 에러를 발생시킨다 (Field Path Injection 방지)', async () => {
      const request = {
        data: {
          groupId: 'invalid.group.id',
          newHostId: 'new-host-id',
        },
        auth: { uid: 'current-host-id' },
      };

      await expect(transferGroupHost(request)).rejects.toThrow();
    });
  });

  describe('권한 에러', () => {
    it('호스트가 아닌 멤버는 양도할 수 없다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          newHostId: 'new-host-id',
        },
        auth: { uid: 'member3' }, // Not the host
      };

      await expect(transferGroupHost(request)).rejects.toThrow();
    });
  });

  describe('멤버 검증 에러', () => {
    it('그룹 멤버가 아닌 사용자에게 양도할 수 없다', async () => {
      const request = {
        data: {
          groupId: 'test-group-id',
          newHostId: 'non-member-id',
        },
        auth: { uid: 'current-host-id' },
      };

      await expect(transferGroupHost(request)).rejects.toThrow();
    });
  });
});

// ============================================================================
// onGroupImageUpdated 트리거 테스트
// ============================================================================
// NOTE: Firestore 트리거 테스트는 실제 에뮬레이터 환경에서만 동작합니다.
// 에뮬레이터 없이 실행 시 skip 처리됩니다.

describe.skip('onGroupImageUpdated', () => {
  let onGroupImageUpdated: any;
  let mockFirestore: any;
  let mockBatch: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    mockBatch = {
      update: jest.fn(),
      commit: jest.fn().mockResolvedValue(undefined as any),
    };

    mockFirestore = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({ id: 'user-id' }),
      }),
      batch: jest.fn().mockReturnValue(mockBatch),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    const functions = await import('../src/functions/groups');
    onGroupImageUpdated = functions.onGroupImageUpdated;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  describe('정상 케이스', () => {
    it('이미지 URL이 변경되면 모든 멤버의 캐시를 업데이트한다', async () => {
      const event = {
        data: {
          before: {
            data: () => ({
              imageUrl: 'https://example.com/old.jpg',
              memberIds: ['user1', 'user2', 'user3'],
            }),
          },
          after: {
            data: () => ({
              imageUrl: 'https://example.com/new.jpg',
              memberIds: ['user1', 'user2', 'user3'],
            }),
          },
        },
        params: {
          groupId: 'test-group-id',
        },
      };

      // Trigger는 wrapped function 반환
      const handler = onGroupImageUpdated.run;
      if (handler) {
        await handler(event);
        expect(mockBatch.update).toHaveBeenCalledTimes(3);
        expect(mockBatch.commit).toHaveBeenCalled();
      }
    });
  });

  describe('변경 없음', () => {
    it('이미지 URL이 동일하면 업데이트하지 않는다', async () => {
      const event = {
        data: {
          before: {
            data: () => ({
              imageUrl: 'https://example.com/same.jpg',
              memberIds: ['user1', 'user2'],
            }),
          },
          after: {
            data: () => ({
              imageUrl: 'https://example.com/same.jpg',
              memberIds: ['user1', 'user2'],
            }),
          },
        },
        params: {
          groupId: 'test-group-id',
        },
      };

      const handler = onGroupImageUpdated.run;
      if (handler) {
        await handler(event);
        expect(mockBatch.update).not.toHaveBeenCalled();
      }
    });
  });

  describe('빈 멤버', () => {
    it('멤버가 없으면 업데이트하지 않는다', async () => {
      const event = {
        data: {
          before: {
            data: () => ({
              imageUrl: 'https://example.com/old.jpg',
              memberIds: [],
            }),
          },
          after: {
            data: () => ({
              imageUrl: 'https://example.com/new.jpg',
              memberIds: [],
            }),
          },
        },
        params: {
          groupId: 'test-group-id',
        },
      };

      const handler = onGroupImageUpdated.run;
      if (handler) {
        await handler(event);
        expect(mockBatch.commit).not.toHaveBeenCalled();
      }
    });
  });
});

// ============================================================================
// 초대 코드 생성 유틸리티 테스트
// ============================================================================

describe('generateUniqueInviteCode', () => {
  let generateUniqueInviteCode: any;
  let randomInviteCode: any;
  let mockFirestore: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    mockFirestore = {
      collection: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            get: jest.fn()
              .mockResolvedValueOnce({ empty: false } as any) // 첫 번째 시도: 중복
              .mockResolvedValueOnce({ empty: false } as any) // 두 번째 시도: 중복
              .mockResolvedValueOnce({ empty: true } as any), // 세 번째 시도: 성공
          }),
        }),
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    const helpers = await import('../src/utils/helpers');
    generateUniqueInviteCode = helpers.generateUniqueInviteCode;
    randomInviteCode = helpers.randomInviteCode;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  describe('randomInviteCode', () => {
    it('지정된 길이의 코드를 생성한다', () => {
      const code = randomInviteCode(6);
      expect(code.length).toBe(6);
    });

    it('대문자와 숫자만 포함한다', () => {
      const code = randomInviteCode(10);
      expect(code).toMatch(/^[A-Z0-9]+$/);
    });
  });

  describe('generateUniqueInviteCode', () => {
    it('중복되지 않는 코드가 나올 때까지 재시도한다', async () => {
      const code = await generateUniqueInviteCode({
        db: mockFirestore,
        length: 6,
        maxAttempts: 5,
      });

      expect(code).toBeDefined();
      expect(code.length).toBe(6);
    });

    it('최대 시도 횟수 초과 시 에러를 발생시킨다', async () => {
      // 모든 시도가 중복인 경우
      mockFirestore.collection = jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            get: jest.fn().mockResolvedValue({ empty: false } as any),
          }),
        }),
      });

      await expect(
        generateUniqueInviteCode({
          db: mockFirestore,
          length: 6,
          maxAttempts: 3,
        })
      ).rejects.toThrow();
    });
  });
});
