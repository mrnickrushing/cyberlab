import { useEffect, useState } from "react";
import { Switch, Route, Router as WouterRouter, useLocation } from "wouter";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import { setupApiInterceptor } from "./lib/api";
import { isLoggedIn } from "./lib/auth";
import NotFound from "@/pages/not-found";
import AppLayout from "@/components/layout/AppLayout";
import Login from "@/pages/login";
import Dashboard from "@/pages/dashboard";
import TargetsPage from "@/pages/targets";
import TargetDetailPage from "@/pages/target-detail";
import ScansPage from "@/pages/scans";
import ScanDetailPage from "@/pages/scan-detail";
import FindingsPage from "@/pages/findings";
import NotesPage from "@/pages/notes";
import AuditPage from "@/pages/audit";
import SettingsPage from "@/pages/settings";

setupApiInterceptor();
const queryClient = new QueryClient();

function ProtectedRoute({ component: Component, ...rest }: any) {
  const [location, setLocation] = useLocation();

  useEffect(() => {
    if (!isLoggedIn()) {
      setLocation("/login");
    }
  }, [location, setLocation]);

  if (!isLoggedIn()) return null;

  return (
    <Route {...rest}>
      {(params) => (
        <AppLayout>
          <Component params={params} />
        </AppLayout>
      )}
    </Route>
  );
}

function Router() {
  return (
    <Switch>
      <Route path="/login" component={Login} />
      <ProtectedRoute path="/" component={Dashboard} />
      <ProtectedRoute path="/targets" component={TargetsPage} />
      <ProtectedRoute path="/targets/:id" component={TargetDetailPage} />
      <ProtectedRoute path="/scans" component={ScansPage} />
      <ProtectedRoute path="/scans/:id" component={ScanDetailPage} />
      <ProtectedRoute path="/findings" component={FindingsPage} />
      <ProtectedRoute path="/notes" component={NotesPage} />
      <ProtectedRoute path="/audit" component={AuditPage} />
      <ProtectedRoute path="/settings" component={SettingsPage} />
      <Route component={NotFound} />
    </Switch>
  );
}

function App() {
  useEffect(() => {
    document.documentElement.classList.add("dark");
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <WouterRouter base={import.meta.env.BASE_URL.replace(/\/$/, "")}>
          <Router />
        </WouterRouter>
        <Toaster />
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
