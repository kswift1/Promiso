import {
  Card,
  CardContent,
  Chip,
  Grid,
  Stack,
  Typography,
} from "@mui/material";

const dashboardCards = [
  {
    title: "Launch Critical",
    items: ["User lookup", "Entitlement override", "Push jobs"],
    tone: "primary" as const,
  },
  {
    title: "Release Control",
    items: ["Force update", "Recommended version", "Feature flags"],
    tone: "secondary" as const,
  },
  {
    title: "Operational Safety",
    items: ["Admin audit logs", "Dry-run push", "Role-based actions"],
    tone: "default" as const,
  },
];

export function DashboardPage() {
  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">Dashboard</Typography>
        <Typography color="text.secondary">
          운영 콘솔 MVP의 핵심 영역을 한 화면에서 정리합니다.
        </Typography>
      </Stack>

      <Grid container spacing={2}>
        {dashboardCards.map((card) => (
          <Grid key={card.title} size={{xs: 12, md: 4}}>
            <Card elevation={0} sx={{height: "100%"}}>
              <CardContent>
                <Stack spacing={2}>
                  <Chip
                    label={card.title}
                    color={card.tone}
                    sx={{alignSelf: "flex-start"}}
                  />
                  <Stack spacing={1}>
                    {card.items.map((item) => (
                      <Typography key={item} variant="body2">
                        {item}
                      </Typography>
                    ))}
                  </Stack>
                </Stack>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Stack>
  );
}

