import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

import { CompareResponse } from './compare.models';

@Injectable({ providedIn: 'root' })
export class CompareService {
  constructor(private readonly http: HttpClient) {}

  compareXml(xml1: File, xml2: File): Observable<CompareResponse> {
    const form = new FormData();
    form.append('xml1', xml1, xml1.name);
    form.append('xml2', xml2, xml2.name);
    return this.http.post<CompareResponse>('/api/compare', form);
  }
}
