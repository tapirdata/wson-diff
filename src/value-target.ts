import debugFactory from "debug"
import { Wson } from "wson"

import { NotifierTarget } from "./notifier-target"
import { Key, Patch, Target } from "./target"

const debug = debugFactory("wson-diff:value-target")

export class ValueTarget implements Target {

  public WSON: Wson
  public root: any
  public current: any
  public stack: any[]
  public topKey: any
  public subTarget: NotifierTarget | null

  constructor(WSON: Wson, root: any) {
    this.WSON = WSON
    this.root = this.current = root
    this.stack = []
    this.topKey = null
    this.subTarget = null
  }

  public setSubTarget(subTarget: NotifierTarget | null) {
    this.subTarget = subTarget
  }

  public put_(key: string | null, value: any) {
    if (key != null) {
      this.current[key] = value
    } else {
      this.current = value
      const { stack } = this
      if (stack.length === 0) {
        this.root = this.current
      } else {
        stack[stack.length - 1][this.topKey] = value
      }
    }
  }

  public closeObjects_(tillIdx: number) {
    let value = this.current
    const { stack } = this
    let idx = stack.length
    while (true) {
      debug("closeObjects_ %o", value)
      if (typeof value === "object" && (value.constructor != null) && value.constructor !== Object) {
        const connector = this.WSON.connectorOfValue(value)
        debug("closeObjects_ connector=%o", connector)
        if (connector && connector.postpatch) {
          connector.postpatch(value)
        }
      }
      if (--idx < tillIdx) {
        break
      }
      value = stack[idx]
    }
  }

  public get(up: number) {
    if ((up == null) || up <= 0) {
      return this.current
    } else {
      const { stack } = this
      return stack[stack.length - up]
    }
  }

  public budge(up: number, key: Key) {
    debug("budge(up=%o key=%o)", up, key)
    debug("budge: stack=%o current=%o", this.stack, this.current)
    const { stack } = this
    let current: any
    if (this.subTarget) {
      this.subTarget.budge(up, key)
    }
    if (up > 0) {
      const newLen = stack.length - up
      this.closeObjects_(newLen + 1)
      current = stack[newLen]
      stack.splice(newLen)
    } else {
      current = this.current
    }
    if (key != null) {
      stack.push(current)
      current = current[key]
    }
    this.current = current
    this.topKey = key
  }

  public unset(key: string) {
    debug("unset(key=%o) @current=%o", key, this.current)
    if (this.subTarget) {
      this.subTarget.unset(key)
    }
    delete this.current[key]
  }

  public assign(key: string | null, value: any) {
    debug("assign(key=%o value=%o)", key, value)
    if (this.subTarget) {
      this.subTarget.assign(key, value)
    }
    this.put_(key, value)
  }

  public delete(idx: number, len: number) {
    debug("delete(idx=%o len=%o) @current=%o", idx, len, this.current)
    if (this.subTarget) {
      this.subTarget.delete(idx, len)
    }
    this.current.splice(idx, len)
  }

  public move(srcIdx: number, dstIdx: number, len: number, reverse: boolean) {
    debug("move(srcIdx=%o dstIdx=%o len=%o reverse=%o)", srcIdx, dstIdx, len, reverse)
    if (this.subTarget) {
      this.subTarget.move(srcIdx, dstIdx, len, reverse)
    }
    const { current } = this
    const chunk = current.splice(srcIdx, len)
    if (reverse) {
      chunk.reverse()
    }
    current.splice.apply(current, [dstIdx, 0].concat(chunk))
  }

  public insert(idx: number, values: any[]) {
    if (this.subTarget) {
      this.subTarget.insert(idx, values)
    }
    const { current } = this
    current.splice.apply(current, [idx, 0].concat(values))
  }

  public replace(idx: number, values: any[]) {
    debug("replace(idx=%o, values=%o)", idx, values)
    if (this.subTarget) {
      this.subTarget.replace(idx, values)
    }
    const valuesLen = values.length
    if (valuesLen === 0) {
      return
    }
    const { current } = this
    let valuesIdx = 0
    while (true) {
      current[idx] = values[valuesIdx]
      if (++valuesIdx === valuesLen) {
        break
      } else {
        ++idx
      }
    }
  }

  public substitute(patches: Patch[]) {
    debug("substitute(patches=%o)", patches)
    if (this.subTarget) {
      this.subTarget.substitute(patches)
    }
    const { current } = this
    let result = ""
    let endOfs = 0
    for (const patch of patches) {
      const [ofs, lenDiff, str] = patch
      if (ofs > endOfs) {
        result += current.slice(endOfs, ofs)
      }
      const strLen = str.length
      if (strLen > 0) {
        result += str
      }
      endOfs = (ofs + strLen) - lenDiff
      debug("substitute: patch=%o result=%o", patch, result)
    }
    if (current.length > endOfs) {
      result += current.slice(endOfs)
    }
    debug("substitute: result=%o", result)
    this.put_(null, result)
  }

  public done() {
    debug("done: stack=%o current=%o", this.stack, this.current)
    if (this.subTarget) {
      this.subTarget.done()
    }
    this.closeObjects_(0)
  }

  public getRoot() { return this.root }
}
