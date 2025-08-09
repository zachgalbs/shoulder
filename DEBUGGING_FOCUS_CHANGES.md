# Lenient Debugging Focus Implementation

## Summary
Modified the MLX model judging logic to be more lenient when the user's focus is set to "Debugging". The system now automatically considers any code-related activity as aligned with the debugging focus.

## Changes Made

### 1. MLXLLMManager.swift - Prompt Enhancement
- Added explicit instruction in the LLM prompt to treat "Debugging" focus with code evidence as aligned
- Line 162: Added IMPORTANT RULE for debugging focus leniency

### 2. MLXLLMManager.swift - Code Detection Function
- Added `detectCodeEvidence()` function (lines 248-255)
- Detects development applications (Xcode, VSCode, Terminal, etc.)
- Identifies programming keywords and syntax
- Returns true if at least 2 code-related indicators are found

### 3. MLXLLMManager.swift - Result Processing
- Lines 225-237: Added post-processing logic to override model decisions
- If focus is "Debugging" and code is detected, forces is_valid to true
- Sets minimum confidence of 75% for overridden decisions
- Logs when lenient rule is applied

### 4. MLXLLMManager.swift - Fallback Logic
- Lines 191-205: Enhanced fallback parsing for when JSON parsing fails
- Applies same lenient debugging rule in fallback scenarios
- Sets confidence to 85% when debugging + code evidence detected

## Behavior Changes

### Before
- Model strictly evaluated if activity matched the stated focus
- "Debugging" focus required explicit debugging activities
- Could mark code browsing or documentation reading as off-focus

### After
- When focus is "Debugging", ANY code-related activity is considered on-focus:
  - Using development tools (Xcode, VSCode, Terminal)
  - Viewing code in any application (even Safari/Chrome)
  - Reading technical documentation with code snippets
  - Running terminal commands
- Other focus types maintain strict evaluation
- Provides clearer feedback about why activity was considered aligned

## Testing
Created test scenarios demonstrating the new behavior:
- Debugging + Xcode = ✅ PASS
- Debugging + Safari with code = ✅ PASS  
- Debugging + Terminal commands = ✅ PASS
- Debugging + Messages (no code) = ❌ FAIL
- Writing code + VSCode = ✅ PASS (normal)
- Writing code + Slack = ❌ FAIL (normal strict)

## Impact
Users who set their focus to "Debugging" will now have a more forgiving experience that recognizes the broad nature of debugging work, including:
- Looking up documentation
- Browsing Stack Overflow
- Reading code in any context
- Using any development tools