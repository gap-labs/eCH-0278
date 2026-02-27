import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatChipsModule } from '@angular/material/chips';
import { MatListModule } from '@angular/material/list';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { Router } from '@angular/router';
import { take } from 'rxjs/operators';

import { SchemaJumpService } from '../schema/schema-jump.service';
import { SchemaPathResolverService } from '../schema/schema-path-resolver.service';
import { ValidateResponse } from './validate.models';
import { ValidateService } from './validate.service';

interface ValidationErrorView {
  raw: string;
  path: string | null;
  message: string;
  canJump: boolean;
}

@Component({
  selector: 'app-validate-page',
  standalone: true,
  imports: [
    CommonModule,
    MatButtonModule,
    MatCardModule,
    MatChipsModule,
    MatListModule,
    MatProgressSpinnerModule,
  ],
  templateUrl: './validate-page.component.html',
  styleUrl: './validate-page.component.css',
})
export class ValidatePageComponent {
  selectedFile?: File;
  loading = false;
  result?: ValidateResponse;
  error?: string;
  validationErrors: ValidationErrorView[] = [];

  private validationErrorToken = 0;

  constructor(
    private readonly validateService: ValidateService,
    private readonly schemaPathResolverService: SchemaPathResolverService,
    private readonly schemaJumpService: SchemaJumpService,
    private readonly router: Router,
  ) {}

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.selectedFile = input.files?.[0] ?? undefined;
  }

  validate(): void {
    if (!this.selectedFile || this.loading) {
      return;
    }

    this.loading = true;
    this.error = undefined;

    this.validateService.validateXml(this.selectedFile).subscribe({
      next: (response) => {
        this.result = response;
        this.buildValidationErrors(response.errors);
        this.loading = false;
      },
      error: () => {
        this.error = 'Validation request failed. Please check connectivity and backend availability.';
        this.loading = false;
      },
    });
  }

  onErrorPathClick(path: string): void {
    if (!this.schemaJumpService.requestJump(path)) {
      return;
    }

    this.router.navigate(['/workspace', 'schema']);
  }

  isErrorPathBusy(path: string): boolean {
    return this.schemaJumpService.isJumpInFlight(path);
  }

  private buildValidationErrors(errors: string[]): void {
    this.validationErrorToken += 1;
    const token = this.validationErrorToken;

    this.validationErrors = errors.map((rawError) => {
      const parsedError = this.parseValidationError(rawError);
      return {
        raw: rawError,
        path: parsedError.path,
        message: parsedError.message,
        canJump: false,
      };
    });

    this.validationErrors.forEach((validationError, index) => {
      if (!validationError.path) {
        return;
      }

      this.schemaPathResolverService
        .resolvePath(validationError.path)
        .pipe(take(1))
        .subscribe((nodePath) => {
          if (token !== this.validationErrorToken) {
            return;
          }

          const updatedErrors = [...this.validationErrors];
          updatedErrors[index] = {
            ...updatedErrors[index],
            canJump: !!nodePath,
          };

          this.validationErrors = updatedErrors;
        });
    });
  }

  private parseValidationError(errorMessage: string): { path: string | null; message: string } {
    const pathSeparatorIndex = errorMessage.indexOf(': ');
    if (pathSeparatorIndex < 0) {
      return { path: null, message: errorMessage };
    }

    const candidatePath = errorMessage.slice(0, pathSeparatorIndex).trim();
    const detailMessage = errorMessage.slice(pathSeparatorIndex + 2).trim();

    if (!candidatePath.startsWith('/') || detailMessage.length === 0) {
      return { path: null, message: errorMessage };
    }

    return { path: candidatePath, message: detailMessage };
  }
}
