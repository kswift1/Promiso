import React from "react";
import ReactDOM from "react-dom/client";
import {CssBaseline, ThemeProvider} from "@mui/material";
import {QueryClient, QueryClientProvider} from "@tanstack/react-query";
import {BrowserRouter} from "react-router-dom";
import {App} from "./App";
import {AuthProvider} from "./auth/AuthProvider";
import {appTheme} from "./theme";

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <ThemeProvider theme={appTheme}>
          <CssBaseline />
          <BrowserRouter>
            <App />
          </BrowserRouter>
        </ThemeProvider>
      </AuthProvider>
    </QueryClientProvider>
  </React.StrictMode>
);
