// Portions of this file are adapted from `flutter_staggered_grid_view`
// (https://github.com/letsar/flutter_staggered_grid_view), MIT License,
// Copyright (c) 2018 Romain Rastel.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const double _precisionErrorTolerance = 1e-10;

/// Controls the number of columns for a masonry sliver.
abstract class MasonryGridDelegate {
  const MasonryGridDelegate();

  int getCrossAxisCount(SliverConstraints constraints, double crossAxisSpacing);

  bool shouldRelayout(covariant MasonryGridDelegate oldDelegate);
}

/// A fixed number of columns.
class MasonryGridDelegateWithFixedCrossAxisCount extends MasonryGridDelegate {
  const MasonryGridDelegateWithFixedCrossAxisCount({
    required this.crossAxisCount,
  }) : assert(crossAxisCount > 0);

  final int crossAxisCount;

  @override
  int getCrossAxisCount(
    SliverConstraints constraints,
    double crossAxisSpacing,
  ) => crossAxisCount;

  @override
  bool shouldRelayout(MasonryGridDelegateWithFixedCrossAxisCount oldDelegate) =>
      oldDelegate.crossAxisCount != crossAxisCount;
}

/// As many columns as fit within [maxCrossAxisExtent].
class MasonryGridDelegateWithMaxCrossAxisExtent extends MasonryGridDelegate {
  const MasonryGridDelegateWithMaxCrossAxisExtent({
    required this.maxCrossAxisExtent,
  }) : assert(maxCrossAxisExtent > 0);

  final double maxCrossAxisExtent;

  @override
  int getCrossAxisCount(
    SliverConstraints constraints,
    double crossAxisSpacing,
  ) => (constraints.crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing))
      .ceil();

  @override
  bool shouldRelayout(MasonryGridDelegateWithMaxCrossAxisExtent oldDelegate) =>
      oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent;
}

/// Parent data for [RenderMasonryGrid] children.
class MasonryParentData extends SliverMultiBoxAdaptorParentData {
  int? crossAxisIndex;
  double? lastMainAxisExtent;

  void applyZero() {
    layoutOffset = 0.0;
    crossAxisIndex = 0;
  }

  void apply(MasonryParentData parentData) {
    layoutOffset = parentData.layoutOffset;
    crossAxisIndex = parentData.crossAxisIndex;
  }
}

/// A sliver that places children in a balanced masonry (waterfall) layout: each
/// child is placed in the currently-shortest column, which keeps columns
/// balanced like Pinterest.
class RenderMasonryGrid extends RenderSliverMultiBoxAdaptor {
  RenderMasonryGrid({
    required super.childManager,
    required MasonryGridDelegate gridDelegate,
    required double mainAxisSpacing,
    required double crossAxisSpacing,
  }) : assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       // ignore: prefer_initializing_formals
       _gridDelegate = gridDelegate,
       _mainAxisSpacing = mainAxisSpacing,
       _crossAxisSpacing = crossAxisSpacing;

  MasonryGridDelegate get gridDelegate => _gridDelegate;
  MasonryGridDelegate _gridDelegate;
  set gridDelegate(MasonryGridDelegate value) {
    if (_gridDelegate == value) return;
    if (value.runtimeType != _gridDelegate.runtimeType ||
        value.shouldRelayout(_gridDelegate)) {
      markNeedsLayout();
    }
    _gridDelegate = value;
  }

  double get mainAxisSpacing => _mainAxisSpacing;
  double _mainAxisSpacing;
  set mainAxisSpacing(double value) {
    if (_mainAxisSpacing == value) return;
    _mainAxisSpacing = value;
    markNeedsLayout();
  }

