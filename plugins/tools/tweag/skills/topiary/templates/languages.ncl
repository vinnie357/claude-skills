# Topiary Language Configuration Template
#
# Save this file as .topiary/languages.ncl in your project root
# Topiary reads this Nickel-format file to register languages, grammars, and indentation settings
#
# Format: Nickel (https://nickel-lang.org/) — a lightweight configuration language
# Topiary searches for this file in the current directory and parent directories

{
  # Language registry
  # Each entry defines a language and its grammar source
  languages = {
    # Official language example: JSON
    json = {
      # File extensions that trigger this language
      extensions = ["json"],

      # Indentation style (optional, defaults to "  " - two spaces)
      # Can be a string (spaces) or a number (number of spaces)
      indent = "  ",

      # Grammar source: Git repository with Tree-sitter grammar
      grammar.source.git = {
        # Git repository URL pointing to the Tree-sitter grammar
        git = "https://github.com/tree-sitter/tree-sitter-json",

        # Revision (commit hash, branch, or tag)
        rev = "master",

        # Optional Nix hash for pre-compiled grammar (Nix deployments only)
        # nixHash = "sha256-..."
      }
    },

    # Custom language example: My formatter
    my-custom-lang = {
      extensions = ["mcl", "my-lang"],
      indent = "    ",  # 4 spaces

      # Grammar source: Local file path (pre-compiled grammar)
      # Use this if you've already compiled a Tree-sitter grammar
      grammar.source.path = "./grammars/my-lang.so"

      # Alternative: Git repository with specific revision
      # grammar.source.git = {
      #   git = "https://github.com/my-org/tree-sitter-my-lang",
      #   rev = "abc123def456"
      # }
    },

    # Bash example with custom indentation
    bash = {
      extensions = ["sh", "bash"],
      indent = "\t",  # Tab indentation

      grammar.source.git = {
        git = "https://github.com/tree-sitter/tree-sitter-bash",
        rev = "master"
      }
    },

    # TOML with Git revision as branch
    toml = {
      extensions = ["toml"],
      grammar.source.git = {
        git = "https://github.com/tree-sitter/tree-sitter-toml",
        rev = "master"
      }
    },

    # OCaml with Nix hash for reproducible builds
    ocaml = {
      extensions = ["ml"],
      grammar.source.git = {
        git = "https://github.com/tree-sitter/tree-sitter-ocaml",
        rev = "master",
        nixHash = "sha256-..."  # Optional: Nix hash for pre-compilation
      }
    }
  }
}

# Grammar Source Options
#
# 1. Git Repository (recommended for reproducibility)
#    grammar.source.git = {
#      git = "https://github.com/org/tree-sitter-lang",
#      rev = "main"  # Branch, tag, or commit hash
#    }
#
# 2. Local File Path (for pre-compiled grammars)
#    grammar.source.path = "/absolute/path/to/grammar.so"
#    grammar.source.path = "./relative/path/to/grammar.so"
#
# Indentation Options
#
# - "  " (two spaces, default)
# - "    " (four spaces)
# - "\t" (tab)
# - Single character: Topiary repeats it for indentation depth
#
# Example Configuration for Your Project
#
# If you're adding formatting for a new language:
#
# 1. Create a Tree-sitter grammar (or find an existing one)
#    See: https://tree-sitter.github.io/tree-sitter/
#
# 2. Register it in this file:
#    my-lang = {
#      extensions = ["ml"],
#      grammar.source.git = {
#        git = "https://github.com/you/tree-sitter-my-lang",
#        rev = "main"
#      }
#    }
#
# 3. Create a query file:
#    .topiary/queries/my-lang.scm
#
# 4. Test formatting:
#    topiary fmt test.ml
#    topiary visualise test.ml
#
# References
#
# - Topiary Configuration: https://topiary.tweag.io/book/cli/configuration.html
# - Nickel Language: https://nickel-lang.org/
# - Tree-sitter Grammars: https://github.com/tree-sitter?type=source
