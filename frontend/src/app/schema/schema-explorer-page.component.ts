import {
  AfterViewInit,
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  HostListener,
  OnDestroy,
  OnInit,
  ViewChild,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { ChangeDetectorRef } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatTooltipModule } from '@angular/material/tooltip';
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
    MatButtonModule,
    MatProgressSpinnerModule,
    MatTooltipModule,
    SchemaTreeComponent,
    SchemaNodeDetailsComponent,
  ],
  templateUrl: './schema-explorer-page.component.html',
  styleUrl: './schema-explorer-page.component.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SchemaExplorerPageComponent implements OnInit, AfterViewInit, OnDestroy {
  @ViewChild(SchemaTreeComponent) private schemaTree?: SchemaTreeComponent;
  @ViewChild('detailsPane', { read: ElementRef }) private detailsPane?: ElementRef<HTMLElement>;
  @ViewChild('layoutContainer', { read: ElementRef }) private layoutContainer?: ElementRef<HTMLElement>;

  loading = true;
  error: string | null = null;
  summary: SchemaSummary | null = null;
  rootNode: SchemaNode | null = null;
  selectedNode: SchemaNode | null = null;
  treePaneWidth = 360;

  private readonly minTreePaneWidth = 240;
  private readonly maxTreePaneWidth = 620;
  private readonly treePaneWidthStorageKey = 'schemaTreePaneWidth';
  private resizing = false;
  private resizeStartX = 0;
  private resizeStartWidth = 360;
  private pendingJumpPath: string | null = null;
  private jumpSubscription?: Subscription;

  constructor(
    private readonly schemaExplorerService: SchemaExplorerService,
    private readonly schemaPathResolverService: SchemaPathResolverService,
    private readonly schemaJumpService: SchemaJumpService,
    private readonly changeDetectorRef: ChangeDetectorRef,
  ) {}

  ngOnInit(): void {
    this.treePaneWidth = this.getStoredTreePaneWidth();

    this.pendingJumpPath = this.schemaJumpService.consumePendingPath();
    this.jumpSubscription = this.schemaJumpService.jumpRequested$.subscribe((path) => {
      this.pendingJumpPath = path;
      this.applyPendingJump();
    });

    this.schemaExplorerService.getSummary().subscribe({
      next: (summary) => {
        this.summary = summary;
        this.changeDetectorRef.markForCheck();
      },
      error: () => {
        this.error = 'Failed to load schema summary.';
        this.loading = false;
        this.changeDetectorRef.markForCheck();
      },
    });

    this.schemaExplorerService.getTree().subscribe({
      next: (response) => {
        this.rootNode = response.root;
        this.selectedNode = response.root;
        this.loading = false;
        this.applyPendingJump();
        this.changeDetectorRef.markForCheck();
      },
      error: () => {
        this.error = 'Failed to load schema tree.';
        this.loading = false;
        this.changeDetectorRef.markForCheck();
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
    this.treePaneWidth = this.clampTreeWidth(this.treePaneWidth);
    this.applyPendingJump();
    this.changeDetectorRef.markForCheck();
  }

  ngOnDestroy(): void {
    this.jumpSubscription?.unsubscribe();
    this.stopResizing();
  }

  startResize(event: MouseEvent): void {
    if (event.button !== 0) {
      return;
    }

    event.preventDefault();
    this.resizing = true;
    this.resizeStartX = event.clientX;
    this.resizeStartWidth = this.treePaneWidth;
    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';
  }

  onResizeHandleKeydown(event: KeyboardEvent): void {
    if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') {
      return;
    }

    event.preventDefault();
    const delta = event.key === 'ArrowRight' ? 16 : -16;
    const nextWidth = this.treePaneWidth + delta;
    this.treePaneWidth = this.clampTreeWidth(nextWidth);
    this.persistTreePaneWidth();
    this.refreshLayout();
  }

  @HostListener('document:mousemove', ['$event'])
  onMouseMove(event: MouseEvent): void {
    if (!this.resizing) {
      return;
    }

    const deltaX = event.clientX - this.resizeStartX;
    const requestedWidth = this.resizeStartWidth + deltaX;
    this.treePaneWidth = this.clampTreeWidth(requestedWidth);
  }

  @HostListener('document:mouseup')
  onMouseUp(): void {
    if (!this.resizing) {
      return;
    }

    this.stopResizing();
    this.persistTreePaneWidth();
    this.refreshLayout();
  }

  collapseAll(): void {
    this.schemaTree?.collapseAll();
    this.refreshLayout();
    this.changeDetectorRef.markForCheck();
  }

  @HostListener('window:resize')
  onWindowResize(): void {
    const clampedWidth = this.clampTreeWidth(this.treePaneWidth);
    if (clampedWidth !== this.treePaneWidth) {
      this.treePaneWidth = clampedWidth;
      this.persistTreePaneWidth();
      this.changeDetectorRef.markForCheck();
    }
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

  private clampTreeWidth(requestedWidth: number): number {
    const containerWidth = this.layoutContainer?.nativeElement.clientWidth ?? 1100;
    const detailsMinWidth = 320;
    const dynamicMaxWidth = Math.max(this.minTreePaneWidth, containerWidth - detailsMinWidth);
    const effectiveMax = Math.min(this.maxTreePaneWidth, dynamicMaxWidth);

    return Math.round(Math.max(this.minTreePaneWidth, Math.min(effectiveMax, requestedWidth)));
  }

  private stopResizing(): void {
    this.resizing = false;
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
  }

  private getStoredTreePaneWidth(): number {
    if (typeof window === 'undefined') {
      return 360;
    }

    const storedWidth = window.localStorage.getItem(this.treePaneWidthStorageKey);
    if (!storedWidth) {
      return 360;
    }

    const parsedWidth = Number(storedWidth);
    if (!Number.isFinite(parsedWidth)) {
      return 360;
    }

    return Math.round(parsedWidth);
  }

  private persistTreePaneWidth(): void {
    if (typeof window === 'undefined') {
      return;
    }

    window.localStorage.setItem(this.treePaneWidthStorageKey, String(this.treePaneWidth));
  }
}
