import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

import { SchemaSummary, SchemaTreeResponse } from './schema.models';

@Injectable({ providedIn: 'root' })
export class SchemaExplorerService {
  constructor(private readonly http: HttpClient) {}

  getSummary(): Observable<SchemaSummary> {
    return this.http.get<SchemaSummary>('/api/schema/summary');
  }

  getTree(): Observable<SchemaTreeResponse> {
    return this.http.get<SchemaTreeResponse>('/api/schema/tree');
  }
}
