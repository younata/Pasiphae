rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'

resque_config = {
  'development' => 'localhost:6379',
  'test' => 'localhost:6379',
}
if vcap = ENV['VCAP_SERVICES'] and rails_env == 'production'
  vcap_json = JSON.parse(vcap)
  credentials = vcap_json['rediscloud'][0]['credentials']
  args = {
    'host': credentials['hostname'],
    'password': credentials['password'],
    'port': credentials['port']
  }
  Resque.redis = Redis.new args
else
  Resque.redis = resque_config[rails_env]
end
