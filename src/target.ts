import debugFactory from 'debug';
import { AnyArray, Value } from './types';

const _debug = debugFactory('wson-diff:target');

export type Key = string | number | null;
export type Patch = [number, number, string];

export interface Target {
  get(up?: number): Value;
  budge(up: number, key: Key): void;

  unset(key: string): void;
  assign(key: string | null, value: Value): void;

  delete(idx: number, len: number): void;
  move(srcIdx: number, dstIdx: number, len: number, reverse: boolean): void;
  insert(idx: number, values: AnyArray): void;
  replace(idx: number, values: AnyArray): void;

  substitute(patches: Patch[]): void;

  done(): void;
}
