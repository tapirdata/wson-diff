import debugFactory = require("debug")
const debug = debugFactory("wson-diff:index")

import { PatchError } from "./patch"
import { WsonDiff } from "./wson-diff"

export interface Factory {
  (options: any): WsonDiff
  PatchError: typeof PatchError
}

const factory = ((createOptions: any) => {
  return new WsonDiff(createOptions)
}) as Factory

factory.PatchError = PatchError

export default factory
export { Notifier } from "./notifier"
export { Key, Patch, Target } from "./target"
