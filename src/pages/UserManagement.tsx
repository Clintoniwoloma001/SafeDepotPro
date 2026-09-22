import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { UserPlus } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, KPICard } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { listUsersWithProfiles, inviteUser, deleteUserAccount, setUserRole } from '@/services/users.service'
import { listDepots } from '@/services/depots.service'
import { cn } from '@/lib/utils'
import type { UserRole } from '@/types/enums'
import type { Depot } from '@/types/entities'

const ROLES: UserRole[] = ['USER', 'COUNTRY_HEAD', 'ADMIN', 'SUPERADMIN']

export default function UserManagement() {
  const user = useCurrentUser()
  const queryClient = useQueryClient()
  const [inviting, setInviting] = useState(false)

  const { data: rows = [] } = useQuery({ queryKey: ['users-admin'], queryFn: () => listUsersWithProfiles() })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['users-admin'] })

  const invite = useMutation({
    mutationFn: inviteUser,
    onSuccess: () => {
      toast.success('User invited')
      setInviting(false)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not invite user'),
  })

  const roleMut = useMutation({
    mutationFn: ({ userId, role }: { userId: string; role: UserRole }) => setUserRole(userId, role),
    onSuccess: () => {
      toast.success('Role updated')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not update role'),
  })

  const del = useMutation({
    mutationFn: deleteUserAccount,
    onSuccess: () => {
      toast.success('User deleted')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not delete user'),
  })

  if (!user.isSuperadmin) {
    return (
      <div className="space-y-8">
        <PageHeader title="User Management" subtitle="Superadmin only" />
        <EmptyState
          title="Restricted area"
          description="Only the SUPERADMIN can invite users, change roles and remove accounts."
        />
      </div>
    )
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="User Management"
        subtitle={`${rows.length} accounts on the platform`}
        actions={<Button onClick={() => setInviting(true)}><UserPlus className="mr-1 h-4 w-4" /> Invite user</Button>}
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<UserPlus className="h-4 w-4" />} iconHue="blue" label="Total accounts" value={rows.length} />
        <KPICard icon={<UserPlus className="h-4 w-4" />} iconHue="red" label="Superadmins" value={rows.filter((r) => r.profile?.role === 'SUPERADMIN').length} />
        <KPICard icon={<UserPlus className="h-4 w-4" />} iconHue="amber" label="Country heads" value={rows.filter((r) => r.profile?.role === 'COUNTRY_HEAD').length} />
      </div>

      {rows.length === 0 ? (
        <EmptyState title="No users" description="Invite your first user to the platform." />
      ) : (
        <SectionCard title="Accounts">
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>User</TableHead>
                  <TableHead className="hidden md:table-cell">Email</TableHead>
                  <TableHead>Depot</TableHead>
                  <TableHead>Role</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-20">{/* actions */}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((r) => (
                  <TableRow key={r.user.id}>
                    <TableCell className="font-medium">{r.profile?.full_name ?? r.user.email}</TableCell>
                    <TableCell className="hidden md:table-cell text-xs">{r.user.email}</TableCell>
                    <TableCell>{depotName(r.profile?.depot_id ?? null)}</TableCell>
                    <TableCell>
                      <Select value={r.profile?.role ?? 'USER'} onValueChange={(v) => roleMut.mutate({ userId: r.user.id, role: v as UserRole })}>
                        <SelectTrigger className="h-8 w-32 text-xs"><SelectValue /></SelectTrigger>
                        <SelectContent>{ROLES.map((role) => <SelectItem key={role} value={role}>{role}</SelectItem>)}</SelectContent>
                      </Select>
                    </TableCell>
                    <TableCell>
                      <span className={cn('rounded-full px-2 py-0.5 text-xs font-medium', r.profile?.is_active === false ? 'bg-muted text-muted-foreground' : 'bg-rag-good/10 text-rag-good')}>
                        {r.profile?.is_active === false ? 'Disabled' : 'Active'}
                      </span>
                    </TableCell>
                    <TableCell className="text-right">
                      <Button size="sm" variant="ghost" className="h-7 px-2 text-rag-bad" onClick={() => void del.mutate(r.user.id)}>
                        Remove
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </SectionCard>
      )}

      <InviteDialog open={inviting} onOpenChange={setInviting} depots={depots} depotName={depotName} onInvite={(input) => invite.mutate(input)} />
    </div>
  )
}

function InviteDialog({
  open,
  onOpenChange,
  depots,
  depotName,
  onInvite,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  depots: Depot[]
  depotName: (id: string | null) => string
  onInvite: (input: Parameters<typeof inviteUser>[0]) => void
}) {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [role, setRole] = useState<UserRole>('USER')
  const [depotId, setDepotId] = useState('__none__')
  const [position, setPosition] = useState('')
  const [password, setPassword] = useState('')
  const selectedDepotLabel = depotId === '__none__' ? 'None' : depotName(depotId)

  const submit = () => {
    if (!name.trim()) return toast.error('Name is required.')
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return toast.error('Enter a valid email.')
    if (password.length < 10) return toast.error('Initial password must be at least 10 characters.')
    onInvite({
      name: name.trim(),
      email: email.trim(),
      role,
      depotId: depotId === '__none__' ? null : depotId,
      position: position || undefined,
      initialPassword: password,
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader><DialogTitle>Invite user</DialogTitle></DialogHeader>
        <div className="space-y-3">
          <Field label="Full name *"><Input value={name} onChange={(e) => setName(e.target.value)} /></Field>
          <Field label="Email *"><Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} /></Field>
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Role">
              <Select value={role} onValueChange={(v) => setRole(v as UserRole)}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>{ROLES.map((r) => <SelectItem key={r} value={r}>{r}</SelectItem>)}</SelectContent>
              </Select>
            </Field>
            <Field label="Depot">
              <Select value={depotId} onValueChange={setDepotId}>
                <SelectTrigger><SelectValue placeholder={selectedDepotLabel} /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="__none__">None</SelectItem>
                  {depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name}</SelectItem>)}
                </SelectContent>
              </Select>
            </Field>
          </div>
          <Field label="Position"><Input value={position} onChange={(e) => setPosition(e.target.value)} placeholder="e.g. Operations Manager" /></Field>
          <Field label="Initial password * (minimum 10 characters)"><Input type="text" value={password} onChange={(e) => setPassword(e.target.value)} /></Field>
          <div className="text-xs text-muted-foreground">The user must change this password on first login.</div>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
            <Button onClick={submit}>Send invite</Button>
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