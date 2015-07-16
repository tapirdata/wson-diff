
module.exports = [
  {
    description:  'plain delta'
    have:  null
    delta: 'foo'
    budgeTest: ->
    nfys: [
      ['assign', [], 'foo']
    ]
  }
  {
    description:  'deep delta detailed'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    delta: '|foo|a:eve'
    budgeTest: ->
    nfys: [
      ['assign', ['foo', 'a'], 'eve']
    ]
  }
  {
    description:  'deep delta till "foo"'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    delta: '|foo|a:eve'
    budgeTest: (top) ->
      top != 'foo'
    nfys: [
      ['assign', ['foo'], {a: 'eve', b: 'bob'}]
    ]
  }
  {
    description:  'deep delta till null'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    delta: '|foo|a:eve'
    budgeTest: (top) ->
      # console.log 'bt', [].splice arguments
      false
    nfys: [
      ['assign', [], {foo: {a: 'eve', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}]
    ]
  }
  {
    description:  'multi deep delta till foo'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    delta: '|bar|a:mallet|foo|a:eve'
    budgeTest: (top) ->
      top != 'foo' and top != 'bar'
    nfys: [
      ['assign', ['bar'], {a: 'mallet', b: 'bob'}]
      ['assign', ['foo'], {a: 'eve', b: 'bob'}]
    ]
  }
  {
    description:  'multi deep delta till null'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    delta: '|bar|a:mallet|foo|a:eve'
    budgeTest: (top) ->
      # console.log 'bt', [].splice arguments
      false
    nfys: [
      ['assign', [], {foo: {a: 'eve', b: 'bob'}, bar: {a: 'mallet', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}]
    ]
  }
]  

