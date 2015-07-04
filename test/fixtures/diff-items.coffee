module.exports = [
  {
    description: 'same number'
    have: 42
    wish: 42
    delta: null
  }
  {
    description: 'changes number'
    have: 43
    wish: 42
    delta: '#42'
  }
  {
    description: 'object to number'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: 42
    delta: '#42'
  }
  {
    description: 'number to obeject'
    have: 42
    wish: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: '{bar:{a:alice|b:bob}|foo:{a:alice|b:bob}}'
  }
  {
    description: 'array to object'
    have: []
    wish: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: '{bar:{a:alice|b:bob}|foo:{a:alice|b:bob}}'
  }
  {
    description: 'object to array'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: []
    delta: '[]'
  }
  {
    description: 'same object'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: null
  }
  {
    description: 'object changed single'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo|b:bobby'
  }
  {
    description: 'object changed multi'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}, bar: {a: 'alice', b: 'bobby'}}
    delta: '|bar|b:bobby|foo|b:bobby'
  }
  {
    description: 'object changed collected multi'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alf', b: 'bobby'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo{a:alf|b:bobby}'
  }
  {
    description: 'object changed whole sub'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bob'}, bar: 'BAR'}
    delta: '|bar:BAR'
  }
  # with del
  {
    description: 'object del and replace'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}}
    delta: '|[-bar]foo|b:bobby'
  }
  {
    description: 'object multi del and replace'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}}
    delta: '|[-bar|baz]foo|b:bobby'
  }
  {
    description: 'object del and multi replace'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}, baz: {a: 'alf', b: 'bob'}}
    delta: '|[-bar]baz|a:alf|foo|b:bobby'
  }
  {
    description: 'object del and multi collected replace'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alf', c: 'chris'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo[-b]{a:alf|c:chris}'
  }
  {
    description: 'object multi del and single replace '
    have: {foo: {a: 'alice', b: 'bob', c: 'chris'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alf'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo[-b|c]a:alf'
  }
  {
    description: 'no change'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdefghijkl'.split ''
    delta: null
  }
  {
    description: 'multi deletes'
    have: 'abcdefghijkl'.split ''
    wish: 'abdefghkl'.split ''
    delta: '|[-8~2|2]'
  }
  {
    description: 'single forward move'
    have: 'abcdefghijkl'.split ''
    wish: 'abdefcghijkl'.split ''
    delta: '|[!2@5]'
  }
  {
    description: 'single backward move'
    have: 'abcdefghijkl'.split ''
    wish: 'abcidefghjkl'.split ''
    delta: '|[!8@3]'
  }
  {
    description: 'double block forward move '
    have: 'abcdefghijkl'.split ''
    wish: 'abefgcdhijkl'.split ''
    # delta: '|[!2@5]'
  }
  {
    description: 'double isolated forward move'
    have: 'abcdefghijkl'.split ''
    wish: 'abdfghcijekl'.split ''
    # delta: '|[!2@5]'
  }
  {
    description: 'double block backward move'
    have: 'abcdefghijkl'.split ''
    wish: 'abcijdefghkl'.split ''
    # delta: '|[!8@3]'
  }
  {
    description: 'double isolated backward move'
    have: 'abcdefghijkl'.split ''
    wish: 'abcidkefghjl'.split ''
    # delta: '|[!8@3]'
  }
  {
    description: 'double block forward exchange move'
    have: 'abcdefghijkl'.split ''
    wish: 'abefgdchijkl'.split ''
    # delta: '|[!2@5]'
  }
  {
    description: 'double block backward exchange move'
    have: 'abcdefghijkl'.split ''
    wish: 'abjicdefghkl'.split ''
  }
  {
    description: 'exchange move'
    have: 'abcdefghijkl'.split ''
    wish: 'abciefghdjkl'.split ''
  }
  {
    description: 'block exchange'
    have: 'abcdefghijkl'.split ''
    wish: 'abijkfghcdel'.split ''
  }
  {
    description: 'multi exchange #1'
    have: 'abcdefghijkl'.split ''
    wish: 'abefjgckldhi'.split ''
  }
  {
    description: 'multi exchange #2'
    have: 'abcdefghijkl'.split ''
    wish: 'jgdhiabecklf'.split ''
  }
  {
    description: 'backward split delete'
    have: 'abcdefghijkl'.split ''
    wish: 'abicdefkl'.split ''
  }
  {
    description: 'reverse'
    have: 'abcdefghijkl'.split ''
    wish: 'lkjihgfedcba'.split ''
  }
  {
    description: 'forward split delete'
    have: 'abcdefghijkl'.split ''
    wish: 'abghijkle'.split ''
  }
]

