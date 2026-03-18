import {BetaAnalyticsDataClient} from "@google-analytics/data";
import {BigQuery} from "@google-cloud/bigquery";
import {
  ANALYTICS_BIGQUERY_DATASET_ID,
  ANALYTICS_BIGQUERY_LOCATION,
  ANALYTICS_BIGQUERY_PROJECT_ID,
  GA4_PROPERTY_ID,
} from "../config";
import type {
  AdminAnalyticsBigQuerySummary,
  AdminAnalyticsGa4Summary,
  AdminAnalyticsSummary,
  AdminAnalyticsWindowDays,
} from "../types/admin";

const GA4_EVENTS = [
  "user_signup",
  "user_login",
  "paywall_open",
  "paywall_purchase",
] as const;

let ga4Client: BetaAnalyticsDataClient | null = null;
let bigQueryClient: BigQuery | null = null;

/**
 * Returns a memoized GA4 Data API client.
 * @return {BetaAnalyticsDataClient} The initialized client.
 */
function getGa4Client(): BetaAnalyticsDataClient {
  if (!ga4Client) {
    ga4Client = new BetaAnalyticsDataClient();
  }

  return ga4Client;
}

/**
 * Returns a memoized BigQuery client for analytics queries.
 * @param {string} projectId The target GCP project id.
 * @return {BigQuery} The initialized client.
 */
function getBigQueryClient(projectId: string): BigQuery {
  if (!bigQueryClient) {
    bigQueryClient = new BigQuery({projectId});
  }

  return bigQueryClient;
}

/**
 * Builds an unavailable GA4 summary payload.
 * @param {string} note The operator-facing fallback note.
 * @return {AdminAnalyticsGa4Summary} The empty summary.
 */
function emptyGa4Summary(note: string): AdminAnalyticsGa4Summary {
  return {
    available: false,
    note,
    signups: null,
    logins: null,
    paywallOpens: null,
    paywallPurchases: null,
  };
}

/**
 * Builds an unavailable BigQuery summary payload.
 * @param {string} note The operator-facing fallback note.
 * @return {AdminAnalyticsBigQuerySummary} The empty summary.
 */
function emptyBigQuerySummary(note: string): AdminAnalyticsBigQuerySummary {
  return {
    available: false,
    note,
    signups: null,
    paywallOpens: null,
    paywallPurchases: null,
  };
}

/**
 * Formats a Date for BigQuery export table suffix filtering.
 * @param {Date} value The date to format.
 * @return {string} The YYYYMMDD-formatted date.
 */
function formatBigQueryDate(value: Date): string {
  return value.toISOString().slice(0, 10).replace(/-/g, "");
}

/**
 * Builds the inclusive date range for the requested window.
 * @param {AdminAnalyticsWindowDays} windowDays The selected window preset.
 * @return {{startDate: string, endDate: string}}
 * The BigQuery date suffix range.
 */
function getWindowDateRange(windowDays: AdminAnalyticsWindowDays): {
  startDate: string;
  endDate: string;
} {
  const endDate = new Date();
  const startDate = new Date(endDate);
  startDate.setUTCDate(startDate.getUTCDate() - (windowDays - 1));

  return {
    startDate: formatBigQueryDate(startDate),
    endDate: formatBigQueryDate(endDate),
  };
}

/**
 * Normalizes GA4 and BigQuery numeric outputs.
 * @param {unknown} value The raw metric value.
 * @return {number} The normalized number.
 */
function toNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === "string" && value.length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return 0;
}

/**
 * Builds a user-facing error message for analytics fallbacks.
 * @param {unknown} error The thrown error.
 * @param {string} fallback The default message.
 * @return {string} The formatted error message.
 */
function getErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return `${fallback}: ${error.message}`;
  }

  return fallback;
}

/**
 * Loads recent GA4 event counts for the selected window.
 * @param {AdminAnalyticsWindowDays} windowDays The selected window preset.
 * @return {Promise<AdminAnalyticsGa4Summary>} The recent GA4 summary.
 */
