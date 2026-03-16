// @ts-nocheck
/* eslint-disable @typescript-eslint/no-explicit-any */
import {
  describe,
  expect,
  it,
} from "@jest/globals";

import {
  buildBriefingSubscriptionProjection,
  buildScheduledBriefingTaskFromProjection,
  computeNextDispatchAt,
  hasActiveSubscription,
  isCurrentBriefingTaskEligible,
} from "../src/utils/briefingScheduler";

describe("briefing scheduling helpers", () => {
  const dispatchTime = new Date("2026-03-13T23:00:00.000Z");

  it("활성 Pro와 브리핑 설정이 있으면 projection 문서를 만든다", () => {
    const projection = buildBriefingSubscriptionProjection({
      settingsData: {
        proSettings: {
          briefing: {
            notificationHour: 8,
          },
        },
      },
      subscriptionStatus: "subscribed",
      overrideActive: false,
      now: dispatchTime,
    });

    expect(projection).not.toBeNull();
    expect(projection).toMatchObject({
      notificationHour: 8,
      timezone: "Asia/Seoul",
      language: "ko",
      style: "friendly",
    });
    expect(projection?.nextDispatchAt.toISOString())
      .toBe("2026-03-13T23:00:00.000Z");
  });

  it("비활성 구독이면 projection 문서를 만들지 않는다", () => {
    const projection = buildBriefingSubscriptionProjection({
      settingsData: {
        proSettings: {
          briefing: {
            notificationHour: 8,
          },
        },
      },
      subscriptionStatus: "expired",
      overrideActive: false,
      now: dispatchTime,
    });

    expect(projection).toBeNull();
  });

  it("override가 활성화되어 있으면 projection 문서를 만든다", () => {
    const projection = buildBriefingSubscriptionProjection({
      settingsData: {
        proSettings: {
          briefing: {
            notificationHour: 8,
            timezone: "Asia/Seoul",
          },
        },
      },
      subscriptionStatus: "expired",
      overrideActive: true,
      now: dispatchTime,
    });

    expect(projection).not.toBeNull();
  });

  it("dispatch 시각 계산이 불가능하면 projection 계산은 예외를 던진다", () => {
    expect(() => buildBriefingSubscriptionProjection({
      settingsData: {
        proSettings: {
          briefing: {
            notificationHour: 8,
            timezone: "Invalid/Timezone",
          },
        },
      },
      subscriptionStatus: "subscribed",
      overrideActive: false,
      now: dispatchTime,
    })).toThrow("Failed to compute nextDispatchAt");
  });

  it("현재 시간이 이미 지난 경우 다음날 dispatch 시각으로 계산한다", () => {
    const nextDispatchAt = computeNextDispatchAt({
      now: new Date("2026-03-13T23:05:00.000Z"),
      timezone: "Asia/Seoul",
      notificationHour: 8,
    });

    expect(nextDispatchAt?.toISOString()).toBe("2026-03-14T23:00:00.000Z");
  });

  it("due projection 문서면 enqueue payload를 만든다", () => {
    const payload = buildScheduledBriefingTaskFromProjection({
      uid: "user-a",
      projectionData: {
        notificationHour: 8,
        timezone: "Asia/Seoul",
        language: "ko",
        style: "friendly",
        nextDispatchAt: new Date("2026-03-13T23:00:00.000Z"),
      },
      now: dispatchTime,
    });

    expect(payload).toEqual({
      uid: "user-a",
      timezone: "Asia/Seoul",
      language: "ko",
      style: "friendly",
      notificationHour: 8,
      defaultLocation: null,
    });
  });

  it("아직 due가 아닌 projection 문서는 enqueue하지 않는다", () => {
    const payload = buildScheduledBriefingTaskFromProjection({
      uid: "user-a",
      projectionData: {
        notificationHour: 8,
        timezone: "Asia/Seoul",
        language: "ko",
        style: "friendly",
        nextDispatchAt: new Date("2026-03-14T23:00:00.000Z"),
      },
      now: dispatchTime,
    });

    expect(payload).toBeNull();
  });

  it("비활성 구독 상태는 Pro로 보지 않는다", () => {
    expect(hasActiveSubscription("expired")).toBe(false);
    expect(hasActiveSubscription("revoked")).toBe(false);
    expect(hasActiveSubscription("subscribed")).toBe(true);
    expect(hasActiveSubscription("gracePeriod")).toBe(true);
  });

  it("비활성 Pro 상태면 enqueue된 task라도 실행하지 않는다", () => {
    const isEligible = isCurrentBriefingTaskEligible({
      payload: {
        uid: "user-a",
        timezone: "Asia/Seoul",
        language: "ko",
        style: "friendly",
        notificationHour: 8,
      },
      settingsData: {
        proSettings: {
          briefing: {
            notificationHour: 8,
          },
        },
      },
      subscriptionStatus: "expired",
      overrideActive: false,
    });

    expect(isEligible).toBe(false);
  });

  it("현재 설정의 알림 시간이 달라졌으면 stale task를 차단한다", () => {
    const isEligible = isCurrentBriefingTaskEligible({
      payload: {
        uid: "user-a",
        timezone: "Asia/Seoul",
        language: "ko",
        style: "friendly",
        notificationHour: 8,
      },
      settingsData: {
        proSettings: {
          briefing: {
            notificationHour: 9,
          },
        },
      },
      subscriptionStatus: "subscribed",
      overrideActive: false,
    });

    expect(isEligible).toBe(false);
  });

  it("현재 Pro 상태이고 알림 시간이 그대로면 task 실행을 허용한다", () => {
    const isEligible = isCurrentBriefingTaskEligible({
      payload: {
        uid: "user-a",
        timezone: "Asia/Seoul",
        language: "ko",
        style: "friendly",
        notificationHour: 8,
      },
      settingsData: {
        proSettings: {
          briefing: {
            notificationHour: 8,
            timezone: "Asia/Seoul",
            language: "ko",
            style: "friendly",
          },
        },
      },
      subscriptionStatus: "subscribed",
      overrideActive: false,
    });

    expect(isEligible).toBe(true);
  });
});
