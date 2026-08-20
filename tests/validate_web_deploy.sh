#!/bin/sh
set -eu

command -v ruby >/dev/null 2>&1 && ruby -e 'require "psych"; require "yaml"' >/dev/null 2>&1 || {
  echo "web deployment validation failed: Ruby with Psych is required" >&2
  exit 1
}

workflow="${1:-.github/workflows/webgl-pages.yml}"
export_preset="${2:-export_presets.cfg}"

ruby - "$workflow" "$export_preset" <<'RUBY'
require "yaml"

workflow_path, preset_path = ARGV

def fail_validation(message)
  warn "web deployment validation failed: #{message}"
  exit 1
end

begin
  workflow = YAML.safe_load_file(workflow_path, aliases: false)
rescue StandardError => e
  fail_validation("#{workflow_path} is not valid YAML: #{e.message}")
end

fail_validation("workflow root must be a mapping") unless workflow.is_a?(Hash)

expected_triggers = {
  "push" => { "branches" => ["main"] },
  "workflow_dispatch" => nil
}
fail_validation("triggers must be exactly push to main and workflow_dispatch") unless workflow["on"] == expected_triggers
fail_validation("top-level permissions must be exactly contents: read") unless workflow["permissions"] == { "contents" => "read" }
fail_validation("concurrency must use the pages group") unless workflow["concurrency"] == { "group" => "pages", "cancel-in-progress" => true }

editor_hash = "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c"
templates_hash = "9714459dc071907c0f3d5f17d608faf69e7cda21331fc5d39c4503ffa4e99eec"
expected_hashes = {
  "GODOT_EDITOR_SHA256" => editor_hash,
  "GODOT_TEMPLATES_SHA256" => templates_hash
}
expected_hashes.each do |name, digest|
  fail_validation("#{name} must contain the official pinned digest") unless workflow.dig("env", name) == digest
end

jobs = workflow["jobs"]
fail_validation("jobs must be exactly build and deploy") unless jobs.is_a?(Hash) && jobs.keys.sort == %w[build deploy]
build = jobs["build"]
deploy = jobs["deploy"]
expected_build_permissions = { "contents" => "read", "pages" => "read" }
fail_validation("build permissions must be contents: read and pages: read") unless build["permissions"] == expected_build_permissions
expected_deploy_permissions = { "pages" => "write", "id-token" => "write" }
fail_validation("deploy permissions must be pages: write and id-token: write") unless deploy["permissions"] == expected_deploy_permissions
fail_validation("deploy must need build") unless deploy["needs"] == "build"
expected_environment = { "name" => "github-pages", "url" => "${{ steps.deployment.outputs.page_url }}" }
fail_validation("deploy must target the github-pages environment") unless deploy["environment"] == expected_environment

build_steps = build["steps"]
deploy_steps = deploy["steps"]
fail_validation("build steps must be a list") unless build_steps.is_a?(Array)
fail_validation("deploy steps must be a list") unless deploy_steps.is_a?(Array)
build_actions = build_steps.filter_map { |step| step["uses"] }
deploy_actions = deploy_steps.filter_map { |step| step["uses"] }
expected_build_actions = %w[actions/checkout@v4 actions/cache@v4 actions/configure-pages@v5 actions/upload-pages-artifact@v4]
fail_validation("build actions or versions are not exact") unless build_actions == expected_build_actions
fail_validation("deploy action must be exactly actions/deploy-pages@v4") unless deploy_actions == ["actions/deploy-pages@v4"]

all_runs = build_steps.filter_map { |step| step["run"] }.join("\n")
required_commands = [
  "godot --headless --path . --editor --quit",
  "godot --headless --path . --script tests/data_validation.gd",
  "godot --headless --path . --script tests/test_suite.gd",
  "godot --headless --path . --export-release Web builds/web/index.html"
]
required_commands.each do |command|
  fail_validation("build is missing command: #{command}") unless all_runs.include?(command)
end

mkdir_web = all_runs.index("mkdir -p builds/web")
export_web = all_runs.index("godot --headless --path . --export-release Web builds/web/index.html")
fail_validation("Web export directory must be created before export") unless mkdir_web && export_web && mkdir_web < export_web

fail_validation("archives must be checked with sha256sum before unzip") unless all_runs.scan("sha256sum --check --strict").length >= 2
%w[GODOT_EDITOR_SHA256 GODOT_TEMPLATES_SHA256].each do |name|
  fail_validation("SHA256 verification must use $#{name}") unless all_runs.include?("$#{name}")
end
first_unzip = all_runs.index("unzip")
last_checksum = all_runs.rindex("sha256sum --check --strict")
fail_validation("SHA256 verification must happen before unzip") unless first_unzip && last_checksum && last_checksum < first_unzip

cache_step = build_steps.find { |step| step["uses"] == "actions/cache@v4" }
cache_key = cache_step.dig("with", "key").to_s
[editor_hash, templates_hash].each do |digest|
  fail_validation("cache key is missing SHA256 #{digest}") unless cache_key.include?(digest)
end

%w[index.html index.js index.wasm index.pck].each do |filename|
  fail_validation("artifact validation must require nonempty builds/web/#{filename}") unless all_runs.include?("test -s builds/web/#{filename}")
end
fail_validation("artifact validation must not use wildcard matches") if all_runs.include?("builds/web/*") || all_runs.include?("compgen")
fail_validation("artifact validation must reject symbolic links") unless all_runs.include?("find builds/web -type l")

preset = File.read(preset_path)
{
  'name="Web"' => "Web preset",
  'export_path="builds/web/index.html"' => "Web export path",
  'variant/extensions_support=false' => "disabled GDExtensions",
  'variant/thread_support=false' => "disabled Web threads",
  'progressive_web_app/enabled=false' => "disabled PWA",
  'progressive_web_app/ensure_cross_origin_isolation_headers=false' => "disabled cross-origin isolation headers",
  'res://game_assets/ui/fonts/ui_cjk.ttf' => "CJK UI font",
  'res://game_assets/ui/title_cover.png' => "title cover splash"
}.each do |text, description|
  fail_validation("export preset is missing #{description}") unless preset.include?(text)
end

puts "Web deployment configuration is valid."
RUBY
