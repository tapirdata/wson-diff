import debugFactory from "debug"

import { Notifier } from "./notifier"
import { Key, Patch, Target } from "./target"
import { ValueTarget } from "./value-target"

const debug = debugFactory("wson-diff:notifier-target")

export class NotifierTarget implements Target {

  public vt: ValueTarget
  public notifiers: Notifier[]
  public depths: (number | null)[]

  constructor(vt: ValueTarget, notifiers: Notifier[]) {
    this.vt        = vt
    this.notifiers = notifiers
    const { current } = vt
    const depths: (number | null)[] = []
    for (let ndx = 0; ndx < notifiers.length; ndx++) {
      const notifier = notifiers[ndx]
      depths[ndx] = notifier.checkedBudge(0, null, current) === false
        ? 0 // assign root
        : null
    }
    this.depths = depths
  }

  public get(up: number) { return undefined }

  public budge(up: number, key: Key) {
    const { vt } = this
    const { depths } = this
    const { stack } = vt
    const { current } = vt
    const stackLen = stack.length
    const newLen = stackLen - up
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      const notifier = this.notifiers[ndx]
      let notifyDepth = depths[ndx]
      let notifyUp
      if (up > 0) {
        if (notifyDepth != null) {
          notifyUp = notifyDepth - newLen
          if (notifyUp > 0) {
            const notifyValue = notifyDepth === stackLen
              ? current
              : stack[notifyDepth]
            notifier.assign(null, notifyValue)
            notifyDepth = null
          } else {
            notifyUp = 0
          }
        } else {
          notifyUp = up
        }
      } else {
        notifyUp = 0
      }
      debug("budge: notifyUp=%o", notifyUp)
      if (key != null) {
        if (notifyDepth == null) {
          if (false === notifier.checkedBudge(notifyUp, key, current)) {
            notifyDepth = newLen + 1
          }
        }
      } else if (notifyUp > 0) {
        notifier.checkedBudge(notifyUp, null, current)
      }
      debug("budge: ->notifyDepth=%o", notifyDepth)
      depths[ndx] = notifyDepth
    }
  }

  public unset(key: string) {
    const { depths } = this
    const { current } = this.vt
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      const notifier = this.notifiers[ndx]
      if (depths[ndx] == null) {
        notifier.unset(key, current)
      }
    }
  }

  public assign(key: string | null, value: any) {
    const { depths } = this
    const { current } = this.vt
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      const notifier = this.notifiers[ndx]
      if (depths[ndx] == null) {
        notifier.assign(key, value, current)
      }
    }
  }

  public delete(idx: number, len: number) {
    const { depths } = this
    const { current } = this.vt
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      const notifier = this.notifiers[ndx]
      if (depths[ndx] == null) {
        notifier.delete(idx, len, current)
      }
    }
  }

  public move(srcIdx: number, dstIdx: number, len: number, reverse: boolean) {
    const { depths } = this
    const { current } = this.vt
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      const notifier = this.notifiers[ndx]
      if (depths[ndx] == null) {
        notifier.move(srcIdx, dstIdx, len, reverse, current)
      }
    }
  }

  public insert(idx: number, values: any[]) {
    const { depths } = this
    const { current } = this.vt
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      const notifier = this.notifiers[ndx]
      if (depths[ndx] == null) {
        notifier.insert(idx, values, current)
      }
    }
  }

  public replace(idx: number, values: any[]) {
    const { depths } = this
    const { current } = this.vt
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      const notifier = this.notifiers[ndx]
      if (depths[ndx] == null) {
        notifier.replace(idx, values, current)
      }
    }
  }

  public substitute(patches: Patch[]) {
    const { depths } = this
    const { current } = this.vt
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      const notifier = this.notifiers[ndx]
      if (depths[ndx] == null) {
        notifier.substitute(patches, current)
      }
    }
  }

  public done() {
    const { depths } = this
    const { current } = this.vt
    const { stack } = this.vt
    debug("done: stack=%o current=%o depths=%o", stack, current, depths)
    const stackLen = stack.length
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      const notifier = this.notifiers[ndx]
      const notifyDepth = depths[ndx]
      if (notifyDepth != null) {
        const notifyValue = notifyDepth === stackLen
          ? current
          : stack[notifyDepth]
        debug("done: ndx=%o value=%o", ndx, notifyValue)
        notifier.assign(null, notifyValue)
      }
    }
  }
}
