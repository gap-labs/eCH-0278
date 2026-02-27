import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

import { ValidateResponse } from './validate.models';

@Injectable({ providedIn: 'root' })
export class ValidateService {
  constructor(private readonly http: HttpClient) {}

  validateXml(file: File): Observable<ValidateResponse> {
    const form = new FormData();
    form.append('file', file, file.name);
    return this.http.post<ValidateResponse>('/api/validate', form);
  }
}
