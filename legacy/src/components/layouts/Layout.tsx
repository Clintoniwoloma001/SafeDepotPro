import { useMemo, useState } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import {
  AlertTriangle,
  Bot,
  CheckSquare,
  ClipboardCheck,
  Clock,
  Download,
  FileCheck,
  LayoutDashboard,
  ListChecks,
  LogOut,
  Menu,
  MessageSquare,
  Package,
  RefreshCw,
  Search,
  Settings,
  ShieldAlert,
  Truck,
  UserCog,
  UserPlus,
  Users,
  Warehouse,
  Wrench,
  X,
  type LucideIcon,
} from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Sheet, SheetContent, SheetTrigger } from '@/components/ui/sheet'
import { Separator } from '@/components/ui/separator'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useIsMobile } from '@/hooks/use-mobile'
import { useSettings } from '@/contexts/SettingsContext'
import { NAV_ITEMS, GROUP_ORDER } from '@/lib/constants'
import { signOut } from '@/services/auth.service'
import { cn } from '@/lib/utils'
import FloatingLogo from '@/components/FloatingLogo'
import DepotSelector from '@/components/DepotSelector'
import InstallBanner from '@/components/InstallBanner'
import NotificationsBell from '@/components/NotificationsBell'

const ICONS: Record<string, LucideIcon> = {
  LayoutDashboard,
  Bot,
  CheckSquare,
  RefreshCw,
  MessageSquare,
  Clock,
  FileCheck,
  ClipboardCheck,
  Truck,
  AlertTriangle,
  ShieldAlert,
  Wrench,
  Package,
  Users,
  Warehouse,
  ListChecks,
  UserCog,
  Download,
  Settings,
  UserPlus,
}

interface NavItem {
  label: string
  to: string
  icon: string
  badge?: string
  group: 'Overview' | 'Operations' | 'Safety' | 'Assets' | 'Admin'
  minRank: number
  superadminOnly?: boolean
}

function SidebarContent({ onNavigate }: { onNavigate?: () => void }) {
  const user = useCurrentUser()
  const navigate = useNavigate()
  const { settings } = useSettings()
  const [search, setSearch] = useState('')

  const visible = useMemo<NavItem[]>(
    () =>
      NAV_ITEMS.filter((item) => user.rank >= item.minRank)
        .filter((item) => !item.superadminOnly || user.isSuperadmin)
        .filter((item) => item.label.toLowerCase().includes(search.toLowerCase())),
    [user, search],
  )

  const groups = useMemo(
    () => GROUP_ORDER.map((g) => ({ group: g, items: visible.filter((i) => i.group === g) })).filter((g) => g.items.length > 0),
    [visible],
  )

  const handleSignOut = async () => {
    try {
      await signOut()
    } finally {
      navigate('/auth/login')
    }
  }

  return (
    <div className="flex h-full flex-col bg-gradient-to-b from-sidebar-from to-sidebar-to text-sidebar-foreground">
      <div className="flex items-center gap-2 px-5 py-4">
        <img src="/logos.png" alt="SafeDepot Pro" className="h-9 w-auto" />
      </div>

      <div className="px-4 pb-2">
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search…"
            className="w-full rounded-md border border-white/10 bg-white/5 py-1.5 pl-8 pr-2 text-sm text-white placeholder:text-white/40 focus:border-white/30 focus:outline-none"
          />
        </div>
      </div>

      <nav className="flex-1 space-y-4 overflow-y-auto px-3 pb-4">
        {groups.map(({ group, items }) => (
          <div key={group}>
            <div className="px-2 pb-1 text-[11px] font-semibold uppercase tracking-wider text-white/40">{group}</div>
            <div className="space-y-0.5">
              {items.map((item) => {
                const Icon = ICONS[item.icon] ?? LayoutDashboard
                return (
                  <NavLink
                    key={item.to}
                    to={item.to}
                    onClick={onNavigate}
                    className={({ isActive }) =>
                      cn(
                        'flex items-center gap-2.5 rounded-md px-2.5 py-1.5 text-sm text-white/80 transition-colors hover:bg-white/10 hover:text-white',
                        isActive && 'bg-brand text-white hover:bg-brand hover:text-white',
                      )
                    }
                  >
                    <Icon className="h-4 w-4 shrink-0" />
                    <span className="flex-1 truncate">{item.label}</span>
                    {item.badge && (
                      <Badge className="bg-amber-accent text-white" variant="outline">
                        {item.badge}
                      </Badge>
                    )}
                  </NavLink>
                )
              })}
            </div>
          </div>
        ))}
      </nav>

      <div className="space-y-1 border-t border-white/10 px-3 py-3">
        {typeof window !== 'undefined' && (window.matchMedia('(display-mode: standalone)').matches || (window.navigator as unknown as { standalone?: boolean }).standalone) && (
          <Button
            variant="ghost"
            size="sm"
            className="w-full justify-start text-white/80 hover:bg-white/10 hover:text-white"
            onClick={async () => {
              try {
                await navigator.share({ title: 'SafeDepot Pro', text: 'Use SafeDepot Pro for depot HSE management', url: window.location.origin })
              } catch {
                /* cancelled */
              }
            }}
          >
            <Download className="h-4 w-4" /> Share App
          </Button>
        )}
        <Button size="sm" variant="ghost" className="w-full justify-start text-white/80 hover:bg-white/10 hover:text-white" onClick={handleSignOut}>
          <LogOut className="h-4 w-4" /> Sign Out
        </Button>
        <div className="px-2.5 pt-1 text-[11px] text-white/35">
          {settings.org_name} — {user.roleLabel}
        </div>
      </div>
    </div>
  )
}

