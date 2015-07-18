debug = require('debug') 'wson-diff:idxer'
_ = require 'lodash'

class Idxer

  constructor: (@state, vals, useHave, allString) ->
    if allString
      for val, idx in vals
        if not _.isString val
          allString = false
          break
      keys = vals
    if not allString
      keys = new Array vals.length
      for val, idx in vals
        key = @state.stringify val, useHave
        keys[idx] = key
      debug 'keys=%o', keys  
    @keys = keys
    @allString = allString

  getItem: (idx) ->
    key = @keys[idx]
    if @allString
      @state.stringify key
    else
      key


module.exports = Idxer
