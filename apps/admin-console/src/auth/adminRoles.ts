export type AdminRole = "owner" | "support" | "marketer";

export function getAdminRoleLabel(role: AdminRole | null | undefined): string {
  switch (role) {
  case "owner":
    return "소유자";
  case "support":
    return "지원";
  case "marketer":
    return "마케터";
  default:
    return "알 수 없음";
  }
}

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
