import { useLocation } from "wouter";
import { useListScans, useCancelScan, getListScansQueryKey } from "@workspace/api-client-react";
import { useState } from "react";
import { format } from "date-fns";
import { ScanSearch, Search, Filter, Ban, ArrowRight } from "lucide-react";
import { useQueryClient } from "@tanstack/react-query";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";

export default function ScansPage() {
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [, setLocation] = useLocation();
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const { data: scans, isLoading } = useListScans({
    status: statusFilter !== "all" ? (statusFilter as any) : undefined
  }, {
    query: {
      refetchInterval: (query) => {
        const hasRunning = query.state.data?.some(s => s.status === "running" || s.status === "pending");
        return hasRunning ? 3000 : false;
      }
    }
  });

  const cancelScan = useCancelScan();

  const handleCancel = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    if (confirm("Cancel this scan?")) {
      cancelScan.mutate(id, {
        onSuccess: () => {
          toast({ title: "Scan cancelled" });
          queryClient.invalidateQueries({ queryKey: getListScansQueryKey() });
        }
      });
    }
  };

  const filteredScans = scans?.filter(s => 
    !search || 
    (s as any).targetName?.toLowerCase().includes(search.toLowerCase()) ||
    s.tool.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight font-mono">Scans</h1>
          <p className="text-muted-foreground font-mono mt-2">
            Active and historical scanning jobs.
          </p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
            <CardTitle className="font-mono text-xl">Job Queue</CardTitle>
            <div className="flex flex-col sm:flex-row gap-2 w-full sm:w-auto">
              <div className="relative w-full sm:w-64">
                <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Filter by target or tool..."
                  className="pl-9 font-mono"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
              </div>
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger className="w-full sm:w-[150px] font-mono">
                  <SelectValue placeholder="Status" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Statuses</SelectItem>
                  <SelectItem value="pending">Pending</SelectItem>
                  <SelectItem value="running">Running</SelectItem>
                  <SelectItem value="completed">Completed</SelectItem>
                  <SelectItem value="failed">Failed</SelectItem>
                  <SelectItem value="cancelled">Cancelled</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-2">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-12 w-full" />
              <Skeleton className="h-12 w-full" />
            </div>
          ) : !filteredScans || filteredScans.length === 0 ? (
            <div className="py-12 text-center text-muted-foreground font-mono">
              No scans found matching criteria.
            </div>
          ) : (
            <div className="rounded-md border border-border">
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent font-mono">
                    <TableHead>Target</TableHead>
                    <TableHead>Tool</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Started</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredScans.map((scan) => (
                    <TableRow 
                      key={scan.id} 
                      className="font-mono text-sm cursor-pointer hover:bg-muted/50 transition-colors"
                      onClick={() => setLocation(`/scans/${scan.id}`)}
                    >
                      <TableCell>
                        <div className="font-semibold text-foreground">{(scan as any).targetName || scan.targetId}</div>
                      </TableCell>
                      <TableCell>
                        <span className="uppercase text-xs font-semibold px-2 py-1 bg-secondary rounded text-secondary-foreground border border-secondary-border">
                          {scan.tool}
                        </span>
                      </TableCell>
                      <TableCell>
                        <span className={`text-xs px-2 py-1 rounded border ${
                          scan.status === 'completed' ? 'border-primary text-primary' : 
                          scan.status === 'failed' ? 'border-destructive text-destructive' : 
                          scan.status === 'running' ? 'bg-primary/10 border-primary text-primary animate-pulse' :
                          'border-chart-3 text-chart-3'
                        }`}>
                          {scan.status}
                        </span>
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {scan.startedAt ? format(new Date(scan.startedAt), "MMM d, HH:mm:ss") : "—"}
                      </TableCell>
                      <TableCell className="text-right">
                        {(scan.status === 'running' || scan.status === 'pending') && (
                          <Button 
                            variant="ghost" 
                            size="icon" 
                            className="h-8 w-8 text-muted-foreground hover:text-destructive mr-1"
                            onClick={(e) => handleCancel(e, scan.id)}
                            disabled={cancelScan.isPending}
                          >
                            <Ban className="h-4 w-4" />
                          </Button>
                        )}
                        <Button variant="ghost" size="icon" className="h-8 w-8 text-muted-foreground hover:text-primary">
                          <ArrowRight className="h-4 w-4" />
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
