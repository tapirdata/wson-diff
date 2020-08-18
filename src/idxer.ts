import * as _ from "lodash"
import debugFactory from "debug"

const debug = debugFactory("wson-diff:idxer")

import { State } from "./diff"

export class Idxer {

  public state: State
  public keys: string[]
  public allString: boolean

  constructor(state: State, vals: any[], useHave: boolean, allString: boolean) {
    this.state = state
    let keys: string[]
    if (allString) {
      for (const val of vals) {
        if (!_.isString(val)) {
          allString = false
          break
        }
      }
      keys = vals as string[]
    }
    if (!allString) {
      keys = new Array(vals.length)
      for (let idx = 0; idx < vals.length; idx++) {
        const val = vals[idx]
        const key = this.state.stringify(val, useHave)
        keys[idx] = key
      }
      debug("keys=%o", keys)
    }
    this.keys = keys!
    this.allString = allString
  }

  public getItem(idx: number) {
    const key = this.keys[idx]
    if (this.allString) {
      return this.state.stringify(key)
    } else {
      return key
    }
  }
}
