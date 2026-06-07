import { useState } from "react";
import { Link, useLocation } from "wouter";
import { useListTargets, useCreateTarget, useDeleteTarget, getListTargetsQueryKey } from "@workspace/api-client-react";
import { TargetType, TargetAuthorizationStatus, TargetRiskLevel } from "@workspace/api-client-react";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Target, Search, Plus, Trash2, ArrowRight, ShieldAlert } from "lucide-react";
import { useQueryClient } from "@tanstack/react-query";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";

const createTargetSchema = z.object({
  name: z.string().min(1, "Name is required"),
  address: z.string().min(1, "Address is required"),
  type: z.enum(["ip", "domain", "subnet", "webapp"]),
});

export default function TargetsPage() {
  const [search, setSearch] = useState("");
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [, setLocation] = useLocation();

  const { data: targets, isLoading } = useListTargets();
  const createTarget = useCreateTarget();
  const deleteTarget = useDeleteTarget();

  const form = useForm<z.infer<typeof createTargetSchema>>({
    resolver: zodResolver(createTargetSchema),
    defaultValues: { name: "", address: "", type: "domain" }
  });

  const onSubmit = (data: z.infer<typeof createTargetSchema>) => {
    createTarget.mutate({ data }, {
      onSuccess: () => {
        toast({ title: "Target created successfully" });
        queryClient.invalidateQueries({ queryKey: getListTargetsQueryKey() });
        setIsCreateOpen(false);
        form.reset();
      },
      onError: (err: any) => {
        toast({ variant: "destructive", title: "Failed to create target", description: err.message });
      }
    });
  };

  const handleDelete = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    if (confirm("Delete this target permanently?")) {
      deleteTarget.mutate(id, {
        onSuccess: () => {
          toast({ title: "Target deleted" });
          queryClient.invalidateQueries({ queryKey: getListTargetsQueryKey() });
        }
      });
    }
  };

  const filteredTargets = targets?.filter(t => 
    !search || t.name.toLowerCase().includes(search.toLowerCase()) || t.address.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight font-mono">Targets</h1>
          <p className="text-muted-foreground font-mono mt-2">
            Manage monitored infrastructure and assets.
          </p>
        </div>
        
        <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
          <DialogTrigger asChild>
            <Button className="font-mono">
              <Plus className="mr-2 h-4 w-4" />
              Add Target
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[425px]">
            <DialogHeader>
              <DialogTitle className="font-mono">Add New Target</DialogTitle>
              <DialogDescription className="font-mono">
                Define a new asset for monitoring and scanning.
              </DialogDescription>
            </DialogHeader>
            <Form {...form}>
              <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 font-mono">
                <FormField control={form.control} name="name" render={({ field }) => (
                  <FormItem>
                    <FormLabel>Name / Identifier</FormLabel>
                    <FormControl><Input placeholder="Prod API Server" {...field} /></FormControl>
                    <FormMessage />
                  </FormItem>
                )} />
                <FormField control={form.control} name="address" render={({ field }) => (
                  <FormItem>
                    <FormLabel>Address (IP, Domain, URL)</FormLabel>
                    <FormControl><Input placeholder="api.example.com" {...field} /></FormControl>
                    <FormMessage />
                  </FormItem>
                )} />
                <FormField control={form.control} name="type" render={({ field }) => (
                  <FormItem>
                    <FormLabel>Target Type</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select a type" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="domain">Domain</SelectItem>
                        <SelectItem value="ip">IP Address</SelectItem>
                        <SelectItem value="subnet">Subnet</SelectItem>
                        <SelectItem value="webapp">Web Application</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )} />
                <DialogFooter>
                  <Button type="submit" disabled={createTarget.isPending}>
                    {createTarget.isPending ? "Adding..." : "Add Target"}
                  </Button>
                </DialogFooter>
              </form>
            </Form>
          </DialogContent>
        </Dialog>
      </div>

      <Card>
        <CardHeader>
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
            <CardTitle className="font-mono text-xl">Asset Inventory</CardTitle>
            <div className="relative w-full sm:w-64">
              <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Filter targets..."
                className="pl-9 font-mono"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
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
          ) : !filteredTargets || filteredTargets.length === 0 ? (
            <div className="py-12 text-center text-muted-foreground font-mono">
              No targets found matching criteria.
            </div>
          ) : (
            <div className="rounded-md border border-border">
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent font-mono">
                    <TableHead>Target</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Authorization</TableHead>
                    <TableHead>Risk Level</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredTargets.map((target) => (
                    <TableRow 
                      key={target.id} 
                      className="font-mono text-sm cursor-pointer hover:bg-muted/50 transition-colors"
                      onClick={() => setLocation(`/targets/${target.id}`)}
                    >
                      <TableCell>
                        <div className="font-semibold text-foreground">{target.name}</div>
                        <div className="text-muted-foreground text-xs">{target.address}</div>
                      </TableCell>
                      <TableCell>
                        <span className="uppercase text-xs font-semibold px-2 py-1 bg-secondary rounded text-secondary-foreground border border-secondary-border">
                          {target.type}
                        </span>
                      </TableCell>
                      <TableCell>
                        <span className={`text-xs px-2 py-1 rounded border ${
                          target.authorizationStatus === 'authorized' ? 'border-primary text-primary' : 
                          target.authorizationStatus === 'unauthorized' ? 'border-destructive text-destructive' : 
                          'border-chart-3 text-chart-3'
                        }`}>
                          {target.authorizationStatus}
                        </span>
                      </TableCell>
                      <TableCell>
                        <span className={`text-xs px-2 py-1 rounded border ${
                          target.riskLevel === 'critical' ? 'bg-destructive/20 border-destructive text-destructive' :
                          target.riskLevel === 'high' ? 'bg-chart-2/20 border-chart-2 text-chart-2' :
                          target.riskLevel === 'medium' ? 'bg-chart-3/20 border-chart-3 text-chart-3' :
                          target.riskLevel === 'low' ? 'bg-chart-1/20 border-chart-1 text-chart-1' :
                          'bg-muted border-border text-muted-foreground'
                        }`}>
                          {target.riskLevel}
                        </span>
                      </TableCell>
                      <TableCell className="text-right">
                        <Button 
                          variant="ghost" 
                          size="icon" 
                          className="h-8 w-8 text-muted-foreground hover:text-destructive mr-1"
                          onClick={(e) => handleDelete(e, target.id)}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
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
