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
  let mockAdminDocRef: any;
  let mockFirestore: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    mockAdminDocRef = {
      get: jest.fn(),
    };

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === "adminUsers") {
          return {
            doc: jest.fn().mockReturnValue(mockAdminDocRef),
          };
        }
        return {};
      }),
    };

    const {admin: configAdmin} = await import("../src/config");
    jest.spyOn(configAdmin, "firestore").mockReturnValue(mockFirestore as any);

    const functions = await import("../src/functions/admin");
    getAdminSession = functions.getAdminSession;
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
    mockAdminDocRef.get.mockResolvedValue(
      createMockDocument(true, {
        role: "owner",
        enabled: true,
        email: "admin@promiso.app",
      })
    );

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
    mockAdminDocRef.get.mockResolvedValue(createMockDocument(false));

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
});

