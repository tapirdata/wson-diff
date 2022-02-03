import debugFactory from 'debug';

import { PatchError } from './patch';
import { DiffOptions } from './options';
import { WsonDiff } from './wson-diff';

const _debug = debugFactory('wson-diff:index');

export interface Factory {
  (options?: DiffOptions): WsonDiff;
  PatchError: typeof PatchError;
}

const factory = ((createOptions: DiffOptions = {}) => {
  return new WsonDiff(createOptions);
}) as Factory;

factory.PatchError = PatchError;

export default factory;
export { Notifier } from './notifier';
export { Key, Patch, Target } from './target';
export { Delta } from './types';
