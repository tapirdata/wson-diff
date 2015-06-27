module.exports = [
  {
    source: 42
    dest: 42
    delta: null
  }
  {
    source: 43
    dest: 42
    delta: '#42'
  }
  {
    source: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    dest: 42
    delta: '#42'
  }
  {
    source: 42
    dest: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: '{bar:{a:alice|b:bob}|foo:{a:alice|b:bob}}'
  }
  {
    source: []
    dest: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: '{bar:{a:alice|b:bob}|foo:{a:alice|b:bob}}'
  }
  {
    source: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    dest: []
    delta: '[]'
  }
  {
    source: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    dest: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: null
  }
  {
    source: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    dest: {foo: {a: 'alice', b: 'bobby'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo|b:bobby'
  }
  {
    source: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    dest: {foo: {a: 'alice', b: 'bobby'}, bar: {a: 'alice', b: 'bobby'}}
    delta: '|bar|b:bobby|foo|b:bobby'
  }
  {
    source: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    dest: {foo: {a: 'alf', b: 'bobby'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo{a:alf|b:bobby}'
  }
  {
    source: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    dest: {foo: {a: 'alice', b: 'bob'}, bar: 'BAR'}
    delta: '|bar:BAR'
  }
  # with del
  {
    source: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    dest: {foo: {a: 'alice', b: 'bobby'}}
    delta: '|[-bar]foo|b:bobby'
  }
  {
    source: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    dest: {foo: {a: 'alice', b: 'bobby'}}
    delta: '|[-bar|baz]foo|b:bobby'
  }
  {
    source: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    dest: {foo: {a: 'alice', b: 'bobby'}, baz: {a: 'alf', b: 'bob'}}
    delta: '|[-bar]baz|a:alf|foo|b:bobby'
  }
  {
    source: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    dest: {foo: {a: 'alf', c: 'chris'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo[-b]{a:alf|c:chris}'
  }
  {
    source: {foo: {a: 'alice', b: 'bob', c: 'chris'}, bar: {a: 'alice', b: 'bob'}}
    dest: {foo: {a: 'alf'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo[-b|c]a:alf'
  }
]

