import { useState } from "react";
import { useLocation } from "wouter";
import { useListFindings, useUpdateFinding, useDeleteFinding, getListFindingsQueryKey } from "@workspace/api-client-react";
import { ShieldAlert, Search, Trash2, ArrowRight } from "lucide-react";
import { useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";

export default function FindingsPage() {
  const [search, setSearch] = useState("");
  const [severityFilter, setSeverityFilter] = useState<string>("all");
  const [statusFilter, setStatusFilter] = useState<string>("open");
  const [, setLocation] = useLocation();
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const { data: findings, isLoading } = useListFindings({
    severity: severityFilter !== "all" ? severityFilter : undefined,
    status: statusFilter !== "all" ? statusFilter : undefined
  });

  const updateFinding = useUpdateFinding();
  const deleteFinding = useDeleteFinding();

  const handleStatusChange = (id: string, newStatus: any) => {
    updateFinding.mutate({ id, data: { status: newStatus } }, {
      onSuccess: () => {
        toast({ title: "Finding status updated" });
        queryClient.invalidateQueries({ queryKey: getListFindingsQueryKey() });
      }
    });
  };

  const handleDelete = (id: string) => {
    if (confirm("Delete this finding?")) {
      deleteFinding.mutate(id, {
        onSuccess: () => {
          toast({ title: "Finding deleted" });
          queryClient.invalidateQueries({ queryKey: getListFindingsQueryKey() });
        }
      });
    }
  };

  const filteredFindings = findings?.filter(f => 
    !search || f.title.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight font-mono flex items-center gap-2">
            <ShieldAlert className="h-8 w-8 text-primary" />
            Findings
          </h1>
          <p className="text-muted-foreground font-mono mt-2">
            Vulnerabilities and security issues discovered across all targets.
          </p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
            <CardTitle className="font-mono text-xl">Vulnerability Database</CardTitle>
            <div className="flex flex-col sm:flex-row gap-2 w-full sm:w-auto">
              <div className="relative w-full sm:w-64">
                <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search findings..."
                  className="pl-9 font-mono"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
              </div>
              <Select value={severityFilter} onValueChange={setSeverityFilter}>
                <SelectTrigger className="w-full sm:w-[130px] font-mono">
                  <SelectValue placeholder="Severity" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Severities</SelectItem>
                  <SelectItem value="critical">Critical</SelectItem>
                  <SelectItem value="high">High</SelectItem>
                  <SelectItem value="medium">Medium</SelectItem>
                  <SelectItem value="low">Low</SelectItem>
                  <SelectItem value="info">Info</SelectItem>
                </SelectContent>
              </Select>
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger className="w-full sm:w-[130px] font-mono">
                  <SelectValue placeholder="Status" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Statuses</SelectItem>
                  <SelectItem value="open">Open</SelectItem>
                  <SelectItem value="fixed">Fixed</SelectItem>
                  <SelectItem value="accepted_risk">Accepted Risk</SelectItem>
                  <SelectItem value="false_positive">False Positive</SelectItem>
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
          ) : !filteredFindings || filteredFindings.length === 0 ? (
            <div className="py-12 text-center text-muted-foreground font-mono">
              No findings matched your criteria.
            </div>
          ) : (
            <div className="rounded-md border border-border">
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent font-mono">
                    <TableHead>Severity</TableHead>
                    <TableHead>Title</TableHead>
                    <TableHead>Target ID</TableHead>
                    <TableHead>CVSS</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredFindings.map((finding) => (
                    <TableRow 
                      key={finding.id} 
                      className="font-mono text-sm hover:bg-muted/50 transition-colors"
                    >
                      <TableCell>
                        <span className={`uppercase text-[10px] font-bold px-2 py-1 rounded border ${
                          finding.severity === 'critical' ? 'bg-destructive/20 border-destructive text-destructive' :
                          finding.severity === 'high' ? 'bg-chart-2/20 border-chart-2 text-chart-2' :
                          finding.severity === 'medium' ? 'bg-chart-3/20 border-chart-3 text-chart-3' :
                          finding.severity === 'low' ? 'bg-chart-1/20 border-chart-1 text-chart-1' :
                          'bg-muted border-border text-muted-foreground'
                        }`}>
                          {finding.severity}
                        </span>
                      </TableCell>
                      <TableCell>
                        <div className="font-semibold text-foreground truncate max-w-[300px]" title={finding.title}>
                          {finding.title}
                        </div>
                        {finding.cveId && (
                          <div className="text-xs text-muted-foreground mt-1">{finding.cveId}</div>
                        )}
                      </TableCell>
                      <TableCell>
                        <span 
                          className="text-muted-foreground text-xs hover:text-primary cursor-pointer truncate max-w-[150px] inline-block"
                          onClick={() => setLocation(`/targets/${finding.targetId}`)}
                        >
                          {finding.targetId}
                        </span>
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {finding.cvssScore !== null ? finding.cvssScore : "—"}
                      </TableCell>
                      <TableCell>
                        <Select 
                          value={finding.status} 
                          onValueChange={(val) => handleStatusChange(finding.id, val)}
                          disabled={updateFinding.isPending}
                        >
                          <SelectTrigger className="h-8 w-[130px] text-xs font-mono">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="open">Open</SelectItem>
                            <SelectItem value="fixed">Fixed</SelectItem>
                            <SelectItem value="accepted_risk">Accepted Risk</SelectItem>
                            <SelectItem value="false_positive">False Positive</SelectItem>
                          </SelectContent>
                        </Select>
                      </TableCell>
                      <TableCell className="text-right">
                        <Button 
                          variant="ghost" 
                          size="icon" 
                          className="h-8 w-8 text-muted-foreground hover:text-destructive"
                          onClick={() => handleDelete(finding.id)}
                          disabled={deleteFinding.isPending}
                        >
                          <Trash2 className="h-4 w-4" />
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
