import { AfterViewInit, Component, ElementRef, OnDestroy, OnInit, ViewChild } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ChangeDetectorRef } from '@angular/core';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { Subscription } from 'rxjs';

import { SchemaNode, SchemaSummary } from './schema.models';
import { SchemaExplorerService } from './schema-explorer.service';
import { SchemaPathResolverService } from './schema-path-resolver.service';
import { SchemaJumpService } from './schema-jump.service';
import { SchemaTreeComponent } from './schema-tree.component';
import { SchemaNodeDetailsComponent } from './schema-node-details.component';

@Component({
  selector: 'app-schema-explorer-page',
  standalone: true,
  imports: [
    CommonModule,
    MatSidenavModule,
    MatProgressSpinnerModule,
    SchemaTreeComponent,
    SchemaNodeDetailsComponent,
  ],
  templateUrl: './schema-explorer-page.component.html',
  styleUrl: './schema-explorer-page.component.css',
})
export class SchemaExplorerPageComponent implements OnInit, AfterViewInit, OnDestroy {
  @ViewChild(SchemaTreeComponent) private schemaTree?: SchemaTreeComponent;
  @ViewChild('detailsPane', { read: ElementRef }) private detailsPane?: ElementRef<HTMLElement>;

  loading = true;
  error: string | null = null;
  summary: SchemaSummary | null = null;
  rootNode: SchemaNode | null = null;
  selectedNode: SchemaNode | null = null;
  private pendingJumpPath: string | null = null;
  private jumpSubscription?: Subscription;

  constructor(
    private readonly schemaExplorerService: SchemaExplorerService,
    private readonly schemaPathResolverService: SchemaPathResolverService,
    private readonly schemaJumpService: SchemaJumpService,
    private readonly changeDetectorRef: ChangeDetectorRef,
  ) {}

  ngOnInit(): void {
    this.pendingJumpPath = this.schemaJumpService.consumePendingPath();
    this.jumpSubscription = this.schemaJumpService.jumpRequested$.subscribe((path) => {
      this.pendingJumpPath = path;
      this.applyPendingJump();
    });

    this.schemaExplorerService.getSummary().subscribe({
      next: (summary) => {
        this.summary = summary;
      },
      error: () => {
        this.error = 'Failed to load schema summary.';
        this.loading = false;
      },
    });

    this.schemaExplorerService.getTree().subscribe({
      next: (response) => {
        this.rootNode = response.root;
        this.selectedNode = response.root;
        this.loading = false;
        this.applyPendingJump();
      },
      error: () => {
        this.error = 'Failed to load schema tree.';
        this.loading = false;
      },
    });
  }

  onNodeSelected(node: SchemaNode): void {
    this.selectedNode = node;
    this.schemaTree?.scrollToNode(node);
    this.resetDetailsPaneScroll();
    this.refreshLayout();
  }

  ngAfterViewInit(): void {
    this.applyPendingJump();
  }

  ngOnDestroy(): void {
    this.jumpSubscription?.unsubscribe();
  }

  private applyPendingJump(): void {
    if (!this.rootNode || !this.pendingJumpPath) {
      return;
    }

    const jumpPath = this.pendingJumpPath;
    const nodePath = this.schemaPathResolverService.resolvePathInRoot(this.rootNode, jumpPath);
    if (!nodePath || nodePath.length === 0) {
      this.schemaJumpService.completeJump(jumpPath);
      this.pendingJumpPath = null;
      return;
    }

    if (!this.schemaTree) {
      return;
    }

    this.schemaTree.expandPath(nodePath);
    const targetNode = nodePath[nodePath.length - 1];
    this.selectedNode = null;
    this.changeDetectorRef.detectChanges();
    this.selectedNode = targetNode;
    this.changeDetectorRef.detectChanges();
    this.schemaTree.scrollToNode(targetNode);
    this.resetDetailsPaneScroll();
    this.refreshLayout();
    this.schemaJumpService.completeJump(jumpPath);
    this.pendingJumpPath = null;
  }

  private resetDetailsPaneScroll(): void {
    const pane = this.detailsPane?.nativeElement;
    if (!pane) {
      return;
    }

    pane.scrollTo({ left: 0, top: 0, behavior: 'auto' });
    requestAnimationFrame(() => {
      pane.scrollTo({ left: 0, top: 0, behavior: 'auto' });
    });
  }

  private refreshLayout(): void {
    requestAnimationFrame(() => {
      window.dispatchEvent(new Event('resize'));
    });
  }
}
