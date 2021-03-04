module ManageIQ::Providers::IbmCloud::VPC::CloudManager::Provision::OptionsHelper
  # The ID for this EMS.
  # @return [Integer]
  def cloud_instance_id
    source.ext_management_system.uid_ems
  end

  # Get a MiqTemplate instance for the template selected during provision.
  # @return [MiqTemplate]
  def vm_image
    @vm_image ||= MiqTemplate.find_by(:id => get_option(:src_vm_id))
  end

  # Standardise the input of log messages.
  # @param method [String] The name of the calling method.
  # @param msg [String] The message to print.
  # @param exception [StandardError] An exception subclassed from StandardError
  # @return [Boolean] The return from the logger method.
  def log_message(method, msg = '', exception = nil)
    standard_message = "#{self.class.name}.#{method}  #{msg}"
    return $ibm_cloud_log.error("#{standard_message} Exception: #{exception}") unless exception.nil?

    $ibm_cloud_log.info(standard_message)
  end
end
