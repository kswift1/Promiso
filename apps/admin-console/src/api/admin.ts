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
