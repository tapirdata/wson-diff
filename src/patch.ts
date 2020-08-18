// tslint:disable:max-classes-per-file
import debugFactory = require("debug")
const debug = debugFactory("wson-diff:patch")
import { Wson } from "wson"

import { WsonDiffError } from "./errors"
import { Notifier } from "./notifier"
import { NotifierTarget } from "./notifier-target"
import { Key, Patch, Target } from "./target"
import { ValueTarget } from "./value-target"
import { WsonDiff } from "./wson-diff"

export type Delta = string | null | undefined

class PrePatchError extends WsonDiffError {

  public name: string
  public cause: string

  constructor(cause?: any) {
    super()
    this.name = "PrePatchError"
    this.cause = cause
  }
}

export class PatchError extends WsonDiffError {

  public name: string
  public cause: string
  public delta: string
  public pos: number

  constructor(delta: string, pos: number, cause: any) {
    super()
    this.name = "PatchError"
    this.delta = delta
    this.pos = pos
    this.cause = cause
    if (this.pos == null) {
      this.pos = this.delta.length
    }
    let char: string
    if (!this.cause) {
      if (this.pos >= this.delta.length) {
        char = "end"
      } else {
        char = `'${this.delta[this.pos]}'`
      }
      this.cause = `unexpected ${char}`
    }
    this.message = `${this.cause} at '${this.delta.slice(0, this.pos)}^${this.delta.slice(this.pos)}'`
  }
}

const reIndex = /^\d+$/
const reRange = /^(\d+)(\+(\d+))?$/
const reMove = /^(\d+)([+|-](\d+))?@(\d+)$/
const reSubst = /^(\d+)([+|-](\d+))?(=(.+))?$/

const TI_UNKNOW = 0
const TI_STRING = 20
const TI_ARRAY  = 24
const TI_OBJECT = 32

interface Stage {
  [key: string]: any
}

class State {

  public WSON: Wson
  public delta: Delta
  public pos: number
  public target: Target
  public stage: Stage
  public rawNext: boolean
  public skipNext: number
  public scopeTi: number | null
  public currentTi: number | null
  public pendingKey: Key
  public pendingUp: number
  public targetDepth: number
  public scopeDepth: number
  public scopeStack: any[]
  public haveUp: any // TODO
  public assignValues: any[] | null
  public replaceValues: any[] | null
  public insertKey: number
  public insertValues: any[]
  public substituteValues: Patch[]

  constructor(WSON: Wson, delta: Delta, pos: number, target: Target, stage: Stage) {
    this.WSON = WSON
    this.delta = delta
    this.pos = pos
    this.rawNext = false
    this.skipNext = 0
    this.target = target
    this.stage = stage
    this.scopeTi = null
    this.currentTi = null
    this.pendingKey = null
    this.pendingUp = 0
    this.targetDepth = 0
    this.scopeDepth = 0
    this.scopeStack  = []
    this.assignValues = null
    this.replaceValues = null
    this.insertKey = 0
    this.insertValues = []
    this.substituteValues = []
  }

  public getCurrentTi() {
    let ti = this.currentTi
    if (ti == null) {
      const { target } = this
      if (target.get != null) {
        const value = target.get(0)
        ti = this.WSON.getTypeid(value)
        this.currentTi = ti
        if (this.haveUp === 0) {
          this.scopeTi = ti
        }
      } else {
        ti = TI_UNKNOW
      }
    }
    return ti
  }

  public budgePending(withKey: boolean) {
    debug("budgePending withKey=%o pendingUp=%o pendingKey=%o", withKey, this.pendingUp, this.pendingKey)
    if (withKey && (this.pendingKey != null)) {
      this.target.budge(this.pendingUp, this.pendingKey)
      this.targetDepth -= this.pendingUp - 1
      this.pendingUp = 0
      this.currentTi = null
      this.pendingKey = null
    } else if (this.pendingUp > 0) {
      this.target.budge(this.pendingUp, null)
      this.targetDepth -= this.pendingUp
      this.pendingUp = 0
    }
  }

