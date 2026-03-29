# Erlang Ports — Deep Reference

This reference covers the Erlang-level Port implementation, wire protocols, and low-level ERTS internals. Load this file when implementing binary protocol framing in C, writing port drivers, or investigating ERTS scheduling behavior.

## Table of Contents

1. [open_port/2 Complete Option Reference](#openport2-complete-option-reference)
2. [Port Architecture](#port-architecture)
3. [Binary Protocol Wire Format](#binary-protocol-wire-format)
4. [erl_interface / ei Library](#erl_interface--ei-library)
5. [Port Driver Architecture](#port-driver-architecture)
6. [ERTS Scheduling and Ports](#erts-scheduling-and-ports)
7. [Backpressure Options](#backpressure-options)
8. [Port Message Protocol Reference](#port-message-protocol-reference)

---

## open_port/2 Complete Option Reference

The Erlang BIF `open_port/2` is what `Port.open/2` calls. The complete set of `PortSettings` options:

### Port Name Forms

```erlang
{spawn, Command}          % Shell command string
{spawn_executable, Path}  % Absolute path, no shell
{spawn_driver, Command}   % Linked-in driver (deprecated pattern)
{fd, FdIn, FdOut}         % Wrap existing file descriptors
```

### Communication Options

| Option | Description |
|--------|-------------|
| `{packet, N}` | N-byte length prefix framing. N must be 1, 2, or 4. |
| `{line, L}` | Line-oriented mode. Max line length L bytes. |
| `stream` | No framing, raw byte stream (default). |
| `binary` | Deliver data as binaries instead of byte lists. |
| `{parallelism, Bool}` | Hint to scheduler for parallel port I/O. |

### I/O Channel Options

| Option | Description |
|--------|-------------|
| `use_stdio` | Use stdin/stdout for port communication (default). |
| `nouse_stdio` | Use file descriptors 3 and 4 instead of 0 and 1. |
| `stderr_to_stdout` | Merge the external program's stderr into stdout. |
| `in` | Port is read-only (input to Erlang only). |
| `out` | Port is write-only (output from Erlang only). |

### Process Options

| Option | Description |
|--------|-------------|
| `exit_status` | Send `{Port, {exit_status, Status}}` when program exits. |
| `{cd, Dir}` | Set working directory of the spawned process. |
| `{env, Env}` | Set environment. `Env` is a list of `{Name, Val}` or `{Name, false}` to unset. Replaces the entire environment. |
| `{args, ArgList}` | Argument list for `spawn_executable`. Each element is a string or binary. |
| `{arg0, ArgString}` | Override `argv[0]` (the program name as seen by the process). |
| `hide` | Windows only: start process with `STARTF_USESHOWWINDOW` + `SW_HIDE`. |

### Busy Limits (Backpressure)

| Option | Description |
|--------|-------------|
| `{busy_limits_port, {Low, High}}` | Busy-signal on the port when output queue exceeds `High` bytes; clear when below `Low`. |
| `{busy_limits_msgq, {Low, High}}` | Busy-signal when the message queue of the port owner exceeds `High`; clear when below `Low`. |
| `busy_limits_port` | Atom form: equivalent to `{busy_limits_port, {1024, 2048}}`. |
| `busy_limits_msgq` | Atom form: equivalent to `{busy_limits_msgq, {1024, 2048}}`. |

---

## Port Architecture

### External Ports

An external port runs as a separate OS process. ERTS communicates with it via:
- stdin (Erlang writes to the port → program's stdin)
- stdout (program writes to stdout → Erlang receives data messages)

The port process and ERTS run in separate OS processes with the OS providing memory isolation. A crash in the external program does not affect the ERTS VM.

### Port Owner

The process that calls `open_port/2` becomes the port owner. The port owner:
- Receives all messages from the port
- Is the only process that can send commands to the port (unless ownership is transferred)
- When the owner terminates, the port is closed and the external program receives SIGTERM

Ownership can be transferred with `port_connect(Port, NewPid)` (or `Port.connect/2` in Elixir).

### Port Lifecycle

```
open_port/2
    │
    ▼
OS fork/exec spawns external process
    │
    ▼
Port is alive — owner sends/receives
    │
    ├── Owner terminates → port closes → external gets SIGTERM
    ├── External exits → {Port, {exit_status, N}} → port closes
    └── port_close(Port) → {Port, closed} → external gets EOF on stdin
```

When `:exit_status` is not set, the port closes silently when the external program exits without notifying the owner.

---

## Binary Protocol Wire Format

### packet Mode Framing

`{packet, N}` prepends each message with a big-endian unsigned integer of N bytes representing the message length. The external program must implement the same framing.

#### Packet 1 (N=1)

- Header: 1 byte, unsigned, big-endian
- Maximum message size: 255 bytes
- Wire format: `[length_byte][payload_bytes...]`

```
Byte 0:        length (0-255)
Bytes 1..N:    payload
```

#### Packet 2 (N=2)

- Header: 2 bytes, unsigned, big-endian
- Maximum message size: 65,535 bytes (64 KB)
- Wire format: `[high_byte][low_byte][payload_bytes...]`

```
Byte 0:        length >> 8 (high byte)
Byte 1:        length & 0xFF (low byte)
Bytes 2..N+1:  payload
```

#### Packet 4 (N=4)

- Header: 4 bytes, unsigned, big-endian
- Maximum message size: 4,294,967,295 bytes (4 GB)
- Wire format: `[byte3][byte2][byte1][byte0][payload_bytes...]`

```
Bytes 0-3:     length in big-endian (network byte order)
Bytes 4..N+3:  payload
```

#### C Implementation Example (packet 2)

```c
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* Read a 2-byte length-prefixed message from stdin */
ssize_t read_packet2(uint8_t *buf, size_t buf_size) {
    uint8_t header[2];
    if (fread(header, 1, 2, stdin) != 2) return -1;

    uint16_t len = ((uint16_t)header[0] << 8) | header[1];
    if (len > buf_size) return -1;

    return fread(buf, 1, len, stdin);
}

/* Write a 2-byte length-prefixed message to stdout */
void write_packet2(const uint8_t *buf, uint16_t len) {
    uint8_t header[2];
    header[0] = (len >> 8) & 0xFF;
    header[1] = len & 0xFF;
    fwrite(header, 1, 2, stdout);
    fwrite(buf, 1, len, stdout);
    fflush(stdout);
}
```

#### Python Implementation Example (packet 4)

```python
import sys
import struct

def read_packet4():
    header = sys.stdin.buffer.read(4)
    if len(header) < 4:
        return None
    length = struct.unpack(">I", header)[0]
    return sys.stdin.buffer.read(length)

def write_packet4(data: bytes):
    header = struct.pack(">I", len(data))
    sys.stdout.buffer.write(header + data)
    sys.stdout.buffer.flush()
```

### Line Mode Wire Format

With `{line, MaxLineLength}`, the port delivers complete lines (including the newline stripped) as:
```erlang
{Port, {data, {eol, Line}}}
```

Lines exceeding `MaxLineLength` bytes are split and the first chunk arrives as:
```erlang
{Port, {data, {noeol, PartialLine}}}
```

---

## erl_interface / ei Library

`erl_interface` (and its successor `ei`) is a C library that allows external C programs to encode and decode Erlang External Term Format (ETF), enabling them to speak Erlang's native term protocol.

### When to Use ei

Use `ei` in external port programs when you want to pass Erlang terms (atoms, tuples, lists, binaries) directly rather than inventing a custom binary encoding. This is common when combined with `{packet, 2}` or `{packet, 4}`.

### Key ei Functions

```c
#include "ei.h"

/* Encoding */
ei_x_buff buf;
ei_x_new(&buf);
ei_x_encode_tuple_header(&buf, 2);
ei_x_encode_atom(&buf, "ok");
ei_x_encode_binary(&buf, data, data_len);

/* Decoding */
int index = 0;
int type, size;
ei_get_type(buf, &index, &type, &size);

char atom[MAXATOMLEN];
ei_decode_atom(buf, &index, atom);

long long_val;
ei_decode_long(buf, &index, &long_val);
```

### Erlang External Term Format

The full ETF specification is available at: https://www.erlang.org/doc/apps/erts/erl_ext_dist

Key tags:
- `131` — version magic byte (always first byte)
- `100` (`ATOM_EXT`) — atom
- `104` (`SMALL_TUPLE_EXT`) — tuple up to 255 elements
- `105` (`LARGE_TUPLE_EXT`) — tuple with more elements
- `108` (`LIST_EXT`) — proper list
- `109` (`BINARY_EXT`) — binary
- `97`  (`SMALL_INTEGER_EXT`) — integer 0–255
- `98`  (`INTEGER_EXT`) — 32-bit integer

In Elixir/Erlang: `:erlang.term_to_binary/1` encodes, `:erlang.binary_to_term/1` decodes. The external C program uses `ei` for the same encoding.

---

## Port Driver Architecture

### What Port Drivers Are

Port drivers (also called linked-in drivers) are shared libraries loaded into the ERTS VM process. They are accessed via `open_port({spawn_driver, Name}, Options)`.

Unlike external ports, port drivers:
- Run inside the ERTS VM process (no OS process isolation)
- Can crash the entire VM on a bug (no memory isolation)
- Have lower latency than external ports (no IPC)
- Are loaded with `erl_ddll:load/2`

### Deprecation Status

Port drivers occupy an awkward position:
- Lower latency than external ports but higher crash risk than NIFs
- NIFs (with dirty NIF support) largely supersede port drivers for in-process native code
- The Erlang/OTP team recommends new code use NIFs or external ports rather than port drivers
- Port driver support remains for backward compatibility but receives minimal new development

### Port Driver Callbacks

A port driver implements a `ErlDrvEntry` struct with function pointers:

```c
static ErlDrvEntry my_driver_entry = {
    .init         = my_init,
    .start        = my_start,
    .stop         = my_stop,
    .output       = my_output,    /* called when Erlang sends data */
    .ready_input  = my_ready_input,
    .ready_output = my_ready_output,
    .driver_name  = "my_driver",
    .finish       = my_finish,
    .call         = my_call,      /* synchronous call from port_call/3 */
    .extended_marker = ERL_DRV_EXTENDED_MARKER,
    .major_version   = ERL_DRV_EXTENDED_MAJOR_VERSION,
    .minor_version   = ERL_DRV_EXTENDED_MINOR_VERSION,
    .driver_flags    = ERL_DRV_FLAG_USE_PORT_LOCKING
};
```

---

## ERTS Scheduling and Ports

### Port I/O Threads

By default, ERTS uses a thread pool for port I/O operations (reads and writes). The pool size defaults to the number of CPU threads and is configurable with `+A` VM flag:

```sh
erl +A 16    # 16 async threads
```

External port I/O is performed in these threads, meaning port I/O does not block ERTS schedulers.

### Port Scheduling

Each port has its own run queue entry. When a port has pending I/O or messages to deliver, it is scheduled like a process. ERTS interleaves port execution with process execution on the same scheduler threads.

The `{parallelism, true}` option hints to the scheduler that the port can benefit from being scheduled on a separate thread, useful for high-throughput ports.

### Impact on Reduction Budget

Sending a message to a port or receiving from a port consumes reductions from the calling process's budget, similar to other operations. Very high-frequency port messaging can affect the reduction balance of the calling process.

---

## Backpressure Options

### busy_limits_port

Controls when `port_command/2` returns `false` (port is busy) or raises `{error, busy}`:

```erlang
%% Port signals busy when output queue exceeds 8192 bytes,
%% clears when it drops below 4096 bytes.
Port = open_port({spawn_executable, Exe}, [
    binary,
    {packet, 4},
    {busy_limits_port, {4096, 8192}}
]).
```

When the port is busy, `Port.command(port, data, [:nosuspend])` returns `false` instead of blocking.

### busy_limits_msgq

Controls when the port signals busy based on the message queue length of the port owner:

```erlang
Port = open_port({spawn_executable, Exe}, [
    binary,
    {packet, 4},
    {busy_limits_msgq, {100, 200}}
]).
```

This prevents the port from producing messages faster than the owner process can consume them.

### Using nosuspend with Port.command

`Port.command(port, data, [:nosuspend])` returns `false` immediately if the port is busy, instead of suspending the caller. Use this for non-blocking sends:

```elixir
case Port.command(port, data, [:nosuspend]) do
  true  -> :sent
  false -> :port_busy  # handle backpressure
end
```

`Port.command(port, data, [:force])` forces the send even when the port is busy, bypassing the busy signal. Use with caution as it can overflow the output queue.

---

## Port Message Protocol Reference

### Messages Sent TO a Port

These are the raw Erlang messages the port receives (Elixir `Port.command/2` and `Port.close/1` send these internally):

```erlang
{PortOwnerPid, {command, IoData}}   % Send data to external program
{PortOwnerPid, close}               % Close the port
{PortOwnerPid, {connect, NewPid}}   % Transfer ownership
```

### Messages Received FROM a Port

```erlang
{Port, {data, Data}}               % Data from external program
{Port, closed}                     % Port closed (after close command)
{Port, connected}                  % Ownership transfer confirmed (old owner receives this)
{Port, {exit_status, Status}}      % External program exited (requires exit_status option)
{'EXIT', Port, Reason}             % Port linked exit signal
{'DOWN', Ref, port, Port, Reason}  % Port monitor DOWN message
```

### Port.info/1 Fields

`Port.info(port)` returns a keyword list with:

| Key | Type | Description |
|-----|------|-------------|
| `:registered_name` | atom | Registered name if any |
| `:id` | integer | Port ID |
| `:connected` | pid | Current owner PID |
| `:links` | [pid] | Linked processes |
| `:name` | charlist | Port name (e.g., `'cat'`) |
| `:input` | integer | Total bytes received from program |
| `:output` | integer | Total bytes sent to program |
| `:os_pid` | integer \| `:undefined` | OS PID of the external process |

`Port.info(port, :os_pid)` returns `{:os_pid, pid_integer}` — useful for sending OS signals from Elixir:

```elixir
{:os_pid, os_pid} = Port.info(port, :os_pid)
System.cmd("kill", ["-SIGTERM", "#{os_pid}"])
```
