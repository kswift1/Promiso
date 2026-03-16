// @ts-nocheck
/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Entitlements reconcileEntitlement 단위 테스트
 *
 * subscriptions/{uid} + entitlementOverrides/{uid} 조합에 따라
 * entitlements/{uid} read model이 올바르게 기록되는지 검증한다.
 */
import {
  describe,
  it,
  expect,
  jest,
  beforeEach,
  afterEach,
} from "@jest/globals";

describe("entitlements reconcile", () => {
  let reconcileEntitlement: any;
  let mockFirestore: any;
  let mockEntitlementRef: any;
  let subscriptionDoc: any;
  let overrideDoc: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    // 기본: 문서 없음
    subscriptionDoc = {exists: false, data: () => undefined};
    overrideDoc = {exists: false, data: () => undefined};
    mockEntitlementRef = {set: jest.fn().mockResolvedValue(undefined)};

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === "subscriptions") {
          return {
            doc: jest.fn(() => ({
              get: jest.fn(() => Promise.resolve(subscriptionDoc)),
            })),
          };
        }
        if (name === "entitlementOverrides") {
          return {
            doc: jest.fn(() => ({
              get: jest.fn(() => Promise.resolve(overrideDoc)),
            })),
          };
        }
        if (name === "entitlements") {
          return {
            doc: jest.fn(() => mockEntitlementRef),
          };
        }
        return {};
      }),
    };

    const {admin: configAdmin} = await import("../src/config");
    jest.spyOn(configAdmin, "firestore").mockReturnValue(mockFirestore as any);

    const entitlements = await import("../src/functions/entitlements");
    reconcileEntitlement = entitlements.reconcileEntitlement;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  it("구독이 active면 hasPro=true, source='subscription'으로 기록한다", async () => {
    subscriptionDoc = {
      exists: true,
      data: () => ({status: "subscribed"}),
    };
    overrideDoc = {exists: false, data: () => undefined};

    await reconcileEntitlement("user-a");

    expect(mockEntitlementRef.set).toHaveBeenCalledWith(
      expect.objectContaining({
        hasPro: true,
        source: "subscription",
        subscriptionStatus: "subscribed",
        overrideActive: false,
        overrideExpiresAt: null,
      }),
      {merge: true},
    );
  });

  it("override만 active면 hasPro=true, source='override'로 기록한다", async () => {
    subscriptionDoc = {
      exists: true,
      data: () => ({status: "expired"}),
    };
    overrideDoc = {
      exists: true,
      data: () => ({isActive: true, expiresAt: "2026-12-31T00:00:00Z"}),
    };

    await reconcileEntitlement("user-a");

    expect(mockEntitlementRef.set).toHaveBeenCalledWith(
      expect.objectContaining({
        hasPro: true,
        source: "override",
        subscriptionStatus: "expired",
        overrideActive: true,
        overrideExpiresAt: "2026-12-31T00:00:00Z",
      }),
      {merge: true},
    );
  });

  it("구독과 override 둘 다 active면 source='subscription'으로 기록한다", async () => {
    subscriptionDoc = {
      exists: true,
      data: () => ({status: "subscribed"}),
    };
    overrideDoc = {
      exists: true,
      data: () => ({isActive: true}),
    };

    await reconcileEntitlement("user-a");

    expect(mockEntitlementRef.set).toHaveBeenCalledWith(
      expect.objectContaining({
        hasPro: true,
        source: "subscription",
      }),
      {merge: true},
    );
  });

  it("구독과 override 둘 다 inactive면 hasPro=false, source='none'으로 기록한다", async () => {
    subscriptionDoc = {
      exists: true,
      data: () => ({status: "expired"}),
    };
    overrideDoc = {
      exists: true,
      data: () => ({isActive: false}),
    };

    await reconcileEntitlement("user-a");

    expect(mockEntitlementRef.set).toHaveBeenCalledWith(
      expect.objectContaining({
        hasPro: false,
        source: "none",
      }),
      {merge: true},
    );
  });

  it("문서가 없으면 hasPro=false, source='none', subscriptionStatus=null로 기록한다", async () => {
    subscriptionDoc = {exists: false, data: () => undefined};
    overrideDoc = {exists: false, data: () => undefined};

    await reconcileEntitlement("user-a");

    expect(mockEntitlementRef.set).toHaveBeenCalledWith(
      expect.objectContaining({
        hasPro: false,
        source: "none",
        subscriptionStatus: null,
        overrideActive: false,
      }),
      {merge: true},
    );
  });
});