  public resetPath() {
    debug("resetPath targetDepth=%o scopeDepth=%o", this.targetDepth, this.scopeDepth)
    this.pendingUp = this.targetDepth - this.scopeDepth
    this.pendingKey = null
    this.currentTi = this.scopeTi
  }

  public enterObjectKey(key: string) {
    this.budgePending(true)
    debug("enterObjectKey key=%o", key)
    const ti = this.getCurrentTi()
    if (ti !== TI_UNKNOW && ti !== TI_OBJECT) {
      if (ti === TI_ARRAY) {
        throw new PrePatchError(`can't index array ${this.target.get()} with object index ${key}`)
      } else {
        throw new PrePatchError(`can't index scalar ${this.target.get()}`)
      }
    }
    this.pendingKey = key
  }

  public enterArrayKey(skey: string) {
    this.budgePending(true)
    debug("enterArrayKey skey=%o", skey)
    const ti = this.getCurrentTi()
    if (!reIndex.test(skey)) {
      throw new PrePatchError(`non-numeric array index ${skey} for ${this.target.get()}`)
    }
    const key = Number(skey)
    if (ti !== TI_UNKNOW && ti !== TI_ARRAY) {
      if (ti === TI_OBJECT) {
        throw new PrePatchError(`can't index object ${this.target.get()} with array index ${key}`)
      } else {
        throw new PrePatchError(`can't index scalar ${this.target.get()}`)
      }
    }
    this.pendingKey = key
  }

  public pushScope(nextStage: Stage) {
    debug("pushScope scopeDepth=%o @targetDepth=%o stage=%o",
      this.scopeDepth, this.targetDepth, this.stage ? this.stage.name : undefined)
    this.scopeStack.push([this.scopeDepth, this.scopeTi, nextStage])
    this.scopeDepth = this.targetDepth
  }

  public popScope() {
    if (!this.stage.canPop) {
      throw new PrePatchError()
    }
    const { scopeStack } = this
    debug("popScope scopeStack=%o", scopeStack)
    if (scopeStack.length === 0) {
      throw new PrePatchError()
    }
    [this.scopeDepth, this.scopeTi, this.stage] = scopeStack.pop()
  }

  public assignValue(value: any) {
    this.budgePending(false)
    try {
      this.target.assign(this.pendingKey as string, value)
    } catch (e) {
      throw new PrePatchError(e)
    }
    this.assignValues = null
  }

  public startReplace() {
    return this.replaceValues = []
  }

  public addReplace(value: any) {
    return this.replaceValues!.push(value)
  }

  public commitReplace() {
    debug("commitReplace pendingKey=%o replaceValues=%o", this.pendingKey, this.replaceValues)
    if (this.replaceValues != null) {
      this.budgePending(false)
      this.target.replace(this.pendingKey as number, this.replaceValues)
      this.replaceValues = null
    }
  }

  public doUnset(key: Key) {
    debug("doUnset key=%o", key)
    this.budgePending(false)
    this.target.unset(key as string)
  }

  public doDelete(skey: string) {
    debug("doDelete skey=%o", skey)
    this.budgePending(true)
    const m = reRange.exec(skey)
    if (m == null) {
      throw new PrePatchError(`ill-formed range '${skey}'`)
    }
    const idx = Number(m[1])
    const len = (m[3] != null) ? Number(m[3]) + 1 : 1
    this.target.delete(idx, len)
  }

