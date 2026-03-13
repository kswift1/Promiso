import {ChangeEvent, useState} from "react";
import {
  Alert,
  Button,
  Card,
  CardContent,
  Checkbox,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControlLabel,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import {useMutation, useQuery, useQueryClient} from "@tanstack/react-query";
import {useAuth} from "../auth/AuthProvider";
import {
  AdminReleaseControlField,
  AdminReleaseControlSection,
  AdminReleaseControls,
  getAdminReleaseControls,
  updateAdminReleaseControls,
} from "../api/admin";

const emptyControls: AdminReleaseControls = {
  forceUpdateVersion: "",
  recommendedVersion: "",
  appStoreURL: "",
  privacyPolicyURL: "",
  termsOfServiceURL: "",
  supportEmail: "",
  notionFAQDatabaseId: "",
  fields: [],
  versionNumber: null,
  updateTime: null,
  updateUserEmail: null,
};

function formatValue(value: string | null, fallback = "-"): string {
  return value && value.length > 0 ? value : fallback;
}

function formatDateTime(value: string | null, fallback = "-"): string {
  if (!value) {
    return fallback;
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat("ko-KR", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(date);
}

function getErrorMessage(error: unknown, fallback: string): string {
  return error instanceof Error && error.message.length > 0 ?
    error.message :
    fallback;
}

function getInputType(field: AdminReleaseControlField) {
  if (field.valueType === "url") {
    return "url";
  }

  if (field.valueType === "email") {
    return "email";
  }

  return "text";
}

type ReleaseControlChange = {
  field: AdminReleaseControlField;
  before: string;
  after: string;
};

type ReleaseControlSectionGroup = {
  key: AdminReleaseControlSection;
  label: string;
  fields: AdminReleaseControlField[];
};

export function ReleaseControlsPage() {
  const {adminSession} = useAuth();
  const queryClient = useQueryClient();
  const [draftControls, setDraftControls] = useState<AdminReleaseControls | null>(
    null
  );
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [confirmedRisk, setConfirmedRisk] = useState(false);

  const controlsQuery = useQuery({
    queryKey: ["admin-release-controls"],
    queryFn: getAdminReleaseControls,
  });

  const saveMutation = useMutation({
    mutationFn: updateAdminReleaseControls,
    onSuccess: (nextControls) => {
      queryClient.setQueryData(["admin-release-controls"], nextControls);
      setDraftControls(nextControls);
      setSuccessMessage("Release Controls를 저장했습니다.");
      setConfirmOpen(false);
      setConfirmedRisk(false);
    },
  });

  const baseControls = controlsQuery.data ?? emptyControls;
  const controls = draftControls ?? baseControls;
  const currentRole = adminSession?.role ?? null;
  const sectionGroups = controls.fields.reduce<ReleaseControlSectionGroup[]>(
    (groups, field) => {
      const group = groups.find((item) => item.key === field.section);

      if (group) {
        group.fields.push(field);
        return groups;
      }

      groups.push({
        key: field.section,
        label: field.sectionLabel,
        fields: [field],
      });
      return groups;
    },
    []
  );
  const changes = baseControls.fields.reduce<ReleaseControlChange[]>(
    (items, field) => {
      const before = baseControls[field.key];
      const after = controls[field.key];

      if (before === after) {
        return items;
      }

      items.push({field, before, after});
      return items;
    },
    []
  );
  const riskyChanges = changes.filter((item) => Boolean(item.field.warning));
  const canSave = changes.length > 0 && !saveMutation.isPending;
  const errorMessage = controlsQuery.error instanceof Error ?
    controlsQuery.error.message :
    saveMutation.error instanceof Error ?
      saveMutation.error.message :
      controlsQuery.isError ?
        "Release Controls를 불러오지 못했습니다." :
        saveMutation.isError ?
          "Release Controls를 저장하지 못했습니다." :
          null;

  const handleChange = (field: AdminReleaseControlField) =>
    (event: ChangeEvent<HTMLInputElement>) => {
      const {value} = event.target;
      setSuccessMessage(null);
      setDraftControls((current) => ({
        ...(current ?? controls),
        [field.key]: value,
      }));
    };

  const handleSave = () => {
    setSuccessMessage(null);
    setConfirmOpen(true);
  };

  const handleConfirm = () => {
    saveMutation.mutate({
      forceUpdateVersion: controls.forceUpdateVersion,
      recommendedVersion: controls.recommendedVersion,
      appStoreURL: controls.appStoreURL,
      privacyPolicyURL: controls.privacyPolicyURL,
      termsOfServiceURL: controls.termsOfServiceURL,
      supportEmail: controls.supportEmail,
      notionFAQDatabaseId: controls.notionFAQDatabaseId,
    });
  };

  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">Release Controls</Typography>
        <Typography color="text.secondary">
          Firebase Remote Config 값을 역할별로 안전하게 조회하고 수정합니다.
        </Typography>
      </Stack>

      <Card elevation={0}>
        <CardContent>
          <Stack spacing={2}>
            <Typography variant="h6">운영 가이드</Typography>
            <Stack spacing={1.5}>
              <Stack direction="row" spacing={1.5} alignItems="flex-start">
                <Chip label="1" size="small" />
                <Stack spacing={0.5}>
                  <Typography variant="subtitle2">
                    `marketer`는 고객 노출 정보만 수정
                  </Typography>
                  <Typography color="text.secondary" variant="body2">
                    `forceUpdateVersion`, `recommendedVersion`은 owner만 수정할 수
                    있습니다. marketer는 링크/지원 정보만 다룹니다.
                  </Typography>
                </Stack>
              </Stack>
              <Stack direction="row" spacing={1.5} alignItems="flex-start">
                <Chip label="2" size="small" />
                <Stack spacing={0.5}>
                  <Typography variant="subtitle2">
                    저장 전에 변경 요약 확인
                  </Typography>
                  <Typography color="text.secondary" variant="body2">
                    어떤 키가 어떻게 바뀌는지 아래 변경 카드와 확인 다이얼로그에서
                    먼저 검토합니다.
                  </Typography>
                </Stack>
              </Stack>
              <Stack direction="row" spacing={1.5} alignItems="flex-start">
                <Chip label="3" size="small" />
                <Stack spacing={0.5}>
                  <Typography variant="subtitle2">
                    저장 후 Last Publish 재확인
                  </Typography>
                  <Typography color="text.secondary" variant="body2">
                    저장 직후 publish 버전과 시간, 수정자를 확인해서 의도한 변경이
                    반영됐는지 바로 점검합니다.
                  </Typography>
                </Stack>
              </Stack>
            </Stack>
          </Stack>
        </CardContent>
      </Card>

      {currentRole === "marketer" && (
        <Alert severity="info">
          현재 계정은 `marketer` 권한입니다. 버전 제어 항목은 읽기 전용으로
          표시되고, 고객 노출 링크/지원 정보만 수정할 수 있습니다.
        </Alert>
      )}

      {errorMessage && <Alert severity="error">{errorMessage}</Alert>}
      {successMessage && <Alert severity="success">{successMessage}</Alert>}

      <Card elevation={0}>
        <CardContent>
          {controlsQuery.isPending ? (
            <Stack
              alignItems="center"
              justifyContent="center"
              minHeight={240}
              spacing={1}
            >
              <CircularProgress size={28} />
              <Typography color="text.secondary">
                Release Controls를 불러오는 중입니다.
              </Typography>
            </Stack>
          ) : (
            <Stack spacing={3}>
              <Stack spacing={0.5}>
                <Typography variant="subtitle2">Last Publish</Typography>
                <Typography color="text.secondary" variant="body2">
                  Version {formatValue(controls.versionNumber)}
                </Typography>
                <Typography color="text.secondary" variant="body2">
                  Updated At {formatDateTime(controls.updateTime)}
                </Typography>
                <Typography color="text.secondary" variant="body2">
                  Updated By {formatValue(controls.updateUserEmail)}
                </Typography>
              </Stack>

              {sectionGroups.map((section) => (
                <Card
                  key={section.key}
                  elevation={0}
                  sx={{bgcolor: "rgba(15, 23, 42, 0.03)", borderRadius: 2}}
                >
                  <CardContent>
                    <Stack spacing={2}>
                      <Stack spacing={0.5}>
                        <Typography variant="h6">{section.label}</Typography>
                        <Typography color="text.secondary" variant="body2">
                          {section.key === "version" &&
                            "업데이트 강제/권장과 스토어 이동 링크를 관리합니다."}
                          {section.key === "legal" &&
                            "결제/설정 화면에서 노출하는 법률 링크를 관리합니다."}
                          {section.key === "support" &&
                            "고객 문의와 FAQ 연결 정보를 관리합니다."}
                        </Typography>
                      </Stack>

                      {section.fields.map((field, index) => {
                        const editable = currentRole ?
                          field.editableRoles.includes(currentRole) :
                          false;
                        const changed = baseControls[field.key] !== controls[field.key];

                        return (
                          <Stack key={field.key} spacing={1.25}>
                            <Stack
                              direction="row"
                              spacing={1}
                              alignItems="center"
                              flexWrap="wrap"
                            >
                              <Typography variant="subtitle2">
                                {field.label}
                              </Typography>
                              <Chip
                                label={editable ? "Editable" : "Owner only"}
                                size="small"
                                color={editable ? "success" : "default"}
                              />
                              {changed && (
                                <Chip
                                  label="Changed"
                                  size="small"
                                  color="warning"
                                />
                              )}
                            </Stack>

                            <Typography color="text.secondary" variant="body2">
                              {field.description}
                            </Typography>

                            {field.warning && (
                              <Alert severity="warning">{field.warning}</Alert>
                            )}

                            <TextField
                              label={field.label}
                              type={getInputType(field)}
                              value={controls[field.key]}
                              onChange={handleChange(field)}
                              disabled={!editable || saveMutation.isPending}
                              fullWidth
                            />

                            {index < section.fields.length - 1 && <Divider />}
                          </Stack>
                        );
                      })}
                    </Stack>
                  </CardContent>
                </Card>
              ))}

              <Card elevation={0} sx={{border: "1px solid", borderColor: "divider"}}>
                <CardContent>
                  <Stack spacing={1.5}>
                    <Typography variant="h6">변경 요약</Typography>
                    {changes.length === 0 ? (
                      <Typography color="text.secondary" variant="body2">
                        아직 변경된 항목이 없습니다.
                      </Typography>
                    ) : (
                      changes.map((item) => (
                        <Stack key={item.field.key} spacing={0.5}>
                          <Typography variant="subtitle2">
                            {item.field.label}
                          </Typography>
                          <Typography color="text.secondary" variant="body2">
                            Before: {formatValue(item.before)}
                          </Typography>
                          <Typography color="text.secondary" variant="body2">
                            After: {formatValue(item.after)}
                          </Typography>
                        </Stack>
                      ))
                    )}
                  </Stack>
                </CardContent>
              </Card>

              <Stack direction="row" justifyContent="flex-end">
                <Button
                  variant="contained"
                  onClick={handleSave}
                  disabled={!canSave}
                >
                  {saveMutation.isPending ? "Saving..." : "Review Changes"}
                </Button>
              </Stack>
            </Stack>
          )}
        </CardContent>
      </Card>

      <Dialog
        open={confirmOpen}
        onClose={() => {
          if (!saveMutation.isPending) {
            setConfirmOpen(false);
            setConfirmedRisk(false);
          }
        }}
        fullWidth
        maxWidth="sm"
      >
        <DialogTitle>Release Controls 변경 확인</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{pt: 1}}>
            <Typography color="text.secondary" variant="body2">
              아래 변경 내용이 맞는지 확인한 뒤 저장합니다.
            </Typography>

            {changes.map((item) => (
              <Stack key={item.field.key} spacing={0.5}>
                <Typography variant="subtitle2">{item.field.label}</Typography>
                <Typography color="text.secondary" variant="body2">
                  Before: {formatValue(item.before)}
                </Typography>
                <Typography color="text.secondary" variant="body2">
                  After: {formatValue(item.after)}
                </Typography>
              </Stack>
            ))}

            {riskyChanges.length > 0 && (
              <Alert severity="warning">
                버전 제어 항목이 포함되어 있습니다. 구버전 사용자가 업데이트
                흐름에 바로 영향을 받을 수 있습니다.
              </Alert>
            )}

            {riskyChanges.length > 0 && (
              <FormControlLabel
                control={
                  <Checkbox
                    checked={confirmedRisk}
                    onChange={(event) => setConfirmedRisk(event.target.checked)}
                  />
                }
                label="버전 제어 변경 영향 범위를 확인했습니다."
              />
            )}
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button
            onClick={() => {
              setConfirmOpen(false);
              setConfirmedRisk(false);
            }}
            disabled={saveMutation.isPending}
          >
            Cancel
          </Button>
          <Button
            variant="contained"
            onClick={handleConfirm}
            disabled={saveMutation.isPending || (riskyChanges.length > 0 &&
              !confirmedRisk)}
          >
            {saveMutation.isPending ? "Saving..." : "Confirm Save"}
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