export default function Layout() {
  const user = useCurrentUser()
  const isMobile = useIsMobile()
  const [mobileOpen, setMobileOpen] = useState(false)

  return (
    <div className="flex min-h-screen bg-background">
      {!isMobile && (
        <aside className="fixed inset-y-0 left-0 z-30 w-64">
          <SidebarContent />
        </aside>
      )}

      {isMobile && (
        <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
          <SheetTrigger asChild>
            <Button variant="ghost" size="icon" className="ml-2 mt-2 fixed z-40">
              <Menu className="h-5 w-5" />
            </Button>
          </SheetTrigger>
          <SheetContent side="left" className="w-64 border-0 bg-sidebar-from p-0" showCloseButton={false}>
            <button
              onClick={() => setMobileOpen(false)}
              className="absolute right-2 top-2 z-50 rounded-md p-1 text-white/60 hover:bg-white/10"
              aria-label="Close menu"
            >
              <X className="h-5 w-5" />
            </button>
            <SidebarContent onNavigate={() => setMobileOpen(false)} />
          </SheetContent>
        </Sheet>
      )}

      <div className={cn('flex min-h-screen w-full flex-col', !isMobile && 'ml-64')}>
        <header className="sticky top-0 z-20 flex h-14 items-center justify-between gap-3 border-b bg-background/90 px-4 backdrop-blur">
          {isMobile && <span className="w-8" />}
          <DepotSelector />
          <div className="flex items-center gap-1">
            <NotificationsBell />
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button className="flex items-center gap-2 rounded-md px-2 py-1 text-sm hover:bg-muted" aria-label="Account menu">
                  <Avatar className="h-7 w-7">
                    <AvatarImage src="" alt="" />
                    <AvatarFallback className="bg-brand text-white text-xs">
                      {(user.fullName || 'U').slice(0, 1).toUpperCase()}
                    </AvatarFallback>
                  </Avatar>
                  <span className="hidden max-w-[10rem] truncate sm:inline">{user.fullName}</span>
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-56">
                <DropdownMenuLabel>
                  <div className="text-sm font-medium">{user.fullName}</div>
                  <div className="text-xs text-muted-foreground">{user.email}</div>
                </DropdownMenuLabel>
                <DropdownMenuSeparator />
                <DropdownMenuItem disabled>Role: {user.roleLabel}</DropdownMenuItem>
                <DropdownMenuItem disabled>Depot: {user.effectiveDepotId ?? '—'}</DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  onClick={async () => {
                    await signOut()
                    window.location.href = '/auth/login'
                  }}
                >
                  <LogOut className="mr-2 h-4 w-4" /> Sign out
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </header>

        <main className="mx-auto w-full max-w-7xl flex-1 px-4 py-6 sm:px-6">
          <Outlet />
        </main>

        <footer className="border-t px-6 py-3 text-center text-xs text-muted-foreground">
          <Separator className="mb-3" />
          SafeDepot Pro — HSE Management
        </footer>
      </div>

      <FloatingLogo />
      <InstallBanner />
    </div>
  )
}