# wson-diff [![Build Status](https://secure.travis-ci.org/tapirdata/wson-diff.png?branch=master)](https://travis-ci.org/tapirdata/wson-diff) [![Dependency Status](https://david-dm.org/tapirdata/wson-diff.svg)](https://david-dm.org/tapirdata/wson-diff) [![devDependency Status](https://david-dm.org/tapirdata/wson-diff/dev-status.svg)](https://david-dm.org/tapirdata/wson-diff#info=devDependencies)
>  A differ/patcher for arbitrary values that presents delta in a terse WSON-like format.

## Usage

```bash
$ npm install wson-diff
```

```js
wdif = require('wson-diff')();

var have = {
  name: "otto",
  size: 177.3,
  completed: ["forth", "javascript", "c++", "haskell"],
  active: true,
  message: 'My hovercraft is full of eels.'
};

var wish = {
  name: "rudi",
  size: 177.4,
  completed: ["forth", "coffeescript", "haskell", "c++", "lisp"],
  active: false,
  message: 'My hovercraft is full of eels!'
};

var delta = wdif.diff(have, wish);
console.log('delta="%s"', delta);
// delta="|active:#f|completed[m3@2][i4:lisp][r1:coffeescript]|message[s29=!]|name:rudi|size:#177.4"

var result = wdif.patch(have, delta);
console.log('result="%j"', result);
// Now result (and have) is deep equal to wish.
```

## Delta

