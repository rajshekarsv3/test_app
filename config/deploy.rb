require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
# require 'mina/rbenv'  # for rbenv support. (http://rbenv.org)
require 'mina/rvm'    # for rvm support. (http://rvm.io)

# Basic settings:
#   domain       - The hostname to SSH to.
#   deploy_to    - Path to deploy into.
#   repository   - Git repo to clone from. (needed by mina/git)
#   branch       - Branch name to deploy. (needed by mina/git)

set :domain, '104.236.45.194'
set :user, "deployer"
set :rails_env,'production'
set :deploy_to, '/home/deployer/apps/test_app'
set :repository, 'https://github.com/rajshekarsv3/test_app.git'
set :branch, 'master'
set :stage, 'production'

# For system-wide RVM install.
#set :rvm_path, '/usr/local/rvm/bin/rvm'

# Manually create these paths in shared/ (eg: shared/config/database.yml) in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, [ 'log']

# Optional settings:
#   set :user, 'foobar'    # Username in the server to SSH to.
#   set :port, '30000'     # SSH port number.
#   set :forward_agent, true     # SSH forward_agent.

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .ruby-version or .rbenv-version to your repository.
  # invoke :'rbenv:load'

  # For those using RVM, use this to load an RVM version@gemset.
  #set :rvm_path, '/usr/local/rvm/scripts/rvm'
  invoke :'rvm:use[ruby-2.2.1]'
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.
task :setup => :environment do
  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/log"]

  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/config"]
  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/tmp/pids"]
  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/tmp/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/tmp/pids"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/tmp/log"]

  queue! %[touch "#{deploy_to}/#{shared_path}/config/database.yml"]
  queue! %[touch "#{deploy_to}/#{shared_path}/tmp/test_app.sock"]
  queue! %[touch "#{deploy_to}/#{shared_path}/tmp/pids/puma.pid"]
  queue  %[echo "-----> Be sure to edit '#{deploy_to}/#{shared_path}/config/database.yml'."]
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  to :before_hook do
    # Put things to run locally before ssh
  end
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths' 
    invoke :'bundle:install'
    invoke :'deploy:cleanup'

    to :launch do
       invoke :'docker:build' 
       invoke :'docker:stop' # stop the previous container
       invoke :'docker:run' # run new container with released code
      # queue "mkdir -p #{deploy_to}/#{current_path}/tmp/"
      # queue "touch #{deploy_to}/#{current_path}/tmp/restart.txt"
      #invoke :'puma:restart'
    end

  end
end

# For help in making your deploy script, see the Mina documentation:
#
#  - http://nadarei.co/mina
#  - http://nadarei.co/mina/tasks
#  - http://nadarei.co/mina/settings
#  - http://nadarei.co/mina/helpers

namespace :puma do
  desc "Start the application"
  task :start do
    queue 'echo "-----> Start Puma"'
    queue %[chmod +x "#{deploy_to}/#{current_path}/bin/puma.sh"]
    queue "cd #{deploy_to}/#{current_path} && RAILS_ENV=#{stage} && bin/puma.sh start #{stage} -p 80 -d"
  end

  desc "Stop the application"
  task :stop do
    queue 'echo "-----> Stop Puma"'
    queue "cd #{deploy_to}/#{current_path} && RAILS_ENV=#{stage} && bin/puma.sh stop"
  end

  desc "Restart the application"
  task :restart do
    queue 'echo "-----> Restart Puma" #{deploy_to}/#{current_path}/#{shared_path}'
    queue %[chmod +x "#{deploy_to}/#{current_path}/bin/puma.sh"]
    queue "cd #{deploy_to}/#{current_path} && RAILS_ENV=#{stage} && bin/puma.sh restart #{stage} -p 80 -d"
  end

end



namespace :docker do
  desc "Build docker image"

  task :build do
    queue "echo 'cd #{deploy_to}/#{current_path}'"
    queue 'cd #{deploy_to}/#{current_path}'
    queue "sudo docker build   -t rajshekarsv3/test:v2 ."
  end

  desc "Start docker container"
  task :run do
    queue "sudo docker run -d -p 81:3000 --name testapp rajshekarsv3/test:v2"
  end

  

  desc "Stop docker container"
  task :stop do
    queue "if [ ! -z \"$(sudo docker ps | grep 'testapp')\" ]; then sudo docker stop testapp; sudo docker rm -f testapp; fi"
  end

  desc "Remove all stop container"
  task :clean_containers do
    queue "sudo docker rm $(sudo docker ps -a -q)"
  end
end

