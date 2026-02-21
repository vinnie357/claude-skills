# Slidev Code Blocks Reference

## Shiki Syntax Highlighting

Slidev uses Shiki for syntax highlighting. Specify the language after the opening code fence:

````markdown
```ts
const greeting = 'hello'
console.log(greeting)
```
````

All languages supported by Shiki are available.

## Line Highlighting

Highlight specific lines using curly braces after the language:

````markdown
```ts {2,3}
function add(
  a: number,  // highlighted
  b: number   // highlighted
) {
  return a + b
}
```
````

### Line Ranges

```
{1}       — single line
{2,5}     — lines 2 and 5
{1-3}     — lines 1 through 3
{1-3,5}   — lines 1 through 3, and line 5
```

### Click-Based Highlighting

Highlight different lines on each click using `|`:

````markdown
```ts {2-3|5|all}
function add(
  a: number,  // highlighted on click 1
  b: number   // highlighted on click 1
) {
  return a + b  // highlighted on click 2
}
// all lines highlighted on click 3
```
````

### Placeholder Syntax

Use `{*}` as a placeholder for line highlighting when combined with other options:

````markdown
```ts {*}{maxHeight:'100px'}
// Code with scroll and default highlighting
```
````

### At and Finally

Control initial and final highlight states:

````markdown
```ts {2,3|5}{at:0}
// Lines 2,3 highlighted from the start (at click 0)
```
````

## Line Numbers

### Global Setting

Enable in headmatter:

```yaml
---
lineNumbers: true
---
```

### Per-Block Setting

````markdown
```ts {6,7}{lines:true,startLine:5}
function add(
  a: Ref<number> | number,
  b: Ref<number> | number
) {
  return computed(() => unref(a) + unref(b))
}
```
````

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `lines` | boolean | `false` | Show line numbers |
| `startLine` | number | `1` | Starting line number |

## Max Height (Scrollable Code)

For code blocks that exceed slide space:

````markdown
```ts {2|3|7|12}{maxHeight:'100px'}
// Long code block with scroll
function example() {
  // ...many lines...
}
```
````

The block becomes scrollable when content exceeds the specified height.

## Code Groups

Display multiple code blocks as tabs. Requires `mdc: true` in headmatter.

````markdown
::code-group

```sh [npm]
npm i @slidev/cli
```

```sh [yarn]
yarn add @slidev/cli
```

```sh [pnpm]
pnpm add @slidev/cli
```

::
````

The text in square brackets becomes the tab label. Icons are automatically matched for common tools (npm, yarn, pnpm, bun, deno, vue, react, etc.).

### Custom Icons

Use Iconify icon syntax in tab labels:

````markdown
```js [Custom ~i-uil:github~]
// Code here
```
````

Requires the icon collection package installed.

## Monaco Editor

Embed the VS Code editor (Monaco) in slides:

````markdown
```ts {monaco}
console.log('HelloWorld')
```
````

### Monaco Diff

Compare two code versions:

````markdown
```ts {monaco-diff}
console.log('Original text')
~~~
console.log('Modified text')
```
````

Use `~~~` to separate original and modified code.

### Height Configuration

````markdown
```ts {monaco} {height:'auto'}
// Editor auto-grows as you type
console.log('Hello, World!')
```

```ts {monaco} {height:'300px'}
// Fixed height editor
```
````

| Value | Behavior |
|-------|----------|
| `'auto'` | Expands as code is added |
| `'300px'` | Fixed pixel height |
| `'100%'` | Fill available space |

### Configuration

Global Monaco settings in headmatter:

```yaml
---
monaco: true          # enable (default)
monacoTypesSource: local  # 'cdn', 'local', or 'none'
---
```

## Magic Move

Animate code transitions between states. Shows smooth morphing between code blocks:

````markdown
````md magic-move
```ts
const greeting = 'hello'
```
```ts
const greeting = 'hello'
const name = 'world'
```
```ts
const greeting = 'hello'
const name = 'world'
console.log(`${greeting}, ${name}!`)
```
````
````

Each code block represents a step. Slidev animates the transition between steps on click.

## TwoSlash

Add TypeScript type annotations inline using TwoSlash syntax:

````markdown
```ts twoslash
import { ref } from 'vue'

const count = ref(0)
//    ^?
```
````

The `^?` marker shows the inferred type at that position. Enable globally:

```yaml
---
twoslash: true
---
```

## Importing Code Snippets

Import code from external files using `<<<`:

```markdown
<<< @/snippets/snippet.js
```

The `@` alias refers to the project root. Store snippets in `@/snippets/` for Monaco compatibility.

### With Language Override

```markdown
<<< @/snippets/snippet.js ts
```

### With Line Highlighting

```markdown
<<< @/snippets/snippet.js {2,3|5}{lines:true}
```

### With Monaco

```markdown
<<< @/snippets/snippet.js ts {monaco}{height:200px}
```

### VS Code Regions

Import a specific region from a file:

```markdown
<<< @/snippets/snippet.js#region-name
```

Define regions in the source file using VS Code region markers.

Available since Slidev v0.47.0.
