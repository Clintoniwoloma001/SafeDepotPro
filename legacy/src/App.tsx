import { lazy, Suspense } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import Layout from '@/components/layouts/Layout'
import ProtectedRoute from '@/components/ProtectedRoute'
import { Skeleton } from '@/components/ui/skeleton'
import { ScrollToTop } from '@/components/ScrollToTop'

const Login = lazy(() => import('@/pages/auth/Login'))
const Register = lazy(() => import('@/pages/auth/Register'))
const ForgotPassword = lazy(() => import('@/pages/auth/ForgotPassword'))
const ResetPassword = lazy(() => import('@/pages/auth/ResetPassword'))
const OAuthCallback = lazy(() => import('@/pages/auth/OAuthCallback'))
const NotFound = lazy(() => import('@/pages/NotFound'))
const Dashboard = lazy(() => import('@/pages/Dashboard'))
const RoutineTasks = lazy(() => import('@/pages/RoutineTasks'))
const Assistant = lazy(() => import('@/pages/Assistant'))
const ShiftHandover = lazy(() => import('@/pages/ShiftHandover'))
const ToolboxTalks = lazy(() => import('@/pages/ToolboxTalks'))
const ManHours = lazy(() => import('@/pages/ManHours'))
const Permits = lazy(() => import('@/pages/Permits'))
const Inspections = lazy(() => import('@/pages/Inspections'))
const TruckInspections = lazy(() => import('@/pages/TruckInspections'))
const Incidents = lazy(() => import('@/pages/Incidents'))
const Hazards = lazy(() => import('@/pages/Hazards'))
const CorrectiveActions = lazy(() => import('@/pages/CorrectiveActions'))
const Assets = lazy(() => import('@/pages/Assets'))
const Personnel = lazy(() => import('@/pages/Personnel'))
const Depots = lazy(() => import('@/pages/Depots'))
const ChecklistBuilder = lazy(() => import('@/pages/ChecklistBuilder'))
const StandInManagement = lazy(() => import('@/pages/StandInManagement'))
const PlatformExport = lazy(() => import('@/pages/PlatformExport'))
const Settings = lazy(() => import('@/pages/Settings'))
const UserManagement = lazy(() => import('@/pages/UserManagement'))

function PageLoader() {
  return (
    <div className="p-6 space-y-4">
      <Skeleton className="h-9 w-64" />
      <Skeleton className="h-48 w-full" />
      <Skeleton className="h-48 w-full" />
    </div>
  )
}

function route(element: React.ReactNode) {
  return <Suspense fallback={<PageLoader />}>{element}</Suspense>
}

export default function App() {
  return (
    <>
      <ScrollToTop />
      <Routes>
        <Route path="/auth/login" element={route(<Login />)} />
        <Route path="/auth/register" element={route(<Register />)} />
        <Route path="/auth/forgot-password" element={route(<ForgotPassword />)} />
        <Route path="/auth/reset-password" element={route(<ResetPassword />)} />
        <Route path="/auth/callback" element={route(<OAuthCallback />)} />

        <Route
          element={
            <ProtectedRoute>
              <Layout />
            </ProtectedRoute>
          }
        >
          <Route index element={route(<Dashboard />)} />
          <Route path="tasks" element={route(<RoutineTasks />)} />
          <Route path="assistant" element={route(<Assistant />)} />
          <Route path="shift-handover" element={route(<ShiftHandover />)} />
          <Route path="toolbox" element={route(<ToolboxTalks />)} />
          <Route path="manhours" element={route(<ManHours />)} />
          <Route path="permits" element={route(<Permits />)} />
          <Route path="inspections" element={route(<Inspections />)} />
          <Route path="truck-inspections" element={route(<TruckInspections />)} />
          <Route path="incidents" element={route(<Incidents />)} />
          <Route path="hazards" element={route(<Hazards />)} />
          <Route path="capa" element={route(<CorrectiveActions />)} />
          <Route path="assets" element={route(<Assets />)} />
          <Route path="personnel" element={route(<Personnel />)} />
          <Route path="depots" element={route(<Depots />)} />
          <Route path="checklist-builder" element={route(<ChecklistBuilder />)} />
          <Route path="stand-in" element={route(<StandInManagement />)} />
          <Route path="platform-export" element={route(<PlatformExport />)} />
          <Route path="settings" element={route(<Settings />)} />
          <Route path="users" element={route(<UserManagement />)} />
        </Route>

        <Route path="/" element={<Navigate to="/auth/login" replace />} />
        <Route path="*" element={route(<NotFound />)} />
      </Routes>
    </>
  )
}