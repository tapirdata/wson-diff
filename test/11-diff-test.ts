import { expect } from "chai"
import debugFactory = require("debug")
import _ = require("lodash")

import wsonDiff from "../src/"
import items from "./fixtures/diff-items"
import { saveRepr } from "./fixtures/helpers"
import setups from "./fixtures/setups"

const debug = debugFactory("wson-diff:test")

for (const setup of setups) {
  describe(setup.name, () => {
    const wdiff = wsonDiff(setup.options)
    return describe("diff", () => {
      for (const item of items) {
        const differ = wdiff.createDiffer(item.diffOptions)
        const patcher = wdiff.createPatcher(item.patchOptions)
        const delta = differ.diff(item.have, item.wish)
        debug("diff: have=%o, wish=%o, delta=%o", item.have, item.wish, delta)
        return describe(item.description, () => {
          if (item.hasOwnProperty("delta")) {
            it(`should diff ${saveRepr(item.have)} to ${saveRepr(item.wish)} with ${saveRepr(item.delta)}.`,
              () => expect(delta).to.be.equal(item.delta),
            )
          }
          if (delta != null) {
            if (!item.noPatch) {
              let have
              if (item.wsonClone) {
                have = wdiff.WSON.parse(wdiff.WSON.stringify(item.have)) // do a real deep clone (with constructors)
              } else {
                have = _.cloneDeep(item.have)
              }
              const got = patcher.patch(have, delta)
              return it(`should patch ${saveRepr(item.have)} with '${delta}' to ${saveRepr(item.wish)}.`,
                () => expect(got).to.be.deep.equal(item.wish),
              )
            }
          } else {
            it("should get null delta for no change only",
              () => expect(item.have).to.be.deep.equal(item.wish),
            )
          }
        })
      }
    })
  })
}
