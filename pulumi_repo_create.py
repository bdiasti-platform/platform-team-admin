import yaml
import pulumi
from pulumi import ResourceOptions, export
from pulumi_github import BranchProtection, Membership, Provider, Repository

# Configure the provider (explicit name, token and owner come from secrets)
github_config = pulumi.Config("github")
github_provider = Provider(
    "platform-github-provider",
    token=github_config.require_secret("token"),
    owner=github_config.require("owner"),
)

# Load repository definitions (config file: config/platform_team_values.yaml)
with open("config/platform_team_values.yaml", encoding="utf-8") as f:
    data = yaml.safe_load(f)

# Add the platform team members to the organization, with their roles.
# Removing an entry from the YAML and running pulumi up removes the member
# (offboarding), so these resources are intentionally NOT protected.
for member in data.get("github_organization_members", []):
    username = member["github-username"]
    role = member.get("github-role", "member")

    Membership(
        f"github-membership-{username}",
        username=username,
        role=role,
        opts=ResourceOptions(provider=github_provider),
    )

for repo_def in data.get("github_repositories", []):
    repo_name = repo_def.get("name")
    repo_description = repo_def.get("description", "")
    # allow per-repo visibility: 'private' | 'public' | 'internal'
    visibility = repo_def.get("visibility", "private")

    # Create the repository, explicitly using the configured provider.
    # protect=True: Pulumi refuses to delete it (pulumi destroy, or removing it
    # from the YAML) until protection is explicitly removed.
    repository = Repository(
        repo_name,
        name=repo_name,
        description=repo_description,
        visibility=visibility,
        opts=ResourceOptions(provider=github_provider, protect=True),
    )

    # Create a branch protection rule that enforces signed commits.
    # node_id makes Pulumi create the rule only after the repository exists.
    BranchProtection(
        f"{repo_name}-main-branch-protection",
        repository_id=repository.node_id,
        pattern="main",
        enforce_admins=True,
        require_signed_commits=True,
        opts=ResourceOptions(provider=github_provider),
    )

    # Require signed commits on every other branch too, so any commit can be
    # traced back to an authorized developer (audit). "**/*" also matches names
    # with "/" (feature/x). Deletion stays allowed so merged branches can be
    # cleaned up; "main" keeps its stricter rule above (more specific pattern wins).
    BranchProtection(
        f"{repo_name}-all-branches-protection",
        repository_id=repository.node_id,
        pattern="**/*",
        enforce_admins=True,
        require_signed_commits=True,
        allows_deletions=True,
        opts=ResourceOptions(provider=github_provider),
    )

    # Export in case other stacks or examples depend on the name
    export(f"{repo_name}_repo_name", repository.name)
