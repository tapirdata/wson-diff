import debugFactory = require("debug")
const debug = debugFactory("wson-diff:wson-diff")

import * as _ from "lodash"
import wsonFactory, { Wson } from "wson"

import { Differ } from "./diff"
import { Delta, Patcher } from "./patch"
import { Target } from "./target"

export class WsonDiff {

  public WSON: Wson
  public options: any

  constructor(options: any = {}) {
    let { WSON } = options
    if (WSON == null) {
      WSON = wsonFactory(options.wsonOptions)
    }
    this.WSON = WSON
    this.options = options
  }

  public createPatcher(options: any = {}) {
    return new Patcher(this, options)
  }

  public createDiffer(options: any = {}) {
    return new Differ(this, options)
  }

  public diff(have: any, wish: any, options: any) {
    const differ = this.createDiffer(options)
    return differ.diff(have, wish)
  }

  public patch(have: any, delta: Delta, options: any) {
    const patcher = this.createPatcher(options)
    return patcher.patch(have, delta, options ? options.notifiers : undefined)
  }

  public patchTarget(target: Target, delta: Delta, options: any) {
    const patcher = this.createPatcher(options)
    return patcher.patchTarget(target, delta)
  }
}