async function fetchGa4Summary(
  windowDays: AdminAnalyticsWindowDays
): Promise<AdminAnalyticsGa4Summary> {
  const propertyId = GA4_PROPERTY_ID.value().trim();

  if (!propertyId) {
    return emptyGa4Summary("GA4 property 설정이 아직 없습니다.");
  }

  try {
    const [report] = await getGa4Client().runReport({
      property: `properties/${propertyId}`,
      dateRanges: [{
        startDate: `${windowDays}daysAgo`,
        endDate: "today",
      }],
      dimensions: [{name: "eventName"}],
      metrics: [{name: "eventCount"}],
      dimensionFilter: {
        filter: {
          fieldName: "eventName",
          inListFilter: {
            values: [...GA4_EVENTS],
          },
        },
      },
    });

    const counts = report.rows?.reduce<Record<string, number>>(
      (result, row) => {
        const eventName = row.dimensionValues?.[0]?.value ?? "";
        const count = toNumber(row.metricValues?.[0]?.value);
        if (!eventName) {
          return result;
        }

        return {
          ...result,
          [eventName]: count,
        };
      },
      {}
    ) ?? {};

    return {
      available: true,
      note: null,
      signups: counts.user_signup ?? 0,
      logins: counts.user_login ?? 0,
      paywallOpens: counts.paywall_open ?? 0,
      paywallPurchases: counts.paywall_purchase ?? 0,
    };
  } catch (error) {
    return emptyGa4Summary(
      getErrorMessage(error, "GA4 Data API 조회에 실패했습니다")
    );
  }
}

/**
 * Loads BigQuery-exported funnel counts for the selected window.
 * @param {AdminAnalyticsWindowDays} windowDays The selected window preset.
 * @return {Promise<AdminAnalyticsBigQuerySummary>}
 * The historical funnel summary.
 */
async function fetchBigQuerySummary(
  windowDays: AdminAnalyticsWindowDays
): Promise<AdminAnalyticsBigQuerySummary> {
  const projectId = ANALYTICS_BIGQUERY_PROJECT_ID.value().trim();
  const datasetId = ANALYTICS_BIGQUERY_DATASET_ID.value().trim();
  const location = ANALYTICS_BIGQUERY_LOCATION.value().trim();

  if (!projectId || !datasetId) {
    return emptyBigQuerySummary("BigQuery export 설정이 아직 없습니다.");
  }

  const {startDate, endDate} = getWindowDateRange(windowDays);

  try {
    const [rows] = await getBigQueryClient(projectId).query({
      query: `
        SELECT
          COUNT(DISTINCT IF(
            event_name = 'user_signup',
            COALESCE(user_id, user_pseudo_id),
            NULL
          )) AS signups,
          COUNT(DISTINCT IF(
            event_name = 'paywall_open',
            COALESCE(user_id, user_pseudo_id),
            NULL
          )) AS paywall_opens,
          COUNT(DISTINCT IF(
            event_name = 'paywall_purchase',
            COALESCE(user_id, user_pseudo_id),
            NULL
          )) AS paywall_purchases
        FROM \`${projectId}.${datasetId}.events_*\`
        WHERE _TABLE_SUFFIX BETWEEN @startDate AND @endDate
          AND event_name IN ('user_signup', 'paywall_open', 'paywall_purchase')
      `,
      params: {
        startDate,
        endDate,
      },
      location: location || undefined,
    });

    const row = rows[0] as Record<string, unknown> | undefined;

    return {
      available: true,
      note: null,
      signups: toNumber(row?.signups),
      paywallOpens: toNumber(row?.paywall_opens),
      paywallPurchases: toNumber(row?.paywall_purchases),
    };
  } catch (error) {
    return emptyBigQuerySummary(
      getErrorMessage(error, "BigQuery funnel 조회에 실패했습니다")
    );
  }
}

/**
 * Loads the combined admin analytics summary payload.
 * @param {AdminAnalyticsWindowDays} windowDays The selected window preset.
 * @return {Promise<AdminAnalyticsSummary>} The combined analytics summary.
 */
export async function getAdminAnalyticsSummaryData(
  windowDays: AdminAnalyticsWindowDays
): Promise<AdminAnalyticsSummary> {
  const [ga4, bigQuery] = await Promise.all([
    fetchGa4Summary(windowDays),
    fetchBigQuerySummary(windowDays),
  ]);

  return {
    windowDays,
    ga4,
    bigQuery,
  };
}
