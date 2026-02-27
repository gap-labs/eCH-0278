import { ChangeDetectionStrategy, ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { MatTabsModule } from '@angular/material/tabs';
import { ActivatedRoute, Router } from '@angular/router';
import { Subscription } from 'rxjs';

import { SchemaExplorerPageComponent } from '../schema/schema-explorer-page.component';
import { ValidatePageComponent } from '../validate/validate-page.component';
import { ComparePageComponent } from '../compare/compare-page.component';

@Component({
  selector: 'app-workspace-page',
  standalone: true,
  imports: [MatTabsModule, SchemaExplorerPageComponent, ValidatePageComponent, ComparePageComponent],
  templateUrl: './workspace-page.component.html',
  styleUrl: './workspace-page.component.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class WorkspacePageComponent implements OnInit, OnDestroy {
  selectedIndex = 0;

  private routeSubscription?: Subscription;

  constructor(
    private readonly route: ActivatedRoute,
    private readonly router: Router,
    private readonly changeDetectorRef: ChangeDetectorRef,
  ) {}

  ngOnInit(): void {
    this.routeSubscription = this.route.paramMap.subscribe((paramMap) => {
      const tab = paramMap.get('tab');
      if (tab === 'validate') {
        this.selectedIndex = 1;
        this.changeDetectorRef.markForCheck();
        return;
      }

      if (tab === 'compare') {
        this.selectedIndex = 2;
        this.changeDetectorRef.markForCheck();
        return;
      }

      this.selectedIndex = 0;
      this.changeDetectorRef.markForCheck();
    });
  }

  ngOnDestroy(): void {
    this.routeSubscription?.unsubscribe();
  }

  onTabChange(index: number): void {
    const nextTab = index === 1 ? 'validate' : index === 2 ? 'compare' : 'schema';
    const currentTab = this.route.snapshot.paramMap.get('tab') ?? 'schema';

    if (nextTab === currentTab) {
      return;
    }

    this.router.navigate(['/workspace', nextTab]);
  }
}
