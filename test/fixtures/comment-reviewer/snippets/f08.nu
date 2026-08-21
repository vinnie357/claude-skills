# Publishes the bundle.
export def publish-bundle [name: string, version: string, dest: string] {
    let tarball = (build-tarball $name $version)
    http post $"($dest)/api/bundles/import" $tarball
}
