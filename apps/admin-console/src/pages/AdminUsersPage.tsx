import {
  Alert,
  Button,
  Card,
  CardContent,
  Checkbox,
  Chip,
  CircularProgress,
  FormControlLabel,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import {useMutation, useQuery, useQueryClient} from "@tanstack/react-query";
import {useEffect, useState} from "react";
import {
  AdminAccount,
  AdminRole,
  createAdminUser,
  getAdminUsers,
  updateAdminUser,
} from "../api/admin";
import {getAdminRoleLabel} from "../auth/adminRoles";
import {useAuth} from "../auth/AuthProvider";

function getErrorMessage(error: unknown, fallback: string): string {
  return error instanceof Error && error.message.length > 0 ?
    error.message :
    fallback;
}

function AdminUserCard(props: {
  user: AdminAccount;
  isCurrentUser: boolean;
  isSaving: boolean;
  onSave: (params: {userId: string; role: AdminRole; enabled: boolean}) => void;
}) {
  const {user, isCurrentUser, isSaving, onSave} = props;
  const [role, setRole] = useState<AdminRole>(user.role);
  const [enabled, setEnabled] = useState(user.enabled);

  useEffect(() => {
    setRole(user.role);
    setEnabled(user.enabled);
  }, [user]);

  const isDirty = role !== user.role || enabled !== user.enabled;

  return (
    <Card elevation={0}>
      <CardContent>
        <Stack spacing={2}>
          <Stack
            direction={{xs: "column", sm: "row"}}
            justifyContent="space-between"
            spacing={1}
          >
            <Stack spacing={0.5}>
              <Typography variant="h6">
                {user.email ?? user.userId}
              </Typography>
              <Typography color="text.secondary" variant="body2">
                {user.userId}
              </Typography>
            </Stack>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Chip
                color={user.enabled ? "success" : "default"}
                label={user.enabled ? "활성" : "비활성"}
              />
              <Chip label={getAdminRoleLabel(user.role)} />
              {isCurrentUser && <Chip color="primary" label="현재 세션" />}
            </Stack>
          </Stack>

          {isCurrentUser && (
            <Alert severity="info">
              현재 로그인한 소유자 계정은 이 화면에서 비활성화하거나 소유자 권한을
              해제할 수 없습니다.
            </Alert>
          )}

          <Stack spacing={2}>
            <TextField
              select
              label="권한"
              value={role}
              onChange={(event) => setRole(event.target.value as AdminRole)}
              disabled={isCurrentUser}
              fullWidth
            >
              <MenuItem value="owner">소유자</MenuItem>
              <MenuItem value="support">지원</MenuItem>
              <MenuItem value="marketer">마케터</MenuItem>
            </TextField>

            <FormControlLabel
              control={
                <Checkbox
                  checked={enabled}
                  onChange={(event) => setEnabled(event.target.checked)}
                  disabled={isCurrentUser}
                />
              }
              label="활성화"
            />
          </Stack>

          <Stack direction="row" justifyContent="flex-end">
            <Button
              variant="contained"
              disabled={!isDirty || isCurrentUser || isSaving}
              onClick={() =>
                onSave({
                  userId: user.userId,
                  role,
                  enabled,
                })
              }
            >
              {isSaving ? "저장 중..." : "변경 저장"}
            </Button>
          </Stack>
        </Stack>
      </CardContent>
    </Card>
  );
}

export function AdminUsersPage() {
  const queryClient = useQueryClient();
  const {adminSession} = useAuth();
  const [searchQuery, setSearchQuery] = useState("");
  const [createEmail, setCreateEmail] = useState("");
  const [createRole, setCreateRole] = useState<AdminRole>("support");
  const [createEnabled, setCreateEnabled] = useState(true);
  const [message, setMessage] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);

  const adminUsersQuery = useQuery({
    queryKey: ["admin-users"],
    queryFn: getAdminUsers,
  });

  const createMutation = useMutation({
    mutationFn: createAdminUser,
    onSuccess: (user) => {
      void queryClient.invalidateQueries({queryKey: ["admin-users"]});
      setCreateEmail("");
      setCreateRole("support");
      setCreateEnabled(true);
      setMessage({
        type: "success",
        text: `${user.email ?? user.userId} 관리자 계정을 등록했습니다.`,
      });
    },
    onError: (error) => {
      setMessage({
        type: "error",
        text: getErrorMessage(error, "관리자 계정 등록에 실패했습니다."),
      });
    },
  });

  const updateMutation = useMutation({
    mutationFn: updateAdminUser,
    onSuccess: (user) => {
      void queryClient.invalidateQueries({queryKey: ["admin-users"]});
      setMessage({
        type: "success",
        text: `${user.email ?? user.userId} 관리자 설정을 저장했습니다.`,
      });
    },
    onError: (error) => {
      setMessage({
        type: "error",
        text: getErrorMessage(error, "관리자 계정 수정에 실패했습니다."),
      });
    },
  });

  const normalizedSearchQuery = searchQuery.trim().toLowerCase();
  const visibleAdminUsers = (adminUsersQuery.data ?? []).filter((user) => {
    if (!normalizedSearchQuery) {
      return true;
    }

    return (
      user.userId.toLowerCase().includes(normalizedSearchQuery) ||
      (user.email ?? "").toLowerCase().includes(normalizedSearchQuery)
    );
  });
  const canCreate = createEmail.trim().length > 0;

  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">관리자 계정</Typography>
        <Typography color="text.secondary">
          소유자 전용 관리자 계정 등록/권한 관리 화면입니다.
        </Typography>
      </Stack>

      <Card elevation={0}>
        <CardContent>
          <Stack spacing={2}>
            <Typography variant="h6">운영 가이드</Typography>
            <Stack spacing={1.5}>
              <Stack direction="row" spacing={1.5} alignItems="flex-start">
                <Chip label="1" size="small" />
                <Typography color="text.secondary" variant="body2">
                  새 관리자 계정은 이메일로 등록합니다. 서버가 Firebase Auth에서
                  같은 이메일의 UID를 찾아 관리자 계정 문서를 생성합니다.
                </Typography>
              </Stack>
              <Stack direction="row" spacing={1.5} alignItems="flex-start">
                <Chip label="2" size="small" />
                <Typography color="text.secondary" variant="body2">
                  계정을 완전히 지우기보다 먼저 활성화를 끄는 방식으로 접근을
                  막는 것이 안전합니다.
                </Typography>
              </Stack>
              <Stack direction="row" spacing={1.5} alignItems="flex-start">
                <Chip label="3" size="small" />
                <Typography color="text.secondary" variant="body2">
                  현재 로그인 중인 소유자 계정은 이 화면에서 비활성화하거나 소유자
                  권한을 해제할 수 없습니다.
                </Typography>
              </Stack>
            </Stack>
          </Stack>
        </CardContent>
      </Card>

      {message && <Alert severity={message.type}>{message.text}</Alert>}

      <Card elevation={0}>
        <CardContent>
          <Stack spacing={2}>
            <Alert severity="info">
              Google 로그인 가능한 Firebase Auth 계정만 등록할 수 있습니다.
              이메일이 Auth에 없으면 등록되지 않습니다.
            </Alert>

            <TextField
              label="관리자 이메일"
              placeholder="admin@promiso.app"
              value={createEmail}
              onChange={(event) => setCreateEmail(event.target.value)}
              fullWidth
            />
            <TextField
              select
              label="권한"
              value={createRole}
              onChange={(event) => setCreateRole(event.target.value as AdminRole)}
              fullWidth
            >
              <MenuItem value="owner">소유자</MenuItem>
              <MenuItem value="support">지원</MenuItem>
              <MenuItem value="marketer">마케터</MenuItem>
            </TextField>
            <FormControlLabel
              control={
                <Checkbox
                  checked={createEnabled}
                  onChange={(event) => setCreateEnabled(event.target.checked)}
                />
              }
              label="생성 시 활성화"
            />

            <Stack direction="row" justifyContent="flex-end">
              <Button
                variant="contained"
                disabled={!canCreate || createMutation.isPending}
                onClick={() => {
                  setMessage(null);
                  createMutation.mutate({
                    email: createEmail.trim(),
                    role: createRole,
                    enabled: createEnabled,
                  });
                }}
              >
                {createMutation.isPending ? "생성 중..." : "관리자 계정 생성"}
              </Button>
            </Stack>
          </Stack>
        </CardContent>
      </Card>

      <Card elevation={0}>
        <CardContent>
          <Stack spacing={2}>
            <Stack
              direction={{xs: "column", sm: "row"}}
              justifyContent="space-between"
              spacing={1}
            >
              <Stack spacing={0.5}>
                <Typography variant="h6">현재 관리자 계정</Typography>
                <Typography color="text.secondary" variant="body2">
                  현재 등록된 관리자 계정을 이메일 또는 사용자 ID로 찾고 수정합니다.
                </Typography>
              </Stack>
              <Button
                variant="text"
                disabled={adminUsersQuery.isRefetching}
                onClick={() => void adminUsersQuery.refetch()}
              >
                {adminUsersQuery.isRefetching ? "새로고침 중..." : "새로고침"}
              </Button>
            </Stack>

            <TextField
              label="관리자 계정 검색"
              placeholder="이메일 / 사용자 ID"
              value={searchQuery}
              onChange={(event) => setSearchQuery(event.target.value)}
              fullWidth
            />
          </Stack>
        </CardContent>
      </Card>

      {adminUsersQuery.isPending ? (
        <Stack direction="row" spacing={1} alignItems="center">
          <CircularProgress size={20} />
          <Typography color="text.secondary">
            관리자 계정 목록을 불러오는 중입니다.
          </Typography>
        </Stack>
      ) : adminUsersQuery.isError ? (
        <Alert severity="error">
          {getErrorMessage(
            adminUsersQuery.error,
            "관리자 계정 목록을 불러오지 못했습니다."
          )}
        </Alert>
      ) : visibleAdminUsers.length === 0 ? (
        <Alert severity="info">
          {normalizedSearchQuery ?
            "검색 조건과 일치하는 관리자 계정이 없습니다." :
            "등록된 관리자 계정이 없습니다."}
        </Alert>
      ) : (
        <Stack spacing={2}>
          {visibleAdminUsers.map((user) => (
            <AdminUserCard
              key={user.userId}
              user={user}
              isCurrentUser={adminSession?.userId === user.userId}
              isSaving={
                updateMutation.isPending &&
                updateMutation.variables?.userId === user.userId
              }
              onSave={(params) => {
                setMessage(null);
                updateMutation.mutate(params);
              }}
            />
          ))}
        </Stack>
      )}
    </Stack>
  );
}
