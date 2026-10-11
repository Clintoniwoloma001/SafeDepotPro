import type { ReactNode } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { STATUS_BADGE, PRIORITY_BADGE, RISK_BADGE } from '@/types/enums'
import { KPI_HUES, type KpiHue } from '@/lib/constants'
import { cn } from '@/lib/utils'

// ---------------------------------------------------------------------------
// Icon badge — soft tint on white, hue carries the meaning (never a solid fill).
// ---------------------------------------------------------------------------

export function IconBadge({ icon, hue = 'slate', className }: { icon: ReactNode; hue?: KpiHue; className?: string }) {
  const t = KPI_HUES[hue]
  return <span className={cn('flex h-10 w-10 shrink-0 items-center justify-center rounded-lg', t.chip, className)}>{icon}</span>
}

// ---------------------------------------------------------------------------
// KPI Card — light border, soft shadow, breathable padding, strong number hierarchy.
// ---------------------------------------------------------------------------

export function KPICard({
  label,
  value,
  sub,
  icon,
  iconHue = 'slate',
  tone = 'default',
  className,
}: {
  label: string
  value: ReactNode
  sub?: ReactNode
  icon?: ReactNode
  iconHue?: KpiHue
  tone?: 'default' | 'good' | 'warn' | 'bad'
  className?: string
}) {
  const valueTone =
    tone === 'good' ? 'text-rag-good' : tone === 'warn' ? 'text-rag-warn' : tone === 'bad' ? 'text-rag-bad' : 'text-foreground'
  return (
    <Card className={className}>
      <CardHeader className="flex flex-row items-start justify-between space-y-0 pb-1">
        <CardTitle className="text-sm font-medium text-muted-foreground">{label}</CardTitle>
        {icon && <IconBadge icon={icon} hue={iconHue} className="h-9 w-9 rounded-lg" />}
      </CardHeader>
      <CardContent>
        <div className={cn('text-3xl font-bold leading-tight tracking-tight', valueTone)}>{value}</div>
        {sub && <p className="mt-1 text-xs font-medium text-muted-foreground">{sub}</p>}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Section Card
// ---------------------------------------------------------------------------

export function SectionCard({ title, description, actions, children, className }: { title: string; description?: string; actions?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <Card className={className}>
      <CardHeader className="flex flex-row items-start justify-between space-y-0">
        <div>
          <CardTitle className="font-semibold">{title}</CardTitle>
          {description && <p className="mt-1 text-sm text-muted-foreground">{description}</p>}
        </div>
        {actions}
      </CardHeader>
      <CardContent>{children}</CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

export function StatusBadge({ status, className }: { status: string; className?: string }) {
  const meta = STATUS_BADGE[status] ?? { label: status, className: 'bg-gray-100 text-gray-600' }
  return <Badge variant="outline" className={cn(meta.className, className)}>{meta.label}</Badge>
}

export function PriorityBadge({ priority, className }: { priority: string; className?: string }) {
  const meta = PRIORITY_BADGE[priority] ?? { label: priority, className: 'bg-gray-100 text-gray-600' }
  return <Badge variant="outline" className={cn(meta.className, className)}>{meta.label}</Badge>
}

export function RiskBadge({ risk, className }: { risk: string; className?: string }) {
  const meta = RISK_BADGE[risk] ?? { label: risk, className: 'bg-gray-100 text-gray-600' }
  return <Badge variant="outline" className={cn(meta.className, className)}>{meta.label}</Badge>
}

// ---------------------------------------------------------------------------
// Page Header — font-semibold section titles, generous bottom spacing.
// ---------------------------------------------------------------------------

export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: string; actions?: ReactNode }) {
  return (
    <div className="mb-8 flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-muted-foreground">{subtitle}</p>}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Empty State — muted, centered, breathing room.
// ---------------------------------------------------------------------------

export function EmptyState({ title, description, action, className }: { title: string; description?: string; action?: ReactNode; className?: string }) {
  return (
    <div className={cn('flex flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-gray-200 bg-gray-50/40 px-6 py-14 text-center', className)}>
      <div className="text-3xl" aria-hidden="true">📋</div>
      <div className="text-sm font-medium text-gray-500">{title}</div>
      {description && <div className="max-w-sm text-sm text-gray-400">{description}</div>}
      {action && <div className="mt-2">{action}</div>}
    </div>
  )
}