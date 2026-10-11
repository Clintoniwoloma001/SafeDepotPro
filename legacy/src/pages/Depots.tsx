import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { MapPin, Plus, Pencil, Layers, Trash2, X } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, KPICard } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { listDepots, deriveDepotCode, createDepot, updateDepot, deleteDepot, listZones, createZone, deleteZone } from '@/services/depots.service'
import { cn } from '@/lib/utils'
import type { Depot } from '@/types/entities'

export default function Depots() {
  const user = useCurrentUser()
  const queryClient = useQueryClient()
  const [creating, setCreating] = useState(false)
  const [editing, setEditing] = useState<Depot | null>(null)
  const [zonesFor, setZonesFor] = useState<Depot | null>(null)

  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const { data: zones = [] } = useQuery({ queryKey: ['zones', zonesFor?.id], queryFn: () => (zonesFor ? listZones(zonesFor.id) : Promise.resolve([] as Awaited<ReturnType<typeof listZones>>)), enabled: Boolean(zonesFor) })

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['depots'] })
    if (zonesFor) void queryClient.invalidateQueries({ queryKey: ['zones', zonesFor.id] })
  }

  const save = useMutation({
    mutationFn: async (input: Partial<Depot>) => (editing ? updateDepot(editing.id, input) : createDepot(input)),
    onSuccess: () => {
      toast.success(editing ? 'Depot updated' : 'Depot created')
      setCreating(false)
      setEditing(null)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save depot'),
  })

  const del = useMutation({
    mutationFn: deleteDepot,
    onSuccess: () => {
      toast.success('Depot removed')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not remove depot'),
  })

  const setOpen = (v: boolean) => {
    if (!v) {
      setCreating(false)
      setEditing(null)
    }
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="Depots"
        subtitle={`${depots.length} active depots`}
        actions={user.isManagement ? <Button onClick={() => setCreating(true)}><Plus className="mr-1 h-4 w-4" /> New depot</Button> : undefined}
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<MapPin className="h-4 w-4" />} iconHue="blue" label="Active depots" value={depots.length} />
        <KPICard icon={<Layers className="h-4 w-4" />} iconHue="amber" label="GPS enabled" value={depots.filter((d) => d.latitude != null && d.longitude != null).length} />
        <KPICard icon={<MapPin className="h-4 w-4" />} iconHue="green" label="Zones" value={zonesFor ? zones.length : '—'} />
      </div>

      {depots.length === 0 ? (
        <EmptyState title="No depots" description="Create your first depot to start assigning personnel and tasks." />
      ) : (
        <SectionCard title="Depot register">
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Code</TableHead>
                  <TableHead className="hidden md:table-cell">Address</TableHead>
                  <TableHead className="hidden lg:table-cell">GPS</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-24">{/* actions */}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {depots.map((d) => (
                  <TableRow key={d.id}>
                    <TableCell className="font-medium">{d.name}</TableCell>
                    <TableCell className="font-mono text-xs">{d.code}</TableCell>
                    <TableCell className="hidden md:table-cell">{d.address ?? '—'}</TableCell>
                    <TableCell className="hidden lg:table-cell text-xs">
                      {d.latitude != null ? `${d.latitude.toFixed(4)}, ${d.longitude?.toFixed(4)}` : '—'}
                    </TableCell>
                    <TableCell>
                      <span className={cn('rounded-full px-2 py-0.5 text-xs font-medium', d.is_active ? 'bg-rag-good/10 text-rag-good' : 'bg-muted text-muted-foreground')}>
                        {d.is_active ? 'Active' : 'Inactive'}
                      </span>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-1">
                        <Button size="sm" variant="outline" className="h-7 px-2" onClick={() => setZonesFor(d)}>
                          <Layers className="h-3.5 w-3.5" />
                        </Button>
                        {user.isManagement && (
                          <>
                            <Button size="sm" variant="outline" className="h-7 px-2" onClick={() => setEditing(d)}>
                              <Pencil className="h-3.5 w-3.5" />
                            </Button>
                            <Button size="sm" variant="ghost" className="h-7 px-2 text-rag-bad" onClick={() => del.mutate(d.id)}>
                              <Trash2 className="h-3.5 w-3.5" />
                            </Button>
                          </>
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

      <DepotForm open={creating || editing !== null} onOpenChange={setOpen} depot={editing} onSave={(input) => save.mutate(input)} />

      <ZonesDialog depot={zonesFor} zones={zones} onClose={() => setZonesFor(null)} onCreate={(name) => {
        if (zonesFor) {
          void createZone(zonesFor.id, name).then(() => {
            toast.success('Zone added')
            invalidate()
          }).catch((e) => toast.error(e instanceof Error ? e.message : 'Could not add zone'))
        }
      }} onDelete={(id) => {
        void deleteZone(id).then(() => {
          toast.success('Zone removed')
          invalidate()
        }).catch((e) => toast.error(e instanceof Error ? e.message : 'Could not remove zone'))
      }} />
    </div>
  )
}

function DepotForm({ open, onOpenChange, depot, onSave }: { open: boolean; onOpenChange: (v: boolean) => void; depot: Depot | null; onSave: (input: Partial<Depot>) => void }) {
  const [name, setName] = useState('')
  const [code, setCode] = useState('')
  const [address, setAddress] = useState('')
  const [lat, setLat] = useState('')
  const [lng, setLng] = useState('')
  const [isActive, setIsActive] = useState(true)

  useEffect(() => {
    if (!open) return
    setName(depot?.name ?? '')
    setCode(depot?.code ?? '')
    setAddress(depot?.address ?? '')
    setLat(depot?.latitude != null ? String(depot.latitude) : '')
    setLng(depot?.longitude != null ? String(depot.longitude) : '')
    setIsActive(depot?.is_active ?? true)
    if (!depot) setCode(deriveDepotCode(''))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, depot])

  const onNameChange = (v: string) => {
    setName(v)
    if (!depot || code === deriveDepotCode(depot.name)) setCode(deriveDepotCode(v))
  }

  const submit = () => {
    if (!name.trim()) return toast.error('Depot name is required.')
    if (!code.trim()) return toast.error('Code is required.')
    onSave({
      name: name.trim(),
      code: code.trim().toUpperCase(),
      address: address || null,
      latitude: lat ? Number(lat) : null,
      longitude: lng ? Number(lng) : null,
      is_active: isActive,
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader><DialogTitle>{depot ? `Edit ${depot.name}` : 'New depot'}</DialogTitle></DialogHeader>
        <div className="space-y-3">
          <Field label="Depot name *"><Input value={name} onChange={(e) => onNameChange(e.target.value)} /></Field>
          <Field label="Code *"><Input value={code} onChange={(e) => setCode(e.target.value)} /></Field>
          <Field label="Address"><Input value={address} onChange={(e) => setAddress(e.target.value)} /></Field>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Latitude"><Input type="number" step="any" value={lat} onChange={(e) => setLat(e.target.value)} /></Field>
            <Field label="Longitude"><Input type="number" step="any" value={lng} onChange={(e) => setLng(e.target.value)} /></Field>
          </div>
          <div className="flex items-center gap-2">
            <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} className="rounded border-gray-300" />
            <span className="text-sm">Active</span>
          </div>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
            <Button onClick={submit}>{depot ? 'Save changes' : 'Create depot'}</Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}

function ZonesDialog({ depot, zones, onClose, onCreate, onDelete }: { depot: Depot | null; zones: Awaited<ReturnType<typeof listZones>>; onClose: () => void; onCreate: (name: string) => void; onDelete: (id: string) => void }) {
  const [name, setName] = useState('')

  useEffect(() => {
    if (!depot) setName('')
  }, [depot])

  return (
    <Dialog open={Boolean(depot)} onOpenChange={(v) => { if (!v) onClose() }}>
      <DialogContent>
        <DialogHeader><DialogTitle>Zones — {depot?.name}</DialogTitle></DialogHeader>
        <div className="space-y-3">
          <div className="flex gap-2">
            <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Zone name (e.g. Bulk yard)" />
            <Button disabled={!name.trim() || !depot} onClick={() => { onCreate(name.trim()); setName('') }}>Add</Button>
          </div>
          <div className="space-y-1">
            {zones.length === 0 && <p className="text-sm text-muted-foreground">No zones yet.</p>}
            {zones.map((z) => (
              <div key={z.id} className="flex items-center justify-between rounded-lg border px-3 py-2 text-sm">
                <span>{z.name}</span>
                <Button size="sm" variant="ghost" className="h-7 px-2 text-rag-bad" onClick={() => onDelete(z.id)}>
                  <X className="h-4 w-4" />
                </Button>
              </div>
            ))}
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