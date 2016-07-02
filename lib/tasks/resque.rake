require 'resque/tasks'
require 'resque/scheduler/tasks'

namespace :resque do
  task :setup_schedule => :environment do
    require 'resque-scheduler'
    Resque.schedule = YAML.load_file('config/recurring_tasks.yml')
  end

  task :scheduler => :setup_schedule
end
