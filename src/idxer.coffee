_ = require 'lodash'

class Idxer

  constructor: (@state, vals, allString=true) ->
    # console.log 'Idxer allString=%s', allString
    if allString
      # uses = {}
      for val, idx in vals
        if not _.isString val
          allString = false
          break
        # use = uses[val]
        # if not use?
        #   uses[val] = use = []
        # use.push idx
      keys = vals
    if not allString
      # uses = {}
      keys = new Array vals.length
      for val, idx in vals
        key = @state.stringify val
        keys[idx] = key
        # use = uses[key]
        # if not use?
        #   uses[key] = use = []
        # use.push idx
    @keys = keys
    @allString = allString

  getItem: (idx) ->
    key = @keys[idx]
    if @allString
      @state.stringify key
    else
      key



module.exports = Idxer
