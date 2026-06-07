import { useGetTarget, useListScans, useListFindings, useListNotes, useCreateScan, getListScansQueryKey, useAcknowledgeLegalWarning } from "@workspace/api-client-react";
import { useState, useEffect } from "react";
import { format } from "date-fns";
import { useQueryClient } from "@tanstack/react-query";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { ShieldAlert, Target, Terminal, StickyNote, Activity, Plus } from "lucide-react";
import { Link, useLocation } from "wouter";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Skeleton } from "@/components/ui/skeleton";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { useToast } from "@/hooks/use-toast";

const scanSchema = z.object({
  tool: z.string().min(1, "Tool is required"),
  flags: z.string().optional(),
});

export default function TargetDetailPage({ params }: { params: { id: string } }) {
  const { id } = params;
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [isScanOpen, setIsScanOpen] = useState(false);
  const [, setLocation] = useLocation();

  const { data: target, isLoading: isLoadingTarget } = useGetTarget(id);
  const { data: scans, isLoading: isLoadingScans } = useListScans({ targetId: id });
  const { data: findings, isLoading: isLoadingFindings } = useListFindings({ targetId: id });
  const { data: notes, isLoading: isLoadingNotes } = useListNotes({ targetId: id });

  const createScan = useCreateScan();
  const ackLegal = useAcknowledgeLegalWarning();

  const form = useForm<z.infer<typeof scanSchema>>({
    resolver: zodResolver(scanSchema),
    defaultValues: { tool: "nmap", flags: "" }
  });

  const onLaunchScan = (data: z.infer<typeof scanSchema>) => {
    const hasAck = localStorage.getItem("cyberlab_legal_ack");
    if (!hasAck) {
      toast({ variant: "destructive", title: "Legal Warning", description: "You must acknowledge the legal warning in Dashboard or Settings before scanning." });
      return;
    }

    createScan.mutate({ 
      data: { targetId: id, tool: data.tool, flags: data.flags || undefined } 
    }, {
      onSuccess: () => {
        toast({ title: "Scan launched successfully" });
        queryClient.invalidateQueries({ queryKey: getListScansQueryKey() });
        setIsScanOpen(false);
        form.reset();
      },
      onError: (err: any) => {
        toast({ variant: "destructive", title: "Failed to launch scan", description: err.message });
      }
    });
  };

  if (isLoadingTarget) return <div className="space-y-4"><Skeleton className="h-24 w-full" /><Skeleton className="h-64 w-full" /></div>;
  if (!target) return <div className="text-center font-mono py-12 text-destructive">Target not found.</div>;

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <div className="flex items-center gap-2">
            <Target className="h-8 w-8 text-primary" />
            <h1 className="text-3xl font-bold tracking-tight font-mono">{target.name}</h1>
          </div>
          <p className="text-muted-foreground font-mono mt-2 text-lg">
            {target.address}
          </p>
        </div>
        <div className="flex gap-2">
          <Dialog open={isScanOpen} onOpenChange={setIsScanOpen}>
            <DialogTrigger asChild>
              <Button className="font-mono">
                <Terminal className="mr-2 h-4 w-4" />
                Launch Scan
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px]">
              <DialogHeader>
                <DialogTitle className="font-mono">Execute Scan</DialogTitle>
                <DialogDescription className="font-mono">
                  Configure tool and parameters for {target.address}.
                </DialogDescription>
              </DialogHeader>
              <Form {...form}>
                <form onSubmit={form.handleSubmit(onLaunchScan)} className="space-y-4 font-mono">
                  <FormField control={form.control} name="tool" render={({ field }) => (
                    <FormItem>
                      <FormLabel>Tool</FormLabel>
                      <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger><SelectValue placeholder="Select tool" /></SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="nmap">Nmap (Port Scan)</SelectItem>
                          <SelectItem value="nuclei">Nuclei (Vuln Scan)</SelectItem>
                          <SelectItem value="ffuf">FFuF (Fuzzing)</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )} />
                  <FormField control={form.control} name="flags" render={({ field }) => (
                    <FormItem>
                      <FormLabel>Custom Flags (Optional)</FormLabel>
                      <FormControl><Input placeholder="-sV -sC -p-" {...field} /></FormControl>
                      <FormMessage />
                    </FormItem>
                  )} />
                  <DialogFooter>
                    <Button type="submit" disabled={createScan.isPending}>
                      {createScan.isPending ? "Launching..." : "Execute"}
                    </Button>
                  </DialogFooter>
                </form>
              </Form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground font-mono mb-1">Type</div>
            <div className="font-mono font-semibold uppercase">{target.type}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground font-mono mb-1">Authorization</div>
            <div className={`font-mono font-semibold ${target.authorizationStatus === 'authorized' ? 'text-primary' : 'text-destructive'}`}>
              {target.authorizationStatus.toUpperCase()}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground font-mono mb-1">Risk Level</div>
            <div className="font-mono font-semibold uppercase text-chart-2">{target.riskLevel}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground font-mono mb-1">Added On</div>
            <div className="font-mono font-semibold">{format(new Date(target.createdAt), "MMM d, yyyy")}</div>
          </CardContent>
        </Card>
      </div>

      <Tabs defaultValue="scans" className="w-full">
        <TabsList className="font-mono grid w-full grid-cols-3">
          <TabsTrigger value="scans">Scan History</TabsTrigger>
          <TabsTrigger value="findings">Findings</TabsTrigger>
          <TabsTrigger value="notes">Notes</TabsTrigger>
        </TabsList>
        
        <TabsContent value="scans" className="mt-4">
          <Card>
            <CardHeader>
              <CardTitle className="font-mono flex items-center gap-2 text-lg">
                <Activity className="h-5 w-5 text-primary" /> Scan History
              </CardTitle>
            </CardHeader>
            <CardContent>
              {isLoadingScans ? <Skeleton className="h-32 w-full" /> : 
                (!scans || scans.length === 0) ? (
                  <div className="py-8 text-center text-muted-foreground font-mono border border-dashed rounded">No scans performed on this target.</div>
                ) : (
                  <div className="space-y-4">
                    {scans.map(scan => (
                      <div key={scan.id} className="flex justify-between items-center p-3 border rounded hover:bg-muted/50 transition-colors cursor-pointer" onClick={() => setLocation(`/scans/${scan.id}`)}>
                        <div>
                          <div className="font-mono font-bold uppercase">{scan.tool}</div>
                          <div className="text-xs text-muted-foreground font-mono">{format(new Date(scan.createdAt), "PPP HH:mm:ss")}</div>
                        </div>
                        <span className={`text-xs px-2 py-1 rounded border font-mono ${
                          scan.status === 'completed' ? 'border-primary text-primary' : 
                          scan.status === 'running' ? 'border-chart-3 text-chart-3 animate-pulse' :
                          'border-destructive text-destructive'
                        }`}>
                          {scan.status}
                        </span>
                      </div>
                    ))}
                  </div>
                )
              }
            </CardContent>
          </Card>
        </TabsContent>
        
        <TabsContent value="findings" className="mt-4">
          <Card>
            <CardHeader>
              <CardTitle className="font-mono flex items-center gap-2 text-lg">
                <ShieldAlert className="h-5 w-5 text-primary" /> Discovered Findings
              </CardTitle>
            </CardHeader>
            <CardContent>
              {isLoadingFindings ? <Skeleton className="h-32 w-full" /> : 
                (!findings || findings.length === 0) ? (
                  <div className="py-8 text-center text-muted-foreground font-mono border border-dashed rounded">No findings discovered.</div>
                ) : (
                  <div className="space-y-4">
                    {findings.map(finding => (
                      <div key={finding.id} className="p-3 border rounded">
                        <div className="flex justify-between items-start mb-2">
                          <div className="font-mono font-bold text-sm">{finding.title}</div>
                          <span className="uppercase text-[10px] font-bold px-2 py-1 rounded border border-border bg-muted">
                            {finding.severity}
                          </span>
                        </div>
                        <div className="text-xs font-mono text-muted-foreground flex justify-between">
                          <span>Status: {finding.status}</span>
                          {finding.cvssScore && <span>CVSS: {finding.cvssScore}</span>}
                        </div>
                      </div>
                    ))}
                  </div>
                )
              }
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="notes" className="mt-4">
          <Card>
            <CardHeader>
              <CardTitle className="font-mono flex items-center gap-2 text-lg">
                <StickyNote className="h-5 w-5 text-primary" /> Target Notes
              </CardTitle>
            </CardHeader>
            <CardContent>
              {isLoadingNotes ? <Skeleton className="h-32 w-full" /> : 
                (!notes || notes.length === 0) ? (
                  <div className="py-8 text-center text-muted-foreground font-mono border border-dashed rounded">No notes for this target.</div>
                ) : (
                  <div className="space-y-4">
                    {notes.map(note => (
                      <div key={note.id} className="p-3 border rounded bg-card">
                        {note.title && <div className="font-mono font-bold text-sm mb-1">{note.title}</div>}
                        <p className="font-mono text-sm whitespace-pre-wrap text-muted-foreground">{note.body}</p>
                        <div className="text-xs font-mono text-muted-foreground mt-2 border-t pt-2">
                          {format(new Date(note.createdAt), "PPP")}
                        </div>
                      </div>
                    ))}
                  </div>
                )
              }
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
