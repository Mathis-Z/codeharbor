# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

require_relative 'sentry_csp'
require_relative 'sentry_javascript'

module CSP
  def self.apply_yml_settings_for(policy)
    yaml_file = Rails.root.join('config/content_security_policy.yml').read
    csp_settings = YAML.safe_load(yaml_file, aliases: true, permitted_classes: [Symbol])[Rails.env]

    csp_settings.each do |directive, additional_settings|
      existing_settings = if directive == 'report_uri'
                            ''
                          else
                            policy.public_send(directive) || []
                          end
      all_settings = additional_settings
      all_settings += existing_settings unless existing_settings == ["'none'"]
      policy.public_send(directive, *all_settings)
    end
  end

  def self.apply_sentry_settings_for(policy)
    sentry_domain = URI.parse SentryJavascript.dsn
    additional_setting = "#{sentry_domain.scheme}://#{sentry_domain.host}"
    existing_settings = policy.connect_src || []
    all_settings = existing_settings + [additional_setting]
    policy.connect_src(*all_settings)
  end
end

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src          :none
    policy.base_uri             :self
    policy.font_src             :self
    # ACE uses :data URIs for images
    policy.img_src              :self, :data
    policy.object_src           :none
    policy.media_src            :self
    # Unfortunately, we still have many click handlers and inline JavaScript that require :unsafe_inline
    policy.script_src           :self, :unsafe_inline, :report_sample
    # Our ACE editor unfortunately requires :unsafe_inline for the code highlighting
    policy.style_src            :self, :unsafe_inline, :report_sample
    policy.connect_src          :self
    # Our ACE editor uses web workers to highlight code, preferably via URL or otherwise with a blob.
    policy.child_src            :self, :blob
    policy.form_action          :self
    policy.frame_ancestors      :none

    # Specify URI for violation reports
    policy.report_uri           SentryCsp.report_url if SentryCsp.active?

    CSP.apply_yml_settings_for      policy
    CSP.apply_sentry_settings_for   policy if SentryJavascript.active?
  end

  # Generate session nonces for permitted importmap and inline scripts
  # config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  # config.content_security_policy_nonce_directives = %w[script-src]

  # Report violations without enforcing the policy
  # config.content_security_policy_report_only = true
end
