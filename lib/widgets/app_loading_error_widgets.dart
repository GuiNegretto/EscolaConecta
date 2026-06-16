import 'package:flutter/material.dart';

// ── App Loading Indicator (Inline) ──────────────────────────────────────────
/// Animated loading indicator for buttons, cards, and inline content.
/// Backed by [AppThreeDotLoader] — the class is kept for backward
/// compatibility with existing call sites that still construct it directly.
class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  // Kept for API compatibility; the three-dot loader uses its own
  // sequenced timing and ignores this value.
  final Duration animationDuration;

  const AppLoadingIndicator({
    super.key,
    this.size = 24,
    this.color,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  Widget build(BuildContext context) {
    // The legacy `size` referred to the school-icon diameter. Map it to a
    // comparable dot diameter so existing call sites scale sensibly.
    return AppThreeDotLoader(
      size: size / 3,
      color: color,
    );
  }
}

// ── App Loading Overlay ─────────────────────────────────────────────────────
/// Animated overlay that sits above content with a pulsing icon and optional message.
/// Respects dark/light theme with semi-transparent background.
class AppLoadingOverlay extends StatefulWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Duration animationDuration;

  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.animationDuration = const Duration(milliseconds: 500),
  });

  @override
  State<AppLoadingOverlay> createState() => _AppLoadingOverlayState();
}

class _AppLoadingOverlayState extends State<AppLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    if (widget.isLoading) {
      _fadeController.forward();
    }
  }

  @override
  void didUpdateWidget(AppLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _fadeController.forward();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _fadeController.reverse();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.black.withOpacity(0.6)
        : Colors.black.withOpacity(0.5);

    return Stack(
      children: [
        widget.child,
        if (widget.isLoading)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: bgColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLoadingIndicator(
                      size: 48,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    if (widget.message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.message!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── App Full Screen Loader ──────────────────────────────────────────────────
/// Full-page loading screen for splash transitions and initial app load.
/// Displays the three-dot loader plus optional title and subtitle.
class AppFullScreenLoader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  // Kept for API compatibility with the previous StatefulWidget signature;
  // the three-dot loader handles its own timing.
  final Duration animationDuration;

  const AppFullScreenLoader({
    super.key,
    this.title,
    this.subtitle,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppThreeDotLoader(
              size: 18,
              color: Theme.of(context).colorScheme.secondary,
            ),
            if (title != null) ...[
              const SizedBox(height: 32),
              Text(
                title!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── App Error Dialog ────────────────────────────────────────────────────────
/// Modal error dialog with icon, title, message, and OK button.
/// Call via: AppErrorDialog.show(context, 'Error message')
class AppErrorDialog extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback? onDismiss;
  final String buttonText;

  const AppErrorDialog({
    super.key,
    this.title = 'Ops, algo deu errado',
    required this.message,
    this.onDismiss,
    this.buttonText = 'OK',
  });

  /// Show error dialog from anywhere in the app
  static Future<void> show(
    BuildContext context, {
    String title = 'Ops, algo deu errado',
    required String message,
    VoidCallback? onDismiss,
    String buttonText = 'OK',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppErrorDialog(
        title: title,
        message: message,
        onDismiss: onDismiss,
        buttonText: buttonText,
      ),
    );
  }

  @override
  State<AppErrorDialog> createState() => _AppErrorDialogState();
}

class _AppErrorDialogState extends State<AppErrorDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 32,
            ),
          ),
          title: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            widget.message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDismiss?.call();
                },
                child: Text(widget.buttonText),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.all(16),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}

// ── App Error State (Inline) ────────────────────────────────────────────────
/// Inline error state for list screens with icon, message, and retry button.
/// Used when data fails to load to show user-friendly error state.
class AppErrorState extends StatelessWidget {
  final String message;
  final String retryButtonText;
  final VoidCallback onRetry;
  final IconData? iconData;
  final bool isNetworkError;

  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryButtonText = 'Tentar novamente',
    this.iconData,
    this.isNetworkError = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = iconData ??
        (isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .error
                  .withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryButtonText),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Loading Button Indicator ─────────────────────────────────────────
/// Replaces CircularProgressIndicator in button states for cleaner appearance.
class AppLoadingButtonIndicator extends StatefulWidget {
  final Color? color;
  final double size;

  const AppLoadingButtonIndicator({
    super.key,
    this.color,
    this.size = 16,
  });

  @override
  State<AppLoadingButtonIndicator> createState() =>
      _AppLoadingButtonIndicatorState();
}

class _AppLoadingButtonIndicatorState extends State<AppLoadingButtonIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.color ?? Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Animated Three Dot Loader ───────────────────────────────────────────────
/// Modern three-dot animated loader that pulses sequentially.
/// Creates a smooth, professional loading animation.
/// Works on both Web and Android.
class AppThreeDotLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final double dotSpacing;
  final Duration animationDuration;

  const AppThreeDotLoader({
    super.key,
    this.size = 12,
    this.color,
    this.dotSpacing = 8,
    this.animationDuration = const Duration(milliseconds: 600),
  });

  @override
  State<AppThreeDotLoader> createState() => _AppThreeDotLoaderState();
}

class _AppThreeDotLoaderState extends State<AppThreeDotLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration * 3, // 3 dots * duration
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.secondary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Calculate the animation phase for each dot
            // Each dot starts its pulse 1/3 of the way through the cycle
            final phase = (_controller.value - (index / 3)) % 1.0;
            final scale = _calculateDotScale(phase);

            return Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : widget.dotSpacing,
              ),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4 * scale),
                        blurRadius: widget.size * scale,
                        spreadRadius: widget.size * 0.2 * scale,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _calculateDotScale(double phase) {
    // Creates a pulsing effect that grows and shrinks
    // Phase goes from 0 to 1
    if (phase < 0.5) {
      // Grow from 0.8 to 1.2
      return 0.8 + (phase * 0.8);
    } else {
      // Shrink from 1.2 to 0.8
      return 1.2 - ((phase - 0.5) * 0.8);
    }
  }
}

// ── Three Dot Loader Overlay ───────────────────────────────────────────────
/// Full-screen loading overlay with three-dot animation and optional message.
class AppThreeDotOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? dotColor;

  const AppThreeDotOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.black.withOpacity(0.7)
        : Colors.black.withOpacity(0.5);

    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: bgColor,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppThreeDotLoader(
                    size: 14,
                    color: dotColor ?? Colors.white,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      message!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Three Dot Full Screen Loader ─────────────────────────────────────────
/// Full-screen loading screen for splash transitions using three-dot animation.
class AppThreeDotSplashLoader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? dotColor;

  const AppThreeDotSplashLoader({
    super.key,
    this.title,
    this.subtitle,
    this.backgroundColor,
    this.textColor,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBgColor = Theme.of(context).scaffoldBackgroundColor;
    final defaultTextColor = Theme.of(context).textTheme.headlineSmall?.color;
    final defaultDotColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: backgroundColor ?? defaultBgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppThreeDotLoader(
              size: 16,
              color: dotColor ?? defaultDotColor,
            ),
            if (title != null) ...[
              const SizedBox(height: 32),
              Text(
                title!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor ?? defaultTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor ?? defaultTextColor?.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
