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

const sendPushNotificationInternalMock = jest.fn();

jest.mock("firebase-functions/params", () => ({
  defineSecret: jest.fn(() => ({
    value: () => "test-secret-value",
  })),
}));

jest.mock("../src/functions/notifications", () => ({
  sendPushNotificationInternal: (...args: unknown[]) =>
    sendPushNotificationInternalMock(...args),
}));

function createMockDocument(
  id: string,
  dataMap: Map<string, Record<string, unknown>>,
): any {
  const data = dataMap.get(id);
  return {
    id,
    exists: Boolean(data),
    data: () => data,
  };
}

describe("admin functions", () => {
  let getAdminSession: any;
  let getAdminUserSummary: any;
  let grantEntitlementOverride: any;
  let revokeEntitlementOverride: any;
  let sendAdminPush: any;

  let adminUsersData: Map<string, Record<string, unknown>>;
  let usersData: Map<string, Record<string, unknown>>;
  let subscriptionData: Map<string, Record<string, unknown>>;
  let overrideData: Map<string, Record<string, unknown>>;
  let auditLogAdds: Record<string, unknown>[];
  let adminPushJobDocs: Record<string, unknown>[];

  beforeEach(async () => {
    jest.clearAllMocks();
    sendPushNotificationInternalMock.mockResolvedValue({
      success: true,
      successCount: 1,
      failureCount: 0,
    });

    adminUsersData = new Map();
    usersData = new Map();
    subscriptionData = new Map();
    overrideData = new Map();
    auditLogAdds = [];
    adminPushJobDocs = [];

    const mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === "adminUsers") {
          return {
            doc: jest.fn((id: string) => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(id, adminUsersData)
              ),
            })),
          };
        }

        if (name === "users") {
          return {
            doc: jest.fn((id: string) => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(id, usersData)
              ),
            })),
            where: jest.fn((field: string, _operator: string, value: string) => ({
              limit: jest.fn(() => ({
                get: jest.fn().mockResolvedValue({
                  docs: [...usersData.entries()]
                    .filter(([, data]) => data[field] === value)
                    .map(([id]) => createMockDocument(id, usersData)),
                }),
              })),
            })),
            get: jest.fn().mockResolvedValue({
              docs: [...usersData.keys()].map((id) => createMockDocument(id, usersData)),
            }),
          };
        }

        if (name === "subscriptions") {
          return {
            doc: jest.fn((id: string) => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(id, subscriptionData)
              ),
            })),
          };
        }

        if (name === "entitlementOverrides") {
          return {
            doc: jest.fn((id: string) => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(id, overrideData)
              ),
              set: jest.fn(async (data: Record<string, unknown>) => {
                const previous = overrideData.get(id) ?? {};
                overrideData.set(id, {
                  ...previous,
                  ...data,
                });
              }),
            })),
          };
        }

        if (name === "adminAuditLogs") {
          return {
            add: jest.fn(async (data: Record<string, unknown>) => {
              auditLogAdds.push(data);
              return {id: `log-${auditLogAdds.length}`};
            }),
          };
        }

        if (name === "adminPushJobs") {
          return {
            add: jest.fn(async (data: Record<string, unknown>) => {
              adminPushJobDocs.push(data);
              const jobId = `job-${adminPushJobDocs.length}`;
              return {
                id: jobId,
                set: jest.fn(async (nextData: Record<string, unknown>) => {
                  adminPushJobDocs[adminPushJobDocs.length - 1] = {
                    ...adminPushJobDocs[adminPushJobDocs.length - 1],
                    ...nextData,
                  };
                }),
              };
            }),
          };
        }

        return {};
      }),
    };

    const {admin: configAdmin} = await import("../src/config");
    const firestoreSpy = jest.spyOn(configAdmin, "firestore").mockReturnValue(
      mockFirestore as any
    );
    (firestoreSpy as any).FieldValue = {
      serverTimestamp: jest.fn(() => "__server_timestamp__"),
    };
    (configAdmin.firestore as any).FieldValue = {
      serverTimestamp: jest.fn(() => "__server_timestamp__"),
    };

    const functions = await import("../src/functions/admin");
    getAdminSession = functions.getAdminSession;
    getAdminUserSummary = functions.getAdminUserSummary;
    grantEntitlementOverride = functions.grantEntitlementOverride;
    revokeEntitlementOverride = functions.revokeEntitlementOverride;
    sendAdminPush = functions.sendAdminPush;
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

  it("override를 부여하고 audit log를 남긴다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    usersData.set("target-user", {
      nickname: "kswift",
    });

    const handler = (grantEntitlementOverride as any).run;
    const result = await handler({
      data: {
        userId: "target-user",
        reason: "CS compensation",
        expiresAt: "2026-04-30T00:00:00.000Z",
      },
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(result).toEqual({success: true});
    expect(overrideData.get("target-user")).toEqual(expect.objectContaining({
      isActive: true,
      reason: "CS compensation",
      expiresAt: "2026-04-30T00:00:00.000Z",
      createdBy: "admin-user",
    }));
    expect(auditLogAdds).toHaveLength(1);
    expect(auditLogAdds[0]).toEqual(expect.objectContaining({
      actorId: "admin-user",
      action: "grant_entitlement_override",
      targetId: "target-user",
    }));
  });

  it("override를 회수하고 audit log를 남긴다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    overrideData.set("target-user", {
      isActive: true,
      reason: "CS compensation",
    });

    const handler = (revokeEntitlementOverride as any).run;
    const result = await handler({
      data: {
        userId: "target-user",
        reason: "benefit ended",
      },
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(result).toEqual({success: true});
    expect(overrideData.get("target-user")).toEqual(expect.objectContaining({
      isActive: false,
      revokedBy: "admin-user",
      revokedReason: "benefit ended",
    }));
    expect(auditLogAdds).toHaveLength(1);
    expect(auditLogAdds[0]).toEqual(expect.objectContaining({
      actorId: "admin-user",
      action: "revoke_entitlement_override",
      targetId: "target-user",
    }));
  });

  it("dry-run admin push는 발송 없이 대상 수만 계산한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    usersData.set("user-a", {nickname: "a"});
    usersData.set("user-b", {nickname: "b"});

    const handler = (sendAdminPush as any).run;
    const result = await handler({
      data: {
        title: "공지",
        body: "테스트",
        audience: "all",
        dryRun: true,
      },
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(result).toEqual({
      success: true,
      dryRun: true,
      targetCount: 2,
      successCount: 0,
      failureCount: 0,
      jobId: "job-1",
    });
    expect(sendPushNotificationInternalMock).not.toHaveBeenCalled();
    expect(adminPushJobDocs[0]).toEqual(expect.objectContaining({
      audience: "all",
      dryRun: true,
      targetCount: 2,
    }));
  });

  it("test user admin push는 시스템 푸시를 발송한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    usersData.set("target-user", {nickname: "kswift"});

    const handler = (sendAdminPush as any).run;
    const result = await handler({
      data: {
        title: "공지",
        body: "원하는 메시지",
        audience: "test_user",
        testUserId: "target-user",
      },
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(result).toEqual({
      success: true,
      dryRun: false,
      targetCount: 1,
      successCount: 1,
      failureCount: 0,
      jobId: "job-1",
    });
    expect(sendPushNotificationInternalMock).toHaveBeenCalledWith(
      expect.objectContaining({
        userIds: ["target-user"],
        title: "공지",
        body: "원하는 메시지",
      })
    );
  });
});
