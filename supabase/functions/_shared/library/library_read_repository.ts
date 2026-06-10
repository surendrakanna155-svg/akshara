import { createEntityReadStore } from "../entity_read/entity_read_store.ts";

export const LIBRARY_BOOK_SCHOOL_A = "bf100000-0000-4000-8000-000000000001";
export const LIBRARY_BOOK_SCHOOL_B = "bf100000-0000-4000-8000-000000000002";

export const libraryStore = createEntityReadStore("library_entities", "Library");

export const getSnapshot = libraryStore.getSnapshot;
export const listEntities = libraryStore.listEntities;
export const getEntity = libraryStore.getEntity;
export const LibrarySnapshotNotFoundError = libraryStore.SnapshotNotFoundError;
export const LibraryEntityNotFoundError = libraryStore.EntityNotFoundError;

export const LIBRARY_ENTITIES_PROBE_SQL = libraryStore.entitiesProbeSql;
export const LIBRARY_CATALOG_API_PROBE_SQL = libraryStore.listApiProbeSql("catalog");
export const LIBRARY_CATALOG_DETAIL_PROBE_SQL = libraryStore.detailProbeSql("catalog");
