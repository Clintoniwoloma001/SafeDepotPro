import { useMemo } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { riskRating } from '@/lib/constants'
import { cn } from '@/lib/utils'

const LIKELIHOOD_LABELS = ['Rare', 'Unlikely', 'Possible', 'Likely', 'Almost certain']
const SEVERITY_LABELS = ['Low', 'Medium', 'High', 'Critical']

function ratingClass(r: string) {
  switch (r) {
    case 'CRITICAL':
      return 'bg-red-600 text-white'
    case 'HIGH':
      return 'bg-orange-500 text-white'
    case 'MEDIUM':
      return 'bg-amber-400 text-black'
    case 'LOW':
      return 'bg-green-600 text-white'
    default:
      return 'bg-muted text-muted-foreground'
  }
}

interface RiskMatrixProps {
  /** Highlight initial and residual scores (n = likelihood × severity). */
  initialScore?: number | null
  residualScore?: number | null
}

export function RiskMatrix({ initialScore, residualScore }: RiskMatrixProps) {
  const severityLevels = [1, 2, 3, 4]

  const cells = useMemo(
    () =>
      LIKELIHOOD_LABELS.map((_, li) =>
        severityLevels.map((severity) => {
          const score = (li + 1) * severity
          return { score, rating: riskRating(score) }
        }),
      ),
    [],
  )

  const mark = (score: number) => {
    if (initialScore != null && score === Math.max(1, Math.round(initialScore))) return 'initial'
    if (residualScore != null && score === Math.max(1, Math.round(residualScore))) return 'residual'
    return null
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Risk Matrix</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-center text-xs">
            <thead>
              <tr>
                <th className="border p-1 text-muted-foreground">Likelihood ↓</th>
                {SEVERITY_LABELS.map((s) => (
                  <th key={s} className="border p-1 font-medium">
                    {s}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {cells.map((row, li) => (
                <tr key={li}>
                  <td className="border p-1 text-left text-muted-foreground">{LIKELIHOOD_LABELS[li]}</td>
                  {row.map((cell) => {
                    const m = mark(cell.score)
                    return (
                      <td
                        key={cell.score}
                        className={cn(
                          'border p-2',
                          ratingClass(cell.rating),
                          m && 'ring-2 ring-offset-1 ring-brand',
                        )}
                      >
                        {cell.rating.slice(0, 1)}
                        {m === 'initial' && <span className="block text-[9px] font-bold">INITIAL</span>}
                        {m === 'residual' && <span className="block text-[9px] font-bold">RESIDUAL</span>}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="mt-2 flex flex-wrap gap-3 text-[11px] text-muted-foreground">
          <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-green-600" />Low (1–3)</span>
          <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-amber-400" />Medium (4–7)</span>
          <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-orange-500" />High (8–14)</span>
          <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-red-600" />Critical (15+)</span>
        </div>
      </CardContent>
    </Card>
  )
}