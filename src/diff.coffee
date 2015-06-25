_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'

errors = require './errors'


class Differ

  constructor: (@wsonDiff) ->

  diff: (@src, @dst) ->



exports.Differ = Differ
