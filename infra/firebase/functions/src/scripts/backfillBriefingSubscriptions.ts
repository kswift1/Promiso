/**
 * Briefing subscription projection backfill script
 *
 * 사용법:
 *   RUST_DATABASE_URL=... npm run backfill:briefing-subscriptions
 *   RUST_DATABASE_URL=... npm run backfill:briefing-subscriptions -- --dry-run
 */
import * as admin from "firebase-admin";
import {closeRustEntitlementPool} from "../utils/rustEntitlements";
import {reconcileAllBriefingSubscriptions} from "../functions/briefingSubscriptionProjection";

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * 기존 유저 설정을 briefingSubscriptions projection으로 backfill한다.
 * @return {Promise<void>}
 */
async function main(): Promise<void> {
  const dryRun = process.argv.includes("--dry-run");
  const summary = await reconcileAllBriefingSubscriptions({dryRun});

  console.log("[BackfillBriefingSubscriptions] Completed", {
    ...summary,
    dryRun,
  });
}

main()
  .then(async () => {
    await closeRustEntitlementPool();
    process.exit(0);
  })
  .catch(async (error) => {
    console.error("[BackfillBriefingSubscriptions] Failed", error);
    await closeRustEntitlementPool();
    process.exit(1);
  });
