import { useGetMe, useLogout } from "@workspace/api-client-react";
import { clearToken } from "@/lib/auth";
import { useLocation } from "wouter";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { User, Shield, Terminal } from "lucide-react";
import { format } from "date-fns";

export default function SettingsPage() {
  const { data: user, isLoading } = useGetMe();
  const logout = useLogout();
  const [, setLocation] = useLocation();

  const handleLogout = () => {
    logout.mutate(undefined, {
      onSettled: () => {
        clearToken();
        setLocation("/login");
      }
    });
  };

  const hasAcknowledgedLegal = localStorage.getItem("cyberlab_legal_ack") === "true";

  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      <div>
        <h1 className="text-3xl font-bold tracking-tight font-mono">Settings</h1>
        <p className="text-muted-foreground font-mono mt-2">
          Operator preferences and system configuration.
        </p>
      </div>

      <div className="grid gap-6">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 font-mono">
              <User className="h-5 w-5 text-primary" />
              Operator Profile
            </CardTitle>
            <CardDescription className="font-mono">
              Your identity and access details.
            </CardDescription>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <div className="space-y-4">
                <Skeleton className="h-4 w-64" />
                <Skeleton className="h-4 w-48" />
              </div>
            ) : user ? (
              <div className="space-y-4 font-mono text-sm">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 border-b border-border pb-4">
                  <div className="text-muted-foreground">Username</div>
                  <div className="md:col-span-2 font-semibold text-foreground">{user.username}</div>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 border-b border-border pb-4">
                  <div className="text-muted-foreground">Email</div>
                  <div className="md:col-span-2">{user.email}</div>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 border-b border-border pb-4">
                  <div className="text-muted-foreground">Operator ID</div>
                  <div className="md:col-span-2 text-xs text-muted-foreground">{user.id}</div>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 pb-2">
                  <div className="text-muted-foreground">Account Created</div>
                  <div className="md:col-span-2">{format(new Date(user.createdAt), "PPP")}</div>
                </div>
              </div>
            ) : null}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 font-mono">
              <Terminal className="h-5 w-5 text-primary" />
              System Information
            </CardTitle>
            <CardDescription className="font-mono">
              API configuration and connection details.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4 font-mono text-sm">
               <div className="grid grid-cols-1 md:grid-cols-3 gap-4 border-b border-border pb-4">
                  <div className="text-muted-foreground">API Base URL</div>
                  <div className="md:col-span-2 text-primary">{window.location.origin}</div>
               </div>
               <div className="grid grid-cols-1 md:grid-cols-3 gap-4 pb-2">
                  <div className="text-muted-foreground">Version</div>
                  <div className="md:col-span-2">v0.1.0-alpha</div>
               </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 font-mono">
              <Shield className="h-5 w-5 text-primary" />
              Compliance
            </CardTitle>
            <CardDescription className="font-mono">
              Legal and operational compliance status.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="font-mono text-sm flex items-center justify-between">
              <div>
                <span className="font-semibold">Legal Warning Acknowledgment</span>
                <p className="text-muted-foreground text-xs mt-1">Required for executing active scans.</p>
              </div>
              <div className={`px-3 py-1 rounded-full text-xs font-semibold ${hasAcknowledgedLegal ? 'bg-primary/20 text-primary' : 'bg-destructive/20 text-destructive'}`}>
                {hasAcknowledgedLegal ? 'ACKNOWLEDGED' : 'PENDING'}
              </div>
            </div>
          </CardContent>
        </Card>

        <div className="flex justify-end pt-4">
          <Button variant="destructive" onClick={handleLogout} className="font-mono">
            Terminate Session
          </Button>
        </div>
      </div>
    </div>
  );
}
