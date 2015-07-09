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
    description: 'block exchange move'
    have: 'abcdefghijkl'.split ''
    wish: 'abijkfghcdel'.split ''
  }
  {
    description: 'multi exchange move #1'
    have: 'abcdefghijkl'.split ''
    wish: 'abefjgckldhi'.split ''
  }
  {
    description: 'multi exchange move #2'
    have: 'abcdefghijkl'.split ''
    wish: 'jgdhiabecklf'.split ''
  }
  {
    description: 'reverse move'
    have: 'abcdefghijkl'.split ''
    wish: 'lkjihgfedcba'.split ''
  }
  {
    description: 'move with duplicates'
    have: 'abcabcde'.split ''
    wish: 'ababdcec'.split ''
  }
  {
    description: 'backward split delete'
    have: 'abcdefghijkl'.split ''
    wish: 'abicdefkl'.split ''
  }
  {
    description: 'forward split delete'
    have: 'abcdefghijkl'.split ''
    wish: 'abghijkle'.split ''
  }
  {
    description: 'multi delete & move'
    have: 'abcdefghijkl'.split ''
    wish: 'ajlefbc'.split ''
  }
  {
    description: 'single insert'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdXefghijkl'.split ''
  }
  {
    description: 'insert that needs quoting'
    have: 'a,b,c,d,e,f,g,h,i,j,k,l'.split ','
    wish: 'a,b,c,d,e,f,g,[],h,i,j,k,l'.split ','
  }
  {
    description: 'insert array'
    have: [['a'], ['c']]
    wish: [['a'], ['b'], ['c']]
  }
  {
    description: 'double block insert'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdXYefghijkl'.split ''
  }
  {
    description: 'double isolated insert'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdXefYghijkl'.split ''
  }
  {
    description: 'multiple insert'
    have: 'abcdefghijkl'.split ''
    wish: 'abcXYdefghiZUVjkl'.split ''
  }
  {
    description: 'move & insert'
    have: 'abcdefghijkl'.split ''
    wish: 'aXYldfghbciZUVjek'.split ''
  }
  {
    description: 'single replace'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdeFghijkl'.split ''
  }
  {
    description: 'double block replace'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdeFGhijkl'.split ''
  }
  {
    description: 'move & replace'
    have: 'abcdefghijkl'.split ''
    wish: 'abgcdeFHijkl'.split ''
  }
  {
    description: 'delete, move & replace'
    have: 'abcdefghijkl'.split ''
    wish: 'abjKdefhIl'.split ''
  }
  {
    description: 'move, insert & replace'
    have: 'abcdefghijkl'.split ''
    wish: 'jkaeFgbcDhilM'.split ''
  }
  {
    description: 'replace missing duplicates'
    have: 'abcabcde'.split ''
    wish: 'ababdccec'.split ''
  }
  {
    description: 'delete superfluous duplicates'
    have: 'abcabcde'.split ''
    wish: 'ababdce'.split ''
  }
  {
    description: 'total replace'
    have: 'abcdefghijkl'.split ''
    wish: 'ABCDEFGHIJKL'.split ''
  }
  {
    description: 'array of objects no change'
    have: [{a: 3}, {b: 4}, {c: 5}]
    wish: [{a: 3}, {b: 4}, {c: 5}]
  }
  {
    description: 'array of objects move'
    have: [{a: 3}, {b: 4}, {c: 5}]
    wish: [{a: 3}, {c: 5}, {b: 4}]
  }
  {
    description: 'array of objects insert'
    have: [{a: 3}, {b: 4}, {c: 5}]
    wish: [{a: 3}, {b: 4}, {x: 11}, {c: 5}]
  }
  {
    description: 'array of objects replace'
    have: [{a: 3}, {b: 4}, {c: 5}]
    wish: [{a: 3}, {b: 14}, {c: 5}]
  }
  {
    description: 'array of objects multi replace'
    have: [{a: 3}, {b: 4}, {c: 5}]
    wish: [{a: 13}, {b: 14}, {c: 15}]
  }
  {
    description: 'add circular reference'
    have: do -> x = foo: a: {y: 3}; x
    wish: do -> x = foo: a: {y: 3}; x.foo.a.x = x; x
  }
  {
    description: 'add circular reference'
    have: do -> x = foo: a: {y: 3}; x
    wish: do -> x = foo: a: {y: 3}; x.foo.a.foo = x.foo; x
  }
]