  public continueModify() {
    const c = (this.delta as string)[++this.pos]
    const ti = this.getCurrentTi()
    debug("coninueModify c=%o", c)
    let stage: Stage
    let expectedTi
    switch (c) {
      case "=":
        expectedTi = TI_OBJECT
        stage = stages.assignBegin
        break
      case "-":
        expectedTi = TI_OBJECT
        stage = stages.unsetBegin
        break
      case "d":
        expectedTi = TI_ARRAY
        stage = stages.deleteBegin
        break
      case "i":
        expectedTi = TI_ARRAY
        stage = stages.insertBegin
        break
      case "m":
        expectedTi = TI_ARRAY
        stage = stages.moveBegin
        break
      case "r":
        expectedTi = TI_ARRAY
        stage = stages.replaceBegin
        break
      case "s":
        expectedTi = TI_STRING
        stage = stages.substituteBegin
        break
      default:
        throw new PrePatchError()
    }
    if (ti !== TI_UNKNOW && ti !== expectedTi) {
      const expectedName = (() => { switch (expectedTi) {
        case TI_ARRAY:
          return "array"
        case TI_OBJECT:
          return "object"
        case TI_STRING:
          return "string"
        default:
          return "scalar"
      } })()
      throw new PatchError(this.delta as string, this.pos,
        `can't patch ${this.target.get()} with ${expectedName} modifier`)
    }
    this.stage = stage
    this.rawNext = true
    this.skipNext = 1
  }

  public startModify(nextStage: Stage) {
    debug("startModify nextStage=%o", nextStage.name)
    this.budgePending(true)
    this.pushScope(nextStage)
    this.continueModify()
  }

  public startInsert(skey: string) {
    if (!reIndex.test(skey)) {
      throw new PrePatchError(
        `non-numeric index ${skey} for array ${this.target.get ? this.target.get() : null}`)
    }
    this.insertKey = Number(skey)
    this.insertValues = []
  }

  public addInsert(value: any) {
    return this.insertValues.push(value)
  }

  public commitInsert() {
    debug("commitInsert insertKey=%o, insertValues=%o", this.insertKey, this.insertValues)
    this.target.insert(this.insertKey, this.insertValues)
  }

  public doMove(skey: string) {
    debug("doMove skey=%o", skey)
    const m = reMove.exec(skey)
    if (m == null) {
      throw new PrePatchError(`ill-formed move '${skey}'`)
    }
    const srcKey = Number(m[1])
    let len: number
    let reverse: boolean
    if (m[3] != null) {
      len = Number(m[3]) + 1
      reverse = m[2][0] === "-"
    } else {
      len = 1
      reverse = false
    }
    const dstKey = Number(m[4])

    debug("doMove srcKey=%o dstKey=%o len=%o reverse=%o", srcKey, dstKey, len, reverse)
    this.target.move(srcKey, dstKey, len, reverse)
  }

  public startSubstitute(skey: string) {
    this.substituteValues = []
    this.addSubstitute(skey)
  }

  public addSubstitute(skey: string) {
    const m = reSubst.exec(skey)
    if (m == null) {
      throw new PrePatchError(
        `invalid substitution ${skey} for string ${this.target.get ? this.target.get() : undefined}`)
    }
    const ofs = Number(m[1])
    let lenDiff: number
    let str: string
    if (m[3] != null) {
      lenDiff = Number(m[3])
      if (m[2][0] === "-") {
        lenDiff = -lenDiff
      }
    } else {
      lenDiff = 0
    }
    if (m[5] != null) {
      str = m[5]
    } else {
      str = ""
    }
    return this.substituteValues.push([ofs, lenDiff, str])
  }

  public commitSubstitute() {
    debug("commitSubstitute insertValues=%o", this.substituteValues)
    this.target.substitute(this.substituteValues)
  }
}

