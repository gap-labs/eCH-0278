import { Component, OnDestroy, OnInit } from '@angular/core';
import { MatTabsModule } from '@angular/material/tabs';
import { ActivatedRoute, Router } from '@angular/router';
import { Subscription } from 'rxjs';

import { SchemaExplorerPageComponent } from '../schema/schema-explorer-page.component';
import { ValidatePageComponent } from '../validate/validate-page.component';

@Component({
  selector: 'app-workspace-page',
  standalone: true,
  imports: [MatTabsModule, SchemaExplorerPageComponent, ValidatePageComponent],
  templateUrl: './workspace-page.component.html',
  styleUrl: './workspace-page.component.css',
})
export class WorkspacePageComponent implements OnInit, OnDestroy {
  selectedIndex = 0;

  private routeSubscription?: Subscription;

  constructor(
    private readonly route: ActivatedRoute,
    private readonly router: Router,
  ) {}

  ngOnInit(): void {
    this.routeSubscription = this.route.paramMap.subscribe((paramMap) => {
      const tab = paramMap.get('tab');
      this.selectedIndex = tab === 'validate' ? 1 : 0;
    });
  }

  ngOnDestroy(): void {
    this.routeSubscription?.unsubscribe();
  }

  onTabChange(index: number): void {
    const nextTab = index === 1 ? 'validate' : 'schema';
    const currentTab = this.route.snapshot.paramMap.get('tab') ?? 'schema';

    if (nextTab === currentTab) {
      return;
    }

    this.router.navigate(['/workspace', nextTab]);
  }
}
