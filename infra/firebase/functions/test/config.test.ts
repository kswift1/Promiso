import {
  afterEach,
  describe,
  expect,
  it,
} from "@jest/globals";

const originalProjectId = process.env.GCLOUD_PROJECT;

describe("functions config", () => {
  afterEach(() => {
    process.env.GCLOUD_PROJECT = originalProjectId;
    jest.resetModules();
  });

  it("uses the Promiso App Store appAppleId in release", async () => {
    process.env.GCLOUD_PROJECT = "promiso-prod";
    jest.resetModules();

    const config = await import("../src/config");

    expect(config.APP_STORE_APPLE_ID).toBe(6757733720);
  });

  it("does not set appAppleId outside release", async () => {
    process.env.GCLOUD_PROJECT = "promiso-stage";
    jest.resetModules();

    const config = await import("../src/config");

    expect(config.APP_STORE_APPLE_ID).toBeUndefined();
  });
});
