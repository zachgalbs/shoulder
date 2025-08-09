//
//  test_debugging_focus.swift
//  Test script to demonstrate lenient debugging focus behavior
//

import Foundation

// Test scenarios to verify the lenient debugging focus rule

struct TestScenario {
    let name: String
    let focus: String
    let appName: String
    let windowTitle: String
    let ocrText: String
    let expectedResult: Bool
    let explanation: String
}

let testScenarios = [
    TestScenario(
        name: "Debugging focus with clear code",
        focus: "Debugging",
        appName: "Xcode",
        windowTitle: "ContentView.swift",
        ocrText: """
        func calculateSum(a: Int, b: Int) -> Int {
            return a + b
        }
        """,
        expectedResult: true,
        explanation: "Should pass - clear code with debugging focus"
    ),
    
    TestScenario(
        name: "Debugging focus with minimal code hints",
        focus: "Debugging",
        appName: "Safari",
        windowTitle: "Google Search",
        ocrText: """
        Search results for: swift array filter
        
        How to use filter() with Swift arrays
        let numbers = [1, 2, 3, 4, 5]
        let evens = numbers.filter { $0 % 2 == 0 }
        """,
        expectedResult: true,
        explanation: "Should pass - has code snippets even though in Safari"
    ),
    
    TestScenario(
        name: "Debugging focus with terminal output",
        focus: "Debugging",
        appName: "Terminal",
        windowTitle: "bash",
        ocrText: """
        $ git status
        On branch main
        $ npm run test
        """,
        expectedResult: true,
        explanation: "Should pass - terminal commands are code-related"
    ),
    
    TestScenario(
        name: "Debugging focus without code",
        focus: "Debugging",
        appName: "Messages",
        windowTitle: "Chat",
        ocrText: """
        Hey, how's it going?
        Pretty good, just having lunch. You?
        Same here, what did you get?
        """,
        expectedResult: false,
        explanation: "Should fail - no code evidence in chat"
    ),
    
    TestScenario(
        name: "Writing code focus with code",
        focus: "Writing code",
        appName: "Visual Studio Code",
        windowTitle: "index.js",
        ocrText: """
        const express = require('express');
        const app = express();
        app.listen(3000);
        """,
        expectedResult: true,
        explanation: "Should pass - normal focus matching"
    ),
    
    TestScenario(
        name: "Writing code focus without code",
        focus: "Writing code",
        appName: "Slack",
        windowTitle: "#general",
        ocrText: """
        Team meeting at 3pm today
        Don't forget to submit your timesheets
        """,
        expectedResult: false,
        explanation: "Should fail - normal strict matching for non-debugging focus"
    )
]

print("""
╔════════════════════════════════════════════════════════╗
║     Testing Lenient Debugging Focus Behavior          ║
╚════════════════════════════════════════════════════════╝

The model judging has been updated with the following rules:

1. LENIENT RULE: If user focus is "Debugging" and there's ANY
   evidence of code, the activity is considered ALIGNED.
   
2. Code evidence includes:
   - Development app usage (Xcode, VSCode, Terminal, etc.)
   - Programming keywords (function, class, import, etc.)
   - Code syntax (brackets, arrows, operators)
   
3. For other focus types, the normal strict rules apply.

Test Scenarios:
═══════════════

""")

for (index, scenario) in testScenarios.enumerated() {
    print("""
    \(index + 1). \(scenario.name)
       Focus: "\(scenario.focus)"
       App: \(scenario.appName)
       Expected: \(scenario.expectedResult ? "✅ PASS" : "❌ FAIL")
       Reason: \(scenario.explanation)
    
    """)
}

print("""
═══════════════════════════════════════════════════════════

Implementation Changes Made:
───────────────────────────

1. Updated MLX prompt to include debugging focus rule
2. Added detectCodeEvidence() function to identify code
3. Modified result processing to override model decisions
   when debugging focus + code evidence is detected
4. Fallback logic also applies lenient debugging rule

These changes ensure that users with "Debugging" focus
will have more lenient evaluation when any code-related
content is present on their screen.
""")