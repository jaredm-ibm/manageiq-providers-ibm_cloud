# frozen_string_literal: true

# Opts into CloudManager provisioning. Custom logic is separated into module mixins.
class ManageIQ::Providers::IbmCloud::VPC::CloudManager::Provision < ::MiqProvisionCloud
  include_concern 'Cloning' # Actual provision to cloud.
  include_concern 'StateMachine' # Preprovision tasks.
  include_concern 'OptionsHelper' # Provides shared utility methods.
end
