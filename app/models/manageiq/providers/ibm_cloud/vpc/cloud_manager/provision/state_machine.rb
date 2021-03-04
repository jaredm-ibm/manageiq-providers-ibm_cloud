# frozen_string_literal: true

# Prepare the cloud environment for the provision.
module ManageIQ::Providers::IbmCloud::VPC::CloudManager::Provision::StateMachine
  # Called before provision. Send signal for method to be called.
  # @return [Nil]
  def create_destination
    signal :prepare_volumes
  end

  # Create any requested volumes before sending the provision request.
  # @return [Nil]
  def prepare_volumes
    # TODO: Create any volumes that have been requested.
    signal :prepare_networks
  end

  # Create any additional networks requested by the user.
  # @return [Nil]
  def prepare_networks
    # TODO: Create any networks that have been requested.
    signal :prepare_provision
  end
end
