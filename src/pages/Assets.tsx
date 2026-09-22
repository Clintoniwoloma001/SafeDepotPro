import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus, Pencil, Trash2 } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, StatusBadge } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import { listAssets, createAsset, updateAsset, deleteAsset } from '@/services/assets.service'
import { listDepots } from '@/services/depots.service'
import { formatDate, todayIso } from '@/lib/utils'
import type { Asset } from '@/types/entities'

const ASSET_STATUS = ['AVAILABLE', 'IN_USE', 'MAINTENANCE', 'RETIRED'] as const

export default function Assets() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState<Asset | null>(null)
  const [creating, setCreating] = useState(false)

  const { data: assets = [] } = useQuery({ queryKey: ['assets', depotId ?? 'all'], queryFn: () => listAssets(depotId ? { depotId } : {}) })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const open = creating || editing !== null
  const setOpen = (v: boolean) => {
    if (!v) {
      setCreating(false)
      setEditing(null)
    }
  }

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['assets'] })

  const save = useMutation({
    mutationFn: async (input: Partial<Asset>) => {
      if (editing) return updateAsset(editing.id, input)
      return createAsset(input)
    },
    onSuccess: () => {
      toast.success(editing ? 'Asset updated' : 'Asset created')
      setOpen(false)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save asset'),
  })

  const remove = useMutation({
    mutationFn: (id: string) => deleteAsset(id),
    onSuccess: () => {
      toast.success('Asset removed')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not remove asset'),
  })

  const scoped = useMemo(
    () => (user.isCountryHead ? assets : assets.filter((a) => a.depot_id === user.effectiveDepotId)),
    [assets, user.isCountryHead, user.effectiveDepotId],
  )

  return (
    <div className="space-y-8">
      <PageHeader
        title="Equipment & Assets"
        subtitle={`${scoped.length} asset${scoped.length === 1 ? '' : 's'} on file`}
        actions={
          <Button onClick={() => setCreating(true)}>
            <Plus className="mr-1 h-4 w-4" /> Add asset
          </Button>
        }
      />

      {scoped.length === 0 ? (
        <EmptyState title="No assets recorded" description="Register equipment, PPE and tools with their calibration and ownership details." />
      ) : (
        <SectionCard title="Asset register">
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Asset</TableHead>
                  <TableHead>Tag</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="hidden md:table-cell">Depot</TableHead>
                  <TableHead className="hidden md:table-cell">Calibration</TableHead>
                  <TableHead className="hidden lg:table-cell">Assigned to</TableHead>
                  <TableHead className="w-20" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {scoped.map((a) => (
                  <TableRow key={a.id}>
                    <TableCell>
                      <div className="font-medium">{a.name}</div>
                      <div className="text-xs text-muted-foreground">{a.asset_type ?? '—'}</div>
                    </TableCell>
                    <TableCell className="font-mono text-xs">{a.asset_tag ?? '—'}</TableCell>
                    <TableCell><StatusBadge status={a.status} /></TableCell>
                    <TableCell className="hidden md:table-cell">{depotName(a.depot_id)}</TableCell>
                    <TableCell className="hidden md:table-cell">
                      {a.next_calibration_date ? (
                        <span className={a.next_calibration_date < todayIso() ? 'text-rag-bad' : 'text-muted-foreground'}>{formatDate(a.next_calibration_date)}</span>
                      ) : (
                        '—'
                      )}
                    </TableCell>
                    <TableCell className="hidden lg:table-cell">{a.assigned_to_name ?? '—'}</TableCell>
                    <TableCell>
                      <div className="flex items-center gap-1">
                        <Button variant="ghost" size="icon" onClick={() => setEditing(a)} aria-label="Edit asset"><Pencil className="h-4 w-4" /></Button>
                        <Button variant="ghost" size="icon" className="text-rag-bad" disabled={remove.isPending} onClick={() => remove.mutate(a.id)} aria-label="Delete asset"><Trash2 className="h-4 w-4" /></Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </SectionCard>
      )}

      <AssetForm
        open={open}
        onOpenChange={setOpen}
        asset={editing}
        defaultDepotId={user.effectiveDepotId ?? undefined}
        depotName={depotName}
        onSave={(input) => save.mutate(input)}
        saving={save.isPending}
      />
    </div>
  )
}

function AssetForm({
  open,
  onOpenChange,
  asset,
  defaultDepotId,
  depotName,
  onSave,
  saving,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  asset: Asset | null
  defaultDepotId?: string
  depotName: (id: string | null) => string
  onSave: (input: Partial<Asset>) => void
  saving: boolean
}) {
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const [name, setName] = useState('')
  const [assetTag, setAssetTag] = useState('')
  const [assetType, setAssetType] = useState('')
  const [makeModel, setMakeModel] = useState('')
  const [serial, setSerial] = useState('')
  const [depotId, setDepotId] = useState('')
  const [status, setStatus] = useState('AVAILABLE')
  const [condition, setCondition] = useState('')
  const [lastCal, setLastCal] = useState('')
  const [nextCal, setNextCal] = useState('')
  const [notes, setNotes] = useState('')

  useEffect(() => {
    if (!open) return
    setName(asset?.name ?? '')
    setAssetTag(asset?.asset_tag ?? '')
    setAssetType(asset?.asset_type ?? '')
    setMakeModel(asset?.make_model ?? '')
    setSerial(asset?.serial_number ?? '')
    setDepotId(asset?.depot_id ?? defaultDepotId ?? '')
    setStatus(asset?.status ?? 'AVAILABLE')
    setCondition(asset?.condition ?? '')
    setLastCal(asset?.last_calibration_date ?? '')
    setNextCal(asset?.next_calibration_date ?? '')
    setNotes(asset?.notes ?? '')
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, asset])

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim()) return toast.error('Asset name is required.')
    if (!depotId) return toast.error('Depot is required.')
    onSave({
      name: name.trim(),
      depot_id: depotId,
      asset_tag: assetTag || null,
      asset_type: assetType || null,
      make_model: makeModel || null,
      serial_number: serial || null,
      zone_name: depotName(depotId),
      status: status as Asset['status'],
      condition: condition || null,
      last_calibration_date: lastCal || null,
      next_calibration_date: nextCal || null,
      notes: notes || null,
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{asset ? 'Edit asset' : 'Add asset'}</DialogTitle>
        </DialogHeader>
        <form onSubmit={submit} className="space-y-3">
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Name *"><Input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Fire Extinguisher 5kg" /></Field>
            <Field label="Tag"><Input value={assetTag} onChange={(e) => setAssetTag(e.target.value)} placeholder="ASSET-0001" /></Field>
            <Field label="Type"><Input value={assetType} onChange={(e) => setAssetType(e.target.value)} placeholder="Fire safety" /></Field>
            <Field label="Make / model"><Input value={makeModel} onChange={(e) => setMakeModel(e.target.value)} /></Field>
            <Field label="Serial no."><Input value={serial} onChange={(e) => setSerial(e.target.value)} /></Field>
            <Field label="Status">
              <Select value={status} onValueChange={setStatus}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {ASSET_STATUS.map((s) => <SelectItem key={s} value={s}>{s.replace(/_/g, ' ')}</SelectItem>)}
                </SelectContent>
              </Select>
            </Field>
            <Field label="Depot *">
              <Select value={depotId} onValueChange={setDepotId}>
                <SelectTrigger><SelectValue placeholder={depotName(depotId) || 'Select depot'} /></SelectTrigger>
                <SelectContent>
                  {depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name} ({d.code})</SelectItem>)}
                </SelectContent>
              </Select>
            </Field>
            <Field label="Condition"><Input value={condition} onChange={(e) => setCondition(e.target.value)} /></Field>
            <Field label="Last calibration"><Input type="date" value={lastCal} onChange={(e) => setLastCal(e.target.value)} /></Field>
            <Field label="Next calibration"><Input type="date" value={nextCal} onChange={(e) => setNextCal(e.target.value)} /></Field>
          </div>
          <Field label="Notes"><Textarea value={notes} onChange={(e) => setNotes(e.target.value)} rows={3} /></Field>
          <DialogFooter>
            <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
            <Button type="submit" disabled={saving}>{saving ? 'Saving…' : asset ? 'Save changes' : 'Create asset'}</Button>
          </DialogFooter>
        </form>
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