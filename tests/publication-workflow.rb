require 'yaml'
require 'tmpdir'
require 'fileutils'
require 'open3'

workflow = YAML.load_file(File.join(__dir__, '../.github/workflows/build.yml'))
jobs = workflow.fetch('jobs')
generation = jobs.fetch('generate-jobs')
script = generation.fetch('steps').find { |step| step['id'] == 'changes' }.fetch('run')
raise 'Missing publication output' unless generation.fetch('outputs')['publish'] == '${{ steps.changes.outputs.publish }}'
raise 'Build must require changed inputs' unless jobs.fetch('build').fetch('if').include?("needs.generate-jobs.outputs.publish == 'true'")
raise 'Validation must precede publication' unless jobs.fetch('build').fetch('needs').include?('test')
raise 'Notification must follow publication' unless jobs.fetch('notify-consumers').fetch('needs') == 'build'

Dir.mktmpdir('publication-scope-') do |dir|
  run = lambda do |*args|
    stdout, stderr, result = Open3.capture3(*args, chdir: dir)
    raise stderr unless result.success?
    stdout.strip
  end
  run.call('git', 'init', '--initial-branch=main')
  run.call('git', 'config', 'user.name', 'fixture')
  run.call('git', 'config', 'user.email', 'fixture@example.test')
  run.call('git', 'config', 'commit.gpgSign', 'false')
  File.write(File.join(dir, 'README.md'), "initial\n")
  run.call('git', 'add', '.')
  run.call('git', 'commit', '-m', 'Initial fixture')

  {
    'README.md' => false,
    'docs/example.md' => false,
    '.github/workflows/build.yml' => false,
    'tests/example.sh' => false,
    'latest/php8.3/apache/Dockerfile' => true,
    'frankenphp/php8.4/frankenphp/bin/entrypoint.sh' => true,
    'templates/production.php.tmpl' => true,
    'init/10-wordpress-php.sh' => true,
    'versions.json' => true,
    '.php' => true,
    '.frankenphp' => true,
  }.each do |filename, expected|
    before = run.call('git', 'rev-parse', 'HEAD')
    target = File.join(dir, filename)
    FileUtils.mkdir_p(File.dirname(target))
    File.write(target, "changed\n")
    run.call('git', 'add', filename)
    run.call('git', 'commit', '-m', 'Change fixture')
    output = File.join(dir, 'output')
    env = { 'EVENT_NAME' => 'push', 'BEFORE_SHA' => before,
            'GITHUB_SHA' => run.call('git', 'rev-parse', 'HEAD'), 'GITHUB_OUTPUT' => output }
    File.write(output, '')
    _, stderr, status = Open3.capture3(env, 'bash', '-Eeuo', 'pipefail', '-c', script, chdir: dir)
    raise "Scope check failed for #{filename}: #{stderr}" unless status.success?
    raise "Wrong publication decision for #{filename}" unless File.read(output) == "publish=#{expected}\n"
  end

  [['workflow_dispatch', '', true], ['push', '0' * 40, true], ['push', 'invalid-sha', false]].each do |event, before, succeeds|
    output = File.join(dir, 'output')
    File.write(output, '')
    env = { 'EVENT_NAME' => event, 'BEFORE_SHA' => before, 'GITHUB_SHA' => 'HEAD', 'GITHUB_OUTPUT' => output }
    _, _, status = Open3.capture3(env, 'bash', '-Eeuo', 'pipefail', '-c', script, chdir: dir)
    raise "Unexpected result for #{event}/#{before}" unless status.success? == succeeds
    raise 'Explicit rebuild was skipped' if succeeds && File.read(output) != "publish=true\n"
    raise 'Git failure published a result' if !succeeds && !File.read(output).empty?
  end
end

puts '14 publication scope checks passed'
