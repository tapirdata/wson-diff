import util = require("util")

export function saveRepr(x: any) {
  try {
    return util.inspect(x, {depth: null})
  } catch (error0)  {
    try {
      return JSON.stringify(x)
    } catch (error1) {
      return String(x)
    }
  }
}