const stages: {[key: string]: Stage} = {
  assignBegin: {
    value(value: any) {
      this.enterObjectKey(value)
      this.stage = stages.assignHasKey
    },
    ["#"](value: any) {
      this.enterObjectKey("")
      this.stage = stages.assignHasKey
    },
  },
  assignHasKey: {
    ["|"]() {
      this.stage = stages.assignBegin
    },
    [":"]() {
      this.rawNext = false
      this.stage = stages.assignHasColon
    },
    ["["]() {
      this.startModify(stages.assignHasModify)
    },
  },
  assignHasColon: {
    value(value: any) {
      this.assignValue(value)
      this.stage = stages.assignHasValue
    },
  },
  assignHasValue: {
    ["|"]() {
      this.resetPath()
      this.stage = stages.assignBegin
    },
    ["]"]() {
      if (this.scopeStack.length === 0) {
        throw new PrePatchError()
      }
      this.stage = stages.modifyEnd
    },
    end() {
      if (this.scopeStack.length > 0) {
        throw new PrePatchError()
      }
    },
  },
  assignHasModify: {
    ["|"]() {
      this.resetPath()
      this.stage = stages.assignBegin
    },
    ["]"]() {
      if (this.scopeStack.length === 0) {
        throw new PrePatchError()
      }
      this.stage = stages.modifyEnd
    },
    end() {
      if (this.scopeStack.length > 0) {
        throw new PrePatchError()
      }
    },
  },

  replaceBegin: {
    value(value: any) {
      this.enterArrayKey(value)
      this.stage = stages.replaceHasKey
    },
  },
  replaceNextKey: {
    value(value: any) {
      this.enterObjectKey(value)
      this.stage = stages.replaceHasKey
    },
  },
  replaceHasKey: {
    ["|"]() {
      this.stage = stages.replaceNextKey
    },
    [":"]() {
      this.rawNext = false
      this.stage = stages.replaceHasColon
      this.startReplace()
    },
    ["["]() {
      this.startModify(stages.replaceHasModify)
    },
  },
  replaceHasColon: {
    value(value: any) {
      this.addReplace(value)
      this.stage = stages.replaceHasValue
    },
  },
  replaceHasValue: {
    [":"]() {
      this.rawNext = false
      this.stage = stages.replaceHasColon
    },
    ["|"]() {
      this.commitReplace()
      this.resetPath()
      this.stage = stages.replaceBegin
    },
    ["]"]() {
      this.commitReplace()
      this.stage = stages.modifyEnd
    },
  },
  replaceHasModify: {
    ["|"]() {
      this.commitReplace()
      this.resetPath()
      this.stage = stages.replaceBegin
    },
    ["]"]() {
      this.commitReplace()
      this.stage = stages.modifyEnd
    },
  },

  unsetBegin: {
    value(value: any) {
      this.doUnset(value)
      this.stage = stages.unsetHas
    },
    ["#"]() {
      this.doUnset("")
      this.stage = stages.unsetHas
    },
  },
  unsetHas: {
    ["]"]() {
      this.stage = stages.modifyEnd
    },
    ["|"]() {
      this.stage = stages.unsetBegin
    },
  },

  deleteBegin: {
    value(value: any) {
      this.doDelete(value)
      this.stage = stages.deleteHas
    },
    ["#"]() {
      this.doDelete("")
      this.stage = stages.deleteHas
    },
  },
  deleteHas: {
    ["]"]() {
      this.stage = stages.modifyEnd
    },
    ["|"]() {
      this.stage = stages.deleteBegin
    },
  },

  insertBegin: {
    value(value: any) {
      this.startInsert(value)
      this.stage = stages.insertHasKey
    },
  },
  insertHasKey: {
    [":"]() {
      this.stage = stages.insertHasColon
      this.rawNext = false
    },
  },
  insertHasColon: {
    value(value: any) {
      this.addInsert(value)
      this.stage = stages.insertHasValue
    },
  },
  insertHasValue: {
    [":"]() {
      this.stage = stages.insertHasColon
      this.rawNext = false
    },
    ["|"]() {
      this.commitInsert()
      this.stage = stages.insertBegin
    },
    ["]"]() {
      this.commitInsert()
      this.stage = stages.modifyEnd
    },
  },

  moveBegin: {
    value(value: any) {
      this.doMove(value)
      this.stage = stages.moveHas
    },
  },
  moveHas: {
    ["]"]() {
      this.stage = stages.modifyEnd
    },
    ["|"]() {
      this.stage = stages.moveBegin
    },
  },

  substituteBegin: {
    value(value: any) {
      this.startSubstitute(value)
      this.stage = stages.substituteHas
    },
  },
  substituteHas: {
    ["]"]() {
      this.commitSubstitute()
      this.stage = stages.modifyEnd
    },
    ["|"]() {
      this.stage = stages.substituteNext
    },
  },
  substituteNext: {
    value(value: any) {
      this.addSubstitute(value)
      this.stage = stages.substituteHas
    },
  },

  modifyEnd: {
    canPop: true,
    ["["]() {
      this.resetPath()
      return this.continueModify()
    },
  },

  patchBegin: {
    value(value: any) {
      this.enterObjectKey(value)
      this.stage = stages.assignHasKey
    },
    ["#"](value: any) {
      this.enterObjectKey("")
      this.stage = stages.assignHasKey
    },
    ["["]() {
      this.startModify(stages.patchHasModify)
    },
  },

  patchHasModify: {
    value(value: any) {
      this.enterObjectKey(value)
      this.stage = stages.assignHasKey
    },
    ["#"](value: any) {
      this.enterObjectKey(value)
      this.stage = stages.assignHasKey
    },
    end() {
      if (this.scopeStack.length > 0) {
        throw new PrePatchError()
      }
    },
  },
}

