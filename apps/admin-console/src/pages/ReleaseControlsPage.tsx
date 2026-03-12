import {
  Card,
  CardContent,
  List,
  ListItem,
  ListItemText,
  Stack,
  Typography,
} from "@mui/material";

const controls = [
  "forceUpdateVersion",
  "recommendedVersion",
  "supportEmail",
  "FAQ / terms / privacy links",
  "ProPlan feature flags",
];

export function ReleaseControlsPage() {
  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">Release Controls</Typography>
        <Typography color="text.secondary">
          Remote Config 기반의 릴리즈 제어 항목을 묶어 관리합니다.
        </Typography>
      </Stack>

      <Card elevation={0}>
        <CardContent>
          <List>
            {controls.map((control) => (
              <ListItem key={control} disableGutters>
                <ListItemText primary={control} />
              </ListItem>
            ))}
          </List>
        </CardContent>
      </Card>
    </Stack>
  );
}

