// @ts-nocheck
/* eslint-disable @typescript-eslint/no-explicit-any */
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from "@jest/globals";

jest.mock("firebase-functions/params", () => ({
  defineSecret: jest.fn(() => ({
    value: () => "test-secret-value",
  })),
}));

function createMockDocument(
  exists: boolean,
  data?: Record<string, unknown>
): any {
  return {
    exists,
    data: () => data,
  };
}

describe("getAdminSession", () => {
  let getAdminSession: any;
  let getAdminUserSummary: any;
  let mockFirestore: any;
  let adminUsersData: Map<string, Record<string, unknown>>;
  let usersData: Map<string, Record<string, unknown>>;
  let subscriptionData: Map<string, Record<string, unknown>>;
  let overrideData: Map<string, Record<string, unknown>>;

  beforeEach(async () => {
    jest.clearAllMocks();

    adminUsersData = new Map();
    usersData = new Map();
    subscriptionData = new Map();
    overrideData = new Map();

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === "adminUsers") {
          return {
            doc: jest.fn((id: string) => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(adminUsersData.has(id), adminUsersData.get(id))
              ),
            })),
          };
        }
        if (name === "users") {
          return {
            doc: jest.fn((id: string) => ({
              get: jest.fn().mockResolvedValue(
                {
                  id,
                  ...createMockDocument(usersData.has(id), usersData.get(id)),
                }
              ),
            })),
            where: jest.fn((field: string, _operator: string, value: string) => ({
              limit: jest.fn(() => ({
                get: jest.fn().mockResolvedValue({
                  docs: [...usersData.entries()]
                    .filter(([, data]) => data[field] === value)
                    .map(([id, data]) => ({
                      id,
                      data: () => data,
                    })),
                }),
              })),
            })),
          };
        }
        if (name === "subscriptions") {
          return {
            doc: jest.fn((id: string) => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(
                  subscriptionData.has(id),
                  subscriptionData.get(id)
                )
              ),
            })),
          };
        }
        if (name === "entitlementOverrides") {
          return {
            doc: jest.fn((id: string) => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(overrideData.has(id), overrideData.get(id))
              ),
            })),
          };
        }
        return {};
      }),
    };

    const {admin: configAdmin} = await import("../src/config");
    jest.spyOn(configAdmin, "firestore").mockReturnValue(mockFirestore as any);

    const functions = await import("../src/functions/admin");
    getAdminSession = functions.getAdminSession;
    getAdminUserSummary = functions.getAdminUserSummary;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  it("인증되지 않은 사용자는 unauthenticated", async () => {
    const handler = (getAdminSession as any).run;

    await expect(handler({data: {}, auth: null})).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  it("활성 관리자면 세션 정보를 반환한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
      email: "admin@promiso.app",
    });

    const handler = (getAdminSession as any).run;
    const result = await handler({
      data: {},
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(result).toEqual({
      success: true,
      userId: "admin-user",
      email: "admin@promiso.app",
      role: "owner",
      enabled: true,
    });
  });

  it("관리자 문서가 없으면 permission-denied", async () => {
    const handler = (getAdminSession as any).run;

    await expect(handler({
      data: {},
      auth: {
        uid: "non-admin",
        token: {
          email: "user@promiso.app",
        },
      },
    })).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("검색어가 비어 있으면 invalid-argument", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });

    const handler = (getAdminUserSummary as any).run;

    await expect(handler({
      data: {query: "   "},
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    })).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  it("userId로 검색하면 요약 정보를 반환한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
      email: "admin@promiso.app",
    });
    usersData.set("target-user", {
      name: "성원",
      nickname: "kswift",
      email: "kswen@promiso.app",
      groups: {
        g1: {role: "admin"},
        g2: {role: "member"},
      },
      devices: {
        d1: {platform: "ios"},
        d2: {platform: "ios"},
      },
    });
    subscriptionData.set("target-user", {
      status: "subscribed",
    });
    overrideData.set("target-user", {
      isActive: true,
    });

    const handler = (getAdminUserSummary as any).run;
    const result = await handler({
      data: {query: "target-user"},
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(result).toEqual({
      success: true,
      results: [{
        userId: "target-user",
        name: "성원",
        nickname: "kswift",
        email: "kswen@promiso.app",
        groupCount: 2,
        deviceCount: 2,
        subscriptionStatus: "subscribed",
        overrideActive: true,
      }],
    });
  });
});
