# wson-diff [![Build Status](https://secure.travis-ci.org/tapirdata/wson-diff.png?branch=master)](https://travis-ci.org/tapirdata/wson-diff) [![Dependency Status](https://david-dm.org/tapirdata/wson-diff.svg)](https://david-dm.org/tapirdata/wson-diff) [![devDependency Status](https://david-dm.org/tapirdata/wson-diff/dev-status.svg)](https://david-dm.org/tapirdata/wson-diff#info=devDependencies)
>  A differ/patcher for arbitrary values that presents delta in a terse WSON-like format.

[WSON](https://www.npmjs.com/package/wson) can be used to stringify structured data, transmit that string to some receiver, where it can be parsed to reconstruct that original data. Now both ends posses that identical data. If now that data happens to change a little, why should we retransmit that whole redundant information? This is where wson-diff comes in:

1. Generate a [delta](#delta) by either:
  - Call `diff` with your old value `have` and the current `wish`.
  - Manually build up this [delta](#delta).
2. Send the **delta** over the wire.
3. On the receiver end: Call `patch` to apply that **delta** to the value `have` in being.

### Features
- `diff` uses [mdiff](https://www.npmjs.com/package/mdiff) to find minimal changes of **arrays** and **strings**. For arrays this changes are further boiled down to deletes, moves, inserts and replaces.
- `patch` can use [notifiers](#notifier) to forward changes to some dependent (DOM?)-structure.
- Extends WSONs support cyclic structures and [custom objects](#custom-objects).
- Provides a terse syntax for **delta** by using the "gaps" of WSON-syntax (no extra special characters).

## Usage

```bash
$ npm install wson-diff
```

```js
wdiff = require('wson-diff')();

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

var delta = wdiff.diff(have, wish);
console.log('delta="%s"', delta);
// delta="|active:#f|completed[m3@2][i4:lisp][r1:coffeescript]|message[s29=!]|name:rudi|size:#177.4"

var result = wdiff.patch(have, delta);
console.log('result="%j"', result);
// Now result (and have) is deep equal to wish.
```

<a name="delta"></a>
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

There are two **modifiers** that operate on an **object**: [unset](#unset-modifier), and [assign](#assign-modifier). Deltas of **objects** are created by deep comparing all own properties of these objects. See also: [Custom Objects](#custom-objects)

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

<a name="custom-objects"></a>
### Custom Objects

The underlying WSON-processor may be created with `connectors` to support [custom objects](https://www.npmjs.com/package/wson#custom-objects). These **conectectors** can be augmented for wson-diff with these extra properties:
- `key` (array): Instead of looking at all own properties `diff` just compares the properties referred by these keys. Thus you can hide private properties from **delta**.
- `postpatch` (function): This function - if present - will be called (bound to the current object) after all patches have been applied. Thus you can update private properties thereafter.

---
#### Complex Examples

| `have`                      | `wish`                      |  `delta`                 | Explanation        |
|-----------------------------|-----------------------------|--------------------------|--------------------|
| {foo: {a: [1, 2]}}          | {foo: {a: [1, 2, 3]}}       | \|foo\|a[i2:#3]          |                    |
| {foo: {a: [1, 2]}}          | {bar: {a: [1, 2]}}          | \|[-foo]bar:{a:[#1\|#2]} | sorry, no renaming |
| {foo: {a: [1, 2]}}          | {foo: {a: 1, b: 1}}         | \|foo[=a:#1\|b:#1]       | assign modifier    |
| [{a: 'alice'}, {b: 'bob'}]  | [{a: 'eve'}, {b: 'bob'}]    | \|[r0\|a:eve]            |                    |


<a name="notifier"></a>
## Notifiers

Be that you are not only interested in in the result of patching some value by a **delta**, but want to update some related structure - say a DOM-tree - accordingly. This task can be accomplished by passing `patch`one or **notifiers**, that should provide the following interface:

```js
{
  checkedBudge: function(up, key, current) {},
  unset: function(key, current) {},
  assign: function(key, value, current) {},
  "delete": function(idx, len, current) {},
  move: function(srcIdx, dstIdx, len, reverse, current) {},
  insert: function(idx, values, current) {},
  replace: function(idx, values, current) {},
  substitute: function(patches, current) {}
}
```
A notifier is assumed to to hold some **cursor** that could be manipulated by calling `checkedBudge`: `up` is a number >= 0 that says how many levels we want to go up. If `key` is not `null` it is a numeric array-index or a string object-key. Then the **cursor** should be moved into the item that is indicated by `key`. If a `key` is provided (or for a first extra call with `up=0, key=null`), `checkedBudge` may return `false` to signal a [cut](#notify-cut). Inititally the **cursor** refers to the root-value (The `have` that is passed to `patch`).

The other methods just resemble the parsed [modifiers](#modifier). For convenience the current value (that one the **cursor** refers to, before apllying the modification) is passed as an additional argument `current`.

`assign` may be called with or without `key`. If `key` is `null`, the item under the **cursor** is expected to be replaced. Otherwise the item referred by this `key` is expected to be set or replaced.

<a name="notify-cut"></a>
### Cut

To finer tailor the amount of notification `checkedBudge` may return `false`. Then all modifications for the value reached by `key` will be collected and notified by a single call of `assign` (without a `current` argument). E.g. if `checkedBudge` returns `false` whenever `current` happens to be a string, a [substitute-delta](#substitute-delta) will never have `substitute` be called but results in the same call of `assign` as if there had been a [plain-delta](plain-plain) for this string.


<a name="api"></a>
## API

#### var wdiff = wson-diff(options)

Creates a new diff/patch processor.

Recognized options:
- `WSON`: a [WSON](https://www.npmjs.com/package/wson)-processor.
- `wsonOptions`: If no `WSON` is provided, create one with this options.

Other options are handed to `diff`.

#### var delta = wdiff.diff(have, wish, options)

Returns `null` if `have` and `wish` are deep equal. Otherwise returns the string `delta`.

Recognized options:
- `arrayLimit` (integer or function, default: `null`): If the number of differences between some `have-array` and some `wish-array` exceeds this limit, a [plain-delta](#plain-delta) will be created instead of a list of [modifiers](#modifier). A [move](#move-modifier) will count as twice it's length. This is to limit the amount of time used to find the minimal set of changes by the underlying [mdiff](https://www.npmjs.com/package/mdiff). If `arrayLimit` is a function, it will applied to `(have-array, wish-array)` to return the limit dynamically.

- `stringLimit` (integer or function, default: `null`): If the number of differences between some `have-string` and some `wish-string` exceeds this limit, a [plain-delta](#plain-delta) will be created instead of a [substitute-modifier](#substitute-modifier). Every deleted or inserted character count as one change. If `stringLimit` is a function, it will applied to `(have-string, wish-string)` to return the limit dynamically.

- `stringEdge` (integer, default: 16): If some `wish-string` is shorter than this limit, a [plain-delta](#plain-delta) will be created instead of a [substitute-modifier](#substitute-modifier).

#### var result = wdiff.patch(have, delta, options)

Returns the result of applying `delta` to `have`. If possible, `have` will be changed in place.

Recognized options:
- `notifiers`: an array of [notifiers](#notifier), each of which receives all applied changes. A single notifier is accepted, too.


