export { listTaskHistory, recordTaskCompletion, deleteTaskHistory } from './routineTasks.service'
import { listTaskHistory, getRoutineTask } from './routineTasks.service'
export const fetchTaskHistory = listTaskHistory
export const fetchTask = getRoutineTask