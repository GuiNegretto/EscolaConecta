import 'package:flutter/material.dart';

class SkeletonContainer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonContainer({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius,
  });

  @override
  State<SkeletonContainer> createState() => _SkeletonContainerState();
}

class _SkeletonContainerState extends State<SkeletonContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1, end: 2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ],
              colors: [
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final bool showFooter;

  const SkeletonCard({
    super.key,
    this.showFooter = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            Row(
              children: [
                const SkeletonContainer(
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonContainer(
                        height: 16,
                        width: MediaQuery.of(context).size.width * 0.4,
                      ),
                      const SizedBox(height: 8),
                      const SkeletonContainer(
                        height: 12,
                        width: 100,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Parents chips skeleton
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SkeletonContainer(
                  width: MediaQuery.of(context).size.width * 0.3,
                  height: 32,
                  borderRadius: BorderRadius.circular(16),
                ),
                SkeletonContainer(
                  width: MediaQuery.of(context).size.width * 0.3,
                  height: 32,
                  borderRadius: BorderRadius.circular(16),
                ),
              ],
            ),
            if (showFooter) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SkeletonContainer(
                    width: 80,
                    height: 36,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  SkeletonContainer(
                    width: 80,
                    height: 36,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  SkeletonContainer(
                    width: 40,
                    height: 36,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const SkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonCard(),
    );
  }
}
