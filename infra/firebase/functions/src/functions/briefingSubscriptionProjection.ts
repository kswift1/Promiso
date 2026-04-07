/**
 * Briefing subscription projection functions
 *
 * 브리핑 발송 대상과 다음 dispatch 시각을 별도 projection 컬렉션에 유지한다.
 */
import {FieldValue} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {admin, REGION, RUST_DATABASE_URL} from "../config";
import {
  BRIEFING_SUBSCRIPTIONS_COLLECTION,
  buildBriefingSubscriptionProjection,
} from "../utils/briefingScheduler";
import {loadRustEntitlementState} from "../utils/rustEntitlements";

interface ReconcileSummary {
  scanned: number;
  upserts: number;
  deletes: number;
  skipped: number;
}

/**
 * 사용자의 현재 settings/Rust entitlement 상태를 projection으로 동기화한다.
 * @param {string} uid 사용자 ID.
 * @param {unknown} [settingsDataOverride] 이미 로드된 settings 데이터.
 * @return {Promise<"upserted" | "deleted" | "skipped">} projection 처리 결과.
 */
export async function reconcileBriefingSubscription(
  uid: string,
  settingsDataOverride?: unknown,
): Promise<"upserted" | "deleted" | "skipped"> {
  try {
    const db = admin.firestore();
    const projectionRef = db
      .collection(BRIEFING_SUBSCRIPTIONS_COLLECTION)
      .doc(uid);

    const settingsData = settingsDataOverride ?? (
      await db.collection("users").doc(uid)
        .collection("settings").doc("main")
        .get()
    ).data() ?? null;
    const entitlement = await loadRustEntitlementState(uid);

    const projection = buildBriefingSubscriptionProjection({
      settingsData,
      subscriptionStatus: entitlement.subscriptionStatus,
      overrideActive: entitlement.overrideActive,
      now: new Date(),
    });

    if (!projection) {
      await projectionRef.delete();
      console.log(`🧹 [BriefingProjection] Deleted projection for ${uid}`);
      return "deleted";
    }

    await projectionRef.set({
      notificationHour: projection.notificationHour,
      timezone: projection.timezone,
      language: projection.language,
      style: projection.style,
      nextDispatchAt: admin.firestore.Timestamp
        .fromDate(projection.nextDispatchAt),
      defaultLocation: projection.defaultLocation,
      updatedAt: FieldValue.serverTimestamp(),
    });

    console.log(
      `✅ [BriefingProjection] Synced projection for ${uid} ` +
      `at ${projection.nextDispatchAt.toISOString()}`
    );
    return "upserted";
  } catch (error) {
    console.error(
      `[BriefingProjection] Failed to reconcile projection for ${uid}`,
      error,
    );
    return "skipped";
  }
}

/**
 * 브리핑 설정이 있는 전체 유저를 Rust entitlement 기준으로 projection 재동기화한다.
 * @param {object} [options] 실행 옵션.
 * @param {boolean} [options.dryRun] true면 실제 쓰기 없이 통계만 계산.
 * @return {Promise<ReconcileSummary>} 실행 요약.
 */
export async function reconcileAllBriefingSubscriptions(
  options: {dryRun?: boolean} = {},
): Promise<ReconcileSummary> {
  const {dryRun = false} = options;
  const db = admin.firestore();
  const settingsSnap = await db
    .collectionGroup("settings")
    .where("proSettings.briefing.notificationHour", ">=", 0)
    .get();

  const summary: ReconcileSummary = {
    scanned: settingsSnap.size,
    upserts: 0,
    deletes: 0,
    skipped: 0,
  };

  for (const doc of settingsSnap.docs) {
    const uid = doc.ref.path.split("/")[1];
    if (!uid) {
      summary.skipped++;
      continue;
    }

    if (dryRun) {
      try {
        const entitlement = await loadRustEntitlementState(uid);
        const projection = buildBriefingSubscriptionProjection({
          settingsData: doc.data(),
          subscriptionStatus: entitlement.subscriptionStatus,
          overrideActive: entitlement.overrideActive,
          now: new Date(),
        });

        if (projection) {
          summary.upserts++;
        } else {
          summary.deletes++;
        }
      } catch (error) {
        summary.skipped++;
        console.error(
          `[BriefingProjection] Dry-run reconcile failed for ${uid}`,
          error,
        );
      }
      continue;
    }

    const result = await reconcileBriefingSubscription(uid, doc.data());
    if (result === "upserted") {
      summary.upserts++;
    } else if (result === "deleted") {
      summary.deletes++;
    } else {
      summary.skipped++;
    }
  }

  return summary;
}

/**
 * settings/main 변경 시 브리핑 projection을 재계산한다.
 */
export const onUserSettingsSyncBriefingSubscription = onDocumentWritten(
  {
    document: "users/{uid}/settings/main",
    region: REGION,
    secrets: [RUST_DATABASE_URL],
  },
  async (event) => {
    const uid = event.params.uid;
    if (!uid) return;

    await reconcileBriefingSubscription(uid);
  },
);

/**
 * legacy entitlements/{uid} 변경 시에도 projection을 재계산한다.
 */
export const onEntitlementSyncBriefingSubscription = onDocumentWritten(
  {
    document: "entitlements/{uid}",
    region: REGION,
    secrets: [RUST_DATABASE_URL],
  },
  async (event) => {
    const uid = event.params.uid;
    if (!uid) return;

    await reconcileBriefingSubscription(uid);
  },
);

/**
 * Rust authority에서 일어난 subscription 변경을 보완하기 위해
 * 브리핑 projection 전체를 주기적으로 재동기화한다.
 */
export const scheduledReconcileBriefingSubscriptions = onSchedule(
  {
    schedule: "55 * * * *",
    region: REGION,
    timeZone: "UTC",
    secrets: [RUST_DATABASE_URL],
  },
  async () => {
    const summary = await reconcileAllBriefingSubscriptions();
    console.log("[BriefingProjection] Scheduled reconcile completed", summary);
  },
);
