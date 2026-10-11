import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Users, Plus, Pencil, UserCog } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { PageHeader, EmptyState, SectionCard, KPICard } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import { listPersonnel, createPersonnel, updatePersonnel, deletePersonnel, listProfiles, updateProfileRole, updateProfileDepot, setProfileActive } from '@/services/personnel.service'
import { listDepots } from '@/services/depots.service'
import { cn } from '@/lib/utils'
import type { Personnel } from '@/types/entities'
import type { UserRole } from '@/types/enums'

const ROLES: UserRole[] = ['USER', 'COUNTRY_HEAD', 'ADMIN', 'SUPERADMIN']

export default function Personnel() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [creating, setCreating] = useState(false)
  const [editing, setEditing] = useState<Personnel | null>(null)

  const { data: people = [] } = useQuery({ queryKey: ['personnel', depotId ?? 'all'], queryFn: () => listPersonnel(depotId ? { depotId } : {}) })
  const { data: profiles = [] } = useQuery({ queryKey: ['profiles'], queryFn: () => listProfiles(), enabled: Boolean(user.userId) })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const scoped = user.isCountryHead ? people : people.filter((p) => p.depot_id === user.effectiveDepotId)

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['personnel'] })
    queryClient.invalidateQueries({ queryKey: ['profiles'] })
  }

  const save = useMutation({
    mutationFn: async (input: Partial<Personnel>) => (editing ? updatePersonnel(editing.id, input) : createPersonnel(input)),
    onSuccess: () => {
      toast.success(editing ? 'Personnel updated' : 'Personnel added')
      setCreating(false)
      setEditing(null)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save personnel'),
  })

  const del = useMutation({
    mutationFn: deletePersonnel,
    onSuccess: () => {
      toast.success('Personnel removed')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not remove'),
  })

  const roleMut = useMutation({
    mutationFn: ({ id, role }: { id: string; role: UserRole }) => updateProfileRole(id, role),
    onSuccess: () => {
      toast.success('Role updated')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not update role'),
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
        title="Personnel"
        subtitle={`${scoped.length} active staff on record`}
        actions={<Button onClick={() => setCreating(true)}><Plus className="mr-1 h-4 w-4" /> Add personnel</Button>}
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<Users className="h-4 w-4" />} iconHue="green" label="Active staff" value={scoped.length} />
        <KPICard icon={<Users className="h-4 w-4" />} iconHue="blue" label="Total accounts" value={profiles.length} />
        <KPICard icon={<UserCog className="h-4 w-4" />} iconHue="amber" label="Supervisors (ADMIN+)" value={profiles.filter((p) => p.role === 'ADMIN' || p.role === 'SUPERADMIN').length} />
      </div>

      <Tabs defaultValue="directory">
        <TabsList>
          <TabsTrigger value="directory">Directory</TabsTrigger>
          <TabsTrigger value="accounts">User accounts</TabsTrigger>
        </TabsList>

        <TabsContent value="directory" className="mt-4">
          {scoped.length === 0 ? (
            <EmptyState title="No personnel" description="Add your team members so they can be assigned to tasks and CAPAs." />
          ) : (
            <SectionCard title="Staff directory">
              <CardContent className="p-0">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Name</TableHead>
                      <TableHead className="hidden sm:table-cell">Position</TableHead>
                      <TableHead className="hidden md:table-cell">Depot</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead className="w-24">{/* actions */}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {scoped.map((p) => (
                      <TableRow key={p.id}>
                        <TableCell>
                          <div className="font-medium">{p.first_name} {p.last_name}</div>
                          <div className="text-xs text-muted-foreground">{p.email}</div>
                        </TableCell>
                        <TableCell className="hidden sm:table-cell">{p.position ?? '—'}</TableCell>
                        <TableCell className="hidden md:table-cell">{depotName(p.depot_id)}</TableCell>
                        <TableCell>
                          <span className={cn('rounded-full px-2 py-0.5 text-xs font-medium', p.is_active ? 'bg-rag-good/10 text-rag-good' : 'bg-muted text-muted-foreground')}>
                            {p.is_active ? 'Active' : 'Inactive'}
                          </span>
                        </TableCell>
                        <TableCell className="text-right">
                          <div className="flex justify-end gap-1">
                            <Button size="sm" variant="outline" className="h-7 px-2" onClick={() => setEditing(p)}>
                              <Pencil className="h-3.5 w-3.5" />
                            </Button>
                            <Button size="sm" variant="ghost" className="h-7 px-2 text-rag-bad" onClick={() => del.mutate(p.id)}>
                              ×
                            </Button>
                          </div>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </SectionCard>
          )}
        </TabsContent>

        <TabsContent value="accounts" className="mt-4">
          {profiles.length === 0 ? (
            <EmptyState title="No user accounts" description="Accounts appear once users sign in or are invited." />
          ) : (
            <SectionCard title="User accounts & roles">
              <CardContent className="p-0">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>User</TableHead>
                      <TableHead className="hidden md:table-cell">Email</TableHead>
                      <TableHead>Depot</TableHead>
                      <TableHead>Role</TableHead>
                      <TableHead>Status</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {profiles.map((p) => (
                      <TableRow key={p.id}>
                        <TableCell className="font-medium">{p.full_name}</TableCell>
                        <TableCell className="hidden md:table-cell text-xs">{p.email}</TableCell>
                        <TableCell>
                          {user.isManagement ? (
                            <Select value={p.depot_id ?? 'none'} onValueChange={(v) => { void updateProfileDepot(p.id, v === 'none' ? null : v).then(() => invalidate()) }}>
                              <SelectTrigger className="h-8 w-36 text-xs"><SelectValue /></SelectTrigger>
                              <SelectContent>
                                <SelectItem value="none">None</SelectItem>
                                {depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name}</SelectItem>)}
                              </SelectContent>
                            </Select>
                          ) : (
                            depotName(p.depot_id)
                          )}
                        </TableCell>
                        <TableCell>
                          {user.isManagement ? (
                            <Select value={p.role} onValueChange={(v) => roleMut.mutate({ id: p.id, role: v as UserRole })}>
                              <SelectTrigger className="h-8 w-32 text-xs"><SelectValue /></SelectTrigger>
                              <SelectContent>{ROLES.map((r) => <SelectItem key={r} value={r}>{r}</SelectItem>)}</SelectContent>
                            </Select>
                          ) : (
                            p.role
                          )}
                        </TableCell>
                        <TableCell>
                          <button onClick={() => user.isManagement && void setProfileActive(p.id, !p.is_active).then(() => invalidate())} className={cn('rounded-full px-2 py-0.5 text-xs font-medium', p.is_active ? 'bg-rag-good/10 text-rag-good' : 'bg-rag-bad/10 text-rag-bad')}>
                            {p.is_active ? 'Active' : 'Disabled'}
                          </button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </SectionCard>
          )}
        </TabsContent>
      </Tabs>

      <PersonnelForm
        open={creating || editing !== null}
        onOpenChange={setOpen}
        person={editing}
        defaultDepotId={user.effectiveDepotId ?? undefined}
        depotName={depotName}
        onSave={(input) => save.mutate(input)}
      />
    </div>
  )
}

function PersonnelForm({
  open,
  onOpenChange,
  person,
  defaultDepotId,
  depotName,
  onSave,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  person: Personnel | null
  defaultDepotId?: string
  depotName: (id: string | null) => string
  onSave: (input: Partial<Personnel>) => void
}) {
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const [first, setFirst] = useState('')
  const [last, setLast] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [position, setPosition] = useState('')
  const [depotId, setDepotId] = useState(defaultDepotId ?? '')
  const [isActive, setIsActive] = useState(true)

  useEffect(() => {
    if (!open) return
    setFirst(person?.first_name ?? '')
    setLast(person?.last_name ?? '')
    setEmail(person?.email ?? '')
    setPhone(person?.phone ?? '')
    setPosition(person?.position ?? '')
    setDepotId(person?.depot_id ?? defaultDepotId ?? '')
    setIsActive(person?.is_active ?? true)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, person])

  const submit = () => {
    if (!first.trim() || !last.trim()) return toast.error('Name is required.')
    if (!email.trim()) return toast.error('Email is required.')
    onSave({
      first_name: first.trim(),
      last_name: last.trim(),
      email: email.trim(),
      phone: phone || null,
      position: position || null,
      depot_id: depotId || null,
      is_active: isActive,
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader><DialogTitle>{person ? 'Edit personnel' : 'Add personnel'}</DialogTitle></DialogHeader>
        <div className="space-y-3">
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="First name *"><Input value={first} onChange={(e) => setFirst(e.target.value)} /></Field>
            <Field label="Last name *"><Input value={last} onChange={(e) => setLast(e.target.value)} /></Field>
            <Field label="Email *"><Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} /></Field>
            <Field label="Phone"><Input value={phone} onChange={(e) => setPhone(e.target.value)} /></Field>
          </div>
          <Field label="Position"><Input value={position} onChange={(e) => setPosition(e.target.value)} placeholder="e.g. HSE Officer" /></Field>
          <Field label="Depot">
            <Select value={depotId} onValueChange={setDepotId}>
              <SelectTrigger><SelectValue placeholder={depotName(depotId) || 'Select'} /></SelectTrigger>
              <SelectContent>{depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name}</SelectItem>)}</SelectContent>
            </Select>
          </Field>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
            <Button onClick={submit}>{person ? 'Save changes' : 'Add'}</Button>
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