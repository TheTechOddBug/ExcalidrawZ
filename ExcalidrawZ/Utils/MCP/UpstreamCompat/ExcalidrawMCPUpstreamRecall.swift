//
//  ExcalidrawMCPUpstreamRecall.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/14.
//

import Foundation

enum ExcalidrawMCPUpstreamRecall {
    static let cheatSheet = """
    # ExcalidrawZ MCP Drawing Reference

    Call `create_view` with an `elements` argument containing a compact JSON array string.

    ## Element basics
    Every drawable element needs `type`, `id`, `x`, `y`, `width`, and `height`.
    Supported first-pass types: `rectangle`, `ellipse`, `diamond`, `text`, `arrow`, `line`, `freedraw`, and `image`.

    Use stable, unique ids. Array order controls z-order: earlier elements are behind later elements.

    ## Labeled shapes
    Prefer a shape with a `label` object instead of separate centered text when possible:

    ```json
    {
      "type": "rectangle",
      "id": "start",
      "x": 100,
      "y": 100,
      "width": 220,
      "height": 90,
      "backgroundColor": "#a5d8ff",
      "fillStyle": "solid",
      "roundness": { "type": 3 },
      "label": { "text": "Start", "fontSize": 20 }
    }
    ```

    ## Arrows
    Use `points` as offsets from the arrow's `x` and `y`.

    ```json
    {
      "type": "arrow",
      "id": "a1",
      "x": 320,
      "y": 145,
      "width": 180,
      "height": 0,
      "points": [[0, 0], [180, 0]],
      "endArrowhead": "arrow"
    }
    ```

    ## Pseudo-elements
    `cameraUpdate` changes the displayed viewport and is not drawn:

    ```json
    { "type": "cameraUpdate", "width": 800, "height": 600, "x": 0, "y": 0 }
    ```

    Use 4:3 camera sizes such as 400x300, 600x450, 800x600, 1200x900, or 1600x1200.

    `delete` removes elements by id when used with `restoreCheckpoint`:

    ```json
    { "type": "delete", "ids": "old_box,old_arrow" }
    ```

    `restoreCheckpoint` starts from an earlier checkpoint returned by `create_view`:

    ```json
    { "type": "restoreCheckpoint", "id": "checkpoint_id" }
    ```

    ## Readability rules
    - Start with a `cameraUpdate`.
    - Use fontSize 16 or larger for body text and 20 or larger for headings.
    - Keep 20-30 px gaps between nearby shapes.
    - Prefer fewer, larger elements over many tiny elements.
    - Put background zones first, then shapes, labels, arrows, and decorative details last.

    ## Palette
    Useful stroke colors: blue #4a9eed, amber #f59e0b, green #22c55e, red #ef4444, purple #8b5cf6, cyan #06b6d4.
    Useful fills: light blue #a5d8ff, light green #b2f2bb, light orange #ffd8a8, light purple #d0bfff, light red #ffc9c9, light yellow #fff3bf, light teal #c3fae8.
    """
}
