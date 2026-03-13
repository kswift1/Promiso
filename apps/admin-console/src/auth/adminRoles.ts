export type AdminRole = "owner" | "support" | "marketer";

export function hasAdminRole(
  role: AdminRole | null | undefined,
  allowedRoles?: AdminRole[]
): boolean {
  if (!allowedRoles || allowedRoles.length === 0) {
    return true;
  }

  if (!role) {
    return false;
  }

  return allowedRoles.includes(role);
}
