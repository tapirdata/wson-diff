import debugFactory = require("debug")
const debug = debugFactory("wson-diff:target")

export type Key = string | number | null
export type Patch = [number, number, string]

export interface Target {

  get(up?: number): any
  budge(up: number, key: Key): void

  unset(key: string): void
  assign(key: string | null, value: any): void

  delete(idx: number, len: number): void
  move(srcIdx: number, dstIdx: number, len: number, reverse: boolean): void
  insert(idx: number, values: any[]): void
  replace(idx: number, values: any[]): void

  substitute(patches: Patch[]): void

  done(): void
}
