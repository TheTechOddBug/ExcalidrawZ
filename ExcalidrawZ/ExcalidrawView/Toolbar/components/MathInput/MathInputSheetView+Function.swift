//
//  MathInputSheetView+Function.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/19.
//

import SwiftUI
import ChocofordUI
import SFSafeSymbols

extension MathInputSheetView {
    var functionInspectorContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            functionInputPanel

            compactFunctionTemplates
        }
    }

    var functionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(String(localizable: .toolbarLatexMathFunctionPanelPickerTitle), selection: $functionPanelTab) {
                ForEach(MathFunctionPanelTab.allCases) { tab in
                    Text(tab.title)
                        .tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.regular)
            .mathNativeCapsuleSegmentedPicker()
            .frame(maxWidth: 360)

            switch functionPanelTab {
                case .input:
                    functionInputPanel
                case .preferences:
                    functionDrawingSettings
            }
        }
    }

    var functionInputPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localizable: .toolbarLatexMathFunctionsTitle).uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)

                Spacer()

                Button {
                    addFunctionExpression()
                } label: {
                    Label(String(localizable: .toolbarLatexMathAddFunctionButton), systemSymbol: .plus)
                        .labelStyle(.titleAndIcon)
                }
            }

            VStack(spacing: 9) {
                ForEach(functionExpressions) { expression in
                    functionExpressionRow(expression)
                }
            }
        }
    }

    func functionExpressionRow(_ expression: MathFunctionExpression) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hexString: expression.colorHex))
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.12))
                }

            TextField(
                "y = x",
                text: Binding(
                    get: {
                        functionExpressions.first(where: { $0.id == expression.id })?.expression ?? expression.expression
                    },
                    set: { newValue in
                        updateFunctionExpression(id: expression.id, expression: newValue)
                    }
                )
            )
            .font(.system(.body, design: .monospaced))
            .textFieldStyle(.roundedBorder)

            Button {
                removeFunctionExpression(id: expression.id)
            } label: {
                Image(systemSymbol: .xmark)
#if os(macOS)
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .contentShape(Circle())
#else
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
#endif
            }
#if os(macOS)
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
#endif
            .disabled(functionExpressions.count <= 1)
            .opacity(functionExpressions.count > 1 ? 1 : 0)
            .help(String(localizable: .toolbarLatexMathRemoveFunctionHelp))
        }
    }

    var compactFunctionTemplates: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localizable: .toolbarLatexMathTemplatesTitle).uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            VStack(spacing: 8) {
                ForEach(MathTemplate.functionTemplates) { template in
                    Button {
                        applyTemplate(template)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text(template.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text(template.latex)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .frame(minHeight: 78, maxHeight: 78, alignment: .topLeading)
                    }
                    .buttonStyle(MathTemplateCardButtonStyle())
                }
            }
        }
    }
}
