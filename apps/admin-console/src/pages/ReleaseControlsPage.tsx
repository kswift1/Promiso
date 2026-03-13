import {ChangeEvent, useState} from "react";
import {
  Alert,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import {useMutation, useQuery, useQueryClient} from "@tanstack/react-query";
import {
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
  versionNumber: null,
  updateTime: null,
  updateUserEmail: null,
};

export function ReleaseControlsPage() {
  const queryClient = useQueryClient();
  const [draftControls, setDraftControls] = useState<AdminReleaseControls | null>(
    null
  );
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

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
    },
  });

  const controls = draftControls ?? controlsQuery.data ?? emptyControls;
  const errorMessage = controlsQuery.error instanceof Error ?
    controlsQuery.error.message :
    saveMutation.error instanceof Error ?
      saveMutation.error.message :
      controlsQuery.isError ?
        "릴리즈 제어 설정을 불러오지 못했습니다." :
        saveMutation.isError ?
          "Release Controls를 저장하지 못했습니다." :
          null;

  const handleChange = (field: keyof AdminReleaseControls) =>
    (event: ChangeEvent<HTMLInputElement>) => {
      const {value} = event.target;
      setSuccessMessage(null);
      setDraftControls((current) => ({
        ...(current ?? controls),
        [field]: value,
      }));
    };

  const handleSave = () => {
    setSuccessMessage(null);
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
          Firebase Remote Config 값을 직접 조회하고 수정합니다.
        </Typography>
      </Stack>

      {errorMessage && <Alert severity="error">{errorMessage}</Alert>}
      {successMessage && <Alert severity="success">{successMessage}</Alert>}

      <Card elevation={0}>
        <CardContent>
          {controlsQuery.isPending ? (
            <Stack
              alignItems="center"
              justifyContent="center"
              minHeight={240}
            >
              <CircularProgress size={28} />
            </Stack>
          ) : (
            <Stack spacing={2.5}>
              <Stack spacing={0.5}>
                <Typography variant="subtitle2">Last Publish</Typography>
                <Typography color="text.secondary" variant="body2">
                  Version {controls.versionNumber ?? "-"}
                </Typography>
                <Typography color="text.secondary" variant="body2">
                  Updated At {controls.updateTime ?? "-"}
                </Typography>
                <Typography color="text.secondary" variant="body2">
                  Updated By {controls.updateUserEmail ?? "-"}
                </Typography>
              </Stack>

              <TextField
                label="Force Update Version"
                value={controls.forceUpdateVersion}
                onChange={handleChange("forceUpdateVersion")}
                fullWidth
              />
              <TextField
                label="Recommended Version"
                value={controls.recommendedVersion}
                onChange={handleChange("recommendedVersion")}
                fullWidth
              />
              <TextField
                label="App Store URL"
                value={controls.appStoreURL}
                onChange={handleChange("appStoreURL")}
                fullWidth
              />
              <TextField
                label="Privacy Policy URL"
                value={controls.privacyPolicyURL}
                onChange={handleChange("privacyPolicyURL")}
                fullWidth
              />
              <TextField
                label="Terms of Service URL"
                value={controls.termsOfServiceURL}
                onChange={handleChange("termsOfServiceURL")}
                fullWidth
              />
              <TextField
                label="Support Email"
                value={controls.supportEmail}
                onChange={handleChange("supportEmail")}
                fullWidth
              />
              <TextField
                label="Notion FAQ Database ID"
                value={controls.notionFAQDatabaseId}
                onChange={handleChange("notionFAQDatabaseId")}
                fullWidth
              />

              <Stack direction="row" justifyContent="flex-end">
                <Button
                  variant="contained"
                  onClick={handleSave}
                  disabled={saveMutation.isPending}
                >
                  {saveMutation.isPending ? "Saving..." : "Save Changes"}
                </Button>
              </Stack>
            </Stack>
          )}
        </CardContent>
      </Card>
    </Stack>
  );
}
