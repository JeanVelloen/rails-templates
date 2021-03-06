require 'shellwords'
require_relative 'lib/config'
require_relative 'lib/rspec'
require_relative 'lib/test_env'
require_relative 'lib/linter'

# Add the current directory to the path Thor uses to look up files

def current_directory
  @current_directory ||=
      if __FILE__ =~ %r{\Ahttps?://}
        tempdir = Dir.mktmpdir("rails-templates")
        at_exit { FileUtils.remove_entry(tempdir) }
        git clone: [
                "--quiet",
                "https://github.com/nimbl3/rails-templates.git",
                tempdir
            ].map(&:shellescape).join(" ")

        tempdir
      else
        File.expand_path(File.dirname(__FILE__))
      end
end

def source_paths
  Array(super) + [current_directory]
end

# Gemfile
remove_file 'Gemfile'
copy_file 'rails_docker/Gemfile.txt', 'Gemfile'

# Docker
remove_file 'Dockerfile'
copy_file 'rails_docker/Dockerfile', 'Dockerfile'
gsub_file 'Dockerfile', '#{app_name}', "#{app_name}"

remove_file 'docker-compose.yml'
copy_file 'rails_docker/docker-compose.yml', 'docker-compose.yml'
gsub_file 'docker-compose.yml', '#{app_name}', "#{app_name}"

copy_file 'rails_docker/docker-compose.dev.yml', 'docker-compose.dev.yml'
gsub_file 'docker-compose.dev.yml', '#{app_name}', "#{app_name}"

copy_file 'rails_docker/docker-compose.test.yml', 'docker-compose.test.yml'
gsub_file 'docker-compose.test.yml', '#{app_name}', "#{app_name}"

remove_file '.dockerignore'
copy_file 'rails_docker/.dockerignore', '.dockerignore'
gsub_file '.dockerignore', '#{app_name}', "#{app_name}"

remove_file '.env'
copy_file 'rails_docker/.env', '.env'

# Shell script for boot the app inside the Docker image (production)
copy_file 'rails_docker/start.sh', 'bin/start.sh'
run 'chmod +x bin/start.sh'

# Shell script for run tests inside the Docker image
copy_file 'rails_docker/test.sh', 'bin/test.sh'
run 'chmod +x bin/test.sh'

# remove test folder
run 'rm -rf test/'

# rvm
run 'touch .ruby-version && echo 2.4.2 > .ruby-version'
run "touch .ruby-gemset && echo #{app_name} > .ruby-gemset"

# Add custom configs
setup_config

# Removing turbolinks
remove_file 'app/assets/javascripts/application.js'
copy_file 'shared/app/assets/javascripts/application.js', 'app/assets/javascripts/application.js'

# Add Procfile
copy_file 'shared/Procfile', 'Procfile'
copy_file 'shared/Procfile.dev', 'Procfile.dev'

after_bundle do
  run 'spring stop'

  # Devise configuration
  generate 'devise:install'
  insert_into_file 'config/environments/development.rb', after: "config.assets.raise_runtime_errors = true\n\n" do
    "  config.action_mailer.default_url_options = { host: \"localhost\", port: 3000 }"
  end

  # Setup test env
  setup_test_env

  # rspec
  setup_rspec

  # Modified Guardfile
  remove_file 'Guardfile'
  copy_file 'shared/Guardfile', 'Guardfile'

  # Shell script to setup the Docker-based development environment
  copy_file 'rails_docker/envsetup', 'bin/envsetup'

  # guard
  run 'bundle exec spring binstub --all'
  run 'bundle exec spring binstub rspec'

  FileUtils.chmod 0755, 'bin/envsetup'

  # Modified README file
  remove_file 'README.md'
  copy_file 'shared/README.md', 'README.md'

  # Setup linters
  setup_linters
end
