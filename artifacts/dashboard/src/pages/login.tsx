import { useState } from "react";
import { useLocation } from "wouter";
import { useLogin, useRegister } from "@workspace/api-client-react";
import { setToken } from "@/lib/auth";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { TerminalSquare, Loader2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useToast } from "@/hooks/use-toast";

const loginSchema = z.object({
  username: z.string().min(1, "Username is required"),
  password: z.string().min(1, "Password is required"),
});

const registerSchema = z.object({
  username: z.string().min(3, "Username must be at least 3 characters"),
  email: z.string().email("Invalid email address"),
  password: z.string().min(6, "Password must be at least 6 characters"),
});

export default function Login() {
  const [, setLocation] = useLocation();
  const { toast } = useToast();
  const [activeTab, setActiveTab] = useState<"login" | "register">("login");

  const loginMutation = useLogin();
  const registerMutation = useRegister();

  const loginForm = useForm<z.infer<typeof loginSchema>>({
    resolver: zodResolver(loginSchema),
    defaultValues: { username: "", password: "" },
  });

  const registerForm = useForm<z.infer<typeof registerSchema>>({
    resolver: zodResolver(registerSchema),
    defaultValues: { username: "", email: "", password: "" },
  });

  const onLogin = (data: z.infer<typeof loginSchema>) => {
    loginMutation.mutate(
      { data },
      {
        onSuccess: (res) => {
          setToken(res.token);
          setLocation("/");
        },
        onError: () => {
          toast({
            variant: "destructive",
            title: "Authentication Failed",
            description: "Invalid username or password.",
          });
        },
      }
    );
  };

  const onRegister = (data: z.infer<typeof registerSchema>) => {
    registerMutation.mutate(
      { data },
      {
        onSuccess: (res) => {
          setToken(res.token);
          setLocation("/");
        },
        onError: () => {
          toast({
            variant: "destructive",
            title: "Registration Failed",
            description: "Could not create account. Username or email may exist.",
          });
        },
      }
    );
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-4 bg-background relative overflow-hidden">
      {/* Decorative background elements */}
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-primary/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-1/4 right-1/4 w-64 h-64 bg-chart-4/10 rounded-full blur-3xl pointer-events-none" />

      <div className="mb-8 flex flex-col items-center space-y-2 z-10">
        <div className="p-3 bg-card border border-border rounded-xl shadow-lg shadow-primary/5">
          <TerminalSquare className="h-10 w-10 text-primary" />
        </div>
        <h1 className="text-3xl font-mono font-bold tracking-tighter text-foreground">CyberLab</h1>
        <p className="text-muted-foreground font-mono text-sm tracking-widest uppercase">Security Operations</p>
      </div>

      <Card className="w-full max-w-md z-10 border-border shadow-2xl bg-card/80 backdrop-blur-sm">
        <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as any)} className="w-full">
          <CardHeader className="pb-4">
            <TabsList className="grid w-full grid-cols-2 mb-2 font-mono">
              <TabsTrigger value="login">Authenticate</TabsTrigger>
              <TabsTrigger value="register">Initialize</TabsTrigger>
            </TabsList>
            <CardTitle className="text-xl font-mono">
              {activeTab === "login" ? "System Access" : "Create Operator Profile"}
            </CardTitle>
            <CardDescription className="font-mono text-xs">
              {activeTab === "login" 
                ? "Enter your credentials to access the console." 
                : "Register a new operator identity."}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <TabsContent value="login" className="mt-0 outline-none">
              <Form {...loginForm}>
                <form onSubmit={loginForm.handleSubmit(onLogin)} className="space-y-4 font-mono">
                  <FormField
                    control={loginForm.control}
                    name="username"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Username</FormLabel>
                        <FormControl>
                          <Input placeholder="operator" className="bg-background" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={loginForm.control}
                    name="password"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Password</FormLabel>
                        <FormControl>
                          <Input type="password" placeholder="••••••••" className="bg-background" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <Button type="submit" className="w-full" disabled={loginMutation.isPending}>
                    {loginMutation.isPending ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                    Grant Access
                  </Button>
                </form>
              </Form>
            </TabsContent>

            <TabsContent value="register" className="mt-0 outline-none">
              <Form {...registerForm}>
                <form onSubmit={registerForm.handleSubmit(onRegister)} className="space-y-4 font-mono">
                  <FormField
                    control={registerForm.control}
                    name="username"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Username</FormLabel>
                        <FormControl>
                          <Input placeholder="operator" className="bg-background" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={registerForm.control}
                    name="email"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Email</FormLabel>
                        <FormControl>
                          <Input type="email" placeholder="operator@cyberlab.local" className="bg-background" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={registerForm.control}
                    name="password"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Password</FormLabel>
                        <FormControl>
                          <Input type="password" placeholder="••••••••" className="bg-background" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <Button type="submit" className="w-full" disabled={registerMutation.isPending}>
                    {registerMutation.isPending ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                    Initialize Profile
                  </Button>
                </form>
              </Form>
            </TabsContent>
          </CardContent>
        </Tabs>
      </Card>
    </div>
  );
}
