import { useCallback, useEffect, useState } from 'react'

export interface GPSPosition {
  latitude: number
  longitude: number
  accuracy?: number
}

export function useGPS() {
  const [position, setPosition] = useState<GPSPosition | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const request = useCallback(() => {
    if (!('geolocation' in navigator)) {
      setError('Geolocation is not supported on this device.')
      return Promise.resolve(null)
    }
    setLoading(true)
    setError(null)
    return new Promise<GPSPosition | null>((resolve) => {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const p = { latitude: pos.coords.latitude, longitude: pos.coords.longitude, accuracy: pos.coords.accuracy }
          setPosition(p)
          setLoading(false)
          resolve(p)
        },
        (err) => {
          setError(err.message || 'Unable to retrieve location.')
          setLoading(false)
          resolve(null)
        },
        { enableHighAccuracy: true, timeout: 15_000 },
      )
    })
  }, [])

  useEffect(() => {
    // grab silently on mount when possible
    request().catch(() => {})
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return { position, error, loading, request }
}