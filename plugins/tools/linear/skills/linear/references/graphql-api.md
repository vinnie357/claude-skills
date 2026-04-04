# Linear GraphQL API Reference

## Table of Contents

- [Authentication](#authentication)
- [Issue Queries](#issue-queries)
- [Issue Mutations](#issue-mutations)
- [Comment Operations](#comment-operations)
- [Attachment Operations](#attachment-operations)
- [Workflow States](#workflow-states)
- [Label Operations](#label-operations)
- [Project and Team Queries](#project-and-team-queries)
- [Pagination](#pagination)
- [Introspection](#introspection)
- [File Uploads](#file-uploads)

## Authentication

All requests use Bearer token auth against `https://api.linear.app/graphql`:

```bash
curl -s \
  -H "Authorization: Bearer $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "...", "variables": {...}}' \
  https://api.linear.app/graphql
```

Rate limits: 1,500 requests/hour, 250,000 complexity points/hour.

## Issue Queries

### By Key

Use when you have a ticket key like `MT-686`:

```graphql
query IssueByKey($key: String!) {
  issue(id: $key) {
    id identifier title url description
    state { id name type }
    project { id name }
    team { id key name }
    labels { nodes { id name } }
    branchName
    attachments { nodes { id title url sourceType } }
    comments { nodes { id body createdAt user { name } } }
    updatedAt
  }
}
```

### By Identifier Filter

Use for search-style lookups:

```graphql
query IssueByIdentifier($identifier: String!) {
  issues(filter: { identifier: { eq: $identifier } }, first: 1) {
    nodes {
      id identifier title url description
      state { id name type }
      project { id name }
    }
  }
}
```

### By Project

List issues in a project with optional state filter:

```graphql
query ProjectIssues($projectId: String!, $stateType: String) {
  issues(
    filter: {
      project: { id: { eq: $projectId } }
      state: { type: { eq: $stateType } }
    }
    first: 50
    orderBy: updatedAt
  ) {
    nodes {
      id identifier title url
      state { id name type }
      labels { nodes { name } }
      description
    }
    pageInfo { hasNextPage endCursor }
  }
}
```

### Viewer (Test Connectivity)

```graphql
query Viewer {
  viewer { id name email }
}
```

## Issue Mutations

### Create Issue

```graphql
mutation CreateIssue(
  $teamId: String!
  $title: String!
  $description: String
  $stateId: String
  $labelIds: [String!]
  $projectId: String
) {
  issueCreate(input: {
    teamId: $teamId
    title: $title
    description: $description
    stateId: $stateId
    labelIds: $labelIds
    projectId: $projectId
  }) {
    success
    issue { id identifier url title }
  }
}
```

### Update Issue

```graphql
mutation UpdateIssue(
  $id: String!
  $stateId: String
  $description: String
  $title: String
  $labelIds: [String!]
) {
  issueUpdate(id: $id, input: {
    stateId: $stateId
    description: $description
    title: $title
    labelIds: $labelIds
  }) {
    success
    issue { id identifier state { id name } }
  }
}
```

### Delete Issue

```graphql
mutation DeleteIssue($id: String!) {
  issueDelete(id: $id) { success }
}
```

## Comment Operations

### Create Comment

```graphql
mutation CreateComment($issueId: String!, $body: String!) {
  commentCreate(input: { issueId: $issueId, body: $body }) {
    success
    comment { id url body }
  }
}
```

### Update Comment

```graphql
mutation UpdateComment($id: String!, $body: String!) {
  commentUpdate(id: $id, input: { body: $body }) {
    success
    comment { id body }
  }
}
```

### List Comments on an Issue

```graphql
query IssueComments($issueId: String!, $after: String) {
  issue(id: $issueId) {
    comments(first: 50, after: $after, orderBy: createdAt) {
      nodes {
        id body createdAt updatedAt
        user { id name }
      }
      pageInfo { hasNextPage endCursor }
    }
  }
}
```

## Attachment Operations

### Attach GitHub PR

Prefer this for GitHub PRs — preserves GitHub metadata:

```graphql
mutation AttachGitHubPR($issueId: String!, $url: String!, $title: String) {
  attachmentLinkGitHubPR(
    issueId: $issueId
    url: $url
    title: $title
    linkKind: links
  ) {
    success
    attachment { id title url }
  }
}
```

### Attach Generic URL

Use when the URL is not a GitHub PR:

```graphql
mutation AttachURL($issueId: String!, $url: String!, $title: String) {
  attachmentLinkURL(issueId: $issueId, url: $url, title: $title) {
    success
    attachment { id title url }
  }
}
```

### List Attachments

```graphql
query IssueAttachments($issueId: String!) {
  issue(id: $issueId) {
    attachments {
      nodes { id title url sourceType metadata }
    }
  }
}
```

## Workflow States

### List Team States

```graphql
query TeamStates($teamId: String!) {
  team(id: $teamId) {
    states {
      nodes { id name type position }
    }
  }
}
```

### Get States via Issue

Use when you have an issue ID and need the team's states:

```graphql
query IssueTeamStates($id: String!) {
  issue(id: $id) {
    team {
      states { nodes { id name type } }
    }
  }
}
```

### State Types

Linear workflow states have a `type` field:

| Type | Meaning |
|------|---------|
| `triage` | Needs triage |
| `backlog` | In backlog |
| `unstarted` | Ready but not started |
| `started` | In progress |
| `completed` | Done |
| `canceled` | Cancelled |

Custom state names map to these types. Always match on `type` for automation, use `name` for display.

## Label Operations

### List Labels

```graphql
query Labels($teamId: String) {
  issueLabels(
    filter: { team: { id: { eq: $teamId } } }
    first: 100
  ) {
    nodes { id name color }
  }
}
```

### Create Label

```graphql
mutation CreateLabel($teamId: String!, $name: String!, $color: String) {
  issueLabelCreate(input: { teamId: $teamId, name: $name, color: $color }) {
    success
    issueLabel { id name }
  }
}
```

## Project and Team Queries

### List Projects

```graphql
query Projects {
  projects(first: 50) {
    nodes { id name slug state }
  }
}
```

### Get Project by Slug

```graphql
query ProjectBySlug {
  projects(filter: { slugId: { eq: "my-project" } }, first: 1) {
    nodes { id name slug }
  }
}
```

### List Teams

```graphql
query Teams {
  teams {
    nodes { id key name }
  }
}
```

## Pagination

Linear uses cursor-based pagination:

```graphql
query PaginatedIssues($after: String) {
  issues(first: 50, after: $after) {
    nodes { id identifier title }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

Loop until `hasNextPage` is `false`, passing `endCursor` as `after` for each page.

## Introspection

### List All Mutations

```graphql
query ListMutations {
  __type(name: "Mutation") { fields { name } }
}
```

### List All Queries

```graphql
query ListQueries {
  __type(name: "Query") { fields { name } }
}
```

### Inspect Input Type

```graphql
query InspectInput($typeName: String!) {
  __type(name: $typeName) {
    inputFields {
      name
      type { kind name ofType { kind name } }
    }
  }
}
```

Use `"IssueCreateInput"`, `"CommentCreateInput"`, etc. as `$typeName`.

### Inspect Object Type

```graphql
query InspectType($typeName: String!) {
  __type(name: $typeName) {
    fields {
      name
      type { kind name ofType { kind name } }
      args { name type { kind name } }
    }
  }
}
```

## File Uploads

For attaching files (images, videos) to comments:

1. Request upload URL:

```graphql
mutation FileUpload($filename: String!, $contentType: String!, $size: Int!) {
  fileUpload(filename: $filename, contentType: $contentType, size: $size) {
    success
    uploadFile {
      uploadUrl
      assetUrl
      headers { key value }
    }
  }
}
```

2. Upload file bytes to `uploadUrl` with the returned headers
3. Reference `assetUrl` in comment body markdown
