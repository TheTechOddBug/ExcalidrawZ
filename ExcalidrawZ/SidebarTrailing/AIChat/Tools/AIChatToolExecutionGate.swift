//
//  AIChatToolExecutionGate.swift
//  ExcalidrawZ
//

import LLMCore

enum AIChatToolExecutionGate {
    static func ensureAIEnabled() throws {
        guard AIChatAvailability.canUseAI else {
            throw ToolError.executionFailed("AI features are disabled.")
        }
    }
}

struct LockedContentProtectedTool: Tool {
    private let tool: any Tool

    init(_ tool: any Tool) {
        self.tool = tool
    }

    var name: String { tool.name }
    var displayName: String { tool.displayName }
    var description: String { tool.description }
    var inputSchema: ToolInputSchema { tool.inputSchema }
    var approvalRequirement: ApprovalRequirement { tool.approvalRequirement }

    func approvalPolicy(input: String) -> ApprovalPolicy {
        tool.approvalPolicy(input: input)
    }

    func execute(_ input: String, context: (any ChatInvocationContext)?) async throws -> ToolResult {
        if let lockedToolResult = try await LockedContentAIGuard.lockedToolResultIfNeeded(
            input: input,
            context: context,
            toolName: tool.name
        ) {
            return lockedToolResult
        }

        return try await LockedContentAIGuard.withProtectedContentAccessDenied {
            try await tool.execute(input, context: context)
        }
    }
}
