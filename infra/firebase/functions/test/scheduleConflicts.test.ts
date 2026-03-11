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
import {Timestamp} from "firebase-admin/firestore";

jest.mock("firebase-functions/params", () => ({
  defineSecret: jest.fn(() => ({
    value: () => "test-secret",
  })),
}));

function createMockDocument(
  exists: boolean,
  data?: Record<string, unknown>,
): any {
  return {
    exists,
    data: () => data,
  };
}

function createMockQuerySnapshot(
  docs: Array<{id: string; data: Record<string, unknown>}>,
): any {
  return {
    size: docs.length,
    docs: docs.map((doc) => ({
      id: doc.id,
      data: () => doc.data,
    })),
  };
}

describe("checkScheduleConflicts", () => {
  let checkScheduleConflicts: any;
  let mockFirestore: any;
  let recurringDocs: Array<{id: string; data: Record<string, unknown>}>;
  let scheduleSlotDocs: Record<string, any>;

  beforeEach(async () => {
    jest.clearAllMocks();
    jest.resetModules();

    recurringDocs = [];
    scheduleSlotDocs = {};

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === "subscriptions") {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(true, {status: "subscribed"}),
              ),
            })),
          };
        }

        if (name === "users") {
          return {
            doc: jest.fn(() => ({
              collection: jest.fn((subcollection: string) => {
                if (subcollection === "scheduleSlots") {
                  return {
                    doc: jest.fn((key: string) => ({
                      get: jest.fn().mockResolvedValue(
                        scheduleSlotDocs[key] ?? createMockDocument(false),
                      ),
                    })),
                  };
                }

                if (subcollection === "recurringEvents") {
                  return {
                    get: jest.fn().mockResolvedValue(
                      createMockQuerySnapshot(recurringDocs),
                    ),
                  };
                }

                return {};
              }),
            })),
          };
        }

        return {};
      }),
    };

    const {admin: configAdmin} = await import("../src/config");
    jest.spyOn(configAdmin, "firestore").mockReturnValue(mockFirestore as any);

    const functions = await import("../src/functions/scheduleConflicts");
    checkScheduleConflicts = functions.checkScheduleConflicts;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  it("반복 일정 편집 시 series id로 자기 자신을 제외한다", async () => {
    recurringDocs = [
      {
        id: "series-1",
        data: {
          title: "매일 운동",
          startTime: {hour: 19, minute: 0},
          endTime: {hour: 20, minute: 0},
          seriesStartDate: Timestamp.fromDate(new Date("2025-03-01T00:00:00+09:00")),
          recurrence: {
            frequency: "daily",
            daysOfWeek: null,
            dayOfMonth: null,
            seriesEndDate: null,
          },
        },
      },
    ];

    const handler = (checkScheduleConflicts as any).run;
    const result = await handler({
      auth: {uid: "user-1"},
      data: {
        startAt: "2025-03-10T10:00:00.000Z",
        endAt: "2025-03-10T11:00:00.000Z",
        excludeIds: ["series-1"],
        minGapMinutes: 0,
        timeZone: "Asia/Seoul",
      },
    });

    expect(result.conflicts).toEqual([]);
  });

  it("매월 31일 반복은 31일이 없는 달을 건너뛴다", async () => {
    recurringDocs = [
      {
        id: "series-31",
        data: {
          title: "월말 정산",
          startTime: {hour: 17, minute: 0},
          endTime: {hour: 18, minute: 0},
          seriesStartDate: Timestamp.fromDate(new Date("2025-01-01T00:00:00+09:00")),
          recurrence: {
            frequency: "monthly",
            daysOfWeek: null,
            dayOfMonth: 31,
            seriesEndDate: null,
          },
        },
      },
    ];

    const handler = (checkScheduleConflicts as any).run;
    const result = await handler({
      auth: {uid: "user-1"},
      data: {
        startAt: "2025-02-28T08:00:00.000Z",
        endAt: "2025-02-28T09:00:00.000Z",
        minGapMinutes: 0,
        timeZone: "Asia/Seoul",
      },
    });

    expect(result.conflicts).toEqual([]);
  });

  it("excludedDates는 사용자 로컬 날짜키 기준으로 적용한다", async () => {
    recurringDocs = [
      {
        id: "daily-1",
        data: {
          title: "일일 미팅",
          startTime: {hour: 9, minute: 0},
          endTime: {hour: 10, minute: 0},
          seriesStartDate: Timestamp.fromDate(new Date("2025-03-01T00:00:00+09:00")),
          excludedDates: ["2025-03-01"],
          recurrence: {
            frequency: "daily",
            daysOfWeek: null,
            dayOfMonth: null,
            seriesEndDate: null,
          },
        },
      },
    ];

    const handler = (checkScheduleConflicts as any).run;
    const result = await handler({
      auth: {uid: "user-1"},
      data: {
        startAt: "2025-03-01T00:00:00.000Z",
        endAt: "2025-03-01T01:00:00.000Z",
        minGapMinutes: 0,
        timeZone: "Asia/Seoul",
      },
    });

    expect(result.conflicts).toEqual([]);
  });
});
