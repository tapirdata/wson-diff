import { expect } from "chai"
import _ = require("lodash")

import wdiffFactory from "../src/"
import { saveRepr } from "./fixtures/helpers"
import items from "./fixtures/patch-items"
import setups from "./fixtures/setups"

for (const setup of setups) {
  describe(setup.name, () => {
    const wdiff = wdiffFactory(setup.options)
    return describe("patch", () => {
      for (const item of items) {
        const patcher = wdiff.createPatcher(item.patchOptions)
        const have = _.cloneDeep(item.have)
        if (item.failPos != null) {
          return it(`should fail to patch ${saveRepr(have)} with '${item.delta}' @${item.failPos}.`, () => {
            let e: any
            try {
              patcher.patch(have, item.delta)
            } catch (e0) {
              e = e0
            }
            expect(e).to.be.instanceof(Error)
            expect(e.name).to.be.equal("PatchError")
            expect(e.pos).to.be.equal(item.failPos)
            if (item.failCause) {
              return expect(e.cause).to.match(item.failCause)
            }
          },
          )
        } else {
          return it(`should patch ${saveRepr(have)} with '${item.delta}' to ${saveRepr(item.wish)}.`,
            () => expect(patcher.patch(have, item.delta)).to.be.deep.equal(item.wish),
          )
        }
      }
    })
  })
}
