import { useGPS } from '@/hooks/useGPS'
import { Badge } from '@/components/ui/badge'
import { MapPin } from 'lucide-react'
import { cn } from '@/lib/utils'

export default function GPSStatus({ compact = false }: { compact?: boolean }) {
  const { position, error, loading } = useGPS()

  if (error) {
    return (
      <Badge variant="outline" className="gap-1 bg-red-50 text-red-600">
        <MapPin className="h-3 w-3" /> {compact ? 'GPS off' : 'GPS unavailable'}
      </Badge>
    )
  }
  if (loading && !position) {
    return (
      <Badge variant="outline" className="gap-1 text-muted-foreground">
        <MapPin className="h-3 w-3 animate-pulse" /> {compact ? 'Locating…' : 'Locating…'}
      </Badge>
    )
  }
  if (position) {
    return (
      <Badge variant="outline" className={cn('gap-1 bg-green-50 text-green-700')}>
        <MapPin className="h-3 w-3" />
        {compact ? 'GPS active' : `${position.latitude.toFixed(4)}, ${position.longitude.toFixed(4)}`}
      </Badge>
    )
  }
  return null
}