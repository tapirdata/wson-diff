
module.exports = [
  {
    description:  'plain delta'
    have:  null
    delta: 'foo'
    budgeTest0: ->
    nfys0: [
      ['assign', [], 'foo']
    ]
  }
  {
    description:  'deep delta detailed'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    delta: '|foo|a:eve'
    budgeTest0: ->
    nfys0: [
      ['assign', ['foo', 'a'], 'eve']
    ]
  }
  {
    description:  'deep delta till "foo"'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    delta: '|foo|a:eve'
    budgeTest0: (top) -> top != 'foo'
    nfys0: [
      ['assign', ['foo'], {a: 'eve', b: 'bob'}]
    ]
  }
  {
    description:  'deep delta till null'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    delta: '|foo|a:eve'
    budgeTest0: (top) -> false
    nfys0: [
      ['assign', [], {foo: {a: 'eve', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}]
    ]
  }
  {
    description:  'multi deep delta till foo'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    delta: '|bar|a:mallet|foo|a:eve'
    budgeTest0: (top) -> top != 'foo' and top != 'bar'
    nfys0: [
      ['assign', ['bar'], {a: 'mallet', b: 'bob'}]
      ['assign', ['foo'], {a: 'eve', b: 'bob'}]
    ]
  }
  {
    description:  'multi deep delta till null'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    delta: '|bar|a:mallet|foo|a:eve'
    budgeTest0: (top) -> false
    nfys0: [
      ['assign', [], {foo: {a: 'eve', b: 'bob'}, bar: {a: 'mallet', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}]
    ]
  }
  {
    description:  'multi deep delta with two notifiers'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    delta: '|bar|a:mallet|foo|a:eve'
    budgeTest0: (top) -> top != 'foo' and top != 'bar'
    budgeTest1: (top) -> false
    nfys0: [
      ['assign', ['bar'], {a: 'mallet', b: 'bob'}]
      ['assign', ['foo'], {a: 'eve', b: 'bob'}]
    ]
    nfys1: [
      ['assign', [], {foo: {a: 'eve', b: 'bob'}, bar: {a: 'mallet', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}]
    ]
  }
]

