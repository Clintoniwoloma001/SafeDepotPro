import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import { useCurrentUser } from '@/hooks/useCurrentUser'

export default function DepotSelector() {
  const { depotId, setDepotId, visibleDepots } = useDepotFilter()
  const user = useCurrentUser()

  const value = depotId ?? 'all'

  return (
    <Select value={value} onValueChange={(v) => setDepotId(v === 'all' ? null : v)}>
      <SelectTrigger className="w-[11rem] sm:w-[15rem]" aria-label="Depot filter">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {user.canViewAllDepots && <SelectItem value="all">All Depots</SelectItem>}
        {!user.canViewAllDepots && <SelectItem value={user.effectiveDepotId ?? 'all'}>{visibleDepots[0]?.name ?? 'My Depot'}</SelectItem>}
        {user.canViewAllDepots &&
          visibleDepots.map((d) => (
            <SelectItem key={d.id} value={d.id}>
              {d.name} ({d.code})
            </SelectItem>
          ))}
      </SelectContent>
    </Select>
  )
}