# VSC-Bridge MCP: Quick Agent Guide

**For AI agents with MCP tools already installed. Assumes you can see tool descriptions.**

---

## Critical Setup

```typescript
// ALWAYS verify bridge is ready before ANY operation
const status = await bridge_status();
if (!status.connected) {
  // Tell user to open VS Code with project
}
```

---

## The 5-Step Debug Pattern (Use This Every Time)

```typescript
// 1. ALWAYS start clean
await breakpoint_clear_project();

// 2. Set breakpoint where you want to pause
await breakpoint_set({ path: FILE, line: BREAKPOINT_LINE });

// 3. Debug the test (use test START line, not breakpoint line)
await test_debug_single({ path: FILE, line: TEST_START_LINE });

// 4. Inspect state when paused
const vars = await debug_list_variables({ scope: "local" });
const value = await debug_evaluate({ expression: "result.token" });

// 5. Step or continue
await debug_step_over();  // or debug_step_into, debug_continue
```

---

## Tool Selection Cheat Sheet

| Need | Use |
|------|-----|
| Debug a test | `test_debug_single` (PRIMARY TOOL) |
| See variables | `debug_list_variables` then `debug_evaluate` |
| Trace execution | `debug_step_over`, `debug_step_into`, `debug_step_out` |
| Find test failure | `dap_summary` → `dap_logs` → `dap_search` |
| Find exception | `dap_exceptions` (JS/C#) or `dap_search` (pytest) |
| Compare runs | `dap_compare` |

---

## Language Syntax (Critical!)

| Language | Length | Access | Tool |
|----------|--------|--------|------|
| **Python** | `len(items)` | `user.email` | pytest failures in **stdout** |
| **JavaScript** | `items.length` | `user?.email` | Jest failures in **stdout** |
| **C#** | `items.Count` | `user?.Email` | May pause at `[External Code]` (OK) |
| **Java** | `items.size()` | `user.getEmail()` | Object expansion limited |

---

## Critical Rules

### ✅ DO

1. **Clear breakpoints first**: `breakpoint_clear_project()` before every debug session
2. **Check prerequisites**: `bridge_status()` before operations, session exists before stepping
3. **Query DAP immediately**: `dap_summary()` right after test ends, before new session
4. **Use correct syntax**: Match language being debugged (Python vs JS vs C# vs Java)
5. **Inspect before continuing**: Always check variables when paused

### ❌ DON'T

1. **Skip clearing breakpoints** - Old breakpoints cause wrong pause locations
2. **Use breakpoint line for test_debug_single** - Use test START line instead
3. **Continue without inspecting** - You'll learn nothing
4. **Look for pytest failures in exceptions** - They're in stdout, use `dap_search`
5. **Start new session before querying DAP** - Data gets overwritten
6. **Set breakpoints on empty lines or comments** - They won't be hit
7. **Set breakpoint on variable assignment line and expect to read it** - Set AFTER the line or step over first

---

## Pytest/Jest Special Handling

**CRITICAL**: Test assertion failures are **NOT exception events** - they're in stdout.

```typescript
// ❌ WRONG - Won't find pytest/Jest failures
const exceptions = await dap_exceptions();

// ✅ CORRECT - Search stdout
const failures = await dap_search({
  pattern: "FAILED|assert.*==",
  category: "stdout"
});
```

---

## Breakpoint Best Practices

### Reading Variables After Assignment

**Critical Rule**: Breakpoints execute BEFORE the line. To read a variable, you must:

**Option 1: Set breakpoint on NEXT line**
```typescript
// Code:
// Line 10: const result = calculate();
// Line 11: const doubled = result * 2;

// ✅ CORRECT - Set breakpoint on line 11 to read 'result'
await breakpoint_set({ path: FILE, line: 11 });
await test_debug_single({ path: FILE, line: TEST_START });
const result = await debug_evaluate({ expression: "result" });  // Works!
```

**Option 2: Set breakpoint on assignment line, then step**
```typescript
// ✅ CORRECT - Set on line 10, step, then read
await breakpoint_set({ path: FILE, line: 10 });
await test_debug_single({ path: FILE, line: TEST_START });
await debug_step_over();  // Now result is assigned
const result = await debug_evaluate({ expression: "result" });  // Works!
```

**⚠️ Scope Warning**: Stepping over may exit the current function/scope. If you need to stay in scope, prefer Option 1.

### Invalid Breakpoint Locations

**❌ Will NOT work:**
- Empty lines (no code)
- Comment-only lines
- Closing braces `}` (some debuggers)
- Import/using statements (language-dependent)

**✅ Valid breakpoint locations:**
- Variable assignments
- Function calls
- Return statements
- Control flow statements (if, for, while)

---

## C# Special Handling

C# often pauses at `[External Code]` (line 0) instead of test code.

```typescript
// ✅ CORRECT - Accept [External Code] as valid pause
// Response: pauseLocation: { name: "[External Code]", line: 0 }
// This is EXPECTED - don't try to continue to "real" breakpoint
```

---

## Workflow Shortcuts

### Find Bug in Failing Test
```typescript
await breakpoint_clear_project();
await breakpoint_set({ path: SRC_FILE, line: SUSPICIOUS_LINE });
await test_debug_single({ path: TEST_FILE, line: TEST_START });
const vars = await debug_list_variables({ scope: "local" });
// Examine vars, step as needed
await debug_step_into();  // Trace into function
```

### Analyze What Went Wrong
```typescript
const summary = await dap_summary();  // Quick health check
if (summary.counts.exceptions > 0) {
  const exceptions = await dap_exceptions();  // For JS/C# crashes
}
const logs = await dap_logs({ count: 20 });  // Recent activity
const failures = await dap_search({ pattern: "FAILED|ERROR" });
```

### Trace Function Execution
```typescript
await breakpoint_set({ path: FILE, line: FUNCTION_START });
await debug_start({ launch: LAUNCH_CONFIG });
// Step through each line
await debug_step_over();
const vars = await debug_list_variables({ scope: "local" });
// Repeat stepping and inspecting
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Timeout errors | Increase `timeoutMs` parameter |
| Wrong pause location | Clear breakpoints first, check line number |
| Can't find failures | Use `dap_search` for pytest/Jest, not `dap_exceptions` |
| Wrong variable syntax | Use Python syntax in Python, JS syntax in JS, etc. |
| No session error | Must call `test_debug_single` or `debug_start` first |

---

## Advanced: Conditional Breakpoints

```typescript
// Only pause when condition true
await breakpoint_set({
  path: FILE,
  line: LINE,
  condition: "user.id > 100"  // Language-specific syntax
});

// Pause on Nth hit
await breakpoint_set({
  path: FILE,
  line: LINE,
  hitCondition: "10"  // Pause on 10th hit
});

// Log without pausing
await breakpoint_set({
  path: FILE,
  line: LINE,
  logMessage: "User: {user.id}"  // Log and continue
});
```

---

## Error Recovery

```typescript
try {
  await debug_evaluate({ expression: "user.email" });
} catch (error) {
  if (error.code === "E_NO_SESSION") {
    // Start session first
    await test_debug_single({ path: TEST, line: START });
  } else if (error.code === "E_TIMEOUT") {
    // Retry with longer timeout
    await debug_evaluate({ expression: "user.email", timeoutMs: 60000 });
  }
}
```

---

## Symbol Search: Fast Codebase Navigation

**Use `search_symbol_search` to quickly find classes, functions, methods WITHOUT reading files.**

### Quick Patterns

```typescript
// Find a specific class/function
await search_symbol_search({ query: "UserService" });

// Get all classes in workspace
await search_symbol_search({ query: "", kinds: "Class" });

// Get file structure/outline
await search_symbol_search({
  mode: "document",
  path: "src/services/auth.ts"
});

// Find all test functions
await search_symbol_search({
  query: "test",
  kinds: "Function,Method",
  limit: 50
});
```

### Symbol Kinds (case-sensitive)

Common: `Class`, `Interface`, `Function`, `Method`, `Property`, `Variable`, `Constant`
Special: `String` (Markdown headers), `Enum`, `EnumMember`, `Constructor`

### When to Use Symbol Search

| Instead of | Use Symbol Search |
|------------|-------------------|
| Reading 10 files to find a class | `query: "ClassName"` |
| Guessing file structure | `mode: "document"` for outline |
| Searching text for function names | `query: "funcName", kinds: "Function"` |
| Finding where class is defined | `query: "MyClass", kinds: "Class"` |

**Speed boost**: Symbol search is **instant** - no file reading needed. Use it BEFORE reading files.

### Example: Find Bug Location Fast

```typescript
// User: "The UserService class has a bug in the login method"

// 1. Find the class (instant)
const classResult = await search_symbol_search({
  query: "UserService",
  kinds: "Class"
});
// Returns: { location: { file: "src/services/user.ts", line: 15 } }

// 2. Get file outline to see all methods
const outline = await search_symbol_search({
  mode: "document",
  path: "src/services/user.ts"
});
// Returns all methods including login at line 42

// 3. Now read only the relevant section
// (You know exactly where to look!)
```

---

## Key Insights

1. **`test_debug_single` is your main tool** - Use for all test debugging
2. **Always start clean** - Clear breakpoints before every investigation
3. **Inspect when paused** - Variables tell you what's wrong
4. **pytest/Jest failures in stdout** - Not in exception events
5. **Language matters** - Use correct syntax for expressions
6. **Query DAP immediately** - Before starting new session
7. **Use symbol search first** - Find symbols instantly before reading files

---

## When to Use VSC-Bridge

**✅ USE FOR:**
- Debugging failing tests with unclear errors
- Understanding why function returns wrong value
- Tracing execution flow step-by-step
- Comparing passing vs failing runs

**❌ DON'T USE FOR:**
- Static code analysis (use file reading)
- Simple test runs (use bash to run pytest/jest)
- Code editing (use file editing tools)
- Performance profiling (not a profiler)

---

**Remember**: VSC-Bridge gives you runtime visibility. Use it to **explain WHY** code behaves incorrectly, not just to run tests.

For full details: See AGENTS.md
