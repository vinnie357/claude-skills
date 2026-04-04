#!/usr/bin/env nu

# Linear GraphQL API client for Nushell
# Fallback for environments where MCP is unavailable.
# Requires: LINEAR_API_KEY environment variable

const LINEAR_API = "https://api.linear.app/graphql"

# Execute a GraphQL query against the Linear API
def graphql [query: string, variables: record = {}] {
  let api_key = ($env | get -o LINEAR_API_KEY | default "")
  if ($api_key | is-empty) {
    error make {
      msg: "LINEAR_API_KEY not set. Generate a key at Linear > Settings > API > Personal API Keys"
    }
  }

  let body = { query: $query, variables: $variables } | to json

  let response = (
    http post $LINEAR_API
      --content-type "application/json"
      --headers ["Authorization" $"Bearer ($api_key)"]
      $body
  )

  if ($response | get -o errors | default [] | length) > 0 {
    let errs = ($response.errors | each { |e| $e.message } | str join ", ")
    error make { msg: $"GraphQL error: ($errs)" }
  }

  $response.data
}

# Test API connectivity
def "linear health" [] {
  let data = (graphql "{ viewer { id name email } }")
  print $"Connected as: ($data.viewer.name) <($data.viewer.email)>"
  $data.viewer
}

# List issues in a project
def "linear issues" [
  project_id: string    # Linear project ID
  --state: string = ""  # Filter by state type (e.g., "started", "unstarted")
  --limit: int = 50     # Max results
] {
  mut filter = $"project: { id: { eq: \"($project_id)\" } }"
  if ($state | is-not-empty) {
    $filter = $"($filter), state: { type: { eq: \"($state)\" } }"
  }

  let query = $"query { issues\(filter: { ($filter) }, first: ($limit), orderBy: updatedAt\) { nodes { id identifier title url state { name type } labels { nodes { name } } description } pageInfo { hasNextPage endCursor } } }"

  let data = (graphql $query)
  $data.issues.nodes
}

# Get a single issue by key (e.g., MT-686)
def "linear issue" [key: string] {
  let query = 'query($key: String!) { issue(id: $key) { id identifier title url description state { id name type } project { id name } team { id key name } labels { nodes { id name } } branchName attachments { nodes { id title url sourceType } } comments { nodes { id body createdAt user { name } } } updatedAt } }'

  let data = (graphql $query { key: $key })
  $data.issue
}

# Create an issue
def "linear create-issue" [
  title: string          # Issue title
  --team-id: string      # Team ID (required)
  --description: string = ""  # Issue description (markdown)
  --state-id: string = ""     # Initial state ID
  --project-id: string = ""   # Project ID
  --label-ids: list<string> = []  # Label IDs
] {
  mut input = $"teamId: \"($team_id)\", title: \"($title)\""
  if ($description | is-not-empty) {
    let desc_escaped = ($description | str replace --all '"' '\"')
    $input = $"($input), description: \"($desc_escaped)\""
  }
  if ($state_id | is-not-empty) {
    $input = $"($input), stateId: \"($state_id)\""
  }
  if ($project_id | is-not-empty) {
    $input = $"($input), projectId: \"($project_id)\""
  }
  if ($label_ids | length) > 0 {
    let ids = ($label_ids | each { |id| $"\"($id)\"" } | str join ", ")
    $input = $"($input), labelIds: [($ids)]"
  }

  let query = $"mutation { issueCreate\(input: { ($input) }\) { success issue { id identifier url title } } }"

  let data = (graphql $query)
  if $data.issueCreate.success {
    print $"Created: ($data.issueCreate.issue.identifier) - ($data.issueCreate.issue.url)"
  }
  $data.issueCreate.issue
}

# Update an issue
def "linear update-issue" [
  id: string             # Issue ID
  --state-id: string = ""     # New state ID
  --description: string = ""  # New description
  --title: string = ""        # New title
] {
  mut input = ""
  if ($state_id | is-not-empty) {
    $input = $"stateId: \"($state_id)\""
  }
  if ($description | is-not-empty) {
    let desc_escaped = ($description | str replace --all '"' '\"')
    if ($input | is-not-empty) { $input = $"($input), " }
    $input = $"($input)description: \"($desc_escaped)\""
  }
  if ($title | is-not-empty) {
    if ($input | is-not-empty) { $input = $"($input), " }
    $input = $"($input)title: \"($title)\""
  }

  if ($input | is-empty) {
    error make { msg: "No update fields provided. Use --state-id, --description, or --title." }
  }

  let query = $"mutation { issueUpdate\(id: \"($id)\", input: { ($input) }\) { success issue { id identifier state { name } } } }"

  let data = (graphql $query)
  $data.issueUpdate.issue
}

# List workflow states for a team
def "linear states" [team_id: string] {
  let query = 'query($teamId: String!) { team(id: $teamId) { states { nodes { id name type position } } } }'

  let data = (graphql $query { teamId: $team_id })
  $data.team.states.nodes | sort-by position
}

# Add a comment to an issue
def "linear comment" [
  issue_id: string  # Issue ID
  body: string      # Comment body (markdown)
] {
  let query = 'mutation($issueId: String!, $body: String!) { commentCreate(input: { issueId: $issueId, body: $body }) { success comment { id url } } }'

  let data = (graphql $query { issueId: $issue_id, body: $body })
  if $data.commentCreate.success {
    print $"Comment created: ($data.commentCreate.comment.url)"
  }
  $data.commentCreate.comment
}

# Attach a GitHub PR URL to an issue
def "linear attach-pr" [
  issue_id: string  # Issue ID
  pr_url: string    # GitHub PR URL
  --title: string = ""  # Attachment title
] {
  mut vars = { issueId: $issue_id, url: $pr_url }
  if ($title | is-not-empty) {
    $vars = ($vars | merge { title: $title })
  }

  let query = 'mutation($issueId: String!, $url: String!, $title: String) { attachmentLinkGitHubPR(issueId: $issueId, url: $url, title: $title, linkKind: links) { success attachment { id title url } } }'

  let data = (graphql $query $vars)
  if $data.attachmentLinkGitHubPR.success {
    print $"PR attached: ($pr_url)"
  }
  $data.attachmentLinkGitHubPR.attachment
}

# List teams
def "linear teams" [] {
  let data = (graphql "{ teams { nodes { id key name } } }")
  $data.teams.nodes
}

# List projects
def "linear projects" [--limit: int = 50] {
  let query = $"{ projects\(first: ($limit)\) { nodes { id name slugId state } } }"
  let data = (graphql $query)
  $data.projects.nodes
}
