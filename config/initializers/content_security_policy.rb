# frozen_string_literal: true

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.script_src :self, :https, :unsafe_inline
    policy.style_src :self, :https, :unsafe_inline
    policy.font_src :self, :https, :data
    policy.img_src :self, :https, :data
    policy.object_src :none
    policy.frame_ancestors :none
    policy.form_action :self, :https
  end

  config.content_security_policy_nonce_directives = %w(script-src style-src)
  config.content_security_policy_report_only = false
end
