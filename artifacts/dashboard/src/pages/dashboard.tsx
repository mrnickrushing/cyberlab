import { useEffect, useState } from "react";
import { Link } from "wouter";
import { useGetDashboard, useAcknowledgeLegalWarning, getGetDashboardQueryKey } from "@workspace/api-client-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { useToast } from "@/hooks/use-toast";
import { format } from "date-fns";
import { Target, ScanSearch, ShieldAlert, AlertTriangle, ArrowRight, ShieldCheck, Activity } from "lucide-react";
import { useQueryClient } from "@tanstack/react-query";

export default function DashboardPage() {
  const { data: stats, isLoading } = useGetDashboard();
  const [showLegalWarning, setShowLegalWarning] = useState(false);
  const ackLegal = useAcknowledgeLegalWarning();
  const { toast } = useToast();
  const queryClient = useQueryClient();

  useEffect(() => {
    const hasAck = localStorage.getItem("cyberlab_legal_ack");
    if (!hasAck) {
      setShowLegalWarning(true);
    }
  }, []);

  const handleAcknowledge = () => {
    ackLegal.mutate(undefined, {
      onSuccess: () => {
        localStorage.setItem("cyberlab_legal_ack", "true");
        setShowLegalWarning(false);
        toast({ title: "Legal warning acknowledged" });
      },
      onError: (err: any) => {
        toast({ variant: "destructive", title: "Failed to acknowledge", description: err.message });
      }
    });
  };

  return (
    <div className="space-y-6">
      <Dialog open={showLegalWarning}>
        <DialogContent className="sm:max-w-[500px]" hideCloseButton>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 font-mono text-destructive">
              <AlertTriangle className="h-5 w-5" />
              Legal Authorization Required
            </DialogTitle>
            <DialogDescription className="font-mono pt-4 space-y-4">
              <p>
                This system contains active scanning capabilities that may interact with target infrastructure in potentially disruptive ways.
              </p>
              <p className="font-semibold text-foreground">
                You must have explicit, written authorization to scan any targets. Unauthorized scanning may violate local, state, and federal laws.
              </p>
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button 
              onClick={handleAcknowledge} 
              disabled={ackLegal.isPending}
              className="w-full font-mono bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {ackLegal.isPending ? "Acknowledging..." : "I Acknowledge & Accept Responsibility"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <div>
        <h1 className="text-3xl font-bold tracking-tight font-mono">Dashboard</h1>
        <p className="text-muted-foreground font-mono mt-2">
          System overview and operational metrics.
        </p>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {[1,2,3,4].map(i => <Skeleton key={i} className="h-32 w-full" />)}
          <Skeleton className="h-64 w-full md:col-span-2" />
          <Skeleton className="h-64 w-full md:col-span-2" />
        </div>
      ) : stats ? (
        <>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium font-mono">Security Score</CardTitle>
                <ShieldCheck className={`h-4 w-4 ${stats.securityScore > 80 ? 'text-primary' : stats.securityScore > 50 ? 'text-chart-3' : 'text-destructive'}`} />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold font-mono">{stats.securityScore}/100</div>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium font-mono">Monitored Targets</CardTitle>
                <Target className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold font-mono">{stats.targetCount}</div>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium font-mono">Active Scans</CardTitle>
                <ScanSearch className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold font-mono">{stats.activeScans}</div>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium font-mono">Open Findings</CardTitle>
                <ShieldAlert className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold font-mono">{stats.openFindings}</div>
              </CardContent>
            </Card>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Card>
              <CardHeader>
                <CardTitle className="font-mono text-lg flex items-center gap-2">
                  <ScanSearch className="h-5 w-5 text-primary" />
                  Recent Scans
                </CardTitle>
              </CardHeader>
              <CardContent>
                {stats.recentScans.length === 0 ? (
                  <div className="text-muted-foreground font-mono text-sm py-8 text-center border border-dashed rounded">
                    No recent scan activity.
                  </div>
                ) : (
                  <div className="space-y-4">
                    {stats.recentScans.map(scan => (
                      <div key={scan.id} className="flex items-center justify-between border-b border-border pb-4 last:pb-0 last:border-0">
                        <div>
                          <div className="font-mono font-medium">{scan.targetName || scan.targetId}</div>
                          <div className="text-xs text-muted-foreground font-mono flex items-center gap-2 mt-1">
                            <span className="uppercase text-primary">{scan.tool}</span>
                            <span>•</span>
                            <span>{format(new Date(scan.createdAt), "MMM d, HH:mm")}</span>
                          </div>
                        </div>
                        <div className="flex items-center gap-4">
                          <span className={`text-xs font-mono px-2 py-1 border rounded ${
                            scan.status === 'completed' ? 'border-primary text-primary' :
                            scan.status === 'failed' ? 'border-destructive text-destructive' :
                            'border-chart-3 text-chart-3'
                          }`}>
                            {scan.status}
                          </span>
                          <Link href={`/scans/${scan.id}`}>
                            <Button variant="ghost" size="icon" className="h-8 w-8">
                              <ArrowRight className="h-4 w-4" />
                            </Button>
                          </Link>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
                <div className="mt-4">
                  <Link href="/scans">
                    <Button variant="outline" className="w-full font-mono text-xs">View All Scans</Button>
                  </Link>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="font-mono text-lg flex items-center gap-2">
                  <Activity className="h-5 w-5 text-primary" />
                  Lab Health
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4 font-mono text-sm">
                  <div className="flex justify-between items-center p-3 border border-border rounded bg-card">
                    <div className="text-muted-foreground">API Connection</div>
                    <div className="flex items-center gap-2">
                      {stats.labHealth.apiReachable ? (
                        <><div className="h-2 w-2 rounded-full bg-primary" /><span className="text-primary">ONLINE</span></>
                      ) : (
                        <><div className="h-2 w-2 rounded-full bg-destructive" /><span className="text-destructive">OFFLINE</span></>
                      )}
                    </div>
                  </div>
                  <div className="flex justify-between items-center p-3 border border-border rounded bg-card">
                    <div className="text-muted-foreground">Worker Queue Depth</div>
                    <div className="font-bold">{stats.labHealth.workerQueueDepth}</div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </>
      ) : null}
    </div>
  );
}
