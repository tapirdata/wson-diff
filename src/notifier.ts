import { Key, Patch } from "./target"

export interface Notifier {
  checkedBudge: (up: number, key: Key, current: any) => boolean
  unset: (key: string, curent: any) => void
  assign: (key: string | null, value: any, current?: any) => void
  delete: (idx: number, len: number, current?: any) => void
  move: (srcIdx: number, dstIdx: number, len: number, reverse: boolean, current?: any) => void
  insert: (idx: number, values: any[], current?: any) => void
  replace: (idx: number, values: any[], current?: any) => void
  substitute: (patches: Patch[], current?: any) => void
}
