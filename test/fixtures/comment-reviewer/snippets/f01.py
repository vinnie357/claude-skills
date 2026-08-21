def collect_ids(users):
    """Ids of `users`, in source order."""
    # Create an empty list called ids.
    ids = []
    # Loop over each user in users.
    for user in users:
        # Append the user's id to the ids list.
        ids.append(user.id)
    # Return the ids list.
    return ids
