import debugFactory = require("debug")
const debug = debugFactory("wson-diff:object-diff")
import * as _ from "lodash"

import { State } from "./diff"

const { hasOwnProperty } = Object.prototype

export interface Obj {
  [key: string]: any
}

export class ObjectDiff {

  public state: State
  public aborted: boolean
  public have!: Obj
  public wish!: Obj

  constructor(state: State, have: Obj, wish: Obj) {
    this.state = state
    if (have.constructor !== wish.constructor) {
      this.aborted = true
    } else {
      this.have = have
      this.wish = wish
      this.aborted = false
    }
  }

  public getDelta(isRoot: boolean) {
    const { have } = this
    const { wish } = this
    debug("getDelta(have=%o, wish=%o, isRoot=%o)", have, wish, isRoot)
    let delta = ""
    const { state } = this

    let diffKeys: string[] | null = null
    if ((have.constructor != null) && have.constructor !== Object) {
      const connector = state.differ.wdiff.WSON.connectorOfValue(have)
      diffKeys = connector ? connector.diffKeys : null
    }
    const hasDiffKeys = (diffKeys != null)

    let delCount = 0
    const haveKeys: string[] = hasDiffKeys ? (diffKeys as string[]) : _(have).keys().sort().value()
    for (const key of haveKeys) {
      if (!hasOwnProperty.call(wish, key)) {
        if (delCount === 0) {
          if (isRoot) {
            delta += "|"
          }
          delta += "[-"
        } else {
          delta += "|"
        }
        delta += state.stringify(key)
        ++delCount
      }
    }
    if (delCount > 0) {
      delta += "]"
    }

    let setDelta = ""
    let setCount = 0
    const wishKeys: string[] = hasDiffKeys ? (diffKeys as string[]) : _(wish).keys().sort().value()
    for (const key of wishKeys) {
      if (hasDiffKeys && !hasOwnProperty.call(wish, key)) {
        continue
      }
      const keyDelta = state.getDelta(have[key], wish[key], false)
      debug("getDelta: key=%o, keyDelta=%o", key, keyDelta)
      if (keyDelta != null) {
        if (setCount > 0) {
          setDelta += "|"
        }
        setDelta += state.stringify(key) + keyDelta
        ++setCount
      }
    }
    debug("getDelta: setDelta=%o, setCount=%o", setDelta, setCount)
    if (setCount > 0) {
      if (isRoot) {
        if (delCount === 0) {
          delta += "|"
        }
        delta += setDelta
      } else {
        if (setCount === 1 && delCount === 0) {
          delta += "|"
          delta += setDelta
        } else {
          delta += `[=${setDelta}]`
        }
      }
    }
    if (delta.length) {
      return delta
    } else {
      return null
    }
  }
}
