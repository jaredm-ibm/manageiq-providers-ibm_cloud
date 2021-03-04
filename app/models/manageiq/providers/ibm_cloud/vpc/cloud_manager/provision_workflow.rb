# frozen_string_literal: true

require 'ipaddr'

class ManageIQ::Providers::IbmCloud::VPC::CloudManager::ProvisionWorkflow < ::MiqProvisionCloudWorkflow
  # Specify the name of the provision dialog to pull from the database.
  # @return [String] The :name field in the provision dialog.
  def self.default_dialog_file
    'miq_provision_vpc_dialogs'
  end

  # Sets the model to use for Provisioning.
  # @return [ManageIQ::Providers::IbmCloud::VPC::CloudManager]
  def self.provider_model
    ManageIQ::Providers::IbmCloud::VPC::CloudManager
  end

  # These are the keys that are populated in the Volumes tab of the UI.
  # @return [Array] Array of strings.
  def volume_dialog_keys
    %i[name size shareable]
  end

  # Fetch available datacenters for this region.
  # @param _options [Hash] Option values returned from web form.
  # @return [Hash] Hash with ems_ref as key and name as value.
  def allowed_placement_availability_zone(_options = {})
    @allowed_placement_availability_zone ||= index_dropdown(ar_ems.availability_zones)
  rescue RuntimeError => e
    log_error_message(__method__, '', e)
    raise
  end

  # Fetch available system profiles.
  # @param _options [Hash] Option values returned from web form.
  # @return [Hash] Hash with ems_ref as key and name as value.
  def allowed_sys_type(_options = {})
    @allowed_sys_type ||= index_dropdown(ar_ems.flavors)
  rescue RuntimeError => e
    log_error_message(__method__, '', e)
    raise
  end

  # @param _options [Hash] Option values returned from web form.
  # @return [Hash] Hash with ems_ref as key and name as value.
  def allowed_storage_type(_options = {})
    @allowed_storage_type ||= index_dropdown(sdk_fetch(:collection, :list_volume_profiles))
  rescue => e
    log_error_message(__method__, '', e)
    raise
  end

  # Get a hash of available SSH key values.
  # @param _options [Hash] Option values returned from web form.
  # @return [Hash] Hash with ems_ref as key and name as value.
  def allowed_guest_access_key_pairs(_options = {})
    return @allowed_guest_access_key_pairs unless @allowed_guest_access_key_pairs.nil?

    @allowed_guest_access_key_pairs ||= begin
      result = sdk_fetch(:request, :list_keys, :optional_key => :keys)
      string_dropdown(result, :key => :id, :value => :name)
    end
  rescue => e
    log_error_message(__method__, '', e)
    raise
  end

  # List available VPCs.
  # @param _options [Hash] Option values returned from web form.
  # @return [Hash] Hash with ems_ref as key and name as value.
  def allowed_cloud_networks(_options = {})
    # TODO: Filter on datacenter. Return empty hash until datacenter is set.
    string_dropdown(ar_ems.cloud_networks, :add_none => true)
  rescue => e
    log_error_message(__method__, '', e)
    raise
  end

  # List available Subnets.
  # @param _options [Hash] Option values returned from web form.
  # @return [Hash] Hash with ems_ref as key and name as value.
  def allowed_subnets(_options = {})
    # TODO: Filter on VPC. Return empty hash until VPC is set.
    string_dropdown(ar_ems.cloud_subnets, :add_none => true)
  rescue => e
    log_error_message(__method__, '', e)
    raise
  end

  # Fetch volumes that either multi_attachment or with a status of available.
  # @param _options [Hash] Option values returned from web form.
  # @return [Hash] Hash with ems_ref as key and name as value.
  def allowed_cloud_volumes(_options = {})
    # TODO: Filter on datacenter. Return empty hash until VPC is set.
    ar_volumes = ar_ems.cloud_volumes.select do |cloud_volume|
      (cloud_volume['multi_attachment'] || cloud_volume['status'] == 'available')
    end

    string_dropdown(ar_volumes)
  rescue => e
    log_error_message(__method__, '', e)
    raise
  end

  # Retrieve a list of resource groups from the IBM Cloud resource controller API.
  # TODO: Remove when all values available via persistor.
  # @param _options [Hash] Not used
  # @return [Array<Hash<String: String>>] A list of hashes containing the resource group id and name.
  def allowed_resource_group(_options = {})
    # FIXME: Guard against cloudtools without resource controller method. I don't want to check it in at the moment. It is a hack, and I'm not sure I need the data.
    begin
      resource_group_list = sdk.cloudtools.respond_to?(:resource_controller) ? sdk.cloudtools.resource_controller.resource_groups : []
    rescue => e
      log_error_message(__method__, '', e)
      resource_group_list = []
    end
    string_dropdown(resource_group_list, :key => :id, :value => :name)
  rescue => e
    log_error_message(__method__, '', e)
    raise
  end

  # Add new volume fields. Super adds requester_group & owner_group
  # @param values [Hash] Values for use in provision request.
  # def set_request_values(values)
  #   # values[:new_volumes] = parse_new_volumes_fields(values)
  #   super
  # end

  # def parse_new_volumes_fields(values)
  #   new_volumes = []
  #   storage_type = values[:storage_type][1]

  #   values.select { |k, _v| k =~ /(#{volume_dialog_keys.join("|")})_(\d+)/ }.each do |key, value|
  #     field, cnt = key.to_s.split("_")
  #     cnt = Integer(cnt)

  #     new_volumes[cnt] ||= {}
  #     new_volumes[cnt][field.to_sym] = value
  #   end

  #   new_volumes.drop(1).map! do |new_volume|
  #     new_volume[:size] = new_volume[:size].to_i
  #     new_volume[:shareable] = [nil, 'null'].exclude?(new_volume[:shareable])
  #     new_volume[:diskType] = storage_type
  #     new_volume
  #   end
  # end

  def validate_entitled_processors(_field, values, _dlg, _fld, value)
    $ibm_cloud_log.info('validate_entitled_processors')
    dedicated = values[:instance_type][1] == 'dedicated'

    fval = /^\s*\d*(\.\d+)?\s*$/.match?(value) ? value.strip.to_f : 0
    return _("Entitled Processors field does not contain a well-formed positive number") unless fval > 0

    if dedicated
      return _('For dedicated processors, the format is: "positive integer"') unless fval % 1 == 0
    else
      return _('For shared processors, the format is: "positive whole multiple of 0.25"') unless ((fval / 0.25) % 1).to_d == 0.to_d
    end
  end

  def validate_ip_address(_field, _values, _dlg, _fld, value)
    $ibm_cloud_log.info('validate_ip_address')
    return _('IP is blank') if value.blank?

    begin
      valid = IPAddr.new(value.strip).ipv4?
    rescue IPAddr::InvalidAddressError
      valid = false
    end

    return _('IP-address field has to be either blank or a valid IPv4 address') unless valid
  end

  private

  # Get a new CloudManager object.
  # @raise [MiqException::MiqProvisionError] Unable to get a new object from server.
  # @return [ManageIQ::Providers::IbmCloud::VPC::CloudManager]
  def ar_ems
    return @ar_ems unless @ar_ems.nil?

    rui = resources_for_ui[:ems]
    ems = load_ar_obj(rui) if rui
    raise MiqException::MiqProvisionError, _('A server-side error occurred in the provisioning workflow') if ems.nil?

    @ar_ems = ems
  rescue => e
    log_error_message(__method__, '', e)
    raise
  end

  # Get a vpc sdk instance.
  # TODO: Remove when all values available via persistor.
  # @return [ManageIQ::Providers::IbmCloud::CloudTools::Vpc]
  def sdk
    ar_ems.connect
  rescue => e
    log_error_message(__method__, "Error received while getting SDK object.", e)
    raise
  end

  # Use callbacks to interact with the VPC SDK.
  # TODO: Remove when all values available via persistor.
  # @param call_type [Symbol] Either :request or :collection.
  # @param call_back [Symbol] The SDK call_back to call.
  # @param optional_key [Symbol | String] The key of the returned api_call to retrieve.
  # @return [Array] The contents of the SDK call.
  def sdk_fetch(call_type, call_back, optional_key: nil)
    result = sdk.send(call_type, call_back)

    # If the cloud_tool call_back is request then a hash will be returned and the Array needs to be exctracted using the optional_key.
    return result.to_a if optional_key.nil?

    array_attempt = find_key(result, optional_key)
    return array_attempt if array_attempt.kind_of?(Array)

    raise MiqException::MiqProvisionError, "unexpected returned results #{result}"
  rescue => e
    log_error_message(__method__, "Using #{call_type} #{call_back} with #{optional_key}", e)
    [{'Error' => 'Provider experienced error'}]
  end

  # Convert an array of hash like objects into a hash.
  # @param provider [Array[Hash]]  An object that acts as an array with hash contents.
  # @param key [String | Symbol] The key in Hash to use for key of the returned hash.
  # @param value [String | Symbol] The key in Hash to use for valuee of the returned hash.
  # @param add_none [Boolean] Add a None key & value.
  # @return [Hash] A hash with the contents of provided key as the key and contents of value key as the value.
  # @return [Hash] If an error is encountered while processing then a hash with Error and 'Provider experienced error' will be returned.
  # On error a log message will be printed to the ibm_cloud.log file.
  def string_dropdown(provider, key: :ems_ref, value: :name, add_none: false)
    # Error handling setup.
    parent_method = caller(1..1).first.split(' ')[-1]

    raise "#{provider.class} does not respond to each_with_object method." unless provider.respond_to?(:each_with_object)

    values = provider.each_with_object({}) { |item, obj| obj[find_key(item, key)] = find_key(item, value) }
    values["None"] = "None" if add_none
    values
  rescue => e
    log_error_message(__method__, "called by: #{parent_method} using #{key} => #{value}", e)
    {'Error' => 'Provider experienced error', 'None' => 'None'}
  end

  # Tries to return the contents of the provided key.
  # @param item [Hash] Hash to query.
  # @param key [String | Symbol] The key to look for,
  # @return [String] The contents of the key in the item hash.
  # @return [String] If the key cannot be found a standard message is returned.
  def find_key(item, key)
    item[key.to_sym] || item[key.to_s] || "key #{key} does not exist in Hash"
  rescue => e
    log_error_message(__method__, "#{item.class} had error using #{key}", e)
    e.to_s
  end

  # Create a hash with integers as keys.
  # @param provider [Array[Hash]]  An object that acts as an array with hash contents.
  # @param value [String | Symbol] The key to use as the returned hash value.
  # @return [Hash] If an error is encountered while processing then a hash with Error and 'Provider experienced error' will be returned.
  # On error a log message will be printed to the ibm_cloud.log file.
  def index_dropdown(provider, value: :name)
    # Error handling setup.
    parent_method = caller(1..1).first.split(' ')[-1]

    raise "#{provider.class} does not respond to 'each_with_object' method." unless provider.respond_to?(:each_with_object)

    index = 0
    provider.each_with_object({}) do |item, obj|
      obj[index] = find_key(item, value)
      index += 1
    end
  rescue => e
    log_error_message(__method__, "called by: #{parent_method}", e)
    {0 => 'Provider experienced error'}
  end

  # Get a templage object by the returned key.
  # @return [MiqTemplate]
  def vm_image
    @vm_image ||= MiqTemplate.find_by(:id => get_option(:src_vm_id))
  rescue RuntimeError => e
    log_error_message(__method__, @vm_image, e)
  end

  # Sets a standardised error log format.
  # @param method_namee [String] The name of the calling method.
  # @param msg [String] A customized message which should have common variables to troubleshoot with.
  # @param exception [Exception] A ruby excepctions which will print out its error string.
  def log_error_message(method_name, msg, exception)
    $ibm_cloud_log.error("#{self.class}.#{method_name} #{msg} exception: #{exception}")
  end

  # Required method to display the provision workflow in UI.
  # @param _message [String]
  # @return [Nil]
  def dialog_name_from_automate(_message = 'get_dialog_name')
  end
end
