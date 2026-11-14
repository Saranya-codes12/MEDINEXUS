import 'package:flutter/material.dart';

/// Lays stat cards out in rows (2 per row on phones, 4 on wide screens).
/// Every card in a row gets the same height and grows with its content,
/// so nothing overflows on small screens or large font sizes.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const StatGrid({super.key, required this.children, this.spacing = 10});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        final rows = <Widget>[];

        for (var i = 0; i < children.length; i += columns) {
          final slice = children.skip(i).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) SizedBox(width: spacing),
                    Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          );
          if (i + columns < children.length) rows.add(SizedBox(height: spacing));
        }

        return Column(children: rows);
      },
    );
  }
}