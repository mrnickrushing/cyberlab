import { useGetScan, useGetScanResults, useCancelScan, getGetScanQueryKey } from "@workspace/api-client-react";
import { format } from "date-fns";
import { Link } from "wouter";
import { ArrowLeft, Ban, CheckCircle, AlertCircle, Loader2, Activity, Terminal } from "lucide-react";
import { useQueryClient } from "@tanstack/react-query";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";
import { Progress } from "@/components/ui/progress";

export default function ScanDetailPage({ params }: { params: { id: string } }) {
  const { id } = params;
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const { data: scan, isLoading } = useGetScan(id, {
    query: {
      refetchInterval: (query) => {
        const status = query.state.data?.status;
        return (status === "running" || status === "pending") ? 3000 : false;
      }
    }
  });

  const { data: results, isLoading: resultsLoading } = useGetScanResults(id, {
    query: {
      enabled: !!scan && scan.status === "completed"
    }
  });

  const cancelScan = useCancelScan();

  const handleCancel = () => {
    if (confirm("Cancel this running scan?")) {
      cancelScan.mutate(id, {
        onSuccess: () => {
          toast({ title: "Cancellation requested" });
          queryClient.invalidateQueries({ queryKey: getGetScanQueryKey(id) });
        }
      });
    }
  };

  if (isLoading) return <div className="space-y-4"><Skeleton className="h-32 w-full" /><Skeleton className="h-64 w-full" /></div>;
  if (!scan) return <div className="text-center font-mono py-12 text-destructive">Scan not found.</div>;

  const isRunning = scan.status === "running" || scan.status === "pending";

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Link href={`/targets/${scan.targetId}`}>
          <Button variant="ghost" size="icon" className="h-8 w-8 text-muted-foreground hover:text-primary">
            <ArrowLeft className="h-4 w-4" />
          </Button>
        </Link>
        <div>
          <h1 className="text-3xl font-bold tracking-tight font-mono uppercase flex items-center gap-3">
            {scan.tool} Scan
            <span className={`text-xs px-2 py-1 rounded border ${
              scan.status === 'completed' ? 'border-primary text-primary' : 
              scan.status === 'failed' ? 'border-destructive text-destructive' : 
              isRunning ? 'bg-primary/10 border-primary text-primary animate-pulse' :
              'border-chart-3 text-chart-3'
            }`}>
              {scan.status}
            </span>
          </h1>
          <p className="text-muted-foreground font-mono mt-1 text-sm">
            Target: <Link href={`/targets/${scan.targetId}`} className="hover:underline text-primary">{scan.targetId}</Link>
          </p>
        </div>
        <div className="ml-auto">
          {isRunning && (
            <Button variant="destructive" className="font-mono" onClick={handleCancel} disabled={cancelScan.isPending}>
              <Ban className="mr-2 h-4 w-4" />
              Abort Scan
            </Button>
          )}
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground font-mono mb-1">Started</div>
            <div className="font-mono font-semibold">{scan.startedAt ? format(new Date(scan.startedAt), "HH:mm:ss") : "Pending"}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground font-mono mb-1">Completed</div>
            <div className="font-mono font-semibold">{scan.completedAt ? format(new Date(scan.completedAt), "HH:mm:ss") : "—"}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground font-mono mb-1">Flags</div>
            <div className="font-mono font-semibold text-xs bg-muted p-1 rounded mt-1 truncate">{scan.flags || "Default"}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground font-mono mb-1">Job ID</div>
            <div className="font-mono font-semibold text-xs truncate">{scan.id}</div>
          </CardContent>
        </Card>
      </div>

      {isRunning && (
        <Card className="border-primary/50 bg-primary/5">
          <CardContent className="pt-6">
            <div className="flex justify-between font-mono text-sm mb-2 text-primary">
              <span className="flex items-center gap-2"><Loader2 className="h-4 w-4 animate-spin" /> Scan in progress...</span>
              <span>{scan.progress}%</span>
            </div>
            <Progress value={scan.progress} className="h-2" />
          </CardContent>
        </Card>
      )}

      {scan.errorMessage && (
        <Card className="border-destructive/50 bg-destructive/5">
          <CardContent className="pt-6">
            <div className="flex items-center gap-2 text-destructive font-mono font-bold mb-2">
              <AlertCircle className="h-5 w-5" /> Execution Failed
            </div>
            <div className="font-mono text-sm text-destructive/80 bg-background p-3 rounded border border-destructive/20 whitespace-pre-wrap">
              {scan.errorMessage}
            </div>
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader>
          <CardTitle className="font-mono flex items-center gap-2 text-lg">
            <Terminal className="h-5 w-5 text-primary" /> Raw Output
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="bg-[#0a0a0a] rounded border border-border p-4 h-[400px] overflow-auto">
            {resultsLoading ? (
               <div className="text-muted-foreground font-mono text-sm flex items-center gap-2"><Loader2 className="h-4 w-4 animate-spin" /> Fetching output...</div>
            ) : results ? (
              <pre className="font-mono text-xs text-primary/80 whitespace-pre-wrap">
                {JSON.stringify(results, null, 2)}
              </pre>
            ) : (
              <div className="text-muted-foreground font-mono text-sm">No output available yet.</div>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
