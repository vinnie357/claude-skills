# Rust Async and Concurrency

## Async Functions

```rust
use tokio;

// Async function
async fn fetch_data(url: &str) -> Result<String, reqwest::Error> {
    let response = reqwest::get(url).await?;
    let body = response.text().await?;
    Ok(body)
}

// Using async function
#[tokio::main]
async fn main() {
    match fetch_data("https://example.com").await {
        Ok(data) => println!("Data: {}", data),
        Err(e) => println!("Error: {}", e),
    }
}
```

## Concurrent Async Operations

```rust
use tokio;

async fn fetch_multiple() {
    // Sequential
    let data1 = fetch_data("https://api1.com").await;
    let data2 = fetch_data("https://api2.com").await;

    // Concurrent with join!
    let (data1, data2) = tokio::join!(
        fetch_data("https://api1.com"),
        fetch_data("https://api2.com")
    );

    // Concurrent with spawn
    let handle1 = tokio::spawn(fetch_data("https://api1.com"));
    let handle2 = tokio::spawn(fetch_data("https://api2.com"));

    let data1 = handle1.await.unwrap();
    let data2 = handle2.await.unwrap();
}
```

## Streams

```rust
use tokio_stream::StreamExt;

async fn process_stream() {
    let mut stream = tokio_stream::iter(vec![1, 2, 3, 4, 5]);

    while let Some(value) = stream.next().await {
        println!("Value: {}", value);
    }
}
```

## Threads

```rust
use std::thread;
use std::time::Duration;

// Spawn thread
let handle = thread::spawn(|| {
    for i in 1..10 {
        println!("Thread: {}", i);
        thread::sleep(Duration::from_millis(1));
    }
});

handle.join().unwrap();

// Move data into thread
let v = vec![1, 2, 3];
let handle = thread::spawn(move || {
    println!("Vector: {:?}", v);
});
```

## Channels

```rust
use std::sync::mpsc;

// Create channel
let (tx, rx) = mpsc::channel();

// Send from thread
thread::spawn(move || {
    tx.send("hello").unwrap();
});

// Receive
let received = rx.recv().unwrap();
println!("Received: {}", received);

// Multiple senders
let (tx, rx) = mpsc::channel();
let tx1 = tx.clone();

thread::spawn(move || tx.send("from thread 1").unwrap());
thread::spawn(move || tx1.send("from thread 2").unwrap());

for received in rx {
    println!("{}", received);
}
```

## Shared State

```rust
use std::sync::{Arc, Mutex};

// Arc for shared ownership, Mutex for mutual exclusion
let counter = Arc::new(Mutex::new(0));
let mut handles = vec![];

for _ in 0..10 {
    let counter = Arc::clone(&counter);
    let handle = thread::spawn(move || {
        let mut num = counter.lock().unwrap();
        *num += 1;
    });
    handles.push(handle);
}

for handle in handles {
    handle.join().unwrap();
}

println!("Result: {}", *counter.lock().unwrap());
```
