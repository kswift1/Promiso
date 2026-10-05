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

const getAdminAnalyticsSummaryDataMock = jest.fn();

jest.mock("../src/utils/adminAnalytics", () => ({
  getAdminAnalyticsSummaryData: (...args: unknown[]) =>
    getAdminAnalyticsSummaryDataMock(...args),
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
  let getAdminDashboardSummary: any;
  let getAdminAnalyticsSummary: any;
  let getAdminAuditLogs: any;
  let getAdminUsers: any;
  let createAdminUser: any;
  let updateAdminUser: any;
  let getAdminUserSummary: any;
  let getAdminUserTimeline: any;
  let getAdminReleaseControls: any;
  let grantEntitlementOverride: any;
  let revokeEntitlementOverride: any;
  let updateAdminReleaseControls: any;

  let adminUsersData: Map<string, Record<string, unknown>>;
  let authUsersByEmail: Map<string, {uid: string; email: string | null}>;
  let usersData: Map<string, Record<string, unknown>>;
  let subscriptionData: Map<string, Record<string, unknown>>;
  let overrideData: Map<string, Record<string, unknown>>;
  let auditLogAdds: Record<string, unknown>[];
  let adminAuditLogQueryCalls: Array<{
    field: string;
    operator: string;
    value: unknown;
  }>;
  let remoteConfigTemplate: Record<string, any>;

  beforeEach(async () => {
    jest.clearAllMocks();
    jest.spyOn(Date, "now").mockReturnValue(
      new Date("2026-03-13T00:00:00.000Z").getTime()
    );
    getAdminAnalyticsSummaryDataMock.mockResolvedValue({
      windowDays: 7,
      ga4: {
        available: true,
        note: null,
        signups: 10,
        logins: 20,
        paywallOpens: 7,
        paywallPurchases: 3,
      },
      bigQuery: {
        available: true,
        note: null,
        signups: 8,
        paywallOpens: 6,
        paywallPurchases: 2,
      },
    });

    adminUsersData = new Map();
    authUsersByEmail = new Map();
    usersData = new Map();
    subscriptionData = new Map();
    overrideData = new Map();
    auditLogAdds = [];
    adminAuditLogQueryCalls = [];
    remoteConfigTemplate = {
      parameters: {},
      parameterGroups: {
        "version-control": {
          parameters: {
            forceUpdateVersion: {
              defaultValue: {value: "1.0.0"},
            },
            recommendedVersion: {
              defaultValue: {value: "1.1.0"},
            },
            appStoreURL: {
              defaultValue: {value: "https://apps.apple.com/kr/app/id6757733720"},
            },
          },
        },
        "leagal-policies": {
          parameters: {
            privacyPolicyURL: {
              defaultValue: {value: "https://example.com/privacy"},
            },
            termsOfServiceURL: {
              defaultValue: {value: "https://example.com/terms"},
            },
          },
        },
        "customer-support": {
          parameters: {
            supportEmail: {
              defaultValue: {value: "support@promiso.app"},
            },
            notionFAQDatabaseId: {
              defaultValue: {value: "faq-database-id"},
            },
          },
        },
      },
      version: {
        versionNumber: "12",
        updateTime: "2026-03-13T00:00:00.000Z",
        updateUser: {
          email: "admin@promiso.app",
        },
      },
    };

    const mockFirestore = {
      collection: jest.fn((name: string) => {
        const adminSubcollections: Record<string, () => any> = {
          "users": () => ({
            doc: jest.fn((id: string) => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(id, adminUsersData)
              ),
              set: jest.fn(async (data: Record<string, unknown>) => {
                const previous = adminUsersData.get(id) ?? {};
                adminUsersData.set(id, {
                  ...previous,
                  ...data,
                });
              }),
            })),
            get: jest.fn().mockResolvedValue({
              docs: [...adminUsersData.keys()].map((id) =>
                createMockDocument(id, adminUsersData)
              ),
            }),
          }),
          "auditLogs": () => {
            const buildAuditLogDocs = (
              filters: Array<{field: string; operator: string; value: unknown}> = [],
              limit?: number,
            ) => {
              let docs = auditLogAdds
                .map((data, index) => ({
                  id: `log-${index + 1}`,
                  data: () => data,
                }))
                .reverse()
                .filter((doc) =>
                  filters.every(({field, operator, value}) => {
                    const data = doc.data();

                    if (operator === "==") {
                      return data[field] === value;
                    }

                    return false;
                  })
                );

              if (typeof limit === "number") {
                docs = docs.slice(0, limit);
              }

              return docs;
            };

            const createAuditLogQuery = (
              filters: Array<{field: string; operator: string; value: unknown}> = [],
              limit?: number,
            ) => ({
              where: jest.fn((field: string, operator: string, value: unknown) => {
                adminAuditLogQueryCalls.push({field, operator, value});
                return createAuditLogQuery(
                  [...filters, {field, operator, value}],
                  limit
                );
              }),
              orderBy: jest.fn(() => createAuditLogQuery(filters, limit)),
              limit: jest.fn((nextLimit: number) =>
                createAuditLogQuery(filters, nextLimit)
              ),
              get: jest.fn().mockResolvedValue({
                docs: buildAuditLogDocs(filters, limit),
              }),
            });

            return {
              add: jest.fn(async (data: Record<string, unknown>) => {
                auditLogAdds.push(data);
                return {id: `log-${auditLogAdds.length}`};
              }),
              get: jest.fn().mockResolvedValue({
                docs: auditLogAdds.map((data, index) => ({
                  id: `log-${index + 1}`,
                  data: () => data,
                })),
              }),
              where: jest.fn((field: string, operator: string, value: unknown) => {
                adminAuditLogQueryCalls.push({field, operator, value});
                return createAuditLogQuery([{field, operator, value}]);
              }),
              orderBy: jest.fn(() => createAuditLogQuery()),
            };
          },
        };

        if (name === "admin") {
          return {
            doc: jest.fn((_id: string) => ({
              collection: jest.fn((subName: string) => {
                const handler = adminSubcollections[subName];
                if (handler) return handler();
                return {};
              }),
            })),
          };
        }

        if (name === "users") {
          return {
            doc: jest.fn((id: string) => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(id, usersData)
              ),
              collection: jest.fn(() => ({
                count: jest.fn(() => ({
                  get: jest.fn().mockResolvedValue({
                    data: () => ({count: 0}),
                  }),
                })),
              })),
            })),
            orderBy: jest.fn(() => ({
              startAfter: jest.fn(() => ({
                limit: jest.fn((limitValue: number) => ({
                  get: jest.fn().mockResolvedValue({
                    docs: [...usersData.keys()]
                      .sort()
                      .slice(0, limitValue)
                      .map((id) => createMockDocument(id, usersData)),
                  }),
                })),
              })),
              limit: jest.fn((limitValue: number) => ({
                get: jest.fn().mockResolvedValue({
                  docs: [...usersData.keys()]
                    .sort()
                    .slice(0, limitValue)
                    .map((id) => createMockDocument(id, usersData)),
                }),
              })),
            })),
            limit: jest.fn((limitValue: number) => ({
              get: jest.fn().mockResolvedValue({
                docs: [...usersData.keys()]
                  .slice(0, limitValue)
                  .map((id) => createMockDocument(id, usersData)),
              }),
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
            get: jest.fn().mockResolvedValue({
              docs: [...overrideData.keys()].map((id) =>
                createMockDocument(id, overrideData)
              ),
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
    jest.spyOn(configAdmin, "auth").mockReturnValue({
      getUserByEmail: jest.fn(async (email: string) => {
        const authUser = authUsersByEmail.get(email.toLowerCase());

        if (!authUser) {
          const error = new Error("User not found");
          (error as any).code = "auth/user-not-found";
          throw error;
        }

        return authUser;
      }),
    } as any);
    jest.spyOn(configAdmin, "remoteConfig").mockReturnValue({
      getTemplate: jest.fn(async () => structuredClone(remoteConfigTemplate)),
      publishTemplate: jest.fn(async (template: Record<string, any>) => {
        remoteConfigTemplate = {
          ...structuredClone(template),
          version: {
            versionNumber: "13",
            updateTime: "2026-03-13T01:00:00.000Z",
            updateUser: {
              email: "admin@promiso.app",
            },
          },
        };
        return structuredClone(remoteConfigTemplate);
      }),
    } as any);
    (firestoreSpy as any).FieldValue = {
      serverTimestamp: jest.fn(() => "__server_timestamp__"),
    };
    (configAdmin.firestore as any).FieldValue = {
      serverTimestamp: jest.fn(() => "__server_timestamp__"),
    };
    (firestoreSpy as any).FieldPath = {
      documentId: jest.fn(() => "__document_id__"),
    };
    (configAdmin.firestore as any).FieldPath = {
      documentId: jest.fn(() => "__document_id__"),
    };

    const functions = await import("../src/functions/admin");
    getAdminSession = functions.getAdminSession;
    getAdminDashboardSummary = functions.getAdminDashboardSummary;
    getAdminAnalyticsSummary = functions.getAdminAnalyticsSummary;
    getAdminAuditLogs = functions.getAdminAuditLogs;
    getAdminUsers = functions.getAdminUsers;
    createAdminUser = functions.createAdminUser;
    updateAdminUser = functions.updateAdminUser;
    getAdminUserSummary = functions.getAdminUserSummary;
    getAdminUserTimeline = functions.getAdminUserTimeline;
    getAdminReleaseControls = functions.getAdminReleaseControls;
    grantEntitlementOverride = functions.grantEntitlementOverride;
    revokeEntitlementOverride = functions.revokeEntitlementOverride;
    updateAdminReleaseControls = functions.updateAdminReleaseControls;
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

  it("owner는 admin 사용자 목록을 조회할 수 있다", async () => {
    adminUsersData.set("owner-user", {
      role: "owner",
      enabled: true,
      email: "owner@promiso.app",
    });
    adminUsersData.set("support-user", {
      role: "support",
      enabled: true,
      email: "support@promiso.app",
    });
    adminUsersData.set("marketer-user", {
      role: "marketer",
      enabled: false,
      email: "marketer@promiso.app",
    });

    const handler = (getAdminUsers as any).run;
    const result = await handler({
      data: {},
      auth: {
        uid: "owner-user",
        token: {
          email: "owner@promiso.app",
        },
      },
    });

    expect(result).toEqual({
      success: true,
      users: [
        {
          userId: "owner-user",
          email: "owner@promiso.app",
          role: "owner",
          enabled: true,
        },
        {
          userId: "support-user",
          email: "support@promiso.app",
          role: "support",
          enabled: true,
        },
        {
          userId: "marketer-user",
          email: "marketer@promiso.app",
          role: "marketer",
          enabled: false,
        },
      ],
    });
  });

  it("support는 admin 사용자 목록을 조회할 수 없다", async () => {
    adminUsersData.set("support-user", {
      role: "support",
      enabled: true,
      email: "support@promiso.app",
    });

    const handler = (getAdminUsers as any).run;

    await expect(handler({
      data: {},
      auth: {
        uid: "support-user",
        token: {
          email: "support@promiso.app",
        },
      },
    })).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("owner는 이메일 기준으로 admin 사용자를 등록할 수 있다", async () => {
    adminUsersData.set("owner-user", {
      role: "owner",
      enabled: true,
      email: "owner@promiso.app",
    });
    authUsersByEmail.set("new-admin@promiso.app", {
      uid: "new-admin-user",
      email: "new-admin@promiso.app",
    });

    const handler = (createAdminUser as any).run;
    const result = await handler({
      data: {
        email: "new-admin@promiso.app",
        role: "support",
        enabled: true,
      },
      auth: {
        uid: "owner-user",
        token: {
          email: "owner@promiso.app",
        },
      },
    });

    expect(result).toEqual({
      success: true,
      user: {
        userId: "new-admin-user",
        email: "new-admin@promiso.app",
        role: "support",
        enabled: true,
      },
    });
    expect(adminUsersData.get("new-admin-user")).toEqual({
      role: "support",
      email: "new-admin@promiso.app",
      enabled: true,
    });
    expect(auditLogAdds).toContainEqual(expect.objectContaining({
      actorId: "owner-user",
      action: "create_admin_user",
      targetType: "admin_user",
      targetId: "new-admin-user",
    }));
  });

  it("owner는 다른 admin 사용자의 role과 enabled를 수정할 수 있다", async () => {
    adminUsersData.set("owner-user", {
      role: "owner",
      enabled: true,
      email: "owner@promiso.app",
    });
    adminUsersData.set("target-admin", {
      role: "support",
      enabled: true,
      email: "target@promiso.app",
    });

    const handler = (updateAdminUser as any).run;
    const result = await handler({
      data: {
        userId: "target-admin",
        role: "marketer",
        enabled: false,
      },
      auth: {
        uid: "owner-user",
        token: {
          email: "owner@promiso.app",
        },
      },
    });

    expect(result).toEqual({
      success: true,
      user: {
        userId: "target-admin",
        email: "target@promiso.app",
        role: "marketer",
        enabled: false,
      },
    });
    expect(adminUsersData.get("target-admin")).toEqual({
      role: "marketer",
      enabled: false,
      email: "target@promiso.app",
    });
    expect(auditLogAdds).toContainEqual(expect.objectContaining({
      actorId: "owner-user",
      action: "update_admin_user",
      targetType: "admin_user",
      targetId: "target-admin",
    }));
  });

  it("owner도 자기 자신을 비활성화할 수 없다", async () => {
    adminUsersData.set("owner-user", {
      role: "owner",
      enabled: true,
      email: "owner@promiso.app",
    });
    adminUsersData.set("other-owner", {
      role: "owner",
      enabled: true,
      email: "other@promiso.app",
    });

    const handler = (updateAdminUser as any).run;

    await expect(handler({
      data: {
        userId: "owner-user",
        role: "owner",
        enabled: false,
      },
      auth: {
        uid: "owner-user",
        token: {
          email: "owner@promiso.app",
        },
      },
    })).rejects.toMatchObject({
      code: "permission-denied",
      message: "자기 자신의 owner 권한을 해제하거나 비활성화할 수 없습니다",
    });
  });

  it("owner도 자기 자신의 role을 owner 외로 바꿀 수 없다", async () => {
    adminUsersData.set("owner-user", {
      role: "owner",
      enabled: true,
      email: "owner@promiso.app",
    });
    adminUsersData.set("other-owner", {
      role: "owner",
      enabled: true,
      email: "other@promiso.app",
    });

    const handler = (updateAdminUser as any).run;

    await expect(handler({
      data: {
        userId: "owner-user",
        role: "support",
        enabled: true,
      },
      auth: {
        uid: "owner-user",
        token: {
          email: "owner@promiso.app",
        },
      },
    })).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("검색어와 필터가 비어 있으면 기본 사용자 요약을 반환한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    usersData.set("user-b", {
      nickname: "beta",
      email: "beta@promiso.app",
    });
    usersData.set("user-a", {
      nickname: "alpha",
      email: "alpha@promiso.app",
    });

    const handler = (getAdminUserSummary as any).run;
    const result = await handler({
      data: {query: "   "},
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(result).toEqual({
      success: true,
      hasMore: false,
      results: [
        {
          userId: "user-a",
          name: null,
          nickname: "alpha",
          email: "alpha@promiso.app",
          groupCount: 0,
          deviceCount: 0,
          personalEventCount: 0,
          subscriptionStatus: null,
          overrideActive: false,
        },
        {
          userId: "user-b",
          name: null,
          nickname: "beta",
          email: "beta@promiso.app",
          groupCount: 0,
          deviceCount: 0,
          personalEventCount: 0,
          subscriptionStatus: null,
          overrideActive: false,
        },
      ],
    });
  });

  it("상태 필터만으로도 사용자 요약을 조회할 수 있다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    usersData.set("user-a", {
      nickname: "alpha",
      email: "alpha@promiso.app",
    });
    usersData.set("user-b", {
      nickname: "beta",
      email: "beta@promiso.app",
    });
    subscriptionData.set("user-a", {
      status: "subscribed",
    });
    overrideData.set("user-a", {
      isActive: true,
    });

    const handler = (getAdminUserSummary as any).run;
    const result = await handler({
      data: {
        override: "active",
        subscription: "subscribed",
        limit: 25,
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
      hasMore: false,
      results: [{
        userId: "user-a",
        name: null,
        nickname: "alpha",
        email: "alpha@promiso.app",
        groupCount: 0,
        deviceCount: 0,
        personalEventCount: 0,
        subscriptionStatus: "subscribed",
        overrideActive: true,
      }],
    });
  });

  it("만료된 override는 사용자 요약에서 비활성으로 본다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    usersData.set("user-a", {
      nickname: "alpha",
      email: "alpha@promiso.app",
    });
    usersData.set("user-b", {
      nickname: "beta",
      email: "beta@promiso.app",
    });
    overrideData.set("user-a", {
      isActive: true,
      expiresAt: "2026-03-12T23:59:59.000Z",
    });
    overrideData.set("user-b", {
      isActive: true,
      expiresAt: "2026-03-14T00:00:00.000Z",
    });

    const handler = (getAdminUserSummary as any).run;
    const result = await handler({
      data: {
        override: "active",
        limit: 25,
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
      hasMore: false,
      results: [{
        userId: "user-b",
        name: null,
        nickname: "beta",
        email: "beta@promiso.app",
        groupCount: 0,
        deviceCount: 0,
        personalEventCount: 0,
        subscriptionStatus: null,
        overrideActive: true,
      }],
    });
  });

  it("marketer는 사용자 검색을 할 수 없다", async () => {
    adminUsersData.set("marketer-user", {
      role: "marketer",
      enabled: true,
    });

    const handler = (getAdminUserSummary as any).run;

    await expect(handler({
      data: {query: "target-user"},
      auth: {
        uid: "marketer-user",
        token: {
          email: "marketer@promiso.app",
        },
      },
    })).rejects.toMatchObject({
      code: "permission-denied",
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
      hasMore: false,
      results: [{
        userId: "target-user",
        name: "성원",
        nickname: "kswift",
        email: "kswen@promiso.app",
        groupCount: 2,
        deviceCount: 2,
        personalEventCount: 0,
        subscriptionStatus: "subscribed",
        overrideActive: true,
      }],
    });
  });

  it("user timeline을 현재 상태와 audit log로 반환한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    usersData.set("target-user", {
      name: "성원",
      nickname: "kswift",
      email: "kswen@promiso.app",
      groups: {
        g1: {role: "admin"},
      },
      devices: {
        d1: {platform: "ios"},
      },
    });
    subscriptionData.set("target-user", {
      status: "subscribed",
      productId: "promiso.pro.monthly",
      expirationDate: "2026-04-13T00:00:00.000Z",
      purchaseDate: "2026-03-13T00:00:00.000Z",
      updatedAt: {
        toDate: () => new Date("2026-03-13T03:00:00.000Z"),
      },
    });
    overrideData.set("target-user", {
      isActive: true,
      type: "manual_pro_grant",
      reason: "CS compensation",
      expiresAt: "2026-04-30T00:00:00.000Z",
      createdBy: "admin-user",
      createdAt: {
        toDate: () => new Date("2026-03-13T04:00:00.000Z"),
      },
      updatedAt: {
        toDate: () => new Date("2026-03-13T04:00:00.000Z"),
      },
    });
    auditLogAdds.push({
      actorId: "admin-user",
      action: "grant_entitlement_override",
      targetType: "user",
      targetId: "target-user",
      before: null,
      after: {isActive: true},
      createdAt: {
        toDate: () => new Date("2026-03-13T05:00:00.000Z"),
      },
    });
    auditLogAdds.push({
      actorId: "admin-user",
      action: "update_release_controls",
      targetType: "remote_config",
      targetId: "default",
      before: null,
      after: {recommendedVersion: "1.2.0"},
      createdAt: {
        toDate: () => new Date("2026-03-13T06:00:00.000Z"),
      },
    });

    const handler = (getAdminUserTimeline as any).run;
    const result = await handler({
      data: {
        userId: "target-user",
        limit: 20,
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
      summary: {
        userId: "target-user",
        name: "성원",
        nickname: "kswift",
        email: "kswen@promiso.app",
        groupCount: 1,
        deviceCount: 1,
        personalEventCount: 0,
        subscriptionStatus: "subscribed",
        overrideActive: true,
      },
      subscription: {
        status: "subscribed",
        productId: "promiso.pro.monthly",
        expirationDate: "2026-04-13T00:00:00.000Z",
        purchaseDate: "2026-03-13T00:00:00.000Z",
        updatedAt: "2026-03-13T03:00:00.000Z",
      },
      override: {
        isActive: true,
        type: "manual_pro_grant",
        reason: "CS compensation",
        expiresAt: "2026-04-30T00:00:00.000Z",
        createdBy: "admin-user",
        createdAt: "2026-03-13T04:00:00.000Z",
        revokedBy: null,
        revokedReason: null,
        revokedAt: null,
        updatedAt: "2026-03-13T04:00:00.000Z",
      },
      auditLogs: [
        {
          id: "log-1",
          actorId: "admin-user",
          action: "grant_entitlement_override",
          targetType: "user",
          targetId: "target-user",
          before: null,
          after: {isActive: true},
          createdAt: "2026-03-13T05:00:00.000Z",
        },
      ],
    });
    expect(adminAuditLogQueryCalls).toContainEqual({
      field: "targetId",
      operator: "==",
      value: "target-user",
    });
  });

  it("만료된 override는 timeline과 실효 Pro 판정에서 비활성으로 본다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    usersData.set("target-user", {
      nickname: "kswift",
      email: "kswen@promiso.app",
    });
    overrideData.set("target-user", {
      isActive: true,
      type: "manual_pro_grant",
      reason: "CS compensation",
      expiresAt: "2026-03-12T23:59:59.000Z",
      createdBy: "admin-user",
    });

    const timelineHandler = (getAdminUserTimeline as any).run;
    const timeline = await timelineHandler({
      data: {
        userId: "target-user",
      },
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(timeline.summary.overrideActive).toBe(false);
    expect(timeline.override?.isActive).toBe(false);

    const dashboardHandler = (getAdminDashboardSummary as any).run;
    const dashboard = await dashboardHandler({
      data: {},
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(dashboard.summary.proUsers).toBe(0);
    expect(dashboard.summary.activeOverrides).toBe(0);
  });

  it("marketer는 user timeline을 조회할 수 없다", async () => {
    adminUsersData.set("marketer-user", {
      role: "marketer",
      enabled: true,
    });

    const handler = (getAdminUserTimeline as any).run;

    await expect(handler({
      data: {
        userId: "target-user",
      },
      auth: {
        uid: "marketer-user",
        token: {
          email: "marketer@promiso.app",
        },
      },
    })).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("dashboard summary를 실데이터로 반환한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    adminUsersData.set("support-user", {
      role: "support",
      enabled: true,
    });
    usersData.set("user-a", {nickname: "a"});
    usersData.set("user-b", {nickname: "b"});
    subscriptionData.set("user-a", {
      status: "subscribed",
    });
    overrideData.set("user-b", {
      isActive: true,
    });
    auditLogAdds.push({
      actorId: "admin-user",
      action: "update_admin_user",
      createdAt: {
        toDate: () => new Date("2026-03-13T00:00:00.000Z"),
      },
    });

    const handler = (getAdminDashboardSummary as any).run;
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
      summary: {
        totalUsers: 2,
        proUsers: 2,
        freeUsers: 0,
        activeOverrides: 1,
        totalAdmins: 2,
        auditLogCount: 1,
        remoteConfigVersion: "12",
        remoteConfigUpdatedAt: "2026-03-13T00:00:00.000Z",
      },
    });
  });

  it("analytics summary를 조회한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    getAdminAnalyticsSummaryDataMock.mockResolvedValueOnce({
      windowDays: 30,
      ga4: {
        available: true,
        note: null,
        signups: 42,
        logins: 77,
        paywallOpens: 15,
        paywallPurchases: 5,
      },
      bigQuery: {
        available: true,
        note: null,
        signups: 33,
        paywallOpens: 12,
        paywallPurchases: 4,
      },
    });

    const handler = (getAdminAnalyticsSummary as any).run;
    const result = await handler({
      data: {windowDays: 30},
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(getAdminAnalyticsSummaryDataMock).toHaveBeenCalledWith(30);
    expect(result).toEqual({
      success: true,
      summary: {
        windowDays: 30,
        ga4: {
          available: true,
          note: null,
          signups: 42,
          logins: 77,
          paywallOpens: 15,
          paywallPurchases: 5,
        },
        bigQuery: {
          available: true,
          note: null,
          signups: 33,
          paywallOpens: 12,
          paywallPurchases: 4,
        },
      },
    });
  });

  it("analytics window가 없으면 기본값 7일을 사용한다", async () => {
    adminUsersData.set("support-user", {
      role: "support",
      enabled: true,
    });

    const handler = (getAdminAnalyticsSummary as any).run;
    await handler({
      data: {},
      auth: {
        uid: "support-user",
        token: {
          email: "support@promiso.app",
        },
      },
    });

    expect(getAdminAnalyticsSummaryDataMock).toHaveBeenCalledWith(7);
  });

  it("analytics window는 1/7/30일 preset만 허용한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });

    const handler = (getAdminAnalyticsSummary as any).run;
    await handler({
      data: {windowDays: 99},
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(getAdminAnalyticsSummaryDataMock).toHaveBeenCalledWith(7);
  });

  it("audit log를 최신순으로 조회한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    auditLogAdds.push({
      actorId: "owner-1",
      action: "grant_entitlement_override",
      targetType: "user",
      targetId: "user-a",
      before: null,
      after: {isActive: true},
      createdAt: {
        toDate: () => new Date("2026-03-13T00:00:00.000Z"),
      },
    });
    auditLogAdds.push({
      actorId: "owner-2",
      action: "update_release_controls",
      targetType: "remote_config",
      targetId: "default",
      before: {recommendedVersion: "1.0.0"},
      after: {recommendedVersion: "1.1.0"},
      createdAt: {
        toDate: () => new Date("2026-03-13T01:00:00.000Z"),
      },
    });

    const handler = (getAdminAuditLogs as any).run;
    const result = await handler({
      data: {limit: 10},
      auth: {
        uid: "admin-user",
        token: {
          email: "admin@promiso.app",
        },
      },
    });

    expect(result).toEqual({
      success: true,
      logs: [
        {
          id: "log-2",
          actorId: "owner-2",
          action: "update_release_controls",
          targetType: "remote_config",
          targetId: "default",
          before: {recommendedVersion: "1.0.0"},
          after: {recommendedVersion: "1.1.0"},
          createdAt: "2026-03-13T01:00:00.000Z",
        },
        {
          id: "log-1",
          actorId: "owner-1",
          action: "grant_entitlement_override",
          targetType: "user",
          targetId: "user-a",
          before: null,
          after: {isActive: true},
          createdAt: "2026-03-13T00:00:00.000Z",
        },
      ],
    });
  });

  it("audit log를 action과 actorId로 필터링한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });
    auditLogAdds.push({
      actorId: "owner-1",
      action: "grant_entitlement_override",
      targetType: "user",
      targetId: "user-a",
      before: null,
      after: {isActive: true},
      createdAt: {
        toDate: () => new Date("2026-03-13T00:00:00.000Z"),
      },
    });
    auditLogAdds.push({
      actorId: "owner-2",
      action: "grant_entitlement_override",
      targetType: "user",
      targetId: "user-b",
      before: null,
      after: {isActive: true},
      createdAt: {
        toDate: () => new Date("2026-03-13T01:00:00.000Z"),
      },
    });
    auditLogAdds.push({
      actorId: "owner-2",
      action: "update_release_controls",
      targetType: "remote_config",
      targetId: "default",
      before: {recommendedVersion: "1.0.0"},
      after: {recommendedVersion: "1.1.0"},
      createdAt: {
        toDate: () => new Date("2026-03-13T02:00:00.000Z"),
      },
    });

    const handler = (getAdminAuditLogs as any).run;
    const result = await handler({
      data: {
        action: "grant_entitlement_override",
        actorId: "owner-2",
        limit: 10,
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
      logs: [
        {
          id: "log-2",
          actorId: "owner-2",
          action: "grant_entitlement_override",
          targetType: "user",
          targetId: "user-b",
          before: null,
          after: {isActive: true},
          createdAt: "2026-03-13T01:00:00.000Z",
        },
      ],
    });
    expect(adminAuditLogQueryCalls).toContainEqual({
      field: "actorId",
      operator: "==",
      value: "owner-2",
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

  it("release controls를 조회한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });

    const handler = (getAdminReleaseControls as any).run;
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
      controls: expect.objectContaining({
        forceUpdateVersion: "1.0.0",
        recommendedVersion: "1.1.0",
        appStoreURL: "https://apps.apple.com/kr/app/id6757733720",
        privacyPolicyURL: "https://example.com/privacy",
        termsOfServiceURL: "https://example.com/terms",
        supportEmail: "support@promiso.app",
        notionFAQDatabaseId: "faq-database-id",
        versionNumber: "12",
        updateTime: "2026-03-13T00:00:00.000Z",
        updateUserEmail: "admin@promiso.app",
      }),
    });
    expect(result.controls.fields).toEqual(expect.arrayContaining([
      expect.objectContaining({
        key: "forceUpdateVersion",
        section: "version",
        valueType: "version",
        editableRoles: ["owner"],
      }),
      expect.objectContaining({
        key: "supportEmail",
        section: "support",
        valueType: "email",
        editableRoles: ["owner", "marketer"],
      }),
    ]));
  });

  it("support는 release controls를 조회할 수 없다", async () => {
    adminUsersData.set("support-user", {
      role: "support",
      enabled: true,
    });

    const handler = (getAdminReleaseControls as any).run;

    await expect(handler({
      data: {},
      auth: {
        uid: "support-user",
        token: {
          email: "support@promiso.app",
        },
      },
    })).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("marketer는 고객 노출 release controls를 수정할 수 있다", async () => {
    adminUsersData.set("marketer-user", {
      role: "marketer",
      enabled: true,
    });

    const handler = (updateAdminReleaseControls as any).run;
    const result = await handler({
      data: {
        forceUpdateVersion: "1.0.0",
        recommendedVersion: "1.1.0",
        appStoreURL: "https://apps.apple.com/kr/app/id6757733720",
        privacyPolicyURL: "https://promiso.app/privacy",
        termsOfServiceURL: "https://promiso.app/terms",
        supportEmail: "help@promiso.app",
        notionFAQDatabaseId: "marketer-faq-id",
      },
      auth: {
        uid: "marketer-user",
        token: {
          email: "marketer@promiso.app",
        },
      },
    });

    expect(result).toEqual({
      success: true,
      controls: expect.objectContaining({
        forceUpdateVersion: "1.0.0",
        recommendedVersion: "1.1.0",
        privacyPolicyURL: "https://promiso.app/privacy",
        termsOfServiceURL: "https://promiso.app/terms",
        supportEmail: "help@promiso.app",
        notionFAQDatabaseId: "marketer-faq-id",
        versionNumber: "13",
      }),
    });
    expect(auditLogAdds).toContainEqual(expect.objectContaining({
      actorId: "marketer-user",
      action: "update_release_controls",
      before: {
        privacyPolicyURL: "https://example.com/privacy",
        termsOfServiceURL: "https://example.com/terms",
        supportEmail: "support@promiso.app",
        notionFAQDatabaseId: "faq-database-id",
      },
      after: {
        privacyPolicyURL: "https://promiso.app/privacy",
        termsOfServiceURL: "https://promiso.app/terms",
        supportEmail: "help@promiso.app",
        notionFAQDatabaseId: "marketer-faq-id",
      },
    }));
  });

  it("marketer는 version release controls를 수정할 수 없다", async () => {
    adminUsersData.set("marketer-user", {
      role: "marketer",
      enabled: true,
    });

    const handler = (updateAdminReleaseControls as any).run;

    await expect(handler({
      data: {
        forceUpdateVersion: "1.2.0",
        recommendedVersion: "1.1.0",
        appStoreURL: "https://apps.apple.com/kr/app/id6757733720",
        privacyPolicyURL: "https://example.com/privacy",
        termsOfServiceURL: "https://example.com/terms",
        supportEmail: "support@promiso.app",
        notionFAQDatabaseId: "faq-database-id",
      },
      auth: {
        uid: "marketer-user",
        token: {
          email: "marketer@promiso.app",
        },
      },
    })).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("release controls version은 x.y.z 형식이어야 한다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });

    const handler = (updateAdminReleaseControls as any).run;

    await expect(handler({
      data: {
        forceUpdateVersion: "1.2",
        recommendedVersion: "1.2.1",
        appStoreURL: "https://apps.apple.com/kr/app/id6757733720",
        privacyPolicyURL: "https://promiso.app/privacy",
        termsOfServiceURL: "https://promiso.app/terms",
        supportEmail: "support@promiso.app",
        notionFAQDatabaseId: "updated-faq-id",
      },
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

  it("release controls를 수정하고 audit log를 남긴다", async () => {
    adminUsersData.set("admin-user", {
      role: "owner",
      enabled: true,
    });

    const handler = (updateAdminReleaseControls as any).run;
    const result = await handler({
      data: {
        forceUpdateVersion: "1.2.0",
        recommendedVersion: "1.2.1",
        appStoreURL: "https://apps.apple.com/kr/app/id6757733720",
        privacyPolicyURL: "https://promiso.app/privacy",
        termsOfServiceURL: "https://promiso.app/terms",
        supportEmail: "support@promiso.app",
        notionFAQDatabaseId: "updated-faq-id",
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
      controls: expect.objectContaining({
        forceUpdateVersion: "1.2.0",
        recommendedVersion: "1.2.1",
        appStoreURL: "https://apps.apple.com/kr/app/id6757733720",
        privacyPolicyURL: "https://promiso.app/privacy",
        termsOfServiceURL: "https://promiso.app/terms",
        supportEmail: "support@promiso.app",
        notionFAQDatabaseId: "updated-faq-id",
        versionNumber: "13",
        updateTime: "2026-03-13T01:00:00.000Z",
        updateUserEmail: "admin@promiso.app",
      }),
    });
    expect(auditLogAdds).toContainEqual(expect.objectContaining({
      actorId: "admin-user",
      action: "update_release_controls",
      targetType: "remote_config",
      targetId: "default",
      before: {
        forceUpdateVersion: "1.0.0",
        recommendedVersion: "1.1.0",
        privacyPolicyURL: "https://example.com/privacy",
        termsOfServiceURL: "https://example.com/terms",
        notionFAQDatabaseId: "faq-database-id",
      },
      after: {
        forceUpdateVersion: "1.2.0",
        recommendedVersion: "1.2.1",
        privacyPolicyURL: "https://promiso.app/privacy",
        termsOfServiceURL: "https://promiso.app/terms",
        notionFAQDatabaseId: "updated-faq-id",
      },
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
});
