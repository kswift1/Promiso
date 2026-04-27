// @ts-nocheck
/* eslint-disable @typescript-eslint/no-explicit-any */
import {
  afterEach,
  describe,
  expect,
  it,
  jest,
} from "@jest/globals";

import {
  closeRustEntitlementPool,
  loadRustEntitlementState,
  normalizeRustEntitlementRow,
} from "../src/utils/rustEntitlements";

describe("rust entitlement helper", () => {
  afterEach(async () => {
    await closeRustEntitlementPool();
    jest.restoreAllMocks();
  });

  it("entitlements row를 브리핑용 상태로 정규화한다", () => {
    const state = normalizeRustEntitlementRow({
      subscription_status: "subscribed",
      override_active: false,
      has_pro: true,
      source: "subscription",
    });

    expect(state).toEqual({
      subscriptionStatus: "subscribed",
      overrideActive: false,
      hasPro: true,
      source: "subscription",
    });
  });

  it("row가 없으면 free 상태로 정규화한다", () => {
    const state = normalizeRustEntitlementRow(undefined);

    expect(state).toEqual({
      subscriptionStatus: null,
      overrideActive: false,
      hasPro: false,
      source: "none",
    });
  });

  it("PostgreSQL authority에서 entitlement 상태를 조회한다", async () => {
    const query = jest.fn().mockResolvedValue({
      rows: [{
        subscription_status: "gracePeriod",
        override_active: true,
        has_pro: true,
        source: "subscription",
      }],
    });

    const state = await loadRustEntitlementState(
      "user-a",
      {query},
    );

    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("FROM entitlements"),
      ["user-a"],
    );
    expect(state).toEqual({
      subscriptionStatus: "gracePeriod",
      overrideActive: true,
      hasPro: true,
      source: "subscription",
    });
  });
});
