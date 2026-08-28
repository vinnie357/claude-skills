# Bundle import

The bundle importer downloads the tarball, verifies its checksum, extracts
the manifest, registers each workflow path, and writes the final result to
the shared cache before it returns control to the caller.