  double get crossAxisSpacing => _crossAxisSpacing;
  double _crossAxisSpacing;
  set crossAxisSpacing(double value) {
    if (_crossAxisSpacing == value) return;
    _crossAxisSpacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! MasonryParentData) {
      child.parentData = MasonryParentData();
    }
  }

  MasonryParentData _parentData(RenderObject child) =>
      child.parentData as MasonryParentData;

  double _stride = 0;
  int Function(int) _getCrossAxisIndex = (int index) => index;

  @override
  double childCrossAxisPosition(RenderBox child) {
    final crossAxisIndex = _parentData(child).crossAxisIndex!;
    return _getCrossAxisIndex(crossAxisIndex) * _stride;
  }

  final List<int> _previousCrossAxisIndexes = <int>[];
  final List<double> _previousMainAxisExtents = <double>[];

  @override
  bool addInitialChild({int index = 0, double layoutOffset = 0.0}) {
    final hasFirstChild = super.addInitialChild(
      index: index,
      layoutOffset: layoutOffset,
    );
    if (hasFirstChild) {
      _parentData(firstChild!).applyZero();
    }
    return hasFirstChild;
  }

  @override
  void collectGarbage(int leadingGarbage, int trailingGarbage) {
    int count = leadingGarbage;
    RenderBox? child = firstChild;
    while (count > 0 && child != null) {
      final crossAxisIndex = _parentData(child).crossAxisIndex;
      if (crossAxisIndex != null) {
        _previousCrossAxisIndexes.add(crossAxisIndex);
        _previousMainAxisExtents.add(paintExtentOf(child));
      }
      child = childAfter(child);
      count -= 1;
    }
    super.collectGarbage(leadingGarbage, trailingGarbage);
  }

  int _lastFirstVisibleChildIndex = 0;

  @override
  RenderBox? insertAndLayoutLeadingChild(
    BoxConstraints childConstraints, {
    bool parentUsesSize = false,
  }) {
    final child = super.insertAndLayoutLeadingChild(
      childConstraints,
      parentUsesSize: parentUsesSize,
    );
    if (child != null) {
      final parentData = _parentData(child);
      parentData.crossAxisIndex = _previousCrossAxisIndexes.isNotEmpty
          ? _previousCrossAxisIndexes.removeLast()
          : 0;
      parentData.lastMainAxisExtent = _previousMainAxisExtents.isNotEmpty
          ? _previousMainAxisExtents.removeLast()
          : 0;
    }
    return child;
  }

  int? _lastCrossAxisCount;

  @override
  void performLayout() {
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    final crossAxisCount = _gridDelegate.getCrossAxisCount(
      constraints,
      crossAxisSpacing,
    );

    _getCrossAxisIndex = axisDirectionIsReversed(constraints.crossAxisDirection)
        ? (int index) => crossAxisCount - index - 1
        : (int index) => index;

    _stride = (constraints.crossAxisExtent + crossAxisSpacing) / crossAxisCount;
    final childCrossAxisExtent = _stride - crossAxisSpacing;
    final childConstraints = constraints.asBoxConstraints(
      crossAxisExtent: childCrossAxisExtent,
    );

    final double scrollOffset =
        constraints.scrollOffset + constraints.cacheOrigin;
    assert(scrollOffset >= 0.0);
    final double remainingExtent = constraints.remainingCacheExtent;
    assert(remainingExtent >= 0.0);
    final double targetEndScrollOffset = scrollOffset + remainingExtent;
    int leadingGarbage = 0;
    int trailingGarbage = 0;
    bool reachedEnd = false;

    final scrollOffsets = List<double>.filled(crossAxisCount, 0.0);

    double positionChild(RenderBox child) {
      final crossAxisIndex = _smallestIndex(scrollOffsets);
      final parentData = _parentData(child);
      parentData.layoutOffset = scrollOffsets[crossAxisIndex];
      parentData.crossAxisIndex = crossAxisIndex;
      scrollOffsets[crossAxisIndex] =
          childScrollOffset(child)! + paintExtentOf(child) + mainAxisSpacing;
      return scrollOffsets[crossAxisIndex];
    }

    if (_lastCrossAxisCount != null && _lastCrossAxisCount != crossAxisCount) {
      _previousCrossAxisIndexes.clear();
      _previousMainAxisExtents.clear();

      if (firstChild != null) {
        final firstIndex = indexOf(firstChild!);
        if (firstIndex != 0) {
          final lastIndex = indexOf(lastChild!);
          collectGarbage(0, lastIndex - firstIndex + 1);
          scrollOffsets.fillRange(0, crossAxisCount, 0);
          addInitialChild();
          RenderBox? child = firstChild;
          child!.layout(childConstraints, parentUsesSize: true);
          int index = indexOf(firstChild!);
          double newPositionOfLastFirstChild = 0;

          while (child != null && index <= _lastFirstVisibleChildIndex) {
            positionChild(child);
            newPositionOfLastFirstChild = childScrollOffset(child)!;
            child = insertAndLayoutChild(
              childConstraints,
              after: child,
              parentUsesSize: true,
            );
            index++;
          }

          final scrollOffsetCorrection =
              newPositionOfLastFirstChild - scrollOffset;
          if (scrollOffsetCorrection != 0) {
            geometry = SliverGeometry(
              scrollOffsetCorrection: scrollOffsetCorrection,
            );
            return;
          }
        }
      }
    }

    _lastCrossAxisCount = crossAxisCount;

    if (firstChild == null) {
      if (!addInitialChild()) {
        geometry = SliverGeometry.zero;
        childManager.didFinishLayout();
        return;
      }
    }

    RenderBox? leadingChildWithLayout, trailingChildWithLayout;

    RenderBox? earliestUsefulChild = firstChild;

    if (childScrollOffset(firstChild!) == null) {
      int leadingChildrenWithoutLayoutOffset = 0;
      while (earliestUsefulChild != null &&
          childScrollOffset(earliestUsefulChild) == null) {
        earliestUsefulChild = childAfter(earliestUsefulChild);
        leadingChildrenWithoutLayoutOffset += 1;
      }
      collectGarbage(leadingChildrenWithoutLayoutOffset, 0);
      if (firstChild == null) {
        if (!addInitialChild()) {
          geometry = SliverGeometry.zero;
          childManager.didFinishLayout();
          return;
        }
      }
    }

    scrollOffsets.fillRange(0, crossAxisCount, double.infinity);

    MasonryParentData computeFirstChildParentData() {
      final firstChildParentData = _parentData(firstChild!);
      final mainAxisExtent =
          firstChildParentData.lastMainAxisExtent! + mainAxisSpacing;
      final crossAxisIndex = firstChildParentData.crossAxisIndex!;

      double offset = scrollOffsets[crossAxisIndex] - mainAxisExtent;

      for (int i = 0; i < crossAxisCount; i++) {
        if (i == crossAxisIndex) continue;
        final otherOffset = scrollOffsets[i];
        if ((offset - otherOffset).abs() < _precisionErrorTolerance) {
          offset = otherOffset;
          break;
        }
      }

      return MasonryParentData()
        ..layoutOffset = offset
        ..crossAxisIndex = crossAxisIndex;
    }

    RenderBox? child = firstChild;

    if (child != null && indexOf(child) == 0) {
      _parentData(child).crossAxisIndex = 0;
    }

    while (child != null && scrollOffsets.any((x) => x.isInfinite)) {
      final index = _parentData(child).crossAxisIndex;
      if (index != null) {
        final offset = childScrollOffset(child)!;
        if (scrollOffsets[index] == double.infinity) {
          scrollOffsets[index] = offset;
        }
      }
      child = childAfter(child);
    }

    earliestUsefulChild = firstChild;
    while (scrollOffsets.any((x) => x > scrollOffset)) {
      earliestUsefulChild = insertAndLayoutLeadingChild(
        childConstraints,
        parentUsesSize: true,
      );

      if (earliestUsefulChild == null) {
        final childParentData = _parentData(firstChild!);
        childParentData.layoutOffset = 0;

        if (scrollOffset == 0) {
          firstChild!.layout(childConstraints, parentUsesSize: true);
          earliestUsefulChild = firstChild;
          leadingChildWithLayout = earliestUsefulChild;
          trailingChildWithLayout ??= earliestUsefulChild;
          break;
        } else {
          geometry = SliverGeometry(scrollOffsetCorrection: -scrollOffset);
          return;
        }
      }

      final earliestScrollOffset = scrollOffsets.reduce(math.min);

      if (earliestScrollOffset < -_precisionErrorTolerance) {
        geometry = SliverGeometry(
          scrollOffsetCorrection: -earliestScrollOffset,
        );
        final childParentData = _parentData(firstChild!);
        final compute = computeFirstChildParentData();
        childParentData.apply(compute);
        childParentData.layoutOffset = 0;
        return;
      }

      final firstChildParentData = computeFirstChildParentData();
      final childParentData = _parentData(earliestUsefulChild);
      childParentData.apply(firstChildParentData);
      scrollOffsets[firstChildParentData.crossAxisIndex!] =
          firstChildParentData.layoutOffset!;
      leadingChildWithLayout = earliestUsefulChild;
      trailingChildWithLayout ??= earliestUsefulChild;
    }

    if (scrollOffset < _precisionErrorTolerance) {
      while (indexOf(firstChild!) > 0) {
        final childParentData = _parentData(firstChild!);
        earliestUsefulChild = insertAndLayoutLeadingChild(
          childConstraints,
          parentUsesSize: true,
        );
        final firstChildParentData = computeFirstChildParentData();
        childParentData.apply(firstChildParentData);
        final firstChildScrollOffset = firstChildParentData.layoutOffset!;
        if (firstChildScrollOffset < -_precisionErrorTolerance) {
          geometry = SliverGeometry(
            scrollOffsetCorrection: -firstChildScrollOffset,
          );
          return;
        }
      }
    }

    if (leadingChildWithLayout == null) {
      earliestUsefulChild!.layout(childConstraints, parentUsesSize: true);
      leadingChildWithLayout = earliestUsefulChild;
      trailingChildWithLayout = earliestUsefulChild;
    }

    final leadingScrollOffset = scrollOffsets.reduce(math.min);

    bool inLayoutRange = true;
    child = earliestUsefulChild;
    int index = indexOf(child!);

    scrollOffsets[_parentData(child).crossAxisIndex!] =
        childScrollOffset(child)! + paintExtentOf(child) + mainAxisSpacing;

    for (int i = 0; i < scrollOffsets.length; i++) {
      if (scrollOffsets[i] == double.infinity) {
        scrollOffsets[i] = 0.0;
      }
    }

    bool foundFirstVisibleChild = scrollOffsets.any(
      (offset) => offset >= constraints.scrollOffset,
    );
    _lastFirstVisibleChildIndex = indexOf(firstChild!);

    bool advance() {
      if (child == trailingChildWithLayout) {
        inLayoutRange = false;
      }
      child = childAfter(child!);
      if (child == null) {
        inLayoutRange = false;
      }
      index += 1;
      if (!inLayoutRange) {
        if (child == null || indexOf(child!) != index) {
          child = insertAndLayoutChild(
            childConstraints,
            after: trailingChildWithLayout,
            parentUsesSize: true,
          );
          if (child == null) {
            return false;
          }
        } else {
          child!.layout(childConstraints, parentUsesSize: true);
        }
        trailingChildWithLayout = child;
      }
      positionChild(child!);
      if (!foundFirstVisibleChild &&
          scrollOffsets.any((offset) => offset >= constraints.scrollOffset)) {
        foundFirstVisibleChild = true;
        _lastFirstVisibleChildIndex = indexOf(child!);
      }
      return true;
    }

    while (scrollOffsets.every(
      (offset) => offset - mainAxisSpacing < scrollOffset,
    )) {
      leadingGarbage += 1;
      if (!advance()) {
        collectGarbage(leadingGarbage - 1, 0);
        final double extent = scrollOffsets.reduce(math.max) - mainAxisSpacing;
        geometry = SliverGeometry(scrollExtent: extent, maxPaintExtent: extent);
        return;
      }
    }

    while (scrollOffsets.any(
      (offset) => offset - mainAxisSpacing < targetEndScrollOffset,
    )) {
      if (!advance()) {
        reachedEnd = true;
        break;
      }
    }

    if (child != null) {
      child = childAfter(child!);
      while (child != null) {
        trailingGarbage += 1;
        child = childAfter(child!);
      }
    }

    collectGarbage(leadingGarbage, trailingGarbage);

    final endScrollOffset = scrollOffsets.reduce(math.max) - mainAxisSpacing;
    final double estimatedMaxScrollOffset;
    if (reachedEnd) {
      estimatedMaxScrollOffset = endScrollOffset;
    } else {
      estimatedMaxScrollOffset = childManager.estimateMaxScrollOffset(
        constraints,
        firstIndex: indexOf(firstChild!),
        lastIndex: indexOf(lastChild!),
        leadingScrollOffset: leadingScrollOffset,
        trailingScrollOffset: endScrollOffset,
      );
    }
    final double paintExtent = calculatePaintOffset(
      constraints,
      from: leadingScrollOffset,
      to: endScrollOffset,
    );
    final double cacheExtent = calculateCacheOffset(
      constraints,
      from: leadingScrollOffset,
      to: endScrollOffset,
    );
    final double targetEndScrollOffsetForPaint =
        constraints.scrollOffset + constraints.remainingPaintExtent;
    geometry = SliverGeometry(
      scrollExtent: estimatedMaxScrollOffset,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: estimatedMaxScrollOffset,
      hasVisualOverflow:
          endScrollOffset > targetEndScrollOffsetForPaint ||
          constraints.scrollOffset > 0.0,
    );

    if (estimatedMaxScrollOffset == endScrollOffset) {
      childManager.setDidUnderflow(true);
    }
    childManager.didFinishLayout();
  }

  static int _smallestIndex(List<double> values) {
    int index = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] < values[index]) index = i;
    }
    return index;
  }
}

