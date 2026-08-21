def purge_expired(items):
    """Removes expired entries from `items` in place."""
    # Reverse order: deleting an element shifts the index of every element
    # after it, so a forward loop skips the entry following each deletion.
    for i in range(len(items) - 1, -1, -1):
        if items[i].expired:
            del items[i]
