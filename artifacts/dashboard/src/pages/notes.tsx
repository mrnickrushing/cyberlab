import { useState } from "react";
import { Link } from "wouter";
import { useListNotes, useCreateNote, useDeleteNote, getListNotesQueryKey } from "@workspace/api-client-react";
import { format } from "date-fns";
import { useQueryClient } from "@tanstack/react-query";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Plus, Search, Trash2, StickyNote, Calendar, FileText } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";

const noteSchema = z.object({
  title: z.string().optional(),
  body: z.string().min(1, "Note body is required"),
  targetId: z.string().min(1, "Target ID is required for now"), // Current API seems to require it in DB but maybe not? Actually schema says targetId is required.
});

export default function NotesPage() {
  const [search, setSearch] = useState("");
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const { toast } = useToast();
  const queryClient = useQueryClient();
  
  // Actually we need to just fetch all, maybe filter client side if targetId is required. 
  // Let's use the hook without targetId if allowed, or we just render an error.
  const { data: notes, isLoading } = useListNotes({ search: search || undefined });
  const createNote = useCreateNote();
  const deleteNote = useDeleteNote();

  const form = useForm<z.infer<typeof noteSchema>>({
    resolver: zodResolver(noteSchema),
    defaultValues: { title: "", body: "", targetId: "" }
  });

  const onSubmit = (data: z.infer<typeof noteSchema>) => {
    createNote.mutate({ data }, {
      onSuccess: () => {
        toast({ title: "Note created" });
        queryClient.invalidateQueries({ queryKey: getListNotesQueryKey() });
        setIsCreateOpen(false);
        form.reset();
      },
      onError: (err: any) => {
        toast({ variant: "destructive", title: "Failed to create note", description: err.message });
      }
    });
  };

  const handleDelete = (id: string) => {
    if (confirm("Delete this note?")) {
      deleteNote.mutate(id, {
        onSuccess: () => {
          toast({ title: "Note deleted" });
          queryClient.invalidateQueries({ queryKey: getListNotesQueryKey() });
        }
      });
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight font-mono">Lab Notes</h1>
          <p className="text-muted-foreground font-mono mt-2">
            Investigation records, hypotheses, and scratchpad.
          </p>
        </div>
        <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
          <DialogTrigger asChild>
            <Button className="font-mono">
              <Plus className="mr-2 h-4 w-4" />
              New Note
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[500px]">
            <DialogHeader>
              <DialogTitle className="font-mono">Create Lab Note</DialogTitle>
              <DialogDescription className="font-mono">
                Record findings or investigation details. Note: Target ID is currently required.
              </DialogDescription>
            </DialogHeader>
            <Form {...form}>
              <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 font-mono">
                <FormField control={form.control} name="targetId" render={({ field }) => (
                  <FormItem>
                    <FormLabel>Target ID</FormLabel>
                    <FormControl><Input placeholder="UUID..." {...field} /></FormControl>
                    <FormMessage />
                  </FormItem>
                )} />
                <FormField control={form.control} name="title" render={({ field }) => (
                  <FormItem>
                    <FormLabel>Title (Optional)</FormLabel>
                    <FormControl><Input placeholder="Brief title..." {...field} /></FormControl>
                    <FormMessage />
                  </FormItem>
                )} />
                <FormField control={form.control} name="body" render={({ field }) => (
                  <FormItem>
                    <FormLabel>Content</FormLabel>
                    <FormControl>
                      <Textarea placeholder="Markdown supported..." className="h-32 font-mono" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )} />
                <DialogFooter>
                  <Button type="submit" disabled={createNote.isPending}>
                    {createNote.isPending ? "Saving..." : "Save Note"}
                  </Button>
                </DialogFooter>
              </form>
            </Form>
          </DialogContent>
        </Dialog>
      </div>

      <div className="flex items-center space-x-2 max-w-sm">
        <Search className="h-4 w-4 text-muted-foreground" />
        <Input 
          placeholder="Search notes..." 
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="font-mono"
        />
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[1,2,3].map(i => <Skeleton key={i} className="h-48 w-full" />)}
        </div>
      ) : !notes || notes.length === 0 ? (
        <Card className="border-dashed bg-transparent">
          <CardContent className="flex flex-col items-center justify-center py-16 text-center">
            <StickyNote className="h-12 w-12 text-muted-foreground/50 mb-4" />
            <div className="font-mono text-lg font-medium text-foreground">No notes found</div>
            <div className="font-mono text-sm text-muted-foreground max-w-sm mt-2">
              Create a note to document your investigation process or attach notes directly to targets.
            </div>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {notes.map(note => (
            <Card key={note.id} className="flex flex-col">
              <CardHeader className="pb-3">
                <div className="flex justify-between items-start">
                  <CardTitle className="text-lg font-mono flex items-center gap-2">
                    <FileText className="h-4 w-4 text-primary" />
                    {note.title || "Untitled"}
                  </CardTitle>
                  <Button variant="ghost" size="icon" className="h-8 w-8 text-muted-foreground hover:text-destructive" onClick={() => handleDelete(note.id)}>
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </CardHeader>
              <CardContent className="flex-1">
                <p className="font-mono text-sm whitespace-pre-wrap text-muted-foreground line-clamp-6">
                  {note.body}
                </p>
              </CardContent>
              <CardFooter className="pt-3 border-t text-xs font-mono text-muted-foreground flex justify-between bg-muted/20">
                <div className="flex items-center gap-1">
                  <Calendar className="h-3 w-3" />
                  {format(new Date(note.createdAt), "MMM d, yyyy")}
                </div>
                {note.targetId && (
                  <Link href={`/targets/${note.targetId}`} className="hover:text-primary transition-colors flex items-center gap-1 truncate max-w-[120px]">
                    Target: {note.targetId.substring(0,8)}...
                  </Link>
                )}
              </CardFooter>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