This is an informal description of the Delta-Syntax. There is also an EBNF-file in the doc-directory and a [syntax-diagram](http://tapirdata.github.io/wson-diff/doc/wson-delta.xhtml) created from it.

### Null-delta

If `have` is deep equal to `wish`, `diff` returns `null`.

Examples:
| `have`              | `wish`              |
|---------------------|---------------------|
| `23`                | `23`                |
| `{a: 3, b: 4}`      | `{a: 3, b: 4}`      |
| `[3, 4]`            | `[3, 4]`            |
| `'hovercraft'`      | `'hovercraft'`      |

<a name="plain-delta"></a>
### Plain-delta

Any WSON-value is a **plain-delta**. Its semantics is: Ignore `have`, just use the WSON-stringified delta as the `result`.

A **plain-delta** will be produced for **scalars** (every **string**, **array**, or **object** except `Date`, which _are_ WSON-scalars) and if `have` and `wish` have different types.

Examples:
| `have`              | `wish`              |  `delta`         |
|---------------------|---------------------|------------------|
| `23`                | `42`                | #42              |
| `false`             | `true`              | #t               |
| `undefined`         | `null`              | #n               |
| `[3, 4]`            | `{a: 3, b: 4}`      | {a:3\|b:4}       |
| `{a: 3, b: 4}`      | `[3, 4]`            | [3\|4]           |

### Real-delta

A **real-delta** starts with a '|' followed by zero ore more [modifiers](#modifier) followed by zero ore more [assignments](#assignment). The **assignments** are separated from each other by '|'. There must be at least one **modifier** or **assignments**. Since the only WSON-value that starts with a '|' is a backref, which can't occur at top-level, there is no ambiguity.

<a name="path"></a>
### Path

A **path** consists of one ore more keys separated by '|'. Each key is a WSON-string.

Examples:
| path                     | keys                                                                                              |
|--------------------------|---------------------------------------------------------------------------------------------------|
| a                        | 'a'                                                                                               |
| foo\|a\|members          | 'foo', 'a', 'members'                                                                             |
| foo\|\`a\`e\|#\|42       | 'foo', '[]', '', '42' (Special characters '[' and ']' are WSON-escaped; '#' is the empty string.) |


<a name="assignment"></a>
### Assignment

An **assignment** consists of a [path](#path) followed by a ':', followed by a WSON-value. Its semantics is: Use **path** to dive into the **object** (All keys but the last must resolve to **objects**). Use the last key to set or replace that property by **value**.

Examples:
| `have`                 | `wish`                        |  `delta`         |
|------------------------|-------------------------------|------------------|
| `{a: 3, b: 4}`         | `{a: 3, b: 42}`               | \|b:#42          |
| `{foo: {a: 3, b: 4}}`  | `{foo: {a: 3, b: 42}}`        | \|foo\|b:#42     |
| `{foo: {a: 3, b: 4}}`  | `{foo: {a: 3, b: 4, c: 5}}`   | \|foo\|c:#5      |


<a name="modifier"></a>
### Modifier

A **Modifier** consists of a '[', followed by a **kind character**, followed by one or more '|'-separated kind-specific **items**, closed by a ']'.

<a name="path-delta"></a>
### Path-delta

A **path-delta** is an [assignments](#assignment) or a [path](#path) followed by one ore more [modifiers](#modifier).


<a name="object-modifier"></a>
#### Object Modifiers

There are two **modifiers** that operate on an **object**: [unset](#unset-modifier), and [assign](#assign-modifier):

<a name="unset-modifier"></a>
##### Unset Modifier

- **kind character**: '-'
- **item**: **key**, a WSON-string
- Semantics: Remove **key** from **object**

Examples:
| `have`                | `wish`              |  `delta`         |
|-----------------------|---------------------|------------------|
| `{a: 3, b: 4, c: 5}`  | `{b: 4}`            | [-a\|c]          |

<a name="assign-modifier"></a>
##### Assign Modifier

- **kind character**: '='
- **item**: a [path-delta](#path-delta)
- Semantics: Set, replace or modify the referred value.

Examples:

Examples:
| `have`                       | `wish`                      |  `delta`           |
|------------------------------|-----------------------------|--------------------|
| `{foo: {a: 3, b: 4, c: 5}}`  | `{foo: {a: 4, b: 3, c: 5}}` | \|foo[=a:#4\|b:#3] |

<a name="array-modifier"></a>
#### Array Modifiers

There are four **modifiers** that operate on an **array**: [delete](#delete-modifier), [move](#move-modifier) [insert](#insert-modifier), and [replace](#replace-modifier).
Since **arrays** are assumed to be mutable, these modifiers work cumulatively. I.e. the indexes refer to the array after all previous modifications applied):

Note: `diff` will create a [plain-delta](#plain-delta):
- for **arrays** that differ too much (more then [`arrayLimit`](#option-arrayLimit) entry changes).


<a name="delete-modifier"></a>
##### Delete Modifier

- **kind character**: 'd'
- **item**: an index optionally followed by '+' and extra-count
- Semantics: Remove one or more entries from the array. If extra-count is specified, then (extra-count + 1) entries will be deleted.

Examples:

Examples:
| `have`                  | `wish`                  |  `delta`         | Explanation                                                                                 |
|-------------------------|-------------------------|------------------|---------------------------------------------------------------------------------------------|
| `[2, 3, 5, 7, 11, 13]`  | `[2, 5, 7, 11, 13]`     | [d1]             | Delete one entry at index 1                                                                 |
| `[2, 3, 5, 7, 11, 13]`  | `[3, 5, 13]`            | [d3+1\|0]        | Delete 2 entries (one + 1) at index 3. From the resulting array delete one entry at index 0 |

<a name="move-modifier"></a>
##### Move Modifier

- **kind character**: 'm'
- **item**: an source-index, optionally followed by '+' or '-' and an extra-count, followed by '@' and an destination-index.
- Semantics: Move one or more entries in the array. If extra-count is specified, then (extra-count + 1) entries will be moved. The sequence to move will be first cut out at source-index and then reinserted at destination-index (which applies to the already reduced array). If there is a '-', the sequence will be reversed before reinsertion.

Examples:
| `have`                  | `wish`                    |  `delta`            | Explanation                                                             |
|-------------------------|---------------------------|---------------------|-------------------------------------------------------------------------|
| `[2, 3, 5, 7, 11, 13]`  |  `[2, 3, 7, 11, 5, 13]`   | [m2@4]              | Cut one entry at index 2 and reinsert it at index 4                     |
| `[2, 3, 5, 7, 11, 13]`  |  `[2, 11, 13, 3, 5, 7]`   | [m4+1@1]            | Cut 2 entries (one + 1) at index 4 and reinsert them at index 1         |
| `[2, 3, 5, 7, 11, 13]`  |  `[2, 13, 11, 3, 5, 7]`   | [m4-1@1]            | Cut 2 entries (one + 1) at index 4 and reinsert them swapped at index 1 |


<a name="insert-modifier"></a>
##### Insert Modifier

- **kind character**: 'i'
- **item**: an index followed by one or more WSON-values, each prefixed by a ':'
- Semantics: Insert one or more entries into the array.

Examples:
| `have`                  | `wish`                  |  `delta`          | Explanation                                                                                |
|-------------------------|-------------------------|-------------------|--------------------------------------------------------------------------------------------|
| `[2, 5, 7, 11, 13]`     | `[2, 3, 5, 7, 11, 13]`  | [i1:#3]           | Insert value `3` at index 1.                                                               |
| `[3, 5, 13]`            | `[2, 3, 5, 7, 11, 13]`  | [i2:#7:#11\|0:#2] | Insert values `7`, `11` at index 11. Into the resulting array insert value `2` at index 0. |


<a name="replace-modifier"></a>
##### Replace Modifier

- **kind character**: 'r'
- **item**: an index followed by either:
  - one or more WSON-strings, each prefixed by a ':'
  - a single **path modifier**, prefixed by a '|'
- Semantics: Replace one or more entries of the array.

Examples:
| `have`                  | `wish`                    |  `delta`            | Explanation                                                                                 |
|-------------------------|---------------------------|---------------------|---------------------------------------------------------------------------------------------|
| `[2, 3, 5, 7, 11, 13]`  |  `[2, 3, 15, 7, 11, 13]`  | [r2:#15]            | Replace the entry at index 2 with `15`.                                                     |
| `[2, 3, 5, 7, 11, 13]`  |  `[2, 23, 15, 7, 1, 13]`  | [r1:#23:#15\|4:#1]  | Replace the entries at index 1 with `23`, `15`. Then replace the entry at index 4 with `1`. |
| `[{a: 3}, {b: 4}]`      |  `[{a: 4}, {b: 3}]`       | [r0\|a:#4\|1\|b:#3] | Replace 'a' at index 0, then 'b' at index 1.                                                |

---
`diff` will produce **array-modifiers** in the order **delete**, **move**, **insert**, **replace**

Examples:

| `have`                  | `wish`                    |  `delta`               | Explanation
|-------------------------|---------------------------|------------------------|------------------------------------------------|
| `[2, 3, 5, 7, 11, 13]`  |  `[5, 11, 13, 7, 42]`     | [d0+1][m1@3][i4:#42]   | Delete `2`, `3`, move `7`, insert `42`.        |
| `[2, 3, 5, 7, 11, 13]`  |  `[13, 11, 2, 3, 51, 7]`  | [m4-1@0][r4:#51]       | Move reversed `11`, `13`, replace `5` by `51`. |


<a name="string-modifier"></a>
#### String Modifier

There in one **modifier** that operates on a **string**: [substitute](#substitute-modifier).
Since **strings** are assumed to be immutable, these modifiers work simultaneously (in contrast to [array-modifiers](#array-modifier):

Note: `diff` will create a [plain-delta](#plain-delta):
- for short **strings** (length < [`stringEdge`](#option-stringEdge))
- for **strings** that differ too much (more then [`stringLimit`](#option-stringLimit) character changes).

<a name="substitute-modifier"></a>
##### Substitute Modifier

- **kind character**: 's'
- **item**: an index optionally followed by '+', '-' and length-modifier number, then optionally a '=' and a non empty WSON-escaped replacement-string.
- Semantics: Replace the substring at the specified index with the string after the '='. The replaced substring grow ('+') or shrink ('-') by the length modifier.
I.e. a missing length-modifier results in a pure replacement.

Examples (with `stringEdge: 0`):
| `have`                    | `wish`                    |  `delta`            | Explanation        |
|---------------------------|---------------------------|---------------------|--------------------|
| `'hovercraft'`            | `'Hovercraft'`            | [s0=H]              | simple replacement |
| `'my hovercraft'`         | `'thine hovercraft'`      | [s0+3=thine]        | grow replacement   |
| `'hovercraft is missing'` | `'hovercraft is away'`    | [s14-3=away]        | shrink replacement |
| `'full of my eels'`       | `'full of eels'`          | [s8-3]              | pure deletion      |
| `'my hovercraft'`         | `'hover my craft'`        | [s0-3\|8+4= my ]    | delete and insert  |

## API

#### var wdif = wson-diff(options)

Creates a new diff/patch processor.  Recognized options are:
- `WSON`: a [WSON](https://www.npmjs.com/package/wson)-processor.
- `wsonOptions`: if no `WSON` is provided, create one with this options.



to be continued...
