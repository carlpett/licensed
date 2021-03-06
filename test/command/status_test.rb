# frozen_string_literal: true
require "test_helper"

describe Licensed::Command::Status do
  let(:config) { Licensed::Configuration.new }

  before do
    config.ui.silence do
      Licensed::Command::Cache.new(config.dup).run(force: true)
    end
    @verifier = Licensed::Command::Status.new(config)
  end

  it "warns if license is not allowed" do
    out, _ = capture_io { @verifier.run }
    assert_match(/license needs reviewed: mit/, out)
  end

  it "does not warn if license is allowed" do
    config.allow "mit"
    out, _ = capture_io { @verifier.run }
    refute_match(/license needs reviewed: mit/, out)
  end

  it "does not warn if dependency is ignored" do
    out, _ = capture_io { @verifier.run }
    assert_match(/licensee.txt/, out)

    config.ignore "type" => "rubygem", "name" => "licensee"
    out, _ = capture_io { @verifier.run }
    refute_match(/licensee.txt/, out)
  end

  it "does not warn if dependency is reviewed" do
    out, _ = capture_io { @verifier.run }
    assert_match(/licensee/, out)

    config.review "type" => "rubygem", "name" => "licensee"
    out, _ = capture_io { @verifier.run }
    refute_match(/licensee/, out)
  end

  it "warns if license is empty" do
    filename = config.cache_path.join("rubygem/licensee.txt")
    license = Licensed::License.read(filename)
    license.text = ""
    license.save(filename)

    out, _ = capture_io { @verifier.run }
    assert_match(/missing license text/, out)
  end

  it "warns if versions do not match" do
    @verifier.app_dependencies(config.apps.first).first["version"] = "nope"
    out, _ = capture_io { @verifier.run }
    assert_match(/cached license data out of date/, out)
  end

  it "warns if cached license data missing" do
    FileUtils.rm config.cache_path.join("rubygem/licensee.txt")
    out, _ = capture_io { @verifier.run }
    assert_match(/cached license data missing/, out)
  end

  it "does not warn if cached license data missing for ignored gem" do
    FileUtils.rm config.cache_path.join("rubygem/licensee.txt")
    config.ignore "type" => "rubygem", "name" => "licensee"

    out, _ = capture_io { @verifier.run }
    refute_match(/licensee/, out)
  end

  it "does not include ignored dependencies in dependency counts" do
    out, _ = capture_io { @verifier.run }
    count = out.match(/(\d+) dependencies checked/)[1].to_i

    config.ignore "type" => "rubygem", "name" => "licensee"
    out, _ = capture_io { @verifier.run }
    ignored_count = out.match(/(\d+) dependencies checked/)[1].to_i
    assert_equal count - 1, ignored_count
  end

  describe "with multiple apps" do
    let(:apps) do
      [
        {
          "name" => "app1",
          "cache_path" => "vendor/licenses/app1",
          "source_path" => Dir.pwd
        },
        {
          "name" => "app2",
          "cache_path" => "vendor/licenses/app2",
          "source_path" => Dir.pwd
        }
      ]
    end
    let(:config) { Licensed::Configuration.new("apps" => apps) }

    it "verifies dependencies for all apps" do
      out, _ = capture_io { @verifier.run }
      config.apps.each do |app|
        assert_match(/Checking licenses for #{app['name']}/, out)
      end
    end
  end

  describe "with app.source_path" do
    let(:fixtures) { File.expand_path("../../fixtures/npm", __FILE__) }
    let(:config) { Licensed::Configuration.new("source_path" => fixtures) }

    it "changes the current directory to app.source_path while running" do
      out, _ = capture_io { @verifier.run }
      assert_match(/autoprefixer.txt:\s+?- license needs reviewed/, out)
    end
  end
end
