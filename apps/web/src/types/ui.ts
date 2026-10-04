/**
 * Small shared UI types.
 *
 * `ListResultLike` mirrors the shape returned by the data layer's list helpers
 * without importing the server-only module into client components.
 */
export interface ListResultLike<T> {
  rows: T[];
  count: number;
  page: number;
  pageSize: number;
}
