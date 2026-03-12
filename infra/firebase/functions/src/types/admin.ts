/**
 * Admin Console 전용 타입 정의
 */

export type AdminRole = "owner" | "support" | "marketer";

export interface AdminUserDocument {
  role: AdminRole;
  email?: string | null;
  enabled?: boolean;
}

export interface GetAdminSessionResponse {
  success: true;
  userId: string;
  email: string | null;
  role: AdminRole;
  enabled: boolean;
}

