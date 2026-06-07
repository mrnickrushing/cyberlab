import { useState } from "react";
import { Link, useLocation } from "wouter";
import { useGetMe, useLogout } from "@workspace/api-client-react";
import { clearToken } from "@/lib/auth";
import { 
  LayoutDashboard, 
  Target, 
  ScanSearch, 
  ShieldAlert, 
  StickyNote, 
  Activity, 
  Settings, 
  LogOut,
  Menu,
  TerminalSquare
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";

interface AppLayoutProps {
  children: React.ReactNode;
}

const navItems = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/targets", label: "Targets", icon: Target },
  { href: "/scans", label: "Scans", icon: ScanSearch },
  { href: "/findings", label: "Findings", icon: ShieldAlert },
  { href: "/notes", label: "Notes", icon: StickyNote },
  { href: "/audit", label: "Audit Log", icon: Activity },
  { href: "/settings", label: "Settings", icon: Settings },
];

export default function AppLayout({ children }: AppLayoutProps) {
  const [location, setLocation] = useLocation();
  const { data: user, isLoading } = useGetMe();
  const logout = useLogout();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const handleLogout = () => {
    logout.mutate(undefined, {
      onSettled: () => {
        clearToken();
        setLocation("/login");
      }
    });
  };

  const SidebarContent = () => (
    <div className="flex flex-col h-full bg-sidebar border-r border-sidebar-border text-sidebar-foreground">
      <div className="p-4 flex items-center space-x-2 border-b border-sidebar-border">
        <TerminalSquare className="h-6 w-6 text-primary" />
        <span className="font-mono font-bold text-lg text-primary tracking-tight">CyberLab</span>
      </div>
      
      <nav className="flex-1 overflow-y-auto py-4">
        <ul className="space-y-1 px-2 font-mono text-sm">
          {navItems.map((item) => {
            const isActive = location === item.href || (item.href !== "/" && location.startsWith(item.href));
            return (
              <li key={item.href}>
                <Link href={item.href}>
                  <Button
                    variant="ghost"
                    className={`w-full justify-start ${isActive ? "bg-sidebar-accent text-sidebar-accent-foreground" : "text-sidebar-foreground hover:bg-sidebar-accent/50"}`}
                    onClick={() => setMobileMenuOpen(false)}
                  >
                    <item.icon className="mr-2 h-4 w-4" />
                    {item.label}
                  </Button>
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="p-4 border-t border-sidebar-border mt-auto">
        {isLoading ? (
          <div className="space-y-2">
            <Skeleton className="h-4 w-3/4 bg-sidebar-accent" />
            <Skeleton className="h-3 w-1/2 bg-sidebar-accent" />
          </div>
        ) : user ? (
          <div className="mb-4">
            <div className="font-mono text-sm font-semibold truncate">{user.username}</div>
            <div className="text-xs text-sidebar-foreground/70 truncate">{user.email}</div>
          </div>
        ) : null}
        <Button 
          variant="outline" 
          className="w-full justify-start border-sidebar-border hover:bg-sidebar-accent hover:text-sidebar-accent-foreground" 
          onClick={handleLogout}
        >
          <LogOut className="mr-2 h-4 w-4" />
          Logout
        </Button>
      </div>
    </div>
  );

  return (
    <div className="flex h-screen w-full bg-background text-foreground overflow-hidden">
      {/* Desktop Sidebar */}
      <aside className="hidden md:flex w-64 flex-col fixed inset-y-0 z-50">
        <SidebarContent />
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col md:pl-64 min-w-0">
        {/* Mobile Header */}
        <header className="md:hidden flex items-center justify-between p-4 border-b border-border bg-card">
          <div className="flex items-center space-x-2">
            <TerminalSquare className="h-5 w-5 text-primary" />
            <span className="font-mono font-bold text-primary">CyberLab</span>
          </div>
          <Sheet open={mobileMenuOpen} onOpenChange={setMobileMenuOpen}>
            <SheetTrigger asChild>
              <Button variant="ghost" size="icon" className="md:hidden">
                <Menu className="h-5 w-5" />
              </Button>
            </SheetTrigger>
            <SheetContent side="left" className="p-0 w-64 border-r-sidebar-border">
              <SidebarContent />
            </SheetContent>
          </Sheet>
        </header>

        {/* Page Content */}
        <div className="flex-1 overflow-y-auto p-4 md:p-8">
          <div className="mx-auto max-w-7xl">
            {children}
          </div>
        </div>
      </main>
    </div>
  );
}
