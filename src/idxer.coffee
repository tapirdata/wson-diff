_ = require 'lodash'

class Idxer 
  
  constructor: (@wsonDiff, src, allString=true) ->
    # console.log 'Idxer allString=%s', allString 
    if allString
      # uses = {}
      for val, idx in src
        if not _.isString val
          allString = false
          break
        # use = uses[val]
        # if not use?
        #   uses[val] = use = []
        # use.push idx
      keys = src 
    if not allString    
      WSON = @wsonDiff.WSON
      # uses = {}
      keys = new Array src.length
      for val, idx in src
        key = WSON.stringify val
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
      @wsonDiff.WSON.escape key
    else
      key



module.exports = Idxer
