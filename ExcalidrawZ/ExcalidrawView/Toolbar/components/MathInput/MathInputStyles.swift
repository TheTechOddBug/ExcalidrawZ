//
//  MathInputStyles.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/19.
//

import SwiftUI

struct MathTokenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(configuration.isPressed ? 0.16 : 0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(configuration.isPressed ? 0.3 : 0.16))
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct MathTemplateCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(configuration.isPressed ? 0.13 : 0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(configuration.isPressed ? 0.28 : 0.13))
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct MathInlineCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 30, height: 30)
            .background {
                MathInlineCircleButtonBackground(isPressed: configuration.isPressed)
            }
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

struct MathInlineGenerateButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background {
                MathInlineCapsuleButtonBackground(isPressed: configuration.isPressed)
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct MathInlineCircleButtonBackground: View {
    let isPressed: Bool

    var body: some View {
        Circle()
            .fill(.clear)
            .background {
                if #available(macOS 26.0, iOS 26.0, *) {
                    Circle()
                        .fill(.clear)
                        .glassEffect(.regular.interactive(), in: Circle())
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.primary.opacity(isPressed ? 0.24 : 0.10))
            }
    }
}

private struct MathInlineCapsuleButtonBackground: View {
    let isPressed: Bool

    var body: some View {
        Capsule()
            .fill(.clear)
            .background {
                if #available(macOS 26.0, iOS 26.0, *) {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.regular.interactive(), in: Capsule())
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(isPressed ? 0.24 : 0.10))
            }
    }
}

struct MathAIDynamicEditorBackground: View {
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 7) / 7
            let palette = AIAppearancePalette.generatingPromptInputPalette(for: colorScheme)
            let gradient = AngularGradient(
                colors: palette.gradientStops,
                center: .center,
                angle: .degrees(phase * 360)
            )

            ZStack {
                if #available(macOS 26.0, iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                }

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(gradient)
                    .opacity(colorScheme == .dark ? 0.08 : 0.055)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(gradient, lineWidth: 1.2)
                    .opacity(palette.borderOpacity)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(gradient, lineWidth: 10)
                    .blur(radius: 9)
                    .opacity(palette.innerGlowBase * 0.5)
            }
        }
    }
}

extension View {
    @ViewBuilder
    func mathNativeCapsuleSegmentedPicker() -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            self
                .buttonBorderShape(.capsule)
                .containerShape(.capsule)
        } else {
            self
        }
    }

#if os(macOS)
    @ViewBuilder
    func mathInputInspector<InspectorContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> InspectorContent
    ) -> some View {
        if #available(macOS 14.0, *) {
            self.inspector(isPresented: isPresented) {
                content()
                    .inspectorColumnWidth(min: 260, ideal: 300, max: 360)
            }
        } else {
            self
        }
    }
#endif
}
