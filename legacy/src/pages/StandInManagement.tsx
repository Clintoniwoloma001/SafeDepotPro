import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { CalendarClock, Plus, Check, X, Clock3 } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, KPICard } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import { listStandIns, createStandIn, setStandInStatus } from '@/services/standIn.service'
import { listDepots } from '@/services/depots.service'
import { cn } from '@/lib/utils'
import type { StandIn } from '@/types/entities'
import type { StandInStatus } from '@/types/enums'

export default function StandInManagement() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [creating, setCreating] = useState(false)

  const { data: all = [] } = useQuery({ queryKey: ['stand-ins'], queryFn: () => listStandIns({}) })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const scoped = user.isCountryHead || user.isSuperadmin ? all : all.filter((s) => depotId ? s.covering_depot_id === depotId : s.user_id === user.userId)
  const active = scoped.filter((s) => s.status === 'ACTIVE').length
  const pending = scoped.filter((s) => s.status === 'PENDING').length

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['stand-ins'] })

  const save = useMutation({
    mutationFn: createStandIn,
    onSuccess: () => {
      toast.success('Stand-in requested')
      setCreating(false)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not request stand-in'),
  })

  const setStatus = useMutation({
    mutationFn: ({ id, status }: { id: string; status: StandInStatus }) => setStandInStatus(id, status),
    onSuccess: () => {
      toast.success('Stand-in updated')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not update stand-in'),
  })

  return (
    <div className="space-y-8">
      <PageHeader
        title="Stand-In Management"
        subtitle={`${active} active cover assignments`}
        actions={<Button onClick={() => setCreating(true)}><Plus className="mr-1 h-4 w-4" /> Request stand-in</Button>}
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<CalendarClock className="h-4 w-4" />} iconHue="green" label="Active" value={active} />
        <KPICard icon={<Clock3 className="h-4 w-4" />} iconHue="amber" label="Pending approval" value={pending} />
        <KPICard icon={<CalendarClock className="h-4 w-4" />} iconHue="slate" label="Total requests" value={scoped.length} />
      </div>

      {scoped.length === 0 ? (
        <EmptyState title="No stand-ins" description="Request temporary cover for a user serving at another depot." />
      ) : (
        <SectionCard title="Cover roster">
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Covering depot</TableHead>
                  <TableHead className="hidden md:table-cell">Period</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-28">{/* actions */}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {scoped.map((s) => (
                  <TableRow key={s.id}>
                    <TableCell className="font-medium">{depotName(s.covering_depot_id)}</TableCell>
                    <TableCell className="hidden md:table-cell text-xs">{s.start_date} → {s.end_date}</TableCell>
                    <TableCell>
                      <span className={cn('rounded-full px-2 py-0.5 text-xs font-medium', s.status === 'ACTIVE' ? 'bg-rag-good/10 text-rag-good' : s.status === 'PENDING' ? 'bg-amber-50 text-amber-700' : s.status === 'REJECTED' ? 'bg-rag-bad/10 text-rag-bad' : 'bg-muted text-muted-foreground')}>
                        {s.status}
                      </span>
                    </TableCell>
                    <TableCell>
                      <div className="flex justify-end gap-1">
                        {s.status === 'PENDING' && user.isManagement && (
                          <>
                            <Button size="sm" variant="outline" className="h-7 px-2 text-rag-good" onClick={() => setStatus.mutate({ id: s.id, status: 'ACTIVE' })}>
                              <Check className="h-3.5 w-3.5" />
                            </Button>
                            <Button size="sm" variant="outline" className="h-7 px-2 text-rag-bad" onClick={() => setStatus.mutate({ id: s.id, status: 'REJECTED' })}>
                              <X className="h-3.5 w-3.5" />
                            </Button>
                          </>
                        )}
                        {s.status === 'ACTIVE' && (
                          <Button size="sm" variant="ghost" className="h-7 text-xs" onClick={() => setStatus.mutate({ id: s.id, status: 'COMPLETED' })}>
                            Complete
                          </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </SectionCard>
      )}

      <StandInForm open={creating} onOpenChange={setCreating} userId={user.userId ?? 'anon'} userName={user.fullName} depotName={depotName} onSave={(input) => save.mutate(input)} />
    </div>
  )
}

function StandInForm({ open, onOpenChange, userId, userName, depotName, onSave }: { open: boolean; onOpenChange: (v: boolean) => void; userId: string; userName: string; depotName: (id: string | null) => string; onSave: (input: Partial<StandIn>) => void }) {
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const [coveringDepot, setCoveringDepot] = useState('')
  const [start, setStart] = useState('')
  const [end, setEnd] = useState('')
  const [reason, setReason] = useState('')

  useEffect(() => {
    if (open) {
      setCoveringDepot('')
      setEnd('')
      setReason('')
    }
  }, [open])

  const submit = () => {
    if (!coveringDepot) return toast.error('Choose the depot to cover.')
    if (!start || !end) return toast.error('Enter start and end dates.')
    if (end < start) return toast.error('End date is before start date.')
    onSave({
      user_id: userId,
      covering_depot_id: coveringDepot,
      requested_by_user_id: userId,
      requested_by_name: userName,
      start_date: start,
      end_date: end,
      reason: reason || null,
      status: 'PENDING',
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader><DialogTitle>Request stand-in cover</DialogTitle></DialogHeader>
        <div className="space-y-3">
          <Field label="Covering depot *">
            <Select value={coveringDepot} onValueChange={setCoveringDepot}>
              <SelectTrigger><SelectValue placeholder={depotName(coveringDepot) || 'Select'} /></SelectTrigger>
              <SelectContent>{depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name}</SelectItem>)}</SelectContent>
            </Select>
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Start date *"><Input type="date" value={start} onChange={(e) => setStart(e.target.value)} /></Field>
            <Field label="End date *"><Input type="date" value={end} onChange={(e) => setEnd(e.target.value)} /></Field>
          </div>
          <Field label="Reason"><Textarea rows={2} value={reason} onChange={(e) => setReason(e.target.value)} /></Field>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
            <Button onClick={submit}>Request cover</Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1.5">
      <Label className="text-sm font-medium text-muted-foreground">{label}</Label>
      {children}
    </div>
  )
}