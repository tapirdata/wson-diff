
export interface Item {
  description: string
  have: any
  wish?: any
  delta?: string | null
  budgeTest0?: (top: any) => boolean
  budgeTest1?: (top: any) => boolean
  nfys0: any[]
  nfys1?: any[]
  patchOptions?: any
}

const items: Item[] = [
  {
    description:  "plain delta",
    have:  null,
    delta: "foo",
    nfys0: [
      ["assign", [], "foo"],
    ],
  },
  {
    description:  "array insert delta",
    have:  ["foo", "bar", "baz"],
    delta: "|[i1:moo]",
    nfys0: [
      ["insert", [], 1, ["moo"]],
    ],
  },
  {
    description:  "array delete delta",
    have:  ["foo", "bar", "baz"],
    delta: "|[d1]",
    nfys0: [
      ["delete", [], 1, 1],
    ],
  },
  {
    description:  "array move delta",
    have:  ["foo", "bar", "baz"],
    delta: "|[m1@2]",
    nfys0: [
      ["move", [], 1, 2, 1, false],
    ],
  },
  {
    description:  "array replace delta",
    have:  ["foo", "bar", "baz"],
    delta: "|[r1:moo]",
    nfys0: [
      ["replace", [], 1, ["moo"]],
    ],
  },
  {
    description:  "deep delta detailed",
    have: {foo: {a: "alice", b: "bob"}, bar: {a: "alice", b: "bob"}, baz: {a: "alice", b: "bob"}},
    delta: "|foo|a:eve",
    nfys0: [
      ["assign", ["foo", "a"], "eve"],
    ],
  },
  {
    description:  'deep delta till "foo"',
    have: {foo: {a: "alice", b: "bob"}, bar: {a: "alice", b: "bob"}, baz: {a: "alice", b: "bob"}},
    delta: "|foo|a:eve",
    budgeTest0(top) { return top !== "foo" },
    nfys0: [
      ["assign", ["foo"], {a: "eve", b: "bob"}],
    ],
  },
  {
    description:  "deep delta till null",
    have: {foo: {a: "alice", b: "bob"}, bar: {a: "alice", b: "bob"}, baz: {a: "alice", b: "bob"}},
    delta: "|foo|a:eve",
    budgeTest0(top) { return false },
    nfys0: [
      ["assign", [], {foo: {a: "eve", b: "bob"}, bar: {a: "alice", b: "bob"}, baz: {a: "alice", b: "bob"}}],
    ],
  },
  {
    description:  "multi deep delta till foo",
    have: {foo: {a: "alice", b: "bob"}, bar: {a: "alice", b: "bob"}, baz: {a: "alice", b: "bob"}},
    delta: "|bar|a:mallet|foo|a:eve",
    budgeTest0(top) { return top !== "foo" && top !== "bar" },
    nfys0: [
      ["assign", ["bar"], {a: "mallet", b: "bob"}],
      ["assign", ["foo"], {a: "eve", b: "bob"}],
    ],
  },
  {
    description:  "multi deep delta till null",
    have: {foo: {a: "alice", b: "bob"}, bar: {a: "alice", b: "bob"}, baz: {a: "alice", b: "bob"}},
    delta: "|bar|a:mallet|foo|a:eve",
    budgeTest0(top) { return false },
    nfys0: [
      ["assign", [], {foo: {a: "eve", b: "bob"}, bar: {a: "mallet", b: "bob"}, baz: {a: "alice", b: "bob"}}],
    ],
  },
  {
    description:  "multi deep delta with two notifiers",
    have: {foo: {a: "alice", b: "bob"}, bar: {a: "alice", b: "bob"}, baz: {a: "alice", b: "bob"}},
    delta: "|bar|a:mallet|foo|a:eve",
    budgeTest0(top) { return top !== "foo" && top !== "bar" },
    budgeTest1(top) { return false },
    nfys0: [
      ["assign", ["bar"], {a: "mallet", b: "bob"}],
      ["assign", ["foo"], {a: "eve", b: "bob"}],
    ],
    nfys1: [
      ["assign", [], {foo: {a: "eve", b: "bob"}, bar: {a: "mallet", b: "bob"}, baz: {a: "alice", b: "bob"}}],
    ],
  },
]

export default items
