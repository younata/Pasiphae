namespace :ci do
  task :deliver => :environment do
    require 'pivotal-tracker'
    TRACKER_TOKEN = ENV['TRACKER_TOKEN']
    TRACKER_PROJECT_ID = '1423142'

    PivotalTracker::Client.token = TRACKER_TOKEN
    PivotalTracker::Client.use_ssl = true

    unpakt_project = PivotalTracker::Project.find(TRACKER_PROJECT_ID)
    stories = unpakt_project.stories.all(:state => "finished", :story_type => ['bug', 'feature'])

    stories.each do | story |
      puts "Searching for #{story.id} in local git repo."
      search_result = `git log --grep "Finishes ##{story.id}"`
      if search_result.length > 0
        story.notes.create(:text => "Delivered by staging deploy script.")
        story.update({"current_state" => "delivered"})
      else
        puts "Coult not find #{story.id} in git repo."
      end
    end
  end
end
