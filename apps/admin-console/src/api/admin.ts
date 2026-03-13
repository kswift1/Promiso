import {httpsCallable} from "firebase/functions";
import {firebaseFunctions} from "../lib/firebase";

export type AdminUserSummary = {
  userId: string;
  name: string | null;
  nickname: string | null;
  email: string | null;
  groupCount: number;
  deviceCount: number;
  subscriptionStatus: string | null;
  overrideActive: boolean;
};

type GetAdminUserSummaryRequest = {
  query: string;
};

type GetAdminUserSummaryResponse = {
  success: true;
  results: AdminUserSummary[];
};

type GrantEntitlementOverrideRequest = {
  userId: string;
  reason: string;
  expiresAt?: string | null;
};

type GrantEntitlementOverrideResponse = {
  success: true;
};

type RevokeEntitlementOverrideRequest = {
  userId: string;
  reason?: string | null;
};

type RevokeEntitlementOverrideResponse = {
  success: true;
};

export async function getAdminUserSummary(
  query: string
): Promise<AdminUserSummary[]> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    GetAdminUserSummaryRequest,
    GetAdminUserSummaryResponse
  >(firebaseFunctions, "getAdminUserSummary");
  const result = await callable({query});
  return result.data.results;
}

export async function grantEntitlementOverride(params: {
  userId: string;
  reason: string;
  expiresAt?: string | null;
}): Promise<void> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    GrantEntitlementOverrideRequest,
    GrantEntitlementOverrideResponse
  >(firebaseFunctions, "grantEntitlementOverride");
  await callable(params);
}

export async function revokeEntitlementOverride(params: {
  userId: string;
  reason?: string | null;
}): Promise<void> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    RevokeEntitlementOverrideRequest,
    RevokeEntitlementOverrideResponse
  >(firebaseFunctions, "revokeEntitlementOverride");
  await callable(params);
}
