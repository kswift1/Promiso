import {Pool} from "pg";
import {RUST_DATABASE_URL} from "../config";

export interface RustEntitlementState {
  subscriptionStatus: string | null;
  overrideActive: boolean;
  hasPro: boolean;
  source: string;
}

interface PgQueryable {
  query: (
    text: string,
    params: unknown[],
  ) => Promise<{rows: Array<Record<string, unknown>>}>;
}

let rustPool: Pool | null = null;

/**
 * Rust authority의 entitlements row를 브리핑 소비자용 상태로 정규화한다.
 * @param {Record<string, unknown> | undefined} row PostgreSQL 조회 결과.
 * @return {RustEntitlementState} 브리핑 판정에 필요한 entitlement 상태.
 */
export function normalizeRustEntitlementRow(
  row: Record<string, unknown> | undefined,
): RustEntitlementState {
  return {
    subscriptionStatus: typeof row?.subscription_status === "string" ?
      row.subscription_status :
      null,
    overrideActive: row?.override_active === true,
    hasPro: row?.has_pro === true,
    source: typeof row?.source === "string" ? row.source : "none",
  };
}

/**
 * Rust/PostgreSQL authority에서 현재 entitlement 상태를 조회한다.
 * @param {string} uid 사용자 ID.
 * @param {PgQueryable} [queryable] 테스트용 주입 가능 query client.
 * @return {Promise<RustEntitlementState>} entitlement 상태.
 */
export async function loadRustEntitlementState(
  uid: string,
  queryable?: PgQueryable,
): Promise<RustEntitlementState> {
  const client = queryable ?? getRustPool();
  const result = await client.query(
    `SELECT subscription_status, override_active, has_pro, source
     FROM entitlements
     WHERE user_id = $1`,
    [uid],
  );

  return normalizeRustEntitlementRow(result.rows[0]);
}

/**
 * 테스트나 스크립트 종료 시 공유 pool을 닫는다.
 * @return {Promise<void>}
 */
export async function closeRustEntitlementPool(): Promise<void> {
  if (!rustPool) return;
  await rustPool.end();
  rustPool = null;
}

/**
 * Rust PostgreSQL connection pool (lazy init singleton).
 * @return {Pool} 공유 연결 풀.
 */
function getRustPool(): Pool {
  if (!rustPool) {
    rustPool = new Pool({
      connectionString: getRustDatabaseUrl(),
      max: 3,
    });
  }
  return rustPool;
}

/**
 * Rust PostgreSQL 연결 URL 조회 (env → secret 순).
 * @return {string} 연결 문자열.
 */
function getRustDatabaseUrl(): string {
  const envValue = process.env.RUST_DATABASE_URL?.trim();
  if (envValue) {
    return envValue;
  }

  const secretValue = RUST_DATABASE_URL.value().trim();
  if (secretValue) {
    return secretValue;
  }

  throw new Error("RUST_DATABASE_URL is not configured");
}
