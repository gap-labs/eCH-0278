import { CommonModule } from '@angular/common';
import { ChangeDetectionStrategy, ChangeDetectorRef, Component } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';

import { CompareResponse } from './compare.models';
import { CompareService } from './compare.service';

@Component({
  selector: 'app-compare-page',
  standalone: true,
  imports: [CommonModule, MatButtonModule, MatCardModule, MatProgressSpinnerModule],
  templateUrl: './compare-page.component.html',
  styleUrl: './compare-page.component.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ComparePageComponent {
  fileA?: File;
  fileB?: File;
  loading = false;
  result?: CompareResponse;
  error?: string;

  constructor(
    private readonly compareService: CompareService,
    private readonly changeDetectorRef: ChangeDetectorRef,
  ) {}

  onFileASelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.fileA = input.files?.[0] ?? undefined;
  }

  onFileBSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.fileB = input.files?.[0] ?? undefined;
  }

  compare(): void {
    if (!this.fileA || !this.fileB || this.loading) {
      return;
    }

    this.loading = true;
    this.error = undefined;

    this.compareService.compareXml(this.fileA, this.fileB).subscribe({
      next: (response) => {
        const bothValid = response.xml1Valid && response.xml2Valid;
        this.result = {
          ...response,
          diffSummary: bothValid ? response.diffSummary : null,
        };
        this.loading = false;
        this.changeDetectorRef.markForCheck();
      },
      error: (error: HttpErrorResponse) => {
        if (error.status === 0) {
          this.error = 'Comparison request failed. Backend is unavailable or network is blocked.';
        } else if (error.status >= 500) {
          this.error = 'Comparison request failed due to a backend error.';
        } else {
          this.error = 'Comparison request failed. Please verify both XML files and try again.';
        }

        this.loading = false;
        this.changeDetectorRef.markForCheck();
      },
    });
  }
}
