import debugFactory = require("debug")
const debug = debugFactory("wson-diff:test")
import _ = require("lodash")
import { expect } from "chai"

import { Key, Notifier, Patch } from "../src"
import wsonDiff from "../src/"
import { saveRepr } from "./fixtures/helpers"
import items from "./fixtures/notify-items"
import setups from "./fixtures/setups"

class MyNotifier implements Notifier {

  public budgeTest: (top: any) => boolean
  public nfys: any[]
  public keyStack: any[]

  constructor(budgeTest: (top: any) => boolean) {
    this.budgeTest = budgeTest
    this.nfys = []
    this.keyStack = []
  }

  public checkedBudge(up: number, key: Key) {
    // console.log 'checkedBudge', up, key
    const { keyStack } = this
    if (up > 0) {
      keyStack.splice(keyStack.length - up)
    }
    if (key != null) {
      keyStack.push(key)
    }
    return this.budgeTest.apply(this, _(keyStack).reverse().value())
  }

  public fullPath(key?: Key) {
    const path = this.keyStack
    if (key != null) {
      return path.concat([key])
    } else {
      return _.clone(path)
    }
  }

  public unset(key: string) {
    return this.nfys.push(["unset", this.fullPath(key)])
  }

  public assign(key: string | null, value: any) {
    return this.nfys.push(["assign", this.fullPath(key), value])
  }

  public delete(idx: number, len: number) {
    return this.nfys.push(["delete", this.fullPath(), idx, len])
  }

  public move(srcIdx: number, dstIdx: number, len: number, reverse: boolean) {
    return this.nfys.push(["move", this.fullPath(), srcIdx, dstIdx, len, reverse])
  }

  public insert(idx: number, values: any[]) {
    return this.nfys.push(["insert", this.fullPath(), idx, values])
  }

  public replace(idx: number, values: any[]) {
    return this.nfys.push(["replace", this.fullPath(), idx, values])
  }

  public substitute(patches: Patch[]) {
    return this.nfys.push(["substitute", this.fullPath(), patches])
  }
}

for (const setup of setups) {
  describe(setup.name, () => {
    const wdiff = wsonDiff(setup.options)
    describe("notify", () => {
      for (const item of items) {
        debug("patch: have=%o, delta=%o", item.have, item.delta)
        const patcher = wdiff.createPatcher(item.patchOptions)
        const budgeTest0 = item.budgeTest0 || ( () => true )
        const notifier0 = new MyNotifier(budgeTest0)
        let notifier1: MyNotifier
        let notifiers: MyNotifier | MyNotifier[]
        if (item.budgeTest1 != null) {
          notifier1 = new MyNotifier(item.budgeTest1)
          notifiers = [notifier0, notifier1]
        } else {
          notifiers = notifier0
        }
        describe(item.description, () => {
          describe(`patch ${saveRepr(item.have)} with '${item.delta}'`, () => {
            patcher.patch(item.have, item.delta, notifiers)
            it(`should notify ${saveRepr(item.nfys0)}.`, () => expect(notifier0.nfys).to.be.deep.equal(item.nfys0),
            )
            if (item.budgeTest1 != null) {
              it(`should also notify ${saveRepr(item.nfys1)}.`,
                () => expect(notifier1.nfys).to.be.deep.equal(item.nfys1),
              )
            }
          })
        })
      }
    })
  })
}
