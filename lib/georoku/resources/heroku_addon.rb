########################################################################
# HerokuAddon is the +heroku_addon+ terraform resource,
#
# {https://www.terraform.io/docs/providers/heroku/r/addon.html Terraform Docs}
########################################################################

require 'geoengineer'
require 'net/http'

class GeoEngineer::Resources::HerokuAddon < GeoEngineer::Resources 
  validate -> { validate_required_attributes([:app, :plan]) }
  validate -> { validate_subresource_required_attributes(:config, [:url]) }

  def to_terraform_state
    tfstate = super
    tfstate[:primary][:attributes] = {
      'id' => _terraform_id,
      'idle_timeout' => '60',
      'enable_deletion_protection' => 'false',
      'enable_http2' => 'true',
      'enable_cross_zone_load_balancing' => 'false'
    }
    tfstate
  end

  def short_type
    "addon"
  end

  def self._merge_attributes(albs, tags)
    albs.map do |alb|
      alb_tags = tags.find { |desc| desc[:resource_arn] == alb[:load_balancer_arn] }
      alb.merge(
        {
          _terraform_id: alb[:load_balancer_arn],
          _geo_id: alb_tags[:tags]&.find { |tag| tag[:key] == "Name" }.dig(:value)
        }
      )
    end
  end

  def self._fetch_remote_resources(provider)
    Net::HTTP.get('example.com', '/index.html')  

    albs = AwsClients.alb(provider).describe_load_balancers['load_balancers'].map(&:to_h)
    return [] if albs.empty?

    tags = AwsClients.alb(provider)
                     .describe_tags({ resource_arns: albs.map { |alb| alb[:load_balancer_arn] } })
                     .tag_descriptions
                     .map(&:to_h)

    _merge_attributes(albs, tags)
  end
end
