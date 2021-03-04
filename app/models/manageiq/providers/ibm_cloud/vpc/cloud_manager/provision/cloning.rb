# frozen_string_literal: true

# Provide all configurable aspects of the actual provision operation.
module ManageIQ::Providers::IbmCloud::VPC::CloudManager::Provision::Cloning
  # Called during provision. Prints message to log file.
  # @param clone_options [Hash] Options used for clone operation.
  # @return [Boolean] The result of the log message.
  def log_clone_options(clone_options)
    log_message(__method__, "IBM SERVER PROVISIONING OPTIONS: #{clone_options}")
    _log.info("IBM SERVER PROVISIONING OPTIONS: #{clone_options}")
  end

  # Create the hash that will be sent to the provider for provisioning.
  # @return [Hash] A complete hash for provisioning.
  def prepare_for_clone_task
    {
      :keys                      => [{:id => get_option(:guest_access_key_pair)}],
      :name                      => get_option(:vm_target_name),
      :profile                   => {:name => get_option_last(:sys_type)},
      :image                     => {:id => vm_image[:ems_id]},
      :zone                      => {:name => get_option_last(:availability_zon)},
      # :vpc                       => {:id => get_option(:cloud_network)}, # If provided, must match the VPC tied to the subnets of the instance's network interfaces.
      :primary_network_interface => {
        :subnet => {:id => get_option(:vlan)}
        # :primary_ipv4_address If unspecified, an available address on the subnet will be automatically selected.
        # :allow_ip_spoofing When not provided defaults to false.
        # :security_groups Collection of security groups. Doesn't say if mandatory. I don't think it is.
      },
      :boot_volume_attachment    => {
        # capacity is the default 100GB
        # encryption_key is the default provider_managed
        # iops appears to be handled by the profile.
        :profile                          => get_option_last(:storage_type),
        :name                             => "#{get_option_last(:vm_target_name)}_boot",
        :delete_volume_on_instance_delete => true
      }
    }
  end

  # Send the final product to the Cloud provider.
  # @param clone_options [Hash] Payload to send to provider.
  # @raise [MiqException::MiqProvisionError] An error was returned by the SDK.
  # @return [String] The ID of the new instance.
  def start_clone(clone_options)
    log_message(__method__, "Options for clone task. #{clone_options}") # FIXME: Remove before commit.
    # response = source.with_provider_object { |vpc| vpc.request(:create_instance, :instance_prototype => clone_options) }
    response = {:id => '0777_a9ee9e6a-231a-4a3c-b9cb-fc83d25114a2'}
    response[:id]
  rescue IBMCloudSdkCore::ApiException => e
    raise MiqException::MiqProvisionError, e.to_s
  end

  # Check the status of the provision.
  # @param clone_task_ref [String] The UUID for the new provision.
  # @return [Array] 2 elements first is boolean when true signals the provision is complete. Second element is a string for logging the current status.
  def do_clone_task_check(clone_task_ref)
    log_message(__method__, "do_clone_task_check(clone_task_ref) #{clone_task_ref}")
    instance = source.with_provider_object { |vpc| vpc.request(:get_instance, :id => clone_task_ref) }
    status = 'The server is being provisioned.'
    case instance[:status].downcase
    when %w[pausing pending restarting resuming starting stopping].include?(status)
      nil # NoOp: Let the case fall to the end and use the default status.
    when 'running'
      return true, 'The server has been provisioned.; '
    when 'failed'
      raise MiqException::MiqProvisionError, _("An error occurred while provisioning the instance.")
    else
      status = "Unknown server state received from the cloud API: '#{instance_state}'"
      _log.warn(status)
      log_message(__method__, status)
    end
    return false, status
  end

  # Standard method unused in our provision.
  # @return [Nil]
  def customize_destination
    signal :post_create_destination
  end
end
