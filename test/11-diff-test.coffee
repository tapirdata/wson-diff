'use strict'

_ = require 'lodash'
debug = require('debug') 'wson-diff:test'

wsonDiff = require '../src/'

chai = require 'chai'
expect = chai.expect

setup = require './fixtures/setups'
items = require './fixtures/diff-items'


try
  util = require 'util'
catch
  util = null

saveRepr = (x) ->
  if util
    util.inspect x, depth: null
  else
    try
      JSON.stringify x
    catch
      String x


for setup in require './fixtures/setups'
  describe setup.name, ->
    wDiff = wsonDiff setup.options
    describe 'diff', ->
      for item in items
        do (item) ->
          differ = wDiff.createDiffer()
          patcher = wDiff.createPatcher()
          delta = differ.diff item.source, item.dest
          debug 'diff: source=%o, dest=%o, delta=%o', item.source, item.dest, delta
          if _.has item, 'delta'
            it "should diff #{saveRepr item.source} to #{saveRepr item.dest} with #{saveRepr item.delta}.", ->
              expect(delta).to.be.equal item.delta
          if delta? and not item.noPatch
            source = _.cloneDeep item.source
            dest = patcher.patch source, delta
            it "should patch #{saveRepr item.source} with '#{delta}' to #{saveRepr item.dest}.", ->
              expect(dest).to.be.deep.equal item.dest