{
  for (const name of Object.keys(stages)) {
    const stage = stages[name]
    stage.name = name
  }
}

export class Patcher {

  public wdiff: WsonDiff

  constructor(wdiff: WsonDiff, options: any) {
    this.wdiff = wdiff
  }

  public patchTarget(target: Target, delta: Delta) {
    debug("patch: target=%o, delta=%o", target, delta)
    if (delta == null) {
      return
    }
    let state: State
    try {
      let handler
      if (delta[0] !== "|") {
        const value = this.wdiff.WSON.parse(delta)
        target.assign(null, value)
      } else {
        state = new State(this.wdiff.WSON, delta, 1, target, stages.patchBegin)
        this.wdiff.WSON.parsePartial(delta, {
          howNext: [true, 1],
          cb(isValue: boolean, value: any, nextPos: number) {
            while (true) {
              const { stage } = state
              debug("patch: stage=%o, isValue=%o, value=%o, nextPos=%o", stage.name, isValue, value, nextPos)
              if (isValue) {
                handler = stage.value
              } else {
                handler = stage[value]
              }
              debug("patch: handler=%o", handler)
              if (handler) {
                break
              }
              state.popScope()
            }
            state.rawNext = true
            state.skipNext = 0
            handler.call(state, value, nextPos)
            debug("patch: pos=%o, rawNext=%o, skipNext=%o, stage.name=%o",
              state.pos, state.rawNext, state.skipNext, state.stage ? state.stage.name : undefined)
            state.pos = nextPos
            if (state.skipNext > 0) {
              state.pos += state.skipNext
              return [state.rawNext, state.skipNext]
            } else {
              return state.rawNext
            }
          },
          backrefCb: (target.get != null) ?
            (refIdx: number)  => target.get(refIdx)
          :
            null,
        },
        )

        state.pos = delta.length
        while (true) {
          debug("patch: done: stage=%o", state.stage.name)
          handler = state.stage.end
          if (handler) {
            break
          }
          state.popScope()
        }
        handler.call(state)
      }

      target.done()
      return

    } catch (error) {
      if (error.name === "PrePatchError") {
        throw new PatchError(delta, state!.pos, error.cause)
      } else if (error.name === "ParseError") {
        throw new PatchError(error.s, error.pos, error.cause)
      } else {
        throw error
      }
    }
  }

  public patch(value: any, delta: Delta, notifiers?: Notifier | Notifier[]) {
    const target = new ValueTarget(this.wdiff.WSON, value)

    if (notifiers != null) {
      if (!Array.isArray(notifiers)) {
        notifiers = [notifiers]
      }
      if (notifiers.length > 0) {
        target.setSubTarget(new NotifierTarget(target, notifiers))
      }
    }

    this.patchTarget(target, delta)

    target.setSubTarget(null)
    return target.getRoot()
  }
}
