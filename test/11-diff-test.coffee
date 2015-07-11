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
          differ = wDiff.createDiffer item.diffOptions
          patcher = wDiff.createPatcher item.patchOptions
          delta = differ.diff item.have, item.wish
          debug 'diff: have=%o, wish=%o, delta=%o', item.have, item.wish, delta
          describe item.description, ->
            console.log 'item=', item
            if _.has item, 'delta'
              it "should diff #{saveRepr item.have} to #{saveRepr item.wish} with #{saveRepr item.delta}.", ->
                expect(delta).to.be.equal item.delta
            if delta?
              if not item.noPatch
                if item.wsonClone
                  have = wDiff.WSON.parse wDiff.WSON.stringify item.have # do a real deep clone (with constructors)
                else
                  have = _.cloneDeep item.have
                got = patcher.patch have, delta
                it "should patch #{saveRepr item.have} with '#{delta}' to #{saveRepr item.wish}.", ->
                  expect(got).to.be.deep.equal item.wish
            else
              it "should get null delta for no change only", ->
                expect(item.have).to.be.deep.equal item.wish




