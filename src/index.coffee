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
    if not options.stringEdge?
      options.stringEdge = 16
    @options = options

  createPatcher: (options) ->
    options or= {}
    new patch.Patcher @, options

  createDiffer: (options) ->
    options or= {}
    new diff.Differ @, options

  diff: (have, wish, options) ->
    differ = @createDiffer options
    differ.diff have, wish

  patch: (have, delta, options) ->
    patcher = @createPatcher options
    patcher.patch have, delta


factory = (options) ->
  new WsonDiff options

factory.PatchError = patch.PatchError

module.exports = factory









