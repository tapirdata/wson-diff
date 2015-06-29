module.exports = [
  {
    have: 42
    wish: 42
    delta: null
  }
  {
    have: 43
    wish: 42
    delta: '#42'
  }
  {
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: 42
    delta: '#42'
  }
  {
    have: 42
    wish: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: '{bar:{a:alice|b:bob}|foo:{a:alice|b:bob}}'
  }
  {
    have: []
    wish: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: '{bar:{a:alice|b:bob}|foo:{a:alice|b:bob}}'
  }
  {
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: []
    delta: '[]'
  }
  {
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: null
  }
  {
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo|b:bobby'
  }
  {
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}, bar: {a: 'alice', b: 'bobby'}}
    delta: '|bar|b:bobby|foo|b:bobby'
  }
  {
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alf', b: 'bobby'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo{a:alf|b:bobby}'
  }
  {
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bob'}, bar: 'BAR'}
    delta: '|bar:BAR'
  }
  # with del
  {
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}}
    delta: '|[-bar]foo|b:bobby'
  }
  {
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}}
    delta: '|[-bar|baz]foo|b:bobby'
  }
  {
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}, baz: {a: 'alf', b: 'bob'}}
    delta: '|[-bar]baz|a:alf|foo|b:bobby'
  }
  {
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alf', c: 'chris'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo[-b]{a:alf|c:chris}'
  }
  {
    have: {foo: {a: 'alice', b: 'bob', c: 'chris'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alf'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo[-b|c]a:alf'
  }
  {
    have: 'abcdefghijkl'.split ''
    wish: 'abcdefghijkl'.split ''
    delta: null
  }
  {
    # deletes
    have: 'abcdefghijkl'.split ''
    wish: 'abdefghkl'.split ''
    delta: '|[-8~2|2]'
  }
  {
    # single forward move 
    have: 'abcdefghijkl'.split ''
    wish: 'abdefcghijkl'.split ''
    delta: '|[!2@5]'
  }
  {
    # single backward move 
    have: 'abcdefghijkl'.split ''
    wish: 'abcidefghjkl'.split ''
    delta: '|[!8@3]'
  }
  {
    # double block forward move 
    have: 'abcdefghijkl'.split ''
    wish: 'abefgcdhijkl'.split ''
    # delta: '|[!2@5]'
  }
  {
    # double isolated forward move 
    have: 'abcdefghijkl'.split ''
    wish: 'abdfghcijekl'.split ''
    # delta: '|[!2@5]'
  }
  {
    # double block backward move 
    have: 'abcdefghijkl'.split ''
    wish: 'abcijdefghkl'.split ''
    # delta: '|[!8@3]'
  }
  {
    # double isolted backward move 
    have: 'abcdefghijkl'.split ''
    wish: 'abcidkefghjl'.split ''
    # delta: '|[!8@3]'
  }
  {
    # double block forward exchange move
    have: 'abcdefghijkl'.split ''
    wish: 'abefgdchijkl'.split ''
    # delta: '|[!2@5]'
  }
  {
    # double block backward exchange move
    have: 'abcdefghijkl'.split ''
    wish: 'abjicdefghkl'.split ''
  }
  {
    # exchange move
    have: 'abcdefghijkl'.split ''
    wish: 'abciefghdjkl'.split ''
  }
  {
    # block exchange
    have: 'abcdefghijkl'.split ''
    wish: 'abijkfghcdel'.split ''
  }
  {
    # block exchange permutate 
    have: 'abcdefghijkl'.split ''
    wish: 'abjikfghedcl'.split ''
  }
]

