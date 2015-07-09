'use strict'

_ = require 'lodash'
debug = require('debug') 'wson-diff:patch'
wson = require 'wson'

patch = require './patch'
diff = require './diff'

class WsonDiff

  constructor: (options) ->
    options or= {}
    WSON = options.WSON
    if not WSON?  
      WSON = wson options.wsonOptions
    @WSON = WSON  

  createPatcher: ->
    new patch.Patcher @

  createDiffer: ->
    new diff.Differ @


factory = (options) ->
  new WsonDiff options

factory.PatchError = patch.PatchError

module.exports = factory