/// A sliver that places children in a balanced masonry (waterfall) layout.
class SliverMasonryGrid extends SliverMultiBoxAdaptorWidget {
  const SliverMasonryGrid({
    super.key,
    required super.delegate,
    required this.gridDelegate,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
  }) : assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0);

  SliverMasonryGrid.count({
    Key? key,
    required int crossAxisCount,
    required IndexedWidgetBuilder itemBuilder,
    int? childCount,
    double mainAxisSpacing = 0,
    double crossAxisSpacing = 0,
  }) : this(
         key: key,
         delegate: SliverChildBuilderDelegate(
           itemBuilder,
           childCount: childCount,
         ),
         gridDelegate: MasonryGridDelegateWithFixedCrossAxisCount(
           crossAxisCount: crossAxisCount,
         ),
         mainAxisSpacing: mainAxisSpacing,
         crossAxisSpacing: crossAxisSpacing,
       );

  SliverMasonryGrid.extent({
    Key? key,
    required double maxCrossAxisExtent,
    required IndexedWidgetBuilder itemBuilder,
    int? childCount,
    double mainAxisSpacing = 0,
    double crossAxisSpacing = 0,
  }) : this(
         key: key,
         delegate: SliverChildBuilderDelegate(
           itemBuilder,
           childCount: childCount,
         ),
         gridDelegate: MasonryGridDelegateWithMaxCrossAxisExtent(
           maxCrossAxisExtent: maxCrossAxisExtent,
         ),
         mainAxisSpacing: mainAxisSpacing,
         crossAxisSpacing: crossAxisSpacing,
       );

  final MasonryGridDelegate gridDelegate;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  @override
  RenderMasonryGrid createRenderObject(BuildContext context) {
    final SliverMultiBoxAdaptorElement element =
        context as SliverMultiBoxAdaptorElement;
    return RenderMasonryGrid(
      childManager: element,
      gridDelegate: gridDelegate,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMasonryGrid renderObject,
  ) {
    renderObject
      ..gridDelegate = gridDelegate
      ..mainAxisSpacing = mainAxisSpacing
      ..crossAxisSpacing = crossAxisSpacing;
  }
}

/// A scrollable masonry (waterfall) grid, analogous to [GridView].
class MasonryGridView extends BoxScrollView {
  MasonryGridView.count({
    super.key,
    super.scrollDirection,
    super.reverse,
    super.controller,
    super.primary,
    super.physics,
    super.shrinkWrap,
    super.padding,
    required int crossAxisCount,
    required this.itemBuilder,
    this.itemCount,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
  }) : gridDelegate = MasonryGridDelegateWithFixedCrossAxisCount(
         crossAxisCount: crossAxisCount,
       ),
       super();

  final MasonryGridDelegate gridDelegate;
  final IndexedWidgetBuilder itemBuilder;
  final int? itemCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  @override
  Widget buildChildLayout(BuildContext context) {
    return SliverMasonryGrid(
      delegate: SliverChildBuilderDelegate(itemBuilder, childCount: itemCount),
      gridDelegate: gridDelegate,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
    );
  }
}
